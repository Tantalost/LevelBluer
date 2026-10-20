extends BaseScreen
## Presentation-only onboarding. No combat, assessment, or mastery APIs.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const DATA_PATH: String = "res://data/student_opening.json"
const STORY_PHONE: GDScript = preload("res://src/gameplay/decision/opening_phone.gd")
const PRACTICE_PHONE: GDScript = preload("res://src/gameplay/decision/tutorial_phone.gd")
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

class CinematicEffects extends Control:
	## Presentation-only layers; timeline values come from the owning screen.
	var mode: String = ""
	var time: float = 0.0
	var reduced: bool = false
	var texture: Texture2D
	var fast_panels: Array[int] = []
	var panel_edges: PackedFloat32Array = [0.0, 0.2177, 0.407, 0.597, 0.785, 1.0]
	var art_rect: Rect2
	func _radial(at: Vector2, radius: float, ink: Color) -> void:
		for ring: int in range(20, 0, -1):
			draw_circle(at, radius * ring / 20.0, Color(ink, ink.a / 10.0))
	func _draw() -> void:
		match mode:
			"takeover":
				var origin: Vector2 = art_rect.position + art_rect.size * Vector2(0.50, 0.52)
				if time >= 0.6 and time < 1.8:
					var spread: float = clampf((time - 0.6) / 1.2, 0, 1)
					if reduced:
						draw_rect(Rect2(Vector2.ZERO, size), Color(0.52, 0.04, 0.08, spread * 0.25))
					else:
						_radial(origin, size.length() * spread, Color(0.70, 0.03, 0.08, 0.55))
				elif time >= 1.8:
					var tail: float = clampf((3.0 - time) / 1.2, 0, 1)
					draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.02, 0.06, tail * 0.20))
					var breath: float = sin(PI * clampf((time - 3.0) / 2.5, 0, 1))
					if not reduced:
						_radial(origin, size.y * 0.30, Color(1, 0.03, 0.08, breath * 0.12))
			"meeting":
				# One dim/recover cycle at the four lamps, then a cut. No strobe.
				if time >= 6.0 and time < 6.65:
					var dip: float = sin(PI * (time - 6.0) / 0.65) * (0.25 if reduced else 0.75)
					for x: float in [0.167, 0.356, 0.642, 0.833]:
						_radial(art_rect.position + art_rect.size * Vector2(x, 0.16), art_rect.size.y * 0.20, Color(0, 0, 0, dip))
			"montage", "closing":
				_draw_victims()
			"rewind":
				draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
				var center: Vector2 = size * 0.5
				var radius: float = minf(size.x, size.y) * 0.095
				var alpha: float = sin(PI * clampf(time, 0, 1))
				var ink: Color = Color("8FF0E6", alpha)
				draw_arc(center, radius, 0, TAU, 48, ink, 3, true)
				for tick: int in 12:
					var direction: Vector2 = Vector2.from_angle(tick * TAU / 12.0)
					draw_line(center + direction * radius * 0.85, center + direction * radius, ink, 2)
				var angle: float = -PI * 0.5 if reduced else -PI * 0.5 - time * TAU * 2.0
				draw_line(center, center + Vector2.from_angle(angle) * radius * 0.78, ink, 4, true)
				draw_line(center, center + Vector2.from_angle(angle * 0.35) * radius * 0.45, ink, 4, true)
	func _draw_victims() -> void:
		if texture == null:
			return
		var texture_size: Vector2 = texture.get_size()
		var fit: float = minf(size.x / texture_size.x, size.y / texture_size.y)
		var bounds: Rect2 = Rect2((size - texture_size * fit) * 0.5, texture_size * fit)
		for index: int in 5:
			var progress: float = 1.0 if mode == "closing" or fast_panels.has(index) else clampf((time - 0.4 - index * 0.7) / 0.6, 0, 1)
			if progress <= 0.0:
				continue
			var region: Rect2 = Rect2(texture_size * Vector2(panel_edges[index], 0), texture_size * Vector2(panel_edges[index + 1] - panel_edges[index], 1))
			var target: Rect2 = Rect2(bounds.position + Vector2(bounds.size.x * index / 5.0, 0), Vector2(bounds.size.x / 5.0, bounds.size.y))
			var zoom: float = 1.0 if reduced else lerpf(1.0, 1.05, progress)
			var cover: float = maxf(target.size.x / region.size.x, target.size.y / region.size.y) * zoom
			var crop_size: Vector2 = target.size / cover
			region.position += (region.size - crop_size) * Vector2(0.5, 0.47)
			region.size = crop_size
			draw_texture_rect_region(texture, target, region, Color(1, 1, 1, progress))
			draw_line(target.position, target.position + Vector2(0, target.size.y), Color("050B18"), 3)
		var line_progress: float = 1.0 if mode == "closing" else clampf((time - 5.2) / 1.2, 0, 1)
		if line_progress > 0:
			var tighten: float = clampf(time / 1.8, 0, 1) if mode == "closing" else 0.0
			var start: Vector2 = bounds.position + bounds.size * Vector2(lerpf(0.025, 0.5, tighten), 0.71)
			var end: Vector2 = bounds.position + bounds.size * Vector2(lerpf(0.975, 0.5, tighten), 0.71)
			end = start.lerp(end, line_progress)
			var glow: float = maxf(0, sin(PI * (time - 6.4) / 1.2)) if mode == "montage" and time < 7.6 else 0.0
			if reduced:
				glow = 0.0
			draw_line(start, end, Color(1, 0.10, 0.18, 0.12 + glow * 0.18), 9, true)
			draw_line(start, end, Color("FF5C5C"), 2, true)

