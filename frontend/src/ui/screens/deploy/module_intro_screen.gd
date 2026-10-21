extends BaseScreen
## Story-only prologue. Viewing this screen never awards chapter progress.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const BEATS: Array[Dictionary] = [
	{"visual": "email", "line": "A million pesos. That was the promise."},
	{"visual": "email", "line": "Now I keep going back to that morning. The message. The deadline. My finger over the button."},
	{"visual": "email", "line": "But was that really where it started?"},
	{"visual": "caption", "line": "Before the morning…"},
	{"visual": "caption", "line": "A club conversation."},
	{"visual": "caption", "line": "A survey invitation."},
	{"visual": "caption", "line": "An unanswered question."},
	{"visual": "resolve", "line": "I need to figure out what went wrong."},
	{"visual": "caption", "line": "5 days before the disaster", "hold": 2.6},
]

class IntroArtwork extends Control:
	var room: Texture2D
	var title_art: Texture2D
	var ending: bool = false
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()
	func _cover(texture: Texture2D, target: Rect2, tint: Color) -> void:
		if texture == null:
			return
		var source: Vector2 = texture.get_size()
		var factor: float = maxf(target.size.x / source.x, target.size.y / source.y)
		var crop: Vector2 = target.size / factor
		draw_texture_rect_region(texture, target, Rect2((source - crop) * 0.5, crop), tint)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("050B18"))
		if not ending:
			_cover(room, Rect2(Vector2.ZERO, size), Color.WHITE)
			return
		_cover(title_art if title_art != null else room, Rect2(Vector2.ZERO, size), Color(1, 1, 1, reveal))

var _module_index: int = 0
var _index: int = 0
var _active: bool = false
var _leaving: bool = false
var _ending: bool = false
var _focus_lost: bool = false
var _app_paused: bool = false
var _seq: int = 0
var _typing: Tween
var _motion: Tween
var _last_advance: int = -1000
var _art: IntroArtwork
var _header: HBoxContainer
var _back_button: Button
var _skip_button: Button
var _replay_button: Button
var _counter: Label
var _dialogue: PanelContainer
var _speaker: Label
var _dialogue_text: Label
var _advance_button: Button
var _item: PanelContainer
var _item_copy: VBoxContainer
var _chapter_label: Label
var _ending_title: Label
var _start_button: Button
var _caption: Label
var _caption_advance: Button
var _dialogue_status: Label

func _ready() -> void:
	_build()
	resized.connect(_layout_page)
	AssetManager.sync_finished.connect(_on_assets_ready)
	SettingsService.settings_changed.connect(_settings_changed)

func _build() -> void:
	_art = IntroArtwork.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item = UI.panel(self)
	_item.name = "IntroItem"
	var item_style: StyleBoxFlat = UI.box(Color("F3ECD6F5"), Color("173058"), 22)
	item_style.set_corner_radius_all(16)
	_item.add_theme_stylebox_override("panel", item_style)
	_item_copy = UI.column(_item, 16)
	_dialogue = UI.panel(self)
	_dialogue.name = "ModuleNarration"
	var dialogue_style: StyleBoxFlat = UI.box(Color("050B18BD"), Color.TRANSPARENT, 0)
	dialogue_style.set_border_width_all(0)
	dialogue_style.corner_radius_top_right = 58
	dialogue_style.corner_radius_bottom_right = 58
	dialogue_style.corner_detail = 12
	_dialogue.add_theme_stylebox_override("panel", dialogue_style)
	var dialogue_layout: VBoxContainer = UI.column(_dialogue, 0)
	var strip: PanelContainer = UI.panel(dialogue_layout)
	var strip_style: StyleBoxFlat = UI.box(Color("4FE0D4E8"), Color.TRANSPARENT, 8)
	strip_style.set_border_width_all(0)
	strip_style.content_margin_left = 22
	strip_style.content_margin_right = 30
	strip_style.corner_radius_top_right = 42
	strip_style.corner_detail = 12
	strip.add_theme_stylebox_override("panel", strip_style)
	var speaker_row: HBoxContainer = HBoxContainer.new()
	strip.add_child(speaker_row)
	_speaker = UI.label("John / Before the prize", 24, Color("050B18"))
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_row.add_child(_speaker)
	_dialogue_status = UI.label("", 18, Color("050B18"))
	_dialogue_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_dialogue_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_row.add_child(_dialogue_status)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge: String in ["top", "bottom", "left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	dialogue_layout.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	_dialogue_text = UI.label("", 28)
	_dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_dialogue_text)
	_advance_button = _button(">", _advance)
	_advance_button.name = "Advance"
	_advance_button.accessibility_name = "Reveal dialogue or advance to the next line"
	_advance_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_advance_button)
	_caption = UI.label("", 52, Color("F3ECD6"))
	_caption.name = "InnerThought"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_outline_color", Color("050B18"))
	_caption.add_theme_constant_override("outline_size", 10)
	_caption.add_theme_color_override("font_shadow_color", Color("050B18"))
	_caption.add_theme_constant_override("shadow_offset_y", 4)
	add_child(_caption)
	_caption_advance = _button(">", _advance)
	_caption_advance.accessibility_name = "Continue John's thought"
	add_child(_caption_advance)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	add_child(_header)
	_back_button = _button("< BACK", _back)
	_header.add_child(_back_button)
	_counter = UI.label("", 20, Color("8FF0E6"))
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_counter)
	_replay_button = _button("REPLAY", _restart)
	_header.add_child(_replay_button)
	_skip_button = _button("SKIP", _skip)
	_header.add_child(_skip_button)
	_chapter_label = UI.label("MODULE 1", 54, Color("F3ECD6"), true)
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chapter_label.add_theme_color_override("font_outline_color", Color("050B18"))
	_chapter_label.add_theme_constant_override("outline_size", 6)
	add_child(_chapter_label)
	_ending_title = UI.label("Email Tricks", 54, Color("FFB648"), true)
	_ending_title.add_theme_color_override("font_outline_color", Color("050B18"))
	_ending_title.add_theme_constant_override("outline_size", 6)
	add_child(_ending_title)
	_start_button = _button("CONTINUE  >", _on_start_pressed)
	_start_button.name = "ContinueToDeployment"
	add_child(_start_button)

