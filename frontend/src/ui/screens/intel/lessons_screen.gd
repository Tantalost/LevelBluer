class_name LessonsScreen
extends BaseScreen
## Mock module carousel. Real lesson playback is out of scope.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const MODULES: Array[Dictionary] = [
	{
		"title": "Phishing & Email Threats",
		"desc": "Identify malicious emails and spoofed senders",
		"icon": "E",
		"done": 4,
		"total": 5,
		"accent": "cyan",
	},
	{
		"title": "Social Engineering",
		"desc": "Spot impersonation and pressure tactics",
		"icon": "S",
		"done": 1,
		"total": 5,
		"accent": "magenta",
	},
	{
		"title": "Mobile Threats",
		"desc": "Recognize malicious apps and smishing",
		"icon": "M",
		"done": 0,
		"total": 5,
		"accent": "green",
	},
	{
		"title": "Workplace Security",
		"desc": "Physical access, tailgating, and clean desks",
		"icon": "W",
		"done": 0,
		"total": 5,
		"accent": "cyan",
	},
	{
		"title": "OSINT Basics",
		"desc": "What public data reveals about a target",
		"icon": "O",
		"done": 0,
		"total": 5,
		"accent": "muted",
	},
]

@onready var _background: ColorRect = $Background
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _counter_label: Label = %CounterLabel
@onready var _header_rule: ColorRect = %HeaderRule
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _module_card: PanelContainer = %ModuleCard
@onready var _module_badge: Label = %ModuleBadge
@onready var _module_icon: Label = %ModuleIcon
@onready var _module_title: Label = %ModuleTitle
@onready var _module_desc: Label = %ModuleDesc
@onready var _progress_text: Label = %ProgressText
@onready var _percent_label: Label = %PercentLabel
@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _continue_button: Button = %ContinueButton
@onready var _chip_row: HBoxContainer = %ChipRow

var _pixel_font: Font
var _index: int = 0
var _chips: Array[Button] = []


func _ready() -> void:
	_load_font()
	_background.color = Palette.BG_DEEP
	_header_rule.color = Palette.CYAN_DIM
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 18)
	_apply_label(_subtitle_label, Palette.CYAN, 9)
	_apply_label(_counter_label, Palette.TEXT_PRIMARY, 10)
	_apply_label(_module_badge, Palette.CYAN, 8)
	_apply_label(_module_icon, Palette.TEXT_PRIMARY, 22)
	_apply_label(_module_title, Palette.TEXT_PRIMARY, 16)
	_apply_label(_module_desc, Palette.TEXT_SECONDARY, 9)
	_apply_label(_progress_text, Palette.TEXT_SECONDARY, 8)
	_apply_label(_percent_label, Palette.CYAN, 8)
	_style_circle_button(_back_button, "<")
	_style_circle_button(_prev_button, "<")
	_style_circle_button(_next_button, ">")
	_style_continue()
	_build_chips()
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_prev_button.pressed.connect(func() -> void: _select_module(_index - 1))
	_next_button.pressed.connect(func() -> void: _select_module(_index + 1))
	_continue_button.pressed.connect(_on_continue_pressed)
	_select_module(0)


func on_enter(_args: Dictionary) -> void:
	_select_module(_index)


func _on_continue_pressed() -> void:
	var module: Dictionary = MODULES[_index]
	print("[Lessons] Continue " + str(module.get("title", "")))


func _select_module(next_index: int) -> void:
	if MODULES.is_empty():
		return
	_index = posmod(next_index, MODULES.size())
	var module: Dictionary = MODULES[_index]
	var accent: Color = _accent_of(str(module.get("accent", "cyan")))
	var done: int = int(module.get("done", 0))
	var total: int = maxi(1, int(module.get("total", 5)))
	var pct: float = clampf(float(done) / float(total), 0.0, 1.0)
	_counter_label.text = "%02d/%02d" % [_index + 1, MODULES.size()]
	_module_badge.text = "MODULE %d" % (_index + 1)
	_module_icon.text = str(module.get("icon", "?"))
	_module_title.text = str(module.get("title", ""))
	_module_desc.text = str(module.get("desc", ""))
	_progress_text.text = "%d/%d Lessons" % [done, total]
	_percent_label.text = "%d%%" % int(round(pct * 100.0))
	_progress_fill.anchor_right = pct
	_progress_fill.offset_right = 0.0
	_style_card(accent)
	_module_badge.add_theme_color_override("font_color", accent)
	_percent_label.add_theme_color_override("font_color", accent)
	_progress_fill.color = accent
	_style_continue()
	for i in _chips.size():
		_style_chip(_chips[i], i == _index, _chip_accent(i))


func _build_chips() -> void:
	for child in _chip_row.get_children():
		child.queue_free()
	_chips.clear()
	for i in MODULES.size():
		var chip := Button.new()
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(88, 72)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var module: Dictionary = MODULES[i]
		chip.text = str(module.get("icon", "?")) + "\nM%d" % (i + 1)
		var captured: int = i
		chip.pressed.connect(func() -> void: _select_module(captured))
		_chip_row.add_child(chip)
		_chips.append(chip)
		if _pixel_font != null:
			chip.add_theme_font_override("font", _pixel_font)
		chip.add_theme_font_size_override("font_size", 9)


func _chip_accent(index: int) -> Color:
	if index < 0 or index >= MODULES.size():
		return Palette.CYAN_DIM
	return _accent_of(str(MODULES[index].get("accent", "cyan")))


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


func _style_card(accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_PANEL, 0.45)
	box.border_color = accent
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	_module_card.add_theme_stylebox_override("panel", box)


func _style_continue() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Palette.CYAN
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	_continue_button.add_theme_stylebox_override("normal", box)
	_continue_button.add_theme_stylebox_override("hover", box)
	_continue_button.add_theme_stylebox_override("pressed", box)
	_continue_button.add_theme_color_override("font_color", Palette.CYAN)
	if _pixel_font != null:
		_continue_button.add_theme_font_override("font", _pixel_font)
	_continue_button.add_theme_font_size_override("font_size", 12)


func _style_chip(chip: Button, selected: bool, accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_PANEL, 0.55)
	box.border_color = accent if selected else Palette.CYAN_DIM
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	chip.add_theme_stylebox_override("normal", box)
	chip.add_theme_stylebox_override("hover", box)
	chip.add_theme_stylebox_override("pressed", box)
	chip.add_theme_color_override("font_color", Palette.TEXT_PRIMARY if selected else Palette.TEXT_SECONDARY)
	chip.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.72)


func _style_circle_button(button: Button, caption: String) -> void:
	button.text = caption
	button.custom_minimum_size = Vector2(40, 40)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_PANEL, 0.9)
	box.border_color = Palette.CYAN_DIM
	box.set_border_width_all(2)
	box.set_corner_radius_all(20)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 14)


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
