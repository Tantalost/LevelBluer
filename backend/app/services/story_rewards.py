"""Bounded story entitlements. Never updates mastery or assessment records."""
from copy import deepcopy
from math import isfinite

IDS = tuple(f"mod_01_ch_{n:02}" for n in range(1, 6))
OBJECTIVES = dict(zip(IDS, (
    ("sort", "highlight", "capture"), ("compare", "report", "headers"),
    ("links", "thorough", "priority"), ("timeline", "board", "case_note"),
    ("evidence", "resolve", "reconstruction"),
)))
REPORT_ANSWERS = {
    f"{source}_{kind}": f"{source}_{kind}"
    for source in ("survey", "urgent", "profile")
    for kind in ("capture", "sender", "excerpt")
}


def number(value, cap=9999):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not isfinite(value):
        return 0
    return max(0, min(cap, int(value)))


def mapping(value):
    return value if isinstance(value, dict) else {}


def has(state, field, items):
    values = state.get(field)
    return isinstance(values, list) and all(item in values for item in items)


def completed(chapter, state):
    if state.get("completed") is not True or state.get("sealed") is not True:
        return False
    if chapter == IDS[0]:
        return (has(state, "read", ("club", "survey", "library", "urgent", "receipt", "profile"))
                and has(state, "sorted", ("club", "survey", "library", "urgent", "receipt", "profile"))
                and all(has(state, field, ("survey", "urgent", "profile")) for field in ("flags", "domains", "captures")))
    if chapter == IDS[1]:
        return (has(state, "flags", ("domain", "wording", "signature")) and has(state, "domains", ("fake",))
                and has(state, "headers", ("From", "Reply-To", "Subject")))
    if chapter == IDS[2]:
        clues = state.get("hotspots", [])
        return (has(state, "revealed", ("payout",)) and has(state, "expanded", ("payout",))
                and isinstance(clues, list) and len(set(x for x in clues if isinstance(x, str)) & {"domain", "http", "security", "logo", "spelling"}) >= 3
                and state.get("reviewed") is True)
    if chapter == IDS[3]:
        return (state.get("claimed") is True and state.get("timeline_order") == ["survey", "eric", "jobert", "prize"]
                and has(state, "timeline_checked", ("prize",)) and has(state, "notes", ("prize",))
                and has(state, "connections", ("coffee|group", "earlier|typo", "jobert|time")))
    return (has(state, "solved", (0, 1, 2, 3)) and state.get("comic_checked") is True
            and state.get("aftermath_done") is True)


def report_base(chapter, state):
    if not completed(chapter, state):
        return 0
    if chapter != IDS[0]:
        return 100
    best = mapping(mapping(state.get("report")).get("best"))
    if not best:
        return 0  # New claims need a report; migration handles earlier completions.
    answers = mapping(best.get("answers"))
    score = sum(answers.get(slot) == item for slot, item in REPORT_ANSWERS.items())
    return 50 + 50 * score // 9


def eligible(chapter, objective, state):
    if not completed(chapter, state) or state.get("star_tracking") is not True:
        return False
    blocked = state.get("star_blocked", [])
    if not isinstance(blocked, list) or objective in blocked:
        return False
    if chapter == IDS[2]:
        if objective == "thorough":
            return has(state, "hotspots", ("domain", "http", "security", "logo", "spelling"))
        if objective == "priority":
            order = state.get("hotspot_order", [])
            if not isinstance(order, list) or not all(x in order for x in ("domain", "http")):
                return False
            return all(x not in order or order.index(x) > max(order.index("domain"), order.index("http")) for x in ("logo", "spelling"))
    if chapter == IDS[4]:
        if objective == "evidence":
            return state.get("round_errors") == [0, 0, 0, 0]
        if objective == "resolve":
            return number(state.get("restarts")) == 0
        if objective == "reconstruction":
            return number(state.get("comic_errors")) == 0
    return True


def clean_paid(raw):
    return {chapter: {"base": number(entry.get("base"), 100), "stars": number(entry.get("stars"), 75),
                      "unknown": entry.get("unknown") is True}
            for chapter, entry in mapping(raw).items() if chapter in IDS and isinstance(entry, dict)}


