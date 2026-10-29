extends BaseScreen
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Data: GDScript = preload("res://src/ui/screens/progress/progress_data.gd")
const Radar: GDScript = preload("res://src/ui/screens/progress/mastery_radar.gd")
const Badge: GDScript = preload("res://src/ui/screens/progress/rank_badge.gd")
const GOOD: Color = Color("33D17A")
const WARN: Color = Color("FFB648")
var _tab: String = "Overview"
var _journey: String = "Story"
var _topic: int = 0
var _chapter: int = 0
var _module: int = 0
var _owner: String = ""
var _signed_in: bool = false
var _snapshot: Dictionary = {}
var _tabs: Dictionary = {}
var _body: VBoxContainer
var _back: Button
var _title: Label
var _radar: Control
var _topic_detail: VBoxContainer
var _topic_buttons: Array[Button] = []
var _journey_detail: VBoxContainer
var _journey_buttons: Array[Button] = []
var _touch: float = 64.0
var _font: int = 28
var _active: bool = true
var _refresh_queued: bool = false

func _ready() -> void:
	var shell: Dictionary = UI.shell(self, "STUDENT PROGRESS", func() -> void: Router.request_back())
	_back = shell.back
	_title = shell.title
	var layout: VBoxContainer = shell.layout
	var navigation: HBoxContainer = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	layout.add_child(navigation)
	for title: String in ["Overview", "Mastery", "Journey"]:
		var button: Button = UI.button(title.to_upper(), _select_tab.bind(title))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		navigation.add_child(button)
		_tabs[title] = button
	_body = UI.scroll_column(layout)
	_body.add_theme_constant_override("separation", 20)
	AuthService.progress_changed.connect(_request_refresh)
	PlayerManager.progress_changed.connect(_request_refresh)
	AuthService.session_changed.connect(_on_session_changed)
	SaveService.cloud_sync_completed.connect(_on_cloud_changed)
	SaveService.cloud_fetch_completed.connect(_on_cloud_changed)
	get_viewport().size_changed.connect(_request_refresh)
	_refresh()

func on_enter(_args: Dictionary) -> void:
	_active = true
	_tab = "Overview"
	_refresh()

func on_resume() -> void:
	_active = true
	_refresh()

func on_exit() -> void:
	_active = false

func _on_cloud_changed(_success: bool) -> void:
	_request_refresh()

func _on_session_changed(_session_signed_in: bool) -> void:
	_topic = 0
	_chapter = 0
	_module = 0
	_tab = "Overview"
	_journey = "Story"
	# Hide the previous student's record immediately; rebuild after hydration.
	UI.clear(_body)
	_request_refresh()

func _request_refresh() -> void:
	if _refresh_queued or not _active:
		return
	_refresh_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree() or not _active:
		return
	var scroll: ScrollContainer = _body.get_parent() as ScrollContainer
	var previous_scroll: int = scroll.scroll_vertical
	var pixels_per_unit: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_touch = maxf(64, ceilf(48 / pixels_per_unit))
	_font = maxi(28, ceili(16 / pixels_per_unit))
	_back.custom_minimum_size.y = _touch
	_back.custom_minimum_size.x = maxf(110, _font * 4.5)
	_back.add_theme_font_size_override("font_size", _font)
	_title.add_theme_font_size_override("font_size", maxi(20, ceili(14 / pixels_per_unit)))
	for title: String in _tabs:
		var button: Button = _tabs[title]
		button.custom_minimum_size.y = _touch
		button.add_theme_font_size_override("font_size", _font)
		button.add_theme_stylebox_override("normal", UI.box(UI.TEAL if title == _tab else UI.PANEL, UI.TEAL, 10))
		button.add_theme_color_override("font_color", UI.BG if title == _tab else UI.TEXT)
	_snapshot = Data.snapshot()
	_owner = AuthService.participant_code()
	_signed_in = AuthService.is_signed_in()
	UI.clear(_body)
	_radar = null
	_topic_buttons.clear()
	_journey_buttons.clear()
	match _tab:
		"Overview": _build_overview()
		"Mastery": _build_mastery()
		"Journey": _build_journey()
	scroll.set_deferred("scroll_vertical", previous_scroll)

