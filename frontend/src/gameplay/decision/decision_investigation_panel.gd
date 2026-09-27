extends VBoxContainer
## Reusable "inspect evidence, reach a conclusion" panel for decision-story
## scenes (see DecisionScenarios.has_investigation). Purely data-driven — any
## module/stage can enable it via an authored "investigation" block on a
## threat; no per-stage branching lives here or in the caller.
##
## Authored inspection mode reveals details; the original mode analyzes a
## single selected conclusion. No drag/drop or Case Board. Never grades BKT, never
## triggers Tower Defense/Game Over, never clears an incident, never selects
## or biases SAFE/RISKY/CRITICAL — it only gates when the operational
## decision's choices become actionable. Investigation asks "what does the
## evidence actually prove?"; the decision that follows asks "what should we
## do now?" — two different questions, kept visually and behaviorally
## distinct (never called a Quiz/Question, never graded Correct/Wrong).
signal investigation_resolved

const UI = preload("res://src/ui/screens/intel/study_ui.gd")

var _title_label: Label
var _prompt_label: Label
var _items_column: VBoxContainer
var _item_buttons: Array[Button] = []
var _button_group: ButtonGroup
var _analyze_button: Button
var _result_label: Label
var _continue_button: Button
var _items: Array[Dictionary] = []
var _selected_index := -1
var _confirmed := false
var _display_column: VBoxContainer
var _inspection_mode: bool = false
var _inspected: Dictionary = {}
var _legacy_panel: PanelContainer
var _inspection_panel: PanelContainer
var _inspection_body: VBoxContainer
var _inspection_progress: Label
var _inspection_continue: Button
var interaction_locked: bool = false


## The same text-only view is also embedded in a threat's existing scrollable
## evidence column. No selection, validation, or signals are added here.
static func render_display(parent: VBoxContainer, source: Dictionary) -> void:
	UI.clear(parent)
	var display: Dictionary = DecisionScenarios.inspection_display(source)
	var metadata: Array = display["metadata"]
	parent.visible = not metadata.is_empty()
	if metadata.is_empty():
		return
	var headings: Dictionary = {
		"generic": "INSPECTION", "email": "EMAIL / MESSAGE",
		"mobile": "MOBILE / ACCOUNT EVENTS", "identity": "IDENTITY / CONTEXT",
		"artifact": "OBJECT / FILE / OFFER",
	}
	parent.add_child(UI.label(str(headings[display["presentation"]]), 26, UI.TEXT))
	for row: Dictionary in metadata:
		# Label, rather than RichTextLabel: authored values are literal text,
		# including brackets, never markup that can impersonate UI highlights.
		var field: Label = UI.label("%s\n%s" % [row["label"], row["value"]], 26, UI.TEXT)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(field)


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var panel := UI.panel(self, Color("14232b"))
	_legacy_panel = panel
	var body := UI.column(panel, 12)
	_title_label = UI.label("", 28, UI.GOLD)
	body.add_child(_title_label)
	_prompt_label = UI.label("", 26, UI.TEXT)
	body.add_child(_prompt_label)
	# Bound metadata height so a long message cannot displace ANALYZE or
	# evidence selection. Plain scenes reuse their existing evidence scroll.
	var display_scroll: ScrollContainer = ScrollContainer.new()
	display_scroll.custom_minimum_size.y = 156
	display_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(display_scroll)
	_display_column = UI.column(display_scroll, 10)
	_display_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_column = UI.column(body, 8)
	_button_group = ButtonGroup.new()
	_analyze_button = UI.button("ANALYZE", _analyze, true)
	body.add_child(_analyze_button)
	_result_label = UI.label("", 26, UI.TEAL)
	_result_label.hide()
	body.add_child(_result_label)
	_continue_button = UI.button("CONTINUE", _confirm_continue, true)
	_continue_button.hide()
	body.add_child(_continue_button)
	_inspection_panel = UI.panel(self, Color("102040"))
	_inspection_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var inspection_layout: VBoxContainer = UI.column(_inspection_panel, 10)
	_inspection_body = UI.scroll_column(inspection_layout)
	_inspection_progress = UI.label("", 26, UI.TEAL)
	inspection_layout.add_child(_inspection_progress)
	_inspection_continue = UI.button("DECIDE / USE YOUR FINDINGS", _confirm_continue, true)
	inspection_layout.add_child(_inspection_continue)
	_inspection_panel.hide()


