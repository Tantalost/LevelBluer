class_name TowerPlacer
extends TileMapLayer
## BUILD-phase grid: drag from the shop to place; tap a tower, then a pad, to move.

signal tower_selected(tower_node: TowerBase)
signal tower_placed(tower_node: TowerBase)

const TILE_BUILDABLE := Vector2i(0, 0)
const TILE_BLOCKED := Vector2i(1, 0)
const SOURCE_ID := 0
const INVALID_CELL := Vector2i(-9999, -9999)
const FOOTPRINT := 3
const TILE_PX := 32.0
const PICK_RADIUS := 52.0

enum DragKind { NONE, PLACE, MOVE }

@export var tower_scene: PackedScene
@export var level_manager_path: NodePath = NodePath("../../LevelManager")

var occupied_cells: Dictionary = {}
var tower_cost: int = 2
var move_cost: int = 1
var max_towers: int = 0
var selected_tower: TowerBase = null
var _show_pads: bool = false
var _pad_overlay: Node2D
var _level_manager: LevelManager = null
var _drag_kind: DragKind = DragKind.NONE
var _drag_tower: TowerBase = null
var _drag_from: Vector2i = INVALID_CELL
var _drag_cell: Vector2i = INVALID_CELL
var _drag_press_local: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _hover_valid: bool = false
var _relocate_arm_frame: int = -1


class PadOverlay extends Node2D:
	func _draw() -> void:
		var host := get_parent() as TowerPlacer
		if host != null:
			host.draw_pads(self)


func _ready() -> void:
	if not level_manager_path.is_empty() and has_node(level_manager_path):
		_level_manager = get_node(level_manager_path) as LevelManager
	if not (get_parent() is MapBuilder) and get_used_cells().is_empty():
		_paint_test_map()
	_pad_overlay = PadOverlay.new()
	_pad_overlay.z_index = 4
	add_child(_pad_overlay)


func bind_level_manager(manager: LevelManager) -> void:
	_level_manager = manager


func set_build_preview(active: bool) -> void:
	_show_pads = active
	if not active:
		_cancel_drag()
	if _pad_overlay != null:
		_pad_overlay.queue_redraw()


func begin_place_drag() -> void:
	if not _is_build_phase():
		return
	if _at_tower_cap():
		print("[TowerPlacer] Tower cap reached.")
		return
	if _level_manager.current_gold < tower_cost:
		print("[Economy] Insufficient gold. Need: " + str(tower_cost))
		return
	_cancel_drag()
	clear_selection()
	_drag_kind = DragKind.PLACE
	_drag_moved = true
	_drag_press_local = get_local_mouse_position()
	_update_drag_pointer(_drag_press_local)


func draw_pads(canvas: CanvasItem) -> void:
	if not _show_pads:
		return
	var cells: Array[Vector2i] = get_used_cells()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var data: TileData = get_cell_tile_data(cell)
		if not _cell_is_buildable(cell, data):
			continue
		var center: Vector2 = map_to_local(cell)
		var rect := Rect2(center - Vector2(15, 15), Vector2(30, 30))
		canvas.draw_rect(rect, Color(Palette.CYAN, 0.12), true)
		canvas.draw_rect(rect, Color(Palette.CYAN, 0.7), false, 1.5)
	if _drag_kind == DragKind.NONE or _drag_cell == INVALID_CELL:
		return
	var ghost_center: Vector2 = map_to_local(_drag_cell)
	var span: float = TILE_PX * float(FOOTPRINT)
	var ghost := Rect2(ghost_center - Vector2(span, span) * 0.5, Vector2(span, span))
	var fill: Color = Color(Palette.SUCCESS, 0.28) if _hover_valid else Color(Palette.DANGER, 0.28)
	var edge: Color = Palette.SUCCESS if _hover_valid else Palette.DANGER
	canvas.draw_rect(ghost, fill, true)
	canvas.draw_rect(ghost, edge, false, 2.0)
	canvas.draw_circle(ghost_center, span * 0.28, Color(edge, 0.85))


func clear_selection() -> void:
	if _drag_kind == DragKind.MOVE:
		_cancel_drag()
	selected_tower = null
	tower_selected.emit(null)


func _process(_delta: float) -> void:
	if _drag_kind != DragKind.MOVE:
		return
	_update_drag_pointer(get_local_mouse_position())


func _input(event: InputEvent) -> void:
	if _drag_kind == DragKind.PLACE:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			_update_drag_pointer(_event_local_pos(event))
			get_viewport().set_input_as_handled()
			return
		if _is_cancel_event(event):
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		if _is_release_event(event):
			_commit_drag()
			get_viewport().set_input_as_handled()
		return
	if _is_cancel_event(event):
		if _gui_blocks_pointer():
			return
		if _drag_kind == DragKind.MOVE:
			_cancel_drag()
		else:
			clear_selection()
		get_viewport().set_input_as_handled()
		return
	if not _is_press_event(event):
		return
	if not _is_build_phase():
		return
	if _gui_blocks_pointer():
		return
	_begin_grid_press(_event_local_pos(event))
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			if _drag_kind != DragKind.NONE:
				_cancel_drag()
			else:
				clear_selection()
			get_viewport().set_input_as_handled()


