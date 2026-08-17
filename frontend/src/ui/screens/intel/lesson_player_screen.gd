class_name LessonPlayerScreen
extends BaseScreen
## Two-pane investigation: case file on the left, report test on the right.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _file_pane: PanelContainer = %FilePane
@onready var _report_pane: PanelContainer = %ReportPane
@onready var _topic_toggle: Button = %TopicToggle
@onready var _case_toggle: Button = %CaseToggle
@onready var _case_label: Label = %CaseLabel
@onready var _date_label: Label = %DateLabel
@onready var _time_label: Label = %TimeLabel
@onready var _photo_well: PanelContainer = %PhotoWell
@onready var _evidence_glyph: IntelPixelIcon = %EvidenceGlyph
@onready var _body_label: Label = %BodyLabel
@onready var _footer_label: Label = %FooterLabel
@onready var _report_title: Label = %ReportTitle
@onready var _close_button: Button = %CloseButton
@onready var _choice_list: VBoxContainer = %ChoiceList
@onready var _flag_a: Button = %FlagA
@onready var _flag_b: Button = %FlagB
@onready var _status_label: Label = %StatusLabel
@onready var _submit_button: Button = %SubmitButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _prev_file: Button = %PrevFile
@onready var _next_file: Button = %NextFile

var _pixel_font: Font
var _module_id: String = ""
var _lesson_index: int = 0
var _lessons: Array[Dictionary] = []
var _choice_index: int = -1
var _flag_on: Array[bool] = [false, false]
var _choice_buttons: Array[Button] = []
var _busy: bool = false
var _review_mode: bool = false
var _show_scenario: bool = false


func _ready() -> void:
	_load_font()
	_style_file_pane()
	_style_report_pane()
	_style_photo_well()
	_style_close_button()
	_style_submit()
	_apply_label(_case_label, Palette.FIELD_TEXT, 11)
	_apply_label(_date_label, Palette.FIELD_TEXT, 11)
	_apply_label(_time_label, Palette.FIELD_TEXT, 11)
	_apply_label(_body_label, Palette.FIELD_TEXT, 12)
	_apply_label(_footer_label, Palette.TEXT_MUTED, 10)
	_apply_label(_report_title, Palette.TEXT_PRIMARY, 14)
	_apply_label(_progress_label, Palette.TEXT_PRIMARY, 11)
	_apply_label(_status_label, Palette.TEXT_PRIMARY, 12)
	_apply_label(_flag_a, Palette.TEXT_PRIMARY, 11)
	_apply_label(_flag_b, Palette.TEXT_PRIMARY, 11)
	_close_button.pressed.connect(func() -> void: Router.request_back())
	_submit_button.pressed.connect(_on_submit)
	_prev_file.pressed.connect(func() -> void: _browse_file(-1))
	_next_file.pressed.connect(func() -> void: _browse_file(1))
	_flag_a.toggled.connect(_on_flag.bind(0, _flag_a))
	_flag_b.toggled.connect(_on_flag.bind(1, _flag_b))
	_flag_a.toggle_mode = true
	_flag_b.toggle_mode = true
	_style_nav_file(_prev_file)
	_style_nav_file(_next_file)
	_topic_toggle.pressed.connect(func() -> void: _set_show_scenario(false))
	_case_toggle.pressed.connect(func() -> void: _set_show_scenario(true))
	_style_pane_toggle(_topic_toggle, true)
	_style_pane_toggle(_case_toggle, false)


func on_enter(args: Dictionary) -> void:
	_module_id = str(args.get("module_id", ""))
	_review_mode = bool(args.get("review", false))
	_lessons = LessonCatalog.lessons_for(_module_id)
	if _lessons.is_empty():
		Router.request_back()
		return
	if _review_mode:
		_lesson_index = 0
	else:
		_lesson_index = clampi(PlayerManager.get_lesson_progress(_module_id), 0, _lessons.size() - 1)
	_load_case()


