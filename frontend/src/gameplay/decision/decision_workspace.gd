extends Control
## Responsive story presentation using the same readable chrome as geometric
## gameplay. Authored dialogue, evidence, choices and consequences stay unchanged.
signal story_continued
signal choice_selected(index: int)
signal consequence_continued
signal decision_ready
signal end_call_requested
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Portrait = preload("res://src/gameplay/decision/dialogue_portrait.gd")
const Emotion = preload("res://src/gameplay/decision/dialogue_emotion.gd")
const ScreenShake = preload("res://src/gameplay/decision/dialogue_screen_shake.gd")
const CallPanel = preload("res://src/gameplay/decision/decision_call_panel.gd")
const InvestigationPanel = preload("res://src/gameplay/decision/decision_investigation_panel.gd")
# Future art can be assigned by exact authored speaker name, without changing story data.
var portrait_textures: Dictionary = {}
var _lines: Array[Dictionary] = []
var _line_index := 0
var _typing := false
var _revealed := 0.0
## Skip-safe hold (see DialogueEmotion.pause_before) before a line's typing
## actually starts revealing characters. A tap/click during it still jumps
## straight to the full line, same as skipping mid-type.
var _pause_remaining := 0.0
var _typing_speed := 1.0
## The previous line's emotion, so a screen shake (angry/shocked) only fires
## on the leading edge of a run of same-emotion lines — see
## DialogueEmotion.shake_profile and the restraint rule in _apply_line_emotion_fx().
var _previous_line_emotion: String = Emotion.NEUTRAL
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
## Set by the caller (see set_decision_timer_visible()) once per threat —
## true only when THIS threat has an authored, enabled timer. Reset to
## false by _reset() so a countdown from one threat can never bleed into
## the next screen's default presentation.
var _timer_visible_for_threat := false
var _call_panel: Control
## Non-empty only while a threat's authored investigation (see
## DecisionScenarios.has_investigation) is still pending — cleared the
## moment it resolves, which doubles as the single source of truth for
## _refresh_controls()'s "are choices actionable yet" gate (see
## _open_decision()/_on_investigation_resolved()). Reset to {} by _reset()
## so one threat's investigation can never bleed into the next screen.
var _investigation_config: Dictionary = {}
## Optional narrative beat, already resolved by the caller (see
## DecisionScenarios.investigation_resolved_story_event_lines), shown right
## after the investigation confirms and before choices become actionable —
## reuses the exact same dialogue reader as everything else, never a new
## consequence/event system.
var _investigation_followup_lines: Array[Dictionary] = []
var _investigation_panel: Control
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
	_call_panel = CallPanel.new()
	layout.add_child(_call_panel)
	_call_panel.end_call_requested.connect(func() -> void: end_call_requested.emit())
	_call_panel.hide()
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
	_investigation_panel = InvestigationPanel.new()
	layout.add_child(_investigation_panel)
	_investigation_panel.investigation_resolved.connect(_on_investigation_resolved)
	_investigation_panel.hide()
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
	_timer_visible_for_threat = false
	_call_panel.hide()
	_investigation_panel.hide()
	_investigation_config = {}
	_investigation_followup_lines = []
	_lines.clear()
	_line_index = 0
	_typing = false
	_pause_remaining = 0.0
	_typing_speed = 1.0
	_previous_line_emotion = Emotion.NEUTRAL
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
	var line_emotion := Emotion.of(line)
	_speaker_label.text = who.to_upper() if not who.is_empty() else "SCENE"
	_line_counter.text = "%d / %d" % [_line_index + 1, _lines.size()]
	_speech.text = str(line.get("text", ""))
	_speech.visible_characters = 0
	_revealed = 0
	_typing_speed = Emotion.typing_speed(line_emotion)
	_pause_remaining = Emotion.pause_before(line_emotion)
	_line_recorded = false
	_typing = not _speech.text.is_empty()
	if not who.is_empty() and who not in _cast:
		_cast[1] = who
	_update_portraits()
	_refresh_controls()
	_apply_line_emotion_fx(line_emotion)

