extends Button
## Circular research node; native Button retains keyboard/touch activation.

const Glyphs = preload("res://src/ui/screens/deploy/upgrade_glyphs.gd")
const PIXEL_FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
var track_id := "stats"
var rank := 1
var max_rank := 3
var state := "LOCKED"
var accent := Color("51e7ab")
var caption := "OUTPUT I"
var selected := false
var is_root := false

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for sig in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		sig.connect(queue_redraw)

func _draw() -> void:
	var r := minf(size.x * 0.32, (size.y - 25.0) * 0.5)
	var c := Vector2(size.x * 0.5, r + 4)
	var ink := Color("59667b") if state == "LOCKED" else accent
	var fill := Color("0c1320")
	if state == "OWNED":
		fill = accent
	if selected or is_hovered() or has_focus():
		draw_circle(c, r + 8, Color(accent, 0.09))
		draw_arc(c, r + 7, 0, TAU, 64, accent, 1.0, true)
	draw_circle(c + Vector2(0, 4), r + 2, Color(0, 0, 0, 0.35))
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 64, ink, 2.5, true)
	Glyphs.paint(self, c, r * 0.48, "root" if is_root else track_id, Color("09141e") if state == "OWNED" else ink)
	if not is_root:
		var badge := Rect2(c + Vector2(-18, r - 7), Vector2(36, 17))
		draw_style_box(_badge_style(ink), badge)
		draw_string(PIXEL_FONT, badge.position + Vector2(0, 12), "%d/%d" % [rank, max_rank], HORIZONTAL_ALIGNMENT_CENTER, 36, 8, ink)
		if state == "LOCKED":
			var lock_pos := c + Vector2(-r * 0.8, r * 0.6)
			draw_circle(lock_pos, 9, Color("111b2b"))
			Glyphs.paint(self, lock_pos, 7, "lock", ink)
	var font_size := clampi(int(size.x / 14), 7, 10)
	var caption_width := PIXEL_FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Knock out the wire behind the small caption, preserving legibility along branches.
	draw_rect(Rect2((size.x - caption_width) * 0.5 - 3, c.y + r + 14, caption_width + 6, 14), Color("080e18"))
	draw_string(PIXEL_FONT, Vector2(0, c.y + r + 25), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color("e4e9ed") if selected else ink)

func _badge_style(ink: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a1220")
	box.border_color = ink
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box
