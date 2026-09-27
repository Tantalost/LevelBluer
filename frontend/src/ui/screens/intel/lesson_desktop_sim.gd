extends VBoxContainer
## An entirely local desktop drill. No shell, browser, real credentials or network.
signal passed
signal content_changed
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Feedback = preload("res://src/ui/screens/intel/study_feedback.gd")
var _data: Dictionary
var _opened: bool = false
var _inspected: bool = false
var _verified: bool = false
var _passed: bool = false
var _window: VBoxContainer
var _feedback: Label
var _task: Label
var _answer_effect: Control
const SENDER: String = "admin@northbridge-edu.example"
const OFFICIAL_DOMAIN: String = "northbridge.edu.example"
const CYAN: Color = Color("4FE0D4")
const SUCCESS: Color = Color("33D17A")
var _investigation: bool = false
var _directory_found: bool = false
var _mail_selected: bool = false
var _active_app: String = "Inbox"
var _query: String = ""
var _app_content: VBoxContainer
var _evidence: VBoxContainer
var _mail_card: Button
var _quarantine: Button
var _search: LineEdit
var _app_buttons: Array[Button] = []

func setup(data: Dictionary) -> void:
	_data = data
	_investigation = str(data.get("simulation_id", "")) == "sender_cross_check"
	if _investigation:
		_setup_investigation()
		return
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
	# Legacy shortcuts must never bypass the investigation's evidence gates.
	if _investigation:
		match action:
			"open": _open_app("Inbox")
			"inspect": _inspect_sender()
			_: _notice("Use the desktop to collect evidence before quarantining this email.", true)
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

func _setup_investigation() -> void:
	add_theme_constant_override("separation", 12)
	_task = UI.label("NORTHBRIDGE ACADEMY / FICTIONAL SCHOOL DESKTOP", 24, CYAN)
	add_child(_task)
	var desktop: PanelContainer = UI.panel(self, Color("0A1730"))
	desktop.size_flags_vertical = SIZE_EXPAND_FILL
	var desk: VBoxContainer = UI.column(desktop, 12)
	var apps: HBoxContainer = HBoxContainer.new()
	apps.add_theme_constant_override("separation", 10)
	desk.add_child(apps)
	for app: String in ["Inbox", "Browser", "Directory", "File Sandbox"]:
		var button: Button = UI.button(app, _open_app.bind(app))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0
		apps.add_child(button)
		_app_buttons.append(button)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	desk.add_child(columns)
	var app_panel: PanelContainer = UI.panel(columns, Color("102040"))
	app_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	app_panel.size_flags_stretch_ratio = 1.55
	_app_content = UI.scroll_column(app_panel)
	_app_content.get_parent().custom_minimum_size.y = 100
	var evidence_panel: PanelContainer = UI.panel(columns, Color("0E2A28"))
	evidence_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_evidence = UI.scroll_column(evidence_panel)
	var transfer: HBoxContainer = HBoxContainer.new()
	transfer.add_theme_constant_override("separation", 16)
	desk.add_child(transfer)
	_mail_card = UI.button("EMAIL / Policy review\nDrag, or tap to select", _select_mail)
	_mail_card.name = "InvestigationEmail"
	_mail_card.size_flags_horizontal = SIZE_EXPAND_FILL
	_mail_card.set_drag_forwarding(_get_mail_drag_data, Callable(), Callable())
	transfer.add_child(_mail_card)
	_quarantine = UI.button("QUARANTINE\nEvidence required", _tap_quarantine)
	_quarantine.name = "QuarantineBin"
	_quarantine.size_flags_horizontal = SIZE_EXPAND_FILL
	_quarantine.set_drag_forwarding(Callable(), _can_quarantine_drop, _drop_quarantine)
	transfer.add_child(_quarantine)
	_feedback = UI.label("Inspect the email, cross-check the directory, then quarantine. All apps are offline.", 22, UI.MUTED)
	desk.add_child(_feedback)
	_answer_effect = Feedback.mount(desktop)
	_open_app("Inbox")
	_refresh_evidence()

