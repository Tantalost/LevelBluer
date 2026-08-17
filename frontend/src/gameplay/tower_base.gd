class_name TowerBase
extends Area2D
## Branching discipline upgrades. Mock DB only — Resources come later.

const TOWER_DB: Dictionary = {
	"base": {
		"name": "Basic Node",
		"damage": 1,
		"fire_rate": 1.0,
		"color": Palette.CYAN,
		"req_skill": "",
		"explosion_radius": 0.0,
	},
	"network": {
		"name": "Firewall",
		"damage": 1,
		"fire_rate": 2.5,
		"color": Palette.GREEN,
		"cost": 3,
		"req_skill": "firewall_1",
		"explosion_radius": 0.0,
	},
	"crypto": {
		"name": "Decryptor",
		"damage": 3,
		"fire_rate": 0.5,
		"color": Palette.MAGENTA,
		"cost": 4,
		"req_skill": "crypto_1",
		"explosion_radius": 80.0,
	},
}

const UPGRADE_PATHS: Dictionary = {
	"base": ["network", "crypto"],
	"network": [],
	"crypto": [],
}

@export var projectile_scene: PackedScene
var current_type: String = "base"
var fire_rate: float = 1.0
var fire_timer: float = 0.0
var base_damage: int = 1
var current_explosion_radius: float = 0.0
var targets_in_range: Array[Area2D] = []
var current_target: Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	apply_stats("base")


func apply_stats(type_id: String) -> void:
	var entry: Dictionary = entry_for(type_id)
	if entry.is_empty():
		push_warning("[Tower] Unknown type '%s'" % type_id)
		return
	current_type = type_id
	base_damage = int(entry.get("damage", 1))
	fire_rate = float(entry.get("fire_rate", 1.0))
	current_explosion_radius = explosion_radius_for(type_id)
	var stored_color: Variant = entry.get("color", Palette.CYAN)
	modulate = stored_color as Color


static func entry_for(type_id: String) -> Dictionary:
	if not TOWER_DB.has(type_id):
		return {}
	var stored: Variant = TOWER_DB[type_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


static func cost_for(type_id: String) -> int:
	return int(entry_for(type_id).get("cost", 0))


static func display_name_for(type_id: String) -> String:
	return str(entry_for(type_id).get("name", type_id))


static func paths_for(type_id: String) -> Array[String]:
	var result: Array[String] = []
	if not UPGRADE_PATHS.has(type_id):
		return result
	var stored: Variant = UPGRADE_PATHS[type_id]
	if typeof(stored) != TYPE_ARRAY:
		return result
	var raw: Array = stored
	for i in raw.size():
		result.append(str(raw[i]))
	return result


static func req_skill_for(type_id: String) -> String:
	return str(entry_for(type_id).get("req_skill", ""))


static func explosion_radius_for(type_id: String) -> float:
	return float(entry_for(type_id).get("explosion_radius", 0.0))


func _on_area_entered(area: Area2D) -> void:
	if not targets_in_range.has(area):
		targets_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	targets_in_range.erase(area)


func _process(delta: float) -> void:
	_prune_invalid_targets()
	if targets_in_range.is_empty():
		current_target = null
	else:
		var parent: Node = targets_in_range[0].get_parent()
		current_target = parent as Node2D
		if current_target != null:
			_sprite.look_at(current_target.global_position)

	fire_timer -= delta
	if fire_timer <= 0.0 and current_target != null and fire_rate > 0.0:
		fire_timer = 1.0 / fire_rate
		_fire()


func _fire() -> void:
	if projectile_scene == null or current_target == null:
		return
	var instance: Node = projectile_scene.instantiate()
	var projectile: ProjectileBase = instance as ProjectileBase
	if projectile == null:
		push_warning("[Tower] projectile_scene is not a ProjectileBase.")
		return
	projectile.initialize(current_target, base_damage, current_explosion_radius)
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(projectile)
	projectile.global_position = global_position


func _prune_invalid_targets() -> void:
	var alive: Array[Area2D] = []
	for area: Area2D in targets_in_range:
		if is_instance_valid(area) and not area.is_queued_for_deletion():
			alive.append(area)
	targets_in_range = alive
