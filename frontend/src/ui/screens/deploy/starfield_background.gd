extends ColorRect
## Seeded pixel-star field. Redraws on resize so the density stays stable.

const STAR_COUNT := 140

var _stars: Array[Vector3] = []


func _ready() -> void:
	color = Palette.BG_STARFIELD
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_rebuild()


func _rebuild() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260815
	for _i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for star in _stars:
		var px := Vector2(star.x * size.x, star.y * size.y)
		var dim := 1.0 if star.z < 0.75 else 2.0
		var alpha := lerpf(0.22, 0.85, star.z)
		draw_rect(Rect2(px, Vector2(dim, dim)), Color(0.62, 0.52, 0.82, alpha))
