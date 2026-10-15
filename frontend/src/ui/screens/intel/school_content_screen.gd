extends BaseScreen
## School-approved supplemental resources. Practice never writes gameplay progress.
const UI: Script = preload("res://src/ui/screens/intel/study_ui.gd")
const TOPICS: Array[String] = ["All topics", "Phishing", "Smishing", "Vishing", "Pretexting", "Baiting"]
const KINDS: Array[String] = ["all", "lesson", "quiz", "codex"]
var _intro: Label
var _filters: HFlowContainer
var _topic: OptionButton
var _kind: OptionButton
var _body: VBoxContainer
var _status: Label
var _refresh: Button
var _selected: String = ""
var _answer: Label
var _heading: Label
var _count: Label
var _reader_header: HBoxContainer

func _ready() -> void:
	var shell: Dictionary = UI.shell(self, "SCHOOL CONTENT", _back)
	var layout: VBoxContainer = shell.layout
	_heading = shell.title
	layout.add_theme_constant_override("separation", 12)
	_intro = UI.label("YOUR SCHOOL'S FIELD NOTES  /  Extra practice, no campaign scores.", 22, Color("#8FF0E6"))
	layout.add_child(_intro)
	_filters = HFlowContainer.new()
	_filters.add_theme_constant_override("h_separation", 16)
	_filters.add_theme_constant_override("v_separation", 12)
	layout.add_child(_filters)
	_topic = OptionButton.new()
	_topic.name = "TopicFilter"
	for topic: String in TOPICS:
		_topic.add_item(topic)
	_kind = OptionButton.new()
	_kind.name = "ContentTypeFilter"
	for caption: String in ["All resources", "Lessons", "Practice questions", "Threat Codex"]:
		_kind.add_item(caption)
	for control: OptionButton in [_topic, _kind]:
		control.custom_minimum_size = Vector2(280, 52)
		_style_filter(control)
		control.item_selected.connect(_filter_changed)
		_filters.add_child(control)
	_refresh = UI.button("Refresh", ContentDB.refresh_school_content)
	_refresh.custom_minimum_size.x = 140
	_refresh.autowrap_mode = TextServer.AUTOWRAP_OFF
	_filters.add_child(_refresh)
	var release_row: HBoxContainer = HBoxContainer.new()
	release_row.add_theme_constant_override("separation", 16)
	layout.add_child(release_row)
	_count = UI.label("", 22, Color("#4FE0D4"))
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	release_row.add_child(_count)
	_status = UI.label("", 20, UI.MUTED)
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	release_row.add_child(_status)
	_reader_header = HBoxContainer.new()
	layout.add_child(_reader_header)
	_reader_header.add_child(UI.button("< RESOURCES", _open.bind("")))
	var practice_note: Label = UI.label("SCHOOL PRACTICE / No campaign scores", 22, Color("#8FF0E6"))
	practice_note.size_flags_horizontal = SIZE_EXPAND_FILL
	practice_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	practice_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reader_header.add_child(practice_note)
	_body = UI.scroll_column(layout)
	_body.add_theme_constant_override("separation", 18)
	(_body.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	resized.connect(_fit_layout)
	ContentDB.content_updated.connect(_refresh_view)
	_refresh_view()
	ContentDB.refresh_school_content()

func _style_filter(control: OptionButton) -> void:
	control.add_theme_font_override("font", UI.FONT)
	control.add_theme_font_size_override("font_size", 24)
	control.add_theme_color_override("font_color", Color("#F3ECD6"))
	control.add_theme_color_override("font_hover_color", Color("#8FF0E6"))
	control.add_theme_color_override("font_pressed_color", Color("#8FF0E6"))
	control.add_theme_stylebox_override("normal", UI.box(Color("#102040"), Color("#173058"), 14))
	control.add_theme_stylebox_override("hover", UI.box(Color("#153B37"), Color("#4FE0D4"), 14))
	control.add_theme_stylebox_override("pressed", UI.box(Color("#0E2A28"), Color("#4FE0D4"), 14))
	control.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, Color("#FFB648"), 0))
	var popup: PopupMenu = control.get_popup()
	popup.add_theme_font_override("font", UI.FONT)
	popup.add_theme_color_override("font_color", Color("#F3ECD6"))
	popup.add_theme_color_override("font_hover_color", Color("#8FF0E6"))
	popup.add_theme_stylebox_override("panel", UI.box(Color("#0A1730"), Color("#4FE0D4"), 12))
	popup.add_theme_stylebox_override("hover", UI.box(Color("#153B37"), Color("#4FE0D4"), 8))
	control.tooltip_text = "Filter by topic" if control == _topic else "Filter by resource type"

func _fit_layout() -> void:
	UI.fit_touch(self)
	var scale_factor: float = maxf(0.25, minf(float(get_window().size.x) / get_viewport_rect().size.x, float(get_window().size.y) / get_viewport_rect().size.y))
	for control: OptionButton in [_topic, _kind]:
		if not is_instance_valid(control):
			continue
		control.get_popup().add_theme_font_size_override("font_size", maxi(24, ceili(16.0 / scale_factor)))
		control.get_popup().add_theme_constant_override("v_separation", ceili(24.0 / scale_factor))

func _filter_changed(_index: int) -> void:
	_selected = ""
	_refresh_view()
	(_body.get_parent() as ScrollContainer).scroll_vertical = 0

