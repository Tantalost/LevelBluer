extends Control
## Lightweight, reusable signal diagrams. No downloaded or generated artwork.
var accent := Color("8dc9bd")
var module_index := 0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 1 or size.y < 1:
		return
	draw_style_box(_well(), Rect2(Vector2.ZERO, size))
	var center := size * 0.5
	var r := minf(size.y * 0.38, size.x * 0.2)
	var dark := Color(accent, 0.17)
	for side in [-1, 1]:
		for lane in 3:
			var start := Vector2(center.x + side * (r + 12), center.y + (lane - 1) * 24)
			var finish := Vector2(center.x + side * (size.x * 0.42), 28 + lane * (size.y - 56) / 2)
			var bend := Vector2(center.x + side * (r + 44), start.y)
			draw_polyline(PackedVector2Array([start, bend, Vector2(bend.x + side * 24, finish.y), finish]), dark, 2, true)
			draw_rect(Rect2(finish - Vector2(4, 4), Vector2(8, 8)), accent if lane == module_index % 3 else dark)
	var hex := PackedVector2Array()
	for n in 6:
		hex.append(center + Vector2.from_angle(PI / 3 * n) * r)
	draw_colored_polygon(hex, Color(accent, 0.06))
	hex.append(hex[0])
	draw_polyline(hex, accent, 2, true)
	var radius := r * 0.5
	match module_index:
		0:
			draw_rect(Rect2(center - Vector2(radius, radius * 0.65), Vector2(radius * 2, radius * 1.3)), accent, false, 3)
			draw_polyline(PackedVector2Array([center + Vector2(-radius, -radius * 0.65), center + Vector2(0, radius * 0.15), center + Vector2(radius, -radius * 0.65)]), accent, 3, true)
		1:
			draw_rect(Rect2(center - Vector2(radius * 0.6, radius), Vector2(radius * 1.2, radius * 2)), accent, false, 3)
			draw_line(center + Vector2(-radius * 0.35, radius * 0.6), center + Vector2(radius * 0.35, radius * 0.6), accent, 3)
			draw_circle(center, 4, accent)
		2:
			draw_arc(center, radius, PI, TAU, 24, accent, 3, true)
			for side in [-1, 1]:
				draw_rect(Rect2(center + Vector2(side * radius - 5, -3), Vector2(10, radius * 0.8)), accent)
			draw_line(center + Vector2(radius, radius * 0.8), center + Vector2(4, radius), accent, 3, true)
		3:
			draw_rect(Rect2(center - Vector2(radius, radius * 0.8), Vector2(radius * 2, radius * 1.6)), accent, false, 3)
			draw_circle(center + Vector2(-radius * 0.4, -5), 6, accent)
			draw_line(center + Vector2(-radius * 0.6, 10), center + Vector2(-radius * 0.2, 10), accent, 3)
			for y in [-6, 6]:
				draw_line(center + Vector2(3, y), center + Vector2(radius * 0.7, y), accent, 2)
		_:
			draw_rect(Rect2(center - Vector2(radius, radius * 0.55), Vector2(radius * 2, radius * 1.4)), accent, false, 3)
			draw_line(center + Vector2(0, -radius * 0.55), center + Vector2(0, radius * 0.85), accent, 3)
			draw_arc(center + Vector2(-9, -radius * 0.7), 9, 0, TAU, 16, accent, 2, true)
			draw_arc(center + Vector2(9, -radius * 0.7), 9, 0, TAU, 16, accent, 2, true)

func _well() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1b23")
	style.border_color = Color(accent, 0.2)
	style.set_border_width_all(1)
	return style
