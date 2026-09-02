extends BaseScreen
## Module 1 comic intro: panel 1 → 2 → 3, zoom out, then Start Module.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const MOVE_SEC := 0.7
const ZOOM_OUT_SEC := 1.05
const LINE_HOLD_SEC := 1.55
const LINE_FADE_SEC := 0.22
const TYPE_SEC := 0.7
const PANEL_ZOOM := 0.9
const DIALOGUE_KEYS: PackedStringArray = [
	"MODULE_INTRO_LINE_1",
	"MODULE_INTRO_LINE_2",
	"MODULE_INTRO_LINE_3",
]
## Normalized page rects: top-left, bottom-left, right horizontal panel.
const PANELS: Array[Rect2] = [
	Rect2(0.02, 0.03, 0.48, 0.46),
	Rect2(0.02, 0.51, 0.48, 0.46),
	Rect2(0.52, 0.12, 0.46, 0.76),
]

@onready var _art_clip: Control = %ArtClip
@onready var _art: TextureRect = %Art
@onready var _dialogue: Control = %DialogueBox
@onready var _portrait_art: TextureRect = %PortraitArt
@onready var _portrait_stub: Control = %PortraitStub
@onready var _dialogue_text: Label = %DialogueText
@onready var _start_button: Button = %StartButton
@onready var _skip_button: Button = %SkipButton

var _pixel_font: Font
var _module_index: int = 0
var _leaving: bool = false
var _seq: int = 0
var _view: Vector2 = Vector2.ZERO
var _fit_size: Vector2 = Vector2.ZERO
var _tweens: Array[Tween] = []


func _ready() -> void:
	_load_font()
	_start_button.pressed.connect(_on_start_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)


func on_enter(args: Dictionary) -> void:
	_seq += 1
	var token: int = _seq
	_leaving = false
	_module_index = clampi(int(args.get("module_index", 0)), 0, 4)
	visible = true
	_start_button.disabled = true
	_start_button.visible = false
	_start_button.modulate.a = 0.0
	_dialogue.modulate.a = 0.0
	_dialogue_text.text = ""
	_apply_copy()
	_refresh_skip()
	_load_art()
	if _art.texture == null:
		await AssetManager.ensure_ready()
		if not _still(token):
			return
		_load_art()
	await get_tree().process_frame
	if not _still(token):
		return
	_layout_page()
	await _play_sequence(token)


func on_exit() -> void:
	_seq += 1
	_kill_tweens()
	visible = false


func _play_sequence(token: int) -> void:
	if _art.texture == null:
		_show_start()
		return
	_apply_camera(_camera_for(PANELS[0]))
	for i in PANELS.size():
		if not _still(token):
			return
		if i > 0:
			await _tween_camera(_camera_for(PANELS[i]), MOVE_SEC)
			if not _still(token):
				return
		await _play_line(tr(DIALOGUE_KEYS[i]), token)
		if not _still(token):
			return
	await _tween_fade(_dialogue, 0.0, LINE_FADE_SEC)
	if not _still(token):
		return
	await _tween_camera(_camera_full(), ZOOM_OUT_SEC)
	if not _still(token):
		return
	_show_start()
	await _tween_fade(_start_button, 1.0, 0.35)


func _play_line(line: String, token: int) -> void:
	_dialogue_text.text = ""
	_dialogue.modulate.a = 0.0
	await _tween_fade(_dialogue, 1.0, LINE_FADE_SEC)
	if not _still(token):
		return
	await _typewrite(line, token)
	if not _still(token):
		return
	await get_tree().create_timer(LINE_HOLD_SEC).timeout
	if not _still(token):
		return
	await _tween_fade(_dialogue, 0.0, LINE_FADE_SEC)


func _typewrite(full: String, token: int) -> void:
	if full.is_empty():
		return
	var step: float = TYPE_SEC / float(full.length())
	for i in full.length():
		if not _still(token):
			return
		_dialogue_text.text = full.substr(0, i + 1)
		await get_tree().create_timer(step).timeout


