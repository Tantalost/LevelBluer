extends SceneTree
## Stage 1 integration check. -- --render saves ignored preview captures.
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var router := root.get_node("Router")
	router.set("active_stage_index",0)
	router.set("is_tutorial",false)
	var level: Node = load("res://src/gameplay/level_base.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var manager := level.get_node("LevelManager")
	manager.change_phase(2)
	var map := level.get_node("Environment/MapMount").get_child(0) as Node2D
	var grid := map.get_node("TileMapLayer") as TileMapLayer
	var track := map.get_node("Path2D") as Path2D
	_check(map.get_script().resource_path.ends_with("stage_one_isometric.gd"), "Live Stage 1 mounts the isometric scene")
	_check(map.get_node_or_null("StageOneBackdrop") == null, "No old baked background")
	_check(not level.get_node("Environment/LevelWorld").visible, "Legacy forest/road/castle is hidden")
	var layout := MapDesigns.get_layout("map_basic")
	var expected_centers := 0
	var actual_centers := 0
	for y in layout.size():
		for x in layout[y].length():
			var cell := Vector2i(x,y)
			var expected: bool = layout[y][x] == "#" and not map.call("is_scenery_cell",cell)
			_check(grid._cell_is_buildable(cell,grid.get_cell_tile_data(cell)) == expected, "Buildability preserved at " + str(cell))
			var legal := true
			for dy in range(-1,2):
				for dx in range(-1,2):
					if y+dy < 0 or y+dy >= 13 or x+dx < 0 or x+dx >= 32 or layout[y+dy][x+dx] != "#":
						legal = false
					if map.call("is_scenery_cell",Vector2i(x+dx,y+dy)):
						legal = false
			if legal: expected_centers += 1
			if grid._can_drop(cell): actual_centers += 1
	_check(grid.get_used_cells().size()==416,"416 unchanged logical cells")
	_check(actual_centers == expected_centers,"Scenery-aware 3x3 placement centers match")
	_check(actual_centers >= 100,"Enough deployment centers remain around scenery")
	var distance: float = map.call("ground_distance",grid.to_global(grid.map_to_local(Vector2i(5,5))),grid.to_global(grid.map_to_local(Vector2i(6,5))))
	_check(is_equal_approx(distance,32.0),"Combat distances use original ground units")
	var step := Vector2(64,32).length()
	_check(is_equal_approx(track.curve.get_baked_length(),35.0*step),"Same 35-cell route length")
	_check(track.to_global(track.curve.get_point_position(0)).distance_to(map.get_start_global_position())<0.01,"Spawn aligned")
	_check(track.to_global(track.curve.get_point_position(track.curve.point_count-1)).distance_to(map.get_end_global_position())<0.01,"Base aligned")
	_check(level.get_node("Environment/PlayerBase").global_position.distance_to(map.get_end_global_position())<0.01,"PlayerBase collider uses the generated endpoint")
	_check(manager._map_endpoint_visuals != null,"Health hook bound after endpoint generation")
	var enemy := load("res://src/gameplay/enemy_base.tscn").instantiate() as PathFollow2D
	enemy.initialize_stats("basic",1.0)
	track.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.progress=0
	enemy._physics_process(32.0/enemy.move_speed)
	_check(absf(enemy.progress-step)<0.01,"Enemy keeps original time per cell")
	enemy.visible=false
	await process_frame
	await process_frame
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/stage_one_isometric_clean.png")
	# Place via the real shop/occupancy path, then verify animation and combat.
	manager.current_gold = 20
	grid._try_place(Vector2i(8,4))
	var tower: Node2D = grid._tower_at(Vector2i(8,4))
	_check(tower != null,"Real tower placement succeeds")
	if tower != null:
		tower.set_process(false)
		enemy.progress=8.0*step
		enemy.visible=true
		for i in 30: await physics_frame
		_check(tower.scale.distance_to(Vector2.ONE*sqrt(5.0))<0.01,"Deploy animation retains isometric actor scale")
		_check(tower.targets_in_range.has(enemy.get_node("Hitbox")),"Projected range acquires enemy")
		tower.current_target=enemy
		tower.get_node("TurretPivot").rotation=tower.to_local(enemy.global_position).angle()
		var hp_before: int = enemy.current_health
		tower._fire()
		for i in 40: await physics_frame
		_check(enemy.current_health < hp_before,"Aimed projectile reaches and damages enemy")
		grid._drag_kind=1
		grid._drag_cell=Vector2i(18,4)
		grid._hover_valid=true
		grid._pad_overlay.queue_redraw()
		if "--render" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/stage_one_isometric_combat.png")
	# Old-map route at (0,0) atlas coordinates must not regress.
	var old := load("res://src/gameplay/maps/map_switchback.tscn").instantiate() as Node2D
	root.add_child(old)
	var old_grid := old.get_node("TileMapLayer") as TileMapLayer
	old_grid.bind_level_manager(manager)
	_check(old_grid.tile_set.tile_size==Vector2i(32,32),"Stage 2 remains square-grid")
	_check(not old_grid._cell_is_buildable(Vector2i(0,1),old_grid.get_cell_tile_data(Vector2i(0,1))),"Stage 2 route still blocks towers")
	old.free()
	print("[STAGE 1 ISO] cells=416 legal_centers=",actual_centers," expected=",expected_centers," failures=",failures)
	level.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