func _select_tab(tab: String) -> void:
	_tab = tab
	(_body.get_parent() as ScrollContainer).scroll_vertical = 0
	_refresh()

func _label(text: String, color: Color = UI.TEXT, font_size: int = 0) -> Label:
	return UI.label(text, _font if font_size == 0 else font_size, color)

func _button(text: String, action: Callable, selected: bool = false) -> Button:
	var button: Button = UI.button(text, action, selected)
	button.custom_minimum_size.y = _touch
	button.add_theme_font_size_override("font_size", _font)
	return button

func _panel(parent: Node, color: Color = UI.PANEL) -> VBoxContainer:
	var panel: PanelContainer = UI.panel(parent, color)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	return UI.column(panel, 14)

func _row(parent: Node) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	return row

func _bar(parent: Node, value: float, total: float) -> void:
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = maxf(total, 1)
	bar.value = clampf(value, 0, bar.max_value)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UI.box(UI.BG, UI.BG, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	parent.add_child(bar)

func _build_overview() -> void:
	var account: VBoxContainer = _panel(_body)
	account.add_child(_label(str(_snapshot.account) + " / YOUR PROGRESS", UI.TEAL))
	account.add_child(_label(str(_snapshot.sync_label), WARN if _snapshot.sync_pending else UI.MUTED))
	var next: Dictionary = _snapshot.next
	var recommendation: VBoxContainer = _panel(_body, Color("0E2A28"))
	recommendation.add_child(_label("YOUR NEXT STEP", UI.TEAL, _font - 2))
	recommendation.add_child(_label(str(next.title), UI.TEXT, _font + 6))
	recommendation.add_child(_label(str(next.reason), UI.MUTED))
	recommendation.add_child(_button(str(next.button), _open_next))
	var summaries: GridContainer = GridContainer.new()
	summaries.columns = 2
	summaries.add_theme_constant_override("h_separation", 20)
	summaries.add_theme_constant_override("v_separation", 20)
	_body.add_child(summaries)
	_summary(summaries, "STORY", "%d / %d" % [_snapshot.chapter_done, _snapshot.chapter_total], "Chapters completed", float(_snapshot.chapter_done), float(_snapshot.chapter_total), _open_journey.bind("Story"))
	_summary(summaries, "LESSONS", "%d / %d" % [_snapshot.lesson_done, _snapshot.lesson_total], "Lessons completed", float(_snapshot.lesson_done), float(_snapshot.lesson_total), _open_journey.bind("Lessons"))
	_summary(summaries, "CHECKPOINTS", "%d / %d" % [_snapshot.checkpoint_done, _snapshot.checkpoint_total], "Module checkpoints passed", float(_snapshot.checkpoint_done), float(_snapshot.checkpoint_total), _open_journey.bind("Checkpoints"))
	_summary(summaries, "BKT ESTIMATE", "%d%%" % roundi(float(_snapshot.average) * 100) if _snapshot.assessed > 0 else "NOT ASSESSED", "Average across %d assessed topics" % _snapshot.assessed, float(_snapshot.average), 1, _select_tab.bind("Mastery"))
	_body.add_child(_label("BKT estimates, checkpoint scores and completion measure different things. They are not research pre/post-test results or proof of learning gains.", UI.MUTED))
	var rank: VBoxContainer = _panel(_body)
	var hero: HBoxContainer = _row(rank)
	var badge: Control = Badge.new()
	badge.rank_index = int(_snapshot.rank_index)
	hero.add_child(badge)
	var info: VBoxContainer = UI.column(hero, 10)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.add_child(_label("CURRENT RANK", UI.GOLD))
	info.add_child(_label(str(_snapshot.rank), UI.TEXT, _font + 14))
	info.add_child(_label("%d total rank points" % _snapshot.points, UI.MUTED))
	_bar(info, float(_snapshot.rank_value), float(_snapshot.rank_span))
	info.add_child(_label("Maximum rank reached" if _snapshot.max_rank else "%d / %d points this rank  |  %d to next rank" % [_snapshot.rank_value, _snapshot.rank_span, maxi(0, int(_snapshot.next_points) - int(_snapshot.points))], UI.TEAL))

func _open_next() -> void:
	if not _active or _owner != AuthService.participant_code() or _signed_in != AuthService.is_signed_in(): return
	# Re-evaluate at tap time: never launch an obsolete recommendation.
	var current: Dictionary = Data.snapshot()
	_open_learning(current.next.args)

func _open_learning(args: Dictionary) -> void:
	if not _active or _owner != AuthService.participant_code() or _signed_in != AuthService.is_signed_in(): return
	Router.push(&"lesson_player", args)

func _summary(parent: Node, title: String, value: String, caption: String, amount: float, total: float, action: Callable) -> void:
	# One large focusable/tappable card, not a tiny link inside a static panel.
	var button: Button = _button("", action)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size.y = maxf(240, _font * 7 + 60)
	parent.add_child(button)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var col: VBoxContainer = UI.column(margin, 12)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_label(title, UI.TEAL, _font - 2))
	col.add_child(_label(value, UI.TEXT, _font + 10))
	col.add_child(_label(caption, UI.MUTED, _font - 2))
	_bar(col, amount, total)
	col.add_child(_label("VIEW DETAILS  >", UI.TEAL, _font - 2))
	button.tooltip_text = title + ": " + value + " " + caption

