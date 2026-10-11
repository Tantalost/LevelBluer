"""Authoritative online PvP rooms.

The server owns the question, option order, grading, submission order, deadlines,
damage, HP, and winner. Clients may only send a room code, the round number they
are answering, and the position of the option they tapped. No BKT, rewards, or tokens.

Rooms live in process memory: production must run ONE backend worker until room
state and locking move to a shared store (Redis/Supabase).

Every state change appends an event to the room outbox with a room-wide, strictly
increasing ``revision``. A transport (see pvp_hub) drains and delivers them.
"""
from __future__ import annotations

import json
import logging
import random
import secrets
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

MAX_HP = 100
ROUND_MS = 10_000
COUNTDOWN_MS = 3_000
RESULT_MS = 2_500
DAMAGE_HIT = 20
OPTION_COUNT = 4
ROOM_CODE_LENGTH = 6
ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
BANK_PATH = Path(__file__).resolve().parent.parent / "data" / "pvp_social_engineering_100_all_easy.json"

ACTIVE_GRACE_MS = 15_000
WAITING_GRACE_MS = 60_000
CLOSED_TTL_MS = 60_000
STALE_WAITING_MS = 10 * 60_000


class RoomState(str, Enum):
    WAITING = "waiting"
    COUNTDOWN = "countdown"
    ACTIVE = "active"
    ROUND_RESULT = "round_result"
    FINISHED = "finished"
    ABANDONED = "abandoned"


TERMINAL_STATES = (RoomState.FINISHED, RoomState.ABANDONED)


class PvpError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class PvpQuestion:
    id: str
    question: str
    options: tuple[str, ...]
    answer_index: int
    topic: str
    difficulty: str


@dataclass
class Player:
    user_id: str
    ready: bool = False
    hp: int = MAX_HP
    connected: bool = True
    disconnected_at: int | None = None


@dataclass
class Submission:
    choice: int
    correct: bool
    at_ms: int


@dataclass
class Round:
    number: int
    question: PvpQuestion
    order: list[int]
    started_at: int
    ends_at: int
    submissions: dict[str, Submission] = field(default_factory=dict)
    resolved: bool = False
    winner_id: str | None = None
    damage: dict[str, int] = field(default_factory=dict)

    def correct_position(self) -> int:
        return self.order.index(self.question.answer_index)


@dataclass
class Event:
    to: str | None
    payload: dict[str, Any]


@dataclass
class Room:
    code: str
    host: Player
    rng: random.Random
    guest: Player | None = None
    state: RoomState = RoomState.WAITING
    round_number: int = 0
    countdown_ends_at: int = 0
    result_ends_at: int = 0
    current: Round | None = None
    winner_id: str | None = None
    retired_by: str | None = None
    finish_reason: str | None = None
    questions_selected: int = 0
    deck: list[str] = field(default_factory=list)
    cursor: int = 0
    last_question_id: str = ""
    revision: int = 0
    outbox: list[Event] = field(default_factory=list)
    created_at: int = 0
    closed_at: int | None = None
    lock: threading.Lock = field(default_factory=threading.Lock)

    def player(self, user_id: str) -> Player | None:
        if self.host.user_id == user_id:
            return self.host
        if self.guest is not None and self.guest.user_id == user_id:
            return self.guest
        return None

    def opponent(self, user_id: str) -> Player | None:
        if self.host.user_id == user_id:
            return self.guest
        if self.guest is not None and self.guest.user_id == user_id:
            return self.host
        return None

    def players(self) -> list[Player]:
        return [self.host] if self.guest is None else [self.host, self.guest]


def question_problem(item: Any) -> str:
    """Why a bank row is unusable, or "" when valid."""
    if not isinstance(item, dict):
        return "not an object"
    if not str(item.get("id", "")).strip():
        return "missing id"
    if not str(item.get("question", "")).strip():
        return "missing question"
    options = item.get("options")
    if not isinstance(options, list) or len(options) != OPTION_COUNT:
        return f"needs exactly {OPTION_COUNT} options"
    if any(not isinstance(option, str) or not option.strip() for option in options):
        return "blank option"
    answer = item.get("answer_index")
    if isinstance(answer, bool) or not isinstance(answer, int):
        return "answer_index is not an integer"
    if not 0 <= answer < OPTION_COUNT:
        return "answer_index out of range"
    return ""


