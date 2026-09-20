class_name LessonPlayerScreen
extends BaseScreen
## Read > check understanding > safely perform the response. Saves only after both checks.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Study = preload("res://src/ui/screens/intel/lesson_study_content.gd")
const Desktop = preload("res://src/ui/screens/intel/lesson_desktop_sim.gd")
const Feedback = preload("res://src/ui/screens/intel/study_feedback.gd")
const PathNode = preload("res://src/ui/screens/intel/lesson_path_node.gd")
const COMPLETE_FILL := Color("193a2b")
const COMPLETE_INK := Color("a3e6b0")

class PathLinks extends HBoxContainer:
	var ink := Color("3b626a")
	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			queue_redraw()
	func _draw() -> void:
		if get_child_count() != 3:
			return
		var points := PackedVector2Array()
		for column in get_children():
			var node := column.get_child(0) as Control
			points.append(column.position + node.position + node.size * 0.5)
		draw_polyline(points, ink, 3, true)
enum Phase { DEFINITION, QUIZ, SIMULATION, COMPLETE }
var _module_id := ""
var _lesson_index := 0
var _lessons: Array[Dictionary] = []
var _review_mode := false
var _busy := false
var _phase: Phase = Phase.DEFINITION
var _quiz_passed := false
var _simulation_passed := false
var _picks: Array[int] = []
var _data: Dictionary = {}
var _side: VBoxContainer
var _content: VBoxContainer
var _phase_label: Label
var _progress_label: Label
var _status_label: Label
var _submit_button: Button
var _close_button: Button
var _quiz_buttons: Array[Button] = []
var _simulation: Control
var _tutorial_overlay: TutorialOverlay
var _panes: HBoxContainer
var _pending_entry: Dictionary = {}
var _answer_effect: Control
var _roadmap: VBoxContainer
var _workspace: PanelContainer
var _start_button: Button
var _page_back: Button
var _reading_page := 0
var _read_passed := false
var _in_lesson := false
var _reading_progress: ProgressBar
var _header_title: Label
var _status_scroll: ScrollContainer

func _ready() -> void:
	var shell := UI.shell(self, "LEARNING PATH", func() -> void: Router.request_back())
	_close_button = shell.back
	_header_title = shell.title
	var layout: VBoxContainer = shell.layout
	_progress_label = UI.label("", 24, UI.TEAL)
	layout.add_child(_progress_label)
	_panes = HBoxContainer.new()
	_panes.name = "StudyPanels"
	_panes.add_theme_constant_override("separation", 24)
	_panes.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(_panes)
	var left := UI.panel(_panes)
	left.name = "TopicInfo"
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.32
	_side = UI.scroll_column(left)
	var right := UI.panel(_panes, Color("101e28"))
	right.name = "ModuleRoadmap"
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.68
	var path_column := UI.column(right, 12)
	_roadmap = UI.scroll_column(path_column)
	_start_button = UI.button("START LESSON  >", _open_lesson, true)
	path_column.add_child(_start_button)
	_workspace = UI.panel(layout, Color("101e28"))
	_workspace.name = "LessonWorkspace"
	_workspace.size_flags_vertical = SIZE_EXPAND_FILL
	_workspace.hide()
	var right_column := UI.column(_workspace, 12)
	_phase_label = UI.label("", 23, UI.TEAL)
	right_column.add_child(_phase_label)
	_reading_progress = ProgressBar.new()
	_reading_progress.custom_minimum_size.y = 6
	_reading_progress.show_percentage = false
	_reading_progress.max_value = 3
	_reading_progress.add_theme_stylebox_override("background", UI.box(UI.BG, UI.BG, 0))
	_reading_progress.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	right_column.add_child(_reading_progress)
	_content = UI.scroll_column(right_column)
	_status_scroll = ScrollContainer.new()
	_status_scroll.name = "AnswerExplanation"
	_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_status_scroll.custom_minimum_size.y = 88
	right_column.add_child(_status_scroll)
	_status_label = UI.label("", 22, UI.GOLD)
	_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_status_scroll.add_child(_status_label)
	_status_scroll.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	right_column.add_child(actions)
	_page_back = UI.button("< PREVIOUS", _previous_page)
	_page_back.custom_minimum_size.x = 190
	actions.add_child(_page_back)
	_submit_button = UI.button("START MINI QUIZ  >", _on_continue, true)
	_submit_button.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(_submit_button)
	_answer_effect = Feedback.mount(_workspace)
	get_viewport().size_changed.connect(_fit_readability)

