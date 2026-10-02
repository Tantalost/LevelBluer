extends Node2D
const Glyphs = preload("res://src/gameplay/preview/unit_glyphs.gd")
const Terrain = preload("res://src/gameplay/preview/preview_terrain.gd")
const CELL := 64
const GRID := Vector2i(13, 7)
const WAYPOINTS := [Vector2i(0, 1), Vector2i(9, 1), Vector2i(9, 3), Vector2i(3, 3), Vector2i(3, 5), Vector2i(12, 5)]
var path_cells: Array[Vector2i] = []
var waypoints: Array[Vector2i] = []
var routes: Array[Dictionary] = []
var campus: bool = false
var selected := Vector2i(-1, -1)
var ghost := ""
var range_radius := 100.0
var show_range := false
var health := 5
var route_offset := 0.0
var home_destroyed := false

func _ready() -> void:
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	terrain.path_cells = path_cells.duplicate()
	add_child(terrain)

func _process(delta: float) -> void:
	route_offset = fposmod(route_offset + delta * 0.7, 3.0)
	queue_redraw()

func play_home_destruction() -> void:
	if home_destroyed:
		return
	home_destroyed = true
	# Feed the existing collapse animator a runtime vector version of this server.
	# No downloaded sprites, generated image files, or production artwork changes.
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-32 -32 64 64"><path d="M-25-25H25V25H-25Z" fill="#823d4c" stroke="#e58d8e" stroke-width="2"/><path d="M-19-19H19V19H-19Z" fill="#a64c60"/><g fill="#e58d8e"><path d="M-13-14H13V-7H-13ZM-13-3H13V4H-13ZM-13 8H13V15H-13Z"/></g><path d="M8-24-2-3 8 3-4 24" fill="none" stroke="#392129" stroke-width="3"/></svg>'
	if campus:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-32 -32 64 64"><path d="M-24-23H24V12H-24Z" fill="#0A1730" stroke="#FF5C5C" stroke-width="3"/><path d="M-17-16H17V4H-17Z" fill="#153B37"/><path d="M-30 18H30" stroke="#FF5C5C" stroke-width="6"/><path d="M8-20-2-3 8 3" fill="none" stroke="#FF5C5C" stroke-width="3"/></svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) == OK:
		var effect := preload("res://src/gameplay/base_destruction.gd").new()
		effect.name = "BaseDestruction"
		effect.position = center(waypoints.back())
		effect.configure(ImageTexture.create_from_image(image), Vector2(64, 64))
		add_child(effect)
	queue_redraw()

func _init() -> void:
	var defaults: Array[Vector2i] = []
	defaults.assign(WAYPOINTS)
	configure_route(defaults)

## Reject malformed routes atomically, before replacing the terrain or enemy path.
func configure_route(points: Array[Vector2i]) -> bool:
	return configure_routes([points])

## All entrances share one destination; validate everything before mutating.
func configure_routes(entries: Array) -> bool:
	if entries.is_empty() or entries.size() > 2:
		return false
	var next_routes: Array[Dictionary] = []
	var all_cells: Array[Vector2i] = []
	var entrances: Array[Vector2i] = []
	var destination: Vector2i = Vector2i(-1, -1)
	for entry: Variant in entries:
		if not entry is Array:
			return false
		var points: Array[Vector2i] = []
		for value: Variant in entry:
			if not value is Vector2i:
				return false
			points.append(value)
		var cells: Array[Vector2i] = _route_cells(points)
		if cells.is_empty() or entrances.has(points[0]):
			return false
		if destination != Vector2i(-1, -1) and points.back() != destination:
			return false
		destination = points.back()
		entrances.append(points[0])
		next_routes.append({"points": points, "cells": cells})
		for cell: Vector2i in cells:
			if not all_cells.has(cell):
				all_cells.append(cell)
	# A route may merge into another, but may not run through its entrance.
	for route: Dictionary in next_routes:
		for entrance: Vector2i in entrances:
			if entrance != route.points[0] and entrance in route.cells:
				return false
	routes = next_routes
	waypoints.assign(routes[0].points)
	path_cells = all_cells
	var terrain: Node2D = get_node_or_null("Terrain") as Node2D
	if terrain != null:
		terrain.set("path_cells", path_cells.duplicate())
		terrain.queue_redraw()
	queue_redraw()
	return true

func _route_cells(points: Array[Vector2i]) -> Array[Vector2i]:
	if points.size() < 2:
		return []
	for point: Vector2i in points:
		if point.x < 0 or point.y < 0 or point.x >= GRID.x or point.y >= GRID.y:
			return []
	var cells: Array[Vector2i] = []
	for i: int in range(points.size() - 1):
		var cell: Vector2i = points[i]
		var end: Vector2i = points[i + 1]
		if cell == end or (cell.x != end.x and cell.y != end.y):
			return []
		var direction: Vector2i = Vector2i(signi(end.x - cell.x), signi(end.y - cell.y))
		while cell != end:
			if cells.has(cell):
				return []
			cells.append(cell)
			cell += direction
	if cells.has(points.back()):
		return []
	cells.append(points.back())
	return cells

