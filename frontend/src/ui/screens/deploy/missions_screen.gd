class_name MissionsScreen
extends BaseScreen
## Briefing overlay. Layout mirrors a settings sheet: header, tabs, columns, Done.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const CARD_WIDTH := 720.0
const TAB_NAMES: PackedStringArray = ["DAILY", "MAIN", "EVENT"]

@onready var _dimmer: ColorRect = %Dimmer
@onready var _modal_card: PanelContainer = %ModalCard
@onready var _header_title: Label = %HeaderTitle
@onready var _tab_left: Button = %TabLeft
@onready var _tab_right: Button = %TabRight
@onready var _tab_label: Label = %TabLabel
@onready var _body_panel: PanelContainer = %BodyPanel
@onready var _column_row: HBoxContainer = %ColumnRow
@onready var _done_button: Button = %DoneButton

var _pixel_font: Font
var _tab_index: int = 0
var _chrome: Color = Palette.FOREST_NIGHT


func _ready() -> void:
	_load_font()
	_chrome = Palette.FOREST_NIGHT.lerp(Palette.MAGENTA, 0.22)
	_dimmer.color = Color(Palette.BG_DEEP, 0.55)
	_style_card()
	_style_body()
	_style_tab_button(_tab_left)
	_style_tab_button(_tab_right)
	_style_done_button()
	_apply_label(_header_title, Palette.TEXT_PRIMARY, 16)
	_apply_label(_tab_label, Palette.TEXT_PRIMARY, 12)
	_tab_left.pressed.connect(func() -> void: _set_tab(_tab_index - 1))
	_tab_right.pressed.connect(func() -> void: _set_tab(_tab_index + 1))
	_done_button.pressed.connect(func() -> void: Router.request_back())
	_dimmer.gui_input.connect(_on_dimmer_gui)


func on_enter(_args: Dictionary) -> void:
	_tab_index = 0
	_refresh_body()


func on_resume() -> void:
	_refresh_body()


func _set_tab(index: int) -> void:
	var count: int = TAB_NAMES.size()
	_tab_index = posmod(index, count)
	_refresh_body()


func _on_dimmer_gui(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _modal_card.get_global_rect().has_point(mouse.global_position):
		return
	Router.request_back()


func _refresh_body() -> void:
	_tab_label.text = TAB_NAMES[_tab_index]
	_clear_columns()
	if _tab_index == 0:
		_fill_daily_columns()
		return
	if _tab_index == 1:
		_column_row.add_child(_make_empty_note("No story directives."))
		return
	_column_row.add_child(_make_empty_note("No active event."))


func _fill_daily_columns() -> void:
	var tasks: Array[Dictionary] = TaskManager.get_active_tasks()
	for t in tasks.size():
		if t > 0:
			_column_row.add_child(_make_divider())
		_column_row.add_child(_make_task_column(tasks[t]))


func _clear_columns() -> void:
	var kids: Array[Node] = _column_row.get_children()
	for i in kids.size():
		var child: Node = kids[i]
		_column_row.remove_child(child)
		child.queue_free()


func _make_task_column(task: Dictionary) -> Control:
	var title: String = str(task.get("title", "DIRECTIVE"))
	var task_id: String = str(task.get("id", ""))
	var target: int = maxi(1, int(task.get("target", 1)))
	var current: int = clampi(int(task.get("current", 0)), 0, target)
	var reward: int = maxi(0, int(task.get("reward", 0)))
	var done: bool = current >= target

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)

	var heading := Label.new()
	heading.text = title.to_upper()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label(heading, Palette.FIELD_TEXT, 11)
	col.add_child(heading)

	var blurb := Label.new()
	blurb.text = _task_blurb(task_id)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label(blurb, Color(Palette.FIELD_TEXT, 0.55), 8)
	col.add_child(blurb)

	var status := Label.new()
	if done:
		status.text = "CLEARED"
	else:
		status.text = "%d / %d" % [current, target]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label(status, Palette.FIELD_TEXT, 12)
	col.add_child(status)

	var reward_label := Label.new()
	reward_label.text = "+%d CR" % reward
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label(reward_label, Palette.GOLD_DIM if done else Palette.GOLD, 9)
	col.add_child(reward_label)
	return col


func _make_empty_note(copy: String) -> Label:
	var note := Label.new()
	note.text = copy.to_upper()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label(note, Color(Palette.FIELD_TEXT, 0.55), 10)
	return note


func _make_divider() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(2, 0)
	line.color = Color(Palette.FIELD_TEXT, 0.12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _task_blurb(task_id: String) -> String:
	if task_id == "defeat_fast":
		return "Intercept fast packets in any deployed stage."
	if task_id == "clear_stages":
		return "Clear stages to complete this directive."
	return "Complete this directive during deploy."


func _style_card() -> void:
	var box: StyleBoxFlat = _pixel_box(_chrome, _chrome, 18, 0)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 6)
	_modal_card.add_theme_stylebox_override("panel", box)
	_modal_card.custom_minimum_size = Vector2(CARD_WIDTH, 400.0)


func _style_body() -> void:
	var box: StyleBoxFlat = _pixel_box(Color(Palette.FIELD_BG, 0.94), Color(Palette.FIELD_BG, 0.94), 0, 0)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 20.0
	_body_panel.add_theme_stylebox_override("panel", box)


func _style_done_button() -> void:
	var box: StyleBoxFlat = _pixel_box(_chrome, _chrome, 0, 0)
	box.corner_radius_bottom_left = 18
	box.corner_radius_bottom_right = 18
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	_done_button.add_theme_stylebox_override("normal", box)
	_done_button.add_theme_stylebox_override("hover", box)
	_done_button.add_theme_stylebox_override("pressed", box)
	_done_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_done_button.add_theme_font_override("font", _pixel_font)
	_done_button.add_theme_font_size_override("font_size", 14)


func _style_tab_button(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 12)


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
