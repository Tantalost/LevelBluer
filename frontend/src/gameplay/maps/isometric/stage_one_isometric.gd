@tool
extends MapBuilder
## Module 1 / Stage 1: the unchanged ASCII layout on the reusable 2:1 kit.
const FLOORS := preload("res://assets/gameplay/isometric/industrial_floors.tres")
const SCENERY := preload("res://assets/gameplay/isometric/industrial_scenery.tres")
const UNIT_SCALE := 2.2360679775 # length(Vector2(64,32)) / old 32 px cell
const APRON_MIN := Vector2i(-2,-2)
const APRON_MAX := Vector2i(33,14)
var _ground: TileMapLayer
var _scenery: TileMapLayer
var _details: TileMapLayer
var _reserved_cells: Dictionary = {}

class Deck extends Node2D:
	var corners := PackedVector2Array()
	func _draw() -> void:
		if corners.size() != 4:
			return
		var depth := Vector2(0,56)
		draw_colored_polygon(PackedVector2Array([corners[1],corners[2],corners[2]+depth,corners[1]+depth]), Color("1a2832"))
		draw_colored_polygon(PackedVector2Array([corners[2],corners[3],corners[3]+depth,corners[2]+depth]), Color("263944"))
		draw_line(corners[1]+Vector2(0,7), corners[2]+Vector2(0,7), Color("46616b"), 4.0)
		draw_line(corners[2]+Vector2(0,7), corners[3]+Vector2(0,7), Color("37515d"), 4.0)
		for side in [1,2]:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side+1)%4]
			for i in 18:
				var p := a.lerp(b, float(i)/18.0)
				draw_line(p+Vector2(0,12),p+Vector2(0,48),Color("10212a"),3.0)

class RouteGuides extends Node2D:
	var arrows: Array[PackedVector2Array] = []
	func _draw() -> void:
		for points in arrows:
			draw_polyline(points, Color(0.54,0.74,0.72,0.8), 3.0, true)

func _ready() -> void:
	_generate_map()

func _generate_map() -> void:
	if not is_inside_tree():
		return
	# This scene never uses the Cloudinary baked Stage 1 backdrop.
	set_meta("authored_environment", true)
	super._generate_map()
	var path := _resolve_path()
	path.y_sort_enabled = true
	path.set_meta("path_unit_scale", UNIT_SCALE)
	path.set_meta("actor_unit_scale", UNIT_SCALE)

func _center_in_view(_layout: PackedStringArray) -> void:
	var grid := _resolve_tilemap()
	var corners := _deck_corners(grid)
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for p in corners:
		bounds = bounds.expand(p)
	bounds.position.y -= 125
	bounds.size.y += 181
	# Fill the play area after removing the old decorative world backdrop.
	var safe_area := Rect2(28,66,1224,600)
	var fit := minf(safe_area.size.x / bounds.size.x, safe_area.size.y / bounds.size.y)
	scale = Vector2.ONE * fit
	position = safe_area.position + (safe_area.size - bounds.size * fit) * 0.5 - bounds.position * fit

