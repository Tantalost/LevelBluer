"""Phase 4B: PvP Points orchestration, ranks and API (offline).

The SQL function is authoritative for the points maths, locking and ordering; FakeRatingDb mirrors its
rules so the Python queue can be tested here. tests/live_pvp_rating.py proves the real SQL in Supabase.
"""
import asyncio
import sys
import types
import unittest
import uuid
from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
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
from app.services import pvp_rating
from app.services.pvp_history import MatchRecorder, match_row
from app.services.pvp_hub import PvpHub
from app.services.pvp_rating import RatingQueue, history_blocker, is_rated_record, rank_for, standing
from app.services.pvp_service import PvpService

try:
    from tests.test_pvp_history import GRACE_MS, WAITING_GRACE_MS, MatchDriver, student
    from tests.test_pvp_realtime import auth, fixture_bank
except ModuleNotFoundError:
    from test_pvp_history import GRACE_MS, WAITING_GRACE_MS, MatchDriver, student
    from test_pvp_realtime import auth, fixture_bank

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "backend" / "app"
MIGRATION = ROOT / "backend" / "migrations" / "pvp_ratings.sql"
K = 32
RATED = ("ko", "forfeit_leave", "forfeit_disconnect")


def reference_delta(points_a: int, points_b: int, score_a: float) -> int:
    """Reference for the SQL formula: K*(score - expected), rounded half away from zero."""
    expected = Decimal(1) / (Decimal(1) + Decimal(10) ** (Decimal(points_b - points_a) / Decimal(400)))
    raw = Decimal(K) * (Decimal(str(score_a)) - expected)
    rounded = raw.copy_abs().quantize(Decimal(1), rounding=ROUND_HALF_UP)
    return int(rounded if raw >= 0 else -rounded)


def reference_apply(points_a: int, points_b: int, score_a: float) -> tuple[int, int]:
    delta = reference_delta(points_a, points_b, score_a)
    return max(0, points_a + delta), max(0, points_b - delta)


class FakeRatingDb:
    """Mirrors levelblue_apply_pvp_rating / levelblue_pvp_unrated_matches over in-memory rows."""

    def __init__(self, rated_from: datetime | None = None) -> None:
        self.rated_from = rated_from or datetime(1970, 1, 1, tzinfo=UTC)  # MatchDriver clocks start at the epoch
        self.matches: dict[str, dict[str, Any]] = {}
        self.ratings: dict[str, dict[str, int]] = {}
        self.events: dict[str, list[dict[str, Any]]] = {}
        self.calls: list[str] = []
        self.failures: dict[str, int] = {}

    def store(self, row: dict[str, Any]) -> None:
        self.matches.setdefault(row["match_id"], dict(row))

    def _rated(self, m: dict[str, Any]) -> bool:
        return (m["origin"] == "matchmaking" and m["started_at"] is not None and m["finish_reason"] in RATED
                and pvp_rating._instant(m["finished_at"]) >= self.rated_from)

    def _key(self, m: dict[str, Any]) -> tuple[datetime, str]:
        return pvp_rating._instant(m["finished_at"]), m["match_id"]

    def apply(self, match_id: str) -> dict[str, Any]:
        self.calls.append(match_id)
        if self.failures.get(match_id, 0) > 0:
            self.failures[match_id] -= 1
            raise TimeoutError("database unavailable")
        m = self.matches.get(match_id)
        if m is None:
            return {"status": "not_recorded"}
        if not self._rated(m):
            return {"status": "unrated"}
        a, b = m["player1_id"], m["player2_id"]
        if match_id in self.events:
            return {"status": "already_applied", "events": self.events[match_id]}
        for other in self.matches.values():
            if (other["match_id"] != match_id and {other["player1_id"], other["player2_id"]} & {a, b}
                    and self._rated(other) and self._key(other) < self._key(m) and other["match_id"] not in self.events):
                return {"status": "waiting_for_prior_match", "prior_match_id": other["match_id"]}
        ra = self.ratings.setdefault(a, {"points": 1000, "rated_matches": 0, "wins": 0, "losses": 0, "draws": 0})
        rb = self.ratings.setdefault(b, {"points": 1000, "rated_matches": 0, "wins": 0, "losses": 0, "draws": 0})
        score = 0.5 if m["winner_id"] is None else (1.0 if m["winner_id"] == a else 0.0)
        new_a, new_b = reference_apply(ra["points"], rb["points"], score)
        events = []
        for row, new, result, who, other_points in ((ra, new_a, score, a, rb["points"]), (rb, new_b, 1 - score, b, ra["points"])):
            label = "draw" if result == 0.5 else ("win" if result == 1 else "loss")
            events.append({"student_id": who, "result": label, "points_before": row["points"], "points_after": new, "points_delta": new - row["points"], "opponent_points_before": other_points})
            row["points"] = new
            row["rated_matches"] += 1
            row[{"win": "wins", "loss": "losses", "draw": "draws"}[label]] += 1
        self.events[match_id] = events
        return {"status": "applied", "events": events}

    def unrated(self, after_finished: str | None, after_id: str | None, limit: int) -> list[dict[str, Any]]:
        rows = sorted((m for m in self.matches.values() if self._rated(m) and m["match_id"] not in self.events), key=self._key)
        if after_finished is not None:
            cursor = (pvp_rating._instant(after_finished), after_id)
            rows = [m for m in rows if self._key(m) > cursor]
        return [{"match_id": m["match_id"], "player1_id": m["player1_id"], "player2_id": m["player2_id"], "finished_at": m["finished_at"]} for m in rows[:limit]]


