extends SceneTree
## Deterministic conversion of the approved sheet; no new AI images.
## Run -- --atlas, import the PNG, then run -- --resources.
const OUT := "res://assets/gameplay/isometric"
const SCENES := "res://src/gameplay/maps/isometric"
const MANIFEST := "res://src/tools/isometric_kit_manifest.json"
const ATLAS_PATH := OUT + "/industrial_atlas.png"
const CATALOG_PATH := OUT + "/industrial_catalog.json"
const FLOOR_NAMES := [
	"concrete", "concrete_alt", "cracked", "oil_stained", "worn",
	"metal", "grate", "hazard", "access_cover", "technical",
	"concrete_rotated", "concrete_alt_rotated", "cracked_rotated",
	"oil_stained_rotated", "worn_rotated", "metal_rotated",
	"concrete_metal_e", "concrete_metal_s", "concrete_metal_w", "concrete_metal_n",
	"concrete_grate_e", "concrete_grate_s", "concrete_grate_w", "concrete_grate_n"]
var _catalog: Dictionary
var _source: Image
var _atlas: Image
var _pen := Vector2i(2, 278)
var _shelf_height := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENES + "/modules"))
	if "--atlas" in OS.get_cmdline_user_args():
		_build_atlas()
	elif "--resources" in OS.get_cmdline_user_args():
		_build_resources()
	else:
		push_error("Specify -- --atlas or -- --resources.")
		quit(1)
		return
	quit()

func _read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")

func _build_atlas() -> void:
	var manifest := _read_json(MANIFEST)
	var source_path := ProjectSettings.globalize_path("res://../" + str(manifest.source))
	_source = Image.load_from_file(source_path)
	assert(_source != null and _source.get_size() == Vector2i(1086, 1448), "Unexpected source dimensions.")
	_atlas = Image.create(2048, 4096, false, Image.FORMAT_RGBA8)
	_catalog = {"tile_size": [128, 64], "floors": [], "props": [], "texture": ATLAS_PATH}
	var floors: Array[Image] = []
	for index in 16:
		var source_index: int = index if index < 10 else index - 10
		var values: Array = manifest.floor_rects[source_index]
		var rect := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		floors.append(_floor(rect, index >= 10))
	for index in 8:
		floors.append(_transition(floors[0], floors[5 if index < 4 else 6], index % 4))
	for index in floors.size():
		_put_floor(floors[index], index, FLOOR_NAMES[index], "ground")
	for mask in range(1, 16):
		_put_floor(_edge(mask, -1), 23 + mask, "edge_mask_%02d" % mask, "overlay")
	for corner in 4:
		_put_floor(_edge(0, corner), 39 + corner, "inner_corner_%d" % corner, "overlay")
	for definition in manifest.props:
		_pack_prop(definition)
	var used_height := ceili(float(_pen.y + _shelf_height + 2) / 64.0) * 64
	var packed_atlas := _atlas.get_region(Rect2i(0, 0, 2048, used_height))
	assert(packed_atlas.save_png(ATLAS_PATH) == OK)
	_catalog["atlas_size"] = [2048, used_height]
	_write_json(CATALOG_PATH, _catalog)
	print("Packed ", _catalog.floors.size(), " floor/edge tiles and ", _catalog.props.size(), " modules into ", packed_atlas.get_size())

func _sample(x: float, y: float) -> Color:
	var x0 := clampi(floori(x), 0, _source.get_width() - 2)
	var y0 := clampi(floori(y), 0, _source.get_height() - 2)
	var a := _source.get_pixel(x0, y0).lerp(_source.get_pixel(x0 + 1, y0), x - x0)
	var b := _source.get_pixel(x0, y0 + 1).lerp(_source.get_pixel(x0 + 1, y0 + 1), x - x0)
	return a.lerp(b, y - y0)

func _floor(rect: Rect2i, rotated: bool) -> Image:
	var tile := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 128:
			var nx := (x + 0.5 - 64.0) / 64.0
			var ny := (y + 0.5 - 32.0) / 32.0
			var distance := absf(nx) + absf(ny)
			if distance > 1.0:
				continue
			# Sample inside the authored bevel, reproject to an exact 2:1 top.
			var sx: float = -nx if rotated else nx
			var sy: float = -ny if rotated else ny
			var sample_color := _sample(rect.position.x + rect.size.x * (0.5 + sx * 0.43),
				rect.position.y + rect.size.y * (0.48 + sy * 0.40))
			# A shared neutral perimeter prevents cracks/alpha pinholes and
			# keeps all material edges compatible under nearest filtering.
			var edge_color := Color(0.255, 0.285, 0.30, 1.0)
			var fade := smoothstep(0.0, 0.12, 1.0 - distance)
			var color := edge_color.lerp(sample_color, fade)
			color.a = 1.0
			tile.set_pixel(x, y, color)
	return tile

