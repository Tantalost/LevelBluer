import unittest

from app.services.bkt_service import P_G, P_S, update_pl


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


if __name__ == "__main__":
    unittest.main()
