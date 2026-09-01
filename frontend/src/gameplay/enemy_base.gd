class_name EnemyBase
extends PathFollow2D
## Path-following packet with a health pool. Economy payout is signaled, not applied here.
## Visual is an AnimatedSprite2D. Character art (Hacker / Ransomware / Phisherman)
## is chosen at random from locally cached AssetManager sheets.

signal enemy_died(bounty_amount: int)
signal reached_base

const TARGET_SPRITE_HEIGHT := 28.0

@export var move_speed: float = 150.0
var max_health: int = 3
var current_health: int = 3
var bounty: int = 1
var is_dead: bool = false
var _leaked: bool = false
var _base_move_speed: float = 50.0
var _base_color: Color = Palette.RED
var _type_id: String = ""
var _slow_timer: SceneTreeTimer = null
var _hit_tween: Tween = null
var _uses_character_sheets: bool = false
var _playing_death: bool = false
var _is_side_facing: bool = true
var _visual_id: String = ""


func initialize_stats(type_id: String, hp_mult: float) -> void:
	_type_id = type_id
	var stats: Dictionary = ContentDB.get_enemy(type_id)
	var health_stored: Variant = stats.get("hp", stats.get("base_health", 3))
	var speed_stored: Variant = stats.get("speed", 50.0)
	var color_stored: Variant = stats.get("color", Palette.RED)
	var bounty_stored: Variant = stats.get("bounty", 1)
	var hp: int = 3
	if typeof(health_stored) == TYPE_INT or typeof(health_stored) == TYPE_FLOAT:
		hp = int(health_stored)
	max_health = maxi(1, int(round(float(hp) * hp_mult)))
	current_health = max_health
	var speed: float = 50.0
	if typeof(speed_stored) == TYPE_INT or typeof(speed_stored) == TYPE_FLOAT:
		speed = float(speed_stored)
	_base_move_speed = speed
	move_speed = _base_move_speed
	if typeof(color_stored) == TYPE_COLOR:
		_base_color = color_stored as Color
	else:
		_base_color = Palette.RED
	if typeof(bounty_stored) == TYPE_INT or typeof(bounty_stored) == TYPE_FLOAT:
		bounty = maxi(0, int(bounty_stored))
	_bind_character_visuals()
	_apply_tint(_base_color)


func _ready() -> void:
	loop = false
	add_to_group("enemies")
	if _uses_character_sheets:
		_play_walk()


func _physics_process(delta: float) -> void:
	if _leaked or is_queued_for_deletion():
		return
	if is_dead:
		return
	progress += move_speed * delta
	_update_character_facing()
	if loop:
		return
	if progress_ratio < 0.999:
		return
	if not mark_leaked():
		return
	reached_base.emit()
	queue_free()


func mark_leaked() -> bool:
	if is_dead or _leaked or is_queued_for_deletion():
		return false
	_leaked = true
	is_dead = true
	_kill_hit_tween()
	_clear_slow_timer()
	_disconnect_death_anim()
	return true


func take_damage(amount: int) -> void:
	if is_dead or _leaked or is_queued_for_deletion():
		return
	current_health -= amount
	if current_health <= 0:
		_begin_death()
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
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite == null:
		return
	var target_color: Color = Palette.CYAN if _slow_timer != null else _idle_modulate()
	_kill_hit_tween()
	sprite.modulate = Color.WHITE
	_hit_tween = create_tween()
	_hit_tween.tween_property(sprite, "modulate", target_color, 0.1)


func _kill_hit_tween() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = null


func _apply_tint(color: Color) -> void:
	_kill_hit_tween()
	var applied: Color = _idle_modulate() if color == _base_color else color
	modulate = Color.WHITE
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite != null:
		sprite.modulate = applied


func _idle_modulate() -> Color:
	if _uses_character_sheets:
		return Color.WHITE
	return _base_color


