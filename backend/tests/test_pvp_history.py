"""Phase 4A: persistent online PvP match history and derived per-student stats."""
import asyncio
import sys
import types
import unittest
import uuid
from dataclasses import replace
from pathlib import Path
from typing import Any
from unittest.mock import patch

if "app.supabase_client" not in sys.modules:
    stub = types.ModuleType("app.supabase_client")
    stub.supabase = object()
    sys.modules["app.supabase_client"] = stub

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.routes.pvp import router
from app.services import pvp_history
from app.services.pvp_history import MatchRecorder, match_row, summarize
from app.services.pvp_hub import PvpHub
from app.services.pvp_service import COUNTDOWN_MS, MAX_HP, RESULT_MS, ROUND_MS, DAMAGE_HIT, PvpService

try:
    from tests.test_pvp_realtime import Clock, auth, fixture_bank
except ModuleNotFoundError:
    from test_pvp_realtime import Clock, auth, fixture_bank

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "backend" / "app"
GRACE_MS = 15_000
WAITING_GRACE_MS = 60_000
KO_HITS = MAX_HP // DAMAGE_HIT


def student() -> str:
    return str(uuid.uuid4())


class FakeQuery:
    def __init__(self, db: "FakeDb", table: str) -> None:
        self.db, self.table_name = db, table
        self.filters: list[tuple[str, str]] = []
        self.equals: list[tuple[str, str]] = []
        self.order_key: tuple[str, bool] | None = None
        self.bounds: tuple[int, int] | None = None
        self.cap: int | None = None
        self.op = "select"
        self.payload: dict[str, Any] | None = None
        self.ignore = False

    def select(self, _columns: str) -> "FakeQuery":
        return self

    def or_(self, expression: str) -> "FakeQuery":
        for part in expression.split(","):
            column, _eq, value = part.split(".", 2)
            self.filters.append((column, value))
        return self

    def eq(self, column: str, value: str) -> "FakeQuery":
        self.equals.append((column, value))
        return self

    def order(self, column: str, desc: bool = False) -> "FakeQuery":
        self.order_key = (column, desc)
        return self

    def range(self, start: int, end: int) -> "FakeQuery":
        self.bounds = (start, end)
        return self

    def limit(self, count: int) -> "FakeQuery":
        self.cap = count
        return self

    def upsert(self, row: dict[str, Any], on_conflict: str = "", ignore_duplicates: bool = False) -> "FakeQuery":
        self.op, self.payload, self.ignore = "upsert", dict(row), ignore_duplicates
        self.db.conflict_keys.add(on_conflict)
        return self

    def execute(self) -> Any:
        self.db.touched.append((self.table_name, self.op))
        if self.db.fail:
            raise RuntimeError("database down")
        rows = self.db.tables.setdefault(self.table_name, {})
        if self.op == "upsert":
            key = self.payload["match_id"]
            if key not in rows or not self.ignore:
                rows[key] = self.payload
            return types.SimpleNamespace(data=[])
        found = [row for row in rows.values() if not self.filters or any(row.get(column) == value for column, value in self.filters)]
        found = [row for row in found if all(row.get(column) == value for column, value in self.equals)]
        if self.order_key:
            found.sort(key=lambda row: str(row.get(self.order_key[0])), reverse=self.order_key[1])
        if self.bounds:
            found = found[self.bounds[0]:self.bounds[1] + 1]
        if self.cap is not None:
            found = found[:self.cap]
        return types.SimpleNamespace(data=[dict(row) for row in found])


class FakeDb:
    def __init__(self) -> None:
        self.tables: dict[str, dict[str, dict[str, Any]]] = {}
        self.touched: list[tuple[str, str]] = []
        self.conflict_keys: set[str] = set()
        self.fail = False

    def table(self, name: str) -> FakeQuery:
        return FakeQuery(self, name)

    def rpc(self, name: str, _params: dict[str, Any]) -> Any:
        self.touched.append((name, "rpc"))
        raise AssertionError("PvP history must not call RPCs")

    @property
    def matches(self) -> dict[str, dict[str, Any]]:
        return self.tables.get("pvp_matches", {})