func _build_mastery() -> void:
	var panels: HBoxContainer = _row(_body)
	var chart: VBoxContainer = _panel(panels, Color("101e28"))
	(chart.get_parent() as Control).size_flags_stretch_ratio = 0.60
	chart.add_child(_label("BKT ESTIMATES / 0–100%", UI.TEAL))
	_radar = Radar.new()
	_radar.font_size = _font - 2
	_radar.touch_height = _touch
	_radar.size_flags_horizontal = SIZE_EXPAND_FILL
	chart.add_child(_radar)
	# Fit a complete radar in the first view where space permits, never below 360.
	_radar.custom_minimum_size.y = maxf(380, (_body.get_parent() as Control).size.y - 94)
	_radar.configure(_snapshot.mastery, _topic)
	_radar.topic_selected.connect(_select_topic)
	chart.add_child(_label("Tap a topic or plotted point. Dashed axes are not assessed.", UI.MUTED, _font - 2))
	chart.add_child(_label("BKT estimates knowledge from responses, not quiz accuracy or lesson completion.", UI.MUTED, _font - 2))
	var details: VBoxContainer = _panel(panels)
	(details.get_parent() as Control).size_flags_stretch_ratio = 0.40
	details.add_child(_label("TOPIC MASTERY", UI.TEAL))
	_topic_detail = UI.column(details)
	var topic_list: VBoxContainer = UI.scroll_column(details)
	(topic_list.get_parent() as Control).custom_minimum_size.y = maxf(210, (_body.get_parent() as Control).size.y - 280)
	for i: int in _snapshot.mastery.size():
		var entry: Dictionary = _snapshot.mastery[i]
		var text: String = "%s   %s" % [entry.name, "%d%%" % roundi(float(entry.value) * 100) if entry.assessed else "—"]
		var button: Button = _button(text, _select_topic.bind(i), i == _topic)
		topic_list.add_child(button)
		_topic_buttons.append(button)
	_select_topic(_topic)

