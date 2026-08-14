extends BaseScreen
## Baseline pre-test. Answers are scored on the mobile backend, which updates BKT P(L).

@onready var _topic: Label = %TopicLabel
@onready var _progress: Label = %ProgressLabel
@onready var _question: Label = %QuestionLabel
@onready var _options: VBoxContainer = %OptionsList
@onready var _next: Button = %NextButton
@onready var _error_panel: PanelContainer = %ErrorPanel
@onready var _error: Label = %ErrorLabel
@onready var _busy: ProgressBar = %BusySpinner
@onready var _title: Label = %TitleLabel

var _questions: Array = []
var _index: int = 0
var _answers: Dictionary = {}  # id -> selected value
var _selected: Variant = null
var _loading: bool = false
var _pixel_font: Font


func _ready() -> void:
	_load_font()
	_next.pressed.connect(_on_next_pressed)


func on_enter(_args: Dictionary) -> void:
	_apply_copy()
	_hide_error()
	_index = 0
	_answers.clear()
	_selected = null
	_load_questions()


func can_go_back() -> bool:
	return not _loading


func _load_font() -> void:
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		var file := load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
		if file != null:
			_pixel_font = file


func _apply_copy() -> void:
	_title.text = tr("PRETEST_TITLE")
	if _pixel_font:
		_title.add_theme_font_override("font", _pixel_font)
		_topic.add_theme_font_override("font", _pixel_font)
		_progress.add_theme_font_override("font", _pixel_font)
		_next.add_theme_font_override("font", _pixel_font)


func _load_questions() -> void:
	_set_busy(true)
	var parsed: Variant = await AuthService.fetch_pretest_questions()
	_set_busy(false)

	if typeof(parsed) != TYPE_DICTIONARY:
		_show_error(tr("PRETEST_ERR_LOAD"))
		return

	if bool(parsed.get("alreadyCompleted", false)):
		Router.replace_all(&"dashboard")
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
	_topic.text = str(question.get("topic", "")).to_upper()
	_progress.text = "%d / %d" % [_index + 1, _questions.size()]
	_question.text = str(question.get("text", ""))
	_next.text = tr("PRETEST_SUBMIT") if _index >= _questions.size() - 1 else tr("PRETEST_NEXT")
	_next.disabled = true
	_rebuild_options(question)


func _rebuild_options(question: Dictionary) -> void:
	for child in _options.get_children():
		child.queue_free()

	var q_type := str(question.get("type", "multiple_choice"))
	if q_type == "true_false":
		_add_option("TRUE", true)
		_add_option("FALSE", false)
		return

	var options: Variant = question.get("options", [])
	if typeof(options) != TYPE_ARRAY:
		return
	for i in options.size():
		_add_option(str(options[i]), i)


func _add_option(label: String, value: Variant) -> void:
	var button := Button.new()
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("e8f0ff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0f1e35")
	style.border_color = Color("5ac8ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.pressed.connect(func(): _select_option(button, value))
	_options.add_child(button)


func _select_option(button: Button, value: Variant) -> void:
	_selected = value
	_next.disabled = false
	for child in _options.get_children():
		if child is Button:
			var style := (child as Button).get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			if child == button:
				style.bg_color = Color("0d3d6e")
				style.border_color = Color("ffd23f")
			else:
				style.bg_color = Color("0f1e35")
				style.border_color = Color("5ac8ff")
			(child as Button).add_theme_stylebox_override("normal", style)
			(child as Button).add_theme_stylebox_override("hover", style)
			(child as Button).add_theme_stylebox_override("pressed", style)


func _on_next_pressed() -> void:
	if _selected == null or _questions.is_empty():
		return

	var question: Dictionary = _questions[_index]
	_answers[int(question.get("id", 0))] = _selected

	if _index < _questions.size() - 1:
		_index += 1
		_show_question()
		return

	_submit()


func _submit() -> void:
	var payload: Array = []
	for question in _questions:
		var qid := int(question.get("id", 0))
		if not _answers.has(qid):
			_show_error(tr("PRETEST_ERR_INCOMPLETE"))
			return
		payload.append({"id": qid, "answer": _answers[qid]})

	_set_busy(true)
	var result: AuthService.Result = await AuthService.submit_pretest(payload)
	_set_busy(false)

	if result == AuthService.Result.OK:
		Router.replace_all(&"dashboard")
	elif result == AuthService.Result.NETWORK_ERROR:
		_show_error(tr("PRETEST_ERR_NETWORK"))
	else:
		_show_error(tr("PRETEST_ERR_SUBMIT"))


func _set_busy(busy: bool) -> void:
	_loading = busy
	_next.visible = not busy
	_busy.visible = busy
	_options.modulate.a = 0.4 if busy else 1.0


func _show_error(message: String) -> void:
	_error.text = "⚠  %s" % message
	_error_panel.visible = true


func _hide_error() -> void:
	_error.text = ""
	_error_panel.visible = false
