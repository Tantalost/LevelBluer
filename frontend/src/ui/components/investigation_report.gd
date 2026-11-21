extends PanelContainer
## Reusable evidence desk. The chapter controller owns grading, saves and progression.
signal draft_changed(snapshot: Dictionary)
signal submit_requested
signal retry_requested
signal continue_requested
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Rules: GDScript = preload("res://src/gameplay/decision/investigation_report_rules.gd")
var definition: Dictionary = {}
var snapshot: Dictionary = {}
var selected: String = ""
var locked: bool = false
var previews: Dictionary = {}
var body: VBoxContainer
var tabs: HBoxContainer
var workspace: HBoxContainer
var footer: HBoxContainer
var physical: float = 1.0

class EvidenceCard extends Button:
	var item_id: String = ""
	var report: Control
	var kind: String = ""
	func _draw() -> void:
		var unit: float = 1.0 / report.physical
		var at: Vector2 = Vector2(size.x * 0.5, 39 * unit)
		draw_rect(Rect2(Vector2(size.x * 0.5 - 6 * unit, 0), Vector2(12, 12) * unit), Color("bf5366"))
		var ink: Color = Color("173058")
		if kind == "capture":
			draw_rect(Rect2(at - Vector2(25, 17) * unit, Vector2(50, 34) * unit), ink, false, 3 * unit)
			draw_rect(Rect2(at - Vector2(19, 10) * unit, Vector2(38, 5) * unit), Color("4fc6ca"))
			draw_line(at + Vector2(-18, 3) * unit, at + Vector2(18, 3) * unit, ink, 2 * unit)
			draw_line(at + Vector2(-18, 10) * unit, at + Vector2(10, 10) * unit, ink, 2 * unit)
		elif kind == "sender":
			draw_rect(Rect2(at - Vector2(24, 15) * unit, Vector2(48, 30) * unit), ink, false, 3 * unit)
			draw_polyline(PackedVector2Array([at + Vector2(-23,-14)*unit, at + Vector2(0,4)*unit, at + Vector2(23,-14)*unit]),ink,3*unit)
		else:
			draw_rect(Rect2(at - Vector2(4, 18) * unit, Vector2(8, 24) * unit), ink)
			draw_rect(Rect2(at + Vector2(-4, 11) * unit, Vector2(8, 7) * unit), ink)
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled: return null
		var preview: Label = Label.new()
		preview.text = text
		preview.add_theme_font_size_override("font_size", 22)
		set_drag_preview(preview)
		return {"report_owner":report.get_instance_id(), "item":item_id}

class ReportSlot extends Button:
	var slot_id: String = ""
	var report: Control
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.get("report_owner", -1) == report.get_instance_id() and report.definition.items.has(str(data.get("item", "")))
	func _drop_data(_at: Vector2, data: Variant) -> void:
		report.place(slot_id, str(data.item))

func _ready() -> void:
	set_meta("owns_responsive_metrics", true)
	add_theme_stylebox_override("panel", UI.box(Color("102040"), Color("4FE0D4"), 12))
	get_viewport().size_changed.connect(_resize)

func configure(config: Dictionary, saved: Dictionary, captures: Dictionary = {}) -> void:
	definition = config
	snapshot = Rules.clean(definition, saved)
	previews = captures
	_render()

func _resize() -> void:
	if not definition.is_empty(): _render.call_deferred()

func _button(text: String, callback: Callable, parent: Control, primary: bool = false) -> Button:
	var button: Button = UI.button(text, callback, primary)
	button.custom_minimum_size = Vector2(0, 48 / physical)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", ceili(16 / physical))
	button.disabled = locked
	parent.add_child(button)
	return button

func _label(text: String, parent: Control, pixels: float = 17, ink: Color = Color("F3ECD6")) -> Label:
	var label: Label = UI.label(text, ceili(pixels / physical), ink)
	parent.add_child(label)
	return label