func _select_topic(index: int) -> void:
	_topic = clampi(index, 0, 4)
	if not is_instance_valid(_radar):
		return
	_radar.configure(_snapshot.mastery, _topic)
	for i: int in _topic_buttons.size():
		_topic_buttons[i].add_theme_stylebox_override("normal", UI.box(UI.TEAL if i == _topic else UI.PANEL, UI.TEAL, 10))
		_topic_buttons[i].add_theme_color_override("font_color", UI.BG if i == _topic else UI.TEXT)
	UI.clear(_topic_detail)
	var entry: Dictionary = _snapshot.mastery[_topic]
	_topic_detail.add_child(_label(str(entry.status).to_upper(), _status_color(str(entry.status))))
	_topic_detail.add_child(_label("%d%% estimated knowledge" % roundi(float(entry.value) * 100) if entry.assessed else "Complete this topic's pre-test to establish a starting estimate."))
	if entry.pending:
		_topic_detail.add_child(_label("Awaiting sync / local estimate", UI.GOLD))
	var module: Dictionary = _snapshot.modules[_topic]
	_topic_detail.add_child(_label(str(module.name) + " / " + str(LessonCatalog.module_by_id(str(module.id)).get("desc", "")), UI.MUTED))

func _status_color(status: String) -> Color:
	if status in ["Completed", "Proficient", "Available", "Passed", "Ready"]:
		return GOOD
	if status in ["Needs practice", "Locked"]:
		return WARN
	return UI.GOLD if status in ["Developing", "Pre-test required"] else UI.MUTED

func _open_journey(section: String) -> void:
	_journey = section
	_select_tab("Journey")

func _build_journey() -> void:
	var sections: HBoxContainer = _row(_body)
	for name: String in ["Story", "Lessons", "Checkpoints"]:
		var button: Button = _button(name.to_upper(), _open_journey.bind(name), name == _journey)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		sections.add_child(button)
	var panels: HBoxContainer = _row(_body)
	var index: VBoxContainer = _panel(panels)
	(index.get_parent() as Control).size_flags_stretch_ratio = 0.53
	_journey_detail = _panel(panels, Color("101e28"))
	(_journey_detail.get_parent() as Control).size_flags_stretch_ratio = 0.47
	if _journey == "Story":
		index.add_child(_label("MODULE 1 / EMAIL TRICKS", UI.TEAL))
		index.add_child(_label("%d / %d chapters completed" % [_snapshot.chapter_done, _snapshot.chapter_total]))
		var grid: GridContainer = GridContainer.new()
		grid.columns = 1
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		index.add_child(grid)
		for i: int in _snapshot.chapters.size():
			var entry: Dictionary = _snapshot.chapters[i]
			var text: String = "%02d  %s\n%s" % [entry.number, entry.name, entry.status]
			var button: Button = _button(text, _select_chapter.bind(i))
			button.custom_minimum_size.y = maxf(90, _touch)
			button.size_flags_horizontal = SIZE_EXPAND_FILL
			grid.add_child(button)
			_journey_buttons.append(button)
		_select_chapter(_chapter)
		for i: int in range(1, _snapshot.modules.size()):
			index.add_child(_label("MODULE %d / %s\nStory coming soon" % [i + 1, _snapshot.modules[i].name], UI.MUTED, _font - 2))
	else:
		index.add_child(_label("MODULE CHECKPOINTS" if _journey == "Checkpoints" else "LESSONS / %d TOTAL" % _snapshot.lesson_total, UI.TEAL))
		for i: int in _snapshot.modules.size():
			var entry: Dictionary = _snapshot.modules[i]
			var text: String = "%02d  %s\n%s" % [i + 1, entry.name, entry.checkpoint] if _journey == "Checkpoints" else "%02d  %s\n%d / %d  ·  %s" % [i + 1, entry.name, entry.done, entry.total, entry.status]
			var button: Button = _button(text, _select_module.bind(i))
			button.custom_minimum_size.y = maxf(90, _touch)
			index.add_child(button)
			_journey_buttons.append(button)
			if _journey == "Lessons": _bar(index, float(entry.done), float(entry.total))
		_select_module(_module)

