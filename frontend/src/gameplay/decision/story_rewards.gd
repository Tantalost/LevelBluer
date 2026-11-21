extends RefCounted
## Pure story performance policy. No nodes, wallet writes or graded observations.
const VERSION: int = 2
const IDS: Array[String] = ["mod_01_ch_01", "mod_01_ch_02", "mod_01_ch_03", "mod_01_ch_04", "mod_01_ch_05"]
const GOALS: Dictionary = {
	"mod_01_ch_01": {"sort":"Accurate sorting / Sort all six messages without an incorrect submission.", "highlight":"Spot the manipulation / Mark all three requests without an incorrect selection.", "capture":"Preserve the evidence / Capture each exhibit correctly on its first submission."},
	"mod_01_ch_02": {"compare":"Spot the differences / Find all three differences without a wrong selection.", "report":"Exact transcription / Submit the sender domain correctly on the first check.", "headers":"Follow the reply / Match all three header fields without a wrong placement."},
	"mod_01_ch_03": {"links":"Trace the destination / Record the displayed-link mismatch and expand its destination.", "thorough":"Look beyond the minimum / Inspect all five page clues.", "priority":"Check the address first / Inspect the domain and HTTP connection before branding or spelling."},
	"mod_01_ch_04": {"timeline":"Reconstruct the morning / Submit the four records in order on the first check.", "board":"Connect the context / Match all three connections without a wrong pair.", "case_note":"Record the gap / Submit the time gap and preceding event correctly on the first check."},
	"mod_01_ch_05": {"evidence":"Defend with evidence / Resolve all four rounds without an incorrect evidence command.", "resolve":"Hold your ground / Finish the hearing without a credibility restart.", "reconstruction":"Reconstruct the case / Submit the six frames correctly on the first check."}
}
const PROOF_FIELDS: Array[String] = ["completed", "sealed", "claimed", "star_tracking", "star_blocked", "performance_version", "read", "sorted", "flags", "domains", "captures", "headers", "revealed", "expanded", "hotspots", "hotspot_order", "reviewed", "timeline_order", "timeline_checked", "connections", "notes", "solved", "round_errors", "restarts", "comic_checked", "comic_errors", "aftermath_done", "report"]

static func number(value: Variant, maximum: int = 9999) -> int:
	return clampi(int(value), 0, maximum) if (value is int or value is float) and is_finite(float(value)) else 0

static func ids(chapter: String) -> Array[String]:
	var result: Array[String] = []
	if GOALS.has(chapter): result.assign(GOALS[chapter].keys())
	return result

static func track(state: Dictionary, raw: Dictionary, chapter: String) -> void:
	if chapter not in IDS: return
	state.performance_version = 1 if raw.is_empty() or raw.get("performance_version", 0) == 1 else 0
	if chapter != IDS[0]: state.star_tracking = state.performance_version == 1
	if not state.has("star_blocked"): state.star_blocked = []
	if raw.get("star_blocked") is Array:
		for id: String in ids(chapter):
			if id in raw.star_blocked and id not in state.star_blocked: state.star_blocked.append(id)
	state.hotspot_order = []
	if raw.get("hotspot_order") is Array:
		for value: Variant in raw.hotspot_order:
			if value in ["domain", "http", "security", "logo", "spelling"] and value not in state.hotspot_order: state.hotspot_order.append(value)

static func block(state: Dictionary, chapter: String, objective: String) -> void:
	if objective not in ids(chapter): return
	if not state.has("star_blocked"): state.star_blocked = []
	if objective not in state.star_blocked: state.star_blocked.append(objective)

static func hint_objective(chapter: String, phase: String) -> String:
	if chapter == IDS[2]: return "priority" if phase == "flaws" else "links"
	if chapter == IDS[4]: return "reconstruction" if phase == "comic" else ("evidence" if phase == "debate" else "")
	return phase if phase in ids(chapter) else ""

static func earned(chapter: String, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not state.get("completed", false) or not state.get("star_tracking", false): return result
	for id: String in ids(chapter):
		if id in state.get("star_blocked", []): continue
		var eligible: bool = true
		if chapter == IDS[2]:
			var order: Array = state.get("hotspot_order", [])
			match id:
				"links": eligible = state.get("revealed", []).has("payout") and state.get("expanded", []).has("payout")
				"thorough": eligible = state.get("hotspots", []).size() == 5
				"priority":
					eligible = order.has("domain") and order.has("http")
					for cosmetic: String in ["logo", "spelling"]:
						if order.has(cosmetic) and (order.find(cosmetic) < order.find("domain") or order.find(cosmetic) < order.find("http")): eligible = false
		if chapter == IDS[4]:
			match id:
				"evidence":
					eligible = state.get("solved", []).size() == 4
					for errors: Variant in state.get("round_errors", []):
						if number(errors) > 0: eligible = false
				"resolve": eligible = number(state.get("restarts", 0)) == 0
				"reconstruction": eligible = state.get("comic_checked", false) and number(state.get("comic_errors", 0)) == 0
		if eligible: result.append(id)
	return result

static func proof(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in PROOF_FIELDS:
		if state.has(field): result[field] = state[field]
	return result.duplicate(true)

static func base(chapter: String, state: Dictionary) -> int:
	if not state.get("completed", false): return 0
	if chapter != IDS[0]: return 100
	var best: Dictionary = state.get("report", {}).get("best", {})
	if best.is_empty(): return 100 # Historical completion; never fabricate a report score.
	return 50 + int(floor(50.0 * number(best.get("score", 0), 9) / 9.0))

static func clean_paid(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary: return result
	for chapter: String in IDS:
		if raw.get(chapter) is Dictionary:
			var entry: Dictionary = raw[chapter]
			result[chapter] = {"base":number(entry.get("base", 0), 100), "stars":number(entry.get("stars", 0), 75), "unknown":entry.get("unknown", false) == true}
	return result

static func total(paid: Dictionary) -> int:
	var result: int = 0
	for entry: Dictionary in clean_paid(paid).values(): result += int(entry.base) + int(entry.stars)
	return result

static func join_paid(first: Dictionary, second: Dictionary) -> Dictionary:
	var result: Dictionary = clean_paid(first)
	for chapter: String in clean_paid(second):
		var other: Dictionary = clean_paid(second)[chapter]
		var entry: Dictionary = result.get(chapter, {"base":0, "stars":0, "unknown":false})
		result[chapter] = {"base":maxi(entry.base, other.base), "stars":maxi(entry.stars, other.stars), "unknown":entry.unknown or other.unknown}
	return result
