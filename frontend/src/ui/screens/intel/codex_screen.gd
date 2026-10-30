class_name CodexScreen
extends BaseScreen
## Investigation archive and combat field guide, projected from existing saves.
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
var _section: StringName = &"characters"
var _section_buttons: Dictionary[StringName, Button] = {}
var _archive_scroll: ScrollContainer
var _archive_body: VBoxContainer
var _character_grid: GridContainer
var _character_buttons: Dictionary[String, Button] = {}
var _selected_character: String = ""
var _story_snapshot: Dictionary = {}
var _catalog_heading: Label
var _catalog_hint: Label
var _expanded: Dictionary[String, bool] = {}
var _chapter: int = 1
var _chapter_buttons: Array[Button] = []
var _library_home: bool = true
var _library_grid: GridContainer
var _sections: HBoxContainer
var _archive_search: LineEdit
var _archive_query: String = ""
var _selected_record: String = ""
var _record_origin: String = ""
var _library_buttons: Dictionary[StringName, Button] = {}
var _record_buttons: Dictionary[String, Button] = {}

func _ready() -> void:
	var shell := UI.shell(self, "CODEX", _on_back_pressed)
	_back_button = shell.back
	var layout: VBoxContainer = shell.layout
	var school_button: Button = UI.button("School Content", func() -> void: Router.push(&"school_content"))
	school_button.custom_minimum_size.x = 200
	shell.title.get_parent().add_child(school_button)
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
	_sections = HBoxContainer.new()
	_sections.add_theme_constant_override("separation", 8)
	layout.add_child(_sections)
	for section: StringName in [&"characters", &"evidence", &"combat"]:
		var section_button: Button = UI.button({&"characters":"Characters", &"evidence":"Evidence", &"combat":"Combat Intel"}[section], _set_section.bind(section))
		section_button.size_flags_horizontal = SIZE_EXPAND_FILL
		_sections.add_child(section_button)
		_section_buttons[section] = section_button
	_archive_search = LineEdit.new()
	_archive_search.placeholder_text = "Search this collection..."
	_archive_search.clear_button_enabled = true
	_archive_search.add_theme_font_override("font", UI.FONT)
	_archive_search.add_theme_color_override("font_color", Color("F3ECD6"))
	_archive_search.add_theme_stylebox_override("normal", UI.box(Color("0A1730"), Color("173058"), 12))
	_archive_search.add_theme_stylebox_override("focus", UI.box(Color("0A1730"), Color("4FE0D4"), 12))
	_archive_search.text_changed.connect(_filter_archive)
	layout.add_child(_archive_search)
	_archive_body = UI.scroll_column(layout)
	_archive_scroll = _archive_body.get_parent() as ScrollContainer
	_archive_body.add_theme_constant_override("separation", 10)
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
	_catalog_heading = UI.label("FIELD COLLECTION", 20, Color("#101623"), true)
	catalog.add_child(_catalog_heading)
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
	_catalog_hint = UI.label("Explore the roster. Find your counter.", 22, Color("#52616B"))
	catalog.add_child(_catalog_hint)
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
	_show_library()
	AuthService.progress_changed.connect(_refresh_archive)
	PlayerManager.progress_changed.connect(_refresh_archive)
	AuthService.session_changed.connect(_archive_session_changed)
	AssetManager.sync_finished.connect(_archive_art_ready)

func on_enter(args: Dictionary) -> void:
	_mobile_details = false
	_refresh_resources()
	var skill_id: String = str(args.get("skill_id", ""))
	if skill_id.is_empty():
		_show_library()
	else: load_topic(skill_id)

func on_resume() -> void:
	_refresh_resources()
	_refresh_archive()

func _set_section(section: StringName) -> void:
	if section not in [&"characters", &"evidence", &"combat"]: return
	_library_home = false
	_selected_record = ""
	_record_origin = ""
	_archive_query = ""
	_archive_search.text = ""
	_archive_search.hide()
	_sections.show()
	_expanded.clear()
	_section = section
	_panes.visible = section == &"combat"
	_archive_scroll.visible = section != &"combat"
	_banner.visible = section == &"combat" and not _focus_skill.is_empty()
	for key: StringName in _section_buttons:
		UI.style_button(_section_buttons[key], key == section)
	if section != &"combat":
		_selected_character = ""
		_refresh_archive()
		_archive_scroll.scroll_vertical = 0
	_layout()

