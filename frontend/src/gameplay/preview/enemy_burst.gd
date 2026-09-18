extends Node2D
## Local-space shards, silhouette fragments and a brief impact core.
## Uses a private RNG so cosmetic variation cannot change combat randomness.
var tint := Color.WHITE
var kind := "basic"
var elapsed := 0.0
const LIFE := 1.05
var _pieces: Array[Dictionary] = []

func _ready() -> void:
	z_index = 20
	set_meta("preview_death_burst", true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := 14 if kind == "boss" else 10
	for i in count:
		var angle := TAU * float(i) / count + rng.randf_range(-0.2, 0.2)
		var radius := rng.randf_range(4.0, 8.0) * (1.25 if kind == "boss" else 1.0)
		var shape := PackedVector2Array()
		if kind == "basic" and i % 2 == 0:
			shape.append(Vector2(-radius * 0.3, 0))
			for segment in 7:
				shape.append(Vector2.from_angle(-PI * 0.65 + segment * PI * 1.3 / 6.0) * radius)
		elif kind in ["heavy", "boss"] and i % 2 == 0:
			shape = PackedVector2Array([Vector2(-radius,-radius * 0.6),Vector2(radius * 0.8,-radius * 0.4),Vector2(radius,radius * 0.7),Vector2(-radius * 0.5,radius)])
		else:
			shape = PackedVector2Array([Vector2(0,-radius),Vector2(radius * 0.7,radius * 0.7),Vector2(-radius * 0.7,radius * 0.4)])
		_pieces.append({"shape": shape, "velocity": Vector2.from_angle(angle) * rng.randf_range(100, 210),
			"spin": rng.randf_range(-9, 9), "angle": rng.randf_range(-PI, PI), "lift": rng.randf_range(8, 20), "shade": rng.randf_range(0.05, 0.35)})
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 48 if kind == "boss" else 34
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 95
	particles.initial_velocity_max = 220
	particles.damping_min = 140
	particles.damping_max = 210
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 2.5
	particles.angular_velocity_min = -180
	particles.angular_velocity_max = 180
	var colors := Gradient.new()
	colors.set_color(0, tint.lightened(0.4))
	colors.add_point(0.3, Color(tint, 0.85))
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
	var t := clampf(elapsed / LIFE, 0, 1)
	var fade := 1.0 - smoothstep(0.45, 1.0, t)
	for piece in _pieces:
		var at: Vector2 = piece.velocity * (1.0 - exp(-elapsed * 2.8)) / 2.8
		at.y -= sin(t * PI) * float(piece.lift)
		draw_set_transform(at, float(piece.angle) + float(piece.spin) * elapsed, Vector2.ONE * lerpf(1.0, 0.65, t))
		var ink := Color(tint.lightened(float(piece.shade)), fade)
		draw_colored_polygon(piece.shape, ink)
		var shape: PackedVector2Array = piece.shape
		draw_line(shape[0], shape[1], Color(tint.lightened(0.55), fade * 0.7), 1, true)
	draw_set_transform(Vector2.ZERO)
	if elapsed < 0.22:
		var impact := 1.0 - elapsed / 0.22
		draw_arc(Vector2.ZERO, 8 + elapsed * 85, 0, TAU, 28, Color(tint, impact * 0.55), 1.5, true)
	if elapsed < 0.09:
		draw_circle(Vector2.ZERO, 6 * (1.0 - elapsed / 0.09), Color(tint.lightened(0.65), 0.8))
