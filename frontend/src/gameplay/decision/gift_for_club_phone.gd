extends "res://src/gameplay/decision/survey_phone.gd"
var _notice: bool = false
var _record: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/gift_for_club_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_record = ""
	_feedback_text = ""
	super.configure_chapter(next_mode,snapshot)

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	match mode:
		"read":
			if _notice:
				_activity_text("UNREAD / Event Recovery Desk\nYour event materials are ready")
				_action("READ OFFER",_open_notice)
			else:
				_activity_text(str(Chapter.MESSAGES[0].body))
				if not phase_ready(): _action("KEEP MESSAGE",_keep)
		"offer":
			if phase_ready():
				_activity_success("PROMISE RECORDED\nThe message offers posters and signs. The desk's role still needs verification.")
			else:
				_activity_text(str(Chapter.MESSAGES[0].body))
				_activity_text("Which detail can Mika record from the message itself?")
				_action("It offers ready-made signs",_choose.bind(true))
				_action("The school chose this supplier",_choose.bind(false))
		"sources":
			if phase_ready(): _activity_success("SOURCES MATCHED\nThe club assigned the design desk. The gift arrived in a separate conversation.")
			for id: String in ["offer","plan"]:
				var label: String = "Event pack offer" if id == "offer" else "Club chat / pinned materials plan"
				_action(("✓ " if state.sorted.has(id+"_source") else "")+label,_inspect.bind(id))
			if not _record.is_empty():
				_activity_text(str(Chapter.MESSAGES[0].body) if _record == "offer" else Chapter.PLAN)
				if not state.sorted.has(_record+"_source"):
					_activity_text("Who supplied this record?")
					_choices("Incoming sender",_match_source.bind("offer"),"Established club chat",_match_source.bind("plan"))
		"route":
			if phase_ready():
				_activity_success("OFFER PRESERVED · PACK UNOPENED\nMika asked the design desk through its pinned contact. Awaiting reply.")
			elif state.sorted.has("contact_open"):
				_activity_text("CLUB CHAT / PINNED DESIGN DESK\nMika: Did you send a ready-made pack from Event Recovery Desk?")
				_action("SEND QUESTION · KEEP PACK CLOSED",_ask)
			else:
				_activity_text("Where should Mika check the offer?")
				_action("Open the club’s pinned contact",_contact)
				_action("Reply to the offer’s verification desk",_choose.bind(false))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Event materials"
	_status.text = "Early evening"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()

func _open_notice() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _keep() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read","gift")
	_render()

func _choose(correct: bool) -> void:
	if _locked or phase_ready(): return
	if mode == "offer" and state.read.has("gift"):
		if correct: _record_finding("flags")
		else: _wrong("The message claims that role. Check the club's own materials plan to see who was assigned.")
	elif mode == "route" and not correct: _wrong("That desk came from the same offer. Open your existing club chat and use its pinned contact.")

func _inspect(id: String) -> void:
	if _locked or mode != "sources" or state.flags.is_empty() or id not in ["offer","plan"]: return
	_record = id
	_feedback_text = ""
	_add("sorted",id+"_open")
	_render()

func _match_source(id: String) -> void:
	if _locked or mode != "sources" or _record.is_empty() or not state.sorted.has(_record+"_open") or state.sorted.has(_record+"_source"): return
	if id != _record:
		_wrong("Look at where you opened this record. A sender can describe a school plan without being its author.")
		return
	_feedback_text = ""
	_add("sorted",id+"_source")
	if state.sorted.has("offer_source") and state.sorted.has("plan_source"): _record_finding("domains")
	else:
		AudioManager.play_sfx("ui_confirm")
		_render()

func _contact() -> void:
	if _locked or mode != "route" or state.domains.is_empty() or phase_ready(): return
	_feedback_text = ""
	_add("sorted","contact_open")
	_render()

func _ask() -> void:
	if _locked or mode != "route" or not state.sorted.has("contact_open") or phase_ready(): return
	_record_finding("captures")

func _record_finding(field: String) -> void:
	_feedback_text = ""
	_add(field,"gift")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _wrong(text: String) -> void:
	state.mistakes += 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(text)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
	var feedback: Control = _content.get_child(-1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(scroll) and is_instance_valid(feedback) and scroll.is_ancestor_of(feedback): scroll.ensure_control_visible(feedback)
	).call_deferred()

func phase_ready() -> bool:
	var field: String = {"read":"read","offer":"flags","sources":"domains","route":"captures"}.get(mode,"")
	return not field.is_empty() and state.get(field,[]).has("gift")

func _close_app() -> void:
	_finish_phase()