var data: Dictionary = {}
var state: Dictionary = {}
var replay: bool = false
var part: String = "intro"
var step: String = "wake"
var intro_index: int = 0
var history: Array[Dictionary] = []
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
var _effects: CinematicEffects
var _cinematic_time: float = 0.0
var _cinematic_duration: float = 0.0
var _cinematic_mode: String = ""
var _rewinding: bool = false
var _reveal_done: bool = false
var _glitch_until: int = -1
var _rgb_material: ShaderMaterial
var _cinematic_focus_lost: bool = false
var _cinematic_app_paused: bool = false
var practice: Dictionary = {}
var _practice_layer: Control
var _practice_tween: Tween
var _practice_buttons: Array[Button] = []
var _thought_label: Label
var _thought_done: bool = false
var _celebration: CelebrationArt
var _practice_margin: MarginContainer
var _practice_card: PanelContainer
var _practice_blurred: bool = true
var _event_layout: bool = false
var _item_card: PanelContainer
var _item_caption: Label

class ChoiceIcon extends Control:
	var kind: int = 0
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		draw_circle(center, 20, Color("8FF0E6"))
		draw_arc(center, 23, 0, TAU, 40, Color("4FE0D4", 0.35), 1.5, true)
		var ink: Color = Color("101623")
		match kind:
			0: # Envelope: claim.
				draw_rect(Rect2(center - Vector2(11, 8), Vector2(22, 16)), ink, false, 2)
				draw_polyline(PackedVector2Array([center + Vector2(-11, -8), center, center + Vector2(11, -8)]), ink, 2)
			1: # Delete.
				draw_rect(Rect2(center - Vector2(7, 5), Vector2(14, 16)), ink, false, 2)
				draw_line(center + Vector2(-10, -8), center + Vector2(10, -8), ink, 2)
				draw_line(center + Vector2(-4, -12), center + Vector2(4, -12), ink, 2)
			2: # Inspect.
				draw_arc(center - Vector2(3, 3), 8, 0, TAU, 24, ink, 2, true)
				draw_line(center + Vector2(3, 3), center + Vector2(12, 12), ink, 3, true)
			_:
				draw_polyline(PackedVector2Array([center + Vector2(-4, -8), center + Vector2(5, 0), center + Vector2(-4, 8)]), ink, 3)

class CelebrationArt extends Control:
	var time: float = 0.0:
		set(value):
			time = value
			queue_redraw()
	var reduced: bool = false
	var emblem_only: bool = false
	func _draw() -> void:
		if emblem_only:
			var c: Vector2 = size * 0.5
			draw_circle(c, 52, Color("153B37"))
			draw_arc(c, 57, 0, TAU, 64, Color("FFB648"), 3)
			draw_rect(Rect2(c - Vector2(34, 24), Vector2(68, 48)), Color("173058"))
			draw_polyline(PackedVector2Array([c + Vector2(-34, -24), c, c + Vector2(34, -24)]), Color("4FE0D4"), 3)
			draw_circle(c + Vector2(23, 23), 17, Color("33D17A"))
			draw_polyline(PackedVector2Array([c + Vector2(14, 23), c + Vector2(21, 30), c + Vector2(33, 16)]), Color("101623"), 3)
			return
		if reduced or time > 3.0:
			return
		var colors: Array[Color] = [Color("4FE0D4"), Color("FFB648"), Color("F3ECD6")]
		for index: int in 60:
			var phase: float = float(index % 7) * 0.045
			var elapsed: float = maxf(0, time - phase)
			var x: float = size.x * 0.5 + sin(index * 2.399) * elapsed * size.x * 0.48
			var y: float = size.y * 0.3 - elapsed * (90 + index % 90) + elapsed * elapsed * 170
			var ink: Color = colors[index % 3]
			ink.a *= clampf((3.0 - time) / 0.6, 0, 1)
			draw_set_transform(Vector2(x, y), elapsed * (index % 5 + 1))
			draw_rect(Rect2(-4, -2, 8, 4), ink)
		draw_set_transform(Vector2.ZERO)

class ThoughtTail extends Control:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 12, Color("4FE0D4"))
		draw_circle(Vector2.ZERO, 10, Color("F3ECD6"))
		draw_circle(Vector2(24, 18), 7, Color("F3ECD6"))
		draw_circle(Vector2(42, 30), 4, Color("F3ECD6"))
var _evidence_preview: Texture2D


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
	var old_version: int = int(state.get("version", 1))
	_migrate_art_sequence(state)
	if old_version < 5 and not state.is_empty():
		# Old click-to-save evidence does not satisfy the hands-on activities.
		state["step"] = "wake"
		state["history"] = []
		state.erase("practice")
		state.erase("pending_outcome")
	practice = (state.get("practice", {}) as Dictionary).duplicate(true)
	part = str(args.get("part", state.get("part", "intro")))
	if part not in ["intro", "tutorial"]:
		part = "intro"
	intro_index = clampi(int(state.get("intro_index", 0)), 0, _intro().size() - 1)
	step = str(state.get("step", "wake"))
	if not (data.get("tutorial", {}) as Dictionary).has(step):
		step = "wake"
	if args.has("part"):
		intro_index = 0
		step = "wake"
	for entry: Variant in state.get("history", []):
		if entry is Dictionary:
			history.append((entry as Dictionary).duplicate())
	if args.has("part"):
		history.clear()
	_normalize_practice_step()
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
		_style_story_button(button)
	parent.add_child(button)
	return button


func _panel_column(weight: float) -> VBoxContainer:
	var panel: PanelContainer = UI.panel(_body)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = weight
	panel.add_theme_stylebox_override("panel", UI.box(Color.TRANSPARENT if part == "intro" else PANEL, Color.TRANSPARENT if part == "intro" else Color("173058"), 20))
	return UI.scroll_column(panel)


