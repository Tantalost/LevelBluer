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
var _list_panel: PanelContainer
var _detail_panel: PanelContainer
var _compact: bool = false
var _mobile_details: bool = false
var _matchup_detail: Label
var _matchup_buttons: Array[Button] = []
var _tactics_body: Label
var _tactics_toggle: Button
var _entry_tween: Tween
var _back_button: Button

func _ready() -> void:
	var shell := UI.shell(self, "CODEX / FIELD GUIDE", _on_back_pressed)
	_back_button = shell.back
	var layout: VBoxContainer = shell.layout
	var strip := HBoxContainer.new()
	layout.add_child(strip)
	strip.hide()
	var intro := UI.label("KNOW THE THREAT. BUILD THE COUNTER.", 20, UI.TEAL)
	intro.size_flags_horizontal = SIZE_EXPAND_FILL
	strip.add_child(intro)
	_resource_label = UI.label("", 20, UI.MUTED)
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resource_label.hide() # Currency is unrelated to browsing the field guide.
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
	_list_panel = left
	left.add_theme_stylebox_override("panel", UI.journal_box(Color("#F3ECD6"), Color("#B7AE96"), 22))
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.36
	var catalog := UI.column(left, 14)
	catalog.add_child(UI.label("FIELD COLLECTION", 20, Color("#101623"), true))
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
	_count = UI.label("", 19, Color("#52616B"))
	catalog.add_child(_count)
	_roster = UI.scroll_column(catalog)
	(_roster.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	catalog.add_child(UI.label("Explore the roster. Find your counter.", 22, Color("#52616B")))
	var right := UI.panel(_panes, Color("101e28"))
	_detail_panel = right
	right.add_theme_stylebox_override("panel", UI.journal_box(Color("#0A1730"), Color("#34566C"), 22))
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.64
	_detail = UI.scroll_column(right)
	_detail.add_theme_constant_override("separation", 12)
	(_detail.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	resized.connect(_layout)
	_refresh_resources()
	_set_tab(&"units")

func on_enter(args: Dictionary) -> void:
	_mobile_details = false
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
	_mobile_details = not skill_id.is_empty()
	_layout()

func _set_tab(tab: StringName) -> void:
	_mobile_details = false
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
		var button: Button = UI.button("", _pick_entry.bind(id))
		button.custom_minimum_size.y = 116
		button.tooltip_text = str(data.name)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 24)
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_right = -12
		row.offset_top = 12
		row.offset_bottom = -12
		row.add_theme_constant_override("separation", 14)
		button.add_child(row)
		row.add_child(_specimen(_tab, id, true))
		var copy: VBoxContainer = UI.column(row, 6)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_child(UI.label("#%03d / %s" % [all_ids.find(id) + 1, data.type], 20, UI.TEAL))
		copy.add_child(UI.label(str(data.name), 27))
		copy.minimum_size_changed.connect(func() -> void: button.custom_minimum_size.y = maxf(116.0, copy.get_combined_minimum_size().y + 24))
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
		_matchup_buttons.clear()
		_mobile_details = false
		_layout()
		return
	if _current_unit_id not in _visible_ids:
		_current_unit_id = _visible_ids[0]
	_show_unit(_current_unit_id)
	_layout()

func _specimen(tab: StringName, id: String, small: bool) -> Control:
	var specimen: Control = Specimen.new()
	specimen.tab = tab
	specimen.unit_id = id
	specimen.compact = small
	specimen.accent = UI.TEAL if tab == &"units" else UI.GOLD
	return specimen

func _pick_entry(id: String) -> void:
	_mobile_details = true
	_show_unit(id)
	_layout()
	if _compact:
		_back_button.grab_focus()

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
		button.add_theme_stylebox_override("normal", UI.journal_box(Color("234039") if selected else UI.PANEL, UI.TEAL if selected else Color("3b626a"), 10))
		button.add_theme_stylebox_override("hover", UI.journal_box(Color("#153B37"), UI.TEAL, 10))
		button.add_theme_stylebox_override("pressed", UI.journal_box(Color("#153B37"), UI.GOLD, 10))
		button.add_theme_color_override("font_color", UI.TEAL if selected else UI.TEXT)
	var data := Field.entry(_tab, id)
	var accent := UI.TEAL if _tab == &"units" else UI.GOLD
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	_detail.add_child(heading)
	_preview = _specimen(_tab, id, false)
	heading.add_child(_preview)
	var identity := UI.column(heading, 10)
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.add_child(UI.label("%s / #%03d" % ["DEFENDER" if _tab == &"units" else "THREAT", Field.ids(_tab).find(id) + 1], 16, accent, true))
	identity.add_child(UI.label(str(data.name).to_upper(), 32))
	identity.add_child(UI.label(str(data.type) + "  /  " + str(data.subtitle), 23, accent))
	var rotate: Button = UI.button("ROTATE VIEW", _rotate_preview)
	rotate.disabled = _tab == &"enemies" and id == "basic"
	if rotate.disabled:
		rotate.text = "ROUND PROFILE"
	identity.add_child(rotate)
	_add_stats(data.stats)
	_detail.add_child(UI.label("PICK A MATCHUP", 18, accent, true))
	var match_grid := HBoxContainer.new()
	match_grid.add_theme_constant_override("separation", 10)
	_detail.add_child(match_grid)
	_matchup_rows = Field.matchups(_tab, id)
	_matchup_buttons.clear()
	for index: int in _matchup_rows.size():
		_add_matchup(match_grid, _matchup_rows[index], index)
	_matchup_detail = UI.label("", 25, UI.TEXT)
	_detail.add_child(_matchup_detail)
	_select_matchup(0)
	var note := "Multipliers affect damage before whole-number rounding. Base stats shown; upgrades and stage scaling may change combat values."
	if id == "sandbox" and _tab == &"units":
		note = "Slow is movement-speed reduction while inside the field, not damage. Pair Sandbox with a damage-dealing tower."
	elif _tab == &"enemies":
		note = "Damage values are incoming tower damage multipliers. Slow values are movement-speed reduction, not damage resistance."
	_tactics_toggle = UI.button("+ TACTICS / HOW TO USE THIS", _toggle_tactics)
	_detail.add_child(_tactics_toggle)
	_tactics_body = UI.label(str(data.tactics) + "\n\n" + note + "\n\nPreview sizes are normalized; rings do not show actual attack range.", 25, UI.MUTED)
	_tactics_body.hide()
	_detail.add_child(_tactics_body)
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
	_layout()
	if _entry_tween != null:
		_entry_tween.kill()
	_detail.modulate.a = 1.0
	if not SettingsService.reduced_motion:
		_detail.modulate.a = 0.35
		_entry_tween = create_tween()
		_entry_tween.tween_property(_detail, "modulate:a", 1.0, 0.18)

func _rotate_preview() -> void:
	if is_instance_valid(_preview):
		_preview.rotate_view()

func _toggle_tactics() -> void:
	_tactics_body.visible = not _tactics_body.visible
	_tactics_toggle.text = ("- " if _tactics_body.visible else "+ ") + "TACTICS / HOW TO USE THIS"

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

func _matchup_caption(row: Dictionary) -> String:
	var label: String = "NEUTRAL"
	if _tab == &"units":
		if row.tier == "strong":
			label = "STRONG AGAINST"
		elif row.tier == "weak":
			label = "LESS EFFECTIVE"
	else:
		if row.tier == "strong":
			label = "VULNERABLE TO"
		elif row.tier == "weak":
			label = "RESISTS" if row.kind == "damage" else "REDUCED SLOW"
	return label

func _add_matchup(parent: Control, row: Dictionary, index: int) -> void:
	var button: Button = UI.button("", _select_matchup.bind(index))
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(96, 128)
	button.tooltip_text = str(row.name) + ": " + str(row.effect)
	parent.add_child(button)
	var art: Control = _specimen(&"enemies" if _tab == &"units" else &"units", str(row.id), true)
	art.name = "MatchupArt"
	art.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	art.offset_top = 8
	art.offset_bottom = 80
	button.add_child(art)
	var name_label: Label = UI.label(str(row.name), 23, UI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -56
	name_label.offset_bottom = -8
	name_label.offset_left = 8
	name_label.offset_right = -8
	name_label.name = "MatchupName"
	button.add_child(name_label)
	button.add_theme_stylebox_override("hover", UI.journal_box(Color("#153B37"), UI.TEAL, 10))
	_matchup_buttons.append(button)

func _select_matchup(index: int) -> void:
	if index < 0 or index >= _matchup_rows.size():
		return
	var row: Dictionary = _matchup_rows[index]
	var ink: Color = UI.TEAL
	if row.tier != "neutral":
		ink = GOOD if (row.tier == "strong") == (_tab == &"units") else BAD
	_matchup_detail.text = "%s / %s\n%s" % [_matchup_caption(row), row.name, row.effect]
	if str(row.kind) == "slow":
		_matchup_detail.text += " / Slows movement, not health."
	_matchup_detail.add_theme_color_override("font_color", ink)
	for number: int in _matchup_buttons.size():
		_matchup_buttons[number].add_theme_stylebox_override("normal", UI.journal_box(Color("#153B37") if number == index else UI.BG, ink if number == index else Color("#34566C"), 10))

func _layout() -> void:
	if not is_instance_valid(_detail_panel):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	_compact = size.x * physical < 1000.0
	_list_panel.visible = not _compact or not _mobile_details
	_detail_panel.visible = not _compact or _mobile_details
	_back_button.text = "< INDEX" if _compact and _mobile_details else "< BACK"
	UI.fit_touch(self)
	if is_instance_valid(_preview):
		_preview.custom_minimum_size = Vector2(maxf(180, 80 / physical), maxf(164, 80 / physical))
	for button: Button in _matchup_buttons:
		var art: Control = button.get_node("MatchupArt")
		var copy: Label = button.get_node("MatchupName")
		var art_height: float = maxf(64, 40 / physical)
		art.custom_minimum_size.y = art_height
		art.offset_bottom = 8 + art_height
		copy.offset_top = -maxf(44, 34 / physical)
		button.custom_minimum_size.y = art_height + maxf(44, 34 / physical) + 16
	_search.custom_minimum_size.y = maxf(48, 48 / physical)
	_search.add_theme_font_size_override("font_size", maxi(22, ceili(16 / physical)))

func can_go_back() -> bool:
	if _compact and _mobile_details:
		_mobile_details = false
		_layout()
		_search.grab_focus()
		return false
	return true

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
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var button: Button = _entry_buttons.get(_current_unit_id)
	var scroll := _roster.get_parent() as ScrollContainer
	if is_instance_valid(button) and scroll.is_ancestor_of(button):
		scroll.ensure_control_visible(button)

func _open_source(url: String) -> void:
	# Only authored public education links; never data-driven arbitrary schemes.
	if url.begins_with("https://csrc.nist.gov/") or url.begins_with("https://www.cisa.gov/"):
		OS.shell_open(url)

func _on_back_pressed() -> void:
	if not can_go_back():
		return
	# Preserve existing remediation behavior.
	PlayerManager.locked_stages.clear()
	Router.request_back()

func on_exit() -> void:
	if _entry_tween != null:
		_entry_tween.kill()
	PlayerManager.locked_stages.clear()

func _exit_tree() -> void:
	if _entry_tween != null:
		_entry_tween.kill()
