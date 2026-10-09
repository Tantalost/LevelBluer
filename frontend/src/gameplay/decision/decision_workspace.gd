extends Control
## Responsive story presentation using the same readable chrome as geometric
## gameplay. Authored dialogue, evidence, choices and consequences stay unchanged.
signal story_continued
signal choice_selected(index: int)
signal consequence_continued
signal decision_ready
signal end_call_requested
signal pause_requested
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Portrait = preload("res://src/gameplay/decision/dialogue_portrait.gd")
const Emotion = preload("res://src/gameplay/decision/dialogue_emotion.gd")
const ScreenShake = preload("res://src/gameplay/decision/dialogue_screen_shake.gd")
const CallPanel = preload("res://src/gameplay/decision/decision_call_panel.gd")
const InvestigationPanel = preload("res://src/gameplay/decision/decision_investigation_panel.gd")
const StoryPhone = preload("res://src/gameplay/decision/story_phone.gd")
var _phone: Control
var minimum_text_pixels: float = 16.0
var _phone_enabled: bool = false
var _phone_prompt: VBoxContainer
var _college_cast: bool = false
var _college_background: Texture2D

func configure_presentation(story: Dictionary) -> void:
	_college_cast = str(story.get("visual_theme", "")) == "college"
	if not _college_cast:
		return
	_college_background = AssetManager.get_texture("story_college_commons")
	_illustrated = true
	_school_cast = true # Reuse the illustrated dialogue layout and listener reactions.
	_header.hide()
	_background.show()
	_portrait_stage.show()
	set_background("college_commons")

func configure_laptop(data: Dictionary) -> void:
	remove_child(_phone)
	_phone.queue_free()
	_phone = preload("res://src/gameplay/decision/story_laptop.gd").new()
	_phone.name = "StoryLaptop"
	add_child(_phone)
	_phone.closed.connect(_close_mail)
	_phone.message_read.connect(_record_phone_mail)
	_phone.investigation_confirmed.connect(_finish_phone_investigation)
	_phone.detail_inspected.connect(_log_phone_detail)
	_phone.pause_requested.connect(func() -> void: pause_requested.emit())
	configure_phone(data)
	_story_pause.show()
	for node: Node in _phone_prompt.get_children():
		if node is Button:
			(node as Button).text = "OPEN LAPTOP / CHECK EVIDENCE"
		elif node is Label:
			(node as Label).text = "Use your laptop to check the message against trusted campus sources."

func configure_phone(data: Dictionary) -> void:
	_phone_enabled = not data.is_empty()
	_phone.configure(data)
	_story_pause.visible = _school_cast and not _phone_enabled
# Future art can be assigned by exact authored speaker name, without changing story data.
var portrait_textures: Dictionary = {}
var _illustrated: bool = false
var _background: ColorRect
var _background_art: TextureRect
var _background_location: String = ""
var _assets: Node
var _school_cast: bool = false
var _portrait_stage: Control
var _guide_speaker: String = "Security Assistant"
var _content_columns: HBoxContainer
var _layout: VBoxContainer
var _story_pause: Button
var _review_scrim: ColorRect
var _review_hint: Label
var _story_hp_label: Label
var _story_hp_row: HBoxContainer
var _story_hearts: Array[Control] = []
var _story_hp: int = -1

func set_story_hp(value: int) -> void:
	_story_hp = value
	_story_hp_label.text = "LAST CHANCE" if value == 0 else "%d / 3" % maxi(0, value)
	_story_hp_label.add_theme_color_override("font_color", Color("FFB648") if value <= 1 else UI.TEAL)
	_story_hp_row.visible = value >= 0
	_story_hp_row.accessibility_name = "Story health: %d of 3. %s" % [maxi(0, value), "Next failed decision restarts the stage." if value == 0 else "Failed decisions cost one heart."]
	for i: int in _story_hearts.size():
		_story_hearts[i].health = 1 if i < value else 0
		_story_hearts[i].queue_redraw()
var _mail_generation: int = 0
var _notice_offset: float = 0.0:
	set(value):
		_notice_offset = value
		_fit_school_portraits()

func set_story_art(module_id: String, guide_speaker: String = "Security Assistant") -> void:
	_illustrated = module_id == "mod_01"
	_guide_speaker = guide_speaker
	_school_cast = module_id == "mod_01" and guide_speaker == "Ms. Reyes"
	_header.visible = not _school_cast
	_story_pause.visible = _school_cast
	set_background("")
	_background.visible = _illustrated
	_portrait_stage.visible = _illustrated

## Read only the startup asset cache; never request a download during dialogue.
func set_background(location: String) -> void:
	const LOCATIONS: PackedStringArray = ["rooftop_day", "music_room", "hallway_day", "library_room", "infirmary", "science_lab", "gymnasium", "courtyard", "school_gate_morning", "classroom_sunset", "clubroom", "classroom_day"]
	_background_art.texture = null
	_background_location = location
	if _college_cast:
		_background_art.texture = _college_background
		_background_art.show()
		return
	if _school_cast and location in LOCATIONS and _assets != null:
		_background_art.texture = _assets.get_texture("story_bg_" + location)
	_background_art.visible = _background_art.texture != null

