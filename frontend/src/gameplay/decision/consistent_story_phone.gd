extends "res://src/gameplay/decision/survey_phone.gd"
## Touch source cards inside the existing phone; the chapter owner saves findings.
var _notice: bool = false
var _record: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/consistent_story_chapter.gd")

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
		_activity_text("NEW MESSAGE / THREE RECORDS\nIncident Response Coordinator / still unverified")
		_action("OPEN MESSAGE",_open_notice)
	elif mode == "read":
		_activity_text("SAME INCOMING CONVERSATION\n"+str(Chapter.MESSAGES[0].body))
		_activity_text("ATTACHED / Profile, email copy, meeting invitation\nEach record was supplied by this sender.")
		if not phase_ready(): _action("KEEP MESSAGE",_read_message)
	elif mode == "sources":
		if phase_ready():
			_activity_success("THREE RECORDS / ONE UNVERIFIED SUPPLIER\nTheir agreement does not independently confirm the coordinator's role.")
		else:
			_activity_text("TRACE THE SOURCE\nOpen a record, then identify who supplied it.")
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		_content.add_child(row)
		for item: Dictionary in Chapter.DOCUMENTS:
			var matched: bool = state.sorted.has("source_"+str(item.id))
			var card: Button = _action(("✓ " if matched else "")+str(item.title),_open_record.bind(str(item.id)))
			card.reparent(row)
			card.size_flags_horizontal = SIZE_EXPAND_FILL
			if matched: card.add_theme_stylebox_override("normal",UI.box(Color("dcefe2"),Color("33D17A"),12))
			elif _record == item.id: card.add_theme_stylebox_override("normal",UI.box(Color("c9eee9"),Color("4FE0D4"),12))
		if not _record.is_empty():
			var selected: Dictionary = Chapter.document(_record)
			_activity_text(str(selected.title)+"\n"+str(selected.body))
			if not state.sorted.has("source_"+_record):
				_choices("SAME UNVERIFIED SENDER",_classify_source.bind("sender"),"INDEPENDENT SCHOOL OFFICE",_classify_source.bind("office"))
	elif mode == "request":
		if phase_ready():
			_activity_success("EXPANDED REQUEST IDENTIFIED\nThe sender wants student names, sections and contact numbers. Matching documents do not authorize disclosure. No list has been sent.")
		elif not state.sorted.has("request_read"):
			_activity_text("WHAT DOES THE COORDINATOR WANT?\nInspect the request before deciding.")
			_action("READ THE DATA REQUEST",_open_request)
		else:
			_activity_text(Chapter.REQUEST)
			_choices("JUST A MEETING ACKNOWLEDGEMENT",_wrong.bind("The sender explicitly asks for student names, sections and contact numbers. That is a data request, not just confirming attendance."),"A STUDENT CONTACT LIST",_confirm_request)
	elif mode == "preserve":
		if phase_ready():
			_activity_success("SOURCES AND LIMITS SAVED\nThe independent notice changes an internal meeting time only. It does not confirm the coordinator or permit disclosure. A scheduling correction does not implicate the staff member.")
		elif not state.sorted.has("office_notice"):
			_activity_text("CHECK THE SEPARATE SCHOOL UPDATE\nUse the existing school shortcut, outside the sender's conversation.")
			_action("OPEN SCHOOL SHORTCUT / OFFICE NOTICE",_open_notice_record)
		else:
			_activity_text(Chapter.SCHOOL_NOTICE)
			if state.sorted.has("limits"):
				_activity_success("ONLY THE INTERNAL MEETING CHANGED\nKeep the supplied records, actual request and school notice together with their sources.")
				_action("SAVE COMPARISON",_save_comparison)
			else:
				_choices("THE COORDINATOR IS APPROVED",_wrong.bind("The school notice changes an internal meeting's time. It does not assign an external coordinator or approve sharing the list."),"ONLY THE INTERNAL TIME CHANGED",_confirm_limits)
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Source comparison"
	_status.text = "10:15  •  New records"
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
	_add("read","sources")
	_render()

func _open_record(id: String) -> void:
	if _locked or mode != "sources" or state.read.is_empty() or Chapter.document(id).is_empty(): return
	_record = id
	_add("sorted","read_"+id)
	_feedback_text = ""
	_render()

func _classify_source(source: String) -> void:
	if _locked or mode != "sources" or _record.is_empty() or not state.sorted.has("read_"+_record) or state.sorted.has("source_"+_record): return
	if source != "sender":
		_wrong("This record was supplied by the same unverified sender. Its branding and matching claims do not make it an independent office response.")
		return
	_add("sorted","source_"+_record)
	var complete: bool = true
	for item: Dictionary in Chapter.DOCUMENTS: complete = complete and state.sorted.has("source_"+str(item.id))
	if complete: _add("flags","sources")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_request() -> void:
	if _locked or mode != "request" or state.flags.is_empty() or phase_ready(): return
	_add("sorted","request_read")
	_feedback_text = ""
	_render()

func _confirm_request() -> void:
	if _locked or mode != "request" or not state.sorted.has("request_read") or phase_ready(): return
	_add("domains","sources")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_notice_record() -> void:
	if _locked or mode != "preserve" or state.domains.is_empty() or phase_ready(): return
	_add("sorted","office_notice")
	_feedback_text = ""
	_render()

func _confirm_limits() -> void:
	if _locked or mode != "preserve" or not state.sorted.has("office_notice") or phase_ready(): return
	_add("sorted","limits")
	_feedback_text = ""
	_render()

func _save_comparison() -> void:
	if _locked or mode != "preserve" or not state.sorted.has("limits") or phase_ready(): return
	_add("captures","sources")
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
	var field: String = {"read":"read","sources":"flags","request":"domains","preserve":"captures"}.get(mode,"")
	return not field.is_empty() and (state.get(field,[]) as Array).has("sources")

func _close_app() -> void:
	_finish_phase()
