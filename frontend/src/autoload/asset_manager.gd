extends Node
## Autoload singleton, registered as "AssetManager".
## Cloudinary is the remote source only. Gameplay loads PNG files from user://assets/.

signal sync_finished(success: bool)
signal sync_progress(done: int, total: int, status: String)

const DB_PATH := "user://levelblue_assets"
const ASSETS_DIR := "user://assets"
const BUNDLED_DIR := "res://assets/enemies"
const CLOUD_ROOT := "https://res.cloudinary.com/nfd5bhkz/image/upload"
const CATALOG_REV := "npc-expr-1"
const DOWNLOAD_TIMEOUT_SEC := 15.0
const BODY_SIZE_LIMIT := 8 * 1024 * 1024
const WALK_FPS := 8.0
const DEATH_FPS := 10.0

const CREATE_ASSETS_SQL := """
CREATE TABLE IF NOT EXISTS assets (
	asset_id TEXT NOT NULL PRIMARY KEY,
	asset_name TEXT NOT NULL,
	asset_type TEXT NOT NULL,
	cloudinary_url TEXT NOT NULL,
	local_path TEXT NOT NULL,
	version TEXT NOT NULL DEFAULT '',
	downloaded_at TEXT DEFAULT (datetime('now')),
	file_hash TEXT DEFAULT ''
);
"""

var _db: SQLite
var _db_ok: bool = false
var _http: HTTPRequest
var _syncing: bool = false
var _synced: bool = false
var _textures: Dictionary = {}
var _character_frames: Dictionary = {}
var _online: bool = false
var _network_blocked: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = DOWNLOAD_TIMEOUT_SEC
	_http.use_threads = true
	_http.body_size_limit = BODY_SIZE_LIMIT
	_configure_tls(false)
	add_child(_http)
	_open_db()


func is_available() -> bool:
	return _db_ok and _db != null


func is_online() -> bool:
	return _online


func ensure_ready() -> void:
	if _syncing:
		await sync_finished
	else:
		await sync_catalog()
	var playable: PackedStringArray = playable_characters()
	for i in playable.size():
		get_character_sprite_frames(playable[i])
	await get_tree().process_frame


func sync_catalog() -> void:
	if _syncing:
		await sync_finished
		return
	_syncing = true
	_network_blocked = false
	_online = false
	_character_frames.clear()
	_ensure_assets_dir()
	sync_progress.emit(0, 1, "LOADING_ASSETS_CHECK")
	_seed_from_bundle()
	_hydrate_from_disk()
	var all_ok: bool = true
	var catalog: Array[Dictionary] = _gameplay_catalog()
	var total: int = catalog.size()
	for i in total:
		var entry: Dictionary = catalog[i]
		sync_progress.emit(i, total, str(entry.get("asset_name", "asset")))
		var ok: bool = await _sync_entry(entry)
		if not ok:
			all_ok = false
		sync_progress.emit(i + 1, total, str(entry.get("asset_name", "asset")))
	_synced = true
	_syncing = false
	if all_ok:
		print("[AssetManager] Catalog ready. online=", _online)
	else:
		push_warning("AssetManager: catalog finished with missing or failed assets. online=%s" % _online)
	sync_finished.emit(all_ok)


func get_texture(asset_id: String) -> Texture2D:
	if asset_id.is_empty():
		return null
	if _textures.has(asset_id):
		var cached: Variant = _textures[asset_id]
		return cached as Texture2D
	var local_path: String = _local_path_for(asset_id)
	var texture: Texture2D = _load_texture_from_disk(local_path)
	if texture == null:
		texture = _load_bundled_texture(asset_id)
	if texture != null:
		_textures[asset_id] = texture
	return texture


func bind_texture(target: CanvasItem, asset_id: String) -> void:
	if target == null or asset_id.is_empty():
		return
	var texture: Texture2D = get_texture(asset_id)
	if texture == null:
		return
	var rect: TextureRect = target as TextureRect
	if rect != null:
		rect.texture = texture
		return
	var sprite: Sprite2D = target as Sprite2D
	if sprite != null:
		sprite.texture = texture


func has_hacker_sprites() -> bool:
	return has_character_sprites("hacker")


