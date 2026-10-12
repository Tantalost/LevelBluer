import json
import threading
import unittest
from pathlib import Path

try:
    from tests.test_pvp_realtime import GUEST, HOST, OUTSIDER, RealtimeHarness, auth, token
except ImportError:
    from test_pvp_realtime import GUEST, HOST, OUTSIDER, RealtimeHarness, auth, token

from app.services.pvp_service import COUNTDOWN_MS, DAMAGE_HIT, MAX_HP, PvpError, PvpQuestion, PvpService

APP = Path(__file__).resolve().parents[1] / "app"
TTL_MS = 90_000
WAITING_GRACE_MS = 60_000


class Clock:
    def __init__(self, now: int = 1_000_000) -> None:
        self.now = now

    def __call__(self) -> int:
        return self.now


def fixture_bank(count: int = 6) -> list[PvpQuestion]:
    return [
        PvpQuestion(id=f"q{i}", question=f"Question {i}?", options=(f"a{i}", f"b{i}", f"c{i}", f"d{i}"), answer_index=i % 4, topic="Phishing", difficulty="easy")
        for i in range(count)
    ]


class QueueHarness(unittest.TestCase):
    def setUp(self) -> None:
        self.clock = Clock()
        self.service = PvpService(bank=fixture_bank(), clock=self.clock, seed=3, queue_ttl_ms=TTL_MS, waiting_grace_ms=WAITING_GRACE_MS)

    def rooms(self, service: PvpService | None = None) -> list[str]:
        return (service or self.service).room_codes()

    def pair(self) -> str:
        self.assertEqual(self.service.join_queue("a")["status"], "queued")
        matched = self.service.join_queue("b")
        self.assertEqual(matched["status"], "matched")
        return matched["room_code"]


class QueueRulesTest(QueueHarness):
    def test_join_empty_queue_waits(self):
        ticket = self.service.join_queue("a")
        self.assertEqual(ticket["status"], "queued")
        self.assertEqual(ticket["expires_at"], self.clock.now + TTL_MS)
        self.assertEqual(self.service.queue_status("a")["status"], "queued")
        self.assertEqual(self.rooms(), [])

    def test_second_student_is_matched_and_both_share_one_room(self):
        code = self.pair()
        self.assertEqual(self.service.queue_status("a"), {"status": "matched", "room_code": code})
        self.assertEqual(self.service.queue_status("b"), {"status": "matched", "room_code": code})
        self.assertEqual(self.rooms(), [code])
        view = self.service.state(code, "a")
        self.assertEqual((view["host_id"], view["guest_id"]), ("a", "b"))
        self.assertEqual(view["origin"], "matchmaking")
        self.assertEqual(view["state"], "waiting")
        self.assertEqual(view["hp"], {"a": MAX_HP, "b": MAX_HP})

    def test_a_student_never_matches_themselves(self):
        self.assertEqual(self.service.join_queue("a")["status"], "queued")
        self.assertEqual(self.service.join_queue("a")["status"], "queued")
        self.assertEqual(self.rooms(), [])
        self.assertEqual(list(self.service._queue), ["a"])

    def test_duplicate_join_is_idempotent(self):
        first = self.service.join_queue("a")
        self.clock.now += 5_000
        second = self.service.join_queue("a")
        self.assertEqual(second["queued_at"], first["queued_at"])
        self.assertEqual(second["expires_at"], self.clock.now + TTL_MS)
        self.assertEqual(len(self.service._queue), 1)

    def test_rejoining_after_a_match_returns_the_same_room(self):
        code = self.pair()
        self.assertEqual(self.service.join_queue("a"), {"status": "matched", "room_code": code})
        self.assertEqual(self.service.join_queue("b"), {"status": "matched", "room_code": code})
        self.assertEqual(self.rooms(), [code])
        self.assertEqual(self.service._queue, {})

    def test_matched_students_leave_the_queue(self):
        self.pair()
        self.assertEqual(self.service._queue, {})
        self.assertEqual(self.service.join_queue("c")["status"], "queued")

    def test_the_next_arrival_takes_the_waiting_student(self):
        self.service.join_queue("a")
        code = self.service.join_queue("b")["room_code"]
        self.assertEqual(self.service.join_queue("c")["status"], "queued")
        other = self.service.join_queue("d")["room_code"]
        self.assertNotEqual(code, other)
        self.assertEqual(self.service.state(other, "c")["host_id"], "c")

    def test_a_student_in_an_active_room_cannot_queue(self):
        private = self.service.create_room("a")["code"]
        with self.assertRaises(PvpError) as caught:
            self.service.join_queue("a")
        self.assertEqual(caught.exception.code, "already_in_match")
        self.assertEqual(self.service._queue, {})
        self.service.retire(private, "a")
        self.assertEqual(self.service.join_queue("a")["status"], "queued")

    def test_a_waiting_student_who_entered_another_room_is_skipped(self):
        self.service.join_queue("a")
        self.service.create_room("a")
        self.assertEqual(self.service.join_queue("b")["status"], "queued")
        self.assertEqual(list(self.service._queue), ["b"])
        self.assertEqual(len(self.rooms()), 1)

    def test_responses_carry_no_opponent_identity(self):
        self.service.join_queue("a")
        responses = [self.service.join_queue("b"), self.service.queue_status("a"), self.service.cancel_queue("b")]
        for response in responses:
            self.assertEqual(set(response), {"status", "room_code"})


