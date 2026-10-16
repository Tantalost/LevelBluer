import json
import threading
import time
import unittest
from pathlib import Path

from app.services.pvp_service import (
    BANK_PATH,
    COUNTDOWN_MS,
    DAMAGE_HIT,
    MAX_HP,
    RESULT_MS,
    ROOM_CODE_ALPHABET,
    ROOM_CODE_LENGTH,
    ROUND_MS,
    PvpError,
    PvpQuestion,
    PvpService,
    load_bank,
)

FRONTEND_BANK = Path(__file__).resolve().parents[2] / "frontend" / "data" / "pvp_social_engineering_100_all_easy.json"
HOST = "student-host"
GUEST = "student-guest"


class Clock:
    def __init__(self, now: int = 1_000_000) -> None:
        self.now = now

    def __call__(self) -> int:
        return self.now


def fixture_bank(count: int) -> list[PvpQuestion]:
    return [
        PvpQuestion(id=f"q{i}", question=f"Question {i}?", options=(f"a{i}", f"b{i}", f"c{i}", f"d{i}"), answer_index=i % 4, topic="Phishing", difficulty="easy")
        for i in range(count)
    ]


class PvpHarness(unittest.TestCase):
    def make(self, bank: list[PvpQuestion] | None = None, seed: int = 7) -> tuple[PvpService, Clock, str]:
        clock = Clock()
        service = PvpService(bank=bank, clock=clock, seed=seed)
        code = service.create_room(HOST)["code"]
        service.join_room(code, GUEST)
        return service, clock, code

    def start(self, service: PvpService, clock: Clock, code: str) -> dict:
        service.set_ready(code, HOST)
        service.set_ready(code, GUEST)
        clock.now += COUNTDOWN_MS
        return service.state(code, HOST)

    def next_round(self, service: PvpService, clock: Clock, code: str) -> dict:
        view = service.state(code, HOST)
        if view["state"] == "active" and view["result"] is None:
            clock.now = view["round"]["ends_at"]
            view = service.state(code, HOST)
        clock.now += RESULT_MS + COUNTDOWN_MS
        return service.state(code, HOST)

    @staticmethod
    def positions(service: PvpService, code: str) -> tuple[int, int]:
        live = service._room(code).current
        right = live.correct_position()
        return right, (right + 1) % len(live.order)

    def assertError(self, code: str, call, *args) -> None:
        with self.assertRaises(PvpError) as caught:
            call(*args)
        self.assertEqual(caught.exception.code, code)


class OverclockTest(PvpHarness):
    def test_three_wins_charge_next_hit_and_duplicate_cannot_consume_twice(self):
        service, clock, code = self.make()
        self.start(service, clock, code)
        for index in range(3):
            right, _ = self.positions(service, code)
            service.submit_answer(code, HOST, index + 1, right)
            view = service.state(code, HOST)
            self.assertEqual(view["charge"][HOST], index + 1)
            self.assertEqual(view["result"]["damage"][GUEST], 20)
            self.next_round(service, clock, code)
        right, _ = self.positions(service, code)
        service.submit_answer(code, HOST, 4, right)
        view = service.state(code, HOST)
        self.assertEqual(view["hp"][GUEST], 15)
        self.assertEqual(view["result"]["damage"][GUEST], 25)
        self.assertEqual(view["charge"][HOST], 0)
        with self.assertRaises(PvpError):
            service.submit_answer(code, HOST, 4, right)
        self.assertEqual(service.state(code, HOST)["hp"][GUEST], 15)

    def test_incomplete_chain_resets_but_loaded_charge_survives_timeout(self):
        service, clock, code = self.make()
        self.start(service, clock, code)
        right, _ = self.positions(service, code)
        service.submit_answer(code, HOST, 1, right)
        self.next_round(service, clock, code)
        clock.now = service.state(code, HOST)["round"]["ends_at"]
        self.assertEqual(service.state(code, HOST)["charge"][HOST], 0)
        # Already-loaded charge is retained across a lost round and reconnect.
        service._room(code).host.charge = 3
        self.next_round(service, clock, code)
        right, _ = self.positions(service, code)
        service.submit_answer(code, GUEST, 3, right)
        view = service.state(code, HOST)
        self.assertEqual(view["charge"], {HOST: 3, GUEST: 1})
        self.assertEqual(view["hp"][HOST], 80)
        self.assertTrue(view["match_id"])


