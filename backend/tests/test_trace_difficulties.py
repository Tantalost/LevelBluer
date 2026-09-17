import json
from collections import Counter
from pathlib import Path
import unittest

VALID = {"easy", "medium", "hard"}
TYPES = (
    "trust_verdict",
    "spot_the_tell",
    "sender_audit",
    "url_spoof",
    "tap_trap_lines",
    "inbox_triage",
    "consequence_choice",
    "safety_rule_tf",
)
BANK_PATH = Path(__file__).resolve().parents[2] / "frontend/data/questions.json"


def _load_modules() -> dict[str, dict]:
    raw = json.loads(BANK_PATH.read_text(encoding="utf-8"))
    if "modules" in raw:
        return {str(module.get("module_id")): module for module in raw["modules"]}
    return {str(raw.get("module_id", "mod_01")): raw}


def _questions(module: dict) -> list[dict]:
    items: list[dict] = []
    for type_row in module.get("question_types", []):
        for question in type_row.get("questions", []):
            item = dict(question)
            item["_type_id"] = type_row.get("type_id")
            items.append(item)
    return items


class TraceDifficultiesTest(unittest.TestCase):
    def test_every_trace_question_has_one_valid_difficulty(self):
        modules = _load_modules()
        self.assertIn("mod_01", modules)
        questions = _questions(modules["mod_01"])
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


class Module2TraceCoverageTest(unittest.TestCase):
    def test_module_2_smishing_bank_is_complete_and_separate(self):
        modules = _load_modules()
        self.assertIn("mod_01", modules)
        self.assertIn("mod_02", modules)
        self.assertIn("mod_03", modules)
        mod1 = _questions(modules["mod_01"])
        mod2 = _questions(modules["mod_02"])
        self.assertEqual(modules["mod_01"]["module_id"], "mod_01")
        self.assertEqual(modules["mod_02"]["module_id"], "mod_02")
        self.assertEqual(str(modules["mod_01"]["topic"]).lower(), "phishing")
        self.assertEqual(str(modules["mod_02"]["topic"]).lower(), "smishing")
        self.assertEqual(len(mod1), 80)
        self.assertEqual(len(mod2), 80)
        self.assertEqual(len(mod1) + len(mod2), 160)

        type_counts = Counter(str(q["_type_id"]) for q in mod2)
        self.assertEqual(set(type_counts), set(TYPES))
        for type_id in TYPES:
            self.assertEqual(type_counts[type_id], 10, type_id)

        counts = Counter()
        missing = 0
        invalid = 0
        ids = []
        for question in mod2:
            qid = str(question.get("id", ""))
            ids.append(qid)
            self.assertTrue(qid.startswith("mod02_"))
            value = str(question.get("difficulty", "")).strip().lower()
            if not value:
                missing += 1
                continue
            if value not in VALID:
                invalid += 1
                continue
            counts[value] += 1
            bkt = question.get("bkt", {})
            self.assertAlmostEqual(float(bkt.get("p_g", 0)), 0.20)
            self.assertAlmostEqual(float(bkt.get("p_s", 0)), 0.10)
            self.assertAlmostEqual(float(bkt.get("p_t", 0)), 0.15)

        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(missing, 0)
        self.assertEqual(invalid, 0)
        self.assertEqual(counts["easy"], 24)
        self.assertEqual(counts["medium"], 32)
        self.assertEqual(counts["hard"], 24)
        self.assertTrue(all(not qid.startswith("mod01_") for qid in ids))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod01_") for q in mod1))


MODULE_SKILLS = {
    "mod_01": "phishing",
    "mod_02": "smishing",
    "mod_03": "vishing",
    "mod_04": "pretexting",
    "mod_05": "baiting",
}


