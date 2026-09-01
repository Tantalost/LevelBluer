@tool
class_name HudGeoButton
extends Control
## Pixel HUD shapes: slash parallelogram, diamond, and resource chip.

signal pressed

enum Geo { SLASH, DIAMOND, CHIP, HEX, BANNER, FLAG }

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const STORY_TEX_PATH := "res://assets/ui/dashboard.png"

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
var _story_tex: Texture2D
var _hover: bool = false
var _poly: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists(FONT_PATH):
		var file: FontFile = load(FONT_PATH) as FontFile
		if file != null:
			_font = file
	if ResourceLoader.exists(STORY_TEX_PATH):
		_story_tex = load(STORY_TEX_PATH) as Texture2D
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


func _is_flag() -> bool:
	return geo == Geo.FLAG or int(geo) == 5


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
		if not _is_flag():
			border = Palette.BLUE_400
	if _is_flag():
		var shadow := PackedVector2Array()
		for i in _poly.size():
			shadow.append(_poly[i] + Vector2(4.0, 5.0))
		draw_colored_polygon(shadow, Color(Palette.DEEP_SPACE, 0.5))
	draw_colored_polygon(_poly, fill)
	if _is_flag():
		_draw_flag_texture()
		_draw_flag_band()
	if geo == Geo.SLASH or geo == Geo.CHIP:
		var hi := PackedVector2Array([_poly[0], _poly[1]])
		var lo := PackedVector2Array([_poly[2], _poly[3]])
		draw_polyline(hi, Color(Palette.CREAM, 0.28), 2.0)
		draw_polyline(lo, Color(Palette.DEEP_SPACE, 0.7), 2.0)
	var closed := PackedVector2Array(_poly)
	closed.append(_poly[0])
	var border_w := 3.5 if _is_flag() else 2.5
	draw_polyline(closed, border, border_w)
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
	if geo == Geo.DIAMOND:
		title_color = Palette.INK if fill_key == "frost" else Palette.CREAM
		sub_color = Color(title_color, 0.72)
	elif _is_flag():
		title_color = Palette.CREAM
		sub_color = Color(Palette.CREAM, 0.8)
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
	if _is_flag():
		var flag_s := minf(shear, size.x * 0.35)
		cx = (flag_s + size.x) * 0.47
	elif geo == Geo.SLASH or geo == Geo.BANNER:
		cx = shear + 28.0
		for i in lines.size():
			var line: Dictionary = lines[i]
			var sz: Vector2 = _font.get_string_size(str(line["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(line["size"]))
			cx = maxf(cx, shear + 28.0 + sz.x * 0.5)
	var y := size.y * 0.5 - stack_h * 0.5
	if _is_flag():
		y = size.y * 0.38 - stack_h * 0.5
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
	var pos := Vector2(cx - sz.x * 0.5, baseline)
	if _is_flag():
		draw_string(_font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.DEEP_SPACE, 0.7))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return _font.get_height(font_size)


func _rebuild_poly() -> void:
	var w := size.x
	var h := size.y
	var s := minf(shear, w * 0.35)
	if _is_flag():
		var mid := h * 0.5
		var right_s := maxf(h, 56.0)
		right_s = minf(right_s, w * 0.45)
		_poly = PackedVector2Array([
			Vector2(0.0, mid),
			Vector2(s, 0.0),
			Vector2(w - right_s, 0.0),
			Vector2(w, h),
			Vector2(s, h),
		])
		return
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


func _draw_flag_texture() -> void:
	if _story_tex == null or _poly.size() < 3:
		return
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in _poly.size():
		uvs.append(Vector2(_poly[i].x / w, _poly[i].y / h))
		cols.append(Color(1.0, 1.0, 1.0, 0.22))
	draw_polygon(_poly, cols, uvs, _story_tex)


func _draw_flag_band() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var s := minf(shear, w * 0.35)
	var right_s := maxf(h, 56.0)
	right_s = minf(right_s, w * 0.45)
	var inset := 3.5
	var band_h := h * 0.22
	var y_top := h - band_h
	var y_bot := h - inset
	var left_top := _x_on_segment(Vector2(0.0, h * 0.5), Vector2(s, h), y_top)
	var right_top := _x_on_segment(Vector2(w - right_s, 0.0), Vector2(w, h), y_top)
	var right_bot := _x_on_segment(Vector2(w - right_s, 0.0), Vector2(w, h), y_bot)
	var band := PackedVector2Array([
		Vector2(left_top + 1.0, y_top),
		Vector2(right_top - 1.0, y_top),
		Vector2(right_bot - inset, y_bot),
		Vector2(s + 1.0, y_bot),
	])
	draw_colored_polygon(band, Palette.CREAM)


func _x_on_segment(a: Vector2, b: Vector2, y: float) -> float:
	if is_equal_approx(a.y, b.y):
		return a.x
	var t := (y - a.y) / (b.y - a.y)
	return lerpf(a.x, b.x, clampf(t, 0.0, 1.0))


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
		"cream":
			return Palette.CREAM
		_:
			return Palette.CYAN_400
