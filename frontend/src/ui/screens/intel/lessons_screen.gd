class_name LessonsScreen
extends BaseScreen
## Sequential training modules. Progress is stored per signed-in participant.
## Visual: LESSONS.DAT window on the Intel terminal desktop.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const SWIPE_PX := 72.0

@onready var _os_bar: PanelContainer = %OsBar
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _ground: ColorRect = %Ground
@onready var _progress_track: ColorRect = %ProgressTrack
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _counter_label: Label = %CounterLabel
@onready var _module_card: PanelContainer = %ModuleCard
@onready var _module_title_bar: PanelContainer = %ModuleTitleBar
@onready var _module_well: PanelContainer = %ModuleWell
@onready var _module_file: Label = %ModuleFile
@onready var _module_glyph: IntelPixelIcon = %ModuleGlyph
@onready var _module_badge: Label = %ModuleBadge
@onready var _module_title: Label = %ModuleTitle
@onready var _module_desc: Label = %ModuleDesc
@onready var _lock_hint: Label = %LockHint
@onready var _progress_text: Label = %ProgressText
@onready var _percent_label: Label = %PercentLabel
@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _continue_button: Button = %ContinueButton
@onready var _chip_row: HBoxContainer = %ChipRow

var _pixel_font: Font
var _modules: Array[Dictionary] = []
var _index: int = 0
var _chips: Array[Button] = []
var _blink_t: float = 0.0
var _swipe_x: float = 0.0
var _swiping: bool = false


func _ready() -> void:
	_load_font()
	_modules = LessonCatalog.modules()
	_ground.color = Palette.FOREST_FLOOR
	_progress_track.color = Palette.BG_DEEP
	_style_os_bar()
	_style_close_button()
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 14)
	_apply_label(_os_cursor, Palette.GREEN, 14)
	_apply_label(_subtitle_label, Palette.TEXT_MUTED, 12)
	_apply_label(_counter_label, Palette.TEXT_PRIMARY, 12)
	_apply_label(_module_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_module_badge, Palette.TEXT_PRIMARY, 12)
	_apply_label(_module_title, Palette.TEXT_PRIMARY, 18)
	_apply_label(_module_desc, Palette.TEXT_PRIMARY, 12)
	_apply_label(_lock_hint, Palette.TEXT_PRIMARY, 12)
	_apply_label(_progress_text, Palette.TEXT_PRIMARY, 12)
	_apply_label(_percent_label, Palette.TEXT_PRIMARY, 12)
	_prepare_swipe_surface()
	_build_chips()
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_continue_button.pressed.connect(_on_continue_pressed)
	_module_card.gui_input.connect(_on_card_gui)
	_index = _first_playable_index()
	_select_module(_index)


func _process(delta: float) -> void:
	_blink_t += delta
	var on := fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)


func on_enter(_args: Dictionary) -> void:
	set_process(true)
	_index = _first_playable_index()
	_select_module(_index)


func on_resume() -> void:
	set_process(true)
	_select_module(_index)


func on_exit() -> void:
	set_process(false)


func _on_continue_pressed() -> void:
	if not _is_unlocked(_index):
		return
	var module: Dictionary = _modules[_index]
	var module_id := str(module.get("id", ""))
	Router.push(&"lesson_player", {
		"module_id": module_id,
		"review": _is_complete(_index),
	})


