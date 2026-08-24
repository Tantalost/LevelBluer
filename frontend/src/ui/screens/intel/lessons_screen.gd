class_name LessonsScreen
extends BaseScreen
## Module picker for Intel Lessons. Same packs as Deploy. Opens the two-pane player.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _os_bar: PanelContainer = %OsBar
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _ground: ColorRect = %Ground
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _counter_label: Label = %CounterLabel
@onready var _list_card: PanelContainer = %ListCard
@onready var _list_title_bar: PanelContainer = %ListTitleBar
@onready var _list_well: PanelContainer = %ListWell
@onready var _list_file: Label = %ListFile
@onready var _lesson_list: ItemList = %LessonList
@onready var _reader_card: PanelContainer = %ReaderCard
@onready var _reader_title_bar: PanelContainer = %ReaderTitleBar
@onready var _reader_well: PanelContainer = %ReaderWell
@onready var _reader_file: Label = %ReaderFile
@onready var _reader_title: Label = %ReaderTitle
@onready var _tag_label: Label = %TagLabel
@onready var _reader_body: RichTextLabel = %ReaderBody
@onready var _complete_button: Button = %CompleteButton

var _pixel_font: Font
var _modules: Array[Dictionary] = []
var _selected_index: int = 0
var _blink_t: float = 0.0


func _ready() -> void:
	_load_font()
	_ground.color = Palette.FOREST_FLOOR
	_style_os_bar()
	_style_close_button()
	_style_window(_list_card, Palette.CYAN)
	_style_window(_reader_card, Palette.GOLD)
	_style_title_bar(_list_title_bar, Palette.CYAN_DIM)
	_style_title_bar(_reader_title_bar, Palette.ORANGE)
	_style_well(_list_well, Palette.CYAN_DIM)
	_style_well(_reader_well, Palette.ORANGE)
	_style_item_list()
	_style_reader_body()
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 14)
	_apply_label(_os_cursor, Palette.GREEN, 14)
	_apply_label(_subtitle_label, Palette.TEXT_MUTED, 12)
	_apply_label(_counter_label, Palette.TEXT_PRIMARY, 12)
	_apply_label(_list_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_reader_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_reader_title, Palette.TEXT_PRIMARY, 16)
	_apply_label(_tag_label, Palette.CYAN, 11)
	_title_label.text = "LESSONS.DAT"
	_subtitle_label.text = "SELECT A MODULE TIED TO DEPLOY"
	_list_file.text = "MODULES.DAT"
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_lesson_list.item_selected.connect(_on_module_selected)
	_complete_button.pressed.connect(_on_open_pressed)


func _process(delta: float) -> void:
	_blink_t += delta
	var on: bool = fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)


func on_enter(_args: Dictionary) -> void:
	set_process(true)
	_refresh_list_ui()


func on_resume() -> void:
	set_process(true)
	_refresh_list_ui()


func on_exit() -> void:
	set_process(false)


func _on_module_selected(index: int) -> void:
	if index < 0 or index >= _modules.size():
		return
	_selected_index = index
	_show_module(index)


func _on_open_pressed() -> void:
	if not _can_open(_selected_index):
		return
	var module_id: String = _module_id(_selected_index)
	if module_id.is_empty():
		return
	var review: bool = _is_complete(_selected_index)
	Router.push(&"lesson_player", {"module_id": module_id, "review": review})


func _refresh_list_ui() -> void:
	_modules = LessonCatalog.modules()
	var keep_id: String = _module_id(_selected_index)
	_lesson_list.clear()
	var select_index: int = 0
	for i in _modules.size():
		var entry: Dictionary = _modules[i]
		var module_id: String = str(entry.get("id", ""))
		var title: String = str(entry.get("title", module_id)).to_upper()
		var mark: String = _row_mark(i)
		_lesson_list.add_item("%s %02d  %s" % [mark, i + 1, title])
		_lesson_list.set_item_metadata(i, module_id)
		if module_id == keep_id:
			select_index = i
	if _modules.is_empty():
		_selected_index = 0
		_reader_title.text = "NO MODULES"
		_tag_label.text = "DEPLOY: —"
		_reader_body.text = "LessonCatalog has no packs."
		_reader_file.text = "EMPTY.DAT"
		_counter_label.text = "00/00"
		_style_open(true, false, false)
		return
	_selected_index = select_index
	_lesson_list.select(_selected_index)
	_show_module(_selected_index)


func _show_module(index: int) -> void:
	if index < 0 or index >= _modules.size():
		return
	var entry: Dictionary = _modules[index]
	var module_id: String = str(entry.get("id", ""))
	var total: int = maxi(1, LessonCatalog.lesson_count(module_id))
	var done: int = clampi(PlayerManager.get_lesson_progress(module_id), 0, total)
	var locked: bool = not _is_unlocked(index)
	var complete: bool = _is_complete(index)
	_reader_title.text = str(entry.get("title", module_id)).to_upper()
	_tag_label.text = _stage_tag(index)
	_reader_file.text = "%s.DAT" % module_id.to_upper()
	_counter_label.text = "%02d/%02d" % [index + 1, _modules.size()]
	var body: String = str(entry.get("desc", ""))
	body += "\n\nUNITS  %d / %d" % [done, total]
	body += "\n\nLeft pane is the case. Right pane is the drill. The unit is not cleared until that drill is finished."
	if locked:
		body += "\n\nLocked until the previous module is cleared."
	elif complete:
		body += "\n\nCleared. Open in review to replay the files."
	_reader_body.text = body
	_style_open(locked, complete, done > 0)


