extends Control
## Responsive story presentation using the same readable chrome as geometric
## gameplay. Authored dialogue, evidence, choices and consequences stay unchanged.
signal story_continued
signal choice_selected(index: int)
signal consequence_continued
signal decision_ready
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Portrait = preload("res://src/gameplay/decision/dialogue_portrait.gd")
# Future art can be assigned by exact authored speaker name, without changing story data.
var portrait_textures: Dictionary = {}
var _lines: Array[Dictionary] = []
var _line_index := 0
var _typing := false
var _revealed := 0.0
var _dialogue_done := true
var _caption := "CONTINUE"
var _speaker_label: Label
var _line_counter: Label
var _speech: RichTextLabel
var _portraits: Array[Control] = []
var _portrait_names: Array[Label] = []
var _cast: Array[String] = []
var _conversation: HBoxContainer
var _speech_box: PanelContainer
var _history: Array[Dictionary] = []
var _line_recorded := false
var _review_open := false
var _review_button: Button
var _review_panel: PanelContainer
var _review_close: Button
var _review_content: VBoxContainer
var _timer_row: HBoxContainer
var _timer_text: Label
var _timer_bar: ProgressBar
var _evidence: Control
var _choice_hint: Label
var _mode: StringName = &"story"
var _locked := false
var _window: PanelContainer
var _header: Label
var _narrative: VBoxContainer
var _actions: VBoxContainer
var _choices_scroll: ScrollContainer
var _continue_button: Button
var _choice_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_window = UI.panel(self, Color("101c24"))
	_window.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var layout := UI.column(_window, 14)
	_header = UI.label("", 26, UI.TEAL)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	layout.add_child(top)
	_header.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_header)
	_review_button = UI.button("DIALOGUE REVIEW", _open_review)
	_review_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_review_button)
	_timer_row = HBoxContainer.new()
	_timer_row.add_theme_constant_override("separation", 16)
	layout.add_child(_timer_row)
	_timer_text = UI.label("DECIDE / 45s", 26, UI.GOLD)
	_timer_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_timer_row.add_child(_timer_text)
	_timer_bar = ProgressBar.new()
	_timer_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_timer_bar.custom_minimum_size.y = 12
	_timer_bar.show_percentage = false
	_timer_bar.add_theme_stylebox_override("background", UI.box(UI.BG, UI.BG, 0))
	_timer_bar.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	_timer_row.add_child(_timer_bar)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	layout.add_child(columns)
	_narrative = UI.scroll_column(columns)
	_narrative.size_flags_vertical = SIZE_EXPAND_FILL
	_narrative.get_parent().size_flags_stretch_ratio = 1.15
	_actions = UI.scroll_column(columns)
	_choices_scroll = _actions.get_parent()
	_continue_button = UI.button("CONTINUE", _continue, true)
	layout.add_child(_continue_button)
	_review_panel = UI.panel(self, Color("101c24"))
	_review_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_review_panel.mouse_filter = MOUSE_FILTER_STOP
	var review_layout := UI.column(_review_panel)
	var review_top := HBoxContainer.new()
	review_layout.add_child(review_top)
	var review_title := UI.label("DIALOGUE REVIEW", 28, UI.GOLD)
	review_title.size_flags_horizontal = SIZE_EXPAND_FILL
	review_top.add_child(review_title)
	_review_close = UI.button("RETURN", _close_review)
	_review_close.autowrap_mode = TextServer.AUTOWRAP_OFF
	review_top.add_child(_review_close)
	review_layout.add_child(UI.label("Conversation so far / Decision timer paused", 26, UI.MUTED))
	_review_content = UI.scroll_column(review_layout)
	_review_panel.hide()
	resized.connect(_metrics)

func _reset(mode: StringName, header: String, caption: String) -> void:
	_mode = mode
	_locked = false
	_review_open = false
	_review_panel.hide()
	_timer_row.hide()
	_lines.clear()
	_line_index = 0
	_typing = false
	_dialogue_done = true
	_caption = caption
	_speech = null
	_evidence = null
	_choice_hint = null
	_conversation = null
	_portraits.clear()
	_portrait_names.clear()
	_cast.clear()
	UI.clear(_narrative)
	UI.clear(_actions)
	_choice_buttons.clear()
	_header.text = header
	_choices_scroll.hide()
	_continue_button.visible = mode != &"threat"
	_continue_button.disabled = false
	_continue_button.text = caption
	(_narrative.get_parent() as ScrollContainer).scroll_vertical = 0
	_choices_scroll.scroll_vertical = 0
	_window.add_theme_stylebox_override("panel", UI.box(Color("101c24")))

