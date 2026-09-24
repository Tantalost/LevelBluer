extends VBoxContainer
## Reusable "inspect evidence, reach a conclusion" panel for decision-story
## scenes (see DecisionScenarios.has_investigation). Purely data-driven — any
## module/stage can enable it via an authored "investigation" block on a
## threat; no per-stage branching lives here or in the caller.
##
## First version, deliberately small: single-selection only (no drag/drop,
## no free-form linking, no Case Board connections). Never grades BKT, never
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


## Resets all state for a NEW investigation — every threat with an enabled
## investigation starts fresh, never carrying over a previous incident's
## selection/result (and a retried incident replays it the same way, since
## nothing here is ever persisted — see the milestone's own "no memory
## writes from investigation" rule).
func configure(config: Dictionary) -> void:
	_selected_index = -1
	_confirmed = false
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
	if not _confirmed or _continue_button.disabled:
		return
	_continue_button.disabled = true
	investigation_resolved.emit()