func _button(caption: String, action: Callable) -> Button:
	var button: Button = UI.button(caption, action)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = UI.box(Color("0A1730F0") if state == "normal" else Color("173058"), Color("4FE0D4"), 12)
		style.set_corner_radius_all(18 if caption != ">" else 80)
		if caption == ">":
			style.bg_color = Color("0E2A28E0")
			style.corner_detail = 16
			style.set_border_width_all(2)
			style.shadow_color = Color(0.31, 0.88, 0.83, 0.28)
			style.shadow_size = 12
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("F3ECD6")
		button.add_theme_stylebox_override(state, style)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Color("F3ECD6"))
	return button

func on_enter(args: Dictionary) -> void:
	_module_index = clampi(int(args.get("module_index", 0)), 0, 4)
	_active = true
	_leaving = false
	visible = true
	_last_advance = -1000
	_index = 0
	_ending = false
	_load_art()
	if _module_index != 0:
		_leave_to_stages()
		return
	_show_beat()

func _show_beat() -> void:
	_stop_tweens()
	_seq += 1
	_ending = false
	_art.ending = false
	_art.reveal = 1.0
	_dialogue.show()
	_caption.hide()
	_caption_advance.hide()
	_skip_button.show()
	_replay_button.hide()
	_chapter_label.hide()
	_ending_title.hide()
	_start_button.hide()
	var beat: Dictionary = BEATS[_index]
	var visual: String = str(beat["visual"])
	_art.queue_redraw()
	_counter.text = "BEFORE THE PRIZE"
	_speaker.text = "John  /  Before the prize"
	_dialogue_text.text = str(beat["line"])
	_item.visible = visual == "email"
	if visual == "caption":
		_show_caption(beat)
		return
	if visual == "email":
		_build_item()
	_dialogue_text.visible_characters = 0
	_advance_button.text = "..."
	_dialogue_status.text = "THINKING"
	_advance_button.tooltip_text = "Tap to reveal the line"
	if SettingsService.reduced_motion or SettingsService.text_speed == "instant":
		_finish_line()
	else:
		var rate: float = 48.0 if SettingsService.text_speed == "fast" else 32.0
		_typing = create_tween()
		_typing.tween_property(_dialogue_text, "visible_characters", _dialogue_text.text.length(), _dialogue_text.text.length() / rate)
		_typing.tween_callback(_finish_line)
	if _index == 0:
		AudioManager.play_sfx("ui_notification")
	if not SettingsService.reduced_motion:
		_item.modulate.a = 0.0
		_motion = create_tween()
		_motion.tween_property(_item, "modulate:a", 1.0, 0.3)
	else:
		_item.modulate.a = 1.0
	_layout_page()
	_layout_page.call_deferred()
	_apply_pause()