## Resets all state for a NEW investigation — every threat with an enabled
## investigation starts fresh, never carrying over a previous incident's
## selection/result (and a retried incident replays it the same way, since
## nothing here is ever persisted — see the milestone's own "no memory
## writes from investigation" rule).
func configure(config: Dictionary) -> void:
	_selected_index = -1
	_confirmed = false
	_inspected.clear()
	_inspection_mode = str(config.get("mode", "")) == "inspect"
	_legacy_panel.visible = not _inspection_mode
	_inspection_panel.visible = _inspection_mode
	size_flags_vertical = SIZE_EXPAND_FILL if _inspection_mode else SIZE_FILL
	_title_label.text = str(config.get("title", "INVESTIGATION")).strip_edges().to_upper()
	_prompt_label.text = str(config.get("prompt", "")).strip_edges()
	render_display(_display_column, config)
	_display_column.get_parent().visible = _display_column.visible
	_items.clear()
	var stored: Variant = config.get("items", [])
	if typeof(stored) == TYPE_ARRAY:
		for entry in (stored as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				_items.append(entry as Dictionary)
	UI.clear(_items_column)
	_item_buttons.clear()
	if _inspection_mode:
		_build_inspection(config)
		return
	for i in _items.size():
		var button := UI.button(_item_text(false, str(_items[i].get("label", ""))), _select.bind(i))
		button.toggle_mode = true
		button.button_group = _button_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_items_column.add_child(button)
		_item_buttons.append(button)
	_items_column.show()
	_analyze_button.disabled = true
	_analyze_button.show()
	_result_label.hide()
	_result_label.text = ""
	_continue_button.hide()
	_continue_button.disabled = false
	if not _item_buttons.is_empty():
		_item_buttons[0].grab_focus.call_deferred()

## Evidence is revealed, not graded. Reopening a detail never counts twice.
## All content stays available until the player explicitly enters the decision.
func _build_inspection(config: Dictionary) -> void:
	UI.clear(_inspection_body)
	_inspection_body.add_child(UI.label(str(config.get("title", "INVESTIGATE")).to_upper(), 28, UI.GOLD))
	_inspection_body.add_child(UI.label(str(config.get("prompt", "")), 26))
	for index: int in _items.size():
		var card: PanelContainer = UI.panel(_inspection_body, Color("0A1730"))
		var content: VBoxContainer = UI.column(card, 10)
		var button: Button = UI.button("+ " + str(_items[index].get("label", "Inspect detail")), func() -> void: pass)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		content.add_child(button)
		var detail: Label = UI.label(str(_items[index].get("analysis", "")), 26)
		content.add_child(detail)
		detail.hide()
		button.pressed.connect(_inspect.bind(index, detail, button))
		_item_buttons.append(button)
	_inspection_continue.disabled = true
	_inspection_progress.text = "DETAILS INSPECTED / 0 OF %d" % _items.size()

func _inspect(index: int, detail: Label, button: Button) -> void:
	if interaction_locked or not _inspection_mode or index < 0 or index >= _items.size():
		return
	_inspected[index] = true
	button.text = "CHECKED / " + str(_items[index].get("label", "Detail"))
	button.add_theme_color_override("font_color", UI.TEAL)
	# No external links, OS applications, rewards or account writes.
	if not detail.visible:
		detail.show()
		var settings: Node = get_node_or_null("/root/SettingsService")
		if settings == null or not bool(settings.get("reduced_motion")):
			detail.modulate.a = 0.0
			var reveal: Tween = detail.create_tween()
			reveal.tween_property(detail, "modulate:a", 1.0, 0.16)
	_confirmed = _inspected.size() == _items.size()
	_inspection_continue.disabled = not _confirmed
	_inspection_progress.text = "DETAILS INSPECTED / %d OF %d" % [_inspected.size(), _items.size()]


func is_resolved() -> bool:
	return _confirmed


## Text-based selected state (a "[X]"/"[ ]" marker), never color alone —
## selection must read clearly to keyboard/controller/touch/reduced_motion
## players exactly the same way.
func _item_text(selected: bool, label: String) -> String:
	return ("[X] " if selected else "[ ] ") + label


func _select(index: int) -> void:
	if _confirmed or index < 0 or index >= _items.size():
		return
	_selected_index = index
	for i in _item_buttons.size():
		_item_buttons[i].text = _item_text(i == index, str(_items[i].get("label", "")))
	_analyze_button.disabled = false
	_analyze_button.grab_focus.call_deferred()


## No BKT, no Tower Defense, no Game Over, no outcome selection — this only
## ever reads the authored "valid"/"analysis" fields back to the player.
func _analyze() -> void:
	if _confirmed or _selected_index < 0:
		return
	var item: Dictionary = _items[_selected_index]
	var analysis: String = str(item.get("analysis", "")).strip_edges()
	if bool(item.get("valid", false)):
		_confirmed = true
		_result_label.add_theme_color_override("font_color", UI.TEAL)
		_result_label.text = "ANALYSIS CONFIRMED\n" + analysis
		_result_label.show()
		_items_column.hide()
		_analyze_button.hide()
		_continue_button.show()
		_continue_button.grab_focus.call_deferred()
	else:
		# Evidence insufficient: the player picks again — items and ANALYZE
		# stay live, exactly like before this attempt, no separate "try
		# again" step and no lock-out.
		_result_label.add_theme_color_override("font_color", UI.GOLD)
		_result_label.text = "EVIDENCE INSUFFICIENT\n" + analysis
		_result_label.show()
		_item_buttons[_selected_index].grab_focus.call_deferred()


func _confirm_continue() -> void:
	if interaction_locked:
		return
	if _inspection_mode:
		if not _confirmed or _inspection_continue.disabled:
			return
		_inspection_continue.disabled = true
		investigation_resolved.emit()
		return
	if not _confirmed or _continue_button.disabled:
		return
	_continue_button.disabled = true
	investigation_resolved.emit()