func _highlight_journey(selection: int) -> void:
	for i: int in _journey_buttons.size():
		_journey_buttons[i].add_theme_stylebox_override("normal", UI.box(Color("234039") if i == selection else UI.PANEL, UI.TEAL if i == selection else Color("3b626a"), 10))

func _select_chapter(index: int) -> void:
	UI.clear(_journey_detail)
	_chapter = clampi(index, 0, _snapshot.chapters.size() - 1)
	_highlight_journey(_chapter)
	var entry: Dictionary = _snapshot.chapters[_chapter]
	_journey_detail.add_child(_label("CHAPTER %02d" % entry.number, UI.TEAL))
	_journey_detail.add_child(_label(str(entry.name), UI.TEXT, _font + 6))
	_journey_detail.add_child(_label(str(entry.status).to_upper(), _status_color(str(entry.status))))
	_journey_detail.add_child(_label("Completed in your story record." if entry.done else ("Ready to select from Deploy." if entry.status == "Available" else str(entry.reason))))
	if entry.done:
		var assistance: String = {"assisted":"Completed with hints or perks", "unassisted":"Completed without hints or perks", "unknown":"Assistance was not recorded"}.get(str(entry.assistance), "Assistance was not recorded")
		_journey_detail.add_child(_label(assistance, UI.MUTED))
	_journey_detail.add_child(_label("Story completion is separate from graded checkpoints and BKT estimates. Replays do not add another completed chapter.", UI.MUTED))

func _select_module(index: int) -> void:
	_module = clampi(index, 0, _snapshot.modules.size() - 1)
	_highlight_journey(_module)
	UI.clear(_journey_detail)
	var entry: Dictionary = _snapshot.modules[_module]
	_journey_detail.add_child(_label(str(entry.name).to_upper(), UI.TEAL))
	if _journey == "Checkpoints":
		_journey_detail.add_child(_label(str(entry.checkpoint).to_upper(), _status_color(str(entry.checkpoint))))
		_journey_detail.add_child(_label("Best saved score: %d / 25" % entry.best if int(entry.best) > 0 else "No passing result recorded."))
		_journey_detail.add_child(_label("Pass at 20 / 25. Checkpoint scores are separate from BKT estimates and research assessments.", UI.MUTED))
		if entry.checkpoint == "Locked":
			_journey_detail.add_child(_label("Complete this module's lessons first. Earlier module checkpoints control access.", WARN))
		else:
			_journey_detail.add_child(_button("REVIEW CHECKPOINT" if entry.passed else "OPEN CHECKPOINT", _open_learning.bind({"module_id":entry.id, "post_quiz":true})))
		return
	_journey_detail.add_child(_label(str(entry.status), _status_color(str(entry.status))))
	_journey_detail.add_child(_label("Pre-test: " + ("Completed" if entry.pretest else "Not taken"), UI.MUTED))
	if not entry.unlocked:
		_journey_detail.add_child(_label("Pass the preceding module's checkpoint to unlock this module.", UI.GOLD))
	else:
		_journey_detail.add_child(_button("REVIEW LESSONS" if int(entry.done) == int(entry.total) else "OPEN LESSON", _open_learning.bind({"module_id":entry.id, "review":int(entry.done) == int(entry.total)})))
	for i: int in entry.lessons.size():
		var done: bool = i < int(entry.done)
		var available: bool = entry.unlocked and entry.pretest and i == int(entry.done)
		var state: String = "Completed" if done else ("Available" if available else ("Pre-test required" if entry.unlocked and not entry.pretest and i == 0 else "Locked"))
		_journey_detail.add_child(_label("%s %02d  %s\n%s" % ["✓" if done else ("•" if available else "▣"), i + 1, entry.lessons[i].title, state], _status_color(state), _font - 2))
