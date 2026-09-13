class_name CodexScreen
extends BaseScreen
## Read-only field guide. Matchups come from combat; real-world notes are separate.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Field = preload("res://src/ui/screens/intel/codex_field_data.gd")
const Specimen = preload("res://src/ui/screens/intel/codex_specimen.gd")
const GOOD := Color("88e5a2")
const BAD := Color("ff9295")
var _tab: StringName = &"units"
var _current_unit_id := ""
var _focus_skill := ""
var _search: LineEdit
var _roster: VBoxContainer
var _detail: VBoxContainer
var _panes: HBoxContainer
var _units_tab: Button
var _enemies_tab: Button
var _count: Label
var _banner: Label
var _resource_label: Label
var _real_body: VBoxContainer
var _real_toggle: Button
var _entry_buttons: Dictionary = {}
var _visible_ids: Array[String] = []
var _matchup_rows: Array[Dictionary] = []
var _preview: Control

func _ready() -> void:
	var shell := UI.shell(self, "CODEX / FIELD GUIDE", _on_back_pressed)
	var layout: VBoxContainer = shell.layout
	var strip := HBoxContainer.new()
	layout.add_child(strip)
	var intro := UI.label("KNOW THE THREAT. BUILD THE COUNTER.", 20, UI.TEAL)
	intro.size_flags_horizontal = SIZE_EXPAND_FILL
	strip.add_child(intro)
	_resource_label = UI.label("", 20, UI.MUTED)
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strip.add_child(_resource_label)
	_banner = UI.label("", 22, UI.GOLD)
	_banner.hide()
	layout.add_child(_banner)
	_panes = HBoxContainer.new()
	_panes.add_theme_constant_override("separation", 24)
	_panes.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(_panes)
	var left := UI.panel(_panes)
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.29
	var catalog := UI.column(left, 14)
	catalog.add_child(UI.label("FIELD INDEX", 16, UI.TEAL, true))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	catalog.add_child(tabs)
	_units_tab = UI.button("Defenders", _set_tab.bind(&"units"))
	_enemies_tab = UI.button("Threats", _set_tab.bind(&"enemies"))
	for button in [_units_tab, _enemies_tab]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		tabs.add_child(button)
	_search = LineEdit.new()
	_search.placeholder_text = "Search name or type..."
	_search.custom_minimum_size.y = 46
	_search.add_theme_font_override("font", UI.FONT)
	_search.add_theme_font_size_override("font_size", 22)
	_search.add_theme_stylebox_override("normal", UI.box(UI.BG, Color("3b626a"), 10))
	_search.add_theme_stylebox_override("focus", UI.box(UI.BG, UI.TEAL, 10))
	_search.add_theme_color_override("font_color", UI.TEXT)
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_list())
	catalog.add_child(_search)
	_count = UI.label("", 19, UI.MUTED)
	catalog.add_child(_count)
	_roster = UI.scroll_column(catalog)
	catalog.add_child(UI.label("Reference entries are always available. Browsing does not unlock towers.", 20, UI.MUTED))
	var right := UI.panel(_panes, Color("101e28"))
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.71
	_detail = UI.scroll_column(right)
	_detail.add_theme_constant_override("separation", 18)
	_refresh_resources()
	_set_tab(&"units")

func on_enter(args: Dictionary) -> void:
	_refresh_resources()
	load_topic(str(args.get("skill_id", "")))

func on_resume() -> void:
	_refresh_resources()

func _refresh_resources() -> void:
	_resource_label.text = "%d CR  /  %d THREAT" % [maxi(0, PlayerManager.credits), maxi(0, AuthService.threat_points())]

func load_topic(skill_id: String) -> void:
	_focus_skill = skill_id
	_banner.visible = not skill_id.is_empty()
	_banner.text = "RECOMMENDED REVIEW / " + skill_id.replace("_", " ").to_upper()
	if skill_id.is_empty():
		_set_tab(_tab)
		return
	if skill_id.to_lower().contains("phish"):
		_tab = &"enemies"
		_current_unit_id = "fast"
	else:
		for tab in [&"units", &"enemies"]:
			for id in Field.ids(tab):
				var req := str(ContentDB.get_tower(id).get("req_skill", "")) if tab == &"units" else ""
				if id == skill_id or (not req.is_empty() and (req.begins_with(skill_id) or skill_id.begins_with(req))):
					_tab = tab
					_current_unit_id = id
	_search.text = ""
	_set_tab(_tab)