func _open_app(app: String) -> void:
	_active_app = app
	_search = null
	UI.clear(_app_content)
	(_app_content.get_parent() as ScrollContainer).scroll_vertical = 0
	for button: Button in _app_buttons:
		button.add_theme_stylebox_override("normal", UI.box(Color("153B37") if button.text == app else Color("102040"), CYAN if button.text == app else Color("173058"), 10))
	_app_content.add_child(UI.label(app.to_upper() + " / LOCAL WORKSPACE", 24, CYAN))
	match app:
		"Inbox":
			_opened = true
			if _passed:
				_app_content.add_child(UI.label("Inbox clear. Policy review moved to Quarantine.", 26, SUCCESS))
				return
			_app_content.add_child(UI.label("From: University IT\nSubject: New school policy", 26))
			_app_content.add_child(UI.label("Hello student,\nPlease review our updated school policy using the document link below.\n— University IT", 24))
			var details: Button = UI.button("View Raw Details" if not _inspected else "Raw details opened", _inspect_sender)
			details.disabled = _inspected
			_app_content.add_child(details)
			if _inspected:
				_app_content.add_child(UI.label("Display name: University IT\nActual sender: " + SENDER, 24, Color("FFB648")))
			_app_content.add_child(UI.button("Review policy link", _unsafe_link))
		"Directory":
			_app_content.add_child(UI.label("CORPORATE DIRECTORY / SCHOOL STAFF\nA trusted address book installed by your school, not a link from the email.", 24))
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_app_content.add_child(row)
			_search = LineEdit.new()
			_search.name = "DirectorySearch"
			_search.placeholder_text = "Search department"
			_search.text = _query
			_search.size_flags_horizontal = SIZE_EXPAND_FILL
			_search.custom_minimum_size = Vector2(0, 56)
			_search.add_theme_font_override("font", UI.FONT)
			_search.add_theme_font_size_override("font_size", 26)
			_search.text_changed.connect(func(value: String) -> void: _query = value)
			_search.text_submitted.connect(_search_directory)
			row.add_child(_search)
			row.add_child(UI.button("Search", func() -> void: _search_directory(_query)))
			if _directory_found:
				_app_content.add_child(UI.label("VERIFIED DIRECTORY ENTRY\nUniversity IT\nOfficial domain: @" + OFFICIAL_DOMAIN + "\nContact: helpdesk@" + OFFICIAL_DOMAIN, 24, CYAN))
			else:
				_app_content.add_child(UI.label("Search for the department named in the email. The directory does not search the internet.", 24, UI.MUTED))
		"Browser":
			_app_content.add_child(UI.label("OFFLINE BROWSER\nNo page is open. This lesson uses the school's installed directory to verify the sender.\nEmail links cannot launch a real website.", 26))
		"File Sandbox":
			_app_content.add_child(UI.label("FILE SANDBOX / EMPTY\nNo attachment is supplied in this case. Nothing is downloaded or executed.\nReturn to Inbox or Directory to continue investigating.", 26))
	# Newly opened app controls must receive the same mobile font/touch sizing.
	_readability_changed.call_deferred()

func _readability_changed() -> void:
	content_changed.emit()

func _inspect_sender() -> void:
	if _passed or not _opened or _active_app != "Inbox":
		return
	_inspected = true
	_notice("Raw sender recorded. Look up University IT in the trusted Directory.")
	_open_app("Inbox")
	_refresh_evidence()

func _search_directory(query: String) -> void:
	if _passed or _active_app != "Directory":
		return
	_query = query.strip_edges()
	var normalized: String = " ".join(_query.to_lower().split(" ", false))
	if normalized != "university it":
		_notice("No matching department. Search for University IT, the sender's display name.", true)
		return
	_directory_found = true
	_notice("Official domain recorded. Compare it with the email's actual sender domain.")
	_open_app("Directory")
	_refresh_evidence()

