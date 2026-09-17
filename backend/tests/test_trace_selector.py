import json
import random
import unittest
from collections import Counter
from pathlib import Path

from tests.test_trace_difficulties import TYPES, _load_modules, _questions

MODULE_SKILLS = {
    "mod_01": "phishing",
    "mod_02": "smishing",
    "mod_03": "vishing",
    "mod_04": "pretexting",
    "mod_05": "baiting",
}
AT_RISK = 0.40
PROFICIENT = 0.70
LEVEL_MANAGER = (
    Path(__file__).resolve().parents[2] / "frontend/src/gameplay/level_manager.gd"
)
PLAYER_MANAGER = (
    Path(__file__).resolve().parents[2] / "frontend/src/autoload/player_manager.gd"
)


def preferred_difficulty(p_learned: float) -> str:
    if p_learned < AT_RISK:
        return "easy"
    if p_learned < PROFICIENT:
        return "medium"
    return "hard"


def _qid(question: dict) -> str:
    return str(question.get("id", "")).strip()


def _difficulty(question: dict) -> str:
    value = str(question.get("difficulty", "")).strip().lower()
    return value if value in {"easy", "medium", "hard"} else ""


def _type_id(question: dict) -> str:
    value = str(question.get("_type_id") or question.get("type_id") or "").strip()
    return value or "other"


def _not_in(pool: list[dict], seen: list[str]) -> list[dict]:
    seen_set = set(seen)
    return [question for question in pool if _qid(question) not in seen_set]


def _with_difficulty(pool: list[dict], difficulty: str) -> list[dict]:
    return [question for question in pool if _difficulty(question) == difficulty]


def _usage_counts(pool: list[dict], seen: list[str]) -> Counter:
    seen_set = set(seen)
    counts: Counter = Counter()
    for question in pool:
        if _qid(question) in seen_set:
            counts[_type_id(question)] += 1
    return counts


def _pick_type_balanced(candidates: list[dict], usage_seen: list[str], pool: list[dict], rng: random.Random) -> dict:
    if not candidates:
        return {}
    counts = _usage_counts(pool, usage_seen)
    min_count = min(counts.get(_type_id(question), 0) for question in candidates)
    best = [question for question in candidates if counts.get(_type_id(question), 0) == min_count]
    return rng.choice(best)


def _balanced_count(candidates: list[dict], usage_seen: list[str], pool: list[dict]) -> int:
    if not candidates:
        return 0
    counts = _usage_counts(pool, usage_seen)
    min_count = min(counts.get(_type_id(question), 0) for question in candidates)
    return sum(1 for question in candidates if counts.get(_type_id(question), 0) == min_count)


def _ranked_difficulties(preferred: str, working: list[dict], pool: list[dict], usage_seen: list[str], rng: random.Random) -> list[str]:
    if preferred == "easy":
        return ["easy", "medium", "hard"]
    if preferred == "hard":
        return ["hard", "medium", "easy"]
    if preferred == "medium":
        if _with_difficulty(working, "medium"):
            return ["medium", "easy", "hard"]
        easy_best = _balanced_count(_with_difficulty(working, "easy"), usage_seen, pool)
        hard_best = _balanced_count(_with_difficulty(working, "hard"), usage_seen, pool)
        if hard_best > easy_best:
            return ["hard", "easy"]
        if easy_best > hard_best:
            return ["easy", "hard"]
        order = ["easy", "hard"]
        rng.shuffle(order)
        return order
    return ["easy", "medium", "hard"]


def select_adaptive(pool: list[dict], seen: list[str], missed: list[str], asked: list[str], preferred: str, rng: random.Random) -> dict:
    unseen = _not_in(pool, seen)
    working = unseen
    if not working:
        review = [question for question in pool if _qid(question) in set(missed) and _qid(question) not in set(asked)]
        working = review or _not_in(pool, asked) or list(pool)
    usage_seen = list(dict.fromkeys([*seen, *asked]))
    for difficulty in _ranked_difficulties(preferred, working, pool, usage_seen, rng):
        matched = _with_difficulty(working, difficulty)
        if matched:
            return _pick_type_balanced(matched, usage_seen, pool, rng)
    return _pick_type_balanced(working, usage_seen, pool, rng) if working else {}


def _take_balanced(candidates: list[dict], needed: int, type_counts: Counter, rng: random.Random) -> list[dict]:
    remaining = list(candidates)
    rng.shuffle(remaining)
    picked: list[dict] = []
    while len(picked) < needed and remaining:
        min_count = min(type_counts.get(_type_id(question), 0) for question in remaining)
        chosen = next(question for question in remaining if type_counts.get(_type_id(question), 0) == min_count)
        picked.append(chosen)
        remaining.remove(chosen)
        type_counts[_type_id(chosen)] += 1
    return picked


def build_exam_deck(pool: list[dict], rng: random.Random) -> list[dict]:
    type_counts: Counter = Counter()
    picked: list[dict] = []
    picked_ids: set[str] = set()
    for difficulty, needed in (("easy", 4), ("medium", 7), ("hard", 4)):
        available = [question for question in _with_difficulty(pool, difficulty) if _qid(question) not in picked_ids]
        taken = _take_balanced(available, needed, type_counts, rng)
        for question in taken:
            picked.append(question)
            picked_ids.add(_qid(question))
    if len(picked) < 15:
        leftover = [question for question in pool if _qid(question) not in picked_ids]
        picked.extend(_take_balanced(leftover, 15 - len(picked), type_counts, rng))
    rng.shuffle(picked)
    return picked[:15]


