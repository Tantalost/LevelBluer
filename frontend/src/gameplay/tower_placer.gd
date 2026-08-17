class_name TowerPlacer
extends TileMapLayer
## BUILD-phase grid: empty cell places, occupied cell selects.

signal tower_selected(tower_node: TowerBase)

const TILE_BUILDABLE := Vector2i(0, 0)
const TILE_BLOCKED := Vector2i(1, 0)
const SOURCE_ID := 0

@export var tower_scene: PackedScene
@export var level_manager_path: NodePath = NodePath("../../LevelManager")

var occupied_cells: Dictionary = {}
var tower_cost: int = 2
var selected_tower: TowerBase = null

@onready var _level_manager: LevelManager = get_node(level_manager_path)


func _ready() -> void:
	_paint_test_map()


func clear_selection() -> void:
	selected_tower = null
	tower_selected.emit(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			clear_selection()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			clear_selection()
			get_viewport().set_input_as_handled()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if _level_manager == null or _level_manager.current_phase != LevelManager.GamePhase.PHASE_2_BUILD:
			return
		_handle_grid_click(get_local_mouse_position())
		get_viewport().set_input_as_handled()


func _handle_grid_click(local_mouse: Vector2) -> void:
	if _level_manager == null:
		push_warning("TowerPlacer: LevelManager missing")
		return
	if _level_manager.current_phase != LevelManager.GamePhase.PHASE_2_BUILD:
		return

	var map_pos: Vector2i = local_to_map(local_mouse)
	var existing: TowerBase = _tower_at(map_pos)
	if existing != null:
		selected_tower = existing
		tower_selected.emit(existing)
		return

	var tile_data: TileData = get_cell_tile_data(map_pos)
	if tile_data == null or tile_data.get_custom_data("is_buildable") != true:
		print("Invalid placement")
		clear_selection()
		return

	_try_place(map_pos)


func _tower_at(map_pos: Vector2i) -> TowerBase:
	if not occupied_cells.has(map_pos):
		return null
	var stored: Variant = occupied_cells[map_pos]
	var tower: TowerBase = stored as TowerBase
	if tower == null or not is_instance_valid(tower) or tower.is_queued_for_deletion():
		occupied_cells.erase(map_pos)
		return null
	return tower


func _try_place(map_pos: Vector2i) -> void:
	if tower_scene == null:
		push_error("TowerPlacer: tower_scene is not assigned")
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
	occupied_cells[map_pos] = tower
	print("[TowerPlacer] Placed at %s" % str(map_pos))


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
