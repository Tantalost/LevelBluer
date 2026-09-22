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
    def _stage(self, stage_number: int, module_id: str = "mod_01") -> dict:
        stages = _load()["stages"]
        matches = [s for s in stages if s["module_id"] == module_id and s["stage"] == stage_number]
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

    def _assert_module2_four_choice_threats(self, stage: dict) -> None:
        threats = stage["threats"]
        self.assertEqual(len(threats), 3)
        ids = [threat["id"] for threat in threats]
        self.assertEqual(len(set(ids)), 3)
        for index, threat in enumerate(threats):
            self.assertEqual(threat["module_id"], "mod_02")
            self.assertEqual(threat["stage"], stage["stage"])
            self.assertEqual(threat["bkt_skill"], "smishing")
            self.assertTrue(threat["title"].strip())
            self.assertTrue(threat["situation"].strip())
            self.assertTrue(threat["explanation"].strip())
            self.assertTrue(threat["story"])
            self.assertTrue(threat["evidence"])
            self.assertGreater(int(threat["breach_gold"]), 0)
            choices = threat["choices"]
            self.assertEqual(len(choices), 4)
            outcomes = [choice["outcome"] for choice in choices]
            self.assertEqual(outcomes.count("SAFE"), 1)
            self.assertEqual(outcomes.count("RISKY"), 2)
            self.assertEqual(outcomes.count("CRITICAL"), 1)
            risky_labels = [choice["label"] for choice in choices if choice["outcome"] == "RISKY"]
            self.assertEqual(len(risky_labels), 2)
            self.assertNotEqual(risky_labels[0], risky_labels[1])
            for choice in choices:
                self.assertTrue(choice["label"].strip())
                self.assertTrue(choice["consequence"].strip())
            expected_next = threats[index + 1]["id"] if index + 1 < len(threats) else ""
            self.assertEqual(threat["next"], expected_next)

    def test_module_1_stages_1_and_2_are_decision_based(self):
        data = _load()
        module_1_stages = [s for s in data["stages"] if s["module_id"] == "mod_01"]
        self.assertEqual(len(module_1_stages), 9)
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

    def test_module_2_stage_1_is_decision_based_with_the_new_four_choice_format(self):
        stage = self._stage(1, module_id="mod_02")
        self.assertEqual(stage["title"], "Unknown Number")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.65)
        self.assertTrue(stage["opening"])
        self.assertTrue(stage["ending"])
        for line in [*stage["opening"], *stage["ending"], *stage["resume_breach"]]:
            self.assertIn("speaker", line)
            self.assertTrue(str(line["text"]).strip())

    def test_module_2_stage_1_has_three_incidents_with_four_choices_each(self):
        self._assert_module2_four_choice_threats(self._stage(1, module_id="mod_02"))

    def test_module_2_stage_1_threat_topics_match_the_brief(self):
        threats = self._stage(1, module_id="mod_02")["threats"]
        self.assertIn("Mobile Account Warning", threats[0]["title"])
        self.assertIn("Transaction Alert", threats[1]["title"])
        self.assertIn("Support Follow-Up", threats[2]["title"])

    def test_module_2_stage_1_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(1, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_2_is_expected_delivery_with_four_choice_incidents(self):
        stage = self._stage(2, module_id="mod_02")
        self.assertEqual(stage["title"], "Expected Delivery")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.70)
        self.assertEqual(stage["clear_title"], "STAGE 2 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "EXPECTED DELIVERY")
        self.assertIn("Stage 3", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_2_topics_and_cliffhanger_match_the_brief(self):
        stage = self._stage(2, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Delivery Delayed", "Redelivery Fee", "Proof of Delivery"],
        )
        self.assertIn("The package is here", " ".join(line["text"] for line in threats[2]["story"]))
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("This one's from you", ending)
        self.assertIn("I didn't send you anything", ending)

    def test_module_2_stage_2_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust blindly",
            r"pay immediately",
        ]
        for threat in self._stage(2, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_2_ids_are_isolated_from_stage_1(self):
        stage1 = self._stage(1, module_id="mod_02")
        stage2 = self._stage(2, module_id="mod_02")
        stage1_ids = {threat["id"] for threat in stage1["threats"]}
        stage2_ids = {threat["id"] for threat in stage2["threats"]}
        self.assertTrue(stage1_ids.isdisjoint(stage2_ids))
        self.assertNotEqual(stage1["id"], stage2["id"])

    def test_module_1_and_module_2_stage_1_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(1, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(1)["id"], self._stage(1, module_id="mod_02")["id"])

    def test_module_2_stage_3_is_someone_you_know_with_four_choice_incidents(self):
        stage = self._stage(3, module_id="mod_02")
        self.assertEqual(stage["title"], "Someone You Know")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.75)
        self.assertEqual(stage["clear_title"], "STAGE 3 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "SOMEONE YOU KNOW")
        self.assertIn("Stage 4", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_3_topics_and_continuity_match_the_brief(self):
        stage = self._stage(3, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["New Number", "I Need a Favor", "Family Emergency"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("This one's from you", opening)
        self.assertIn("I didn't send you anything", opening)
        self.assertIn("Mims", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("They used my mother", ending)
        self.assertIn("verification code", ending)

    def test_module_2_stage_3_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(3, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_3_ids_are_isolated_from_stages_1_and_2(self):
        stage1 = self._stage(1, module_id="mod_02")
        stage2 = self._stage(2, module_id="mod_02")
        stage3 = self._stage(3, module_id="mod_02")
        stage1_ids = {threat["id"] for threat in stage1["threats"]}
        stage2_ids = {threat["id"] for threat in stage2["threats"]}
        stage3_ids = {threat["id"] for threat in stage3["threats"]}
        self.assertTrue(stage3_ids.isdisjoint(stage1_ids | stage2_ids))
        self.assertNotEqual(stage2["id"], stage3["id"])

    def test_module_1_and_module_2_stage_3_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(3)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(3, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(3)["id"], self._stage(3, module_id="mod_02")["id"])

    def test_module_2_stage_4_is_the_code_with_four_choice_incidents(self):
        stage = self._stage(4, module_id="mod_02")
        self.assertEqual(stage["title"], "The Code")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.8)
        self.assertEqual(stage["clear_title"], "STAGE 4 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "THE CODE")
        self.assertIn("Stage 5", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_4_topics_and_continuity_match_the_brief(self):
        stage = self._stage(4, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Unrequested Code", "Cancel the Request", "Recovery Race"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("It's a verification code", opening)
        self.assertIn("The code can be real", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("recovery number was changed", ending)
        self.assertIn("I'm locked out", ending)
        self.assertIn("First, we find out what they changed", ending)

    def test_module_2_stage_4_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(4, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_4_ids_are_isolated_from_stages_1_2_3(self):
        stage1 = self._stage(1, module_id="mod_02")
        stage2 = self._stage(2, module_id="mod_02")
        stage3 = self._stage(3, module_id="mod_02")
        stage4 = self._stage(4, module_id="mod_02")
        stage1_ids = {threat["id"] for threat in stage1["threats"]}
        stage2_ids = {threat["id"] for threat in stage2["threats"]}
        stage3_ids = {threat["id"] for threat in stage3["threats"]}
        stage4_ids = {threat["id"] for threat in stage4["threats"]}
        self.assertTrue(stage4_ids.isdisjoint(stage1_ids | stage2_ids | stage3_ids))
        self.assertNotEqual(stage3["id"], stage4["id"])

    def test_module_1_and_module_2_stage_4_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(4)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(4, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(4)["id"], self._stage(4, module_id="mod_02")["id"])

    def test_module_2_stage_4_safe_playthrough_still_reaches_lockout_ending(self):
        # The lockout is a story escalation revealing an attacker foothold from
        # elsewhere, not a punishment for correct SAFE decisions — so the ending
        # content itself (not tied to any particular choice path) must contain
        # the lockout beat regardless of which choices a player made.
        stage = self._stage(4, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("logged me out", ending)
        self.assertIn("I'm locked out", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_5_is_locked_out_with_four_choice_incidents(self):
        stage = self._stage(5, module_id="mod_02")
        self.assertEqual(stage["title"], "Locked Out")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.85)
        self.assertEqual(stage["clear_title"], "STAGE 5 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "LOCKED OUT")
        self.assertIn("Stage 6", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_5_topics_and_continuity_match_the_brief(self):
        stage = self._stage(5, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Recovery Contact Changed", "Messages From Me", "Prove You're You"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("Try it again", opening)
        self.assertIn("They changed the recovery path", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("I'm back in", ending)
        self.assertIn("I have no signal", ending)
        self.assertIn("No Service", ending)
        self.assertNotIn("SIM swap", ending)

    def test_module_2_stage_5_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(5, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_5_ids_are_isolated_from_stages_1_2_3_4(self):
        stage1 = self._stage(1, module_id="mod_02")
        stage2 = self._stage(2, module_id="mod_02")
        stage3 = self._stage(3, module_id="mod_02")
        stage4 = self._stage(4, module_id="mod_02")
        stage5 = self._stage(5, module_id="mod_02")
        earlier_ids = {
            threat["id"]
            for stage in (stage1, stage2, stage3, stage4)
            for threat in stage["threats"]
        }
        stage5_ids = {threat["id"] for threat in stage5["threats"]}
        self.assertTrue(stage5_ids.isdisjoint(earlier_ids))
        self.assertNotEqual(stage4["id"], stage5["id"])

    def test_module_1_and_module_2_stage_5_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(5)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(5, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(5)["id"], self._stage(5, module_id="mod_02")["id"])

    def test_module_2_stage_5_story_contains_impersonation_and_leaves_entry_point_uncertain(self):
        stage = self._stage(5, module_id="mod_02")
        threats = stage["threats"]
        incident2_story = " ".join(line["text"] for line in threats[1]["story"])
        incident3_story = " ".join(line["text"] for line in threats[2]["story"])
        self.assertIn("asking everyone for money", incident2_story)
        self.assertIn("talking to my family as me", incident2_story)
        self.assertIn("We still don't know that's how they got in", incident3_story)
        self.assertIn("we may leave the real one open", incident3_story)
        forbidden_blame_phrases = [
            "the click caused",
            "the click was how they got in",
            "that click let them in",
            "confirmed the entry point was",
        ]
        for phrase in forbidden_blame_phrases:
            self.assertNotIn(phrase, incident3_story.lower())

    def test_module_2_stage_5_safe_playthrough_still_includes_guilt_dialogue(self):
        # Leah's guilt over her Stage 1 click is story content shown regardless
        # of the player's choices — it must not be tied to a RISKY/CRITICAL path.
        stage = self._stage(5, module_id="mod_02")
        incident3_story = " ".join(line["text"] for line in stage["threats"][2]["story"])
        self.assertIn("I clicked one message four stages ago", incident3_story)
        self.assertIn("But it's my name", incident3_story)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_6_is_no_signal_with_four_choice_incidents(self):
        stage = self._stage(6, module_id="mod_02")
        self.assertEqual(stage["title"], "No Signal")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.9)
        self.assertEqual(stage["clear_title"], "STAGE 6 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "NO SIGNAL")
        self.assertIn("Stage 7", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_6_topics_and_continuity_match_the_brief(self):
        stage = self._stage(6, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["New SIM", "Codes Somewhere Else", "Fraud Team"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("It still says No Service", opening)
        self.assertIn("eSIM activation", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("I have service", ending)
        self.assertIn("Before the first text", ending)
        self.assertIn("Because now I'm angry", ending)
        self.assertIn("wasn't the only target", ending)
        self.assertNotIn("SIM swap", ending)

    def test_module_2_stage_6_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(6, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_6_ids_are_isolated_from_stages_1_through_5(self):
        stages = [self._stage(n, module_id="mod_02") for n in range(1, 6)]
        stage6 = self._stage(6, module_id="mod_02")
        earlier_ids = {
            threat["id"] for stage in stages for threat in stage["threats"]
        }
        stage6_ids = {threat["id"] for threat in stage6["threats"]}
        self.assertTrue(stage6_ids.isdisjoint(earlier_ids))
        self.assertNotEqual(stages[-1]["id"], stage6["id"])

    def test_module_1_and_module_2_stage_6_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(6)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(6, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(6)["id"], self._stage(6, module_id="mod_02")["id"])

    def test_module_2_stage_6_esim_content_and_no_overclaim(self):
        stage = self._stage(6, module_id="mod_02")
        opening = " ".join(line["text"] for line in stage["opening"])
        incident1_story = " ".join(line["text"] for line in stage["threats"][0]["story"])
        self.assertIn("eSIM", opening)
        self.assertIn("eSIM", incident1_story)
        all_text = " ".join(
            line["text"] for line in stage["opening"] + stage["ending"]
        ) + " " + " ".join(
            line["text"] for threat in stage["threats"] for line in threat["story"]
        )
        overclaim_phrases = [
            "every account was compromised",
            "automatically compromised",
            "controlled every account",
        ]
        for phrase in overclaim_phrases:
            self.assertNotIn(phrase, all_text.lower())

    def test_module_2_stage_6_safe_playthrough_still_reaches_the_ramon_reveal(self):
        # The Ramon/predates-Stage-1 revelations are story content shown after
        # Incident 3 regardless of the player's choices throughout the stage.
        stage = self._stage(6, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("Before the first text", ending)
        self.assertIn("Ramon", ending)
        self.assertIn("wasn't the only target", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_7_is_not_just_leah_with_four_choice_incidents(self):
        stage = self._stage(7, module_id="mod_02")
        self.assertEqual(stage["title"], "Not Just Leah")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.95)
        self.assertEqual(stage["clear_title"], "STAGE 7 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "NOT JUST LEAH")
        self.assertIn("Stage 8", stage["next_stage_title"])
        self.assertIn("Close to Home", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_7_topics_and_continuity_match_the_brief(self):
        stage = self._stage(7, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Same Problem", "Third Name", "BlueTech Security"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("His phone still has no service", opening)
        self.assertIn("Leah may not be the only person being targeted", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("Every one of them is directly connected to someone who does", ending)
        self.assertIn("hitting everyone they found", ending)

    def test_module_2_stage_7_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(7, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_7_ids_are_isolated_from_stages_1_through_6(self):
        stages = [self._stage(n, module_id="mod_02") for n in range(1, 7)]
        stage7 = self._stage(7, module_id="mod_02")
        earlier_ids = {
            threat["id"] for stage in stages for threat in stage["threats"]
        }
        stage7_ids = {threat["id"] for threat in stage7["threats"]}
        self.assertTrue(stage7_ids.isdisjoint(earlier_ids))
        self.assertNotEqual(stages[-1]["id"], stage7["id"])

    def test_module_1_and_module_2_stage_7_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(7)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(7, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(7)["id"], self._stage(7, module_id="mod_02")["id"])

    def test_module_2_stage_7_paolo_is_introduced_as_ramons_brother_not_bluetech(self):
        stage = self._stage(7, module_id="mod_02")
        incident1_story = " ".join(line["text"] for line in stage["threats"][0]["story"])
        incident2_story = " ".join(line["text"] for line in stage["threats"][1]["story"])
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("Paolo", incident1_story)
        self.assertIn("keep your brother on Wi-Fi", opening)
        self.assertIn("does not work for BlueTech", incident2_story + stage["threats"][1]["situation"])

    def test_module_2_stage_7_establishes_three_victims_and_bluetech_link(self):
        stage = self._stage(7, module_id="mod_02")
        incident2_story = " ".join(line["text"] for line in stage["threats"][1]["story"])
        self.assertIn("Three people", incident2_story)
        self.assertIn("None of the three known victims", stage["threats"][1]["situation"])
        self.assertIn("BlueTech", incident2_story)

    def test_module_2_stage_7_incident_3_uses_fake_bluetech_security_sms(self):
        stage = self._stage(7, module_id="mod_02")
        incident3 = stage["threats"][2]
        incident3_story = " ".join(line["text"] for line in incident3["story"])
        self.assertIn("BLUETECH SECURITY", incident3_story)
        combined_text = " ".join(choice["consequence"] for choice in incident3["choices"]) + incident3["explanation"]
        self.assertTrue(
            "doesn't prove" in combined_text or "does not prove" in combined_text
        )

    def test_module_2_stage_7_does_not_reveal_ultimate_motive(self):
        stage = self._stage(7, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("I don't know", ending)
        motive_leak_phrases = [
            "because bluetech",
            "in order to steal",
            "their ultimate goal is",
            "the reason bluetech is being targeted is",
        ]
        for phrase in motive_leak_phrases:
            self.assertNotIn(phrase, ending.lower())

    def test_module_2_stage_7_safe_playthrough_still_reaches_the_major_reveal(self):
        # The BlueTech-link reveal and coordinated-wave cliffhanger are story
        # content shown regardless of the player's choices throughout the stage.
        stage = self._stage(7, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("Every one of them is directly connected to someone who does", ending)
        self.assertIn("hitting everyone they found", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_8_is_close_to_home_with_four_choice_incidents(self):
        stage = self._stage(8, module_id="mod_02")
        self.assertEqual(stage["title"], "Close to Home")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 1.0)
        self.assertEqual(stage["clear_title"], "STAGE 8 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "CLOSE TO HOME")
        self.assertIn("Stage 9", stage["next_stage_title"])
        self.assertIn("Trust No Number", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_8_topics_and_continuity_match_the_brief(self):
        stage = self._stage(8, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["She Needs Your Help", "Your Brother Is Compromised", "Family Emergency"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("Multiple phones begin vibrating", opening)
        self.assertIn("and their families another", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("Leverage against the employees", ending)
        self.assertIn("Recovery authority", ending)
        self.assertIn("Not a personal one", ending)

    def test_module_2_stage_8_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(8, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_8_ids_are_isolated_from_stages_1_through_7(self):
        stages = [self._stage(n, module_id="mod_02") for n in range(1, 8)]
        stage8 = self._stage(8, module_id="mod_02")
        earlier_ids = {
            threat["id"] for stage in stages for threat in stage["threats"]
        }
        stage8_ids = {threat["id"] for threat in stage8["threats"]}
        self.assertTrue(stage8_ids.isdisjoint(earlier_ids))
        self.assertNotEqual(stages[-1]["id"], stage8["id"])

    def test_module_1_and_module_2_stage_8_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(8)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(8, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(8)["id"], self._stage(8, module_id="mod_02")["id"])

    def test_module_2_stage_8_incident_1_uses_mirrored_mia_leah_manipulation(self):
        stage = self._stage(8, module_id="mod_02")
        incident1_story = " ".join(line["text"] for line in stage["threats"][0]["story"])
        self.assertIn("do not contact her directly", incident1_story)
        self.assertIn("Do not contact her until", incident1_story)

    def test_module_2_stage_8_incident_2_uses_ramon_paolo_cross_validation_with_real_otp(self):
        stage = self._stage(8, module_id="mod_02")
        incident2 = stage["threats"][1]
        incident2_story = " ".join(line["text"] for line in incident2["story"])
        self.assertIn("Paolo", incident2_story)
        self.assertIn("Ramon", incident2_story)
        self.assertIn("OTP", incident2_story)
        critical_choice = next(c for c in incident2["choices"] if c["outcome"] == "CRITICAL")
        self.assertIn("code", critical_choice["consequence"])

    def test_module_2_stage_8_incident_3_is_coordinated_multi_victim_campaign(self):
        stage = self._stage(8, module_id="mod_02")
        incident3_story = " ".join(line["text"] for line in stage["threats"][2]["story"])
        self.assertIn("coordinated wave", incident3_story)
        self.assertIn("two messages that convince each other", incident3_story)

    def test_module_2_stage_8_leah_helps_another_victim_recognize_the_pattern(self):
        stage = self._stage(8, module_id="mod_02")
        incident3_story = " ".join(line["text"] for line in stage["threats"][2]["story"])
        self.assertIn("So did mine", incident3_story)
        self.assertIn("verify with your sister", incident3_story.lower())

    def test_module_2_stage_8_does_not_reveal_the_exact_final_target(self):
        stage = self._stage(8, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("recovery authority", ending.lower())
        self.assertIn("recovery request", ending)
        forbidden_leak_phrases = [
            "admin console",
            "master key",
            "root access to bluetech",
            "the final target is",
        ]
        for phrase in forbidden_leak_phrases:
            self.assertNotIn(phrase, ending.lower())

    def test_module_2_stage_8_safe_playthrough_still_reaches_the_leverage_reveal(self):
        # The leverage/recovery-authority reveal and the new recovery-request
        # cliffhanger are story content shown regardless of player choices.
        stage = self._stage(8, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("Leverage against the employees", ending)
        self.assertIn("Not a personal one", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_9_is_the_final_story_stage_with_a_finale(self):
        stage9 = self._stage(9, module_id="mod_02")
        self.assertEqual(stage9["title"], "Trust No Number")
        self.assertEqual(stage9["bkt_skill"], "smishing")
        self.assertEqual(stage9["breach_hp_multiplier"], 1.0)
        self.assertEqual(stage9["clear_title"], "STAGE 9 COMPLETE")
        self.assertEqual(stage9["clear_subtitle"], "TRUST NO NUMBER")
        self.assertIn("Stage 10", stage9["next_stage_title"])
        self._assert_module2_four_choice_threats(stage9)
        finale = stage9.get("finale", {})
        self.assertTrue(finale.get("enabled"))
        self.assertEqual(finale.get("type"), "tower_defense")
        self.assertEqual(finale.get("enemy_hp_multiplier"), 1.0)
        self.assertEqual(finale.get("affected_system"), "BLUETECH IDENTITY RECOVERY SERVICE")
        self.assertEqual(finale.get("complete_banner"), "MODULE 2 STORY COMPLETE")
        self.assertTrue(finale.get("ending"))
        self.assertTrue(finale.get("closing"))
        summary = finale.get("case_summary", {})
        self.assertTrue(summary.get("title"))
        self.assertEqual(summary.get("subtitle"), "SIGNAL LOST")
        self.assertTrue(summary.get("items"))
        for stage_number in range(1, 9):
            self.assertNotIn(
                "finale", self._stage(stage_number, module_id="mod_02"),
                "Only Stage 9 authors a finale in Module 2",
            )

    def test_module_2_stage_9_topics_and_continuity_match_the_brief(self):
        stage = self._stage(9, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Not a Personal Account", "Second Approval", "The Last Call"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("Not a personal account", opening)
        self.assertIn("identity recovery administrator", opening.lower())
        self.assertIn("don't automatically own bluetech", opening.lower())
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("leverage", ending.lower())
        self.assertIn("reset authentication factors and recovery methods", ending)
        finale_closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("verify the process, not the story", finale_closing.lower())

    def test_module_2_stage_9_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(9, module_id="mod_02")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_2_stage_9_ids_are_isolated_from_stages_1_through_8(self):
        stages = [self._stage(n, module_id="mod_02") for n in range(1, 9)]
        stage9 = self._stage(9, module_id="mod_02")
        earlier_ids = {
            threat["id"] for stage in stages for threat in stage["threats"]
        }
        stage9_ids = {threat["id"] for threat in stage9["threats"]}
        self.assertTrue(stage9_ids.isdisjoint(earlier_ids))
        self.assertNotEqual(stages[-1]["id"], stage9["id"])

    def test_module_1_and_module_2_stage_9_ids_do_not_collide(self):
        mod1_ids = {threat["id"] for threat in self._stage(9)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(9, module_id="mod_02")["threats"]}
        self.assertTrue(mod1_ids.isdisjoint(mod2_ids))
        self.assertNotEqual(self._stage(9)["id"], self._stage(9, module_id="mod_02")["id"])

    def test_module_2_stage_9_does_not_overclaim_universal_bluetech_access(self):
        stage = self._stage(9, module_id="mod_02")
        opening = " ".join(line["text"] for line in stage["opening"])
        ending = " ".join(line["text"] for line in stage["ending"])
        overreach_phrases = [
            "access to every account",
            "access to every system",
            "own all of bluetech",
        ]
        for phrase in overreach_phrases:
            self.assertNotIn(phrase, opening.lower())
            self.assertNotIn(phrase, ending.lower())

    def test_module_2_stage_9_incident_3_shows_caller_id_and_real_code_are_not_proof(self):
        stage = self._stage(9, module_id="mod_02")
        incident3 = stage["threats"][2]
        explanation = incident3["explanation"].lower()
        self.assertIn("caller id", explanation)
        self.assertIn("genuine", explanation)
        critical_choice = next(c for c in incident3["choices"] if c["outcome"] == "CRITICAL")
        self.assertIn("caller id", critical_choice["label"].lower())

    def test_module_2_stage_9_safe_playthrough_still_reaches_the_final_reveal(self):
        # The leverage/objective reveal is story content shown regardless of
        # the player's choices throughout the stage.
        stage = self._stage(9, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("leverage", ending.lower())
        self.assertIn("Take over the account that helps other people recover theirs", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_1_stage_1_still_authors_exactly_three_choices(self):
        # Module 2 introduces a 4-choice format; Module 1's existing stages
        # must keep authoring exactly 3 choices per incident, unaffected.
        for threat in self._stage(1)["threats"]:
            self.assertEqual(len(threat["choices"]), 3)

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
