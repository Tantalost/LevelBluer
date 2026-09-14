import json
from collections import Counter
from pathlib import Path
import unittest

VALID = {"easy", "medium", "hard"}
BANK_PATH = Path(__file__).resolve().parents[2] / "frontend/data/questions.json"


def _questions(bank: dict) -> list[dict]:
    items: list[dict] = []
    for type_row in bank.get("question_types", []):
        items.extend(type_row.get("questions", []))
    return items


class TraceDifficultiesTest(unittest.TestCase):
    def test_every_trace_question_has_one_valid_difficulty(self):
        bank = json.loads(BANK_PATH.read_text(encoding="utf-8"))
        questions = _questions(bank)
        counts = Counter()
        missing = 0
        invalid = 0
        for question in questions:
            value = str(question.get("difficulty", "")).strip().lower()
            if not value:
                missing += 1
                continue
            if value not in VALID:
                invalid += 1
                continue
            counts[value] += 1

        self.assertEqual(len(questions), 80)
        self.assertEqual(missing, 0)
        self.assertEqual(invalid, 0)
        self.assertEqual(sum(counts.values()), 80)
        self.assertEqual(counts["easy"], 25)
        self.assertEqual(counts["medium"], 32)
        self.assertEqual(counts["hard"], 23)


if __name__ == "__main__":
    unittest.main()
