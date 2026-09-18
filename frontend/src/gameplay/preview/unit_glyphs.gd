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
			bevel(canvas, points, Color("388cd2"))
			canvas.draw_circle(Vector2.ZERO, 6, Color("96dbf2"))
			canvas.draw_arc(Vector2.ZERO, 14, angle - 0.8, angle + 0.8, 16, Color("b0eaf5"), 3, true)
			canvas.draw_line(Vector2.ZERO, Vector2.from_angle(angle) * (21 - recoil * 3), Color("b0eaf5"), 4, true)
		"sandbox":
			canvas.draw_circle(Vector2.ZERO, radius, Color(0.65, 0.58, 0.85, 0.055))
			canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.65, 0.58, 0.85, 0.35), 1.5, true)
			bevel(canvas, PackedVector2Array([Vector2(-23,-23),Vector2(23,-23),Vector2(23,23),Vector2(-23,23)]), Color("8c65c7"))
			canvas.draw_rect(Rect2(-11,-11,22,22), Color("d1b8ef"), false, 3)
			canvas.draw_rect(Rect2(-5,-5,10,10), Color("c1a4e8"))
			for p in [Vector2(-14,-14),Vector2(14,-14),Vector2(14,14),Vector2(-14,14)]:
				canvas.draw_circle(p, 2, Color("eadcfa"))
		_:
			bevel(canvas, polygon(32, 24, -PI / 2), Color("139e94"))
			canvas.draw_circle(Vector2.ZERO, 16, Color("15958c"))
			canvas.draw_line(Vector2.ZERO, Vector2.from_angle(angle) * (29 - recoil * 5), Color("8ae0ca"), 8, true)
			canvas.draw_circle(Vector2.ZERO, 10, Color("73d2ba"))
			canvas.draw_arc(Vector2.ZERO, 10, PI, TAU, 16, Color("a0ead2"), 1.5, true)
	if recoil > 0.4:
		canvas.draw_circle(Vector2.from_angle(angle) * 31, 4 * recoil, Color("f4dfb1"))

static func bevel(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	# Shared raised rim, inset face and directional facets across every unit.
	canvas.draw_colored_polygon(points, color.darkened(0.2))
	var inset := PackedVector2Array()
	for p in points:
		inset.append(p * 0.78)
	canvas.draw_colored_polygon(inset, color)
	for i in points.size():
		var next := (i + 1) % points.size()
		var lit := (points[i] + points[next]).dot(Vector2(-0.5, -1)) > 0
		canvas.draw_colored_polygon(PackedVector2Array([points[i],points[next],inset[next],inset[i]]), color.lightened(0.18) if lit else color.darkened(0.16))
	var edge := points.duplicate()
	edge.append(edge[0])
	canvas.draw_polyline(edge, color.lightened(0.12), 1, true)

static func enemy(canvas: CanvasItem, kind: String, angle: float, color: Color) -> void:
	if kind == "basic":
		bevel(canvas, polygon(20, 13), color)
		canvas.draw_circle(Vector2.ZERO, 5, color.lightened(0.4))
		return
	var sides := 3 if kind == "fast" else (6 if kind == "boss" else 4)
	var points := polygon(sides, 23 if kind == "boss" else 17, angle if kind == "fast" else PI / 4)
	bevel(canvas, points, color)
	if kind != "fast":
		canvas.draw_rect(Rect2(-6, -6, 12, 12), DARK)

static func fragments(parent: Node, at: Vector2, color: Color, kind: String = "basic") -> void:
	# Match-local caps bound overdraw/memory during clustered kills on mobile.
	_limit_effects(parent, "preview_death_burst", 16)
	_limit_effects(parent, "preview_death_stain", 32)
	var stain := preload("res://src/gameplay/preview/enemy_stain.gd").new()
	stain.position = at
	stain.tint = color
	stain.kind = kind
	parent.add_child(stain)
	var burst := preload("res://src/gameplay/preview/enemy_burst.gd").new()
	burst.position = at
	burst.tint = color
	burst.kind = kind
	parent.add_child(burst)

static func _limit_effects(parent: Node, tag: String, maximum: int) -> void:
	var effects: Array[Node] = []
	for child in parent.get_children():
		if child.has_meta(tag) and not child.is_queued_for_deletion():
			effects.append(child)
	while effects.size() >= maximum:
		var oldest: Node = effects.pop_front()
		oldest.hide()
		oldest.queue_free()
