extends RefCounted

## Shared selection contract: 4 easy / 7 medium / 4 hard, balanced by type.
static func _take_balanced_count(candidates: Array[Dictionary], needed: int, type_counts: Dictionary) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = candidates.duplicate()
	remaining.shuffle()
	var picked: Array[Dictionary] = []
	while picked.size() < needed and not remaining.is_empty():
		var min_count: int = 999999
		for i: int in remaining.size():
			var used: int = int(type_counts.get(_question_type_id(remaining[i]), 0))
			if used < min_count:
				min_count = used
		var chosen_index: int = -1
		for i: int in remaining.size():
			if int(type_counts.get(_question_type_id(remaining[i]), 0)) == min_count:
				chosen_index = i
				break
		if chosen_index < 0:
			break
		var chosen: Dictionary = remaining[chosen_index]
		picked.append(chosen)
		remaining.remove_at(chosen_index)
		var type_id: String = _question_type_id(chosen)
		type_counts[type_id] = int(type_counts.get(type_id, 0)) + 1
	return picked


static func build_exam_deck(pool: Array[Dictionary], module_id: String) -> Array[Dictionary]:
	if pool.is_empty():
		push_error("LevelManager: TRACE exam bank unavailable for %s" % module_id)
		return []
	var type_counts: Dictionary = {}
	var picked: Array[Dictionary] = []
	var picked_ids: Dictionary = {}
	var quotas: Array = [["easy", 4], ["medium", 7], ["hard", 4]]
	for q: int in quotas.size():
		var difficulty: String = str(quotas[q][0])
		var needed: int = int(quotas[q][1])
		var available: Array[Dictionary] = []
		var matched: Array[Dictionary] = _questions_with_difficulty(pool, difficulty)
		for i: int in matched.size():
			var qid: String = _question_key(matched[i])
			if picked_ids.has(qid):
				continue
			available.append(matched[i])
		var taken: Array[Dictionary] = _take_balanced_count(available, needed, type_counts)
		for i: int in taken.size():
			var item: Dictionary = taken[i]
			picked.append(item)
			picked_ids[_question_key(item)] = true
	if picked.size() < 15:
		var leftover: Array[Dictionary] = []
		for i: int in pool.size():
			var qid: String = _question_key(pool[i])
			if picked_ids.has(qid):
				continue
			leftover.append(pool[i])
		var filler: Array[Dictionary] = _take_balanced_count(leftover, 15 - picked.size(), type_counts)
		for i: int in filler.size():
			picked.append(filler[i])
			picked_ids[_question_key(filler[i])] = true
	picked.shuffle()
	var easy_n: int = 0
	var medium_n: int = 0
	var hard_n: int = 0
	var unique_ids: Dictionary = {}
	for i: int in picked.size():
		unique_ids[_question_key(picked[i])] = true
		match _question_difficulty(picked[i]):
			"easy":
				easy_n += 1
			"hard":
				hard_n += 1
			_:
				medium_n += 1
	print("[TRACE EXAM]")
	print("module=%s" % module_id)
	print("questions=%d" % picked.size())
	print("easy=%d" % easy_n)
	print("medium=%d" % medium_n)
	print("hard=%d" % hard_n)
	print("unique=%d" % unique_ids.size())
	return picked

static func _question_key(q: Dictionary) -> String:
	var qid: String = str(q.get("id", "")).strip_edges()
	return qid if not qid.is_empty() else str(q.get("text", q.get("question", "")))

static func _question_type_id(q: Dictionary) -> String:
	var type_id: String = str(q.get("type_id", "")).strip_edges()
	return type_id if not type_id.is_empty() else "other"

static func _question_difficulty(q: Dictionary) -> String:
	var difficulty: String = str(q.get("difficulty", "")).strip_edges().to_lower()
	return difficulty if difficulty in ["easy", "medium", "hard"] else ""