func _render() -> void:
	_clear_practice_layer()
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
	if part in ["intro", "tutorial"]:
		_set_art(str(data["room_art"]))
		_scene_art.show()
	_hero = _panel_column(0.9)
	_copy = _panel_column(1.1)
	_title.text = _text(part)
	if replay:
		_title.text += " / " + _text("replay_short")
	_title.tooltip_text = _text("replay_note") if replay else ""
	_counter.text = _text("progress").format({"count": intro_index + 1, "total": _intro().size()}) if part == "intro" else "PRACTICE"
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
	if is_instance_valid(_effects):
		_effects.texture = _scene_art.texture
		_effects.queue_redraw()
	var descriptions: Dictionary[String, String] = {
		"opening_john_room_wake_v1": "Morning light fills John's room.",
		"opening_john_reaching_phone_v1": "John reaches across the bed for his buzzing phone.",
		"opening_john_claim_prize_v1": "John taps Claim Prize before checking the offer.",
		"opening_john_got_you_v1": "The phone turns red. Got You.",
		"opening_collector_meeting_v2": "Four masked scammers. Four lights. An empty chair in shadow.",
		"opening_five_victims_v3": "Five people. Five traps. Shock, confusion, tears, anger and sadness."
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
	_effects = CinematicEffects.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic.add_child(_effects)
	_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.gui_input.connect(_panel_input)
	var rgb_shader: Shader = Shader.new()
	rgb_shader.code = "shader_type canvas_item; uniform float split = 0.0; void fragment(){ vec4 c = texture(TEXTURE, UV); vec2 d = vec2(TEXTURE_PIXEL_SIZE.x * split, 0.0); COLOR = vec4(texture(TEXTURE, UV+d).r, c.g, texture(TEXTURE, UV-d).b, c.a); }"
	_rgb_material = ShaderMaterial.new()
	_rgb_material.shader = rgb_shader
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
	_cinematic_next.set_meta("ui_sound", "")
	_advance_button.set_meta("ui_sound", "") # No late click tail after the silence cut.
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
	_cinematic_mode = visual
	_cinematic_duration = {"takeover": 6.0, "meeting": 7.0, "montage": 9.0, "closing": 6.0}[visual]
	_cinematic_time = 0.0
	_reveal_done = false
	_effects.mode = visual
	_effects.texture = _scene_art.texture
	_effects.reduced = SettingsService.reduced_motion
	_effects.fast_panels.clear()
	_effects.mouse_filter = Control.MOUSE_FILTER_STOP if visual == "montage" else Control.MOUSE_FILTER_IGNORE
	_effects.show()
	# Cuts both decks and pending UI click tails before the 0.6-second quiet.
	AudioManager.cut_opening_audio(self)
	AudioManager.play_opening_score(visual, self)
	_closing_caption.text = str(beat.get("caption", ""))
	_closing_caption.visible_characters = -1
	if visual == "meeting":
		_position_laugh_captions()
		for laugh: Label in _laugh_captions:
			laugh.show()
			laugh.modulate.a = 0.0
	if visual in ["montage", "closing"]:
		_scene_art.hide() # Five independently cropped panels are drawn by Effects.
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_method(_cinematic_frame, 0.0, _cinematic_duration, _cinematic_duration)
	_cinematic_tween.tween_callback(_finish_cinematic_visual)
	_cinematic_frame(0.0)


func _cinematic_frame(time: float) -> void:
	_cinematic_time = time
	_effects.time = time
	_effects.reduced = SettingsService.reduced_motion
	var reduced: bool = SettingsService.reduced_motion
	_scene_art.position = Vector2.ZERO
	match _cinematic_mode:
		"takeover":
			if time >= 1.8 and not _reveal_done:
				_reveal_done = true
				_reveal_red_phone()
				if not reduced:
					_glitch_until = Engine.get_process_frames() + 2
					_scene_art.material = _rgb_material
					_rgb_material.set_shader_parameter("split", 3.0)
					_vibrate(80)
			if time >= 0.6 and time < 1.8 and not reduced:
				var strength: float = (time - 0.6) / 1.2 * 3.0
				_scene_art.position = Vector2(sin(time * 47.0), cos(time * 39.0)) * strength
			if reduced:
				_scene_art.modulate.a = clampf((time - 1.8) / 0.45, 0.0, 1.0) if time >= 1.8 else clampf((1.8 - time) / 0.45, 0.0, 1.0)
		"meeting":
			_scene_art.pivot_offset = size * Vector2(0.5, 0.60)
			_scene_art.scale = Vector2.ONE * (1.0 if reduced else lerpf(1.0, 1.08, clampf(time / 7.0, 0, 1)))
			_black_fade.modulate.a = maxf(1.0 - time / 0.65, clampf((time - 6.65) / 0.35, 0, 1))
			_position_laugh_captions()
			for index: int in 5:
				var laugh: Label = _laugh_captions[index]
				var reveal: float = clampf((time - 0.9 - index * 0.9) / 0.5, 0, 1)
				laugh.modulate.a = reveal * (1.0 - clampf((time - 6.65) / 0.35, 0, 1))
				laugh.scale = Vector2.ONE if reduced else Vector2.ONE * (1.0 + sin(reveal * PI) * 0.13)
				if index == 4 and not reduced:
					laugh.position.x -= (1.0 - reveal) * size.x * 0.30
					laugh.position.y += (1.0 - reveal) * size.y * 0.10
		"closing":
			_black_fade.modulate.a = lerpf(0.0, 0.65, clampf(time / 1.4, 0, 1)) if time < 4.8 else lerpf(0.65, 1.0, (time - 4.8) / 1.2)
			_closing_caption.modulate.a = clampf((time - 1.2) / 0.4, 0, 1) * (1.0 - clampf((time - 4.8) / 1.2, 0, 1))
			# Reveal complete words. Last word lands at 2.8s, matching score silence.
			var words: PackedStringArray = _closing_caption.text.split(" ")
			var count: int = mini(words.size(), maxi(0, int((time - 1.2) / (1.6 / (words.size() - 1))) + 1)) if time >= 1.2 else 0
			_closing_caption.visible_characters = " ".join(words.slice(0, count)).length()
	_update_effect_art_rect()
	_effects.queue_redraw()


func _process(_delta: float) -> void:
	if _glitch_until >= 0 and Engine.get_process_frames() >= _glitch_until:
		_scene_art.material = null
		_glitch_until = -1


func _update_effect_art_rect() -> void:
	if _scene_art.texture == null:
		_effects.art_rect = Rect2(Vector2.ZERO, size)
		return
	var image_size: Vector2 = _scene_art.texture.get_size()
	var cover: float = maxf(size.x / image_size.x, size.y / image_size.y)
	var image_rect: Rect2 = Rect2((size - image_size * cover) * 0.5, image_size * cover)
	image_rect.position = _scene_art.pivot_offset + (image_rect.position - _scene_art.pivot_offset) * _scene_art.scale + _scene_art.position
	image_rect.size *= _scene_art.scale
	_effects.art_rect = image_rect


func _panel_input(event: InputEvent) -> void:
	if _leaving or _menu.visible or _cinematic_mode != "montage" or not _cinematic_busy:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()) or (event is InputEventScreenTouch and event.is_pressed()):
		var index: int = int(floor((_cinematic_time - 0.4) / 0.7))
		if index >= 0 and index < 5 and not _effects.fast_panels.has(index):
			_effects.fast_panels.append(index)
			_effects.queue_redraw()
		accept_event()


