class_name IndustrialTileStyle
extends RefCounted
## Reusable 2.5D primitives for the industrial map family. These four shapes
## are deliberately atlas-friendly: floor/recess, raised slab, machinery, gate.


static func draw_recessed_tile(
	canvas: CanvasItem,
	rect: Rect2,
	fill: Color,
	light_edge: Color,
	dark_edge: Color
) -> void:
	canvas.draw_rect(rect, dark_edge, true)
	var well: Rect2 = rect.grow(-2.0)
	canvas.draw_rect(well, fill, true)
	canvas.draw_line(well.position, Vector2(well.end.x, well.position.y), Color(dark_edge, 0.82), 2.0)
	canvas.draw_line(well.position, Vector2(well.position.x, well.end.y), Color(dark_edge, 0.64), 2.0)
	canvas.draw_line(Vector2(well.position.x, well.end.y), well.end, Color(light_edge, 0.38), 1.0)
	canvas.draw_line(Vector2(well.end.x, well.position.y), well.end, Color(light_edge, 0.3), 1.0)


static func draw_raised_panel(
	canvas: CanvasItem,
	top_rect: Rect2,
	top_color: Color,
	edge_light: Color,
	edge_dark: Color,
	depth: float = 8.0,
	shadow_offset: Vector2 = Vector2(8.0, 12.0)
) -> void:
	var shadow := PackedVector2Array([
		top_rect.position + shadow_offset,
		Vector2(top_rect.end.x, top_rect.position.y) + shadow_offset,
		top_rect.end + shadow_offset,
		Vector2(top_rect.position.x, top_rect.end.y) + shadow_offset,
	])
	canvas.draw_colored_polygon(shadow, Color(0.01, 0.025, 0.04, 0.48))
	# Front and right faces create the readable height at the chosen camera angle.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(top_rect.position.x, top_rect.end.y), top_rect.end,
		top_rect.end + Vector2(0.0, depth),
		Vector2(top_rect.position.x, top_rect.end.y + depth),
	]), edge_dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(top_rect.end.x, top_rect.position.y), top_rect.end,
		top_rect.end + Vector2(0.0, depth),
		Vector2(top_rect.end.x + 3.0, top_rect.position.y + 3.0),
	]), edge_dark.darkened(0.16))
	canvas.draw_rect(top_rect, top_color, true)
	canvas.draw_line(top_rect.position, Vector2(top_rect.end.x, top_rect.position.y), edge_light, 2.0)
	canvas.draw_line(top_rect.position, Vector2(top_rect.position.x, top_rect.end.y), Color(edge_light, 0.7), 2.0)
	canvas.draw_line(Vector2(top_rect.position.x, top_rect.end.y), top_rect.end, Color(edge_dark, 0.86), 2.0)
	canvas.draw_line(Vector2(top_rect.end.x, top_rect.position.y), top_rect.end, edge_dark, 2.0)
	for corner in [
		top_rect.position + Vector2(7.0, 7.0),
		Vector2(top_rect.end.x - 7.0, top_rect.position.y + 7.0),
		top_rect.end - Vector2(7.0, 7.0),
		Vector2(top_rect.position.x + 7.0, top_rect.end.y - 7.0),
	]:
		canvas.draw_circle(corner, 1.8, Color(edge_dark, 0.72))


static func draw_machine_block(
	canvas: CanvasItem,
	top_rect: Rect2,
	top_color: Color,
	edge_light: Color,
	edge_dark: Color,
	depth: float = 10.0
) -> void:
	draw_raised_panel(canvas, top_rect, top_color, edge_light, edge_dark, depth, Vector2(10.0, 15.0))
	# A second inset top plane makes the equipment read as a manufactured casing.
	var inset := top_rect.grow(-6.0)
	canvas.draw_rect(inset, top_color.lightened(0.055), true)
	canvas.draw_line(inset.position, Vector2(inset.end.x, inset.position.y), Color(edge_light, 0.64), 1.0)
	canvas.draw_line(Vector2(inset.position.x, inset.end.y), inset.end, Color(edge_dark, 0.72), 2.0)


static func draw_wire_cube(
	canvas: CanvasItem,
	base_rect: Rect2,
	rise: Vector2,
	color: Color,
	fill_alpha: float = 0.08
) -> void:
	var top_rect := Rect2(base_rect.position + rise, base_rect.size)
	canvas.draw_rect(base_rect, Color(color, fill_alpha), true)
	canvas.draw_rect(base_rect, color, false, 2.5)
	canvas.draw_rect(top_rect, Color(color, fill_alpha * 0.6), true)
	canvas.draw_rect(top_rect, color, false, 2.5)
	var base_corners := PackedVector2Array([
		base_rect.position,
		Vector2(base_rect.end.x, base_rect.position.y),
		base_rect.end,
		Vector2(base_rect.position.x, base_rect.end.y),
	])
	for corner: Vector2 in base_corners:
		canvas.draw_line(corner, corner + rise, color, 2.5)