def synthetic(a: str, b: str, winner: str | None, minute: int, origin: str = "matchmaking", reason: str = "ko") -> dict[str, Any]:
    finished = datetime(2026, 10, 12, 12, minute, tzinfo=UTC)
    return {"match_id": str(uuid.uuid4()), "origin": origin, "player1_id": a, "player2_id": b, "winner_id": winner,
            "finish_reason": reason, "started_at": None if reason == "abandoned_before_start" else (finished - timedelta(minutes=1)).isoformat(),
            "finished_at": finished.isoformat()}


class Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


class RankTest(unittest.TestCase):
    def test_every_boundary(self):
        cases = {0: "Bronze", 899: "Bronze", 900: "Silver", 1199: "Silver", 1200: "Gold", 1599: "Gold", 1600: "Platinum",
                 2099: "Platinum", 2100: "Diamond", 2699: "Diamond", 2700: "Grandmaster", 9999: "Grandmaster"}
        for points, rank in cases.items():
            self.assertEqual(rank_for(points), rank, points)

    def test_new_player_is_1000_silver(self):
        self.assertEqual(standing(None), {"points": 1000, "rank": "Silver", "current_threshold": 900, "next_rank": "Gold", "next_threshold": 1200,
                                          "points_to_next_rank": 200, "rated_matches": 0, "wins": 0, "losses": 0, "draws": 0})
        self.assertIn("initial_points integer     not null default 1000", MIGRATION.read_text(encoding="utf-8"))

    def test_standing_payload_and_grandmaster(self):
        self.assertEqual(standing({"points": 1048, "rated_matches": 18, "wins": 11, "losses": 7, "draws": 0}),
                         {"points": 1048, "rank": "Silver", "current_threshold": 900, "next_rank": "Gold", "next_threshold": 1200, "points_to_next_rank": 152,
                          "rated_matches": 18, "wins": 11, "losses": 7, "draws": 0})
        top = standing({"points": 2846, "rated_matches": 90, "wins": 70, "losses": 20, "draws": 0})
        self.assertEqual((top["rank"], top["next_rank"], top["next_threshold"], top["points_to_next_rank"]), ("Grandmaster", None, None, None))

    def test_current_threshold_brackets_points(self):
        for points in (0, 899, 900, 1048, 1199, 1200, 2099, 2100, 2699, 2700, 5000):
            row = standing({"points": points})
            self.assertLessEqual(row["current_threshold"], points)
            if row["next_threshold"] is not None:
                self.assertLess(points, row["next_threshold"])
                self.assertEqual(row["points_to_next_rank"], row["next_threshold"] - points)

    def test_promotion_and_demotion_follow_points(self):
        self.assertEqual((rank_for(1195), rank_for(1195 + 16)), ("Silver", "Gold"))
        self.assertEqual((rank_for(1203), rank_for(1203 - 16)), ("Gold", "Silver"))
        self.assertEqual((rank_for(2690), rank_for(2711)), ("Diamond", "Grandmaster"))
        self.assertEqual((rank_for(905), rank_for(889)), ("Silver", "Bronze"))


