import contextlib
import json
import queue
import sys
import threading
import time
import types
import unittest
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta

if "app.supabase_client" not in sys.modules:
    stub = types.ModuleType("app.supabase_client")
    stub.supabase = object()
    sys.modules["app.supabase_client"] = stub

import jwt
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.config import settings
from app.routes.pvp import router
from app.services.auth_service import JWT_ALGORITHM
from app.services.pvp_hub import CLOSE_REPLACED, CLOSE_ROOM_GONE, PvpHub
from app.services.pvp_service import COUNTDOWN_MS, DAMAGE_HIT, MAX_HP, RESULT_MS, PvpQuestion, PvpService

HOST = "stu-host"
GUEST = "stu-guest"
OUTSIDER = "stu-outsider"
GRACE_MS = 15_000
TTL_MS = 60_000
STALE_MS = 600_000
ROUND_KEYS = {"type", "revision", "code", "server_now", "round", "question_id", "question", "options", "started_at", "ends_at"}
SECRETS = ("answer_index", "bkt", "p_g", "p_s", "p_t", "correct_option")


def token(user_id: str, role: str = "student") -> str:
    payload = {"id": user_id, "role": role, "exp": datetime.now(UTC) + timedelta(hours=1), "iat": datetime.now(UTC)}
    return jwt.encode(payload, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def auth(user_id: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token(user_id)}"}


def fixture_bank(count: int = 6) -> list[PvpQuestion]:
    return [
        PvpQuestion(id=f"q{i}", question=f"Question {i}?", options=(f"a{i}", f"b{i}", f"c{i}", f"d{i}"), answer_index=i % 4, topic="Phishing", difficulty="easy")
        for i in range(count)
    ]


class Clock:
    def __init__(self) -> None:
        self.now = 5_000_000

    def __call__(self) -> int:
        return self.now


class Socket:
    """A test client socket with a reader thread so waits can time out instead of hanging."""

    def __init__(self, client: TestClient, code: str, user_id: str) -> None:
        self._context = client.websocket_connect(f"/api/pvp/rooms/{code}/ws", headers=auth(user_id))
        self.ws = self._context.__enter__()
        self.user_id = user_id
        self.inbox: queue.Queue[dict] = queue.Queue()
        self.seen: list[dict] = []
        self.close_code: int | None = None
        threading.Thread(target=self._pump, daemon=True).start()

    def _pump(self) -> None:
        try:
            while True:
                self.inbox.put(self.ws.receive_json())
        except WebSocketDisconnect as exc:
            self.close_code = exc.code
        except Exception:
            pass
        self.inbox.put({"type": "__closed__", "code": self.close_code})

    def next(self, kind: str, timeout: float = 3.0) -> dict:
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f"{self.user_id} never received {kind}; saw {[m['type'] for m in self.seen]}")
            try:
                message = self.inbox.get(timeout=remaining)
            except queue.Empty:
                continue
            self.seen.append(message)
            if message["type"] == kind:
                return message

    def drain(self, settle: float = 0.15) -> list[dict]:
        time.sleep(settle)
        out: list[dict] = []
        while True:
            try:
                message = self.inbox.get_nowait()
            except queue.Empty:
                return out
            self.seen.append(message)
            out.append(message)

    def send(self, message: dict) -> None:
        self.ws.send_json(message)

    def close(self) -> None:
        with contextlib.suppress(Exception):
            self._context.__exit__(None, None, None)


