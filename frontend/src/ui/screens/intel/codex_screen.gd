class_name CodexScreen
extends BaseScreen
## Intel catalog. TAP FOR INFO stays mock this milestone.
## Visual: CODEX.DAT window on the Intel terminal desktop.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FALLBACK_THREAT := 1000
const FALLBACK_MATERIALS := 200

const UNITS: Array[Dictionary] = [
	{"name": "Firewall Sentinel", "role": "DEFENDER", "rarity": "COMMON", "glyph": "terminal", "file": "SENTINEL.DAT", "skill_id": "firewalls", "accent": "cyan"},
	{"name": "IDS Watcher", "role": "SCANNER", "rarity": "UNCOMMON", "glyph": "camera", "file": "WATCHER.DAT", "skill_id": "ports", "accent": "green"},
	{"name": "Honeypot Lure", "role": "TRAPPER", "rarity": "UNCOMMON", "glyph": "badge", "file": "LURE.DAT", "skill_id": "", "accent": "gold"},
	{"name": "SIEM Analyst", "role": "SUPPORT", "rarity": "RARE", "glyph": "codex", "file": "ANALYST.DAT", "skill_id": "", "accent": "magenta"},
	{"name": "Key Vault", "role": "SUPPORT", "rarity": "RARE", "glyph": "lock", "file": "VAULT.DAT", "skill_id": "", "accent": "magenta"},
	{"name": "Patch Kit", "role": "SUPPORT", "rarity": "COMMON", "glyph": "wrench", "file": "PATCH.DAT", "skill_id": "", "accent": "gold"},
]

const ENEMIES: Array[Dictionary] = [
	{"name": "Phish Kit", "role": "INTRUDER", "rarity": "COMMON", "glyph": "envelope", "file": "PHISH.DAT", "skill_id": "", "accent": "red"},
	{"name": "Brute Bot", "role": "INTRUDER", "rarity": "UNCOMMON", "glyph": "skull", "file": "BRUTE.DAT", "skill_id": "ports", "accent": "gold"},
	{"name": "Ransom Drop", "role": "INTRUDER", "rarity": "RARE", "glyph": "lock", "file": "RANSOM.DAT", "skill_id": "", "accent": "magenta"},
	{"name": "Packet Sniff", "role": "SCANNER", "rarity": "UNCOMMON", "glyph": "phone", "file": "SNIFF.DAT", "skill_id": "firewalls", "accent": "cyan"},
]

@onready var _os_bar: PanelContainer = %OsBar
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _ground: ColorRect = %Ground
@onready var _status_line: Label = %StatusLine
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _threat_box: PanelContainer = %ThreatBox
@onready var _materials_box: PanelContainer = %MaterialsBox
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _catalog_card: PanelContainer = %CatalogCard
@onready var _catalog_title_bar: PanelContainer = %CatalogTitleBar
@onready var _catalog_well: PanelContainer = %CatalogWell
@onready var _catalog_file: Label = %CatalogFile
@onready var _units_tab: Button = %UnitsTab
@onready var _enemies_tab: Button = %EnemiesTab
@onready var _weakness_banner: Label = %WeaknessBanner
@onready var _grid: GridContainer = %EntryGrid

var _pixel_font: Font
var _tab: StringName = &"units"
var _focus_skill: String = ""
var _blink_t: float = 0.0


func _ready() -> void:
	_load_font()
	_ground.color = Palette.FOREST_FLOOR
	_style_os_bar()
	_style_close_button()
	_style_resource_pill(_threat_box)
	_style_resource_pill(_materials_box)
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 14)
	_apply_label(_os_cursor, Palette.GREEN, 14)
	_apply_label(_status_line, Palette.TEXT_MUTED, 12)
	_apply_label(_catalog_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_weakness_banner, Palette.TEXT_PRIMARY, 11)
	_back_button.pressed.connect(_on_back_pressed)
	_units_tab.pressed.connect(func() -> void: _set_tab(&"units"))
	_enemies_tab.pressed.connect(func() -> void: _set_tab(&"enemies"))
	_weakness_banner.visible = false
	_set_tab(&"units")


func _process(delta: float) -> void:
	_blink_t += delta
	var on := fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)


func on_enter(args: Dictionary) -> void:
	set_process(true)
	_refresh_resources()
	var skill_id: String = str(args.get("skill_id", ""))
	load_topic(skill_id)


func on_resume() -> void:
	set_process(true)
	_refresh_resources()


func on_exit() -> void:
	set_process(false)
	# Vertical-slice remediation: any Codex visit clears exam locks.
	PlayerManager.locked_stages.clear()


func _on_back_pressed() -> void:
	PlayerManager.locked_stages.clear()
	Router.request_back()