func on_enter(args: Dictionary) -> void:
	_pending_entry = {}
	var module_id := str(args.get("module_id", "mod_01"))
	var tutorial := Router.is_tutorial and (Router.tutorial_beat == &"lesson" or bool(args.get("tutorial", false)))
	if tutorial:
		module_id = "mod_01"
	var completed := PlayerManager.get_lesson_progress(module_id) >= LessonCatalog.lesson_count(module_id)
	if not tutorial:
		var ids := LessonCatalog.module_ids()
		var module_index := ids.find(module_id)
		if module_index < 0:
			Router.request_back()
			return
		if module_index > 0 and PlayerManager.get_lesson_progress(ids[module_index - 1]) < LessonCatalog.lesson_count(ids[module_index - 1]):
			Router.request_back()
			return
		if not completed and not AuthService.has_module_pretest(module_id):
			_pending_entry = args.duplicate()
			_pending_entry["module_id"] = module_id
			Router.push(&"pretest", {"module_id": module_id})
			return
	_load_module(module_id, bool(args.get("review", false)) and completed, tutorial)
	if tutorial:
		_begin_tutorial_coach()

func on_resume() -> void:
	if not _pending_entry.is_empty():
		var args := _pending_entry.duplicate()
		_pending_entry = {}
		if AuthService.has_module_pretest(str(args.get("module_id", "mod_01"))):
			on_enter(args)
		else:
			Router.request_back()

func _load_module(module_id: String, review: bool = false, tutorial: bool = false) -> void:
	_module_id = module_id
	_review_mode = review
	_lessons = LessonCatalog.lessons_for(module_id)
	if _lessons.is_empty():
		_status_label.text = "No lessons are available for this module."
		_submit_button.disabled = true
		return
	_lesson_index = 0 if review or tutorial else clampi(PlayerManager.get_lesson_progress(module_id), 0, _lessons.size() - 1)
	_close_button.visible = not tutorial
	_start_lesson()

func _start_lesson() -> void:
	_busy = false
	_quiz_passed = false
	_simulation_passed = false
	_picks.clear()
	_read_passed = false
	_reading_page = 0
	_data = Study.build(_module_id, _lesson_index)
	_refresh_topic_info()
	_set_phase(Phase.DEFINITION)
	_show_roadmap()
	_scroll_to_selected.call_deferred()

func _scroll_to_selected() -> void:
	var selected := _roadmap.find_child("TopicPath%d" % (_lesson_index + 1), true, false)
	if selected != null:
		(_roadmap.get_parent() as ScrollContainer).ensure_control_visible(selected)

func _refresh_topic_info() -> void:
	UI.clear(_side)
	var module := LessonCatalog.module_by_id(_module_id)
	_progress_label.text = "%s  /  TOPIC %02d OF %02d%s" % [str(module.get("title", "")).to_upper(), _lesson_index + 1, _lessons.size(), "  /  REVIEW" if _review_mode else ""]
	_side.add_child(UI.label("TOPIC BRIEF", 14, UI.TEAL, true))
	_side.add_child(UI.label(str(_data.title), 28))
	_side.add_child(UI.label(str(_data.term).to_upper(), 17, UI.GOLD, true))
	_side.add_child(UI.label(str(_data.rule), 23, UI.MUTED))
	var progress := PlayerManager.get_lesson_progress(_module_id)
	_side.add_child(HSeparator.new())
	_side.add_child(UI.label("%d / %d TOPICS COMPLETED" % [progress, _lessons.size()], 23, COMPLETE_INK))
	_side.add_child(UI.label("Read the lesson, check your understanding, then try it in a safe simulation. Each complete topic unlocks the next.", 24, UI.MUTED))
	_side.add_child(UI.label("Progress is saved after finishing all three steps of a topic.", 22, UI.GOLD))
	if progress >= _lessons.size():
		_side.add_child(UI.label("MODULE COMPLETE\nYour entire path is open for review.", 26, COMPLETE_INK))
	var left := _panes.get_child(0) as PanelContainer
	left.add_theme_stylebox_override("panel", UI.box(COMPLETE_FILL if _lesson_index < progress else UI.PANEL, COMPLETE_INK if _lesson_index < progress else UI.TEAL))