func _transition(a: Image, b: Image, orientation: int) -> Image:
	var tile := a.duplicate() as Image
	for y in 64:
		for x in 128:
			if a.get_pixel(x, y).a == 0:
				continue
			var nx := (x + 0.5 - 64.0) / 64.0
			var ny := (y + 0.5 - 32.0) / 32.0
			var axis: float = nx + ny if orientation % 2 == 0 else ny - nx
			if orientation >= 2:
				axis = -axis
			tile.set_pixel(x, y, a.get_pixel(x, y).lerp(b.get_pixel(x, y), smoothstep(-0.15, 0.15, axis)))
	return tile

func _edge(mask: int, corner: int) -> Image:
	var tile := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 128:
			var nx := (x + 0.5 - 64.0) / 64.0
			var ny := (y + 0.5 - 32.0) / 32.0
			var u := (nx + ny + 1.0) * 0.5
			var v := (ny - nx + 1.0) * 0.5
			if minf(u, v) < 0 or maxf(u, v) > 1:
				continue
			var distances := [1.0 - u, 1.0 - v, u, v]
			var edge_distance := 1.0
			for side in 4:
				if mask & (1 << side):
					edge_distance = minf(edge_distance, distances[side])
			if corner >= 0:
				edge_distance = maxf(distances[corner], distances[(corner + 1) % 4])
			if edge_distance < 0.09:
				var color := Color("54616a") if edge_distance > 0.018 else Color("1a242b")
				if edge_distance > 0.065:
					color = Color("89949b")
				tile.set_pixel(x, y, color)
	return tile

func _put_floor(tile: Image, index: int, id: String, kind: String) -> void:
	var coords := Vector2i(index % 12, index / 12)
	var origin := Vector2i(2, 2) + coords * Vector2i(132, 68)
	_atlas.blit_rect(tile, Rect2i(0, 0, 128, 64), origin)
	_catalog.floors.append({"id": id, "kind": kind, "coords": [coords.x, coords.y]})

func _pack_prop(definition: Dictionary) -> void:
	var r: Array = definition.rect
	var crop := _source.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	# Discard low-alpha extraction noise before tight-bounding each sprite.
	for y in crop.get_height():
		for x in crop.get_width():
			var c := crop.get_pixel(x, y)
			if c.a < 0.35:
				crop.set_pixel(x, y, Color.TRANSPARENT)
	_remove_crop_fragments(crop, str(definition.category) == "decoration")
	var used := crop.get_used_rect()
	assert(used.has_area(), "Empty module: " + str(definition.id))
	crop = crop.get_region(used)
	var cells: Array = definition.footprint
	var w := 1
	var h := 1
	for cell in cells:
		w = maxi(w, int(cell[0]) + 1)
		h = maxi(h, int(cell[1]) + 1)
	# Thin wall/rail modules occupy a boundary of their declared cells.
	var thin: bool = str(definition.category) in ["walls", "doors", "edges"] or str(definition.id).begins_with("railing") or str(definition.id).begins_with("fence")
	var target_width: int = 64 * (w + h)
	if thin:
		target_width = 64 * maxi(w, h) + 16
	elif str(definition.category) == "decoration":
		target_width = 82 if w == 1 else 150
	if str(definition.id) in ["wall_end", "wall_post", "pipe_riser", "tank_vertical", "hydrant", "light_bollard"]:
		target_width = roundi(crop.get_width() * 1.28)
	var scale_factor := float(target_width) / float(crop.get_width())
	crop.resize(target_width, maxi(1, roundi(crop.get_height() * scale_factor)), Image.INTERPOLATE_LANCZOS)
	for y in crop.get_height():
		for x in crop.get_width():
			if crop.get_pixel(x, y).a < 0.01:
				crop.set_pixel(x, y, Color.TRANSPARENT)
	if _pen.x + crop.get_width() + 2 > 2048:
		_pen.x = 2
		_pen.y += _shelf_height + 4
		_shelf_height = 0
	assert(_pen.y + crop.get_height() < 4096, "Atlas overflow")
	_atlas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), _pen)
	var entry := definition.duplicate(true)
	entry["atlas_rect"] = [_pen.x, _pen.y, crop.get_width(), crop.get_height()]
	entry["ground_front"] = 32 * (w + h - 1)
	entry["visual_center_x"] = 32 * (w - h)
	entry["source_trim"] = [used.position.x, used.position.y, used.size.x, used.size.y]
	_catalog.props.append(entry)
	_pen.x += crop.get_width() + 4
	_shelf_height = maxi(_shelf_height, crop.get_height())

