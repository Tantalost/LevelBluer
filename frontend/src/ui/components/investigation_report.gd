extends PanelContainer
## Reusable evidence desk. The chapter controller owns grading, saves and progression.
signal draft_changed(snapshot: Dictionary)
signal submit_requested
signal retry_requested
signal continue_requested
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Rules: GDScript = preload("res://src/gameplay/decision/investigation_report_rules.gd")
const INK: Color = Color("101623")
const CREAM: Color = Color("F3ECD6")
const CYAN: Color = Color("4FE0D4")
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
var _scroll_positions: Dictionary = {}
var compact: bool = false

class DeskSurface extends PanelContainer:
	var unit: float = 1.0
	func _draw() -> void:
		# Restrained drafting grid, drawn once per resize; no animated noise.
		for x: int in range(16, int(size.x * unit), 24):
			for y: int in range(16, int(size.y * unit), 24):
				draw_rect(Rect2(Vector2(x,y) / unit, Vector2.ONE / unit), Color("25433f"))

class EvidenceCard extends Button:
	var item_id: String = ""
	var report: Control
	var kind: String = ""
	var placed: bool = false
	func _ready() -> void:
		clip_contents = true
		resized.connect(_layout)
		var item: Dictionary = report.definition.items[item_id]
		var type_label: Label = report._label(report._kind_name(kind).to_upper(), self, 12, Color("365b63"))
		type_label.name = "Kind"
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_color_override("font_color", report._kind_color(kind))
		var heading: Label = report._label(str(item.title), self, 17, INK)
		heading.name = "Title"
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.max_lines_visible = 2
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var status: Label = report._label("IN REPORT" if placed else "TAP TO INSPECT", self, 12, Color("173058"))
		status.name = "Status"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.max_lines_visible = 1
		status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_layout.call_deferred()
	func _layout() -> void:
		if not is_node_ready(): return
		var u: float = 1.0 / report.physical
		for key: String in ["Kind", "Title", "Status"]:
			var label: Label = get_node(key)
			var positions: Dictionary = {"Kind":10.0,"Title":68.0,"Status":110.0} if report.compact else {"Kind":15.0,"Title":103.0,"Status":158.0}
			var heights: Dictionary = {"Kind":16.0,"Title":39.0,"Status":18.0} if report.compact else {"Kind":18.0,"Title":45.0,"Status":20.0}
			var y: float = positions[key]
			var height: float = heights[key]
			label.position = Vector2(12, y) * u
			label.size = Vector2(maxf(1, size.x - 24 * u), height * u)
		queue_redraw()
	func _draw() -> void:
		var u: float = 1.0 / report.physical
		var pin: Vector2 = Vector2(size.x * 0.5, 5 * u)
		draw_rect(Rect2(pin - Vector2(12,3)*u, Vector2(24,8)*u), Color("baa77c"))
		draw_circle(pin, 3*u, Color("bf5366"))
		var accent: Color = report._kind_color(kind)
		var center: Vector2 = Vector2(size.x * 0.5, (46 if report.compact else 65) * u)
		draw_set_transform(center, 0.0, Vector2.ONE * u * (0.75 if report.compact else 1.0))
		draw_rect(Rect2(-29,-24,58,48), Color(accent,0.12))
		if kind == "capture":
			draw_rect(Rect2(-21,-12,42,28),accent,false,2)
			draw_rect(Rect2(-13,-18,13,6),accent,false,2)
			draw_arc(Vector2(0,2),9,0,TAU,24,accent,2)
			draw_rect(Rect2(13,-8,4,4),accent)
		elif kind == "sender":
			draw_rect(Rect2(-21,-16,42,32),accent,false,2)
			draw_circle(Vector2(-10,-5),5,accent)
			draw_arc(Vector2(-10,10),7,PI,TAU,16,accent,2)
			for y: int in [-7,0,7]: draw_line(Vector2(2,y),Vector2(15,y),accent,2)
		else:
			for x: int in [-18,5]:
				draw_rect(Rect2(x,-12,13,15),accent)
				draw_polyline(PackedVector2Array([Vector2(x+11,3),Vector2(x+8,10),Vector2(x+2,14)]),accent,3)
		draw_set_transform(Vector2.ZERO)
		var divider: float = 108 if report.compact else 153
		draw_line(Vector2(12,divider)*u,Vector2(size.x-12*u,divider*u),Color("b7b6a5"),u)
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled or report.locked: return null
		var preview: Label = UI.label(str(report.definition.items[item_id].title), ceili(16 / report.physical), CREAM)
		preview.custom_minimum_size.x = 170 / report.physical
		set_drag_preview(preview)
		return {"report_owner":report.get_instance_id(), "item":item_id}