func _gui_blocks_pointer() -> bool:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if hovered is Label:
		return false
	return hovered is BaseButton or hovered is HudGeoButton or hovered.mouse_filter == Control.MOUSE_FILTER_STOP


func _begin_grid_press(local_mouse: Vector2) -> void:
	var map_pos: Vector2i = local_to_map(local_mouse)
	var existing: TowerBase = _tower_at(map_pos)
	if existing == null:
		existing = _nearest_tower(local_mouse)
	if _drag_kind == DragKind.MOVE and _drag_tower != null and is_instance_valid(_drag_tower):
		if existing == _drag_tower:
			if Engine.get_process_frames() == _relocate_arm_frame:
				return
			_put_down_selected(_drag_tower)
			return
		if existing != null:
			_start_relocate(existing)
			return
		_try_relocate_to(map_pos)
		return
	if existing != null:
		_start_relocate(existing)
		return
	if not _can_drop(map_pos):
		print("Invalid placement")
		clear_selection()
		return
	_try_place(map_pos)


func _start_relocate(tower: TowerBase) -> void:
	if _drag_kind != DragKind.NONE:
		_cancel_drag()
	_drag_kind = DragKind.MOVE
	_drag_tower = tower
	_drag_from = _center_of(tower)
	_drag_cell = _drag_from
	_drag_moved = true
	_hover_valid = true
	tower.modulate.a = 0.4
	_relocate_arm_frame = Engine.get_process_frames()
	selected_tower = tower
	tower_selected.emit(tower)
	if _pad_overlay != null:
		_pad_overlay.queue_redraw()


func _put_down_selected(tower: TowerBase) -> void:
	_cancel_drag()
	if tower == null or not is_instance_valid(tower):
		return
	selected_tower = tower
	tower_selected.emit(tower)


func _try_relocate_to(cell: Vector2i) -> void:
	var tower: TowerBase = _drag_tower
	var from_cell: Vector2i = _drag_from
	if tower == null or not is_instance_valid(tower):
		_clear_drag_state()
		return
	if cell == from_cell:
		_put_down_selected(tower)
		return
	if not _can_drop(cell):
		print("Invalid placement")
		return
	if _level_manager == null or _level_manager.current_gold < move_cost:
		print("[Economy] Insufficient gold. Need: " + str(move_cost))
		return
	_level_manager.current_gold -= move_cost
	print("[Economy] Tower moved (" + str(move_cost) + "G). Remaining Gold: " + str(_level_manager.current_gold))
	_level_manager.update_hud()
	_vacate(from_cell)
	_occupy(cell, tower)
	tower.position = map_to_local(cell)
	tower.modulate.a = 1.0
	_clear_drag_state()
	selected_tower = tower
	tower_selected.emit(tower)
	print("[TowerPlacer] Moved %s → %s" % [str(from_cell), str(cell)])


func _update_drag_pointer(local_mouse: Vector2) -> void:
	var next_cell: Vector2i = local_to_map(local_mouse)
	var next_valid: bool = _can_drop(next_cell)
	if next_cell == _drag_cell and next_valid == _hover_valid:
		return
	_drag_cell = next_cell
	_hover_valid = next_valid
	if _pad_overlay != null:
		_pad_overlay.queue_redraw()


func _commit_drag() -> void:
	var kind: DragKind = _drag_kind
	var cell: Vector2i = _drag_cell
	_clear_drag_state()
	if kind == DragKind.PLACE and _can_drop(cell):
		_try_place(cell)


func _cancel_drag() -> void:
	if _drag_kind == DragKind.MOVE and _drag_tower != null and is_instance_valid(_drag_tower):
		_drag_tower.modulate.a = 1.0
		_drag_tower.position = map_to_local(_drag_from)
	_clear_drag_state()


func _clear_drag_state() -> void:
	_drag_kind = DragKind.NONE
	_drag_tower = null
	_drag_from = INVALID_CELL
	_drag_cell = INVALID_CELL
	_drag_moved = false
	_hover_valid = false
	if _pad_overlay != null:
		_pad_overlay.queue_redraw()


func _can_drop(center: Vector2i) -> bool:
	if not _is_build_phase():
		return false
	var cells: Array[Vector2i] = _footprint(center)
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var data: TileData = get_cell_tile_data(cell)
		if not _cell_is_buildable(cell, data):
			return false
		var occupant: TowerBase = _tower_at(cell)
		if occupant == null:
			continue
		if _drag_kind == DragKind.MOVE and occupant == _drag_tower:
			continue
		return false
	return true