class MatchDriver:
    """Drives the authoritative service directly with a fake clock."""

    def __init__(self) -> None:
        self.clock = Clock()
        self.service = PvpService(bank=fixture_bank(), clock=self.clock, seed=7, active_grace_ms=GRACE_MS, waiting_grace_ms=WAITING_GRACE_MS)
        self.host, self.guest = student(), student()

    def private_room(self) -> str:
        code = self.service.create_room(self.host)["code"]
        self.service.join_room(code, self.guest)
        return code

    def matchmade_room(self) -> str:
        self.service.join_queue(self.host)
        code = self.service.join_queue(self.guest)["room_code"]
        self.service.connect(code, self.host)
        self.service.connect(code, self.guest)
        return code

    def start(self, code: str) -> None:
        self.service.set_ready(code, self.host)
        self.service.set_ready(code, self.guest)
        self.clock.now += COUNTDOWN_MS
        self.service.tick(code)

    def correct_choice(self, code: str) -> int:
        return self.service._room(code).current.correct_position()

    def next_round(self, code: str) -> None:
        self.clock.now += RESULT_MS + COUNTDOWN_MS
        self.service.tick(code)

    def win_round(self, code: str, winner: str, loser_wrong: bool = False) -> None:
        number = self.service._room(code).current.number
        if loser_wrong:
            loser = self.guest if winner == self.host else self.host
            self.service.submit_answer(code, loser, number, (self.correct_choice(code) + 1) % 4)
        self.service.submit_answer(code, winner, number, self.correct_choice(code))

    def timeout_round(self, code: str) -> None:
        self.clock.now += ROUND_MS
        self.service.tick(code)

    def play_to_ko(self, code: str) -> None:
        self.start(code)
        self.win_round(code, self.guest)                  # host 80
        self.next_round(code)
        self.timeout_round(code)                          # no damage, both time out
        self.next_round(code)
        for hit in range(KO_HITS):
            self.win_round(code, self.host, loser_wrong=hit == 0)
            if hit < KO_HITS - 1:
                self.next_round(code)

    def churn(self, code: str) -> None:
        """Everything that could plausibly re-finalize a closed room."""
        for user in (self.host, self.guest):
            self.service.retire(code, user)
            self.service.state(code, user)
            self.service.disconnect(code, user)
            self.service.connect(code, user)
        for _ in range(3):
            self.service.tick(code)
            self.clock.now += 1_000
            self.service.cleanup()


class RecordedOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.d = MatchDriver()

    def test_ko_is_recorded_once_with_authoritative_numbers(self):
        code = self.d.private_room()
        self.d.play_to_ko(code)
        records = self.d.service.drain_records()
        self.assertEqual(len(records), 1)
        record = records[0]
        self.assertEqual(record.finish_reason, "ko")
        self.assertEqual(record.winner_id, self.d.host)
        self.assertIsNone(record.forfeited_by)
        self.assertEqual((record.player1.user_id, record.player2.user_id), (self.d.host, self.d.guest))
        self.assertEqual((record.player1.hp, record.player2.hp), (MAX_HP - DAMAGE_HIT, 0))
        self.assertEqual(record.rounds_played, 2 + KO_HITS)
        self.assertEqual((record.player1.correct, record.player1.wrong, record.player1.timeouts), (KO_HITS, 0, 1))
        self.assertEqual((record.player2.correct, record.player2.wrong, record.player2.timeouts), (1, 1, 1))
        self.assertIsNotNone(record.started_at)
        self.assertGreaterEqual(record.finished_at, record.started_at)
        self.d.churn(code)
        self.assertEqual(self.d.service.drain_records(), [])

    def test_disconnect_forfeit_is_recorded_once(self):
        code = self.d.private_room()
        self.d.start(code)
        self.d.win_round(code, self.d.host)
        self.d.service.disconnect(code, self.d.guest)
        self.d.clock.now += GRACE_MS
        self.d.service.tick(code)
        records = self.d.service.drain_records()
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0].finish_reason, "forfeit_disconnect")
        self.assertEqual(records[0].forfeited_by, self.d.guest)
        self.assertEqual(records[0].winner_id, self.d.host)
        self.assertEqual(records[0].rounds_played, 1)
        self.d.churn(code)
        self.assertEqual(self.d.service.drain_records(), [])

    def test_leave_forfeit_is_recorded_once(self):
        code = self.d.private_room()
        self.d.start(code)
        self.d.service.retire(code, self.d.host)
        self.d.service.retire(code, self.d.host)
        records = self.d.service.drain_records()
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0].finish_reason, "forfeit_leave")
        self.assertEqual(records[0].forfeited_by, self.d.host)
        self.assertEqual(records[0].winner_id, self.d.guest)
        self.assertEqual(records[0].rounds_played, 0)
        self.d.churn(code)
        self.assertEqual(self.d.service.drain_records(), [])

    def test_leaving_during_the_first_countdown_is_a_forfeit_not_an_abandon(self):
        code = self.d.private_room()
        self.d.service.set_ready(code, self.d.host)
        self.d.service.set_ready(code, self.d.guest)
        self.d.service.retire(code, self.d.guest)
        record = self.d.service.drain_records()[0]
        self.assertEqual((record.finish_reason, record.winner_id, record.rounds_played), ("forfeit_leave", self.d.host, 0))

    def test_abandoned_before_start(self):
        lobby_leave = self.d.private_room()
        self.d.service.retire(lobby_leave, self.d.guest)
        [record] = self.d.service.drain_records()
        self.assertEqual(record.finish_reason, "abandoned_before_start")
        self.assertIsNone(record.winner_id)
        self.assertIsNone(record.forfeited_by)
        self.assertIsNone(record.started_at)
        self.assertEqual(record.rounds_played, 0)

        lonely = MatchDriver()
        code = lonely.service.create_room(lonely.host)["code"]
        lonely.service.retire(code, lonely.host)
        stale = lonely.service.create_room(lonely.host)["code"]
        lonely.clock.now += 11 * 60_000
        lonely.service.cleanup()
        self.assertEqual(lonely.service.drain_records(), [], "a room nobody joined is not a match")

        noshow = MatchDriver()
        noshow.service.join_queue(noshow.host)
        matched = noshow.service.join_queue(noshow.guest)["room_code"]
        noshow.service.connect(matched, noshow.host)
        noshow.clock.now += WAITING_GRACE_MS
        noshow.service.tick(matched)
        [record] = noshow.service.drain_records()
        self.assertEqual((record.origin, record.finish_reason, record.winner_id), ("matchmaking", "abandoned_before_start", None))
        noshow.churn(matched)
        self.assertEqual(noshow.service.drain_records(), [])
        self.assertTrue(stale)

    def test_origins_are_stored(self):
        private = self.d.private_room()
        self.d.service.retire(private, self.d.guest)
        matchmade = self.d.matchmade_room()
        self.d.start(matchmade)
        self.d.service.retire(matchmade, self.d.guest)
        origins = [record.origin for record in self.d.service.drain_records()]
        self.assertEqual(origins, ["private", "matchmaking"])

    def test_match_ids_are_unique_even_when_room_codes_repeat(self):
        clock = Clock()
        service = PvpService(bank=fixture_bank(), clock=clock, code_factory=lambda: "SAMEAA")
        host, guest = student(), student()
        ids = []
        for _ in range(3):
            code = service.create_room(host)["code"]
            service.join_room(code, guest)
            service.retire(code, guest)
            clock.now += 120_000
            service.cleanup()
            ids += [record.match_id for record in service.drain_records()]
        self.assertEqual(len(ids), 3)
        self.assertEqual(len(set(ids)), 3)


class PersistenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = FakeDb()
        patcher = patch.object(pvp_history, "supabase", self.db)
        patcher.start()
        self.addCleanup(patcher.stop)

    def finished_record(self, origin: str = "private"):
        d = MatchDriver()
        code = d.private_room() if origin == "private" else d.matchmade_room()
        d.play_to_ko(code)
        return d, d.service.drain_records()[0]

    def test_duplicate_finalization_never_duplicates_rows(self):
        d, record = self.finished_record()
        first = MatchRecorder()
        first.add([record])
        first.add([record])
        self.assertEqual(first.pending, 1)
        first.flush()
        second = MatchRecorder()
        second.add([record])
        second.flush()
        pvp_history.insert_match(match_row(record))
        self.assertEqual(len(self.db.matches), 1)
        self.assertEqual(self.db.conflict_keys, {"match_id"})

    def test_lost_acknowledgement_retry_is_harmless(self):
        _d, record = self.finished_record()
        calls = []

        def write_then_lose_reply(row):
            pvp_history.insert_match(row)
            calls.append(1)
            if len(calls) == 1:
                raise TimeoutError("reply lost")

        now = [0.0]
        recorder = MatchRecorder(writer=write_then_lose_reply, clock=lambda: now[0])
        recorder.add([record])
        self.assertEqual(recorder.flush(), 0)
        self.assertEqual(recorder.pending, 1)
        now[0] += recorder.retry_delay(1)
        self.assertEqual(recorder.flush(), 1)
        self.assertEqual(recorder.pending, 0)
        self.assertEqual(len(self.db.matches), 1)

    def test_outage_keeps_the_match_pending_with_capped_backoff(self):
        _d, record = self.finished_record()
        now = [0.0]
        recorder = MatchRecorder(clock=lambda: now[0], base_seconds=1.0, max_seconds=60.0)
        recorder.add([record])
        self.db.fail = True
        attempts_at: list[float] = []
        with self.assertLogs("app.services.pvp_history", level="WARNING"):
            while now[0] < 6 * 3600:
                before = len(self.db.touched)
                recorder.flush()
                if len(self.db.touched) > before:
                    attempts_at.append(now[0])
                now[0] += 0.5
        self.assertEqual(recorder.pending, 1, "a finished match is never dropped while the process lives")
        gaps = [later - earlier for earlier, later in zip(attempts_at, attempts_at[1:])]
        self.assertEqual(gaps[:6], [1.0, 2.0, 4.0, 8.0, 16.0, 32.0])
        self.assertEqual(max(gaps), 60.0)
        self.assertLess(len(attempts_at), 400, "backoff, not a hot retry loop")
        self.db.fail = False
        now[0] += 60.0
        self.assertEqual(recorder.flush(), 1)
        self.assertEqual(recorder.pending, 0)
        self.assertEqual(len(self.db.matches), 1)

    def test_one_failing_match_does_not_hold_back_others(self):
        _d, stuck = self.finished_record()
        _e, healthy = self.finished_record()

        def writer(row):
            if row["match_id"] == stuck.match_id:
                raise TimeoutError("slow")
            pvp_history.insert_match(row)

        recorder = MatchRecorder(writer=writer)
        recorder.add([stuck, healthy])
        self.assertEqual(recorder.flush(), 1)
        self.assertEqual(set(self.db.matches), {healthy.match_id})
        self.assertEqual(recorder.pending, 1)

    def test_exact_duplicate_delivery_is_harmless(self):
        _d, record = self.finished_record()
        for _ in range(3):
            recorder = MatchRecorder()
            recorder.add([record])
            self.assertEqual(recorder.flush(), 1)
            self.assertEqual(recorder.conflicts, 0)
        self.assertEqual(len(self.db.matches), 1)

    def test_postgres_timestamp_spelling_is_not_a_conflict(self):
        _d, record = self.finished_record()
        row = match_row(record)
        stored = dict(row, finished_at=row["finished_at"].replace("+00:00", "Z"))
        self.assertEqual(pvp_history.conflicting_columns(stored, row), [])

    def test_conflicting_result_for_the_same_match_id_is_detected_not_overwritten(self):
        d, record = self.finished_record()
        recorder = MatchRecorder()
        recorder.add([record])
        recorder.flush()
        original = dict(self.db.matches[record.match_id])
        forged = replace(record, winner_id=d.guest, player1=replace(record.player1, hp=0), player2=replace(record.player2, hp=100))
        second = MatchRecorder()
        second.add([forged])
        with self.assertLogs("app.services.pvp_history", level="ERROR") as logs:
            self.assertEqual(second.flush(), 0)
        self.assertEqual(second.conflicts, 1)
        self.assertEqual(second.pending, 0, "retrying cannot fix a conflicting result")
        self.assertEqual(self.db.matches[record.match_id], original, "the stored result is untouched")
        self.assertIn("integrity conflict", logs.output[0])
        self.assertIn("winner_id", logs.output[0])
        with self.assertRaises(pvp_history.MatchConflict):
            pvp_history.insert_match(match_row(forged))

    def test_row_matches_the_authoritative_record(self):
        d, record = self.finished_record("matchmaking")
        recorder = MatchRecorder()
        recorder.add([record])
        recorder.flush()
        row = self.db.matches[record.match_id]
        self.assertEqual(row["origin"], "matchmaking")
        self.assertEqual(row["finish_reason"], "ko")
        self.assertEqual((row["player1_id"], row["player2_id"], row["winner_id"]), (d.host, d.guest, d.host))
        self.assertEqual((row["player1_hp"], row["player2_hp"]), (MAX_HP - DAMAGE_HIT, 0))
        self.assertTrue(row["started_at"].endswith("+00:00") and row["finished_at"].endswith("+00:00"))

    def test_non_student_ids_are_never_written(self):
        clock = Clock()
        service = PvpService(bank=fixture_bank(), clock=clock)
        code = service.create_room("e2e-a-123")["code"]
        service.join_room(code, "e2e-b-123")
        service.retire(code, "e2e-b-123")
        recorder = MatchRecorder()
        recorder.add(service.drain_records())
        self.assertEqual(recorder.pending, 0)
        self.assertEqual(self.db.touched, [])

    def test_hub_persists_each_finished_match_once(self):
        d = MatchDriver()
        hub = PvpHub(d.service, recorder=MatchRecorder())
        code = d.private_room()
        d.play_to_ko(code)
        d.churn(code)

        async def scenario() -> None:
            for _ in range(3):
                await hub.persist()
                hub.tick()
                hub.cleanup()

        asyncio.run(scenario())
        self.assertEqual(len(self.db.matches), 1)

    def test_pvp_never_touches_bkt_mastery_or_students(self):
        d = MatchDriver()
        hub = PvpHub(d.service, recorder=MatchRecorder())
        for build in (d.private_room, d.matchmade_room):
            code = build()
            d.play_to_ko(code)
            d.clock.now += 120_000
            d.service.cleanup()
        asyncio.run(hub.persist())
        self.assertEqual({table for table, _op in self.db.touched}, {"pvp_matches"})
        self.assertEqual(set(self.db.tables), {"pvp_matches"})
        source = (APP / "services" / "pvp_history.py").read_text(encoding="utf-8").lower()
        imports = [line for line in source.splitlines() if line.startswith(("import ", "from "))]
        for forbidden in ("bkt", "mastery", "progress", "assess", "pretest", "token", "reward", "elo"):
            self.assertFalse([line for line in imports if forbidden in line], f"pvp_history imports {forbidden}")
        for table in ("bkt_records", "students", "player_saves"):
            self.assertNotIn(f'"{table}"', source)


