extends Control
## Read-only view: the dashboard owns routing; WorldAccess owns gate snapshots.
signal dismissed
signal route_requested(route: StringName)
signal missions_requested

const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const CREAM: Color = Color("#F3ECD6")
const INK: Color = Color("#101623")
const CYAN: Color = Color("#4FE0D4")
const NAVY: Color = Color("#0A1730")
const MUTED: Color = Color("#A0B7BB")
const ICONS: Array[IntelPixelIcon.Kind] = [IntelPixelIcon.Kind.ENVELOPE, IntelPixelIcon.Kind.CHAT, IntelPixelIcon.Kind.PHONE, IntelPixelIcon.Kind.BADGE, IntelPixelIcon.Kind.PICKAXE]

var action: Button
var _snapshot: Dictionary = {}
var _selected: int = 0
var _completed_only: bool = false
var _compact: bool = false
var _details_open: bool = false
var _safe: SafeAreaContainer
var _book: PanelContainer
var _pages: HBoxContainer
var _list_page: PanelContainer
var _detail_page: PanelContainer
var _cards: VBoxContainer
var _details: VBoxContainer
var _tabs: Array[Button] = []
var _back: Button
var _close: Button
var _heading: Label
var _tween: Tween
var _previous_focus: Control
var _route: StringName = &"lessons"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.09, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_safe = SafeAreaContainer.new()
	_safe.extra_margin = 24
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	_book = PanelContainer.new()
	_book.add_theme_stylebox_override("panel", _paper(Color("#173058"), Color("#64878B"), 14))
	_safe.add_child(_book)
	var layout: VBoxContainer = UI.column(_book, 16)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	_back = _button("WORLDS", _return_to_list)
	header.add_child(_back)
	_heading = UI.label("WORLD JOURNAL", 24, CREAM, true)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_heading)
	_close = _button("X", _dismiss)
	_close.tooltip_text = "Close world journal"
	header.add_child(_close)
	_pages = HBoxContainer.new()
	_pages.add_theme_constant_override("separation", 18)
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_pages)
	_list_page = PanelContainer.new()
	_list_page.add_theme_stylebox_override("panel", _paper(CREAM, Color("#B7AE96"), 22))
	_list_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_page.size_flags_stretch_ratio = 0.85
	_pages.add_child(_list_page)
	var left: VBoxContainer = UI.column(_list_page, 18)
	left.add_child(UI.label("YOUR WORLDS", 24, INK, true))
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	left.add_child(tabs)
	for index: int in 2:
		var tab: Button = _button("ALL" if index == 0 else "COMPLETED", _set_filter.bind(index == 1))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
		_tabs.append(tab)
	_cards = _scroll(left)
	var tip: Label = UI.label("Scroll to explore. Select a world.", 22, Color("#52616B"))
	left.add_child(tip)
	_detail_page = PanelContainer.new()
	_detail_page.add_theme_stylebox_override("panel", _paper(NAVY, Color("#34566C"), 24))
	_detail_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_page.size_flags_stretch_ratio = 1.15
	_pages.add_child(_detail_page)
	var right: VBoxContainer = UI.column(_detail_page, 16)
	_details = _scroll(right)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	right.add_child(actions)
	action = _button("CONTINUE", _navigate, true)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action)
	var missions: Button = _button("MISSIONS", func() -> void: missions_requested.emit())
	actions.add_child(missions)
	resized.connect(_layout)
	hide()