func _show_caption(beat: Dictionary) -> void:
	_dialogue.hide()
	_item.hide()
	_caption.show()
	_caption_advance.show()
	_caption.text = str(beat["line"])
	_caption.modulate.a = 0.0
	_caption_advance.modulate.a = 0.0
	var fade: float = 0.2 if SettingsService.reduced_motion else 0.55
	_motion = create_tween()
	_motion.tween_property(_caption, "modulate:a", 1.0, fade)
	_motion.tween_property(_caption_advance, "modulate:a", 1.0, 0.15)
	_motion.tween_interval(float(beat.get("hold", 1.8)))
	_motion.tween_property(_caption_advance, "modulate:a", 0.0, 0.15)
	_motion.tween_property(_caption, "modulate:a", 0.0, fade)
	_motion.tween_callback(_next_beat)
	_layout_page()
	_apply_pause()

func _build_item() -> void:
	UI.clear(_item_copy)
	_item_label("MAIL / PRIZE DESK", Color("153B37"))
	_item_label("You won ₱1,000,000", Color("101623"), true)
	_item_label("Claim within 10 minutes.\nConfirm your account password.", Color("101623"))

func _item_label(caption: String, ink: Color, heading: bool = false) -> void:
	var label: Label = UI.label(caption, 26 if heading else 24, ink)
	label.set_meta("item_heading", heading)
	_item_copy.add_child(label)

func _finish_line() -> void:
	_dialogue_text.visible_characters = -1
	_advance_button.text = ">"
	_advance_button.tooltip_text = "Continue"
	_dialogue_status.text = "CONTINUE"

func _advance() -> void:
	if not _can_interact() or _ending or Time.get_ticks_msec() - _last_advance < 160:
		return
	_last_advance = Time.get_ticks_msec()
	if _caption.visible:
		_next_beat()
		return
	if _dialogue_text.visible_characters >= 0:
		if _typing != null and _typing.is_valid():
			_typing.kill()
		_finish_line()
		return
	AudioManager.play_sfx("ui_confirm")
	_next_beat()

func _next_beat() -> void:
	if not _active or _leaving or _ending:
		return
	if _index + 1 < BEATS.size():
		_index += 1
		_show_beat()
	else:
		_show_title()

func _show_title() -> void:
	_stop_tweens()
	_seq += 1
	_ending = true
	_art.ending = true
	_art.reveal = 0.0 if not SettingsService.reduced_motion else 1.0
	_art.queue_redraw()
	_dialogue.hide()
	_item.hide()
	_caption.hide()
	_caption_advance.hide()
	_skip_button.hide()
	_counter.text = ""
	_replay_button.show()
	_chapter_label.show()
	_ending_title.show()
	_start_button.show()
	_start_button.disabled = true
	_start_button.modulate.a = 0.0
	_motion = create_tween()
	if not SettingsService.reduced_motion:
		_motion.tween_property(_art, "reveal", 1.0, 0.65).set_trans(Tween.TRANS_SINE)
	_motion.tween_interval(0.3)
	_motion.tween_callback(func() -> void:
		_start_button.modulate.a = 1.0
		_start_button.disabled = false
	)
	AudioManager.play_sfx("ui_transition")
	_layout_page()
	_apply_pause()

func _skip() -> void:
	if _can_interact() and not _ending:
		_show_title()

func _restart() -> void:
	if not _can_interact():
		return
	_index = 0
	_last_advance = -1000
	_show_beat()

func _back() -> void:
	if _can_interact():
		Router.request_back()

func _on_start_pressed() -> void:
	if not _can_interact() or not _ending or _start_button.disabled:
		return
	_leave_to_stages()

func _leave_to_stages() -> void:
	if _leaving:
		return
	_leaving = true
	_stop_tweens()
	_start_button.disabled = true
	if _module_index == 0:
		PlayerManager.mark_module_intro_seen("mod_01")
	await Router.replace(&"survey_chapter" if _module_index == 0 else &"module_stages", {"module_index": _module_index})

func _can_interact() -> bool:
	return _active and not _leaving and not _focus_lost and not _app_paused

func _load_art() -> void:
	_art.room = AssetManager.get_texture("opening_john_room_wake_v1")
	_art.title_art = AssetManager.get_texture("module1_email_tricks_title_v1")
	_art.queue_redraw()

func _on_assets_ready(_success: bool) -> void:
	_load_art() # Refresh pixels only; never restart a beat or modify progression.

