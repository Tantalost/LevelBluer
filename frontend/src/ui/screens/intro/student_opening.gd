extends BaseScreen
## Presentation-only onboarding. No combat, assessment, or mastery APIs.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const DATA_PATH: String = "res://data/student_opening.json"
const STORY_PHONE: GDScript = preload("res://src/gameplay/decision/opening_phone.gd")
const BG: Color = Color("050B18")
const PANEL: Color = Color("0A1730")
const CARD: Color = Color("102040")
const CYAN: Color = Color("4FE0D4")
const TEXT: Color = Color("F3ECD6")

class Eyelids extends Control:
	var aperture: float = 1.0:
		set(value):
			aperture = value
			queue_redraw()
	func _draw() -> void:
		var depth: float = size.y * (1.0 - aperture) * 0.5
		draw_rect(Rect2(0, 0, size.x, depth), Color.BLACK)
		draw_rect(Rect2(0, size.y - depth, size.x, depth), Color.BLACK)

class HiddenFigure extends Control:
	func _draw() -> void:
		var center: Vector2 = size * Vector2(0.5, 0.45)
		var unit: float = minf(size.x, size.y) * 0.32
		draw_circle(center, unit * 1.25, Color("153B37"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-unit, unit * 1.4), center + Vector2(-unit * 0.65, -unit * 0.1), center + Vector2(0, -unit), center + Vector2(unit * 0.65, -unit * 0.1), center + Vector2(unit, unit * 1.4)]), Color("050B18"))
		draw_arc(center - Vector2(0, unit * 0.1), unit * 0.52, PI, TAU, 24, Color("4FE0D4"), 2.0)
		for line: int in range(0, int(size.y), 12):
			draw_line(Vector2(size.x * 0.18, line), Vector2(size.x * 0.82, line), Color(0.31, 0.88, 0.83, 0.08))

var data: Dictionary = {}
var state: Dictionary = {}
var replay: bool = false
var part: String = "intro"
var step: String = "wake"
var intro_index: int = 0
var clues: Array[String] = []
var inspected: Array[String] = []
var history: Array[Dictionary] = []
var feedback: String = ""
var _layout: VBoxContainer
var _header: HBoxContainer
var _body: HBoxContainer
var _footer: HBoxContainer
var _title: Label
var _counter: Label
var _hero: VBoxContainer
var _copy: VBoxContainer
var _dialogue: PanelContainer
var _dialogue_copy: VBoxContainer
var _speaker_label: Label
var _dialogue_status: Label
var _advance_slot: Control
var _advance_button: Button
var _advance_action: Callable = Callable()
var _typing: Tween
var _prompt_tween: Tween
var _typed_labels: Array[Label] = []
var _dialogue_ready: bool = false
var _last_advance_ms: int = -1000
var _scene_art: TextureRect
var _menu: Control
var _menu_card: PanelContainer
var _eyelids: Eyelids
var _focus_effect: ColorRect
var _motion: Tween
var _leaving: bool = false
var _phone_view: Control
var _phone_host: Control
var _cinematic: Control
var _red_wash: ColorRect
var _black_fade: ColorRect
var _closing_caption: Label
var _cinematic_next: Button
var _cinematic_tween: Tween
var _cinematic_active: bool = false
var _cinematic_busy: bool = false
var _laugh_captions: Array[Label] = []
var _art_id: String = ""
var _art_fallback: Label
var _waking: bool = false
var _wake_phase: String = ""


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed as Dictionary
	_build_shell()
	resized.connect(_resize)
	SettingsService.settings_changed.connect(_settings_changed)
	AssetManager.sync_finished.connect(_refresh_art)


func on_enter(args: Dictionary) -> void:
	replay = bool(args.get("replay", false))
	state = PlayerManager.onboarding_state.duplicate(true) if not replay else {}
	_migrate_art_sequence(state)
	part = str(args.get("part", state.get("part", "intro")))
	if part not in ["intro", "tutorial"]:
		part = "intro"
	intro_index = clampi(int(state.get("intro_index", 0)), 0, _intro().size() - 1)
	step = str(state.get("step", "wake"))
	if not (data.get("tutorial", {}) as Dictionary).has(step) and not step.begins_with("clue/"):
		step = "wake"
	if args.has("part"):
		intro_index = 0
		step = "wake"
	for entry: Variant in state.get("clues", []):
		if _clue(str(entry)).size() > 0 and not clues.has(str(entry)):
			clues.append(str(entry))
	for entry: Variant in state.get("inspected", []):
		if _clue(str(entry)).size() > 0 and not inspected.has(str(entry)):
			inspected.append(str(entry))
	for entry: Variant in state.get("history", []):
		if entry is Dictionary:
			history.append((entry as Dictionary).duplicate())
	if args.has("part"):
		history.clear()
	_render()
	_persist()


func _migrate_art_sequence(snapshot: Dictionary) -> void:
	# Version 2 inserts the phone-search shot after wake. Preserve old resume
	# cursors and Back destinations rather than replaying the wrong story beat.
	if snapshot.is_empty() or int(snapshot.get("version", 1)) >= 4:
		return
	var version: int = int(snapshot.get("version", 1))
	var cursors: Array[Dictionary] = [snapshot]
	for previous: Dictionary in snapshot.get("history", []):
		cursors.append(previous)
	for cursor: Dictionary in cursors:
		var index: int = int(cursor.get("intro_index", 0))
		if version < 2 and index > 0:
			index += 1
		# Version 3 inserts the illustrated claim after the email action.
		if version < 3 and index >= 4:
			index += 1
		# Version 4 merges the four separate previews into one five-victim shot.
		if index >= 7 and index <= 10:
			index = 7
		elif index >= 11:
			index = 8
		cursor["intro_index"] = index
	snapshot["version"] = 4


func _text(key: String) -> String:
	return str((data.get("ui", {}) as Dictionary).get(key, key))


