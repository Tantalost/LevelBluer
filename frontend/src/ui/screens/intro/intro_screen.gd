extends BaseScreen
## Cinematic intro: black hold, art reveal, Ken Burns pan with story cards, then logo.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const ART_PATH := "res://assets/ui/intro_art.png"
const ART_FALLBACK := "res://assets/ui/dashboard.png"

const BLACK_HOLD_SEC := 2.0
const FADE_IN_SEC := 0.35
const PAN_SEC := 5.0
const ART_HEIGHT_MUL := 2.6
const LOGO_FADE_SEC := 0.85
const LOGO_BOB_PX := 14.0
const LOGO_BOB_SEC := 2.0
const STORY_KEYS: PackedStringArray = [
	"INTRO_STORY_1",
	"INTRO_STORY_2",
	"INTRO_STORY_3",
	"INTRO_STORY_4",
	"INTRO_STORY_5",
]

@onready var _art_clip: Control = %ArtClip
@onready var _art: TextureRect = %Art
@onready var _blackout: ColorRect = %Blackout
@onready var _story_layer: Control = %StoryLayer
@onready var _logo_layer: Control = %LogoLayer
@onready var _logo_bob: Control = %LogoBob
@onready var _cta_layer: Control = %CtaLayer
@onready var _logo: TextureRect = %Logo
@onready var _start_button: Button = %StartButton
@onready var _tagline: Label = %TaglineLabel
@onready var _press_hint: Label = %PressHintLabel

var _pixel_font: Font
var _seq: int = 0
var _start_locked: bool = false
var _tweens: Array[Tween] = []
var _story_boxes: Array[PanelContainer] = []
var _story_labels: Array[Label] = []


func _ready() -> void:
	_load_font()
	_start_button.pressed.connect(_on_start_pressed)
	_collect_story_nodes()
	_style_story_boxes()
	_load_art()


func on_enter(_args: Dictionary) -> void:
	_seq += 1
	var token: int = _seq
	_start_locked = true
	_start_button.disabled = true
	_apply_copy()
	_reset_visuals()
	await get_tree().process_frame
	if not _still(token):
		return
	_layout_art()
	await _play_sequence(token)


func on_exit() -> void:
	_seq += 1
	_kill_tweens()


func can_go_back() -> bool:
	return false


func _play_sequence(token: int) -> void:
	await get_tree().create_timer(BLACK_HOLD_SEC).timeout
	if not _still(token):
		return
	await _tween_fade(_blackout, 0.0, FADE_IN_SEC)
	if not _still(token):
		return
	var pan: Tween = _start_art_pan()
	await _play_story(token)
	if not _still(token):
		return
	if pan.is_valid() and pan.is_running():
		await pan.finished
	if not _still(token):
		return
	await _tween_fade(_story_layer, 0.0, 0.35)
	if not _still(token):
		return
	_logo_layer.visible = true
	await _tween_fade(_logo_layer, 1.0, LOGO_FADE_SEC)
	if not _still(token):
		return
	_start_logo_bob()
	_cta_layer.visible = true
	_start_locked = false
	_start_button.disabled = false
	await _tween_fade(_cta_layer, 1.0, 0.4)