func _on_story_assets_ready(_success: bool) -> void:
	set_background(_background_location)
	if _school_cast and not _lines.is_empty() and is_instance_valid(_speech):
		_update_portraits()

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
var _cast_emotions: Dictionary = {}
var _scene_speakers: PackedStringArray = []
var _last_speaker: String = ""
var _conversation: HBoxContainer
var _speech_box: PanelContainer
var _speaker_heading: HBoxContainer
var _speaker_tab: PanelContainer
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
## Local presentation only: opening a message never follows a URL or grades a choice.
var _mail: Dictionary = {}
var _mail_read: bool = false
var _mail_open: bool = false
var _mail_notice: Button
var _mail_panel: PanelContainer
var _mail_content: VBoxContainer
var _mail_close: Button
var _mail_tween: Tween

func _ready() -> void:
	_assets = get_node_or_null("/root/AssetManager")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_background = ColorRect.new()
	_background.name = "StoryBackground"
	_background.color = Color("0A1730")
	_background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.hide()
	_background_art = TextureRect.new()
	_background_art.name = "LocationArt"
	_background_art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background_art.mouse_filter = MOUSE_FILTER_IGNORE
	_background.add_child(_background_art)
	_portrait_stage = Control.new()
	_portrait_stage.name = "CharacterStage"
	_portrait_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_portrait_stage.mouse_filter = MOUSE_FILTER_IGNORE
	_portrait_stage.clip_contents = true
	add_child(_portrait_stage)
	_window = UI.panel(self, Color("101c24"))
	_window.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var layout := UI.column(_window, 14)
	_layout = layout
	_header = UI.label("", 26, UI.TEAL)
	_header.add_theme_color_override("font_outline_color", Color("050B18"))
	_header.add_theme_constant_override("outline_size", 5)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	layout.add_child(top)
	_header.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_header)
	_story_hp_label = UI.label("", 26, UI.TEAL)
	_story_hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_review_button = UI.button("LOGS", _open_review)
	_review_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_review_button)
	top.alignment = BoxContainer.ALIGNMENT_END
	_story_pause = UI.button("", func() -> void: pause_requested.emit())
	_story_pause.tooltip_text = "Pause"
	_story_pause.accessibility_name = "Pause story"
	top.add_child(_story_pause)
	var pause_icon: Control = preload("res://src/gameplay/preview/resource_icon.gd").new()
	pause_icon.kind = "pause"
	pause_icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_story_pause.add_child(pause_icon)
	_story_pause.hide()
	_mail_notice = UI.button("", _open_mail)
	_mail_notice.set_meta("owns_responsive_metrics", true)
	_mail_notice.autowrap_mode = TextServer.AUTOWRAP_OFF
	_mail_notice.clip_text = true
	_mail_notice.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		var notice_style: StyleBoxFlat = _mail_notice.get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
		notice_style.content_margin_left = 64
		_mail_notice.add_theme_stylebox_override(style_name, notice_style)
	var envelope: IntelPixelIcon = IntelPixelIcon.new()
	envelope.kind = IntelPixelIcon.Kind.ENVELOPE
	envelope.ink_override = UI.TEAL
	envelope.mouse_filter = MOUSE_FILTER_IGNORE
	_mail_notice.add_child(envelope)
	envelope.anchor_top = 0.5
	envelope.anchor_bottom = 0.5
	envelope.offset_left = 14
	envelope.offset_right = 46
	envelope.offset_top = -16
	envelope.offset_bottom = 16
	# Float beside the speaker; never consume the short landscape portrait band.
	add_child(_mail_notice)
	_mail_notice.hide()
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
	_phone_prompt = UI.column(layout)
	_phone_prompt.add_child(UI.label("Check the message and compare your saved school details before deciding.", 26, UI.TEAL))
	_phone_prompt.add_child(UI.button("OPEN PHONE", _open_phone_investigation, true))
	_phone_prompt.hide()
	_content_columns = columns
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
	_mail_panel = UI.panel(self, Color("0A1730"))
	_mail_panel.name = "EmailReader"
	_mail_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_mail_panel.mouse_filter = MOUSE_FILTER_STOP
	var mail_layout: VBoxContainer = UI.column(_mail_panel)
	mail_layout.add_child(UI.label("INBOX / MESSAGE", 28, UI.TEAL))
	_mail_content = UI.scroll_column(mail_layout)
	mail_layout.add_child(UI.label("Message preview only / Links and replies are inactive", 26, UI.MUTED))
	_mail_close = UI.button("BACK TO CONVERSATION", _close_mail, true)
	mail_layout.add_child(_mail_close)
	_mail_panel.hide()
	_review_scrim = ColorRect.new()
	_review_scrim.color = Color("050B18", 0.6)
	_review_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_review_scrim.mouse_filter = MOUSE_FILTER_STOP
	add_child(_review_scrim)
	_review_scrim.hide()
	_review_panel = UI.panel(self, Color("0A1730", 0.97))
	_review_panel.add_theme_stylebox_override("panel", _dialogue_frame(Color("0A1730", 0.97), Color("85d9c3")))
	_review_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_review_panel.mouse_filter = MOUSE_FILTER_STOP
	var review_layout := UI.column(_review_panel)
	var review_top := HBoxContainer.new()
	review_layout.add_child(review_top)
	var review_title := UI.label("LOGS", 28, UI.GOLD)
	review_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	review_title.size_flags_horizontal = SIZE_EXPAND_FILL
	review_top.add_child(review_title)
	_review_close = UI.button("X", _close_review)
	_review_close.accessibility_name = "Close Logs"
	_review_close.autowrap_mode = TextServer.AUTOWRAP_OFF
	review_top.add_child(_review_close)
	_review_hint = UI.label("Conversation so far", 26, UI.MUTED)
	review_layout.add_child(_review_hint)
	_review_content = UI.scroll_column(review_layout)
	_review_panel.hide()
	_phone = StoryPhone.new()
	_phone.name = "StoryPhone"
	add_child(_phone)
	_phone.closed.connect(_close_mail)
	_phone.message_read.connect(_record_phone_mail)
	_phone.investigation_confirmed.connect(_finish_phone_investigation)
	_phone.detail_inspected.connect(_log_phone_detail)
	_story_hp_row = HBoxContainer.new()
	_story_hp_row.name = "StoryHearts"
	_story_hp_row.position = Vector2(24, 24)
	_story_hp_row.mouse_filter = MOUSE_FILTER_IGNORE
	_story_hp_row.add_theme_constant_override("separation", 6)
	add_child(_story_hp_row)
	for i: int in 3:
		var heart: Control = preload("res://src/gameplay/preview/resource_icon.gd").new()
		heart.kind = "health"
		_story_hp_row.add_child(heart)
		_story_hearts.append(heart)
	_story_hp_label.add_theme_color_override("font_outline_color", Color("050B18"))
	_story_hp_label.add_theme_constant_override("outline_size", 5)
	_story_hp_row.add_child(_story_hp_label)
	_story_hp_row.hide()
	resized.connect(_metrics)
	if _assets != null:
		_assets.sync_finished.connect(_on_story_assets_ready)

