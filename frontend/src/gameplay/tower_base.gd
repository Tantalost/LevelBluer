class_name TowerBase
extends Area2D
## Combat stats come from ContentDB. Meta ranks from PlayerManager.

const MAX_UPGRADE_LEVEL: int = 7
const UPGRADE_MULT: float = 1.5
const BUFF_DURATION: float = 6.0
const BUFF_FIRE_SCALE: float = 1.6
const LAG_DURATION: float = 6.0
const LAG_FIRE_SCALE: float = 0.55
const GLOBAL_PATCH_DAMAGE: float = 1.15
const AIM_TURN_SPEED: float = 9.0
const IDLE_ANGLE: float = -PI * 0.5
const FIRE_ALIGNMENT_RADIANS: float = 0.3
const DEPLOY_RING_SCALE: Vector2 = Vector2(0.23, 0.23)
const BASIC_NODE_BASE_ASSET_ID := "tower_basic_node_base"
const BASIC_NODE_HEAD_ASSET_ID := "tower_basic_node_head"
const BASIC_NODE_ATLAS_ASSET_ID := "tower_basic_node_atlas"
const ATLAS_CELL_SIZE := 627.0

@export var projectile_scene: PackedScene
@export var starting_type: String = "base"
var current_type: String = "base"
var upgrade_level: int = 0
var fire_rate: float = 1.0
var fire_timer: float = 0.0
var base_damage: int = 1
var current_explosion_radius: float = 0.0
var current_slow_factor: float = 1.0
var current_slow_duration: float = 0.0
var current_zone_slow: float = 1.0
var targets_in_range: Array[Area2D] = []
var current_target: Node2D = null
var _buff_time_left: float = 0.0
var _buff_fire_scale: float = 1.0
var _buff_is_lag: bool = false
var _match_damage_scale: float = 1.0
var _desired_aim_angle: float = IDLE_ANGLE
var _deploy_tween: Tween = null
var _ring_tween: Tween = null
var _recoil_tween: Tween = null
var _flash_tween: Tween = null
var deployment_scale := Vector2.ONE
var ground_range_scale := Vector2.ONE
var combat_map: Node2D = null
var _ground_radius: float = -1.0
var match_context: MatchContext = MatchContext.new()
var _preview_recoil := 0.0
var preview_damage_dealt := 0
var preview_kills := 0

@onready var _base_sprite: Sprite2D = $BaseSprite
@onready var _turret_pivot: Node2D = $TurretPivot
@onready var _head_sprite: Sprite2D = $TurretPivot/HeadSprite
@onready var _muzzle_origin: Marker2D = $TurretPivot/MuzzleOrigin
@onready var _muzzle_flash: Sprite2D = $TurretPivot/MuzzleFlash
@onready var _deploy_ring: Sprite2D = $DeployRing


func _ready() -> void:
	scale = deployment_scale
	if ground_range_scale != Vector2.ONE:
		_ground_radius = _range_radius()
		var points := PackedVector2Array()
		for i in 64:
			points.append(Vector2.from_angle(TAU * i / 64.0) * _ground_radius * ground_range_scale)
		var range_polygon := ConvexPolygonShape2D.new()
		range_polygon.points = points
		$RangeShape.shape = range_polygon
	current_type = starting_type
	add_to_group("towers")
	input_pickable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_bind_runtime_art()
	if starting_type == "base":
		_base_sprite.visible = _base_sprite.texture != null
		_head_sprite.visible = _head_sprite.texture != null
	_turret_pivot.rotation = IDLE_ANGLE
	apply_stats(starting_type)
	queue_redraw()
	call_deferred("play_deploy_animation")