func _set_tab(tab: StringName) -> void:
	_tab = tab
	_search.text = ""
	for button in [_units_tab, _enemies_tab]:
		var selected: bool = (button == _units_tab) == (tab == &"units")
		button.add_theme_stylebox_override("normal", UI.box(UI.TEAL if selected else UI.BG, UI.TEAL if selected else Color("3b626a"), 10))
		button.add_theme_color_override("font_color", UI.BG if selected else UI.TEXT)
	_rebuild_list()

func _rebuild_list() -> void:
	UI.clear(_roster)
	_entry_buttons.clear()
	_visible_ids.clear()
	var all_ids := Field.ids(_tab)
	var query := _search.text.strip_edges().to_lower()
	for id in all_ids:
		var data := Field.entry(_tab, id)
		if not query.is_empty() and not ("%s %s %s" % [id, data.name, data.type]).to_lower().contains(query):
			continue
		_visible_ids.append(id)
		var button := UI.button("#%03d  %s\n%s" % [all_ids.find(id) + 1, str(data.name).to_upper(), data.type], _show_unit.bind(id))
		button.custom_minimum_size.y = 78
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 24)
		_roster.add_child(button)
		_entry_buttons[id] = button
	_count.text = "%02d / %02d ENTRIES" % [_visible_ids.size(), all_ids.size()]
	if _visible_ids.is_empty():
		_current_unit_id = ""
		_roster.add_child(UI.label("No matching entries. Try another name or type.", 24, UI.MUTED))
		UI.clear(_detail)
		_detail.add_child(UI.label("NO SIGNAL MATCH", 22, UI.GOLD, true))
		_detail.add_child(UI.label("Clear the search to return to the field index.", 26, UI.MUTED))
		_preview = null
		_real_body = null
		_real_toggle = null
		_matchup_rows.clear()
		return
	if _current_unit_id not in _visible_ids:
		_current_unit_id = _visible_ids[0]
	_show_unit(_current_unit_id)

func _show_unit(id: String) -> void:
	if id not in _visible_ids:
		return
	_current_unit_id = id
	_reveal_selected.call_deferred()
	UI.clear(_detail)
	(_detail.get_parent() as ScrollContainer).scroll_vertical = 0
	for key in _entry_buttons:
		var button: Button = _entry_buttons[key]
		var selected: bool = key == id
		button.add_theme_stylebox_override("normal", UI.box(Color("234039") if selected else UI.PANEL, UI.TEAL if selected else Color("3b626a"), 10))
		button.add_theme_color_override("font_color", UI.TEAL if selected else UI.TEXT)
	var data := Field.entry(_tab, id)
	var accent := UI.TEAL if _tab == &"units" else UI.GOLD
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	_detail.add_child(heading)
	_preview = Specimen.new()
	_preview.tab = _tab
	_preview.unit_id = id
	_preview.accent = accent
	heading.add_child(_preview)
	var identity := UI.column(heading, 10)
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.add_child(UI.label("%s / #%03d" % ["DEFENDER" if _tab == &"units" else "THREAT", Field.ids(_tab).find(id) + 1], 16, accent, true))
	identity.add_child(UI.label(str(data.name).to_upper(), 32))
	identity.add_child(UI.label(str(data.type) + "  /  " + str(data.subtitle), 23, accent))
	identity.add_child(UI.label(str(data.tactics), 24, UI.MUTED))
	_add_stats(data.stats)
	_detail.add_child(UI.label("TYPE MATCHUPS", 16, accent, true))
	var match_grid := HBoxContainer.new()
	match_grid.add_theme_constant_override("separation", 10)
	_detail.add_child(match_grid)
	_matchup_rows = Field.matchups(_tab, id)
	for row in _matchup_rows:
		_add_matchup(match_grid, row)
	var note := "Multipliers affect damage before whole-number rounding. Base stats shown; upgrades and stage scaling may change combat values."
	if id == "sandbox" and _tab == &"units":
		note = "Slow is movement-speed reduction while inside the field, not damage. Pair Sandbox with a damage-dealing tower."
	elif _tab == &"enemies":
		note = "Damage values are incoming tower damage multipliers. Slow values are movement-speed reduction, not damage resistance."
	_detail.add_child(UI.label(note, 20, UI.MUTED))
	_real_toggle = UI.button("+ REAL-WORLD INTEL / " + str(data.real_title).to_upper(), _toggle_real)
	_real_toggle.add_theme_font_size_override("font_size", 23)
	_detail.add_child(_real_toggle)
	_real_body = UI.column(_detail)
	_real_body.hide()
	_real_body.add_child(UI.label("BEYOND THE BATTLEFIELD", 14, UI.GOLD, true))
	_real_body.add_child(UI.label(str(data.real_body), 25))
	_real_body.add_child(UI.label("Game types and damage bonuses are teaching metaphors, not real-world cybersecurity classifications.", 21, UI.MUTED))
	if not str(data.url).is_empty():
		var source := UI.button("Read source: " + str(data.source) + "  >", _open_source.bind(str(data.url)))
		source.add_theme_font_size_override("font_size", 21)
		source.tooltip_text = "Opens the reference in your browser. Requires internet."
		_real_body.add_child(source)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	_detail.add_child(nav)
	var previous := UI.button("< PREVIOUS", _step.bind(-1))
	var next := UI.button("NEXT ENTRY >", _step.bind(1))
	previous.disabled = _visible_ids.find(id) <= 0
	next.disabled = _visible_ids.find(id) >= _visible_ids.size() - 1
	for button in [previous, next]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		nav.add_child(button)

