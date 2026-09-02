extends BaseScreen
## Cinematic intro: pan with story lines, logo lockup, then flash into the title card.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

const BLACK_HOLD_SEC := 2.0
const FADE_IN_SEC := 0.35
const REVEAL_HOLD_SEC := 0.3
const PAN_SEC := 5.0
const LINE_FADE_SEC := 0.22
const CTA_SLIDE_SEC := 1.15
const CTA_SLIDE_PX := 90.0
const HOLD_BEFORE_FLASH_SEC := 0.35
const FLASH_IN_SEC := 0.12
const FLASH_HOLD_SEC := 0.08
const FLASH_OUT_SEC := 0.55
const LOGO_BOB_PX := 14.0
const LOGO_BOB_SEC := 2.0
const PREVIEW_DIM_A := 0.14
const STORY_KEYS: PackedStringArray = [
	"INTRO_STORY_1",
	"INTRO_STORY_2",
	"INTRO_STORY_3",
]

@onready var _art_clip: Control = %ArtClip
@onready var _art: TextureRect = %Art
@onready var _dim: ColorRect = $Dim
@onready var _blackout: ColorRect = %Blackout
@onready var _flash: ColorRect = %WhiteFlash
@onready var _story_layer: Control = %StoryLayer
@onready var _story_text: Label = %StoryText
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


func _ready() -> void:
	_load_font()
	_start_button.pressed.connect(_on_start_pressed)
	_load_art()


func on_enter(_args: Dictionary) -> void:
	_seq += 1
	var token: int = _seq
	_start_locked = true
	_start_button.disabled = true
	_apply_copy()
	_reset_visuals()
	_load_art()
	if not _intro_assets_ready():
		await AssetManager.ensure_ready()
		if not _still(token):
			return
		_load_art()
	await get_tree().process_frame
	if not _still(token):
		return
	_layout_cinematic_art()
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
	await get_tree().create_timer(REVEAL_HOLD_SEC).timeout
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
	await get_tree().create_timer(HOLD_BEFORE_FLASH_SEC).timeout
	if not _still(token):
		return
	await _play_title_flash(token)
	if not _still(token):
		return
	await _play_cta_slide(token)
	if not _still(token):
		return
	_start_locked = false
	_start_button.disabled = false


func _play_story(token: int) -> void:
	var count: int = STORY_KEYS.size()
	if count <= 0:
		return
	var slot: float = PAN_SEC / float(count)
	var hold: float = maxf(slot - LINE_FADE_SEC * 2.0, 0.4)
	for i in count:
		if not _still(token):
			return
		_story_text.text = tr(STORY_KEYS[i])
		_story_text.modulate.a = 0.0
		await _tween_fade(_story_text, 1.0, LINE_FADE_SEC)
		if not _still(token):
			return
		await get_tree().create_timer(hold).timeout
		if not _still(token):
			return
		if i < count - 1:
			await _tween_fade(_story_text, 0.0, LINE_FADE_SEC)


func _play_cta_slide(token: int) -> void:
	await get_tree().process_frame
	if not _still(token):
		return
	var height: float = maxf(_cta_layer.size.y, 150.0)
	_cta_layer.visible = true
	_cta_layer.modulate.a = 0.0
	_cta_layer.offset_top = -CTA_SLIDE_PX
	_cta_layer.offset_bottom = height - CTA_SLIDE_PX
	var slide: Tween = _make_tween()
	slide.set_parallel(true)
	slide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	slide.tween_property(_cta_layer, "modulate:a", 1.0, CTA_SLIDE_SEC)
	slide.tween_property(_cta_layer, "offset_top", 0.0, CTA_SLIDE_SEC)
	slide.tween_property(_cta_layer, "offset_bottom", height, CTA_SLIDE_SEC)
	await slide.finished


