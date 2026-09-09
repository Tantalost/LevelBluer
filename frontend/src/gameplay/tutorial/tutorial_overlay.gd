class_name TutorialOverlay
extends Control
## RPG-style handler coach: portrait, typewriter box, right-side choices.

signal deploy_requested
signal quiz_requested
signal build_requested
signal defend_requested
signal upgrades_requested
signal lesson_requested
signal file_requested
signal dashboard_requested
signal dismiss_requested

const FONT_PATH := "res://assets/fonts/DigitalDisco.ttf"
const FONT_FALLBACK_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const TYPE_SEC_PER_CHAR := 0.028
const TALK_SWAP_CHARS := 5
const EXPR_TALK := "npc_talk"
const EXPR_CALM := "npc_calm"
const EXPR_SMILE := "npc_smile"
const BOX_FILL := Color("#1A3C6D")
const BOX_BORDER := Color("#EEF2FF")
const BOX_INNER := Color("#C8D8FF")
const TAG_FILL := Color("#C2C2C2")
const TEXT_WHITE := Color("#EEF2FF")
const HOVER_BORDER := Color("#FFE08A")

enum Mode { DASHBOARD, MATCH }

var _dim: ColorRect
var _cards: Control
var _dialogue_box: PanelContainer
var _face_art: TextureRect
var _name_label: Label
var _body_label: Label
var _tap_catch: Control
var _choice_list: VBoxContainer

var _pixel_font: Font
var _mode: Mode = Mode.MATCH
var _deploy_rect: Rect2 = Rect2()
var _full_line: String = ""
var _typing: bool = false
var _seq: int = 0
var _beat: int = 0
var _expr_id: String = ""
var _tweens: Array[Tween] = []
var _portrait_allowed: bool = true
var _glow_rect: Rect2 = Rect2()


func _ready() -> void:
	_bind_nodes()
	_load_font()
	_style_chrome()
	if _choice_list != null:
		_choice_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _dialogue_box != null:
		_dialogue_box.gui_input.connect(_on_npc_gui)
	if _tap_catch != null:
		_tap_catch.gui_input.connect(_on_catch_gui)
	if not AssetManager.sync_finished.is_connected(_on_assets_ready):
		AssetManager.sync_finished.connect(_on_assets_ready)
	set_process(false)


func _exit_tree() -> void:
	_seq += 1
	if AssetManager.sync_finished.is_connected(_on_assets_ready):
		AssetManager.sync_finished.disconnect(_on_assets_ready)


static func mount_on(host: Node, canvas_layer: int = -1) -> TutorialOverlay:
	if host == null or not is_instance_valid(host):
		return null
	var parent: Node = host
	if canvas_layer >= 0:
		var wrap: CanvasLayer = host.get_node_or_null("TutorialCoachLayer") as CanvasLayer
		if wrap == null:
			wrap = CanvasLayer.new()
			wrap.name = "TutorialCoachLayer"
			wrap.layer = canvas_layer
			host.add_child(wrap)
		parent = wrap
	var existing: TutorialOverlay = parent.get_node_or_null("TutorialOverlay") as TutorialOverlay
	if existing != null:
		return existing
	var packed: PackedScene = load("res://src/gameplay/tutorial/tutorial_overlay.tscn") as PackedScene
	if packed == null:
		return null
	var overlay: TutorialOverlay = packed.instantiate() as TutorialOverlay
	if overlay == null:
		return null
	overlay.name = "TutorialOverlay"
	parent.add_child(overlay)
	return overlay


func setup_dashboard(deploy_rect: Rect2) -> void:
	_mode = Mode.DASHBOARD
	_deploy_rect = deploy_rect
	_glow_rect = deploy_rect
	if _dim != null:
		_dim.visible = true
		_dim.color = Color(Palette.BG_DEEP, 0.58)
	if _cards != null:
		_cards.visible = false
	if _tap_catch != null:
		_tap_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_fonts()
	if _name_label != null:
		_name_label.text = tr("TUTORIAL_NPC_NAME")
	_play_line(tr("TUTORIAL_DASH_LINE"))
	set_process(true)
	queue_redraw()


func setup_explore() -> void:
	_mode = Mode.MATCH
	_deploy_rect = Rect2()
	_glow_rect = Rect2()
	_prime_coach(108, tr("TUTORIAL_DASH_DONE"), 0.42, true, false)