func _layout_page() -> void:
	if not is_instance_valid(_art):
		return
	var w: float = size.x
	var h: float = size.y
	if w < 1 or h < 1:
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var touch: float = maxf(52, 48.0 / physical)
	var inset: float = maxf(18, 12.0 / physical)
	_header.position = Vector2(inset, inset)
	_header.size = Vector2(w - inset * 2, touch)
	for button: Button in [_back_button, _skip_button, _replay_button]:
		button.custom_minimum_size = Vector2(maxf(108, 88.0 / physical), touch)
		button.add_theme_font_size_override("font_size", ceili(18 / physical))
	_counter.add_theme_font_size_override("font_size", ceili(16 / physical))
	_dialogue.position = Vector2(inset, h * 0.69)
	_dialogue.size = Vector2(w - inset * 2, h * 0.31 - inset)
	_dialogue_text.add_theme_font_size_override("font_size", ceili(22 / physical))
	_speaker.add_theme_font_size_override("font_size", ceili(18 / physical))
	_dialogue_status.add_theme_font_size_override("font_size", ceili(13 / physical))
	_advance_button.custom_minimum_size = Vector2.ONE * maxf(64, touch)
	_advance_button.add_theme_font_size_override("font_size", ceili(24 / physical))
	_item.position = Vector2(inset + w * 0.025, inset + touch + 22)
	for node: Node in _item_copy.find_children("*", "Label", true, false):
		var label: Label = node as Label
		label.add_theme_font_size_override("font_size", ceili((22.0 if bool(label.get_meta("item_heading", false)) else 17.0) / physical))
	_item.size = Vector2(w * 0.40, 0)
	_caption.position = Vector2(w * 0.08, h * 0.30)
	_caption.size = Vector2(w * 0.84, h * 0.30)
	_caption.add_theme_font_size_override("font_size", ceili(clampf(w * physical * 0.044, 28, 54) / physical))
	_caption_advance.custom_minimum_size = Vector2.ONE * touch
	_caption_advance.size = Vector2.ONE * touch
	_caption_advance.position = Vector2((w - touch) * 0.5, h * 0.66)
	_caption_advance.add_theme_font_size_override("font_size", ceili(24 / physical))
	_chapter_label.position = Vector2(w * 0.43, h * 0.03)
	_chapter_label.size = Vector2(w * 0.54, h * 0.11)
	_chapter_label.add_theme_font_size_override("font_size", int(w * 0.041))
	_ending_title.position = Vector2(w * 0.035, h * 0.80)
	_ending_title.size = Vector2(w * 0.70, h * 0.13)
	_ending_title.add_theme_font_size_override("font_size", int(w * 0.043))
	_start_button.position = Vector2(w * 0.76, h - touch - inset)
	_start_button.size = Vector2(w * 0.22, touch)
	_start_button.add_theme_font_size_override("font_size", ceili(18 / physical))
	if _ending:
		_header.position = Vector2(inset, inset)
		_header.size = Vector2(w * 0.32, touch)
		_counter.hide()
	else:
		_counter.show()
	_art.queue_redraw()

func _settings_changed() -> void:
	if not _active:
		return
	if not _ending and str(BEATS[_index]["visual"]) == "caption":
		_show_beat()
		return
	if SettingsService.reduced_motion or SettingsService.text_speed == "instant":
		if _typing != null and _typing.is_valid():
			_typing.kill()
		_finish_line()
	if SettingsService.reduced_motion:
		if _motion != null and _motion.is_valid():
			_motion.kill()
		_item.modulate.a = 1.0
		_art.reveal = 1.0
		if _ending:
			_start_button.disabled = false
			_start_button.modulate.a = 1.0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _focus_lost = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _focus_lost = false
		NOTIFICATION_APPLICATION_PAUSED: _app_paused = true
		NOTIFICATION_APPLICATION_RESUMED: _app_paused = false
		_: return
	if is_node_ready():
		_apply_pause()

func _apply_pause() -> void:
	for tween: Tween in [_typing, _motion]:
		if tween != null and tween.is_valid():
			if _focus_lost or _app_paused or not _active:
				tween.pause()
			else:
				tween.play()

func _stop_tweens() -> void:
	for tween: Tween in [_typing, _motion]:
		if tween != null and tween.is_valid():
			tween.kill()
	_typing = null
	_motion = null

func on_exit() -> void:
	_active = false
	_seq += 1
	_stop_tweens()
	visible = false

func on_resume() -> void:
	_active = true
	visible = true
	if not _ending:
		if str(BEATS[_index]["visual"]) == "caption":
			_show_beat()
		else:
			_finish_line()
	else:
		_art.reveal = 1.0
		_start_button.modulate.a = 1.0
		_start_button.disabled = false
	_apply_pause()

func _exit_tree() -> void:
	_stop_tweens()