func _paint_tiles(tilemap: TileMapLayer, layout: PackedStringArray) -> void:
	y_sort_enabled = true
	tilemap.y_sort_enabled = true
	tilemap.self_modulate = Color(1,1,1,0)
	if _ground == null:
		_ground = TileMapLayer.new()
		_ground.name = "IndustrialGround"
		_ground.z_index = -4
		_ground.tile_set = FLOORS.duplicate(true)
		_ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_ground)
		_details = TileMapLayer.new()
		_details.name = "IndustrialTrim"
		_details.tile_set = _ground.tile_set
		_details.z_index = -3
		add_child(_details)
		_scenery = TileMapLayer.new()
		_scenery.name = "IndustrialScenery"
		_scenery.tile_set = SCENERY
		_scenery.y_sort_enabled = true
		add_child(_scenery)
	_ground.clear()
	_details.clear()
	_scenery.clear()
	# Mutate only this map's private art TileSet, never the shared kit.
	for source_id in [0,1]:
		var source := _ground.tile_set.get_source(source_id) as TileSetAtlasSource
		for index in source.get_tiles_count():
			var coords := source.get_tile_id(index)
			source.get_tile_data(coords,0).modulate = Color(0.73,0.81,0.84) if source_id == 0 else Color(0.28,0.39,0.45)
	for y in range(APRON_MIN.y,APRON_MAX.y+1):
		for x in range(APRON_MIN.x,APRON_MAX.x+1):
			var cell := Vector2i(x,y)
			var playable: bool = y >= 0 and y < layout.size() and x >= 0 and x < layout[0].length()
			var hash_value := posmod(x*19+y*31,29)
			if playable:
				var buildable: bool = layout[y][x] == "#"
				var material := Vector2i(1,0) if hash_value < 3 else Vector2i.ZERO
				if hash_value == 8:
					material = Vector2i(4,0)
				if not buildable:
					material = Vector2i(5,0)
				tilemap.set_cell(cell, 0 if buildable else 1, material)
				_ground.set_cell(cell, 0 if buildable else 1, material)
			else:
				_ground.set_cell(cell,1,Vector2i(6,0) if posmod(x+y,3)==0 else Vector2i(5,0))
			var mask := 0
			if x == APRON_MAX.x: mask |= 1
			if y == APRON_MAX.y: mask |= 2
			if x == APRON_MIN.x: mask |= 4
			if y == APRON_MIN.y: mask |= 8
			if mask:
				var atlas_index := 23 + mask
				_details.set_cell(cell,2,Vector2i(atlas_index%12,atlas_index/12))
	_build_scenery()
	_paint_service_bays()
	_build_deck_and_guides(tilemap)

func _sync_stage_art(_tilemap: TileMapLayer, _layout: PackedStringArray) -> void:
	pass

func _build_curve(tilemap: TileMapLayer, path: Path2D, corners: Array[Vector2i]) -> Curve2D:
	# Straight centerline segments never cut a narrow route corner.
	var curve := Curve2D.new()
	for cell in corners:
		curve.add_point(_cell_to_path_local(tilemap,path,cell))
	return curve

func _sync_endpoint_visuals(tilemap: TileMapLayer) -> void:
	super._sync_endpoint_visuals(tilemap)
	var endpoints := get_node("MapEndpointVisuals")
	endpoints.call("set_isometric_style", true)

func _deck_corners(grid: TileMapLayer) -> PackedVector2Array:
	return PackedVector2Array([
		grid.map_to_local(APRON_MIN)+Vector2(0,-32),
		grid.map_to_local(Vector2i(APRON_MAX.x,APRON_MIN.y))+Vector2(64,0),
		grid.map_to_local(APRON_MAX)+Vector2(0,32),
		grid.map_to_local(Vector2i(APRON_MIN.x,APRON_MAX.y))+Vector2(-64,0)])

func _build_deck_and_guides(grid: TileMapLayer) -> void:
	for node_name in ["DeckFaces","RouteGuides"]:
		var old := get_node_or_null(node_name)
		if old != null:
			remove_child(old)
			old.queue_free()
	var deck := Deck.new()
	deck.name = "DeckFaces"
	deck.z_index = -5
	deck.corners = _deck_corners(grid)
	add_child(deck)
	var guides := RouteGuides.new()
	guides.name = "RouteGuides"
	guides.z_index = -2
	for item in [[5,6,1,0],[12,6,1,0],[19,6,1,0],[22,8,0,1],[27,10,1,0]]:
		var cell := Vector2i(item[0],item[1])
		var direction := (grid.map_to_local(cell+Vector2i(item[2],item[3]))-grid.map_to_local(cell)).normalized()
		var center := grid.map_to_local(cell)
		var across := direction.orthogonal()
		guides.arrows.append(PackedVector2Array([center-direction*10+across*9,center+direction*8,center-direction*10-across*9]))
	add_child(guides)