func setup_match() -> void:
	_mode = Mode.MATCH
	if _dim != null:
		_dim.visible = true
		_dim.color = Color(Palette.BG_DEEP, 0.28)
	if _cards != null:
		_cards.visible = false
	if _tap_catch != null:
		_tap_catch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_fonts()
	if _name_label != null:
		_name_label.text = tr("TUTORIAL_NPC_NAME")
	_beat = 0
	_show_beat()
	set_process(false)


func show_post_quiz() -> void:
	_glow_rect = Rect2()
	_prime_coach(99, tr("TUTORIAL_QUIZ_DONE"), 0.28, true, false)


func start_build_coach() -> void:
	_glow_rect = Rect2()
	_prime_coach(100, tr("TUTORIAL_BUILD_GO"), 0.0, false, true)


func coach_build_progress(placed: int) -> void:
	if _beat != 100:
		return
	if placed == 1:
		_play_line(tr("TUTORIAL_BUILD_ONE"))


func show_post_build() -> void:
	_glow_rect = Rect2()
	_prime_coach(101, tr("TUTORIAL_BUILD_DONE"), 0.0, false, true)


func show_post_defend() -> void:
	_glow_rect = Rect2()
	_prime_coach(102, tr("TUTORIAL_DEFEND_DONE"), 0.28, true, false)


func show_results() -> void:
	PlayerManager.grant_tutorial_capacity_rank()
	_glow_rect = Rect2()
	_prime_coach(103, tr("TUTORIAL_RESULTS"), 0.28, true, false)


func setup_upgrade(glow_rect: Rect2) -> void:
	_glow_rect = glow_rect
	_prime_coach(104, tr("TUTORIAL_UPGRADE_BUY"), 0.18, false, true)
	set_process(glow_rect.size.x >= 8.0)
	queue_redraw()


func show_fail_lock() -> void:
	_glow_rect = Rect2()
	set_process(false)
	queue_redraw()
	_prime_coach(105, tr("TUTORIAL_FAIL_LOCK"), 0.42, true, false)


func show_upgrade_owned() -> void:
	_glow_rect = Rect2()
	set_process(false)
	queue_redraw()
	_prime_coach(110, tr("TUTORIAL_UPGRADE_DONE"), 0.28, true, false)


func setup_lesson() -> void:
	_glow_rect = Rect2()
	_prime_coach(106, tr("TUTORIAL_LESSON_GO"), 0.42, true, false)


func show_lesson_done() -> void:
	_glow_rect = Rect2()
	_prime_coach(107, tr("TUTORIAL_LESSON_DONE"), 0.42, true, false)


func set_glow_rect(rect: Rect2) -> void:
	_glow_rect = rect
	set_process(rect.size.x >= 8.0)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _glow_rect.size.x < 8.0:
		return
	var local_pos: Vector2 = _glow_rect.position - get_global_rect().position
	var local_rect := Rect2(local_pos, _glow_rect.size)
	var pulse: float = 0.45 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
	draw_rect(local_rect.grow(6.0), Color(Palette.CYAN_400, pulse), false, 3.0)


func _gui_input(event: InputEvent) -> void:
	if _mode != Mode.DASHBOARD:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _deploy_rect.has_point(mouse.global_position):
		deploy_requested.emit()
		accept_event()


func _on_catch_gui(event: InputEvent) -> void:
	_gui_input(event)


