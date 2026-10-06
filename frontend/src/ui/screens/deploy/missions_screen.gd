class_name MissionsScreen
extends BaseScreen
## Presentation only. TaskManager owns progress and automatic reward payouts.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const CREAM: Color = Color("#F3ECD6")
const INK: Color = Color("#101623")
const CYAN: Color = Color("#4FE0D4")
const NAVY: Color = Color("#0A1730")
const TABS: PackedStringArray = ["DAILY", "MAIN", "EVENT"]

var _tab_index: int = 0
var _selected_id: String = ""
var _tasks: Array[Dictionary] = []
var _compact: bool = false
var _details_open: bool = false
var _modal_card: PanelContainer
var _list_page: PanelContainer
var _detail_page: PanelContainer
var _cards: VBoxContainer
var _details: VBoxContainer
var _tabs: Array[Button] = []
var _back: Button
var _close: Button
var _heading: Label
var _tween: Tween

func _ready() -> void:
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.02, 0.04, 0.09, 0.88)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	dimmer.gui_input.connect(_on_dimmer_gui)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra_margin = 24
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	_modal_card = _panel(safe, Color("#173058"), Color("#64878B"), 14)
	var layout: VBoxContainer = UI.column(_modal_card, 16)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	_back = _button("MISSIONS", _return_to_list)
	header.add_child(_back)
	_heading = UI.label("MISSION JOURNAL", 24, CREAM, true)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_heading)
	_close = _button("X", _dismiss)
	_close.tooltip_text = "Close missions"
	header.add_child(_close)
	var pages: HBoxContainer = HBoxContainer.new()
	pages.add_theme_constant_override("separation", 18)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(pages)
	_list_page = _panel(pages, CREAM, Color("#B7AE96"), 22)
	_list_page.size_flags_stretch_ratio = 0.85
	var left: VBoxContainer = UI.column(_list_page, 18)
	left.add_child(UI.label("YOUR MISSIONS", 24, INK, true))
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	left.add_child(tabs)
	for index: int in TABS.size():
		var tab: Button = _button(TABS[index], _set_tab.bind(index))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
		_tabs.append(tab)
	_cards = _scroll(left)
	left.add_child(UI.label("Select a mission to view its objective.", 22, Color("#52616B")))
	_detail_page = _panel(pages, NAVY, Color("#34566C"), 24)
	_detail_page.size_flags_stretch_ratio = 1.15
	var right: VBoxContainer = UI.column(_detail_page, 16)
	_details = _scroll(right)
	right.add_child(UI.label("Rewards are credited automatically.", 22, UI.MUTED))
	resized.connect(_layout)
	_refresh_body()

func _panel(parent: Node, fill: Color, border: Color, padding: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.journal_box(fill, border, padding))
	parent.add_child(panel)
	return panel

func _button(text: String, callback: Callable) -> Button:
	var button: Button = UI.button(text, callback)
	button.custom_minimum_size = Vector2(64, 56)
	button.add_theme_stylebox_override("normal", UI.journal_box(NAVY, Color("#64878B"), 12))
	return button

func _scroll(parent: Node) -> VBoxContainer:
	var content: VBoxContainer = UI.scroll_column(parent)
	var scroll: ScrollContainer = content.get_parent() as ScrollContainer
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	return content