func _dialogue(lines: Array[Dictionary]) -> void:
	_lines = lines.duplicate(true)
	if _lines.is_empty():
		return
	_dialogue_done = false
	# First named speaker takes the left, the second the right for this scene.
	for line in lines:
		var who := str(line.get("speaker", ""))
		if not who.is_empty() and who not in _cast:
			_cast.append(who)
			if _cast.size() == 2:
				break
	if _cast.is_empty():
		_cast.append("Mia")
	if _cast.size() == 1:
		_cast.append("Security Assistant" if _cast[0] == "Mia" else "Mia")
	_conversation = HBoxContainer.new()
	_conversation.add_theme_constant_override("separation", 20)
	_narrative.add_child(_conversation)
	for who in _cast:
		var seat := UI.column(_conversation, 6)
		seat.custom_minimum_size.x = 150
		var portrait := Portrait.new()
		seat.add_child(portrait)
		_portraits.append(portrait)
		var nameplate := UI.label(who, 24, UI.MUTED)
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seat.add_child(nameplate)
		_portrait_names.append(nameplate)
	_speech_box = UI.panel(_conversation, Color("172d38"))
	_speech_box.size_flags_horizontal = SIZE_EXPAND_FILL
	var body := UI.column(_speech_box, 10)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	body.add_child(heading)
	_speaker_label = UI.label("", 26, UI.TEAL)
	_speaker_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_speaker_label)
	_line_counter = UI.label("", 24, UI.MUTED)
	_line_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_line_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_line_counter)
	_speech = RichTextLabel.new()
	_speech.bbcode_enabled = false
	_speech.fit_content = true
	_speech.scroll_active = false
	_speech.custom_minimum_size.y = 90
	_speech.add_theme_font_override("normal_font", UI.FONT)
	_speech.add_theme_color_override("default_color", UI.TEXT)
	_speech.mouse_filter = MOUSE_FILTER_STOP
	_speech.gui_input.connect(_speech_input)
	body.add_child(_speech)
	_show_line()

func _show_line() -> void:
	var line := _lines[_line_index]
	var who := str(line.get("speaker", ""))
	_speaker_label.text = who.to_upper() if not who.is_empty() else "SCENE"
	_line_counter.text = "%d / %d" % [_line_index + 1, _lines.size()]
	_speech.text = str(line.get("text", ""))
	_speech.visible_characters = 0
	_revealed = 0
	_line_recorded = false
	_typing = not _speech.text.is_empty()
	if not who.is_empty() and who not in _cast:
		_cast[1] = who
	_update_portraits()
	_refresh_controls()

func _update_portraits() -> void:
	var who := str(_lines[_line_index].get("speaker", ""))
	for i in _portraits.size():
		_portraits[i].get_parent().visible = who == _cast[i]
		_portraits[i].portrait_texture = portrait_textures.get(_cast[i])
		_portraits[i].configure(_cast[i], who == _cast[i], who == _cast[i] and _typing and not _locked and not _review_open)
		_portrait_names[i].text = _cast[i]
		_portrait_names[i].add_theme_color_override("font_color", UI.TEAL if who == _cast[i] else UI.MUTED)
	_conversation.move_child(_portraits[0].get_parent(), 0)
	_conversation.move_child(_speech_box, 1)
	_conversation.move_child(_portraits[1].get_parent(), 2)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if who == _cast[1] else HORIZONTAL_ALIGNMENT_LEFT

func _process(delta: float) -> void:
	if not _typing or _locked or _review_open or not is_visible_in_tree():
		return
	_revealed += delta * 42.0
	_speech.visible_characters = int(_revealed)
	if _speech.visible_characters >= _speech.get_total_character_count():
		_reveal_line()

func _reveal_line() -> void:
	_typing = false
	_speech.visible_characters = -1
	if not _line_recorded:
		_history.append(_lines[_line_index].duplicate(true))
		_line_recorded = true
	_update_portraits()
	_refresh_controls()

func _speech_input(event: InputEvent) -> void:
	if _locked or _review_open or not _typing:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_reveal_line()
		_speech.accept_event()

func _refresh_controls() -> void:
	var deciding := _mode == &"threat" and _dialogue_done
	_narrative.alignment = BoxContainer.ALIGNMENT_BEGIN if deciding else BoxContainer.ALIGNMENT_END
	_choices_scroll.visible = deciding
	_timer_row.visible = deciding
	_review_button.disabled = _locked or _history.is_empty()
	_review_close.disabled = _locked
	if _conversation != null:
		_conversation.visible = not deciding
	_continue_button.visible = _mode != &"threat" or not _dialogue_done
	_continue_button.disabled = _locked
	_continue_button.text = "SHOW TEXT" if _typing else ("NEXT LINE  >" if not _dialogue_done and _line_index + 1 < _lines.size() else _caption)
	for button in _choice_buttons:
		button.disabled = _locked or not _dialogue_done
	if _choice_hint != null:
		_choice_hint.text = "Choose your response" if _dialogue_done else "Listen, then choose your response"
	if _evidence != null:
		_evidence.visible = _dialogue_done

func show_story(lines: Array[Dictionary], header: String, continue_text: String = "CONTINUE", banner: String = "") -> void:
	_reset(&"story", header, continue_text)
	if not banner.is_empty():
		_narrative.add_child(UI.label(banner, 30, UI.TEAL))
	_dialogue(lines)
	_metrics.call_deferred()

