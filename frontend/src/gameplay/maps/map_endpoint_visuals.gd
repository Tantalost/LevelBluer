class_name MapEndpointVisuals
extends Node2D
## Reusable 16-bit endpoint presentation shared by every gameplay map.

const SPAWN_ASSET := "enemy_spawn_broken_pc"
const HOME_CLEAN_ASSET := "home_base_clean"
const HOME_CRACKED_ASSET := "home_base_cracked"
const HOME_CRITICAL_ASSET := "home_base_critical"
const EDITOR_TEXTURES := {
	SPAWN_ASSET: "res://assets/gameplay/map_endpoints/enemy_spawn_broken_pc_v1.png",
	HOME_CLEAN_ASSET: "res://assets/gameplay/map_endpoints/home_base_clean_v1.png",
	HOME_CRACKED_ASSET: "res://assets/gameplay/map_endpoints/home_base_cracked_v1.png",
	HOME_CRITICAL_ASSET: "res://assets/gameplay/map_endpoints/home_base_critical_v1.png",
}

const DISPLAY_EXTENT: float = 132.0
const SPRITE_Y_OFFSET: float = -8.0
const SHADOW := Color("071019")
const SPAWN_RING := Color("b62e48")
const HOME_RING := Color("20b7d5")

var _start_position := Vector2.ZERO
var _end_position := Vector2.ZERO
var _spawn_sprite: Sprite2D
var _home_sprite: Sprite2D
var _current_health: int = 5
var _max_health: int = 5
var _isometric_style: bool = false
var _destroyed := false


func play_home_destruction() -> void:
	if _destroyed:
		return
	_destroyed = true
	_ensure_sprites()
	var critical := _texture_for(HOME_CRITICAL_ASSET)
	if critical == null:
		critical = _home_sprite.texture
	if critical == null:
		push_warning("Base destruction: home texture is unavailable.")
		return
	_home_sprite.visible = false
	var effect := preload("res://src/gameplay/base_destruction.gd").new()
	effect.name = "BaseDestruction"
	effect.position = _home_sprite.position
	effect.configure(critical, critical.get_size() * _home_sprite.scale)
	add_child(effect)


func set_isometric_style(enabled: bool) -> void:
	_isometric_style = enabled
	_fit_sprite(_spawn_sprite)
	_fit_sprite(_home_sprite)
	queue_redraw()


func _ready() -> void:
	z_index = 8
	_ensure_sprites()
	_sync_positions()
	_sync_home_texture()
	if not Engine.is_editor_hint():
		AssetManager.sync_finished.connect(_on_assets_ready)


func _texture_for(asset_id: String) -> Texture2D:
	if not Engine.is_editor_hint():
		return AssetManager.get_texture(asset_id)
	var path: String = EDITOR_TEXTURES.get(asset_id, "")
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _on_assets_ready(_success: bool) -> void:
	_spawn_sprite.texture = _texture_for(SPAWN_ASSET)
	_fit_sprite(_spawn_sprite)
	_sync_home_texture()


func configure(start_position: Vector2, end_position: Vector2) -> void:
	_start_position = start_position
	_end_position = end_position
	_ensure_sprites()
	_sync_positions()
	queue_redraw()


func set_health(current_health: int, max_health: int = 5) -> void:
	_current_health = maxi(0, current_health)
	_max_health = maxi(1, max_health)
	_ensure_sprites()
	_sync_home_texture()


func _ensure_sprites() -> void:
	if _spawn_sprite == null:
		_spawn_sprite = Sprite2D.new()
		_spawn_sprite.name = "EnemySpawnSprite"
		_spawn_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spawn_sprite.texture = _texture_for(SPAWN_ASSET)
		add_child(_spawn_sprite)
		_fit_sprite(_spawn_sprite)
	if _home_sprite == null:
		_home_sprite = Sprite2D.new()
		_home_sprite.name = "HomeBaseSprite"
		_home_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_home_sprite)


func _sync_positions() -> void:
	if _spawn_sprite != null:
		_spawn_sprite.position = _start_position + Vector2(0.0, SPRITE_Y_OFFSET)
	if _home_sprite != null:
		_home_sprite.position = _end_position + Vector2(0.0, SPRITE_Y_OFFSET)


func _sync_home_texture() -> void:
	if _home_sprite == null:
		return
	if _destroyed:
		return
	if _current_health <= 1:
		_home_sprite.texture = _texture_for(HOME_CRITICAL_ASSET)
	elif _current_health >= _max_health:
		_home_sprite.texture = _texture_for(HOME_CLEAN_ASSET)
	else:
		_home_sprite.texture = _texture_for(HOME_CRACKED_ASSET)
	_fit_sprite(_home_sprite)


func _fit_sprite(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null:
		return
	var longest_side: float = maxf(float(sprite.texture.get_width()), float(sprite.texture.get_height()))
	if longest_side <= 0.0:
		return
	var fitted_scale: float = DISPLAY_EXTENT / longest_side
	if _isometric_style:
		fitted_scale *= 2.4
	sprite.scale = Vector2(fitted_scale, fitted_scale)


func _draw() -> void:
	if _isometric_style:
		for item in [[_start_position, SPAWN_RING], [_end_position, HOME_RING]]:
			draw_set_transform(item[0], 0.0, Vector2(2.2,1.1))
			draw_circle(Vector2.ZERO,41.0,Color(SHADOW,0.8))
			draw_arc(Vector2.ZERO,39.0,0.0,TAU,32,Color(item[1],0.7),2.5)
		draw_set_transform(Vector2.ZERO)
		return
	# Circular plates conceal the legacy wire-cube marks in the Stage 1 baked
	# backdrop while avoiding another square-shaped endpoint marker.
	draw_circle(_start_position + Vector2(0.0, 2.0), 41.0, Color(SHADOW, 0.94))
	draw_arc(_start_position + Vector2(0.0, 2.0), 39.0, PI * 0.12, PI * 1.88, 22, Color(SPAWN_RING, 0.68), 3.0)
	draw_circle(_end_position + Vector2(0.0, 2.0), 41.0, Color(SHADOW, 0.94))
	draw_arc(_end_position + Vector2(0.0, 2.0), 39.0, PI * 0.12, PI * 1.88, 22, Color(HOME_RING, 0.68), 3.0)
