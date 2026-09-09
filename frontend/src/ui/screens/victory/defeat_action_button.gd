extends Button
## Layered pixel-metal frame; usable for primary and secondary result actions.
var primary := false

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_font_override("font", preload("res://assets/fonts/PressStart2P-Regular.ttf"))
	add_theme_color_override("font_color", Color("eee3ef"))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for sig in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		sig.connect(queue_redraw)

func _draw() -> void:
	var r := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	var ink := Color("ffd39a") if primary else Color("937d9e")
	if is_hovered() or has_focus():
		ink = Color("ff729d")
	draw_rect(r.grow(4), Color("160f23"))
	draw_rect(r.grow(3), ink.darkened(0.55), false, 2)
	draw_rect(r, Color("292139"))
	draw_rect(r, ink, false, 1)
	draw_rect(r.grow(-4), Color("665477"), false, 1)
	if primary:
		for x in [r.position.x, r.end.x]:
			for y in [r.position.y, r.end.y]:
				var c := Vector2(x, y)
				draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("160f23"))
				draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), ink)
				draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color("fff3d9"))
	# Custom frame draws after Button's built-in text, so paint the caption last.
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	draw_string(font, Vector2(0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color("fff0e7"))