def total(paid):
    return sum(entry["base"] + entry["stars"] for entry in clean_paid(paid).values())


def migrate(snapshot):
    if snapshot.get("story_economy_version") == 2:
        return clean_paid(snapshot.get("story_paid"))
    result = {}
    claims = mapping(snapshot.get("story_reward_claims"))
    for chapter, state in mapping(snapshot.get("chapter_progress")).items():
        if chapter not in IDS or not isinstance(state, dict) or state.get("completed") is not True:
            continue
        reward = number(state.get("reward"), 125)
        bonus = number(state.get("star_bonus_awarded"), 75)
        if chapter == IDS[0]:
            bonus = max(bonus, sum(claims.get(f"{chapter}:{key}") is True for key in OBJECTIVES[chapter]) * 25)
        result[chapter] = {"base":100, "stars":max(bonus, max(0, reward - 100)), "unknown":reward not in (100, 125)}
    return result


def settle(incoming, stored):
    """Prepare one CAS write. Server history is authoritative for paid amounts."""
    stored = mapping(stored)
    paid = migrate(stored)
    # First uploaded legacy files retain their existing balances, never repay them.
    if not stored:
        paid = migrate({**incoming, "story_economy_version":0})
        # New v2 completions are pending, not historical grants.
        for chapter, state in mapping(incoming.get("chapter_progress")).items():
            if isinstance(state, dict) and state.get("performance_version") == 1:
                paid.pop(chapter, None)
    old_paid = deepcopy(paid)
    claims = {}
    for source in (stored, incoming):
        for chapter, entry in mapping(source.get("story_performance")).items():
            if chapter not in IDS or not isinstance(entry, dict):
                continue
            target = claims.setdefault(chapter, {"completion":{}, "objectives":{}})
            candidate = mapping(entry.get("completion"))
            if report_base(chapter, candidate) > report_base(chapter, target["completion"]):
                target["completion"] = deepcopy(candidate)
            for objective, proof in mapping(entry.get("objectives")).items():
                if objective in OBJECTIVES[chapter] and isinstance(proof, dict) and eligible(chapter, objective, proof):
                    target["objectives"].setdefault(objective, deepcopy(proof))
    for chapter, entry in claims.items():
        current = paid.setdefault(chapter, {"base":0, "stars":0, "unknown":False})
        if current["unknown"]:
            continue
        current["base"] = max(current["base"], report_base(chapter, entry["completion"]))
        legacy_stars = sum(mapping(stored.get("story_reward_claims")).get(f"{chapter}:{key}") is True
                           or key in entry["objectives"] for key in OBJECTIVES[chapter])
        current["stars"] = max(current["stars"], legacy_stars * 25)
    seen = clean_paid(incoming.get("story_paid"))
    acknowledged = sum(min(v["base"], old_paid.get(k, {}).get("base", 0)) + min(v["stars"], old_paid.get(k, {}).get("stars", 0)) for k, v in seen.items())
    blob = deepcopy(incoming)
    # Preserve originals and earlier stars when another device uploads a sparse
    # or unfinished snapshot. Corrected replay proofs live in the separate ledger.
    chapters = deepcopy(mapping(blob.get("chapter_progress")))
    for chapter in IDS:
        prior = mapping(mapping(stored.get("chapter_progress")).get(chapter))
        if prior and (prior.get("completed") is True or chapter not in chapters):
            chapters[chapter] = deepcopy(prior)
    if chapters:
        blob["chapter_progress"] = chapters
    old_claims = mapping(stored.get("story_reward_claims"))
    new_claims = mapping(blob.get("story_reward_claims"))
    blob["story_reward_claims"] = {key: True for key in (f"{IDS[0]}:{x}" for x in ("clear", *OBJECTIVES[IDS[0]]))
                                   if old_claims.get(key) is True or new_claims.get(key) is True}
    blob["story_economy_version"] = 2
    blob["story_paid"] = paid
    blob["story_performance"] = claims
    blob["credits"] = number(incoming.get("credits"), 2_000_000_000) + total(paid) - acknowledged
    if incoming.get("story_economy_version") != 2:
        # Old clients already included their historical grants in the wallet.
        blob["credits"] -= total(migrate(incoming))
    return blob