func _reveal_red_phone() -> void:
	if _leaving or not _cinematic_active:
		return
	_scene_art.position = Vector2.ZERO
	_scene_art.scale = Vector2.ONE
	var beat: Dictionary = _intro()[intro_index] as Dictionary
	_set_art(str(beat["reveal_art"]))


func _finish_cinematic_visual() -> void:
	if _leaving or not _cinematic_active:
		return
	_scene_art.position = Vector2.ZERO
	_red_wash.modulate.a = 0.0
	_cinematic_frame(_cinematic_duration)
	_cinematic_busy = false
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_advance_prompt()


func _stop_cinematic() -> void:
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.kill()
	_cinematic_tween = null
	_cinematic_active = false
	_cinematic_busy = false
	_rewinding = false
	_glitch_until = -1
	_cinematic_mode = ""
	AudioManager.stop_dialogue_blips(self)
	if is_instance_valid(_cinematic):
		_cinematic.hide()
		_red_wash.modulate.a = 0.0
		_black_fade.modulate.a = 0.0
		_closing_caption.modulate.a = 0.0
		_cinematic_next.hide()
		for laugh: Label in _laugh_captions:
			laugh.hide()
		_effects.hide()
		_effects.fast_panels.clear()
	if is_instance_valid(_scene_art):
		_scene_art.position = Vector2.ZERO
		_scene_art.scale = Vector2.ONE
		_scene_art.material = null


func _phone_action(source: Control, beat_id: String) -> void:
	# Deferred signals cannot advance a replacement scene after Back/Skip/Menu.
	if _leaving or _menu.visible or source != _phone_view or part != "intro":
		return
	if str((_intro()[intro_index] as Dictionary)["id"]) == beat_id:
		advance()


func _practice_phone(mode: String) -> void:
	var host: Control = Control.new()
	host.name = "TutorialPhoneHost"
	host.clip_contents = true
	add_child(host)
	move_child(host, _menu.get_index())
	_phone_host = host
	_phone_view = PRACTICE_PHONE.new() as Control
	host.add_child(_phone_view)
	_phone_view.configure_practice(mode, practice, _evidence_preview)
	var message: Dictionary = data["message"] as Dictionary
	_phone_view.receive_message({"sender": str(message["sender_name"]) + " <" + str(message["sender_address"]) + ">", "subject": str(message["subject"]), "body": str(message["body"])})
	_phone_view.practice_action.connect(_practice_action.bind(_phone_view), CONNECT_DEFERRED)
	_phone_view.evidence_changed.connect(_practice_updated.bind(_phone_view))
	_phone_view.photo_taken.connect(_practice_photo.bind(_phone_view))
	_phone_view.thought_requested.connect(_practice_thought.bind(_phone_view))
	_phone_view.message_read.connect(_practice_message_read.bind(_phone_view))
	_phone_view.open_phone()
	if mode == "notes":
		_phone_view.show_notes_home()
	elif mode != "read":
		_phone_view.show_open_message()


func _practice_message_read(source: Control) -> void:
	if source != _phone_view or part != "tutorial" or step != "inbox":
		return
	_advance_action = func() -> void: go("choice")
	_advance_slot.show()
	_finish_reveal()


func _practice_updated(snapshot: Dictionary, source: Control) -> void:
	if source == _phone_view and not _leaving and part == "tutorial":
		practice = snapshot.duplicate(true)
		_persist()


func _practice_photo(preview: Texture2D, source: Control) -> void:
	if source == _phone_view and not _leaving:
		_evidence_preview = preview


func _practice_action(action: String, source: Control) -> void:
	if source != _phone_view or _leaving or _menu.visible or part != "tutorial":
		return
	match step:
		"inbox":
			if action == "choice": go("choice")
		"claim":
			if action == "failure" and _phone_view._password_ready: go(action)
		"safe":
			if action == "inspect": go("inspect_intro")
			elif action == "leave": skip()
		"inspect":
			if action == "flags_done" and _phone_view.flags_complete(): go("next_issue")
		"sender":
			if action == "notes" and bool(practice.get("sender_opened", false)): go("notes")
		"notes":
			if action == "capture" and _practice_ready(): go("capture")
		"capture":
			if action == "submit" and bool(practice.get("captured", false)): go("submit")
		"submit":
			if action == "sealed" and bool(practice.get("sealed", false)): go("sealed")


func _practice_ready() -> bool:
	var flags: Array = practice.get("flags", [])
	return flags.has("reward") and flags.has("pressure") and flags.has("password") and str(practice.get("domain", "")) == "prize-claim.example" and bool(practice.get("sender_opened", false))