func _remove_crop_fragments(crop: Image, keep_scattered: bool) -> void:
	var seen := PackedByteArray()
	seen.resize(crop.get_width() * crop.get_height())
	var components: Array = []
	var largest := 0
	for y in crop.get_height():
		for x in crop.get_width():
			var index := y * crop.get_width() + x
			if seen[index] or crop.get_pixel(x, y).a < 0.35:
				continue
			var queue: Array[Vector2i] = [Vector2i(x,y)]
			seen[index] = 1
			var cursor := 0
			while cursor < queue.size():
				var p := queue[cursor]
				cursor += 1
				for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var next: Vector2i = p + offset
					if next.x < 0 or next.y < 0 or next.x >= crop.get_width() or next.y >= crop.get_height():
						continue
					var next_index := next.y * crop.get_width() + next.x
					if not seen[next_index] and crop.get_pixelv(next).a >= 0.35:
						seen[next_index] = 1
						queue.append(next)
			components.append(queue)
			largest = maxi(largest, queue.size())
	for component in components:
		if component.size() < (maxi(8, largest / 30) if keep_scattered else largest):
			for point in component:
				crop.set_pixelv(point, Color.TRANSPARENT)

func _new_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(128, 64)
	return tileset

func _save(resource: Resource, path: String) -> void:
	assert(ResourceSaver.save(resource, path) == OK, "Save failed: " + path)
	# Subsequent resources must reference this file, not embed another copy.
	resource.take_over_path(path)

func _build_resources() -> void:
	_catalog = _read_json(CATALOG_PATH)
	var atlas := load(OUT + "/industrial_atlas_texture.tres") as ImageTexture
	assert(atlas != null, "Runtime atlas resource must exist.")
	if FileAccess.file_exists(ATLAS_PATH):
		atlas.set_image(Image.load_from_file(ATLAS_PATH))
	var floor_set := _new_tileset()
	floor_set.resource_name = "Industrial Floors — 128x64"
	for field in [["asset_id", TYPE_STRING], ["is_buildable", TYPE_BOOL], ["is_walkable", TYPE_BOOL]]:
		var index := floor_set.get_custom_data_layers_count()
		floor_set.add_custom_data_layer()
		floor_set.set_custom_data_layer_name(index, field[0])
		floor_set.set_custom_data_layer_type(index, field[1])
	for source_id in 3:
		var source := TileSetAtlasSource.new()
		source.texture = atlas
		source.texture_region_size = Vector2i(128, 64)
		source.margins = Vector2i(2, 2)
		source.separation = Vector2i(4, 4)
		source.resource_name = ["Buildable Floor", "Route Floor", "Edges and Corners"][source_id]
		floor_set.add_source(source, source_id)
		for definition in _catalog.floors:
			if (source_id == 2) != (definition.kind == "overlay"):
				continue
			var coords := Vector2i(int(definition.coords[0]), int(definition.coords[1]))
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			data.set_custom_data("asset_id", definition.id)
			data.set_custom_data("is_buildable", source_id == 0)
			data.set_custom_data("is_walkable", source_id != 2)
	_save(floor_set, OUT + "/industrial_floors.tres")
	var scenery_set := _new_tileset()
	scenery_set.resource_name = "Industrial Scenery — Multi-cell Modules"
	var categories: Dictionary = {}
	var registry: Dictionary = {}
	for definition in _catalog.props:
		var category: String = definition.category
		if not categories.has(category):
			var source := TileSetScenesCollectionSource.new()
			source.resource_name = category.capitalize()
			var source_id := categories.size() + 10
			scenery_set.add_source(source, source_id)
			categories[category] = source_id
		var source_id: int = categories[category]
		var source := scenery_set.get_source(source_id) as TileSetScenesCollectionSource
		for mirrored in ([false, true] if definition.mirror else [false]):
			var packed := _module_scene(definition, atlas, mirrored)
			var scene_id := source.create_scene_tile(packed)
			source.set_scene_tile_display_placeholder(scene_id, false)
			registry[str(packed.get_meta("module_id"))] = {"source": source_id, "scene": scene_id, "footprint": packed.get_meta("footprint_json"), "blocks_movement": definition.blocks_movement}
	_save(scenery_set, OUT + "/industrial_scenery.tres")
	_write_json(OUT + "/module_registry.json", registry)
	_make_map(floor_set, scenery_set, registry, false)
	_make_map(floor_set, scenery_set, registry, true)
	print("Created floor TileSet, ", registry.size(), " scenery variants, empty map and kit workbench.")