class ReferenceFormulaTest(unittest.TestCase):
    """The reference the live suite compares the real SQL results against."""

    def test_equal_points_move_sixteen(self):
        self.assertEqual(reference_apply(1000, 1000, 1), (1016, 984))
        self.assertEqual(reference_apply(1000, 1000, 0), (984, 1016))
        self.assertEqual(reference_apply(1000, 1000, 0.5), (1000, 1000))

    def test_unequal_points(self):
        self.assertEqual(reference_delta(1200, 1000, 1), 8)     # favourite wins: small gain
        self.assertEqual(reference_delta(1000, 1200, 1), 24)    # underdog wins: large gain
        self.assertEqual(reference_delta(1400, 1000, 0), -29)
        self.assertEqual(reference_delta(1000, 1400, 0.5), 13)

    def test_floor_is_zero_and_may_break_zero_sum(self):
        self.assertEqual(reference_apply(5, 5, 0), (0, 21))
        self.assertEqual(reference_apply(0, 0, 0), (0, 16))


class EligibilityTest(unittest.TestCase):
    def setUp(self) -> None:
        self.d = MatchDriver()

    def test_explicit_rated_rule(self):
        code = self.d.matchmade_room()
        self.d.play_to_ko(code)
        [record] = self.d.service.drain_records()
        self.assertTrue(is_rated_record(record))
        from dataclasses import replace
        self.assertFalse(is_rated_record(replace(record, origin="private")))
        self.assertFalse(is_rated_record(replace(record, started_at=None)))
        self.assertFalse(is_rated_record(replace(record, finish_reason="abandoned_before_start")))
        self.assertFalse(is_rated_record(replace(record, finish_reason="stale")))
        self.assertFalse(is_rated_record(replace(record, finish_reason="something_new")))
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("m.finish_reason in ('ko', 'forfeit_leave', 'forfeit_disconnect')", sql)
        self.assertIn("m.started_at is not null", sql)
        self.assertIn("m.finished_at >= cutoff", sql)


class PipelineTest(unittest.TestCase):
    """Real PvpService -> history recorder -> rating queue -> FakeRatingDb."""

    def setUp(self) -> None:
        self.db = FakeRatingDb()
        self.history_fail = 0
        self.clock = Clock()
        self.recorder = MatchRecorder(writer=self.write_history, clock=self.clock)
        self.queue = RatingQueue(apply=self.db.apply, unrated=self.db.unrated, clock=self.clock, history_blocked=history_blocker(self.recorder))
        self.recorder.on_stored = self.queue.add
        self.queue.recover()

    def write_history(self, row: dict[str, Any]) -> None:
        if self.history_fail > 0:
            self.history_fail -= 1
            raise TimeoutError("history down")
        self.db.store(row)

    def finish(self, driver: MatchDriver) -> None:
        self.recorder.add(driver.service.drain_records())
        self.recorder.flush()
        self.queue.flush()

    def test_matchmaking_ko_is_rated(self):
        d = MatchDriver()
        d.play_to_ko(d.matchmade_room())
        self.finish(d)
        self.assertEqual(self.db.ratings[d.host]["points"], 1016)
        self.assertEqual(self.db.ratings[d.guest]["points"], 984)
        self.assertEqual(len(next(iter(self.db.events.values()))), 2)

    def test_matchmaking_leave_forfeit_is_rated(self):
        d = MatchDriver()
        code = d.matchmade_room()
        d.start(code)
        d.service.retire(code, d.guest)
        self.finish(d)
        self.assertEqual((self.db.ratings[d.host]["wins"], self.db.ratings[d.guest]["losses"]), (1, 1))

    def test_matchmaking_disconnect_forfeit_is_rated(self):
        d = MatchDriver()
        code = d.matchmade_room()
        d.start(code)
        d.service.disconnect(code, d.host)
        d.clock.now += GRACE_MS
        d.service.tick(code)
        self.finish(d)
        self.assertEqual((self.db.ratings[d.guest]["points"], self.db.ratings[d.host]["points"]), (1016, 984))

    def test_private_and_abandoned_matches_are_never_sent_for_rating(self):
        d = MatchDriver()
        d.play_to_ko(d.private_room())
        noshow = MatchDriver()
        noshow.service.join_queue(noshow.host)
        code = noshow.service.join_queue(noshow.guest)["room_code"]
        noshow.service.connect(code, noshow.host)
        noshow.clock.now += WAITING_GRACE_MS
        noshow.service.tick(code)
        lobby = MatchDriver()
        lobby_code = lobby.matchmade_room()
        lobby.service.retire(lobby_code, lobby.guest)
        for driver in (d, noshow, lobby):
            self.finish(driver)
        self.assertEqual(len(self.db.matches), 3, "all three still have history rows")
        self.assertEqual(self.db.calls, [])
        self.assertEqual(self.db.ratings, {})

    def test_rating_waits_for_the_history_row(self):
        d = MatchDriver()
        d.play_to_ko(d.matchmade_room())
        self.history_fail = 1
        self.finish(d)
        self.assertEqual((self.queue.pending, self.db.calls), (0, []), "nothing is rated before history is stored")
        self.clock.now += 1
        self.recorder.flush()
        self.queue.flush()
        self.assertEqual(len(self.db.events), 1)

    def test_duplicate_processing_applies_once(self):
        d = MatchDriver()
        d.play_to_ko(d.matchmade_room())
        self.finish(d)
        [match_id] = list(self.db.events)
        before = dict(self.db.ratings[d.host])
        for _ in range(3):
            self.assertEqual(self.db.apply(match_id)["status"], "already_applied")
        replay = RatingQueue(apply=self.db.apply, unrated=self.db.unrated, clock=self.clock)
        replay._enqueue(match_id, frozenset({d.host, d.guest}), datetime.now(UTC))
        self.assertEqual(replay.flush(), 0)
        self.assertEqual(replay.pending, 0)
        self.assertEqual(self.db.ratings[d.host], before)
        self.assertEqual(len(self.db.events[match_id]), 2)


class OrderingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = FakeRatingDb()
        self.clock = Clock()
        self.a, self.b, self.c, self.e = student(), student(), student(), student()

    def queue(self) -> RatingQueue:
        q = RatingQueue(apply=self.db.apply, unrated=self.db.unrated, clock=self.clock)
        self.assertTrue(q.recover())
        return q

    def test_later_match_never_overtakes_a_failing_earlier_one(self):
        first = synthetic(self.a, self.b, self.a, minute=1)
        second = synthetic(self.a, self.c, self.c, minute=2)
        self.db.store(first)
        self.db.failures[first["match_id"]] = 3
        q = self.queue()
        self.db.store(second)
        q._enqueue(second["match_id"], frozenset({self.a, self.c}), pvp_rating._instant(second["finished_at"]))
        for _ in range(3):
            q.flush()
            self.assertNotIn(second["match_id"], self.db.events, "match 2 must not be rated before match 1")
            self.assertNotIn(second["match_id"], self.db.calls, "the queue does not even try match 2 while match 1 is pending")
            self.clock.now += 1000
        self.assertEqual(self.db.apply(second["match_id"])["status"], "waiting_for_prior_match", "the database refuses too")
        self.db.calls.clear()
        q.flush()
        self.assertEqual(self.db.calls, [first["match_id"], second["match_id"]])
        a_after_first = self.db.events[first["match_id"]][0]["points_after"]
        a_second = next(e for e in self.db.events[second["match_id"]] if e["student_id"] == self.a)
        self.assertEqual(a_after_first, 1016)
        self.assertEqual(a_second["points_before"], a_after_first, "match 2 uses match 1's resulting points")
        self.assertEqual(a_second["points_after"], reference_apply(1016, 1000, 0)[0])
        self.assertEqual(q.pending, 0)

    def test_restart_recovery_rates_oldest_first(self):
        rows = [synthetic(self.a, self.b, self.a, minute=3), synthetic(self.a, self.b, self.b, minute=1), synthetic(self.b, self.a, self.a, minute=2)]
        for row in rows:
            self.db.store(row)
        old_process = RatingQueue(apply=self.db.apply, unrated=self.db.unrated, clock=self.clock)
        self.db.failures = {row["match_id"]: 1 for row in rows}
        old_process.recover()
        old_process.flush()
        self.assertEqual(self.db.events, {})
        del old_process  # restart: in-memory jobs are gone
        self.db.failures.clear()
        self.db.calls.clear()
        fresh = self.queue()
        self.assertEqual(fresh.pending, 3)
        fresh.flush()
        expected_order = [row["match_id"] for row in sorted(rows, key=lambda r: r["finished_at"])]
        self.assertEqual(self.db.calls, expected_order)
        chain = [next(e for e in self.db.events[mid] if e["student_id"] == self.a) for mid in expected_order]
        for earlier, later in zip(chain, chain[1:]):
            self.assertEqual(later["points_before"], earlier["points_after"])

    def test_recovery_pages_through_everything(self):
        for minute in range(5):
            for second in range(50):
                row = synthetic(student(), student(), None, minute=minute)
                row["finished_at"] = (datetime(2026, 10, 12, 12, minute, second, tzinfo=UTC)).isoformat()
                self.db.store(row)
        q = self.queue()
        self.assertEqual(q.pending, 250)

    def test_recovery_failure_retries_with_backoff(self):
        calls = []

        def broken(*_args: Any) -> list[dict[str, Any]]:
            calls.append(self.clock.now)
            raise ConnectionError("down")

        q = RatingQueue(apply=self.db.apply, unrated=broken, clock=self.clock)
        for _ in range(10):
            q.recover()
            self.clock.now += 0.5
        self.assertFalse(q.recovered)
        self.assertEqual(calls, [0.0, 1.0, 3.0])

    def test_independent_players_are_not_blocked(self):
        stuck = synthetic(self.a, self.b, self.a, minute=1)
        free = synthetic(self.c, self.e, self.c, minute=2)
        for row in (stuck, free):
            self.db.store(row)
        self.db.failures[stuck["match_id"]] = 5
        q = self.queue()
        q.flush()
        self.assertIn(free["match_id"], self.db.events)
        self.assertNotIn(stuck["match_id"], self.db.events)

    def test_pending_history_of_an_older_match_blocks_a_later_one(self):
        d = MatchDriver()
        d.play_to_ko(d.matchmade_room())
        def history_down(_row: dict[str, Any]) -> None:
            raise TimeoutError("history down")

        recorder = MatchRecorder(writer=history_down, clock=self.clock)
        recorder.add(d.service.drain_records())
        recorder.flush()
        later = synthetic(d.host, self.c, d.host, minute=59)
        later["finished_at"] = (datetime.now(UTC) + timedelta(hours=1)).isoformat()
        self.db.store(later)
        q = RatingQueue(apply=self.db.apply, unrated=self.db.unrated, clock=self.clock, history_blocked=history_blocker(recorder))
        q.recover()
        q.flush()
        self.assertEqual(self.db.calls, [], "the later match waits for the older match's history row")

    def test_waiting_retries_on_a_short_fixed_interval(self):
        statuses = iter(["waiting_for_prior_match"] * 6 + ["applied"])
        calls = []

        def apply(match_id: str) -> dict[str, Any]:
            calls.append(self.clock.now)
            return {"status": next(statuses)}

        q = RatingQueue(apply=apply, unrated=lambda *_: [], clock=self.clock, wait_seconds=2.0)
        q.recover()
        q._enqueue("m", frozenset({self.a, self.b}), datetime.now(UTC))
        while q.pending:
            q.flush()
            self.clock.now += 0.5
        self.assertEqual(calls, [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0])

    def test_conflict_is_logged_and_not_retried(self):
        q = RatingQueue(apply=lambda _m: {"status": "conflict"}, unrated=lambda *_: [], clock=self.clock)
        q.recover()
        q._enqueue("m", frozenset({self.a, self.b}), datetime.now(UTC))
        with self.assertLogs("app.services.pvp_rating", level="ERROR") as logs:
            q.flush()
        self.assertEqual((q.pending, q.conflicts), (0, 1))
        self.assertIn("integrity conflict", logs.output[0])

    def test_transient_failures_keep_retrying_with_capped_backoff(self):
        calls = []

        def apply(_m: str) -> dict[str, Any]:
            calls.append(self.clock.now)
            raise ConnectionError("down")

        q = RatingQueue(apply=apply, unrated=lambda *_: [], clock=self.clock, base_seconds=1, max_seconds=60)
        q.recover()
        q._enqueue("m", frozenset({self.a, self.b}), datetime.now(UTC))
        with self.assertLogs("app.services.pvp_rating", level="WARNING"):
            while self.clock.now < 3600:
                q.flush()
                self.clock.now += 0.5
        gaps = [later - earlier for earlier, later in zip(calls, calls[1:])]
        self.assertEqual(gaps[:6], [1, 2, 4, 8, 16, 32])
        self.assertEqual(max(gaps), 60)
        self.assertEqual(q.pending, 1, "never dropped while the process lives")


