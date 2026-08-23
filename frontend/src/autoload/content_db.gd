extends Node
## Autoload singleton, registered as "ContentDB".
## Loads authored JSON at boot. FastAPI swap comes later.

var questions: Dictionary = {}
var stages: Dictionary = {}
var enemies: Dictionary = {}
var towers: Dictionary = {}
var incidents: Array = []


func _ready() -> void:
	_load_json_dict("res://data/questions.json", questions)
	_load_json_dict("res://data/stages.json", stages)
	_load_json_dict("res://data/enemies.json", enemies)
	_load_json_dict("res://data/towers.json", towers)
	_load_json_array("res://data/incidents.json", incidents)
	print(
		"[ContentDB] Parsed skills=", questions.size(),
		" stages=", stages.size(),
		" enemies=", enemies.size(),
		" towers=", towers.size(),
		" incidents=", incidents.size()
	)


func load_all() -> void:
	if questions.is_empty():
		_load_json_dict("res://data/questions.json", questions)
	if stages.is_empty():
		_load_json_dict("res://data/stages.json", stages)
	if enemies.is_empty():
		_load_json_dict("res://data/enemies.json", enemies)
	if towers.is_empty():
		_load_json_dict("res://data/towers.json", towers)
	if incidents.is_empty():
		_load_json_array("res://data/incidents.json", incidents)
	await get_tree().process_frame


func get_questions() -> Dictionary:
	return questions.duplicate(true)


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
	return {
		"hp": hp,
		"base_health": hp,
		"speed": speed,
		"color": _palette_color(str(raw.get("color", "RED")), Palette.RED),
		"bounty": bounty,
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
	var cost_raw: Variant = raw.get("cost", 0)
	var cost: int = 0
	if typeof(cost_raw) == TYPE_INT or typeof(cost_raw) == TYPE_FLOAT:
		cost = maxi(0, int(cost_raw))
	return {
		"name": str(raw.get("name", "")),
		"damage": damage,
		"fire_rate": fire_rate,
		"color": _palette_color(str(raw.get("color", "CYAN")), Palette.CYAN),
		"cost": cost,
		"req_skill": str(raw.get("req_skill", "")),
		"splash_radius": splash_radius,
		"explosion_radius": splash_radius,
		"slow_factor": slow_factor,
		"slow_duration": slow_duration,
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
		"MAGENTA":
			return Palette.MAGENTA
		"GOLD":
			return Palette.GOLD
		_:
			return fallback


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