func _paper(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	return UI.journal_box(fill, border, padding)

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = UI.button(text, callback, primary)
	button.custom_minimum_size = Vector2(64, 56)
	button.add_theme_stylebox_override("normal", _paper(CYAN if primary else NAVY, CYAN if primary else Color("#64878B"), 12))
	return button

func _scroll(parent: Node) -> VBoxContainer:
	var column: VBoxContainer = UI.scroll_column(parent)
	var scroll: ScrollContainer = column.get_parent() as ScrollContainer
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	column.add_theme_constant_override("separation", 14)
	return column

func open(state: Dictionary) -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	_details_open = false
	show()
	refresh(state)
	if _tween != null:
		_tween.kill()
	_book.modulate.a = 1.0
	if not SettingsService.reduced_motion:
		_book.modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(_book, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tabs[0].grab_focus()

func close() -> void:
	if _tween != null:
		_tween.kill()
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()

func back() -> void:
	if _compact and _details_open:
		_return_to_list()
	else:
		_dismiss()

func _dismiss() -> void:
	close()
	dismissed.emit()

func refresh(state: Dictionary) -> void:
	_snapshot = state
	_rebuild_cards()
	_rebuild_details()
	_layout()

func _is_complete(index: int) -> bool:
	# Future worlds cannot be cleared before their stages exist.
	if index != 0 or _snapshot.stages.is_empty():
		return false
	var module: Dictionary = _snapshot.modules[index]
	if int(module.done) < int(module.total):
		return false
	for stage: Dictionary in _snapshot.stages:
		if not bool(stage.done):
			return false
	return true

func _set_filter(completed: bool) -> void:
	_completed_only = completed
	_details_open = false
	refresh(_snapshot)
	_tabs[1 if completed else 0].grab_focus()

func _rebuild_cards() -> void:
	UI.clear(_cards)
	var available: Array[int] = []
	for index: int in _snapshot.modules.size():
		if not _completed_only or _is_complete(index):
			available.append(index)
	if not available.has(_selected):
		_selected = -1 if available.is_empty() else available[0]
	for index: int in available:
		var module: Dictionary = _snapshot.modules[index]
		var card: Button = _button("", select_world.bind(index))
		card.name = "World%d" % (index + 1)
		card.custom_minimum_size.y = 136
		card.tooltip_text = str(module.title)
		card.add_theme_stylebox_override("normal", _paper(Color("#153B37") if index == _selected else Color("#E5DDC7"), CYAN if index == _selected else Color("#B7AE96"), 16))
		card.add_theme_stylebox_override("hover", _paper(Color("#153B37") if index == _selected else CREAM, CYAN, 16))
		card.add_theme_stylebox_override("pressed", _paper(Color("#153B37") if index == _selected else CREAM, UI.GOLD, 16))
		var content: HBoxContainer = HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 16
		content.offset_right = -16
		content.offset_top = 14
		content.offset_bottom = -14
		content.add_theme_constant_override("separation", 18)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		var icon: IntelPixelIcon = IntelPixelIcon.new()
		icon.kind = ICONS[index % ICONS.size()]
		icon.ink_override = CYAN if index == _selected else Color("#356372")
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		var copy: VBoxContainer = UI.column(content, 7)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color: Color = CREAM if index == _selected else INK
		copy.add_child(UI.label("%02d  /  %s" % [index + 1, module.name], 28, color))
		copy.add_child(UI.label("CLEARED" if _is_complete(index) else (str(module.status) if index == 0 else "STAGES COMING SOON"), 20, CYAN if index == _selected else Color("#52616B")))
		copy.add_child(UI.label("Lessons  %d / %d" % [module.done, module.total], 22, color))
		_cards.add_child(card)
	if available.is_empty():
		_cards.add_child(UI.label("No worlds cleared yet.\nFinish a world's lessons and stages to add it here.", 26, INK))
	for index: int in _tabs.size():
		_tabs[index].add_theme_stylebox_override("normal", _paper(Color("#153B37") if _completed_only == (index == 1) else NAVY, CYAN if _completed_only == (index == 1) else Color("#64878B"), 12))

func select_world(index: int) -> void:
	_selected = index
	_details_open = true
	refresh(_snapshot)
	(_details.get_parent() as ScrollContainer).scroll_vertical = 0
	if _compact:
		_back.grab_focus()
	else:
		action.grab_focus()

func _rebuild_details() -> void:
	UI.clear(_details)
	action.disabled = _selected < 0
	if _selected < 0:
		_details.add_child(UI.label("YOUR NEXT CHAPTER", 26, CYAN, true))
		_details.add_child(UI.label("Your completed worlds will be collected here.", 28, CREAM))
		return
	var module: Dictionary = _snapshot.modules[_selected]
	_details.add_child(UI.label("WORLD %02d  /  FIELD DOSSIER" % (_selected + 1), 22, CYAN))
	_details.add_child(UI.label(str(module.name).to_upper(), 30, CREAM, true))
	_details.add_child(UI.label(str(module.summary) + ".", 28, MUTED))
	var requirement: PanelContainer = UI.panel(_details, Color("#102040"))
	var requirements: VBoxContainer = UI.column(requirement, 10)
	requirements.add_child(UI.label("NEXT OBJECTIVE", 22, CYAN))
	if _selected == 0:
		requirements.add_child(UI.label(str(_snapshot.heading), 27, CREAM))
		requirements.add_child(UI.label(str(_snapshot.hint), 24, MUTED))
		_route = _snapshot.route
		action.text = str(_snapshot.action)
	else:
		requirements.add_child(UI.label(str(module.reason), 26, CREAM))
		_route = &"lessons"
		action.text = "OPEN LESSONS"
	_details.add_child(UI.label("JOURNEY CHECKLIST", 22, CYAN))
	_check_row("Lesson preparation", "%d / %d lessons complete" % [module.done, module.total], int(module.done) >= int(module.total), false)
	if _selected == 0:
		for stage: Dictionary in _snapshot.stages:
			var note: String = "Cleared" if bool(stage.done) else "Ready to deploy"
			if str(stage.status) == "LOCKED":
				note = str(stage.reason)
				if PlayerManager.is_stage_locked("mod_01", int(stage.id)):
					note += " Reviewing does not automatically remove this lock."
			_check_row(str(stage.title), note, bool(stage.done), str(stage.status) == "LOCKED")
	else:
		_details.add_child(UI.label("No stages published for this world yet.", 24, MUTED))

func _check_row(title: String, note: String, done: bool, locked: bool) -> void:
	var row: PanelContainer = UI.panel(_details, Color("#153B37") if done else Color("#102040"))
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	row.add_child(content)
	var mark: Control = UI.journal_check(done)
	content.add_child(mark)
	var copy: VBoxContainer = UI.column(content, 6)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UI.label(title, 26, CREAM))
	copy.add_child(UI.label(("LOCKED / " if locked else "") + note, 23, MUTED))

func _navigate() -> void:
	if _selected >= 0:
		route_requested.emit(_route)

func _return_to_list() -> void:
	_details_open = false
	_layout()
	_tabs[0].grab_focus()

func _layout() -> void:
	if not is_instance_valid(_book):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	_compact = size.x * physical < 1000.0
	_back.visible = _compact and _details_open
	_list_page.visible = not _compact or not _details_open
	_detail_page.visible = not _compact or _details_open
	_heading.text = "WORLD DETAILS" if _compact and _details_open else "WORLD JOURNAL"
	UI.fit_touch(self)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control] = []
		for node: Node in find_children("*", "Button", true, false):
			var button: Button = node as Button
			if button.is_visible_in_tree() and not button.disabled:
				controls.append(button)
		if not controls.is_empty():
			var index: int = controls.find(get_viewport().gui_get_focus_owner())
			var step: int = -1 if event.is_action_pressed("ui_focus_prev") else 1
			controls[posmod(index + step, controls.size())].grab_focus()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
