extends Control
## Static CRT-style scanlines matching the prototype IntroScreen overlay.

const LINE_COLOR := Color(0, 0.831373, 1, 0.025)
const LINE_SPACING := 13.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), LINE_COLOR, 1.0)
		y += LINE_SPACING
