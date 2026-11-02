extends "res://src/gameplay/decision/survey_phone.gd"
## Uses the existing chapter/save owner. Support and reporting stay inside the game.
var _notice: bool = false
var _view: String = ""
var _feedback_text: String = ""
var _prior_call: Dictionary = {}

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/safe_callback_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_view = ""
	_feedback_text = ""
	# Replay uses the preserved original incident, not a later alternate replay.
	_prior_call = PlayerManager.story_checkpoint(Chapter.PriorCall.ID, false)
	super.configure_chapter(next_mode, snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	if _notice:
		_activity_text("NEW MESSAGE / SECURITY SUPERVISOR\nA second name. Another request to trust the same team.")
		_action("READ MESSAGE", _open_notice)
	elif mode == "read":
		_activity_text("SECURITY SUPERVISOR / UNVERIFIED\n" + Chapter.REQUEST)
		_activity_text(Chapter.CONTACT)
		if phase_ready(): _activity_success("Message saved. This name and contact are still unverified.")
		else: _action("SAVE MESSAGE", _read_message)
	elif mode == "route":
		if phase_ready():
			_activity_success("INDEPENDENT CONTACT SELECTED\nExisting wallet app → Support → Contact us\nThis contact was reached outside the suspicious message.")
		elif _view == "support":
			_activity_text("MY WALLET / SUPPORT / CONTACT US\nAccount security help\nUse the support contact listed inside this app to check an unexpected call.")
			_action("CONTACT WALLET SUPPORT", _choose_contact)
		elif _view == "wallet":
			_activity_text("MY EXISTING WALLET APP\nOpened directly from my apps. No link or contact from the message was used.")
			_action("SUPPORT / CONTACT US", _open_support)
		else:
			_activity_text("The supervisor offers a callback number. Which source will Liza use to verify the call?")
			_choices("MESSAGE'S CALLBACK NUMBER", _wrong.bind("The message supplied that number. A second name using the same source is not an independent check."), "OPEN MY WALLET APP", _open_wallet)
	elif mode == "compare":
		if phase_ready():
			_activity_success("THE CALL WAS NOT REQUESTED BY THE SERVICE\nSupport contradicts the supervisor's claim. This reset was not completed; review account activity for anything unfamiliar.")
		elif not state.sorted.has("response"):
			_activity_text(Chapter.SUPPORT_REPLY)
			_action("KEEP SUPPORT RESPONSE", _keep_response)
		else:
			_activity_text("SUPERVISOR CLAIM / Our team requested the call.\nWALLET SUPPORT / We did not request that call or ask for the reset code.")
			_activity_text("Which conclusion does this comparison support?")
			_action("THE SERVICE DID NOT REQUEST THE CALL", _confirm_comparison)
			_choices("THE SUPERVISOR IS VERIFIED", _wrong.bind("Support contradicts the claimed connection. The supervisor's identity remains unverified."), "EVERY ACCOUNT IS SAFE", _wrong.bind("Support confirms only that this reset was not completed. Review account activity; do not turn a specific finding into a guarantee."))
	elif mode == "report":
		if phase_ready():
			_activity_success("INCIDENT RECORD SAVED\nSupervisor message + service response + wallet alert + received call notes\nCode kept private. The caller remains unidentified.")
		elif _view in ["alert","call_notes"]:
			_activity_text(Chapter.PriorCall.ALERT if _view == "alert" else _call_notes())
			if state.sorted.has(_view): _activity_success("Attached to the incident record.")
			else: _action("ATTACH THIS RECORD", _attach_document)
			_action("BACK TO INCIDENT RECORD", _back_to_report)
		else:
			_activity_text("INCIDENT RECORD / PRACTICE\nThe supervisor message and wallet response are included. Review and attach the alert and actual call notes. This record stays in the game.")
			_choices(("ATTACHED / " if state.sorted.has("alert") else "REVIEW / ") + "WALLET ALERT", _open_document.bind("alert"), ("ATTACHED / " if state.sorted.has("call_notes") else "REVIEW / ") + "CALL NOTES", _open_document.bind("call_notes"))
			if state.sorted.has("alert") and state.sorted.has("call_notes"):
				_action("SAVE INCIDENT RECORD", _save_record)
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _call_notes() -> String:
	var lines: PackedStringArray = ["SAVED CALL NOTES / CHAPTER 3", "Displayed label: Account Security. Identity unverified."]
	var received: int = int(_prior_call.get("call_received", 0))
	if received == 0:
		lines.append("Call declined. No caller statements received. No transcript is attached.")
	else:
		for index: int in received: lines.append("Caller: " + str(Chapter.PriorCall.CALL_LINES[index]))
		if received < Chapter.PriorCall.CALL_LINES.size(): lines.append("Call ended before the next statement.")
	lines.append("Call ended. No code was shared. Review examples are not call evidence.")
	return "\n\n".join(lines)

func _refresh() -> void:
	super._refresh()
	for node: Node in _content.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.begins_with("ATTACHED / "):
			button.add_theme_stylebox_override("normal", UI.box(Color("dcefe2"), Color("33D17A"), 12))
	_title.text = str({"read":"Messages / Supervisor","route":"My wallet / Independent contact","compare":"Wallet / Support response","report":"Wallet / Incident record"}.get(mode, "Phone"))
	_status.text = "15:40  /  Covered courtyard"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.accessibility_name = "Continue to the next story or investigation step"
	_close.disabled = _locked or not phase_ready()

func _open_notice() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _read_message() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read", "callback")
	_render()

func _open_wallet() -> void:
	if _locked or mode != "route" or phase_ready(): return
	_view = "wallet"
	_feedback_text = ""
	_render()

func _open_support() -> void:
	if _locked or mode != "route" or _view != "wallet" or phase_ready(): return
	_view = "support"
	_render()

func _choose_contact() -> void:
	if _locked or mode != "route" or _view != "support" or phase_ready(): return
	_add("flags", "callback")
	_render()

func _keep_response() -> void:
	if _locked or mode != "compare" or state.sorted.has("response") or state.flags.is_empty(): return
	_add("sorted", "response")
	_render()

func _confirm_comparison() -> void:
	if _locked or mode != "compare" or not state.sorted.has("response") or phase_ready(): return
	_add("domains", "callback")
	_feedback_text = ""
	_render()

func _open_document(id: String) -> void:
	if _locked or mode != "report" or phase_ready() or id not in ["alert","call_notes"]: return
	_view = id
	_feedback_text = ""
	_render()

func _attach_document() -> void:
	if _locked or mode != "report" or _view not in ["alert","call_notes"] or state.sorted.has(_view) or phase_ready(): return
	_add("sorted", _view)
	_view = ""
	_render()

func _back_to_report() -> void:
	if _locked or mode != "report": return
	_view = ""
	_render()

func _save_record() -> void:
	if _locked or mode != "report" or phase_ready() or not state.sorted.has("alert") or not state.sorted.has("call_notes"): return
	_add("captures", "callback")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _wrong(explanation: String) -> void:
	if _locked or mode not in ["route","compare"] or phase_ready(): return
	state.mistakes += 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(explanation)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
	var feedback: Control = _content.get_child(_content.get_child_count() - 1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(feedback) and is_instance_valid(scroll) and scroll.is_ancestor_of(feedback): scroll.ensure_control_visible(feedback)
	).call_deferred()

func phase_ready() -> bool:
	var field: String = {"read":"read","route":"flags","compare":"domains","report":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("callback")

func _close_app() -> void:
	_finish_phase()