class ReportSlot extends Button:
	var slot_id: String = ""
	var report: Control
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and not report.locked and data is Dictionary and data.get("report_owner", -1) == report.get_instance_id() and report.definition.items.has(str(data.get("item", ""))) and report.definition.items[str(data.item)].get("available", false)
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if _can_drop_data(_at, data): report.place(slot_id, str(data.item))

func _ready() -> void:
	set_meta("owns_responsive_metrics", true)
	get_viewport().size_changed.connect(_resize)

func configure(config: Dictionary, saved: Dictionary, captures: Dictionary = {}) -> void:
	if definition.get("id", "") != config.get("id", ""):
		selected = ""
		_scroll_positions.clear()
	definition = config
	snapshot = Rules.clean(definition, saved)
	previews = captures
	if not selected.is_empty() and (not definition.items.has(selected) or not definition.items[selected].get("available", false)): selected = ""
	_render()

func _resize() -> void:
	if not definition.is_empty(): _render.call_deferred()

func _kind_name(kind: String) -> String:
	return str({"capture":"Message capture","sender":"Sender note","excerpt":"Excerpt"}.get(kind,kind.capitalize()))

func _kind_color(kind: String) -> Color:
	return {"capture":Color("244c80"), "sender":Color("205a57"), "excerpt":Color("865500")}.get(kind, INK)

func _button(text: String, callback: Callable, parent: Control, primary: bool = false) -> Button:
	var button: Button = UI.button(text, callback, primary)
	button.custom_minimum_size = Vector2(0, 48 / physical)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", ceili(16 / physical))
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var fill: Color = Color("2E6BFF") if primary else Color("102040")
		if state == "pressed": fill = Color("173058")
		if state == "disabled": fill = Color("0A1730")
		var style: StyleBoxFlat = UI.box(Color.TRANSPARENT if state == "focus" else fill, CYAN if state == "focus" or primary else Color("36516a"), ceili(8 / physical))
		style.set_corner_radius_all(ceili(7 / physical))
		style.corner_detail = 1
		style.shadow_size = 0
		button.add_theme_stylebox_override(state, style)
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(key, CREAM)
	button.disabled = locked
	parent.add_child(button)
	return button

func _label(text: String, parent: Control, pixels: float = 17, ink: Color = CREAM) -> Label:
	var label: Label = UI.label(text, ceili(pixels / physical), ink)
	parent.add_child(label)
	return label