## Screen-level emotion FX (see DialogueEmotion.shake_profile) fire exactly
## once here, at the moment a new line begins — never repeated by the
## _update_portraits() calls that follow later for the same line (typing
## finishing, dialogue review open/close). Restraint rule: a shake only
## fires on the LEADING EDGE of a run of same-emotion lines — consecutive
## angry/shocked lines don't each re-shake, but leaving and later
## re-entering angry/shocked (even later in the same block) can trigger it
## again, since that's a genuinely new emotional beat.
func _apply_line_emotion_fx(line_emotion: String) -> void:
	# Only a genuine transition triggers a shake. Repeating the same emotion
	# deliberately does nothing here (not even a cancel) — any prior shake
	# from this same beat is short enough to have already finished in
	# practice, and the NEXT real transition (to any other emotion) always
	# cancels stale state first via ScreenShake.apply()'s own cancel() call,
	# so nothing can leak or accumulate either way.
	if line_emotion != _previous_line_emotion:
		ScreenShake.apply(_window, line_emotion)
	_previous_line_emotion = line_emotion

func _update_portraits() -> void:
	var line := _lines[_line_index]
	var who := str(line.get("speaker", ""))
	var line_emotion := Emotion.of(line)
	for i in _portraits.size():
		_portraits[i].get_parent().visible = who == _cast[i]
		_portraits[i].portrait_texture = portrait_textures.get(_cast[i])
		_portraits[i].configure(_cast[i], who == _cast[i], who == _cast[i] and _typing and not _locked and not _review_open, line_emotion)
		_portrait_names[i].text = _cast[i]
		_portrait_names[i].add_theme_color_override("font_color", UI.TEAL if who == _cast[i] else UI.MUTED)
	_conversation.move_child(_portraits[0].get_parent(), 0)
	_conversation.move_child(_speech_box, 1)
	_conversation.move_child(_portraits[1].get_parent(), 2)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if who == _cast[1] else HORIZONTAL_ALIGNMENT_LEFT

func _process(delta: float) -> void:
	if not _typing or _locked or _review_open or not is_visible_in_tree():
		return
	if _pause_remaining > 0.0:
		# Skip-safe hold before revealing starts (see DialogueEmotion.pause_before)
		# — a tap during it goes through _speech_input() -> _reveal_line()
		# exactly like skipping mid-type, never blocked by this pause.
		_pause_remaining = maxf(0.0, _pause_remaining - delta)
		return
	_revealed += delta * 42.0 * _typing_speed
	_speech.visible_characters = int(_revealed)
	if _speech.visible_characters >= _speech.get_total_character_count():
		_reveal_line()

func _reveal_line() -> void:
	_typing = false
	_pause_remaining = 0.0
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
	var investigating := _mode == &"threat" and _dialogue_done and not _investigation_config.is_empty()
	# Choices (and the decision timer) only ever become actionable once any
	# authored investigation is resolved (see _open_decision()/
	# _on_investigation_resolved()) — an incident with no investigation at
	# all behaves exactly as before this system existed.
	var deciding := _mode == &"threat" and _dialogue_done and not investigating
	_narrative.alignment = BoxContainer.ALIGNMENT_BEGIN if (deciding or investigating) else BoxContainer.ALIGNMENT_END
	_investigation_panel.visible = investigating
	_choices_scroll.visible = deciding
	# Most decisions are untimed (see DecisionScenarios.has_timer) — the
	# countdown row only ever shows when the caller has explicitly enabled
	# it for the current threat via set_decision_timer_visible(), never by
	# default just because choices are actionable.
	_timer_row.visible = deciding and _timer_visible_for_threat
	_review_button.disabled = _locked or _history.is_empty()
	_review_close.disabled = _locked
	if _conversation != null:
		_conversation.visible = not deciding and not investigating
	_continue_button.visible = _mode != &"threat" or not _dialogue_done
	_continue_button.disabled = _locked
	_continue_button.text = "SHOW TEXT" if _typing else ("NEXT LINE  >" if not _dialogue_done and _line_index + 1 < _lines.size() else _caption)
	for button in _choice_buttons:
		button.disabled = _locked or not _dialogue_done
	if _choice_hint != null:
		_choice_hint.text = "Choose your response" if _dialogue_done else "Listen, then choose your response"
	if _evidence != null:
		_evidence.visible = _dialogue_done and not investigating