func _render() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or definition.is_empty(): return
	physical = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	UI.clear(self)
	body = UI.column(self, 8)
	_label(str(definition.title), body, 20, Color("4FE0D4"))
	tabs = HBoxContainer.new()
	body.add_child(tabs)
	_button("EVIDENCE BOARD", _view.bind("board"), tabs, snapshot.view == "board")
	var total: int = int(Rules.evaluate(definition, {}).total)
	_button("REPORT · %d/%d" % [snapshot.draft.size(), total], _view.bind("report"), tabs, snapshot.view == "report")
	workspace = HBoxContainer.new()
	workspace.size_flags_vertical = SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	body.add_child(workspace)
	footer = HBoxContainer.new()
	body.add_child(footer)
	if snapshot.view == "results":
		_results()
		return
	var wide: bool = size.x * physical >= 720
	if (snapshot.view == "board" and (selected.is_empty() or wide)) or (snapshot.view == "report" and wide): _board()
	if snapshot.view == "report": _report()
	elif not selected.is_empty(): _inspect()
	_button("OPEN REPORT" if snapshot.view == "board" else "SUBMIT REPORT", _open_or_submit, footer, true)
	set_locked(locked)

func _column(parent: Control) -> VBoxContainer:
	var panel: PanelContainer = UI.panel(parent, Color("0A1730"))
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	return UI.scroll_column(panel)

func _board() -> void:
	var column: VBoxContainer = _column(workspace)
	_label("CASE FILE / COLLECTED EVIDENCE", column, 16, Color("8FF0E6"))
	_label("Tap to inspect. Drag or select, then tap a slot.", column, 14)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3 if snapshot.view == "board" and selected.is_empty() and size.x * physical >= 720 else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for id: String in definition.items:
		var item: Dictionary = definition.items[id]
		if not item.get("available", false): continue
		var card: EvidenceCard = EvidenceCard.new()
		card.item_id = id
		card.report = self
		card.kind = str(item.type)
		card.name = "Evidence_" + id
		card.text = str(item.type).to_upper() + "\n" + str(item.title)
		card.accessibility_name = str(item.type) + ". " + str(item.title) + ". " + str(item.source)
		card.add_theme_font_override("font", UI.FONT)
		card.add_theme_font_size_override("font_size", ceili(16 / physical))
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.custom_minimum_size = Vector2(0, 152 / physical)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = UI.box(Color("F3ECD6"), Color("4FE0D4") if selected == id else Color("927d63"), 10)
			style.border_width_top = 5
			style.content_margin_top = 67 / physical
			style.content_margin_left = 8 / physical
			style.content_margin_right = 8 / physical
			card.add_theme_stylebox_override(state, style)
			card.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("101623"))
		card.pressed.connect(_select.bind(id))
		grid.add_child(card)

func _inspect() -> void:
	var column: VBoxContainer = _column(workspace)
	var item: Dictionary = definition.items[selected]
	_label(str(item.source), column, 17, Color("8FF0E6"))
	_label(str(item.text), column)
	var texture: Texture2D = previews.get(str(item.get("capture_id", ""))) as Texture2D
	if texture != null:
		var image: TextureRect = TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size.y = 140 / physical
		column.add_child(image)
	_button("USE IN REPORT", _view.bind("report"), column, true)
	_button("BACK TO EVIDENCE", _clear_selection, column)

