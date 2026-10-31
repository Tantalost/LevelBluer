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
const INDUSTRIAL_ATLAS_RESOURCE := "res://assets/gameplay/isometric/industrial_atlas_texture.tres"
const DEATH_FPS := 10.0
const BUNDLED_ESSENTIAL_DIR := "res://assets/bundled"
## Keep false until every ESSENTIAL_BUNDLE file is imported under BUNDLED_ESSENTIAL_DIR;
## enabling it earlier blocks launch for students without a complete cache.
const ESSENTIAL_GATE_ENABLED := false
const REQUIRED_CHARACTERS: PackedStringArray = ["hacker", "ransomware", "phisherman"]
const CHARACTER_SHEETS: PackedStringArray = ["walk_side", "walk_top", "death_side", "death_top"]
## Art needed to reach the dashboard and play Module 1 offline, served from the APK.
## Values are the Cloudinary versions the bundled files were exported from.
const ESSENTIAL_BUNDLE: Dictionary[String, String] = {
	"ui_logo": "1788336656", "ui_intro": "1788338103", "ui_intro_preview": "1788338998", "ui_background": "1788336648",
	"ui_dashboard": "1788336649", "ui_dashboard_scenic": "1789109666", "ui_dashboard_pvp": "1791049225",
	"ui_pfp": "1788336662", "ui_setting": "1788336659",
	"ui_pause": "1788336657", "ui_speedup": "1788336660",
	"ui_heart_full": "1788336650", "ui_heart_half": "1788336652", "ui_heart_empty": "1788336648",
	"ui_avatar_byte_bot": "1791177053", "ui_avatar_cyber_cat": "1791177071", "ui_avatar_commander": "1791177054",
	"ui_avatar_operative": "1791177072", "ui_avatar_neon_fox": "1791177084", "ui_avatar_circuit_owl": "1791177053",
	"ui_avatar_glitch_ghost": "1791177069", "ui_avatar_pixel_bunny": "1791177053", "ui_avatar_cyber_axolotl": "1791177067",
	"ui_avatar_masked_raccoon": "1791177068",
	"npc_thoughtfulness": "1788689630", "npc_talk": "1788689629", "npc_smile": "1788689629", "npc_skepticism": "1788689629",
	"npc_scream": "1788689628", "npc_sadness": "1788689627", "npc_laughter": "1788689627", "npc_fear": "1788689626",
	"npc_eye_rolling": "1788689626", "npc_calm": "1788689625", "npc_cry": "1788689626", "npc_discomfort": "1788689626",
	"npc_embarrassment": "1788689626", "npc_doubt": "1788689626", "npc_awkwardness": "1788689625",
	"npc_disgust": "1788689625", "npc_aggression": "1788689625", "npc_astonishment": "1788689625",
	"tower_basic_node_base": "1788769625", "tower_basic_node_head": "1788769626", "tower_basic_node_atlas": "1788769625",
	"map_industrial_atlas": "1788939071", "home_base_clean": "1788938897", "home_base_cracked": "1788938898",
	"home_base_critical": "1788938907", "enemy_spawn_broken_pc": "1788938897",
	"map_module_1_stage_1": "1788767750", "map_module_1_stage_2": "1788938879", "map_module_1_stage_3": "1788938879",
}
## Catalog art no current screen references; still downloaded, never counted for offline readiness.
const OFFLINE_EXCLUDED: PackedStringArray = ["ui_loading", "ui_module1_morning_comic", "story_portrait_alex", "story_portrait_mia", "story_portrait_ms_reyes"]

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
var _last_sync_ok: bool = false
var _invalidations: int = 0
var _essential_gate_enabled: bool = ESSENTIAL_GATE_ENABLED
var _catalog_index: Dictionary = {}
var _textures: Dictionary = {}
var _character_frames: Dictionary = {}
var _online: bool = false
var _network_blocked: bool = false
var _sync_done: int = 0
var _sync_total: int = 0
var _sync_label: String = ""
var _transfer_active: bool = false