func show_story(lines: Array[Dictionary], header: String, continue_text: String = "CONTINUE", banner: String = "") -> void:
	_reset(&"story", header, continue_text)
	if not banner.is_empty():
		_narrative.add_child(UI.label(banner, 30, UI.TEAL))
	_dialogue(lines)
	_metrics.call_deferred()

## story_lines: the threat's own opening dialogue, already resolved by the
## caller (see stage_one_live.gd's _show_threat()) — this never calls
## DecisionScenarios.dialogue_lines() itself, so it stays account-agnostic
## and never needs to know about story memory, exactly like show_story()
## and show_consequence() already take their lines as a parameter.
func show_threat(threat: Dictionary, story_lines: Array[Dictionary], number: int, total: int, header: String) -> void:
	_reset(&"threat", header, "VIEW SCENARIO / START DECISION")
	_narrative.add_child(UI.label(str(threat.get("title", "INCIDENT")), 30, UI.TEAL))
	_dialogue(story_lines)
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

## story_lines: optional authored story-event beats (see
## DecisionScenarios.story_event_lines) appended after the consequence and
## explanation, inside this SAME screen — never a separate step, so the
## existing CONTINUE gate that already holds RISKY/CRITICAL before
## breach/TD/Game Over covers them for free.
func show_consequence(outcome: String, consequence: String, explanation: String, header: String, continue_text: String = "CONTINUE", banner_override: String = "", story_lines: Array[Dictionary] = []) -> void:
	_reset(&"consequence", header, continue_text)
	var ink := DecisionOverlay.outcome_color(outcome)
	_narrative.add_child(UI.label(banner_override if not banner_override.is_empty() else DecisionOverlay.outcome_banner(outcome), 30, ink))
	var lines: Array[Dictionary] = [{"speaker": "", "text": consequence}]
	if not explanation.is_empty():
		lines.append({"speaker": "Security Assistant", "text": explanation})
	lines.append_array(story_lines)
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

## An authored, still-pending investigation (see set_investigation()) shows
## its panel here INSTEAD of emitting decision_ready — the operational
## choices (and the decision timer) only become actionable once
## _on_investigation_resolved() fires, so a threat with an investigation
## never starts its countdown, or exposes its choices, while it's unread.
func _open_decision() -> void:
	_dialogue_done = true
	_refresh_controls()
	(_narrative.get_parent() as ScrollContainer).scroll_vertical = 0
	if not _investigation_config.is_empty():
		_investigation_panel.configure(_investigation_config)
		_refresh_controls()
		return
	decision_ready.emit()

## Called once an authored investigation's valid item has been analyzed and
## confirmed (see decision_investigation_panel.gd's investigation_resolved
## signal) — clearing _investigation_config both hides the panel (via
## _refresh_controls()'s gate) and permanently unlocks this threat's choices
## for the rest of this attempt (a retry replays the whole incident, so the
## investigation naturally reappears — see the milestone's own retry rule).
## Any authored resolved_story_event lines are spliced into the SAME
## dialogue reader already driving this screen (never a new consequence/
## event system) — once they're read, _continue() reaches _open_decision()
## again on its own, which now finds _investigation_config already empty
## and emits decision_ready immediately, exactly like a threat with no
## investigation at all.
func _on_investigation_resolved() -> void:
	_investigation_config = {}
	var followup: Array[Dictionary] = _investigation_followup_lines
	_investigation_followup_lines = []
	_refresh_controls()
	if followup.is_empty():
		decision_ready.emit()
		return
	var insert_at: int = _lines.size()
	_lines.append_array(followup)
	_dialogue_done = false
	_line_index = insert_at
	_show_line()