func has_character_sprites(character_id: String) -> bool:
	return get_character_walk(character_id, true) != null or get_character_walk(character_id, false) != null


func playable_characters() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(["hacker", "ransomware", "phisherman"])
	var playable: PackedStringArray = PackedStringArray()
	for i in ids.size():
		if has_character_sprites(ids[i]):
			playable.append(ids[i])
	return playable


func pick_random_character() -> String:
	var playable: PackedStringArray = playable_characters()
	if playable.is_empty():
		return ""
	return playable[randi() % playable.size()]


func has_required_gameplay_assets() -> bool:
	return not playable_characters().is_empty()


func get_character_walk(character_id: String, side: bool) -> Texture2D:
	var primary: String = "%s_walk_side" % character_id if side else "%s_walk_top" % character_id
	var fallback: String = "%s_walk_top" % character_id if side else "%s_walk_side" % character_id
	var texture: Texture2D = get_texture(primary)
	if texture != null:
		return texture
	return get_texture(fallback)


func get_character_death(character_id: String, side: bool) -> Texture2D:
	var primary: String = "%s_death_side" % character_id if side else "%s_death_top" % character_id
	var fallback: String = "%s_death_top" % character_id if side else "%s_death_side" % character_id
	var texture: Texture2D = get_texture(primary)
	if texture != null:
		return texture
	var walk: Texture2D = get_character_walk(character_id, side)
	if walk != null:
		return walk
	return get_texture(fallback)


func get_hacker_walk(side: bool) -> Texture2D:
	return get_character_walk("hacker", side)


func get_hacker_death(side: bool) -> Texture2D:
	return get_character_death("hacker", side)


func get_hacker_sprite_frames() -> SpriteFrames:
	return get_character_sprite_frames("hacker")


func get_character_sprite_frames(character_id: String) -> SpriteFrames:
	if character_id.is_empty():
		return null
	if _character_frames.has(character_id):
		var cached: Variant = _character_frames[character_id]
		return cached as SpriteFrames
	if not has_character_sprites(character_id):
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	_add_sheet_animation(frames, &"walk_side", get_character_walk(character_id, true), true, WALK_FPS)
	_add_sheet_animation(frames, &"walk_top", get_character_walk(character_id, false), false, WALK_FPS)
	_add_sheet_animation(frames, &"death_side", get_character_death(character_id, true), true, DEATH_FPS)
	_add_sheet_animation(frames, &"death_top", get_character_death(character_id, false), false, DEATH_FPS)
	if not frames.has_animation(&"walk_side") and not frames.has_animation(&"walk_top"):
		return null
	_character_frames[character_id] = frames
	return frames


func _hacker_catalog() -> Array[Dictionary]:
	return _character_sheet_catalog("hacker", "assets/enemies/hacker", [
		["walk_side", "HACKER side-walking"],
		["walk_top", "HACKER top-down walking"],
		["death_side", "HACKER side-death"],
		["death_top", "HACKER top-down death"],
	])


func _gameplay_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	catalog.append(_catalog_entry(
		"map_module_1_stage_1",
		"Module 1 Stage 1 map",
		"image",
		"https://res.cloudinary.com/nfd5bhkz/image/upload/v1788767750/module_1_stage_1_25d_baked.png",
	))
	catalog.append(_catalog_entry(
		"tower_basic_node_base",
		"Basic Node armored base",
		"image",
		"https://res.cloudinary.com/nfd5bhkz/image/upload/v1788769625/basic_node_base_v1.png",
	))
	catalog.append(_catalog_entry(
		"tower_basic_node_head",
		"Basic Node rotating head",
		"image",
		"https://res.cloudinary.com/nfd5bhkz/image/upload/v1788769626/basic_node_head_v2.png",
	))
	catalog.append(_catalog_entry(
		"tower_basic_node_atlas",
		"Basic Node effects atlas",
		"image",
		"https://res.cloudinary.com/nfd5bhkz/image/upload/v1788769625/basic_node_atlas_v1.png",
	))
	catalog.append_array(_hacker_catalog())
	catalog.append_array(_character_sheet_catalog("ransomware", "assets/enemies/Ransomware", [
		["walk_side", "RANSOMWARE side-walking"],
		["walk_top", "RANSOMWARE top-down walking"],
		["death_side", "RANSOMWARE side-death"],
		["death_top", "RANSOMWARE top-down death"],
	]))
	catalog.append_array(_character_sheet_catalog("phisherman", "assets/enemies/phisherman", [
		["walk_side", "PHISHERMAN side-walking"],
		["walk_top", "PHISHERMAN top-down walking"],
		["death_side", "PHISHERMAN side-death"],
		["death_top", "PHISHERMAN top-down death"],
	]))
	catalog.append_array(_ui_catalog())
	return catalog


