"""PvP Points (ranked progression) for automatic matchmaking matches.

The points calculation, locking, idempotency and chronological ordering live in the SQL function
``levelblue_apply_pvp_rating`` (migrations/pvp_ratings.sql), which reads the stored authoritative
``pvp_matches`` row; this module only decides *when* to call it and maps points to ranks.
Rank is always derived from points here and never stored. Separate from BKT/mastery/tokens.

Durability: a match is queued for rating only after its history row is stored. Jobs pending in memory
are lost on restart, but ``recover()`` re-finds every rated-eligible match without rating events
(oldest first) from the database, so a restart delays ratings rather than losing them.
"""
from __future__ import annotations

import logging
import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from app.services.pvp_history import MatchRecorder, is_student_id
from app.services.pvp_service import (
    FINISH_FORFEIT_DISCONNECT,
    FINISH_FORFEIT_LEAVE,
    FINISH_KO,
    ORIGIN_MATCHMAKING,
    MatchRecord,
)
from app.supabase_client import supabase
from app.services.database_diagnostics import safe_database_error

logger = logging.getLogger(__name__)

INITIAL_POINTS = 1000
RANKS: tuple[tuple[str, int], ...] = (
    ("Bronze", 0),
    ("Silver", 900),
    ("Gold", 1200),
    ("Platinum", 1600),
    ("Diamond", 2100),
    ("Grandmaster", 2700),
)
RATED_FINISHES = frozenset({FINISH_KO, FINISH_FORFEIT_LEAVE, FINISH_FORFEIT_DISCONNECT})
RETRY_BASE_SECONDS = 1.0
RETRY_MAX_SECONDS = 300.0
WAIT_SECONDS = 2.0
RECOVERY_PAGE = 200

DONE = frozenset({"applied", "already_applied", "unrated"})
WAITING = "waiting_for_prior_match"
CONFLICT = "conflict"


class RatingUnavailable(Exception):
    pass


# ---- ranks ---------------------------------------------------------------------------

def rank_index(points: int) -> int:
    index = 0
    for position, (_name, threshold) in enumerate(RANKS):
        if points >= threshold:
            index = position
    return index


def rank_for(points: int) -> str:
    return RANKS[rank_index(points)][0]


def standing(row: dict[str, Any] | None) -> dict[str, Any]:
    """The /me/rank payload. A student with no rated match yet reads as a new player."""
    row = row or {}
    points = int(row.get("points", INITIAL_POINTS))
    index = rank_index(points)
    following = RANKS[index + 1] if index + 1 < len(RANKS) else None
    return {
        "points": points,
        "rank": RANKS[index][0],
        "current_threshold": RANKS[index][1],
        "next_rank": following[0] if following else None,
        "next_threshold": following[1] if following else None,
        "points_to_next_rank": following[1] - points if following else None,
        "rated_matches": int(row.get("rated_matches", 0)),
        "wins": int(row.get("wins", 0)),
        "losses": int(row.get("losses", 0)),
        "draws": int(row.get("draws", 0)),
    }


def student_standing(student_id: str) -> dict[str, Any]:
    if not is_student_id(student_id):
        return standing(None)
    try:
        rows = supabase.table("pvp_ratings").select("points,rated_matches,wins,losses,draws").eq("student_id", student_id).execute().data or []
    except Exception as exc:
        raise RatingUnavailable from exc
    return standing(rows[0] if rows else None)


# ---- database calls -----------------------------------------------------------------------

def apply_rating(match_id: str) -> dict[str, Any]:
    data = supabase.rpc("levelblue_apply_pvp_rating", {"p_match_id": match_id}).execute().data
    if not isinstance(data, dict) or "status" not in data:
        raise RuntimeError("rating function returned no status")
    return data


def list_unrated(after_finished: str | None, after_id: str | None, limit: int) -> list[dict[str, Any]]:
    return supabase.rpc("levelblue_pvp_unrated_matches", {"p_after_finished": after_finished, "p_after_id": after_id, "p_limit": limit}).execute().data or []


def is_rated_record(record: MatchRecord) -> bool:
    """Python mirror of levelblue_pvp_is_rated (the SQL function is authoritative and re-checks)."""
    return record.origin == ORIGIN_MATCHMAKING and record.started_at is not None and record.finish_reason in RATED_FINISHES


def _instant(value: Any) -> datetime:
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, UTC)
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def history_blocker(recorder: MatchRecorder) -> Callable[[frozenset[str], datetime], bool]:
    """True while an older rated-eligible match of these players is still waiting for its history row."""
    def blocked(players: frozenset[str], finished: datetime) -> bool:
        return any(
            is_rated_record(record)
            and players & {record.player1.user_id, record.player2.user_id}
            and _instant(record.finished_at) < finished
            for record in recorder.pending_records()
        )
    return blocked