func _layout_page() -> void:
	_view = _art_clip.size
	if _view.x < 1.0 or _view.y < 1.0:
		_view = get_viewport_rect().size
	var tex: Texture2D = _art.texture
	if tex == null or tex.get_width() <= 0:
		_fit_size = _view
		return
	var tex_size := Vector2(float(tex.get_width()), float(tex.get_height()))
	var scale: float = minf(_view.x / tex_size.x, _view.y / tex_size.y)
	_fit_size = tex_size * scale


func _camera_for(panel: Rect2) -> Dictionary:
	var panel_px := Vector2(panel.size.x * _fit_size.x, panel.size.y * _fit_size.y)
	var zoom: float = 1.0
	if panel_px.x > 1.0 and panel_px.y > 1.0:
		zoom = minf(_view.x / panel_px.x, _view.y / panel_px.y) * PANEL_ZOOM
	var size: Vector2 = _fit_size * zoom
	var center: Vector2 = (panel.position + panel.size * 0.5) * size
	return {
		"position": _view * 0.5 - center,
		"size": size,
	}


func _camera_full() -> Dictionary:
	return {
		"position": (_view - _fit_size) * 0.5,
		"size": _fit_size,
	}


func _apply_camera(cam: Dictionary) -> void:
	_art.position = cam["position"] as Vector2
	_art.size = cam["size"] as Vector2


func _tween_camera(cam: Dictionary, duration: float) -> void:
	var move: Tween = _make_tween()
	move.set_parallel(true)
	move.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_property(_art, "position", cam["position"] as Vector2, duration)
	move.tween_property(_art, "size", cam["size"] as Vector2, duration)
	await move.finished


func _load_art() -> void:
	AssetManager.bind_texture(_art, "ui_module1_intro")
	_refresh_portrait()


func _refresh_portrait() -> void:
	var has_art: bool = _portrait_art.texture != null
	_portrait_art.visible = has_art
	_portrait_stub.visible = not has_art


func _apply_copy() -> void:
	_start_button.text = tr("MODULE_INTRO_START")
	_skip_button.text = tr("MODULE_INTRO_SKIP")
	_apply_label(_dialogue_text, Palette.CREAM, 14)
	if _pixel_font != null:
		_start_button.add_theme_font_override("font", _pixel_font)
		_skip_button.add_theme_font_override("font", _pixel_font)
	_start_button.add_theme_font_size_override("font_size", 18)
	_start_button.add_theme_color_override("font_color", Palette.CREAM)
	_skip_button.add_theme_font_size_override("font_size", 11)
	_skip_button.add_theme_color_override("font_color", Palette.CYAN_400)


func _show_start() -> void:
	PlayerManager.mark_module_intro_seen(_module_id())
	_refresh_skip()
	_start_button.visible = true
	_start_button.disabled = false


func _refresh_skip() -> void:
	var can_skip: bool = PlayerManager.has_seen_module_intro(_module_id())
	_skip_button.visible = can_skip
	_skip_button.disabled = not can_skip


func _module_id() -> String:
	var modules: Array[Dictionary] = LessonCatalog.modules()
	if _module_index < 0 or _module_index >= modules.size():
		return "mod_01"
	return str(modules[_module_index].get("id", "mod_01"))


func _on_start_pressed() -> void:
	await _leave_to_stages()


func _on_skip_pressed() -> void:
	await _leave_to_stages()


func _leave_to_stages() -> void:
	if _leaving:
		return
	_leaving = true
	_start_button.disabled = true
	_skip_button.disabled = true
	PlayerManager.mark_module_intro_seen(_module_id())
	_kill_tweens()
	await Router.replace(&"module_stages", {"module_index": _module_index})


func _tween_fade(node: CanvasItem, alpha: float, duration: float) -> void:
	var fade: Tween = _make_tween()
	fade.tween_property(node, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade.finished


func _make_tween() -> Tween:
	var tween: Tween = create_tween()
	_tweens.append(tween)
	return tween


func _still(token: int) -> bool:
	return token == _seq and is_inside_tree()


func _kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()


func _apply_label(label: Label, color: Color, font_size: int) -> void:
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
