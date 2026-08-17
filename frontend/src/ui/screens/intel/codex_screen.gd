class_name CodexScreen
extends BaseScreen
## Intel Hub catalog. TAP FOR INFO and simulations stay mock this milestone.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FALLBACK_THREAT := 1000
const FALLBACK_MATERIALS := 200

const UNITS: Array[Dictionary] = [
	{"name": "Firewall Sentinel", "role": "DEFENDER", "rarity": "COMMON", "icon": "S", "skill_id": "firewalls", "accent": "cyan"},
	{"name": "IDS Watcher", "role": "SCANNER", "rarity": "UNCOMMON", "icon": "I", "skill_id": "ports", "accent": "green"},
	{"name": "Honeypot Lure", "role": "TRAPPER", "rarity": "UNCOMMON", "icon": "H", "skill_id": "", "accent": "gold"},
	{"name": "SIEM Analyst", "role": "SUPPORT", "rarity": "RARE", "icon": "A", "skill_id": "", "accent": "magenta"},
	{"name": "Key Vault", "role": "SUPPORT", "rarity": "RARE", "icon": "K", "skill_id": "", "accent": "magenta"},
	{"name": "Patch Kit", "role": "SUPPORT", "rarity": "COMMON", "icon": "P", "skill_id": "", "accent": "gold"},
]

const ENEMIES: Array[Dictionary] = [
	{"name": "Phish Kit", "role": "INTRUDER", "rarity": "COMMON", "icon": "F", "skill_id": "", "accent": "red"},
	{"name": "Brute Bot", "role": "INTRUDER", "rarity": "UNCOMMON", "icon": "B", "skill_id": "ports", "accent": "gold"},
	{"name": "Ransom Drop", "role": "INTRUDER", "rarity": "RARE", "icon": "R", "skill_id": "", "accent": "magenta"},
	{"name": "Packet Sniff", "role": "SCANNER", "rarity": "UNCOMMON", "icon": "N", "skill_id": "firewalls", "accent": "cyan"},
]

@onready var _background: ColorRect = $Background
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _gold_rule: ColorRect = %GoldRule
@onready var _threat_box: PanelContainer = %ThreatBox
@onready var _materials_box: PanelContainer = %MaterialsBox
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _units_tab: Button = %UnitsTab
@onready var _enemies_tab: Button = %EnemiesTab
@onready var _weakness_banner: Label = %WeaknessBanner
@onready var _grid: GridContainer = %EntryGrid

var _pixel_font: Font
var _tab: StringName = &"units"
var _focus_skill: String = ""


func _ready() -> void:
	_load_font()
	_background.color = Palette.BG_DEEP
	_gold_rule.color = Palette.GOLD
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 18)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_weakness_banner, Palette.GOLD, 9)
	_style_circle_button(_back_button)
	_style_resource_pill(_threat_box)
	_style_resource_pill(_materials_box)
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_units_tab.pressed.connect(func() -> void: _set_tab(&"units"))
	_enemies_tab.pressed.connect(func() -> void: _set_tab(&"enemies"))
	_weakness_banner.visible = false
	_set_tab(&"units")


func on_enter(args: Dictionary) -> void:
	_refresh_resources()
	var skill_id: String = str(args.get("skill_id", ""))
	load_topic(skill_id)


func on_resume() -> void:
	_refresh_resources()


func load_topic(skill_id: String) -> void:
	_focus_skill = skill_id
	if skill_id.is_empty():
		_weakness_banner.visible = false
		_rebuild_grid()
		return
	_weakness_banner.visible = true
	_weakness_banner.text = "Critical Weakness: " + skill_id.capitalize()
	_rebuild_grid()


func _set_tab(tab: StringName) -> void:
	_tab = tab
	_style_tab(_units_tab, tab == &"units")
	_style_tab(_enemies_tab, tab == &"enemies")
	_rebuild_grid()


func _rebuild_grid() -> void:
	var kids: Array = _grid.get_children()
	for i in kids.size():
		var node: Node = kids[i] as Node
		if node == null:
			continue
		_grid.remove_child(node)
		node.queue_free()
	var source: Array[Dictionary] = UNITS if _tab == &"units" else ENEMIES
	for i in source.size():
		_grid.add_child(_make_entry_card(source[i]))


func _make_entry_card(entry: Dictionary) -> Button:
	var accent: Color = _accent_of(str(entry.get("accent", "cyan")))
	var skill_id: String = str(entry.get("skill_id", ""))
	var focused: bool = not _focus_skill.is_empty() and skill_id == _focus_skill
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(220, 210)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.BG_PANEL, 0.4)
	box.border_color = accent
	box.set_border_width_all(3 if focused else 2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("normal", box)
	card.add_theme_stylebox_override("hover", box)
	card.add_theme_stylebox_override("pressed", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(_card_label(str(entry.get("icon", "?")), Palette.TEXT_PRIMARY, 22, false))
	column.add_child(_card_label(str(entry.get("name", "")), Palette.TEXT_PRIMARY, 9, true))
	column.add_child(_role_pill(str(entry.get("role", "")), accent))
	column.add_child(_card_label(str(entry.get("rarity", "")), Palette.TEXT_MUTED, 7, true))
	column.add_child(_card_label("TAP FOR INFO", Palette.TEXT_MUTED, 6, true))
	var entry_name: String = str(entry.get("name", ""))
	card.pressed.connect(func() -> void: print("[Codex] " + entry_name))
	return card


func _role_pill(role: String, accent: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.18)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", style)
	var label := _card_label(role, accent, 7, true)
	pill.add_child(label)
	return pill


func _card_label(text: String, color: Color, font_size: int, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label(label, color, font_size)
	return label


func _accent_of(name: String) -> Color:
	match name:
		"green":
			return Palette.GREEN
		"gold":
			return Palette.GOLD
		"magenta":
			return Palette.MAGENTA
		"red":
			return Palette.RED
		_:
			return Palette.CYAN


func _style_tab(tab: Button, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.CYAN if selected else Color(Palette.BG_PANEL, 0.9)
	box.border_color = Palette.CYAN if selected else Palette.CYAN_DIM
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	tab.add_theme_stylebox_override("normal", box)
	tab.add_theme_stylebox_override("hover", box)
	tab.add_theme_stylebox_override("pressed", box)
	tab.add_theme_color_override("font_color", Palette.BG_DEEP if selected else Palette.TEXT_SECONDARY)
	if _pixel_font != null:
		tab.add_theme_font_override("font", _pixel_font)
	tab.add_theme_font_size_override("font_size", 10)


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


func _style_circle_button(button: Button) -> void:
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


func _refresh_resources() -> void:
	var threat: int = AuthService.threat_points()
	var materials: int = AuthService.materials()
	_threat_value.text = str(threat if threat >= 0 else FALLBACK_THREAT)
	_materials_value.text = str(materials if materials >= 0 else FALLBACK_MATERIALS)


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
