extends Control
## Local, single-pulse feedback. Never moves the camera or blocks input.
const ERROR := Color("ff9295")
const SUCCESS := Color("88e5a2")
var _target: Control
var _tween: Tween
var _origin := Vector2.ZERO
var _moving := false
var _ink := ERROR
var _wash := 0.0
var _active := false

static func mount(target: Control) -> Control:
	var effect := new()
	effect._target = target
	effect.name = "AnswerFeedback"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the overlay outside Container layout so its border surrounds the panel,
	# not the text/content rectangle inside the panel's padding.
	var canvas := Node2D.new()
	canvas.name = "FeedbackCanvas"
	target.add_child(canvas)
	canvas.add_child(effect)
	effect.size = target.size
	target.resized.connect(effect._on_target_resized)
	return effect

func show_result(correct: bool) -> void:
	reset()
	_ink = SUCCESS if correct else ERROR
	_active = true
	_wash = 0.10
	_origin = _target.position
	_tween = create_tween()
	if not correct:
		_moving = true
		# A four-pixel nudge, not a whole-screen shake. Repeated attempts restart cleanly.
		for offset in [4.0, -4.0, 3.0, -2.0, 0.0]:
			_tween.tween_property(_target, "position:x", _origin.x + offset, 0.05)
		_tween.tween_callback(func() -> void: _moving = false)
	_tween.tween_method(_set_wash, 0.10, 0.025, 0.25)
	queue_redraw()

func reset() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _moving and is_instance_valid(_target):
		_target.position = _origin
	_moving = false
	_active = false
	_wash = 0.0
	queue_redraw()

func _set_wash(value: float) -> void:
	_wash = value
	queue_redraw()

func _on_target_resized() -> void:
	# Container reflow may happen while simulation controls are rebuilt.
	# Stop motion, but keep the result visible at the new size.
	var was_active := _active
	reset()
	_active = was_active
	_wash = 0.025
	size = _target.size
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(_ink, _wash))
	draw_rect(Rect2(Vector2.ONE * 2.0, (size - Vector2.ONE * 4.0).max(Vector2.ZERO)), _ink, false, 2.0)

func _exit_tree() -> void:
	reset()