func on_enter(_args: Dictionary) -> void:
	_tab_index = 0
	_details_open = false
	_refresh_body()
	if _tween != null:
		_tween.kill()
	_modal_card.modulate.a = 1.0
	if not SettingsService.reduced_motion:
		_modal_card.modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(_modal_card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tabs[0].grab_focus()

func on_resume() -> void:
	_refresh_body()

func on_exit() -> void:
	if _tween != null:
		_tween.kill()

func _exit_tree() -> void:
	on_exit()

func can_go_back() -> bool:
	if _compact and _details_open:
		_return_to_list()
		return false
	return true

func _dismiss() -> void:
	_details_open = false
	Router.request_back()

func _on_dimmer_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and not _modal_card.get_global_rect().has_point(mouse.global_position):
			_dismiss()

func _set_tab(index: int) -> void:
	_tab_index = posmod(index, TABS.size())
	_details_open = false
	_selected_id = ""
	_refresh_body()
	(_cards.get_parent() as ScrollContainer).scroll_vertical = 0
	_tabs[_tab_index].grab_focus()

func _refresh_body() -> void:
	_tasks.clear()
	if _tab_index == 0:
		_tasks = TaskManager.get_active_tasks()
	var selected_exists: bool = false
	for task: Dictionary in _tasks:
		if str(task.get("id", "")) == _selected_id:
			selected_exists = true
	if not selected_exists:
		_selected_id = "" if _tasks.is_empty() else str(_tasks[0].get("id", ""))
	UI.clear(_cards)
	for task: Dictionary in _tasks:
		_add_card(task)
	if _tasks.is_empty():
		_cards.add_child(UI.label("No daily missions available." if _tab_index == 0 else ("No story directives yet." if _tab_index == 1 else "No active event."), 28, INK))
	for index: int in _tabs.size():
		_tabs[index].add_theme_stylebox_override("normal", UI.journal_box(Color("#153B37") if index == _tab_index else NAVY, CYAN if index == _tab_index else Color("#64878B"), 12))
	_fill_details()
	_layout()

func _add_card(task: Dictionary) -> void:
	var task_id: String = str(task.get("id", ""))
	var target: int = maxi(1, int(task.get("target", 1)))
	var current: int = clampi(int(task.get("current", 0)), 0, target)
	var selected: bool = task_id == _selected_id
	var color: Color = CREAM if selected else INK
	var button: Button = _button("", _select_task.bind(task_id))
	button.tooltip_text = str(task.get("title", "Mission"))
	button.custom_minimum_size.y = 158
	button.add_theme_stylebox_override("normal", UI.journal_box(Color("#153B37") if selected else Color("#E5DDC7"), CYAN if selected else Color("#B7AE96"), 16))
	button.add_theme_stylebox_override("hover", UI.journal_box(Color("#153B37") if selected else CREAM, CYAN, 16))
	button.add_theme_stylebox_override("pressed", UI.journal_box(Color("#153B37") if selected else CREAM, UI.GOLD, 16))
	var content: HBoxContainer = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16
	content.offset_right = -16
	content.offset_top = 16
	content.offset_bottom = -16
	content.add_theme_constant_override("separation", 18)
	button.add_child(content)
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = IntelPixelIcon.Kind.ENVELOPE if task_id == "defeat_fast" else IntelPixelIcon.Kind.BADGE
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.ink_override = CYAN if selected else Color("#356372")
	content.add_child(icon)
	var copy: VBoxContainer = UI.column(content, 10)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(UI.label(str(task.get("title", "Mission")), 28, color))
	copy.add_child(UI.label("COMPLETED" if current >= target else "%d / %d complete" % [current, target], 24, color))
	copy.add_child(_progress(current, target))
	_cards.add_child(button)
	copy.minimum_size_changed.connect(func() -> void: button.custom_minimum_size.y = maxf(158.0, copy.get_combined_minimum_size().y + 32.0))

func _select_task(task_id: String) -> void:
	_selected_id = task_id
	_details_open = true
	_refresh_body()
	(_details.get_parent() as ScrollContainer).scroll_vertical = 0
	if _compact:
		_back.grab_focus()
	else:
		_close.grab_focus()

func _fill_details() -> void:
	UI.clear(_details)
	var selected: Dictionary = {}
	for task: Dictionary in _tasks:
		if str(task.get("id", "")) == _selected_id:
			selected = task
	_details.add_child(UI.label(TABS[_tab_index] + " / MISSION DETAILS", 22, CYAN))
	if selected.is_empty():
		_details.add_child(UI.label("ALL QUIET", 30, CREAM, true))
		_details.add_child(UI.label("There are no missions in this category right now. Browse another tab to see your available objectives.", 28, UI.MUTED))
		return
	var target: int = maxi(1, int(selected.get("target", 1)))
	var current: int = clampi(int(selected.get("current", 0)), 0, target)
	var done: bool = current >= target
	_details.add_child(UI.label(str(selected.get("title", "Mission")).to_upper(), 28, CREAM, true))
	_details.add_child(UI.label(_task_blurb(_selected_id), 28, UI.MUTED))
	var objective: PanelContainer = _panel(_details, Color("#153B37") if done else Color("#102040"), Color("#34566C"), 20)
	var copy: VBoxContainer = UI.column(objective, 14)
	copy.add_child(UI.label("OBJECTIVE COMPLETED" if done else "OBJECTIVE IN PROGRESS", 24, Color("#33D17A") if done else CYAN))
	var status: HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override("separation", 16)
	copy.add_child(status)
	status.add_child(UI.journal_check(done))
	var count: Label = UI.label("%d / %d" % [current, target], 32, CREAM)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.add_child(count)
	copy.add_child(_progress(current, target))
	_details.add_child(UI.label("REWARD", 22, CYAN))
	var reward: PanelContainer = _panel(_details, Color("#102040"), Color("#34566C"), 20)
	var reward_copy: VBoxContainer = UI.column(reward, 10)
	reward_copy.add_child(UI.label("+%d CR" % maxi(0, int(selected.get("reward", 0))), 32, UI.GOLD))
	reward_copy.add_child(UI.label("Credited on completion" if done else "Earned when the objective is complete", 24, UI.MUTED))

func _progress(current: int, target: int) -> ProgressBar:
	var progress: ProgressBar = ProgressBar.new()
	progress.custom_minimum_size.y = 12
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.show_percentage = false
	progress.max_value = target
	progress.value = current
	progress.add_theme_stylebox_override("background", UI.box(NAVY, Color("#34566C"), 0))
	progress.add_theme_stylebox_override("fill", UI.box(Color("#33D17A") if current >= target else CYAN, CYAN, 0))
	return progress

func _task_blurb(task_id: String) -> String:
	if task_id == "defeat_fast":
		return "Intercept fast packets in any deployed stage."
	if task_id == "clear_stages":
		return "Clear stages to complete this directive."
	return "Complete this directive during deploy."

func _return_to_list() -> void:
	_details_open = false
	_layout()
	_tabs[_tab_index].grab_focus()

func _layout() -> void:
	if not is_instance_valid(_modal_card):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	_compact = size.x * physical < 1000.0
	_list_page.visible = not _compact or not _details_open
	_detail_page.visible = not _compact or _details_open
	_back.visible = _compact and _details_open
	_heading.text = "MISSION DETAILS" if _compact and _details_open else "MISSION JOURNAL"
	UI.fit_touch(self)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		Router.request_back()
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
