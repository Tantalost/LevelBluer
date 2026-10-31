extends RefCounted
## Explicit story-only capability policy. Never imported by assessment gameplay.
const CHAPTER: String = "mod_01_ch_01"
const VERSION: int = 1
const IDS: Array[String] = ["recap", "perspective", "reference"]
const DATA: Dictionary = {
	"recap": {"name":"Case Recap", "cost":0, "glyph":"capacity", "color":"c5afd7", "effect":"Review facts John has already encountered. No culprit or future events are revealed.", "limit":"Once per chapter / Day or Night"},
	"perspective": {"name":"Fresh Perspective", "cost":100, "glyph":"skill", "color":"85d9c3", "effect":"Get one extra contextual investigation hint. Evidence still has to be collected by you.", "limit":"Once per chapter / Night investigation"},
	"reference": {"name":"Cross-Reference", "cost":150, "glyph":"sandbox", "color":"8dbfda", "effect":"Compare two messages whose evidence screenshots you have already collected.", "limit":"Reusable / Two collected messages required"}
}

static func ids(raw: Variant, limit: int = 3) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for value: Variant in raw:
			if value is String and value in IDS and not result.has(value) and result.size() < limit: result.append(value)
	return result

static func new_run(id: String, loadout: Array[String], replay: bool, known: bool = true, chapter_id: String = CHAPTER) -> Dictionary:
	return {"id":id, "chapter":chapter_id, "content_version":1, "perk_version":VERSION, "loadout":loadout.duplicate(), "replay":replay, "known":known, "uses":{}, "events":[], "builtin_hints":0, "completed":false, "started_at":Time.get_unix_time_from_system(), "finished_at":0.0}

static func clean_run(raw: Variant) -> Dictionary:
	if not raw is Dictionary or str(raw.get("id", "")).is_empty() or raw.get("chapter") not in [CHAPTER, "mod_01_ch_02", "mod_01_ch_03", "mod_01_ch_04", "mod_01_ch_05", "mod_02_ch_01", "mod_02_ch_02", "mod_02_ch_03", "mod_02_ch_04", "mod_02_ch_05"]: return {}
	var run: Dictionary = new_run(str(raw.id).left(80), ids(raw.get("loadout", []), 2), raw.get("replay", false) == true, raw.get("known", false) == true, str(raw.chapter))
	for key: String in ["content_version", "perk_version", "builtin_hints"]:
		var value: Variant = raw.get(key, run[key])
		if (value is int or value is float) and is_finite(float(value)): run[key] = maxi(0, int(value))
	for key: String in ["started_at", "finished_at"]:
		var value: Variant = raw.get(key, 0.0)
		if (value is int or value is float) and is_finite(float(value)): run[key] = maxf(0, float(value))
	run["completed"] = raw.get("completed", false) == true
	var uses: Variant = raw.get("uses", {})
	if uses is Dictionary:
		for id: String in IDS:
			var count: Variant = uses.get(id, 0)
			if (count is int or count is float) and is_finite(float(count)) and int(count) > 0: run.uses[id] = int(count)
	var events: Variant = raw.get("events", [])
	if events is Array:
		for event: Variant in events:
			if event is Dictionary and str(event.get("perk", "")) in IDS + ["builtin_hint"]:
				run.events.append({"perk":str(event.perk), "phase":str(event.get("phase", "")).left(24), "beat":str(event.get("beat", "")).left(8), "at":str(event.get("at", "")).left(32)})
	return run

static func status(run: Dictionary, hint_used: bool = false) -> String:
	if hint_used or not (run.get("uses", {}) as Dictionary).is_empty() or int(run.get("builtin_hints", 0)) > 0: return "assisted"
	return "unassisted" if run.get("known", false) == true else "unknown"

static func allowed(run: Dictionary, id: String, context: String, phase: String, captures: Array) -> bool:
	# Deny by default: no test/checkpoint/assessment context can activate a perk.
	if context != "story_chapter" or run.get("chapter") not in [CHAPTER, "mod_01_ch_02", "mod_01_ch_03", "mod_01_ch_04", "mod_01_ch_05", "mod_02_ch_01", "mod_02_ch_02", "mod_02_ch_03", "mod_02_ch_04", "mod_02_ch_05"] or run.get("completed", false): return false
	if int(run.get("perk_version", 0)) != VERSION or id not in run.get("loadout", []): return false
	var phases: Array = ["day", "sort", "highlight", "notes", "capture", "seal", "sleep"] if run.chapter == CHAPTER else ["day", "compare", "report", "headers", "seal", "sleep"]
	if run.chapter == "mod_01_ch_03": phases = ["day", "reveal", "expand", "flaws", "seal", "sleep"]
	if run.chapter == "mod_01_ch_04": phases = ["day","timeline","board","case_note","seal","sleep"]
	if run.chapter == "mod_02_ch_01": phases = ["day","reveal","expand","verify","seal","sleep"]
	if run.chapter == "mod_02_ch_02": phases = ["day","purpose","contradiction","verify","seal","sleep"]
	if run.chapter == "mod_02_ch_03": phases = ["day","sources","contact","verify","seal","sleep"]
	if run.chapter == "mod_02_ch_04": phases = ["day","sequence","route","verify","seal","sleep"]
	if run.chapter == "mod_02_ch_05": phases = ["day","fee","code","public","reconstruct","seal","sleep"]
	if run.chapter == "mod_01_ch_05": phases = ["debate","final","comic"]
	if phase not in phases: return false
	if id != "reference" and int(run.get("uses", {}).get(id, 0)) > 0: return false
	match id:
		"recap": return true
		"perspective": return phase in ["fee", "code", "public", "reconstruct", "sequence", "route", "sources", "contact", "purpose", "contradiction", "sort", "highlight", "notes", "capture", "compare", "report", "headers", "reveal", "expand", "verify", "flaws", "timeline", "board", "case_note", "debate", "final", "comic"]
		"reference": return phase in ["capture", "compare", "report", "headers", "seal", "sleep", "debate", "final", "comic"] and captures.size() >= 2
	return false

static func activate(run: Dictionary, id: String, context: String, phase: String, beat: int, captures: Array) -> bool:
	if not allowed(run, id, context, phase, captures): return false
	run.uses[id] = int(run.uses.get(id, 0)) + 1
	record(run, id, phase, beat)
	return true

static func record(run: Dictionary, id: String, phase: String, beat: int) -> void:
	run.events.append({"perk":id, "phase":phase, "beat":str(beat), "at":str(Time.get_unix_time_from_system())})
