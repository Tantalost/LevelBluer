extends Control
## Static CRT-style scanlines matching the prototype IntroScreen overlay.

@export var draw_grid: bool = false

const LINE_COLOR := Color(0, 0.831373, 1, 0.025)
const LINE_SPACING := 13.0
const GRID_SPACING := 48.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), LINE_COLOR, 1.0)
		y += LINE_SPACING
	if not draw_grid:
		return
	var grid := Color(Palette.CYAN, 0.06)
	var gy := 0.0
	while gy < size.y:
		draw_line(Vector2(0, gy), Vector2(size.x, gy), grid, 1.0)
		gy += GRID_SPACING
	var gx := 0.0
	while gx < size.x:
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), grid, 1.0)
		gx += GRID_SPACING
