class_name ProjectileBase
extends Area2D
## Homing bolt. Decryptor blasts; Firewall snares. No HP math lives here.

var speed: float = 400.0
var target: Node2D = null
var damage: int = 1
var blast_radius: float = 0.0
var slow_factor: float = 1.0
var slow_duration: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func initialize(
	target_node: Node2D,
	damage_amount: int = 1,
	blast: float = 0.0,
	slow_pct: float = 1.0,
	slow_time: float = 0.0,
) -> void:
	target = target_node
	damage = damage_amount
	blast_radius = blast
	slow_factor = slow_pct
	slow_duration = slow_time


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	look_at(target.global_position)
	global_position = global_position.move_toward(target.global_position, speed * delta)


func _on_area_entered(area: Area2D) -> void:
	if blast_radius > 0.0:
		VfxManager.spawn_vfx("aoe", global_position)
		_apply_aoe()
	else:
		VfxManager.spawn_vfx("impact", global_position)
		_apply_single(area)
	queue_free()


func _apply_single(area: Area2D) -> void:
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if _hit_enemy(enemy):
		print("[Combat] Dealt " + str(damage) + " damage!")


func _apply_aoe() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var nodes: Array[Node] = tree.get_nodes_in_group("enemies")
	var hit_count: int = 0
	for i in nodes.size():
		var enemy: EnemyBase = nodes[i] as EnemyBase
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead or enemy.is_queued_for_deletion():
			continue
		if global_position.distance_to(enemy.global_position) > blast_radius:
			continue
		if _hit_enemy(enemy):
			hit_count += 1
	print("[Combat] AoE Blast hit " + str(hit_count) + " enemies!")


func _hit_enemy(enemy: EnemyBase) -> bool:
	if enemy == null or enemy.is_dead:
		return false
	enemy.take_damage(damage)
	enemy.apply_slow(slow_factor, slow_duration)
	return true