func set_campus_style(enabled: bool) -> void:
	campus = enabled
	var terrain: Node2D = get_node_or_null("Terrain") as Node2D
	if terrain != null:
		terrain.set("campus", enabled)
		terrain.queue_redraw()
	queue_redraw()

static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5

func curve(route_index: int = 0) -> Curve2D:
	var result: Curve2D = Curve2D.new()
	for cell: Vector2i in routes[route_index].points:
		result.add_point(center(cell))
	return result

func cell_reason(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID.x or cell.y >= GRID.y:
		return "Choose a tile inside the battlefield."
	for route: Dictionary in routes:
		if cell == route.points[0]:
			return "Enemy entry: keep this terminal clear."
	if cell == waypoints.back():
		return "Home base: towers cannot occupy the server."
	if path_cells.has(cell):
		return "Enemy route: choose a floor tile beside the path."
	return ""

func _draw() -> void:
	for route: Dictionary in routes:
		_draw_route_arrows(route.cells)
	_draw_selection()
	_draw_endpoints()

func _draw_route_arrows(cells: Array[Vector2i]) -> void:
	for i: int in range(0, cells.size() - 1, 3):
		var travel: float = float(i) + route_offset
		if travel < 0.65 or travel > cells.size() - 1.65:
			continue
		var segment: int = int(travel)
		var at: Vector2 = center(cells[segment]).lerp(center(cells[segment + 1]), fmod(travel, 1.0))
		var direction: Vector2 = Vector2(cells[segment + 1] - cells[segment])
		var normal: Vector2 = direction.orthogonal()
		draw_polyline(PackedVector2Array([at - direction * 4 + normal * 4, at + direction * 2, at - direction * 4 - normal * 4]), Color("7a9a9c"), 2, true)

func _draw_selection() -> void:
	if selected.x >= 0:
		var at: Vector2 = center(selected)
		draw_rect(Rect2(Vector2(selected) * CELL + Vector2(2, 2), Vector2(60, 60)), Color("85d9c3"), false, 3)
		if show_range or not ghost.is_empty():
			draw_circle(at, range_radius, Color(0.52, 0.85, 0.76, 0.08))
			draw_arc(at, range_radius, 0, TAU, 64, Color(0.52, 0.85, 0.76, 0.5), 1.5, true)
		if not ghost.is_empty():
			draw_set_transform(at)
			Glyphs.tower(self, ghost, -PI / 2, 0, range_radius)
			draw_set_transform(Vector2.ZERO)

func _draw_endpoints() -> void:
	for index: int in routes.size():
		_draw_entrance(center(routes[index].points[0]), index)
	if home_destroyed:
		return
	var at: Vector2 = center(waypoints.back())
	var tint: Color = Color("85d9c3") if health > 3 else (Color("e5c88a") if health > 1 else Color("e58d8e"))
	if campus:
		draw_rect(Rect2(at - Vector2(24, 23), Vector2(48, 35)), Color("0A1730"))
		draw_rect(Rect2(at - Vector2(24, 23), Vector2(48, 35)), tint, false, 3)
		draw_rect(Rect2(at - Vector2(17, 16), Vector2(34, 20)), Color("153B37"))
		draw_line(at + Vector2(-30, 18), at + Vector2(30, 18), tint, 6)
		return
	_draw_server(at, tint)

func _draw_entrance(at: Vector2, index: int) -> void:
	draw_rect(Rect2(at - Vector2(22, 18), Vector2(44, 31)), Color("201c25"))
	draw_rect(Rect2(at - Vector2(22, 18), Vector2(44, 31)), Color("e58d8e"), false, 3)
	draw_polyline(PackedVector2Array([at + Vector2(2, -17), at + Vector2(-5, -3), at + Vector2(6, 0), at + Vector2(-2, 12)]), Color("e58d8e"), 3)
	draw_line(at + Vector2(-17, 20), at + Vector2(17, 20), Color("e58d8e"), 4)
	if routes.size() > 1:
		draw_string(ThemeDB.fallback_font, at + Vector2(-4, -28), "A" if index == 0 else "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("F3ECD6"))

func _draw_server(at: Vector2, tint: Color) -> void:
	draw_set_transform(at)
	Glyphs.bevel(self, PackedVector2Array([Vector2(-25,-25),Vector2(25,-25),Vector2(25,25),Vector2(-25,25)]), tint.darkened(0.35))
	draw_set_transform(Vector2.ZERO)
	for i: int in 3:
		draw_rect(Rect2(at + Vector2(-13, -14 + i * 11), Vector2(26, 7)), tint)
		draw_rect(Rect2(at + Vector2(7, -12 + i * 11), Vector2(3, 3)), Color("183c3b"))
	if health <= 3:
		draw_polyline(PackedVector2Array([at + Vector2(8, -20), at + Vector2(-2, -3), at + Vector2(8, 3), at + Vector2(-4, 20)]), Color("ed9b91"), 2)
