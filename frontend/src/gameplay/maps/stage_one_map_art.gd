class_name StageOneMapArt
extends Node2D
## Authored presentation for Module 1, Stage 1. The ASCII layout remains the
## source of truth; this node only turns those cells into an industrial deck.

const TILE: float = 32.0
const COLS: int = 32
const ROWS: int = 13
const MAP_SIZE := Vector2(COLS * TILE, ROWS * TILE)
const SCREEN_RECT := Rect2(Vector2(-128.0, -152.0), Vector2(1280.0, 720.0))

const VOID := Color("071019")
const WALL_DARK := Color("101922")
const WALL_MID := Color("1b2731")
const WALL_LIT := Color("33434e")
const DECK_A := Color("34404a")
const DECK_B := Color("3b4852")
const DECK_EDGE := Color("64727b")
const DECK_SHADOW := Color("202a33")
const ROUTE_A := Color("202b36")
const ROUTE_B := Color("263440")
const ROUTE_EDGE := Color("8d9aa2")
const ROUTE_DASH := Color("cad3d6")
const CYAN := Color("32d9ff")
const CYAN_DIM := Color("14647a")
const RED := Color("ff4053")
const RED_DIM := Color("7a1e2d")
const AMBER := Color("e89b36")
const LIGHT := Color("dce7e7")
const PANEL_LIT := Color("9ca6a8")
const PANEL_FACE := Color("313b43")
const TILE_STYLE := preload("res://src/gameplay/maps/industrial_tile_style.gd")

@export var map_id: String = "map_basic"

var _layout: PackedStringArray = PackedStringArray()
var _path_cells: Dictionary = {}
var _start_cell := Vector2i.ZERO
var _end_cell := Vector2i(COLS - 1, ROWS - 3)


func configure(layout: PackedStringArray) -> void:
	_layout = layout
	_path_cells.clear()
	for y in _layout.size():
		var row: String = _layout[y]
		for x in row.length():
			var marker: String = row.substr(x, 1)
			if marker == "." or marker == "S" or marker == "E":
				_path_cells[Vector2i(x, y)] = true
			if marker == "S":
				_start_cell = Vector2i(x, y)
			elif marker == "E":
				_end_cell = Vector2i(x, y)
	queue_redraw()


func _ready() -> void:
	z_index = -1
	# The Stage 1 scene owns this renderer explicitly. Self-configuration keeps
	# the art present even when the scene is run directly or a tool script has
	# not injected the ASCII layout yet.
	if _layout.is_empty():
		configure(MapDesigns.get_layout(map_id))
	queue_redraw()


func _draw() -> void:
	if _layout.is_empty():
		return
	_draw_backdrop()
	_draw_machine_banks()
	_draw_deck_shadow()
	_draw_cells()
	_draw_architecture_shadows()
	_draw_raised_platforms()
	_draw_route_details()
	_draw_deck_frame()
	# Entry and base sprites are reusable runtime nodes, not baked map pixels.
	_draw_light_wash()


func _draw_backdrop() -> void:
	draw_rect(SCREEN_RECT, VOID, true)
	# Layered wall bands keep the playable deck framed like a physical facility.
	draw_rect(Rect2(SCREEN_RECT.position, Vector2(SCREEN_RECT.size.x, 138.0)), WALL_DARK, true)
	draw_rect(Rect2(Vector2(SCREEN_RECT.position.x, MAP_SIZE.y + 12.0), Vector2(SCREEN_RECT.size.x, 140.0)), WALL_DARK, true)
	draw_rect(Rect2(Vector2(-128.0, -22.0), Vector2(128.0, MAP_SIZE.y + 44.0)), Color("0d171f"), true)
	draw_rect(Rect2(Vector2(MAP_SIZE.x, -22.0), Vector2(128.0, MAP_SIZE.y + 44.0)), Color("0d171f"), true)
	# Warm/cool light pools echo the cinematic reference without obscuring play.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-128.0, -152.0), Vector2(282.0, -152.0),
		Vector2(430.0, MAP_SIZE.y + 152.0), Vector2(-128.0, MAP_SIZE.y + 152.0),
	]), Color(AMBER, 0.035))
	draw_colored_polygon(PackedVector2Array([
		Vector2(540.0, -152.0), Vector2(1110.0, -152.0),
		Vector2(950.0, MAP_SIZE.y + 152.0), Vector2(400.0, MAP_SIZE.y + 152.0),
	]), Color(CYAN, 0.025))


