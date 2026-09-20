import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
DATA_PATH = ROOT / "frontend/data/decision_scenarios.json"
BANK_PATH = ROOT / "frontend/data/questions.json"
OUTCOMES = {"SAFE", "RISKY", "CRITICAL"}


def _load() -> dict:
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


class DecisionScenarioDataTest(unittest.TestCase):
    def test_only_module_1_stage_1_is_decision_based(self):
        data = _load()
        stages = data["stages"]
        self.assertEqual(len(stages), 1)
        stage = stages[0]
        self.assertEqual(stage["module_id"], "mod_01")
        self.assertEqual(stage["stage"], 1)
        self.assertEqual(stage["bkt_skill"], "phishing")
        self.assertEqual(stage["title"], "The First Warning")
        self.assertTrue(stage["opening"])
        self.assertTrue(stage["ending"])
        for line in [*stage["opening"], *stage["ending"], *stage["resume_breach"]]:
            self.assertIn("speaker", line)
            self.assertTrue(str(line["text"]).strip())

    def test_stage_1_has_three_threats_with_one_of_each_outcome(self):
        stage = _load()["stages"][0]
        threats = stage["threats"]
        self.assertEqual(len(threats), 3)
        ids = [threat["id"] for threat in threats]
        self.assertEqual(len(set(ids)), 3)
        for index, threat in enumerate(threats):
            self.assertEqual(threat["module_id"], "mod_01")
            self.assertEqual(threat["stage"], 1)
            self.assertEqual(threat["bkt_skill"], "phishing")
            self.assertTrue(threat["title"].strip())
            self.assertTrue(threat["situation"].strip())
            self.assertTrue(threat["explanation"].strip())
            self.assertTrue(threat["story"])
            self.assertTrue(threat["evidence"])
            self.assertGreater(int(threat["breach_gold"]), 0)
            choices = threat["choices"]
            self.assertEqual(len(choices), 3)
            outcomes = [choice["outcome"] for choice in choices]
            self.assertEqual(set(outcomes), OUTCOMES)
            for choice in choices:
                self.assertTrue(choice["label"].strip())
                self.assertTrue(choice["consequence"].strip())
            expected_next = threats[index + 1]["id"] if index + 1 < len(threats) else ""
            self.assertEqual(threat["next"], expected_next)

    def test_threat_topics_match_the_brief(self):
        threats = _load()["stages"][0]["threats"]
        self.assertIn("Suspension", threats[0]["title"])
        self.assertIn("Invoice", threats[1]["title"])
        self.assertIn("Password Reset", threats[2]["title"])
        self.assertEqual(threats[0]["choices"][0]["outcome"], "CRITICAL")
        self.assertEqual(threats[0]["choices"][1]["outcome"], "SAFE")
        self.assertEqual(threats[0]["choices"][2]["outcome"], "RISKY")
        self.assertEqual(threats[1]["choices"][0]["outcome"], "CRITICAL")
        self.assertEqual(threats[1]["choices"][1]["outcome"], "SAFE")
        self.assertEqual(threats[1]["choices"][2]["outcome"], "RISKY")

    def test_decision_data_is_isolated_from_trace_bank(self):
        bank = json.loads(BANK_PATH.read_text(encoding="utf-8"))
        total = sum(
            len(type_row["questions"])
            for module in bank["modules"]
            for type_row in module["question_types"]
        )
        self.assertEqual(total, 400)
        self.assertNotIn("stages", bank)
        trace_ids = {
            question["id"]
            for module in bank["modules"]
            for type_row in module["question_types"]
            for question in type_row["questions"]
        }
        decision_ids = {threat["id"] for threat in _load()["stages"][0]["threats"]}
        self.assertTrue(trace_ids.isdisjoint(decision_ids))


if __name__ == "__main__":
    unittest.main()
