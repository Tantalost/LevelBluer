extends VBoxContainer
## Lessons-only adaptive checkpoint. UI emits no combat/economy/stage events.
signal finished(passed: bool)
signal return_requested
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Quiz = preload("res://src/gameplay/quiz_content.gd")
const COUNT: int = 25
const PASS: int = 20
const ACTIVITY_TYPES: Dictionary = {"guided": "sender_audit", "trust": "trust_verdict", "spot": "spot_the_tell", "tap": "tap_trap_lines", "triage": "inbox_triage", "consequence": "consequence_choice", "branch": "consequence_choice", "reverse": "tap_trap_lines", "timeline": "spot_the_tell"}
var account: Object
var module_id: String = ""
var pool: Array[Dictionary] = []
var seen: Array[String] = []
var type_counts: Dictionary = {}
var question: Dictionary = {}
var answered: int = 0
var score: int = 0
var resolved: bool = true
var review: bool = false
var _selection: Array[int] = []
var _none_selected: bool = false
var _none_button: Button
var _choices: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _mistakes: Array[String] = []
var _heading: Label
var _body: VBoxContainer
var _feedback: Label
var _action: Button
var _started: bool = false
var _recorded: bool = false
var _skill: String = ""
var _graded_wrong: Dictionary = {}

func _ready() -> void:
	if account == null:
		account = PlayerManager
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	_heading = UI.label("MODULE CHECKPOINT", 26, Color("#4FE0D4"))
	add_child(_heading)
	_body = UI.scroll_column(self)
	_feedback = UI.label("", 24, Color("#FFB648"))
	_body.add_child(_feedback)
	_action = UI.button("BEGIN / 25 QUESTIONS", begin, true)
	add_child(_action)
	get_viewport().size_changed.connect(_fit_touch)

func setup(id: String) -> void:
	module_id = id
	_skill = str(LessonCatalog.module_by_id(id).get("domain", ""))
	review = account.has_lesson_post_quiz(id)
	_body.add_child(UI.label("Put your learning to the test", 32))
	_body.add_child(UI.label("25 questions / Pass with 20 correct.\nDifferent situations and question formats from this module. Difficulty adapts to your mastery; every lesson's skills are included.", 26, UI.MUTED))
	_body.add_child(UI.label("No timer. Read each result before continuing. Leaving restarts this attempt; submitted mastery updates are kept.", 24, UI.MUTED))
	if review:
		_body.add_child(UI.label("REVIEW / You already passed. This practice will not change mastery or your unlock.", 24, Color("#33D17A")))
	_action.disabled = account.get_lesson_progress(id) < LessonCatalog.lesson_count(id) or _skill.is_empty()
	_fit_touch.call_deferred()

func begin() -> void:
	if _started or _action.disabled:
		return
	if not account.can_access_lesson_module(module_id) or account.get_lesson_progress(module_id) < LessonCatalog.lesson_count(module_id):
		return
	pool.clear()
	var unique: Dictionary = {}
	for raw: Variant in ContentDB.get_module_questions(module_id):
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw as Dictionary
		var id: String = Quiz._question_key(row)
		if id.is_empty() or unique.has(id) or str(row.get("module_id", "")) != module_id or Quiz.options(row).is_empty():
			continue
		unique[id] = true
		pool.append(row)
	if pool.size() < COUNT:
		_feedback.text = "The full question bank is unavailable. No score has been recorded."
		_action.disabled = true
		return
	_started = true
	_action.pressed.disconnect(begin)
	_action.pressed.connect(_advance)
	_next()

## Coverage first, mastery-guided difficulty second. Four of every seven target
## the current BKT band; the other three retain easy/medium/hard breadth.
static func select_next(candidates: Array[Dictionary], used: Array[String], counts: Dictionary, preferred: String, index: int, lessons: Array[Dictionary]) -> Dictionary:
	var band: Array[String] = ["easy", "medium", "hard"]
	var target: String = band[index % 7] if index % 7 < 3 else preferred
	var required: String = str(ACTIVITY_TYPES.get(str(lessons[index].get("activity", "")), "")) if index < lessons.size() else ""
	var available: Array[Dictionary] = []
	for row: Dictionary in candidates:
		if Quiz._question_key(row) not in used:
			available.append(row)
	available.shuffle()
	var best: Dictionary = {}
	var best_cost: int = 100000
	for row: Dictionary in available:
		var type_id: String = str(row.get("type_id", ""))
		var cost: int = int(counts.get(type_id, 0)) * 10
		if not required.is_empty():
			cost = 0 if type_id == required else 1000
		cost += absi(band.find(str(row.get("difficulty", "medium"))) - band.find(target))
		if cost < best_cost:
			best = row
			best_cost = cost
	return best.duplicate(true)