func _bind_runtime_art() -> void:
	if match_context.geometric:
		_base_sprite.hide()
		_head_sprite.hide()
		_muzzle_flash.hide()
		_deploy_ring.hide()
		_muzzle_origin.position = Vector2(27, 0)
		return
	if starting_type != "base":
		_base_sprite.visible = false
		_head_sprite.visible = false
		_muzzle_flash.visible = false
		_deploy_ring.visible = false
		return
	var base_texture: Texture2D = AssetManager.get_texture(BASIC_NODE_BASE_ASSET_ID)
	if base_texture != null:
		_base_sprite.texture = base_texture
	var head_texture: Texture2D = AssetManager.get_texture(BASIC_NODE_HEAD_ASSET_ID)
	if head_texture != null:
		_head_sprite.texture = head_texture
	var atlas_texture: Texture2D = AssetManager.get_texture(BASIC_NODE_ATLAS_ASSET_ID)
	if atlas_texture == null:
		return
	var muzzle_region := AtlasTexture.new()
	muzzle_region.atlas = atlas_texture
	muzzle_region.region = Rect2(0.0, ATLAS_CELL_SIZE, ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	_muzzle_flash.texture = muzzle_region
	var deploy_region := AtlasTexture.new()
	deploy_region.atlas = atlas_texture
	deploy_region.region = Rect2(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE, ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	_deploy_ring.texture = deploy_region


func _draw() -> void:
	if match_context.geometric:
		preload("res://src/gameplay/preview/unit_glyphs.gd").tower(self, current_type, _turret_pivot.rotation, _preview_recoil, _range_radius())
		return
	if current_type == "sandbox":
		var radius: float = _range_radius()
		draw_set_transform(Vector2.ZERO, 0.0, ground_range_scale)
		draw_circle(Vector2.ZERO, radius, Color(Palette.PURPLE, 0.22))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(Palette.PURPLE, 0.7), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	if current_type == "base" and _base_sprite.texture != null and _head_sprite.texture != null:
		return
	match current_type:
		"scanner":
			_draw_scanner_placeholder()
		"sandbox":
			_draw_sandbox_placeholder()
		_:
			draw_circle(Vector2.ZERO, 40.0, Palette.BG_HEADER)
			draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 36, Palette.CYAN, 3.0, true)
			draw_rect(Rect2(-20.0, -22.0, 40.0, 44.0), Palette.CYAN_DIM, true)
			draw_rect(Rect2(-20.0, -22.0, 40.0, 44.0), Palette.CYAN, false, 3.0)
			draw_rect(Rect2(14.0, -11.0, 36.0, 22.0), Palette.CYAN, true)
			draw_circle(Vector2.ZERO, 11.0, Palette.GOLD)


func _draw_scanner_placeholder() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -36.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, 36.0),
		Vector2(-28.0, 0.0),
	]), Palette.BLUE_400)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Palette.CYAN_300, 2.0, true)


func _draw_sandbox_placeholder() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -28.0),
		Vector2(24.0, -14.0),
		Vector2(24.0, 14.0),
		Vector2(0.0, 28.0),
		Vector2(-24.0, 14.0),
		Vector2(-24.0, -14.0),
	]), Palette.PURPLE)
	draw_rect(Rect2(-10.0, -10.0, 20.0, 20.0), Palette.NAVY_900, true)


func apply_stats(type_id: String) -> void:
	var entry: Dictionary = entry_for(type_id)
	if entry.is_empty():
		push_warning("[Tower] Unknown type '%s'" % type_id)
		return
	current_type = type_id
	base_damage = damage_at(type_id, upgrade_level)
	fire_rate = float(entry.get("fire_rate", 1.0))
	current_explosion_radius = splash_radius_for(type_id)
	current_slow_factor = slow_factor_for(type_id)
	current_slow_duration = slow_duration_for(type_id)
	current_zone_slow = zone_slow_for(type_id)
	_apply_meta_stats()
	if current_type == "base" and match_context.account_bonuses:
		fire_rate += float(PlayerManager.stats_bonus_for("base").get("fire_rate", 0.0))
	queue_redraw()
	if _buff_time_left > 0.0:
		modulate = Palette.CYAN_DIM if _buff_is_lag else Palette.YELLOW
	else:
		_restore_modulate()


static func entry_for(type_id: String) -> Dictionary:
	return ContentDB.get_tower(type_id)


static func cost_for(type_id: String) -> int:
	return int(entry_for(type_id).get("cost", 0))


static func scale_up(value: int) -> int:
	return maxi(1, int(ceil(float(maxi(1, value)) * UPGRADE_MULT)))


static func upgrade_cost_at(type_id: String, current_level: int) -> int:
	if current_level < 0 or current_level >= MAX_UPGRADE_LEVEL:
		return 0
	var cost: int = scale_up(maxi(1, cost_for(type_id)))
	for _i in current_level:
		cost = scale_up(cost)
	return cost


static func damage_at(type_id: String, level: int) -> int:
	var damage: int = maxi(0, int(entry_for(type_id).get("damage", 1)))
	if damage <= 0:
		return 0
	var steps: int = clampi(level, 0, MAX_UPGRADE_LEVEL)
	for _i in steps:
		damage = scale_up(damage)
	return damage


