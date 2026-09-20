class_name DecisionOverlay
extends Control
## Incident-style presentation for decision stages. Built in code so the
## existing level_base.tscn (TRACE quiz modal, HUD, pause menu) stays untouched.
##
## Three views:
##   story       - dialogue lines + one CONTINUE button
##   threat      - dialogue, situation, evidence, "CHOOSE AN ACTION", 3 actions
##   consequence - outcome banner (THREAT CONTAINED / SECURITY WARNING /
##                 SYSTEM COMPROMISED), narrative result, lesson, CONTINUE
## It never shows quiz vocabulary ("Question", "Correct", "Quiz", "Exam").

signal story_continued
signal choice_selected(choice_index: int)
signal consequence_continued

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const WINDOW_WIDTH := 760.0
const VIEW_MARGIN := 40.0
const CHOICE_MIN_HEIGHT := 56.0
const CHOICE_PAD_Y := 28.0
const CHOICE_PAD_X := 42.0

var _pixel_font: Font
var _dim: ColorRect
var _window: PanelContainer
var _column: VBoxContainer
var _body_scroll: ScrollContainer
var _header_left: Label
var _header_right: Label
var _banner: Label
var _dialogue_box: VBoxContainer
var _situation_title: Label
var _situation: Label
var _evidence_title: Label
var _evidence_box: VBoxContainer
var _prompt: Label
var _choices_box: VBoxContainer
var _choice_buttons: Array[Button] = []
var _continue_button: Button
var _mode: StringName = &"story"
var _locked: bool = false
var _selected_index: int = -1
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_focus: StyleBoxFlat
var _style_disabled: StyleBoxFlat
var _story_banner: String = ""


func _init() -> void:
	# Built in _init, not _ready: LevelManager mounts this overlay while the
	# level scene is still being readied, and shows the first beat immediately.
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(FONT_PATH):
		_pixel_font = load(FONT_PATH) as Font
	resized.connect(_fit_layout)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(Palette.DEEP_SPACE, 0.82)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_window = PanelContainer.new()
	_window.name = "IncidentWindow"
	_window.custom_minimum_size = Vector2(WINDOW_WIDTH, 0)
	_window.clip_contents = true
	var box: StyleBoxFlat = _panel_box(Palette.NAVY_900, Palette.CYAN_400, 3)
	box.shadow_color = Color(Palette.DEEP_SPACE, 0.82)
	box.shadow_size = 5
	box.shadow_offset = Vector2(8, 8)
	box.content_margin_left = 26.0
	box.content_margin_right = 26.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 22.0
	_window.add_theme_stylebox_override("panel", box)
	center.add_child(_window)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", 12)
	_window.add_child(_column)

	var header := HBoxContainer.new()
	header.name = "Header"
	_header_left = _label(Palette.CYAN_300, 9)
	_header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_right = _label(Palette.CYAN_300, 9)
	_header_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_header_left)
	header.add_child(_header_right)
	_column.add_child(header)

	_banner = _label(Palette.SUCCESS, 18)
	_banner.name = "Banner"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_banner)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "BodyScroll"
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_column.add_child(_body_scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_body_scroll.add_child(body)

	_dialogue_box = VBoxContainer.new()
	_dialogue_box.name = "Dialogue"
	_dialogue_box.add_theme_constant_override("separation", 8)
	body.add_child(_dialogue_box)

	_situation_title = _label(Palette.GOLD, 9)
	_situation_title.name = "SituationTitle"
	_situation_title.text = "INCIDENT"
	body.add_child(_situation_title)
	_situation = _label(Palette.CREAM, 11)
	_situation.name = "Situation"
	body.add_child(_situation)

	_evidence_title = _label(Palette.GOLD, 9)
	_evidence_title.name = "EvidenceTitle"
	_evidence_title.text = "EVIDENCE"
	body.add_child(_evidence_title)
	var evidence_panel := PanelContainer.new()
	evidence_panel.name = "EvidencePanel"
	evidence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var well: StyleBoxFlat = _panel_box(Color(Palette.NAVY_800, 0.98), Palette.NAVY_700, 1)
	well.content_margin_left = 14.0
	well.content_margin_right = 14.0
	well.content_margin_top = 10.0
	well.content_margin_bottom = 10.0
	evidence_panel.add_theme_stylebox_override("panel", well)
	body.add_child(evidence_panel)
	_evidence_box = VBoxContainer.new()
	_evidence_box.name = "Evidence"
	_evidence_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_evidence_box.add_theme_constant_override("separation", 6)
	evidence_panel.add_child(_evidence_box)

	_prompt = _label(Palette.GOLD, 10)
	_prompt.name = "Prompt"
	_prompt.text = "CHOOSE AN ACTION"
	body.add_child(_prompt)

	_choices_box = VBoxContainer.new()
	_choices_box.name = "Choices"
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_box.add_theme_constant_override("separation", 8)
	body.add_child(_choices_box)
	_make_choice_styles()
	for i in 3:
		var button := Button.new()
		button.name = "Action%d" % (i + 1)
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		button.clip_contents = false
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, CHOICE_MIN_HEIGHT)
		_style_choice(button)
		button.pressed.connect(_on_choice_pressed.bind(i))
		button.mouse_entered.connect(_on_choice_hovered.bind(i))
		button.focus_entered.connect(_on_choice_focused.bind(i))
		_choices_box.add_child(button)
		_choice_buttons.append(button)

	_continue_button = Button.new()
	_continue_button.name = "Continue"
	_continue_button.text = "CONTINUE"
	_style_submit(_continue_button)
	_continue_button.pressed.connect(_on_continue_pressed)
	_column.add_child(_continue_button)
	_apply_mode()


