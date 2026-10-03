extends VBoxContainer
## An entirely local desktop drill. No shell, browser, real credentials or network.
signal passed
signal content_changed
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Feedback = preload("res://src/ui/screens/intel/study_feedback.gd")
const PC = preload("res://src/ui/screens/intel/lesson_pc_shell.gd")
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
var _pc_mode: bool = false
var _pc: PanelContainer
var _message_open: bool = false

func setup(data: Dictionary) -> void:
	_data = data
	_investigation = str(data.get("simulation_id", "")) == "sender_cross_check"
	_pc_mode = str(data.get("module_id", "")) == "mod_01" or _investigation
	if _pc_mode:
		_setup_pc()
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
	if _pc_mode and action == "open":
		_open_app("Inbox")
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
	if _pc_mode:
		_open_app(_active_app)
	else:
		_show_window()

func _setup_pc() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = SIZE_EXPAND_FILL
	_task = UI.label("SCHOOL PC  /  LOCAL TRAINING SESSION", 20, CYAN)
	add_child(_task)
	_pc = PC.new()
	add_child(_pc)
	_pc.app_requested.connect(_open_app)
	_pc.back_requested.connect(func() -> void:
		_message_open = false
		_open_app("Inbox")
	)
	_app_content = _pc.body
	_evidence = VBoxContainer.new()
	add_child(_evidence)
	_evidence.hide()
	_mail_card = UI.button("Policy review\nDrag or select", _select_mail)
	_mail_card.name = "InvestigationEmail"
	_mail_card.size_flags_horizontal = SIZE_EXPAND_FILL
	_mail_card.set_drag_forwarding(_get_mail_drag_data, Callable(), Callable())
	_pc.actions.add_child(_mail_card)
	_quarantine = UI.button("QUARANTINE\nEvidence required", _tap_quarantine)
	_quarantine.name = "QuarantineBin"
	_quarantine.size_flags_horizontal = SIZE_EXPAND_FILL
	_quarantine.set_drag_forwarding(Callable(), _can_quarantine_drop, _drop_quarantine)
	_pc.actions.add_child(_quarantine)
	_pc.actions.hide()
	_feedback = UI.label("Open Mail to start. Evidence keeps your investigation checklist. All apps are offline.", 22, UI.MUTED)
	add_child(_feedback)
	_answer_effect = Feedback.mount(_pc)
	if _investigation:
		_refresh_evidence()
	_readability_changed.call_deferred()

func _open_pc_app(app: String) -> void:
	_active_app = app
	_search = null
	if _evidence.get_parent() != self:
		_evidence.reparent(self)
	_evidence.hide()
	UI.clear(_app_content)
	(_app_content.get_parent() as ScrollContainer).scroll_vertical = 0
	_pc.show_app(app)
	_pc.back_button.visible = app == "Inbox" and _message_open and not _passed
	_pc.actions.visible = _investigation and app == "Inbox" and _message_open and _verified and not _passed
	match app:
		"Inbox": _pc_mail()
		"Directory": _pc_directory()
		"Browser": _pc_browser()
		"File Sandbox": _pc_files()
		"Evidence":
			if _investigation:
				_refresh_evidence()
				_evidence.reparent(_app_content)
				_evidence.show()
			else:
				_pc_evidence()
		"Quarantine":
			_pc_card("QUARANTINE / ISOLATED MESSAGES", "1 message contained. This email can no longer be opened." if _passed else "No messages contained yet. Inspect the request and collect evidence before reporting it.")
			if not _passed:
				_app_content.add_child(UI.button("Move selected email" if _investigation else "Report investigated message", _tap_quarantine if _investigation else _act.bind("report"), true))
			_app_content.add_child(UI.button("Return to Mail", _open_app.bind("Inbox")))
	_readability_changed.call_deferred()

func _pc_card(title: String, body: String) -> VBoxContainer:
	var panel: PanelContainer = UI.panel(_app_content, Color("#102040"))
	var content: VBoxContainer = UI.column(panel, 12)
	content.add_child(UI.label(title, 22, CYAN))
	content.add_child(UI.label(body, 24, Color("#F3ECD6")))
	return content

func _pc_mail() -> void:
	_opened = true
	if _passed:
		_pc_card("INBOX / ALL CLEAR", "The suspicious message is contained. Your collected evidence remains in the Evidence app.")
		return
	var subject: String = "New school policy" if _investigation else str(_data.title)
	if not _message_open:
		_pc_card("INBOX / 1 MESSAGE", "Select a message to read it. Opening this preview does not open its links or attachments.")
		var message: Button = UI.button(subject + "\nSchool account  /  08:57", _read_message)
		message.name = "OpenCaseMessage"
		message.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_app_content.add_child(message)
		return
	var message_body: String = "From: University IT\nSubject: New school policy\n\nHello student,\nPlease review our updated school policy using the document link below.\n- University IT" if _investigation else str(_data.scenario)
	_pc_card("MAIL / " + subject.to_upper(), message_body)
	var details: Button = UI.button("View Raw Details" if not _inspected else "Details recorded", _inspect_sender if _investigation else _act.bind("inspect"))
	details.disabled = _inspected
	_app_content.add_child(details)
	if _inspected:
		_pc_card("MESSAGE DETAILS", "Actual sender: " + SENDER + "\nDisplay name: University IT" if _investigation else str(_data.rule))
	_app_content.add_child(UI.button("Preview link destination", _open_app.bind("Browser")))
	if int(_data.get("lesson_index", 0)) == 3:
		_app_content.add_child(UI.button("Attachment / FINE_NOTICE.PDF.exe", _open_app.bind("File Sandbox")))
	_app_content.add_child(UI.button("Open trusted Directory", _open_app.bind("Directory")))
	_app_content.add_child(UI.button("Review collected evidence", _open_app.bind("Evidence")))
	if not _investigation:
		_app_content.add_child(UI.button(str(_data.domain.action), _act.bind("report"), true))