func can_upgrade() -> bool:
	return upgrade_level < MAX_UPGRADE_LEVEL


func next_upgrade_cost() -> int:
	return upgrade_cost_at(current_type, upgrade_level)


func apply_power_upgrade() -> bool:
	if not can_upgrade():
		return false
	upgrade_level += 1
	base_damage = damage_at(current_type, upgrade_level)
	_apply_meta_stats()
	return true


static func display_name_for(type_id: String) -> String:
	return str(entry_for(type_id).get("name", type_id))


static func role_for(type_id: String) -> String:
	return str(entry_for(type_id).get("role", "DPS"))


static func accent_for(type_id: String) -> Color:
	var stored: Variant = entry_for(type_id).get("color", Palette.CYAN)
	if typeof(stored) == TYPE_COLOR:
		return stored as Color
	return Palette.CYAN


static func req_skill_for(type_id: String) -> String:
	return str(entry_for(type_id).get("req_skill", ""))


static func explosion_radius_for(type_id: String) -> float:
	return splash_radius_for(type_id)


static func splash_radius_for(type_id: String) -> float:
	var entry: Dictionary = entry_for(type_id)
	if entry.has("splash_radius"):
		return float(entry["splash_radius"])
	return float(entry.get("explosion_radius", 0.0))


static func slow_factor_for(type_id: String) -> float:
	return float(entry_for(type_id).get("slow_factor", 1.0))


static func slow_duration_for(type_id: String) -> float:
	return float(entry_for(type_id).get("slow_duration", 0.0))


static func zone_slow_for(type_id: String) -> float:
	return float(entry_for(type_id).get("zone_slow", 1.0))


func _apply_meta_stats() -> void:
	if not match_context.account_bonuses:
		return
	if current_type != "base":
		return
	var bonus: Dictionary = PlayerManager.stats_bonus_for("base")
	base_damage += int(bonus.get("damage", 0))


func _on_area_entered(area: Area2D) -> void:
	if not targets_in_range.has(area):
		targets_in_range.append(area)
	_apply_zone_to(area, true)


func _on_area_exited(area: Area2D) -> void:
	targets_in_range.erase(area)
	_apply_zone_to(area, false)


func _apply_zone_to(area: Area2D, entering: bool) -> void:
	if current_type != "sandbox":
		return
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if enemy == null or not is_instance_valid(enemy):
		return
	if entering:
		enemy.add_zone_slow(enemy.sandbox_slow_factor(), true)
	else:
		enemy.remove_zone_slow()


func _process(delta: float) -> void:
	if match_context.geometric:
		_preview_recoil = maxf(0, _preview_recoil - delta * 8)
		queue_redraw()
	_prune_invalid_targets()
	if current_type == "sandbox" or fire_rate <= 0.0:
		current_target = null
		_desired_aim_angle = IDLE_ANGLE
		if _buff_time_left > 0.0:
			_buff_time_left -= delta
			if _buff_time_left <= 0.0:
				_buff_time_left = 0.0
				_buff_fire_scale = 1.0
				_buff_is_lag = false
				_restore_modulate()
		return
	if targets_in_range.is_empty():
		current_target = null
		_desired_aim_angle = IDLE_ANGLE
	else:
		var parent: Node = targets_in_range[0].get_parent()
		current_target = parent as Node2D
		if current_target != null:
			_desired_aim_angle = to_local(current_target.global_position).angle()
	var aim_weight: float = 1.0 - exp(-AIM_TURN_SPEED * delta)
	_turret_pivot.rotation = lerp_angle(_turret_pivot.rotation, _desired_aim_angle, aim_weight)

	if _buff_time_left > 0.0:
		_buff_time_left -= delta
		if _buff_time_left <= 0.0:
			_buff_time_left = 0.0
			_buff_fire_scale = 1.0
			_buff_is_lag = false
			_restore_modulate()

	fire_timer -= delta
	var active_rate: float = fire_rate * _buff_fire_scale
	var aim_error: float = absf(angle_difference(_turret_pivot.rotation, _desired_aim_angle))
	if fire_timer <= 0.0 and current_target != null and active_rate > 0.0 and aim_error <= FIRE_ALIGNMENT_RADIANS:
		fire_timer = 1.0 / active_rate
		_fire()


func apply_incident_buff() -> void:
	_buff_time_left = BUFF_DURATION
	_buff_fire_scale = BUFF_FIRE_SCALE
	_buff_is_lag = false
	modulate = Palette.YELLOW
	print("Tower Buffed!")


