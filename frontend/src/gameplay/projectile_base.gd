class_name ProjectileBase
extends Area2D
## Homing bolt. Stateful Inspection lets a Basic Node shot pierce one extra target.

const DEFAULT_SPEED := 400.0
var speed: float = DEFAULT_SPEED
var target: Node2D = null
var damage: int = 1
var blast_radius: float = 0.0
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var pierce_remaining: int = 0
var source_type: String = "base"
var _hit_ids: Dictionary = {}
var _last_dir: Vector2 = Vector2.RIGHT
var _orphan_life: float = 0.0
var combat_map: Node2D = null
var match_context: MatchContext = MatchContext.new()
var source_tower: WeakRef


func _combat_distance(a: Vector2, b: Vector2) -> float:
	if is_instance_valid(combat_map):
		return combat_map.call("ground_distance", a, b)
	return a.distance_to(b)


func _advance_toward(destination: Vector2, travel: float) -> void:
	var distance := _combat_distance(global_position, destination)
	global_position = global_position.lerp(destination, minf(1.0, travel / maxf(distance, 0.001)))


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func initialize(
	target_node: Node2D,
	damage_amount: int = 1,
	blast: float = 0.0,
	slow_pct: float = 1.0,
	slow_time: float = 0.0,
	pierce_extra: int = 0,
	tower_type: String = "base",
) -> void:
	target = target_node
	damage = damage_amount
	blast_radius = blast
	slow_factor = slow_pct
	slow_duration = slow_time
	pierce_remaining = maxi(0, pierce_extra)
	source_type = tower_type


func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		_last_dir = (target.global_position - global_position).normalized()
		look_at(target.global_position)
		_advance_toward(target.global_position, speed * delta)
		return
	if pierce_remaining >= 0 and not _hit_ids.is_empty():
		_orphan_life -= delta
		if _last_dir == Vector2.ZERO:
			_last_dir = Vector2.RIGHT
		_advance_toward(global_position + _last_dir * 10000.0, speed * delta)
		if _orphan_life <= 0.0:
			queue_free()
		return
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if enemy == null or enemy.is_dead:
		return
	var enemy_id: int = enemy.get_instance_id()
	if _hit_ids.has(enemy_id):
		return
	if blast_radius > 0.0:
		if not match_context.geometric:
			_spawn_vfx("aoe", global_position)
		_apply_aoe()
		queue_free()
		return
	if not match_context.geometric:
		_spawn_vfx("impact", global_position)
	if _hit_enemy(enemy):
		print("[Combat] Dealt " + str(damage) + " damage!")
	_hit_ids[enemy_id] = true
	if pierce_remaining > 0:
		pierce_remaining -= 1
		_retarget()
		return
	queue_free()


## Resolved via the SceneTree root instead of the bare "VfxManager" autoload
## identifier: a bare autoload identifier forces GDScript to eagerly compile
## this script's autoload dependency before headless --script runs have
## registered any autoloads.
func _spawn_vfx(effect_id: String, pos: Vector2) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var vfx: Node = loop.root.get_node_or_null("VfxManager")
	if vfx != null:
		vfx.call("spawn_vfx", effect_id, pos)


func _retarget() -> void:
	target = null
	var tree: SceneTree = get_tree()
	if tree == null:
		_orphan_life = 0.45
		return
	var best: EnemyBase = null
	var best_d: float = INF
	var nodes: Array[Node] = tree.get_nodes_in_group("enemies")
	for i in nodes.size():
		var enemy: EnemyBase = nodes[i] as EnemyBase
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead or enemy.is_queued_for_deletion():
			continue
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		var dist: float = _combat_distance(global_position, enemy.global_position)
		if dist < best_d:
			best_d = dist
			best = enemy
	if best == null:
		_orphan_life = 0.45
		return
	target = best
	_orphan_life = 0.0


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
		if _combat_distance(global_position, enemy.global_position) > blast_radius:
			continue
		if _hit_enemy(enemy):
			hit_count += 1
	print("[Combat] AoE Blast hit " + str(hit_count) + " enemies!")


func _hit_enemy(enemy: EnemyBase) -> bool:
	if enemy == null or enemy.is_dead:
		return false
	var multiplier: float = enemy.damage_multiplier_vs(source_type)
	var scaled: int = maxi(0, int(round(float(damage) * multiplier)))
	var tier: StringName = EnemyBase.matchup_tier(multiplier, 1.5, 0.5)
	var before := enemy.current_health
	enemy.take_damage(scaled, tier)
	if match_context.geometric and source_tower != null:
		var tower: Node = source_tower.get_ref()
		if is_instance_valid(tower):
			tower.preview_damage_dealt += maxi(0, before - enemy.current_health)
			tower.preview_kills += int(before > 0 and enemy.current_health == 0)
	enemy.apply_slow(slow_factor, slow_duration)
	return true