func _load_case() -> void:
	_busy = false
	_choice_index = -1
	_flag_on[0] = false
	_flag_on[1] = false
	_flag_a.set_pressed_no_signal(false)
	_flag_b.set_pressed_no_signal(false)
	_status_label.text = ""
	_show_scenario = false
	var lesson: Dictionary = _lessons[_lesson_index]
	_footer_label.text = "LEVEL BLUE  //  INTEL"
	_report_title.text = "REPORT FOR:"
	_progress_label.text = "FILE %02d/%02d" % [_lesson_index + 1, _lessons.size()]
	_evidence_glyph.kind = _evidence_kind(str(lesson.get("evidence", "envelope")))
	var flags := _as_strings(lesson.get("flags", PackedStringArray()))
	_flag_a.text = "[ ] %s" % (flags[0] if flags.size() > 0 else "")
	_flag_b.text = "[ ] %s" % (flags[1] if flags.size() > 1 else "")
	_flag_a.visible = flags.size() > 0
	_flag_b.visible = flags.size() > 1
	_style_flag(_flag_a, false)
	_style_flag(_flag_b, false)
	_rebuild_choices(lesson)
	_style_submit()
	_prev_file.visible = _review_mode
	_next_file.visible = _review_mode
	_prev_file.disabled = _lesson_index <= 0
	_next_file.disabled = _lesson_index >= _lessons.size() - 1
	if _review_mode:
		_submit_button.text = "CHECK"
	_apply_left_pane()


func _set_show_scenario(show_scenario: bool) -> void:
	if _show_scenario == show_scenario:
		return
	_show_scenario = show_scenario
	_apply_left_pane()


func _apply_left_pane() -> void:
	if _lessons.is_empty():
		return
	var lesson: Dictionary = _lessons[_lesson_index]
	_style_pane_toggle(_topic_toggle, not _show_scenario)
	_style_pane_toggle(_case_toggle, _show_scenario)
	_date_label.visible = _show_scenario
	_time_label.visible = _show_scenario
	_photo_well.visible = _show_scenario
	if _show_scenario:
		_case_label.text = "CASE: %s" % str(lesson.get("case_id", ""))
		_date_label.text = "DATE: %s" % str(lesson.get("date", ""))
		_time_label.text = "TIME: %s" % str(lesson.get("time", ""))
		_body_label.text = str(lesson.get("body", ""))
		_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_case_label.text = "TOPIC: %s" % str(lesson.get("title", ""))
		_body_label.text = str(lesson.get("explain", ""))
		_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _rebuild_choices(lesson: Dictionary) -> void:
	var existing: Array = _choice_list.get_children()
	for i in existing.size():
		var child: Node = existing[i] as Node
		if child != null:
			_choice_list.remove_child(child)
			child.queue_free()
	_choice_buttons.clear()
	var choices := _as_strings(lesson.get("choices", PackedStringArray()))
	for i in choices.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 48)
		button.text = choices[i]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var captured: int = i
		button.pressed.connect(func() -> void: _select_choice(captured))
		if _pixel_font != null:
			button.add_theme_font_override("font", _pixel_font)
		button.add_theme_font_size_override("font_size", 11)
		_choice_list.add_child(button)
		_choice_buttons.append(button)
		_style_choice(button, false)


func _select_choice(index: int) -> void:
	_choice_index = index
	for i in _choice_buttons.size():
		_style_choice(_choice_buttons[i], i == index)


func _on_flag(on: bool, index: int, button: Button) -> void:
	_flag_on[index] = on
	_style_flag(button, on)
	var label := button.text
	if label.begins_with("[ ] ") or label.begins_with("[X] "):
		label = label.substr(4)
	button.text = ("[X] " if on else "[ ] ") + label


func _on_submit() -> void:
	if _busy or _lessons.is_empty():
		return
	if _choice_index < 0:
		_status_label.text = "CLASSIFY THE INCIDENT"
		_status_label.add_theme_color_override("font_color", Palette.GOLD)
		return
	var lesson: Dictionary = _lessons[_lesson_index]
	var correct_choice: int = int(lesson.get("correct_choice", -1))
	var needed := _as_ints(lesson.get("correct_flags", PackedInt32Array()))
	var flags_ok := true
	for i in _flag_on.size():
		var should: bool = false
		for n in needed.size():
			if int(needed[n]) == i:
				should = true
				break
		if _flag_on[i] != should:
			flags_ok = false
			break
	if _choice_index != correct_choice or not flags_ok:
		_status_label.text = "REPORT REJECTED"
		_status_label.add_theme_color_override("font_color", Palette.RED)
		return
	_status_label.text = "REPORT FILED"
	_status_label.add_theme_color_override("font_color", Palette.GREEN)
	if _review_mode:
		return
	_busy = true
	PlayerManager.complete_lesson_unit(_module_id, _lessons.size(), LessonCatalog.module_ids())
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	var next: int = PlayerManager.get_lesson_progress(_module_id)
	if next >= _lessons.size():
		Router.request_back()
		return
	_lesson_index = next
	_load_case()