func _build_scenery() -> void:
	_reserved_cells.clear()
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/gameplay/isometric/module_registry.json"))
	var placements := [
		["wall_outer_corner",-2,-2],
		["wall_long",1,-2],["wall_vent",4,-2],["wall_long",7,-2],
		["door_double",10,-2],["wall_window",13,-2],["wall_long",16,-2],
		["wall_vent",19,-2],["wall_long",22,-2],["door_shutter",25,-2],["wall_long",28,-2],
		["wall_long_mirrored",-2,1],["wall_pipe",-2,4],
		["wall_long_mirrored",-2,8],["wall_long_mirrored",-2,11],
		["air_conditioner",3,-1],["electrical_cabinet",9,-1],["vent_box",15,-1],
		["pipe_straight",20,-1],["utility_box",26,-1],
		["generator",32,0],["transformer",32,3],["electrical_cabinet",32,7],
		["hvac_rooftop",32,12],
		["railing_long",0,14],["railing_long",4,14],["railing_long",8,14],
		["railing_long",12,14],["railing_long",16,14],["railing_long",20,14],
		["railing_long",24,14],["railing_long",28,14],
		["tire",-1,13],["trash_bags",31,-1],["concrete_chips",6,13],
		["scrap_metal",11,13],["cable_straight",17,13],["rubble",25,13]]
	# Interior landmarks occupy real cells. The enemy route and surrounding
	# deployment lanes remain open; low equipment sits on the foreground bays.
	placements.append_array([
		["fan_array",5,1],["hvac_rooftop",8,1],
		["industrial_machine",14,1],["electrical_cabinet",16,2],["pipe_cluster",14,3],
		["container",25,1],["crate_metal",28,2],["dumpster",26,3],
		["fan_small",3,9],["crate_wood",5,9],
		["generator",12,8],["tank_vertical",15,8],["pipe_valve",13,9],
		["barrier_long",18,11],["utility_box",25,7],["air_conditioner",27,7]])
	var layout := MapDesigns.get_layout(map_id)
	for item in placements:
		var module: Dictionary = registry[item[0]]
		var anchor := Vector2i(item[1],item[2])
		# Scenery footprints are checked against the route, not texture bounds.
		for offset in module.footprint:
			var cell := anchor + Vector2i(int(offset[0]),int(offset[1]))
			if cell.x >= 0 and cell.x < 32 and cell.y >= 0 and cell.y < 13:
				assert(layout[cell.y][cell.x] == "#", "Scenery must never obstruct the enemy route")
				assert(not _reserved_cells.has(cell), "Overlapping scenery footprint")
				_reserved_cells[cell] = str(item[0])
		_scenery.set_cell(anchor,int(module.source),Vector2i.ZERO,int(module.scene))

func _paint_service_bays() -> void:
	# Material changes establish utility bays without painting a global overlay.
	for bay in [Rect2i(4,0,7,4),Rect2i(13,0,5,4),Rect2i(24,0,6,4),Rect2i(11,7,6,3),Rect2i(2,8,5,3),Rect2i(24,7,6,2)]:
		for y in range(bay.position.y,bay.end.y):
			for x in range(bay.position.x,bay.end.x):
				var cell := Vector2i(x,y)
				if _resolve_tilemap().get_cell_source_id(cell) != 0:
					continue
				_ground.set_cell(cell,0,Vector2i(6,0) if _reserved_cells.has(cell) else Vector2i(5,0))
		# Hazard paint on the bay's rear edge is a material, not a collision.
		for x in range(bay.position.x,bay.end.x):
			var cell := Vector2i(x,bay.position.y)
			if _resolve_tilemap().get_cell_source_id(cell) == 0:
				_ground.set_cell(cell,0,Vector2i(7,0))

func is_scenery_cell(cell: Vector2i) -> bool:
	return _reserved_cells.has(cell)

func configure_tower(tower: TowerBase) -> void:
	tower.deployment_scale = Vector2.ONE * UNIT_SCALE
	# An original circle projects into this 2:1 ellipse on the ground.
	tower.ground_range_scale = Vector2(sqrt(8.0),sqrt(2.0)) / UNIT_SCALE
	tower.combat_map = self

func ground_distance(from_world: Vector2, to_world: Vector2) -> float:
	var delta := to_local(to_world)-to_local(from_world)
	return Vector2(delta.x*0.25+delta.y*0.5,-delta.x*0.25+delta.y*0.5).length()

func get_gameplay_scale() -> Vector2:
	return scale * UNIT_SCALE
