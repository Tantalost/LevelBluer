"""Persistent online PvP match history (table ``pvp_matches``) and per-student stats.

Only server-built MatchRecords are written; no route accepts a result from a client.
``match_id`` is the primary key and inserts ignore duplicates, then the stored row is read
back: an identical row is a harmless duplicate, a different one is an integrity conflict.
Stats are derived from history, never stored.
Separate from BKT/mastery: this module touches no table other than ``pvp_matches``.

Pre-match semantics: a room that never had two players produces no row (PvpService never
builds a record for it). A two-player room closed before both readied is stored as
``abandoned_before_start`` but excluded from every stat. A started match always has a row.

Durability limit: failed writes stay pending and retry with capped exponential backoff for
the life of the process, but pending writes live in memory, so a backend restart before
they land still loses them. Durable delivery (outbox table/queue) is Phase 5 infrastructure.
"""
from __future__ import annotations

import logging
import time
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from app.services.pvp_service import FINISH_ABANDONED, MatchRecord
from app.supabase_client import supabase

logger = logging.getLogger(__name__)

TABLE = "pvp_matches"
RETRY_BASE_SECONDS = 1.0
RETRY_MAX_SECONDS = 300.0
PAGE_SIZE = 1000
RECENT_LIMIT_MAX = 20
SUMMARY_COLUMNS = "player1_id,player2_id,winner_id,forfeited_by,finish_reason,rounds_played"
RECENT_COLUMNS = (
    "match_id,origin,player1_id,player2_id,winner_id,forfeited_by,finish_reason,rounds_played,finished_at,"
    "player1_hp,player2_hp,player1_correct,player2_correct,player1_wrong,player2_wrong,player1_timeouts,player2_timeouts"
)


class HistoryUnavailable(Exception):
    pass


class MatchConflict(Exception):
    """A row with this match_id already exists with a different result."""


def is_student_id(value: str) -> bool:
    """Only canonical lowercase UUIDs, the form Postgres returns for students.id."""
    try:
        return str(uuid.UUID(str(value))) == value
    except ValueError:
        return False


def _iso(ms: int | None) -> str | None:
    return None if ms is None else datetime.fromtimestamp(ms / 1000, UTC).isoformat()


def match_row(record: MatchRecord) -> dict[str, Any]:
    one, two = record.player1, record.player2
    return {
        "match_id": record.match_id,
        "origin": record.origin,
        "player1_id": one.user_id,
        "player2_id": two.user_id,
        "winner_id": record.winner_id,
        "forfeited_by": record.forfeited_by,
        "finish_reason": record.finish_reason,
        "player1_hp": one.hp,
        "player2_hp": two.hp,
        "player1_correct": one.correct,
        "player2_correct": two.correct,
        "player1_wrong": one.wrong,
        "player2_wrong": two.wrong,
        "player1_timeouts": one.timeouts,
        "player2_timeouts": two.timeouts,
        "rounds_played": record.rounds_played,
        "started_at": _iso(record.started_at),
        "finished_at": _iso(record.finished_at),
    }


def _comparable(column: str, value: Any) -> Any:
    # Postgres echoes timestamps in its own ISO spelling; compare instants, not strings.
    if value is not None and column in ("started_at", "finished_at"):
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    return value


def conflicting_columns(stored: dict[str, Any], row: dict[str, Any]) -> list[str]:
    return [column for column in row if _comparable(column, stored.get(column)) != _comparable(column, row[column])]


def insert_match(row: dict[str, Any]) -> None:
    """Insert once; an identical existing row is success, a different one raises MatchConflict."""
    supabase.table(TABLE).upsert(row, on_conflict="match_id", ignore_duplicates=True).execute()
    stored = supabase.table(TABLE).select(",".join(row)).eq("match_id", row["match_id"]).execute().data or []
    if not stored:
        raise RuntimeError("match row not visible after insert")
    differs = conflicting_columns(stored[0], row)
    if differs:
        raise MatchConflict(f"match {row['match_id']} already stored with different {', '.join(differs)}")


@dataclass
class _Pending:
    record: MatchRecord
    row: dict[str, Any]
    attempts: int = 0
    next_at: float = 0.0