func _reset(mode: StringName, header: String, caption: String) -> void:
	# Detach the shared action before freeing the previous dialogue container.
	if _continue_button.get_parent() != _layout:
		_continue_button.reparent(_layout)
	_continue_button.size_flags_horizontal = SIZE_FILL
	_continue_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window.show()
	_clear_mail()
	_phone.reset_incident()
	_mode = mode
	_locked = false
	_review_open = false
	_review_panel.hide()
	_review_scrim.hide()
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
	_cast_emotions.clear()
	_scene_speakers.clear()
	_last_speaker = ""
	UI.clear(_portrait_stage)
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
		if not who.is_empty() and who not in _scene_speakers:
			_scene_speakers.append(who)
		if not who.is_empty() and who not in _cast and _cast.size() < 2:
			_cast.append(who)
	if _cast.is_empty():
		_cast.append("Mia")
	if _cast.size() == 1:
		var listener: String = _guide_speaker
		if listener == _cast[0]:
			listener = "Alex" if _cast[0] == "Mia" else "Mia"
		_cast.append(listener)
	_conversation = HBoxContainer.new()
	_conversation.add_theme_constant_override("separation", 20)
	_conversation.item_rect_changed.connect(_fit_school_portraits, CONNECT_DEFERRED)
	_narrative.add_child(_conversation)
	for who in _cast:
		var seat: Control
		if _illustrated:
			seat = Control.new()
			seat.mouse_filter = MOUSE_FILTER_IGNORE
			_portrait_stage.add_child(seat)
			var on_left: bool = _portraits.is_empty()
			seat.anchor_left = 0.03 if on_left else 0.61
			seat.anchor_right = 0.39 if on_left else 0.97
			seat.anchor_top = 0.06
			seat.anchor_bottom = 0.80
		else:
			seat = UI.column(_conversation, 6)
			seat.custom_minimum_size.x = 150
		var portrait := Portrait.new()
		seat.add_child(portrait)
		if _illustrated:
			portrait.frameless = true
			portrait.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_portraits.append(portrait)
		var nameplate := UI.label(who, 24, UI.MUTED)
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seat.add_child(nameplate)
		nameplate.visible = not _illustrated
		if _college_cast:
			nameplate.add_theme_stylebox_override("normal", UI.box(Color("0A1730", 0.94), Color("173058"), 6))
			nameplate.autowrap_mode = TextServer.AUTOWRAP_OFF
		_portrait_names.append(nameplate)
	var dialogue_parent: Control = _conversation
	if _illustrated:
		dialogue_parent = UI.column(_conversation, 0)
		dialogue_parent.size_flags_horizontal = SIZE_EXPAND_FILL
	_speech_box = UI.panel(dialogue_parent, Color("172d38"))
	_speech_box.size_flags_horizontal = SIZE_EXPAND_FILL
	if _illustrated:
		_speech_box.add_theme_stylebox_override("panel", _dialogue_frame(Color("173058"), Color("F3ECD6")))
	var body: VBoxContainer = UI.column(_speech_box, 10)
	var heading: HBoxContainer = HBoxContainer.new()
	_speaker_heading = heading
	heading.add_theme_constant_override("separation", 18)
	if _illustrated:
		dialogue_parent.add_child(heading)
		dialogue_parent.move_child(heading, 0)
	else:
		body.add_child(heading)
	_speaker_label = UI.label("", 26, UI.TEAL)
	_speaker_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _illustrated:
		_speaker_tab = PanelContainer.new()
		var tab_style: StyleBoxFlat = _dialogue_frame(Color("F3ECD6"), Color("8FF0E6"))
		tab_style.content_margin_top = 6
		tab_style.content_margin_bottom = 6
		_speaker_tab.add_theme_stylebox_override("panel", tab_style)
		heading.add_child(_speaker_tab)
		_speaker_tab.add_child(_speaker_label)
		_speaker_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_speaker_label.add_theme_color_override("font_color", Color("101623"))
	else:
		heading.add_child(_speaker_label)
	_line_counter = UI.label("", 24, UI.MUTED)
	_line_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_line_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _illustrated:
		_line_counter.add_theme_color_override("font_outline_color", Color("050B18"))
		_line_counter.add_theme_constant_override("outline_size", 4)
	heading.add_child(_line_counter)
	_line_counter.visible = not _school_cast
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
	if _school_cast:
		_continue_button.reparent(body)
		_continue_button.size_flags_horizontal = SIZE_SHRINK_END
		_continue_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_show_line()

