extends Node
## Autoload singleton, registered as "ContentDB".
## Loads authored JSON at boot. FastAPI swap comes later.

var questions: Dictionary = {}
var stages: Dictionary = {}
var enemies: Dictionary = {}
var towers: Dictionary = {}
var tech_tree: Dictionary = {}
var incidents: Array = []
var lessons: Dictionary = {}
var _module_question_ids: Dictionary = {}
var _stage_pools: Dictionary = {}

const CORE_LESSON_IDS: PackedStringArray = ["ports_basics", "firewalls_intro", "crypto_101"]
const MODULE_UNLOCK_LESSON := "mod1_all"
const DEFAULT_SKILL_ID := "phishing"
const MODULE_STAGE_COUNT := 10


func _ready() -> void:
	_load_question_bank()
	_load_json_dict("res://data/stages.json", stages)
	_load_json_dict("res://data/enemies.json", enemies)
	_load_json_dict("res://data/towers.json", towers)
	_load_json_dict("res://data/tech_tree.json", tech_tree)
	_load_json_array("res://data/incidents.json", incidents)
	_load_json_dict("res://data/lessons.json", lessons)
	_assign_stage_pools()
	print(
		"[ContentDB] Parsed skills=", questions.size(),
		" questions=", _question_count(),
		" stages=", stages.size(),
		" enemies=", enemies.size(),
		" towers=", towers.size(),
		" tech=", tech_tree.size(),
		" incidents=", incidents.size(),
		" lessons=", lessons.size()
	)


func load_all() -> void:
	if questions.is_empty():
		_load_question_bank()
	if stages.is_empty():
		_load_json_dict("res://data/stages.json", stages)
	if enemies.is_empty():
		_load_json_dict("res://data/enemies.json", enemies)
	if towers.is_empty():
		_load_json_dict("res://data/towers.json", towers)
	if tech_tree.is_empty():
		_load_json_dict("res://data/tech_tree.json", tech_tree)
	if incidents.is_empty():
		_load_json_array("res://data/incidents.json", incidents)
	if lessons.is_empty():
		_load_json_dict("res://data/lessons.json", lessons)
	_assign_stage_pools()
	await get_tree().process_frame


func get_questions() -> Dictionary:
	return questions.duplicate(true)


func get_stage_question_pool(stage_id: int) -> Array:
	if _stage_pools.is_empty():
		_assign_stage_pools()
	var key: String = str(clampi(stage_id, 1, MODULE_STAGE_COUNT))
	if not _stage_pools.has(key):
		return []
	var stored: Variant = _stage_pools[key]
	if typeof(stored) != TYPE_ARRAY:
		return []
	return (stored as Array).duplicate(true)


func get_module_questions(module_id: String) -> Array:
	var skill_id: String = str(_module_question_ids.get(module_id, DEFAULT_SKILL_ID))
	if skill_id.is_empty() or not questions.has(skill_id):
		skill_id = DEFAULT_SKILL_ID
	if not questions.has(skill_id):
		return []
	var stored: Variant = questions[skill_id]
	if typeof(stored) != TYPE_ARRAY:
		return []
	return (stored as Array).duplicate(true)


