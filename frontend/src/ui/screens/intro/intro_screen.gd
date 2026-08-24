extends BaseScreen
## Title screen — LEVEL BLUE logo, tagline, and START GAME.
## Matches the React Native IntroScreen layout and motion.

const CYAN := Color("#00d4ff")
const GOLD := Color("#f0ce98")
const NAVY := Color("#0a0d1a")

const DOT_POSITIONS: Array[Dictionary] = [
	{"anchor_x": 0.12, "anchor_y": 0.20, "delay": 0.0, "range": 12.0},
	{"anchor_x": 0.90, "anchor_y": 0.35, "delay": 0.7, "range": 8.0},
	{"anchor_x": 0.08, "anchor_y": 0.65, "delay": 1.4, "range": 14.0},
	{"anchor_x": 0.85, "anchor_y": 0.55, "delay": 0.3, "range": 6.0},
]

@onready var _background: TextureRect = %Background
@onready var _logo: TextureRect = %Logo
@onready var _logo_bob: Control = %LogoBob
@onready var _start_button: Button = %StartButton
@onready var _button_glow: ColorRect = %ButtonGlow
@onready var _particles: Control = %Particles
@onready var _tagline: Label = %TaglineLabel
@onready var _press_hint: Label = %PressHintLabel

var _loop_tweens: Array[Tween] = []
var _float_tween: Tween = null
var _start_locked: bool = false


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)


func on_enter(_args: Dictionary) -> void:
	modulate.a = 1.0
	_start_locked = false
	_start_button.disabled = false
	_tagline.text = tr("INTRO_TAGLINE")
	_start_button.text = tr("INTRO_START_GAME")
	_press_hint.text = tr("INTRO_PRESS_HINT")
	_build_particles()
	await get_tree().process_frame
	_background.pivot_offset = _background.size * 0.5
	_start_animations()


func on_exit() -> void:
	_stop_animations()
	for child in _particles.get_children():
		child.queue_free()


func can_go_back() -> bool:
	return false


func _on_start_pressed() -> void:
	if _start_locked:
		return
	_start_locked = true
	_start_button.disabled = true
	_stop_animations()

	await TransitionManager.fade_to_black()

	var has_session: bool = await AuthService.restore_session()
	if has_session:
		await Router.open_splash_screen()
	else:
		await SettingsService.load_local()
		await SaveService.load_local()
		await ContentDB.load_all()
		await Router.open_login_screen()


func _build_particles() -> void:
	for child in _particles.get_children():
		child.queue_free()

	for spec in DOT_POSITIONS:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 4)
		dot.color = CYAN
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particles.add_child(dot)
		call_deferred("_place_particle", dot, spec)


func _place_particle(dot: ColorRect, spec: Dictionary) -> void:
	var view := get_viewport_rect().size
	dot.position = Vector2(
		view.x * spec["anchor_x"] - 2.0,
		view.y * spec["anchor_y"],
	)
	_animate_particle(dot, spec["delay"], spec["range"])


func _animate_particle(dot: ColorRect, delay: float, range_px: float) -> void:
	var home_y := dot.position.y
	dot.modulate.a = 0.3

	var loop := create_tween().set_loops()
	if delay > 0.0:
		loop.tween_interval(delay)
	loop.tween_property(dot, "position:y", home_y - range_px, 2.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(dot, "modulate:a", 0.8, 1.4)
	loop.tween_property(dot, "position:y", home_y, 2.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(dot, "modulate:a", 0.3, 1.4)
	_loop_tweens.append(loop)


func _start_animations() -> void:
	_stop_animations()
	_start_floating_animation()

	# Background breathe — scale 1.0 ↔ 1.05 over 10 s.
	var bg_breathe := create_tween().set_loops()
	bg_breathe.tween_property(_background, "scale", Vector2(1.05, 1.05), 10.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bg_breathe.tween_property(_background, "scale", Vector2.ONE, 10.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tweens.append(bg_breathe)

	# Button border glow pulse.
	var glow_pulse := create_tween().set_loops()
	glow_pulse.tween_property(_button_glow, "modulate:a", 1.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_pulse.tween_property(_button_glow, "modulate:a", 0.4, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tweens.append(glow_pulse)


func _start_floating_animation() -> void:
	# Logo is full-rect inside LogoBob. Tween the bob's offset, not position:y —
	# anchored TextureRects ignore position.y.
	var original_top: float = _logo_bob.offset_top
	var float_distance: float = 15.0
	var float_duration: float = 2.0
	_float_tween = create_tween().set_loops()
	_float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(_logo_bob, "offset_top", original_top - float_distance, float_duration)
	_float_tween.tween_property(_logo_bob, "offset_top", original_top, float_duration)
	_loop_tweens.append(_float_tween)
	_logo.pivot_offset = _logo.size * 0.5


func _stop_animations() -> void:
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
	for tween in _loop_tweens:
		if tween != null and tween.is_running():
			tween.kill()
	_loop_tweens.clear()