## A loading screen can attach after title-art synchronization has already begun.
func get_sync_progress() -> Dictionary:
	return {"active": _syncing, "done": _sync_done, "total": _sync_total,
		"label": _sync_label, "downloading": _transfer_active,
		"received": _http.get_downloaded_bytes() if _transfer_active else 0,
		"bytes_total": _http.get_body_size() if _transfer_active else 0}

func _report_sync_progress(done: int, total: int, label: String) -> void:
	_sync_done = done
	_sync_total = total
	_sync_label = label
	sync_progress.emit(done, total, label)


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = DOWNLOAD_TIMEOUT_SEC
	_http.use_threads = true
	_http.body_size_limit = BODY_SIZE_LIMIT
	_configure_tls()
	add_child(_http)
	_open_db()


func is_available() -> bool:
	return _db_ok and _db != null


func is_online() -> bool:
	return _online


## Reuses the running or last successful pass; only a failed pass is retried.
func ensure_ready() -> void:
	if _syncing:
		await sync_finished
	elif not (_synced and _last_sync_ok):
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
	_report_sync_progress(0, 0, "LOADING_ASSETS_CHECK")
	var catalog: Array[Dictionary] = _gameplay_catalog()
	_index_catalog(catalog)
	for entry: Dictionary in catalog:
		_recover_interrupted_replace(str(entry.get("asset_id", "")), str(entry.get("local_path", "")))
	_seed_from_bundle()
	var invalidations_at_start: int = _invalidations
	var all_ok: bool = true
	var total: int = catalog.size()
	for i in total:
		var entry: Dictionary = catalog[i]
		_report_sync_progress(i, total, str(entry.get("asset_name", "asset")))
		var ok: bool = await _sync_entry(entry)
		if not ok:
			all_ok = false
		_report_sync_progress(i + 1, total, str(entry.get("asset_name", "asset")))
		await get_tree().process_frame
	_synced = true
	# A file rejected on access during this pass may have been checked before it broke.
	all_ok = all_ok and _invalidations == invalidations_at_start
	_last_sync_ok = all_ok
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
	# A matching bundled copy beats an outdated download; a current download beats the bundle.
	var entry: Dictionary = _catalog_entry_for(asset_id)
	var prefer_bundle: bool = _essential_bundle_current(entry) and not _is_cache_current(
		asset_id, str(entry.get("cloudinary_url", "")), str(entry.get("version", "")), local_path)
	var texture: Texture2D = null if prefer_bundle else _load_cached_texture(asset_id, local_path)
	if texture == null:
		texture = _load_bundled_texture(asset_id)
		if texture != null and asset_id == "map_industrial_atlas":
			var shared: ImageTexture = load(INDUSTRIAL_ATLAS_RESOURCE) as ImageTexture
			shared.set_image(texture.get_image())
			texture = shared
	if texture == null and prefer_bundle:
		texture = _load_cached_texture(asset_id, local_path)
	if texture != null:
		_textures[asset_id] = texture
	return texture


func bind_texture(target: CanvasItem, asset_id: String) -> void:
	if target == null or asset_id.is_empty():
		return
	# Legacy portrait consumers all resolve to the selected uniform avatar.
	# Receiver-owned signal connections disappear when their TextureRect is freed.
	if asset_id == "ui_pfp" and target is TextureRect:
		var portrait_script: GDScript = preload("res://src/ui/screens/profile/avatar_portrait.gd")
		if target.get_script() != portrait_script:
			target.set_script(portrait_script)
		target.call("bind_current")
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
	if _essential_gate_enabled:
		return has_essential_assets()
	return not playable_characters().is_empty()


func is_essential_asset(asset_id: String) -> bool:
	return _essential_bundle().has(asset_id)


## Strict gate: every essential image and all enemy sheets resolve from the bundle or cache.
## Read-only: no decoding, hashing or cache changes.
func has_essential_assets() -> bool:
	for asset_id: String in _required_asset_ids():
		var entry: Dictionary = _catalog_entry_for(asset_id)
		if entry.is_empty() or _entry_state(entry) == "missing":
			return false
	return true