func _refresh_roadmap() -> void:
	UI.clear(_roadmap)
	var progress := PlayerManager.get_lesson_progress(_module_id)
	for i in _lessons.size():
		var finished := i < progress
		var locked := (not _review_mode and i > progress) or (Router.is_tutorial and i != 0)
		if i > 0:
			var stem := ColorRect.new()
			stem.color = COMPLETE_INK if i <= progress else Color("3b626a")
			stem.custom_minimum_size = Vector2(3, 18)
			stem.size_flags_horizontal = SIZE_SHRINK_CENTER
			stem.mouse_filter = MOUSE_FILTER_IGNORE
			_roadmap.add_child(stem)
		var card := UI.panel(_roadmap, COMPLETE_FILL if finished else UI.PANEL)
		card.name = "TopicPath%d" % (i + 1)
		card.add_theme_stylebox_override("panel", UI.box(COMPLETE_FILL if finished else (Color("1b2027") if locked else UI.PANEL), UI.GOLD if i == _lesson_index else (COMPLETE_INK if finished else Color("3b626a")), 12))
		var column := UI.column(card, 8)
		var select := UI.button("TOPIC %02d%s" % [i + 1, " / SELECTED" if i == _lesson_index else ""], _select_topic.bind(i))
		select.name = "SelectTopic"
		if locked:
			UI.lock_topic(select, "Complete Topic %02d first." % i)
		elif finished:
			select.add_theme_stylebox_override("normal", UI.box(COMPLETE_FILL, COMPLETE_INK, 10))
			select.add_theme_color_override("font_color", COMPLETE_INK)
		column.add_child(select)
		var links := PathLinks.new()
		links.ink = COMPLETE_INK if finished else Color("3b626a")
		links.add_theme_constant_override("separation", 0)
		column.add_child(links)
		for step in 3:
			var node_column := UI.column(links, 5)
			node_column.size_flags_horizontal = SIZE_EXPAND_FILL
			var node := PathNode.new()
			node.name = "Step%d" % step
			node.kind = step
			node.complete = finished or (i == _lesson_index and [_read_passed, _quiz_passed, _simulation_passed][step])
			node.disabled = locked or (not finished and (i != _lesson_index or not _read_passed) and step == 1) or (not finished and (i != _lesson_index or not _quiz_passed) and step == 2)
			node.ink = UI.MUTED if node.disabled else (COMPLETE_INK if node.complete else UI.TEAL)
			node.custom_minimum_size = Vector2(80, 80)
			node.size_flags_horizontal = SIZE_SHRINK_CENTER
			node.add_theme_stylebox_override("normal", UI.box(COMPLETE_FILL if node.complete else Color("203b43"), node.ink, 4))
			node.add_theme_stylebox_override("disabled", UI.box(Color("1b2027"), Color("48505a"), 4))
			node.add_theme_stylebox_override("hover", UI.box(Color("30543d"), UI.GOLD, 4))
			node.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, UI.GOLD, 0))
			node.tooltip_text = ["Read definitions and examples", "Finish reading before the mini quiz", "Pass the mini quiz before practice"][step]
			node.pressed.connect(_open_step.bind(i, step))
			node_column.add_child(node)
			var caption := UI.label(["Learn", "Quiz", "Practice"][step], 22, node.ink)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node_column.add_child(caption)
		if locked:
			column.add_child(UI.label("Finish the tutorial first." if Router.is_tutorial else "Complete Topic %02d to unlock." % i, 22, UI.MUTED))
	_start_button.text = "CONTINUE LESSON  >" if _read_passed or _reading_page > 0 else ("REVIEW LESSON  >" if _lesson_index < progress else "START LESSON  >")
	_fit_readability.call_deferred()

