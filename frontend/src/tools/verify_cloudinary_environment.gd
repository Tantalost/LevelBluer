extends SceneTree
## --download validates only the seven supplied URLs and populates the asset cache.
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
	var entries: Array = assets._map_environment_catalog()
	_check(entries.size() == 7, "Seven environment assets registered")
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
