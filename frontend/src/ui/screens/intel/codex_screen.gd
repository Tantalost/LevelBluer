class_name CodexScreen
extends BaseScreen
## Unit and enemy reference. Stats are read from ContentDB JSON. No completion.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FALLBACK_THREAT := 1000
const FALLBACK_MATERIALS := 200

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
@onready var _unit_list: ItemList = %UnitList
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_body: RichTextLabel = %StatsBody

var _pixel_font: Font
var _tab: StringName = &"units"
var _focus_skill: String = ""
var _current_unit_id: String = ""
var _blink_t: float = 0.0


func _ready() -> void:
	_load_font()
	_ground.color = Palette.FOREST_FLOOR
	_style_os_bar()
	_style_close_button()
	_style_resource_pill(_threat_box)
	_style_resource_pill(_materials_box)
	_style_item_list()
	_style_stats_body()
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 14)
	_apply_label(_os_cursor, Palette.GREEN, 14)
	_apply_label(_status_line, Palette.TEXT_MUTED, 12)
	_apply_label(_catalog_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_weakness_banner, Palette.TEXT_PRIMARY, 11)
	_apply_label(_stats_title, Palette.TEXT_PRIMARY, 14)
	_back_button.pressed.connect(_on_back_pressed)
	_units_tab.pressed.connect(func() -> void: _set_tab(&"units"))
	_enemies_tab.pressed.connect(func() -> void: _set_tab(&"enemies"))
	_unit_list.item_selected.connect(_on_unit_selected)
	_weakness_banner.visible = false
	_set_tab(&"units")


func _process(delta: float) -> void:
	_blink_t += delta
	var on: bool = fmod(_blink_t, 1.05) < 0.58
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
	if _tab_has_skill(&"units", skill_id):
		_set_tab(&"units")
	elif _tab_has_skill(&"enemies", skill_id):
		_set_tab(&"enemies")
	else:
		_set_tab(_tab)


func _tab_has_skill(tab: StringName, skill_id: String) -> bool:
	var ids: Array[String] = ContentDB.get_all_tower_ids() if tab == &"units" else ContentDB.get_all_enemy_ids()
	for i in ids.size():
		if _unit_matches_skill(tab, ids[i], skill_id):
			return true
	return false


func _unit_matches_skill(tab: StringName, unit_id: String, skill_id: String) -> bool:
	if skill_id.is_empty():
		return false
	var needle: String = skill_id.to_lower()
	if tab == &"units":
		var tower: Dictionary = ContentDB.get_tower(unit_id)
		var req: String = str(tower.get("req_skill", "")).to_lower()
		if req == needle or req.begins_with(needle) or needle.begins_with(req):
			return not req.is_empty()
		return unit_id.to_lower() == needle
	return unit_id.to_lower() == needle


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
	_rebuild_list()


func _rebuild_list() -> void:
	var ids: Array[String] = ContentDB.get_all_enemy_ids() if _tab == &"enemies" else ContentDB.get_all_tower_ids()
	_unit_list.clear()
	var select_index: int = 0
	for i in ids.size():
		var unit_id: String = ids[i]
		var label: String = _list_label(_tab, unit_id)
		_unit_list.add_item(label)
		_unit_list.set_item_metadata(i, unit_id)
		if _unit_matches_skill(_tab, unit_id, _focus_skill):
			select_index = i
		elif unit_id == _current_unit_id:
			select_index = i
	if ids.is_empty():
		_current_unit_id = ""
		_stats_title.text = "NO ENTRIES"
		_stats_body.text = "No authored units in ContentDB."
		return
	_unit_list.select(select_index)
	_show_unit(str(_unit_list.get_item_metadata(select_index)))


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= _unit_list.item_count:
		return
	_show_unit(str(_unit_list.get_item_metadata(index)))


func _list_label(tab: StringName, unit_id: String) -> String:
	if tab == &"units":
		var tower: Dictionary = ContentDB.get_tower(unit_id)
		var tower_name: String = str(tower.get("name", unit_id))
		if tower_name.is_empty():
			tower_name = unit_id
		return tower_name.to_upper()
	return unit_id.to_upper()


func _show_unit(unit_id: String) -> void:
	_current_unit_id = unit_id
	if _tab == &"units":
		_show_tower(unit_id)
	else:
		_show_enemy(unit_id)


