class_name IntelHubScreen
extends BaseScreen
## Dashboard Intel destination. Lessons and Codex are pushed on top of this hub.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FALLBACK_THREAT := 1000
const FALLBACK_MATERIALS := 200

@onready var _background: ColorRect = $Background
@onready var _back_button: Button = %BackButton
@onready var _header_title: Label = %HeaderTitle
@onready var _gold_rule: ColorRect = %GoldRule
@onready var _threat_box: PanelContainer = %ThreatBox
@onready var _materials_box: PanelContainer = %MaterialsBox
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _hub_title: Label = %HubTitle
@onready var _lessons_card: PanelContainer = %LessonsCard
@onready var _codex_card: PanelContainer = %CodexCard
@onready var _lessons_title: Label = %LessonsTitle
@onready var _lessons_sub: Label = %LessonsSub
@onready var _lessons_enter: Button = %LessonsEnter
@onready var _codex_title: Label = %CodexTitle
@onready var _codex_sub: Label = %CodexSub
@onready var _codex_enter: Button = %CodexEnter
@onready var _diamond: ColorRect = %Diamond

var _pixel_font: Font


func _ready() -> void:
	_load_font()
	_background.color = Palette.BG_DEEP
	_gold_rule.color = Palette.GOLD
	_diamond.color = Palette.GOLD
	_diamond.pivot_offset = Vector2(5, 5)
	_diamond.rotation_degrees = 45.0
	_style_back_button()
	_style_resource_pill(_threat_box)
	_style_resource_pill(_materials_box)
	_style_card(_lessons_card, Palette.CYAN)
	_style_card(_codex_card, Palette.GOLD)
	_style_enter_button(_lessons_enter, Palette.CYAN)
	_style_enter_button(_codex_enter, Palette.GOLD)
	_style_sub_pill(_lessons_sub, Palette.CYAN)
	_style_sub_pill(_codex_sub, Palette.GOLD)
	_apply_label(_header_title, Palette.GOLD, 16)
	_apply_label(_hub_title, Palette.GOLD, 22)
	_apply_label(_lessons_title, Palette.CYAN, 18)
	_apply_label(_lessons_sub, Palette.CYAN, 8)
	_apply_label(_codex_title, Palette.GOLD, 18)
	_apply_label(_codex_sub, Palette.GOLD, 8)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_make_card_click_through(_lessons_card)
	_make_card_click_through(_codex_card)
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_lessons_card.gui_input.connect(_on_card_gui.bind(&"lessons"))
	_codex_card.gui_input.connect(_on_card_gui.bind(&"codex"))


func on_enter(_args: Dictionary) -> void:
	_refresh_resources()


func on_resume() -> void:
	_refresh_resources()


func _on_card_gui(event: InputEvent, screen_id: StringName) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	Router.push(screen_id)


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


func _style_resource_pill(box: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.BG_PANEL, 0.9)
	style.border_color = Palette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	box.add_theme_stylebox_override("panel", style)


func _style_back_button() -> void:
	_back_button.custom_minimum_size = Vector2(40, 40)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_PANEL, 0.9)
	box.border_color = Palette.CYAN_DIM
	box.set_border_width_all(2)
	box.set_corner_radius_all(20)
	_back_button.add_theme_stylebox_override("normal", box)
	_back_button.add_theme_stylebox_override("hover", box)
	_back_button.add_theme_stylebox_override("pressed", box)
	_back_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 14)


func _style_card(card: PanelContainer, accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_PANEL, 0.35)
	box.border_color = accent
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 28.0
	box.content_margin_bottom = 20.0
	card.add_theme_stylebox_override("panel", box)


func _style_sub_pill(label: Label, accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = accent
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	label.add_theme_stylebox_override("normal", box)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_enter_button(button: Button, accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = accent
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", accent)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 10)


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