func _normalize_practice_step() -> void:
	# Only the canonical domain is persisted; never retain arbitrary typed text.
	if str(practice.get("domain", "")) != "prize-claim.example":
		practice.erase("domain")
	var normalized_flags: Array[String] = []
	if practice.get("flags", []) is Array:
		for flag: Variant in practice.get("flags", []):
			if str(flag) in ["reward", "pressure", "password"] and not normalized_flags.has(str(flag)):
				normalized_flags.append(str(flag))
	practice["flags"] = normalized_flags
	if normalized_flags.size() < 3 and step in ["next_issue", "sender", "notes"]:
		step = "inspect"
	if not bool(practice.get("sender_opened", false)) and step == "notes":
		step = "sender"
	if not _practice_ready():
		practice.erase("captured")
		practice.erase("sealed")
		if step in ["capture", "submit", "sealed", "closing"]: step = "inspect"
	if not bool(practice.get("captured", false)):
		practice.erase("sealed")
		if step in ["submit", "sealed", "closing"]: step = "capture"
	if not bool(practice.get("sealed", false)) and step in ["sealed", "closing"]:
		step = "submit"
	if not bool(practice.get("sealed", false)) and state.get("pending_outcome", "") == "completed":
		state.erase("pending_outcome")
	if not (data["tutorial"] as Dictionary).has(step):
		step = "wake"


func _render_tutorial() -> void:
	_show_room(str(data["room_art"]))
	var copy: Dictionary = (data["tutorial"] as Dictionary)[step] as Dictionary
	if step == "summary" and str(state.get("pending_outcome", "")) != "completed":
		_narrate("PRACTICE PAUSED", "You can return to this tutorial from the menu. No coins, mastery, or chapter progress were awarded.")
	else:
		_narrate(str(copy["title"]), str(copy["text"]), _name("player"))
	match step:
		"wake":
			_blink()
			_advance_action = func() -> void: go("inbox")
		"inbox": _practice_phone("read")
		"choice":
			_practice_phone("read")
			_phone_view.show_open_message()
			_decision_overlay()
		"inspect_intro":
			_practice_phone("read")
			_phone_view.show_open_message()
			_title_overlay("Read between the lines", "inspect")
		"next_issue":
			_practice_phone("inspect")
			_title_overlay("Alright, what next could be the issue?", "sender")
			if not SettingsService.reduced_motion:
				_practice_tween.parallel().tween_property(_phone_view._passage, "modulate:a", 0.0, 0.65)
		"claim", "inspect", "sender", "notes", "capture", "submit": _practice_phone(step)
		"safe": _practice_phone("deleted")
		"failure":
			_set_art("opening_john_got_you_v1")
			AudioManager.play_sfx("ui_error")
			_add_button(_footer, "retry", retry, true)
		"sealed":
			AudioManager.play_sfx("ui_success")
			_advance_action = func() -> void: go("closing")
		"closing": _practice_closing()
		"summary":
			if state.get("pending_outcome", "") == "completed":
				_completion_overlay()
			else:
				_add_button(_footer, "hub", _hub, true)
				_footer.add_child(UI.button("REPLAY TUTORIAL", _replay_practice))


func _clear_practice_layer() -> void:
	if _practice_tween != null and _practice_tween.is_valid():
		_practice_tween.kill()
	_practice_tween = null
	if is_instance_valid(_practice_layer):
		remove_child(_practice_layer)
		_practice_layer.queue_free()
	_practice_layer = null
	_practice_buttons.clear()
	_thought_label = null
	_celebration = null
	_event_layout = false
	_item_card = null
	_item_caption = null
	_dialogue.z_index = 0


func _overlay_column(blur: bool = true, event: bool = false) -> VBoxContainer:
	_clear_practice_layer()
	_event_layout = event
	_practice_layer = Control.new()
	_practice_layer.name = "PracticeOverlay"
	add_child(_practice_layer)
	move_child(_practice_layer, _menu.get_index())
	_practice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if blur:
		_dialogue.hide()
		if is_instance_valid(_phone_view): _phone_view.set_locked(true)
		var shade: ColorRect = ColorRect.new()
		shade.color = Color(0.02, 0.04, 0.09, 0.82)
		_practice_layer.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if not SettingsService.reduced_motion:
			var shader: Shader = Shader.new()
			shader.code = "shader_type canvas_item; uniform sampler2D scene_tex : hint_screen_texture, filter_linear_mipmap; void fragment(){ vec3 c = textureLod(scene_tex, SCREEN_UV, 2.5).rgb; COLOR = vec4(mix(c, vec3(0.02,0.04,0.09),0.65),1.0); }"
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = shader
			shade.material = material
	if event:
		# The scene alone is blurred. Item and narration render above the veil.
		_dialogue.show()
		_dialogue.z_index = 1
		move_child(_practice_layer, _phone_host.get_index())
		_item_card = PanelContainer.new()
		_item_card.name = "IntroducedItemCard"
		_item_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_practice_layer.add_child(_item_card)
		var item_style: StyleBoxFlat = UI.box(Color("0A1730EB"), Color("4FE0D470"), 14)
		item_style.set_corner_radius_all(26)
		item_style.corner_detail = 12
		item_style.shadow_size = 12
		_item_card.add_theme_stylebox_override("panel", item_style)
		_item_caption = UI.label("JOHN'S PHONE\nOne unexpected prize email", 22, TEXT)
		_item_caption.name = "IntroducedItemCaption"
		_item_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_practice_layer.add_child(_item_caption)
		_phone_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_phone_view.size = Vector2(480, 840)
		_phone_view.show_item_preview()
	var margin: MarginContainer = MarginContainer.new()
	_practice_margin = margin
	_practice_blurred = blur
	_practice_layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", int(_header.get_global_rect().end.y + 18))
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_theme_constant_override("margin_left", int(size.x * (0.15 if blur else 0.03)))
	margin.add_theme_constant_override("margin_right", int(size.x * (0.15 if blur else 0.52)))
	if not blur:
		_practice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var panel: PanelContainer = UI.panel(center)
	_practice_card = panel
	panel.name = "PracticeOverlayCard"
	panel.custom_minimum_size.x = size.x * (0.65 if blur else 0.43)
	var style: StyleBoxFlat = UI.box(PANEL if blur else Color("F3ECD6"), Color("FFB648") if blur else CYAN, 20)
	if event:
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color.TRANSPARENT
		style.shadow_size = 0
		style.set_content_margin_all(0)
	style.set_corner_radius_all(18 if not blur else 8)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	if not blur:
		var tail_host: Control = Control.new()
		tail_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tail_host)
		var tail: ThoughtTail = ThoughtTail.new()
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tail_host.add_child(tail)
		tail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		tail.offset_left = -70
		tail.offset_right = -70
		tail.offset_top = 6
		tail.offset_bottom = 6
	return UI.column(panel, 14)