class CancelTest(QueueHarness):
    def test_cancel_before_a_match(self):
        self.service.join_queue("a")
        self.assertEqual(self.service.cancel_queue("a"), {"status": "cancelled"})
        self.assertEqual(self.service.queue_status("a"), {"status": "idle"})
        self.assertEqual(self.service.join_queue("b")["status"], "queued")
        self.assertEqual(self.rooms(), [])

    def test_cancel_when_not_queued_is_harmless(self):
        self.assertEqual(self.service.cancel_queue("a"), {"status": "idle"})

    def test_cancel_after_a_match_keeps_the_match(self):
        code = self.pair()
        self.assertEqual(self.service.cancel_queue("a"), {"status": "matched", "room_code": code})
        self.assertEqual(self.service.state(code, "a")["state"], "waiting")
        self.assertEqual(self.service.queue_status("b"), {"status": "matched", "room_code": code})

    def test_cancel_and_match_race_is_deterministic(self):
        outcomes: set[str] = set()
        for attempt in range(200):
            service = PvpService(bank=fixture_bank(), clock=self.clock, seed=attempt, queue_ttl_ms=TTL_MS)
            service.join_queue("a")
            barrier = threading.Barrier(2)
            results: dict[str, dict] = {}

            def cancel() -> None:
                barrier.wait()
                results["a"] = service.cancel_queue("a")

            def join() -> None:
                barrier.wait()
                results["b"] = service.join_queue("b")

            threads = [threading.Thread(target=cancel), threading.Thread(target=join)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            if results["a"]["status"] == "cancelled":
                outcomes.add("cancel_first")
                self.assertEqual(results["b"]["status"], "queued")
                self.assertEqual(service.room_codes(), [])
            else:
                outcomes.add("match_first")
                self.assertEqual(results["a"]["status"], "matched")
                self.assertEqual(results["b"], results["a"])
                self.assertEqual(service.room_codes(), [results["a"]["room_code"]])
            self.assertEqual(set(service._matched.values()), set(service.room_codes()))
        self.assertTrue(outcomes)


class ConcurrencyTest(QueueHarness):
    def run_joins(self, service: PvpService, users: list[str]) -> dict[str, dict]:
        barrier = threading.Barrier(len(users))
        results: dict[str, dict] = {}

        def join(user: str) -> None:
            barrier.wait()
            results[user] = service.join_queue(user)

        threads = [threading.Thread(target=join, args=(user,)) for user in users]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        return results

    def test_two_simultaneous_joins_create_exactly_one_room(self):
        for attempt in range(100):
            service = PvpService(bank=fixture_bank(), clock=self.clock, seed=attempt)
            results = self.run_joins(service, ["a", "b"])
            statuses = sorted(result["status"] for result in results.values())
            self.assertEqual(statuses, ["matched", "queued"])
            self.assertEqual(len(service.room_codes()), 1)
            code = service.room_codes()[0]
            self.assertEqual(service.queue_status("a"), {"status": "matched", "room_code": code})
            self.assertEqual(service.queue_status("b"), {"status": "matched", "room_code": code})
            self.assertEqual(service._queue, {})

    def test_many_simultaneous_joins_pair_everyone_exactly_once(self):
        users = [f"s{i}" for i in range(12)]
        service = PvpService(bank=fixture_bank(), clock=self.clock, seed=5)
        self.run_joins(service, users)
        codes = service.room_codes()
        self.assertEqual(len(codes), 6)
        seen: list[str] = []
        for code in codes:
            view = service.state(code, service._room(code).host.user_id)
            self.assertNotEqual(view["host_id"], view["guest_id"])
            seen += [view["host_id"], view["guest_id"]]
        self.assertEqual(sorted(seen), sorted(users))
        self.assertEqual(service._queue, {})
        for user in users:
            self.assertEqual(service.queue_status(user)["status"], "matched")


class ExpiryTest(QueueHarness):
    def test_stale_entries_expire_and_are_never_matched(self):
        self.service.join_queue("a")
        self.clock.now += TTL_MS
        self.assertEqual(self.service.join_queue("b")["status"], "queued")
        self.assertEqual(self.service.queue_status("a"), {"status": "idle"})
        self.assertEqual(self.rooms(), [])

    def test_polling_status_keeps_an_entry_alive(self):
        self.service.join_queue("a")
        for _ in range(4):
            self.clock.now += TTL_MS - 1
            self.assertEqual(self.service.queue_status("a")["status"], "queued")
        self.assertEqual(self.service.join_queue("b")["status"], "matched")

    def test_periodic_cleanup_drops_abandoned_entries(self):
        self.service.join_queue("a")
        self.clock.now += TTL_MS
        self.service.cleanup()
        self.assertEqual(self.service._queue, {})

    def test_matched_no_show_frees_both_students(self):
        code = self.pair()
        self.service.connect(code, "a")
        self.clock.now += WAITING_GRACE_MS
        self.service.cleanup()
        view = self.service.state(code, "a")
        self.assertEqual((view["state"], view["finish_reason"], view["retired_by"], view["winner_id"]), ("abandoned", "forfeit", "b", None))
        self.assertEqual(self.service.queue_status("a"), {"status": "idle"})
        self.assertEqual(self.service.join_queue("a")["status"], "queued")
        self.assertEqual(self.service.join_queue("b")["status"], "matched")


class IsolationTest(QueueHarness):
    def test_private_rooms_are_unchanged(self):
        self.service.join_queue("q")
        code = self.service.create_room("h")["code"]
        view = self.service.join_room(code, "g")
        self.assertEqual(view["origin"], "private")
        self.assertTrue(view["connected"]["h"])
        self.service.set_ready(code, "h")
        self.service.set_ready(code, "g")
        self.assertEqual(self.service.state(code, "h")["state"], "countdown")
        self.assertEqual(self.service.queue_status("q")["status"], "queued")

    def test_matchmaking_never_touches_bkt_tokens_or_rewards(self):
        for path in (APP / "services" / "pvp_service.py", APP / "services" / "pvp_hub.py", APP / "routes" / "pvp.py"):
            imports = [line.lower() for line in path.read_text(encoding="utf-8").splitlines() if line.startswith(("import ", "from "))]
            for forbidden in ("bkt", "mastery", "pvp_token", "reward", "elo", "supabase", "progress", "wallet"):
                self.assertFalse([line for line in imports if forbidden in line], f"{path.name} imports {forbidden}")


class MatchmakingHttpTest(RealtimeHarness):
    def test_endpoints_require_a_student_jwt(self):
        for method, path in (("post", "/api/pvp/matchmaking/join"), ("post", "/api/pvp/matchmaking/cancel"), ("get", "/api/pvp/matchmaking/status")):
            call = getattr(self.client, method)
            self.assertEqual(call(path).status_code, 401)
            self.assertEqual(call(path, headers={"Authorization": "Bearer forged"}).status_code, 401)
            self.assertEqual(call(path, headers={"Authorization": f"Bearer {token('t-1', role='teacher')}"}).status_code, 403)

    def test_identity_comes_only_from_the_jwt(self):
        self.client.post("/api/pvp/matchmaking/join", headers=auth(HOST), json={"user_id": GUEST})
        self.assertEqual(list(self.service._queue), [HOST])

    def test_active_match_conflict_is_409(self):
        self.client.post("/api/pvp/rooms", headers=auth(OUTSIDER))
        response = self.client.post("/api/pvp/matchmaking/join", headers=auth(OUTSIDER))
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["code"], "already_in_match")

    def test_matched_room_plays_through_the_phase_2_flow(self):
        self.assertEqual(self.client.post("/api/pvp/matchmaking/join", headers=auth(HOST)).json(), {"status": "queued", "queued_at": self.clock.now, "expires_at": self.clock.now + self.service.queue_ttl_ms})
        matched = self.client.post("/api/pvp/matchmaking/join", headers=auth(GUEST)).json()
        self.assertEqual(matched["status"], "matched")
        code = matched["room_code"]
        self.assertEqual(self.client.get("/api/pvp/matchmaking/status", headers=auth(HOST)).json(), {"status": "matched", "room_code": code})
        view = self.client.get(f"/api/pvp/rooms/{code}", headers=auth(HOST)).json()
        self.assertEqual((view["origin"], view["state"]), ("matchmaking", "waiting"))
        host = self.open(code, HOST)
        host.next("room_state")
        guest = self.open(code, GUEST)
        guest.next("room_state")
        host.next("opponent_connected")
        host.send({"type": "ready"})
        guest.send({"type": "ready"})
        host.next("countdown_started")
        guest.next("countdown_started")
        self.clock.now += COUNTDOWN_MS
        round_host = host.next("round_started")
        round_guest = guest.next("round_started")
        self.assertEqual(round_host["options"], round_guest["options"])
        right = self.service._room(code).current.correct_position()
        guest.send({"type": "answer", "round": 1, "option_index": right})
        result = host.next("round_result")
        self.assertEqual(result["winner_id"], GUEST)
        self.assertEqual(result["hp"], {HOST: MAX_HP - DAMAGE_HIT, GUEST: MAX_HP})
        self.assertEqual(guest.next("round_result")["hp"], result["hp"])
        self.assertEqual(self.client.post("/api/pvp/matchmaking/cancel", headers=auth(HOST)).json(), {"status": "matched", "room_code": code})
        self.assertEqual(self.service.state(code, HOST)["state"], "round_result")
        leaked = json.dumps(self.client.get("/api/pvp/matchmaking/status", headers=auth(GUEST)).json())
        self.assertNotIn(HOST, leaked)


if __name__ == "__main__":
    unittest.main()
