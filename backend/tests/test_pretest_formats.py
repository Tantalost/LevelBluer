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


if __name__ == "__main__":
    unittest.main()