func _show_roadmap() -> void:
	_in_lesson = false
	_workspace.hide()
	_panes.show()
	_header_title.text = "LEARNING PATH"
	_close_button.text = "< BACK"
	_answer_effect.reset()
	_refresh_roadmap()

func _open_lesson() -> void:
	_in_lesson = true
	_panes.hide()
	_workspace.show()
	_header_title.text = str(_data.title).to_upper()
	_close_button.text = "< PATH"

func _open_step(index: int, step: int) -> void:
	if index != _lesson_index:
		_select_topic(index)
	if index != _lesson_index:
		return
	# Completed nodes offer review, but never bypass the current practice checks.
	if step == 0:
		_reading_page = 0
		_set_phase(Phase.DEFINITION)
	elif step == 1 and _read_passed:
		_set_phase(Phase.QUIZ)
	elif step == 2 and _quiz_passed:
		_set_phase(Phase.SIMULATION)
	_open_lesson()

func can_go_back() -> bool:
	if _in_lesson:
		_show_roadmap()
		return false
	return true

func _previous_page() -> void:
	if _phase == Phase.DEFINITION and _reading_page > 0:
		_reading_page -= 1
		_set_phase(Phase.DEFINITION)

func _fit_readability() -> void:
	# Godot stretches the logical canvas on phones. Keep text and taps usable
	# in physical pixels; overflowing content scrolls instead of shrinking.
	var physical_scale := minf(float(get_window().size.x) / get_viewport_rect().size.x, float(get_window().size.y) / get_viewport_rect().size.y)
	physical_scale = maxf(0.5, physical_scale)
	for control in find_children("*", "Control", true, false):
		if control is Label or control is Button:
			if not control.has_meta("lesson_font_size"):
				control.set_meta("lesson_font_size", control.get_theme_font_size("font_size"))
			var base_size := int(control.get_meta("lesson_font_size"))
			control.add_theme_font_size_override("font_size", maxi(base_size, ceili(16.0 / physical_scale)))
		if control is Button:
			if not control.has_meta("lesson_minimum"):
				control.set_meta("lesson_minimum", control.custom_minimum_size)
			var minimum: Vector2 = control.get_meta("lesson_minimum")
			control.custom_minimum_size = Vector2(minimum.x, maxf(minimum.y, ceilf(44.0 / physical_scale)))
	# These short navigation labels should never split in the middle of a word.
	for button in [_close_button, _page_back]:
		button.custom_minimum_size.x = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + 28

func _select_topic(index: int) -> void:
	if index < 0 or index >= _lessons.size() or _busy:
		return
	if index == _lesson_index:
		return
	if not _review_mode and index > PlayerManager.get_lesson_progress(_module_id):
		return
	if Router.is_tutorial and index != 0:
		return
	_lesson_index = index
	_start_lesson()

func _set_phase(phase: Phase) -> void:
	if phase == Phase.QUIZ and not _read_passed:
		return
	if phase == Phase.SIMULATION and not _quiz_passed:
		return
	if phase == Phase.COMPLETE and (not _quiz_passed or not _simulation_passed):
		return
	_phase = phase
	_answer_effect.reset()
	UI.clear(_content)
	_quiz_buttons.clear()
	_simulation = null
	_status_label.text = ""
	_status_scroll.hide()
	_status_scroll.scroll_vertical = 0
	_status_label.add_theme_color_override("font_color", UI.GOLD)
	_submit_button.disabled = false
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	_phase_label.text = ["LEARN / %d OF 3" % (_reading_page + 1), "CHECK YOUR UNDERSTANDING", "PUT IT INTO PRACTICE", "TOPIC COMPLETE"][_phase]
	_page_back.visible = _phase == Phase.DEFINITION and _reading_page > 0
	_reading_progress.visible = _phase == Phase.DEFINITION
	_reading_progress.value = _reading_page + 1
	match _phase:
		Phase.DEFINITION:
			_build_reading_page()
			_submit_button.text = "START MINI QUIZ  >" if _reading_page == 2 else "CONTINUE  >"
		Phase.QUIZ:
			_content.add_child(UI.label(str(_data.question), 28))
			_content.add_child(UI.label(str(_data.get("quiz_scenario", _data.scenario)), 24, UI.MUTED))
			if bool(_data.multi):
				_content.add_child(UI.label("Select every correct detail, then check your answer.", 22, UI.GOLD))
			for i in _data.options.size():
				var button := UI.button(str(_data.options[i]), _pick.bind(i))
				_quiz_buttons.append(button)
				_content.add_child(button)
			_refresh_choices()
			_submit_button.text = "START SIMULATION  >" if _quiz_passed else "CHECK ANSWER"
		Phase.SIMULATION:
			_simulation = Desktop.new()
			_content.add_child(_simulation)
			_simulation.setup(_data)
			_simulation.passed.connect(_on_simulation_passed)
			_submit_button.text = "COMPLETE THE SIMULATION"
			_submit_button.disabled = true
		Phase.COMPLETE:
			_content.add_child(UI.label("SAFE RESPONSE CONFIRMED", 23, UI.TEAL, true))
			_content.add_child(UI.label(str(_data.summary), 28))
			_content.add_child(UI.label("You identified the threat and handled the request in a safe training environment.", 26, UI.MUTED))
			_submit_button.text = "FINISH TOPIC  >"
	if _phase == Phase.QUIZ:
		_content.add_child(UI.button("< Review lesson", func() -> void:
			_reading_page = 0
			_set_phase(Phase.DEFINITION)
		))
	_fit_readability.call_deferred()

