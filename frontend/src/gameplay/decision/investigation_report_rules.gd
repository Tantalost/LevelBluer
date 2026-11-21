extends RefCounted
## Canonical, chapter-independent report rules. No wallet, mastery or UI dependencies.
static func fresh() -> Dictionary:
	return {"version":1, "draft":{}, "view":"board", "section":0, "revision":0, "first":{}, "latest":{}, "best":{}}

static func number(value: Variant, maximum: int) -> int:
	if (value is int or value is float) and is_finite(float(value)): return clampi(int(value), 0, maximum)
	return 0

static func valid_definition(definition: Dictionary) -> bool:
	var slots: Dictionary = {}
	var items: Dictionary = definition.get("items", {})
	for section: Dictionary in definition.get("sections", []):
		for slot: Dictionary in section.get("slots", []):
			var id: String = str(slot.get("id", ""))
			if id.is_empty() or slots.has(id) or not items.has(str(slot.get("answer", ""))): return false
			slots[id] = true
	return not slots.is_empty()

static func canonical(definition: Dictionary, raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var used: Array[String] = []
	for section: Dictionary in definition.get("sections", []):
		for slot: Dictionary in section.slots:
			var item: String = str(raw.get(slot.id, ""))
			if definition.items.has(item) and item not in used:
				result[slot.id] = item
				used.append(item)
	return result

static func evaluate(definition: Dictionary, raw: Dictionary) -> Dictionary:
	var answers: Dictionary = canonical(definition, raw)
	var correct: Dictionary = {}
	var score: int = 0
	var total: int = 0
	for section: Dictionary in definition.get("sections", []):
		for slot: Dictionary in section.slots:
			var passed: bool = answers.get(slot.id, "") == slot.answer
			correct[slot.id] = passed
			total += 1
			if passed: score += 1
	return {"answers":answers, "correct":correct, "score":score, "total":total, "percent":roundi(100.0 * score / maxi(1, total))}

static func clean(definition: Dictionary, raw: Dictionary) -> Dictionary:
	var result: Dictionary = fresh()
	if raw.get("version", 1) != 1: return result
	if raw.get("draft") is Dictionary: result.draft = canonical(definition, raw.draft)
	result.view = str(raw.get("view", "board")) if raw.get("view", "board") in ["board", "report", "results"] else "board"
	result.section = number(raw.get("section", 0), maxi(0, definition.get("sections", []).size() - 1))
	result.revision = number(raw.get("revision", 0), 1000000)
	for field: String in ["first", "latest", "best"]:
		var submission: Variant = raw.get(field, {})
		if submission is Dictionary and submission.get("answers") is Dictionary:
			result[field] = evaluate(definition, submission.answers)
			result[field]["submitted_revision"] = number(submission.get("submitted_revision", 0), 1000000)
	if result.latest.is_empty() and result.view == "results": result.view = "report"
	return result

static func submit(definition: Dictionary, raw: Dictionary) -> Dictionary:
	var result: Dictionary = clean(definition, raw)
	var grade: Dictionary = evaluate(definition, result.draft)
	grade["submitted_revision"] = int(result.revision) + 1
	if result.first.is_empty(): result.first = grade.duplicate(true)
	result.latest = grade
	if result.best.is_empty() or int(grade.score) > int(result.best.score): result.best = grade.duplicate(true)
	result.view = "results"
	result.revision += 1
	return result

static func merge(definition: Dictionary, first: Dictionary, second: Dictionary) -> Dictionary:
	var a: Dictionary = clean(definition, first)
	var b: Dictionary = clean(definition, second)
	# Choose one whole revision. Never manufacture a report by combining answers.
	var result: Dictionary = (a if int(a.revision) > int(b.revision) or (int(a.revision) == int(b.revision) and JSON.stringify(a) > JSON.stringify(b)) else b).duplicate(true)
	for candidate: Dictionary in [a,b]:
		if not candidate.first.is_empty() and (result.first.is_empty() or int(candidate.first.submitted_revision) < int(result.first.submitted_revision)):
			result.first = candidate.first.duplicate(true)
		if not candidate.best.is_empty() and (result.best.is_empty() or int(candidate.best.score) > int(result.best.score)):
			result.best = candidate.best.duplicate(true)
	return result
