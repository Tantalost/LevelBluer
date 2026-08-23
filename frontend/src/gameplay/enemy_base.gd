class_name EnemyBase
extends PathFollow2D
## Path-following packet with a health pool. Economy payout is signaled, not applied here.

signal enemy_died(bounty_amount: int)

@export var move_speed: float = 150.0
var max_health: int = 3
var current_health: int = 3
var bounty: int = 1
var is_dead: bool = false
var _base_move_speed: float = 50.0
var _base_color: Color = Palette.RED
var _slow_timer: SceneTreeTimer = null
var _hit_tween: Tween = null


func initialize_stats(type_id: String, hp_mult: float) -> void:
	var stats: Dictionary = StageManager.get_enemy_stats(type_id)
	var health_stored: Variant = stats.get("base_health", 3)
	var speed_stored: Variant = stats.get("speed", 50.0)
	var color_stored: Variant = stats.get("color", Palette.RED)
	max_health = maxi(1, int(round(float(int(health_stored)) * hp_mult)))
	current_health = max_health
	_base_move_speed = float(speed_stored)
	move_speed = _base_move_speed
	_base_color = color_stored as Color
	_apply_tint(_base_color)


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
		_kill_hit_tween()
		_clear_slow_timer()
		enemy_died.emit(bounty)
		queue_free()
		return
	_flash_hit()


func apply_slow(factor: float, duration: float) -> void:
	if is_dead or is_queued_for_deletion():
		return
	if factor >= 1.0 or factor <= 0.0 or duration <= 0.0:
		return
	move_speed = _base_move_speed * factor
	_apply_tint(Palette.CYAN)
	_clear_slow_timer()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_slow_timer = tree.create_timer(duration)
	_slow_timer.timeout.connect(_on_slow_expired)


func _on_slow_expired() -> void:
	_slow_timer = null
	if is_dead or not is_instance_valid(self) or is_queued_for_deletion():
		return
	move_speed = _base_move_speed
	_apply_tint(_base_color)


func _clear_slow_timer() -> void:
	if _slow_timer != null and _slow_timer.timeout.is_connected(_on_slow_expired):
		_slow_timer.timeout.disconnect(_on_slow_expired)
	_slow_timer = null


func _flash_hit() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var target_color: Color = Palette.CYAN if _slow_timer != null else _base_color
	_kill_hit_tween()
	sprite.modulate = Color.WHITE
	modulate = Color.WHITE
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(sprite, "modulate", target_color, 0.1)
	_hit_tween.tween_property(self, "modulate", target_color, 0.1)


func _kill_hit_tween() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = null


func _apply_tint(color: Color) -> void:
	_kill_hit_tween()
	modulate = color
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = color