func _build_reading_page() -> void:
	match _reading_page:
		0:
			_content.add_child(UI.label("Meet the idea", 26, UI.TEAL))
			_content.add_child(UI.label(str(_data.term), 34))
			_content.add_child(UI.label(str(_data.definition), 30))
			var card := UI.panel(_content, Color("18333a"))
			var body := UI.column(card, 12)
			body.add_child(UI.label("KEEP THIS IN MIND", 16, UI.GOLD, true))
			body.add_child(UI.label(str(_data.rule), 28))
		1:
			_content.add_child(UI.label("See it in context", 30))
			# An accessible, code-native illustration of the actual authored case.
			# It scales with text and never opens a real message, URL or device.
			var example := UI.panel(_content, Color("1b343e"))
			example.name = "VisualExample"
			var body := UI.column(example, 16)
			var heading := HBoxContainer.new()
			heading.add_theme_constant_override("separation", 16)
			body.add_child(heading)
			var icon := IntelPixelIcon.new()
			icon.kind = {"Mail": IntelPixelIcon.Kind.ENVELOPE, "Messages": IntelPixelIcon.Kind.PHONE, "Calls": IntelPixelIcon.Kind.PHONE, "Service Desk": IntelPixelIcon.Kind.BADGE}.get(str(_data.domain.app), IntelPixelIcon.Kind.BOOKS)
			icon.ink_override = UI.TEAL
			icon.custom_minimum_size = Vector2(56, 56)
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			heading.add_child(icon)
			var app := UI.label(str(_data.domain.app).to_upper() + " / TRAINING EXAMPLE", 24, UI.TEAL)
			app.size_flags_horizontal = SIZE_EXPAND_FILL
			heading.add_child(app)
			body.add_child(HSeparator.new())
			body.add_child(UI.label(str(_data.scenario), 28))
			_content.add_child(UI.label("Pause and notice: who is asking, what do they want, and are they pressuring you to act?", 26, UI.GOLD))
		2:
			_content.add_child(UI.label("Connect the clues", 30))
			_content.add_child(UI.label(str(_data.takeaway), 28))
			var card := UI.panel(_content, Color("18333a"))
			var body := UI.column(card)
			body.add_child(UI.label("YOUR SAFE RESPONSE", 16, UI.TEAL, true))
			body.add_child(UI.label(str(_data.rule), 28))
			_content.add_child(UI.label("Ready? Try a short quiz, then practice the response on a training desktop.", 26, UI.MUTED))

func _pick(index: int) -> void:
	if _phase != Phase.QUIZ or _quiz_passed:
		return
	if bool(_data.multi):
		if index in _picks:
			_picks.erase(index)
		else:
			_picks.append(index)
	else:
		_picks.assign([index])
	_refresh_choices()

