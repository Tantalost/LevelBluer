import json
from pathlib import Path
import unittest

from app.data.pretest_questions import MODULE_BANKS, public_question
from app.services.pretest_grading import is_correct


class PretestFormatsTest(unittest.TestCase):
    def test_bundled_bank_matches_server(self):
        path = Path(__file__).resolve().parents[2] / "frontend/data/pretest_questions.json"
        self.assertEqual(json.loads(path.read_text(encoding="utf-8")), MODULE_BANKS)

    def test_all_formats_and_no_answer_leaks(self):
        for bank in MODULE_BANKS.values():
            self.assertEqual(len(bank), 15)
            self.assertEqual(len({q["id"] for q in bank}), 15)
            self.assertEqual({q["type"] for q in bank}, {"multiple_choice", "true_false", "short_answer"})
            for q in bank:
                public = public_question(q)
                self.assertNotIn("answer", public)
                self.assertNotIn("accepted_answers", public)
                self.assertNotIn("legacy_answer", public)
                self.assertTrue(is_correct(q, q["answer"]))
                self.assertFalse(is_correct(q, None))
                if q["type"] == "short_answer":
                    self.assertTrue(is_correct(q, "  " + q["answer"].upper() + ". "))
                    for alias in q["accepted_answers"]:
                        self.assertTrue(is_correct(q, alias))
                    self.assertTrue(is_correct(q, q["legacy_answer"]))
                    self.assertFalse(is_correct(q, ""))
                    self.assertFalse(is_correct(q, "not " + q["answer"]))
                    self.assertFalse(is_correct(q, "x" * 97))
                elif q["type"] == "true_false":
                    self.assertFalse(is_correct(q, not q["answer"]))
                    self.assertFalse(is_correct(q, str(q["answer"])))
                else:
                    self.assertFalse(is_correct(q, -1))
                    self.assertFalse(is_correct(q, True))


if __name__ == "__main__":
    unittest.main()
