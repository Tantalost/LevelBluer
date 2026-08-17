class_name IntelHubScreen
extends BaseScreen
## Dashboard Intel destination. Lessons and Codex are pushed on top of this hub.
## Visual: terminal OS windows sitting on a night-forest desktop.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FALLBACK_THREAT := 1000
const FALLBACK_MATERIALS := 200

@onready var _os_bar: PanelContainer = %OsBar
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _ground: ColorRect = %Ground
@onready var _status_line: Label = %StatusLine
@onready var _back_button: Button = %BackButton
@onready var _header_title: Label = %HeaderTitle
@onready var _threat_box: PanelContainer = %ThreatBox
@onready var _materials_box: PanelContainer = %MaterialsBox
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _lessons_card: PanelContainer = %LessonsCard
@onready var _codex_card: PanelContainer = %CodexCard
@onready var _lessons_file: Label = %LessonsFile
@onready var _codex_file: Label = %CodexFile
@onready var _lessons_title_bar: PanelContainer = %LessonsTitleBar
@onready var _codex_title_bar: PanelContainer = %CodexTitleBar
@onready var _lessons_well: PanelContainer = %LessonsWell
@onready var _codex_well: PanelContainer = %CodexWell
@onready var _lessons_title: Label = %LessonsTitle
@onready var _lessons_sub: Label = %LessonsSub
@onready var _lessons_enter: Button = %LessonsEnter
@onready var _codex_title: Label = %CodexTitle
@onready var _codex_sub: Label = %CodexSub
@onready var _codex_enter: Button = %CodexEnter

var _pixel_font: Font
var _blink_t: float = 0.0


func _ready() -> void:
	_load_font()
	_ground.color = Palette.FOREST_FLOOR
	_style_os_bar()
	_style_close_button()
	_style_resource_pill(_threat_box)
	_style_resource_pill(_materials_box)
	_style_window(_lessons_card, Palette.CYAN, false)
	_style_window(_codex_card, Palette.GOLD, false)
	_style_title_bar(_lessons_title_bar, Palette.CYAN_DIM)
	_style_title_bar(_codex_title_bar, Palette.ORANGE)
	_style_well(_lessons_well, Palette.CYAN_DIM, false)
	_style_well(_codex_well, Palette.ORANGE, false)
	_style_enter_button(_lessons_enter, Palette.CYAN, Palette.BG_DEEP, false)
	_style_enter_button(_codex_enter, Palette.GOLD, Palette.TEXT_ON_GOLD, false)
	_apply_label(_header_title, Palette.TEXT_PRIMARY, 14)
	_apply_label(_os_cursor, Palette.GREEN, 14)
	_apply_label(_status_line, Palette.TEXT_MUTED, 12)
	_apply_label(_lessons_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_codex_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_lessons_title, Palette.TEXT_PRIMARY, 20)
	_apply_label(_lessons_sub, Palette.TEXT_PRIMARY, 12)
	_apply_label(_codex_title, Palette.TEXT_PRIMARY, 20)
	_apply_label(_codex_sub, Palette.TEXT_PRIMARY, 12)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_make_card_click_through(_lessons_card)
	_make_card_click_through(_codex_card)
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_lessons_card.gui_input.connect(_on_card_gui.bind(&"lessons"))
	_codex_card.gui_input.connect(_on_card_gui.bind(&"codex"))
	_lessons_card.mouse_entered.connect(_set_lessons_hover.bind(true))
	_lessons_card.mouse_exited.connect(_set_lessons_hover.bind(false))
	_codex_card.mouse_entered.connect(_set_codex_hover.bind(true))
	_codex_card.mouse_exited.connect(_set_codex_hover.bind(false))


func _process(delta: float) -> void:
	_blink_t += delta
	var on := fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)


func on_enter(_args: Dictionary) -> void:
	set_process(true)
	_refresh_resources()


func on_resume() -> void:
	set_process(true)
	_refresh_resources()


func on_exit() -> void:
	set_process(false)


func _on_card_gui(event: InputEvent, screen_id: StringName) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	Router.push(screen_id)


func _set_lessons_hover(hovered: bool) -> void:
	_style_window(_lessons_card, Palette.CYAN, hovered)
	_style_well(_lessons_well, Palette.CYAN if hovered else Palette.CYAN_DIM, hovered)
	_style_enter_button(_lessons_enter, Palette.CYAN, Palette.BG_DEEP, hovered)


func _set_codex_hover(hovered: bool) -> void:
	_style_window(_codex_card, Palette.GOLD, hovered)
	_style_well(_codex_well, Palette.GOLD if hovered else Palette.ORANGE, hovered)
	_style_enter_button(_codex_enter, Palette.GOLD, Palette.TEXT_ON_GOLD, hovered)


func _make_card_click_through(card: PanelContainer) -> void:
	var nodes: Array[Node] = [card]
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
		if n == 0:
			continue
		var control := nodes[n] as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_resources() -> void:
	var threat: int = AuthService.threat_points()
	var materials: int = AuthService.materials()
	_threat_value.text = str(threat if threat >= 0 else FALLBACK_THREAT)
	_materials_value.text = str(materials if materials >= 0 else FALLBACK_MATERIALS)


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


func _style_resource_pill(box: PanelContainer) -> void:
	var style := _pixel_box(Color(Palette.FOREST_NIGHT, 0.9), Palette.TEXT_MUTED, 0, 1)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	box.add_theme_stylebox_override("panel", style)


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


func _style_window(card: PanelContainer, accent: Color, hovered: bool) -> void:
	var box := _pixel_box(Palette.BG_HEADER, accent, 0, 3)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.75)
	box.shadow_size = 2 if hovered else 1
	box.shadow_offset = Vector2(8, 8) if hovered else Vector2(5, 5)
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	bar.add_theme_stylebox_override("panel", style)


func _style_well(well: PanelContainer, fill: Color, hovered: bool) -> void:
	var style := _pixel_box(fill, Color(Palette.TEXT_PRIMARY, 0.22 if hovered else 0.12), 0, 2)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 14.0
	well.add_theme_stylebox_override("panel", style)


func _style_enter_button(button: Button, fill: Color, text: Color, hovered: bool) -> void:
	var bg := fill if hovered else Color(fill, 0.92)
	var box := _pixel_box(bg, Palette.BG_DEEP, 0, 0)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", text)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(0, 58)


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
