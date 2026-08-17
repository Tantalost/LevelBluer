class_name StageNodeUI
extends VBoxContainer
## One square in the stage dock. Visual states only — no save lookup.

signal stage_pressed(index: int)

enum Kind { NORMAL, BOSS }

var index: int = 0
var kind: Kind = Kind.NORMAL

@onready var _arrow: Label = %SelectArrow
@onready var _cell: Button = %CellButton
@onready var _index_label: Label = %IndexLabel
@onready var _boss_label: Label = %BossLabel

var _pixel_font: Font
var _state: String = "LOCKED"


func _ready() -> void:
	_cell.show_behind_parent = true
	_cell.pressed.connect(func() -> void: stage_pressed.emit(index))


func configure(p_index: int, p_kind: Kind, font: Font) -> void:
	index = p_index
	kind = p_kind
	_pixel_font = font
	_index_label.text = str(p_index + 1)
	_boss_label.visible = false
	_index_label.visible = p_kind != Kind.BOSS


func apply_visual_state(state: String) -> void:
	_state = state
	_refresh_style()
	queue_redraw()


func apply_scale(cell_px: int, font_px: int) -> void:
	_cell.custom_minimum_size = Vector2(cell_px, cell_px)
	_arrow.add_theme_font_size_override("font_size", maxi(8, int(round(font_px * 0.7))))
	_index_label.add_theme_font_size_override("font_size", font_px)
	_boss_label.add_theme_font_size_override("font_size", font_px)
	if _pixel_font:
		_arrow.add_theme_font_override("font", _pixel_font)
		_index_label.add_theme_font_override("font", _pixel_font)
		_boss_label.add_theme_font_override("font", _pixel_font)
	_refresh_style()
	queue_redraw()


func _refresh_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_HEADER, 0.55)
	box.set_corner_radius_all(0)
	box.set_border_width_all(2)
	match _state:
		"SELECTED":
			box.bg_color = Color(Palette.BG_PANEL_ALT, 0.95)
			box.border_color = Palette.SKILL_AURA
			box.shadow_color = Color(Palette.SKILL_AURA, 0.7)
			box.shadow_size = 8
			_index_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
			_boss_label.add_theme_color_override("font_color", Palette.SKILL_AURA)
		"UNLOCKED":
			box.border_color = Palette.CYAN_DIM
			_index_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			_boss_label.add_theme_color_override("font_color", Palette.CYAN)
		_:
			box.border_color = Color(Palette.CYAN_DIM, 0.35)
			_index_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
			_boss_label.add_theme_color_override("font_color", Color(Palette.CYAN_DIM, 0.7))
	_cell.add_theme_stylebox_override("normal", box)
	_cell.add_theme_stylebox_override("hover", box)
	_cell.add_theme_stylebox_override("pressed", box)
	_arrow.add_theme_color_override("font_color", Palette.SKILL_AURA)
	_arrow.modulate.a = 0.0
	queue_redraw()


func _draw() -> void:
	if _cell == null:
		return
	var cx := size.x * 0.5
	if _state == "SELECTED":
		var tip_y := _cell.position.y - 1.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(cx, tip_y),
				Vector2(cx - 5.0, tip_y - 8.0),
				Vector2(cx + 5.0, tip_y - 8.0),
			]),
			Palette.SKILL_AURA,
		)
	if kind == Kind.BOSS:
		var skull := Palette.SKILL_AURA
		match _state:
			"UNLOCKED":
				skull = Palette.CYAN
			"LOCKED":
				skull = Color(Palette.CYAN_DIM, 0.85)
		_draw_skull(Rect2(_cell.position, _cell.size), skull)


func _draw_skull(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	draw_rect(Rect2(c.x - 7.0, c.y - 7.0, 14.0, 11.0), color)
	draw_rect(Rect2(c.x - 4.0, c.y + 4.0, 8.0, 4.0), color)
	draw_rect(Rect2(c.x - 4.0, c.y - 3.0, 3.0, 3.0), Palette.BG_HEADER)
	draw_rect(Rect2(c.x + 1.0, c.y - 3.0, 3.0, 3.0), Palette.BG_HEADER)
	draw_rect(Rect2(c.x - 1.0, c.y + 2.0, 2.0, 2.0), Palette.BG_HEADER)
