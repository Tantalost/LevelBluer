class_name EnemyBase
extends PathFollow2D
## Path-following packet with a health pool. Economy payout is signaled, not applied here.
## Visual is an AnimatedSprite2D. Wave type maps to character and threat_profile:
## basic → Hacker/stealth, fast → Phisherman/swarm, heavy|boss → Ransomware/heavy.

signal enemy_died(bounty_amount: int)
signal reached_base

const TARGET_SPRITE_HEIGHT := 28.0
const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const BAR_WIDTH := 28.0
const BAR_HEIGHT := 3.0
const BAR_Y := -22.0
const HITBOX_SIZE := Vector2(40, 40)
const POPUP_LIFE := 0.5

@export var move_speed: float = 150.0
@export var threat_profile: String = "stealth"
var max_health: int = 3
var current_health: int = 3
var bounty: int = 1
var is_dead: bool = false
var _leaked: bool = false
var _base_move_speed: float = 50.0
var _base_color: Color = Palette.RED
var _type_id: String = ""
var _slow_timer: SceneTreeTimer = null
var _timed_slow_factor: float = 1.0
var _zone_slow_count: int = 0
var _zone_slow_factor: float = 1.0
var _hit_tween: Tween = null
var _uses_character_sheets: bool = false
var _playing_death: bool = false
var _is_side_facing: bool = true
var _visual_id: String = ""
var _pixel_font: Font
var _sprite_base_scale: Vector2 = Vector2.ONE
var _displayed_health: float = 3.0
var _bar_tween: Tween = null
var _visual_scale: float = 1.0
var _bar_width: float = BAR_WIDTH
var _bar_y: float = BAR_Y
var _path_unit_scale: float = 1.0


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
	_displayed_health = float(max_health)
	queue_redraw()
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
	var scale_stored: Variant = stats.get("scale", 1.0)
	_visual_scale = 1.0
	if typeof(scale_stored) == TYPE_INT or typeof(scale_stored) == TYPE_FLOAT:
		_visual_scale = maxf(0.5, float(scale_stored))
	_bar_width = BAR_WIDTH * _visual_scale
	_bar_y = BAR_Y * _visual_scale
	_bind_character_visuals()
	threat_profile = profile_for_character(_visual_id)
	_apply_hitbox_scale()
	_apply_tint(_base_color)


func _ready() -> void:
	_path_unit_scale = float(get_parent().get_meta("path_unit_scale", 1.0))
	scale *= float(get_parent().get_meta("actor_unit_scale", 1.0))
	loop = false
	add_to_group("enemies")
	_load_font()
	queue_redraw()
	if _uses_character_sheets:
		_play_walk()


func _physics_process(delta: float) -> void:
	if _leaked or is_queued_for_deletion():
		return
	if is_dead:
		return
	progress += move_speed * _path_unit_scale * delta
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
	_kill_bar_tween()
	_clear_slow_timer()
	_disconnect_death_anim()
	return true


func take_damage(amount: int, matchup: StringName = &"neutral") -> void:
	if is_dead or _leaked or is_queued_for_deletion():
		return
	var dealt: int = mini(amount, current_health)
	current_health = maxi(0, current_health - amount)
	_show_hit(dealt, matchup)
	if current_health <= 0:
		_begin_death()


func apply_slow(factor: float, duration: float) -> void:
	if is_dead or is_queued_for_deletion():
		return
	if factor >= 1.0 or factor <= 0.0 or duration <= 0.0:
		return
	_timed_slow_factor = factor
	_recompute_move_speed()
	_apply_tint(Palette.CYAN)
	_clear_slow_timer()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_slow_timer = tree.create_timer(duration)
	_slow_timer.timeout.connect(_on_slow_expired)


func add_zone_slow(factor: float, show_feedback: bool = false) -> void:
	if is_dead or is_queued_for_deletion():
		return
	if factor >= 1.0 or factor <= 0.0:
		return
	var first_stack: bool = _zone_slow_count <= 0
	_zone_slow_count += 1
	_zone_slow_factor = factor
	_recompute_move_speed()
	if show_feedback and first_stack:
		var tier: StringName = _slow_matchup_tier(factor)
		if tier != &"neutral":
			_spawn_matchup_popup("SLOW", tier)


func remove_zone_slow() -> void:
	_zone_slow_count = maxi(0, _zone_slow_count - 1)
	if _zone_slow_count <= 0:
		_zone_slow_factor = 1.0
	_recompute_move_speed()


func _recompute_move_speed() -> void:
	if is_dead or _leaked:
		return
	var speed: float = _base_move_speed * _timed_slow_factor
	if _zone_slow_count > 0:
		speed *= _zone_slow_factor
	move_speed = speed


func _on_slow_expired() -> void:
	_slow_timer = null
	if is_dead or not is_instance_valid(self) or is_queued_for_deletion():
		return
	_timed_slow_factor = 1.0
	_recompute_move_speed()
	if _zone_slow_count <= 0:
		_apply_tint(_base_color)


func _clear_slow_timer() -> void:
	if _slow_timer != null and _slow_timer.timeout.is_connected(_on_slow_expired):
		_slow_timer.timeout.disconnect(_on_slow_expired)
	_slow_timer = null


