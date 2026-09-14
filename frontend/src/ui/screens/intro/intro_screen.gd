extends BaseScreen
## Original title card, preceded by a separate short intro animation.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

const Cinematic = preload("res://src/ui/screens/intro/signal_intro.tscn")
const LOGO_BOB_PX := 14.0
const LOGO_BOB_SEC := 2.0
const PREVIEW_DIM_A := 0.14

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


var _active := false
var _cinematic: Control

func _ready() -> void:
	_load_font()
	_start_button.pressed.connect(_on_start_pressed)
	_cinematic = Cinematic.instantiate()
	add_child(_cinematic)
	_cinematic.finished.connect(_show_original_title)
	get_viewport().size_changed.connect(_apply_preview_art)

func on_enter(_args: Dictionary) -> void:
	_seq += 1
	_active = true
	_kill_tweens()
	_start_locked = true
	_start_button.disabled = true
	_start_button.focus_mode = Control.FOCUS_NONE
	_apply_copy()
	_apply_preview_art()
	AssetManager.bind_texture(_logo, "ui_logo")
	_blackout.visible = false
	_flash.visible = false
	_story_layer.visible = false
	_logo_layer.visible = false
	_cta_layer.visible = false
	_cinematic.play()
	# Original title textures load in parallel, never delaying the cinematic.
	if AssetManager.get_texture("ui_intro_preview") == null or _logo.texture == null:
		_refresh_title_assets(_seq)

func _refresh_title_assets(token: int) -> void:
	await AssetManager.ensure_ready()
	if not is_inside_tree() or not _active or token != _seq:
		return
	_apply_preview_art()
	AssetManager.bind_texture(_logo, "ui_logo")

func _show_original_title() -> void:
	if not _active:
		return
	_cinematic.stop()
	_cinematic.hide()
	_logo_layer.visible = true
	_logo_layer.modulate.a = 1.0
	_logo_bob.offset_top = 0.0
	_logo_bob.offset_bottom = 0.0
	_cta_layer.visible = true
	_cta_layer.modulate.a = 1.0
	_cta_layer.offset_top = 0.0
	_cta_layer.offset_bottom = 150.0
	_start_locked = false
	_start_button.disabled = false
	_start_button.focus_mode = Control.FOCUS_ALL
	_start_button.grab_focus()
	_kill_tweens()
	_start_logo_bob()

func on_resume() -> void:
	_active = true
	_show_original_title()

func on_exit() -> void:
	_seq += 1
	_active = false
	_cinematic.stop()
	_kill_tweens()

func can_go_back() -> bool:
	return false

func _on_start_pressed() -> void:
	if _start_locked or not _active:
		return
	_start_locked = true
	_start_button.disabled = true
	_kill_tweens()
	var token := _seq
	await TransitionManager.fade_to_black()
	if not is_inside_tree() or not _active or token != _seq:
		return
	await Router.open_splash_screen()

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


func _make_tween() -> Tween:
	var tween: Tween = create_tween()
	_tweens.append(tween)
	return tween


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
