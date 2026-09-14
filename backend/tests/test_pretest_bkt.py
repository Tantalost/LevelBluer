import unittest

from app.services.bkt_service import (
    P_G,
    P_S,
    P_T,
    update_pl,
    update_pl_diagnostic,
)


def _godot_pretest_step(p_l: float, is_correct: bool) -> float:
    """Match PretestBank._update_pl_diagnostic + snappedf(..., 0.0001)."""
    p_l = min(0.99, max(0.01, p_l))
    if is_correct:
        numer = p_l * (1.0 - P_S)
        denom = numer + (1.0 - p_l) * P_G
    else:
        numer = p_l * P_S
        denom = numer + (1.0 - p_l) * (1.0 - P_G)
    posterior = numer / denom if denom > 0.0 else p_l
    clamped = min(0.99, max(0.01, posterior))
    return round(clamped, 4)


class PretestDiagnosticBktTest(unittest.TestCase):
    def test_one_correct_pretest_answer_skips_learning(self):
        diagnostic = update_pl_diagnostic(0.10, True, p_g=P_G, p_s=P_S)
        learned = update_pl(0.10, True, p_t=P_T, p_g=P_G, p_s=P_S)
        self.assertAlmostEqual(diagnostic, 0.3333, places=4)
        self.assertAlmostEqual(learned, 0.4000, places=4)
        self.assertGreater(learned, diagnostic)

    def test_one_incorrect_pretest_answer_skips_learning(self):
        diagnostic = update_pl_diagnostic(0.10, False, p_g=P_G, p_s=P_S)
        learned = update_pl(0.10, False, p_t=P_T, p_g=P_G, p_s=P_S)
        self.assertAlmostEqual(diagnostic, 0.0137, places=4)
        self.assertGreater(learned, diagnostic)

    def test_trace_gameplay_still_applies_authored_p_t(self):
        once = update_pl(0.10, True, p_t=0.15, p_g=P_G, p_s=P_S)
        self.assertAlmostEqual(once, 0.4333, places=4)

    def test_backend_and_godot_pretest_sequences_match(self):
        answers = [
            True,
            False,
            True,
            True,
            False,
            True,
            False,
            False,
            True,
            True,
            True,
            False,
            True,
            False,
            True,
        ]
        backend = 0.10
        godot = 0.10
        for is_correct in answers:
            backend = round(update_pl_diagnostic(backend, is_correct), 4)
            godot = _godot_pretest_step(godot, is_correct)
            self.assertAlmostEqual(backend, godot, places=4)


if __name__ == "__main__":
    unittest.main()