func _is_build_phase() -> bool:
	return _level_manager != null and _level_manager.current_phase == LevelManager.GamePhase.PHASE_2_BUILD


func _cell_is_buildable(cell: Vector2i, tile_data: TileData) -> bool:
	if get_cell_atlas_coords(cell) == TILE_BUILDABLE:
		return true
	if tile_data != null and tile_data.get_custom_data("is_buildable") == true:
		return true
	return false


func _nearest_tower(local_mouse: Vector2) -> TowerBase:
	var best: TowerBase = null
	var best_d: float = PICK_RADIUS
	var seen: Dictionary = {}
	var keys: Array = occupied_cells.keys()
	for i in keys.size():
		var cell: Vector2i = keys[i] as Vector2i
		var tower: TowerBase = _tower_at(cell)
		if tower == null:
			continue
		var tower_id: int = tower.get_instance_id()
		if seen.has(tower_id):
			continue
		seen[tower_id] = true
		var dist: float = local_mouse.distance_to(tower.position)
		if dist < best_d:
			best_d = dist
			best = tower
	return best


func _tower_at(map_pos: Vector2i) -> TowerBase:
	if not occupied_cells.has(map_pos):
		return null
	var stored: Variant = occupied_cells[map_pos]
	var tower: TowerBase = stored as TowerBase
	if tower == null or not is_instance_valid(tower) or tower.is_queued_for_deletion():
		occupied_cells.erase(map_pos)
		return null
	return tower


func _center_of(tower: TowerBase) -> Vector2i:
	return local_to_map(tower.position)


func _footprint(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var extent: int = FOOTPRINT / 2
	for oy in range(-extent, extent + 1):
		for ox in range(-extent, extent + 1):
			cells.append(center + Vector2i(ox, oy))
	return cells


func _occupy(center: Vector2i, tower: TowerBase) -> void:
	var cells: Array[Vector2i] = _footprint(center)
	for i in cells.size():
		occupied_cells[cells[i]] = tower


func _vacate(center: Vector2i) -> void:
	var cells: Array[Vector2i] = _footprint(center)
	for i in cells.size():
		occupied_cells.erase(cells[i])


func placed_count() -> int:
	var seen: Dictionary = {}
	var keys: Array = occupied_cells.keys()
	for i in keys.size():
		var tower: Variant = occupied_cells[keys[i]]
		if typeof(tower) != TYPE_OBJECT or tower == null:
			continue
		seen[tower] = true
	return seen.size()


func _at_tower_cap() -> bool:
	return max_towers > 0 and placed_count() >= max_towers


func _try_place(map_pos: Vector2i) -> void:
	if tower_scene == null:
		push_error("TowerPlacer: tower_scene is not assigned")
		return
	if _at_tower_cap():
		print("[TowerPlacer] Tower cap reached.")
		return
	if _level_manager.current_gold < tower_cost:
		print("[Economy] Insufficient gold. Need: " + str(tower_cost))
		return
	var instance: Node = tower_scene.instantiate()
	var tower: TowerBase = instance as TowerBase
	if tower == null:
		push_error("TowerPlacer: tower_scene is not a TowerBase")
		return
	_level_manager.current_gold -= tower_cost
	print("[Economy] Tower built. Remaining Gold: " + str(_level_manager.current_gold))
	_level_manager.update_hud()
	add_child(tower)
	tower.position = map_to_local(map_pos)
	_occupy(map_pos, tower)
	print("[TowerPlacer] Placed at %s" % str(map_pos))
	tower_placed.emit(tower)


func _event_local_pos(event: InputEvent) -> Vector2:
	var screen := event as InputEventScreenTouch
	if screen != null:
		return make_input_local(screen).position
	var drag := event as InputEventScreenDrag
	if drag != null:
		return make_input_local(drag).position
	return get_local_mouse_position()


func _is_press_event(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _is_release_event(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		return not touch.pressed
	var mouse := event as InputEventMouseButton
	return mouse != null and not mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _is_cancel_event(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT


func _paint_test_map() -> void:
	for x in range(1, 41):
		for y in range(4, 18):
			set_cell(Vector2i(x, y), SOURCE_ID, TILE_BUILDABLE)
	var path_points: Array[Vector2] = [
		Vector2(80, 400),
		Vector2(640, 180),
		Vector2(1200, 400),
	]
	for i in range(path_points.size() - 1):
		_stamp_path_segment(path_points[i], path_points[i + 1])


func _stamp_path_segment(from_px: Vector2, to_px: Vector2) -> void:
	var steps := maxi(1, int(from_px.distance_to(to_px) / 16.0))
	for i in steps + 1:
		var px: Vector2 = from_px.lerp(to_px, float(i) / float(steps))
		var cell := local_to_map(px)
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				set_cell(cell + Vector2i(ox, oy), SOURCE_ID, TILE_BLOCKED)
