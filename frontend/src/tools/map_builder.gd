@tool
class_name MapBuilder
extends Node2D
## Editor/runtime ASCII → TileMapLayer + smoothed Path2D.

const TILE_SOURCE_ID: int = 0
const TILE_BUILDABLE := Vector2i(0, 0)
const TILE_PATH := Vector2i(1, 0)
const INVALID_CELL := Vector2i(-1, -1)
const ORTHO_DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]
const HANDLE_FACTOR: float = 0.4
const HANDLE_CLAMP: float = 0.45
const GROUP_LEVEL_PATH := "level_path"
const STAGE_ONE_MAP_ID := "map_basic"
const STAGE_ONE_MAP_ASSET_ID := "map_module_1_stage_1"
const STAGE_ONE_ART := preload("res://src/gameplay/maps/stage_one_map_art.gd")

@export var map_id: String = "map_basic"
@export var tilemap_path: NodePath = NodePath("TileMapLayer")
@export var path_path: NodePath = NodePath("Path2D")
@export var generate_map: bool = false:
	get:
		return false
	set(value):
		if value:
			_generate_map()

var _end_cell: Vector2i = INVALID_CELL
var _start_cell: Vector2i = INVALID_CELL
var _stage_one_art: StageOneMapArt = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_generate_map()


func get_end_global_position() -> Vector2:
	var tilemap: TileMapLayer = _resolve_tilemap()
	if tilemap == null or _end_cell == INVALID_CELL:
		return Vector2.ZERO
	return tilemap.to_global(tilemap.map_to_local(_end_cell))


func get_start_global_position() -> Vector2:
	var tilemap: TileMapLayer = _resolve_tilemap()
	if tilemap == null or _start_cell == INVALID_CELL:
		return Vector2.ZERO
	return tilemap.to_global(tilemap.map_to_local(_start_cell))


func _generate_map() -> void:
	if not is_inside_tree():
		return
	var tilemap: TileMapLayer = _resolve_tilemap()
	var path: Path2D = _resolve_path()
	if tilemap == null or path == null:
		push_error("MapBuilder: TileMapLayer and Path2D references are required")
		return
	var layout: PackedStringArray = MapDesigns.get_layout(map_id)
	if layout.is_empty():
		return
	_validate_layout(layout)
	_center_in_view(layout)
	tilemap.clear()
	path.curve = Curve2D.new()
	_paint_tiles(tilemap, layout)
	_sync_stage_art(tilemap, layout)
	_start_cell = _find_marker(layout, "S")
	_end_cell = _find_marker(layout, "E")
	if _start_cell == INVALID_CELL or _end_cell == INVALID_CELL:
		push_error("MapBuilder: layout '%s' needs exactly one S and one E" % map_id)
		return
	var raw_path: Array[Vector2i] = _trace_path(layout, _start_cell, _end_cell)
	if raw_path.is_empty() or raw_path[raw_path.size() - 1] != _end_cell:
		push_error("MapBuilder: failed to walk S→E on '%s'" % map_id)
		return
	var corners: Array[Vector2i] = _extract_corners(raw_path)
	path.curve = _build_curve(tilemap, path, corners)
	if not path.is_in_group(GROUP_LEVEL_PATH):
		path.add_to_group(GROUP_LEVEL_PATH, true)


func _sync_stage_art(tilemap: TileMapLayer, layout: PackedStringArray) -> void:
	var use_authored_art: bool = map_id == STAGE_ONE_MAP_ID
	# self_modulate hides only the placeholder atlas; towers and the placement
	# overlay are children of the TileMapLayer and remain fully visible.
	tilemap.self_modulate = Color(1.0, 1.0, 1.0, 0.0 if use_authored_art else 1.0)
	if not use_authored_art:
		if _stage_one_art != null and is_instance_valid(_stage_one_art):
			_stage_one_art.queue_free()
		_stage_one_art = null
		return
	# Stage 1 ships with a baked version of the approved 2.5D composition so the
	# live game does not depend on custom CanvasItem draw ordering. The authored
	# renderer remains the source for future tileset extraction and fallback.
	var baked_backdrop := get_node_or_null("StageOneBackdrop") as CanvasItem
	if baked_backdrop != null:
		baked_backdrop.visible = true
		AssetManager.bind_texture(baked_backdrop, STAGE_ONE_MAP_ASSET_ID)
		if _stage_one_art != null and is_instance_valid(_stage_one_art):
			_stage_one_art.queue_free()
		_stage_one_art = null
		return
	var scene_art := get_node_or_null("StageOneMapArt") as StageOneMapArt
	if scene_art != null:
		_stage_one_art = scene_art
	if _stage_one_art == null or not is_instance_valid(_stage_one_art):
		_stage_one_art = STAGE_ONE_ART.new() as StageOneMapArt
		add_child(_stage_one_art)
		move_child(_stage_one_art, 0)
	_stage_one_art.configure(layout)


func _center_in_view(layout: PackedStringArray) -> void:
	var cols: int = layout[0].length()
	var rows: int = layout.size()
	var pixel_size := Vector2(float(cols * MapDesigns.TILE_SIZE), float(rows * MapDesigns.TILE_SIZE))
	position = (MapDesigns.VIEW_SIZE - pixel_size) * 0.5


func _paint_tiles(tilemap: TileMapLayer, layout: PackedStringArray) -> void:
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var ch: String = row.substr(x, 1)
			var cell := Vector2i(x, y)
			if ch == "#":
				tilemap.set_cell(cell, TILE_SOURCE_ID, TILE_BUILDABLE)
			elif ch == "." or ch == "S" or ch == "E":
				tilemap.set_cell(cell, TILE_SOURCE_ID, TILE_PATH)


