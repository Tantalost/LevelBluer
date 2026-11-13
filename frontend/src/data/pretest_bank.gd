class_name PretestBank
extends RefCounted
## Bundled per-module pre-test. Used when the mobile API is unreachable.

const BANK_PATH := "res://data/pretest_questions.json"
const MODULE_1_ID := "mod_01"
const P_L0 := 0.10
const P_G := 0.20
const P_S := 0.10

## Zero-based lesson objectives, keyed by the stable diagnostic item IDs 1–15.
## Multi-objective misses require every associated lesson, not a guessed topic.
const ROUTE_VERSION: int = 1
const LESSON_MAP: Dictionary = {
	"mod_01": [[0,4],[0],[1],[5],[2],[1],[2,5],[3],[1,3],[1,4],[1,5],[2],[5],[0,1],[3,4]],
	"mod_02": [[0],[2],[1,3],[0],[1],[1],[3],[2],[4],[3],[0],[1],[1],[5],[4,5]],
	"mod_03": [[0],[0,3],[1],[2],[1],[2],[3],[0,3],[2],[5],[4],[1,3],[2],[2,5],[4,5]],
	"mod_04": [[0],[0,4],[4],[2],[1],[2],[1],[4],[3],[1],[3],[2,3],[1,4],[5],[3,5]],
	"mod_05": [[0],[0,2],[1,5],[1],[4],[4],[1,3],[2,5],[4],[4],[0,5],[2],[1],[2,4],[3,5]],
}


static func has_route_coverage(module_id: String) -> bool:
	var mapping: Array = LESSON_MAP.get(module_id, [])
	var bank: Array = _bank_for(module_id)
	if bank.size() != 15 or mapping.size() != 15:
		return false
	var covered: Dictionary = {}
	var ids: Dictionary = {}
	for question: Dictionary in bank:
		var id: int = int(question.get("id", 0))
		if id < 1 or id > 15 or ids.has(id):
			return false
		ids[id] = true
		for index: int in mapping[id - 1]:
			if index < 0 or index >= 6:
				return false
			covered[index] = true
	return covered.size() == 6


static func route_baseline(module_id: String, baseline: Dictionary) -> Dictionary:
	var result: Dictionary = baseline.duplicate(true)
	result["route"] = "full"
	result["required_lessons"] = [0,1,2,3,4,5]
	if int(result.get("total", 0)) != 15 or not has_route_coverage(module_id):
		return result
	var correct: int = int(result.get("correct", 0))
	# A historical perfect 15-item result has no missing concepts to reconstruct.
	if correct == 15:
		result.merge({"route":"cleared", "required_lessons":[], "missed_ids":[], "route_version":ROUTE_VERSION}, true)
	elif correct >= 12 and int(result.get("route_version", 0)) == ROUTE_VERSION:
		var raw: Variant = result.get("missed_ids", [])
		if not raw is Array or raw.size() != 15 - correct:
			return result
		var missed: Array[int] = []
		var required: Array[int] = []
		for value: Variant in raw:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or int(value) < 1 or int(value) > 15 or int(value) in missed:
				return result
			missed.append(int(value))
			for index: int in LESSON_MAP[module_id][int(value) - 1]:
				if index not in required:
					required.append(index)
		required.sort()
		result["route"] = "targeted"
		result["required_lessons"] = required
	return result

## Keep the first score; only fill missing item evidence from a matching result.
static func merge_baselines(primary: Dictionary, secondary: Dictionary) -> Dictionary:
	var merged: Dictionary = primary.duplicate(true)
	for module_id: String in secondary:
		if not LESSON_MAP.has(module_id) or not secondary[module_id] is Dictionary:
			continue
		if not merged.has(module_id):
			merged[module_id] = secondary[module_id].duplicate(true)
			continue
		if not merged[module_id] is Dictionary:
			continue
		var first: Dictionary = route_baseline(module_id, merged[module_id])
		var other: Dictionary = route_baseline(module_id, secondary[module_id])
		if first.get("correct", -1) != other.get("correct", -2) or first.get("total", -1) != other.get("total", -2):
			continue
		if first.route == "full" and other.route == "targeted":
			merged[module_id] = other
	return merged


static var _banks: Dictionary = {}
static var _loaded: bool = false


static func public_questions(module_id: String) -> Array:
	var bank: Array = _bank_for(module_id)
	var out: Array = []
	for i in bank.size():
		var row: Dictionary = bank[i]
		var payload := {
			"id": int(row.get("id", 0)),
			"topic": str(row.get("topic", "")),
			"type": str(row.get("type", "multiple_choice")),
			"text": str(row.get("text", "")),
		}
		if row.has("options") and typeof(row.get("options")) == TYPE_ARRAY:
			payload["options"] = (row["options"] as Array).duplicate()
		out.append(payload)
	return out


