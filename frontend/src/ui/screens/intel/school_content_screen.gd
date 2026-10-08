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

func _ready() -> void:
	var shell: Dictionary = UI.shell(self, "SCHOOL CONTENT", _back)
	var layout: VBoxContainer = shell.layout
	layout.add_theme_constant_override("separation", 12)
	_intro = UI.label("School-approved resources. Practice does not change campaign progress.", 20, Color("#8FF0E6"))
	layout.add_child(_intro)
	_filters = HFlowContainer.new()
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
		control.custom_minimum_size = Vector2(240, 52)
		control.add_theme_font_override("font", UI.FONT)
		control.add_theme_font_size_override("font_size", 20)
		control.add_theme_color_override("font_color", Color("#F3ECD6"))
		control.add_theme_stylebox_override("normal", UI.box(Color("#102040"), Color("#173058"), 12))
		control.item_selected.connect(_filter_changed)
		_filters.add_child(control)
	_refresh = UI.button("Refresh", ContentDB.refresh_school_content)
	_refresh.custom_minimum_size.x = 140
	_refresh.autowrap_mode = TextServer.AUTOWRAP_OFF
	_filters.add_child(_refresh)
	_status = UI.label("", 18, UI.MUTED)
	layout.add_child(_status)
	_body = UI.scroll_column(layout)
	ContentDB.content_updated.connect(_refresh_view)
	_refresh_view()
	ContentDB.refresh_school_content()

func _filter_changed(_index: int) -> void:
	_selected = ""
	_refresh_view()

func _refresh_view() -> void:
	UI.clear(_body)
	_status.text = ContentDB.school_content_status
	_refresh.disabled = ContentDB.school_content_loading
	for item: Dictionary in ContentDB.school_items:
		if str(item["id"]) == _selected:
			_intro.hide()
			_filters.hide()
			_status.hide()
			_detail(item)
			return
	_selected = ""
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
		var column: VBoxContainer = UI.column(card)
		column.add_child(UI.label("%s / %s · Revision %s" % [item["topic"], str(item["kind"]).capitalize(), str(item.get("revision", 1))], 22, Color("#8FF0E6")))
		column.add_child(UI.button(str(item["title"]), _open.bind(str(item["id"]))))
	if count == 0:
		_body.add_child(UI.label("No published resources match these filters." if not ContentDB.school_items.is_empty() else "Published school resources will appear here. You can continue your learning journey using bundled lessons.", 26))

func _open(id: String) -> void:
	_selected = id
	_refresh_view()

func _detail(item: Dictionary) -> void:
	_body.add_child(UI.button("Back to resources", _open.bind("")))
	_body.add_child(UI.label(str(item["title"]), 30, Color("#4FE0D4")))
	var content: Dictionary = item["content"]
	match str(item["kind"]):
		"lesson":
			for objective: String in content["objectives"]:
				_body.add_child(UI.label("• " + objective, 24, UI.MUTED))
			_body.add_child(UI.label(str(content["body"]), 26))
		"codex":
			_body.add_child(UI.label(str(content["definition"]), 26))
			_body.add_child(UI.label("WARNING SIGNS", 24, Color("#FFB648")))
			for sign_text: String in content["warningSigns"]:
				_body.add_child(UI.label("• " + sign_text, 26))
			_body.add_child(UI.label("SAFE RESPONSE", 24, Color("#33D17A")))
			_body.add_child(UI.label(str(content["safeResponse"]), 26))
		"quiz":
			_body.add_child(UI.label(str(content["prompt"]), 26))
			for index: int in content["options"].size():
				_body.add_child(UI.button(str(content["options"][index]), _choose_answer.bind(index, content)))
			_answer = UI.label("Choose an answer to see the explanation.", 24, UI.MUTED)
			_answer.name = "AnswerFeedback"
			_body.add_child(_answer)

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
