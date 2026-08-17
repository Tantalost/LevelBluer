class_name SkillTreePanZoom
extends Control
## Clipping viewport for the skill-tree canvas. Pan with RMB / WASD / touch-drag;
## zoom with the mouse wheel toward the cursor. HUD sits on a higher CanvasLayer
## so this never steals button clicks.

@export var min_scale: float = 0.5
@export var max_scale: float = 2.2
@export var zoom_step: float = 0.12
@export var pan_speed: float = 280.0

@onready var _canvas: Control = $SkillTreeCanvas

var _dragging := false
var _view_ready := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)


func reset_view() -> void:
	if _canvas == null or size.x <= 0.0:
		return
	_canvas.scale = Vector2.ONE
	_canvas.position = size * 0.5
	_view_ready = true


func _on_resized() -> void:
	if not _view_ready:
		reset_view()


func _process(delta: float) -> void:
	if _canvas == null or not is_visible_in_tree():
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y -= 1.0
	if dir != Vector2.ZERO:
		_canvas.position += dir.normalized() * pan_speed * delta


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mouse.pressed
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_zoom_at(1.0 + zoom_step, mouse.position)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_zoom_at(1.0 - zoom_step, mouse.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_canvas.position += motion.relative
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_canvas.position += drag.relative
		accept_event()


func _zoom_at(factor: float, cursor: Vector2) -> void:
	var old := _canvas.scale.x
	var next := clampf(old * factor, min_scale, max_scale)
	if is_equal_approx(next, old):
		return
	var from_canvas := (cursor - _canvas.position) / old
	_canvas.scale = Vector2(next, next)
	_canvas.position = cursor - from_canvas * next
