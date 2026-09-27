extends SceneTree
## --download validates the supplied URLs and populates the asset cache.
## --story selects the 15 school story assets instead of the seven environment assets.
## Default mode verifies offline cache reuse and real scene bindings; no saves.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var assets := root.get_node("AssetManager")
	assets._ensure_assets_dir()
	if "--story" in OS.get_cmdline_user_args():
		await _verify_school_story(assets)
		print("[CLOUD STORY] failures=%d" % failures)
		quit(0 if failures == 0 else 1)
		return
	var entries: Array = assets._map_environment_catalog()
	_check(entries.size() == 7, "Seven environment assets registered")
	if not "--download" in OS.get_cmdline_user_args():
		for entry: Dictionary in entries:
			if not FileAccess.file_exists(str(entry.get("local_path", ""))):
				print("[SKIP CLOUD ENVIRONMENT] Offline asset cache is incomplete; run with --download in an authorized network environment.")
				quit(0 if failures == 0 else 1)
				return
	for entry in entries:
		if "--download" in OS.get_cmdline_user_args():
			var success: bool = await assets._download_and_store(entry)
			_check(success and assets._is_cache_current(entry.asset_id, entry.cloudinary_url, entry.version, entry.local_path), "Remote download stored and versioned: " + entry.asset_id)
		var texture: Texture2D = assets.get_texture(entry.asset_id)
		_check(texture != null and FileAccess.file_exists(entry.local_path), "Cached texture available: " + entry.asset_id)
		if texture != null:
			print("[CLOUD ASSET] %s %s" % [entry.asset_id, texture.get_size()])
	if failures > 0:
		quit(1)
		return
	var endpoint: Node = load("res://src/gameplay/maps/map_endpoint_visuals.gd").new()
	root.add_child(endpoint)
	endpoint.configure(Vector2.ZERO, Vector2(200, 0))
	_check(endpoint.get_node("EnemySpawnSprite").texture == assets.get_texture("enemy_spawn_broken_pc"), "Enemy base uses cache")
	for health in [5, 3, 1]:
		endpoint.set_health(health)
		var id := "home_base_clean" if health == 5 else ("home_base_cracked" if health == 3 else "home_base_critical")
		_check(endpoint.get_node("HomeBaseSprite").texture == assets.get_texture(id), "Home health state uses cache")
	endpoint.play_home_destruction()
	_check(endpoint.get_node("BaseDestruction").texture == assets.get_texture("home_base_critical"), "Destruction uses cached critical sprite")
	endpoint.free()
	for map_id in ["map_switchback", "map_spiral"]:
		var map: Node = load("res://src/gameplay/maps/" + map_id + ".tscn").instantiate()
		root.add_child(map)
		var id := "map_module_1_stage_2" if map_id == "map_switchback" else "map_module_1_stage_3"
		_check(map.get_node("StageBackdrop").texture == assets.get_texture(id), "Baked map uses cache: " + map_id)
		map.free()
	var floor_set: TileSet = load("res://assets/gameplay/isometric/industrial_floors.tres")
	var atlas: Texture2D = assets.get_texture("map_industrial_atlas")
	_check(atlas.get_size() == Vector2(2048, 2048), "Exact packed atlas dimensions")
	_check(not atlas.get_image().is_invisible(), "Atlas is not the empty startup placeholder")
	_check(floor_set.get_source(0).texture == atlas, "Floors share cached atlas")
	var module: Node = load("res://src/gameplay/maps/isometric/modules/fan_array.tscn").instantiate()
	_check(module.get_node("Artwork").texture.atlas == atlas, "Scenery shares cached atlas")
	module.free()
	print("[CLOUD ENVIRONMENT] failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _verify_school_story(assets: Node) -> void:
	var entries: Array[Dictionary] = assets._school_story_catalog()
	_check(entries.size() == 15, "Three portraits and twelve locations registered")
	for entry: Dictionary in entries:
		var id: String = str(entry.asset_id)
		if "--download" in OS.get_cmdline_user_args():
			var success: bool = await assets._download_and_store(entry)
			_check(success and assets._is_cache_current(id, entry.cloudinary_url, entry.version, entry.local_path), "Remote story asset cached and versioned: " + id)
		# Force the same disk-only load used on the next offline launch.
		assets._textures.erase(id)
		var texture: Texture2D = assets.get_texture(id)
		_check(texture != null, "Offline story texture available: " + id)
		if texture == null:
			continue
		var portrait: bool = id.begins_with("story_portrait_")
		_check(texture.get_size() == (Vector2(2172, 724) if portrait else Vector2(800, 400)), "Original dimensions retained: " + id)
		if portrait:
			_check(texture.get_image().get_pixel(0, 0).a == 0.0, "Portrait transparency retained: " + id)
	if failures > 0:
		return
	var portrait_script: GDScript = load("res://src/gameplay/decision/dialogue_portrait.gd")
	var workspace: Control = load("res://src/gameplay/decision/decision_workspace.gd").new()
	root.add_child(workspace)
	workspace.set_story_art("mod_01", "Ms. Reyes")
	workspace.set_background("hallway_day")
	var lines: Array[Dictionary] = [{"speaker": "Alex", "text": "My inbox just buzzed."}]
	workspace.show_story(lines, "School story cache check")
	_check(workspace._background_art.texture == assets.get_texture("story_bg_hallway_day"), "Scene binds cached location")
	for who: String in ["Alex", "Mia", "Ms. Reyes"]:
		for mood: String in ["neutral", "worried", "relieved"]:
			_check(portrait_script.school_expression(who, mood) is AtlasTexture, "Cached expression available: " + who + "/" + mood)
	# Simulate a first-launch cache miss in memory only; never delete a user's cache.
	var sheet: Texture2D = assets.get_texture("story_portrait_alex")
	var background: Texture2D = assets.get_texture("story_bg_hallway_day")
	assets._textures["story_portrait_alex"] = null
	assets._textures["story_bg_hallway_day"] = null
	assets.sync_finished.emit(false)
	_check(workspace._portraits[0].portrait_texture == null, "Missing portrait uses procedural fallback")
	_check(workspace._background_art.texture == null and not workspace._background_art.visible, "Missing location uses the themed panel")
	assets._textures["story_portrait_alex"] = sheet
	assets._textures["story_bg_hallway_day"] = background
	assets.sync_finished.emit(true)
	_check(workspace._portraits[0].portrait_texture is AtlasTexture and workspace._background_art.texture == background, "Late cache arrival refreshes the open scene")
	_check(workspace._line_index == 0 and workspace._typing, "Asset refresh never advances or restarts dialogue")
	var subscribers: int = assets.sync_finished.get_connections().size()
	workspace.free()
	_check(assets.sync_finished.get_connections().size() == subscribers - 1, "Freed workspace disconnects its cache signal")
