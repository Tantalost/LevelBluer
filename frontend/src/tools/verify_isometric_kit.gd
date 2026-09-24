extends SceneTree
## Headless resource/occupancy checks. Add -- --render for a GPU screenshot
## saved only in .godot (not a shipped asset).
const BASE := "res://src/gameplay/maps/isometric/"
const ASSETS := "res://assets/gameplay/isometric/"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var floor_set := load(ASSETS + "industrial_floors.tres") as TileSet
	var scenery_set := load(ASSETS + "industrial_scenery.tres") as TileSet
	_check(floor_set != null and scenery_set != null, "TileSets load")
	_check(floor_set.tile_size == Vector2i(128,64), "Exact 128x64 cell")
	_check(floor_set.get_source(0).get_tiles_count() == 24, "24 ground materials/transitions")
	_check(floor_set.get_source(2).get_tiles_count() == 19, "19 border/corner masks")
	var map: Node2D = load(BASE + "isometric_map_template.tscn").instantiate()
	root.add_child(map)
	var ground := map.get_node("Ground") as TileMapLayer
	var scenery := map.get_node("Scenery") as TileMapLayer
	var origin := ground.map_to_local(Vector2i.ZERO)
	_check(ground.map_to_local(Vector2i.RIGHT) - origin == Vector2(64,32), "X grid projection")
	_check(ground.map_to_local(Vector2i.DOWN) - origin == Vector2(-64,32), "Y grid projection")
	for y in range(-2, 6):
		for x in range(-2, 6):
			var cell := Vector2i(x,y)
			_check(ground.local_to_map(ground.map_to_local(cell)) == cell, "Cell round trip")
			ground.set_cell(cell, 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(-2,-2), 1, Vector2i.ZERO)
	_check(not map.call("is_buildable", Vector2i(-2,-2)), "Route prevents building")
	_check(map.call("is_buildable", Vector2i(4,4)), "Empty ground permits building")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "module_registry.json"))
	var module: Dictionary = registry.fan_array
	_check(map.call("place_module", int(module.source), int(module.scene), Vector2i.ZERO), "Place 2x2 module")
	_check(map.call("occupied_cells").size() == 4, "Reloaded scene reserves all four cells")
	_check(not map.call("is_buildable", Vector2i(1,1)), "Non-anchor occupied cell blocks building")
	_check(not map.call("place_module", int(module.source), int(module.scene), Vector2i.ONE), "Reject overlapping footprints")
	_check(not map.call("place_module", int(module.source), int(module.scene), Vector2i(5,5)), "Reject overhanging footprints")
	_check(map.call("placement_issues").is_empty(), "Valid placement has no warnings")
	scenery.set_cell(Vector2i(1,1), int(module.source), Vector2i.ZERO, int(module.scene))
	_check(not map.call("placement_issues").is_empty(), "Native overlapping paint reports warning")
	scenery.erase_cell(Vector2i(1,1))
	var scene_count := 0
	for index in scenery_set.get_source_count():
		var source := scenery_set.get_source(scenery_set.get_source_id(index)) as TileSetScenesCollectionSource
		for tile_index in source.get_scene_tiles_count():
			var packed := source.get_scene_tile_scene(source.get_scene_tile_id(tile_index))
			var instance := packed.instantiate()
			_check(instance.get("occupied_cells").size() > 0, "Module has footprint")
			_check(instance.get_node("Artwork").texture.atlas.resource_path == ASSETS + "industrial_atlas_texture.tres", "Shared cached atlas")
			if instance.get("blocks_movement"):
				_check(instance.get_node("FootprintCollision").get_child_count() == instance.get("occupied_cells").size(), "Collision covers full footprint")
			instance.free()
			scene_count += 1
	_check(scene_count == registry.size(), "Every registry module is paintable")
	await process_frame
	await process_frame
	_check(scenery.get_child_count() >= 1, "Scene tile actually instantiates")
	if FileAccess.file_exists("user://assets/map_industrial_atlas.png"):
		_verify_pixels()
	else:
		print("[SKIP ISOMETRIC PIXELS] Cloud atlas is not cached locally; structural checks still ran")
	map.free()
	print("[ISOMETRIC VERIFY] modules=", scene_count, " failures=", failures)
	if "--render" in OS.get_cmdline_user_args():
		await _render()
	quit(0 if failures == 0 else 1)

func _verify_pixels() -> void:
	var image := (load(ASSETS + "industrial_atlas_texture.tres") as Texture2D).get_image()
	var counts: Dictionary = {}
	for cy in 4:
		for cx in 4:
			for y in 64:
				for x in 128:
					var alpha := image.get_pixel(x+2,y+2).a
					var expected := absf((x+0.5-64.0)/64.0) + absf((y+0.5-32.0)/32.0) < 1.0
					_check((alpha == 1.0) == expected, "Floor alpha matches exact diamond")
					if alpha == 1.0:
						var point := Vector2i(64*(cx-cy)+x-64, 32*(cx+cy)+y-32)
						counts[point] = int(counts.get(point,0)) + 1
	for y in range(-32, 224):
		for x in range(-256,256):
			var u := ((x+0.5)/64.0+(y+0.5)/32.0)*0.5
			var v := ((y+0.5)/32.0-(x+0.5)/64.0)*0.5
			if u > -0.5 and u < 3.5 and v > -0.5 and v < 3.5:
				_check(counts.get(Vector2i(x,y),0) == 1, "No holes or overlaps in 4x4 joined floor")
	print("[ISOMETRIC VERIFY] joined floor pixels=", counts.size())

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400,1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var workbench: Node2D = load(BASE + "industrial_kit_workbench.tscn").instantiate()
	viewport.add_child(workbench)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	_check(result != null and not result.is_empty(), "Rendered preview exists")
	if result != null:
		result.save_png("res://.godot/isometric_workbench_verify.png")
	# Close-up verifies floor joins and true scene sprites at their cell anchors.
	var camera := workbench.get_node("PreviewCamera") as Camera2D
	camera.position = Vector2(-1024,720)
	camera.zoom = Vector2(0.9,0.9)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.godot/isometric_closeup_verify.png")
	viewport.queue_free()
