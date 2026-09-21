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
    def _stage(self, stage_number: int) -> dict:
        stages = _load()["stages"]
        matches = [s for s in stages if s["module_id"] == "mod_01" and s["stage"] == stage_number]
        self.assertEqual(len(matches), 1)
        return matches[0]

    def _assert_stage_shape(self, stage: dict, expected_title: str) -> None:
        self.assertEqual(stage["module_id"], "mod_01")
        self.assertEqual(stage["bkt_skill"], "phishing")
        self.assertEqual(stage["title"], expected_title)
        self.assertTrue(stage["opening"])
        self.assertTrue(stage["ending"])
        for line in [*stage["opening"], *stage["ending"], *stage["resume_breach"]]:
            self.assertIn("speaker", line)
            self.assertTrue(str(line["text"]).strip())

    def _assert_three_threats_one_of_each_outcome(self, stage: dict) -> None:
        threats = stage["threats"]
        self.assertEqual(len(threats), 3)
        ids = [threat["id"] for threat in threats]
        self.assertEqual(len(set(ids)), 3)
        for index, threat in enumerate(threats):
            self.assertEqual(threat["module_id"], "mod_01")
            self.assertEqual(threat["stage"], stage["stage"])
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

    def test_module_1_stages_1_and_2_are_decision_based(self):
        data = _load()
        stages = data["stages"]
        self.assertEqual(len(stages), 2)
        self._assert_stage_shape(self._stage(1), "The First Warning")
        self._assert_stage_shape(self._stage(2), "They Know Who We Are")

    def test_stage_1_has_three_threats_with_one_of_each_outcome(self):
        self._assert_three_threats_one_of_each_outcome(self._stage(1))

    def test_stage_2_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(2)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.65)

    def test_threat_topics_match_the_brief(self):
        threats = self._stage(1)["threats"]
        self.assertIn("Suspension", threats[0]["title"])
        self.assertIn("Invoice", threats[1]["title"])
        self.assertIn("Password Reset", threats[2]["title"])
        self.assertEqual(threats[0]["choices"][0]["outcome"], "CRITICAL")
        self.assertEqual(threats[0]["choices"][1]["outcome"], "SAFE")
        self.assertEqual(threats[0]["choices"][2]["outcome"], "RISKY")
        self.assertEqual(threats[1]["choices"][0]["outcome"], "CRITICAL")
        self.assertEqual(threats[1]["choices"][1]["outcome"], "SAFE")
        self.assertEqual(threats[1]["choices"][2]["outcome"], "RISKY")

    def test_stage_2_threat_topics_match_the_brief(self):
        threats = self._stage(2)["threats"]
        self.assertIn("Meeting Follow-Up", threats[0]["title"])
        self.assertIn("HR Benefits Update", threats[1]["title"])
        self.assertIn("Manager Access Request", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_2_does_not_duplicate_stage_1_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        self.assertTrue(stage1_ids.isdisjoint(stage2_ids))

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
        decision_ids = {
            threat["id"]
            for stage in _load()["stages"]
            for threat in stage["threats"]
        }
        self.assertTrue(trace_ids.isdisjoint(decision_ids))


if __name__ == "__main__":
    unittest.main()