def load_bank(path: Path = BANK_PATH) -> list[PvpQuestion]:
    """Flatten modules -> question_types -> questions. Malformed rows are skipped; a bad file yields []."""
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        logger.error("PvP bank unavailable at %s: %s", path, exc)
        return []
    modules = raw.get("modules") if isinstance(raw, dict) else None
    if not isinstance(modules, list):
        logger.error("PvP bank at %s has no modules list", path)
        return []
    bank: list[PvpQuestion] = []
    seen: set[str] = set()
    for module in modules:
        if not isinstance(module, dict):
            continue
        topic = str(module.get("topic", "")).strip()
        for question_type in module.get("question_types", []) or []:
            if not isinstance(question_type, dict):
                continue
            for item in question_type.get("questions", []) or []:
                problem = question_problem(item)
                qid = str(item.get("id", "")).strip() if isinstance(item, dict) else ""
                if not problem and qid in seen:
                    problem = "duplicate id"
                if problem:
                    logger.warning("Skipping PvP question %r: %s", qid, problem)
                    continue
                seen.add(qid)
                bank.append(PvpQuestion(
                    id=qid,
                    question=str(item["question"]).strip(),
                    options=tuple(str(option) for option in item["options"]),
                    answer_index=int(item["answer_index"]),
                    topic=topic,
                    difficulty=str(item.get("difficulty", "")).strip(),
                ))
    return bank


def _wall_clock_ms() -> int:
    return int(time.time() * 1000)


def _random_code() -> str:
    return "".join(secrets.choice(ROOM_CODE_ALPHABET) for _ in range(ROOM_CODE_LENGTH))


