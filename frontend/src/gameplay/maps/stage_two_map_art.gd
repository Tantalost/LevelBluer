class_name StageTwoMapArt
extends StageOneMapArt
## Module 1, Stage 2: an adaptive server gauntlet. The base renderer keeps the
## ASCII path exact; these overrides give the switchback its own visual identity.

const VIOLET := Color("aa6dff")
const VIOLET_DIM := Color("49336a")
const SERVER_FACE := Color("19242e")
const SERVER_INSET := Color("0c141d")


func _draw_backdrop() -> void:
	super._draw_backdrop()
	# A restrained diagnostic wash distinguishes this stage without changing the
	# cyan-entry/red-core navigation language established in Stage 1.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-128.0, -152.0), Vector2(360.0, -152.0),
		Vector2(520.0, MAP_SIZE.y + 152.0), Vector2(30.0, MAP_SIZE.y + 152.0),
	]), Color(VIOLET, 0.018))


func _draw_machine_banks() -> void:
	# Alternating cooling and compute cabinets frame the adaptive test chamber.
	for i in 7:
		var x: float = -100.0 + float(i) * 181.0
		var body := Rect2(Vector2(x, -136.0), Vector2(154.0, 98.0))
		TILE_STYLE.draw_machine_block(self, body, SERVER_FACE, WALL_LIT, VOID, 10.0)
		if i == 0 or i == 6:
			_draw_fan(body.position + Vector2(49.0, 54.0), 25.0)
			_draw_fan(body.position + Vector2(105.0, 54.0), 25.0)
		else:
			var rack := body.grow(-10.0)
			draw_rect(rack, SERVER_INSET, true)
			for bay in 4:
				var bx: float = rack.position.x + 8.0 + float(bay) * 31.0
				draw_rect(Rect2(Vector2(bx, rack.position.y + 8.0), Vector2(23.0, 57.0)), Color("25333e"), true)
				for led in 3:
					draw_circle(Vector2(bx + 17.0, rack.position.y + 18.0 + float(led) * 14.0), 1.8, VIOLET if (bay + led + i) % 3 == 0 else CYAN_DIM)
	# Lower banks use denser cooling equipment to sell the long-path heat load.
	for i in 7:
		var x: float = -100.0 + float(i) * 181.0
		var body := Rect2(Vector2(x, MAP_SIZE.y + 34.0), Vector2(154.0, 96.0))
		TILE_STYLE.draw_machine_block(self, body, Color("17212a"), WALL_LIT, VOID, 10.0)
		if i % 3 == 0:
			_draw_fan(body.position + Vector2(49.0, 55.0), 24.0)
			_draw_fan(body.position + Vector2(105.0, 55.0), 24.0)
		else:
			for slot in 4:
				var sy: float = body.position.y + 29.0 + float(slot) * 13.0
				draw_line(Vector2(body.position.x + 14.0, sy), Vector2(body.end.x - 14.0, sy), Color("50616b"), 2.0)
				draw_circle(Vector2(body.end.x - 18.0, sy), 2.0, VIOLET_DIM)
	# Cable trunks enter on both sides at the three widened route elevations.
	for row in [1, 6, 11]:
		var y: float = (float(row) + 0.5) * TILE
		draw_line(Vector2(-112.0, y), Vector2(-18.0, y), Color("394954"), 7.0)
		draw_line(Vector2(MAP_SIZE.x + 18.0, y), Vector2(MAP_SIZE.x + 112.0, y), Color("394954"), 7.0)


func _draw_raised_platforms() -> void:
	# Three-by-three deployment slabs mirror the Basic Node footprint. They sit
	# inside the widened bays between lanes and make legal placement obvious.
	var modules: Array[Rect2] = [
		Rect2(Vector2(3.0, 2.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(9.0, 2.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(15.0, 2.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(21.0, 2.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(27.0, 2.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(3.0, 7.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(9.0, 7.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(15.0, 7.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(21.0, 7.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(27.0, 7.0) * TILE, Vector2(3.0, 3.0) * TILE),
	]
	for i in modules.size():
		var top_rect: Rect2 = modules[i].grow(-5.0)
		var top_color: Color = Color("65727a") if i % 4 == 0 else Color("293742")
		TILE_STYLE.draw_raised_panel(self, top_rect, top_color, LIGHT, PANEL_FACE, 6.0, Vector2(6.0, 9.0))
		if i % 3 == 0:
			for led in 3:
				var lx: float = lerpf(top_rect.position.x + 15.0, top_rect.end.x - 15.0, float(led) / 2.0)
				draw_rect(Rect2(Vector2(lx - 4.0, top_rect.get_center().y - 2.0), Vector2(8.0, 4.0)), VIOLET_DIM, true)
		else:
			draw_line(top_rect.position + Vector2(12.0, top_rect.size.y * 0.5), Vector2(top_rect.end.x - 12.0, top_rect.get_center().y), Color("53646f"), 2.0)
	# Grates remain inside the widened build bays.
	_draw_service_grate(Rect2(Vector2(6.0, 3.0) * TILE + Vector2(6.0, 3.0), Vector2(52.0, 25.0)))
	_draw_service_grate(Rect2(Vector2(18.0, 8.0) * TILE + Vector2(6.0, 3.0), Vector2(52.0, 25.0)))


func _draw_route_details() -> void:
	super._draw_route_details()
	# Violet corner diagnostics make the alternating switchbacks instantly countable.
	for stored: Variant in _path_cells.keys():
		var cell: Vector2i = stored as Vector2i
		var horizontal: bool = _is_path(cell + Vector2i.LEFT) or _is_path(cell + Vector2i.RIGHT)
		var vertical: bool = _is_path(cell + Vector2i.UP) or _is_path(cell + Vector2i.DOWN)
		if not (horizontal and vertical):
			continue
		var center := _cell_center(cell)
		draw_circle(center, 4.0, Color(VIOLET, 0.72))
		draw_arc(center, 10.0, 0.0, TAU, 12, Color(VIOLET, 0.42), 2.0)


func _draw_architecture_shadows() -> void:
	# Narrow rack shadows repeat rhythmically between switchback lanes.
	for x in [96.0, 320.0, 544.0, 768.0, 928.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0.0), Vector2(x + 28.0, 0.0),
			Vector2(x + 74.0, MAP_SIZE.y), Vector2(x + 46.0, MAP_SIZE.y),
		]), Color(VOID, 0.09))


func _draw_light_wash() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(260.0, 0.0),
		Vector2(370.0, MAP_SIZE.y), Vector2(90.0, MAP_SIZE.y),
	]), Color(LIGHT, 0.025))
	draw_colored_polygon(PackedVector2Array([
		Vector2(610.0, 0.0), Vector2(820.0, 0.0),
		Vector2(760.0, MAP_SIZE.y), Vector2(540.0, MAP_SIZE.y),
	]), Color(VIOLET, 0.028))
