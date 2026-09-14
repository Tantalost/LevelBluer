extends BaseScreen
## A 1.8-second signal-defense vignette, then an immediately usable title screen.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const SignalArt = preload("res://src/ui/screens/intro/signal_intro_art.gd")
const REVEAL_SECONDS := 1.8
var _art: Control
var _wordmark: Label
var _caption: Label
var _start_button: Button
var _skip_button: Button
var _stack: VBoxContainer
var _active := false
var _ready_for_start := false
var _start_locked := false
var _started_usec := 0
var _seq := 0
var _elapsed := 0.0

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("060b10")
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var safe := SafeAreaContainer.new()
	safe.extra_margin = 24
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := UI.column(safe, 0)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(top)
	_skip_button = UI.button("SKIP  >", _finish_reveal)
	top.add_child(_skip_button)
	var center := CenterContainer.new()
	center.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(center)
	_stack = UI.column(center, 12)
	_art = SignalArt.new()
	_art.name = "SignalVignette"
	_stack.add_child(_art)
	_wordmark = UI.label("LEVEL BLUE", 64, UI.TEXT, true)
	_wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack.add_child(_wordmark)
	_caption = UI.label("ONE SIGNAL. ONE DEFENDER.", 30, UI.TEAL)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack.add_child(_caption)
	_start_button = UI.button(tr("INTRO_START_GAME"), _on_start_pressed, true)
	_start_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	_stack.add_child(_start_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(false)

func on_enter(_args: Dictionary) -> void:
	_seq += 1
	_active = true
	visible = true
	_start_locked = false
	_ready_for_start = false
	_elapsed = 0
	_started_usec = Time.get_ticks_usec()
	_skip_button.visible = true
	_skip_button.disabled = false
	_skip_button.modulate.a = 1
	_skip_button.focus_mode = FOCUS_ALL
	_skip_button.mouse_filter = MOUSE_FILTER_STOP
	_start_button.text = tr("INTRO_START_GAME")
	_start_button.disabled = true
	_start_button.modulate.a = 0
	_apply_time(0)
	set_process(true)
	_skip_button.grab_focus()

func on_resume() -> void:
	_active = true
	visible = true
	_start_locked = false
	_finish_reveal()

func on_exit() -> void:
	_seq += 1
	_active = false
	set_process(false)

func can_go_back() -> bool:
	return false

func _layout() -> void:
	var view := get_viewport_rect().size
	var ratio := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var width := clampf(view.x * 0.68, 480, 860)
	_stack.custom_minimum_size.x = width
	_art.custom_minimum_size = Vector2(width, 228)
	_wordmark.add_theme_font_size_override("font_size", mini(64, int(width / 10.5)))
	_caption.add_theme_font_size_override("font_size", maxi(30, ceili(16 / ratio)))
	for button in [_skip_button, _start_button]:
		button.custom_minimum_size.y = maxf(64, ceilf(48 / ratio))
		button.add_theme_font_size_override("font_size", maxi(28, ceili(16 / ratio)))
	_start_button.custom_minimum_size.x = minf(width, 380)
	_skip_button.custom_minimum_size.x = 180

func _process(_delta: float) -> void:
	if not _active or _ready_for_start:
		return
	# Wall-clock timing avoids extending the intro on low FPS or after app suspension.
	_apply_time(float(Time.get_ticks_usec() - _started_usec) / 1000000.0)
	if _elapsed >= REVEAL_SECONDS:
		_finish_reveal()

func _apply_time(seconds: float) -> void:
	_elapsed = clampf(seconds, 0, REVEAL_SECONDS)
	_art.timeline = _elapsed
	var reveal := clampf((_elapsed - 0.88) / 0.36, 0, 1)
	_wordmark.modulate.a = reveal
	# Brief horizontal convergence, never a slow vertical camera pan.
	_wordmark.scale = Vector2(lerpf(0.97, 1.0, reveal), 1)
	_wordmark.pivot_offset = _wordmark.size * 0.5
	_caption.modulate.a = 1.0
	_start_button.modulate.a = clampf((_elapsed - 1.28) / 0.28, 0, 1)

func _finish_reveal() -> void:
	if not _active or _start_locked:
		return
	_apply_time(REVEAL_SECONDS)
	_ready_for_start = true
	_start_button.disabled = false
	# Keep header space reserved: no layout jump when Skip disappears.
	_skip_button.modulate.a = 0
	_skip_button.disabled = true
	_skip_button.focus_mode = FOCUS_NONE
	_skip_button.mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	_start_button.grab_focus()

func _on_start_pressed() -> void:
	if not _active or not _ready_for_start or _start_locked:
		return
	_start_locked = true
	_start_button.disabled = true
	var token := _seq
	await TransitionManager.fade_to_black(0.15)
	if not is_inside_tree() or not _active or token != _seq:
		return
	# Existing loading, asset checks, session restoration and login flow remain intact.
	await Router.open_splash_screen()
