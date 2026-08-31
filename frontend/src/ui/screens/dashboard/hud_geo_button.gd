@tool
class_name HudGeoButton
extends Control
## Pixel HUD shapes: slash parallelogram, diamond, and resource chip.

signal pressed

enum Geo { SLASH, DIAMOND, CHIP, HEX, BANNER }

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@export var geo: Geo = Geo.SLASH:
	set(value):
		geo = value
		queue_redraw()
@export var title: String = ""
@export var subtitle: String = ""
@export var detail: String = ""
@export var fill_key: String = "header"
@export var border_key: String = "cyan"
@export var title_size: int = 16
@export var subtitle_size: int = 12
@export var detail_size: int = 10
@export var shear: float = 36.0:
	set(value):
		shear = value
		queue_redraw()
@export var progress: float = -1.0

var _font: Font
var _hover: bool = false
var _poly: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists(FONT_PATH):
		var file: FontFile = load(FONT_PATH) as FontFile
		if file != null:
			_font = file
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _has_point(mouse.position):
		AudioManager.play_sfx("ui_click")
		pressed.emit()
		accept_event()


func _has_point(point: Vector2) -> bool:
	if _poly.size() < 3:
		_rebuild_poly()
	return Geometry2D.is_point_in_polygon(point, _poly)


func _draw() -> void:
	_rebuild_poly()
	if _poly.size() < 3:
		return
	var fill := _fill_color()
	var border := _border_color()
	if _hover:
		fill = fill.lightened(0.08)
		border = Palette.BLUE_400
	draw_colored_polygon(_poly, fill)
	if _poly.size() == 4:
		var hi := PackedVector2Array([_poly[0], _poly[1]])
		var lo := PackedVector2Array([_poly[2], _poly[3]])
		draw_polyline(hi, Color(Palette.CREAM, 0.28), 2.0)
		draw_polyline(lo, Color(Palette.DEEP_SPACE, 0.7), 2.0)
	var closed := PackedVector2Array(_poly)
	closed.append(_poly[0])
	draw_polyline(closed, border, 2.5)
	_draw_copy()


func _draw_copy() -> void:
	if _font == null:
		return
	var title_color := Palette.CREAM
	var sub_color := Palette.CYAN_400
	if fill_key == "gold":
		title_color = Palette.CREAM
		sub_color = Palette.CYAN_300
	elif fill_key == "orange":
		title_color = Palette.INK
		sub_color = Palette.INK
	elif fill_key == "frost":
		title_color = Palette.INK
		sub_color = Palette.CYAN_400
	var lines: Array[Dictionary] = []
	if not title.is_empty():
		lines.append({"text": title, "size": title_size, "color": title_color})
	if not subtitle.is_empty():
		lines.append({"text": subtitle, "size": subtitle_size, "color": sub_color})
	if not detail.is_empty():
		var parts: PackedStringArray = detail.replace(" • ", "\n").replace("•", "\n").split("\n")
		for i in parts.size():
			var part := parts[i].strip_edges()
			if not part.is_empty():
				lines.append({"text": part, "size": detail_size, "color": title_color})
	if lines.is_empty() and progress < 0.0:
		return
	var gap := 14.0 if geo == Geo.DIAMOND else 10.0
	var bar_h := 8.0
	var bar_gap := 16.0 if geo == Geo.DIAMOND else 12.0
	var stack_h := 0.0
	for i in lines.size():
		var line: Dictionary = lines[i]
		stack_h += _font.get_height(int(line["size"]))
		if i < lines.size() - 1:
			stack_h += gap
	if progress >= 0.0:
		stack_h += bar_gap + bar_h
	var cx := size.x * 0.5
	if geo == Geo.SLASH:
		cx += shear * 0.1
	var y := size.y * 0.5 - stack_h * 0.5
	for i in lines.size():
		var line: Dictionary = lines[i]
		var font_size: int = int(line["size"])
		y += _blit_line(str(line["text"]), font_size, line["color"] as Color, cx, y)
		if i < lines.size() - 1:
			y += gap
	if progress < 0.0:
		return
	y += bar_gap
	var bar_w := size.x * (0.34 if geo == Geo.DIAMOND else 0.52)
	var bar_x := cx - bar_w * 0.5
	draw_rect(Rect2(bar_x, y, bar_w, bar_h), Palette.DEEP_SPACE)
	draw_rect(Rect2(bar_x, y, bar_w * clampf(progress, 0.0, 1.0), bar_h), Palette.CYAN_400)


func _blit_line(text: String, font_size: int, color: Color, cx: float, top: float) -> float:
	var sz := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := top + _font.get_ascent(font_size)
	draw_string(_font, Vector2(cx - sz.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return _font.get_height(font_size)


func _rebuild_poly() -> void:
	var w := size.x
	var h := size.y
	var s := minf(shear, w * 0.35)
	match geo:
		Geo.DIAMOND:
			_poly = PackedVector2Array([
				Vector2(w * 0.5, 4.0),
				Vector2(w - 4.0, h * 0.5),
				Vector2(w * 0.5, h - 4.0),
				Vector2(4.0, h * 0.5),
			])
		Geo.HEX:
			_poly = _hex_poly(w, h)
		Geo.CHIP:
			_poly = PackedVector2Array([
				Vector2(s, 0.0),
				Vector2(w, 0.0),
				Vector2(w - s, h),
				Vector2(0.0, h),
			])
		Geo.BANNER: 
			# Asymmetrical Banner:
			# Left point is pushed low. Right point is almost perfectly centered.
			var left_point_y := h * 0.75   # Pushed 75% down
			var right_point_y := h * 0.55  # Just slightly off-center (difference of like 1)

			_poly = PackedVector2Array([
				Vector2(0.0, left_point_y),       # Left point (<)
				Vector2(s, 0.0),                  # Top-left corner
				Vector2(w - s, 0.0),              # Top-right corner
				Vector2(w, right_point_y),        # Right point (>)
				Vector2(w - s, h),                # Bottom-right corner
				Vector2(s, h)                     # Bottom-left corner
			])
			
		_: # <--- DEFAULT CATCH-ALL MUST BE AT THE VERY BOTTOM
			_poly = PackedVector2Array([
				Vector2(s, 0.0),
				Vector2(w, 0.0),
				Vector2(w - s, h),
				Vector2(0.0, h),
			])


func _hex_poly(w: float, h: float) -> PackedVector2Array:
	var center := Vector2(w, h) * 0.5
	var radius: float = minf(w, h) * 0.5 - 3.0
	var pts := PackedVector2Array()
	for i in 6:
		var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _fill_color() -> Color:
	match fill_key:
		"gold":
			return Palette.PRIMARY_BLUE
		"orange":
			return Palette.WARNING
		"red":
			return Palette.DANGER
		"cyan":
			return Palette.PRIMARY_BLUE
		"frost":
			return Color(Palette.CREAM, 0.94)
		"violet":
			return Palette.TEAL_900
		"indigo":
			return Palette.TEAL_800
		"panel":
			return Color(Palette.NAVY_800, 0.94)
		_:
			return Color(Palette.NAVY_900, 0.94)


func _border_color() -> Color:
	match border_key:
		"gold":
			return Palette.WARNING
		"orange":
			return Palette.WARNING
		"red":
			return Palette.DANGER
		"magenta":
			return Palette.PRIMARY_BLUE
		"muted":
			return Palette.NAVY_700
		_:
			return Palette.CYAN_400