class BankTest(unittest.TestCase):
    def test_backend_bank_matches_canonical_frontend_text(self):
        # Git can check out one file as CRLF on Windows. Ignore only newline
        # encoding, not wording, options, ordering, ids or answer keys.
        self.assertEqual(BANK_PATH.read_text(encoding="utf-8"), FRONTEND_BANK.read_text(encoding="utf-8"))

    def test_all_100_questions_load_and_are_well_formed(self):
        bank = load_bank()
        self.assertEqual(len(bank), 100)
        self.assertEqual(len({question.id for question in bank}), 100)
        for question in bank:
            self.assertEqual(len(question.options), 4)
            self.assertIn(question.answer_index, range(4))

    def test_malformed_rows_are_skipped_and_missing_file_is_empty(self):
        good = {"id": "ok", "question": "q", "options": ["a", "b", "c", "d"], "answer_index": 1}
        rows = [good, dict(good), dict(good, id="three", options=["a", "b", "c"]), dict(good, id="float", answer_index=1.0), dict(good, id="high", answer_index=4), dict(good, id="blank", question=" ")]
        path = Path(__file__).with_name("_pvp_probe_bank.json")
        path.write_text(json.dumps({"modules": [{"topic": "Phishing", "question_types": [{"questions": rows}]}]}), encoding="utf-8")
        try:
            with self.assertLogs("app.services.pvp_service", level="WARNING"):
                bank = load_bank(path)
        finally:
            path.unlink()
        self.assertEqual([question.id for question in bank], ["ok"])
        with self.assertLogs("app.services.pvp_service", level="ERROR"):
            self.assertEqual(load_bank(path), [])

    def test_empty_bank_cannot_open_rooms(self):
        service = PvpService(bank=[], clock=Clock())
        with self.assertRaises(PvpError) as caught:
            service.create_room(HOST)
        self.assertEqual(caught.exception.code, "bank_unavailable")


class RoomLifecycleTest(PvpHarness):
    def test_create_room(self):
        service = PvpService(bank=fixture_bank(4), clock=Clock())
        view = service.create_room(HOST)
        self.assertEqual(view["state"], "waiting")
        self.assertEqual(view["host_id"], HOST)
        self.assertIsNone(view["guest_id"])
        self.assertEqual(view["hp"], {HOST: MAX_HP})

    def test_room_codes_are_short_and_unique(self):
        service = PvpService(bank=fixture_bank(4), clock=Clock())
        codes = {service.create_room(f"user-{i}")["code"] for i in range(300)}
        self.assertEqual(len(codes), 300)
        for code in codes:
            self.assertEqual(len(code), ROOM_CODE_LENGTH)
            self.assertTrue(set(code) <= set(ROOM_CODE_ALPHABET))

    def test_code_collision_retries(self):
        sequence = iter(["AAAAAA", "AAAAAA", "BBBBBB"])
        service = PvpService(bank=fixture_bank(4), clock=Clock(), code_factory=lambda: next(sequence))
        self.assertEqual(service.create_room("one")["code"], "AAAAAA")
        self.assertEqual(service.create_room("two")["code"], "BBBBBB")

    def test_join_room_and_lowercase_code(self):
        service = PvpService(bank=fixture_bank(4), clock=Clock())
        code = service.create_room(HOST)["code"]
        view = service.join_room(code.lower(), GUEST)
        self.assertEqual(view["guest_id"], GUEST)
        self.assertEqual(view["hp"], {HOST: MAX_HP, GUEST: MAX_HP})

    def test_third_player_rejected(self):
        service, _clock, code = self.make(fixture_bank(4))
        self.assertError("room_full", service.join_room, code, "intruder")
        self.assertError("not_in_room", service.state, code, "intruder")
        self.assertError("room_not_found", service.join_room, "ZZZZZZ", "intruder")

    def test_ready_state_starts_countdown_only_when_both_ready(self):
        service, clock, code = self.make(fixture_bank(4))
        view = service.set_ready(code, HOST)
        self.assertEqual(view["state"], "waiting")
        self.assertEqual(view["ready"], {HOST: True, GUEST: False})
        view = service.set_ready(code, GUEST)
        self.assertEqual(view["state"], "countdown")
        self.assertEqual(view["countdown_ends_at"], clock.now + COUNTDOWN_MS)
        self.assertIsNone(view["round"])
        clock.now += COUNTDOWN_MS - 1
        self.assertEqual(service.state(code, HOST)["state"], "countdown")
        clock.now += 1
        self.assertEqual(service.state(code, HOST)["state"], "active")
        self.assertError("not_waiting", service.set_ready, code, HOST, False)

    def test_host_alone_cannot_start(self):
        service = PvpService(bank=fixture_bank(4), clock=Clock())
        code = service.create_room(HOST)["code"]
        self.assertEqual(service.set_ready(code, HOST)["state"], "waiting")