func _name(key: String) -> String:
	return str((data.get("cast", {}) as Dictionary).get(key, key))


func _intro() -> Array:
	return data.get("intro", []) as Array


func _clue(id: String) -> Dictionary:
	for entry: Dictionary in data.get("clues", []):
		if str(entry.get("id")) == id:
			return entry
	return {}


func _build_shell() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Artwork is a full-screen layer, independent of every UI container.
	_scene_art = TextureRect.new()
	_scene_art.name = "StoryArtwork"
	_scene_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_art)
	_scene_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_fallback = UI.label("", 26, TEXT)
	_art_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_art_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_fallback)
	_art_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_fallback.offset_left = 90
	_art_fallback.offset_right = -90
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra_margin = 18
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout = UI.column(safe, 14)
	_header = HBoxContainer.new()
	_header.z_index = 1 # Remains visible over the ending's fade-to-black layer.
	_header.add_theme_constant_override("separation", 12)
	_layout.add_child(_header)
	_add_button(_header, "back", _back)
	_title = UI.label("", 24, CYAN)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_title)
	_counter = UI.label("", 22, TEXT)
	_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_counter)
	_add_button(_header, "skip", skip)
	_add_button(_header, "menu", _open_menu)
	# Only this non-container host owns the moving workspace. Never tween a
	# Container-managed child's position; navigation stays outside the effect.
	var workspace: Control = Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.custom_minimum_size.y = 120
	workspace.clip_contents = true
	_layout.add_child(workspace)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	workspace.add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.resized.connect(_resize)
	_dialogue = UI.panel(_layout)
	_dialogue.name = "BottomDialogue"
	var dialogue_style: StyleBoxFlat = UI.box(Color("050B18BD"), Color.TRANSPARENT, 0)
	dialogue_style.set_border_width_all(0)
	dialogue_style.corner_radius_top_right = 58
	dialogue_style.corner_radius_bottom_right = 58
	dialogue_style.corner_detail = 12
	_dialogue.add_theme_stylebox_override("panel", dialogue_style)
	_dialogue.focus_mode = Control.FOCUS_ALL
	_dialogue.gui_input.connect(_dialogue_input)
	var dialogue_layout: VBoxContainer = UI.column(_dialogue, 0)
	var speaker_strip: PanelContainer = UI.panel(dialogue_layout)
	var strip_style: StyleBoxFlat = UI.box(Color("4FE0D4E8"), Color.TRANSPARENT, 8)
	strip_style.set_border_width_all(0)
	strip_style.content_margin_left = 22
	strip_style.content_margin_right = 30
	strip_style.corner_radius_top_right = 42
	strip_style.corner_detail = 12
	speaker_strip.add_theme_stylebox_override("panel", strip_style)
	var speaker_row: HBoxContainer = HBoxContainer.new()
	speaker_row.add_theme_constant_override("separation", 16)
	speaker_strip.add_child(speaker_row)
	_speaker_label = UI.label("", 24, BG)
	_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_row.add_child(_speaker_label)
	_dialogue_status = UI.label("", 18, BG)
	_dialogue_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	speaker_row.add_child(_dialogue_status)
	var dialogue_margin: MarginContainer = MarginContainer.new()
	dialogue_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge: String in ["top", "bottom", "left", "right"]:
		dialogue_margin.add_theme_constant_override("margin_" + edge, 20)
	dialogue_layout.add_child(dialogue_margin)
	var dialogue_row: HBoxContainer = HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 20)
	dialogue_margin.add_child(dialogue_row)
	_dialogue_copy = UI.scroll_column(dialogue_row)
	_dialogue_copy.add_theme_constant_override("separation", 8)
	(_dialogue_copy.get_parent() as ScrollContainer).gui_input.connect(_dialogue_input)
	_advance_slot = Control.new()
	_advance_slot.custom_minimum_size.x = 80
	_advance_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_row.add_child(_advance_slot)
	_advance_button = UI.button(">", _advance_pressed)
	_advance_button.name = "DialogueAdvanceButton"
	_advance_button.tooltip_text = _text("next")
	_advance_button.custom_minimum_size = Vector2(64, 64)
	_advance_button.add_theme_font_size_override("font_size", 32)
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var circle: StyleBoxFlat = UI.box(Color("0E2A28E0"), CYAN, 0)
		circle.set_corner_radius_all(128)
		circle.corner_detail = 16
		circle.set_border_width_all(2 if style_name == "normal" else 3)
		circle.shadow_color = Color(0.31, 0.88, 0.83, 0.28)
		circle.shadow_size = 12 if style_name == "normal" else 18
		_advance_button.add_theme_stylebox_override(style_name, circle)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_advance_button.add_theme_color_override(color_name, CYAN)
	_advance_slot.add_child(_advance_button)
	_advance_slot.resized.connect(_position_advance)
	_build_cinematic_layer()
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 12)
	_layout.add_child(_footer)
	_menu = Control.new()
	_menu.name = "OpeningMenu"
	_menu.z_index = 2
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.96)
	_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	_menu.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["top", "bottom", "left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	_menu_card = UI.panel(margin)
	_menu_card.add_theme_stylebox_override("panel", UI.box(PANEL, CYAN, 20))
	var menu_content: VBoxContainer = UI.scroll_column(_menu_card)
	menu_content.add_child(UI.label(_text("pause_title"), 32, CYAN))
	menu_content.add_child(UI.label(_text("pause_text"), 24, TEXT))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	menu_content.add_child(grid)
	_add_button(grid, "resume", _close_menu, true)
	_add_button(grid, "skip_opening", _skip_opening)
	_add_button(grid, "replay_intro", _replay_intro)
	_add_button(grid, "exit", Router.request_exit_game)
	var reduce: CheckButton = CheckButton.new()
	reduce.text = _text("reduce_motion")
	reduce.add_theme_font_override("font", UI.FONT)
	reduce.add_theme_font_size_override("font_size", 24)
	reduce.button_pressed = SettingsService.reduced_motion
	reduce.toggled.connect(func(enabled: bool) -> void:
		SettingsService.reduced_motion = enabled
		SettingsService.save_settings()
		_settings_changed()
	)
	menu_content.add_child(reduce)
	_menu.hide()


func _add_button(parent: Node, key: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = UI.button(_text(key), callback, primary)
	button.name = key.to_pascal_case() + "Button"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent == _header:
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	return button


func _panel_column(weight: float) -> VBoxContainer:
	var panel: PanelContainer = UI.panel(_body)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = weight
	panel.add_theme_stylebox_override("panel", UI.box(Color.TRANSPARENT if part == "intro" else PANEL, Color.TRANSPARENT if part == "intro" else Color("173058"), 20))
	return UI.scroll_column(panel)


func _render() -> void:
	_stop_cinematic()
	_stop_motion()
	_stop_dialogue()
	if is_instance_valid(_phone_view):
		_phone_view.stop()
	if is_instance_valid(_phone_host):
		remove_child(_phone_host)
		_phone_host.queue_free()
	_phone_host = null
	_phone_view = null
	_advance_action = Callable()
	UI.clear(_body)
	UI.clear(_footer)
	UI.clear(_dialogue_copy)
	(_dialogue_copy.get_parent() as ScrollContainer).scroll_vertical = 0
	_scene_art.hide()
	_art_id = ""
	_art_fallback.hide()
	_scene_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_dialogue.show()
	if part == "intro":
		_set_art(str(data["room_art"]))
		_scene_art.show()
	_hero = _panel_column(0.9)
	_copy = _panel_column(1.1)
	_title.text = _text(part)
	if replay:
		_title.text += " / " + _text("replay_short")
	_title.tooltip_text = _text("replay_note") if replay else ""
	_counter.text = _text("progress").format({"count": intro_index + 1, "total": _intro().size()}) if part == "intro" else _text("practice")
	AudioManager.set_opening_morning(self, part == "tutorial" or intro_index <= 4)
	if part == "intro":
		_render_intro()
	else:
		_render_tutorial()
	# Empty interaction columns must not reserve half of a narrative scene.
	(_copy.get_parent().get_parent() as Control).visible = _copy.get_child_count() > 0
	_footer.visible = _footer.get_child_count() > 0
	_begin_dialogue()
	_resize()
	_resize.call_deferred()


func _narrate(title: String, body: String, speaker: String = "") -> void:
	var caption: String = title if speaker.is_empty() else speaker + "  /  " + title
	_speaker_label.text = caption
	_dialogue_copy.add_child(UI.label(body, 28, TEXT))


func _show_room(path: String) -> void:
	_set_art(path)
	_scene_art.show()
	(_hero.get_parent().get_parent() as Control).hide()
	if not SettingsService.reduced_motion:
		_motion = create_tween()
		_motion.tween_property(_scene_art, "modulate:a", 1.0, 0.35).from(0.0)


func _set_art(asset_id: String) -> void:
	_art_id = asset_id
	_refresh_art(true)


func _refresh_art(_success: bool) -> void:
	# One receiver-owned connection. Late sync refreshes only the CURRENT beat.
	if _leaving or _art_id.is_empty():
		return
	_scene_art.texture = AssetManager.get_texture(_art_id)
	var descriptions: Dictionary[String, String] = {
		"opening_john_room_wake_v1": "Morning light fills John's room.",
		"opening_john_reaching_phone_v1": "John reaches across the bed for his buzzing phone.",
		"opening_john_claim_prize_v1": "John taps Claim Prize before checking the offer.",
		"opening_john_got_you_v1": "The phone turns red. Got You.",
		"opening_collector_meeting_v1": "Masked scammers laugh around a table in a dark room.",
		"opening_five_victims_v1": "Five people. Five traps. Shock, confusion, tears, anger and sadness."
	}
	_art_fallback.text = descriptions.get(_art_id, "Opening scene") + "\n\nScene art unavailable. Connect and reload to download it."
	_art_fallback.visible = _scene_art.texture == null


func _begin_dialogue() -> void:
	_dialogue_ready = false
	_advance_slot.visible = _advance_action.is_valid()
	_advance_button.hide()
	_advance_button.disabled = true
	_dialogue_status.text = _text("reading")
	_dialogue.tooltip_text = _text("reveal_text")
	for child: Node in _dialogue_copy.get_children():
		if child is Label:
			_typed_labels.append(child as Label)
	# Practice instructions remain immediate so evidence/response controls are
	# never time-gated. Narrative-only beats use the reveal animation.
	if _cinematic_active or SettingsService.reduced_motion or not _advance_action.is_valid():
		_finish_reveal()
		return
	_typing = create_tween()
	for label: Label in _typed_labels:
		label.visible_characters = 0
		_typing.tween_property(label, "visible_characters", label.text.length(), maxf(0.2, float(label.text.length()) / 45.0))
	_typing.finished.connect(_finish_reveal)
	if _waking:
		_typing.pause()


func _finish_reveal() -> void:
	if _leaving:
		return
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = null
	for label: Label in _typed_labels:
		if is_instance_valid(label):
			label.visible_characters = -1
	_dialogue_ready = true
	_dialogue.tooltip_text = ""
	_dialogue_status.text = _text("ready") if _advance_action.is_valid() else _text("practice")
	if is_instance_valid(_phone_view):
		_dialogue_status.text = ""
	_update_advance_prompt()


func _update_advance_prompt() -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = null
	var prompt: Button = _cinematic_next if _cinematic_active else _advance_button
	_advance_button.modulate = Color.WHITE
	_cinematic_next.modulate = Color.WHITE
	_advance_button.visible = not _cinematic_active and not _waking and _dialogue_ready and _advance_action.is_valid()
	_advance_button.disabled = not _advance_button.visible or _menu.visible
	_cinematic_next.visible = _cinematic_active and not _cinematic_busy and _advance_action.is_valid()
	_cinematic_next.disabled = not _cinematic_next.visible or _menu.visible
	if prompt.visible and not _menu.visible and not SettingsService.reduced_motion:
		_prompt_tween = create_tween().set_loops()
		_prompt_tween.tween_property(prompt, "modulate:a", 0.60, 0.9).set_trans(Tween.TRANS_SINE)
		_prompt_tween.tween_property(prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _dialogue_input(event: InputEvent) -> void:
	if _menu.visible or _leaving or _dialogue_ready:
		return
	var pointer: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed()) or (event is InputEventScreenTouch and event.is_pressed())
	if pointer or (event.is_action_pressed("ui_accept") and not event.is_echo()):
		_finish_reveal()
		get_viewport().set_input_as_handled()


func _advance_pressed() -> void:
	if _leaving or _menu.visible or _waking or not _dialogue_ready or not _advance_action.is_valid():
		return
	# Absorb touch/mouse duplication and rapid double taps, including reduced
	# motion where the following line is already fully visible.
	var now: int = Time.get_ticks_msec()
	if now - _last_advance_ms < 250:
		return
	_last_advance_ms = now
	_advance_action.call()


func _stop_dialogue() -> void:
	if _typing != null and _typing.is_valid():
		_typing.kill()
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_typing = null
	_prompt_tween = null
	_typed_labels.clear()


func _position_advance() -> void:
	if not is_instance_valid(_advance_button):
		return
	var diameter: float = maxf(64.0, _advance_button.custom_minimum_size.y)
	_advance_slot.custom_minimum_size.x = diameter + 16.0
	_advance_button.size = Vector2.ONE * diameter
	_advance_button.position = Vector2((_advance_slot.size.x - diameter) * 0.5, maxf(0.0, (_advance_slot.size.y - diameter) * 0.5))


func _render_intro() -> void:
	var beat: Dictionary = _intro()[intro_index] as Dictionary
	var visual: String = str(beat.get("visual", "phone"))
	if visual in ["takeover", "meeting", "montage", "closing"]:
		_advance_action = advance
		_start_cinematic(beat)
	else:
		_narrate(str(beat["title"]), str(beat["text"]), _name(str(beat["speaker"])) if beat.has("speaker") else "")
		if beat.has("art_path"):
			_show_room(str(beat["art_path"]))
		elif visual in ["collector", "hit"]:
			_collector()
		else:
			_intro_phone(bool(beat.get("opened", false)))
		if beat.has("note"):
			_dialogue_copy.add_child(UI.label(str(beat["note"]), 22, CYAN))
		if visual == "blink":
			_blink(true)
		elif str(beat["id"]) == "search":
			AudioManager.play_opening_cue("shuffle", self)
		elif visual == "hit":
			_hit()
		elif str(beat["id"]) == "prize":
			AudioManager.play_sfx("ui_notification")
			_vibrate(70)
			if not SettingsService.reduced_motion:
				_motion = create_tween()
				_motion.tween_property(_body, "position:y", -3.0, 0.2)
				_motion.tween_property(_body, "position:y", 0.0, 0.2)
	if not is_instance_valid(_phone_view):
		_advance_action = advance


func _intro_phone(opened: bool) -> void:
	(_hero.get_parent().get_parent() as Control).hide()
	var host: Control = Control.new()
	host.name = "OpeningPhoneHost"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	add_child(host)
	move_child(host, _menu.get_index())
	_phone_host = host
	_phone_view = STORY_PHONE.new() as Control
	host.add_child(_phone_view)
	var message: Dictionary = data["message"] as Dictionary
	_phone_view.configure({"embedded": true, "claim_enabled": opened, "device_name": _name("player") + "'s phone"})
	_phone_view.receive_message({"sender": str(message["sender_name"]) + " <" + str(message["sender_address"]) + ">", "subject": str(message["subject"]), "body": str(message["body"])})
	_phone_view.message_read.connect(_phone_action.bind(_phone_view, "prize"), CONNECT_DEFERRED)
	_phone_view.claim_pressed.connect(_phone_action.bind(_phone_view, "tap"), CONNECT_DEFERRED)
	_phone_view.open_phone()
	if opened:
		_phone_view.show_open_message()


func _build_cinematic_layer() -> void:
	# Above the empty workspace for pointer routing; header draws above effects.
	_cinematic = Control.new()
	_cinematic.name = "OpeningCinematic"
	_cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cinematic)
	_cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_red_wash = ColorRect.new()
	_red_wash.color = Color("A51628")
	_red_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic.add_child(_red_wash)
	_red_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black_fade = ColorRect.new()
	_black_fade.color = Color.BLACK
	_black_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic.add_child(_black_fade)
	_black_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_closing_caption = UI.label("", 46, TEXT)
	_closing_caption.name = "ClosingCaption"
	_closing_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_closing_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_closing_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closing_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	_closing_caption.add_theme_constant_override("shadow_offset_x", 3)
	_closing_caption.add_theme_constant_override("shadow_offset_y", 3)
	_cinematic.add_child(_closing_caption)
	_closing_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_closing_caption.offset_left = 70
	_closing_caption.offset_right = -70
	for index: int in 5:
		var laugh: Label = UI.label("HAHAHAHA", 32 + (index % 3) * 7, TEXT)
		laugh.name = "LaughingCaption%d" % index
		laugh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		laugh.add_theme_color_override("font_shadow_color", Color.BLACK)
		laugh.add_theme_constant_override("shadow_offset_x", 3)
		laugh.add_theme_constant_override("shadow_offset_y", 3)
		laugh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cinematic.add_child(laugh)
		_laugh_captions.append(laugh)
		laugh.hide()
	_cinematic_next = UI.button(">", _advance_pressed)
	_cinematic_next.name = "CinematicAdvanceButton"
	_cinematic_next.tooltip_text = _text("next")
	_cinematic_next.custom_minimum_size = Vector2(64, 64)
	_cinematic_next.add_theme_font_size_override("font_size", 32)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		_cinematic_next.add_theme_stylebox_override(key, _advance_button.get_theme_stylebox(key))
	_cinematic_next.add_theme_color_override("font_color", CYAN)
	_cinematic.add_child(_cinematic_next)
	_cinematic.hide()


func _start_cinematic(beat: Dictionary) -> void:
	_cinematic_active = true
	_cinematic_busy = true
	_cinematic.show()
	_dialogue.hide()
	_show_room(str(beat["art_path"]))
	_stop_motion() # Cinematic tween owns the art; no competing room fade.
	var visual: String = str(beat["visual"])
	_closing_caption.text = str(beat.get("caption", ""))
	if visual == "meeting":
		_position_laugh_captions()
		for laugh: Label in _laugh_captions:
			laugh.show()
			laugh.modulate.a = 0.0
	if visual in ["montage", "closing"]:
		# Keep all five faces, even on extra-wide phones. Never crop a victim out.
		_scene_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if SettingsService.reduced_motion:
		_finish_cinematic_visual()
		if visual == "takeover":
			AudioManager.play_opening_laugh(self)
		return
	_cinematic_tween = create_tween()
	match visual:
		"takeover":
			_scene_art.pivot_offset = size * 0.5
			_scene_art.scale = Vector2.ONE * 1.025
			_cinematic_tween.tween_property(_red_wash, "modulate:a", 0.65, 0.3)
			for offset: Vector2 in [Vector2(5, 2), Vector2(-5, -2), Vector2(3, 1), Vector2(-2, -1), Vector2.ZERO]:
				_cinematic_tween.tween_property(_scene_art, "position", offset, 0.075)
			_cinematic_tween.tween_interval(0.25)
			_cinematic_tween.tween_callback(_reveal_red_phone)
			_cinematic_tween.tween_property(_red_wash, "modulate:a", 0.0, 0.4)
			_cinematic_tween.tween_interval(1.7)
		"meeting":
			_black_fade.modulate.a = 1.0
			_cinematic_tween.tween_property(_black_fade, "modulate:a", 0.0, 0.65)
			# Staggered appearances, not a flashing/strobing loop.
			for laugh: Label in _laugh_captions:
				_cinematic_tween.tween_property(laugh, "modulate:a", 1.0, 0.24)
				_cinematic_tween.parallel().tween_property(laugh, "scale", Vector2.ONE, 0.24).from(Vector2.ONE * 0.88)
			_cinematic_tween.tween_interval(0.5)
		"montage":
			_black_fade.modulate.a = 1.0
			_cinematic_tween.tween_property(_black_fade, "modulate:a", 0.0, 0.65)
			_cinematic_tween.tween_interval(1.0)
		"closing":
			_cinematic_tween.tween_property(_black_fade, "modulate:a", 0.45, 0.6)
			_cinematic_tween.parallel().tween_property(_closing_caption, "modulate:a", 1.0, 0.8)
			_cinematic_tween.tween_interval(2.0)
			_cinematic_tween.tween_property(_black_fade, "modulate:a", 1.0, 1.2)
			_cinematic_tween.parallel().tween_property(_closing_caption, "modulate:a", 0.0, 1.2)
	_cinematic_tween.tween_callback(_finish_cinematic_visual)


func _reveal_red_phone() -> void:
	if _leaving or not _cinematic_active:
		return
	_scene_art.position = Vector2.ZERO
	_scene_art.scale = Vector2.ONE
	var beat: Dictionary = _intro()[intro_index] as Dictionary
	_set_art(str(beat["reveal_art"]))
	AudioManager.play_opening_laugh(self)


func _finish_cinematic_visual() -> void:
	if _leaving or not _cinematic_active:
		return
	var beat: Dictionary = _intro()[intro_index] as Dictionary
	_scene_art.position = Vector2.ZERO
	_scene_art.scale = Vector2.ONE
	_red_wash.modulate.a = 0.0
	_black_fade.modulate.a = 0.0
	if str(beat["visual"]) == "takeover":
		_set_art(str(beat["reveal_art"]))
	elif str(beat["visual"]) == "meeting":
		for laugh: Label in _laugh_captions:
			laugh.modulate.a = 1.0
			laugh.scale = Vector2.ONE
	elif str(beat["visual"]) == "closing":
		_black_fade.modulate.a = 1.0
		# Reduced motion preserves the caption as a static card on black.
		_closing_caption.modulate.a = 1.0 if SettingsService.reduced_motion else 0.0
	_cinematic_busy = false
	_update_advance_prompt()


func _stop_cinematic() -> void:
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.kill()
	_cinematic_tween = null
	_cinematic_active = false
	_cinematic_busy = false
	AudioManager.stop_dialogue_blips(self)
	if is_instance_valid(_cinematic):
		_cinematic.hide()
		_red_wash.modulate.a = 0.0
		_black_fade.modulate.a = 0.0
		_closing_caption.modulate.a = 0.0
		_cinematic_next.hide()
		for laugh: Label in _laugh_captions:
			laugh.hide()
	if is_instance_valid(_scene_art):
		_scene_art.position = Vector2.ZERO
		_scene_art.scale = Vector2.ONE


func _phone_action(source: Control, beat_id: String) -> void:
	# Deferred signals cannot advance a replacement scene after Back/Skip/Menu.
	if _leaving or _menu.visible or source != _phone_view or part != "intro":
		return
	if str((_intro()[intro_index] as Dictionary)["id"]) == beat_id:
		advance()


func _phone(opened: bool, interactive: bool) -> void:
	var message: Dictionary = data["message"] as Dictionary
	var center: CenterContainer = CenterContainer.new()
	_hero.add_child(center)
	var phone: PanelContainer = UI.panel(center)
	phone.name = "PracticePhone"
	phone.custom_minimum_size.x = 400
	var frame: StyleBoxFlat = UI.box(BG, Color("173058"), 18)
	frame.set_corner_radius_all(28)
	frame.corner_detail = 6
	frame.set_border_width_all(3)
	phone.add_theme_stylebox_override("panel", frame)
	var device: VBoxContainer = UI.column(phone, 16)
	var speaker: Label = UI.label(_text("phone_status"), 20, CYAN)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	device.add_child(speaker)
	var notification: PanelContainer = UI.panel(device)
	var notification_style: StyleBoxFlat = UI.box(CARD, CYAN, 16)
	notification_style.set_corner_radius_all(12)
	notification.add_theme_stylebox_override("panel", notification_style)
	var inside: VBoxContainer = UI.column(notification, 14)
	inside.add_child(UI.label(str(message["text_label"] if str(message["channel"]) == "text" else message["email_label"]), 22, CYAN))
	inside.add_child(UI.label(str(message["subject"]), 32, TEXT))
	inside.add_child(UI.label(str(message["sender_name"]), 24, TEXT))
	if opened:
		inside.add_child(UI.label(str(message["body"]), 26, TEXT))
	elif interactive:
		_add_button(inside, "open", func() -> void: go("message"), true)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	device.add_child(spacer)
	var home: Label = UI.label("—", 24, CYAN)
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	device.add_child(home)
	_hero.add_child(UI.label(str(message["safety_label"]), 20, CYAN))


func _render_tutorial() -> void:
	if step.begins_with("clue/"):
		var clue: Dictionary = _clue(step.trim_prefix("clue/"))
		if clue.is_empty():
			step = "inspect"
			_render_tutorial()
			return
		_phone(true, false)
		_narrate(str(clue["title"]), str(clue["value"]) + "\n\n" + str(clue["note"]))
		var id: String = str(clue["id"])
		var save: Button = _add_button(_footer, "saved" if clues.has(id) else "save", func() -> void: save_clue(id), true)
		save.disabled = clues.has(id)
		_add_button(_footer, "inspect", func() -> void: go("inspect"))
		return
	var copy: Dictionary = (data["tutorial"] as Dictionary)[step] as Dictionary
	_narrate(str(copy["title"]), str(copy["text"]), _name("player"))
	match step:
		"wake":
			_show_room(str(data["room_art"]))
			_blink()
			_advance_action = func() -> void: go("inbox")
		"inbox":
			_phone(false, true)
			AudioManager.play_sfx("ui_notification")
			_vibrate(70)
		"message":
			_phone(true, false)
			_add_button(_footer, "inspect", func() -> void: go("inspect"), true)
			_add_button(_footer, "respond", func() -> void: go("respond"))
		"inspect":
			_phone(true, false)
			for clue: Dictionary in data["clues"]:
				var id: String = str(clue["id"])
				var button: Button = UI.button(str(clue["title"]), func() -> void: inspect_clue(id))
				button.name = "Inspect_" + id
				_copy.add_child(button)
			_add_button(_footer, "binder", func() -> void: go("binder"), true)
			_add_button(_footer, "respond", func() -> void: go("respond"))
		"binder":
			_phone(false, false)
			if clues.is_empty():
				_copy.add_child(UI.label(_text("empty"), 24, CYAN))
			for id: String in clues:
				var clue: Dictionary = _clue(id)
				_copy.add_child(UI.label(str(clue["title"]) + "\n" + str(clue["value"]), 24, CYAN))
			_add_button(_footer, "inspect", func() -> void: go("inspect"))
			_add_button(_footer, "respond", func() -> void: go("respond"), true)
		"respond":
			_phone(true, false)
			for response: Dictionary in data["responses"]:
				var id: String = str(response["id"])
				var button: Button = UI.button(str(response["label"]), func() -> void: respond(id))
				button.name = "Response_" + id
				_copy.add_child(button)
			_add_button(_footer, "inspect", func() -> void: go("inspect"))
		"failure":
			_collector()
			_hit()
			_add_button(_footer, "retry", retry, true)
		"review":
			_phone(false, false)
			_add_button(_footer, "inspect", func() -> void: go("inspect"), true)
		"success":
			_phone(false, false)
			_dialogue_copy.add_child(UI.label(feedback, 24, CYAN))
			AudioManager.play_sfx("ui_success")
			_add_button(_footer, "finish", finish, true)
		"summary":
			_show_room(str(data["room_art"]))
			_add_button(_footer, "hub", _hub, true)
	if step in ["inspect", "binder", "respond"]:
		_copy.add_child(UI.label(_text("clue_count").format({"count": clues.size()}), 22, CYAN))


func _record_history() -> void:
	history.append({"part": part, "step": step, "intro_index": intro_index})
	# Bounded local navigation trail, not assessment-attempt history.
	if history.size() > 64:
		history.pop_front()


func go(target: String) -> void:
	if _leaving or _menu.visible:
		return
	_record_history()
	step = target
	_render()
	_persist()


func advance() -> void:
	if _leaving or _menu.visible or part != "intro" or _cinematic_busy or _waking:
		return
	if is_instance_valid(_phone_view):
		var id: String = str((_intro()[intro_index] as Dictionary)["id"])
		if (id == "prize" and not bool(_phone_view.get("_read"))) or (id == "tap" and not bool(_phone_view.get("_claim_sent"))):
			return
	_record_history()
	if intro_index + 1 < _intro().size():
		intro_index += 1
	else:
		state["intro_status"] = "completed"
		part = "tutorial"
		step = "wake" if str(data.get("after_intro", "tutorial")) == "tutorial" else "summary"
	_render()
	_persist()


func inspect_clue(id: String) -> void:
	if _leaving or _menu.visible or part != "tutorial" or step != "inspect" or _clue(id).is_empty():
		return
	if not inspected.has(id):
		inspected.append(id)
	go("clue/" + id)


func save_clue(id: String) -> void:
	if _leaving or _menu.visible or step != "clue/" + id or not inspected.has(id) or clues.has(id):
		return
	clues.append(id)
	AudioManager.play_sfx("ui_confirm")
	_render()
	_persist()


func respond(id: String) -> void:
	if _leaving or _menu.visible or step != "respond":
		return
	for response: Dictionary in data["responses"]:
		if str(response["id"]) != id:
			continue
		feedback = str(response["feedback"])
		go("failure" if not bool(response["safe"]) else ("success" if clues.size() >= 3 else "review"))
		return


func retry() -> void:
	go("message")


func skip() -> void:
	if _leaving or _menu.visible:
		return
	_record_history()
	if part == "intro":
		state["intro_status"] = "skipped"
		part = "tutorial"
		step = "wake"
	else:
		state["pending_outcome"] = "skipped"
		step = "summary"
	_render()
	_persist()


func finish() -> void:
	if step != "success" or _leaving:
		return
	state["pending_outcome"] = "completed"
	go("summary")


func _hub() -> void:
	if _leaving:
		return
	_leaving = true
	var outcome: String = str(state.get("pending_outcome", "skipped"))
	state["tutorial_status"] = outcome
	if not state.has("intro_status"):
		state["intro_status"] = "skipped"
	state.erase("pending_outcome")
	if not replay:
		PlayerManager.save_onboarding(state, outcome)
	Router.replace_all(&"dashboard")


func _persist() -> void:
	state["version"] = int(data.get("version", 1))
	state["part"] = part
	state["step"] = step
	state["intro_index"] = intro_index
	state["clues"] = clues.duplicate()
	state["inspected"] = inspected.duplicate()
	state["history"] = history.duplicate(true)
	state["tutorial_status"] = "in_progress" if part == "tutorial" else str(state.get("tutorial_status", "not_started"))
	if part == "intro":
		state["intro_status"] = "in_progress"
	if not replay and not _leaving:
		PlayerManager.save_onboarding(state)


func _back() -> void:
	if _leaving:
		return
	if _menu.visible:
		_close_menu()
		return
	if history.is_empty():
		_open_menu()
		return
	var previous: Dictionary = history.pop_back()
	part = str(previous.get("part", "intro"))
	step = str(previous.get("step", "wake"))
	intro_index = clampi(int(previous.get("intro_index", 0)), 0, _intro().size() - 1)
	state.erase("pending_outcome")
	_render()
	_persist()


func consume_back() -> bool:
	_back()
	return true


func _open_menu() -> void:
	if _menu.visible or _leaving:
		return
	if _waking and _motion != null and _motion.is_valid():
		_motion.pause()
	else:
		_stop_motion()
	AudioManager.pause_opening_audio(self, true)
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.pause()
	AudioManager.stop_dialogue_blips(self)
	if is_instance_valid(_phone_view):
		_phone_view.set_locked(true)
	if _typing != null and _typing.is_valid():
		_typing.pause()
	# Also block keyboard activation behind the modal, not only pointer input.
	for node: Node in _layout.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		button.set_meta("opening_disabled", button.disabled)
		button.disabled = true
	_menu.show()
	_update_advance_prompt()
	(_menu.find_child("ResumeButton", true, false) as Button).grab_focus()


func _close_menu() -> void:
	_menu.hide()
	AudioManager.pause_opening_audio(self, false)
	for node: Node in _layout.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if button.has_meta("opening_disabled"):
			button.disabled = bool(button.get_meta("opening_disabled"))
			button.remove_meta("opening_disabled")
	(_header.find_child("MenuButton", true, false) as Button).grab_focus()
	if _typing != null and _typing.is_valid() and (not _waking or _wake_phase == "opening"):
		_typing.play()
	if _waking and _motion != null and _motion.is_valid():
		_motion.play()
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.play()
	if is_instance_valid(_phone_view):
		_phone_view.set_locked(false)
		_phone_action.call_deferred(_phone_view, str((_intro()[intro_index] as Dictionary)["id"]))
	_update_advance_prompt()


func _skip_opening() -> void:
	_close_menu()
	_record_history()
	if part == "intro":
		state["intro_status"] = "skipped"
	part = "tutorial"
	step = "summary"
	state["pending_outcome"] = "skipped"
	_render()
	_persist()


func _replay_intro() -> void:
	_close_menu()
	_record_history()
	part = "intro"
	intro_index = 0
	_render()
	_persist()


func _resize() -> void:
	if _layout == null:
		return
	UI.fit_touch(self)
	if is_instance_valid(_phone_view):
		_phone_view._metrics.call_deferred()
		_phone_host.position = Vector2(size.x * 0.54, _header.get_global_rect().end.y + 12)
		_phone_host.size = Vector2(size.x * 0.46 - 18, size.y - _phone_host.position.y - 12)
		_dialogue.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_dialogue.custom_minimum_size.x = size.x * 0.50
	else:
		_dialogue.size_flags_horizontal = Control.SIZE_FILL
		_dialogue.custom_minimum_size.x = 0
	_dialogue.custom_minimum_size.y = clampf(size.y * 0.30, 180.0, 240.0)
	_position_advance()
	_position_laugh_captions()
	if is_instance_valid(_cinematic_next):
		var diameter: float = maxf(64.0, _cinematic_next.custom_minimum_size.y)
		_cinematic_next.size = Vector2.ONE * diameter
		_cinematic_next.position = size - Vector2.ONE * (diameter + 26.0)
	# Navigation and dialogue remain above the full-screen eyelid layer.
	if is_instance_valid(_eyelids):
		_eyelids.position = global_position
		_eyelids.size = size
	if is_instance_valid(_focus_effect):
		_focus_effect.position = global_position
		_focus_effect.size = size


func _position_laugh_captions() -> void:
	var positions: Array[Vector2] = [Vector2(0.5, 0.48), Vector2(0.22, 0.25), Vector2(0.72, 0.23), Vector2(0.29, 0.72), Vector2(0.76, 0.66)]
	for index: int in _laugh_captions.size():
		var laugh: Label = _laugh_captions[index]
		laugh.size = Vector2(size.x * 0.26, 70)
		laugh.position = size * positions[index] - laugh.size * 0.5
		laugh.pivot_offset = laugh.size * 0.5


func _collector() -> void:
	_hero.add_child(UI.label(_name("collector"), 28, CYAN))
	var figure: HiddenFigure = HiddenFigure.new()
	figure.custom_minimum_size.y = 220
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(figure)


func _blink(morning: bool = false) -> void:
	# The eyelid reveal owns the room's transition; don't leave a competing fade.
	_stop_motion()
	if SettingsService.reduced_motion and not morning:
		return
	if morning:
		_waking = true
		_wake_phase = "alarm"
		_dialogue.hide()
	if SettingsService.reduced_motion:
		_motion = create_tween()
		_motion.tween_callback(_morning_alarm)
		_motion.tween_interval(0.82)
		_motion.tween_callback(_morning_open)
		_motion.tween_callback(_morning_ready)
		return
	_focus_effect = ColorRect.new()
	_focus_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_linear; uniform float blur = 2.0; void fragment() { vec2 d = SCREEN_PIXEL_SIZE * blur; vec3 c = texture(screen_image, SCREEN_UV + vec2(d.x, d.y)).rgb; c += texture(screen_image, SCREEN_UV + vec2(-d.x, d.y)).rgb; c += texture(screen_image, SCREEN_UV + vec2(d.x, -d.y)).rgb; c += texture(screen_image, SCREEN_UV - d).rgb; COLOR = vec4(c * 0.25, 1.0); }"
	var focus_material: ShaderMaterial = ShaderMaterial.new()
	focus_material.shader = shader
	focus_material.set_shader_parameter("blur", 2.0)
	_focus_effect.material = focus_material
	add_child(_focus_effect)
	move_child(_focus_effect, _scene_art.get_index() + 1)
	_focus_effect.set_as_top_level(true)
	_focus_effect.position = global_position
	_focus_effect.size = size
	_eyelids = Eyelids.new()
	_eyelids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eyelids)
	move_child(_eyelids, _focus_effect.get_index() + 1)
	_eyelids.set_as_top_level(true)
	_eyelids.position = global_position
	_eyelids.size = size
	_eyelids.aperture = 0.0
	_motion = create_tween()
	if morning:
		_motion.tween_callback(_morning_alarm)
		_motion.tween_interval(0.82)
		_motion.tween_callback(_morning_open)
	_motion.tween_property(_eyelids, "aperture", 0.85, 0.55).set_trans(Tween.TRANS_SINE)
	_motion.tween_property(_eyelids, "aperture", 0.15, 0.25)
	_motion.tween_property(_eyelids, "aperture", 1.0, 0.7)
	_motion.parallel().tween_method(func(value: float) -> void: focus_material.set_shader_parameter("blur", value), 2.0, 0.0, 0.7)
	_motion.tween_callback(func() -> void:
		if is_instance_valid(_focus_effect):
			_focus_effect.hide()
	)
	if morning:
		_motion.tween_callback(_morning_ready)


