extends BaseScreen
## Mixed-format baseline cards. First responses are saved; corrections come after submission.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var _topic: Label
var _progress: Label
var _question: Label
var _options: VBoxContainer
var _next: Button
var _error: Label
var _format: Label
var _guide: Label
var _bar: ProgressBar
var _back: Button
var _card: VBoxContainer
var _questions: Array = []
var _index := 0
var _answers: Dictionary = {}
var _selected: Variant = null
var _loading := false
var _module_id := ""
var _finished := false
var _review: Array[Dictionary] = []
var _review_index := 0

func _ready() -> void:
	var shell := UI.shell(self, "MODULE CHECK-IN", func() -> void: Router.request_back())
	_back = shell.back
	var layout: VBoxContainer = shell.layout
	_progress = UI.label("Preparing your cards...", 24, UI.TEAL)
	layout.add_child(_progress)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 10
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", UI.box(UI.PANEL, UI.PANEL, 0))
	_bar.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	layout.add_child(_bar)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 24)
	panes.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(panes)
	var side := UI.panel(panes)
	side.size_flags_horizontal = SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 0.28
	var brief := UI.scroll_column(side)
	brief.add_child(UI.label("BEFORE YOU BEGIN", 14, UI.TEAL, true))
	_topic = UI.label("", 28)
	brief.add_child(_topic)
	brief.add_child(UI.label("A quick starting-point check, not a pass/fail barrier.", 25))
	brief.add_child(HSeparator.new())
	_guide = UI.label("Choose an answer, decide true or false, or recall a short term. No timer. Take your time.", 24, UI.MUTED)
	brief.add_child(_guide)
	brief.add_child(UI.label("Your first responses set your baseline. Review the answers after you finish, then start the lessons.", 22, UI.GOLD))
	var right := UI.panel(panes, Color("101e28"))
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.72
	var column := UI.column(right, 16)
	_format = UI.label("", 15, UI.TEAL, true)
	column.add_child(_format)
	column.add_child(HSeparator.new())
	_card = UI.scroll_column(column)
	_question = UI.label("", 29)
	_card.add_child(_question)
	_options = UI.column(_card, 14)
	_error = UI.label("", 22, UI.GOLD)
	_error.hide()
	column.add_child(_error)
	_next = UI.button("SAVE ANSWER  >", _on_next_pressed, true)
	_next.disabled = true
	column.add_child(_next)

func on_enter(args: Dictionary) -> void:
	_module_id = str(args.get("module_id", "mod_01")).strip_edges()
	_finished = false
	_index = 0
	_answers.clear()
	_selected = null
	_hide_error()
	_load_questions()

func can_go_back() -> bool:
	return not _loading

func _load_questions() -> void:
	_set_busy(true)
	var parsed: Variant = await AuthService.fetch_pretest_questions(_module_id)
	if not is_inside_tree():
		return
	_set_busy(false)
	if typeof(parsed) != TYPE_DICTIONARY:
		_show_error(tr("PRETEST_ERR_LOAD"))
		return
	if bool(parsed.get("alreadyCompleted", false)):
		_go_to_lesson()
		return
	var list: Variant = parsed.get("questions", [])
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		_show_error(tr("PRETEST_ERR_LOAD"))
		return
	_questions = list
	_show_question()

func _show_question() -> void:
	_hide_error()
	_selected = null
	var question: Dictionary = _questions[_index]
	var module := LessonCatalog.module_by_id(_module_id)
	_topic.text = str(module.get("title", question.get("topic", "")))
	_progress.text = "CARD %02d OF %02d    /    %d ANSWERED" % [_index + 1, _questions.size(), _answers.size()]
	_bar.max_value = _questions.size()
	_bar.value = _answers.size()
	_question.text = str(question.get("text", ""))
	_next.text = "FINISH PRE-TEST  >" if _index == _questions.size() - 1 else "SAVE ANSWER  >"
	_next.disabled = true
	UI.clear(_options)
	(_card.get_parent() as ScrollContainer).scroll_vertical = 0
	var kind := str(question.get("type", "multiple_choice"))
	match kind:
		"true_false":
			_format.text = "TRUE OR FALSE  /  DECIDE"
			_guide.text = "Decide whether the statement is true or false. Choose the answer you believe now."
			_add_option("True", true)
			_add_option("False", false)
		"multiple_choice":
			_format.text = "MULTIPLE CHOICE  /  RECOGNIZE"
			_guide.text = "Read every option, then choose the single best answer. Your choice is saved when you continue."
			var options: Array = question.get("options", [])
			for i in options.size():
				_add_option(str(options[i]), i)
		_:
			_show_error("This card format is not supported. Please update the game.")