class Module3TraceCoverageTest(unittest.TestCase):
    def test_module_3_vishing_bank_is_complete_and_separate(self):
        modules = _load_modules()
        self.assertIn("mod_01", modules)
        self.assertIn("mod_02", modules)
        self.assertIn("mod_03", modules)
        mod1 = _questions(modules["mod_01"])
        mod2 = _questions(modules["mod_02"])
        mod3 = _questions(modules["mod_03"])
        self.assertEqual(modules["mod_03"]["module_id"], "mod_03")
        self.assertEqual(str(modules["mod_03"]["topic"]).lower(), "vishing")
        self.assertEqual(len(mod1), 80)
        self.assertEqual(len(mod2), 80)
        self.assertEqual(len(mod3), 80)
        self.assertEqual(len(mod1) + len(mod2) + len(mod3), 240)

        type_counts = Counter(str(q["_type_id"]) for q in mod3)
        self.assertEqual(set(type_counts), set(TYPES))
        for type_id in TYPES:
            self.assertEqual(type_counts[type_id], 10, type_id)

        counts = Counter()
        missing = 0
        invalid = 0
        ids = []
        for question in mod3:
            qid = str(question.get("id", ""))
            ids.append(qid)
            self.assertTrue(qid.startswith("mod03_"))
            value = str(question.get("difficulty", "")).strip().lower()
            if not value:
                missing += 1
                continue
            if value not in VALID:
                invalid += 1
                continue
            counts[value] += 1
            bkt = question.get("bkt", {})
            self.assertAlmostEqual(float(bkt.get("p_g", 0)), 0.20)
            self.assertAlmostEqual(float(bkt.get("p_s", 0)), 0.10)
            self.assertAlmostEqual(float(bkt.get("p_t", 0)), 0.15)

        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(missing, 0)
        self.assertEqual(invalid, 0)
        self.assertEqual(counts["easy"], 24)
        self.assertEqual(counts["medium"], 32)
        self.assertEqual(counts["hard"], 24)
        self.assertTrue(all(not qid.startswith("mod01_") and not qid.startswith("mod02_") for qid in ids))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod01_") for q in mod1))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod02_") for q in mod2))

    def test_module_3_selector_is_vishing_only(self):
        modules = _load_modules()
        self.assertEqual(MODULE_SKILLS["mod_03"], "vishing")
        self.assertNotIn(MODULE_SKILLS["mod_03"], {"phishing", "smishing"})
        selected = []
        for type_row in modules["mod_03"].get("question_types", []):
            for question in type_row.get("questions", []):
                selected.append(question)
                self.assertTrue(str(question.get("id", "")).startswith("mod03_"))
        self.assertEqual(len(selected), 80)
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod01_") for q in selected))
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod02_") for q in selected))
        self.assertEqual(str(modules["mod_03"]["topic"]).lower(), "vishing")
        self.assertEqual(str(modules["mod_01"]["topic"]).lower(), "phishing")
        self.assertEqual(str(modules["mod_02"]["topic"]).lower(), "smishing")


class Module4TraceCoverageTest(unittest.TestCase):
    def test_module_4_pretexting_bank_is_complete_and_separate(self):
        modules = _load_modules()
        self.assertIn("mod_01", modules)
        self.assertIn("mod_02", modules)
        self.assertIn("mod_03", modules)
        self.assertIn("mod_04", modules)
        mod1 = _questions(modules["mod_01"])
        mod2 = _questions(modules["mod_02"])
        mod3 = _questions(modules["mod_03"])
        mod4 = _questions(modules["mod_04"])
        self.assertEqual(modules["mod_04"]["module_id"], "mod_04")
        self.assertEqual(str(modules["mod_04"]["topic"]).lower(), "pretexting")
        self.assertEqual(len(mod1), 80)
        self.assertEqual(len(mod2), 80)
        self.assertEqual(len(mod3), 80)
        self.assertEqual(len(mod4), 80)
        self.assertEqual(len(mod1) + len(mod2) + len(mod3) + len(mod4), 320)

        type_counts = Counter(str(q["_type_id"]) for q in mod4)
        self.assertEqual(set(type_counts), set(TYPES))
        for type_id in TYPES:
            self.assertEqual(type_counts[type_id], 10, type_id)

        counts = Counter()
        missing = 0
        invalid = 0
        ids = []
        for question in mod4:
            qid = str(question.get("id", ""))
            ids.append(qid)
            self.assertTrue(qid.startswith("mod04_"))
            value = str(question.get("difficulty", "")).strip().lower()
            if not value:
                missing += 1
                continue
            if value not in VALID:
                invalid += 1
                continue
            counts[value] += 1
            bkt = question.get("bkt", {})
            self.assertAlmostEqual(float(bkt.get("p_g", 0)), 0.20)
            self.assertAlmostEqual(float(bkt.get("p_s", 0)), 0.10)
            self.assertAlmostEqual(float(bkt.get("p_t", 0)), 0.15)

        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(missing, 0)
        self.assertEqual(invalid, 0)
        self.assertEqual(counts["easy"], 24)
        self.assertEqual(counts["medium"], 32)
        self.assertEqual(counts["hard"], 24)
        self.assertTrue(
            all(
                not qid.startswith("mod01_")
                and not qid.startswith("mod02_")
                and not qid.startswith("mod03_")
                for qid in ids
            )
        )
        self.assertTrue(all(str(q.get("id", "")).startswith("mod01_") for q in mod1))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod02_") for q in mod2))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod03_") for q in mod3))

    def test_module_4_selector_is_pretexting_only(self):
        modules = _load_modules()
        self.assertEqual(MODULE_SKILLS["mod_04"], "pretexting")
        self.assertNotIn(MODULE_SKILLS["mod_04"], {"phishing", "smishing", "vishing"})
        selected = []
        for type_row in modules["mod_04"].get("question_types", []):
            for question in type_row.get("questions", []):
                selected.append(question)
                self.assertTrue(str(question.get("id", "")).startswith("mod04_"))
        self.assertEqual(len(selected), 80)
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod01_") for q in selected))
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod02_") for q in selected))
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod03_") for q in selected))
        self.assertEqual(str(modules["mod_04"]["topic"]).lower(), "pretexting")
        self.assertEqual(str(modules["mod_01"]["topic"]).lower(), "phishing")
        self.assertEqual(str(modules["mod_02"]["topic"]).lower(), "smishing")
        self.assertEqual(str(modules["mod_03"]["topic"]).lower(), "vishing")