# ---- queue ---------------------------------------------------------------------------------

@dataclass
class _Job:
    match_id: str
    players: frozenset[str]
    finished: datetime
    attempts: int = 0
    next_at: float = 0.0


class RatingQueue:
    """Applies stored matchmaking results oldest-first, retrying for the life of the process.

    ``add``/``recover``/``flush`` run sequentially in the hub's recorder task (off the event loop).
    ``history_blocked(players, finished)`` reports an older rated-eligible match of the same players
    whose history row is still pending, so a later match never overtakes it in this process.
    """

    def __init__(
        self,
        apply: Callable[[str], dict[str, Any]] = apply_rating,
        unrated: Callable[[str | None, str | None, int], list[dict[str, Any]]] = list_unrated,
        clock: Callable[[], float] = time.monotonic,
        base_seconds: float = RETRY_BASE_SECONDS,
        max_seconds: float = RETRY_MAX_SECONDS,
        wait_seconds: float = WAIT_SECONDS,
        history_blocked: Callable[[frozenset[str], datetime], bool] | None = None,
    ) -> None:
        self._apply = apply
        self._unrated = unrated
        self._clock = clock
        self._base = base_seconds
        self._max = max_seconds
        self._wait = wait_seconds
        self.history_blocked = history_blocked
        self._jobs: dict[str, _Job] = {}
        self.recovered = False
        self._recovery_attempts = 0
        self._recovery_next_at = 0.0
        self.conflicts = 0

    @property
    def pending(self) -> int:
        return len(self._jobs)

    def retry_delay(self, attempts: int) -> float:
        return min(self._max, self._base * 2 ** max(0, attempts - 1))

    def _enqueue(self, match_id: str, players: frozenset[str], finished: datetime) -> None:
        self._jobs.setdefault(match_id, _Job(match_id, players, finished))

    def add(self, record: MatchRecord) -> None:
        """Called once the match's history row is stored."""
        if is_rated_record(record):
            self._enqueue(record.match_id, frozenset({record.player1.user_id, record.player2.user_id}), _instant(record.finished_at))

    def recover(self) -> bool:
        """Queue every rated-eligible match the database still has without rating events."""
        now = self._clock()
        if self.recovered or now < self._recovery_next_at:
            return self.recovered
        after_finished: str | None = None
        after_id: str | None = None
        try:
            while True:
                page = self._unrated(after_finished, after_id, RECOVERY_PAGE)
                for row in page:
                    self._enqueue(str(row["match_id"]), frozenset({str(row["player1_id"]), str(row["player2_id"])}), _instant(row["finished_at"]))
                if len(page) < RECOVERY_PAGE:
                    break
                after_finished, after_id = str(page[-1]["finished_at"]), str(page[-1]["match_id"])
        except Exception as exc:
            self._recovery_attempts += 1
            self._recovery_next_at = now + self.retry_delay(self._recovery_attempts)
            logger.warning("PvP rating recovery failed (attempt %d) operation=pvp_rating_recovery %s", self._recovery_attempts, safe_database_error(exc))
            return False
        self.recovered = True
        if self._jobs:
            logger.info("PvP rating recovery queued %d unrated match(es)", len(self._jobs))
        return True

    def _blocked(self, job: _Job, ahead: list[_Job]) -> bool:
        if any(other.players & job.players for other in ahead):
            return True
        return self.history_blocked is not None and self.history_blocked(job.players, job.finished)

    def flush(self) -> int:
        applied = 0
        now = self._clock()
        unfinished: list[_Job] = []
        for job in sorted(self._jobs.values(), key=lambda item: (item.finished, item.match_id)):
            # An older job for the same player that is still pending holds this one back locally too.
            if job.next_at > now or self._blocked(job, unfinished):
                unfinished.append(job)
                continue
            try:
                outcome = self._apply(job.match_id)
            except Exception as exc:
                job.attempts += 1
                job.next_at = now + self.retry_delay(job.attempts)
                logger.warning("PvP rating for match %s failed (attempt %d, retry in %.0fs): %s", job.match_id, job.attempts, job.next_at - now, type(exc).__name__)
                unfinished.append(job)
                continue
            status = str(outcome.get("status"))
            if status in DONE:
                del self._jobs[job.match_id]
                applied += status == "applied"
            elif status == CONFLICT:
                del self._jobs[job.match_id]
                self.conflicts += 1
                logger.error("PvP rating integrity conflict for match %s: stored rating events disagree with the match result", job.match_id)
            elif status == WAITING:
                job.next_at = now + self._wait
                unfinished.append(job)
            else:
                job.attempts += 1
                job.next_at = now + self.retry_delay(job.attempts)
                logger.warning("PvP rating for match %s not ready (%s), retry in %.0fs", job.match_id, status, job.next_at - now)
                unfinished.append(job)
        return applied