func _trace_path(layout: PackedStringArray, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var walked: Array[Vector2i] = [start]
	var visited: Dictionary[Vector2i, bool] = {}
	visited[start] = true
	var current: Vector2i = start
	var last_dir: Vector2i = Vector2i.RIGHT
	var max_steps: int = layout.size() * 64
	var steps: int = 0
	while current != goal:
		steps += 1
		if steps > max_steps:
			push_error("MapBuilder: path walk exceeded max steps")
			return walked
		var next_cell: Vector2i = _pick_next(layout, current, goal, visited, last_dir)
		if next_cell == INVALID_CELL:
			push_error("MapBuilder: dead end at %s on '%s'" % [str(current), map_id])
			return walked
		last_dir = next_cell - current
		visited[next_cell] = true
		walked.append(next_cell)
		current = next_cell
	return walked


func _pick_next(
	layout: PackedStringArray,
	current: Vector2i,
	goal: Vector2i,
	visited: Dictionary[Vector2i, bool],
	last_dir: Vector2i
) -> Vector2i:
	var preferred: Vector2i = current + last_dir
	var fallback: Array[Vector2i] = []
	for i in ORTHO_DIRS.size():
		var neighbor: Vector2i = current + ORTHO_DIRS[i]
		if visited.has(neighbor):
			continue
		if not _is_path_cell(layout, neighbor):
			continue
		if not _reaches_goal(layout, neighbor, goal, visited):
			continue
		if neighbor == preferred:
			return neighbor
		fallback.append(neighbor)
	if fallback.is_empty():
		return INVALID_CELL
	return fallback[0]


func _reaches_goal(
	layout: PackedStringArray,
	origin: Vector2i,
	goal: Vector2i,
	blocked: Dictionary[Vector2i, bool]
) -> bool:
	if origin == goal:
		return true
	var seen: Dictionary[Vector2i, bool] = blocked.duplicate()
	seen[origin] = true
	var queue: Array[Vector2i] = [origin]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for i in ORTHO_DIRS.size():
			var neighbor: Vector2i = cell + ORTHO_DIRS[i]
			if seen.has(neighbor):
				continue
			if not _is_path_cell(layout, neighbor):
				continue
			if neighbor == goal:
				return true
			seen[neighbor] = true
			queue.append(neighbor)
	return false


func _extract_corners(raw_path: Array[Vector2i]) -> Array[Vector2i]:
	var corners: Array[Vector2i] = []
	if raw_path.is_empty():
		return corners
	corners.append(raw_path[0])
	for i in range(1, raw_path.size() - 1):
		var dir_in: Vector2i = raw_path[i] - raw_path[i - 1]
		var dir_out: Vector2i = raw_path[i + 1] - raw_path[i]
		if dir_in != dir_out:
			corners.append(raw_path[i])
	corners.append(raw_path[raw_path.size() - 1])
	return corners


func _build_curve(tilemap: TileMapLayer, path: Path2D, corners: Array[Vector2i]) -> Curve2D:
	var curve := Curve2D.new()
	if corners.is_empty():
		return curve
	var tile_size: float = float(MapDesigns.TILE_SIZE)
	if tilemap.tile_set != null:
		tile_size = float(tilemap.tile_set.tile_size.x)
	for i in corners.size():
		var world_pos: Vector2 = _cell_to_path_local(tilemap, path, corners[i])
		if i == 0 or i == corners.size() - 1:
			curve.add_point(world_pos)
			continue
		var prev_world: Vector2 = _cell_to_path_local(tilemap, path, corners[i - 1])
		var next_world: Vector2 = _cell_to_path_local(tilemap, path, corners[i + 1])
		var incoming: Vector2 = world_pos - prev_world
		var outgoing: Vector2 = next_world - world_pos
		var in_len: float = incoming.length()
		var out_len: float = outgoing.length()
		if in_len <= 0.001 or out_len <= 0.001:
			curve.add_point(world_pos)
			continue
		var dir_in: Vector2 = incoming / in_len
		var dir_out: Vector2 = outgoing / out_len
		var radius: float = minf(tile_size * HANDLE_FACTOR, minf(in_len, out_len) * HANDLE_CLAMP)
		curve.add_point(world_pos, -dir_in * radius, dir_out * radius)
	return curve


func _cell_to_path_local(tilemap: TileMapLayer, path: Path2D, cell: Vector2i) -> Vector2:
	var tile_local: Vector2 = tilemap.map_to_local(cell)
	var world: Vector2 = tilemap.to_global(tile_local)
	return path.to_local(world)


func _find_marker(layout: PackedStringArray, marker: String) -> Vector2i:
	var found: Vector2i = INVALID_CELL
	for y in layout.size():
		var row: String = layout[y]
		var x: int = row.find(marker)
		if x < 0:
			continue
		if found != INVALID_CELL:
			push_warning("MapBuilder: extra '%s' in '%s'" % [marker, map_id])
			break
		found = Vector2i(x, y)
	return found


func _is_path_cell(layout: PackedStringArray, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= layout.size():
		return false
	var row: String = layout[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return false
	var ch: String = row.substr(cell.x, 1)
	return ch == "." or ch == "S" or ch == "E"


func _validate_layout(layout: PackedStringArray) -> void:
	var width: int = layout[0].length()
	for y in layout.size():
		if layout[y].length() != width:
			push_warning("MapBuilder: row %d width mismatch on '%s'" % [y, map_id])


func _resolve_tilemap() -> TileMapLayer:
	if tilemap_path.is_empty() or not has_node(tilemap_path):
		return null
	return get_node(tilemap_path) as TileMapLayer


func _resolve_path() -> Path2D:
	if path_path.is_empty() or not has_node(path_path):
		return null
	return get_node(path_path) as Path2D