func _draw_machine_banks() -> void:
	# Top service cabinets.
	for i in 8:
		var x: float = -92.0 + float(i) * 154.0
		var body := Rect2(Vector2(x, -136.0), Vector2(132.0, 100.0))
		TILE_STYLE.draw_machine_block(self, body, WALL_MID, WALL_LIT, VOID, 9.0)
		draw_rect(Rect2(body.position + Vector2(8.0, 8.0), Vector2(body.size.x - 16.0, 12.0)), WALL_LIT, true)
		if i % 2 == 0:
			for vent in 5:
				var vx: float = body.position.x + 12.0 + float(vent) * 21.0
				draw_rect(Rect2(Vector2(vx, body.position.y + 36.0), Vector2(12.0, 42.0)), WALL_DARK, true)
		else:
			for slot in 4:
				var vy: float = body.position.y + 34.0 + float(slot) * 13.0
				draw_line(Vector2(body.position.x + 12.0, vy), Vector2(body.end.x - 12.0, vy), Color("53636d"), 3.0)
		draw_circle(body.position + Vector2(body.size.x - 14.0, 14.0), 3.0, CYAN if i % 3 == 0 else AMBER)
	# Bottom server blocks and cable trays.
	for i in 7:
		var x: float = -98.0 + float(i) * 180.0
		var body := Rect2(Vector2(x, MAP_SIZE.y + 34.0), Vector2(150.0, 96.0))
		TILE_STYLE.draw_machine_block(self, body, Color("18232c"), WALL_LIT, VOID, 10.0)
		draw_rect(Rect2(body.position + Vector2(10.0, 10.0), Vector2(body.size.x - 20.0, 18.0)), WALL_LIT, true)
		if i == 0 or i == 5:
			_draw_fan(body.position + Vector2(48.0, 60.0), 24.0)
			_draw_fan(body.position + Vector2(103.0, 60.0), 24.0)
		else:
			for rack in 3:
				var ry: float = body.position.y + 40.0 + float(rack) * 14.0
				draw_line(Vector2(body.position.x + 12.0, ry), Vector2(body.end.x - 12.0, ry), Color("52616a"), 2.0)
				draw_circle(Vector2(body.end.x - 18.0, ry), 2.5, CYAN_DIM)
	# Side conduits give the route a believable entry and exit through the wall.
	for i in 4:
		var y: float = 28.0 + float(i) * 102.0
		draw_line(Vector2(-112.0, y), Vector2(-18.0, y), WALL_LIT, 8.0)
		draw_line(Vector2(MAP_SIZE.x + 18.0, y), Vector2(MAP_SIZE.x + 112.0, y), WALL_LIT, 8.0)


func _draw_deck_shadow() -> void:
	draw_rect(Rect2(Vector2(18.0, 24.0), MAP_SIZE), Color(VOID, 0.72), true)
	# The whole playable area is a thick suspended deck, not a painted plane.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, MAP_SIZE.y), Vector2(MAP_SIZE.x + 4.0, MAP_SIZE.y),
		Vector2(MAP_SIZE.x + 16.0, MAP_SIZE.y + 16.0), Vector2(8.0, MAP_SIZE.y + 16.0),
	]), Color("111a21"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(MAP_SIZE.x, -4.0), Vector2(MAP_SIZE.x + 4.0, 0.0),
		Vector2(MAP_SIZE.x + 16.0, MAP_SIZE.y + 16.0), Vector2(MAP_SIZE.x + 4.0, MAP_SIZE.y),
	]), Color("0b131a"))
	draw_rect(Rect2(Vector2(-4.0, -4.0), MAP_SIZE + Vector2(8.0, 8.0)), WALL_LIT, true)
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), DECK_SHADOW, true)


