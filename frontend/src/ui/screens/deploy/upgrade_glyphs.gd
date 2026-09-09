extends RefCounted
## Shared code-native insignias. No additional bitmap assets required.

static func paint(canvas: CanvasItem, center: Vector2, radius: float, kind: String, ink: Color) -> void:
	var points := PackedVector2Array()
	match kind:
		"stats":
			points = PackedVector2Array([Vector2(-0.65, 0.45), Vector2(-0.15, -0.05), Vector2(0.1, 0.15), Vector2(0.65, -0.55)])
		"capacity":
			for offset in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
				canvas.draw_rect(Rect2(center + offset * radius - Vector2.ONE * radius * 0.23, Vector2.ONE * radius * 0.46), ink, false, 2.0)
		"skill", "scanner":
			for factor in [0.35, 0.7, 1.0]:
				canvas.draw_arc(center, radius * factor, -PI * 0.85, PI * 0.15, 32, ink, 2.0, true)
			points = PackedVector2Array([Vector2(-0.65, 0.65), Vector2(0.55, -0.55)])
		"evolution":
			points = PackedVector2Array([Vector2(-0.65, 0.65), Vector2(0.55, -0.55), Vector2(-0.15, -0.55), Vector2(0.55, -0.55), Vector2(0.55, 0.15)])
			canvas.draw_line(center + Vector2(-0.65, 0.05) * radius, center + Vector2(0.05, -0.65) * radius, ink, 2.0, true)
		"lock":
			canvas.draw_arc(center + Vector2(0, -0.18) * radius, radius * 0.4, PI, TAU, 20, ink, 2.0, true)
			canvas.draw_rect(Rect2(center + Vector2(-0.6, -0.15) * radius, Vector2(1.2, 0.85) * radius), ink)
		"sandbox":
			points = PackedVector2Array([Vector2(0, -0.9), Vector2(0.8, -0.5), Vector2(0.7, 0.4), Vector2(0, 0.9), Vector2(-0.7, 0.4), Vector2(-0.8, -0.5), Vector2(0, -0.9)])
		_:
			canvas.draw_circle(center, radius * 0.55, ink, false, 2.0, true)
			for i in 4:
				var axis := Vector2.from_angle(i * PI * 0.5)
				canvas.draw_line(center + axis * radius * 0.75, center + axis * radius * 1.1, ink, 2.0, true)
	if points.size() > 1:
		for i in points.size():
			points[i] = center + points[i] * radius
		canvas.draw_polyline(points, ink, 2.5, true)
