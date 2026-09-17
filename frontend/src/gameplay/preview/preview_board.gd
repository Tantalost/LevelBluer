extends Node2D
const Glyphs = preload("res://src/gameplay/preview/unit_glyphs.gd")
const CELL := 64
const GRID := Vector2i(13, 7)
const WAYPOINTS := [Vector2i(0, 1), Vector2i(9, 1), Vector2i(9, 3), Vector2i(3, 3), Vector2i(3, 5), Vector2i(12, 5)]
var path_cells: Array[Vector2i] = []
var selected := Vector2i(-1, -1)
var ghost := ""
var range_radius := 100.0
var show_range := false
var health := 5
var route_offset := 0.0
var home_destroyed := false

func _process(delta: float) -> void:
	route_offset = fposmod(route_offset + delta * 0.7, 3.0)
	queue_redraw()

func play_home_destruction() -> void:
	if home_destroyed:
		return
	home_destroyed = true
	# Feed the existing collapse animator a runtime vector version of this server.
	# No downloaded sprites, generated image files, or production artwork changes.
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-32 -32 64 64"><path d="M-25-22H25L22 14 0 27-22 14Z" fill="#14252b" stroke="#e58d8e" stroke-width="2.5"/><g fill="none" stroke="#e58d8e" stroke-width="2"><path d="M-12-15H12V-8H-12ZM-12-5H12V2H-12ZM-12 5H12V12H-12Z"/><path d="M8-20-2-3 8 3-4 20"/></g></svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) == OK:
		var effect := preload("res://src/gameplay/base_destruction.gd").new()
		effect.name = "BaseDestruction"
		effect.position = center(WAYPOINTS.back())
		effect.configure(ImageTexture.create_from_image(image), Vector2(64, 64))
		add_child(effect)
	queue_redraw()

func _init() -> void:
	for i in WAYPOINTS.size() - 1:
		var cell: Vector2i = WAYPOINTS[i]
		var end: Vector2i = WAYPOINTS[i + 1]
		var direction := Vector2i(signi(end.x - cell.x), signi(end.y - cell.y))
		while cell != end:
			if not path_cells.has(cell):
				path_cells.append(cell)
			cell += direction
	path_cells.append(WAYPOINTS.back())

static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5

func curve() -> Curve2D:
	var result := Curve2D.new()
	for cell in WAYPOINTS:
		result.add_point(center(cell))
	return result

func cell_reason(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID.x or cell.y >= GRID.y:
		return "Choose a tile inside the battlefield."
	if cell == WAYPOINTS[0]:
		return "Enemy entry: keep this terminal clear."
	if cell == WAYPOINTS.back():
		return "Home base: towers cannot occupy the server."
	if path_cells.has(cell):
		return "Enemy route: choose a floor tile beside the path."
	return ""

func _draw() -> void:
	for y in GRID.y:
		for x in GRID.x:
			var cell := Vector2i(x, y)
			var path := path_cells.has(cell)
			var fill := Color("35484e") if path else Color("19262d")
			if not path and (x + y) % 2 == 0:
				fill = Color("1d2b32")
			draw_rect(Rect2(Vector2(cell) * CELL + Vector2(2, 2), Vector2(60, 60)), fill)
	for i in range(0, path_cells.size() - 1, 3):
		var travel := float(i) + route_offset
		if travel < 0.65 or travel > path_cells.size() - 1.65:
			continue
		var segment := int(travel)
		var at := center(path_cells[segment]).lerp(center(path_cells[segment + 1]), fmod(travel, 1.0))
		var direction := Vector2(path_cells[segment + 1] - path_cells[segment])
		var normal := direction.orthogonal()
		draw_polyline(PackedVector2Array([at - direction * 4 + normal * 4, at + direction * 2, at - direction * 4 - normal * 4]), Color("7a9a9c"), 2, true)
	if selected.x >= 0:
		var at := center(selected)
		draw_rect(Rect2(Vector2(selected) * CELL + Vector2(2, 2), Vector2(60, 60)), Color("85d9c3"), false, 3)
		if show_range or not ghost.is_empty():
			draw_circle(at, range_radius, Color(0.52, 0.85, 0.76, 0.08))
			draw_arc(at, range_radius, 0, TAU, 64, Color(0.52, 0.85, 0.76, 0.5), 1.5, true)
		if not ghost.is_empty():
			draw_set_transform(at)
			Glyphs.tower(self, ghost, -PI / 2, 0, range_radius)
			draw_set_transform(Vector2.ZERO)
	_draw_endpoints()

func _draw_endpoints() -> void:
	var at := center(WAYPOINTS[0])
	draw_rect(Rect2(at - Vector2(22, 18), Vector2(44, 31)), Color("201c25"))
	draw_rect(Rect2(at - Vector2(22, 18), Vector2(44, 31)), Color("e58d8e"), false, 3)
	draw_polyline(PackedVector2Array([at + Vector2(2, -17), at + Vector2(-5, -3), at + Vector2(6, 0), at + Vector2(-2, 12)]), Color("e58d8e"), 3)
	draw_line(at + Vector2(-17, 20), at + Vector2(17, 20), Color("e58d8e"), 4)
	if home_destroyed:
		return
	at = center(WAYPOINTS.back())
	var tint := Color("85d9c3") if health > 3 else (Color("e5c88a") if health > 1 else Color("e58d8e"))
	var shield := PackedVector2Array([at + Vector2(-25, -22), at + Vector2(25, -22), at + Vector2(22, 14), at + Vector2(0, 27), at + Vector2(-22, 14), at + Vector2(-25, -22)])
	draw_colored_polygon(shield, Color("14252b"))
	draw_polyline(shield, tint, 2.5, true)
	for i in 3:
		draw_rect(Rect2(at + Vector2(-12, -15 + i * 10), Vector2(24, 7)), tint, false, 2)
	if health <= 3:
		draw_polyline(PackedVector2Array([at + Vector2(8, -20), at + Vector2(-2, -3), at + Vector2(8, 3), at + Vector2(-4, 20)]), Color("ed9b91"), 2)