func _play_title_flash(token: int) -> void:
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	await _tween_color_alpha(_flash, 1.0, FLASH_IN_SEC)
	if not _still(token):
		return
	_apply_preview_art()
	_story_layer.modulate.a = 0.0
	_logo_layer.visible = true
	_logo_layer.modulate.a = 1.0
	_cta_layer.modulate.a = 0.0
	await get_tree().create_timer(FLASH_HOLD_SEC).timeout
	if not _still(token):
		return
	await _tween_color_alpha(_flash, 0.0, FLASH_OUT_SEC)
	if not _still(token):
		return
	_start_logo_bob()


func _start_art_pan() -> Tween:
	var view_h: float = _art_clip.size.y
	if view_h < 1.0:
		view_h = get_viewport_rect().size.y
	var travel: float = maxf(_art.size.y - view_h, 0.0)
	_art.position.y = 0.0
	var pan: Tween = _make_tween()
	pan.tween_property(_art, "position:y", -travel, PAN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return pan


func _layout_cinematic_art() -> void:
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var view := _clip_size()
	var aspect: float = _texture_aspect(_art.texture)
	var art_w: float = view.x
	var art_h: float = art_w * aspect
	if art_h < view.y * 1.15:
		art_h = view.y * 1.4
		art_w = art_h / aspect if aspect > 0.001 else view.x
	_art.position = Vector2((view.x - art_w) * 0.5, 0.0)
	_art.size = Vector2(art_w, art_h)


func _apply_preview_art() -> void:
	AssetManager.bind_texture(_art, "ui_intro_preview")
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var view := _clip_size()
	_art.position = Vector2.ZERO
	_art.size = view
	_dim.color = Color(Palette.BG_DEEP, PREVIEW_DIM_A)


func _clip_size() -> Vector2:
	var view := _art_clip.size
	if view.x < 1.0 or view.y < 1.0:
		return get_viewport_rect().size
	return view


func _texture_aspect(tex: Texture2D) -> float:
	if tex == null or tex.get_width() <= 0:
		return 1.0
	return float(tex.get_height()) / float(tex.get_width())


func _intro_assets_ready() -> bool:
	return (
		AssetManager.get_texture("ui_intro") != null
		and AssetManager.get_texture("ui_logo") != null
		and AssetManager.get_texture("ui_intro_preview") != null
	)


func _load_art() -> void:
	AssetManager.bind_texture(_art, "ui_intro")
	AssetManager.bind_texture(_logo, "ui_logo")


func _reset_visuals() -> void:
	_kill_tweens()
	_blackout.color = Color(Palette.BG_DEEP, 1.0)
	_blackout.modulate.a = 1.0
	_blackout.visible = true
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_dim.color = Color(Palette.BG_DEEP, 0.28)
	_story_layer.modulate.a = 1.0
	_story_text.text = ""
	_story_text.modulate.a = 0.0
	_logo_layer.modulate.a = 0.0
	_logo_layer.visible = true
	_logo_bob.offset_top = 0.0
	_logo_bob.offset_bottom = 0.0
	_cta_layer.modulate.a = 0.0
	_cta_layer.visible = true
	_cta_layer.offset_top = -CTA_SLIDE_PX
	_art.position.y = 0.0
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _apply_copy() -> void:
	_tagline.text = tr("INTRO_TAGLINE")
	_start_button.text = tr("INTRO_START_GAME")
	_press_hint.text = tr("INTRO_PRESS_HINT")
	_apply_label(_tagline, Palette.CYAN_400, 14)
	_apply_label(_press_hint, Color(Palette.CYAN_400, 0.72), 13)
	_apply_label(_story_text, Palette.CREAM, 22)
	_story_text.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	_story_text.add_theme_constant_override("outline_size", 10)
	if _pixel_font != null:
		_start_button.add_theme_font_override("font", _pixel_font)
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.add_theme_color_override("font_color", Palette.CREAM)


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
	await Router.open_splash_screen()


func _tween_fade(node: CanvasItem, alpha: float, duration: float) -> void:
	var fade: Tween = _make_tween()
	fade.tween_property(node, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade.finished


func _tween_color_alpha(rect: ColorRect, alpha: float, duration: float) -> void:
	var fade: Tween = _make_tween()
	fade.tween_property(rect, "color:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
