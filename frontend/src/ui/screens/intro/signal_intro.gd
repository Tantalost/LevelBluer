extends Control
## Animation only: no title card, Start button, assets, or navigation.
signal finished

const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const SignalArt = preload("res://src/ui/screens/intro/signal_intro_art.gd")
const DURATION := 1.8
var _art: Control
var _caption: Label
var _skip: Button
var _stack: VBoxContainer
var _spacer: Control
var _started_usec := 0
var _playing := false

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("060b10")
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
	_skip = UI.button("SKIP  >", _finish)
	top.add_child(_skip)
	var center := CenterContainer.new()
	center.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(center)
	_stack = UI.column(center, 24)
	_art = SignalArt.new()
	_stack.add_child(_art)
	_caption = UI.label("ONE SIGNAL. ONE DEFENDER.", 30, UI.TEAL)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack.add_child(_caption)
	# Balance the Skip row to center the vignette in the safe area.
	_spacer = Control.new()
	layout.add_child(_spacer)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(false)

func _layout() -> void:
	var view := get_viewport_rect().size
	var ratio := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var width := clampf(view.x * 0.68, 480, 860)
	_stack.custom_minimum_size.x = width
	_art.custom_minimum_size = Vector2(width, 240)
	_caption.add_theme_font_size_override("font_size", maxi(30, ceili(16 / ratio)))
	_skip.custom_minimum_size = Vector2(180, maxf(64, ceilf(48 / ratio)))
	_skip.add_theme_font_size_override("font_size", maxi(28, ceili(16 / ratio)))
	_spacer.custom_minimum_size.y = _skip.custom_minimum_size.y

func play() -> void:
	show()
	_started_usec = Time.get_ticks_usec()
	_playing = true
	_art.timeline = 0.0
	_skip.disabled = false
	_skip.grab_focus()
	set_process(true)

func stop() -> void:
	_playing = false
	set_process(false)

func _process(_delta: float) -> void:
	if not _playing:
		return
	var elapsed := float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	_art.timeline = minf(elapsed, DURATION)
	if elapsed >= DURATION:
		_finish()

func _finish() -> void:
	if not _playing:
		return
	stop()
	_skip.disabled = true
	finished.emit()