func _add_stats(stats: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_detail.add_child(row)
	var values: Array
	if _tab == &"units":
		values = [["DAMAGE", str(stats.get("damage", 0))], ["SHOTS / SEC", "%.2f" % float(stats.get("fire_rate", 0))], ["DEPLOY", "%s G" % str(stats.get("cost", 0))]]
	else:
		values = [["BASE HP", str(stats.get("hp", 0))], ["SPEED", "%.0f" % float(stats.get("speed", 0))], ["BOUNTY", "%s G" % str(stats.get("bounty", 0))]]
	for pair in values:
		var panel := UI.panel(row, UI.BG)
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color("29424b"), 10))
		var col := UI.column(panel, 6)
		col.add_child(UI.label(pair[0], 17, UI.MUTED))
		col.add_child(UI.label(pair[1], 28))

func _add_matchup(parent: Control, row: Dictionary) -> void:
	var ink := UI.MUTED
	var label := "NEUTRAL"
	if _tab == &"units":
		if row.tier == "strong":
			label = "STRONG AGAINST"
			ink = GOOD
		elif row.tier == "weak":
			label = "LESS EFFECTIVE"
			ink = BAD
	else:
		if row.tier == "strong":
			label = "VULNERABLE TO"
			ink = BAD
		elif row.tier == "weak":
			label = "RESISTS" if row.kind == "damage" else "REDUCED SLOW"
			ink = GOOD
	var panel := UI.panel(parent, UI.BG)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(ink, 0.6), 10))
	var col := UI.column(panel, 8)
	col.add_child(UI.label(label, 17, ink))
	col.add_child(UI.label(str(row.name), 25))
	col.add_child(UI.label(str(row.effect), 24, ink))

func _toggle_real() -> void:
	if not is_instance_valid(_real_body):
		return
	_real_body.visible = not _real_body.visible
	var data := Field.entry(_tab, _current_unit_id)
	_real_toggle.text = ("- " if _real_body.visible else "+ ") + "REAL-WORLD INTEL / " + str(data.real_title).to_upper()

func _step(direction: int) -> void:
	var index := _visible_ids.find(_current_unit_id) + direction
	if index >= 0 and index < _visible_ids.size():
		_show_unit(_visible_ids[index])

func _reveal_selected() -> void:
	# Search/tab changes can replace buttons before the deferred layout finishes.
	var button: Button = _entry_buttons.get(_current_unit_id)
	var scroll := _roster.get_parent() as ScrollContainer
	if is_instance_valid(button) and scroll.is_ancestor_of(button):
		scroll.ensure_control_visible(button)

func _open_source(url: String) -> void:
	# Only authored public education links; never data-driven arbitrary schemes.
	if url.begins_with("https://csrc.nist.gov/") or url.begins_with("https://www.cisa.gov/"):
		OS.shell_open(url)

func _on_back_pressed() -> void:
	# Preserve existing remediation behavior.
	PlayerManager.locked_stages.clear()
	Router.request_back()

func on_exit() -> void:
	PlayerManager.locked_stages.clear()
