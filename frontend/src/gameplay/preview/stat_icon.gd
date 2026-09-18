extends Control
## Vector symbols with short visible captions in the parent, never hover-only.
const Glyphs = preload("res://src/gameplay/preview/unit_glyphs.gd")
var kind := "range"
var tint := Color("85d9c3")

func _ready() -> void:
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_set_transform(size * 0.5)
	match kind:
		"range":
			draw_arc(Vector2.ZERO, 11, 0, TAU, 24, tint, 2, true)
			for v in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				draw_line(v * 7, v * 15, tint, 2)
			draw_circle(Vector2.ZERO, 3, tint)
		"damage":
			draw_colored_polygon(PackedVector2Array([Vector2(4,-15),Vector2(-10,2),Vector2(-2,2),Vector2(-5,15),Vector2(11,-4),Vector2(2,-4)]), tint)
		"rate":
			draw_arc(Vector2.ZERO, 12, 0, TAU, 24, tint, 2, true)
			draw_line(Vector2.ZERO, Vector2(0,-8), tint, 2)
			draw_line(Vector2.ZERO, Vector2(7,3), tint, 2)
		"slow":
			for i in 3:
				var axis := Vector2.from_angle(i * PI / 3) * 13
				draw_line(-axis, axis, tint, 2)
			draw_circle(Vector2.ZERO, 4, tint)
		"heavy":
			Glyphs.bevel(self, Glyphs.polygon(4, 15, PI / 4), tint)
			draw_rect(Rect2(-5,-5,10,10), tint.lightened(0.4), false, 2)
		"swarm":
			for p in [Vector2(-8,5),Vector2(8,5),Vector2(0,-8)]:
				draw_circle(p, 5, tint)
		"stealth":
			draw_arc(Vector2.ZERO, 11, 0, TAU, 6, tint, 2, true)
			draw_line(Vector2(-13,13),Vector2(13,-13),tint,2)
	draw_set_transform(Vector2.ZERO)