func _report() -> void:
	var column: VBoxContainer = _column(workspace)
	var sections: HBoxContainer = HBoxContainer.new()
	column.add_child(sections)
	for index: int in definition.sections.size():
		_button(str(index + 1), _section.bind(index), sections, index == int(snapshot.section))
	var section: Dictionary = definition.sections[int(snapshot.section)]
	_label(str(section.title), column, 19, Color("8FF0E6"))
	if not selected.is_empty(): _label("Selected: " + str(definition.items[selected].title) + " / " + str(definition.items[selected].type), column, 14)
	for slot: Dictionary in section.slots:
		var target: ReportSlot = ReportSlot.new()
		target.report = self
		target.slot_id = str(slot.id)
		target.name = "Slot_" + str(slot.id)
		var item: String = str(snapshot.draft.get(slot.id, ""))
		target.text = str(slot.label) + "\n" + (str(definition.items[item].title) if not item.is_empty() else "Tap to place selected evidence")
		target.accessibility_name = target.text
		target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target.add_theme_font_override("font", UI.FONT)
		target.add_theme_font_size_override("font_size", ceili(17 / physical))
		UI.style_button(target, not selected.is_empty())
		target.custom_minimum_size.y = 74 / physical
		target.pressed.connect(_slot_tapped.bind(str(slot.id)))
		column.add_child(target)
		if not item.is_empty(): _button("REMOVE", place.bind(str(slot.id), ""), column)

func _results() -> void:
	var column: VBoxContainer = _column(workspace)
	_label("REPORT REVIEW · %d/%d (%d%%)" % [snapshot.latest.score, snapshot.latest.total, snapshot.latest.percent], column, 22, Color("4FE0D4"))
	var first_text: String = "not recorded" if snapshot.first.is_empty() else "%d/%d" % [snapshot.first.score, snapshot.first.total]
	var best_text: String = "not recorded" if snapshot.best.is_empty() else "%d/%d" % [snapshot.best.score, snapshot.best.total]
	_label("First: " + first_text + " · Best: " + best_text, column, 15)
	for section: Dictionary in definition.sections:
		var correct: int = 0
		for slot: Dictionary in section.slots:
			if snapshot.latest.correct.get(slot.id, false): correct += 1
		_label(str(section.title) + " · %d/%d" % [correct, section.slots.size()], column, 18)
		for slot: Dictionary in section.slots:
			var passed: bool = snapshot.latest.correct.get(slot.id, false)
			_label(("✓ " if passed else "× ") + str(slot.label) + (" — matched" if passed else " — use " + str(definition.items[slot.answer].source) + " / " + str(definition.items[slot.answer].type)), column, 16, Color("33D17A") if passed else Color("FFB648"))
		_label(str(section.explanation), column, 16)
	_button("EDIT REPORT", _view.bind("report"), column)
	_button("RETRY INVESTIGATION", _retry, column)
	_label(str(definition.get("reward_notice", "Complete the chapter to record this report.")), column, 14)
	_button("CONTINUE", _continue, footer, true)
	set_locked(locked)

func _select(id: String) -> void:
	if locked: return
	selected = id
	snapshot.view = "board"
	_render()

func _clear_selection() -> void:
	if locked: return
	selected = ""
	_view("board")

func _slot_tapped(id: String) -> void:
	if locked: return
	if not selected.is_empty(): place(id, selected)
	elif snapshot.draft.has(id):
		selected = str(snapshot.draft[id])
		_view("board")

func place(slot: String, item: String) -> void:
	if locked: return
	if not item.is_empty() and (not definition.items.has(item) or not definition.items[item].get("available", false)): return
	for key: String in snapshot.draft.keys():
		if snapshot.draft[key] == item: snapshot.draft.erase(key)
	if item.is_empty(): snapshot.draft.erase(slot)
	else: snapshot.draft[slot] = item
	snapshot.draft = Rules.canonical(definition, snapshot.draft)
	selected = ""
	_changed()

func _changed() -> void:
	snapshot.revision += 1
	draft_changed.emit(snapshot.duplicate(true))
	_render()

func _view(view: String) -> void:
	if locked: return
	snapshot.view = view
	_changed()

func _section(index: int) -> void:
	if locked: return
	snapshot.section = index
	_changed()

func _open_or_submit() -> void:
	if locked: return
	if snapshot.view == "board": _view("report")
	else: submit_requested.emit()

func _retry() -> void:
	if not locked: retry_requested.emit()

func _continue() -> void:
	if not locked: continue_requested.emit()

func set_locked(value: bool) -> void:
	locked = value
	for node: Node in find_children("*", "Button", true, false):
		(node as Button).disabled = locked
	if locked and get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