## Dialogue-only beat (opening, ending, resume notice). An optional banner
## reuses the consequence banner styling for beats that need a short heading
## (e.g. "BREACH CONTAINED") without offering the three action choices.
func show_story(lines: Array[Dictionary], header: String, continue_text: String = "CONTINUE", banner: String = "") -> void:
	_mode = &"story"
	_locked = false
	_selected_index = -1
	_header_left.text = header
	_header_right.text = ""
	_fill_dialogue(lines)
	_continue_button.text = continue_text
	_story_banner = banner.strip_edges()
	if not _story_banner.is_empty():
		_banner.text = _story_banner
		_banner.add_theme_color_override("font_color", outcome_color(DecisionScenarios.OUTCOME_SAFE))
	_apply_mode()
	_release_choice_focus()
	_fit_layout()
	call_deferred("_fit_layout")


## Threat beat: dialogue, incident, evidence, three actions.
func show_threat(threat: Dictionary, threat_number: int, threat_total: int, header: String) -> void:
	_mode = &"threat"
	_locked = false
	_selected_index = -1
	_header_left.text = header
	_header_right.text = "INCIDENT %d / %d" % [threat_number, threat_total]
	_fill_dialogue(DecisionScenarios.dialogue_lines(threat, "story"))
	_situation_title.text = str(threat.get("title", "INCIDENT")).to_upper()
	_situation.text = str(threat.get("situation", ""))
	_fill_evidence(threat.get("evidence", []))
	var choices: Array = threat.get("choices", []) as Array
	for i in _choice_buttons.size():
		var button: Button = _choice_buttons[i]
		if i < choices.size() and typeof(choices[i]) == TYPE_DICTIONARY:
			button.text = "%s   %s" % [char(65 + i), str((choices[i] as Dictionary).get("label", ""))]
			button.visible = true
			button.disabled = false
			_paint_choice(button, false)
		else:
			button.visible = false
	_apply_mode()
	_release_choice_focus()
	_body_scroll.scroll_vertical = 0
	_fit_layout()
	call_deferred("_fit_layout")


## Narrative result of a decision. No right/wrong wording. banner_override
## replaces the outcome's default banner text (e.g. "BREACH DETECTED" instead
## of "SECURITY WARNING") while keeping the outcome's status line and color.
func show_consequence(outcome: String, consequence: String, explanation: String, header: String, continue_text: String = "CONTINUE", banner_override: String = "") -> void:
	_mode = &"consequence"
	_locked = false
	_header_left.text = header
	_header_right.text = outcome_status_line(outcome)
	var banner_text: String = banner_override.strip_edges()
	_banner.text = banner_text if not banner_text.is_empty() else outcome_banner(outcome)
	_banner.add_theme_color_override("font_color", outcome_color(outcome))
	var lines: Array[Dictionary] = [{"speaker": "", "text": consequence}]
	if not explanation.strip_edges().is_empty():
		lines.append({"speaker": "Security Assistant", "text": explanation})
	_fill_dialogue(lines)
	_continue_button.text = continue_text
	_apply_mode()
	_release_choice_focus()
	_fit_layout()
	call_deferred("_fit_layout")


func set_interaction_locked(locked: bool) -> void:
	_locked = locked
	for button in _choice_buttons:
		button.disabled = locked
	_continue_button.disabled = locked


