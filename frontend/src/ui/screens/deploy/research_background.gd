extends ColorRect
## Restrained blueprint backdrop, local to research (not other deploy screens).

func _ready() -> void:
	color = Color("080e18")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	for x in range(0, int(size.x), 48):
		for y in range(72, int(size.y), 48):
			draw_circle(Vector2(x, y), 0.8, Color(0.35, 0.55, 0.7, 0.12))
	var center := size * Vector2(0.5, 0.53)
	for r in [0.22, 0.34, 0.46]:
		draw_arc(center, size.x * r, 0, TAU, 128, Color(0.2, 0.48, 0.6, 0.035), 1.0, true)
	draw_line(Vector2(24, 67), Vector2(size.x - 24, 67), Color("223144"))