func _archive_session_changed(_signed_in: bool) -> void:
	_selected_character = ""
	_chapter = 1
	_show_library()

func _show_library() -> void:
	_library_home = true
	_focus_skill = ""
	_selected_character = ""
	_selected_record = ""
	_record_origin = ""
	_archive_query = ""
	_archive_search.text = ""
	_expanded.clear()
	_sections.hide()
	_panes.hide()
	_banner.hide()
	_archive_search.hide()
	_archive_scroll.show()
	_refresh_archive()
	_archive_scroll.set_deferred("scroll_vertical", 0)

func _filter_archive(query: String) -> void:
	_archive_query = query.strip_edges().to_lower()
	_refresh_archive()
	_archive_scroll.set_deferred("scroll_vertical", 0)

func _matches_archive(text: String) -> bool:
	return _archive_query.is_empty() or text.to_lower().contains(_archive_query)

func _build_library() -> void:
	_archive_body.add_child(UI.label("YOUR FIELD LIBRARY", 30, Color("F3ECD6"), true))
	_archive_body.add_child(UI.label("Meet the people. Revisit the clues. Understand the threats.", 22, Color("8FF0E6")))
	_library_grid = GridContainer.new()
	_library_grid.add_theme_constant_override("h_separation", 16)
	_library_grid.add_theme_constant_override("v_separation", 16)
	_archive_body.add_child(_library_grid)
	var found: int = 0
	var total: int = 0
	var people: Array[String] = []
	for number: int in range(1, Field.CHAPTERS.size() + 1):
		var chapter: GDScript = Field.chapter_definition(number)
		var snapshot: Dictionary = Field.story_snapshot(PlayerManager.story_checkpoint(chapter.ID, false), number)
		var progress: Dictionary = Field.discovery_progress(snapshot)
		found += int(progress.found)
		total += int(progress.total)
		if _chapter_available(number):
			for id: String in Field.character_ids(snapshot):
				if id not in people: people.append(id)
	var collections: Array[Dictionary] = [
		{"id":&"characters", "number":"01", "title":"Characters", "copy":"People, relationships and what you have learned about them.", "count":"%d files available" % people.size(), "preview":"John / Eric / Jobert"},
		{"id":&"evidence", "number":"02", "title":"Evidence", "copy":"Messages, suspicious details and the sources behind each observation.", "count":"%d / %d discovered" % [found, total], "preview":"Emails / Links / Timelines"},
		{"id":&"combat", "number":"03", "title":"Combat Intel", "copy":"Explore defenders and threats, then read their real-world notes.", "count":"%d reference entries" % (Field.ids(&"units").size() + Field.ids(&"enemies").size()), "preview":"Defenders / Threats / Tactics"}
	]
	for item: Dictionary in collections:
		var card: Button = _library_card(_library_grid, str(item.number) + " / COLLECTION", str(item.title), str(item.copy), str(item.count), _set_section.bind(item.id))
		card.accessibility_name = "Open " + str(item.title) + ". " + str(item.count)
		_library_buttons[item.id] = card
		var content: VBoxContainer = card.get_child(0) as VBoxContainer
		content.add_child(UI.label(str(item.preview), 18, Color("8FF0E6")))
	_archive_body.add_child(UI.label("STORY ARCHIVE / MODULE 01", 18, Color("8FF0E6")))
	_archive_body.add_child(UI.label("New records appear as you investigate. Return here whenever you want to review a discovery.", 22, UI.MUTED))

func _library_card(parent: Control, eyebrow: String, title: String, copy: String, footer: String, callback: Callable) -> Button:
	var card: Button = UI.button("", callback)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var style: StyleBoxFlat = UI.journal_box(Color("102040"), Color("173058"), 18)
	style.border_width_left = 5
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("hover", UI.journal_box(Color("153B37"), Color("4FE0D4"), 18))
	parent.add_child(card)
	var content: VBoxContainer = UI.column(card, 12)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(UI.label(eyebrow, 18, Color("8FF0E6")))
	var heading: Label = UI.label(title, 30, Color("F3ECD6"))
	heading.set_meta("library_heading", true)
	content.add_child(heading)
	content.add_child(UI.label(copy, 22, Color("F3ECD6")))
	content.add_child(UI.label(footer + "  >", 18, Color("8FF0E6")))
	# Button is not a Container: place its non-interactive contents and size it to fit.
	content.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	content.offset_left = 22
	content.offset_right = -22
	content.offset_top = 18
	var fit: Callable = func() -> void:
		if not is_instance_valid(card): return
		var height: float = content.get_combined_minimum_size().y
		content.offset_bottom = content.offset_top + height
		card.custom_minimum_size.y = height + 36
	content.resized.connect(fit)
	content.minimum_size_changed.connect(fit)
	return card