## Called once per threat by the caller (see DecisionScenarios.
## has_investigation) — an empty dict (the default after every _reset())
## means no investigation at all, so decision_ready emits immediately once
## dialogue is read, exactly like every existing threat.
func set_investigation(config: Dictionary, followup_lines: Array[Dictionary] = []) -> void:
	_investigation_config = config
	_investigation_followup_lines = followup_lines

## Only ever called by the caller for a threat that actually has an
## enabled, authored timer (see set_decision_timer_visible()) — this method
## itself has no opinion on whether a timer should exist, only on how to
## render one that does. `label` is the optional authored pressure line
## (e.g. "THE CALLER SAYS THE TRANSFER MAY PROCESS"); it defaults to the
## generic "DECIDE" heading when a threat's timer doesn't author one.
## Urgency in the final 3 seconds is signaled by BOTH color and a text
## change (never color alone), and never flashes/animates.
func update_decision_timer(seconds: float, total: float, label: String = "DECIDE") -> void:
	var clamped: float = maxf(0.0, seconds)
	var whole: int = ceili(clamped)
	var urgent: bool = whole <= 3
	_timer_bar.max_value = total
	_timer_bar.value = clamped
	_timer_text.text = "%s / %02ds%s" % [label if not label.is_empty() else "DECIDE", whole, "  !" if urgent else ""]
	_timer_text.add_theme_color_override("font_color", Color("ff3b3b") if urgent else (Color("ef9292") if clamped <= 10.0 else UI.GOLD))


## Called once per threat by the caller (see DecisionScenarios.has_timer) —
## true only for a threat with an enabled, authored timer. false (the
## default after every _reset()) keeps the countdown row hidden entirely,
## which is what "most decisions remain untimed" means in practice here.
func set_decision_timer_visible(visible_now: bool) -> void:
	_timer_visible_for_threat = visible_now
	_refresh_controls()

## Called once per threat/story screen by the caller (see DecisionScenarios.
## has_call) — an empty dict (the default after every _reset()) keeps the
## call row hidden, which is what "most decisions have no call at all" means
## in practice here. Non-empty call_data both shows and (re)configures the
## panel, so a stale mute/ended state from a previous incident's call can
## never bleed into this one.
func set_call(call_data: Dictionary) -> void:
	if call_data.is_empty():
		_call_panel.hide()
		return
	_call_panel.configure(call_data)
	_call_panel.show()

## Presentation only — see stage_one_live.gd's advance_call_duration(). A
## separate clock from the decision countdown; never one clock for both.
func update_call_duration(elapsed_seconds: float) -> void:
	_call_panel.update_duration(elapsed_seconds)

## Ending a call and deciding what to do next are separate concepts: this
## marks the call ENDED and, if the threat authored a call_end_story_event,
## splices it into the SAME dialogue reader the rest of the scene already
## uses (reusing _lines/_show_line() — never a new consequence/event system)
## so it plays through the usual reveal/continue rhythm before leaving the
## player exactly where they were (mid-dialogue, or already deciding). It
## never grades anything and never selects a choice on the player's behalf.
func end_call(story_lines: Array[Dictionary] = []) -> void:
	_call_panel.set_ended()
	if story_lines.is_empty():
		return
	var insert_at: int = _lines.size() if _dialogue_done else _line_index + 1
	for i in story_lines.size():
		_lines.insert(insert_at + i, story_lines[i])
	if _dialogue_done:
		_dialogue_done = false
		_line_index = insert_at
		_show_line()
	_refresh_controls()

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
