"""Classic Bayesian Knowledge Tracing (Corbett & Anderson, 1995)."""

TOPICS = ("Phishing", "Smishing", "Vishing", "Pretexting", "Baiting")

# Default skill parameters used when a question does not override them.
P_L0 = 0.10  # prior probability the skill is already known
P_T = 0.10  # probability of learning after an opportunity
P_G = 0.20  # probability of a correct guess while unknown
P_S = 0.10  # probability of a slip while known

MASTERY_COLUMNS = {
    "Phishing": "mastery_phishing",
    "Smishing": "mastery_smishing",
    "Vishing": "mastery_vishing",
    "Pretexting": "mastery_pretexting",
    "Baiting": "mastery_baiting",
}


def clamp_pl(value: float) -> float:
    return min(0.99, max(0.01, float(value)))


def initial_pl(stored: float | None) -> float:
    """Fresh accounts store 0; start BKT from P(L0) instead of a dead prior."""
    if stored is None or stored <= 0:
        return P_L0
    return clamp_pl(stored)


def update_pl(
    p_l: float,
    is_correct: bool,
    p_t: float = P_T,
    p_g: float = P_G,
    p_s: float = P_S,
) -> float:
    p_l = clamp_pl(p_l)
    if is_correct:
        numer = p_l * (1.0 - p_s)
        denom = numer + (1.0 - p_l) * p_g
    else:
        numer = p_l * p_s
        denom = numer + (1.0 - p_l) * (1.0 - p_g)

    posterior = numer / denom if denom > 0 else p_l
    learned = posterior + (1.0 - posterior) * p_t
    return clamp_pl(learned)


def average_pl(mastery: dict[str, float]) -> float:
    if not mastery:
        return 0.0
    return sum(mastery.values()) / len(mastery)