func _archive_art_ready(_success: bool) -> void:
	_refresh_archive()

func _refresh_archive() -> void:
	if not is_instance_valid(_archive_body): return
	var definition: GDScript = Field.chapter_definition(_chapter)
	_story_snapshot = Field.story_snapshot(PlayerManager.story_checkpoint(definition.ID, false), _chapter)
	var scroll_position: int = _archive_scroll.scroll_vertical
	UI.clear(_archive_body)
	_character_buttons.clear()
	_chapter_buttons.clear()
	_library_buttons.clear()
	_record_buttons.clear()
	_character_grid = null
	_library_grid = null
	_archive_search.visible = not _library_home and _section != &"combat" and _selected_character.is_empty() and _selected_record.is_empty()
	if _library_home:
		_build_library()
		_layout()
		return
	if _section == &"combat": return
	if not _selected_record.is_empty():
		_build_record_page()
		_layout()
		return
	if not _selected_character.is_empty():
		_build_character_profile()
		_layout()
		_archive_scroll.set_deferred("scroll_vertical", scroll_position)
		return
	var module_row: HBoxContainer = HBoxContainer.new()
	module_row.add_theme_constant_override("separation", 12)
	_archive_body.add_child(module_row)
	for first_chapter: int in [1,6]:
		var module_button: Button = UI.button("MODULE %d" % (1 if first_chapter == 1 else 2), _select_chapter.bind(first_chapter), (_chapter <= 5) == (first_chapter == 1))
		module_button.disabled = not _chapter_available(first_chapter)
		module_button.size_flags_horizontal = SIZE_EXPAND_FILL
		module_row.add_child(module_button)
	var chapter_row: HBoxContainer = HBoxContainer.new()
	chapter_row.add_theme_constant_override("separation", 8)
	_archive_body.add_child(chapter_row)
	for number: int in range(1, Field.CHAPTERS.size() + 1):
		if (number <= 5) != (_chapter <= 5): continue
		var chapter: GDScript = Field.chapter_definition(number)
		var button: Button = UI.button("CH %02d" % chapter.NUMBER, _select_chapter.bind(number), number == _chapter)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.disabled = not _chapter_available(number)
		button.accessibility_name = "%s: %s. %s" % [Field.chapter_label(number), chapter.TITLE, "Available" if not button.disabled else "Continue the story to unlock"]
		chapter_row.add_child(button)
		_chapter_buttons.append(button)
	var discovery: Dictionary = Field.discovery_progress(_story_snapshot)
	var collection_heading: Label = UI.label("%s / %d of %d discovered" % [definition.TITLE, discovery.found, discovery.total], 22, Color("8FF0E6"))
	collection_heading.name = "CollectionSummary"
	_archive_body.add_child(collection_heading)
	if _section == &"characters" and _selected_character.is_empty():
		_character_grid = GridContainer.new()
		_character_grid.add_theme_constant_override("h_separation", 16)
		_character_grid.add_theme_constant_override("v_separation", 16)
		_archive_body.add_child(_character_grid)
		for id: String in Field.character_ids(_story_snapshot):
			var data: Dictionary = Field.character(id, _story_snapshot)
			if not _matches_archive(str(data.name) + " " + str(data.role)): continue
			var card: Button = UI.button("", _open_character.bind(id))
			card.accessibility_name = "Open " + str(data.name) + " character file"
			card.size_flags_horizontal = SIZE_EXPAND_FILL
			card.add_theme_stylebox_override("normal", UI.box(Color("102040"), Color("173058"), 12))
			_character_grid.add_child(card)
			_character_buttons[id] = card
			var column: VBoxContainer = UI.column(card, 6)
			column.mouse_filter = MOUSE_FILTER_IGNORE
			column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			column.offset_left = 12
			column.offset_right = -12
			column.offset_top = 12
			column.offset_bottom = -12
			column.add_child(_character_portrait(id))
			var progress: Dictionary = Field.discovery_progress(_story_snapshot, id)
			for copy: String in [str(data.name), str(data.role), "%d / %d discovered  >" % [progress.found, progress.total]]:
				var label: Label = UI.label(copy, 24 if copy == data.name else 18, Color("F3ECD6") if copy == data.name else Color("8FF0E6"))
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				column.add_child(label)
		if _character_buttons.is_empty(): _empty_search()
	else:
		var hidden: int = 0
		for observation: Dictionary in Field.observations(_story_snapshot):
			if observation.discovered:
				if _matches_archive(str(observation.title) + " " + str(observation.text) + " " + str(observation.source)):
					_observation_card(observation, _archive_body)
			else: hidden += 1
		if _record_buttons.is_empty() and not _archive_query.is_empty(): _empty_search()
		_undiscovered(_archive_body, hidden)
	_layout()
	_archive_scroll.set_deferred("scroll_vertical", scroll_position)