class RoundTest(PvpHarness):
    def test_both_players_get_the_same_round_and_question(self):
        service, clock, code = self.make(None)
        self.start(service, clock, code)
        for _round in range(12):
            host_view = service.state(code, HOST)
            guest_view = service.state(code, GUEST)
            self.assertEqual(host_view["round"], guest_view["round"])
            payload = host_view["round"]
            self.assertEqual(set(payload), {"round", "question_id", "question", "options", "started_at", "ends_at"})
            self.assertEqual(payload["ends_at"] - payload["started_at"], ROUND_MS)
            self.assertEqual(len(payload["options"]), 4)
            leaked = json.dumps(host_view)
            for secret in ("answer_index", "bkt", "p_g", "correct_option"):
                self.assertNotIn(secret, leaked)
            self.next_round(service, clock, code)

    def test_wrong_answer_locks_only_that_player(self):
        service, clock, code = self.make(fixture_bank(4))
        self.start(service, clock, code)
        right, wrong = self.positions(service, code)
        clock.now += 1000
        reply = service.submit_answer(code, HOST, 1, wrong)
        self.assertFalse(reply["correct"])
        self.assertEqual(reply["room"]["state"], "active")
        self.assertIsNone(reply["room"]["result"])
        self.assertError("already_answered", service.submit_answer, code, HOST, 1, right)
        clock.now += 1000
        reply = service.submit_answer(code, GUEST, 1, right)
        self.assertTrue(reply["correct"])
        self.assertEqual(reply["room"]["result"]["winner_id"], GUEST)
        self.assertEqual(reply["room"]["hp"], {HOST: MAX_HP - DAMAGE_HIT, GUEST: MAX_HP})

    def test_both_wrong_resolves_with_no_damage(self):
        service, clock, code = self.make(fixture_bank(4))
        self.start(service, clock, code)
        _right, wrong = self.positions(service, code)
        service.submit_answer(code, HOST, 1, wrong)
        reply = service.submit_answer(code, GUEST, 1, wrong)
        self.assertEqual(reply["room"]["state"], "round_result")
        self.assertIsNone(reply["room"]["result"]["winner_id"])
        self.assertEqual(reply["room"]["hp"], {HOST: MAX_HP, GUEST: MAX_HP})

    def test_first_correct_wins_immediately(self):
        service, clock, code = self.make(fixture_bank(4))
        self.start(service, clock, code)
        right, _wrong = self.positions(service, code)
        clock.now += 1500
        reply = service.submit_answer(code, HOST, 1, right)
        self.assertTrue(reply["correct"])
        view = reply["room"]
        self.assertEqual(view["state"], "round_result")
        self.assertEqual(view["result"], {"round": 1, "winner_id": HOST, "damage": {GUEST: DAMAGE_HIT}, "correct_option": right})
        self.assertEqual(view["hp"][GUEST], MAX_HP - DAMAGE_HIT)
        self.assertError("round_resolved", service.submit_answer, code, GUEST, 1, right)

    def test_simultaneous_correct_submissions_have_one_winner(self):
        for attempt in range(25):
            service, clock, code = self.make(fixture_bank(4), seed=attempt)
            self.start(service, clock, code)
            right, _wrong = self.positions(service, code)
            resolve = service._resolve

            def slow_resolve(*args, **kwargs) -> None:
                time.sleep(0.005)
                resolve(*args, **kwargs)

            service._resolve = slow_resolve
            barrier = threading.Barrier(2)
            outcomes: dict[str, str] = {}

            def answer(user: str) -> None:
                barrier.wait()
                try:
                    service.submit_answer(code, user, 1, right)
                    outcomes[user] = "won"
                except PvpError as exc:
                    outcomes[user] = exc.code

            threads = [threading.Thread(target=answer, args=(user,)) for user in (HOST, GUEST)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            self.assertEqual(sorted(outcomes.values()), ["round_resolved", "won"])
            view = service.state(code, HOST)
            winner = view["result"]["winner_id"]
            self.assertEqual(outcomes[winner], "won")
            self.assertEqual(sorted(view["hp"].values()), [MAX_HP - DAMAGE_HIT, MAX_HP])

    def test_late_answer_rejected(self):
        service, clock, code = self.make(fixture_bank(4))
        view = self.start(service, clock, code)
        right, _wrong = self.positions(service, code)
        clock.now = view["round"]["ends_at"]
        self.assertError("late", service.submit_answer, code, HOST, 1, right)
        self.assertEqual(service.state(code, HOST)["hp"], {HOST: MAX_HP, GUEST: MAX_HP})

    def test_duplicate_and_wrong_round_answers_rejected(self):
        service, clock, code = self.make(fixture_bank(4))
        self.start(service, clock, code)
        _right, wrong = self.positions(service, code)
        service.submit_answer(code, HOST, 1, wrong)
        self.assertError("already_answered", service.submit_answer, code, HOST, 1, wrong)
        self.assertError("wrong_round", service.submit_answer, code, GUEST, 2, wrong)
        self.assertError("bad_choice", service.submit_answer, code, GUEST, 1, 4)
        self.assertError("bad_choice", service.submit_answer, code, GUEST, 1, True)

    def test_answers_before_the_round_opens_are_rejected(self):
        service, clock, code = self.make(fixture_bank(4))
        service.set_ready(code, HOST)
        service.set_ready(code, GUEST)
        self.assertError("wrong_round", service.submit_answer, code, HOST, 1, 0)

    def test_timeout_deals_zero_damage(self):
        service, clock, code = self.make(fixture_bank(4))
        view = self.start(service, clock, code)
        clock.now = view["round"]["ends_at"]
        view = service.state(code, GUEST)
        self.assertEqual(view["state"], "round_result")
        self.assertIsNone(view["result"]["winner_id"])
        self.assertEqual(view["result"]["damage"], {})
        self.assertEqual(view["hp"], {HOST: MAX_HP, GUEST: MAX_HP})

    def test_hp_decreases_exactly_once_per_round(self):
        service, clock, code = self.make(fixture_bank(4))
        self.start(service, clock, code)
        right, _wrong = self.positions(service, code)
        service.submit_answer(code, GUEST, 1, right)
        for _poll in range(5):
            service.state(code, HOST)
        clock.now += RESULT_MS - 1
        self.assertEqual(service.state(code, HOST)["hp"], {HOST: MAX_HP - DAMAGE_HIT, GUEST: MAX_HP})

    def test_match_continues_past_round_7(self):
        service, clock, code = self.make(fixture_bank(20))
        self.start(service, clock, code)
        for round_number in range(1, 9):
            right, _wrong = self.positions(service, code)
            winner = HOST if round_number % 2 else GUEST
            if round_number <= 4:
                service.submit_answer(code, winner, round_number, right)
            view = self.next_round(service, clock, code)
        self.assertEqual(view["state"], "active")
        self.assertEqual(view["round"]["round"], 9)
        self.assertEqual(view["hp"], {HOST: MAX_HP - 2 * DAMAGE_HIT, GUEST: MAX_HP - 2 * DAMAGE_HIT})

    def test_deck_uses_every_question_then_reshuffles(self):
        service, clock, code = self.make(None)
        self.start(service, clock, code)
        seen: list[str] = []
        for _round in range(101):
            seen.append(service.state(code, HOST)["round"]["question_id"])
            self.next_round(service, clock, code)
        self.assertEqual(len(set(seen[:100])), 100)
        self.assertIn(seen[100], seen[:100])
        self.assertNotEqual(seen[100], seen[99])
        self.assertEqual(service._room(code).questions_selected, 102)

    def test_no_immediate_repeat_across_many_reshuffles(self):
        for seed in range(15):
            service, clock, code = self.make(fixture_bank(2), seed=seed)
            self.start(service, clock, code)
            previous = ""
            for _round in range(12):
                current = service.state(code, HOST)["round"]["question_id"]
                self.assertNotEqual(current, previous)
                previous = current
                self.next_round(service, clock, code)

    def test_single_question_bank_repeats_only_because_it_must(self):
        service, clock, code = self.make(fixture_bank(1))
        self.start(service, clock, code)
        first = service.state(code, HOST)["round"]["question_id"]
        second = self.next_round(service, clock, code)["round"]["question_id"]
        self.assertEqual(first, second)

    def test_ko_finishes_match(self):
        service, clock, code = self.make(fixture_bank(10))
        self.start(service, clock, code)
        for round_number in range(1, 6):
            right, _wrong = self.positions(service, code)
            reply = service.submit_answer(code, HOST, round_number, right)
            if round_number < 5:
                self.next_round(service, clock, code)
        view = reply["room"]
        self.assertEqual(view["state"], "finished")
        self.assertEqual(view["winner_id"], HOST)
        self.assertEqual(view["hp"], {HOST: MAX_HP, GUEST: 0})
        clock.now += RESULT_MS + COUNTDOWN_MS + ROUND_MS
        self.assertEqual(service.state(code, GUEST)["state"], "finished")
        self.assertError("room_closed", service.submit_answer, code, GUEST, 5, 0)
        self.assertError("room_closed", service.submit_answer, code, GUEST, 6, 0)

    def test_retired_room_rejects_future_input(self):
        service, clock, code = self.make(fixture_bank(4))
        self.start(service, clock, code)
        right, _wrong = self.positions(service, code)
        view = service.retire(code, GUEST)
        self.assertEqual(view["state"], "abandoned")
        self.assertEqual(view["retired_by"], GUEST)
        self.assertEqual(view["winner_id"], HOST)
        self.assertError("room_closed", service.submit_answer, code, HOST, 1, right)
        self.assertError("room_closed", service.join_room, code, "late-joiner")
        clock.now += ROUND_MS * 3
        view = service.state(code, HOST)
        self.assertEqual(view["state"], "abandoned")
        self.assertEqual(view["hp"], {HOST: MAX_HP, GUEST: MAX_HP})

    def test_retiring_before_start_has_no_winner(self):
        service, _clock, code = self.make(fixture_bank(4))
        view = service.retire(code, HOST)
        self.assertEqual(view["state"], "abandoned")
        self.assertIsNone(view["winner_id"])

    def test_disconnect_and_rejoin_resyncs_the_same_round(self):
        service, clock, code = self.make(fixture_bank(10))
        self.start(service, clock, code)
        before = service.state(code, GUEST)["round"]
        self.assertFalse(service.disconnect(code, GUEST)["connected"][GUEST])
        clock.now += 2000
        rejoined = service.join_room(code, GUEST)
        self.assertTrue(rejoined["connected"][GUEST])
        self.assertEqual(rejoined["round"], before)
        self.assertEqual(service._room(code).questions_selected, 1)


if __name__ == "__main__":
    unittest.main()