func _on_card_gui(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		if mouse.pressed:
			_swiping = true
			_swipe_x = mouse.position.x
		elif _swiping:
			_finish_swipe(mouse.position.x)
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_swiping = true
			_swipe_x = touch.position.x
		elif _swiping:
			_finish_swipe(touch.position.x)


func _finish_swipe(end_x: float) -> void:
	_swiping = false
	var delta_x := end_x - _swipe_x
	if delta_x <= -SWIPE_PX:
		_select_module(_index + 1)
	elif delta_x >= SWIPE_PX:
		_select_module(_index - 1)


func _select_module(next_index: int) -> void:
	if _modules.is_empty():
		return
	_index = clampi(next_index, 0, _modules.size() - 1)
	var module: Dictionary = _modules[_index]
	var module_id := str(module.get("id", ""))
	var locked: bool = not _is_unlocked(_index)
	var complete: bool = _is_complete(_index)
	var total: int = maxi(1, LessonCatalog.lesson_count(module_id))
	var done: int = mini(PlayerManager.get_lesson_progress(module_id), total)
	var pct: float = 0.0 if locked else clampf(float(done) / float(total), 0.0, 1.0)
	var accent_name := "muted" if locked else str(module.get("accent", "cyan"))
	var accent: Color = _accent_of(accent_name)
	_counter_label.text = "%02d/%02d" % [_index + 1, _modules.size()]
	_module_file.text = "MODULE_%02d.DAT" % (_index + 1)
	_module_title.text = str(module.get("title", "")).to_upper()
	_module_glyph.kind = IntelPixelIcon.Kind.LOCK if locked else IntelPixelIcon.Kind.BOOKS
	if locked:
		_module_badge.text = "LOCKED"
		_module_desc.text = str(module.get("desc", "")).to_upper()
		_lock_hint.visible = true
		_lock_hint.text = "COMPLETE MODULE %d TO UNLOCK" % _index
		_progress_text.text = "0/%d LESSONS" % total
		_percent_label.text = "LOCK"
		_continue_button.text = "LOCKED"
		_continue_button.disabled = true
	elif complete:
		_module_badge.text = "MODULE %d" % (_index + 1)
		_module_desc.text = str(module.get("desc", "")).to_upper()
		_lock_hint.visible = false
		_progress_text.text = "%d/%d LESSONS" % [done, total]
		_percent_label.text = "100%"
		_continue_button.text = "REVIEW  >"
		_continue_button.disabled = false
	else:
		_module_badge.text = "MODULE %d" % (_index + 1)
		_module_desc.text = str(module.get("desc", "")).to_upper()
		_lock_hint.visible = false
		_progress_text.text = "%d/%d LESSONS" % [done, total]
		_percent_label.text = "%d%%" % int(round(pct * 100.0))
		_continue_button.text = "CONTINUE  >"
		_continue_button.disabled = false
	_progress_fill.anchor_right = pct
	_progress_fill.offset_right = 0.0
	_progress_fill.color = Palette.TEXT_PRIMARY
	_style_window(_module_card, accent)
	_style_title_bar(_module_title_bar, _title_fill(accent_name))
	_style_well(_module_well, _well_fill(accent_name))
	_style_continue(accent, accent_name, locked, complete)
	for i in _chips.size():
		_style_chip(_chips[i], i == _index, i)


func _first_playable_index() -> int:
	for i in _modules.size():
		if _is_unlocked(i) and not _is_complete(i):
			return i
	if _modules.is_empty():
		return 0
	return _modules.size() - 1


func _is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var prev: Dictionary = _modules[index - 1]
	var prev_id := str(prev.get("id", ""))
	return PlayerManager.get_lesson_progress(prev_id) >= LessonCatalog.lesson_count(prev_id)


func _is_complete(index: int) -> bool:
	if index < 0 or index >= _modules.size():
		return false
	var module: Dictionary = _modules[index]
	var module_id := str(module.get("id", ""))
	return PlayerManager.get_lesson_progress(module_id) >= LessonCatalog.lesson_count(module_id)


func _prepare_swipe_surface() -> void:
	var nodes: Array[Node] = [_module_card]
	var i: int = 0
	while i < nodes.size():
		var node: Node = nodes[i]
		var kids: Array = node.get_children()
		for k in kids.size():
			var child: Node = kids[k] as Node
			if child != null:
				nodes.append(child)
		i += 1
	for n in nodes.size():
		var control := nodes[n] as Control
		if control == null:
			continue
		if control == _continue_button:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_module_card.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_chips() -> void:
	var existing: Array = _chip_row.get_children()
	for i in existing.size():
		var child: Node = existing[i] as Node
		if child != null:
			child.queue_free()
	_chips.clear()
	for i in _modules.size():
		var chip := Button.new()
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(96, 56)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.text = "M%d" % (i + 1)
		var captured: int = i
		chip.pressed.connect(func() -> void: _select_module(captured))
		_chip_row.add_child(chip)
		_chips.append(chip)
		if _pixel_font != null:
			chip.add_theme_font_override("font", _pixel_font)
		chip.add_theme_font_size_override("font_size", 12)


func _accent_of(name: String) -> Color:
	match name:
		"magenta":
			return Palette.MAGENTA
		"green":
			return Palette.GREEN
		"muted":
			return Palette.TEXT_MUTED
		_:
			return Palette.CYAN


func _title_fill(name: String) -> Color:
	match name:
		"magenta":
			return Palette.MAGENTA
		"green":
			return Palette.GREEN
		"muted":
			return Palette.TEXT_MUTED
		_:
			return Palette.CYAN_DIM


func _well_fill(name: String) -> Color:
	match name:
		"magenta":
			return Palette.MAGENTA
		"green":
			return Palette.GREEN
		"muted":
			return Palette.BG_PANEL
		_:
			return Palette.CYAN_DIM


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_os_bar() -> void:
	var style := _pixel_box(Color(Palette.BG_HEADER, 0.92), Palette.CYAN_DIM, 0, 2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_os_bar.add_theme_stylebox_override("panel", style)


func _style_close_button() -> void:
	_back_button.custom_minimum_size = Vector2(44, 32)
	var normal := _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	var hover := _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2)
	_back_button.add_theme_stylebox_override("normal", normal)
	_back_button.add_theme_stylebox_override("hover", hover)
	_back_button.add_theme_stylebox_override("pressed", hover)
	_back_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 12)


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box := _pixel_box(Palette.BG_HEADER, accent, 0, 3)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.75)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	bar.add_theme_stylebox_override("panel", style)