func _chapter_available(number: int) -> bool:
	var chapter: GDScript = Field.chapter_definition(number)
	return number == 1 or PlayerManager.story_unlocked(chapter.ID) or not PlayerManager.story_checkpoint(chapter.ID, false).is_empty()

func _select_chapter(number: int) -> void:
	if number < 1 or number > Field.CHAPTERS.size() or not _chapter_available(number): return
	_chapter = number
	_selected_character = ""
	_selected_record = ""
	_expanded.clear()
	_refresh_archive()
	_archive_scroll.set_deferred("scroll_vertical", 0)

func _character_portrait(id: String) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color("0E2A28"), Color("173058"), 8))
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.set_meta("character_portrait", true)
	var image: TextureRect = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(image)
	var sheet: Texture2D = AssetManager.get_texture("story_amani_poses" if id == "amani" else "chapter1_" + id) if id in Field.CHARACTER_IDS or id == "amani" else null
	if sheet != null:
		var portrait: AtlasTexture = AtlasTexture.new()
		portrait.atlas = sheet
		# Neutral first pose, using the same authored row split as Chapter 1.
		var split: float = float({"john":512, "eric":524, "jobert":546, "amani":512}[id])
		portrait.region = Rect2(100, 0, 312, split * 0.7)
		portrait.filter_clip = true
		image.texture = portrait
	else:
		# No invented likeness for characters without an approved in-game portrait.
		var name: String = str(Field.CHARACTERS[id].name)
		var offline: Label = UI.label(name + ("\nPortrait unavailable offline" if id in Field.CHARACTER_IDS else "\nCharacter file"), 18, Color("8FF0E6"))
		offline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		offline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(offline)
	return frame

func _open_character(id: String) -> void:
	if id not in Field.character_ids(_story_snapshot): return
	_expanded.clear()
	_selected_character = id
	_refresh_archive()
	_archive_scroll.set_deferred("scroll_vertical", 0)

func _build_character_profile() -> void:
	var data: Dictionary = Field.character(_selected_character, _story_snapshot)
	_archive_body.add_child(UI.label("CHARACTERS / " + Field.chapter_label(_chapter).to_upper(), 18, Color("8FF0E6")))
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_archive_body.add_child(header)
	header.add_child(_character_portrait(_selected_character))
	var identity: VBoxContainer = UI.column(header, 4)
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.add_child(UI.label(str(data.name).to_upper(), 26, Color("F3ECD6")))
	identity.add_child(UI.label(str(data.role), 20, Color("8FF0E6")))
	var summary: String = str(data.behavior if not (data.interactions as Array).is_empty() else data.background).get_slice(". ", 0)
	identity.add_child(UI.label(summary if summary.ends_with(".") else summary + ".", 20, Color("F3ECD6")))
	_discovery_meter(_archive_body, _selected_character)
	var page: VBoxContainer = _reading_panel()
	page.add_child(UI.label("BACKGROUND", 18, Color("101623")))
	page.add_child(UI.label(str(data.background), 26, Color("101623")))
	page.add_child(UI.label("OBSERVED BEHAVIOR", 18, Color("101623")))
	page.add_child(UI.label(str(data.behavior), 26, Color("101623")))
	page.add_child(UI.label("RELATIONSHIPS", 18, Color("101623")))
	page.add_child(UI.label(str(data.relationship), 26, Color("101623")))
	var discoveries: VBoxContainer = _foldout(_archive_body, "Discoveries / %d recorded" % data.interactions.size(), "discoveries")
	for observation: Dictionary in data.interactions: _observation_card(observation, discoveries)
	var progress: Dictionary = Field.discovery_progress(_story_snapshot, _selected_character)
	_undiscovered(discoveries, int(progress.total) - int(progress.found))
	discoveries.add_child(UI.label("Discovery records what happened, not who is trustworthy or guilty.", 18, UI.MUTED))
	_archive_body.add_child(UI.button("BACK TO CHARACTERS", _set_section.bind(&"characters")))