func _render() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or definition.is_empty(): return
	physical = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	compact = get_viewport_rect().size.y * physical < 500 and size.x * physical >= 600
	for node: Node in find_children("*", "ScrollContainer", true, false):
		_scroll_positions[str(node.get_meta("scroll_key", ""))] = (node as ScrollContainer).scroll_vertical
	UI.clear(self)
	var frame: StyleBoxFlat = UI.box(Color("050B18"),Color("36516a"),ceili(10/physical))
	frame.set_corner_radius_all(ceili(10/physical))
	frame.shadow_size = 10
	add_theme_stylebox_override("panel",frame)
	body = UI.column(self, ceili((5 if compact else 7)/physical))
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	var title: Label = _label(("CASE / " if compact else "CASE FILE / ") + str(definition.title).get_slice(" / ",0), header, 16 if compact else 19, CYAN)
	if compact and snapshot.view == "report" and not selected.is_empty():
		title.text = "PLACE / " + str(definition.items[selected].title)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.max_lines_visible = 1
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var total: int = int(Rules.evaluate(definition, {}).total)
	var counter: Label = _label("%d/%d PLACED" % [snapshot.draft.size(),total], header, 14, CREAM)
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	if compact:
		header.size_flags_horizontal = SIZE_EXPAND_FILL
		counter.text = "%d/%d" % [snapshot.draft.size(),total]
	var progress: ProgressBar = ProgressBar.new()
	progress.name = "ReportProgress"
	progress.show_percentage = false
	progress.max_value = total
	progress.value = snapshot.draft.size()
	progress.custom_minimum_size.y = 4/physical
	progress.add_theme_stylebox_override("background",UI.box(Color("173058"),Color.TRANSPARENT,0))
	progress.add_theme_stylebox_override("fill",UI.box(CYAN,Color.TRANSPARENT,0))
	body.add_child(progress)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",ceili(8/physical))
	if compact:
		header.add_child(tabs)
		tabs.custom_minimum_size.x = 320/physical
	else: body.add_child(tabs)
	_button("EVIDENCE" if compact else "01  EVIDENCE", _view.bind("board"), tabs, snapshot.view == "board")
	_button("REPORT" if compact else "02  BUILD REPORT", _view.bind("report"), tabs, snapshot.view == "report")
	workspace = HBoxContainer.new()
	workspace.size_flags_vertical = SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", ceili(10/physical))
	body.add_child(workspace)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",ceili(8/physical))
	body.add_child(footer)
	if snapshot.view == "results":
		_results()
	else:
		var wide: bool = size.x * physical >= 720 and not compact
		if (snapshot.view == "board" and (selected.is_empty() or wide)) or (snapshot.view == "report" and wide): _board()
		if snapshot.view == "report": _report()
		elif not selected.is_empty(): _inspect()
		_button(("USE SELECTED EVIDENCE" if not selected.is_empty() else "BUILD REPORT") if snapshot.view == "board" else "SUBMIT REPORT", _open_or_submit, footer, true)
	set_locked(locked)
	for node: Node in find_children("*", "ScrollContainer", true, false):
		(node as ScrollContainer).set_deferred("scroll_vertical", int(_scroll_positions.get(str(node.get_meta("scroll_key", "")),0)))

func _column(parent: Control, key: String = "board", paper: bool = false) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new() if paper else DeskSurface.new()
	if panel is DeskSurface: panel.unit = physical
	panel.add_theme_stylebox_override("panel",UI.box(CREAM if paper else Color("0E201F"),Color("b5ab91") if paper else Color("284b45"),ceili((8 if compact else 12)/physical)))
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column: VBoxContainer = UI.scroll_column(panel)
	column.add_theme_constant_override("separation",ceili((6 if compact else 10)/physical))
	(column.get_parent() as ScrollContainer).set_meta("scroll_key",key)
	return column

func _board() -> void:
	var column: VBoxContainer = _column(workspace)
	var count: int = 0
	for item: Dictionary in definition.items.values():
		if item.get("available",false): count += 1
	if not compact:
		_label("EVIDENCE DESK  /  %02d ITEMS" % count, column, 15, Color("8FF0E6"))
		_label("Tap to inspect · Drag or tap to place", column, 14, Color("a0b7bb"))
	var grid: GridContainer = GridContainer.new()
	var split: bool = not compact and (snapshot.view == "report" or not selected.is_empty())
	var available: float = size.x * physical * (0.5 if split else 1.0) - 65
	grid.columns = clampi(int(available / 165.0),1,4)
	grid.add_theme_constant_override("h_separation", ceili(12/physical))
	grid.add_theme_constant_override("v_separation", ceili(14/physical))
	column.add_child(grid)
	for id: String in definition.items:
		var item: Dictionary = definition.items[id]
		if not item.get("available", false): continue
		var card: EvidenceCard = EvidenceCard.new()
		card.item_id = id
		card.report = self
		card.kind = str(item.type)
		card.placed = id in snapshot.draft.values()
		card.name = "Evidence_" + id
		card.accessibility_name = _kind_name(card.kind) + ". " + str(item.title) + ". " + str(item.source) + (". In report." if card.placed else "")
		card.custom_minimum_size = Vector2(0,(134 if compact else 184)/physical)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		var paper: Color = Color("dce9e3") if card.kind == "sender" else Color("eee0b9") if card.kind == "excerpt" else CREAM
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = UI.box(Color.TRANSPARENT if state == "focus" else paper, CYAN if selected == id or state == "focus" else Color("a49a7c"),0)
			style.set_border_width_all(ceili((3 if selected == id else 1)/physical))
			style.set_corner_radius_all(ceili(3/physical))
			style.shadow_offset = Vector2(2,4)/physical
			card.add_theme_stylebox_override(state,style)
		card.pressed.connect(_select.bind(id))
		grid.add_child(card)