func is_offline_ready() -> bool:
	var status: Dictionary = get_offline_status()
	return int(status.total) > 0 and int(status.ready) == int(status.total)


## Read-only readiness. "ready" means bundled at the catalog version, or cached at the catalog
## version with a hash recorded after download verification. A file damaged later is caught
## on first access, invalidated, and then reported missing.
func get_offline_status() -> Dictionary:
	var ready: int = 0
	var total: int = 0
	var outdated: int = 0
	var unverified: int = 0
	var missing_ids: PackedStringArray = PackedStringArray()
	var essential_total: int = 0
	var essential_missing_ids: PackedStringArray = PackedStringArray()
	var excluded: PackedStringArray = _offline_excluded()
	for entry: Dictionary in _gameplay_catalog():
		var asset_id: String = str(entry.get("asset_id", ""))
		var state: String = _entry_state(entry)
		if is_essential_asset(asset_id):
			essential_total += 1
			if state == "missing":
				essential_missing_ids.append(asset_id)
		if excluded.has(asset_id):
			continue
		total += 1
		match state:
			"bundled", "cached":
				ready += 1
			"outdated":
				outdated += 1
			"unverified":
				unverified += 1
			_:
				missing_ids.append(asset_id)
	return {
		"ready": ready, "total": total, "outdated": outdated, "unverified": unverified, "missing_ids": missing_ids,
		"essential_total": essential_total, "essential_usable": essential_total - essential_missing_ids.size(),
		"essential_missing_ids": essential_missing_ids, "essential_ready": has_essential_assets(),
		"gate_enabled": _essential_gate_enabled,
	}


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
	catalog.append_array(_map_environment_catalog())
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
	catalog.append_array(_school_story_catalog())
	catalog.append_array(_college_story_catalog())
	return catalog


func _college_story_catalog() -> Array[Dictionary]:
	return [
		_catalog_entry("story_college_cast", "College story cast atlas (Alex/Mia/Leah)", "image", "%s/v1791030251/mia_and_alex.png" % CLOUD_ROOT),
		_catalog_entry("story_college_commons", "College commons background", "image", "%s/v1791030176/temp.jpg" % CLOUD_ROOT),
	]


func _school_story_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	catalog.append(_catalog_entry("story_amani_poses", "Module 2 / Amani expression sheet", "image", "%s/v1793339789/levelblue_mod2_amani_poses_v1.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_bg_event_room_day", "Module 2 / Club event preparation room", "image", "%s/v1793339808/levelblue_mod2_event_room_day_v1.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_chapter2_cover", "Chapter 2 / The Advisor Email", "image", "%s/v1792721173/chapter2_advisor_cover_v1.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_chapter3_cover", "Chapter 3 / The Payout", "image", "%s/v1793086637/chapter3_payout_cover_v2.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_chapter4_cover", "Chapter 4 / The Prize", "image", "%s/v1793086638/chapter4_prize_cover_v2.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_john_laugh", "John / Laughing pose", "image", "%s/v1792721629/john_laugh_v1.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_bg_john_bed_night", "Chapter 2 / John's nighttime investigation", "image", "%s/v1792721171/john_bed_night_v1.png" % CLOUD_ROOT))
	catalog.append(_catalog_entry("story_bg_john_desk_night", "Chapter 1 / John's nighttime desk", "image", "%s/v1792675006/john_desk_night_v1.png" % CLOUD_ROOT))
	for person: String in ["john", "eric", "jobert"]:
		var sprite_version: String = "1792675005" if person == "eric" else "1792675007"
		catalog.append(_catalog_entry("chapter1_" + person, "Chapter 1 / " + person, "image", "%s/v%s/%s_poses_v1.png" % [CLOUD_ROOT, sprite_version, person]))
	for character: String in ["alex", "mia", "ms_reyes"]:
		catalog.append(_catalog_entry("story_portrait_" + character, "School portrait / " + character, "sprite_sheet", "%s/v1790436023/%s_expressions.png" % [CLOUD_ROOT, character]))
		catalog.append(_catalog_entry("story_dialogue_" + character, "School full-body dialogue / " + character, "sprite_sheet", "%s/v1790828276/%s_dialogue_atlas.png" % [CLOUD_ROOT, character]))
	catalog.append(_catalog_entry("ui_module1_morning_comic", "Alex's school morning comic", "image", "%s/v1790828295/module1_morning_comic.png" % CLOUD_ROOT))
	for location: String in ["gymnasium", "courtyard", "school_gate_morning", "classroom_sunset", "clubroom", "classroom_day", "rooftop_day", "music_room", "hallway_day", "library_room", "infirmary", "science_lab"]:
		var version: String = "1790432520" if location in ["gymnasium", "courtyard", "school_gate_morning", "classroom_sunset", "clubroom", "classroom_day"] else "1790432521"
		catalog.append(_catalog_entry("story_bg_" + location, "School location / " + location, "image", "%s/v%s/%s.png" % [CLOUD_ROOT, version, location]))
	return catalog