class HubTest(unittest.TestCase):
    def test_hub_rates_after_history_and_never_blocks_combat(self):
        db = FakeRatingDb()
        recorder = MatchRecorder(writer=db.store)
        queue = RatingQueue(apply=db.apply, unrated=db.unrated, history_blocked=history_blocker(recorder))
        recorder.on_stored = queue.add
        d = MatchDriver()
        hub = PvpHub(d.service, recorder=recorder, rating=queue)
        d.play_to_ko(d.matchmade_room())
        asyncio.run(hub.persist())
        self.assertEqual(len(db.events), 1)
        self.assertTrue(queue.recovered)
        asyncio.run(hub.persist())
        self.assertEqual(len(db.calls), 1, "nothing left to apply")


class RankApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rows: dict[str, dict[str, Any]] = {}
        self.fail = False
        test = self

        class Query:
            def __init__(self) -> None:
                self.student = None

            def select(self, _columns: str) -> "Query":
                return self

            def eq(self, _column: str, value: str) -> "Query":
                self.student = value
                return self

            def execute(self) -> Any:
                if test.fail:
                    raise RuntimeError("db down")
                row = test.rows.get(self.student)
                return types.SimpleNamespace(data=[row] if row else [])

        class Db:
            tables: list[str] = []

            def table(self, name: str) -> Query:
                Db.tables.append(name)
                return Query()

        self.db = Db()
        patcher = patch.object(pvp_rating, "supabase", self.db)
        patcher.start()
        self.addCleanup(patcher.stop)
        app = FastAPI()
        app.include_router(router)
        app.state.pvp_hub = PvpHub(PvpService(bank=fixture_bank()))
        self.client = TestClient(app)

    def test_requires_a_student_jwt(self):
        self.assertEqual(self.client.get("/api/pvp/me/rank").status_code, 401)

    def test_new_player_and_existing_player(self):
        me = student()
        self.assertEqual(self.client.get("/api/pvp/me/rank", headers=auth(me)).json()["points"], 1000)
        self.rows[me] = {"points": 2846, "rated_matches": 90, "wins": 70, "losses": 20, "draws": 0}
        body = self.client.get("/api/pvp/me/rank", headers=auth(me)).json()
        self.assertEqual(body, {"points": 2846, "rank": "Grandmaster", "current_threshold": 2700, "next_rank": None, "next_threshold": None, "points_to_next_rank": None,
                                "rated_matches": 90, "wins": 70, "losses": 20, "draws": 0})
        self.assertEqual(set(self.db.tables), {"pvp_ratings"})

    def test_cannot_read_another_students_standing(self):
        me, other = student(), student()
        self.rows[other] = {"points": 2200, "rated_matches": 40, "wins": 30, "losses": 10, "draws": 0}
        for query in (f"?student_id={other}", f"?user_id={other}"):
            self.assertEqual(self.client.get(f"/api/pvp/me/rank{query}", headers=auth(me)).json()["points"], 1000)
        self.assertEqual(self.client.get(f"/api/pvp/me/rank/{other}", headers=auth(me)).status_code, 404)

    def test_outage_is_a_safe_503(self):
        self.fail = True
        response = self.client.get("/api/pvp/me/rank", headers=auth(student()))
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("db down", response.text)