func _refresh_evidence() -> void:
	UI.clear(_evidence)
	_evidence.add_child(UI.label("CASE FILE / EVIDENCE", 24, CYAN))
	_evidence.add_child(UI.label(("[✓]" if _inspected else "[ ]") + " Raw sender\n" + (SENDER if _inspected else "Inspect the email's raw details."), 24))
	_evidence.add_child(UI.label(("[✓]" if _directory_found else "[ ]") + " Trusted directory\n" + ("@" + OFFICIAL_DOMAIN if _directory_found else "Search the school's directory."), 24))
	if _verified:
		_evidence.add_child(UI.label("[✓] Mismatch confirmed\nThe hyphenated domain is not the school's official domain.", 24, SUCCESS))
	elif _inspected and _directory_found:
		_evidence.add_child(UI.label("Compare the exact domains after @. Do they match?", 24, Color("FFB648")))
		_evidence.add_child(UI.button("Same domain", _compare_domains.bind(false)))
		_evidence.add_child(UI.button("Different domains", _compare_domains.bind(true)))
	else:
		_evidence.add_child(UI.label("[ ] Compare both sources\nQuarantine requires evidence, not a guess.", 24, UI.MUTED))
	if _passed:
		# The result action replaces transfer controls, leaving room on phones.
		(_mail_card.get_parent() as Control).hide()
		_quarantine.text = "[✓] QUARANTINED"
		_mail_card.text = "EMAIL CONTAINED"
		_mail_card.disabled = true
		_quarantine.disabled = true
	else:
		_quarantine.text = "QUARANTINE\nDrop email here" if _verified else "QUARANTINE\nEvidence required"
	_readability_changed.call_deferred()

func _compare_domains(mismatch: bool) -> void:
	if _passed or not _inspected or not _directory_found:
		return
	if not mismatch:
		_notice("These domains differ: '-' and '.' are not interchangeable. Compare the exact addresses in the case file.", true)
		return
	_verified = true
	_notice("Mismatch proven. Drag the email into Quarantine, or tap the email and then Quarantine.")
	_refresh_evidence()

func _select_mail() -> void:
	if _passed:
		return
	_mail_selected = true
	_mail_card.text = "[✓] EMAIL SELECTED\nTap Quarantine to move"
	_notice("Email selected. Quarantine will check your collected evidence before moving it.")

func _get_mail_drag_data(_at: Vector2) -> Variant:
	if _passed:
		return null
	var preview: Label = UI.label("Policy review / University IT", 24, CYAN)
	_mail_card.set_drag_preview(preview)
	return {"kind": "policy_email", "source": self}

func _can_quarantine_drop(_at: Vector2, payload: Variant) -> bool:
	return payload is Dictionary and payload.get("kind") == "policy_email" and payload.get("source") == self and _opened and _inspected and _directory_found and _verified and not _passed

func _drop_quarantine(at: Vector2, payload: Variant) -> void:
	if _can_quarantine_drop(at, payload):
		_complete_investigation()

func _tap_quarantine() -> void:
	if _passed:
		return
	if not _mail_selected:
		_notice("Select the email first, or drag it here after collecting the evidence.", true)
		return
	if not _can_quarantine_drop(Vector2.ZERO, {"kind": "policy_email", "source": self}):
		_notice("Evidence missing. Inspect the sender, search University IT, then compare the two domains.", true)
		return
	_complete_investigation()

func _complete_investigation() -> void:
	if _passed:
		return
	_passed = true
	_task.text = "CASE CLOSED / SENDER MISMATCH PROVEN"
	_task.add_theme_color_override("font_color", SUCCESS)
	_notice("Email quarantined. You verified a lookalike sender instead of trusting its name. All school names and .example addresses in this case are fictional.")
	_feedback.add_theme_color_override("font_color", SUCCESS)
	_answer_effect.show_result(true)
	# Leave native drag handling's source/target alive until the drop has finished.
	_refresh_evidence.call_deferred()
	_open_app.call_deferred("Inbox")
	passed.emit()

func _unsafe_link() -> void:
	_notice("Link blocked by the training sandbox. Verify the sender independently before opening an unexpected policy link.", true)

func _notice(message: String, error: bool = false) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", Color("FF5C5C") if error else UI.MUTED)
	if error:
		_answer_effect.show_result(false)
	else:
		_answer_effect.reset()