func get_stage(stage_id: String) -> Dictionary:
	if stage_id.is_empty() or not stages.has(stage_id):
		return {}
	var stored: Variant = stages[stage_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	var config: Dictionary = stored as Dictionary
	if config.is_empty():
		return {}
	return config.duplicate(true)


func get_enemy(type_id: String) -> Dictionary:
	var key: String = type_id if enemies.has(type_id) else "basic"
	if not enemies.has(key):
		return {}
	var stored: Variant = enemies[key]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return _normalize_enemy(stored as Dictionary)


func get_tower(type_id: String) -> Dictionary:
	if type_id.is_empty() or not towers.has(type_id):
		return {}
	var stored: Variant = towers[type_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return _normalize_tower(stored as Dictionary)


func get_tech_tower(tower_id: String) -> Dictionary:
	if tower_id.is_empty() or not tech_tree.has(tower_id):
		return {}
	var stored: Variant = tech_tree[tower_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func default_capacity(tower_id: String) -> int:
	var entry: Dictionary = get_tech_tower(tower_id)
	var stored: Variant = entry.get("default_capacity", 1)
	if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
		return maxi(0, int(stored))
	return 1


func tech_track_ids(tower_id: String) -> Array[String]:
	var ids: Array[String] = []
	var tracks: Dictionary = _tech_tracks(tower_id)
	var keys: Array = tracks.keys()
	keys.sort()
	var preferred: Array[String] = ["stats", "capacity", "skill", "evolution"]
	for i in preferred.size():
		var track_id: String = preferred[i]
		if tracks.has(track_id):
			ids.append(track_id)
	for i in keys.size():
		var track_id: String = str(keys[i])
		if track_id.is_empty() or ids.has(track_id):
			continue
		ids.append(track_id)
	return ids


func tech_track(tower_id: String, track_id: String) -> Dictionary:
	if track_id.is_empty():
		return {}
	var tracks: Dictionary = _tech_tracks(tower_id)
	if not tracks.has(track_id):
		return {}
	var stored: Variant = tracks[track_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func tech_max_rank(tower_id: String, track_id: String) -> int:
	var track: Dictionary = tech_track(tower_id, track_id)
	var stored: Variant = track.get("max_rank", 0)
	if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
		return maxi(0, int(stored))
	return _tech_ranks(tower_id, track_id).size()


func tech_rank_entry(tower_id: String, track_id: String, rank: int) -> Dictionary:
	if rank <= 0:
		return {}
	var ranks: Array = _tech_ranks(tower_id, track_id)
	var index: int = rank - 1
	if index < 0 or index >= ranks.size():
		return {}
	var stored: Variant = ranks[index]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func tech_rank_cost(tower_id: String, track_id: String, rank: int) -> int:
	var entry: Dictionary = tech_rank_entry(tower_id, track_id, rank)
	if entry.is_empty():
		return -1
	return maxi(0, int(entry.get("cost", 0)))


func tech_stats_bonus(tower_id: String, ranks: int) -> Dictionary:
	var damage_bonus: int = 0
	var fire_rate_bonus: float = 0.0
	var clamped: int = clampi(ranks, 0, tech_max_rank(tower_id, "stats"))
	for rank in range(1, clamped + 1):
		var entry: Dictionary = tech_rank_entry(tower_id, "stats", rank)
		damage_bonus += int(entry.get("damage", 0))
		fire_rate_bonus += float(entry.get("fire_rate", 0.0))
	return {
		"damage": damage_bonus,
		"fire_rate": fire_rate_bonus,
	}


func _tech_tracks(tower_id: String) -> Dictionary:
	var entry: Dictionary = get_tech_tower(tower_id)
	var stored: Variant = entry.get("tracks", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func _tech_ranks(tower_id: String, track_id: String) -> Array:
	var track: Dictionary = tech_track(tower_id, track_id)
	var stored: Variant = track.get("ranks", [])
	if typeof(stored) != TYPE_ARRAY:
		return []
	return stored as Array


func get_incidents() -> Array:
	var result: Array = []
	for i in incidents.size():
		var row: Variant = incidents[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = row as Dictionary
		result.append({
			"text": str(event.get("text", "")),
			"correct": str(event.get("correct", "")),
			"wrong": str(event.get("wrong", "")),
		})
	return result


func get_lesson(lesson_id: String) -> Dictionary:
	if lesson_id.is_empty() or not lessons.has(lesson_id):
		return {}
	var stored: Variant = lessons[lesson_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = stored as Dictionary
	return {
		"id": lesson_id,
		"title": str(raw.get("title", lesson_id)),
		"body": str(raw.get("body", "")),
		"skill_tag": str(raw.get("skill_tag", "")),
	}


func get_all_lesson_ids() -> Array[String]:
	var ids: Array[String] = []
	var keys: Array = lessons.keys()
	for i in keys.size():
		var lesson_id: String = str(keys[i])
		if not lesson_id.is_empty():
			ids.append(lesson_id)
	return ids


func get_all_tower_ids() -> Array[String]:
	return _sorted_string_ids(towers.keys())


func get_all_enemy_ids() -> Array[String]:
	return _sorted_string_ids(enemies.keys())


func _sorted_string_ids(raw_keys: Array) -> Array[String]:
	var ids: Array[String] = []
	for i in raw_keys.size():
		var entry_id: String = str(raw_keys[i])
		if not entry_id.is_empty():
			ids.append(entry_id)
	ids.sort()
	return ids


func _normalize_enemy(raw: Dictionary) -> Dictionary:
	var hp_raw: Variant = raw.get("hp", raw.get("base_health", 3))
	var hp: int = 3
	if typeof(hp_raw) == TYPE_INT or typeof(hp_raw) == TYPE_FLOAT:
		hp = maxi(1, int(hp_raw))
	var speed_raw: Variant = raw.get("speed", 50.0)
	var speed: float = 50.0
	if typeof(speed_raw) == TYPE_INT or typeof(speed_raw) == TYPE_FLOAT:
		speed = float(speed_raw)
	var bounty_raw: Variant = raw.get("bounty", 1)
	var bounty: int = 1
	if typeof(bounty_raw) == TYPE_INT or typeof(bounty_raw) == TYPE_FLOAT:
		bounty = maxi(0, int(bounty_raw))
	var scale_raw: Variant = raw.get("scale", 1.0)
	var visual_scale: float = 1.0
	if typeof(scale_raw) == TYPE_INT or typeof(scale_raw) == TYPE_FLOAT:
		visual_scale = maxf(0.5, float(scale_raw))
	return {
		"hp": hp,
		"base_health": hp,
		"speed": speed,
		"color": _palette_color(str(raw.get("color", "RED")), Palette.RED),
		"bounty": bounty,
		"scale": visual_scale,
	}


func _normalize_tower(raw: Dictionary) -> Dictionary:
	var damage_raw: Variant = raw.get("damage", 1)
	var damage: int = 1
	if typeof(damage_raw) == TYPE_INT or typeof(damage_raw) == TYPE_FLOAT:
		damage = maxi(0, int(damage_raw))
	var fire_rate_raw: Variant = raw.get("fire_rate", 1.0)
	var fire_rate: float = 1.0
	if typeof(fire_rate_raw) == TYPE_INT or typeof(fire_rate_raw) == TYPE_FLOAT:
		fire_rate = float(fire_rate_raw)
	var splash_raw: Variant = raw.get("splash_radius", raw.get("explosion_radius", 0.0))
	var splash_radius: float = 0.0
	if typeof(splash_raw) == TYPE_INT or typeof(splash_raw) == TYPE_FLOAT:
		splash_radius = float(splash_raw)
	var slow_factor_raw: Variant = raw.get("slow_factor", 1.0)
	var slow_factor: float = 1.0
	if typeof(slow_factor_raw) == TYPE_INT or typeof(slow_factor_raw) == TYPE_FLOAT:
		slow_factor = float(slow_factor_raw)
	var slow_duration_raw: Variant = raw.get("slow_duration", 0.0)
	var slow_duration: float = 0.0
	if typeof(slow_duration_raw) == TYPE_INT or typeof(slow_duration_raw) == TYPE_FLOAT:
		slow_duration = float(slow_duration_raw)
	var zone_slow_raw: Variant = raw.get("zone_slow", 1.0)
	var zone_slow: float = 1.0
	if typeof(zone_slow_raw) == TYPE_INT or typeof(zone_slow_raw) == TYPE_FLOAT:
		zone_slow = float(zone_slow_raw)
	var cost_raw: Variant = raw.get("cost", 0)
	var cost: int = 0
	if typeof(cost_raw) == TYPE_INT or typeof(cost_raw) == TYPE_FLOAT:
		cost = maxi(0, int(cost_raw))
	return {
		"name": str(raw.get("name", "")),
		"role": str(raw.get("role", "DPS")),
		"damage": damage,
		"fire_rate": fire_rate,
		"color": _palette_color(str(raw.get("color", "CYAN")), Palette.CYAN),
		"cost": cost,
		"req_skill": str(raw.get("req_skill", "")),
		"splash_radius": splash_radius,
		"explosion_radius": splash_radius,
		"slow_factor": slow_factor,
		"slow_duration": slow_duration,
		"zone_slow": zone_slow,
	}


func _palette_color(color_name: String, fallback: Color) -> Color:
	match color_name.strip_edges().to_upper():
		"RED":
			return Palette.RED
		"YELLOW":
			return Palette.YELLOW
		"ORANGE":
			return Palette.ORANGE
		"GREEN":
			return Palette.GREEN
		"CYAN":
			return Palette.CYAN
		"BLUE":
			return Palette.BLUE_400
		"PURPLE":
			return Palette.PURPLE
		"MAGENTA":
			return Palette.MAGENTA
		"GOLD":
			return Palette.GOLD
		_:
			return fallback


func _load_question_bank() -> void:
	questions.clear()
	_module_question_ids.clear()
	var data: Variant = _parse_json_file("res://data/questions.json")
	if data == null:
		return
	if typeof(data) != TYPE_DICTIONARY:
		push_error("ContentDB: Root is not a Dictionary in res://data/questions.json")
		return
	var raw: Dictionary = data as Dictionary
	if raw.has("question_types"):
		_ingest_module_bank(raw)
		return
	questions.merge(raw, true)


func _ingest_module_bank(raw: Dictionary) -> void:
	var module_id: String = str(raw.get("module_id", "mod_01"))
	var skill_id: String = str(raw.get("topic", DEFAULT_SKILL_ID)).strip_edges().to_lower()
	if skill_id.is_empty():
		skill_id = DEFAULT_SKILL_ID
	var types_stored: Variant = raw.get("question_types", [])
	if typeof(types_stored) != TYPE_ARRAY:
		push_error("ContentDB: question_types is not an Array")
		return
	var flat: Array = []
	var types: Array = types_stored as Array
	for i in types.size():
		var type_row: Variant = types[i]
		if typeof(type_row) != TYPE_DICTIONARY:
			continue
		var type_dict: Dictionary = type_row as Dictionary
		var type_id: String = str(type_dict.get("type_id", ""))
		var type_label: String = str(type_dict.get("type_label", type_id))
		var delivery: String = str(type_dict.get("delivery", ""))
		var list_stored: Variant = type_dict.get("questions", [])
		if typeof(list_stored) != TYPE_ARRAY:
			continue
		var list: Array = list_stored as Array
		for j in list.size():
			var q_stored: Variant = list[j]
			if typeof(q_stored) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = (q_stored as Dictionary).duplicate(true)
			item["type_id"] = type_id
			item["type_label"] = type_label
			item["delivery"] = delivery
			item["skill_id"] = skill_id
			item["module_id"] = module_id
			flat.append(item)
	questions[skill_id] = flat
	if not module_id.is_empty():
		_module_question_ids[module_id] = skill_id
	print("[ContentDB] Flattened module ", module_id, " -> ", skill_id, " (", flat.size(), " items)")


func _assign_stage_pools() -> void:
	_stage_pools.clear()
	var by_type: Dictionary = {}
	var skill_keys: Array = questions.keys()
	for i in skill_keys.size():
		var list_stored: Variant = questions[skill_keys[i]]
		if typeof(list_stored) != TYPE_ARRAY:
			continue
		var rows: Array = list_stored as Array
		for j in rows.size():
			var row_stored: Variant = rows[j]
			if typeof(row_stored) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = (row_stored as Dictionary).duplicate(true)
			var type_id: String = str(item.get("type_id", "other"))
			if type_id.is_empty():
				type_id = "other"
			if not by_type.has(type_id):
				by_type[type_id] = []
			var bucket: Array = by_type[type_id]
			bucket.append(item)
			by_type[type_id] = bucket
	var type_ids: Array = by_type.keys()
	type_ids.sort()
	for t in type_ids.size():
		var group: Array = by_type[type_ids[t]]
		group.sort_custom(_sort_stage_questions)
		by_type[type_ids[t]] = group
	var stage_total: int = MODULE_STAGE_COUNT
	if stages.size() > 0:
		stage_total = maxi(1, stages.size())
	for stage_n in range(1, stage_total + 1):
		var pool: Array = []
		var slot: int = stage_n - 1
		for t in type_ids.size():
			var group: Array = by_type[type_ids[t]]
			if slot >= group.size():
				continue
			var picked: Variant = group[slot]
			if typeof(picked) == TYPE_DICTIONARY:
				pool.append((picked as Dictionary).duplicate(true))
		_stage_pools[str(stage_n)] = pool
		print("[ContentDB] Stage ", stage_n, " TRACE pool: ", pool.size(), " unique items")


func _sort_stage_questions(a: Dictionary, b: Dictionary) -> bool:
	var rank_a: int = _difficulty_rank(a)
	var rank_b: int = _difficulty_rank(b)
	if rank_a != rank_b:
		return rank_a < rank_b
	return str(a.get("id", "")) < str(b.get("id", ""))


func _difficulty_rank(q: Dictionary) -> int:
	match str(q.get("difficulty", "")).strip_edges().to_lower():
		"easy":
			return 0
		"hard":
			return 2
		_:
			return 1


func _question_count() -> int:
	var total: int = 0
	var keys: Array = questions.keys()
	for i in keys.size():
		var stored: Variant = questions[keys[i]]
		if typeof(stored) == TYPE_ARRAY:
			total += (stored as Array).size()
	return total


func _load_json_dict(file_path: String, target_dict: Dictionary) -> void:
	var data: Variant = _parse_json_file(file_path)
	if typeof(data) != TYPE_DICTIONARY:
		if data != null:
			push_error("ContentDB: Root is not a Dictionary in " + file_path)
		return
	target_dict.merge(data as Dictionary, true)


func _load_json_array(file_path: String, target_array: Array) -> void:
	var data: Variant = _parse_json_file(file_path)
	if typeof(data) != TYPE_ARRAY:
		if data != null:
			push_error("ContentDB: Root is not an Array in " + file_path)
		return
	target_array.clear()
	var raw: Array = data as Array
	for i in raw.size():
		target_array.append(raw[i])


func _parse_json_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_error("ContentDB: Missing file " + file_path)
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("ContentDB: Failed to open " + file_path)
		return null
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("ContentDB: JSON Parse Error in " + file_path)
		return null
	return json.data