func _map_environment_catalog() -> Array[Dictionary]:
	# Only the packed runtime atlas is valid for these fixed tile crop coordinates.
	return [
		_catalog_entry("map_industrial_atlas", "Industrial isometric runtime atlas", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788939071/industrial_atlas.png"),
		_catalog_entry("home_base_clean", "Home base / full health", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788938897/home_base_clean_v1.png"),
		_catalog_entry("home_base_cracked", "Home base / damaged", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788938898/home_base_cracked_v1.png"),
		_catalog_entry("home_base_critical", "Home base / critical and destruction", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788938907/home_base_critical_v1.png"),
		_catalog_entry("enemy_spawn_broken_pc", "Enemy spawn / broken PC", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788938897/enemy_spawn_broken_pc_v1.png"),
		_catalog_entry("map_module_1_stage_2", "Module 1 Stage 2 map", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788938879/module_1_stage_2_25d_baked.png"),
		_catalog_entry("map_module_1_stage_3", "Module 1 Stage 3 map", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788938879/module_1_stage_3_25d_baked.png"),
	]


func _ui_catalog() -> Array[Dictionary]:
	return [
		_catalog_entry("module1_email_tricks_title_v1", "Module 1 / Email Tricks cinematic title", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792510294/module1_email_tricks_john_personal_v1.png"),
		_catalog_entry("opening_john_got_you_v1", "Opening / john got you", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792317115/john_got_you_v1.png"),
		_catalog_entry("opening_john_reaching_phone_v1", "Opening / john reaching phone", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792317115/john_reaching_phone_v1.png"),
		_catalog_entry("opening_collector_meeting_v2", "Opening / four lights meeting", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792338328/collector_meeting_v2.png"),
		_catalog_entry("opening_john_room_wake_v1", "Opening / john room wake", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792317115/john_room_wake_v1.png"),
		_catalog_entry("opening_john_claim_prize_v1", "Opening / john claim prize", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792317115/john_claim_prize_v1.png"),
		_catalog_entry("opening_five_victims_john_v4", "Opening / personalized John victim panels", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792509486/opening_five_victims_john_personal_v4.png"),
		_catalog_entry("ui_intro", "Intro cinematic art", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788338103/Gemini_Generated_Image_3bwb7g3bwb7g3bwb.jpg"),
		_catalog_entry("ui_intro_preview", "Intro title preview", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788338998/preview.png"),
		_catalog_entry("ui_dashboard", "Dashboard art", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1788336649/dashboard.png"),
		_catalog_entry("ui_dashboard_scenic", "Command outpost dashboard", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1789109666/command_outpost_v1.png"),
		_catalog_entry("ui_dashboard_pvp", "PvP mode-selection artwork", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791049225/pvp_command_v1.png"),
		_catalog_entry("ui_dashboard_pvp_workspace", "Muted PvP workspace", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791168774/pvp_workspace_muted_v1.png"),
		_catalog_entry("ui_avatar_byte_bot", "Byte Bot", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177053/byte_bot_v1.png"),
		_catalog_entry("ui_avatar_cyber_cat", "Cyber Cat", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177071/cyber_cat_v1.png"),
		_catalog_entry("ui_avatar_commander", "Commander", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177054/commander_v1.png"),
		_catalog_entry("ui_avatar_operative", "Operative", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177072/operative_v1.png"),
		_catalog_entry("ui_avatar_neon_fox", "Neon Fox", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177084/neon_fox_v1.png"),
		_catalog_entry("ui_avatar_circuit_owl", "Circuit Owl", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177053/circuit_owl_v1.png"),
		_catalog_entry("ui_avatar_glitch_ghost", "Glitch Ghost", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177069/glitch_ghost_v1.png"),
		_catalog_entry("ui_avatar_pixel_bunny", "Pixel Bunny", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177053/pixel_bunny_v1.png"),
		_catalog_entry("ui_avatar_cyber_axolotl", "Cyber Axolotl", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177067/cyber_axolotl_v1.png"),
		_catalog_entry("ui_avatar_masked_raccoon", "Masked Raccoon", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791177068/masked_raccoon_v1.png"),
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
		_catalog_entry("hearing_debate_v1", "Hearing / debate stage", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792930826/hearing_debate_v1.png"),
		_catalog_entry("hearing_mystery_v1", "Hearing / mystery", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792930833/hearing_mystery_v1.png"),
		_catalog_entry("john_counter_lettered_v1", "John / counter", "image", "https://res.cloudinary.com/nfd5bhkz/image/upload/v1792930834/john_counter_lettered_v1.png"),
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
	# Cached bytes are hashed and decoded on first get_texture(), not during sync.
	if _is_cache_current(asset_id, url, version, local_path):
		return true
	if _essential_bundle_current(entry):
		# An outdated copy is superseded by the always-available bundle; removing it keeps
		# direct readers such as the shared industrial atlas from preferring stale art.
		if FileAccess.file_exists(local_path):
			_remove_file(local_path)
			_delete_meta(asset_id)
		return true
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
	return str(meta.get("version", "")) == version


func _download_and_store(entry: Dictionary) -> bool:
	var asset_id: String = str(entry.get("asset_id", ""))
	var url: String = str(entry.get("cloudinary_url", ""))
	var local_path: String = str(entry.get("local_path", ""))
	var response: Dictionary = await _http_get(url, FileAccess.file_exists(local_path))
	if not bool(response.get("ok", false)):
		var error_text: String = str(response.get("error", ""))
		if error_text.begins_with("no_internet_") or error_text.begins_with("request_start_") or error_text == "tls_handshake":
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
	var rejection: String = _image_rejection(asset_id, image)
	if not rejection.is_empty():
		push_warning("AssetManager: invalid image payload for '%s' (%s)." % [asset_id, rejection])
		return _use_local_fallback(asset_id, local_path, false)
	# Keep downloaded UI portraits lightweight rather than retaining full-resolution textures.
	if asset_id.begins_with("ui_avatar_") and maxi(image.get_width(), image.get_height()) > 256:
		var scale_ratio: float = 256.0 / float(maxi(image.get_width(), image.get_height()))
		image.resize(maxi(1, roundi(image.get_width() * scale_ratio)), maxi(1, roundi(image.get_height() * scale_ratio)), Image.INTERPOLATE_NEAREST)
	var png: PackedByteArray = image.save_png_to_buffer()
	if png.is_empty():
		png = body
	if not _replace_cached_file(entry, png):
		return _use_local_fallback(asset_id, local_path, false)
	# Only textures already handed out are replaced; others load lazily from the new file.
	if asset_id == "map_industrial_atlas" and ResourceLoader.has_cached(INDUSTRIAL_ATLAS_RESOURCE):
		var shared: ImageTexture = load(INDUSTRIAL_ATLAS_RESOURCE) as ImageTexture
		shared.set_image(image)
		_textures[asset_id] = shared
	elif _textures.has(asset_id):
		_textures[asset_id] = ImageTexture.create_from_image(image)
	_character_frames.clear()
	_online = true
	print("[AssetManager] Stored %s -> %s" % [asset_id, local_path])
	return true


func _image_rejection(asset_id: String, image: Image) -> String:
	if image == null or image.is_empty():
		return "undecodable image"
	if asset_id == "map_industrial_atlas" and image.get_size() != Vector2i(2048, 2048):
		return "industrial atlas must be the packed 2048x2048 runtime texture"
	if asset_id.begins_with("story_portrait_") and image.get_width() != image.get_height() * 3:
		return "school expression sheets must contain three square cells"
	if asset_id.begins_with("story_dialogue_") and image.get_size() != Vector2i(1536, 1024):
		return "school dialogue atlases require the original 1536x1024 crop layout"
	return ""


## Temp write, read-back verification, then rename into place. Renames never target an
## existing path (the old file moves to .bak first), so Windows and Android behave alike.
## Metadata changes only after the new file is in place; any failure restores the old pair.
## The SHA-256 proves the stored bytes are the ones validated here, not that Cloudinary is authentic.
func _replace_cached_file(entry: Dictionary, png: PackedByteArray) -> bool:
	var asset_id: String = str(entry.get("asset_id", ""))
	var local_path: String = str(entry.get("local_path", ""))
	var temp_path: String = local_path + ".tmp"
	var backup_path: String = local_path + ".bak"
	_recover_interrupted_replace(asset_id, local_path)
	var file_hash: String = _sha256(png)
	if not _write_bytes(temp_path, png):
		_remove_file(temp_path)
		push_warning("AssetManager: could not write temporary file for '%s'; kept the cached copy." % asset_id)
		return false
	var written: PackedByteArray = FileAccess.get_file_as_bytes(temp_path)
	var rejection: String = ""
	if written.size() != png.size() or _sha256(written) != file_hash:
		rejection = "temporary file bytes differ from the validated download"
	else:
		rejection = _image_rejection(asset_id, _image_from_buffer(written))
	if not rejection.is_empty():
		_remove_file(temp_path)
		push_warning("AssetManager: temporary file for '%s' failed verification (%s); kept the cached copy." % [asset_id, rejection])
		return false
	var had_previous: bool = FileAccess.file_exists(local_path)
	if had_previous and not _rename_file(local_path, backup_path):
		_remove_file(temp_path)
		push_warning("AssetManager: could not move the cached '%s' aside; kept it unchanged." % asset_id)
		return false
	if not _rename_file(temp_path, local_path):
		_remove_file(temp_path)
		if had_previous:
			_restore_backup(asset_id, local_path)
		push_warning("AssetManager: could not move the new '%s' into place; kept the cached copy." % asset_id)
		return false
	if not _upsert_meta(entry, file_hash):
		if had_previous:
			_remove_file(local_path)
			_restore_backup(asset_id, local_path)
			push_warning("AssetManager: metadata update failed for '%s'; restored the previous cached copy." % asset_id)
			return false
		# No previous copy to protect: keep the verified file for offline use, as before.
		push_warning("AssetManager: SQLite metadata write failed for '%s'; file is still cached." % asset_id)
	if had_previous:
		_remove_file(backup_path)
	return true


## Finishes or rolls back a replacement interrupted by a crash, using metadata to tell which
## file it describes. Only this asset's .tmp/.bak files are touched, never a valid .png.
func _recover_interrupted_replace(asset_id: String, local_path: String) -> void:
	var temp_path: String = local_path + ".tmp"
	var backup_path: String = local_path + ".bak"
	if FileAccess.file_exists(temp_path):
		_remove_file(temp_path)
	if not FileAccess.file_exists(backup_path):
		return
	if not FileAccess.file_exists(local_path):
		_restore_backup(asset_id, local_path)
		return
	var stored_hash: String = str(_read_meta(asset_id).get("file_hash", ""))
	if not stored_hash.is_empty() and _sha256(FileAccess.get_file_as_bytes(backup_path)) == stored_hash:
		# Crashed after the swap but before metadata: the backup is the described file.
		_remove_file(local_path)
		_restore_backup(asset_id, local_path)
	else:
		_remove_file(backup_path)


func _restore_backup(asset_id: String, local_path: String) -> void:
	if not _rename_file(local_path + ".bak", local_path):
		push_warning("AssetManager: could not restore the previous '%s'; it will be redownloaded when online." % asset_id)


func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path)) == OK


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Existing files are validated when first accessed; an invalid one is removed then.
func _use_local_fallback(asset_id: String, local_path: String, offline: bool) -> bool:
	if FileAccess.file_exists(local_path):
		if offline:
			print("[AssetManager] Offline cache hit: %s" % asset_id)
		return true
	if offline:
		push_warning("AssetManager: no Internet and no local file for '%s'." % asset_id)
	return false


## Certificate verification is never relaxed; a TLS failure falls back to local files.
func _http_get(url: String, has_local_file: bool = false) -> Dictionary:
	_http.download_file = ""
	_http.timeout = 5.0 if has_local_file else DOWNLOAD_TIMEOUT_SEC
	var headers := PackedStringArray(["Accept: image/png,image/webp,image/*;q=0.8"])
	var err: Error = _http.request(url, headers)
	if err != OK:
		return {
			"ok": false,
			"code": 0,
			"body": PackedByteArray(),
			"error": "request_start_%s" % err,
		}
	_transfer_active = true
	var completed: Array = await _http.request_completed
	_transfer_active = false
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


func _delete_meta(asset_id: String) -> void:
	if not is_available():
		return
	if not _db.query_with_bindings("DELETE FROM assets WHERE asset_id = ?;", [asset_id]):
		push_warning("AssetManager: SQLite delete failed. %s" % _db.error_message)


func _ensure_assets_dir() -> void:
	var abs_path: String = ProjectSettings.globalize_path(ASSETS_DIR)
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("AssetManager: could not create %s (error %s)." % [ASSETS_DIR, err])


func _local_path_for(asset_id: String) -> String:
	return "%s/%s.png" % [ASSETS_DIR, asset_id]


## Verifies the stored hash and decodes on first access. Bad files are invalidated.
func _load_cached_texture(asset_id: String, local_path: String) -> Texture2D:
	if local_path.is_empty() or not FileAccess.file_exists(local_path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(local_path)
	var stored_hash: String = str(_read_meta(asset_id).get("file_hash", ""))
	if bytes.is_empty():
		_invalidate_cache_entry(asset_id, local_path, "empty or unreadable file")
		return null
	if not stored_hash.is_empty() and _sha256(bytes) != stored_hash:
		_invalidate_cache_entry(asset_id, local_path, "hash mismatch")
		return null
	var image: Image = _image_from_buffer(bytes)
	if image == null or image.is_empty():
		_invalidate_cache_entry(asset_id, local_path, "undecodable image")
		return null
	if asset_id == "map_industrial_atlas":
		if image.get_size() != Vector2i(2048, 2048):
			_invalidate_cache_entry(asset_id, local_path, "atlas is not 2048x2048")
			return null
		var shared: ImageTexture = load(INDUSTRIAL_ATLAS_RESOURCE) as ImageTexture
		shared.set_image(image)
		return shared
	return ImageTexture.create_from_image(image)


## Removing file and metadata makes the next pass redownload; offline, bundled art is used.
func _invalidate_cache_entry(asset_id: String, local_path: String, reason: String) -> void:
	push_warning("AssetManager: cached '%s' rejected (%s); it will be redownloaded when online." % [asset_id, reason])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	_delete_meta(asset_id)
	_textures.erase(asset_id)
	_character_frames.clear()
	_invalidations += 1
	_last_sync_ok = false


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


func _configure_tls() -> void:
	if _http == null or not _http.has_method("set_tls_options"):
		return
	_http.call("set_tls_options", TLSOptions.client())


func _seed_from_bundle() -> void:
	var catalog: Array[Dictionary] = _gameplay_catalog()
	for i in catalog.size():
		var entry: Dictionary = catalog[i]
		var asset_id: String = str(entry.get("asset_id", ""))
		var local_path: String = str(entry.get("local_path", ""))
		# Essential art is served from the imported bundle in place, never copied.
		if asset_id.is_empty() or is_essential_asset(asset_id) or FileAccess.file_exists(local_path):
			continue
		var bundled_path: String = _bundled_path(asset_id)
		if bundled_path.is_empty() or not FileAccess.file_exists(bundled_path):
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
	if is_essential_asset(asset_id):
		return "%s/%s.png" % [BUNDLED_ESSENTIAL_DIR, asset_id]
	match asset_id:
		"ui_module1_intro", "ui_dashboard_pvp_workspace":
			return ""
		"ui_loading":
			return "res://assets/ui/loading.png"
		"story_college_cast":
			return "res://assets/story/college_cast.png"
		"story_college_commons":
			return "res://assets/story/college_commons.png"
		_:
			var character_id: String = asset_id.get_slice("_", 0)
			if character_id.is_empty():
				character_id = "hacker"
			return "%s/%s/%s.png" % [BUNDLED_DIR, character_id, asset_id]


func _load_bundled_texture(asset_id: String) -> Texture2D:
	if not _bundle_has(asset_id):
		return null
	var loaded: Resource = ResourceLoader.load(_bundled_path(asset_id))
	return loaded as Texture2D


func _bundle_has(asset_id: String) -> bool:
	var path: String = _bundled_path(asset_id)
	return not path.is_empty() and ResourceLoader.exists(path)


func _essential_bundle() -> Dictionary:
	return ESSENTIAL_BUNDLE


func _offline_excluded() -> PackedStringArray:
	return OFFLINE_EXCLUDED


func _required_asset_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(_essential_bundle().keys())
	for character_id: String in REQUIRED_CHARACTERS:
		for sheet: String in CHARACTER_SHEETS:
			ids.append("%s_%s" % [character_id, sheet])
	return ids


func _index_catalog(catalog: Array[Dictionary]) -> void:
	_catalog_index.clear()
	for entry: Dictionary in catalog:
		_catalog_index[str(entry.get("asset_id", ""))] = entry


func _catalog_entry_for(asset_id: String) -> Dictionary:
	if _catalog_index.is_empty():
		_index_catalog(_gameplay_catalog())
	return _catalog_index.get(asset_id, {})


## True only when the APK holds this essential image at the catalog's current version.
func _essential_bundle_current(entry: Dictionary) -> bool:
	var asset_id: String = str(entry.get("asset_id", ""))
	if not is_essential_asset(asset_id):
		return false
	return str(_essential_bundle()[asset_id]) == str(entry.get("version", "")) and _bundle_has(asset_id)


## bundled/cached = ready offline; outdated/unverified = usable but not ready; missing.
## Uses file existence, metadata and import presence only: no decoding or hashing.
func _entry_state(entry: Dictionary) -> String:
	var asset_id: String = str(entry.get("asset_id", ""))
	var local_path: String = str(entry.get("local_path", _local_path_for(asset_id)))
	var bundled: bool = _bundle_has(asset_id)
	var bundled_current: bool = _essential_bundle_current(entry) if is_essential_asset(asset_id) else bundled
	if FileAccess.file_exists(local_path):
		var meta: Dictionary = _read_meta(asset_id)
		if meta.is_empty() or str(meta.get("file_hash", "")).is_empty():
			return "bundled" if bundled_current else "unverified"
		if str(meta.get("cloudinary_url", "")) == str(entry.get("cloudinary_url", "")) and str(meta.get("version", "")) == str(entry.get("version", "")):
			return "cached"
		return "bundled" if bundled_current else "outdated"
	if bundled_current:
		return "bundled"
	return "outdated" if bundled else "missing"


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
