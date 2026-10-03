extends Node2D
## Static, code-drawn preview tiles. Terrain commands are cached separately from
## the board's animated arrows, selections and unit effects.
const CELL := 64
const GRID := Vector2i(13, 7)
const FLOOR := Color("484e50")
const ROUTE := Color("23282b")
var path_cells: Array[Vector2i] = []
var campus: bool = false

func _ready() -> void:
	z_index = -2
	show_behind_parent = true

func _draw() -> void:
	for y in GRID.y:
		for x in GRID.x:
			var cell := Vector2i(x, y)
			if path_cells.has(cell):
				_draw_route(cell)
			else:
				_draw_platform(cell)
	if campus:
		# Scenery sits outside selectable cells, so decorations never imply blockers.
		for x: int in [1, 5, 9]:
			var at: Vector2 = Vector2(x * CELL, -26)
			draw_rect(Rect2(at, Vector2(94, 14)), Color("173058"))
			draw_rect(Rect2(at + Vector2(4, -8), Vector2(86, 12)), Color("153B37"))
			for book: int in 7:
				draw_rect(Rect2(at + Vector2(9 + book * 11, -15), Vector2(7, 17)), Color("4FE0D4") if book % 2 == 0 else Color("F3ECD6"))

func _draw_platform(cell: Vector2i) -> void:
	var origin := Vector2(cell) * CELL
	var outer := Rect2(origin + Vector2(3, 3), Vector2(58, 58))
	# A grounded shadow, four beveled faces and a quiet gray inset keep the
	# playable cell readable without adding scenery or implying tile bonuses.
	draw_rect(Rect2(outer.position + Vector2(0, 2), outer.size), Color("101619"))
	draw_rect(outer, Color("303739"))
	var tl := outer.position
	var tr := Vector2(outer.end.x, outer.position.y)
	var br := outer.end
	var bl := Vector2(outer.position.x, outer.end.y)
	var inset := 6.0
	var a := tl + Vector2(inset, inset)
	var b := tr + Vector2(-inset, inset)
	var c := br - Vector2(inset, inset)
	var d := bl + Vector2(inset, -inset)
	var variation := float((cell.x * 7 + cell.y * 3) % 3) * 0.008
	var face: Color = (Color("173058") if campus else FLOOR).lightened(variation)
	draw_colored_polygon(PackedVector2Array([tl,tr,b,a]), Color("61696b"))
	draw_colored_polygon(PackedVector2Array([tl,a,d,bl]), Color("535c5e"))
	draw_colored_polygon(PackedVector2Array([tr,br,c,b]), Color("343b3e"))
	draw_colored_polygon(PackedVector2Array([bl,d,c,br]), Color("2b3235"))
	draw_colored_polygon(PackedVector2Array([a,b,c,d]), face)
	# Restrained surface facets echo the tower kit's directional lighting.
	draw_colored_polygon(PackedVector2Array([a,b,c]), face.lightened(0.018))

func _draw_route(cell: Vector2i) -> void:
	var origin := Vector2(cell) * CELL
	# Full-cell surfaces connect at every bend: no gaps or outlines between
	# route cells. Only edges against platforms or the void receive a curb.
	var surface: Color = Color("0E2A28") if campus else ROUTE
	draw_rect(Rect2(origin, Vector2.ONE * CELL), surface)
	var middle := origin + Vector2(30 + (cell.x % 3) * 2, 29 + (cell.y % 3) * 2)
	draw_colored_polygon(PackedVector2Array([origin, origin + Vector2(CELL,0), middle]), surface.lightened(0.012))
	draw_colored_polygon(PackedVector2Array([origin + Vector2(0,CELL), middle, origin + Vector2(CELL,CELL)]), surface.darkened(0.025))
	if not path_cells.has(cell + Vector2i.UP):
		draw_rect(Rect2(origin, Vector2(CELL, 3)), Color("3a4245"))
	if not path_cells.has(cell + Vector2i.LEFT):
		draw_rect(Rect2(origin, Vector2(3, CELL)), Color("333c3f"))
	if not path_cells.has(cell + Vector2i.DOWN):
		draw_rect(Rect2(origin + Vector2(0,CELL - 3), Vector2(CELL,3)), Color("161d20"))
	if not path_cells.has(cell + Vector2i.RIGHT):
		draw_rect(Rect2(origin + Vector2(CELL - 3,0), Vector2(3,CELL)), Color("1a2124"))