def _normalize_history(raw) -> dict[str, list[str]]:
    history = {module_id: [] for module_id in MODULE_SKILLS}
    if not isinstance(raw, dict):
        return history
    for module_id in MODULE_SKILLS:
        rows = raw.get(module_id, [])
        if not isinstance(rows, list):
            continue
        ids: list[str] = []
        for item in rows:
            qid = str(item).strip()
            if qid and qid not in ids:
                ids.append(qid)
        history[module_id] = ids
    return history


class TraceSelectorTest(unittest.TestCase):
    def test_preferred_difficulty_thresholds(self):
        self.assertEqual(preferred_difficulty(0.20), "easy")
        self.assertEqual(preferred_difficulty(0.39), "easy")
        self.assertEqual(preferred_difficulty(0.50), "medium")
        self.assertEqual(preferred_difficulty(0.69), "medium")
        self.assertEqual(preferred_difficulty(0.80), "hard")

    def test_selector_never_leaves_the_active_module(self):
        modules = _load_modules()
        rng = random.Random(7)
        for module_id, skill in MODULE_SKILLS.items():
            pool = _questions(modules[module_id])
            seen: list[str] = []
            asked: list[str] = []
            for _ in range(20):
                selected = select_adaptive(pool, seen, [], asked, preferred_difficulty(0.50), rng)
                qid = _qid(selected)
                prefix = module_id.replace("mod_", "mod")
                self.assertTrue(qid.startswith(prefix + "_"), qid)
                self.assertEqual(str(modules[module_id]["topic"]).lower(), skill)
                asked.append(qid)
                seen.append(qid)

    def test_unseen_questions_are_used_before_repeats(self):
        pool = _questions(_load_modules()["mod_03"])
        rng = random.Random(11)
        seen: list[str] = []
        asked: list[str] = []
        selected_ids: list[str] = []
        for _ in range(80):
            selected = select_adaptive(pool, seen, [], asked, "medium", rng)
            qid = _qid(selected)
            self.assertNotIn(qid, selected_ids)
            selected_ids.append(qid)
            asked.append(qid)
            seen.append(qid)
        self.assertEqual(len(set(selected_ids)), 80)
        missed = selected_ids[:5]
        eighty_first = select_adaptive(pool, seen, missed, [], "medium", rng)
        self.assertIn(_qid(eighty_first), missed)

    def test_type_balancing_prefers_least_used_type(self):
        pool = _questions(_load_modules()["mod_05"])
        easy = _with_difficulty(pool, "easy")
        present = {_type_id(question) for question in easy}
        target = sorted(present)[0]
        seen = [_qid(question) for question in easy if _type_id(question) != target]
        selected = _pick_type_balanced(easy, seen, pool, random.Random(3))
        self.assertEqual(_type_id(selected), target)

    def test_stage_10_deck_is_unique_4_7_4_and_module_local(self):
        modules = _load_modules()
        rng = random.Random(21)
        for module_id in MODULE_SKILLS:
            pool = _questions(modules[module_id])
            first = build_exam_deck(pool, random.Random(21))
            second = build_exam_deck(pool, random.Random(22))
            ids = [_qid(question) for question in first]
            prefix = module_id.replace("mod_", "mod")
            self.assertEqual(len(ids), 15)
            self.assertEqual(len(set(ids)), 15)
            self.assertTrue(all(qid.startswith(prefix + "_") for qid in ids))
            counts = Counter(_difficulty(question) for question in first)
            self.assertEqual(counts["easy"], 4)
            self.assertEqual(counts["medium"], 7)
            self.assertEqual(counts["hard"], 4)
            type_counts = Counter(_type_id(question) for question in first)
            self.assertLessEqual(max(type_counts.values()), 3)
            self.assertGreaterEqual(len(type_counts), 7)
            self.assertNotEqual(ids, [_qid(question) for question in second])

    def test_old_saves_without_trace_history_still_normalize(self):
        history = _normalize_history({})
        self.assertEqual(set(history), set(MODULE_SKILLS))
        self.assertTrue(all(ids == [] for ids in history.values()))
        restored = _normalize_history({"mod_03": ["mod03_tv_01", "mod03_tv_01", ""]})
        self.assertEqual(restored["mod_03"], ["mod03_tv_01"])
        self.assertEqual(restored["mod_01"], [])

    def test_gdscript_no_longer_randomly_disables_preferred_difficulty(self):
        source = LEVEL_MANAGER.read_text(encoding="utf-8")
        self.assertNotIn("if not chase_weak and randf() > 0.5:", source)
        self.assertIn("func _pick_adaptive_question() -> Dictionary:", source)
        self.assertIn("PlayerManager.preferred_difficulty(skill_id)", source)
        self.assertIn("[TRACE SELECT]", source)
        self.assertIn("[TRACE EXAM]", source)
        self.assertIn("review_missed", source)
        player = PLAYER_MANAGER.read_text(encoding="utf-8")
        self.assertIn("trace_seen_by_module", player)
        self.assertIn("func record_trace_result(", player)
        self.assertIn("func get_trace_seen(", player)
        self.assertIn("func get_trace_missed(", player)


if __name__ == "__main__":
    unittest.main()
