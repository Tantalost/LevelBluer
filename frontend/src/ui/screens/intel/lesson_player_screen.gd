class_name LessonPlayerScreen
extends BaseScreen
## Read > check understanding > safely perform the response. Saves only after both checks.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Study = preload("res://src/ui/screens/intel/lesson_study_content.gd")
const Desktop = preload("res://src/ui/screens/intel/lesson_desktop_sim.gd")
const Feedback = preload("res://src/ui/screens/intel/study_feedback.gd")
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

func _ready() -> void:
	var shell := UI.shell(self, "STUDY WORKSPACE", func() -> void: Router.request_back())
	_close_button = shell.back
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
	right.name = "LessonWorkspace"
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.68
	var right_column := UI.column(right, 16)
	_phase_label = UI.label("", 23, UI.TEAL)
	right_column.add_child(_phase_label)
	var divider := HSeparator.new()
	right_column.add_child(divider)
	_content = UI.scroll_column(right_column)
	_status_label = UI.label("", 22, UI.GOLD)
	right_column.add_child(_status_label)
	_submit_button = UI.button("START MINI QUIZ  >", _on_continue, true)
	right_column.add_child(_submit_button)
	_answer_effect = Feedback.mount(right)

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
	_data = Study.build(_module_id, _lesson_index)
	_refresh_topic_info()
	_set_phase(Phase.DEFINITION)

func _refresh_topic_info() -> void:
	UI.clear(_side)
	var module := LessonCatalog.module_by_id(_module_id)
	_progress_label.text = "%s  /  TOPIC %02d OF %02d%s" % [str(module.get("title", "")).to_upper(), _lesson_index + 1, _lessons.size(), "  /  REVIEW" if _review_mode else ""]
	_side.add_child(UI.label("TOPIC BRIEF", 14, UI.TEAL, true))
	_side.add_child(UI.label(str(_data.title), 28))
	_side.add_child(UI.label(str(_data.term).to_upper(), 17, UI.GOLD, true))
	_side.add_child(UI.label(str(_data.rule), 23, UI.MUTED))
	_side.add_child(HSeparator.new())
	_side.add_child(UI.label("MODULE TOPICS", 14, UI.TEAL, true))
	var progress := PlayerManager.get_lesson_progress(_module_id)
	for i in _lessons.size():
		var text := "%02d  %s" % [i + 1, str(_lessons[i].title)]
		if i < progress:
			text = "DONE  " + text
		var button := UI.button(text, _select_topic.bind(i), i == _lesson_index)
		button.add_theme_font_size_override("font_size", 21)
		button.disabled = (not _review_mode and i > progress) or (Router.is_tutorial and i != 0)
		if button.disabled:
			UI.lock_topic(button, "Finish the tutorial first." if Router.is_tutorial else "Complete Topic %02d to unlock this topic." % i)
		_side.add_child(button)

func _select_topic(index: int) -> void:
	if index < 0 or index >= _lessons.size() or _busy:
		return
	if not _review_mode and index > PlayerManager.get_lesson_progress(_module_id):
		return
	if Router.is_tutorial and index != 0:
		return
	_lesson_index = index
	_start_lesson()

func _set_phase(phase: Phase) -> void:
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
	_status_label.add_theme_color_override("font_color", UI.GOLD)
	_submit_button.disabled = false
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	_phase_label.text = ["01  DEFINITION     /     02  QUIZ     /     03  SIMULATION",
		"01  READ     /     [02  MINI QUIZ]     /     03  SIMULATION",
		"01  READ     /     02  PASSED     /     [03  SIMULATION]",
		"TOPIC COMPLETE  /  KNOWLEDGE + PRACTICE VERIFIED"][_phase]
	match _phase:
		Phase.DEFINITION:
			_content.add_child(UI.label("Know the threat", 24, UI.TEXT, true))
			_content.add_child(UI.label(str(_data.definition), 28))
			_content.add_child(UI.label("WHAT TO LOOK FOR", 14, UI.TEAL, true))
			_content.add_child(UI.label(str(_data.takeaway), 25, UI.MUTED))
			_content.add_child(UI.label("EXAMPLE CASE", 14, UI.GOLD, true))
			_content.add_child(UI.label(str(_data.scenario), 25))
			_submit_button.text = "START MINI QUIZ  >"
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
		_content.add_child(UI.button("< Review definition", _set_phase.bind(Phase.DEFINITION)))

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
		_status_label.text = "Not quite. Re-read the case and try again. You must identify every correct option." if bool(_data.multi) else "Not quite. Verify the request rather than trusting a name or deadline. Try again."
		_status_label.add_theme_color_override("font_color", Feedback.ERROR)
		_answer_effect.show_result(false)
		return
	_quiz_passed = true
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
	if _lesson_index + 1 >= _lessons.size():
		Router.request_back()
		return
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