class Module5TraceCoverageTest(unittest.TestCase):
    def test_module_5_baiting_bank_is_complete_and_separate(self):
        modules = _load_modules()
        self.assertEqual(set(modules), {"mod_01", "mod_02", "mod_03", "mod_04", "mod_05"})
        mod1 = _questions(modules["mod_01"])
        mod2 = _questions(modules["mod_02"])
        mod3 = _questions(modules["mod_03"])
        mod4 = _questions(modules["mod_04"])
        mod5 = _questions(modules["mod_05"])
        self.assertEqual(modules["mod_05"]["module_id"], "mod_05")
        self.assertEqual(str(modules["mod_05"]["topic"]).lower(), "baiting")
        self.assertEqual(len(mod1), 80)
        self.assertEqual(len(mod2), 80)
        self.assertEqual(len(mod3), 80)
        self.assertEqual(len(mod4), 80)
        self.assertEqual(len(mod5), 80)
        self.assertEqual(len(mod1) + len(mod2) + len(mod3) + len(mod4) + len(mod5), 400)

        type_counts = Counter(str(q["_type_id"]) for q in mod5)
        self.assertEqual(set(type_counts), set(TYPES))
        for type_id in TYPES:
            self.assertEqual(type_counts[type_id], 10, type_id)

        counts = Counter()
        missing = 0
        invalid = 0
        ids = []
        for question in mod5:
            qid = str(question.get("id", ""))
            ids.append(qid)
            self.assertTrue(qid.startswith("mod05_"))
            value = str(question.get("difficulty", "")).strip().lower()
            if not value:
                missing += 1
                continue
            if value not in VALID:
                invalid += 1
                continue
            counts[value] += 1
            bkt = question.get("bkt", {})
            self.assertAlmostEqual(float(bkt.get("p_g", 0)), 0.20)
            self.assertAlmostEqual(float(bkt.get("p_s", 0)), 0.10)
            self.assertAlmostEqual(float(bkt.get("p_t", 0)), 0.15)

        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(missing, 0)
        self.assertEqual(invalid, 0)
        self.assertEqual(counts["easy"], 24)
        self.assertEqual(counts["medium"], 32)
        self.assertEqual(counts["hard"], 24)
        self.assertTrue(
            all(
                not qid.startswith("mod01_")
                and not qid.startswith("mod02_")
                and not qid.startswith("mod03_")
                and not qid.startswith("mod04_")
                for qid in ids
            )
        )
        self.assertTrue(all(str(q.get("id", "")).startswith("mod01_") for q in mod1))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod02_") for q in mod2))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod03_") for q in mod3))
        self.assertTrue(all(str(q.get("id", "")).startswith("mod04_") for q in mod4))

    def test_module_5_selector_is_baiting_only(self):
        modules = _load_modules()
        self.assertEqual(MODULE_SKILLS["mod_05"], "baiting")
        self.assertNotIn(MODULE_SKILLS["mod_05"], {"phishing", "smishing", "vishing", "pretexting"})
        selected = []
        for type_row in modules["mod_05"].get("question_types", []):
            for question in type_row.get("questions", []):
                selected.append(question)
                self.assertTrue(str(question.get("id", "")).startswith("mod05_"))
        self.assertEqual(len(selected), 80)
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod01_") for q in selected))
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod02_") for q in selected))
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod03_") for q in selected))
        self.assertTrue(all(not str(q.get("id", "")).startswith("mod04_") for q in selected))
        self.assertEqual(str(modules["mod_05"]["topic"]).lower(), "baiting")
        self.assertEqual(str(modules["mod_01"]["topic"]).lower(), "phishing")
        self.assertEqual(str(modules["mod_02"]["topic"]).lower(), "smishing")
        self.assertEqual(str(modules["mod_03"]["topic"]).lower(), "vishing")
        self.assertEqual(str(modules["mod_04"]["topic"]).lower(), "pretexting")


if __name__ == "__main__":
    unittest.main()