func _inspect() -> void:
	var column: VBoxContainer = _column(workspace,"inspect",true)
	var item: Dictionary = definition.items[selected]
	_label("EXHIBIT / " + _kind_name(str(item.type)).to_upper(),column,14,_kind_color(str(item.type)))
	_label(str(item.title),column,22,INK)
	_label(str(item.source),column,16,Color("365b63"))
	var texture: Texture2D = previews.get(str(item.get("capture_id", ""))) as Texture2D
	if texture != null:
		var image: TextureRect = TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size.y = 150/physical
		column.add_child(image)
	_label(str(item.text),column,18,INK)
	if selected in snapshot.draft.values(): _label("Already placed. Select a new slot to move it.",column,14,Color("365b63"))
	_button("BACK TO EVIDENCE", _clear_selection,column)

func _report() -> void:
	var column: VBoxContainer = _column(workspace,"report",true)
	if not compact: _label("INVESTIGATION REPORT",column,19,INK)
	var section: Dictionary = definition.sections[int(snapshot.section)]
	var claim: String = str(section.get("statement", "Select evidence that supports this finding: " + str(section.title) + "."))
	var sections: HBoxContainer = HBoxContainer.new()
	sections.add_theme_constant_override("separation",ceili(6/physical))
	if compact:
		var statement_row: HBoxContainer = HBoxContainer.new()
		statement_row.add_theme_constant_override("separation",ceili(12/physical))
		column.add_child(statement_row)
		var statement: Label = _label(claim,statement_row,18,INK)
		statement.name = "ReportStatement"
		statement.size_flags_horizontal = SIZE_EXPAND_FILL
		statement_row.add_child(sections)
		sections.custom_minimum_size.x = 180/physical
	else: column.add_child(sections)
	for index: int in definition.sections.size():
		var filled: int = 0
		for slot: Dictionary in definition.sections[index].slots:
			if snapshot.draft.has(slot.id): filled += 1
		var tab: Button = _button(("%02d\n%d/%d" if compact else "%02d · %d/%d") % [index+1,filled,definition.sections[index].slots.size()], _section.bind(index), sections, index == int(snapshot.section))
		tab.accessibility_name = "Section %d. %s. %d items placed." % [index+1,definition.sections[index].title,filled]
	if not compact:
		_label(str(section.title),column,20,INK)
		var statement: Label = _label(claim,column,18,INK)
		statement.name = "ReportStatement"
		if not selected.is_empty():
			var selection: Label = _label("PLACE: " + _kind_name(str(definition.items[selected].type)) + " / " + str(definition.items[selected].title),column,15,Color("365b63"))
			selection.max_lines_visible = 1
			selection.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var slots: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()
	slots.add_theme_constant_override("separation",ceili(8/physical))
	column.add_child(slots)
	for slot: Dictionary in section.slots:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation",ceili(6/physical))
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		slots.add_child(row)
		var target: ReportSlot = ReportSlot.new()
		target.report = self
		target.slot_id = str(slot.id)
		target.name = "Slot_" + str(slot.id)
		var item: String = str(snapshot.draft.get(slot.id, ""))
		target.text = str(slot.get("prompt", slot.label)) + "\n" + (str(definition.items[item].title) if not item.is_empty() else "+ Add supporting evidence")
		target.accessibility_name = target.text
		target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target.alignment = HORIZONTAL_ALIGNMENT_LEFT
		target.add_theme_font_override("font", UI.FONT)
		target.add_theme_font_size_override("font_size",ceili(17/physical))
		for key: String in ["normal","hover","pressed","disabled","focus"]:
			var style: StyleBoxFlat = UI.box(Color.TRANSPARENT if key == "focus" else Color("fffaf2") if item.is_empty() else Color("dce9e3"), Color("4d8d88") if not selected.is_empty() or key == "focus" else Color("b9b39e"),ceili(12/physical))
			style.shadow_size = 0
			style.border_width_left = ceili(4/physical)
			target.add_theme_stylebox_override(key,style)
		for key: String in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: target.add_theme_color_override(key,INK)
		target.custom_minimum_size.y = 82/physical
		target.size_flags_horizontal = SIZE_EXPAND_FILL
		target.pressed.connect(_slot_tapped.bind(str(slot.id)))
		row.add_child(target)
		if not item.is_empty():
			var remove: Button = _button("×",place.bind(str(slot.id),""),row)
			remove.size_flags_horizontal = SIZE_SHRINK_END
			remove.custom_minimum_size.x = 48/physical
			remove.accessibility_name = "Remove " + str(slot.label)