func _character_sprite() -> AnimatedSprite2D:
	return get_node_or_null("HackerSprite") as AnimatedSprite2D


func _bind_character_visuals() -> void:
	var sprite: AnimatedSprite2D = _character_sprite()
	_visual_id = AssetManager.pick_random_character()
	var frames: SpriteFrames = AssetManager.get_character_sprite_frames(_visual_id)
	if sprite == null or frames == null:
		_uses_character_sheets = false
		rotates = false
		if sprite != null:
			sprite.visible = false
		return
	_uses_character_sheets = true
	rotates = false
	sprite.visible = true
	sprite.centered = true
	sprite.sprite_frames = frames
	_fit_sprite_scale(sprite)
	_play_walk()


func _fit_sprite_scale(sprite: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return
	var anim: StringName = &"walk_side" if frames.has_animation(&"walk_side") else &"walk_top"
	if not frames.has_animation(anim):
		return
	var tex: Texture2D = frames.get_frame_texture(anim, 0)
	if tex == null or tex.get_height() <= 0:
		return
	var scale_f: float = TARGET_SPRITE_HEIGHT / float(tex.get_height())
	sprite.scale = Vector2(scale_f, scale_f)


func _update_character_facing() -> void:
	if not _uses_character_sheets or _playing_death:
		return
	var tangent: Vector2 = _path_tangent()
	var side: bool = absf(tangent.x) >= absf(tangent.y)
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite != null:
		sprite.flip_h = tangent.x < 0.0
	if side == _is_side_facing:
		return
	_is_side_facing = side
	_play_walk()


func _play_walk() -> void:
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: StringName = &"walk_side" if _is_side_facing else &"walk_top"
	if not sprite.sprite_frames.has_animation(anim):
		anim = &"walk_top" if sprite.sprite_frames.has_animation(&"walk_top") else &"walk_side"
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _begin_death() -> void:
	is_dead = true
	_kill_hit_tween()
	_clear_slow_timer()
	_disable_hitbox()
	VfxManager.spawn_vfx("death", global_position)
	TaskManager.record_enemy_defeated(_type_id)
	enemy_died.emit(bounty)
	var sprite: AnimatedSprite2D = _character_sprite()
	var death_anim: StringName = _death_anim_name()
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(death_anim):
		queue_free()
		return
	_playing_death = true
	sprite.sprite_frames.set_animation_loop(death_anim, false)
	if sprite.animation_finished.is_connected(_on_death_anim_finished):
		sprite.animation_finished.disconnect(_on_death_anim_finished)
	sprite.animation_finished.connect(_on_death_anim_finished)
	sprite.play(death_anim)


func _death_anim_name() -> StringName:
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return &"death_side"
	var preferred: StringName = &"death_side" if _is_side_facing else &"death_top"
	if sprite.sprite_frames.has_animation(preferred):
		return preferred
	if sprite.sprite_frames.has_animation(&"death_side"):
		return &"death_side"
	return &"death_top"


func _on_death_anim_finished() -> void:
	_disconnect_death_anim()
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()


func _disconnect_death_anim() -> void:
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite != null and sprite.animation_finished.is_connected(_on_death_anim_finished):
		sprite.animation_finished.disconnect(_on_death_anim_finished)


func _disable_hitbox() -> void:
	var hitbox: Area2D = get_node_or_null("Hitbox") as Area2D
	if hitbox == null:
		return
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.collision_layer = 0


func _path_tangent() -> Vector2:
	var path: Path2D = get_parent() as Path2D
	if path == null or path.curve == null:
		return Vector2.RIGHT
	if path.curve.get_baked_length() <= 0.01:
		return Vector2.RIGHT
	var xf: Transform2D = path.curve.sample_baked_with_rotation(progress, false)
	var tangent: Vector2 = xf.x
	if tangent.length_squared() < 0.0001:
		return Vector2.RIGHT
	return tangent.normalized()
