extends Control
## Small vector HUD symbols; readable without relying on color or a symbol font.
var kind := "gold"
var health := 5

func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var at := size * 0.5
	if kind == "gold":
		var points := PackedVector2Array()
		for i in 6:
			points.append(at + Vector2.from_angle(TAU * i / 6) * 18)
		draw_colored_polygon(points, Color("e5bd62"))
		points.append(points[0])
		draw_polyline(points, Color("ffe2a0"), 2, true)
		draw_arc(at, 11, 0, TAU, 24, Color("8b652c"), 2, true)
		draw_line(at + Vector2(0, -6), at + Vector2(0, 6), Color("fff0bb"), 3)
	else:
		var tint := Color("a3deb2") if health > 3 else (Color("e5c88a") if health > 1 else Color("ee8791"))
		var points := PackedVector2Array([at + Vector2(-16,-17), at + Vector2(16,-17), at + Vector2(14,4), at + Vector2(0,16), at + Vector2(-14,4), at + Vector2(-16,-17)])
		draw_colored_polygon(points, Color("1e3d38"))
		draw_polyline(points, tint, 2.5, true)
		draw_line(at + Vector2(-7, -3), at + Vector2(7,-3), tint, 3)
		draw_line(at + Vector2(0,-10), at + Vector2(0,4), tint, 3)
		for i in 5:
			draw_rect(Rect2(at + Vector2(-20 + i * 8, 22), Vector2(6, 3)), tint if i < health else Color("394247"))