func _refresh_choices() -> void:
	for i in _quiz_buttons.size():
		var button := _quiz_buttons[i]
		button.text = ("[X]  " if i in _picks else "[ ]  ") + str(_data.options[i])
		button.disabled = _quiz_passed
		button.add_theme_stylebox_override("normal", UI.box(Color("29464e") if i in _picks else UI.PANEL, UI.TEAL if i in _picks else Color("3b626a"), 10))
		if _quiz_passed and i in _picks:
			button.add_theme_stylebox_override("disabled", UI.box(Color("193a2a"), Feedback.SUCCESS, 10))
			button.add_theme_color_override("font_disabled_color", Feedback.SUCCESS)

func _check_quiz() -> void:
	if _phase != Phase.QUIZ:
		return
	var correct: Array = _data.correct
	var ok := _picks.size() == correct.size()
	for index in correct:
		ok = ok and index in _picks
	if not ok:
		_status_scroll.show()
		_status_label.text = "Not quite. Re-read the case and try again. You must identify every correct option." if bool(_data.multi) else "Not quite. Verify the request rather than trusting a name or deadline. Try again."
		_status_label.add_theme_color_override("font_color", Feedback.ERROR)
		_answer_effect.show_result(false)
		return
	_quiz_passed = true
	_status_scroll.show()
	_status_label.text = "Correct. " + str(_data.feedback)
	_status_label.add_theme_color_override("font_color", Feedback.SUCCESS)
	_answer_effect.show_result(true)
	_refresh_choices()
	_submit_button.text = "START SIMULATION  >"

func _on_simulation_passed() -> void:
	if _phase != Phase.SIMULATION or not _quiz_passed:
		return
	_simulation_passed = true
	_submit_button.disabled = false
	_submit_button.text = "VIEW RESULT  >"

func _on_continue() -> void:
	if _busy or _submit_button.disabled:
		return
	match _phase:
		Phase.DEFINITION:
			if _reading_page < 2:
				_reading_page += 1
				_set_phase(Phase.DEFINITION)
			else:
				_read_passed = true
				_set_phase(Phase.QUIZ)
		Phase.QUIZ:
			if _quiz_passed:
				_set_phase(Phase.SIMULATION)
			else:
				_check_quiz()
		Phase.SIMULATION:
			if _simulation_passed:
				_set_phase(Phase.COMPLETE)
		Phase.COMPLETE:
			_finish_lesson()

func _can_complete() -> bool:
	return not _busy and _phase == Phase.COMPLETE and _quiz_passed and _simulation_passed

func _finish_lesson() -> void:
	if not _can_complete():
		return
	_busy = true
	if Router.is_tutorial and Router.tutorial_beat == &"lesson":
		PlayerManager.grant_intel_bonus(_module_id)
		_show_tutorial_lesson_done()
		return
	var progress := PlayerManager.get_lesson_progress(_module_id)
	# Replaying a completed topic must not increment the next topic's progress.
	if not _review_mode and _lesson_index == progress:
		PlayerManager.complete_lesson_unit(_module_id, _lessons.size(), LessonCatalog.module_ids())
	if _lesson_index + 1 < _lessons.size():
		_lesson_index += 1
	_start_lesson()

func _begin_tutorial_coach() -> void:
	_tutorial_overlay = TutorialOverlay.mount_on(self)
	if _tutorial_overlay == null:
		return
	_tutorial_overlay.file_requested.connect(_on_tutorial_file_requested)
	_tutorial_overlay.dashboard_requested.connect(_on_tutorial_dashboard_requested)
	_tutorial_overlay.setup_lesson()

func _on_tutorial_file_requested() -> void:
	if is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.hide()
		_tutorial_overlay.mouse_filter = MOUSE_FILTER_IGNORE

func _on_tutorial_dashboard_requested() -> void:
	Router.open_tutorial_dashboard()

func _show_tutorial_lesson_done() -> void:
	if not is_instance_valid(_tutorial_overlay):
		_tutorial_overlay = TutorialOverlay.mount_on(self)
	if _tutorial_overlay == null:
		Router.open_tutorial_dashboard()
	else:
		_tutorial_overlay.show_lesson_done()

func on_exit() -> void:
	_answer_effect.reset()
	if is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.hide()