func _show_tower(unit_id: String) -> void:
	var raw: Dictionary = _raw_entry(ContentDB.towers, unit_id)
	var stats: Dictionary = ContentDB.get_tower(unit_id)
	var display_name: String = str(stats.get("name", unit_id))
	if display_name.is_empty():
		display_name = unit_id
	_stats_title.text = display_name.to_upper()
	_stats_body.text = _format_stats(raw, [
		"name",
		"damage",
		"fire_rate",
		"splash_radius",
		"slow_factor",
		"slow_duration",
		"cost",
		"role",
		"req_skill",
		"color",
	])


func _show_enemy(unit_id: String) -> void:
	var raw: Dictionary = _raw_entry(ContentDB.enemies, unit_id)
	_stats_title.text = unit_id.to_upper()
	_stats_body.text = _format_stats(raw, [
		"hp",
		"speed",
		"bounty",
		"color",
	])


func _raw_entry(source: Dictionary, unit_id: String) -> Dictionary:
	if unit_id.is_empty() or not source.has(unit_id):
		return {}
	var stored: Variant = source[unit_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func _format_stats(raw: Dictionary, preferred_order: PackedStringArray) -> String:
	if raw.is_empty():
		return "No stats authored for this unit."
	var lines: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for i in preferred_order.size():
		var key: String = String(preferred_order[i])
		if not raw.has(key):
			continue
		seen[key] = true
		lines.append(_stat_line(key, raw[key]))
	var leftover: Array = raw.keys()
	leftover.sort()
	for j in leftover.size():
		var extra_key: String = str(leftover[j])
		if seen.has(extra_key):
			continue
		lines.append(_stat_line(extra_key, raw[extra_key]))
	return "\n".join(lines)


func _stat_line(key: String, value: Variant) -> String:
	var label: String = key.to_upper().replace("_", " ")
	return "[b]%s[/b]: %s" % [label, str(value)]


func _style_item_list() -> void:
	var panel: StyleBoxFlat = _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2)
	panel.content_margin_left = 8.0
	panel.content_margin_right = 8.0
	panel.content_margin_top = 8.0
	panel.content_margin_bottom = 8.0
	var selected: StyleBoxFlat = _pixel_box(Palette.GOLD, Palette.TEXT_PRIMARY, 0, 2)
	selected.content_margin_left = 8.0
	selected.content_margin_right = 8.0
	selected.content_margin_top = 8.0
	selected.content_margin_bottom = 8.0
	_unit_list.add_theme_stylebox_override("panel", panel)
	_unit_list.add_theme_stylebox_override("selected", selected)
	_unit_list.add_theme_stylebox_override("hovered", selected)
	_unit_list.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_unit_list.add_theme_color_override("font_hovered_color", Palette.BG_DEEP)
	_unit_list.add_theme_color_override("font_selected_color", Palette.BG_DEEP)
	_unit_list.add_theme_constant_override("v_separation", 8)
	if _pixel_font != null:
		_unit_list.add_theme_font_override("font", _pixel_font)
	_unit_list.add_theme_font_size_override("font_size", 11)


func _style_stats_body() -> void:
	_stats_body.add_theme_color_override("default_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_stats_body.add_theme_font_override("normal_font", _pixel_font)
		_stats_body.add_theme_font_override("bold_font", _pixel_font)
	_stats_body.add_theme_font_size_override("normal_font_size", 12)
	_stats_body.add_theme_font_size_override("bold_font_size", 12)


func _style_chip(tab: Button, selected: bool, threat: bool) -> void:
	var fill: Color = Palette.FOREST_NIGHT
	var border: Color = Palette.CYAN_DIM
	var text: Color = Palette.TEXT_PRIMARY
	if selected:
		fill = Palette.RED if threat else Palette.GOLD
		border = Palette.TEXT_PRIMARY
		text = Palette.TEXT_PRIMARY if threat else Palette.TEXT_ON_GOLD
	var box: StyleBoxFlat = _pixel_box(fill, border, 0, 2)
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
	var style: StyleBoxFlat = _pixel_box(Color(Palette.BG_HEADER, 0.92), Palette.CYAN_DIM, 0, 2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_os_bar.add_theme_stylebox_override("panel", style)


func _style_resource_pill(box: PanelContainer) -> void:
	var style: StyleBoxFlat = _pixel_box(Color(Palette.FOREST_NIGHT, 0.9), Palette.TEXT_MUTED, 0, 1)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	box.add_theme_stylebox_override("panel", style)


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
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	well.add_theme_stylebox_override("panel", style)


func _refresh_resources() -> void:
	var threat: int = AuthService.threat_points()
	var materials: int = PlayerManager.credits
	_threat_value.text = str(threat if threat >= 0 else FALLBACK_THREAT)
	_materials_value.text = str(maxi(0, materials))


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