func _style_well(well: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, Color(Palette.TEXT_PRIMARY, 0.12), 0, 2)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 14.0
	well.add_theme_stylebox_override("panel", style)


func _style_continue(accent: Color, accent_name: String, locked: bool, complete: bool) -> void:
	var fill := Palette.RED_DEEP if locked else (Palette.GREEN if complete else accent)
	var text := Palette.TEXT_PRIMARY if locked or accent_name == "muted" else Palette.BG_DEEP
	if complete:
		text = Palette.BG_DEEP
	var box := _pixel_box(fill, Palette.BG_DEEP, 0, 0)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	_continue_button.add_theme_stylebox_override("normal", box)
	_continue_button.add_theme_stylebox_override("hover", box)
	_continue_button.add_theme_stylebox_override("pressed", box)
	_continue_button.add_theme_stylebox_override("disabled", box)
	_continue_button.add_theme_color_override("font_color", text)
	_continue_button.add_theme_color_override("font_disabled_color", text)
	if _pixel_font != null:
		_continue_button.add_theme_font_override("font", _pixel_font)
	_continue_button.add_theme_font_size_override("font_size", 16)
	_continue_button.custom_minimum_size = Vector2(0, 58)


func _style_chip(chip: Button, selected: bool, index: int) -> void:
	var locked: bool = not _is_unlocked(index)
	var complete: bool = _is_complete(index)
	var accent: Color = _accent_of(str(_modules[index].get("accent", "cyan")))
	var fill := Color(Palette.FOREST_NIGHT, 0.88)
	var border := Palette.CYAN_DIM
	var text := Palette.TEXT_MUTED
	if locked:
		fill = Color(Palette.FOREST_NIGHT, 0.92)
		border = Palette.RED if selected else Palette.TEXT_MUTED
		text = Palette.RED if selected else Palette.TEXT_MUTED
		chip.text = "M%d" % (index + 1)
	elif complete:
		fill = Palette.GREEN if selected else Color(Palette.GREEN, 0.55)
		border = Palette.TEXT_PRIMARY if selected else Palette.GREEN
		text = Palette.BG_DEEP
		chip.text = "M%d" % (index + 1)
	else:
		fill = accent if selected else Color(Palette.FOREST_NIGHT, 0.88)
		border = Palette.TEXT_PRIMARY if selected else Palette.CYAN_DIM
		text = Palette.BG_DEEP if selected else Palette.TEXT_PRIMARY
		chip.text = "M%d" % (index + 1)
	var box := _pixel_box(fill, border, 0, 2)
	chip.add_theme_stylebox_override("normal", box)
	chip.add_theme_stylebox_override("hover", box)
	chip.add_theme_stylebox_override("pressed", box)
	chip.add_theme_color_override("font_color", text)


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