func _morning_alarm() -> void:
	if not _leaving and _waking and not _menu.visible:
		AudioManager.play_opening_cue("alarm", self)


func _morning_open() -> void:
	if _leaving or not _waking or _menu.visible:
		return
	_wake_phase = "opening"
	AudioManager.play_opening_cue("thump", self)
	_dialogue.show()
	if _typing != null and _typing.is_valid():
		_typing.play()


func _morning_ready() -> void:
	_waking = false
	_wake_phase = "ready"
	_dialogue.show()
	_update_advance_prompt()


func _fade_hero() -> void:
	if SettingsService.reduced_motion:
		return
	_motion = create_tween()
	_motion.tween_property(_hero, "modulate:a", 1.0, 0.3).from(0.0)


func _hit() -> void:
	AudioManager.play_sfx("ui_error")
	# A single muted red field, never an alternating flash or strobe.
	if SettingsService.reduced_motion:
		return
	(_hero.get_parent().get_parent() as PanelContainer).add_theme_stylebox_override("panel", UI.box(Color("30131E"), Color("FF5C5C"), 20))
	_vibrate(160)
	_motion = create_tween()
	for offset: float in [3.0, -3.0, 2.0, -2.0, 0.0]:
		_motion.tween_property(_body, "position:x", offset, 0.06)