func _browse_file(delta: int) -> void:
	if not _review_mode or _lessons.is_empty():
		return
	_lesson_index = clampi(_lesson_index + delta, 0, _lessons.size() - 1)
	_load_case()


func _as_strings(raw: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		return raw
	if typeof(raw) != TYPE_ARRAY:
		return out
	var arr: Array = raw
	for i in arr.size():
		out.append(str(arr[i]))
	return out


func _as_ints(raw: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if typeof(raw) == TYPE_PACKED_INT32_ARRAY:
		return raw
	if typeof(raw) != TYPE_ARRAY:
		return out
	var arr: Array = raw
	for i in arr.size():
		out.append(int(arr[i]))
	return out


func _evidence_kind(name: String) -> IntelPixelIcon.Kind:
	match name:
		"phone":
			return IntelPixelIcon.Kind.PHONE
		"camera":
			return IntelPixelIcon.Kind.CAMERA
		"badge":
			return IntelPixelIcon.Kind.BADGE
		"terminal":
			return IntelPixelIcon.Kind.TERMINAL
		_:
			return IntelPixelIcon.Kind.ENVELOPE


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_file_pane() -> void:
	var box := _pixel_box(Palette.FIELD_BG, Palette.CASTLE_STONE, 0, 3)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 12.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	_file_pane.add_theme_stylebox_override("panel", box)


func _style_report_pane() -> void:
	var box := _pixel_box(Palette.CYAN_DIM, Palette.CYAN, 0, 3)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	_report_pane.add_theme_stylebox_override("panel", box)


func _style_photo_well() -> void:
	var box := _pixel_box(Palette.FOREST_NIGHT, Palette.CASTLE_SHADOW, 0, 2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	_photo_well.add_theme_stylebox_override("panel", box)


func _style_close_button() -> void:
	_close_button.custom_minimum_size = Vector2(44, 32)
	var normal := _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	var hover := _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2)
	_close_button.add_theme_stylebox_override("normal", normal)
	_close_button.add_theme_stylebox_override("hover", hover)
	_close_button.add_theme_stylebox_override("pressed", hover)
	_close_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_close_button.add_theme_font_override("font", _pixel_font)
	_close_button.add_theme_font_size_override("font_size", 12)


func _style_pane_toggle(button: Button, selected: bool) -> void:
	var fill := Palette.CASTLE_SHADOW if selected else Palette.FIELD_BG
	var border := Palette.FIELD_TEXT if selected else Palette.CASTLE_STONE
	var text := Palette.FIELD_BG if selected else Palette.FIELD_TEXT
	var box := _pixel_box(fill, border, 0, 2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", text)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 11)
	button.custom_minimum_size = Vector2(0, 44)


func _style_nav_file(button: Button) -> void:
	button.custom_minimum_size = Vector2(120, 44)
	var box := _pixel_box(Color(Palette.BG_DEEP, 0.4), Palette.CYAN, 0, 2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", _pixel_box(Color(Palette.BG_DEEP, 0.25), Palette.TEXT_MUTED, 0, 2))
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 11)


func _style_submit() -> void:
	var box := _pixel_box(Palette.GREEN, Palette.BG_DEEP, 0, 2)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	_submit_button.add_theme_stylebox_override("normal", box)
	_submit_button.add_theme_stylebox_override("hover", box)
	_submit_button.add_theme_stylebox_override("pressed", box)
	_submit_button.add_theme_color_override("font_color", Palette.BG_DEEP)
	if _pixel_font != null:
		_submit_button.add_theme_font_override("font", _pixel_font)
	_submit_button.add_theme_font_size_override("font_size", 16)
	_submit_button.custom_minimum_size = Vector2(0, 56)


func _style_choice(button: Button, selected: bool) -> void:
	var fill := Palette.FIELD_BG if selected else Color(Palette.BG_DEEP, 0.35)
	var border := Palette.TEXT_PRIMARY if selected else Palette.CYAN
	var text := Palette.FIELD_TEXT if selected else Palette.TEXT_PRIMARY
	var box := _pixel_box(fill, border, 0, 2)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", text)


func _style_flag(button: Button, selected: bool) -> void:
	var fill := Color(Palette.BG_DEEP, 0.28)
	var border := Palette.TEXT_PRIMARY if selected else Palette.CYAN
	var box := _pixel_box(fill, border, 0, 2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 11)
	button.custom_minimum_size = Vector2(0, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _apply_label(label: Control, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