static func _questions_with_difficulty(pool: Array[Dictionary], difficulty: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q: Dictionary in pool:
		if _question_difficulty(q) == difficulty:
			result.append(q)
	return result

## Shared question presentation and grading; no economy, timers, or account state.

static func _format_scenario(q: Dictionary) -> String:
	var scene: Dictionary = {}
	var scene_stored: Variant = q.get("scenario", {})
	if typeof(scene_stored) == TYPE_DICTIONARY:
		scene = scene_stored as Dictionary
	# Sender Audit ships the address inside "scenario", triage ships it top level.
	var from_line: String = _first_text([q.get("from_line", ""), scene.get("from_line", "")])
	if not from_line.is_empty():
		return "FROM  %s" % from_line
	var preview: String = _first_text([q.get("preview", ""), scene.get("preview", "")])
	var content: String = _first_text([q.get("content", ""), scene.get("content", "")])
	if not preview.is_empty() or not content.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		if not preview.is_empty():
			parts.append(preview.to_upper())
		if not content.is_empty():
			parts.append(content)
		return "\n".join(parts)
	var lines: PackedStringArray = PackedStringArray()
	var sender: String = str(scene.get("from", "")).strip_edges()
	var subject: String = str(scene.get("subject", "")).strip_edges()
	var body: String = str(scene.get("body", "")).strip_edges()
	if not sender.is_empty():
		lines.append("FROM  %s" % sender)
	if not subject.is_empty():
		lines.append("SUBJ  %s" % subject)
	if not body.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append(body)
	return "\n".join(lines)

static func _first_text(candidates: Array) -> String:
	for i in candidates.size():
		var value: String = str(candidates[i]).strip_edges()
		if not value.is_empty():
			return value
	return ""

static func _format_prompt(q: Dictionary) -> String:
	var prompt: String = str(q.get("question", "")).strip_edges()
	if not prompt.is_empty():
		return prompt
	var delivery: String = str(q.get("delivery", ""))
	if delivery == "binary_ab":
		return "Phishing or legitimate?"
	if delivery == "true_false":
		return str(q.get("text", "")).strip_edges()
	return str(q.get("prompt", q.get("text", ""))).strip_edges()

static func _int_list(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	var rows: Array = raw as Array
	for i in rows.size():
		out.append(int(rows[i]))
	return out

static func grade(current_question: Dictionary, picked: Variant, fallback: String = "") -> bool:
	var delivery: String = str(current_question.get("delivery", ""))
	var type_id: String = str(current_question.get("type_id", ""))
	if delivery == "multi_select" or type_id == "tap_trap_lines":
		var expected: Array[int] = _int_list(current_question.get("correct_indices", []))
		var got: Array[int] = []
		if typeof(picked) == TYPE_ARRAY:
			got = _int_list(picked)
		expected.sort()
		got.sort()
		if expected.size() != got.size():
			return false
		for i in expected.size():
			if expected[i] != got[i]:
				return false
		return true
	if delivery == "binary_ab" or type_id == "trust_verdict":
		return str(picked).to_lower() == str(current_question.get("correct_answer", "")).to_lower()
	if delivery == "true_false" or type_id == "safety_rule_tf":
		return bool(picked) == bool(current_question.get("answer", false))
	if current_question.has("answer_index"):
		return int(picked) == int(current_question.get("answer_index", -1))
	return str(picked) == fallback

static func explanation(current_question: Dictionary, is_correct: bool, picked: Variant) -> String:
	var note: String = ""
	if is_correct:
		note = str(current_question.get("correct_feedback", "")).strip_edges()
	else:
		note = str(current_question.get("incorrect_feedback", "")).strip_edges()
		var type_id: String = str(current_question.get("type_id", ""))
		if type_id == "consequence_choice" and typeof(picked) == TYPE_INT:
			if int(picked) == 0:
				note = str(current_question.get("click_debrief", note)).strip_edges()
			elif int(picked) == 1:
				note = str(current_question.get("ignore_debrief", note)).strip_edges()
	if note.is_empty():
		note = str(current_question.get("explanation", "")).strip_edges()
	if note.is_empty():
		note = "SECURE" if is_correct else "MISS"
	return note

static func is_multi(q: Dictionary) -> bool:
	return q.get("delivery", "") == "multi_select" or q.get("type_id", "") == "tap_trap_lines"

static func options(q: Dictionary) -> Array[Dictionary]:
	if q.get("delivery", "") == "binary_ab" or q.get("type_id", "") == "trust_verdict":
		return [{"text": "Phishing", "value": "phishing"}, {"text": "Legitimate", "value": "legitimate"}]
	if q.get("delivery", "") == "true_false" or q.get("type_id", "") == "safety_rule_tf":
		return [{"text": "True", "value": true}, {"text": "False", "value": false}]
	var rows: Array = q.get("email_lines", []) if is_multi(q) else q.get("options", [])
	var out: Array[Dictionary] = []
	for i in rows.size():
		out.append({"text": str(rows[i]), "value": i})
	return out