func _next() -> void:
	question = select_next(pool, seen, type_counts, account.preferred_difficulty(_skill), answered, LessonCatalog.lessons_for(module_id))
	if question.is_empty():
		_action.disabled = true
		return
	var id: String = Quiz._question_key(question)
	seen.append(id)
	var type_id: String = str(question.get("type_id", ""))
	type_counts[type_id] = int(type_counts.get(type_id, 0)) + 1
	resolved = false
	_selection.clear()
	_none_selected = false
	_none_button = null
	_buttons.clear()
	UI.clear(_body)
	_heading.text = "POST-QUIZ / %02d OF 25 / %s" % [answered + 1, str(question.get("type_label", "")).to_upper()]
	var scenario: String = Quiz._format_scenario(question)
	if not scenario.is_empty():
		var evidence: PanelContainer = UI.panel(_body, Color("#102040"))
		var text: Label = UI.label(scenario, 24, Color("#F3ECD6"))
		evidence.add_child(text)
	_body.add_child(UI.label(Quiz._format_prompt(question), 28))
	if Quiz.is_multi(question):
		_body.add_child(UI.label("Select ALL suspicious lines, or choose 'No suspicious lines'.", 23, Color("#8FF0E6")))
	_choices = Quiz.options(question)
	_choices.shuffle()
	for i: int in _choices.size():
		var label: String = str(_choices[i].text)
		if label == "Phishing":
			label = "Suspicious / attack"
		_choices[i].text = label
		var button: Button = UI.button(label, _pick.bind(i))
		_buttons.append(button)
		_body.add_child(button)
	if Quiz.is_multi(question):
		_none_button = UI.button("No suspicious lines", _pick_none)
		_body.add_child(_none_button)
	_feedback = UI.label("", 25)
	_body.add_child(_feedback)
	_action.text = "SUBMIT ANSWER"
	_action.disabled = true
	(_body.get_parent() as ScrollContainer).scroll_vertical = 0
	_fit_touch.call_deferred()

func _pick(index: int) -> void:
	if resolved or index < 0 or index >= _choices.size():
		return
	_none_selected = false
	if is_instance_valid(_none_button):
		_none_button.text = "No suspicious lines"
	if Quiz.is_multi(question):
		if index in _selection:
			_selection.erase(index)
		else:
			_selection.append(index)
	else:
		_selection.assign([index])
	for i: int in _buttons.size():
		_buttons[i].text = ("[X] " if i in _selection else "[ ] ") + str(_choices[i].text)
	_action.disabled = _selection.is_empty()

func _pick_none() -> void:
	if resolved:
		return
	_selection.clear()
	_none_selected = true
	for i: int in _buttons.size():
		_buttons[i].text = "[ ] " + str(_choices[i].text)
	_none_button.text = "[X] No suspicious lines"
	_action.disabled = false

func submit() -> void:
	if resolved or (_selection.is_empty() and not _none_selected) or answered >= COUNT:
		return
	resolved = true # Guard before signals or persistence.
	var picked: Variant = null if _selection.is_empty() else _choices[_selection[0]].value
	if Quiz.is_multi(question):
		var values: Array[int] = []
		for index: int in _selection:
			values.append(int(_choices[index].value))
		picked = values
	var correct: bool = Quiz.grade(question, picked)
	answered += 1
	if correct:
		score += 1
	var explanation: String = Quiz.explanation(question, correct, picked)
	if question.has("explanations"):
		var explanations: Dictionary = question.explanations
		var details: PackedStringArray = []
		for key: Variant in explanations:
			details.append(str(explanations[key]))
		explanation = " ".join(details)
	if not correct:
		_mistakes.append("%s: %s" % [str(question.get("type_label", "")), explanation])
	for button: Button in _buttons:
		button.disabled = true
	if is_instance_valid(_none_button):
		_none_button.disabled = true
	_feedback.text = ("CORRECT / " if correct else "REVIEW / ") + explanation
	_feedback.add_theme_color_override("font_color", Color("#33D17A") if correct else Color("#FFB648"))
	_scroll_feedback.call_deferred()
	if not review and not Quiz.repeat_wrong_answer(_graded_wrong, question, picked, correct):
		account.update_mastery(_skill, correct, question.get("bkt", {}))
	_action.text = "SEE RESULTS" if answered == COUNT else "NEXT QUESTION"
	if answered == COUNT and not _recorded:
		_recorded = true
		if not review:
			account.record_lesson_post_quiz(module_id, score, answered)
		finished.emit(score >= PASS)

func _advance() -> void:
	if not resolved:
		submit()
	elif answered == COUNT:
		_results()
	else:
		_next()

func _results() -> void:
	UI.clear(_body)
	_heading.text = "CHECKPOINT %s / %d OF 25" % ["PASSED" if score >= PASS else "KEEP PRACTICING", score]
	var success_text: String = "Final module checkpoint passed." if module_id == "mod_05" else "Your next module is ready."
	_body.add_child(UI.label(success_text if score >= PASS else "Pass with 20 correct. Review the feedback below, then reopen the checkpoint to try again.", 28, Color("#33D17A") if score >= PASS else Color("#FFB648")))
	for note: String in _mistakes:
		_body.add_child(UI.label(note, 24, UI.MUTED))
	if _mistakes.is_empty():
		_body.add_child(UI.label("Perfect score. You checked the evidence and chose safe responses.", 26))
	_action.text = "RETURN TO PATH"
	_action.pressed.disconnect(_advance)
	_action.pressed.connect(func() -> void: return_requested.emit())
	_fit_touch.call_deferred()

func _scroll_feedback() -> void:
	if is_instance_valid(_feedback) and _body.is_ancestor_of(_feedback):
		(_body.get_parent() as ScrollContainer).ensure_control_visible(_feedback)

func _fit_touch() -> void:
	UI.fit_touch(self)
