extends Node
## Autoload singleton, registered as "StageManager".
## Enemy stats stay local. Stage configs are loaded from ContentDB JSON.

const INCIDENT_BANK: Array[Dictionary] = [
	{"text": "WARNING: Anomalous payload from internal IP. Action?", "correct": "Isolate Subnet", "wrong": "Ignore Traffic"},
	{"text": "ALERT: Suspicious encryption routine detected!", "correct": "Drop Packets", "wrong": "Reroute"},
	{"text": "DDoS signature matching known botnet...", "correct": "Enable Rate Limiting", "wrong": "Increase Bandwidth"},
]

const ENEMY_DB: Dictionary = {
	"basic": {"speed": 50.0, "base_health": 3, "color": Palette.RED},
	"fast": {"speed": 90.0, "base_health": 2, "color": Palette.YELLOW},
	"heavy": {"speed": 35.0, "base_health": 8, "color": Palette.ORANGE},
}

func get_stage_config(stage_id: int) -> Dictionary:
	return ContentDB.get_stage(str(stage_id))


func get_enemy_stats(type_id: String) -> Dictionary:
	var key: String = type_id if ENEMY_DB.has(type_id) else "basic"
	if not ENEMY_DB.has(key):
		return {}
	var stored: Variant = ENEMY_DB[key]
	var stats: Dictionary = stored as Dictionary
	if stats.is_empty():
		return {}
	return stats.duplicate(true)
