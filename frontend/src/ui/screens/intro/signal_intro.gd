extends Control
## Local, player-paced disclaimer. The host owns title-screen navigation.
signal finished

const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const DISCLAIMER: String = "LEVELBLUE is an academic project for educational and research purposes only and is not intended for commercial use. Third-party names, trademarks, and intellectual property belong to their respective owners. Any unintended similarities or associations are purely coincidental."
const FADE_SECONDS: float = 0.55
var _heading: Label
var _caption: Label
var _continue: Button
var _stack: VBoxContainer
var _safe_content: Control
var _scroll: ScrollContainer
var _transition: Tween
var _playing: bool = false
var _ready_to_continue: bool = false

func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra_margin = 28
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	_safe_content = Control.new()
	safe.add_child(_safe_content)
	_stack = UI.column(_safe_content, 24)
	_stack.modulate.a = 0.0
	_heading = UI.label("DISCLAIMER", 36, Color("#4FE0D4"))
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack.add_child(_heading)
	var divider: ColorRect = ColorRect.new()
	divider.color = Color("#173058")
	divider.custom_minimum_size.y = 2
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	_stack.add_child(divider)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_stack.add_child(_scroll)
	_caption = UI.label(DISCLAIMER, 28, Color("#F3ECD6"))
	_caption.name = "DisclaimerText"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_constant_override("line_spacing", 10)
	_caption.size_flags_horizontal = SIZE_EXPAND_FILL
	_caption.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.add_child(_caption)
	_continue = UI.button("CONTINUE", _finish)
	_continue.size_flags_horizontal = SIZE_SHRINK_CENTER
	_continue.disabled = true
	_stack.add_child(_continue)
	_safe_content.resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var ratio: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var available: Vector2 = _safe_content.size
	var width: float = minf(1120.0, available.x * 0.88)
	var height: float = minf(520.0, available.y)
	_heading.add_theme_font_size_override("font_size", maxi(36, ceili(26.0 / ratio)))
	_caption.add_theme_font_size_override("font_size", maxi(28, ceili(20.0 / ratio)))
	_continue.add_theme_font_size_override("font_size", maxi(28, ceili(20.0 / ratio)))
	_continue.custom_minimum_size = Vector2(240, maxf(64.0, ceilf(48.0 / ratio)))
	_stack.position = (available - Vector2(width, height)) * 0.5
	_stack.size = Vector2(width, height)

func play() -> void:
	stop()
	show()
	_playing = true
	_stack.modulate.a = 0.0
	_scroll.scroll_vertical = 0
	_transition = create_tween()
	_transition.tween_interval(0.2)
	_transition.tween_property(_stack, "modulate:a", 1.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
	_transition.tween_callback(_allow_continue)

func _allow_continue() -> void:
	if not _playing:
		return
	_ready_to_continue = true
	_continue.disabled = false
	_continue.grab_focus()

func stop() -> void:
	_playing = false
	_ready_to_continue = false
	if is_instance_valid(_continue):
		_continue.disabled = true
	if _transition != null and _transition.is_valid():
		_transition.kill()

func _finish() -> void:
	if not _playing or not _ready_to_continue:
		return
	_ready_to_continue = false
	_continue.disabled = true
	_continue.release_focus()
	_transition = create_tween()
	_transition.tween_property(_stack, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	_transition.tween_callback(_complete)

func _complete() -> void:
	if not _playing:
		return
	_playing = false
	finished.emit()

func _exit_tree() -> void:
	stop()