func _overlay_label(parent: Control, text: String, heading: bool = false, ink: Color = TEXT) -> Label:
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var label: Label = UI.label(text, ceili((28.0 if heading else 18.0) / physical), ink)
	label.set_meta("practice_heading", heading)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _style_story_button(button: Button, choice: bool = false) -> void:
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill: Color = Color("102040F0")
		var border: Color = Color("4FE0D478")
		if style_name == "hover":
			fill = Color("173058")
			border = CYAN
		elif style_name == "pressed":
			fill = Color("153B37")
			border = Color("8FF0E6")
		elif style_name == "disabled":
			fill = Color("0A1730")
			border = Color("173058")
		elif style_name == "focus":
			fill = Color.TRANSPARENT
			border = Color("8FF0E6")
		var style: StyleBoxFlat = UI.box(fill, border, 12)
		style.set_corner_radius_all(30 if choice else 12)
		style.corner_detail = 12
		style.set_border_width_all(2 if style_name in ["focus", "hover"] else 1)
		style.content_margin_left = 76 if choice else 16
		style.content_margin_right = 24 if choice else 16
		style.shadow_size = 9 if style_name == "hover" else 4
		style.shadow_color = Color("4FE0D428") if style_name == "hover" else Color("050B1870")
		style.shadow_offset = Vector2(0, 2 if style_name == "pressed" else 4)
		if style_name == "focus":
			style.shadow_size = 0
		button.add_theme_stylebox_override(style_name, style)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, TEXT)


func _overlay_button(parent: Control, caption: String, action: Callable, icon_kind: int = -1) -> Button:
	var button: Button = UI.button(caption, func() -> void:
		if not _menu.visible and not _leaving and not _cinematic_focus_lost and not _cinematic_app_paused:
			action.call()
	)
	_style_story_button(button, _event_layout)
	if _event_layout:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 64
		var icon: ChoiceIcon = ChoiceIcon.new()
		icon.kind = icon_kind
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		icon.offset_left = 10
		icon.offset_right = 62
		icon.offset_top = -26
		icon.offset_bottom = 26
	parent.add_child(button)
	_practice_buttons.append(button)
	return button


func _reveal_overlay_controls(delay: float) -> void:
	for button: Button in _practice_buttons:
		button.modulate.a = 0.0
		button.disabled = true
	_practice_tween = create_tween()
	_practice_tween.tween_interval(delay if not SettingsService.reduced_motion else 0.05)
	if not SettingsService.reduced_motion:
		for button: Button in _practice_buttons:
			_practice_tween.tween_property(button, "modulate:a", 1.0, 0.12)
	_practice_tween.tween_callback(func() -> void:
		for button: Button in _practice_buttons:
			button.modulate.a = 1.0
			button.disabled = false
	)


