extends Button
## Glowing orbit nodes; real Buttons provide keyboard and touch input.
const Glyphs = preload("res://src/ui/screens/deploy/upgrade_glyphs.gd")
const FONT = preload("res://assets/fonts/DigitalDisco.ttf")
var track_id := "stats"
var rank := 1
var max_rank := 3
var state := "LOCKED"
var accent := Color("85d9c3")
var caption := "OUTPUT"
var selected := false
var is_root := false
var font_size := 23
var _pulse := 0.0

func _ready() -> void:
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for sig in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		sig.connect(queue_redraw)

func celebrate() -> void:
	_pulse = 1
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_pulse = value
		queue_redraw(), 1.0, 0.0, 0.65)

func _draw() -> void:
	var r := minf(size.x * 0.29, (size.y - 44) * 0.5)
	var c := Vector2(size.x * 0.5, r + 12)
	var ink := Color("80939c") if state == "LOCKED" else accent
	var highlighted := selected or is_hovered() or has_focus()
	if state != "LOCKED" or highlighted:
		for i in range(4, 0, -1):
			draw_circle(c, r + i * 4, Color(accent, 0.04 + (0.025 if highlighted else 0)))
	draw_circle(c + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.4))
	draw_circle(c, r, Color("21413f") if state == "OWNED" else Color("0c1821"))
	draw_arc(c, r, 0, TAU, 64, ink, 3, true)
	if highlighted:
		draw_arc(c, r + 5, 0, TAU, 64, Color("e5c88a"), 2, true)
	if _pulse > 0:
		draw_arc(c, r + 6 + (1 - _pulse) * 28, 0, TAU, 64, Color(accent, _pulse), 3, true)
	Glyphs.paint(self, c, r * 0.5, "root" if is_root else track_id, ink)
	if state == "LOCKED" and not is_root:
		var lock := c + Vector2(-r * 0.8, r * 0.65)
		draw_circle(lock, 11, Color("0c1821"))
		Glyphs.paint(self, lock, 8, "lock", ink)
	var badge := "CORE" if is_root else "%d/%d" % [rank, max_rank]
	var baseline := c.y + r + 17
	draw_rect(Rect2(c.x - 32, baseline - 17, 64, 24), Color("0b141c"))
	draw_string(FONT, Vector2(0, baseline + 2), badge, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
	if not is_root and not caption.is_empty():
		var caption_width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2((size.x - caption_width) * 0.5 - 3, size.y - font_size - 1, caption_width + 6, font_size + 4), Color("0b141c"))
		draw_string(FONT, Vector2(0, size.y - 2), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color("e3eee5") if highlighted else ink)