func show_threat(threat: Dictionary, number: int, total: int, header: String) -> void:
	_reset(&"threat", header, "VIEW SCENARIO / START DECISION")
	_narrative.add_child(UI.label(str(threat.get("title", "INCIDENT")), 30, UI.TEAL))
	_dialogue(DecisionScenarios.dialogue_lines(threat, "story"))
	_evidence = UI.column(_narrative)
	_evidence.add_child(UI.label(str(threat.get("situation", "")), 28))
	var evidence := UI.panel(_evidence, Color("1b3038"))
	var details := UI.column(evidence)
	details.add_child(UI.label("EVIDENCE", 26, UI.GOLD))
	for clue in threat.get("evidence", []):
		details.add_child(UI.label(str(clue), 26))
	_actions.add_child(UI.label("INCIDENT %d / %d" % [number, total], 26, UI.MUTED))
	_choice_hint = UI.label("", 30, UI.TEAL)
	_actions.add_child(_choice_hint)
	var choices: Array = threat.get("choices", [])
	for i in choices.size():
		var button := UI.button(str(choices[i].get("label", "")), _choose.bind(i))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_actions.add_child(button)
		_choice_buttons.append(button)
	_refresh_controls()
	if _lines.is_empty():
		_open_decision()
	_metrics.call_deferred()

func show_consequence(outcome: String, consequence: String, explanation: String, header: String, continue_text: String = "CONTINUE", banner_override: String = "") -> void:
	_reset(&"consequence", header, continue_text)
	var ink := DecisionOverlay.outcome_color(outcome)
	_narrative.add_child(UI.label(banner_override if not banner_override.is_empty() else DecisionOverlay.outcome_banner(outcome), 30, ink))
	var lines: Array[Dictionary] = [{"speaker": "", "text": consequence}]
	if not explanation.is_empty():
		lines.append({"speaker": "Security Assistant", "text": explanation})
	_dialogue(lines)
	_window.add_theme_stylebox_override("panel", UI.box(Color("101c24"), ink))
	_metrics.call_deferred()

func set_interaction_locked(locked: bool) -> void:
	_locked = locked
	_refresh_controls()
	if not _lines.is_empty():
		_update_portraits()

func _choose(index: int) -> void:
	if _locked or _review_open or _mode != &"threat" or not _dialogue_done or index < 0 or index >= _choice_buttons.size():
		return
	_history.append({"speaker": "Your response", "text": _choice_buttons[index].text})
	set_interaction_locked(true)
	choice_selected.emit(index)

func _continue() -> void:
	if _locked or _review_open:
		return
	if _typing:
		_reveal_line()
		return
	if not _dialogue_done:
		if _line_index + 1 < _lines.size():
			_line_index += 1
			_show_line()
			return
		_dialogue_done = true
		_refresh_controls()
		if _mode == &"threat":
			_open_decision()
			return
	set_interaction_locked(true)
	if _mode == &"story":
		story_continued.emit()
	elif _mode == &"consequence":
		consequence_continued.emit()

func _open_decision() -> void:
	_dialogue_done = true
	_refresh_controls()
	(_narrative.get_parent() as ScrollContainer).scroll_vertical = 0
	decision_ready.emit()

func update_decision_timer(seconds: float, total: float) -> void:
	_timer_bar.max_value = total
	_timer_bar.value = maxf(0, seconds)
	_timer_text.text = "DECIDE / %02ds" % ceili(maxf(0, seconds))
	_timer_text.add_theme_color_override("font_color", Color("ef9292") if seconds <= 10 else UI.GOLD)

func _open_review() -> void:
	if _locked or _review_open or _history.is_empty():
		return
	_review_open = true
	UI.clear(_review_content)
	for line in _history:
		var entry := UI.panel(_review_content, Color("142731"))
		var text := UI.column(entry, 8)
		text.add_child(UI.label(str(line.get("speaker", "")).to_upper() if not str(line.get("speaker", "")).is_empty() else "SCENE", 26, UI.GOLD))
		text.add_child(UI.label(str(line.get("text", "")), 28))
	_review_panel.show()
	(_review_content.get_parent() as ScrollContainer).scroll_vertical = 0
	if not _lines.is_empty():
		_update_portraits()
	_metrics()
	_review_close.grab_focus()

func _close_review() -> void:
	if _locked or not _review_open:
		return
	_review_open = false
	_review_panel.hide()
	if not _lines.is_empty():
		_update_portraits()
	_review_button.grab_focus()

func _metrics() -> void:
	var factor := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var font := maxi(26, ceili(16 / factor))
	for portrait in _portraits:
		portrait.custom_minimum_size = Vector2(80, 90 if get_viewport_rect().size.y < 500 else 130)
	for node in find_children("*", "Control", true, false):
		if node is Label or node is Button:
			node.add_theme_font_size_override("font_size", font)
		if node is Button:
			node.custom_minimum_size.y = maxf(64, ceilf(48 / factor))
		if node is RichTextLabel:
			node.add_theme_font_size_override("normal_font_size", font)