func _refresh_view() -> void:
	UI.clear(_body)
	_answer = null
	_fit_layout.call_deferred()
	_status.text = ContentDB.school_content_status
	_refresh.disabled = ContentDB.school_content_loading
	for item: Dictionary in ContentDB.school_items:
		if str(item["id"]) == _selected:
			_intro.hide()
			_filters.hide()
			_status.hide()
			_count.hide()
			_reader_header.show()
			_heading.text = "SCHOOL RESOURCE"
			_detail(item)
			return
	_selected = ""
	_heading.text = "SCHOOL CONTENT"
	_reader_header.hide()
	_count.show()
	_intro.show()
	_filters.show()
	_status.show()
	var count: int = 0
	for item: Dictionary in ContentDB.school_items:
		if _topic.selected > 0 and item["topic"] != TOPICS[_topic.selected]:
			continue
		if _kind.selected > 0 and item["kind"] != KINDS[_kind.selected]:
			continue
		count += 1
		var card: PanelContainer = UI.panel(_body, Color("#102040"))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		card.add_child(row)
		var icon: IntelPixelIcon = IntelPixelIcon.new()
		icon.kind = IntelPixelIcon.Kind.CHAT if item["kind"] == "quiz" else (IntelPixelIcon.Kind.CODEX if item["kind"] == "codex" else IntelPixelIcon.Kind.BOOKS)
		icon.ink_override = Color("#8FF0E6")
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(icon)
		var column: VBoxContainer = UI.column(row, 8)
		column.size_flags_horizontal = SIZE_EXPAND_FILL
		column.add_child(UI.label("%s / %s" % [str(item["topic"]).to_upper(), "PRACTICE" if item["kind"] == "quiz" else str(item["kind"]).to_upper()], 22, Color("#8FF0E6")))
		column.add_child(UI.label(str(item["title"]), 28, Color("#F3ECD6")))
		column.add_child(UI.label("SCHOOL RELEASE / REV %s" % str(item.get("revision", 1)), 20, UI.MUTED))
		var open_button: Button = UI.button("OPEN >", _open.bind(str(item["id"])), true)
		open_button.accessibility_name = "Open " + str(item["title"])
		open_button.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(open_button)
	_count.text = "%02d RESOURCES" % count
	if count == 0:
		var empty: VBoxContainer = UI.column(UI.panel(_body, Color("#0E2A28")), 16)
		empty.add_child(UI.label("NO MATCHES" if not ContentDB.school_items.is_empty() else "AWAITING SCHOOL RESOURCES", 26, Color("#8FF0E6")))
		empty.add_child(UI.label("Try another topic or resource type." if not ContentDB.school_items.is_empty() else "Your school's published materials will appear here. Your bundled lessons are still available in Learning Journey.", 24))

func _open(id: String) -> void:
	_selected = id
	_refresh_view()
	(_body.get_parent() as ScrollContainer).scroll_vertical = 0

func _detail(item: Dictionary) -> void:
	_body.add_child(UI.label("%s / %s" % [str(item["topic"]).to_upper(), str(item["kind"]).to_upper()], 22, Color("#8FF0E6")))
	_body.add_child(UI.label(str(item["title"]), 30, Color("#4FE0D4")))
	var content: Dictionary = item["content"]
	match str(item["kind"]):
		"lesson":
			var objectives: VBoxContainer = _section("MISSION OBJECTIVES", Color("#8FF0E6"))
			for objective: String in content["objectives"]:
				objectives.add_child(UI.label("• " + objective, 26, Color("#F3ECD6")))
			var reading: VBoxContainer = _section("FIELD NOTES", Color("#8FF0E6"))
			reading.add_child(UI.label(str(content["body"]), 28))
		"codex":
			_body.add_child(UI.label(str(content["definition"]), 26))
			var warnings: VBoxContainer = _section("WARNING SIGNS", Color("#FFB648"))
			for sign_text: String in content["warningSigns"]:
				warnings.add_child(UI.label("• " + sign_text, 26))
			var response: VBoxContainer = _section("SAFE RESPONSE", Color("#33D17A"))
			response.add_child(UI.label(str(content["safeResponse"]), 26))
		"quiz":
			_body.add_child(UI.label(str(content["prompt"]), 26))
			for index: int in content["options"].size():
				_body.add_child(UI.button(str(content["options"][index]), _choose_answer.bind(index, content)))
			_answer = UI.label("Choose an answer to see the explanation.", 24, UI.MUTED)
			_answer.name = "AnswerFeedback"
			_body.add_child(_answer)

func _section(title: String, accent: Color) -> VBoxContainer:
	var panel: PanelContainer = UI.panel(_body, Color("#0A1730"))
	panel.add_theme_stylebox_override("panel", UI.box(Color("#0A1730"), accent.darkened(0.5), 20))
	var column: VBoxContainer = UI.column(panel, 16)
	column.add_child(UI.label(title, 24, accent))
	return column

func on_exit() -> void:
	_topic.get_popup().hide()
	_kind.get_popup().hide()

func _choose_answer(index: int, content: Dictionary) -> void:
	var correct: bool = index == int(content["correctOption"])
	_answer.text = ("Correct. " if correct else "Try again. ") + str(content["explanation"])
	_answer.add_theme_color_override("font_color", Color("#33D17A") if correct else Color("#FFB648"))

func _back() -> void:
	if not _selected.is_empty():
		_open("")
	else:
		Router.request_back()

func can_go_back() -> bool:
	if not _selected.is_empty():
		_open("")
		return false
	return true
