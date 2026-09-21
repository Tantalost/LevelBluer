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
        self.assertEqual(len(stages), 9)
        self._assert_stage_shape(self._stage(1), "The First Warning")
        self._assert_stage_shape(self._stage(2), "They Know Who We Are")
        self._assert_stage_shape(self._stage(3), "Someone Got In")
        self._assert_stage_shape(self._stage(4), "The Impostor Inside")
        self._assert_stage_shape(self._stage(5), "The Second Key")
        self._assert_stage_shape(self._stage(6), "Trusted Files")
        self._assert_stage_shape(self._stage(7), "Trusted Supplier")
        self._assert_stage_shape(self._stage(8), "All Hands")
        self._assert_stage_shape(self._stage(9), "Cut the Line")

    def test_module_1_stage_9_is_the_final_story_stage_with_a_finale(self):
        stage9 = self._stage(9)
        finale = stage9.get("finale", {})
        self.assertTrue(finale.get("enabled"))
        self.assertEqual(finale.get("type"), "tower_defense")
        self.assertEqual(finale.get("enemy_hp_multiplier"), 1.0)
        self.assertTrue(finale.get("ending"))
        self.assertTrue(finale.get("closing"))
        summary = finale.get("case_summary", {})
        self.assertTrue(summary.get("title"))
        self.assertTrue(summary.get("items"))
        for stage_number in (1, 2, 3, 4, 5, 6, 7, 8):
            self.assertNotIn("finale", self._stage(stage_number), "Only Stage 9 authors a finale")

    def test_stage_1_has_three_threats_with_one_of_each_outcome(self):
        self._assert_three_threats_one_of_each_outcome(self._stage(1))

    def test_stage_2_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(2)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.65)

    def test_stage_3_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(3)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.7)

    def test_stage_4_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(4)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.75)

    def test_stage_5_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(5)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.8)

    def test_stage_6_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(6)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.85)

    def test_stage_7_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(7)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.9)

    def test_stage_8_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(8)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 0.95)

    def test_stage_9_has_three_threats_with_one_of_each_outcome(self):
        stage = self._stage(9)
        self._assert_three_threats_one_of_each_outcome(stage)
        self.assertEqual(stage["breach_hp_multiplier"], 1.0)

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

    def test_stage_3_threat_topics_match_the_brief(self):
        threats = self._stage(3)["threats"]
        self.assertIn("Compromised Colleague", threats[0]["title"])
        self.assertIn("Session Left Open", threats[1]["title"])
        self.assertIn("Second Invite", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_4_threat_topics_match_the_brief(self):
        threats = self._stage(4)["threats"]
        self.assertIn("Payroll Change", threats[0]["title"])
        self.assertIn("Confidential Folder Access", threats[1]["title"])
        self.assertIn("Emergency Security Request", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_5_threat_topics_match_the_brief(self):
        threats = self._stage(5)["threats"]
        self.assertIn("Unexpected MFA Prompt", threats[0]["title"])
        self.assertIn("Password Reset Isn't Enough", threats[1]["title"])
        self.assertIn("Session Expired", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_6_threat_topics_match_the_brief(self):
        threats = self._stage(6)["threats"]
        self.assertIn("Shared Proposal", threats[0]["title"])
        self.assertIn("Collaboration App Access", threats[1]["title"])
        self.assertIn("Secure Document QR", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_6_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore the warning",
            r"ignore everything",
            r"open anything immediately",
            r"ignore it",
            r"looks safe",
        ]
        for threat in self._stage(6)["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_stage_7_threat_topics_match_the_brief(self):
        threats = self._stage(7)["threats"]
        self.assertIn("Updated Bank Details", threats[0]["title"])
        self.assertIn("Purchase Order", threats[1]["title"])
        self.assertIn("Executive Payment Request", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_7_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"send money immediately",
            r"ignore the supplier",
            r"trust it because it looks real",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
        ]
        for threat in self._stage(7)["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_stage_8_threat_topics_match_the_brief(self):
        threats = self._stage(8)["threats"]
        self.assertIn("Emergency Security Update", threats[0]["title"])
        self.assertIn("Compromised Employee", threats[1]["title"])
        self.assertIn("The Attacker's Exit", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_8_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"ignore everything",
            r"do nothing",
            r"give access",
            r"trust the attacker",
            r"ignore it",
            r"looks safe",
        ]
        for threat in self._stage(8)["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_stage_9_threat_topics_match_the_brief(self):
        threats = self._stage(9)["threats"]
        self.assertIn("Active Session", threats[0]["title"])
        self.assertIn("Hidden Forwarding Rule", threats[1]["title"])
        self.assertIn("Final Connection", threats[2]["title"])
        for threat in threats:
            self.assertEqual(threat["choices"][0]["outcome"], "CRITICAL")
            self.assertEqual(threat["choices"][1]["outcome"], "SAFE")
            self.assertEqual(threat["choices"][2]["outcome"], "RISKY")

    def test_stage_9_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"ignore everything",
            r"do nothing",
            r"give access",
            r"trust the attacker",
            r"ignore it",
            r"looks safe",
        ]
        for threat in self._stage(9)["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_stage_2_does_not_duplicate_stage_1_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        self.assertTrue(stage1_ids.isdisjoint(stage2_ids))

    def test_stage_3_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        self.assertTrue(stage3_ids.isdisjoint(stage1_ids | stage2_ids))

    def test_stage_4_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        stage4_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        self.assertTrue(stage4_ids.isdisjoint(stage1_ids | stage2_ids | stage3_ids))

    def test_stage_5_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        stage4_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        stage5_ids = {threat["id"] for threat in self._stage(5)["threats"]}
        self.assertTrue(stage5_ids.isdisjoint(stage1_ids | stage2_ids | stage3_ids | stage4_ids))

    def test_stage_6_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        stage4_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        stage5_ids = {threat["id"] for threat in self._stage(5)["threats"]}
        stage6_ids = {threat["id"] for threat in self._stage(6)["threats"]}
        self.assertTrue(stage6_ids.isdisjoint(stage1_ids | stage2_ids | stage3_ids | stage4_ids | stage5_ids))

    def test_stage_7_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        stage4_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        stage5_ids = {threat["id"] for threat in self._stage(5)["threats"]}
        stage6_ids = {threat["id"] for threat in self._stage(6)["threats"]}
        stage7_ids = {threat["id"] for threat in self._stage(7)["threats"]}
        self.assertTrue(stage7_ids.isdisjoint(stage1_ids | stage2_ids | stage3_ids | stage4_ids | stage5_ids | stage6_ids))

    def test_stage_8_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        stage4_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        stage5_ids = {threat["id"] for threat in self._stage(5)["threats"]}
        stage6_ids = {threat["id"] for threat in self._stage(6)["threats"]}
        stage7_ids = {threat["id"] for threat in self._stage(7)["threats"]}
        stage8_ids = {threat["id"] for threat in self._stage(8)["threats"]}
        self.assertTrue(stage8_ids.isdisjoint(stage1_ids | stage2_ids | stage3_ids | stage4_ids | stage5_ids | stage6_ids | stage7_ids))

    def test_stage_9_does_not_duplicate_earlier_stage_ids(self):
        stage1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        stage2_ids = {threat["id"] for threat in self._stage(2)["threats"]}
        stage3_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        stage4_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        stage5_ids = {threat["id"] for threat in self._stage(5)["threats"]}
        stage6_ids = {threat["id"] for threat in self._stage(6)["threats"]}
        stage7_ids = {threat["id"] for threat in self._stage(7)["threats"]}
        stage8_ids = {threat["id"] for threat in self._stage(8)["threats"]}
        stage9_ids = {threat["id"] for threat in self._stage(9)["threats"]}
        self.assertTrue(stage9_ids.isdisjoint(
            stage1_ids | stage2_ids | stage3_ids | stage4_ids | stage5_ids | stage6_ids | stage7_ids | stage8_ids
        ))

    def test_module_1_has_exactly_nine_story_stages_before_the_post_assessment(self):
        module_1_stage_numbers = sorted(s["stage"] for s in _load()["stages"] if s["module_id"] == "mod_01")
        self.assertEqual(module_1_stage_numbers, list(range(1, 10)))

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