class StatsTest(unittest.TestCase):
    def test_wins_losses_draws_forfeits_and_rate(self):
        me, rival = student(), student()
        rows = [
            {"player1_id": me, "player2_id": rival, "winner_id": me, "forfeited_by": None, "finish_reason": "ko", "rounds_played": 7},
            {"player1_id": rival, "player2_id": me, "winner_id": me, "forfeited_by": rival, "finish_reason": "forfeit_leave", "rounds_played": 2},
            {"player1_id": me, "player2_id": rival, "winner_id": rival, "forfeited_by": me, "finish_reason": "forfeit_disconnect", "rounds_played": 3},
            {"player1_id": rival, "player2_id": me, "winner_id": rival, "forfeited_by": None, "finish_reason": "ko", "rounds_played": 5},
            {"player1_id": me, "player2_id": rival, "winner_id": None, "forfeited_by": None, "finish_reason": "ko", "rounds_played": 4},
            {"player1_id": me, "player2_id": rival, "winner_id": None, "forfeited_by": None, "finish_reason": "abandoned_before_start", "rounds_played": 0},
            {"player1_id": rival, "player2_id": student(), "winner_id": rival, "forfeited_by": None, "finish_reason": "ko", "rounds_played": 9},
        ]
        self.assertEqual(summarize(me, rows), {"matches_played": 5, "wins": 2, "losses": 2, "draws": 1, "forfeits": 1, "win_rate": 0.4, "rounds_played": 21})
        self.assertEqual(summarize(student(), rows)["matches_played"], 0)
        self.assertEqual(summarize(student(), [])["win_rate"], 0.0)

    def test_summary_reads_past_the_page_cap(self):
        me, rival = student(), student()
        db = FakeDb()
        for index in range(pvp_history.PAGE_SIZE + 5):
            db.tables.setdefault("pvp_matches", {})[f"{index:08d}"] = {"match_id": f"{index:08d}", "player1_id": me, "player2_id": rival, "winner_id": me, "forfeited_by": None, "finish_reason": "ko", "rounds_played": 1}
        with patch.object(pvp_history, "supabase", db):
            summary = pvp_history.student_summary(me)
        self.assertEqual(summary["matches_played"], pvp_history.PAGE_SIZE + 5)


class HistoryApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = FakeDb()
        patcher = patch.object(pvp_history, "supabase", self.db)
        patcher.start()
        self.addCleanup(patcher.stop)
        app = FastAPI()
        app.include_router(router)
        app.state.pvp_hub = PvpHub(PvpService(bank=fixture_bank()))
        self.client = TestClient(app)
        self.d = MatchDriver()
        code = self.d.private_room()
        self.d.play_to_ko(code)
        recorder = MatchRecorder()
        recorder.add(self.d.service.drain_records())
        recorder.flush()

    def test_endpoints_require_a_student_jwt(self):
        for path in ("/api/pvp/me/summary", "/api/pvp/me/matches"):
            self.assertEqual(self.client.get(path).status_code, 401)
            self.assertEqual(self.client.get(path, headers={"Authorization": "Bearer nonsense"}).status_code, 401)

    def test_each_student_sees_their_own_side(self):
        host = self.client.get("/api/pvp/me/summary", headers=auth(self.d.host)).json()
        guest = self.client.get("/api/pvp/me/summary", headers=auth(self.d.guest)).json()
        self.assertEqual((host["wins"], host["losses"], host["matches_played"]), (1, 0, 1))
        self.assertEqual((guest["wins"], guest["losses"], guest["matches_played"]), (0, 1, 1))
        [mine] = self.client.get("/api/pvp/me/matches", headers=auth(self.d.guest)).json()["matches"]
        self.assertEqual((mine["result"], mine["my_hp"], mine["opponent_hp"], mine["correct"], mine["wrong"], mine["timeouts"]), ("loss", 0, MAX_HP - DAMAGE_HIT, 1, 1, 1))
        self.assertEqual(set(mine), {"match_id", "origin", "result", "finish_reason", "forfeited", "my_hp", "opponent_hp", "rounds_played", "correct", "wrong", "timeouts", "finished_at"})
        self.assertNotIn(self.d.host, str(mine), "the opponent's account id is not exposed")

    def test_another_student_cannot_read_someone_elses_history(self):
        outsider = student()
        for query in ("", f"?student_id={self.d.host}", f"?player_id={self.d.host}&user_id={self.d.host}"):
            matches = self.client.get(f"/api/pvp/me/matches{query}", headers=auth(outsider))
            self.assertEqual(matches.json(), {"matches": []})
            summary = self.client.get(f"/api/pvp/me/summary{query}", headers=auth(outsider)).json()
            self.assertEqual(summary["matches_played"], 0)
        self.assertEqual(self.client.get(f"/api/pvp/me/matches/{self.d.host}", headers=auth(outsider)).status_code, 404)

    def test_limit_is_bounded(self):
        self.assertEqual(self.client.get("/api/pvp/me/matches?limit=500", headers=auth(self.d.host)).status_code, 422)
        self.assertEqual(self.client.get("/api/pvp/me/matches?limit=0", headers=auth(self.d.host)).status_code, 422)

    def test_database_outage_is_a_safe_503(self):
        self.db.fail = True
        for path in ("/api/pvp/me/summary", "/api/pvp/me/matches"):
            response = self.client.get(path, headers=auth(self.d.host))
            self.assertEqual(response.status_code, 503)
            self.assertNotIn("database down", response.text)

    def test_no_route_accepts_a_client_reported_result(self):
        writable = [(route.path, sorted(route.methods)) for route in router.routes if getattr(route, "methods", None) and route.methods - {"GET", "HEAD"}]
        self.assertEqual(sorted(path for path, _ in writable), ["/api/pvp/matchmaking/cancel", "/api/pvp/matchmaking/join", "/api/pvp/rooms", "/api/pvp/rooms/{code}/join"])
        for path, methods in writable:
            self.assertNotIn("/me", path, f"{path} {methods} would let a client write history")


class BotPvpTest(unittest.TestCase):
    def test_local_bot_battle_never_reaches_the_online_backend(self):
        frontend = ROOT / "frontend" / "src"
        for path in (frontend / "gameplay" / "pvp" / "pvp_battle.gd", frontend / "ui" / "screens" / "pvp" / "pvp_battle_screen.gd"):
            source = path.read_text(encoding="utf-8")
            self.assertNotIn("/api/pvp", source, f"{path.name} must stay offline")
            self.assertNotIn("HTTPRequest", source, f"{path.name} must stay offline")
            self.assertNotIn("PvpOnlineSession", source, f"{path.name} must stay offline")


if __name__ == "__main__":
    unittest.main()