static func outcome_banner(outcome: String) -> String:
	match outcome:
		DecisionScenarios.OUTCOME_SAFE:
			return "THREAT CONTAINED"
		DecisionScenarios.OUTCOME_RISKY:
			return "SECURITY WARNING"
		DecisionScenarios.OUTCOME_CRITICAL:
			return "SYSTEM COMPROMISED"
	return ""


static func outcome_status_line(outcome: String) -> String:
	match outcome:
		DecisionScenarios.OUTCOME_SAFE:
			return "STATUS  SECURE"
		DecisionScenarios.OUTCOME_RISKY:
			return "STATUS  BREACH IN PROGRESS"
		DecisionScenarios.OUTCOME_CRITICAL:
			return "STATUS  CRITICAL"
	return ""


static func outcome_color(outcome: String) -> Color:
	match outcome:
		DecisionScenarios.OUTCOME_SAFE:
			return Palette.SUCCESS
		DecisionScenarios.OUTCOME_RISKY:
			return Palette.WARNING
		DecisionScenarios.OUTCOME_CRITICAL:
			return Palette.DANGER
	return Palette.CREAM


func _apply_mode() -> void:
	var threat: bool = _mode == &"threat"
	var consequence: bool = _mode == &"consequence"
	var story_banner: bool = _mode == &"story" and not _story_banner.is_empty()
	_banner.visible = consequence or story_banner
	_situation_title.visible = threat
	_situation.visible = threat
	_evidence_title.visible = threat and _evidence_box.get_child_count() > 0
	_evidence_box.get_parent().visible = _evidence_title.visible
	_prompt.visible = threat
	_choices_box.visible = threat
	_continue_button.visible = not threat
	_continue_button.disabled = _locked


func _fill_dialogue(lines: Array[Dictionary]) -> void:
	for child in _dialogue_box.get_children():
		child.queue_free()
	for i in lines.size():
		var line: Dictionary = lines[i]
		var speaker: String = str(line.get("speaker", "")).strip_edges()
		var text: String = str(line.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 3)
		if not speaker.is_empty():
			var who: Label = _label(Palette.CYAN_300, 9)
			who.text = speaker.to_upper()
			row.add_child(who)
		var said: Label = _label(Palette.CREAM if speaker.is_empty() else Palette.TEXT_PRIMARY, 11)
		said.text = text if speaker.is_empty() else "\"%s\"" % text
		row.add_child(said)
		_dialogue_box.add_child(row)


func _fill_evidence(raw: Variant) -> void:
	for child in _evidence_box.get_children():
		child.queue_free()
	if typeof(raw) != TYPE_ARRAY:
		return
	var rows: Array = raw as Array
	for i in rows.size():
		var text: String = str(rows[i]).strip_edges()
		if text.is_empty():
			continue
		var line: Label = _label(Palette.CYAN_300, 9)
		line.text = "> " + text
		_evidence_box.add_child(line)


func _on_choice_pressed(index: int) -> void:
	if _locked or _mode != &"threat":
		return
	_selected_index = index
	_paint_choices()
	set_interaction_locked(true)
	choice_selected.emit(index)


func _on_choice_hovered(index: int) -> void:
	if _locked or _mode != &"threat":
		return
	# Mouse hover should never stack on top of another button's keyboard focus.
	for i in _choice_buttons.size():
		if i != index and _choice_buttons[i].has_focus():
			_choice_buttons[i].release_focus()


func _on_choice_focused(index: int) -> void:
	if _locked or _mode != &"threat":
		return
	for i in _choice_buttons.size():
		if i != index and _choice_buttons[i].has_focus():
			_choice_buttons[i].release_focus()


func _on_continue_pressed() -> void:
	if _locked:
		return
	set_interaction_locked(true)
	if _mode == &"consequence":
		consequence_continued.emit()
	else:
		story_continued.emit()


func _fit_layout() -> void:
	if _window == null or _body_scroll == null:
		return
	var view: Vector2 = get_viewport_rect().size
	if view.x < 8.0 or view.y < 8.0:
		view = Vector2(1280, 720)
	var max_h: float = maxf(360.0, view.y - VIEW_MARGIN)
	var width: float = minf(WINDOW_WIDTH, maxf(320.0, view.x - VIEW_MARGIN))
	_window.custom_minimum_size.x = width
	_fit_choice_buttons(width)
	var chrome: float = 40.0
	for child in _column.get_children():
		var control: Control = child as Control
		if control == null or control == _body_scroll or not control.visible:
			continue
		chrome += control.get_combined_minimum_size().y + 12.0
	var body: Control = _body_scroll.get_child(0) as Control if _body_scroll.get_child_count() > 0 else null
	var body_h: float = body.get_combined_minimum_size().y if body != null else 0.0
	var scroll_h: float = minf(body_h, maxf(80.0, max_h - chrome))
	_body_scroll.custom_minimum_size = Vector2(0, scroll_h)
	_window.custom_minimum_size.y = minf(chrome + scroll_h, max_h)


