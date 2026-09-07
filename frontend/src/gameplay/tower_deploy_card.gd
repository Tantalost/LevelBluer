@tool
class_name TowerDeployCard
extends Control
## Compact reusable tower deploy card. Supply a portrait for final art; when it
## is null the card renders a neutral operator silhouette placeholder.

signal pressed

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@export var tower_id: String = "base"
@export var tower_name: String = "BASIC NODE":
	set(value):
		tower_name = value
		queue_redraw()
@export var role_label: String = "DPS":
	set(value):
		role_label = value
		queue_redraw()
@export var cost: int = 2:
	set(value):
		cost = maxi(0, value)
		queue_redraw()
@export var portrait: Texture2D:
	set(value):
		portrait = value
		queue_redraw()
@export var accent: Color = Color("65e9ef"):
	set(value):
		accent = value
		queue_redraw()
@export var available: bool = true:
	set(value):
		available = value
		queue_redraw()

var _font: Font
var _hover: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile
	queue_redraw()


func configure(
	next_id: String,
	next_name: String,
	next_role: String,
	next_cost: int,
	next_portrait: Texture2D = null,
	next_accent: Color = Color("65e9ef")
) -> void:
	tower_id = next_id
	tower_name = next_name
	role_label = next_role
	cost = next_cost
	portrait = next_portrait
	accent = next_accent
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
	if not available:
		accept_event()
		return
	AudioManager.play_sfx("ui_click")
	pressed.emit()
	accept_event()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var card := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
	var active_accent: Color = accent.lightened(0.16) if _hover else accent
	if not available:
		active_accent = Color("59636a")
	# Offset shadow and clipped-corner silhouette match the compact operator card.
	draw_colored_polygon(_card_polygon(card, Vector2(5.0, 6.0)), Color(0.01, 0.02, 0.035, 0.72))
	draw_colored_polygon(_card_polygon(card), Color("182028"))
	var portrait_rect := Rect2(card.position + Vector2(4.0, 30.0), Vector2(card.size.x - 8.0, card.size.y - 58.0))
	draw_rect(portrait_rect, Color("252e37"), true)
	if portrait != null:
		draw_texture_rect(portrait, portrait_rect, false, Color.WHITE)
	else:
		_draw_placeholder_portrait(portrait_rect)
	# Dark cost header overlaps the portrait like the reference card.
	var header := Rect2(card.position + Vector2(3.0, 3.0), Vector2(card.size.x - 20.0, 34.0))
	draw_rect(header, Color("0d1218"), true)
	draw_rect(Rect2(header.position, Vector2(49.0, header.size.y)), Color("a8adb0"), true)
	draw_line(Vector2(header.position.x + 49.0, header.position.y), Vector2(header.position.x + 49.0, header.end.y), Color("2d3439"), 2.0)
	_draw_label(role_label, header.position + Vector2(5.0, 21.0), 7, Color("13191e"))
	_draw_label(str(cost), header.position + Vector2(57.0, 25.0), 15, Color("e6e8e5"))
	# Bottom identity strip and strong white baseline keep the silhouette readable.
	var footer := Rect2(Vector2(card.position.x + 4.0, card.end.y - 27.0), Vector2(card.size.x - 8.0, 23.0))
	draw_rect(footer, Color("0d1218"), true)
	_draw_label(tower_name, footer.position + Vector2(7.0, 15.0), 7, Color("e6e8e5"))
	draw_line(Vector2(card.position.x + 2.0, card.end.y - 2.0), Vector2(card.end.x - 9.0, card.end.y - 2.0), Color("f1f0e9"), 4.0)
	# Outer border: subdued normally, cyan focus when interactive/hovered.
	var outline := _card_polygon(card)
	outline.append(outline[0])
	draw_polyline(outline, active_accent if _hover else Color("6c777d"), 2.0)
	draw_line(Vector2(card.position.x + 2.0, card.end.y - 2.0), Vector2(card.end.x - 9.0, card.end.y - 2.0), active_accent if _hover else Color("f1f0e9"), 3.0)


func _card_polygon(rect: Rect2, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + offset,
		Vector2(rect.end.x, rect.position.y) + offset,
		Vector2(rect.end.x, rect.end.y - 13.0) + offset,
		Vector2(rect.end.x - 13.0, rect.end.y) + offset,
		Vector2(rect.position.x, rect.end.y) + offset,
	])


func _draw_placeholder_portrait(rect: Rect2) -> void:
	# Abstract and intentionally identity-free; final tower art slots in directly.
	draw_circle(rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.35), rect.size.x * 0.38, Color(accent, 0.08))
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.47)
	draw_circle(center + Vector2(0.0, -15.0), 17.0, Color("11171d"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-34.0, 35.0), center + Vector2(-24.0, 10.0),
		center + Vector2(-10.0, 1.0), center + Vector2(10.0, 1.0),
		center + Vector2(25.0, 10.0), center + Vector2(36.0, 35.0),
	]), Color("10161c"))
	# Angular hair/helmet planes make the placeholder feel intentional.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-19.0, -17.0), center + Vector2(-4.0, -37.0),
		center + Vector2(18.0, -25.0), center + Vector2(13.0, -8.0),
		center + Vector2(4.0, -18.0), center + Vector2(-4.0, -7.0),
	]), Color("29333c"))
	draw_line(center + Vector2(-25.0, 18.0), center + Vector2(26.0, 18.0), Color(accent, 0.42), 2.0)


func _draw_label(copy: String, baseline: Vector2, font_size: int, color: Color) -> void:
	if _font == null or copy.is_empty():
		return
	draw_string(_font, baseline, copy, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