func _draw_cells() -> void:
	for y in _layout.size():
		var row: String = _layout[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(float(x) * TILE, float(y) * TILE), Vector2(TILE, TILE))
			if _is_path(cell):
				_draw_route_cell(rect, cell)
			else:
				_draw_deck_cell(rect, cell)


func _draw_deck_cell(rect: Rect2, cell: Vector2i) -> void:
	var fill: Color = DECK_A if (cell.x + cell.y * 3) % 5 < 3 else DECK_B
	draw_rect(rect, fill, true)
	# Bevel and recessed seam: small enough to preserve one readable grid per cell.
	draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0), Color(DECK_EDGE, 0.58), 1.0)
	draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.position.x + 1.0, rect.end.y - 1.0), Color(DECK_EDGE, 0.42), 1.0)
	draw_line(Vector2(rect.position.x + 1.0, rect.end.y - 1.0), rect.end - Vector2(1.0, 1.0), Color(VOID, 0.62), 1.0)
	draw_line(Vector2(rect.end.x - 1.0, rect.position.y + 1.0), rect.end - Vector2(1.0, 1.0), Color(VOID, 0.5), 1.0)
	if (cell.x * 7 + cell.y * 11) % 13 == 0:
		draw_circle(rect.position + Vector2(6.0, 6.0), 1.4, Color(LIGHT, 0.38))
		draw_circle(rect.end - Vector2(6.0, 6.0), 1.4, Color(VOID, 0.7))
	# Stronger three-cell seams imply larger manufactured slabs and mirror a
	# tower's 3x3 footprint without changing where a tower may be placed.
	if cell.x % 3 == 0:
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(DECK_EDGE, 0.45), 1.5)
	if cell.y % 3 == 0:
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(DECK_EDGE, 0.45), 1.5)


func _draw_route_cell(rect: Rect2, cell: Vector2i) -> void:
	var fill: Color = ROUTE_A if (cell.x + cell.y) % 2 == 0 else ROUTE_B
	TILE_STYLE.draw_recessed_tile(self, rect, fill, ROUTE_EDGE, Color("101820"))
	# Bright lips only where the route meets the buildable deck.
	if not _is_path(cell + Vector2i.UP):
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), ROUTE_EDGE, 2.0)
		draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(TILE - 4.0, 4.0)), Color(VOID, 0.48), true)
	if not _is_path(cell + Vector2i.DOWN):
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(ROUTE_EDGE, 0.62), 2.0)
	if not _is_path(cell + Vector2i.LEFT):
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), ROUTE_EDGE, 2.0)
		draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(4.0, TILE - 4.0)), Color(VOID, 0.4), true)
	if not _is_path(cell + Vector2i.RIGHT):
		draw_line(Vector2(rect.end.x, rect.position.y), rect.end, Color(ROUTE_EDGE, 0.62), 2.0)


