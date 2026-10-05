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

    def _assert_module2_four_choice_threats(self, stage: dict, module_id: str = "mod_02", bkt_skill: str = "smishing", choice_count: int = 4) -> None:
        threats = stage["threats"]
        self.assertEqual(len(threats), 3)
        ids = [threat["id"] for threat in threats]
        self.assertEqual(len(set(ids)), 3)
        for index, threat in enumerate(threats):
            self.assertEqual(threat["module_id"], module_id)
            self.assertEqual(threat["stage"], stage["stage"])
            self.assertEqual(threat["bkt_skill"], bkt_skill)
            self.assertTrue(threat["title"].strip())
            self.assertTrue(threat["situation"].strip())
            self.assertTrue(threat["explanation"].strip())
            self.assertTrue(threat["story"])
            self.assertTrue(threat["evidence"])
            self.assertGreater(int(threat["breach_gold"]), 0)
            choices = threat["choices"]
            self.assertEqual(len(choices), choice_count)
            outcomes = [choice["outcome"] for choice in choices]
            self.assertEqual(outcomes.count("SAFE"), 1)
            self.assertEqual(outcomes.count("RISKY"), choice_count - 2)
            self.assertEqual(outcomes.count("CRITICAL"), 1)
            risky_labels = [choice["label"] for choice in choices if choice["outcome"] == "RISKY"]
            self.assertEqual(len(risky_labels), choice_count - 2)
            self.assertEqual(len(set(risky_labels)), len(risky_labels))
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

    def test_module_2_stage_1_continues_into_college_with_laptop_evidence(self):
        stage = self._stage(1, module_id="mod_02")
        self.assertEqual(stage["title"], "First Login")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["visual_theme"], "college")
        self.assertTrue(stage["laptop"]["pages"])
        self.assertTrue(stage["laptop"]["contacts"])
        self.assertIn("Post-assessment", stage["opening"][0]["text"])
        self.assertTrue(stage["opening"])
        self.assertTrue(stage["ending"])
        for line in [*stage["opening"], *stage["ending"], *stage["resume_breach"]]:
            self.assertIn("speaker", line)
            self.assertTrue(str(line["text"]).strip())

    def test_module_2_stage_1_has_three_incidents_with_inspection_and_three_choices(self):
        stage = self._stage(1, module_id="mod_02")
        self._assert_module2_four_choice_threats(stage, choice_count=3)
        for threat in stage["threats"]:
            self.assertEqual(threat["investigation"]["mode"], "inspect")
            self.assertTrue(threat["investigation"]["enabled"])
            for item in threat["investigation"]["items"]:
                self.assertTrue(item["fields"])
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])

    def test_college_practice_requires_both_entrances_and_gradual_waves(self):
        stage = self._stage(1, module_id="mod_02")
        routes = stage["map_routes"]
        self.assertEqual(len(routes), 2)
        self.assertNotEqual(routes[0][0], routes[1][0])
        self.assertEqual(routes[0][-1], routes[1][-1])
        self.assertTrue(stage["finale"]["enabled"])
        waves = stage["finale"]["waves"]
        self.assertEqual(len(waves), 2)
        self.assertLess(waves[0]["enemy_count"], waves[1]["enemy_count"])
        for wave in [*waves, *stage["breach_waves"]]:
            self.assertEqual(set(wave["spawn_routes"]), {0, 1})

    def test_module_2_stage_1_threat_topics_match_the_brief(self):
        threats = self._stage(1, module_id="mod_02")["threats"]
        self.assertEqual([t["title"] for t in threats], ["A deadline in a text", "A real reminder", "Help from the right place"])

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
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
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
        ending = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("this one's from you", ending)
        self.assertIn("I didn't send you anything", ending)

    def test_module_2_stage_2_requires_matching_independent_delivery_records(self):
        stage = self._stage(2, module_id="mod_02")
        self.assertIn("Registration is sorted", stage["opening"][0]["text"])
        cards = {card["evidence_id"]: card for card in stage["laptop"]["pages"]}
        self.assertIn("HOME-6381", cards["old_parcel"]["title"])
        self.assertIn("EDU-6381", cards["tracking"]["title"])
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len(items), 3)
            self.assertIn("tracking", [item["id"] for item in items])
            self.assertNotIn("old_parcel", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        fee_fields = stage["threats"][1]["investigation"]["items"][1]["fields"]
        self.assertIn("PHP 0", fee_fields[0]["value"])
        self.assertIn("HOME-6381", fee_fields[1]["value"])

    def test_module_2_stage_2_map_adds_pressure_without_a_large_budget_jump(self):
        previous = self._stage(1, module_id="mod_02")
        stage = self._stage(2, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        self.assertEqual(stage["finale"]["gold"], previous["finale"]["gold"])
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            self.assertGreater(len(route), len(previous["map_routes"][0]))
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        self.assertEqual(expanded[0][-1], expanded[1][-1])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(x, 3) for x in range(8, 13)})
        for old, new in zip(previous["finale"]["waves"], stage["finale"]["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertGreaterEqual(new["spawn_delay"], old["spawn_delay"] - 0.11)
            self.assertEqual(set(new["spawn_routes"]), {0, 1})

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
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
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
        closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("verification code", closing)

    def test_module_2_stage_3_verification_uses_established_contacts_and_scoped_access(self):
        stage = self._stage(3, module_id="mod_02")
        contacts = {card["evidence_id"]: card for card in stage["laptop"]["contacts"]}
        self.assertIn("high school", contacts["mia"]["title"])
        self.assertIn("not saved as Mia", contacts["unverified"]["body"])
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len(items), 3)
            self.assertNotIn("unverified", [item["id"] for item in items])
            self.assertTrue(any(item["phone_app"] == "contacts" for item in items))
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        sharing = stage["threats"][1]["investigation"]["items"][2]
        self.assertEqual(sharing["id"], "sharing")
        self.assertIn("Restricted", sharing["fields"][0]["value"])
        self.assertIn("No public editing", sharing["fields"][1]["value"])
        family = stage["threats"][2]["investigation"]["items"][1]
        self.assertIn("permission", family["fields"][0]["value"])
        self.assertIn("at home", family["fields"][1]["value"])

    def test_module_2_stage_3_introduces_unequal_routes_with_modest_wave_growth(self):
        previous = self._stage(2, module_id="mod_02")
        stage = self._stage(3, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual(len(expanded[1]), len(expanded[0]) + 2)
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        self.assertEqual(expanded[0][-1], expanded[1][-1])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(x, 3) for x in range(9, 13)})
        self.assertEqual(stage["finale"]["gold"], previous["finale"]["gold"])
        for old, new in zip(previous["finale"]["waves"], stage["finale"]["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertEqual(new["spawn_delay"], old["spawn_delay"])
            self.assertEqual(set(new["spawn_routes"]), {0, 1})

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
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
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
        self.assertIn("timeline", ending)
        closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("I'm locked out", closing)
        self.assertIn("temporary protective hold", closing)
        self.assertIn("existing support case", closing)

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
        # Recovery follows an explained protective hold, not an unexplained
        # takeover after correct decisions. The draft and support route survive.
        stage = self._stage(4, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("temporary protective hold", ending)
        self.assertIn("reset did not complete", ending)
        self.assertIn("saved the draft", ending)
        self.assertIn("I'm locked out", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_4_requires_current_records_and_code_purpose(self):
        stage = self._stage(4, module_id="mod_02")
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len(items), 3)
            self.assertNotIn("archive", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        first, second, third = stage["threats"]
        self.assertIn("pending verification", first["investigation"]["items"][1]["fields"][0]["value"])
        self.assertIn("PASSWORD RESET", second["investigation"]["items"][0]["fields"][0]["value"])
        self.assertIn("Yesterday", third["investigation"]["items"][1]["fields"][0]["value"])
        self.assertIn("protective hold", third["investigation"]["items"][2]["analysis"])
        self.assertNotIn("BlueTech", json.dumps(stage))

    def test_module_2_stage_4_adds_winding_routes_and_one_heavy_packet(self):
        stage = self._stage(4, module_id="mod_02")
        previous = self._stage(3, module_id="mod_02")
        routes = stage["map_routes"]
        self.assertEqual(len(routes), 2)
        expanded = []
        for route in routes:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(route) for route in expanded], [17, 17])
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(x, 3) for x in range(10, 13)})
        finale = stage["finale"]
        self.assertTrue(finale["enabled"])
        self.assertEqual(finale["gold"], previous["finale"]["gold"])
        self.assertEqual(finale["enemy_hp_multiplier"], previous["finale"]["enemy_hp_multiplier"])
        for old, new in zip(previous["finale"]["waves"], finale["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertEqual(new["spawn_delay"], old["spawn_delay"])
            self.assertEqual(set(new["spawn_routes"]), {0, 1})
        self.assertNotIn("heavy", finale["waves"][0]["enemy_mix"])
        self.assertEqual(finale["waves"][1]["enemy_mix"].count("heavy"), 1)
        self.assertEqual(len(finale["waves"][1]["enemy_mix"]), finale["waves"][1]["enemy_count"])

    def test_module_2_stage_5_is_locked_out_with_four_choice_incidents(self):
        stage = self._stage(5, module_id="mod_02")
        self.assertEqual(stage["title"], "Locked Out")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
        self.assertEqual(stage["clear_title"], "STAGE 5 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "LOCKED OUT")
        self.assertIn("Stage 6", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_5_topics_and_continuity_match_the_brief(self):
        stage = self._stage(5, module_id="mod_02")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Find the Recovery Route", "Prove You're You", "Messages From Me"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("protective hold", opening)
        self.assertIn("HC-104", opening)
        self.assertIn("local interview draft", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("I'm back in", ending)
        closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("I have no signal", closing)
        self.assertIn("No Service", closing)
        self.assertIn("separate symptom", closing)
        self.assertNotIn("SIM swap", closing)

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
        self.assertIn("verified desk appointment", incident2_story)
        self.assertIn("13:12, before the hold", incident3_story)
        self.assertIn("earlier message I did not write", incident3_story)
        self.assertIn("entry point is still unconfirmed", incident3_story)
        forbidden_blame_phrases = [
            "the click caused",
            "the click was how they got in",
            "that click let them in",
            "confirmed the entry point was",
        ]
        for phrase in forbidden_blame_phrases:
            self.assertNotIn(phrase, incident3_story.lower())

    def test_module_2_stage_5_safe_playthrough_does_not_invent_an_unsafe_choice(self):
        # Support Leah without asserting a click the player may never have made.
        stage = self._stage(5, module_id="mod_02")
        story = " ".join(line["text"] for threat in stage["threats"] for line in threat["story"])
        self.assertNotIn("I clicked one message", story)
        self.assertIn("But it's my name", story)
        self.assertIn("without blaming you", story)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_5_recovery_sources_limit_disclosure_and_gate_restored_account(self):
        stage = self._stage(5, module_id="mod_02")
        self.assertNotIn("BlueTech", json.dumps(stage))
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len(items), 3)
            self.assertNotIn("offer", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        first, second, third = [threat["investigation"]["items"] for threat in stage["threats"]]
        self.assertNotIn("audit", [item["id"] for item in first + second])
        self.assertIn("no held-account login required", first[2]["fields"][0]["value"])
        self.assertIn("not evidence of current account status", first[1]["analysis"])
        self.assertIn("No document upload", second[1]["fields"][1]["value"])
        self.assertIn("Keep backup codes private", second[2]["fields"][1]["value"])
        self.assertEqual(third[1]["id"], "audit")
        self.assertIn("13:12 before the hold", third[1]["fields"][1]["value"])
        self.assertIn("remains restricted", third[2]["fields"][0]["value"])

    def test_module_2_stage_5_map_adds_bends_without_a_budget_or_health_spike(self):
        stage = self._stage(5, module_id="mod_02")
        previous = self._stage(4, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        expanded = []
        for route, old in zip(stage["map_routes"], previous["map_routes"]):
            self.assertGreater(len(route), len(old))
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(route) for route in expanded], [17, 17])
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(x, 3) for x in range(10, 13)})
        finale = stage["finale"]
        self.assertTrue(finale["enabled"])
        self.assertEqual(finale["gold"], previous["finale"]["gold"])
        self.assertEqual(finale["enemy_hp_multiplier"], previous["finale"]["enemy_hp_multiplier"])
        for old, new in zip(previous["finale"]["waves"], finale["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertGreaterEqual(new["spawn_delay"], old["spawn_delay"])
            self.assertEqual(set(new["spawn_routes"]), {0, 1})
        self.assertEqual(finale["waves"][0]["spawn_delay"], 1.7)
        self.assertEqual(finale["waves"][1]["spawn_delay"], 1.9)
        mixed = finale["waves"][1]
        self.assertEqual(len(mixed["enemy_mix"]), mixed["enemy_count"])
        heavy_indices = [i for i, kind in enumerate(mixed["enemy_mix"]) if kind == "heavy"]
        self.assertEqual(len(heavy_indices), 2)
        self.assertGreater(heavy_indices[1] - heavy_indices[0], 3)
        self.assertNotEqual(mixed["spawn_routes"][heavy_indices[0] % 4], mixed["spawn_routes"][heavy_indices[1] % 4])

    def test_module_2_stage_6_is_no_signal_with_four_choice_incidents(self):
        stage = self._stage(6, module_id="mod_02")
        self.assertEqual(stage["title"], "No Signal")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
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
        self.assertIn("account", ending)
        closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("wasn't the only target", closing)
        self.assertIn("do not yet prove the same cause", closing)
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
        # A separate classmate report follows completed practice, without
        # claiming a common attacker or blaming an unchosen earlier action.
        stage = self._stage(6, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("seminar group", ending)
        self.assertIn("Ramon", ending)
        self.assertIn("wasn't the only target", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_6_separates_saved_sms_from_wifi_and_account_dependencies(self):
        stage = self._stage(6, module_id="mod_02")
        self.assertNotIn("BlueTech", json.dumps(stage))
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len(items), 3)
            self.assertNotIn("archive", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        first, second, third = [threat["investigation"]["items"] for threat in stage["threats"]]
        self.assertIn("before service loss", first[0]["fields"][0]["value"])
        self.assertIn("not receiving a new text", first[0]["fields"][1]["value"])
        self.assertIn("Current line record", first[1]["fields"][1]["value"])
        self.assertNotIn("restore", [item["id"] for item in first + second])
        self.assertIn("authenticator already enrolled", second[1]["fields"][0]["value"])
        self.assertIn("no completed new session", second[1]["fields"][1]["value"])
        self.assertIn("Carrier cannot confirm", second[2]["fields"][1]["value"])
        self.assertIn("test an ordinary call and SMS", third[1]["fields"][1]["value"])
        self.assertIn("no remote-control app", third[1]["fields"][0]["value"])

    def test_module_2_stage_6_extends_lower_route_and_merges_later_with_modest_wave_growth(self):
        stage = self._stage(6, module_id="mod_02")
        previous = self._stage(5, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(route) for route in expanded], [17, 19])
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(11, 3), (12, 3)})
        finale = stage["finale"]
        self.assertTrue(finale["enabled"])
        self.assertEqual(finale["gold"], previous["finale"]["gold"])
        self.assertEqual(finale["enemy_hp_multiplier"], previous["finale"]["enemy_hp_multiplier"])
        for old, new in zip(previous["finale"]["waves"], finale["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertGreaterEqual(new["spawn_delay"], old["spawn_delay"])
            self.assertEqual(set(new["spawn_routes"]), {0, 1})
        mixed = finale["waves"][1]
        self.assertEqual(len(mixed["enemy_mix"]), mixed["enemy_count"])
        heavy_indices = [i for i, kind in enumerate(mixed["enemy_mix"]) if kind == "heavy"]
        self.assertEqual(len(heavy_indices), 2)
        self.assertNotEqual(mixed["spawn_routes"][heavy_indices[0] % 4], mixed["spawn_routes"][heavy_indices[1] % 4])

    def test_module_2_stage_7_is_not_just_leah_with_four_choice_incidents(self):
        stage = self._stage(7, module_id="mod_02")
        self.assertEqual(stage["title"], "Not Just Leah")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
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
            ["Same Problem", "Third Name", "Campus Security"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("His phone still has no service", opening)
        self.assertIn("Five forwards can still describe one person", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("Two confirmed line incidents and one suspicious message", ending)
        self.assertIn("original sources", ending)

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

    def test_module_2_stage_7_paolo_is_introduced_as_ramons_brother_outside_the_seminar(self):
        stage = self._stage(7, module_id="mod_02")
        incident1_story = " ".join(line["text"] for line in stage["threats"][0]["story"])
        incident2_story = " ".join(line["text"] for line in stage["threats"][1]["story"])
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("Ramon", incident1_story)
        self.assertIn("using Wi-Fi", opening)
        self.assertIn("Paolo is Ramon's brother", incident2_story)
        self.assertIn("not in our seminar group", incident2_story)

    def test_module_2_stage_7_distinguishes_three_reports_from_two_confirmed_line_incidents(self):
        stage = self._stage(7, module_id="mod_02")
        incident2_story = " ".join(line["text"] for line in stage["threats"][1]["story"])
        self.assertIn("third person reporting something suspicious", incident2_story)
        comparison = stage["threats"][1]["investigation"]["items"][2]
        self.assertIn("Three people, two confirmed line incidents", comparison["fields"][1]["value"])
        self.assertIn("no carrier change found", comparison["fields"][0]["value"])
        self.assertNotIn("BlueTech", json.dumps(stage))

    def test_module_2_stage_7_incident_3_uses_fake_campus_security_sms(self):
        stage = self._stage(7, module_id="mod_02")
        incident3 = stage["threats"][2]
        incident3_story = " ".join(line["text"] for line in incident3["story"])
        self.assertIn("CAMPUS SECURITY", incident3_story)
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
        # Family-directed pressure follows the limited class response on every
        # completed path; no unsupported common-attacker claim is required.
        stage = self._stage(7, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("names their mother", ending)
        self.assertIn("family recovery request", ending)
        self.assertIn("family contact he already knows", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_2_stage_7_requires_original_sources_and_warning_permission(self):
        stage = self._stage(7, module_id="mod_02")
        self.assertEqual([len(t["investigation"]["items"]) for t in stage["threats"]], [3, 3, 4])
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertNotIn("forward", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        first, second, third = [t["investigation"]["items"] for t in stage["threats"]]
        self.assertIn("all three forwards show that post", first[1]["fields"][0]["value"])
        self.assertIn("no replacement or pending transfer", second[1]["fields"][0]["value"])
        self.assertEqual(third[3]["id"], "notice")
        self.assertIn("No permission for class-wide identity records", third[2]["fields"][0]["value"])
        self.assertIn("no live suspicious links", third[3]["fields"][1]["value"])
        self.assertIn("Two carrier-confirmed line incidents plus one message-only report", third[2]["fields"][1]["value"])

    def test_module_2_stage_7_adds_upper_detour_and_switching_groups(self):
        stage = self._stage(7, module_id="mod_02")
        previous = self._stage(6, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(route) for route in expanded], [19, 19])
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(11, 3), (12, 3)})
        finale = stage["finale"]
        self.assertTrue(finale["enabled"])
        self.assertEqual(finale["gold"], previous["finale"]["gold"])
        self.assertEqual(finale["enemy_hp_multiplier"], previous["finale"]["enemy_hp_multiplier"])
        for old, new in zip(previous["finale"]["waves"], finale["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertGreaterEqual(new["spawn_delay"], old["spawn_delay"])
            self.assertEqual(set(new["spawn_routes"]), {0, 1})
        mixed = finale["waves"][1]
        self.assertEqual(mixed["spawn_routes"], [1, 1, 1, 0, 0, 0])
        self.assertEqual(len(mixed["enemy_mix"]), mixed["enemy_count"])
        heavy_indices = [i for i, kind in enumerate(mixed["enemy_mix"]) if kind == "heavy"]
        self.assertEqual(len(heavy_indices), 2)
        self.assertNotEqual(mixed["spawn_routes"][heavy_indices[0] % 6], mixed["spawn_routes"][heavy_indices[1] % 6])

    def test_module_2_stage_8_is_close_to_home_with_four_choice_incidents(self):
        stage = self._stage(8, module_id="mod_02")
        self.assertEqual(stage["title"], "Close to Home")
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["visual_theme"], "college")
        self.assertEqual(stage["clear_title"], "STAGE 8 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "CLOSE TO HOME")
        self.assertEqual(stage["next_stage_title"], "Stage 9 — Trust No Number")
        self.assertNotIn("BlueTech", json.dumps(stage))
        self._assert_module2_four_choice_threats(stage)

    def test_module_2_stage_8_topics_and_continuity_match_the_brief(self):
        stage = self._stage(8, module_id="mod_02")
        self.assertEqual([t["title"] for t in stage["threats"]], [
            "She Needs Your Help", "A Real Request, the Wrong Role", "The Approval Behind the Emergency"])
        previous = " ".join(line["text"] for line in self._stage(7, module_id="mod_02")["finale"]["closing"])
        opening = " ".join(line["text"] for line in stage["opening"])
        for text in (previous, opening):
            self.assertIn("Paolo", text)
            self.assertIn("their mother", text)
            self.assertIn("family recovery", text)
        self.assertIn("presentation", opening)
        self.assertEqual(stage["locations"], self._stage(7, module_id="mod_02")["locations"])

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

    def test_module_2_stage_8_incident_1_breaks_circular_family_confirmation(self):
        items = self._stage(8, module_id="mod_02")["threats"][0]["investigation"]["items"]
        self.assertEqual([item["id"] for item in items], ["message", "family", "timeline"])
        self.assertIn("do not call", items[0]["fields"][0]["value"])
        self.assertIn("saved before today", items[1]["fields"][0]["value"])
        self.assertIn("requested no recovery", items[1]["fields"][1]["value"])
        self.assertIn("15:28", items[2]["fields"][0]["label"])
        self.assertIn("15:29", items[2]["fields"][1]["label"])
        self.assertIn("no independent evidence", items[2]["fields"][1]["value"])

    def test_module_2_stage_8_incident_2_separates_identity_from_role_scope(self):
        incident = self._stage(8, module_id="mod_02")["threats"][1]
        items = {item["id"]: item for item in incident["investigation"]["items"]}
        self.assertIn("genuine request", items["message"]["analysis"])
        self.assertIn("No change", items["ramon"]["fields"][1]["value"])
        self.assertIn("personal photo account", items["roles"]["fields"][0]["value"])
        self.assertIn("Paolo has no workspace role", items["roles"]["fields"][1]["value"])
        self.assertIn("cannot approve college workspace changes", items["support"]["fields"][0]["value"])
        critical = next(c for c in incident["choices"] if c["outcome"] == "CRITICAL")
        self.assertIn("live session", critical["consequence"])

    def test_module_2_stage_8_incident_3_checks_request_effect_status_and_authority(self):
        incident = self._stage(8, module_id="mod_02")["threats"][2]
        items = {item["id"]: item for item in incident["investigation"]["items"]}
        self.assertIn("RN-318", items["request"]["fields"][0]["value"])
        self.assertIn("replace its recovery contact", items["request"]["fields"][0]["value"])
        self.assertIn("Pending, not approved or applied", items["request"]["fields"][1]["value"])
        self.assertIn("both required", items["request"]["fields"][1]["value"])
        self.assertIn("no contact change applied", items["support"]["fields"][0]["value"])
        self.assertIn("No approval is needed", items["plan"]["fields"][0]["value"])
        self.assertIn("existing local slides", items["plan"]["fields"][1]["value"])

    def test_module_2_stage_8_leah_helps_without_assuming_player_mistakes(self):
        story = " ".join(line["text"] for line in self._stage(8, module_id="mod_02")["threats"][2]["story"] if line["speaker"] == "Leah")
        self.assertIn("earlier messages", story)
        self.assertIn("without approving an account change", story)
        self.assertNotIn("I approved", story)
        self.assertNotIn("I clicked", story)

    def test_module_2_stage_8_keeps_request_origin_and_campaign_attribution_uncertain(self):
        ending = " ".join(line["text"] for line in self._stage(8, module_id="mod_02")["ending"])
        self.assertIn("recovery authority", ending)
        self.assertIn("recovery request", ending)
        self.assertIn("do not know who submitted it", ending)
        self.assertIn("whether every message has the same sender", ending)

    def test_module_2_stage_8_safe_playthrough_still_requires_practice_and_pending_case(self):
        stage = self._stage(8, module_id="mod_02")
        self.assertTrue(stage["finale"]["enabled"])
        self.assertEqual(stage["finale"]["type"], "tower_defense")
        closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("No one has approved", closing)
        self.assertIn("CAMPUS HELP", closing)
        self.assertIn("independent support route", closing)
        self.assertEqual(sum(c["outcome"] == "SAFE" for t in stage["threats"] for c in t["choices"]), 3)

    def test_module_2_stage_8_requires_actual_sources_and_full_scope_reviews(self):
        stage = self._stage(8, module_id="mod_02")
        self.assertEqual([len(t["investigation"]["items"]) for t in stage["threats"]], [3, 4, 4])
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len({item["id"] for item in items}), len(items))
            self.assertNotIn("forward", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        self.assertEqual(stage["threats"][1]["investigation"]["items"][-1]["id"], "support")
        self.assertEqual(stage["threats"][2]["investigation"]["items"][-1]["id"], "plan")

    def test_module_2_stage_8_extends_lower_route_with_gradual_overlapping_pressure(self):
        stage = self._stage(8, module_id="mod_02")
        previous = self._stage(7, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        self.assertEqual(stage["map_routes"][0], previous["map_routes"][0])
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(route) for route in expanded], [19, 21])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(11, 3), (12, 3)})
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        for position in [(10, 1), (10, 3), (11, 5)]:
            self.assertNotIn(position, expanded[0] + expanded[1])
        finale = stage["finale"]
        self.assertEqual(finale["gold"], previous["finale"]["gold"])
        self.assertEqual(finale["enemy_hp_multiplier"], previous["finale"]["enemy_hp_multiplier"])
        for old, new in zip(previous["finale"]["waves"], finale["waves"]):
            self.assertEqual(new["enemy_count"], old["enemy_count"] + 1)
            self.assertGreaterEqual(new["spawn_delay"], old["spawn_delay"])
            self.assertEqual(set(new["spawn_routes"]), {0, 1})
        mixed = finale["waves"][1]
        self.assertEqual(len(mixed["enemy_mix"]), mixed["enemy_count"])
        heavy = [i for i, kind in enumerate(mixed["enemy_mix"]) if kind == "heavy"]
        self.assertEqual(len(heavy), 2)
        self.assertEqual(mixed["enemy_mix"].count("fast"), 4)
        self.assertNotEqual(mixed["spawn_routes"][heavy[0] % 6], mixed["spawn_routes"][heavy[1] % 6])

    def test_module_2_stage_9_is_college_support_verification_with_required_practice(self):
        stage = self._stage(9, module_id="mod_02")
        self.assertEqual(stage["title"], "Trust No Number")
        self.assertEqual(stage["content_version"], 2)
        self.assertEqual(stage["visual_theme"], "college")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.45)
        self.assertEqual(stage["clear_title"], "STAGE 9 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "TRUST NO NUMBER")
        self.assertEqual(stage["next_stage_title"], "Stage 10 — Final Checkpoint")
        self._assert_module2_four_choice_threats(stage)
        finale = stage["finale"]
        self.assertTrue(finale["enabled"])
        self.assertEqual(finale["type"], "tower_defense")
        self.assertEqual(finale["enemy_hp_multiplier"], 0.45)
        self.assertEqual(finale["affected_system"], "LAPTOP / INDEPENDENT SUPPORT PRACTICE")
        self.assertEqual(finale["complete_banner"], "SUPPORT VERIFICATION COMPLETE")
        self.assertTrue(finale["ending"])
        self.assertTrue(finale["closing"])
        self.assertTrue(finale["case_summary"]["items"])
        self.assertNotIn("BlueTech", json.dumps(stage))
        self.assertNotIn("MODULE 2 STORY COMPLETE", json.dumps(stage))

    def test_module_2_stage_9_topics_and_continuity_match_the_brief(self):
        stage = self._stage(9, module_id="mod_02")
        self.assertEqual([t["title"] for t in stage["threats"]], [
            "They Know the Case", "A Second Screen Is Not a Second Source", "The Verified Reply"])
        previous = " ".join(line["text"] for line in self._stage(8, module_id="mod_02")["finale"]["closing"])
        opening = " ".join(line["text"] for line in stage["opening"])
        for text in (previous, opening):
            self.assertIn("CAMPUS HELP", text)
            self.assertIn("RN-318", text)
            self.assertIn("release", text)
        self.assertIn("saved on the laptop", opening)
        self.assertEqual(stage["locations"], self._stage(8, module_id="mod_02")["locations"])

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

    def test_module_2_stage_9_does_not_overclaim_review_scope_or_attribution(self):
        stage = self._stage(9, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("do not know who made every contact", ending)
        self.assertIn("separate carrier case", ending)
        review = next(item for item in stage["threats"][2]["investigation"]["items"] if item["id"] == "review")
        self.assertIn("no unauthorized change found in that review", review["fields"][0]["value"])
        self.assertIn("does not identify every caller", review["fields"][1]["value"])
        self.assertIn("common attacker", review["fields"][1]["value"])

    def test_module_2_stage_9_incident_1_separates_case_knowledge_from_caller_identity(self):
        incident = self._stage(9, module_id="mod_02")["threats"][0]
        explanation = incident["explanation"].lower()
        self.assertIn("caller id", explanation)
        self.assertIn("genuine case", explanation)
        items = {item["id"]: item for item in incident["investigation"]["items"]}
        self.assertIn("no incoming link or callback number", items["support"]["fields"][0]["value"])
        self.assertIn("has not requested release", items["support"]["fields"][1]["value"])
        self.assertIn("does not authenticate", items["case"]["fields"][1]["value"])
        critical = next(c for c in incident["choices"] if c["outcome"] == "CRITICAL")
        self.assertIn("caller ID", critical["label"])

    def test_module_2_stage_9_safe_playthrough_rejects_the_change_and_keeps_stage_10_pending(self):
        stage = self._stage(9, module_id="mod_02")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("rejected RN-318", ending)
        self.assertIn("not applied", ending)
        closing = " ".join(line["text"] for line in stage["finale"]["closing"])
        self.assertIn("presentation draft is saved", closing)
        self.assertIn("One college checkpoint remains", closing)
        self.assertEqual(sum(c["outcome"] == "SAFE" for t in stage["threats"] for c in t["choices"]), 3)

    def test_module_2_stage_9_sms_page_and_chat_are_not_independent_verification(self):
        incident = self._stage(9, module_id="mod_02")["threats"][1]
        items = {item["id"]: item for item in incident["investigation"]["items"]}
        self.assertIn("Incoming SMS -> supplied verification page -> chat", items["link"]["fields"][0]["value"])
        self.assertIn("cannot independently validate", items["link"]["fields"][1]["value"])
        self.assertIn("bookmark saved at orientation", items["route"]["fields"][0]["value"])
        self.assertIn("does not use the SMS verification page", items["support"]["fields"][0]["value"])
        safe = next(c for c in incident["choices"] if c["outcome"] == "SAFE")
        self.assertIn("page closed", safe["label"])
        self.assertIn("Private browsing does not verify", " ".join(c["consequence"] for c in incident["choices"]))

    def test_module_2_stage_9_verified_result_allows_scoped_work_without_reusing_old_instructions(self):
        incident = self._stage(9, module_id="mod_02")["threats"][2]
        items = {item["id"]: item for item in incident["investigation"]["items"]}
        self.assertIn("case update retrieved", items["message"]["fields"][0]["value"])
        self.assertIn("rejected by designated student maintainer and campus IT", items["case"]["fields"][0]["value"])
        self.assertIn("supersedes the earlier on-hold status", items["case"]["fields"][1]["value"])
        self.assertIn("Keep normal account protections enabled", items["plan"]["fields"][0]["value"])
        safe = next(c for c in incident["choices"] if c["outcome"] == "SAFE")
        self.assertIn("Resume the project", safe["label"])
        self.assertIn("rejected, not authorized", next(c for c in incident["choices"] if c["outcome"] == "CRITICAL")["consequence"])

    def test_module_2_stage_9_requires_actual_sources_and_full_scope_reviews(self):
        stage = self._stage(9, module_id="mod_02")
        self.assertEqual([len(t["investigation"]["items"]) for t in stage["threats"]], [3, 4, 4])
        for threat in stage["threats"]:
            items = threat["investigation"]["items"]
            self.assertEqual(len({item["id"] for item in items}), len(items))
            self.assertNotIn("display", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [card["evidence_id"] for card in stage["laptop"][item["phone_app"]]])
        self.assertEqual(stage["threats"][1]["investigation"]["items"][-1]["id"], "support")
        self.assertEqual(stage["threats"][2]["investigation"]["items"][-1]["id"], "plan")

    def test_module_2_stage_9_extends_upper_route_with_gradual_mixed_pressure(self):
        stage = self._stage(9, module_id="mod_02")
        previous = self._stage(8, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        self.assertEqual(stage["map_routes"][1], previous["map_routes"][1])
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(route) for route in expanded], [21, 21])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(11, 3), (12, 3)})
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        for position in [(10, 1), (10, 3), (11, 5)]:
            self.assertNotIn(position, expanded[0] + expanded[1])
        finale = stage["finale"]
        self.assertEqual(finale["gold"], previous["finale"]["gold"])
        self.assertEqual(finale["enemy_hp_multiplier"], previous["finale"]["enemy_hp_multiplier"])
        for old_wave, new_wave in zip(previous["finale"]["waves"], finale["waves"]):
            self.assertEqual(new_wave["enemy_count"], old_wave["enemy_count"] + 1)
            self.assertGreaterEqual(new_wave["spawn_delay"], old_wave["spawn_delay"])
            self.assertEqual(set(new_wave["spawn_routes"]), {0, 1})
        mixed = finale["waves"][1]
        self.assertEqual(len(mixed["enemy_mix"]), mixed["enemy_count"])
        heavy = [i for i, kind in enumerate(mixed["enemy_mix"]) if kind == "heavy"]
        self.assertEqual(len(heavy), 2)
        self.assertEqual(mixed["enemy_mix"].count("fast"), 4)
        self.assertNotEqual(mixed["spawn_routes"][heavy[0] % 6], mixed["spawn_routes"][heavy[1] % 6])

    def test_module_2_stage_10_is_an_assessment_not_an_extra_story_grade(self):
        stage = self._stage(10, module_id="mod_02")
        self.assertEqual(stage["stage_type"], "assessment")
        self.assertEqual(stage["title"], "Final Checkpoint")
        self.assertEqual(stage["visual_theme"], "college")
        self.assertEqual(stage["bkt_skill"], "smishing")
        self.assertNotIn("threats", stage)
        self.assertEqual(len(stage["rounds"]), 3)
        config = stage["assessment"]
        self.assertEqual(config["exam_question_count"], 15)
        self.assertEqual(config["exam_required_score"], 0.75)
        self.assertEqual(config["questions_per_wave"], 5)
        self.assertEqual(config["incident_chance"], 0)

    def test_module_2_stage_10_continues_presentation_story_and_concludes_college(self):
        stage = self._stage(10, module_id="mod_02")
        opening = " ".join(line["text"] for line in stage["opening"])
        closing = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("RN-318 was rejected", opening)
        self.assertIn("presentation draft is saved", opening)
        self.assertIn("high school", opening)
        self.assertIn("college project", closing)
        self.assertIn("carrier follow-up separate", closing)
        self.assertNotIn("BlueTech", json.dumps(stage))
        self.assertNotIn("next_stage_title", stage)

    def test_module_2_stage_10_has_fifteen_unique_questions_grouped_by_case(self):
        stage = self._stage(10, module_id="mod_02")
        self.assertEqual([r["title"] for r in stage["rounds"]], [
            "The Presentation Deadline", "A Helpful Group Member", "The Recovery Handoff"])
        questions = [q for r in stage["rounds"] for q in r["questions"]]
        self.assertEqual([len(r["questions"]) for r in stage["rounds"]], [5, 5, 5])
        self.assertEqual(len({q["id"] for q in questions}), 15)
        self.assertEqual([q["id"] for q in questions], [f"mod02_final_{n:02}" for n in range(1, 16)])
        self.assertEqual({q["module_id"] for q in questions}, {"mod_02"})
        self.assertEqual({q["skill_id"] for q in questions}, {"smishing"})
        for difficulty, count in [("easy", 4), ("medium", 7), ("hard", 4)]:
            self.assertEqual(sum(q["difficulty"] == difficulty for q in questions), count)

    def test_module_2_stage_10_questions_have_gradable_answers_and_self_contained_facts(self):
        deliveries = set()
        for case in self._stage(10, module_id="mod_02")["rounds"]:
            for q in case["questions"]:
                deliveries.add(q["delivery"])
                self.assertTrue(q["question"])
                self.assertTrue(q["scenario"]["body"])
                self.assertTrue(q["explanation"])
                if q["delivery"] == "single_choice":
                    self.assertEqual(len(set(q["options"])), 4)
                    self.assertIn(q["answer_index"], range(4))
                elif q["delivery"] == "true_false":
                    self.assertIsInstance(q["answer"], bool)
                else:
                    self.assertEqual(len(set(q["email_lines"])), 4)
                    self.assertEqual(len(set(q["correct_indices"])), 2)
                    self.assertTrue(set(q["correct_indices"]).issubset(range(4)))
        self.assertEqual(deliveries, {"single_choice", "multi_select", "true_false"})

    def test_module_2_stage_10_cases_require_real_sources_and_no_forwarded_shortcuts(self):
        stage = self._stage(10, module_id="mod_02")
        self.assertEqual([len(r["investigation"]["items"]) for r in stage["rounds"]], [3, 4, 4])
        for case in stage["rounds"]:
            self.assertTrue(case["story"][-1]["mail"]["body"])
            self.assertEqual(case["background"], "college_commons")
            items = case["investigation"]["items"]
            self.assertNotIn("forward", [item["id"] for item in items])
            for item in items:
                self.assertGreaterEqual(len(item["fields"]), 2)
                if item["phone_app"] != "mail":
                    self.assertIn(item["id"], [c["evidence_id"] for c in stage["laptop"][item["phone_app"]]])

    def test_module_2_stage_10_deadline_case_separates_real_schedule_from_fee(self):
        case = self._stage(10, module_id="mod_02")["rounds"][0]
        record = next(i for i in case["investigation"]["items"] if i["id"] == "record")
        self.assertIn("PR-410", record["fields"][0]["value"])
        self.assertIn("no balance due", record["fields"][0]["value"])
        self.assertIn("PR-401 belongs to last week", record["fields"][1]["value"])
        self.assertFalse(case["questions"][1]["answer"])

    def test_module_2_stage_10_access_case_checks_permission_and_consent(self):
        case = self._stage(10, module_id="mod_02")["rounds"][1]
        scope = next(i for i in case["investigation"]["items"] if i["id"] == "scope")
        self.assertIn("public sharing was not agreed", scope["fields"][0]["value"])
        self.assertIn("no college project role", scope["fields"][1]["value"])
        self.assertEqual(case["questions"][-1]["correct_indices"], [0, 1])

    def test_module_2_stage_10_handoff_case_distinguishes_rejected_from_applied(self):
        case = self._stage(10, module_id="mod_02")["rounds"][2]
        record = next(i for i in case["investigation"]["items"] if i["id"] == "record")
        self.assertIn("RN-422", record["fields"][0]["value"])
        self.assertIn("rejected", record["fields"][0]["value"])
        self.assertIn("not applied", record["fields"][0]["value"])
        self.assertFalse(case["questions"][1]["answer"])
        self.assertIn("outside", case["questions"][-1]["scenario"]["body"])

    def test_module_2_stage_10_final_routes_merge_only_at_laptop(self):
        stage = self._stage(10, module_id="mod_02")
        self.assertEqual(len(stage["map_routes"]), 2)
        expanded = []
        for route in stage["map_routes"]:
            cells = [tuple(route[0])]
            for start, end in zip(route, route[1:]):
                self.assertNotEqual(start, end)
                self.assertTrue(start[0] == end[0] or start[1] == end[1])
                dx = (end[0] > start[0]) - (end[0] < start[0])
                dy = (end[1] > start[1]) - (end[1] < start[1])
                while cells[-1] != tuple(end):
                    x, y = cells[-1][0] + dx, cells[-1][1] + dy
                    self.assertTrue(0 <= x < 13 and 0 <= y < 7)
                    cells.append((x, y))
            self.assertEqual(len(cells), len(set(cells)))
            expanded.append(cells)
        self.assertEqual([len(r) for r in expanded], [23, 23])
        self.assertEqual(set(expanded[0]) & set(expanded[1]), {(12, 3)})
        self.assertNotEqual(expanded[0][0], expanded[1][0])
        for cell in [(10, 1), (11, 3), (11, 5)]:
            self.assertNotIn(cell, expanded[0] + expanded[1])

    def test_module_2_stage_10_three_waves_build_gradually_on_stage_9(self):
        stage = self._stage(10, module_id="mod_02")
        previous = self._stage(9, module_id="mod_02")["finale"]
        self.assertEqual(stage["assessment"]["starting_gold"], previous["gold"])
        self.assertEqual(stage["enemy_hp_multiplier"], previous["enemy_hp_multiplier"])
        waves = stage["assessment"]["waves"]
        self.assertEqual([w["enemy_count"] for w in waves], [10, 12, 14])
        self.assertEqual([w["enemy_mix"].count("heavy") for w in waves], [0, 1, 2])
        self.assertEqual([w["enemy_mix"].count("fast") for w in waves], [0, 2, 4])
        for w in waves:
            self.assertEqual(set(w["spawn_routes"]), {0, 1})
            self.assertGreaterEqual(w["spawn_delay"], 1.8)
            self.assertEqual(w["health_multiplier"], 1)

    def test_module_3_stage_1_is_unknown_caller_with_four_choice_incidents(self):
        stage = self._stage(1, module_id="mod_03")
        self.assertEqual(stage["title"], "Unknown Caller")
        self.assertEqual(stage["bkt_skill"], "vishing")
        self.assertEqual(stage["breach_hp_multiplier"], 0.65)
        self.assertEqual(stage["clear_title"], "STAGE 1 COMPLETE")
        self.assertEqual(stage["clear_subtitle"], "UNKNOWN CALLER")
        self.assertIn("Stage 2", stage["next_stage_title"])
        self.assertIn("Stay on the Line", stage["next_stage_title"])
        self._assert_module2_four_choice_threats(stage, module_id="mod_03", bkt_skill="vishing")

    def test_module_3_stage_1_topics_and_continuity_match_the_brief(self):
        stage = self._stage(1, module_id="mod_03")
        threats = stage["threats"]
        self.assertEqual(
            [threat["title"] for threat in threats],
            ["Fraud Department", "Stay on the Line", "Security Callback"],
        )
        opening = " ".join(line["text"] for line in stage["opening"])
        self.assertIn("Fraud Prevention Department", opening)
        self.assertIn("Daniel", opening)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("isn't a random robocall", ending)
        self.assertIn("PRIVATE NUMBER", ending)
        self.assertIn("stay on the line", ending.lower())

    def test_module_3_stage_1_choices_avoid_trivial_wording(self):
        trivial_patterns = [
            r"give.*password",
            r"ignore it",
            r"ignore everything",
            r"looks safe",
            r"trust it because it looks real",
        ]
        for threat in self._stage(1, module_id="mod_03")["threats"]:
            for choice in threat["choices"]:
                label = choice["label"].lower()
                for pattern in trivial_patterns:
                    self.assertNotRegex(label, pattern)

    def test_module_3_stage_1_ids_do_not_collide_with_module_1_or_2_stage_1(self):
        mod3_ids = {threat["id"] for threat in self._stage(1, module_id="mod_03")["threats"]}
        mod1_ids = {threat["id"] for threat in self._stage(1)["threats"]}
        mod2_ids = {threat["id"] for threat in self._stage(1, module_id="mod_02")["threats"]}
        self.assertTrue(mod3_ids.isdisjoint(mod1_ids))
        self.assertTrue(mod3_ids.isdisjoint(mod2_ids))

    def test_module_3_stage_1_daniel_is_a_recognized_speaker(self):
        stage = self._stage(1, module_id="mod_03")
        opening_speakers = {line["speaker"] for line in stage["opening"]}
        self.assertIn("Daniel", opening_speakers)

    def test_module_3_stage_1_uses_caller_id_spoofing_and_teaches_callback_verification(self):
        stage = self._stage(1, module_id="mod_03")
        incident1 = stage["threats"][0]
        self.assertEqual(incident1["affected_system"], "DANIEL'S BUSINESS BANK ACCOUNT")
        incident1_story = " ".join(line["text"] for line in incident1["story"])
        self.assertIn("we detected an attempted", incident1_story)
        safe_labels = " ".join(
            choice["label"].lower()
            for threat in stage["threats"]
            for choice in threat["choices"]
            if choice["outcome"] == "SAFE"
        )
        self.assertTrue(
            "independently" in safe_labels
            or "known official channel" in safe_labels
            or "previously trusted channel" in safe_labels
        )

    def test_module_3_stage_1_attacker_tells_daniel_to_stay_on_the_line(self):
        stage = self._stage(1, module_id="mod_03")
        incident2_story = " ".join(line["text"] for line in stage["threats"][1]["story"])
        self.assertIn("stay on this call", incident2_story.lower())

    def test_module_3_stage_1_emotion_metadata_is_present_and_diverse(self):
        stage = self._stage(1, module_id="mod_03")
        all_lines = list(stage["opening"]) + list(stage["ending"])
        for threat in stage["threats"]:
            all_lines += threat["story"]
        emotions_found = {line["emotion"] for line in all_lines if "emotion" in line}
        required = {"worried", "frustrated", "angry", "sad", "shocked", "determined"}
        self.assertTrue(required.issubset(emotions_found), emotions_found)
        self.assertNotIn("crying", emotions_found)
        valid_emotions = {
            "neutral", "worried", "shocked", "scared", "angry",
            "crying", "sad", "frustrated", "determined", "relieved",
        }
        self.assertTrue(emotions_found.issubset(valid_emotions), emotions_found)
        # Lines with no "emotion" key at all must keep working (default neutral
        # is applied by DialogueEmotion at read time, not authored here).
        lines_without_emotion = [line for line in all_lines if "emotion" not in line]
        self.assertTrue(lines_without_emotion)

    def test_module_3_stage_1_emotion_does_not_correlate_with_outcome(self):
        # Emotion is a dialogue-line concept, not a choice concept: choice
        # dictionaries (SAFE/RISKY/RISKY/CRITICAL) must never carry an
        # "emotion" key, so presentation can never leak which option is
        # correct. This is a structural guarantee, not a per-stage judgment
        # call — checked here so it can never regress.
        stage = self._stage(1, module_id="mod_03")
        for threat in stage["threats"]:
            for choice in threat["choices"]:
                self.assertNotIn("emotion", choice)

    def test_module_3_stage_1_ending_includes_bluetech_clue_without_full_reveal(self):
        stage = self._stage(1, module_id="mod_03")
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("BlueTech", ending)
        self.assertIn("Probably nothing", ending)
        campaign_leak_phrases = [
            "the same attacker who targeted bluetech",
            "this is part of the phishing campaign",
            "connected to the smishing campaign",
        ]
        for phrase in campaign_leak_phrases:
            self.assertNotIn(phrase, ending.lower())

    def test_module_3_stage_1_safe_playthrough_still_reaches_the_same_beats(self):
        stage = self._stage(1, module_id="mod_03")
        incident3_story = " ".join(line["text"] for line in stage["threats"][2]["story"])
        self.assertIn("Someone knows my bank account", incident3_story)
        ending = " ".join(line["text"] for line in stage["ending"])
        self.assertIn("BlueTech", ending)
        self.assertIn("PRIVATE NUMBER", ending)
        safe_outcomes = [
            next(choice for choice in threat["choices"] if choice["outcome"] == "SAFE")
            for threat in stage["threats"]
        ]
        self.assertEqual(len(safe_outcomes), 3)

    def test_module_3_stage_1_demo_story_events_are_well_formed(self):
        # Milestone: visible decision consequences. Only 3 demo choices are
        # authored with "story_event" on Stage 1; every other choice across
        # the whole project must remain untouched (no "story_event" key).
        stage = self._stage(1, module_id="mod_03")
        incident1_risky = next(
            c for c in stage["threats"][0]["choices"]
            if c["outcome"] == "RISKY" and "Keep the caller on the line" in c["label"]
        )
        events = incident1_risky["story_event"]
        self.assertIsInstance(events, list)
        self.assertEqual(events[0]["type"], "notification")
        self.assertEqual(events[0]["title"], "SECURITY ACTIVITY")
        self.assertEqual(events[1]["type"], "dialogue")
        self.assertEqual(events[1]["speaker"], "Daniel")
        self.assertEqual(events[1]["emotion"], "shocked")

        incident2_critical = next(c for c in stage["threats"][1]["choices"] if c["outcome"] == "CRITICAL")
        critical_events = incident2_critical["story_event"]
        self.assertEqual(critical_events[0]["type"], "status")
        self.assertEqual(critical_events[0]["title"], "CALL STATUS")
        self.assertEqual(critical_events[1]["type"], "notification")

        incident3_safe = next(c for c in stage["threats"][2]["choices"] if c["outcome"] == "SAFE")
        safe_event = incident3_safe["story_event"]
        self.assertEqual(safe_event["type"], "status")
        self.assertEqual(safe_event["title"], "FRAUD CASE")

        # Everywhere else on Stage 1, choices must be untouched.
        demo_choice_ids = {id(incident1_risky), id(incident2_critical), id(incident3_safe)}
        for threat in stage["threats"]:
            for choice in threat["choices"]:
                if id(choice) not in demo_choice_ids:
                    self.assertNotIn("story_event", choice)

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
