extends Button
## Code-drawn roadmap symbols: no image downloads or font-dependent glyphs.
var kind := 0
var complete := false
var ink := Color("85d9c3")

func _draw() -> void:
	var p := size * 0.5
	if disabled:
		draw_arc(p + Vector2(0, -5), 9, PI, TAU, 16, ink, 3, true)
		draw_rect(Rect2(p + Vector2(-13, -5), Vector2(26, 22)), ink, false, 3)
	elif complete:
		draw_polyline(PackedVector2Array([p + Vector2(-13, 0), p + Vector2(-3, 10), p + Vector2(16, -12)]), ink, 4, true)
	elif kind == 0:
		for direction in [-1, 1]:
			var x := float(direction)
			draw_polyline(PackedVector2Array([p + Vector2(0, 13), p + Vector2(x * 18, 8), p + Vector2(x * 18, -14), p + Vector2(0, -9), p + Vector2(0, 13)]), ink, 3, true)
	elif kind == 1:
		draw_rect(Rect2(p + Vector2(-14, -18), Vector2(28, 36)), ink, false, 3)
		for y in [-8, 2, 12]:
			draw_line(p + Vector2(-7, y), p + Vector2(8, y), ink, 2, true)
	else:
		draw_rect(Rect2(p + Vector2(-20, -15), Vector2(40, 27)), ink, false, 3)
		draw_line(p + Vector2(0, 12), p + Vector2(0, 20), ink, 3, true)
		draw_line(p + Vector2(-12, 20), p + Vector2(12, 20), ink, 3, true)
