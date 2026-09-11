class_name PretestBank
extends RefCounted
## Bundled per-module pre-test. Used when the mobile API is unreachable.

const BANK_PATH := "res://data/pretest_questions.json"
const MODULE_1_ID := "mod_01"
const P_L0 := 0.10
const P_T := 0.10
const P_G := 0.20
const P_S := 0.10

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
	for i in bank.size():
		var question: Dictionary = bank[i]
		var qid: int = int(question.get("id", 0))
		var is_correct: bool = _is_correct(question, submitted.get(qid))
		if is_correct:
			correct_count += 1
		p_l = _update_pl(p_l, is_correct)
	var total: int = bank.size()
	var pre_score: int = int(round((float(correct_count) / float(total)) * 100.0)) if total > 0 else 0
	return {
		"ok": true,
		"topic": topic,
		"correct_count": correct_count,
		"total": total,
		"pre_score": pre_score,
		"p_l": snappedf(p_l, 0.0001),
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
	if str(question.get("type", "")) == "true_false":
		return bool(submitted) == bool(expected)
	return int(submitted) == int(expected)


static func _initial_pl(stored: float) -> float:
	if stored <= 0.0:
		return P_L0
	return clampf(stored, 0.01, 0.99)


static func _update_pl(p_l: float, is_correct: bool) -> float:
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
	return clampf(posterior + (1.0 - posterior) * P_T, 0.01, 0.99)