func _ui_catalog() -> Array[Dictionary]:
	return [
		_catalog_entry("ui_intro", "Intro cinematic art", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788338103/Gemini_Generated_Image_3bwb7g3bwb7g3bwb.jpg"),
		_catalog_entry("ui_intro_preview", "Intro title preview", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788338998/preview.png"),
		_catalog_entry("ui_module1_intro", "Module 1 comic intro", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788339918/Gemini_Generated_Image_fhsnvyfhsnvyfhsn.jpg"),
		_catalog_entry("ui_dashboard", "Dashboard art", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336649/dashboard.png"),
		_catalog_entry("ui_background", "Login background", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336648/background.png"),
		_catalog_entry("ui_logo", "Brand logo", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336656/logo.png"),
		_catalog_entry("ui_loading", "Loading mark", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336655/loading.png"),
		_catalog_entry("ui_pfp", "Profile portrait", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336662/tempo_pfp.jpg"),
		_catalog_entry("ui_setting", "Settings icon", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336659/setting.png"),
		_catalog_entry("ui_pause", "Pause icon", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336657/pause.png"),
		_catalog_entry("ui_speedup", "Speed icon", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336660/speedup.png"),
		_catalog_entry("ui_heart_full", "HP full", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336650/fullheart.png"),
		_catalog_entry("ui_heart_half", "HP half", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336652/halfheart.png"),
		_catalog_entry("ui_heart_empty", "HP empty", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336648/emptyheart.png"),
		_catalog_entry("npc_thoughtfulness", "NPC thoughtfulness", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689630/Thoughtfulness.png"),
		_catalog_entry("npc_talk", "NPC talk", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689629/Talk.png"),
		_catalog_entry("npc_smile", "NPC smile", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689629/Smile.png"),
		_catalog_entry("npc_skepticism", "NPC skepticism", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689629/Skepticism.png"),
		_catalog_entry("npc_scream", "NPC scream", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689628/Scream.png"),
		_catalog_entry("npc_sadness", "NPC sadness", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689627/Sadness.png"),
		_catalog_entry("npc_laughter", "NPC laughter", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689627/laughter.png"),
		_catalog_entry("npc_fear", "NPC fear", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689626/Fear.png"),
		_catalog_entry("npc_eye_rolling", "NPC eye rolling", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689626/Eye_rolling.png"),
		_catalog_entry("npc_calm", "NPC calm", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689625/Calm.png"),
		_catalog_entry("npc_cry", "NPC cry", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689626/Cry.png"),
		_catalog_entry("npc_discomfort", "NPC discomfort", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689626/Dscomfort.png"),
		_catalog_entry("npc_embarrassment", "NPC embarrassment", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689626/Embarrassment.png"),
		_catalog_entry("npc_doubt", "NPC doubt", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689626/Doubt.png"),
		_catalog_entry("npc_awkwardness", "NPC awkwardness", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689625/Awkwardness.png"),
		_catalog_entry("npc_disgust", "NPC disgust", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689625/Disgust.png"),
		_catalog_entry("npc_aggression", "NPC aggression", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689625/Aggression.png"),
		_catalog_entry("npc_astonishment", "NPC astonishment", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788689625/Astonishment.png"),
	]


func _character_sheet_catalog(character_id: String, folder: String, rows: Array) -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_ARRAY:
			continue
		var parts: Array = row
		if parts.size() < 2:
			continue
		var sheet_id: String = str(parts[0])
		catalog.append(_catalog_entry(
			"%s_%s" % [character_id, sheet_id],
			str(parts[1]),
			"sprite_sheet",
			"%s/%s_%s.png" % [folder, character_id, sheet_id],
		))
	return catalog


func _cloud_url(public_id: String) -> String:
	return "%s/%s" % [CLOUD_ROOT, public_id]


func _catalog_entry(asset_id: String, asset_name: String, asset_type: String, source: String) -> Dictionary:
	var url: String = source if source.begins_with("http") else _cloud_url(source)
	var version: String = _version_from_cloudinary_url(url)
	if version.is_empty():
		version = CATALOG_REV
	return {
		"asset_id": asset_id,
		"asset_name": asset_name,
		"asset_type": asset_type,
		"cloudinary_url": url,
		"version": version,
		"local_path": _local_path_for(asset_id),
	}


func _sync_entry(entry: Dictionary) -> bool:
	var asset_id: String = str(entry.get("asset_id", ""))
	var url: String = str(entry.get("cloudinary_url", ""))
	var version: String = str(entry.get("version", ""))
	var local_path: String = str(entry.get("local_path", _local_path_for(asset_id)))
	if asset_id.is_empty() or url.is_empty():
		push_warning("AssetManager: invalid catalog entry.")
		return false
	if _is_cache_current(asset_id, url, version, local_path):
		if get_texture(asset_id) != null:
			return true
		push_warning("AssetManager: cached file for '%s' is not a valid image." % asset_id)
		_textures.erase(asset_id)
	if _network_blocked:
		return _use_local_fallback(asset_id, local_path, true)
	return await _download_and_store(entry)


func _is_cache_current(asset_id: String, url: String, version: String, local_path: String) -> bool:
	if not FileAccess.file_exists(local_path):
		return false
	var meta: Dictionary = _read_meta(asset_id)
	if meta.is_empty():
		return false
	if str(meta.get("cloudinary_url", "")) != url:
		return false
	if str(meta.get("version", "")) != version:
		return false
	var stored_hash: String = str(meta.get("file_hash", ""))
	if stored_hash.is_empty():
		return true
	var disk_hash: String = _hash_file(local_path)
	if disk_hash.is_empty():
		return false
	if disk_hash != stored_hash:
		push_warning("AssetManager: hash mismatch for '%s'; will refresh if online." % asset_id)
		return false
	return true


func _download_and_store(entry: Dictionary) -> bool:
	var asset_id: String = str(entry.get("asset_id", ""))
	var url: String = str(entry.get("cloudinary_url", ""))
	var local_path: String = str(entry.get("local_path", ""))
	var response: Dictionary = await _http_get(url, FileAccess.file_exists(local_path))
	if not bool(response.get("ok", false)):
		var error_text: String = str(response.get("error", ""))
		if error_text.begins_with("no_internet_") or error_text.begins_with("request_start_"):
			_network_blocked = true
		push_warning(
			"AssetManager: download failed for '%s' (%s). %s"
			% [asset_id, str(response.get("code", 0)), error_text]
		)
		return _use_local_fallback(asset_id, local_path, _network_blocked)
	var body: PackedByteArray = PackedByteArray()
	var body_stored: Variant = response.get("body", PackedByteArray())
	if typeof(body_stored) == TYPE_PACKED_BYTE_ARRAY:
		body = body_stored
	var image: Image = _image_from_buffer(body)
	if image == null or image.is_empty():
		push_warning("AssetManager: invalid image payload for '%s'." % asset_id)
		return _use_local_fallback(asset_id, local_path, false)
	var png: PackedByteArray = image.save_png_to_buffer()
	if png.is_empty():
		png = body
	if not _write_bytes(local_path, png):
		push_warning("AssetManager: could not write '%s'." % local_path)
		return _use_local_fallback(asset_id, local_path, false)
	var file_hash: String = _sha256(png)
	if not _upsert_meta(entry, file_hash):
		push_warning("AssetManager: SQLite metadata write failed for '%s'; file is still cached." % asset_id)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[asset_id] = texture
	_character_frames.clear()
	_online = true
	print("[AssetManager] Stored %s -> %s" % [asset_id, local_path])
	return true


func _use_local_fallback(asset_id: String, local_path: String, offline: bool) -> bool:
	var fallback: Texture2D = _load_texture_from_disk(local_path)
	if fallback != null:
		_textures[asset_id] = fallback
		if offline:
			print("[AssetManager] Offline cache hit: %s" % asset_id)
		return true
	if offline:
		push_warning("AssetManager: no Internet and no local file for '%s'." % asset_id)
	return false


func _http_get(url: String, has_local_file: bool = false) -> Dictionary:
	var first: Dictionary = await _http_get_once(url, has_local_file, false)
	if bool(first.get("ok", false)):
		return first
	if str(first.get("error", "")) == "tls_handshake" and _http.has_method("set_tls_options"):
		push_warning("AssetManager: Cloudinary TLS verify failed; retrying with relaxed TLS.")
		return await _http_get_once(url, has_local_file, true)
	return first


func _http_get_once(url: String, has_local_file: bool, relax_tls: bool) -> Dictionary:
	_http.download_file = ""
	_http.timeout = 5.0 if has_local_file else DOWNLOAD_TIMEOUT_SEC
	_configure_tls(relax_tls)
	var headers := PackedStringArray(["Accept: image/png,image/webp,image/*;q=0.8"])
	var err: Error = _http.request(url, headers)
	if err != OK:
		return {
			"ok": false,
			"code": 0,
			"body": PackedByteArray(),
			"error": "request_start_%s" % err,
		}
	var completed: Array = await _http.request_completed
	var result: int = int(completed[0])
	var code: int = int(completed[1])
	var body: PackedByteArray = PackedByteArray()
	var body_stored: Variant = completed[3]
	if typeof(body_stored) == TYPE_PACKED_BYTE_ARRAY:
		body = body_stored
	if result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
		return {"ok": false, "code": code, "body": body, "error": "tls_handshake"}
	if _is_network_failure(result):
		return {"ok": false, "code": code, "body": body, "error": "no_internet_%s" % result}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "body": body, "error": "http_result_%s" % result}
	if code < 200 or code >= 300:
		return {"ok": false, "code": code, "body": body, "error": "http_status"}
	if body.is_empty():
		return {"ok": false, "code": code, "body": body, "error": "empty_body"}
	return {"ok": true, "code": code, "body": body, "error": ""}


func _hydrate_from_disk() -> void:
	var catalog: Array[Dictionary] = _gameplay_catalog()
	for i in catalog.size():
		var entry: Dictionary = catalog[i]
		var asset_id: String = str(entry.get("asset_id", ""))
		var local_path: String = str(entry.get("local_path", ""))
		if asset_id.is_empty() or _textures.has(asset_id):
			continue
		if not FileAccess.file_exists(local_path):
			continue
		var texture: Texture2D = _load_texture_from_disk(local_path)
		if texture != null:
			_textures[asset_id] = texture


func _open_db() -> void:
	if not ClassDB.class_exists("SQLite"):
		push_warning("AssetManager: SQLite addon is not loaded. Files will still cache on disk.")
		return
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.verbosity_level = 0
	if not _db.open_db():
		push_warning("AssetManager: could not open %s. %s" % [DB_PATH, _db.error_message])
		_db = null
		return
	if not _db.query(CREATE_ASSETS_SQL):
		push_warning("AssetManager: create table failed. %s" % _db.error_message)
		_db = null
		return
	_db_ok = true


func _read_meta(asset_id: String) -> Dictionary:
	if not is_available() or asset_id.is_empty():
		return {}
	if not _db.query_with_bindings("SELECT * FROM assets WHERE asset_id = ? LIMIT 1;", [asset_id]):
		push_warning("AssetManager: SQLite read failed. %s" % _db.error_message)
		return {}
	var rows: Array = _db.query_result
	if rows.is_empty():
		return {}
	var row: Variant = rows[0]
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


func _upsert_meta(entry: Dictionary, file_hash: String) -> bool:
	if not is_available():
		return false
	var sql := """
INSERT INTO assets (
	asset_id, asset_name, asset_type, cloudinary_url, local_path, version, downloaded_at, file_hash
) VALUES (?, ?, ?, ?, ?, ?, datetime('now'), ?)
ON CONFLICT(asset_id) DO UPDATE SET
	asset_name = excluded.asset_name,
	asset_type = excluded.asset_type,
	cloudinary_url = excluded.cloudinary_url,
	local_path = excluded.local_path,
	version = excluded.version,
	downloaded_at = excluded.downloaded_at,
	file_hash = excluded.file_hash;
"""
	var bindings: Array = [
		str(entry.get("asset_id", "")),
		str(entry.get("asset_name", "")),
		str(entry.get("asset_type", "sprite_sheet")),
		str(entry.get("cloudinary_url", "")),
		str(entry.get("local_path", "")),
		str(entry.get("version", "")),
		file_hash,
	]
	if not _db.query_with_bindings(sql, bindings):
		push_warning("AssetManager: SQLite upsert failed. %s" % _db.error_message)
		return false
	return true


func _ensure_assets_dir() -> void:
	var abs_path: String = ProjectSettings.globalize_path(ASSETS_DIR)
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("AssetManager: could not create %s (error %s)." % [ASSETS_DIR, err])


func _local_path_for(asset_id: String) -> String:
	return "%s/%s.png" % [ASSETS_DIR, asset_id]


func _load_texture_from_disk(local_path: String) -> Texture2D:
	if local_path.is_empty() or not FileAccess.file_exists(local_path):
		return null
	var image: Image = Image.load_from_file(local_path)
	if image == null or image.is_empty():
		push_warning("AssetManager: failed to load image at %s." % local_path)
		return null
	return ImageTexture.create_from_image(image)


func _image_from_buffer(body: PackedByteArray) -> Image:
	if body.is_empty():
		return null
	var image := Image.new()
	var err: Error = image.load_png_from_buffer(body)
	if err == OK and not image.is_empty():
		return image
	err = image.load_jpg_from_buffer(body)
	if err == OK and not image.is_empty():
		return image
	err = image.load_webp_from_buffer(body)
	if err == OK and not image.is_empty():
		return image
	return null


func _write_bytes(local_path: String, body: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		push_warning("AssetManager: FileAccess.open failed for %s. %s" % [local_path, FileAccess.get_open_error()])
		return false
	file.store_buffer(body)
	file.close()
	return true


func _hash_file(local_path: String) -> String:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(local_path)
	if bytes.is_empty():
		return ""
	return _sha256(bytes)


func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


func _is_network_failure(result: int) -> bool:
	return (
		result == HTTPRequest.RESULT_CANT_CONNECT
		or result == HTTPRequest.RESULT_CANT_RESOLVE
		or result == HTTPRequest.RESULT_CONNECTION_ERROR
		or result == HTTPRequest.RESULT_NO_RESPONSE
		or result == HTTPRequest.RESULT_TIMEOUT
	)


func _version_from_cloudinary_url(url: String) -> String:
	var regex := RegEx.new()
	if regex.compile("/v(\\d+)/") != OK:
		return ""
	var matched: RegExMatch = regex.search(url)
	if matched == null:
		return ""
	return matched.get_string(1)


func _configure_tls(relax: bool) -> void:
	if _http == null or not _http.has_method("set_tls_options"):
		return
	var options: TLSOptions = TLSOptions.client_unsafe() if relax else TLSOptions.client()
	_http.call("set_tls_options", options)


func _seed_from_bundle() -> void:
	var catalog: Array[Dictionary] = _gameplay_catalog()
	for i in catalog.size():
		var entry: Dictionary = catalog[i]
		var asset_id: String = str(entry.get("asset_id", ""))
		var local_path: String = str(entry.get("local_path", ""))
		if asset_id.is_empty() or FileAccess.file_exists(local_path):
			continue
		var bundled_path: String = _bundled_path(asset_id)
		if bundled_path.is_empty():
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bundled_path)
		if bytes.is_empty():
			continue
		if not _write_bytes(local_path, bytes):
			continue
		if not _upsert_meta(entry, _sha256(bytes)):
			push_warning("AssetManager: seeded '%s' on disk but SQLite write failed." % asset_id)
		print("[AssetManager] Seeded local cache from bundle: %s" % asset_id)


func _bundled_path(asset_id: String) -> String:
	if asset_id.begins_with("npc_"):
		return ""
	match asset_id:
		"map_module_1_stage_1":
			return "res://assets/gameplay/maps/module_1_stage_1_25d_baked.png"
		"tower_basic_node_base":
			return "res://assets/gameplay/towers/basic_node_base_v1.png"
		"tower_basic_node_head":
			return "res://assets/gameplay/towers/basic_node_head_v2.png"
		"tower_basic_node_atlas":
			return "res://assets/gameplay/towers/basic_node_atlas_v1.png"
		"ui_intro":
			return ""
		"ui_intro_preview":
			return ""
		"ui_module1_intro":
			return ""
		"ui_dashboard":
			return "res://assets/ui/dashboard.png"
		"ui_background":
			return "res://assets/ui/background.png"
		"ui_logo":
			return "res://assets/ui/logo.png"
		"ui_loading":
			return "res://assets/ui/loading.png"
		"ui_pfp":
			return "res://assets/ui/tempo_pfp.jpg"
		"ui_setting":
			return "res://assets/ui/setting.png"
		"ui_pause":
			return "res://assets/ui/pause.png"
		"ui_speedup":
			return "res://assets/ui/speedup.png"
		"ui_heart_full":
			return "res://assets/ui/fullheart.png"
		"ui_heart_half":
			return "res://assets/ui/halfheart.png"
		"ui_heart_empty":
			return "res://assets/ui/emptyheart.png"
		_:
			var character_id: String = asset_id.get_slice("_", 0)
			if character_id.is_empty():
				character_id = "hacker"
			return "%s/%s/%s.png" % [BUNDLED_DIR, character_id, asset_id]


func _load_bundled_texture(asset_id: String) -> Texture2D:
	var path: String = _bundled_path(asset_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = ResourceLoader.load(path)
	return loaded as Texture2D


func _add_sheet_animation(
	frames: SpriteFrames,
	anim_name: StringName,
	texture: Texture2D,
	bottom_align: bool,
	fps: float
) -> void:
	if texture == null:
		return
	var sheet_frames: Array[Texture2D] = _sheet_to_frame_textures(texture, bottom_align)
	if sheet_frames.is_empty():
		return
	if not frames.has_animation(anim_name):
		frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	var loops: bool = not String(anim_name).begins_with("death")
	frames.set_animation_loop(anim_name, loops)
	for i in sheet_frames.size():
		frames.add_frame(anim_name, sheet_frames[i])


func _sheet_to_frame_textures(texture: Texture2D, bottom_align: bool) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		result.append(texture)
		return result
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return result
	var col_counts: Array[int] = []
	col_counts.resize(width)
	var occupied: Array[bool] = []
	occupied.resize(width)
	for x in width:
		var count: int = 0
		for y in height:
			if image.get_pixel(x, y).a > 0.06:
				count += 1
		col_counts[x] = count
		occupied[x] = count > 0
	var runs: Array[Vector2i] = []
	var run_start: int = -1
	for x in width:
		if occupied[x] and run_start < 0:
			run_start = x
		elif not occupied[x] and run_start >= 0:
			runs.append(Vector2i(run_start, x - 1))
			run_start = -1
	if run_start >= 0:
		runs.append(Vector2i(run_start, width - 1))
	if runs.is_empty():
		result.append(texture)
		return result
	runs = _split_connected_frame_runs(col_counts, runs, width)
	var crops: Array[Image] = []
	var max_w: int = 1
	var max_h: int = 1
	for i in runs.size():
		var run: Vector2i = runs[i]
		var region: Rect2i = _opaque_rect_in_columns(image, run.x, run.y)
		if region.size.x <= 0 or region.size.y <= 0:
			continue
		var crop: Image = image.get_region(region)
		crops.append(crop)
		max_w = maxi(max_w, crop.get_width())
		max_h = maxi(max_h, crop.get_height())
	if crops.is_empty():
		result.append(texture)
		return result
	for i in crops.size():
		var crop: Image = crops[i]
		var canvas: Image = Image.create_empty(max_w, max_h, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
		var ox: int = int(floor(float(max_w - crop.get_width()) * 0.5))
		var oy: int = 0
		if bottom_align:
			oy = max_h - crop.get_height()
		else:
			oy = int(floor(float(max_h - crop.get_height()) * 0.5))
		canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(ox, oy))
		result.append(ImageTexture.create_from_image(canvas))
	return result


func _split_connected_frame_runs(col_counts: Array[int], runs: Array[Vector2i], sheet_width: int) -> Array[Vector2i]:
	## Fishing rods / overlapping poses can glue several frames into one opaque run.
	## Split those wide runs at occupancy valleys so each pose is its own crop.
	var max_reasonable: int = maxi(108, sheet_width / 5)
	var out: Array[Vector2i] = []
	for i in runs.size():
		var run: Vector2i = runs[i]
		var run_w: int = run.y - run.x + 1
		if run_w >= max_reasonable:
			var parts: Array[Vector2i] = _split_wide_run(col_counts, run.x, run.y)
			if parts.size() >= 2:
				out.append_array(parts)
				continue
		out.append(run)
	return out


func _split_wide_run(col_counts: Array[int], x0: int, x1: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var run_w: int = x1 - x0 + 1
	var min_dist: int = maxi(40, run_w / 10)
	var peaks: Array[int] = _occupancy_peaks(col_counts, x0, x1, min_dist)
	if peaks.size() < 2:
		var n: int = clampi(int(round(float(run_w) / 85.0)), 2, 8)
		for i in n:
			var a: int = x0 + int(round(float(i * run_w) / float(n)))
			var b: int = x0 + int(round(float((i + 1) * run_w) / float(n))) - 1
			if i == n - 1:
				b = x1
			result.append(Vector2i(a, b))
		return result
	var start: int = x0
	for i in range(peaks.size() - 1):
		var p0: int = peaks[i]
		var p1: int = peaks[i + 1]
		var mid: int = int(floor(float(p0 + p1) * 0.5))
		var best_x: int = mid
		var best_c: int = col_counts[mid]
		for x in range(mid, p1):
			if col_counts[x] < best_c:
				best_c = col_counts[x]
				best_x = x
		result.append(Vector2i(start, best_x))
		start = best_x + 1
	result.append(Vector2i(start, x1))
	return result


func _occupancy_peaks(col_counts: Array[int], x0: int, x1: int, min_dist: int) -> Array[int]:
	var mx: int = 0
	for x in range(x0, x1 + 1):
		mx = maxi(mx, col_counts[x])
	if mx <= 0:
		return []
	var thresh: float = float(mx) * 0.45
	var sm: Array[float] = []
	sm.resize(col_counts.size())
	for x in range(x0, x1 + 1):
		var a: int = maxi(x0, x - 2)
		var b: int = mini(x1, x + 2)
		var acc: float = 0.0
		for i in range(a, b + 1):
			acc += float(col_counts[i])
		sm[x] = acc / float(b - a + 1)
	var candidates: Array[int] = []
	for x in range(x0 + 1, x1):
		if sm[x] < thresh:
			continue
		if sm[x] >= sm[x - 1] and sm[x] >= sm[x + 1] and (sm[x] > sm[x - 1] or sm[x] > sm[x + 1]):
			candidates.append(x)
	candidates.sort_custom(func(a: int, b: int) -> bool: return sm[a] > sm[b])
	var peaks: Array[int] = []
	for i in candidates.size():
		var x: int = candidates[i]
		var far: bool = true
		for j in peaks.size():
			if absi(x - peaks[j]) < min_dist:
				far = false
				break
		if far:
			peaks.append(x)
	peaks.sort()
	return peaks


func _opaque_rect_in_columns(image: Image, x0: int, x1: int) -> Rect2i:
	var height: int = image.get_height()
	var min_x: int = x1
	var max_x: int = x0
	var min_y: int = height
	var max_y: int = 0
	for x in range(x0, x1 + 1):
		for y in height:
			if image.get_pixel(x, y).a <= 0.06:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	var pad := 1
	min_x = maxi(0, min_x - pad)
	min_y = maxi(0, min_y - pad)
	max_x = mini(image.get_width() - 1, max_x + pad)
	max_y = mini(height - 1, max_y + pad)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