func _fit_choice_buttons(window_width: float) -> void:
	var wrap_w: float = maxf(160.0, window_width - 52.0 - CHOICE_PAD_X)
	for button in _choice_buttons:
		if not button.visible:
			continue
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		if font == null:
			button.custom_minimum_size = Vector2(0, CHOICE_MIN_HEIGHT)
			continue
		var text_size: Vector2 = font.get_multiline_string_size(
			button.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			wrap_w,
			font_size
		)
		button.custom_minimum_size = Vector2(0, maxf(CHOICE_MIN_HEIGHT, text_size.y + CHOICE_PAD_Y))


func _release_choice_focus() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var owner: Control = viewport.gui_get_focus_owner()
	if owner != null and _choice_buttons.has(owner):
		owner.release_focus()
	_continue_button.release_focus()


func _paint_choices() -> void:
	for i in _choice_buttons.size():
		_paint_choice(_choice_buttons[i], i == _selected_index)


func _paint_choice(button: Button, selected: bool) -> void:
	if selected:
		button.add_theme_stylebox_override("normal", _style_selected)
		button.add_theme_stylebox_override("hover", _style_selected)
		button.add_theme_stylebox_override("pressed", _style_selected)
		button.add_theme_stylebox_override("focus", _style_selected)
	else:
		button.add_theme_stylebox_override("normal", _style_normal)
		button.add_theme_stylebox_override("hover", _style_hover)
		button.add_theme_stylebox_override("pressed", _style_selected)
		button.add_theme_stylebox_override("focus", _style_focus)


func _label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)
	return label


func _panel_box(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(0)
	return box


func _make_choice_styles() -> void:
	_style_normal = _panel_box(Palette.NAVY_900, Palette.CYAN_400, 2)
	_style_normal.border_width_left = 6
	_style_hover = _panel_box(Palette.NAVY_800, Palette.CYAN_300, 2)
	_style_hover.border_width_left = 8
	_style_selected = _panel_box(Palette.PRIMARY_BLUE, Palette.CYAN_300, 3)
	_style_selected.border_width_left = 8
	# Focus is an outline only. It must not reuse the hover/selected fill.
	_style_focus = _panel_box(Palette.NAVY_900, Palette.GOLD, 1)
	_style_focus.border_width_left = 6
	_style_disabled = _panel_box(Color(Palette.NAVY_900, 0.68), Palette.NAVY_700, 2)
	for box in [_style_normal, _style_hover, _style_selected, _style_focus, _style_disabled]:
		box.content_margin_left = 18.0
		box.content_margin_right = 18.0
		box.content_margin_top = 14.0
		box.content_margin_bottom = 14.0


func _style_choice(button: Button) -> void:
	_paint_choice(button, false)
	button.add_theme_stylebox_override("disabled", _style_disabled)
	button.add_theme_color_override("font_color", Palette.CREAM)
	button.add_theme_color_override("font_hover_color", Palette.CREAM)
	button.add_theme_color_override("font_pressed_color", Palette.CREAM)
	button.add_theme_color_override("font_focus_color", Palette.CREAM)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	button.add_theme_font_size_override("font_size", 10)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)


func _style_submit(button: Button) -> void:
	var normal: StyleBoxFlat = _panel_box(Palette.GOLD, Palette.TEXT_ON_GOLD, 2)
	var hover: StyleBoxFlat = _panel_box(Palette.CYAN, Palette.TEXT_ON_GOLD, 2)
	var disabled: StyleBoxFlat = _panel_box(Color(Palette.BG_PANEL_ALT, 0.85), Palette.TEXT_MUTED, 2)
	var focus: StyleBoxFlat = _panel_box(Palette.GOLD, Palette.CYAN_300, 2)
	for box in [normal, hover, disabled, focus]:
		box.content_margin_left = 22.0
		box.content_margin_right = 22.0
		box.content_margin_top = 10.0
		box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_hover_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_pressed_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_focus_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	button.add_theme_font_size_override("font_size", 12)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(320, 52)
