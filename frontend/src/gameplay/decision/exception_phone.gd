extends "res://src/gameplay/decision/survey_phone.gd"
## Review-only roster card. No student data entry or disclosure action exists.
var _notice: bool = false
var _record: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/exception_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_record = ""
	_feedback_text = ""
	super.configure_chapter(next_mode,snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	if _notice:
		_activity_text("NEW MESSAGE / EMERGENCY CLEARANCE\nIncident Response Coordinator / still unverified")
		_action("OPEN MESSAGE",_open_notice)
	elif mode == "read":
		_activity_text(Chapter.REQUEST)
		_roster_card()
		if not phase_ready(): _action("KEEP REQUEST",_read_message)
	elif mode == "compare":
		if phase_ready():
			_activity_success("FIELDS AND CHANNEL IDENTIFIED\nNames, sections and contact numbers, requested by private message. This recipient and channel have no independently confirmed approval in the record.")
		else:
			_activity_text("CHECK THE REQUEST AGAINST THE SCHOOL NOTICE\nOpen both records, then inspect the fields and channel.")
		_choices(("✓ " if state.sorted.has("request") else "")+"REQUEST",_open_record.bind("request"),("✓ " if state.sorted.has("notice") else "")+"SCHOOL NOTICE",_open_record.bind("notice"))
		if not _record.is_empty(): _activity_text(Chapter.REQUEST if _record == "request" else Chapter.AUTHORIZATION_NOTICE)
		if state.sorted.has("request") and state.sorted.has("notice") and not phase_ready():
			if not state.sorted.has("fields"):
				_activity_text("Which information is being requested?")
				_choices("STUDENT CONTACT DETAILS",_match_detail.bind("fields"),"MEETING ATTENDANCE ONLY",_wrong.bind("The request names students' names, sections and contact numbers. It asks for the contact list, not simply who attended a meeting."))
			else:
				_activity_success("CONTACT DETAILS IDENTIFIED")
				_activity_text("What does the record show about the sharing channel?")
				_choices("INDEPENDENTLY APPROVED",_wrong.bind("Only the sender has said approved. No independent approval for this private conversation has been provided."),"PRIVATE / UNCONFIRMED",_match_detail.bind("channel"))
	elif mode == "approval":
		if phase_ready():
			_activity_success("CLAIM IS NOT CONFIRMATION\nThe missing piece is independently confirmed, documented approval for the recipient, purpose, fields and channel. This is not yet an office denial.")
		elif not state.sorted.has("claim"):
			_activity_text("THE EXCEPTION\nInspect what the sender calls approval.")
			_action("REVIEW EMERGENCY CLAIM",_open_claim)
		else:
			_activity_text(Chapter.EXCEPTION_CLAIM)
			_activity_text("What is still missing?")
			_choices("A MORE OFFICIAL LOGO",_wrong.bind("A logo can be copied. The school notice requires independently confirmed approval for this recipient, purpose, data and channel."),"VERIFIED APPROVAL",_confirm_missing)
	elif mode == "route":
		if phase_ready():
			_activity_success("SCHOOL OFFICE / EXISTING DIRECTORY\nAppointment and permission check pending.\nLIST RESTRICTED / NOTHING SENT")
		elif not state.sorted.has("directory"):
			_roster_card()
			_activity_text("Choose a verification route outside the sender's conversation.")
			_action("OPEN EXISTING SCHOOL DIRECTORY",_open_directory)
		else:
			_activity_text("EXISTING SCHOOL DIRECTORY\nSchool Office / appointment and authorization enquiries\n\nWhat should Sir Rham do next?")
			_action("KEEP LIST / ASK SCHOOL OFFICE",_choose_route.bind("office"))
			_action("SEND ONLY NAMES AND SECTIONS",_choose_route.bind("partial"))
			_action("USE THE SENDER'S PRIVATE CONTACT",_choose_route.bind("supplied"))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _roster_card() -> void:
	var panel: PanelContainer = UI.panel(_content,Color("0A1730"))
	panel.add_theme_stylebox_override("panel",UI.box(Color("0A1730"),Color("4FE0D4"),14))
	panel.add_child(UI.label("▣  CLUB CONTACT LIST / RESTRICTED\nSEALED · NOT ATTACHED · NOT SENT",24,Color("F3ECD6")))

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Authorization check"
	_status.text = "15:40  •  New message"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()

func _open_notice() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _read_message() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read","exception")
	_render()

func _open_record(id: String) -> void:
	if _locked or mode != "compare" or state.read.is_empty() or id not in ["request","notice"]: return
	_record = id
	_add("sorted",id)
	_feedback_text = ""
	_render()

func _match_detail(id: String) -> void:
	if _locked or mode != "compare" or phase_ready() or not state.sorted.has("request") or not state.sorted.has("notice"): return
	if id not in ["fields","channel"] or state.sorted.has(id): return
	if id == "channel" and not state.sorted.has("fields"): return
	_add("sorted",id)
	if id == "channel": _add("flags","exception")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_claim() -> void:
	if _locked or mode != "approval" or state.flags.is_empty() or phase_ready(): return
	_add("sorted","claim")
	_feedback_text = ""
	_render()

func _confirm_missing() -> void:
	if _locked or mode != "approval" or not state.sorted.has("claim") or phase_ready(): return
	_add("domains","exception")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_directory() -> void:
	if _locked or mode != "route" or state.domains.is_empty() or phase_ready(): return
	_add("sorted","directory")
	_feedback_text = ""
	_render()

func _choose_route(id: String) -> void:
	if _locked or mode != "route" or not state.sorted.has("directory") or phase_ready(): return
	if id == "partial":
		_wrong("Nothing was sent. Fewer fields still disclose student information. Check permission before sharing any of the list.")
	elif id == "supplied":
		_wrong("No contact was opened and nothing was sent. Another contact supplied by the same sender cannot independently confirm their permission.")
	elif id == "office":
		_add("captures","exception")
		_feedback_text = ""
		AudioManager.play_sfx("ui_confirm")
		_render()

func _wrong(explanation: String) -> void:
	if _locked or phase_ready() or not Chapter.TASKS.has(mode): return
	state.mistakes = int(state.mistakes)+1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(explanation)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
	var feedback: Control = _content.get_child(_content.get_child_count()-1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(feedback) and is_instance_valid(scroll) and scroll.is_ancestor_of(feedback): scroll.ensure_control_visible(feedback)
	).call_deferred()

func phase_ready() -> bool:
	var field: String = {"read":"read","compare":"flags","approval":"domains","route":"captures"}.get(mode,"")
	return not field.is_empty() and (state.get(field,[]) as Array).has("exception")

func _close_app() -> void:
	_finish_phase()