func _discovery_meter(parent: Control, person: String = "") -> void:
	var progress: Dictionary = Field.discovery_progress(_story_snapshot, person)
	var column: VBoxContainer = UI.column(parent, 4)
	column.add_child(UI.label("%d / %d observations discovered" % [progress.found, progress.total], 18, Color("8FF0E6")))
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "DiscoveryProgress"
	bar.max_value = maxi(1, int(progress.total))
	bar.value = int(progress.found)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UI.box(Color("173058"), Color("173058"), 0))
	bar.add_theme_stylebox_override("fill", UI.box(Color("4FE0D4"), Color("4FE0D4"), 0))
	column.add_child(bar)

func _foldout(parent: Control, title: String, key: String, color: Color = Color("8FF0E6")) -> VBoxContainer:
	var column: VBoxContainer = UI.column(parent, 6)
	var toggle: Button = UI.button("", Callable())
	toggle.name = "Toggle_" + key
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode = true
	toggle.button_pressed = _expanded.get(key, false)
	toggle.text = ("− " if toggle.button_pressed else "+ ") + title
	toggle.accessibility_name = title + (", expanded" if toggle.button_pressed else ", collapsed")
	toggle.add_theme_color_override("font_color", color)
	column.add_child(toggle)
	var body: VBoxContainer = UI.column(column, 8)
	body.name = "Details_" + key
	body.visible = toggle.button_pressed
	toggle.toggled.connect(func(open: bool) -> void:
		_expanded[key] = open
		body.visible = open
		toggle.text = ("− " if open else "+ ") + title
		toggle.accessibility_name = title + (", expanded" if open else ", collapsed"))
	return body

func _undiscovered(parent: Control, count: int) -> void:
	if count <= 0: return
	var panel: PanelContainer = UI.panel(parent, Color("102040"))
	panel.add_child(UI.label("? UNKNOWN / %d undiscovered\nContinue %s to reveal these records." % [count, Field.chapter_label(_chapter)], 20, UI.MUTED))

func _observation_card(observation: Dictionary, parent: Control) -> void:
	# Undiscovered records never instantiate their authored title, body or source.
	if not observation.discovered: return
	var status: String = str(observation.status)
	var color: Color = Color("33D17A") if status == "Known" else (Color("FFB648") if status == "Unverified" else UI.MUTED)
	var preview: String = str(observation.text).get_slice(". ", 0)
	if preview.length() > 115: preview = preview.left(112) + "…"
	var card: Button = _library_card(parent, status.to_upper(), str(observation.title), preview, str(observation.source), _open_record.bind(str(observation.id)))
	card.name = "Record_" + str(observation.id)
	card.accessibility_name = str(observation.title) + ". " + status + ". Open record."
	(card.get_child(0).get_child(0) as Label).add_theme_color_override("font_color", color)
	_record_buttons[str(observation.id)] = card

func _empty_search() -> void:
	_archive_body.add_child(UI.label("No matching entries", 26, Color("F3ECD6")))
	_archive_body.add_child(UI.label("Try a name or keyword from this chapter. Search includes only discovered records.", 22, UI.MUTED))

func _open_record(id: String) -> void:
	for observation: Dictionary in Field.observations(_story_snapshot):
		if str(observation.id) != id or not observation.discovered: continue
		_record_origin = _selected_character
		_selected_record = id
		_refresh_archive()
		_archive_scroll.set_deferred("scroll_vertical", 0)
		return

func _reading_panel() -> VBoxContainer:
	var panel: PanelContainer = UI.panel(_archive_body, Color("F3ECD6"))
	panel.name = "ReadingPage"
	panel.add_theme_stylebox_override("panel", UI.journal_box(Color("F3ECD6"), Color("173058"), 24))
	return UI.column(panel, 20)