func _dialogue_frame(fill: Color, border: Color) -> StyleBoxFlat:
	var frame: StyleBoxFlat = UI.box(fill, border, 3)
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	frame.content_margin_left = 18
	frame.content_margin_right = 18
	frame.content_margin_top = 14
	frame.content_margin_bottom = 14
	frame.shadow_color = Color("050B18", 0.7)
	frame.shadow_size = 3
	return frame

## Full-body art is staged behind the dialogue so faces remain readable on
## phones. Other cast members retain their head portraits until art approval.
func _fit_school_portraits() -> void:
	if not _school_cast or not is_instance_valid(_conversation) or not is_inside_tree():
		return
	var top: float = _review_button.get_global_rect().end.y - _portrait_stage.global_position.y + 6.0
	var bottom: float = _conversation.global_position.y - _portrait_stage.global_position.y
	var body_bottom: float = minf(_portrait_stage.size.y - 12.0, _speech_box.get_global_rect().end.y - _portrait_stage.global_position.y - 6.0)
	var height: float = maxf(0.0, body_bottom - top)
	var width: float = minf(_portrait_stage.size.x * 0.25, height * 0.48)
	if _mail_notice.visible:
		var factor: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
		_mail_notice.custom_minimum_size = Vector2(0, maxf(64, ceilf(72.0 / factor)))
		var middle_width: float = maxf(1.0, _portrait_stage.size.x - 2.0 * (width + 32.0))
		_mail_notice.size = Vector2(minf(middle_width, 480.0 / factor), _mail_notice.custom_minimum_size.y)
		_mail_notice.pivot_offset = _mail_notice.size * 0.5
		_mail_notice.position = Vector2((_portrait_stage.size.x - _mail_notice.size.x) * 0.5, top + _notice_offset)
	for index: int in _portraits.size():
		var seat: Control = _portraits[index].get_parent() as Control
		seat.set_anchors_preset(PRESET_TOP_LEFT)
		var full_body: bool = _portraits[index].body_texture != null or _college_cast
		var seat_size: Vector2 = Vector2(width, height) if full_body else Vector2.ONE * minf(width, minf(height * 0.28, maxf(0.0, bottom - top)))
		seat.position = Vector2(20.0 if index == 0 else _portrait_stage.size.x - seat_size.x - 20.0, top)
		seat.size = seat_size
		if _college_cast:
			var nameplate: Label = _portrait_names[index]
			nameplate.position = Vector2(0, maxf(0, _speaker_heading.global_position.y - seat.global_position.y))
			nameplate.size = Vector2(seat_size.x, nameplate.get_minimum_size().y)

func _show_line() -> void:
	_clear_mail()
	var line := _lines[_line_index]
	_mail = (line.get("mail", {}) as Dictionary).duplicate(true)
	if not _mail.is_empty():
		if _phone_enabled:
			_phone.receive_message(_mail)
		_mail_notice.text = "NEW SMS\nOPEN LAPTOP  >" if _college_cast else "NEW EMAIL\nOPEN MESSAGE  >"
		_animate_notice.call_deferred(_mail_generation)
	var who := str(line.get("speaker", ""))
	var line_emotion := Emotion.of(line)
	_speaker_label.text = who.to_upper() if not who.is_empty() else "SCENE"
	_line_counter.text = "%d / %d" % [_line_index + 1, _lines.size()]
	_speech.text = str(line.get("text", ""))
	_speech.visible_characters = 0
	_revealed = 0
	var settings: Node = get_node_or_null("/root/SettingsService")
	var speed_mode: String = str(settings.get("text_speed")) if settings != null else "normal"
	_typing_speed = Emotion.typing_speed(line_emotion) * (float(settings.call("text_speed_multiplier")) if settings != null else 1.0)
	_pause_remaining = 0.0 if speed_mode == "instant" else Emotion.pause_before(line_emotion)
	_line_recorded = false
	_typing = not _speech.text.is_empty()
	if not who.is_empty() and who not in _cast:
		# A third participant replaces the older listener, not the person who
		# just spoke. For other modules retain their existing seat behavior.
		var seat_index: int = 0 if _school_cast and _cast[1] == _last_speaker else 1
		_cast[seat_index] = who
	if not who.is_empty():
		_cast_emotions[who] = line_emotion
		_last_speaker = who
	_update_portraits()
	_refresh_controls()
	_apply_line_emotion_fx(line_emotion)
	if speed_mode == "instant" and _typing:
		_reveal_line()
	_fit_school_portraits.call_deferred()