func apply_incident_lag() -> void:
	_buff_time_left = LAG_DURATION
	_buff_fire_scale = LAG_FIRE_SCALE
	_buff_is_lag = true
	modulate = Palette.CYAN_DIM
	print("Tower Lagged!")


func apply_global_patch() -> void:
	_match_damage_scale = GLOBAL_PATCH_DAMAGE


func _restore_modulate() -> void:
	var entry: Dictionary = entry_for(current_type)
	var stored_color: Variant = entry.get("color", Palette.CYAN)
	modulate = Color.WHITE
	var accent: Color = stored_color as Color
	_head_sprite.modulate = Color.WHITE.lerp(accent, 0.2) if current_type != "base" else Color.WHITE


func _pierce_extra() -> int:
	if not match_context.account_bonuses:
		return 0
	if current_type != "base":
		return 0
	if PlayerManager.has_stateful_inspection:
		return 1
	return 0


func _range_radius() -> float:
	if _ground_radius > 0.0:
		return _ground_radius
	var shape_node: CollisionShape2D = $RangeShape as CollisionShape2D
	if shape_node == null:
		return 100.0
	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	if circle == null:
		return 100.0
	return circle.radius


func _fire() -> void:
	if projectile_scene == null or current_target == null:
		return
	_play_attack_animation()
	var instance: Node = projectile_scene.instantiate()
	var projectile: ProjectileBase = instance as ProjectileBase
	if projectile == null:
		push_warning("[Tower] projectile_scene is not a ProjectileBase.")
		return
	projectile.initialize(
		current_target,
		maxi(0, int(round(float(base_damage) * _match_damage_scale))),
		current_explosion_radius,
		current_slow_factor,
		current_slow_duration,
		_pierce_extra(),
		current_type,
	)
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	projectile.match_context = match_context
	if match_context.geometric:
		projectile.source_tower = weakref(self)
	parent_node.add_child(projectile)
	projectile.combat_map = combat_map
	projectile.scale = deployment_scale
	projectile.global_position = _muzzle_origin.global_position
	AudioManager.play_sfx("shoot")


func play_deploy_animation() -> void:
	if not is_inside_tree():
		return
	if _deploy_tween != null and _deploy_tween.is_valid():
		_deploy_tween.kill()
	if _ring_tween != null and _ring_tween.is_valid():
		_ring_tween.kill()
	scale = deployment_scale * 0.28
	modulate.a = 0.0
	_deploy_ring.visible = true
	_deploy_ring.scale = DEPLOY_RING_SCALE * 0.55
	_deploy_ring.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_deploy_tween = create_tween()
	_deploy_tween.set_parallel(true)
	_deploy_tween.tween_property(self, "scale", deployment_scale * 1.08, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deploy_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	_deploy_tween.chain().tween_property(self, "scale", deployment_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ring_tween = create_tween()
	_ring_tween.set_parallel(true)
	_ring_tween.tween_property(_deploy_ring, "scale", DEPLOY_RING_SCALE * 1.18, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ring_tween.tween_property(_deploy_ring, "modulate:a", 0.0, 0.34).set_delay(0.08)
	_ring_tween.chain().tween_callback(_finish_deploy_ring)


func play_redeploy_animation() -> void:
	play_deploy_animation()


func _finish_deploy_ring() -> void:
	_deploy_ring.visible = false
	_deploy_ring.scale = DEPLOY_RING_SCALE


func _play_attack_animation() -> void:
	if match_context.geometric:
		_preview_recoil = 1.0
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_head_sprite.position = Vector2.ZERO
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_head_sprite, "position:x", -5.5, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_head_sprite, "position:x", 0.0, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_muzzle_flash.visible = true
	_muzzle_flash.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_muzzle_flash.scale = Vector2(0.07, 0.07)
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	_flash_tween.tween_property(_muzzle_flash, "scale", Vector2(0.125, 0.125), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_muzzle_flash, "modulate:a", 0.0, 0.12).set_delay(0.035)
	_flash_tween.chain().tween_callback(_hide_muzzle_flash)


func _hide_muzzle_flash() -> void:
	_muzzle_flash.visible = false


func _prune_invalid_targets() -> void:
	var alive: Array[Area2D] = []
	for area: Area2D in targets_in_range:
		if is_instance_valid(area) and not area.is_queued_for_deletion():
			alive.append(area)
	targets_in_range = alive
