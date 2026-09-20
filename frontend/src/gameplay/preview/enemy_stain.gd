extends Node2D
## Non-interactive residue beneath units/arrows, above terrain; fades then frees.
const HOLD := 2.2
const LIFE := 4.2
var tint := Color.WHITE
var kind := "basic"
var elapsed := 0.0
var _patches: Array[Dictionary] = []

func _ready() -> void:
	z_index = -1
	set_meta("preview_death_stain", true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var size_scale := 1.3 if kind == "boss" else 1.0
	for i in 15:
		var at := Vector2.ZERO if i == 0 else Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(7, 28) * size_scale
		var radius := (15.0 if i == 0 else rng.randf_range(1.5, 5.5)) * size_scale
		var points := PackedVector2Array()
		var vertices := 10 if i == 0 else 5
		for p in vertices:
			points.append(at + Vector2.from_angle(TAU * float(p) / vertices) * radius * rng.randf_range(0.55, 1.0))
		_patches.append({"points": points, "alpha": 0.38 if i == 0 else rng.randf_range(0.15, 0.32)})

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFE:
		queue_free()
	elif elapsed >= HOLD:
		queue_redraw()

func opacity() -> float:
	return 1.0 - smoothstep(HOLD, LIFE, elapsed)

func _draw() -> void:
	for patch in _patches:
		draw_colored_polygon(patch.points, Color(tint.darkened(0.2), float(patch.alpha) * opacity()))
