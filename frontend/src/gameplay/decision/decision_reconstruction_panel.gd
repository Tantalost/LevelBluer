extends Control
## Shared, read-only stage epilogue used by both decision presentations.
## It has no account, controller, grading, or reward access.
signal continued

const UI = preload("res://src/ui/screens/intel/study_ui.gd")

var _title: Label
var _timeline: VBoxContainer
var _techniques: VBoxContainer
var _finding: Label
var _continue: Button
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var card: PanelContainer = UI.panel(self, Color("0a1730"))
	card.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var body: VBoxContainer = UI.column(card, 16)
	_title = UI.label("INCIDENT RECONSTRUCTION", 28, UI.TEXT)
	body.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	var content: VBoxContainer = UI.column(_scroll, 14)
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_child(UI.label("TIMELINE", 26, UI.TEXT))
	_timeline = UI.column(content, 10)
	content.add_child(UI.label("TECHNIQUES", 26, UI.TEXT))
	_techniques = UI.column(content, 8)
	content.add_child(UI.label("KEY FINDING", 26, UI.TEXT))
	_finding = UI.label("", 26, UI.TEXT)
	content.add_child(_finding)
	_continue = UI.button("CONTINUE", _on_continue, true)
	body.add_child(_continue)
	hide()


func configure(data: Dictionary) -> void:
	_title.text = str(data.get("title", "INCIDENT RECONSTRUCTION"))
	UI.clear(_timeline)
	for entry: Variant in data.get("events", []) as Array:
		var event: Dictionary = entry as Dictionary
		_timeline.add_child(UI.label("%s — %s" % [event["time"], event["text"]], 26, UI.TEXT))
	UI.clear(_techniques)
	for technique: Variant in data.get("techniques", []) as Array:
		_techniques.add_child(UI.label("• " + str(technique), 26, UI.TEXT))
	_finding.text = str(data.get("finding", ""))
	_scroll.scroll_vertical = 0
	_continue.disabled = false
	show()
	_continue.grab_focus.call_deferred()


func _on_continue() -> void:
	if _continue.disabled:
		return
	_continue.disabled = true
	hide()
	continued.emit()