func _row_mark(index: int) -> String:
	if not _is_unlocked(index):
		return "[ ]"
	if _is_complete(index):
		return "[X]"
	if PlayerManager.get_lesson_progress(_module_id(index)) > 0:
		return "[>]"
	return "[ ]"


func _stage_tag(index: int) -> String:
	if index == 0:
		return "DEPLOY: MODULE 1  /  STAGES 1-10"
	if index == 1:
		return "DEPLOY: MODULE 2  /  STAGES SOON"
	return "DEPLOY: MODULE %d  /  STAGES SOON" % (index + 1)


func _module_id(index: int) -> String:
	if index < 0 or index >= _modules.size():
		return ""
	return str(_modules[index].get("id", ""))


func _is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	return _is_complete(index - 1)


func _is_complete(index: int) -> bool:
	var module_id: String = _module_id(index)
	if module_id.is_empty():
		return false
	return PlayerManager.get_lesson_progress(module_id) >= LessonCatalog.lesson_count(module_id)


func _can_open(index: int) -> bool:
	return index >= 0 and index < _modules.size() and _is_unlocked(index)


func _style_open(locked: bool, complete: bool, in_progress: bool) -> void:
	_complete_button.disabled = locked
	if locked:
		_complete_button.text = "LOCKED"
	elif complete:
		_complete_button.text = "REVIEW  >"
	elif in_progress:
		_complete_button.text = "CONTINUE  >"
	else:
		_complete_button.text = "OPEN  >"
	var fill: Color = Palette.CYAN
	var text: Color = Palette.BG_DEEP
	if locked:
		fill = Palette.TEXT_MUTED
		text = Palette.TEXT_PRIMARY
	elif complete:
		fill = Palette.GOLD
		text = Palette.TEXT_ON_GOLD
	var box: StyleBoxFlat = _pixel_box(fill, Palette.BG_DEEP, 0, 0)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	_complete_button.add_theme_stylebox_override("normal", box)
	_complete_button.add_theme_stylebox_override("hover", box)
	_complete_button.add_theme_stylebox_override("pressed", box)
	_complete_button.add_theme_stylebox_override("disabled", box)
	_complete_button.add_theme_color_override("font_color", text)
	_complete_button.add_theme_color_override("font_disabled_color", text)
	if _pixel_font != null:
		_complete_button.add_theme_font_override("font", _pixel_font)
	_complete_button.add_theme_font_size_override("font_size", 14)


func _style_item_list() -> void:
	var panel: StyleBoxFlat = _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2)
	panel.content_margin_left = 8.0
	panel.content_margin_right = 8.0
	panel.content_margin_top = 8.0
	panel.content_margin_bottom = 8.0
	var selected: StyleBoxFlat = _pixel_box(Palette.CYAN, Palette.TEXT_PRIMARY, 0, 2)
	selected.content_margin_left = 8.0
	selected.content_margin_right = 8.0
	selected.content_margin_top = 8.0
	selected.content_margin_bottom = 8.0
	_lesson_list.add_theme_stylebox_override("panel", panel)
	_lesson_list.add_theme_stylebox_override("selected", selected)
	_lesson_list.add_theme_stylebox_override("hovered", selected)
	_lesson_list.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_lesson_list.add_theme_color_override("font_hovered_color", Palette.BG_DEEP)
	_lesson_list.add_theme_color_override("font_selected_color", Palette.BG_DEEP)
	_lesson_list.add_theme_constant_override("v_separation", 8)
	if _pixel_font != null:
		_lesson_list.add_theme_font_override("font", _pixel_font)
	_lesson_list.add_theme_font_size_override("font_size", 11)


func _style_reader_body() -> void:
	_reader_body.add_theme_color_override("default_color", Palette.TEXT_PRIMARY)
	_reader_body.add_theme_color_override("font_shadow_color", Palette.BG_DEEP)
	if _pixel_font != null:
		_reader_body.add_theme_font_override("normal_font", _pixel_font)
		_reader_body.add_theme_font_override("bold_font", _pixel_font)
	_reader_body.add_theme_font_size_override("normal_font_size", 12)
	_reader_body.add_theme_font_size_override("bold_font_size", 12)


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_os_bar() -> void:
	var style: StyleBoxFlat = _pixel_box(Color(Palette.BG_HEADER, 0.92), Palette.CYAN_DIM, 0, 2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_os_bar.add_theme_stylebox_override("panel", style)


func _style_close_button() -> void:
	_back_button.custom_minimum_size = Vector2(44, 32)
	var normal: StyleBoxFlat = _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	var hover: StyleBoxFlat = _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2)
	_back_button.add_theme_stylebox_override("normal", normal)
	_back_button.add_theme_stylebox_override("hover", hover)
	_back_button.add_theme_stylebox_override("pressed", hover)
	_back_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 12)


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box: StyleBoxFlat = _pixel_box(Palette.BG_HEADER, accent, 0, 3)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.75)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style: StyleBoxFlat = _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	bar.add_theme_stylebox_override("panel", style)


func _style_well(well: PanelContainer, fill: Color) -> void:
	var style: StyleBoxFlat = _pixel_box(fill, Color(Palette.TEXT_PRIMARY, 0.12), 0, 2)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	well.add_theme_stylebox_override("panel", style)


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