func _draw_raised_platforms() -> void:
	# Authored from a small repeatable vocabulary: 2x2, 3x2 and 4x2 slabs.
	# They remain buildable—the tower sits visually on the top face.
	var platforms: Array[Rect2] = [
		Rect2(Vector2(4.0, 3.0) * TILE, Vector2(3.0, 2.0) * TILE),
		Rect2(Vector2(13.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(26.0, 2.0) * TILE, Vector2(3.0, 2.0) * TILE),
		Rect2(Vector2(3.0, 8.0) * TILE, Vector2(4.0, 2.0) * TILE),
		Rect2(Vector2(12.0, 9.0) * TILE, Vector2(3.0, 2.0) * TILE),
		Rect2(Vector2(25.0, 11.0) * TILE, Vector2(3.0, 2.0) * TILE),
	]
	for i in platforms.size():
		var top_rect: Rect2 = platforms[i].grow(-4.0)
		var top_color: Color = PANEL_LIT if i % 3 != 1 else Color("6f7b80")
		TILE_STYLE.draw_raised_panel(self, top_rect, top_color, LIGHT, PANEL_FACE, 8.0)
		_draw_platform_seams(top_rect, i)
	# Two inset service grates demonstrate a reusable surface-detail tile.
	_draw_service_grate(Rect2(Vector2(8.0, 1.0) * TILE + Vector2(7.0, 7.0), Vector2(50.0, 34.0)))
	_draw_service_grate(Rect2(Vector2(18.0, 11.0) * TILE + Vector2(7.0, 4.0), Vector2(50.0, 34.0)))


func _draw_platform_seams(rect: Rect2, variant: int) -> void:
	var divisions: int = 2 if variant % 2 == 0 else 3
	for i in range(1, divisions):
		var x: float = lerpf(rect.position.x, rect.end.x, float(i) / float(divisions))
		draw_line(Vector2(x, rect.position.y + 3.0), Vector2(x, rect.end.y - 3.0), Color(PANEL_FACE, 0.58), 1.0)


func _draw_service_grate(rect: Rect2) -> void:
	draw_rect(rect, Color("111920"), true)
	draw_rect(rect, Color("65727a"), false, 2.0)
	for i in 6:
		var x: float = rect.position.x + 6.0 + float(i) * 7.0
		draw_line(Vector2(x, rect.position.y + 4.0), Vector2(x, rect.end.y - 4.0), Color("46545d"), 3.0)


func _draw_route_details() -> void:
	for stored: Variant in _path_cells.keys():
		var cell: Vector2i = stored as Vector2i
		if cell == _start_cell or cell == _end_cell:
			continue
		var center := Vector2((float(cell.x) + 0.5) * TILE, (float(cell.y) + 0.5) * TILE)
		var horizontal: bool = _is_path(cell + Vector2i.LEFT) or _is_path(cell + Vector2i.RIGHT)
		var vertical: bool = _is_path(cell + Vector2i.UP) or _is_path(cell + Vector2i.DOWN)
		if horizontal and not vertical and cell.x % 3 == 1:
			draw_rect(Rect2(center - Vector2(7.0, 1.0), Vector2(14.0, 2.0)), Color(ROUTE_DASH, 0.52), true)
		elif vertical and not horizontal and cell.y % 3 == 1:
			draw_rect(Rect2(center - Vector2(1.0, 7.0), Vector2(2.0, 14.0)), Color(ROUTE_DASH, 0.52), true)
		elif horizontal and vertical:
			# Directional turn marker follows the data instead of assuming a cell.
			draw_polyline(PackedVector2Array([
				center + Vector2(-9.0, -2.0), center + Vector2(4.0, -2.0),
				center + Vector2(4.0, 10.0), center + Vector2(-1.0, 5.0),
			]), Color(CYAN, 0.72), 2.0)


func _draw_deck_frame() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("a7b1b7"), false, 3.0)
	# Alternating amber/black hazard strip at the outer deck boundary.
	for x in range(0, COLS, 2):
		var px: float = float(x) * TILE
		draw_rect(Rect2(Vector2(px, -6.0), Vector2(TILE, 4.0)), AMBER if x % 4 == 0 else WALL_DARK, true)
		draw_rect(Rect2(Vector2(px, MAP_SIZE.y + 2.0), Vector2(TILE, 4.0)), AMBER if x % 4 == 0 else WALL_DARK, true)
	# Rails, posts and the front fascia establish scale and sell the suspended deck.
	draw_line(Vector2(-3.0, -14.0), Vector2(MAP_SIZE.x + 3.0, -14.0), Color("76848c"), 3.0)
	draw_line(Vector2(-3.0, -7.0), Vector2(MAP_SIZE.x + 3.0, -7.0), Color("29343c"), 2.0)
	for x in range(0, COLS + 1, 3):
		var px: float = float(x) * TILE
		draw_line(Vector2(px, -17.0), Vector2(px, 0.0), Color("78858c"), 3.0)
	for x in range(0, COLS + 1, 2):
		var px: float = float(x) * TILE + 8.0
		draw_rect(Rect2(Vector2(px, MAP_SIZE.y + 7.0), Vector2(4.0, 9.0)), Color("53616a"), true)