func _animate_notice(generation: int) -> void:
	if generation != _mail_generation or _mail.is_empty():
		return
	ScreenShake.cancel(_background)
	var settings: Node = get_node_or_null("/root/SettingsService")
	if settings != null and bool(settings.get("reduced_motion")):
		return
	# Incoming mail is the authored buzz cue, not a text-string match.
	ScreenShake.buzz(_background)
	_fit_school_portraits()
	_notice_offset = -_mail_notice.position.y - _mail_notice.size.y
	_mail_notice.modulate.a = 0.0
	_mail_tween = create_tween()
	_mail_tween.finished.connect(func() -> void: _mail_tween = null)
	_mail_tween.set_parallel(true)
	_mail_tween.tween_property(self, "_notice_offset", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_mail_tween.tween_property(_mail_notice, "modulate:a", 1.0, 0.20)
	_mail_tween.chain().tween_property(_mail_notice, "scale", Vector2.ONE * 1.025, 0.10)
	_mail_tween.chain().tween_property(_mail_notice, "scale", Vector2.ONE, 0.12)
	if _locked or _review_open:
		_mail_tween.pause()

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
		var active: bool = who == _cast[i]
		var mood: String = str(_cast_emotions.get(_cast[i], Emotion.NEUTRAL)) if _school_cast else line_emotion
		_portraits[i].get_parent().visible = _cast[i] in _scene_speakers if _school_cast else active
		_portraits[i].retain_expression = _school_cast
		_portraits[i].portrait_texture = portrait_textures.get(_cast[i])
		_portraits[i].body_texture = Portrait.school_body(_cast[i]) if _school_cast and not _college_cast and _portraits[i].portrait_texture == null else null
		if _college_cast:
			_portraits[i].portrait_texture = Portrait.college_expression(_cast[i], mood)
		elif _school_cast and _portraits[i].portrait_texture == null:
			_portraits[i].portrait_texture = Portrait.school_expression(_cast[i], mood)
		_portraits[i].configure(_cast[i], active, active and _typing and not _locked and not _review_open, mood)
		_portrait_names[i].text = _cast[i].to_upper() if _college_cast else _cast[i]
		_portrait_names[i].visible = not active if _college_cast else not _illustrated
		_portrait_names[i].add_theme_color_override("font_color", UI.TEAL if who == _cast[i] else UI.MUTED)
	if not _illustrated:
		_conversation.move_child(_portraits[0].get_parent(), 0)
		_conversation.move_child(_speech_box, 1)
		_conversation.move_child(_portraits[1].get_parent(), 2)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if who == _cast[1] else HORIZONTAL_ALIGNMENT_LEFT
	if _illustrated:
		_speaker_heading.alignment = BoxContainer.ALIGNMENT_END if who == _cast[1] else BoxContainer.ALIGNMENT_BEGIN
		_speaker_heading.move_child(_speaker_tab, 1 if who == _cast[1] else 0)

func _process(delta: float) -> void:
	if not _typing or _locked or _review_open or _mail_open or not is_visible_in_tree():
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
	if _locked or _review_open or _mail_open or not _typing:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_reveal_line()
		_speech.accept_event()

func _refresh_controls() -> void:
	_window.visible = not _review_open and not (_phone_enabled and _mail_open)
	var choices_were_visible: bool = _choices_scroll.visible
	var investigating := _mode == &"threat" and _dialogue_done and not _investigation_config.is_empty()
	# Choices (and the decision timer) only ever become actionable once any
	# authored investigation is resolved (see _open_decision()/
	# _on_investigation_resolved()) — an incident with no investigation at
	# all behaves exactly as before this system existed.
	var deciding := _mode == &"threat" and _dialogue_done and not investigating
	_story_hp_row.visible = _story_hp >= 0
	_narrative.get_parent().visible = not (deciding and _phone_enabled)
	_choices_scroll.size_flags_stretch_ratio = 1.0
	if _illustrated:
		_portrait_stage.visible = not deciding and not investigating
		var fill: Color = Color("101c24", (0.62 if _phone_enabled else 0.95) if deciding or investigating else 0.10)
		_window.add_theme_stylebox_override("panel", UI.box(fill, Color.TRANSPARENT if _school_cast and not deciding and not investigating else Color("3b626a")))
	_narrative.alignment = BoxContainer.ALIGNMENT_BEGIN if (deciding or investigating) else BoxContainer.ALIGNMENT_END
	_investigation_panel.visible = investigating and not _phone_enabled
	_phone_prompt.visible = investigating and _phone_enabled
	_content_columns.visible = not (investigating and str(_investigation_config.get("mode", "")) == "inspect")
	_investigation_panel.interaction_locked = _locked or _review_open
	_choices_scroll.visible = deciding
	if deciding and not choices_were_visible and not _choice_buttons.is_empty():
		_focus_first_choice.call_deferred()
	# Most decisions are untimed (see DecisionScenarios.has_timer) — the
	# countdown row only ever shows when the caller has explicitly enabled
	# it for the current threat via set_decision_timer_visible(), never by
	# default just because choices are actionable.
	_timer_row.visible = deciding and _timer_visible_for_threat
	_review_button.disabled = _locked or _history.is_empty()
	_review_close.disabled = _locked
	_story_pause.disabled = _locked or _review_open
	if _conversation != null:
		_conversation.visible = not deciding and not investigating
	_continue_button.visible = _mode != &"threat" or not _dialogue_done
	_continue_button.disabled = _locked
	_continue_button.text = "SHOW TEXT" if _typing else ("NEXT LINE  >" if not _dialogue_done and _line_index + 1 < _lines.size() else _caption)
	if _school_cast:
		_continue_button.text = "REVEAL  >" if _typing else ("NEXT  >" if not _dialogue_done and _line_index + 1 < _lines.size() else _caption)
	if not _typing and not _mail.is_empty() and not _mail_read:
		_continue_button.text = "OPEN LAPTOP  >" if _college_cast else "OPEN EMAIL  >"
	_mail_notice.visible = not _mail.is_empty() and not _dialogue_done and not _review_open
	_mail_notice.disabled = _locked or _review_open or _mail_open
	_mail_close.disabled = _locked
	_review_button.disabled = _review_button.disabled or _mail_open
	for button in _choice_buttons:
		button.disabled = _locked or _review_open or not _dialogue_done or investigating
	if _choice_hint != null:
		_choice_hint.text = "What should Alex do?" if _phone_enabled else ("Choose your response" if _dialogue_done else "Listen, then choose your response")
	if _evidence != null:
		_evidence.visible = _dialogue_done and not investigating
	# Phone inspection hides this root. Refit when it returns as compact choices,
	# rather than retaining the previous dialogue/investigation minimum height.
	_window.set_deferred("size", size)

func show_story(lines: Array[Dictionary], header: String, continue_text: String = "CONTINUE", banner: String = "") -> void:
	_reset(&"story", header, continue_text)
	if not banner.is_empty():
		_narrative.add_child(UI.label(banner, 30, UI.TEAL))
	_dialogue(lines)
	_metrics.call_deferred()

func _focus_first_choice() -> void:
	# A scene can reset before the deferred container layout finishes.
	if not _choice_buttons.is_empty() and is_instance_valid(_choice_buttons[0]) and _choice_buttons[0].is_visible_in_tree() and not _choice_buttons[0].disabled:
		_choice_buttons[0].grab_focus()

## story_lines: the threat's own opening dialogue, already resolved by the
## caller (see stage_one_live.gd's _show_threat()) — this never calls
## DecisionScenarios.dialogue_lines() itself, so it stays account-agnostic
## and never needs to know about story memory, exactly like show_story()
## and show_consequence() already take their lines as a parameter.
func show_threat(threat: Dictionary, story_lines: Array[Dictionary], number: int, total: int, header: String) -> void:
	_reset(&"threat", header, "VIEW SCENARIO / START DECISION")
	if _school_cast:
		_header.text = str(threat.get("title", "INCIDENT")).to_upper()
	else:
		_narrative.add_child(UI.label(str(threat.get("title", "INCIDENT")), 30, UI.TEAL))
	_dialogue(story_lines)
	_evidence = UI.column(_narrative)
	var inspection: VBoxContainer = UI.column(_evidence, 10)
	InvestigationPanel.render_display(inspection, threat)
	_evidence.add_child(UI.label(str(threat.get("situation", "")), 28))
	var evidence := UI.panel(_evidence, Color("1b3038"))
	var details := UI.column(evidence)
	details.add_child(UI.label("EVIDENCE", 26, UI.GOLD))
	for clue in threat.get("evidence", []):
		details.add_child(UI.label(str(clue), 26))
	if not _phone_enabled:
		_actions.add_child(UI.label("INCIDENT %d / %d" % [number, total], 26, UI.MUTED))
	_choice_hint = UI.label("", 30, UI.TEAL)
	_actions.add_child(_choice_hint)
	var choices: Array = threat.get("choices", [])
	for i in choices.size():
		var button := UI.button(str(choices[i].get("label", "")), _choose.bind(i))
		button.set_meta("story_decision_card", _phone_enabled)
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
		lines.append({"speaker": _guide_speaker, "text": explanation})
	lines.append_array(story_lines)
	_dialogue(lines)
	_window.add_theme_stylebox_override("panel", UI.box(Color("101c24", 0.16 if _illustrated else 1.0), ink))
	_metrics.call_deferred()

func set_interaction_locked(locked: bool) -> void:
	_locked = locked
	_phone.set_locked(locked)
	if _mail_tween != null and _mail_tween.is_valid():
		if locked:
			_mail_tween.pause()
		else:
			_mail_tween.play()
	_refresh_controls()
	if not _lines.is_empty():
		_update_portraits()

func _choose(index: int) -> void:
	if _locked or _review_open or _mail_open or _mode != &"threat" or not _dialogue_done or not _investigation_config.is_empty() or index < 0 or index >= _choice_buttons.size():
		return
	_history.append({"speaker": "Your response", "text": _choice_buttons[index].text})
	set_interaction_locked(true)
	choice_selected.emit(index)

func _continue() -> void:
	if _locked or _review_open or _mail_open:
		return
	if _typing:
		_reveal_line()
		return
	if not _mail.is_empty() and not _mail_read:
		_open_mail()
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
		if _phone_enabled:
			_open_phone_investigation()
			return
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
	if _phone_enabled:
		_phone.set_investigation(config)
	if not config.is_empty():
		_caption = "OPEN EVIDENCE"
		_refresh_controls()

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
	if _phone_enabled:
		_review_hint.text = _timer_text.text + " / Timer running"


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
	if _locked or _review_open or _mail_open or _history.is_empty():
		return
	_review_open = true
	if not _timer_visible_for_threat:
		_review_hint.text = "Conversation and inspected evidence"
	if _mail_tween != null and _mail_tween.is_valid():
		_mail_tween.pause()
	UI.clear(_review_content)
	for line in _history:
		_add_log_entry(line)
	_review_scrim.show()
	_review_panel.show()
	(_review_content.get_parent() as ScrollContainer).scroll_vertical = 0
	if not _lines.is_empty():
		_update_portraits()
	_refresh_controls()
	_metrics()
	_review_close.grab_focus()

func _close_review() -> void:
	if _locked or not _review_open:
		return
	_review_open = false
	if _mail_tween != null and _mail_tween.is_valid():
		_mail_tween.play()
	_review_panel.hide()
	_review_scrim.hide()
	if not _lines.is_empty():
		_update_portraits()
	_refresh_controls()
	_review_button.grab_focus()
	_fit_school_portraits.call_deferred()

func _add_log_entry(line: Dictionary) -> void:
	var who: String = str(line.get("speaker", ""))
	var player_side: bool = who == "Alex" or who == "Your response"
	var is_mail: bool = who.begins_with("Inbox / ")
	var row: HBoxContainer = HBoxContainer.new()
	row.set_meta("player_side", player_side)
	row.add_theme_constant_override("separation", 12)
	_review_content.add_child(row)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.12
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var avatar_frame: PanelContainer = UI.panel(row, Color("102040"))
	avatar_frame.set_meta("log_avatar", true)
	avatar_frame.size_flags_vertical = SIZE_SHRINK_BEGIN
	avatar_frame.clip_contents = true
	var avatar_style: StyleBoxFlat = UI.box(Color("102040"), UI.TEAL, 2)
	avatar_style.set_corner_radius_all(32)
	avatar_frame.add_theme_stylebox_override("panel", avatar_style)
	if who.is_empty() or is_mail or who == "Your response":
		var icon: IntelPixelIcon = IntelPixelIcon.new()
		icon.kind = IntelPixelIcon.Kind.ENVELOPE if is_mail else IntelPixelIcon.Kind.CHAT
		icon.ink_override = UI.TEAL
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		avatar_frame.add_child(icon)
	else:
		var portrait: Control = Portrait.new()
		portrait.frameless = true
		portrait.custom_minimum_size = Vector2.ZERO
		portrait.portrait_texture = portrait_textures.get(who)
		if _college_cast:
			portrait.portrait_texture = Portrait.college_expression(who, Emotion.of(line), true)
		elif _school_cast and portrait.portrait_texture == null:
			portrait.portrait_texture = Portrait.school_expression(who, Emotion.of(line))
		avatar_frame.add_child(portrait)
		portrait.configure(who, true, false, Emotion.of(line))
		portrait.set_process(false)
	var bubble: PanelContainer = UI.panel(row, Color("153B37") if player_side else Color("102040"))
	bubble.size_flags_horizontal = SIZE_EXPAND_FILL
	bubble.size_flags_stretch_ratio = 0.88
	var bubble_style: StyleBoxFlat = UI.box(Color("153B37") if player_side else Color("102040"), UI.TEAL if player_side else Color("3b626a"), 14)
	bubble_style.set_corner_radius_all(12)
	bubble.add_theme_stylebox_override("panel", bubble_style)
	var content: VBoxContainer = UI.column(bubble, 6)
	var nameplate: Label = UI.label(who.to_upper() if not who.is_empty() else "EVENT", 26, UI.GOLD)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if player_side else HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(nameplate)
	content.add_child(UI.label(str(line.get("text", "")), 28))
	if player_side:
		row.move_child(bubble, 1)
		row.move_child(avatar_frame, 2)
	else:
		row.move_child(spacer, 2)

func _clear_mail() -> void:
	ScreenShake.cancel(_background)
	_mail_generation += 1
	_phone.stop()
	if _mail_tween != null and _mail_tween.is_valid():
		_mail_tween.kill()
	_mail_tween = null
	_notice_offset = 0.0
	_mail_notice.scale = Vector2.ONE
	_mail.clear()
	_mail_read = false
	_mail_open = false
	_mail_notice.hide()
	_mail_notice.modulate = Color.WHITE
	_mail_panel.hide()
	UI.clear(_mail_content)

func _open_mail() -> void:
	if _locked or _review_open or _mail_open or _mail.is_empty() or _dialogue_done:
		return
	if _typing:
		_reveal_line()
	_mail_open = true
	if _phone_enabled:
		_phone.open_phone()
		_refresh_controls()
		return
	UI.clear(_mail_content)
	_mail_content.add_child(UI.label("FROM / " + str(_mail.get("sender", "")), 26, UI.MUTED))
	_mail_content.add_child(UI.label(str(_mail.get("subject", "")), 30, UI.GOLD))
	var body: PanelContainer = UI.panel(_mail_content, Color("102040"))
	body.add_child(UI.label(str(_mail.get("body", "")), 28))
	(_mail_content.get_parent() as ScrollContainer).scroll_vertical = 0
	_mail_panel.show()
	_refresh_controls()
	_metrics()
	_mail_close.grab_focus()

func _close_mail() -> void:
	if _locked or not _mail_open:
		return
	if not _mail_read and not _phone_enabled:
		_history.append({"speaker": "Inbox / " + str(_mail.get("sender", "")), "text": str(_mail.get("subject", "")) + "\n\n" + str(_mail.get("body", ""))})
		_mail_read = true
	_mail_open = false
	_phone.stop()
	_mail_panel.hide()
	if _college_cast:
		_mail_notice.text = "MESSAGE READ\nOPEN AGAIN  >" if _mail_read else "NEW SMS\nOPEN LAPTOP  >"
	else:
		_mail_notice.text = "EMAIL READ\nOPEN AGAIN  >" if _mail_read else "NEW EMAIL\nOPEN PHONE  >"
	_refresh_controls()
	if _continue_button.is_visible_in_tree():
		_continue_button.grab_focus()

func _record_phone_mail() -> void:
	if _locked or not _mail_open or _mail_read or _mail.is_empty():
		return
	_history.append({"speaker": "Inbox / " + str(_mail.get("sender", "")), "text": str(_mail.get("subject", "")) + "\n\n" + str(_mail.get("body", ""))})
	_mail_read = true

func _log_phone_detail(id: String) -> void:
	for item: Dictionary in _investigation_config.get("items", []):
		if str(item.get("id", "")) == id:
			_history.append({"speaker": "Evidence / " + str(item.get("label", "")), "text": str(item.get("analysis", ""))})
			return

func _open_phone_investigation() -> void:
	if _locked or _review_open or not _phone_enabled or not _dialogue_done or _investigation_config.is_empty():
		return
	_mail_open = true
	_phone.open_phone(true)
	_refresh_controls()

func _finish_phone_investigation() -> void:
	if _locked or not _mail_open or _investigation_config.is_empty() or not _phone.is_complete():
		return
	_mail_open = false
	_phone.stop()
	_on_investigation_resolved()
	_focus_first_choice.call_deferred()

func _metrics() -> void:
	_fit_school_portraits.call_deferred()
	var factor := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var font: int = maxi(26, ceili(minimum_text_pixels / factor))
	var decision_height: float = 48.0 if _choice_buttons.size() > 3 else 72.0
	var inset_x: float = minf(size.x * 0.07, 60.0)
	var inset_y: float = minf(size.y * 0.06, 32.0)
	_review_panel.offset_left = inset_x
	_review_panel.offset_right = -inset_x
	_review_panel.offset_top = inset_y
	_review_panel.offset_bottom = -inset_y
	if _school_cast:
		_mail_panel.offset_top = _review_button.get_global_rect().end.y - global_position.y + 14.0
	for portrait in _portraits:
		portrait.custom_minimum_size = Vector2.ZERO if _illustrated else Vector2(80, 90 if get_viewport_rect().size.y < 500 else 130)
	for node in find_children("*", "Control", true, false):
		if node == _phone or _phone.is_ancestor_of(node):
			continue # Phone sizes independently for short landscape screens.
		if node == _mail_notice:
			node.add_theme_font_size_override("font_size", font)
			continue
		if node.get_meta("log_avatar", false):
			node.custom_minimum_size = Vector2.ONE * maxf(64.0, ceilf(40.0 / factor))
		if _call_panel != null and _call_panel.is_ancestor_of(node):
			continue # Preserve the compact phone header instead of inflating it to dialogue size.
		if node is Label or node is Button:
			node.add_theme_font_size_override("font_size", font)
		if node is Button:
			node.custom_minimum_size.y = maxf(64, ceilf((decision_height if bool(node.get_meta("story_decision_card", false)) else 48.0) / factor))
		if node is RichTextLabel:
			node.add_theme_font_size_override("normal_font_size", font)
	# Long consequence copy can temporarily grow the non-container root.
	# Refit after the replacement dialogue's minimum sizes have settled.
	_window.set_deferred("size", size)