func load_topic(skill_id: String) -> void:
	_focus_skill = skill_id
	if skill_id.is_empty():
		_weakness_banner.visible = false
		_set_tab(_tab)
		return
	_weakness_banner.visible = true
	_weakness_banner.text = "CRITICAL WEAKNESS: %s" % skill_id.to_upper()
	if _catalog_has_skill(UNITS, skill_id):
		_set_tab(&"units")
	elif _catalog_has_skill(ENEMIES, skill_id):
		_set_tab(&"enemies")
	else:
		_set_tab(_tab)


func _catalog_has_skill(source: Array[Dictionary], skill_id: String) -> bool:
	for i in source.size():
		if str(source[i].get("skill_id", "")) == skill_id:
			return true
	return false


func _set_tab(tab: StringName) -> void:
	_tab = tab
	var enemies: bool = tab == &"enemies"
	_catalog_file.text = "ENEMIES.DAT" if enemies else "UNITS.DAT"
	_status_line.text = "ENEMIES / INTRUDERS" if enemies else "UNITS / DEFENDERS"
	_style_chip(_units_tab, not enemies, false)
	_style_chip(_enemies_tab, enemies, true)
	_style_window(_catalog_card, Palette.RED if enemies else Palette.GOLD)
	_style_title_bar(_catalog_title_bar, Palette.RED_DEEP if enemies else Palette.ORANGE)
	_style_well(_catalog_well, Palette.RED if enemies else Palette.ORANGE)
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
	card.custom_minimum_size = Vector2(240, 248)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := _pixel_box(Palette.BG_HEADER, Palette.TEXT_PRIMARY if focused else accent, 0, 3 if focused else 2)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	card.add_theme_stylebox_override("normal", box)
	card.add_theme_stylebox_override("hover", box)
	card.add_theme_stylebox_override("pressed", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(_strip(str(entry.get("file", "FILE.DAT")), accent, Palette.TEXT_PRIMARY, 10, false))
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 8)
	column.add_child(pad)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 8)
	pad.add_child(body)
	var glyph := IntelPixelIcon.new()
	glyph.kind = _glyph_kind(str(entry.get("glyph", "codex")))
	glyph.monochrome = true
	glyph.custom_minimum_size = Vector2(40, 40)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(glyph)
	body.add_child(_card_label(str(entry.get("name", "")).to_upper(), Palette.TEXT_PRIMARY, 10, true, true))
	body.add_child(_role_chip(str(entry.get("role", "")), accent))
	body.add_child(_card_label(str(entry.get("rarity", "")), Palette.TEXT_PRIMARY, 9, true, false))
	column.add_child(_strip("TAP FOR INFO", Color(Palette.BG_DEEP, 0.55), Palette.TEXT_PRIMARY, 9, true))
	var entry_name: String = str(entry.get("name", ""))
	card.pressed.connect(func() -> void: print("[Codex] " + entry_name))
	return card


func _strip(text: String, fill: Color, color: Color, font_size: int, centered: bool) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	bar.add_theme_stylebox_override("panel", style)
	bar.add_child(_card_label(text, color, font_size, centered, false))
	return bar


func _role_chip(role: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _pixel_box(Color(Palette.BG_DEEP, 0.45), accent, 0, 2)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_card_label(role, Palette.TEXT_PRIMARY, 9, true, false))
	return chip


func _card_label(text: String, color: Color, font_size: int, centered: bool, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.max_lines_visible = 2
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
	_apply_label(label, color, font_size)
	return label


func _glyph_kind(name: String) -> IntelPixelIcon.Kind:
	match name:
		"terminal":
			return IntelPixelIcon.Kind.TERMINAL
		"camera":
			return IntelPixelIcon.Kind.CAMERA
		"badge":
			return IntelPixelIcon.Kind.BADGE
		"lock":
			return IntelPixelIcon.Kind.LOCK
		"wrench":
			return IntelPixelIcon.Kind.WRENCH
		"envelope":
			return IntelPixelIcon.Kind.ENVELOPE
		"skull":
			return IntelPixelIcon.Kind.SKULL
		"phone":
			return IntelPixelIcon.Kind.PHONE
		_:
			return IntelPixelIcon.Kind.CODEX


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


func _style_chip(tab: Button, selected: bool, threat: bool) -> void:
	var fill := Palette.FOREST_NIGHT
	var border := Palette.CYAN_DIM
	var text := Palette.TEXT_PRIMARY
	if selected:
		fill = Palette.RED if threat else Palette.GOLD
		border = Palette.TEXT_PRIMARY
		text = Palette.TEXT_PRIMARY if threat else Palette.TEXT_ON_GOLD
	var box := _pixel_box(fill, border, 0, 2)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	tab.add_theme_stylebox_override("normal", box)
	tab.add_theme_stylebox_override("hover", box)
	tab.add_theme_stylebox_override("pressed", box)
	tab.add_theme_color_override("font_color", text)
	if _pixel_font != null:
		tab.add_theme_font_override("font", _pixel_font)
	tab.add_theme_font_size_override("font_size", 12)
	tab.custom_minimum_size = Vector2(0, 48)


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
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	well.add_theme_stylebox_override("panel", style)


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
