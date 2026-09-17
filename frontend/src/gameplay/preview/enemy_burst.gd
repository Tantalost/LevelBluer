extends Node2D
## Local-space, texture-free colored particle burst; no global VFX host.
var tint := Color.WHITE
var elapsed := 0.0
const LIFE := 0.55

func _ready() -> void:
	z_index = 20
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 18
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 45
	particles.initial_velocity_max = 115
	particles.damping_min = 80
	particles.damping_max = 110
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	particles.angular_velocity_min = -180
	particles.angular_velocity_max = 180
	var colors := Gradient.new()
	colors.set_color(0, tint.lightened(0.25))
	colors.set_color(1, Color(tint, 0))
	particles.color_ramp = colors
	add_child(particles)
	particles.emitting = true

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= LIFE:
		queue_free()

func _draw() -> void:
	var fade := 1.0 - clampf(elapsed / LIFE, 0, 1)
	draw_arc(Vector2.ZERO, 7 + elapsed * 64, 0, TAU, 24, Color(tint, fade * 0.65), 2, true)