func _module_scene(definition: Dictionary, atlas: Texture2D, mirrored: bool) -> PackedScene:
	var id: String = str(definition.id) + ("_mirrored" if mirrored else "")
	var root := Node2D.new()
	root.name = id.to_pascal_case()
	root.set_script(load(SCENES + "/isometric_module.gd"))
	root.y_sort_enabled = true
	root.set("module_id", StringName(id))
	var footprint: Array[Vector2i] = []
	var json_cells: Array = []
	for coords in definition.footprint:
		var cell := Vector2i(int(coords[0]), int(coords[1]))
		if mirrored:
			cell = Vector2i(cell.y, cell.x)
		footprint.append(cell)
		json_cells.append([cell.x, cell.y])
	root.set("occupied_cells", footprint)
	root.set("blocks_movement", definition.blocks_movement)
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	var rect: Array = definition.atlas_rect
	texture.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	texture.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = "Artwork"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.flip_h = mirrored
	sprite.position = Vector2(float(definition.visual_center_x) * (-1.0 if mirrored else 1.0), float(definition.ground_front))
	sprite.offset = Vector2(0.0, -float(rect[3]) * 0.5)
	root.add_child(sprite)
	sprite.owner = root
	if definition.blocks_movement:
		var body := StaticBody2D.new()
		body.name = "FootprintCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)
		body.owner = root
		for cell in footprint:
			var collision := CollisionPolygon2D.new()
			collision.position = Vector2(64 * (cell.x - cell.y), 32 * (cell.x + cell.y))
			collision.polygon = PackedVector2Array([Vector2(0,-32), Vector2(64,0), Vector2(0,32), Vector2(-64,0)])
			body.add_child(collision)
			collision.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	packed.set_meta("module_id", id)
	packed.set_meta("occupied_cells", footprint)
	packed.set_meta("footprint_json", json_cells)
	packed.set_meta("blocks_movement", definition.blocks_movement)
	_save(packed, SCENES + "/modules/" + id + ".tscn")
	root.free()
	return packed

func _make_map(floor_set: TileSet, scenery_set: TileSet, registry: Dictionary, demo: bool) -> void:
	var root := Node2D.new()
	root.name = "IndustrialKitWorkbench" if demo else "IsometricMap"
	root.set_script(load(SCENES + "/isometric_map.gd"))
	root.y_sort_enabled = true
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = floor_set
	ground.z_index = -2
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var details := TileMapLayer.new()
	details.name = "FloorDetails"
	details.tile_set = floor_set
	details.z_index = -1
	details.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scenery := TileMapLayer.new()
	scenery.name = "Scenery"
	scenery.tile_set = scenery_set
	scenery.y_sort_enabled = true
	for layer in [ground, details, scenery]:
		root.add_child(layer)
		layer.owner = root
	if demo:
		# Separated test pads, not a stage layout.
		for index in 24:
			var origin := Vector2i((index % 6) * 4, (index / 6) * 4)
			for y in 3:
				for x in 3:
					ground.set_cell(origin + Vector2i(x,y), 0, Vector2i(index % 12, index / 12))
		var samples := ["wall_long", "wall_long_mirrored", "wall_outer_corner", "door_service_lit",
			"fan_small", "fan_array", "generator", "electrical_cabinet", "industrial_machine",
			"tank_horizontal", "barrier_long", "crate_metal", "container", "stairs", "ramp",
			"railing_long", "fence_long", "pipe_cluster", "utility_pole", "dumpster",
			"air_conditioner", "hvac_rooftop", "platform_concrete", "tank_vertical"]
		for index in samples.size():
			var origin := Vector2i((index % 6) * 4, (index / 6) * 4 + 18)
			for y in 3:
				for x in 3:
					ground.set_cell(origin + Vector2i(x,y), 0, Vector2i.ZERO)
			var module: Dictionary = registry[samples[index]]
			scenery.set_cell(origin, int(module.source), Vector2i.ZERO, int(module.scene))
		var camera := Camera2D.new()
		camera.name = "PreviewCamera"
		camera.position = Vector2(-320, 830)
		camera.zoom = Vector2(0.34, 0.34)
		camera.set_script(load(SCENES + "/kit_camera.gd"))
		root.add_child(camera)
		camera.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	_save(packed, SCENES + ("/industrial_kit_workbench.tscn" if demo else "/isometric_map_template.tscn"))
	root.free()