class MatchRecorder:
    """Retries each match write until it lands, for the life of the process.

    Failures back off exponentially (capped) per match, so an outage never spins and
    one stuck write never delays others. ``add`` and ``flush`` are called sequentially
    by one hub task, off the event loop, never concurrently.
    """

    def __init__(
        self,
        writer: Callable[[dict[str, Any]], None] = insert_match,
        clock: Callable[[], float] = time.monotonic,
        base_seconds: float = RETRY_BASE_SECONDS,
        max_seconds: float = RETRY_MAX_SECONDS,
        on_stored: Callable[[MatchRecord], None] | None = None,
    ) -> None:
        self._writer = writer
        self._clock = clock
        self._base = base_seconds
        self._max = max_seconds
        self._pending: dict[str, _Pending] = {}
        self.conflicts = 0
        # Fired only after the history row is confirmed stored (Phase 4B rating hook).
        self.on_stored = on_stored

    @property
    def pending(self) -> int:
        return len(self._pending)

    def pending_records(self) -> list[MatchRecord]:
        return [item.record for item in self._pending.values()]

    def retry_delay(self, attempts: int) -> float:
        return min(self._max, self._base * 2 ** max(0, attempts - 1))

    def add(self, records: list[MatchRecord]) -> None:
        for record in records:
            if not (is_student_id(record.player1.user_id) and is_student_id(record.player2.user_id)):
                logger.warning("PvP match %s not recorded: player ids are not student accounts", record.match_id)
                continue
            self._pending.setdefault(record.match_id, _Pending(record, match_row(record)))

    def flush(self) -> int:
        written = 0
        now = self._clock()
        for match_id, item in list(self._pending.items()):
            if item.next_at > now:
                continue
            try:
                self._writer(item.row)
            except MatchConflict as exc:
                # Retrying cannot fix a different stored result; the existing row is kept untouched.
                del self._pending[match_id]
                self.conflicts += 1
                logger.error("PvP history integrity conflict: %s", exc)
                continue
            except Exception as exc:
                item.attempts += 1
                item.next_at = now + self.retry_delay(item.attempts)
                logger.warning("PvP match %s write failed (attempt %d, retry in %.0fs): %s", match_id, item.attempts, item.next_at - now, type(exc).__name__)
                continue
            del self._pending[match_id]
            written += 1
            if self.on_stored is not None:
                self.on_stored(item.record)
        return written


# ---- reads (the caller's own matches only) ---------------------------------------

def _own(columns: str, student_id: str):
    # student_id is a validated UUID from the verified JWT, so it is safe inside the filter.
    return supabase.table(TABLE).select(columns).or_(f"player1_id.eq.{student_id},player2_id.eq.{student_id}")


def _fetch_all(student_id: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    start = 0
    while True:
        page = _own(SUMMARY_COLUMNS, student_id).order("match_id").range(start, start + PAGE_SIZE - 1).execute().data or []
        rows.extend(page)
        if len(page) < PAGE_SIZE:
            return rows
        start += PAGE_SIZE


def summarize(student_id: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    played = wins = losses = draws = forfeits = rounds = 0
    for row in rows:
        if student_id not in (row.get("player1_id"), row.get("player2_id")):
            continue
        if row.get("finish_reason") == FINISH_ABANDONED:
            continue
        played += 1
        rounds += int(row.get("rounds_played") or 0)
        winner = row.get("winner_id")
        if winner is None:
            draws += 1
        elif winner == student_id:
            wins += 1
        else:
            losses += 1
        if row.get("forfeited_by") == student_id:
            forfeits += 1
    return {
        "matches_played": played,
        "wins": wins,
        "losses": losses,
        "draws": draws,
        "forfeits": forfeits,
        "win_rate": round(wins / played, 4) if played else 0.0,
        "rounds_played": rounds,
    }


def _outcome(student_id: str, row: dict[str, Any]) -> str:
    if row.get("finish_reason") == FINISH_ABANDONED:
        return "no_contest"
    winner = row.get("winner_id")
    if winner is None:
        return "draw"
    return "win" if winner == student_id else "loss"


def recent_entry(student_id: str, row: dict[str, Any]) -> dict[str, Any]:
    me, them = ("player1", "player2") if row.get("player1_id") == student_id else ("player2", "player1")
    return {
        "match_id": row["match_id"],
        "origin": row["origin"],
        "result": _outcome(student_id, row),
        "finish_reason": row["finish_reason"],
        "forfeited": row.get("forfeited_by") == student_id,
        "my_hp": row[f"{me}_hp"],
        "opponent_hp": row[f"{them}_hp"],
        "rounds_played": row["rounds_played"],
        "correct": row[f"{me}_correct"],
        "wrong": row[f"{me}_wrong"],
        "timeouts": row[f"{me}_timeouts"],
        "finished_at": row["finished_at"],
    }


def student_summary(student_id: str) -> dict[str, Any]:
    if not is_student_id(student_id):
        return summarize(student_id, [])
    try:
        rows = _fetch_all(student_id)
    except Exception as exc:
        raise HistoryUnavailable from exc
    return summarize(student_id, rows)


def recent_matches(student_id: str, limit: int) -> list[dict[str, Any]]:
    if not is_student_id(student_id):
        return []
    limit = max(1, min(limit, RECENT_LIMIT_MAX))
    try:
        rows = _own(RECENT_COLUMNS, student_id).order("finished_at", desc=True).limit(limit).execute().data or []
    except Exception as exc:
        raise HistoryUnavailable from exc
    return [recent_entry(student_id, row) for row in rows if student_id in (row.get("player1_id"), row.get("player2_id"))]