func _read_message() -> void:
	_message_open = true
	_pc.unread = false
	_pc.refresh_badges()
	_open_app("Inbox")

func _pc_directory() -> void:
	_pc_card("SCHOOL DIRECTORY", "Saved school contacts. This address book was not supplied by the email.")
	if not _investigation:
		_pc_card("VERIFIED CONTACT / SCHOOL HELP DESK", "Use the school's known support channel. A display name in an email does not verify its sender.")
		var verify: Button = UI.button("Check request with trusted contact", _act.bind("verify"))
		verify.disabled = not _opened or not _inspected or _passed
		_app_content.add_child(verify)
		if _verified:
			_pc_card("HELP DESK RESPONSE", "This request is not authorized. Do not send a password, open the file, or follow its login link.")
		else:
			_app_content.add_child(UI.label("Inspect the message details before checking the request.", 22, UI.MUTED))
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_app_content.add_child(row)
	_search = LineEdit.new()
	_search.name = "DirectorySearch"
	_search.placeholder_text = "Search department"
	_search.text = _query
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	_search.custom_minimum_size.y = 56
	_search.add_theme_font_override("font", UI.FONT)
	_search.add_theme_font_size_override("font_size", 26)
	_search.text_changed.connect(func(value: String) -> void: _query = value)
	_search.text_submitted.connect(_search_directory)
	row.add_child(_search)
	row.add_child(UI.button("Search", func() -> void: _search_directory(_query)))
	if _directory_found:
		_pc_card("UNIVERSITY IT / VERIFIED STAFF", "Official domain: @" + OFFICIAL_DOMAIN + "\nContact: helpdesk@" + OFFICIAL_DOMAIN)
		_app_content.add_child(UI.button("Compare in Evidence", _open_app.bind("Evidence"), true))
	else:
		_app_content.add_child(UI.label("Search for University IT, the department named in the email.", 22, UI.MUTED))

func _pc_browser() -> void:
	var destination: String = "No destination supplied in this case"
	var expression: RegEx = RegEx.new()
	expression.compile("(?:https?://[a-zA-Z0-9.-]+(?:/[a-zA-Z0-9_./-]*)?|[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}/[a-zA-Z0-9_./-]+)")
	var match_url: RegExMatch = expression.search(str(_data.scenario))
	if match_url != null:
		destination = match_url.get_string()
	if _investigation:
		destination = "northbridge-edu.example/policy"
	var address: LineEdit = LineEdit.new()
	address.text = destination
	address.editable = false
	address.custom_minimum_size.y = 54
	address.add_theme_font_override("font", UI.FONT)
	address.add_theme_font_size_override("font_size", 24)
	_app_content.add_child(address)
	_pc_card("LINK PREVIEW / NOT VISITED", "The address above is evidence only. No website is loaded and no login details are requested.")
	_app_content.add_child(UI.button("Attempt to open email link", _unsafe_link if _investigation else _act.bind("unsafe")))
	_app_content.add_child(UI.button("Use saved school contacts instead", _open_app.bind("Directory"), true))

func _pc_files() -> void:
	_app_content.add_child(UI.label("THIS PC  /  MAIL ATTACHMENTS", 24, CYAN))
	if int(_data.get("lesson_index", 0)) != 3:
		_pc_card("FOLDER EMPTY", "This case has no attachment. No files have been downloaded.")
		return
	_pc_card("FINE_NOTICE.PDF.exe", "TYPE: Executable program (.exe)\nSOURCE: Email attachment\nSTATUS: Not executed\n\nThe final extension determines the file type, not the PDF text in its name.")
	var inspect: Button = UI.button("Record file properties", _act.bind("inspect"))
	inspect.disabled = not _opened or _passed
	_app_content.add_child(inspect)
	if not _opened:
		_app_content.add_child(UI.button("Read the related email first", _open_app.bind("Inbox")))
	_app_content.add_child(UI.button("Run attachment", _act.bind("unsafe")))
	_app_content.add_child(UI.button("Verify with school staff", _open_app.bind("Directory"), true))

func _pc_evidence() -> void:
	_pc_card("CASE FILE / " + str(_data.title).to_upper(), "Your findings are kept when you minimize or close an app.")
	for item: Array in [[_opened, "Read the request"], [_inspected, "Inspect its details"], [_verified, "Verify independently"], [_passed, "Report safely"]]:
		_app_content.add_child(UI.label(("[DONE] " if item[0] else "[ ] ") + str(item[1]), 24, SUCCESS if item[0] else UI.MUTED))
	if _inspected:
		_pc_card("RECORDED DETAILS", str(_data.rule))
	if _verified:
		_pc_card("TRUSTED RESPONSE", "The request was not authorized. It is ready to report.")
	_app_content.add_child(UI.button("Back to Mail", _open_app.bind("Inbox")))

func _open_app(app: String) -> void:
	if _pc_mode:
		_open_pc_app(app)

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
	if _pc_mode:
		_open_app("Evidence")

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
