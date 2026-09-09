class_name StageThreeMapArt
extends StageOneMapArt
## Module 1, Stage 3: a packet-inspection chamber built around the exact ASCII
## spiral. Amber scanner hardware gives this stage a distinct filter-drill theme.

const FILTER_GOLD := Color("f2ad42")
const FILTER_GOLD_DIM := Color("765124")
const FILTER_GREEN := Color("71d89b")
const FILTER_GLASS := Color("253943")
const QUARANTINE_FACE := Color("161f27")


func _draw_backdrop() -> void:
	super._draw_backdrop()
	draw_colored_polygon(PackedVector2Array([
		Vector2(182.0, -152.0), Vector2(780.0, -152.0),
		Vector2(654.0, MAP_SIZE.y + 152.0), Vector2(58.0, MAP_SIZE.y + 152.0),
	]), Color(FILTER_GOLD, 0.024))


func _draw_machine_banks() -> void:
	# Replace the generic cabinets with reusable inspection cartridges and
	# analyzer banks. The outer frame remains consistent with the module family.
	for i in 7:
		var x: float = -100.0 + float(i) * 181.0
		var body := Rect2(Vector2(x, -136.0), Vector2(154.0, 98.0))
		TILE_STYLE.draw_machine_block(self, body, QUARANTINE_FACE, WALL_LIT, VOID, 10.0)
		if i % 3 == 0:
			_draw_fan(body.position + Vector2(49.0, 54.0), 25.0)
			_draw_fan(body.position + Vector2(105.0, 54.0), 25.0)
		else:
			for cartridge in 4:
				var tube := Rect2(body.position + Vector2(13.0 + float(cartridge) * 33.0, 16.0), Vector2(22.0, 61.0))
				_draw_filter_cartridge(tube, (cartridge + i) % 3 == 0)

	for i in 7:
		var x: float = -100.0 + float(i) * 181.0
		var body := Rect2(Vector2(x, MAP_SIZE.y + 34.0), Vector2(154.0, 96.0))
		TILE_STYLE.draw_machine_block(self, body, Color("17212a"), WALL_LIT, VOID, 10.0)
		if i == 0 or i == 6:
			_draw_fan(body.position + Vector2(49.0, 55.0), 24.0)
			_draw_fan(body.position + Vector2(105.0, 55.0), 24.0)
		else:
			var scanner := body.grow(-13.0)
			draw_rect(scanner, Color("0d151c"), true)
			for slot in 4:
				var sy: float = scanner.position.y + 10.0 + float(slot) * 15.0
				draw_line(Vector2(scanner.position.x + 7.0, sy), Vector2(scanner.end.x - 7.0, sy), Color("53636d"), 2.0)
				draw_circle(Vector2(scanner.end.x - 10.0, sy), 2.0, FILTER_GOLD if (slot + i) % 3 == 0 else CYAN_DIM)

	# Thick pipe bundles carry inspected traffic in and quarantined traffic out.
	for row in [0, 4, 8, 12]:
		var y: float = (float(row) + 0.5) * TILE
		draw_line(Vector2(-112.0, y), Vector2(-18.0, y), Color("3c4c56"), 7.0)
		draw_line(Vector2(MAP_SIZE.x + 18.0, y), Vector2(MAP_SIZE.x + 112.0, y), Color("3c4c56"), 7.0)