func _add_option(text: String, value: Variant) -> void:
	var button := UI.button(text, Callable())
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_select_option.bind(button, value))
	_options.add_child(button)

func _select_option(button: Button, value: Variant) -> void:
	if _loading or _finished:
		return
	_selected = value
	_next.disabled = false
	for child in _options.get_children():
		if child is Button:
			child.add_theme_stylebox_override("normal", UI.box(Color("29464e") if child == button else UI.PANEL, UI.TEAL if child == button else Color("3b626a"), 10))

func _on_next_pressed() -> void:
	if _loading or _next.disabled:
		return
	if _finished:
		_go_to_lesson()
		return
	if _selected == null or _questions.is_empty():
		return
	var question: Dictionary = _questions[_index]
	_answers[int(question.id)] = _selected
	_bar.value = _answers.size()
	if _index < _questions.size() - 1:
		_index += 1
		_show_question()
	else:
		_submit()

func _payload() -> Array:
	var payload: Array = []
	for question in _questions:
		var id := int(question.id)
		if not _answers.has(id):
			return []
		payload.append({"id": id, "answer": _answers[id]})
	return payload

func _submit() -> void:
	var payload := _payload()
	if payload.is_empty():
		_show_error(tr("PRETEST_ERR_INCOMPLETE"))
		return
	_set_busy(true)
	var result: AuthService.Result = await AuthService.submit_pretest(_module_id, payload)
	if not is_inside_tree():
		return
	_set_busy(false)
	if result == AuthService.Result.OK:
		_show_results()
	elif result == AuthService.Result.NETWORK_ERROR:
		_show_error(tr("PRETEST_ERR_NETWORK"))
	else:
		_show_error(tr("PRETEST_ERR_SUBMIT"))

func _show_results() -> void:
	_finished = true
	_review = PretestBank.review_cards(_module_id, _answers)
	_review_index = 0
	_bar.value = _questions.size()
	var correct := 0
	for card in _review:
		if card.correct:
			correct += 1
	_progress.text = "CHECK-IN COMPLETE    /    %d OF %d CORRECT    /    100%% ANSWERED" % [correct, _review.size()]
	_guide.text = "Review your answers like flashcards. Corrections are for learning; they do not change your recorded baseline."
	_next.text = "START LESSONS  >"
	_next.disabled = false
	_show_review_card()

func _show_review_card() -> void:
	if _review.is_empty():
		return
	var card: Dictionary = _review[_review_index]
	_format.text = "REVIEW CARD %02d / %02d" % [_review_index + 1, _review.size()]
	_question.text = str(card.question)
	UI.clear(_options)
	_options.add_child(UI.label("CORRECT" if card.correct else "REVISIT THIS", 17, UI.TEAL if card.correct else UI.GOLD, true))
	_options.add_child(UI.label("Your answer: " + str(card.submitted), 25, UI.MUTED))
	_options.add_child(UI.label("Remember: " + str(card.answer), 28))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_options.add_child(row)
	var previous := UI.button("< Previous", _review_move.bind(-1))
	previous.size_flags_horizontal = SIZE_EXPAND_FILL
	previous.disabled = _review_index == 0
	row.add_child(previous)
	var next := UI.button("Next card >", _review_move.bind(1))
	next.size_flags_horizontal = SIZE_EXPAND_FILL
	next.disabled = _review_index == _review.size() - 1
	row.add_child(next)
	(_card.get_parent() as ScrollContainer).scroll_vertical = 0

func _review_move(delta: int) -> void:
	_review_index = clampi(_review_index + delta, 0, _review.size() - 1)
	_show_review_card()

func _go_to_lesson() -> void:
	Router.replace(&"lesson_player", {"module_id": _module_id, "review": false})

func _set_busy(busy: bool) -> void:
	_loading = busy
	_next.disabled = busy or _selected == null
	_back.disabled = busy
	for child in _options.get_children():
		if child is Button:
			child.disabled = busy
	if busy:
		_next.text = "SAVING..." if not _questions.is_empty() else "LOADING..."
	elif not _questions.is_empty():
		_next.text = "FINISH PRE-TEST  >" if _index == _questions.size() - 1 else "SAVE ANSWER  >"

func _show_error(message: String) -> void:
	_error.text = message
	_error.show()

func _hide_error() -> void:
	_error.text = ""
	_error.hide()
