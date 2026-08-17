class_name SkillNodeUI
extends Control
## Diamond upgrade node. Emits skill_pressed; purchase / save is out of scope.

signal skill_pressed(skill_id: String)

@export var skill_id: String = "starter"
@export var current_rank: int = 0
@export var max_rank: int = 1

@onready var _icon: Label = %NodeIcon
@onready var _rank: Label = %RankLabel
@onready var _particles: CPUParticles2D = %AuraParticles
@onready var _hit: Button = %HitButton

var _pixel_font: Font
var _diamond_size := 56.0
var _skill_name: String = ""
var _state: String = "LOCKED"


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_hit.pressed.connect(func() -> void: skill_pressed.emit(skill_id))
	_refresh_rank()
	_setup_particles()
	resized.connect(queue_redraw)
	_apply_state_visuals()


func configure(p_skill_id: String, rank: int, p_max_rank: int, font: Font) -> void:
	skill_id = p_skill_id
	current_rank = rank
	max_rank = maxi(1, p_max_rank)
	_pixel_font = font
	if _pixel_font:
		_rank.add_theme_font_override("font", _pixel_font)
		_icon.add_theme_font_override("font", _pixel_font)
	_refresh_rank()
	queue_redraw()


func set_skill_data(p_skill_id: String, p_skill_name: String, p_state: String) -> void:
	skill_id = p_skill_id
	_skill_name = p_skill_name
	_state = p_state
	_apply_state_visuals()


func apply_scale(diamond_px: int, font_px: int) -> void:
	_diamond_size = float(diamond_px)
	custom_minimum_size = Vector2(diamond_px + 24, diamond_px + 36)
	size = custom_minimum_size
	_rank.add_theme_font_size_override("font_size", font_px)
	_icon.add_theme_font_size_override("font_size", maxi(10, int(round(font_px * 1.2))))
	_hit.position = Vector2(12, 4)
	_hit.size = Vector2(diamond_px, diamond_px)
	if _particles:
		_particles.position = Vector2(size.x * 0.5, 10.0)
		_particles.emission_sphere_radius = diamond_px * 0.18
	queue_redraw()


func place_on_canvas(graph_position: Vector2) -> void:
	position = graph_position - size * 0.5


func _refresh_rank() -> void:
	if _rank:
		_rank.text = "%d/%d" % [current_rank, max_rank]


func _setup_particles() -> void:
	_particles.amount = 14
	_particles.lifetime = 1.15
	_particles.one_shot = false
	_particles.explosiveness = 0.05
	_particles.randomness = 0.4
	_particles.direction = Vector2(0, -1)
	_particles.spread = 28.0
	_particles.gravity = Vector2(0, -18)
	_particles.initial_velocity_min = 12.0
	_particles.initial_velocity_max = 28.0
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 2.0
	_particles.color = Palette.SKILL_AURA
	_particles.emitting = false


func _apply_state_visuals() -> void:
	var unlocked := _state == "UNLOCKED"
	if _particles:
		_particles.emitting = unlocked
		_particles.color = Palette.SKILL_AURA
	if _icon:
		match _state:
			"UNLOCKED":
				_icon.add_theme_color_override("font_color", Palette.SKILL_AURA)
			"PURCHASABLE":
				_icon.add_theme_color_override("font_color", Palette.GOLD)
			_:
				_icon.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	if _rank:
		_rank.add_theme_color_override("font_color", Palette.TEXT_PRIMARY if unlocked or _state == "PURCHASABLE" else Palette.TEXT_MUTED)
	modulate = Color.WHITE if _state != "LOCKED" else Color(Palette.TEXT_MUTED, 0.9)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, _diamond_size * 0.5 + 6.0)
	var half := _diamond_size * 0.5
	var fill := Palette.BG_HEADER
	var glow := Color(Palette.SKILL_AURA, 0.18)
	var outline := Palette.SKILL_AURA
	var inner := Color(Palette.SKILL_AURA, 0.45)
	var outline_w := 3.0
	match _state:
		"PURCHASABLE":
			glow = Color(Palette.GOLD, 0.16)
			outline = Palette.GOLD
			inner = Color(Palette.GOLD, 0.5)
		"LOCKED":
			glow = Color.TRANSPARENT
			outline = Palette.CYAN_DIM
			inner = Color(Palette.CYAN_DIM, 0.25)
			outline_w = 2.0
	draw_colored_polygon(_diamond(center, half + 7.0), glow)
	draw_colored_polygon(_diamond(center, half), fill)
	draw_polyline(_diamond_closed(center, half), outline, outline_w, false)
	draw_polyline(_diamond_closed(center, half - 5.0), inner, 1.5, false)


func _diamond(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -half),
		center + Vector2(half, 0.0),
		center + Vector2(0.0, half),
		center + Vector2(-half, 0.0),
	])


func _diamond_closed(center: Vector2, half: float) -> PackedVector2Array:
	var pts := _diamond(center, half)
	pts.append(pts[0])
	return pts