func _draw_raised_platforms() -> void:
	# Three-by-three filter housings expose the Basic Node's real footprint.
	# Every housing sits inside one of the spiral's widened deployment bands.
	var housings: Array[Rect2] = [
		Rect2(Vector2(1.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(6.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(11.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(16.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(21.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(26.0, 1.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(0.0, 5.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(6.0, 5.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(11.0, 5.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(16.0, 5.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(21.0, 5.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(26.0, 5.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(1.0, 9.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(6.0, 9.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(10.0, 9.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(19.0, 9.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(24.0, 9.0) * TILE, Vector2(3.0, 3.0) * TILE),
		Rect2(Vector2(29.0, 9.0) * TILE, Vector2(3.0, 3.0) * TILE),
	]
	for i in housings.size():
		var top_rect: Rect2 = housings[i].grow(-5.0)
		var top_color: Color = FILTER_GLASS if i % 3 == 0 else Color("35434c")
		TILE_STYLE.draw_raised_panel(self, top_rect, top_color, LIGHT, PANEL_FACE, 7.0, Vector2(7.0, 10.0))
		_draw_filter_window(top_rect, i)

	# A dedicated 3x3 processor directly above the objective anchors the final coil.
	var quarantine := Rect2(Vector2(14.0, 9.0) * TILE + Vector2(5.0, 5.0), Vector2(3.0, 3.0) * TILE - Vector2(10.0, 10.0))
	TILE_STYLE.draw_raised_panel(self, quarantine, Color("26343e"), LIGHT, QUARANTINE_FACE, 9.0, Vector2(9.0, 13.0))
	for bay in 5:
		var bx: float = lerpf(quarantine.position.x + 25.0, quarantine.end.x - 25.0, float(bay) / 4.0)
		draw_circle(Vector2(bx, quarantine.get_center().y), 3.0, FILTER_GOLD if bay == 2 else FILTER_GOLD_DIM)


func _draw_route_details() -> void:
	super._draw_route_details()
	# Transverse amber triplets are the packet-filter scanners. Their orientation
	# follows the path, so the detail remains reusable on straight tiles.
	for stored: Variant in _path_cells.keys():
		var cell: Vector2i = stored as Vector2i
		if cell == _start_cell or cell == _end_cell:
			continue
		if (cell.x * 5 + cell.y * 7) % 17 != 0:
			continue
		var center := _cell_center(cell)
		var horizontal: bool = _is_path(cell + Vector2i.LEFT) and _is_path(cell + Vector2i.RIGHT)
		var vertical: bool = _is_path(cell + Vector2i.UP) and _is_path(cell + Vector2i.DOWN)
		if horizontal:
			for offset in [-5.0, 0.0, 5.0]:
				draw_line(center + Vector2(offset, -9.0), center + Vector2(offset, 9.0), Color(FILTER_GOLD, 0.7), 1.4)
		elif vertical:
			for offset in [-5.0, 0.0, 5.0]:
				draw_line(center + Vector2(-9.0, offset), center + Vector2(9.0, offset), Color(FILTER_GOLD, 0.7), 1.4)


func _draw_architecture_shadows() -> void:
	# Repeating scanner arches cast staggered shadows toward the center, making
	# the concentric route feel like a physical inspection tunnel.
	for x in [82.0, 326.0, 570.0, 814.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0.0), Vector2(x + 54.0, 0.0),
			Vector2(x + 118.0, 168.0), Vector2(x + 64.0, 168.0),
		]), Color(VOID, 0.14))
	for y in [80.0, 208.0, 336.0]:
		draw_line(Vector2(0.0, y), Vector2(164.0, y + 58.0), Color(VOID, 0.12), 5.0)


func _draw_light_wash() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(86.0, 0.0), Vector2(318.0, 0.0),
		Vector2(438.0, MAP_SIZE.y), Vector2(206.0, MAP_SIZE.y),
	]), Color(LIGHT, 0.03))
	draw_colored_polygon(PackedVector2Array([
		Vector2(520.0, 0.0), Vector2(760.0, 0.0),
		Vector2(704.0, MAP_SIZE.y), Vector2(464.0, MAP_SIZE.y),
	]), Color(FILTER_GOLD, 0.035))
	# A restrained glow identifies the quarantine core without hiding its tile.
	draw_circle(_cell_center(_end_cell), 48.0, Color(RED, 0.035))


func _draw_filter_cartridge(rect: Rect2, active: bool) -> void:
	draw_rect(rect, Color("0d151c"), true)
	draw_rect(rect, Color("4c5a63"), false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(4.0, 9.0), Vector2(rect.size.x - 8.0, rect.size.y - 18.0)), Color("273842"), true)
	draw_line(rect.position + Vector2(2.0, 12.0), Vector2(rect.end.x - 2.0, rect.position.y + 12.0), FILTER_GOLD_DIM, 2.0)
	draw_line(Vector2(rect.position.x + 2.0, rect.end.y - 12.0), rect.end - Vector2(2.0, 12.0), FILTER_GOLD_DIM, 2.0)
	draw_circle(rect.get_center(), 2.4, FILTER_GOLD if active else CYAN_DIM)


func _draw_filter_window(rect: Rect2, variant: int) -> void:
	var window := rect.grow(-8.0)
	draw_rect(window, Color("101920"), true)
	draw_rect(window, Color(FILTER_GOLD_DIM, 0.78), false, 1.5)
	var segments: int = 3 if variant % 2 == 0 else 4
	for segment in segments:
		var x: float = lerpf(window.position.x + 7.0, window.end.x - 7.0, float(segment) / float(maxi(segments - 1, 1)))
		draw_line(Vector2(x, window.position.y + 3.0), Vector2(x, window.end.y - 3.0), Color(FILTER_GOLD, 0.45), 1.0)
