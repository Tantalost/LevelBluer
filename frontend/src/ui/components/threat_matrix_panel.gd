class_name ThreatMatrixPanel
extends PanelContainer
## Open learner model: BKT mastery bars for Ports, Firewalls, and Crypto.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const SKILL_ORDER: PackedStringArray = ["phishing"]

@onready var _header: Label = %HeaderLabel
@onready var _skills: VBoxContainer = %SkillsContainer

var _pixel_font: Font


func _ready() -> void:
	_load_font()
	_style_panel()
	_apply_label(_header, Palette.GOLD, 10)
	refresh_matrix()


func refresh_matrix() -> void:
	_clear_rows()
	var matrix: Dictionary = PlayerManager.mastery_matrix
	var seen: Dictionary = {}
	for i in SKILL_ORDER.size():
		var skill_id: String = SKILL_ORDER[i]
		if matrix.has(skill_id):
			_add_skill_row(skill_id, matrix[skill_id])
			seen[skill_id] = true
	var extra_keys: Array = matrix.keys()
	for k in extra_keys.size():
		var skill_id: String = str(extra_keys[k])
		if skill_id.is_empty() or seen.has(skill_id):
			continue
		_add_skill_row(skill_id, matrix[skill_id])


func _add_skill_row(skill_id: String, stored: Variant) -> void:
	var value_type: int = typeof(stored)
	if value_type != TYPE_FLOAT and value_type != TYPE_INT:
		return
	var mastery_val: float = clampf(float(stored), 0.0, 1.0)
	var mastery_pct: int = clampi(int(round(mastery_val * 100.0)), 0, 100)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = "%s  %d%%" % [skill_id.to_upper(), mastery_pct]
	name_label.custom_minimum_size = Vector2(210, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(name_label, Palette.TEXT_PRIMARY, 9)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.min_value = 0.0
	bar.value = float(mastery_pct)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	_style_bar(bar)

	row.add_child(name_label)
	row.add_child(bar)
	_skills.add_child(row)


func _clear_rows() -> void:
	var kids: Array = _skills.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child == null:
			continue
		_skills.remove_child(child)
		child.queue_free()


func _style_panel() -> void:
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.CYAN, 0, 2)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", box)


func _style_bar(bar: ProgressBar) -> void:
	var bg := _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 1)
	var fill := _pixel_box(Palette.CYAN, Palette.CYAN, 0, 0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _apply_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
