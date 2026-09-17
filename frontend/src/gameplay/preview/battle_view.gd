extends SubViewportContainer
## Camera-only navigation. Physics and combat always run in canonical world units.
signal cell_tapped(cell: Vector2i)
const Board = preload("res://src/gameplay/preview/preview_board.gd")
var viewport: SubViewport
var board: Node2D
var world: Node2D
var camera: Camera2D
var track: Path2D
var enabled := true
var _pressed := false
var _dragged := false
var _origin := Vector2.ZERO
var _touches: Dictionary = {}
var _fit := 1.0
var _zoom := 1.0
var shake_left := 0.0
var _shake_age := 0.0

func shake_hit() -> void:
	shake_left = 0.34
	_shake_age = 0.0

func _process(delta: float) -> void:
	if camera == null or shake_left <= 0:
		return
	shake_left = maxf(0, shake_left - delta)
	_shake_age += delta
	# Shake the camera, not buttons or hit-testing. Restore exactly on completion.
	var strength := 7.0 * pow(shake_left / 0.34, 2)
	camera.offset = Vector2(sin(_shake_age * 93), cos(_shake_age * 77)) * strength / camera.zoom.x
	if shake_left == 0:
		camera.offset = Vector2.ZERO
	camera.force_update_scroll()

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node2D.new()
	viewport.add_child(world)
	board = Board.new()
	world.add_child(board)
	track = Path2D.new()
	track.curve = board.curve()
	world.add_child(track)
	camera = Camera2D.new()
	camera.position = Vector2(416, 224)
	world.add_child(camera)
	resized.connect(recenter)
	gui_input.connect(_handle_input)
	call_deferred("recenter")

func recenter() -> void:
	if camera == null:
		return
	_fit = maxf(0.1, minf(size.x / 896.0, size.y / 512.0))
	_zoom = 1.0
	camera.zoom = Vector2.ONE * _fit
	camera.position = Vector2(416, 224)
	camera.force_update_scroll()

func _world_position(at: Vector2) -> Vector2:
	return viewport.canvas_transform.affine_inverse() * at

func zoom_at(factor: float, at: Vector2) -> void:
	var before := _world_position(at)
	_zoom = clampf(_zoom * factor, 0.8, 3.5)
	camera.zoom = Vector2.ONE * _fit * _zoom
	camera.force_update_scroll()
	camera.position += before - _world_position(at)
	_clamp_camera()

func _clamp_camera() -> void:
	camera.position = camera.position.clamp(Vector2(-64, -64), Vector2(896, 512))
	camera.force_update_scroll()

func _handle_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(1 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_pointer(event.pressed, event.position)
	elif event is InputEventMouseMotion and _pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		_pan(event.position, event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_pointer(true, event.position)
			else:
				_dragged = true
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				_pointer(false, event.position)
	elif event is InputEventScreenDrag:
		if _touches.size() > 1:
			var previous: Array = _touches.values()
			var old_distance: float = previous[0].distance_to(previous[1])
			_touches[event.index] = event.position
			var next: Array = _touches.values()
			zoom_at(next[0].distance_to(next[1]) / maxf(1, old_distance), (next[0] + next[1]) * 0.5)
			_dragged = true
		else:
			_touches[event.index] = event.position
			_pan(event.position, event.relative)
	accept_event()

func _pointer(down: bool, at: Vector2) -> void:
	if down:
		_pressed = true
		_dragged = false
		_origin = at
	else:
		if _pressed and not _dragged:
			var world_at := _world_position(at)
			cell_tapped.emit(Vector2i(floori(world_at.x / Board.CELL), floori(world_at.y / Board.CELL)))
		_pressed = false

func _pan(at: Vector2, relative: Vector2) -> void:
	var physical_scale := maxf(0.1, get_viewport().get_final_transform().get_scale().x)
	if at.distance_to(_origin) * physical_scale > 8:
		_dragged = true
	if _dragged:
		camera.position -= relative / camera.zoom
		_clamp_camera()