func _vibrate(duration: int) -> void:
	if SettingsService.vibration_enabled and not SettingsService.reduced_motion and OS.has_feature("android"):
		Input.vibrate_handheld(duration)


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	if _waking:
		AudioManager.stop_dialogue_blips(self)
		_dialogue.show()
	_waking = false
	_wake_phase = ""
	if is_instance_valid(_body):
		_body.position = Vector2.ZERO
	if is_instance_valid(_hero):
		_hero.modulate = Color.WHITE
	if is_instance_valid(_scene_art):
		_scene_art.modulate = Color.WHITE
	if is_instance_valid(_eyelids):
		_eyelids.queue_free()
	_eyelids = null
	if is_instance_valid(_focus_effect):
		_focus_effect.queue_free()
	_focus_effect = null


func _settings_changed() -> void:
	if SettingsService.reduced_motion:
		_stop_motion()
		if _cinematic_active:
			if _cinematic_tween != null and _cinematic_tween.is_valid():
				_cinematic_tween.kill()
			_cinematic_tween = null
			_finish_cinematic_visual()
		_finish_reveal()


func on_exit() -> void:
	AudioManager.release_opening_audio(self)
	_stop_cinematic()
	if is_instance_valid(_phone_view):
		_phone_view.stop()
	_stop_motion()
	_stop_dialogue()
	_leaving = true


func _exit_tree() -> void:
	AudioManager.release_opening_audio(self)
	_stop_cinematic()
	_stop_motion()
	_stop_dialogue()
