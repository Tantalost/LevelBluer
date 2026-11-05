extends "res://src/gameplay/decision/survey_phone.gd"
## Source-labelled response review; no contact launches or roster transmission.
var _notice: bool = false
var _record: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/real_office_chapter.gd")

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
		_activity_text("SCHOOL OFFICE / NEW RESPONSE\nThrough the existing directory route")
		_action("OPEN RESPONSE",_open_notice)
	elif mode == "read":
		_activity_text(Chapter.OFFICE_REPLY)
		if not phase_ready(): _action("KEEP RESPONSE",_read_message)
	elif mode == "route":
		if phase_ready():
			_activity_success("INDEPENDENT SOURCE TRACED\nExisting school directory → School Office → response. The sender did not supply this route.")
		else:
			_activity_text("TRACE THE ROUTE / OPEN EACH STEP IN ORDER")
		for index: int in Chapter.ROUTE.size():
			var item: Dictionary = Chapter.ROUTE[index]
			var opened: bool = state.sorted.has("route_"+str(item.id))
			var button: Button = _action(("✓ " if opened else str(index+1)+" / ")+str(item.title),_open_route.bind(index))
			button.disabled = _locked or (index > 0 and not state.sorted.has("route_"+str(Chapter.ROUTE[index-1].id)))
			if opened: button.add_theme_stylebox_override("normal",UI.box(Color("dcefe2"),Color("33D17A"),12))
		if not _record.is_empty():
			for item: Dictionary in Chapter.ROUTE:
				if item.id == _record: _activity_text(str(item.body))
		if state.sorted.has("route_reply") and not phase_ready():
			_activity_text("Why is this response independent?")
			_choices("EXISTING SCHOOL DIRECTORY",_confirm_route,"THE SENDER SENT A LINK",_wrong.bind("Sir Rham used the established directory outside the suspicious conversation. A contact supplied by the sender would not establish an independent route."))
	elif mode == "match":
		if phase_ready():
			_activity_success("TWO DENIALS / CLEAR LIMITS\nNo assignment and no approval for this request. The operator remains unidentified; system-wide safety is not established.")
		else:
			var item: Dictionary = _current_match()
			if state.sorted.has("match_permission"): _activity_success("ASSIGNMENT AND APPROVAL DENIALS MATCHED")
			elif state.sorted.has("match_assignment"): _activity_success("ASSIGNMENT DENIAL MATCHED")
			_activity_text("OFFICE STATEMENT\n“"+str(item.quote)+"”\n\n"+str(item.question))
			# Alternate placement so a fixed left/right tap pattern is not sufficient.
			if item.id == "permission": _choices(str(item.wrong),_match_statement.bind(false),str(item.correct),_match_statement.bind(true))
			else: _choices(str(item.correct),_match_statement.bind(true),str(item.wrong),_match_statement.bind(false))
	elif mode == "report":
		if phase_ready():
			_activity_success("CASE RECORD SAVED\nAppointment + private request + independent response. Sources retained; student roster excluded.")
		else:
			_activity_text("REVIEW THE THREE RECORDS TO INCLUDE\nKeep their sources with them. The student list stays restricted.")
			for id: String in ["appointment","request","reply"]:
				var attached: bool = state.sorted.has("report_"+id)
				var button: Button = _action(("✓ " if attached else "")+{"appointment":"SUPPLIED APPOINTMENT","request":"PRIVATE REQUEST","reply":"OFFICE RESPONSE"}[id],_open_record.bind(id))
				if attached: button.add_theme_stylebox_override("normal",UI.box(Color("dcefe2"),Color("33D17A"),12))
			if not _record.is_empty():
				var record: Dictionary = Chapter.report_record(_record)
				_activity_text(str(record.title)+"\n"+str(record.body))
				if not state.sorted.has("report_"+_record): _action("INCLUDE THIS RECORD",_include_record)
			_action("INCLUDE STUDENT ROSTER",_wrong.bind("The roster is not attached. Preserve the messages and office response; student contacts are unnecessary for this case record."))
			_action("INCLUDE A CULPRIT GUESS",_wrong.bind("No accusation was added. The office denies the claims in this case, but does not identify the operator."))
			var save_button: Button = _action("SAVE CASE RECORD",_save_report)
			save_button.disabled = _locked or not _report_ready()
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Independent response"
	_status.text = "16:10  •  School Office"
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
	_add("read","office")
	_render()

func _open_route(index: int) -> void:
	if _locked or mode != "route" or state.read.is_empty() or index < 0 or index >= Chapter.ROUTE.size(): return
	if index > 0 and not state.sorted.has("route_"+str(Chapter.ROUTE[index-1].id)): return
	_record = str(Chapter.ROUTE[index].id)
	_add("sorted","route_"+_record)
	_feedback_text = ""
	_render()

func _confirm_route() -> void:
	if _locked or mode != "route" or not state.sorted.has("route_reply") or phase_ready(): return
	_add("flags","office")
	_confirmed()

func _current_match() -> Dictionary:
	for item: Dictionary in Chapter.MATCHES:
		if not state.sorted.has("match_"+str(item.id)): return item
	return {}

func _match_statement(correct: bool) -> void:
	if _locked or mode != "match" or state.flags.is_empty() or phase_ready(): return
	var item: Dictionary = _current_match()
	if item.is_empty(): return
	if not correct:
		_wrong(str(item.explanation))
		return
	_add("sorted","match_"+str(item.id))
	if _current_match().is_empty(): _add("domains","office")
	_confirmed()

func _open_record(id: String) -> void:
	if _locked or mode != "report" or state.domains.is_empty() or phase_ready() or Chapter.report_record(id).is_empty(): return
	_record = id
	_feedback_text = ""
	_render()

func _include_record() -> void:
	if _locked or mode != "report" or state.domains.is_empty() or phase_ready() or Chapter.report_record(_record).is_empty(): return
	_add("sorted","report_"+_record)
	_confirmed()

func _report_ready() -> bool:
	return state.sorted.has("report_appointment") and state.sorted.has("report_request") and state.sorted.has("report_reply")

func _save_report() -> void:
	if _locked or mode != "report" or phase_ready() or not _report_ready(): return
	_add("captures","office")
	_confirmed()

func _confirmed() -> void:
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
	var field: String = {"read":"read","route":"flags","match":"domains","report":"captures"}.get(mode,"")
	return not field.is_empty() and (state.get(field,[]) as Array).has("office")

func _close_app() -> void:
	_finish_phase()