func _on_npc_gui(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _typing:
		_finish_line()
		accept_event()


func _on_assets_ready(_ok: bool) -> void:
	if not _alive() or _expr_id.is_empty():
		return
	_set_expression(_expr_id)


func _show_beat() -> void:
	match _beat:
		0:
			if _cards != null:
				_cards.visible = false
			_play_line(tr("TUTORIAL_INTRO_1"))
		1:
			if _cards != null:
				_cards.visible = true
			_play_line(tr("TUTORIAL_INTRO_2"))
		2:
			if _cards != null:
				_cards.visible = true
			_play_line(tr("TUTORIAL_PHASE_QUIZ"))
		3:
			if _cards != null:
				_cards.visible = true
			_play_line(tr("TUTORIAL_PHASE_BUILD"))
		4:
			if _cards != null:
				_cards.visible = true
			_play_line(tr("TUTORIAL_PHASE_DEFEND"))
		_:
			if _cards != null:
				_cards.visible = true
			_play_line(tr("TUTORIAL_PHASE_HOLD"))


func _play_line(line: String) -> void:
	_seq += 1
	var token: int = _seq
	_full_line = line
	if _body_label != null:
		_body_label.text = ""
	_typing = true
	if _choice_list != null:
		_choice_list.visible = false
	_kill_tweens()
	if line.is_empty():
		_typing = false
		_set_expression(EXPR_SMILE)
		_present_choices()
		return
	var step: float = TYPE_SEC_PER_CHAR
	for i in line.length():
		if token != _seq or not _alive():
			return
		_tick_talk(i)
		if _body_label != null:
			_body_label.text = line.substr(0, i + 1)
		await get_tree().create_timer(step).timeout
	if token != _seq or not _alive():
		return
	_typing = false
	_set_expression(EXPR_SMILE)
	_present_choices()


func _finish_line() -> void:
	_seq += 1
	_typing = false
	if _body_label != null:
		_body_label.text = _full_line
	_set_expression(EXPR_SMILE)
	_present_choices()


func _tick_talk(char_index: int) -> void:
	if char_index % TALK_SWAP_CHARS != 0:
		return
	var mouth_open: bool = (char_index / TALK_SWAP_CHARS) % 2 == 0
	_set_expression(EXPR_TALK if mouth_open else EXPR_CALM)


func _present_choices() -> void:
	if not _alive() or _choice_list == null:
		return
	_clear_choices()
	if _typing:
		_choice_list.visible = false
		return
	if _mode == Mode.DASHBOARD:
		_add_choice(tr("TUTORIAL_CHOICE_DEPLOY"), &"deploy")
		_choice_list.visible = true
		return
	if _beat <= 4:
		_add_choice(tr("TUTORIAL_NEXT"), &"next")
		_choice_list.visible = true
		return
	if _beat == 5:
		_add_choice(tr("TUTORIAL_CHOICE_QUIZ"), &"quiz")
		_choice_list.visible = true
		return
	if _beat == 99:
		_add_choice(tr("TUTORIAL_CHOICE_BUILD"), &"build")
		_choice_list.visible = true
		return
	if _beat == 101:
		_add_choice(tr("TUTORIAL_CHOICE_DEFEND"), &"defend")
		_choice_list.visible = true
		return
	if _beat == 102:
		_add_choice(tr("TUTORIAL_NEXT"), &"results")
		_choice_list.visible = true
		return
	if _beat == 103:
		_add_choice(tr("TUTORIAL_CHOICE_UPGRADE"), &"upgrades")
		_choice_list.visible = true
		return
	if _beat == 110:
		_add_choice(tr("TUTORIAL_NEXT"), &"failock")
		_choice_list.visible = true
		return
	if _beat == 105:
		_add_choice(tr("TUTORIAL_CHOICE_LESSON"), &"lesson")
		_choice_list.visible = true
		return
	if _beat == 106:
		_add_choice(tr("TUTORIAL_CHOICE_START_FILE"), &"file")
		_choice_list.visible = true
		return
	if _beat == 107:
		_add_choice(tr("TUTORIAL_CHOICE_DASH"), &"dashboard")
		_choice_list.visible = true
		return
	if _beat == 108:
		_add_choice(tr("TUTORIAL_CHOICE_EXPLORE"), &"dismiss")
		_choice_list.visible = true
		return
	_choice_list.visible = false


func _add_choice(label: String, id: StringName) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0.0, 44.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_ALL
	btn.text = label
	btn.pressed.connect(_on_choice.bind(id))
	_style_choice(btn)
	_choice_list.add_child(btn)


func _clear_choices() -> void:
	if _choice_list == null:
		return
	while _choice_list.get_child_count() > 0:
		var child: Node = _choice_list.get_child(0)
		_choice_list.remove_child(child)
		child.free()


func _on_choice(id: StringName) -> void:
	if _typing:
		_finish_line()
		return
	match id:
		&"deploy":
			deploy_requested.emit()
		&"quiz":
			quiz_requested.emit()
		&"build":
			build_requested.emit()
		&"defend":
			defend_requested.emit()
		&"results":
			show_results()
		&"upgrades":
			upgrades_requested.emit()
		&"failock":
			show_fail_lock()
		&"lesson":
			lesson_requested.emit()
		&"file":
			file_requested.emit()
		&"dashboard":
			dashboard_requested.emit()
		&"dismiss":
			dismiss_requested.emit()
		&"next":
			if _mode != Mode.MATCH:
				return
			_beat += 1
			_show_beat()


func _set_expression(asset_id: String) -> void:
	_expr_id = asset_id
	if _face_art == null or not is_instance_valid(_face_art):
		return
	AssetManager.bind_texture(_face_art, asset_id)
	_face_art.visible = _portrait_allowed and _face_art.texture != null


func _alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _prime_coach(beat: int, line: String, dim_alpha: float, block_mouse: bool, build_shift: bool) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if block_mouse else Control.MOUSE_FILTER_IGNORE
	_mode = Mode.MATCH
	_beat = beat
	_portrait_allowed = not build_shift
	_layout_for_build(build_shift)
	if _dim != null:
		_dim.visible = dim_alpha > 0.0
		_dim.color = Color(Palette.BG_DEEP, dim_alpha)
	if _cards != null:
		_cards.visible = false
	if _tap_catch != null:
		_tap_catch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_fonts()
	if _name_label != null:
		_name_label.text = tr("TUTORIAL_NPC_NAME")
	_play_line(line)
	set_process(_glow_rect.size.x >= 8.0)


func _layout_for_build(active: bool) -> void:
	var box: PanelContainer = _dialogue_box
	if box != null:
		box.offset_left = 236.0 if active else 24.0
	var tag: PanelContainer = get_node_or_null("NameTag") as PanelContainer
	if tag != null:
		tag.offset_left = 252.0 if active else 44.0
		tag.offset_right = 484.0 if active else 276.0
	if _face_art != null:
		_face_art.visible = (not active) and _portrait_allowed and _face_art.texture != null


func _style_chrome() -> void:
	if _dialogue_box != null:
		_dialogue_box.add_theme_stylebox_override("panel", _rpg_box(BOX_FILL, BOX_BORDER, 10, 6, 6.0, 6.0))
	var inner: PanelContainer = get_node_or_null("DialogueBox/DialogueInner") as PanelContainer
	if inner != null:
		inner.add_theme_stylebox_override("panel", _rpg_box(BOX_FILL, BOX_INNER, 6, 2, 16.0, 12.0))
	var tag: PanelContainer = get_node_or_null("NameTag") as PanelContainer
	if tag != null:
		tag.add_theme_stylebox_override("panel", _rpg_box(TAG_FILL, BOX_BORDER, 8, 5, 14.0, 8.0))


func _style_choice(btn: Button) -> void:
	var normal: StyleBoxFlat = _rpg_box(BOX_FILL, BOX_BORDER, 8, 5, 16.0, 10.0)
	var hover: StyleBoxFlat = _rpg_box(BOX_FILL, HOVER_BORDER, 8, 6, 16.0, 10.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", TEXT_WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 16)
	if _pixel_font != null:
		btn.add_theme_font_override("font", _pixel_font)


func _rpg_box(fill: Color, border: Color, radius: int, border_w: int, pad_x: float, pad_y: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


func _apply_fonts() -> void:
	if _name_label != null:
		_apply_label(_name_label, Palette.INK, 16)
	if _body_label != null:
		_apply_label(_body_label, TEXT_WHITE, 18)


func _bind_nodes() -> void:
	_dim = get_node_or_null("Dim") as ColorRect
	_cards = get_node_or_null("PhaseCards") as Control
	_dialogue_box = get_node_or_null("DialogueBox") as PanelContainer
	_face_art = get_node_or_null("FaceArt") as TextureRect
	_name_label = get_node_or_null("NameTag/NpcName") as Label
	_body_label = get_node_or_null("DialogueBox/DialogueInner/NpcBody") as Label
	_tap_catch = get_node_or_null("TapCatch") as Control
	_choice_list = get_node_or_null("ChoiceList") as VBoxContainer


func _apply_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()


func _load_font() -> void:
	var file: FontFile = _load_font_file(FONT_PATH)
	if file == null:
		file = _load_font_file(FONT_FALLBACK_PATH)
	if file != null:
		_pixel_font = file


func _load_font_file(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var file: FontFile = load(path) as FontFile
	if file == null:
		return null
	file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return file