func _build_record_page() -> void:
	for observation: Dictionary in Field.observations(_story_snapshot):
		if str(observation.id) != _selected_record or not observation.discovered: continue
		_archive_body.add_child(UI.label("EVIDENCE / " + Field.chapter_label(_chapter).to_upper(), 18, Color("8FF0E6")))
		var heading: Label = UI.label(str(observation.title), 32, Color("F3ECD6"))
		heading.set_meta("library_heading", true)
		_archive_body.add_child(heading)
		var page: VBoxContainer = _reading_panel()
		var meaning: String = {"Known":"Observed in the story", "Unverified":"A claim that has not been verified", "Unknown":"An unresolved observation"}[str(observation.status)]
		page.add_child(UI.label(str(observation.status).to_upper() + " / " + meaning, 18, Color("101623")))
		page.add_child(UI.label(str(observation.text), 28, Color("101623")))
		page.add_child(UI.label("SOURCE\n" + str(observation.source), 20, Color("101623")))
		_archive_body.add_child(UI.button("BACK TO " + ("CHARACTER" if not _record_origin.is_empty() else "EVIDENCE"), _close_record))
		return
	# An account/progress refresh can remove a record while its page is open.
	_archive_body.add_child(UI.label("This record is not available in the current progress.", 24, UI.MUTED))
	_archive_body.add_child(UI.button("BACK TO COLLECTION", _close_record))

func _close_record() -> void:
	_selected_record = ""
	_selected_character = _record_origin
	_record_origin = ""
	_refresh_archive()
	_archive_scroll.set_deferred("scroll_vertical", 0)

func _refresh_resources() -> void:
	_resource_label.text = "%d CR  /  %d THREAT" % [maxi(0, PlayerManager.credits), maxi(0, AuthService.threat_points())]

func load_topic(skill_id: String) -> void:
	_focus_skill = skill_id
	_banner.visible = not skill_id.is_empty()
	_banner.text = "RECOMMENDED REVIEW / " + skill_id.replace("_", " ").to_upper()
	if skill_id.is_empty():
		_set_tab(_tab)
		return
	_set_section(&"combat")
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
	if is_instance_valid(_detail_panel): _set_section(&"combat")
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
	var short_screen: bool = size.y * physical < 500.0
	_catalog_heading.visible = not short_screen
	_catalog_hint.visible = not short_screen
	_count.visible = not short_screen
	_compact = size.x * physical < 1000.0
	_list_panel.visible = not _compact or not _mobile_details
	_detail_panel.visible = not _compact or _mobile_details
	_back_button.text = "< INDEX" if _compact and _mobile_details else "BACK"
	UI.fit_touch(self)
	for heading: Node in _archive_body.find_children("*", "Label", true, false):
		if heading.has_meta("library_heading"):
			(heading as Label).add_theme_font_size_override("font_size", maxi(30, ceili(22 / physical)))
	if _library_home:
		_back_button.text = "BACK"
		if is_instance_valid(_library_grid): _library_grid.columns = 3 if size.x * physical >= 600 else 1
	elif _section != &"combat":
		_back_button.text = "< COLLECTION" if not _selected_record.is_empty() else ("< CHARACTERS" if not _selected_character.is_empty() else "< LIBRARY")
		if is_instance_valid(_character_grid):
			_character_grid.columns = 3 if size.x * physical >= 600 else 1
		for card: Button in _character_buttons.values():
			card.custom_minimum_size.y = (202 if short_screen else 266) / physical
		for node: Node in _archive_body.find_children("*", "PanelContainer", true, false):
			if node.has_meta("character_portrait"):
				(node as Control).custom_minimum_size = (Vector2(80, 92) if not _selected_character.is_empty() else Vector2(128, 112 if short_screen else 140)) / physical
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
	_archive_search.custom_minimum_size.y = maxf(48, 48 / physical)
	_archive_search.add_theme_font_size_override("font_size", maxi(22, ceili(16 / physical)))
	if not _library_home and _section == &"combat" and not (_compact and _mobile_details): _back_button.text = "< LIBRARY"

func can_go_back() -> bool:
	if _library_home: return true
	if _section != &"combat":
		if not _selected_record.is_empty():
			_close_record()
			return false
		if _section == &"characters" and not _selected_character.is_empty():
			_selected_character = ""
			_refresh_archive()
			_archive_scroll.set_deferred("scroll_vertical", 0)
			return false
		_show_library()
		return false
	if _compact and _mobile_details:
		_mobile_details = false
		_layout()
		_search.grab_focus()
		return false
	_show_library()
	return false

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
