class_name EnemyBase
extends PathFollow2D
## Path-following packet with a health pool. Economy payout is signaled, not applied here.

signal enemy_died(bounty_amount: int)

@export var move_speed: float = 150.0
var max_health: int = 3
var current_health: int = 3
var bounty: int = 1
var is_dead: bool = false


func initialize_stats(type_id: String, hp_mult: float) -> void:
	var stats: Dictionary = StageManager.get_enemy_stats(type_id)
	var health_stored: Variant = stats.get("base_health", 3)
	var speed_stored: Variant = stats.get("speed", 50.0)
	var color_stored: Variant = stats.get("color", Palette.RED)
	max_health = maxi(1, int(round(float(int(health_stored)) * hp_mult)))
	current_health = max_health
	move_speed = float(speed_stored)
	# instantiate() builds children immediately; @onready is still null until add_child().
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = color_stored as Color


func _ready() -> void:
	loop = false
	add_to_group("enemies")


func _process(delta: float) -> void:
	if is_dead or is_queued_for_deletion():
		return
	progress += move_speed * delta


func take_damage(amount: int) -> void:
	if is_dead or is_queued_for_deletion():
		return
	current_health -= amount
	if current_health <= 0:
		is_dead = true
		enemy_died.emit(bounty)
		queue_free()