func _show_hit(dealt: int, matchup: StringName = &"neutral") -> void:
	if dealt <= 0 and matchup == &"neutral":
		return
	if dealt > 0:
		_tween_health_bar()
		_flash_hit()
		queue_redraw()
		_spawn_damage_popup(dealt, matchup)
	elif matchup != &"neutral":
		_spawn_damage_popup(0, matchup)


func _flash_hit() -> void:
	var sprite: AnimatedSprite2D = _character_sprite()
	if sprite == null:
		return
	var target_color: Color = Palette.CYAN if _slow_timer != null else _idle_modulate()
	_kill_hit_tween()
	sprite.modulate = Color.WHITE
	sprite.scale = _sprite_base_scale * 1.18
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(sprite, "modulate", target_color, 0.12)
	_hit_tween.tween_property(sprite, "scale", _sprite_base_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	_visual_id = character_for_wave(_type_id)
	if _visual_id.is_empty():
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
	var scale_f: float = (TARGET_SPRITE_HEIGHT * _visual_scale) / float(tex.get_height())
	_sprite_base_scale = Vector2(scale_f, scale_f)
	sprite.scale = _sprite_base_scale


func _apply_hitbox_scale() -> void:
	var collider: CollisionShape2D = get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
	if collider == null:
		return
	var source: RectangleShape2D = collider.shape as RectangleShape2D
	if source == null:
		return
	var shaped := source.duplicate() as RectangleShape2D
	if shaped == null:
		return
	shaped.size = HITBOX_SIZE * _visual_scale
	collider.shape = shaped


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
	_kill_bar_tween()
	_displayed_health = 0.0
	queue_redraw()
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


func _draw() -> void:
	if _leaked or max_health <= 0:
		return
	var origin := Vector2(-_bar_width * 0.5, _bar_y)
	var ratio: float = clampf(_displayed_health / float(max_health), 0.0, 1.0)
	var fill_w: float = _bar_width * ratio
	var fill: Color = Palette.SUCCESS
	if ratio <= 0.33:
		fill = Palette.DANGER
	elif ratio <= 0.66:
		fill = Palette.WARNING
	draw_rect(Rect2(origin, Vector2(_bar_width, BAR_HEIGHT)), Palette.DEEP_SPACE, true)
	if fill_w > 0.5:
		draw_rect(Rect2(origin, Vector2(fill_w, BAR_HEIGHT)), fill, true)
	draw_rect(Rect2(origin, Vector2(_bar_width, BAR_HEIGHT)), Palette.CREAM, false, 1.0)


func _spawn_damage_popup(dealt: int, matchup: StringName = &"neutral") -> void:
	if matchup == &"neutral":
		_spawn_matchup_popup(str(dealt), &"neutral")
		return
	_spawn_matchup_popup(str(dealt), matchup)


func _spawn_matchup_popup(copy: String, matchup: StringName) -> void:
	if matchup == &"neutral" and copy.is_empty():
		return
	var host: Node = get_parent()
	if host == null:
		return
	var marker := Node2D.new()
	marker.z_index = 24
	host.add_child(marker)
	marker.global_position = global_position + Vector2(0.0, _bar_y - 6.0)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = copy
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font_size: int = 10
	var color: Color = Palette.CREAM
	if matchup == &"strong":
		font_size = 14
		color = Palette.SUCCESS
	elif matchup == &"weak":
		font_size = 7
		color = Palette.NAVY_700.lerp(Palette.CREAM, 0.55)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)
	label.position = Vector2(-18.0, -10.0)
	label.size = Vector2(36.0, 18.0)
	marker.add_child(label)
	var rise: Tween = marker.create_tween()
	rise.set_parallel(true)
	rise.tween_property(marker, "position:y", marker.position.y - 20.0, POPUP_LIFE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(marker, "modulate:a", 0.0, POPUP_LIFE)
	rise.set_parallel(false)
	rise.tween_callback(marker.queue_free)


static func character_for_wave(type_id: String) -> String:
	match type_id:
		"fast":
			return "phisherman"
		"heavy", "boss":
			return "ransomware"
		_:
			return "hacker"


static func profile_for_character(character_id: String) -> String:
	match character_id:
		"phisherman":
			return "swarm"
		"ransomware":
			return "heavy"
		_:
			return "stealth"


func damage_multiplier_vs(tower_type: String) -> float:
	if tower_type == "base":
		if threat_profile == "heavy":
			return 1.5
		if threat_profile == "swarm":
			return 0.5
		return 1.0
	if tower_type == "scanner":
		if threat_profile == "swarm":
			return 1.5
		if threat_profile == "heavy":
			return 0.5
		return 1.0
	return 1.0


func sandbox_slow_factor() -> float:
	if threat_profile == "stealth":
		return 0.4
	if threat_profile == "swarm" or threat_profile == "heavy":
		return 0.8
	return 0.6


static func matchup_tier(multiplier: float, strong_at: float, weak_at: float) -> StringName:
	if is_equal_approx(multiplier, strong_at):
		return &"strong"
	if is_equal_approx(multiplier, weak_at):
		return &"weak"
	return &"neutral"


func _slow_matchup_tier(factor: float) -> StringName:
	return matchup_tier(factor, 0.4, 0.8)


func _tween_health_bar() -> void:
	_kill_bar_tween()
	_bar_tween = create_tween()
	_bar_tween.tween_method(_set_displayed_health, _displayed_health, float(current_health), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_displayed_health(value: float) -> void:
	_displayed_health = value
	queue_redraw()


func _kill_bar_tween() -> void:
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = null


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file


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