func _decision_overlay() -> void:
	var column: VBoxContainer = _overlay_column(true, true)
	var heading: Label = _overlay_label(column, "What should I do?", true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for option: String in ["Claim Prize", "Delete and move on", "Investigate"]:
		var target: String = {"Claim Prize": "claim", "Delete and move on": "safe", "Investigate": "inspect_intro"}[option]
		_overlay_button(column, option, go.bind(target), _practice_buttons.size())
	_reveal_overlay_controls(0.5)


func _title_overlay(caption: String, target: String) -> void:
	var column: VBoxContainer = _overlay_column(true, true)
	var heading: Label = _overlay_label(column, caption, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_overlay_button(column, "CONTINUE", go.bind(target))
	_reveal_overlay_controls(0.9)


func _practice_thought(text: String, complete: bool, source: Control) -> void:
	if source != _phone_view or _menu.visible or _leaving:
		return
	_phone_view.set_locked(true)
	_dialogue.hide()
	_thought_done = complete
	var column: VBoxContainer = _overlay_column(false)
	_overlay_label(column, "John · thinking…", false, Color("173058"))
	_thought_label = _overlay_label(column, text, false, Color("101623"))
	_thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_overlay_button(column, "WHAT NEXT?" if complete else "KEEP LOOKING", _dismiss_thought)
	_thought_label.visible_characters = -1 if SettingsService.reduced_motion else 0
	_reveal_overlay_controls(0.05 if SettingsService.reduced_motion else maxf(0.4, text.length() / 45.0))
	if not SettingsService.reduced_motion:
		_practice_tween.kill()
		_practice_tween = create_tween()
		_practice_tween.tween_property(_thought_label, "visible_characters", text.length(), maxf(0.4, text.length() / 45.0))
		_practice_tween.tween_callback(func() -> void:
			for button: Button in _practice_buttons:
				button.modulate.a = 1.0
				button.disabled = false
		)


func _dismiss_thought() -> void:
	if _menu.visible or _leaving:
		return
	var next: bool = _thought_done
	_clear_practice_layer()
	_dialogue.show()
	if is_instance_valid(_phone_view): _phone_view.set_locked(false)
	if next: go("next_issue")


func _completion_overlay() -> void:
	var column: VBoxContainer = _overlay_column()
	_overlay_label(column, "TUTORIAL COMPLETE", true)
	var emblem: CelebrationArt = CelebrationArt.new()
	emblem.emblem_only = true
	emblem.custom_minimum_size.y = 124
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(emblem)
	_overlay_label(column, "You spotted the warning signs, preserved the evidence, and protected your information. Your story is just beginning.")
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var proceed: Button = _overlay_button(actions, "CONTINUE", _hub)
	proceed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proceed.size_flags_stretch_ratio = 1.5
	proceed.add_theme_stylebox_override("normal", UI.box(Color("2E6BFF"), Color("FFB648"), 12))
	_overlay_button(actions, "REPLAY TUTORIAL", _replay_practice).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_celebration = CelebrationArt.new()
	_celebration.name = "CompletionConfetti"
	_celebration.reduced = SettingsService.reduced_motion
	_celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_layer.add_child(_celebration)
	_celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_tween = create_tween()
	_practice_tween.tween_property(_celebration, "time", 3.1, 3.1)
	AudioManager.play_sfx("ui_success")


func _pause_practice(paused: bool) -> void:
	if _practice_tween != null and _practice_tween.is_valid():
		if paused: _practice_tween.pause()
		else: _practice_tween.play()


func _practice_closing() -> void:
	_stop_motion()
	_set_art("opening_john_claim_prize_v1")
	_dialogue.hide()
	_cinematic_active = true
	_cinematic_busy = true
	_cinematic_mode = "practice_closing"
	_cinematic.show()
	_closing_caption.text = str((data["tutorial"] as Dictionary)["closing"]["text"])
	_closing_caption.visible_characters = -1
	_advance_action = finish
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(_black_fade, "modulate:a", 0.65, 0.6)
	_cinematic_tween.parallel().tween_property(_closing_caption, "modulate:a", 1.0, 0.8)
	_cinematic_tween.tween_interval(2.0)
	_cinematic_tween.tween_callback(func() -> void:
		_cinematic_busy = false
		_update_advance_prompt()
	)


func _replay_practice() -> void:
	practice.clear()
	_evidence_preview = null
	history.clear()
	state.erase("pending_outcome")
	part = "tutorial"
	step = "wake"
	_render()
	_persist()


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
	_normalize_practice_step()
	_render()
	_persist()


func advance() -> void:
	if _leaving or _menu.visible or part != "intro" or _cinematic_busy or _waking:
		return
	if is_instance_valid(_phone_view):
		var id: String = str((_intro()[intro_index] as Dictionary)["id"])
		if (id == "prize" and not bool(_phone_view.get("_read"))) or (id == "tap" and not bool(_phone_view.get("_claim_sent"))):
			return
	if intro_index == _intro().size() - 1:
		_start_rewind()
		return
	_advance_story()


func _advance_story() -> void:
	_record_history()
	if intro_index + 1 < _intro().size():
		intro_index += 1
	else:
		state["intro_status"] = "completed"
		part = "tutorial"
		step = "wake" if str(data.get("after_intro", "tutorial")) == "tutorial" else "summary"
	_render()
	_persist()


func _start_rewind() -> void:
	if _rewinding or _leaving:
		return
	_rewinding = true
	_cinematic_busy = true
	_cinematic_mode = "rewind"
	_cinematic_time = 0.0
	_black_fade.modulate.a = 0.0
	_closing_caption.modulate.a = 0.0
	_effects.mode = "rewind"
	_effects.time = 0.0
	_effects.queue_redraw()
	_update_advance_prompt()
	AudioManager.cut_opening_audio(self)
	AudioManager.play_opening_score("rewind", self)
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_method(func(value: float) -> void:
		_cinematic_time = value
		_effects.time = value
		_effects.queue_redraw()
	, 0.0, 1.0, 1.0)
	_cinematic_tween.tween_callback(func() -> void:
		if not _leaving and _rewinding:
			_advance_story()
	)


func retry() -> void:
	if step == "failure":
		go("choice")


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
	if step != "closing" or _leaving or _menu.visible or _cinematic_busy or not bool(practice.get("sealed", false)):
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
	state.erase("clues")
	state.erase("inspected")
	state["history"] = history.duplicate(true)
	state["practice"] = practice.duplicate(true)
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
	_normalize_practice_step()
	_render()
	_persist()


func consume_back() -> bool:
	_back()
	return true


func _open_menu() -> void:
	if _menu.visible or _leaving:
		return
	_pause_practice(true)
	if _waking and _motion != null and _motion.is_valid():
		_motion.pause()
	else:
		_stop_motion()
	AudioManager.pause_opening_audio(self, true)
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.pause()
	if not _cinematic_active:
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
	_pause_practice(_cinematic_focus_lost or _cinematic_app_paused)
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
	if _cinematic_tween != null and _cinematic_tween.is_valid() and not _cinematic_focus_lost and not _cinematic_app_paused:
		_cinematic_tween.play()
		if _cinematic_busy:
			AudioManager.play_opening_score(_cinematic_mode, self, _cinematic_time)
	if is_instance_valid(_phone_view):
		_phone_view.set_locked(_cinematic_focus_lost or _cinematic_app_paused or is_instance_valid(_practice_layer))
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
	if is_instance_valid(_practice_layer) and not _event_layout:
		_practice_margin.add_theme_constant_override("margin_top", int(_header.get_global_rect().end.y + 18))
		_practice_margin.add_theme_constant_override("margin_left", int(size.x * (0.15 if _practice_blurred else 0.03)))
		_practice_margin.add_theme_constant_override("margin_right", int(size.x * (0.15 if _practice_blurred else 0.52)))
		_practice_card.custom_minimum_size.x = size.x * (0.65 if _practice_blurred else 0.43)
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		for node: Node in _practice_layer.find_children("*", "Label", true, false):
			if node.has_meta("practice_heading"):
				(node as Label).add_theme_font_size_override("font_size", ceili((28.0 if node.get_meta("practice_heading") else 18.0) / physical))
	if _event_layout:
		_layout_event()
	elif is_instance_valid(_phone_view):
		_phone_view._metrics.call_deferred()
		_phone_host.position = Vector2(size.x * 0.54, _header.get_global_rect().end.y + 12)
		_phone_host.size = Vector2(size.x * 0.46 - 18, size.y - _phone_host.position.y - 12)
		_dialogue.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_dialogue.custom_minimum_size.x = size.x * 0.50
	else:
		_dialogue.size_flags_horizontal = Control.SIZE_FILL
		_dialogue.custom_minimum_size.x = 0
	if not _event_layout:
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


func _layout_event() -> void:
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	_dialogue.size_flags_horizontal = Control.SIZE_FILL
	_dialogue.custom_minimum_size.x = 0
	_dialogue.custom_minimum_size.y = maxf(160.0, 104.0 / physical)
	var top: float = _header.get_global_rect().end.y + 14
	var bottom: float = minf(_dialogue.get_global_rect().position.y - 12, size.y - _dialogue.custom_minimum_size.y - 26)
	var height: float = maxf(160, bottom - top)
	_practice_margin.add_theme_constant_override("margin_top", int(top))
	_practice_margin.add_theme_constant_override("margin_bottom", int(size.y - bottom))
	_practice_margin.add_theme_constant_override("margin_left", int(size.x * 0.045))
	_practice_margin.add_theme_constant_override("margin_right", int(size.x * 0.49))
	_practice_card.custom_minimum_size.x = size.x * 0.44
	_item_card.position = Vector2(size.x * 0.62, top)
	_item_card.size = Vector2(size.x * 0.34, height)
	var caption_height: float = maxf(60, 42 / physical)
	_item_caption.position = _item_card.position + Vector2(14, height - caption_height)
	_item_caption.size = Vector2(_item_card.size.x - 28, caption_height)
	_item_caption.add_theme_font_size_override("font_size", ceili(16.0 / physical))
	_phone_host.position = _item_card.position + Vector2(18, 8)
	_phone_host.size = Vector2(_item_card.size.x - 36, maxf(100, height - caption_height - 16))
	var fit: float = minf(_phone_host.size.x / 480.0, _phone_host.size.y / 840.0)
	_phone_view.scale = Vector2.ONE * fit
	_phone_view.position = (_phone_host.size - Vector2(480, 840) * fit) * 0.5
	_phone_view._metrics.call_deferred()
	for button: Button in _practice_buttons:
		button.custom_minimum_size.y = maxf(64, 44 / physical)
		button.add_theme_font_size_override("font_size", ceili(20.0 / physical))
	for node: Node in _practice_layer.find_children("*", "Label", true, false):
		if node.has_meta("practice_heading"):
			(node as Label).add_theme_font_size_override("font_size", ceili((24.0 if node.get_meta("practice_heading") else 18.0) / physical))


func _position_laugh_captions() -> void:
	var positions: Array[Vector2] = [Vector2(0.19, 0.42), Vector2(0.34, 0.31), Vector2(0.66, 0.33), Vector2(0.83, 0.44), Vector2(0.80, 0.60)]
	for index: int in _laugh_captions.size():
		var laugh: Label = _laugh_captions[index]
		laugh.autowrap_mode = TextServer.AUTOWRAP_OFF
		laugh.add_theme_font_size_override("font_size", int(size.y * (0.17 if index == 4 else (0.045 + index * 0.004))))
		laugh.size = Vector2(size.x * (0.75 if index == 4 else 0.28), size.y * (0.18 if index == 4 else 0.10))
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
	if is_instance_valid(_celebration):
		_celebration.reduced = SettingsService.reduced_motion
		_celebration.queue_redraw()
	if SettingsService.reduced_motion:
		_stop_motion()
		if _cinematic_active:
			_scene_art.material = null
			_glitch_until = -1
			_effects.reduced = true
			if not _rewinding:
				_cinematic_frame(_cinematic_time)
		_finish_reveal()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _cinematic_focus_lost = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _cinematic_focus_lost = false
		NOTIFICATION_APPLICATION_PAUSED: _cinematic_app_paused = true
		NOTIFICATION_APPLICATION_RESUMED: _cinematic_app_paused = false
		_: return
	if not is_node_ready():
		return
	_pause_practice(_cinematic_focus_lost or _cinematic_app_paused or _menu.visible)
	if is_instance_valid(_phone_view):
		_phone_view.set_locked(_cinematic_focus_lost or _cinematic_app_paused or _menu.visible or is_instance_valid(_practice_layer))
	if not _cinematic_active or not _cinematic_busy:
		return
	if _cinematic_focus_lost or _cinematic_app_paused or _menu.visible:
		if _cinematic_tween != null and _cinematic_tween.is_valid():
			_cinematic_tween.pause()
	else:
		if _cinematic_tween != null and _cinematic_tween.is_valid():
			_cinematic_tween.play()
		# Backgrounding stopped the score: resume at the paused timeline offset.
		AudioManager.play_opening_score(_cinematic_mode, self, _cinematic_time)


func on_exit() -> void:
	_clear_practice_layer()
	AudioManager.release_opening_audio(self)
	_stop_cinematic()
	if is_instance_valid(_phone_view):
		_phone_view.stop()
	_stop_motion()
	_stop_dialogue()
	_leaving = true


func _exit_tree() -> void:
	if _practice_tween != null and _practice_tween.is_valid():
		_practice_tween.kill()
	AudioManager.release_opening_audio(self)
	_stop_cinematic()
	_stop_motion()
	_stop_dialogue()