static func grade(module_id: String, answers: Array, current_pl: float) -> Dictionary:
	var bank: Array = _bank_for(module_id)
	if bank.is_empty() or answers.is_empty():
		return {"ok": false}
	var by_id: Dictionary = {}
	for i in bank.size():
		var row: Dictionary = bank[i]
		by_id[int(row.get("id", 0))] = row
	if by_id.size() != answers.size():
		return {"ok": false}
	var submitted: Dictionary = {}
	for i in answers.size():
		var item: Variant = answers[i]
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var row: Dictionary = item
		submitted[int(row.get("id", 0))] = row.get("answer")
	for qid in by_id.keys():
		if not submitted.has(qid):
			return {"ok": false}
	var topic := str((bank[0] as Dictionary).get("topic", "Phishing"))
	var p_l: float = _initial_pl(current_pl)
	var correct_count: int = 0
	var missed_ids: Array[int] = []
	for i in bank.size():
		var question: Dictionary = bank[i]
		var qid: int = int(question.get("id", 0))
		var is_correct: bool = _is_correct(question, submitted.get(qid))
		if is_correct:
			correct_count += 1
		else:
			missed_ids.append(qid)
		p_l = snappedf(_update_pl_diagnostic(p_l, is_correct), 0.0001)
	var total: int = bank.size()
	var pre_score: int = int(round((float(correct_count) / float(total)) * 100.0)) if total > 0 else 0
	return {
		"ok": true,
		"topic": topic,
		"correct_count": correct_count,
		"total": total,
		"pre_score": pre_score,
		"p_l": snappedf(p_l, 0.0001),
		"missed_ids": missed_ids,
	}


static func _bank_for(module_id: String) -> Array:
	_ensure_loaded()
	var stored: Variant = _banks.get(module_id, [])
	if typeof(stored) != TYPE_ARRAY:
		return []
	return stored as Array


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(BANK_PATH):
		push_warning("PretestBank: missing %s" % BANK_PATH)
		return
	var file := FileAccess.open(BANK_PATH, FileAccess.READ)
	if file == null:
		push_warning("PretestBank: could not read %s" % BANK_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_banks = parsed


static func _is_correct(question: Dictionary, submitted: Variant) -> bool:
	var expected: Variant = question.get("answer")
	var kind := str(question.get("type", "multiple_choice"))
	if kind == "true_false":
		return typeof(submitted) == TYPE_BOOL and submitted == expected
	return _is_choice_number(submitted) and submitted == expected


static func _is_choice_number(value: Variant) -> bool:
	# Godot's JSON parser represents numeric choice indices as floats on reload.
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))


static func review_by_question(module_id: String, answers: Dictionary) -> Dictionary:
	var review: Dictionary = {}
	for question: Dictionary in _bank_for(module_id):
		var qid: int = int(question.id)
		var selected: Variant = answers.get(qid)
		review[qid] = {
			"answer": question.answer,
			"submitted": selected,
			"correct": _is_correct(question, selected),
			"explanation": question.explanation,
		}
	return review


static func visual_example(module_id: String, question_id: int, text: String) -> Dictionary:
	# Bind art to the authored item, never to keywords or the current card index.
	# A changed server question must not inherit a mismatched local example.
	# Presentation-only metadata stays separate from the shared server scoring bank.
	if module_id != "mod_01" or question_id != 9 or text != "Your instructor's real name appears in an email asking you to open a project document. What would make it most suspicious?":
		return {}
	return {"kind": "email", "sender": "Ms. Reyes", "address": "reyes@project-desk.example",
		"subject": "Water Wise / project notes", "known_domain": "harborhigh.example",
		"body": "Hi Alex,\n\nPlease review the notes for our Water Wise project before our next class. The document is attached below.\n\nThank you,",
		"signature": "Ms. Reyes\nScience instructor", "attachment": "Project-notes.pdf",
		"prompt": "Inspect the project email. Which detail is most suspicious?",
		"review_note": "The sender's domain differs from the school's saved domain. A familiar name, project and signature do not verify the sender. Check through the instructor's saved contact before opening the document."}


static func _initial_pl(stored: float) -> float:
	if stored <= 0.0:
		return P_L0
	return clampf(stored, 0.01, 0.99)


static func _update_pl_diagnostic(p_l: float, is_correct: bool) -> float:
	# Pre-test only: Bayesian evidence update. Do not apply the learning transition P(T).
	p_l = clampf(p_l, 0.01, 0.99)
	var numer: float
	var denom: float
	if is_correct:
		numer = p_l * (1.0 - P_S)
		denom = numer + (1.0 - p_l) * P_G
	else:
		numer = p_l * P_S
		denom = numer + (1.0 - p_l) * (1.0 - P_G)
	var posterior: float = numer / denom if denom > 0.0 else p_l
	return clampf(posterior, 0.01, 0.99)
