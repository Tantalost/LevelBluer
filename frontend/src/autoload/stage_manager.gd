extends Node
## Autoload singleton, registered as "StageManager".
## In-memory stage and enemy configs only. Persistence is out of scope.

const ENEMY_DB: Dictionary = {
	"basic": {"speed": 50.0, "base_health": 3, "color": Palette.RED},
	"fast": {"speed": 90.0, "base_health": 2, "color": Palette.YELLOW},
	"heavy": {"speed": 35.0, "base_health": 8, "color": Palette.ORANGE},
}

const STAGE_DB: Dictionary = {
	1: {
		"name": "Diagnostic Protocol",
		"type": "diagnostic",
		"starting_gold": 2,
		"waves": [
			{"enemy_count": 3, "spawn_delay": 1.5, "health_multiplier": 1.0, "enemy_type": "basic"},
			{"enemy_count": 5, "spawn_delay": 1.0, "health_multiplier": 1.0, "enemy_type": "fast"},
		],
	},
	2: {
		"name": "Adaptive Gauntlet",
		"type": "formative",
		"starting_gold": 5,
		"waves": [
			{"enemy_count": 8, "spawn_delay": 0.8, "health_multiplier": 1.2, "enemy_type": "heavy"},
		],
	},
}


func get_stage_config(stage_id: int) -> Dictionary:
	if not STAGE_DB.has(stage_id):
		return {}
	var stored: Variant = STAGE_DB[stage_id]
	var config: Dictionary = stored as Dictionary
	if config.is_empty():
		return {}
	return config.duplicate(true)


func get_enemy_stats(type_id: String) -> Dictionary:
	var key: String = type_id if ENEMY_DB.has(type_id) else "basic"
	if not ENEMY_DB.has(key):
		return {}
	var stored: Variant = ENEMY_DB[key]
	var stats: Dictionary = stored as Dictionary
	if stats.is_empty():
		return {}
	return stats.duplicate(true)
