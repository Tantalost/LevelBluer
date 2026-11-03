extends "res://src/gameplay/decision/survey_phone.gd"
## Source inspection inside the shared phone shell; every action is touch-first.
var _notice: bool = false
var _record: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/here_to_help_chapter.gd")

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
		_activity_text("NEW APPOINTMENT\nSchool incident follow-up\nIncident Response Coordinator / unverified")
		_action("OPEN MESSAGE",_open_notice)
	elif mode == "read":
		_activity_text("INCOMING MESSAGE\n"+str(Chapter.MESSAGES[0].body))
		_activity_text(Chapter.APPOINTMENT)
		if not phase_ready(): _action("KEEP MESSAGE",_read_message)
	elif mode == "claims":
		if phase_ready():
			_activity_success("CLAIMS SEPARATED\nThe message and its branding are visible. The sender's role and school approval remain unverified.")
		else:
			var item: Dictionary = _current_claim()
			_activity_text("CLAIM OR OBSERVATION?\n"+str(item.text))
			_activity_text("Classify what the record actually supports.")
			_choices("UNVERIFIED CLAIM",_classify.bind("claim"),"OBSERVATION",_classify.bind("observation"))
		for claim: Dictionary in Chapter.CLAIMS:
			if state.sorted.has(claim.id): _activity_success("✓ "+str(claim.text)+"\n"+str(claim.explanation))
	elif mode == "compare":
		if phase_ready():
			_activity_success("MISMATCH / PURPOSE AND VISITOR\nThe school schedule records an internal meeting, not the supplied external consultation. This needs checking; a schedule discrepancy alone does not prove fraud.")
		else:
			_activity_text("OPEN BOTH SOURCES\nOne is supplied by the sender. One is the schedule Sir Rham already uses.")
		_action(("✓ " if state.sorted.has("supplied") else "")+"SUPPLIED APPOINTMENT",_open_record.bind("supplied"))
		_action(("✓ " if state.sorted.has("schedule") else "")+"EXISTING SCHOOL SHORTCUT / SCHEDULE",_open_record.bind("schedule"))
		if not _record.is_empty(): _activity_text(Chapter.APPOINTMENT if _record == "supplied" else Chapter.SCHEDULE)
		if not phase_ready() and state.sorted.has("supplied") and state.sorted.has("schedule"):
			_activity_text("Which part differs?")
			_choices("10:30 TIME",_wrong.bind("Both records say 10:30. A matching time does not confirm the claimed purpose or visitor."),"PURPOSE + EXTERNAL VISITOR",_confirm_mismatch)
	elif mode == "verify":
		if phase_ready():
			_activity_success("INDEPENDENT ROUTE SAVED\nSir Rham will use the established School Office contact. No reply has arrived and no student list has been shared.")
		elif state.sorted.has("directory"):
			_activity_text("EXISTING SCHOOL DIRECTORY\nSchool Office / Established internal contact\nOpened through Sir Rham's usual school shortcut, outside the supplied message.")
			_action("CHOOSE SCHOOL OFFICE",_choose_office)
		else:
			_activity_text("WHO SHOULD CONFIRM THE APPOINTMENT?\nSelect a source outside the sender's conversation.")
			_action("OPEN EXISTING SCHOOL DIRECTORY",_open_directory)
			_action("USE SENDER'S VERIFICATION CONTACT",_wrong.bind("The sender chose that contact. It cannot independently confirm the sender's story."))
			_action("TRUST THE SCHOOL BRANDING",_wrong.bind("A logo can be copied. Choose a school contact you already know independently."))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Appointment review"
	_status.text = "09:40  •  New appointment"
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
	_add("read","appointment")
	_render()

func _current_claim() -> Dictionary:
	for item: Dictionary in Chapter.CLAIMS:
		if not state.sorted.has(item.id): return item
	return {}

func _classify(answer: String) -> void:
	if _locked or mode != "claims" or phase_ready() or state.read.is_empty(): return
	var item: Dictionary = _current_claim()
	if answer != item.answer:
		_wrong(str(item.explanation))
		return
	_add("sorted",str(item.id))
	if _current_claim().is_empty(): _add("flags","appointment")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_record(id: String) -> void:
	if _locked or mode != "compare" or state.flags.is_empty() or id not in ["supplied","schedule"]: return
	_record = id
	_add("sorted",id)
	_feedback_text = ""
	_render()

func _confirm_mismatch() -> void:
	if _locked or mode != "compare" or phase_ready() or not state.sorted.has("supplied") or not state.sorted.has("schedule"): return
	_add("domains","appointment")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_directory() -> void:
	if _locked or mode != "verify" or phase_ready() or state.domains.is_empty(): return
	_add("sorted","directory")
	_feedback_text = ""
	_render()

func _choose_office() -> void:
	if _locked or mode != "verify" or phase_ready() or not state.sorted.has("directory"): return
	_add("captures","appointment")
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
	var field: String = {"read":"read","claims":"flags","compare":"domains","verify":"captures"}.get(mode,"")
	return not field.is_empty() and (state.get(field,[]) as Array).has("appointment")

func _close_app() -> void:
	_finish_phase()
