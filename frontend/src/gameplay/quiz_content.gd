extends RefCounted
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