func _draw_architecture_shadows() -> void:
	# Long projected shadows are the strongest 2.5D cue in the reference. Their
	# top-left light direction is shared by every future tile family.
	var casters: Array[Rect2] = [
		Rect2(34.0, -8.0, 82.0, 8.0),
		Rect2(284.0, -8.0, 76.0, 8.0),
		Rect2(548.0, -8.0, 88.0, 8.0),
		Rect2(850.0, -8.0, 72.0, 8.0),
	]
	for caster: Rect2 in casters:
		var reach := Vector2(74.0, 206.0)
		draw_colored_polygon(PackedVector2Array([
			caster.position,
			Vector2(caster.end.x, caster.position.y),
			Vector2(caster.end.x, caster.position.y) + reach,
			caster.position + reach,
		]), Color(VOID, 0.13))
	# Scaffolding bars create recognizable angular shadows rather than soft bands.
	for x in [72.0, 608.0, 936.0]:
		draw_line(Vector2(x, 0.0), Vector2(x + 82.0, 174.0), Color(VOID, 0.2), 5.0)
		draw_line(Vector2(x + 28.0, 0.0), Vector2(x + 110.0, 174.0), Color(VOID, 0.14), 3.0)
		draw_line(Vector2(x + 23.0, 44.0), Vector2(x + 64.0, 44.0), Color(VOID, 0.16), 4.0)


func _draw_spawn_gate() -> void:
	var center := _cell_center(_start_cell)
	var frame := Rect2(center - Vector2(22.0, 22.0), Vector2(44.0, 44.0))
	TILE_STYLE.draw_wire_cube(self, frame, Vector2(-11.0, -16.0), CYAN, 0.09)
	for i in 3:
		var x: float = center.x - 14.0 + float(i) * 9.0
		draw_polyline(PackedVector2Array([
			Vector2(x, center.y - 7.0), Vector2(x + 7.0, center.y), Vector2(x, center.y + 7.0),
		]), CYAN, 2.0)
	# Project the gateway into the left wall so the spawn reads as an entrance.
	draw_line(Vector2(-34.0, center.y - 25.0), Vector2(0.0, center.y - 25.0), CYAN_DIM, 4.0)
	draw_line(Vector2(-34.0, center.y + 25.0), Vector2(0.0, center.y + 25.0), CYAN_DIM, 4.0)


func _draw_core_gate() -> void:
	var center := _cell_center(_end_cell)
	var frame := Rect2(center - Vector2(22.0, 22.0), Vector2(44.0, 44.0))
	TILE_STYLE.draw_wire_cube(self, frame, Vector2(-11.0, -16.0), RED, 0.09)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -12.0), center + Vector2(12.0, 0.0),
		center + Vector2(0.0, 12.0), center + Vector2(-12.0, 0.0),
	]), Color(RED, 0.26))
	draw_circle(center, 6.0, RED)
	draw_circle(center, 2.5, LIGHT)
	draw_line(Vector2(MAP_SIZE.x, center.y - 25.0), Vector2(MAP_SIZE.x + 35.0, center.y - 25.0), RED_DIM, 4.0)
	draw_line(Vector2(MAP_SIZE.x, center.y + 25.0), Vector2(MAP_SIZE.x + 35.0, center.y + 25.0), RED_DIM, 4.0)


func _draw_light_wash() -> void:
	# Two restrained translucent polygons create depth while leaving every tile readable.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(280.0, 0.0),
		Vector2(395.0, MAP_SIZE.y), Vector2(128.0, MAP_SIZE.y),
	]), Color(LIGHT, 0.035))
	draw_colored_polygon(PackedVector2Array([
		Vector2(620.0, 0.0), Vector2(820.0, 0.0),
		Vector2(730.0, MAP_SIZE.y), Vector2(530.0, MAP_SIZE.y),
	]), Color(CYAN, 0.025))


func _draw_fan(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, WALL_DARK)
	draw_circle(center, radius - 3.0, Color("2b3943"))
	for i in 6:
		var angle: float = TAU * float(i) / 6.0
		var spoke_end: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 5.0)
		draw_line(center, spoke_end, Color("71808a"), 2.0)
	draw_circle(center, 6.0, Color("101820"))
	draw_circle(center, radius, Color("71808a"), false, 2.0)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * TILE, (float(cell.y) + 0.5) * TILE)


func _is_path(cell: Vector2i) -> bool:
	return _path_cells.has(cell)