class SeparationTest(unittest.TestCase):
    def test_ratings_never_touch_bkt_mastery_or_tokens(self):
        for path in (APP / "services" / "pvp_rating.py", MIGRATION):
            text = path.read_text(encoding="utf-8").lower()
            for table in ("bkt_records", "player_saves", "public.students set", "update public.students", "pvp_tokens"):
                self.assertNotIn(table, text, f"{path.name} references {table}")
        imports = [line for line in (APP / "services" / "pvp_rating.py").read_text(encoding="utf-8").splitlines() if line.startswith(("import ", "from "))]
        for forbidden in ("bkt", "mastery", "progress", "assess", "token", "reward"):
            self.assertFalse([line for line in imports if forbidden in line.lower()], forbidden)

    def test_migration_keeps_the_safety_properties(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        for fragment in (
            "primary key (match_id, student_id)",
            "greatest(0, ra.points + delta_a)",
            "greatest(0, rb.points - delta_a)",
            "low_id := least(m.player1_id, m.player2_id)",
            "deferrable initially deferred",
            "raise exception 'pvp_rating_events is an immutable audit log'",
            "rated_from     timestamptz not null default now()",
            "revoke all on function public.levelblue_apply_pvp_rating(uuid) from public, anon, authenticated",
            "'waiting_for_prior_match'",
        ):
            self.assertIn(fragment, sql)


if __name__ == "__main__":
    unittest.main()
