extends RefCounted
const TEAL := Color("85d9c3")
const DARK := Color("14252b")

static func polygon(sides: int, radius: float, angle: float = 0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(Vector2.from_angle(angle + TAU * i / sides) * radius)
	return points

static func tower(canvas: CanvasItem, kind: String, angle: float = 0, recoil: float = 0, radius: float = 100) -> void:
	canvas.draw_circle(Vector2(0, 4), 25, Color(0, 0, 0, 0.25))
	match kind:
		"scanner":
			var points := polygon(4, 26)
			canvas.draw_colored_polygon(points, DARK)
			points.append(points[0])
			canvas.draw_polyline(points, Color("a6c9f5"), 3, true)
			canvas.draw_arc(Vector2.ZERO, 15, angle - 0.7, angle + 0.7, 16, TEAL, 3, true)
			canvas.draw_line(Vector2.ZERO, Vector2.from_angle(angle) * 22, TEAL, 4, true)
		"sandbox":
			canvas.draw_circle(Vector2.ZERO, radius, Color(0.65, 0.58, 0.85, 0.055))
			canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.65, 0.58, 0.85, 0.35), 1.5, true)
			canvas.draw_rect(Rect2(-22, -22, 44, 44), DARK)
			canvas.draw_rect(Rect2(-22, -22, 44, 44), Color("b7abd2"), false, 3)
			canvas.draw_rect(Rect2(-10, -10, 20, 20), Color("b7abd2"), false, 2)
		_:
			canvas.draw_circle(Vector2.ZERO, 22, DARK)
			canvas.draw_arc(Vector2.ZERO, 22, 0, TAU, 40, TEAL, 3, true)
			canvas.draw_line(Vector2.ZERO, Vector2.from_angle(angle) * (29 - recoil * 5), TEAL, 9, true)
			canvas.draw_circle(Vector2.ZERO, 8, Color("e4cf91"))
	if recoil > 0.4:
		canvas.draw_circle(Vector2.from_angle(angle) * 31, 4 * recoil, Color("f4dfb1"))

static func enemy(canvas: CanvasItem, kind: String, angle: float, color: Color) -> void:
	if kind == "basic":
		canvas.draw_circle(Vector2.ZERO, 13, color)
		canvas.draw_circle(Vector2.ZERO, 5, DARK)
		return
	var sides := 3 if kind == "fast" else (6 if kind == "boss" else 4)
	var points := polygon(sides, 23 if kind == "boss" else 17, angle if kind == "fast" else PI / 4)
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, Color("e9e5dc"), 2, true)
	if kind != "fast":
		canvas.draw_rect(Rect2(-6, -6, 12, 12), DARK)

static func fragments(parent: Node, at: Vector2, color: Color) -> void:
	var burst := preload("res://src/gameplay/preview/enemy_burst.gd").new()
	burst.position = at
	burst.tint = color
	parent.add_child(burst)