func _results() -> void:
	var column: VBoxContainer = _column(workspace,"results",true)
	_label("REPORT REVIEW",column,14,Color("365b63"))
	_label("%d / %d  MATCHED" % [snapshot.latest.score,snapshot.latest.total],column,30,INK)
	var first_text: String = "not recorded" if snapshot.first.is_empty() else "%d/%d" % [snapshot.first.score,snapshot.first.total]
	var best_text: String = "not recorded" if snapshot.best.is_empty() else "%d/%d" % [snapshot.best.score,snapshot.best.total]
	_label("First: " + first_text + " · Best: " + best_text,column,15,Color("365b63"))
	var reward: PanelContainer = UI.panel(column)
	reward.add_theme_stylebox_override("panel",UI.box(Color("0E2A28"),Color("4FE0D4"),ceili(12/physical)))
	_label(str(definition.get("reward_notice","Complete the chapter to record this report.")),reward,16,CREAM)
	for index: int in definition.sections.size():
		var section: Dictionary = definition.sections[index]
		var correct: int = 0
		for slot: Dictionary in section.slots:
			if snapshot.latest.correct.get(slot.id,false): correct += 1
		var review: PanelContainer = UI.panel(column)
		review.add_theme_stylebox_override("panel",UI.box(Color("fffaf2"),Color("b9b39e"),ceili(12/physical)))
		var details: VBoxContainer = UI.column(review,ceili(8/physical))
		_label("%02d  %s · %d/%d" % [index+1,section.title,correct,section.slots.size()],details,18,INK)
		for slot: Dictionary in section.slots:
			var passed: bool = snapshot.latest.correct.get(slot.id,false)
			_label(("✓ " if passed else "× ") + str(slot.label) + (" — matched" if passed else " — use " + str(definition.items[slot.answer].source) + " / " + _kind_name(str(definition.items[slot.answer].type))),details,16,Color("246844") if passed else Color("8a3b25"))
		_label(str(section.explanation),details,16,INK)
	_button("RETRY INVESTIGATION",_retry,column)
	_button("EDIT REPORT",_view.bind("report"),footer)
	_button("CONTINUE",_continue,footer,true)

func _select(id: String) -> void:
	if locked or not definition.items.has(id) or not definition.items[id].get("available", false): return
	selected = id
	snapshot.view = "board"
	# A newly inspected exhibit opens at its beginning, even after reading a long one.
	for node: Node in find_children("*", "ScrollContainer", true, false):
		if node.get_meta("scroll_key", "") == "inspect": (node as ScrollContainer).scroll_vertical = 0
	_scroll_positions["inspect"] = 0
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
	for node: Node in find_children("*", "ScrollContainer", true, false):
		if node.get_meta("scroll_key", "") == "report": (node as ScrollContainer).scroll_vertical = 0
	_scroll_positions["report"] = 0
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
