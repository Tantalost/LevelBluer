extends VBoxContainer
## An entirely local desktop drill. No shell, browser, real credentials or network.
signal passed
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Feedback = preload("res://src/ui/screens/intel/study_feedback.gd")
var _data: Dictionary
var _opened := false
var _inspected := false
var _verified := false
var _passed := false
var _window: VBoxContainer
var _feedback: Label
var _task: Label
var _answer_effect: Control

func setup(data: Dictionary) -> void:
	_data = data
	add_theme_constant_override("separation", 14)
	add_child(UI.label("TRAINING DESKTOP  /  OFFLINE SANDBOX", 14, UI.TEAL, true))
	_task = UI.label("Open the pending request. Inspect it, verify its source, then handle it safely.", 24)
	add_child(_task)
	var desktop := UI.panel(self, Color("183e46"))
	var desk := UI.column(desktop)
	var apps := HBoxContainer.new()
	apps.add_theme_constant_override("separation", 12)
	desk.add_child(apps)
	var app_button := UI.button("[+] " + str(data.domain.app), _act.bind("open"), true)
	app_button.custom_minimum_size.x = 240
	apps.add_child(app_button)
	apps.add_child(UI.button("[?] Task", func() -> void: _feedback.text = "Inspect the request and use an independent, trusted channel before reporting it."))
	var window_panel := UI.panel(desk, Color("d6dfd8"))
	_window = UI.column(window_panel)
	_show_window()
	var taskbar := UI.label("START   |   %s   |   TRAINING SESSION" % str(data.domain.app).to_upper(), 18, UI.TEAL)
	desk.add_child(taskbar)
	_feedback = UI.label("Nothing here opens a real link, file or application.", 22, UI.MUTED)
	add_child(_feedback)
	_answer_effect = Feedback.mount(desktop)

func _show_window() -> void:
	UI.clear(_window)
	if not _opened:
		_window.add_child(UI.label("1 PENDING REQUEST", 24, UI.BG))
		_window.add_child(UI.label("Use the application above to open the training case.", 24, UI.BG))
		return
	var title_panel := UI.panel(_window, Color("254658"))
	title_panel.add_theme_stylebox_override("panel", UI.box(Color("254658"), Color("254658"), 8))
	var titlebar := HBoxContainer.new()
	title_panel.add_child(titlebar)
	var title := UI.label(str(_data.domain.app).to_upper() + "  /  REQUEST REVIEW", 15, UI.TEAL, true)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	titlebar.add_child(title)
	var minimize := UI.button("_", func() -> void:
		_opened = false
		_show_window()
	)
	minimize.custom_minimum_size = Vector2(40, 36)
	titlebar.add_child(minimize)
	_window.add_child(UI.label(str(_data.scenario), 24, UI.BG))
	if _inspected:
		_window.add_child(UI.label("DETAILS  /  " + str(_data.rule), 23, Color("364e52")))
	if _verified:
		_window.add_child(UI.label("TRUSTED CHANNEL: This unusual request is not authorized. No secret, file, payment or device access is required.", 23, Color("215c4d")))
	var inspect := UI.button(str(_data.domain.inspect), _act.bind("inspect"))
	inspect.disabled = _passed
	_window.add_child(inspect)
	var verify := UI.button(str(_data.domain.verify), _act.bind("verify"))
	verify.disabled = not _inspected or _passed
	_window.add_child(verify)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_window.add_child(actions)
	var unsafe := UI.button(str(_data.domain.unsafe), _act.bind("unsafe"))
	unsafe.size_flags_horizontal = SIZE_EXPAND_FILL
	unsafe.disabled = _passed
	actions.add_child(unsafe)
	var safe := UI.button(str(_data.domain.action), _act.bind("report"), true)
	safe.size_flags_horizontal = SIZE_EXPAND_FILL
	safe.disabled = _passed
	actions.add_child(safe)

func _act(action: String) -> void:
	if _passed:
		return
	match action:
		"open":
			_opened = true
		"inspect":
			if not _opened:
				return
			_inspected = true
			_feedback.text = "Details inspected. Now verify using a source outside this request."
			_feedback.add_theme_color_override("font_color", UI.MUTED)
			_answer_effect.reset()
		"verify":
			if not _opened or not _inspected:
				return
			_verified = true
			_feedback.text = "The trusted channel does not authorize this request. Choose a safe response."
			_feedback.add_theme_color_override("font_color", UI.MUTED)
			_answer_effect.reset()
		"unsafe":
			_feedback.text = "Unsafe action blocked by the sandbox. It would expose data or access. Review the details and try again."
			_feedback.add_theme_color_override("font_color", Feedback.ERROR)
			_answer_effect.show_result(false)
			return
		"report":
			if not _opened or not _inspected or not _verified:
				_feedback.text = "Do not guess. Inspect the request and verify independently before you report it."
				_feedback.add_theme_color_override("font_color", Feedback.ERROR)
				_answer_effect.show_result(false)
				return
			_passed = true
			_task.text = "SIMULATION PASSED  /  Request inspected, verified and reported."
			_feedback.text = "Safe response confirmed. You can now complete this topic."
			_feedback.add_theme_color_override("font_color", Feedback.SUCCESS)
			_task.add_theme_color_override("font_color", Feedback.SUCCESS)
			_answer_effect.show_result(true)
			passed.emit()
	_show_window()