func _play_story(token: int) -> void:
	var slot: float = PAN_SEC / float(STORY_KEYS.size())
	for i in _story_boxes.size():
		if not _still(token):
			return
		var box: PanelContainer = _story_boxes[i]
		box.visible = true
		box.modulate.a = 0.0
		var appear: Tween = _make_tween()
		appear.tween_property(box, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await appear.finished
		if not _still(token):
			return
		var line: String = tr(STORY_KEYS[i])
		var type_sec: float = maxf(slot - 0.28, 0.45)
		await _typewrite(_story_labels[i], line, type_sec, token)


func _typewrite(label: Label, full: String, duration: float, token: int) -> void:
	label.text = ""
	if full.is_empty():
		return
	var chars: int = full.length()
	var step: float = duration / float(chars)
	for i in chars:
		if not _still(token):
			return
		label.text = full.substr(0, i + 1)
		await get_tree().create_timer(step).timeout


func _start_art_pan() -> Tween:
	var view_h: float = get_viewport_rect().size.y
	var travel: float = maxf(_art.size.y - view_h, 0.0)
	_art.position.y = 0.0
	var pan: Tween = _make_tween()
	pan.tween_property(_art, "position:y", -travel, PAN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return pan


func _layout_art() -> void:
	var view := _art_clip.size
	if view.x < 1.0 or view.y < 1.0:
		view = get_viewport_rect().size
	_art.position = Vector2.ZERO
	_art.size = Vector2(view.x, view.y * ART_HEIGHT_MUL)


func _load_art() -> void:
	var path := ART_PATH if ResourceLoader.exists(ART_PATH) else ART_FALLBACK
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_art.texture = tex


func _reset_visuals() -> void:
	_kill_tweens()
	_blackout.modulate.a = 1.0
	_blackout.visible = true
	_story_layer.modulate.a = 1.0
	_logo_layer.modulate.a = 0.0
	_logo_layer.visible = false
	_logo_bob.offset_top = 0.0
	_logo_bob.offset_bottom = 0.0
	_cta_layer.modulate.a = 0.0
	_cta_layer.visible = false
	_art.position.y = 0.0
	for i in _story_boxes.size():
		_story_boxes[i].visible = false
		_story_boxes[i].modulate.a = 0.0
		_story_labels[i].text = ""


func _apply_copy() -> void:
	_tagline.text = tr("INTRO_TAGLINE")
	_start_button.text = tr("INTRO_START_GAME")
	_press_hint.text = tr("INTRO_PRESS_HINT")
	_apply_label(_tagline, Palette.CYAN_400, 11)
	_apply_label(_press_hint, Color(Palette.CYAN_400, 0.45), 11)
	if _pixel_font != null:
		_start_button.add_theme_font_override("font", _pixel_font)
	_start_button.add_theme_font_size_override("font_size", 16)
	_start_button.add_theme_color_override("font_color", Palette.CREAM)


func _collect_story_nodes() -> void:
	_story_boxes.clear()
	_story_labels.clear()
	for i in STORY_KEYS.size():
		var box: PanelContainer = _story_layer.get_node("StoryBox%d" % (i + 1)) as PanelContainer
		var label: Label = box.get_node("StoryLabel") as Label
		_story_boxes.append(box)
		_story_labels.append(label)


func _style_story_boxes() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(Palette.NAVY_900, 0.82)
	panel.border_color = Palette.CREAM
	panel.set_border_width_all(2)
	panel.content_margin_left = 16.0
	panel.content_margin_right = 16.0
	panel.content_margin_top = 14.0
	panel.content_margin_bottom = 14.0
	for i in _story_labels.size():
		_story_boxes[i].add_theme_stylebox_override("panel", panel)
		_story_labels[i].text = ""
		_apply_label(_story_labels[i], Palette.CREAM, 11)


func _start_logo_bob() -> void:
	_logo.pivot_offset = _logo.size * 0.5
	var bob: Tween = _make_tween()
	bob.set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_logo_bob, "offset_top", -LOGO_BOB_PX, LOGO_BOB_SEC)
	bob.parallel().tween_property(_logo_bob, "offset_bottom", -LOGO_BOB_PX, LOGO_BOB_SEC)
	bob.tween_property(_logo_bob, "offset_top", 0.0, LOGO_BOB_SEC)
	bob.parallel().tween_property(_logo_bob, "offset_bottom", 0.0, LOGO_BOB_SEC)


func _on_start_pressed() -> void:
	if _start_locked:
		return
	_start_locked = true
	_start_button.disabled = true
	_kill_tweens()
	await TransitionManager.fade_to_black()
	var has_session: bool = await AuthService.restore_session()
	if has_session:
		await Router.open_splash_screen()
	else:
		await SettingsService.load_local()
		await SaveService.load_local()
		await ContentDB.load_all()
		await Router.open_login_screen()


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
