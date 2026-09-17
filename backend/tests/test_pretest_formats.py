import json
from pathlib import Path
import unittest

from app.data.pretest_questions import MODULE_BANKS, MODULE_IDS, public_question
from app.services.pretest_grading import is_correct


class PretestFormatsTest(unittest.TestCase):
    def test_bundled_bank_matches_server(self):
        path = Path(__file__).resolve().parents[2] / "frontend/data/pretest_questions.json"
        self.assertEqual(json.loads(path.read_text(encoding="utf-8")), MODULE_BANKS)

    def test_banks_are_identical_multiple_choice(self):
        path = Path(__file__).resolve().parents[2] / "frontend/data/pretest_questions.json"
        frontend = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(list(MODULE_BANKS.keys()), list(MODULE_IDS))
        self.assertEqual(list(frontend.keys()), list(MODULE_IDS))
        self.assertEqual(len(MODULE_BANKS), 5)
        self.assertEqual(len(frontend), 5)

        backend_mc = 0
        frontend_mc = 0
        backend_sa = 0
        frontend_sa = 0
        mismatches = 0
        seen_ids: set[tuple[str, int]] = set()

        for module_id in MODULE_IDS:
            backend_bank = MODULE_BANKS[module_id]
            frontend_bank = frontend[module_id]
            self.assertEqual(len(backend_bank), 15)
            self.assertEqual(len(frontend_bank), 15)
            self.assertEqual(len({q["id"] for q in backend_bank}), 15)
            self.assertEqual([q["id"] for q in backend_bank], [q["id"] for q in frontend_bank])
            for backend_q, frontend_q in zip(backend_bank, frontend_bank):
                pair = (module_id, int(backend_q["id"]))
                self.assertNotIn(pair, seen_ids)
                seen_ids.add(pair)
                self.assertEqual(backend_q["type"], "multiple_choice")
                self.assertEqual(frontend_q["type"], "multiple_choice")
                self.assertEqual(len(backend_q["options"]), 4)
                self.assertEqual(len(frontend_q["options"]), 4)
                self.assertIsInstance(backend_q["answer"], int)
                self.assertIn(backend_q["answer"], (0, 1, 2, 3))
                backend_mc += 1
                frontend_mc += 1
                if backend_q["type"] == "short_answer":
                    backend_sa += 1
                if frontend_q["type"] == "short_answer":
                    frontend_sa += 1
                for field in ("topic", "type", "text", "options", "answer"):
                    if backend_q[field] != frontend_q[field]:
                        mismatches += 1
                public = public_question(backend_q)
                self.assertEqual(set(public), {"id", "topic", "type", "text", "options"})
                self.assertNotIn("answer", public)
                self.assertNotIn("difficulty", public)
                self.assertNotIn("skill", public)
                self.assertTrue(is_correct(backend_q, backend_q["answer"]))
                self.assertFalse(is_correct(backend_q, None))
                self.assertFalse(is_correct(backend_q, -1))
                self.assertFalse(is_correct(backend_q, True))

        self.assertEqual(len(seen_ids), 75)
        self.assertEqual(backend_mc, 75)
        self.assertEqual(frontend_mc, 75)
        self.assertEqual(backend_sa, 0)
        self.assertEqual(frontend_sa, 0)
        self.assertEqual(mismatches, 0)


class Module4PretestCoverageTest(unittest.TestCase):
    def test_module_4_pretexting_bank(self):
        path = Path(__file__).resolve().parents[2] / "frontend/data/pretest_questions.json"
        frontend = json.loads(path.read_text(encoding="utf-8"))
        bank = MODULE_BANKS["mod_04"]
        self.assertEqual(frontend["mod_04"], bank)
        self.assertEqual(len(bank), 15)
        self.assertEqual([q["id"] for q in bank], list(range(1, 16)))
        self.assertEqual([q["answer"] for q in bank], [3, 1, 0, 2, 1, 3, 0, 2, 3, 1, 0, 2, 1, 3, 2])
        self.assertEqual([q["answer"] for q in bank].count(0), 3)
        self.assertEqual([q["answer"] for q in bank].count(1), 4)
        self.assertEqual([q["answer"] for q in bank].count(2), 4)
        self.assertEqual([q["answer"] for q in bank].count(3), 4)
        self.assertEqual([q["difficulty"] for q in bank].count("easy"), 4)
        self.assertEqual([q["difficulty"] for q in bank].count("medium"), 7)
        self.assertEqual([q["difficulty"] for q in bank].count("hard"), 4)
        for question in bank:
            self.assertEqual(question["topic"], "Pretexting")
            self.assertEqual(question["type"], "multiple_choice")
            self.assertEqual(len(question["options"]), 4)
            self.assertIn(question["difficulty"], {"easy", "medium", "hard"})
            self.assertTrue(str(question.get("skill", "")).strip())


class Module5PretestCoverageTest(unittest.TestCase):
    def test_module_5_baiting_bank(self):
        path = Path(__file__).resolve().parents[2] / "frontend/data/pretest_questions.json"
        frontend = json.loads(path.read_text(encoding="utf-8"))
        bank = MODULE_BANKS["mod_05"]
        self.assertEqual(frontend["mod_05"], bank)
        self.assertEqual(len(bank), 15)
        self.assertEqual([q["id"] for q in bank], list(range(1, 16)))
        self.assertEqual([q["answer"] for q in bank], [2, 0, 3, 1, 2, 1, 0, 3, 2, 1, 0, 3, 1, 2, 3])
        self.assertEqual([q["answer"] for q in bank].count(0), 3)
        self.assertEqual([q["answer"] for q in bank].count(1), 4)
        self.assertEqual([q["answer"] for q in bank].count(2), 4)
        self.assertEqual([q["answer"] for q in bank].count(3), 4)
        self.assertEqual([q["difficulty"] for q in bank].count("easy"), 4)
        self.assertEqual([q["difficulty"] for q in bank].count("medium"), 7)
        self.assertEqual([q["difficulty"] for q in bank].count("hard"), 4)
        expected_skills = [
            "recognition",
            "unknown_media",
            "gift_bait",
            "suspicious_download",
            "qr_safety",
            "file_extension",
            "temptation",
            "safe_handling",
            "source_verification",
            "charging_safety",
            "attacker_goal",
            "multi_cue_analysis",
            "scarcity_bait",
            "trusted_download",
            "transfer",
        ]
        self.assertEqual([q["skill"] for q in bank], expected_skills)
        for question in bank:
            self.assertEqual(question["topic"], "Baiting")
            self.assertEqual(question["type"], "multiple_choice")
            self.assertEqual(len(question["options"]), 4)
            self.assertIn(question["difficulty"], {"easy", "medium", "hard"})
            public = public_question(question)
            self.assertNotIn("skill", public)
            self.assertNotIn("answer", public)
            self.assertEqual(public["topic"], "Baiting")


if __name__ == "__main__":
    unittest.main()
