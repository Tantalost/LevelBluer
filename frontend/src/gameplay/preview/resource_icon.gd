extends Control
## Small vector HUD symbols; readable without relying on color or a symbol font.
var kind := "gold"
var health := 5

func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if kind == "pause" and get_parent() is Button:
		var button := get_parent() as Button
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)

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
	elif kind == "pause":
		var button := get_parent() as Button
		var active := button != null and (button.is_hovered() or button.is_pressed())
		var ink := Color("132127") if active else Color("e3eee5")
		for x in [-12.0, 4.0]:
			var bar := Rect2(at + Vector2(x, -14), Vector2(8, 28))
			draw_rect(Rect2(bar.position + Vector2(2, 2), bar.size), Color("20383d"))
			draw_rect(bar, ink)
			draw_rect(Rect2(bar.position, Vector2(8, 3)), ink.lightened(0.2))
	else:
		# A familiar filled heart replaces the shield and duplicate integrity bars.
		var points := PackedVector2Array([Vector2(0,-8),Vector2(-6,-14),Vector2(-13,-14),Vector2(-18,-9),Vector2(-18,-2),Vector2(-13,5),Vector2(0,17),Vector2(13,5),Vector2(18,-2),Vector2(18,-9),Vector2(13,-14),Vector2(6,-14)])
		draw_set_transform(at + Vector2(0, 2))
		draw_colored_polygon(points, Color("5c303b"))
		draw_set_transform(at)
		draw_colored_polygon(points, Color("ee8791") if health > 0 else Color("5d444b"))
		draw_polyline(PackedVector2Array([Vector2(-14,-8),Vector2(-11,-11),Vector2(-7,-11)]), Color("ffc1be") if health > 0 else Color("8b646f"), 2, true)
		draw_set_transform(Vector2.ZERO)