class PvpService:
    def __init__(
        self,
        bank: list[PvpQuestion] | None = None,
        clock: Callable[[], int] = _wall_clock_ms,
        code_factory: Callable[[], str] = _random_code,
        seed: int | None = None,
        active_grace_ms: int = ACTIVE_GRACE_MS,
        waiting_grace_ms: int = WAITING_GRACE_MS,
        closed_ttl_ms: int = CLOSED_TTL_MS,
        stale_waiting_ms: int = STALE_WAITING_MS,
    ) -> None:
        self._bank: dict[str, PvpQuestion] = {question.id: question for question in (load_bank() if bank is None else bank)}
        self._clock = clock
        self._code_factory = code_factory
        self._seeds = random.Random(seed)
        self._rooms: dict[str, Room] = {}
        self._rooms_lock = threading.Lock()
        self.active_grace_ms = active_grace_ms
        self.waiting_grace_ms = waiting_grace_ms
        self.closed_ttl_ms = closed_ttl_ms
        self.stale_waiting_ms = stale_waiting_ms

    @property
    def bank_size(self) -> int:
        return len(self._bank)

    def now(self) -> int:
        return self._clock()

    # ---- lifecycle -------------------------------------------------------

    def create_room(self, user_id: str) -> dict[str, Any]:
        if not self._bank:
            raise PvpError("bank_unavailable", "PvP questions are unavailable")
        with self._rooms_lock:
            for _attempt in range(64):
                code = self._code_factory().strip().upper()
                if code and code not in self._rooms:
                    break
            else:
                raise PvpError("code_exhausted", "Could not allocate a room code")
            room = Room(code=code, host=Player(user_id), rng=random.Random(self._seeds.getrandbits(64)), created_at=self._clock())
            self._rooms[code] = room
        with room.lock:
            return self._view(room, user_id)

    def member_of(self, code: str, user_id: str) -> bool:
        room = self._room(code)
        with room.lock:
            return room.player(user_id) is not None

    def join_room(self, code: str, user_id: str) -> dict[str, Any]:
        room = self._room(code)
        with room.lock:
            self._advance(room)
            existing = room.player(user_id)
            if existing is not None:
                existing.connected = True
                existing.disconnected_at = None
                return self._view(room, user_id)
            if room.state in TERMINAL_STATES:
                raise PvpError("room_closed", "This room is closed")
            if room.guest is not None:
                raise PvpError("room_full", "This room already has two players")
            room.guest = Player(user_id)
            self._emit_states(room)
            return self._view(room, user_id)

    def set_ready(self, code: str, user_id: str, ready: bool = True) -> dict[str, Any]:
        room = self._room(code)
        with room.lock:
            self._advance(room)
            player = self._member(room, user_id)
            if room.state != RoomState.WAITING:
                raise PvpError("not_waiting", "Ready can only change before the match starts")
            player.ready = ready
            if room.guest is not None and room.host.ready and room.guest.ready:
                room.round_number = 1
                room.countdown_ends_at = self._clock() + COUNTDOWN_MS
                room.state = RoomState.COUNTDOWN
                self._emit(room, "countdown_started", {"round": room.round_number, "countdown_ends_at": room.countdown_ends_at})
            else:
                self._emit_states(room)
            return self._view(room, user_id)

    def connect(self, code: str, user_id: str) -> dict[str, Any]:
        """A realtime connection for this member opened (first time or reconnect)."""
        room = self._room(code)
        with room.lock:
            self._advance(room)
            player = self._member(room, user_id)
            player.connected = True
            player.disconnected_at = None
            self._emit(room, "room_state", self._view(room, user_id), to=user_id)
            opponent = room.opponent(user_id)
            if opponent is not None:
                self._emit(room, "opponent_connected", {"user_id": user_id}, to=opponent.user_id)
            return self._view(room, user_id)

    def disconnect(self, code: str, user_id: str) -> dict[str, Any]:
        """The member's realtime connection dropped. The match clock keeps running; grace starts now."""
        room = self._room(code)
        with room.lock:
            self._advance(room)
            player = self._member(room, user_id)
            if player.connected and room.state not in TERMINAL_STATES:
                player.connected = False
                player.disconnected_at = self._clock()
                opponent = room.opponent(user_id)
                if opponent is not None:
                    self._emit(room, "opponent_disconnected", {"user_id": user_id, "grace_ends_at": player.disconnected_at + self._grace_ms(room)}, to=opponent.user_id)
            else:
                player.connected = False
            return self._view(room, user_id)

    def retire(self, code: str, user_id: str) -> dict[str, Any]:
        room = self._room(code)
        with room.lock:
            self._advance(room)
            self._member(room, user_id)
            if room.state not in TERMINAL_STATES:
                self._abandon(room, user_id, "retired")
            return self._view(room, user_id)

    # ---- play --------------------------------------------------------------

    def state(self, code: str, user_id: str) -> dict[str, Any]:
        """Resync: the current authoritative room view, including the live round payload."""
        room = self._room(code)
        with room.lock:
            self._advance(room)
            self._member(room, user_id)
            return self._view(room, user_id)

    def tick(self, code: str) -> None:
        """Advance deadlines and grace periods with no client traffic."""
        room = self._room(code)
        with room.lock:
            self._advance(room)

    def submit_answer(self, code: str, user_id: str, round_number: int, choice: int) -> dict[str, Any]:
        room = self._room(code)
        with room.lock:
            now = self._clock()
            self._member(room, user_id)
            live = room.current
            late = live is not None and live.number == round_number and not live.resolved and now >= live.ends_at
            self._advance(room)
            if room.state in TERMINAL_STATES:
                raise PvpError("room_closed", "This match is over")
            if late:
                raise PvpError("late", "The round deadline has passed")
            live = room.current
            if room.state not in (RoomState.ACTIVE, RoomState.ROUND_RESULT) or live is None or live.number != round_number:
                raise PvpError("wrong_round", "That round is not open")
            if live.resolved:
                raise PvpError("round_resolved", "That round is already decided")
            if user_id in live.submissions:
                raise PvpError("already_answered", "You already answered this round")
            if isinstance(choice, bool) or not isinstance(choice, int) or not 0 <= choice < len(live.order):
                raise PvpError("bad_choice", "Unknown option")
            correct = live.order[choice] == live.question.answer_index
            live.submissions[user_id] = Submission(choice=choice, correct=correct, at_ms=now)
            self._emit(room, "answer_locked", {"round": live.number, "option_index": choice, "correct": correct}, to=user_id)
            if correct:
                self._resolve(room, now, winner_id=user_id, reason="correct")
            elif len(live.submissions) == len(room.players()):
                self._resolve(room, now, winner_id=None, reason="both_wrong")
            return {"accepted": True, "correct": correct, "room": self._view(room, user_id)}

    # ---- transport support ----------------------------------------------------

    def room_codes(self) -> list[str]:
        with self._rooms_lock:
            return list(self._rooms)

    def drain_events(self, code: str) -> list[Event]:
        room = self._room(code)
        with room.lock:
            events, room.outbox = room.outbox, []
            return events

    def revision(self, code: str) -> int:
        room = self._room(code)
        with room.lock:
            return room.revision

    def cleanup(self) -> list[str]:
        """Close stale waiting rooms; forget rooms closed longer than the TTL. Returns removed codes."""
        now = self._clock()
        removed: list[str] = []
        for code in self.room_codes():
            try:
                room = self._room(code)
            except PvpError:
                continue
            with room.lock:
                self._advance(room)
                if room.state == RoomState.WAITING and now - room.created_at >= self.stale_waiting_ms:
                    self._abandon(room, None, "stale")
                if room.closed_at is not None and now - room.closed_at >= self.closed_ttl_ms:
                    removed.append(code)
        if removed:
            with self._rooms_lock:
                for code in removed:
                    self._rooms.pop(code, None)
        return removed

    # ---- internals -----------------------------------------------------------

    def _room(self, code: str) -> Room:
        with self._rooms_lock:
            room = self._rooms.get(str(code).strip().upper())
        if room is None:
            raise PvpError("room_not_found", "Room not found")
        return room

    @staticmethod
    def _member(room: Room, user_id: str) -> Player:
        player = room.player(user_id)
        if player is None:
            raise PvpError("not_in_room", "You are not in this room")
        return player

    def _grace_ms(self, room: Room) -> int:
        return self.waiting_grace_ms if room.state == RoomState.WAITING else self.active_grace_ms

    def _advance(self, room: Room) -> None:
        """Apply every deadline that has passed, anchored to server deadlines, never client time."""
        now = self._clock()
        while True:
            if room.state == RoomState.COUNTDOWN and now >= room.countdown_ends_at:
                self._open_round(room, room.countdown_ends_at)
            elif room.state == RoomState.ACTIVE and room.current is not None and now >= room.current.ends_at:
                self._resolve(room, room.current.ends_at, winner_id=None, reason="timeout")
            elif room.state == RoomState.ROUND_RESULT and now >= room.result_ends_at:
                room.round_number += 1
                room.countdown_ends_at = room.result_ends_at + COUNTDOWN_MS
                room.state = RoomState.COUNTDOWN
                self._emit(room, "countdown_started", {"round": room.round_number, "countdown_ends_at": room.countdown_ends_at})
            else:
                break
        if room.state in TERMINAL_STATES:
            return
        grace = self._grace_ms(room)
        for player in room.players():
            if not player.connected and player.disconnected_at is not None and now >= player.disconnected_at + grace:
                self._abandon(room, player.user_id, "forfeit")
                return

    def _open_round(self, room: Room, started_at: int) -> None:
        if room.cursor >= len(room.deck):
            self._refill(room)
        question = self._bank[room.deck[room.cursor]]
        room.cursor += 1
        room.last_question_id = question.id
        room.questions_selected += 1
        order = list(range(len(question.options)))
        room.rng.shuffle(order)
        room.current = Round(
            number=room.round_number,
            question=question,
            order=order,
            started_at=started_at,
            ends_at=started_at + ROUND_MS,
        )
        room.state = RoomState.ACTIVE
        self._emit(room, "round_started", self.round_payload(room.current))

    def _refill(self, room: Room) -> None:
        ids = sorted(self._bank)
        room.rng.shuffle(ids)
        if len(ids) > 1 and ids[0] == room.last_question_id:
            ids[0], ids[1] = ids[1], ids[0]
        room.deck = ids
        room.cursor = 0

    def _resolve(self, room: Room, at_ms: int, winner_id: str | None, reason: str) -> None:
        live = room.current
        if live is None or live.resolved:
            return
        live.resolved = True
        live.winner_id = winner_id
        if winner_id is not None:
            loser = room.opponent(winner_id)
            if loser is not None:
                loser.hp = max(0, loser.hp - DAMAGE_HIT)
                live.damage[loser.user_id] = DAMAGE_HIT
        room.result_ends_at = at_ms + RESULT_MS
        knocked_out = any(player.hp <= 0 for player in room.players())
        room.state = RoomState.FINISHED if knocked_out else RoomState.ROUND_RESULT
        self._emit(room, "round_result", {
            "round": live.number,
            "winner_id": winner_id,
            "reason": reason,
            "damage": dict(live.damage),
            "hp": self._hp(room),
            "correct_option": live.correct_position(),
            "result_ends_at": room.result_ends_at,
        })
        if knocked_out:
            room.winner_id = winner_id
            self._close(room, "ko")

    def _abandon(self, room: Room, leaver_id: str | None, reason: str) -> None:
        started = room.state != RoomState.WAITING
        opponent = room.opponent(leaver_id) if leaver_id is not None else None
        room.retired_by = leaver_id
        room.winner_id = opponent.user_id if started and opponent is not None else None
        room.state = RoomState.ABANDONED
        self._close(room, reason)

    def _close(self, room: Room, reason: str) -> None:
        room.finish_reason = reason
        room.closed_at = self._clock()
        self._emit(room, "match_finished", {
            "state": room.state.value,
            "reason": reason,
            "winner_id": room.winner_id,
            "retired_by": room.retired_by,
            "hp": self._hp(room),
        })

    def _emit(self, room: Room, kind: str, data: dict[str, Any], to: str | None = None) -> None:
        room.revision += 1
        payload = {"type": kind, "revision": room.revision, "code": room.code, "server_now": self._clock()}
        payload.update({key: value for key, value in data.items() if key not in payload})
        room.outbox.append(Event(to=to, payload=payload))

    def _emit_states(self, room: Room) -> None:
        for player in room.players():
            self._emit(room, "room_state", self._view(room, player.user_id), to=player.user_id)

    @staticmethod
    def _hp(room: Room) -> dict[str, int]:
        return {player.user_id: player.hp for player in room.players()}

    @staticmethod
    def round_payload(live: Round) -> dict[str, Any]:
        return {
            "round": live.number,
            "question_id": live.question.id,
            "question": live.question.question,
            "options": [live.question.options[index] for index in live.order],
            "started_at": live.started_at,
            "ends_at": live.ends_at,
        }

    def _view(self, room: Room, user_id: str) -> dict[str, Any]:
        view: dict[str, Any] = {
            "code": room.code,
            "state": room.state.value,
            "host_id": room.host.user_id,
            "guest_id": room.guest.user_id if room.guest else None,
            "ready": {player.user_id: player.ready for player in room.players()},
            "connected": {player.user_id: player.connected for player in room.players()},
            "hp": self._hp(room),
            "round_number": room.round_number,
            "countdown_ends_at": room.countdown_ends_at if room.state == RoomState.COUNTDOWN else None,
            "round": None,
            "result": None,
            "winner_id": room.winner_id,
            "retired_by": room.retired_by,
            "finish_reason": room.finish_reason,
            "revision": room.revision,
            "server_now": self._clock(),
        }
        live = room.current
        if live is None:
            return view
        view["round"] = self.round_payload(live)
        mine = live.submissions.get(user_id)
        view["you_answered"] = mine is not None
        if live.resolved:
            view["result"] = {
                "round": live.number,
                "winner_id": live.winner_id,
                "damage": dict(live.damage),
                "correct_option": live.correct_position(),
            }
        return view
