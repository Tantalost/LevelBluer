import unittest

from app.services.bkt_service import (
    P_G,
    P_S,
    P_T,
    _evidence_posterior,
    update_pl,
    update_pl_diagnostic,
)


class BktSingleUpdateTest(unittest.TestCase):
    def test_one_correct_trace_answer_is_not_applied_twice(self):
        once = update_pl(0.10, True, p_t=0.15, p_g=P_G, p_s=P_S)
        twice = update_pl(once, True, p_t=0.15, p_g=P_G, p_s=P_S)
        self.assertAlmostEqual(once, 0.4333, places=4)
        self.assertGreater(twice, once)
        self.assertNotAlmostEqual(twice, 0.4333, places=3)

    def test_one_incorrect_trace_answer_is_a_single_update(self):
        once = update_pl(0.10, False, p_t=0.15, p_g=P_G, p_s=P_S)
        twice = update_pl(once, False, p_t=0.15, p_g=P_G, p_s=P_S)
        self.assertAlmostEqual(once, 0.1616, places=3)
        self.assertNotAlmostEqual(twice, once, places=4)


class BktWrongDropCapTest(unittest.TestCase):
    @staticmethod
    def _raw(p_l: float, is_correct: bool) -> float:
        posterior = _evidence_posterior(p_l, is_correct)
        return posterior + (1.0 - posterior) * P_T

    def test_wrong_answer_from_080_is_capped_at_070(self):
        self.assertAlmostEqual(self._raw(0.80, False), 0.40, places=4)
        self.assertAlmostEqual(update_pl(0.80, False), 0.70, places=6)

    def test_small_wrong_drop_is_unchanged(self):
        raw = self._raw(0.15, False)
        self.assertLess(0.15 - raw, 0.10)
        self.assertAlmostEqual(update_pl(0.15, False), raw, places=9)

    def test_correct_answer_uses_existing_formula(self):
        self.assertAlmostEqual(update_pl(0.80, True), self._raw(0.80, True), places=9)

    def test_consecutive_wrong_answers_each_capped(self):
        self.assertAlmostEqual(update_pl(update_pl(0.80, False), False), 0.60, places=6)

    def test_pretest_diagnostic_is_not_capped(self):
        self.assertAlmostEqual(update_pl_diagnostic(0.80, False), 0.3333, places=4)
        self.assertAlmostEqual(update_pl_diagnostic(0.10, True), 0.3333, places=4)


if __name__ == "__main__":
    unittest.main()