def wait_until(condition, timeout: float = 3.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if condition():
            return True
        time.sleep(0.01)
    return condition()


class RealtimeHarness(unittest.TestCase):
    def setUp(self) -> None:
        self.clock = Clock()
        self.service = PvpService(bank=fixture_bank(), clock=self.clock, seed=11, active_grace_ms=GRACE_MS, waiting_grace_ms=GRACE_MS * 4, closed_ttl_ms=TTL_MS, stale_waiting_ms=STALE_MS)
        self.hub = PvpHub(self.service, tick_seconds=0.01, cleanup_seconds=0.02)
        hub = self.hub

        @asynccontextmanager
        async def lifespan(app: FastAPI):
            app.state.pvp_hub = hub
            async with hub.running():
                yield

        app = FastAPI(lifespan=lifespan)
        app.include_router(router)
        self.client = TestClient(app)
        self.client.__enter__()
        self.sockets: list[Socket] = []

    def tearDown(self) -> None:
        for socket in self.sockets:
            socket.close()
        self.client.__exit__(None, None, None)

    def open(self, code: str, user_id: str) -> Socket:
        socket = Socket(self.client, code, user_id)
        self.sockets.append(socket)
        return socket

    def room(self) -> str:
        code = self.client.post("/api/pvp/rooms", headers=auth(HOST)).json()["code"]
        self.assertEqual(self.client.post(f"/api/pvp/rooms/{code}/join", headers=auth(GUEST)).status_code, 200)
        return code

    def connected_pair(self) -> tuple[str, Socket, Socket]:
        code = self.room()
        host = self.open(code, HOST)
        host.next("room_state")
        guest = self.open(code, GUEST)
        guest.next("room_state")
        host.next("opponent_connected")
        return code, host, guest

    def started_pair(self) -> tuple[str, Socket, Socket, dict, dict]:
        code, host, guest = self.connected_pair()
        host.send({"type": "ready"})
        guest.send({"type": "ready"})
        host.next("countdown_started")
        guest.next("countdown_started")
        self.clock.now += COUNTDOWN_MS
        return code, host, guest, host.next("round_started"), guest.next("round_started")

    def positions(self, code: str) -> tuple[int, int]:
        right = self.service._room(code).current.correct_position()
        return right, (right + 1) % 4


class HttpTest(RealtimeHarness):
    def test_http_requires_a_student_jwt(self):
        self.assertEqual(self.client.post("/api/pvp/rooms").status_code, 401)
        self.assertEqual(self.client.post("/api/pvp/rooms", headers={"Authorization": "Bearer nope"}).status_code, 401)
        teacher = {"Authorization": f"Bearer {token('t-1', role='teacher')}"}
        self.assertEqual(self.client.post("/api/pvp/rooms", headers=teacher).status_code, 403)

    def test_create_and_join_use_jwt_identity(self):
        created = self.client.post("/api/pvp/rooms", headers=auth(HOST), json={"user_id": "spoofed", "host_id": "spoofed"})
        self.assertEqual(created.status_code, 201)
        code = created.json()["code"]
        self.assertEqual(created.json()["host_id"], HOST)
        self.assertEqual(self.client.post(f"/api/pvp/rooms/{code}/join", headers=auth(HOST)).json()["code"], "already_in_room")
        joined = self.client.post(f"/api/pvp/rooms/{code.lower()}/join", headers=auth(GUEST), json={"user_id": "spoofed"})
        self.assertEqual(joined.status_code, 200)
        self.assertEqual((joined.json()["host_id"], joined.json()["guest_id"]), (HOST, GUEST))
        self.assertEqual(self.client.post(f"/api/pvp/rooms/{code}/join", headers=auth(GUEST)).status_code, 409)
        third = self.client.post(f"/api/pvp/rooms/{code}/join", headers=auth(OUTSIDER))
        self.assertEqual((third.status_code, third.json()["code"]), (409, "room_full"))
        self.assertEqual(self.client.get(f"/api/pvp/rooms/{code}", headers=auth(OUTSIDER)).status_code, 403)
        self.assertEqual(self.client.get(f"/api/pvp/rooms/{code}", headers=auth(GUEST)).json()["guest_id"], GUEST)
        self.assertEqual(self.client.post("/api/pvp/rooms/ZZZZZZ/join", headers=auth(GUEST)).status_code, 404)

    def test_host_cannot_take_both_slots(self):
        code = self.client.post("/api/pvp/rooms", headers=auth(HOST)).json()["code"]
        self.assertEqual(self.client.post(f"/api/pvp/rooms/{code}/join", headers=auth(HOST)).status_code, 409)
        self.assertIsNone(self.client.get(f"/api/pvp/rooms/{code}", headers=auth(HOST)).json()["guest_id"])

    def test_closed_rooms_reject_joins(self):
        code = self.client.post("/api/pvp/rooms", headers=auth(HOST)).json()["code"]
        self.service.retire(code, HOST)
        closed = self.client.post(f"/api/pvp/rooms/{code}/join", headers=auth(GUEST))
        self.assertEqual((closed.status_code, closed.json()["code"]), (409, "room_closed"))


class SocketAuthTest(RealtimeHarness):
    def assertRefused(self, code: str, headers: dict, close_code: int) -> None:
        with self.assertRaises(WebSocketDisconnect) as caught:
            with self.client.websocket_connect(f"/api/pvp/rooms/{code}/ws", headers=headers):
                pass
        self.assertEqual(caught.exception.code, close_code)

    def test_socket_auth_failure_and_success(self):
        code = self.room()
        self.assertRefused(code, {}, 4401)
        self.assertRefused(code, {"Authorization": "Bearer forged"}, 4401)
        self.assertRefused(code, {"Authorization": f"Bearer {token(HOST, role='teacher')}"}, 4403)
        self.assertRefused(code, auth(OUTSIDER), 4403)
        self.assertRefused("ZZZZZZ", auth(HOST), 4404)
        host = self.open(code, HOST)
        state = host.next("room_state")
        self.assertEqual(state["host_id"], HOST)
        self.assertTrue(state["connected"][HOST])


class MatchFlowTest(RealtimeHarness):
    def test_ready_is_synchronized(self):
        code, host, guest = self.connected_pair()
        host.send({"type": "ready"})
        self.assertTrue(guest.next("room_state")["ready"][HOST])
        self.assertTrue(host.next("room_state")["ready"][HOST])
        guest.send({"type": "ready"})
        host_count = host.next("countdown_started")
        guest_count = guest.next("countdown_started")
        self.assertEqual(host_count["countdown_ends_at"], guest_count["countdown_ends_at"])
        self.assertEqual(host_count["revision"], guest_count["revision"])

    def test_both_clients_receive_the_exact_same_round(self):
        _code, _host, _guest, host_round, guest_round = self.started_pair()
        self.assertEqual(host_round, guest_round)
        self.assertEqual(set(host_round), ROUND_KEYS)
        self.assertEqual(len(host_round["options"]), 4)

    def test_wrong_answer_locks_only_the_submitter(self):
        code, host, guest, _hr, _gr = self.started_pair()
        right, wrong = self.positions(code)
        host.send({"type": "answer", "round": 1, "option_index": wrong, "correct": True, "hp": {GUEST: 0}, "winner_id": HOST, "started_at": 0})
        locked = host.next("answer_locked")
        self.assertEqual((locked["correct"], locked["option_index"]), (False, wrong))
        self.assertEqual(self.service.state(code, HOST)["state"], "active")
        self.assertEqual(self.service.state(code, HOST)["hp"], {HOST: MAX_HP, GUEST: MAX_HP})
        self.assertEqual([m for m in guest.drain() if m["type"] == "answer_locked"], [])
        host.send({"type": "answer", "round": 1, "option_index": right})
        self.assertEqual(host.next("error")["code"], "already_answered")
        guest.send({"type": "answer", "round": 1, "option_index": right})
        self.assertTrue(guest.next("answer_locked")["correct"])
        guest_result = guest.next("round_result")
        host_result = host.next("round_result")
        self.assertEqual(guest_result, host_result)
        self.assertEqual(guest_result["winner_id"], GUEST)
        self.assertEqual(guest_result["hp"], {HOST: MAX_HP - DAMAGE_HIT, GUEST: MAX_HP})
        self.assertNotIn("answer_locked", [m["type"] for m in guest.seen if m.get("user_id") == HOST])

    def test_correct_answer_broadcasts_exactly_one_result(self):
        code, host, guest, _hr, _gr = self.started_pair()
        right, _wrong = self.positions(code)
        host.send({"type": "answer", "round": 1, "option_index": right})
        result = host.next("round_result")
        self.assertEqual((result["winner_id"], result["reason"], result["correct_option"]), (HOST, "correct", right))
        self.assertEqual(guest.next("round_result"), result)
        extra = [m for m in host.drain() + guest.drain() if m["type"] == "round_result"]
        self.assertEqual(extra, [])

    def test_concurrent_correct_answers_produce_one_winner(self):
        code, host, guest, _hr, _gr = self.started_pair()
        right, _wrong = self.positions(code)
        host.send({"type": "answer", "round": 1, "option_index": right})
        guest.send({"type": "answer", "round": 1, "option_index": right})
        result = host.next("round_result")
        self.assertEqual(guest.next("round_result"), result)
        loser = guest if result["winner_id"] == HOST else host
        self.assertEqual(loser.next("error")["code"], "round_resolved")
        self.assertEqual(sorted(result["hp"].values()), [MAX_HP - DAMAGE_HIT, MAX_HP])
        self.assertEqual([m for m in host.drain() + guest.drain() if m["type"] == "round_result"], [])

    def test_expired_answer_rejected(self):
        code, host, guest, round_payload, _gr = self.started_pair()
        right, _wrong = self.positions(code)
        self.clock.now = round_payload["ends_at"]
        host.send({"type": "answer", "round": 1, "option_index": right})
        self.assertIn(host.next("error")["code"], {"late", "round_resolved"})
        self.assertEqual(self.service.state(code, HOST)["hp"], {HOST: MAX_HP, GUEST: MAX_HP})

    def test_timeout_resolves_and_next_round_starts_without_client_traffic(self):
        _code, host, guest, round_payload, _gr = self.started_pair()
        self.clock.now = round_payload["ends_at"]
        result = host.next("round_result")
        self.assertEqual((result["reason"], result["winner_id"], result["damage"]), ("timeout", None, {}))
        self.assertEqual(guest.next("round_result"), result)
        self.clock.now = result["result_ends_at"]
        countdown = host.next("countdown_started")
        self.assertEqual(countdown["round"], 2)
        self.clock.now = countdown["countdown_ends_at"]
        second_host = host.next("round_started")
        self.assertEqual(second_host, guest.next("round_started"))
        self.assertEqual(second_host["round"], 2)
        self.assertNotEqual(second_host["question_id"], round_payload["question_id"])

    def test_ping_pong(self):
        _code, host, _guest = self.connected_pair()
        host.send({"type": "ping"})
        self.assertEqual(host.next("pong")["server_now"], self.clock.now)


class ConnectionTest(RealtimeHarness):
    def test_reconnect_restores_current_state_without_a_new_question(self):
        code, host, guest, round_payload, _gr = self.started_pair()
        guest.close()
        gone = host.next("opponent_disconnected")
        self.assertEqual(gone["grace_ends_at"], self.clock.now + GRACE_MS)
        self.clock.now += 2000
        again = self.open(code, GUEST)
        state = again.next("room_state")
        self.assertEqual(state["state"], "active")
        self.assertEqual(state["round"], {key: round_payload[key] for key in ("round", "question_id", "question", "options", "started_at", "ends_at")})
        self.assertTrue(state["connected"][GUEST])
        host.next("opponent_connected")
        self.assertEqual(self.service._room(code).questions_selected, 1)
        self.assertGreater(state["revision"], round_payload["revision"])

    def test_old_socket_cannot_submit_after_replacement(self):
        code, host, guest, _hr, _gr = self.started_pair()
        right, _wrong = self.positions(code)
        replacement = self.open(code, GUEST)
        replacement.next("room_state")
        self.assertEqual(guest.next("__closed__")["code"], CLOSE_REPLACED)
        with contextlib.suppress(Exception):
            guest.send({"type": "answer", "round": 1, "option_index": right})
        time.sleep(0.2)
        self.assertFalse(self.service.state(code, GUEST)["you_answered"])
        self.assertEqual(self.service.state(code, GUEST)["state"], "active")
        self.assertTrue(self.service.state(code, GUEST)["connected"][GUEST])
        replacement.send({"type": "answer", "round": 1, "option_index": right})
        self.assertEqual(replacement.next("round_result")["winner_id"], GUEST)

    def test_disconnect_grace_keeps_the_match_alive(self):
        code, host, guest, _hr, _gr = self.started_pair()
        guest.close()
        host.next("opponent_disconnected")
        self.clock.now += GRACE_MS - 1
        time.sleep(0.1)
        self.assertNotIn(self.service.state(code, HOST)["state"], {"finished", "abandoned"})
        again = self.open(code, GUEST)
        again.next("room_state")
        self.clock.now += GRACE_MS * 2
        time.sleep(0.1)
        self.assertNotEqual(self.service.state(code, HOST)["state"], "abandoned")

    def test_grace_expiry_forfeits_the_disconnected_player(self):
        code, host, guest, _hr, _gr = self.started_pair()
        guest.close()
        host.next("opponent_disconnected")
        self.clock.now += GRACE_MS
        finished = host.next("match_finished")
        self.assertEqual((finished["reason"], finished["winner_id"], finished["retired_by"]), ("forfeit", HOST, GUEST))
        host.send({"type": "answer", "round": 1, "option_index": 0})
        self.assertEqual(host.next("error")["code"], "room_closed")

    def test_leave_retires_and_opponent_wins(self):
        _code, host, guest, _hr, _gr = self.started_pair()
        guest.send({"type": "leave"})
        finished = host.next("match_finished")
        self.assertEqual((finished["reason"], finished["winner_id"]), ("retired", HOST))
        self.assertEqual(guest.next("match_finished"), finished)
        self.assertEqual(guest.next("__closed__")["code"], 1000)


class CleanupTest(RealtimeHarness):
    def test_finished_room_is_removed_and_sockets_closed(self):
        code, host, guest, _hr, _gr = self.started_pair()
        guest.send({"type": "leave"})
        host.next("match_finished")
        self.clock.now += TTL_MS
        self.assertEqual(host.next("__closed__")["code"], CLOSE_ROOM_GONE)
        self.assertTrue(wait_until(lambda: code not in self.service.room_codes()))
        self.assertEqual(self.client.get(f"/api/pvp/rooms/{code}", headers=auth(HOST)).status_code, 404)

    def test_stale_waiting_room_is_abandoned_then_removed(self):
        code = self.client.post("/api/pvp/rooms", headers=auth(HOST)).json()["code"]
        self.clock.now += STALE_MS
        self.assertTrue(wait_until(lambda: self.client.get(f"/api/pvp/rooms/{code}", headers=auth(HOST)).json().get("finish_reason") == "stale"))
        self.clock.now += TTL_MS
        self.assertTrue(wait_until(lambda: code not in self.service.room_codes()))


class LeakAndOrderingTest(RealtimeHarness):
    def test_no_answer_key_or_bkt_in_active_round_payloads(self):
        code, host, guest, _hr, _gr = self.started_pair()
        for round_number in (1, 2, 3):
            _right, wrong = self.positions(code)
            live_host = len(host.seen) - 1
            live_guest = len(guest.seen) - 1
            host.send({"type": "answer", "round": round_number, "option_index": wrong})
            host.next("answer_locked")
            http_view = self.client.get(f"/api/pvp/rooms/{code}", headers=auth(GUEST)).json()
            self.assertIsNone(http_view["result"])
            self.assertFalse(http_view["you_answered"])
            guest.drain()
            for message in host.seen[live_host:] + guest.seen[live_guest:] + [http_view]:
                text = json.dumps(message)
                for secret in SECRETS:
                    self.assertNotIn(secret, text, message["type"] if "type" in message else "http")
            self.assertEqual([m for m in guest.seen[live_guest:] if m["type"] == "answer_locked"], [])
            self.clock.now = self.service._room(code).current.ends_at
            result = guest.next("round_result")
            self.assertIn("correct_option", result)
            self.clock.now = result["result_ends_at"] + COUNTDOWN_MS
            host.next("round_started")
            guest.next("round_started")

    def test_revisions_strictly_increase_for_each_client(self):
        code, host, guest, _hr, _gr = self.started_pair()
        right, wrong = self.positions(code)
        guest.send({"type": "answer", "round": 1, "option_index": wrong})
        host.send({"type": "answer", "round": 1, "option_index": right})
        result = host.next("round_result")
        guest.next("round_result")
        self.clock.now = result["result_ends_at"] + COUNTDOWN_MS
        host.next("round_started")
        guest.next("round_started")
        host.send({"type": "ping"})
        host.next("pong")
        for socket in (host, guest):
            revisions = [m["revision"] for m in socket.seen if m["type"] not in ("pong", "error", "__closed__")]
            self.assertEqual(revisions, sorted(set(revisions)), socket.user_id)
        stale = [m for m in host.seen if m["type"] == "round_started"][0]
        latest = max(m["revision"] for m in host.seen if "revision" in m)
        self.assertLess(stale["revision"], latest)


if __name__ == "__main__":
    unittest.main()
