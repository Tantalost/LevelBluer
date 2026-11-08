extends "res://src/gameplay/decision/survey_phone.gd"
var _notice: bool = false
var _record: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/four_connections_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_record = ""
	_feedback_text = ""
	super.configure_chapter(next_mode,snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	match mode:
		"read":
			if _notice:
				_activity_text("SCHOOL SUPPORT / DELIVERY REVIEW AVAILABLE")
				_action("Open case response",_open_notice)
			else:
				_activity_text(Chapter.REPORT)
				if not phase_ready(): _action("Keep report",_keep_report)
		"route":
			if phase_ready(): _activity_success("INDEPENDENT ROUTE CHECKED\nSchool directory → School Office → existing support case.")
			else:
				_activity_text("Open the route in order.")
				for index: int in Chapter.ROUTE.size():
					var item: Dictionary = Chapter.ROUTE[index]
					var button: Button = _marked_button("route_"+str(item.id),str(item.title),_open_route.bind(index))
					button.disabled = _locked or (index > 0 and not state.sorted.has("route_"+str(Chapter.ROUTE[index-1].id)))
					if _record == item.id: _activity_text(str(item.body))
				if state.sorted.has("route_case"):
					_activity_text("Why can this route provide an independent check?")
					_choices("The sender supplied it",_confirm_route.bind(false),"The school directory supplied it",_confirm_route.bind(true))
		"match":
			if phase_ready(): _activity_success("BOTH DELIVERIES PAIRED\nDL-041 / coordinator request\nDL-052 / event-pack offer\nThe independent service report corroborates their connection.")
			else:
				for delivery: Dictionary in Chapter.DELIVERIES:
					if state.sorted.has("match_"+str(delivery.id)): _activity_success(str(delivery.reference)+" / "+str(delivery.title))
				var item: Dictionary = _current_delivery()
				_activity_text("SERVICE EXPORT / "+str(item.reference)+"\n“"+str(item.quote)+"”")
				_activity_text("Inspect an original, then pair it with this reference.")
				for delivery: Dictionary in Chapter.DELIVERIES:
					_marked_button("read_"+str(delivery.id),str(delivery.title),_open_original.bind(str(delivery.id)))
				var original: Dictionary = Chapter.record(_record)
				if not original.is_empty():
					_activity_text(str(original.title)+"\n"+str(original.body))
					_action("Pair this original with "+str(item.reference),_pair)
		"note":
			if phase_ready(): _activity_success("CASE NOTE SAVED\nThe report links the coordinator request and pack offer. Directing account: withheld pending verification. Earlier findings kept separate.\nQuestion for the hearing: Who directed the switch?")
			else:
				_activity_text("EARLIER CASES / Keep each finding's limits.")
				for item: Dictionary in Chapter.EARLIER:
					_marked_button("case_"+str(item.id),str(item.title),_open_case.bind(str(item.id)))
					if _record == item.id: _activity_text(str(item.body))
				if _cases_read():
					_activity_text("Which case note is supported now?")
					_action("Two deliveries linked. Directing account still withheld.",_save_note.bind("limited"))
					_action("The report identifies the mastermind of every case.",_save_note.bind("identity"))
					_action("The similar messages alone prove one sender.",_save_note.bind("similarity"))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _marked_button(key: String, label: String, action: Callable) -> Button:
	var marked: bool = state.sorted.has(key)
	var button: Button = _action(("✓ " if marked else "")+label,action)
	if marked: button.add_theme_stylebox_override("normal",UI.box(Color("dcefe2"),Color("33D17A"),12))
	return button

func _open_notice() -> void:
	if _locked or mode != "read" or not _notice: return
	_notice = false
	_render()

func _keep_report() -> void:
	if _locked or mode != "read" or _notice or phase_ready(): return
	_add("read","connections")
	_render()

func _open_route(index: int) -> void:
	if _locked or mode != "route" or state.read.is_empty() or phase_ready() or index < 0 or index >= Chapter.ROUTE.size(): return
	if index > 0 and not state.sorted.has("route_"+str(Chapter.ROUTE[index-1].id)): return
	_record = str(Chapter.ROUTE[index].id)
	_add("sorted","route_"+_record)
	_feedback_text = ""
	_render()

func _confirm_route(correct: bool) -> void:
	if _locked or mode != "route" or phase_ready() or not state.sorted.has("route_case"): return
	if not correct:
		_wrong("Sir Rham used the existing school directory. The suspicious sender supplied neither this route nor the support report.")
		return
	_add("flags","connections")
	_confirmed()

func _current_delivery() -> Dictionary:
	for item: Dictionary in Chapter.DELIVERIES:
		if not state.sorted.has("match_"+str(item.id)): return item
	return {}

func _open_original(id: String) -> void:
	if _locked or mode != "match" or state.flags.is_empty() or phase_ready() or Chapter.record(id).is_empty(): return
	_record = id
	_add("sorted","read_"+id)
	_feedback_text = ""
	_render()
	_reveal_last()

func _pair() -> void:
	if _locked or mode != "match" or state.flags.is_empty() or phase_ready() or not state.sorted.has("read_"+_record): return
	var item: Dictionary = _current_delivery()
	if item.is_empty(): return
	if _record != item.id:
		_wrong("Read the actual request in the excerpt. One asks for student contacts; the other offers event materials. Keep each reference with its matching original.")
		return
	_add("sorted","match_"+_record)
	_record = ""
	if _current_delivery().is_empty(): _add("domains","connections")
	_confirmed()

func _open_case(id: String) -> void:
	if _locked or mode != "note" or state.domains.is_empty() or phase_ready(): return
	for item: Dictionary in Chapter.EARLIER:
		if id == item.id:
			_record = id
			_add("sorted","case_"+id)
			_feedback_text = ""
			_render()
			return

func _cases_read() -> bool:
	for item: Dictionary in Chapter.EARLIER:
		if not state.sorted.has("case_"+str(item.id)): return false
	return true

func _save_note(choice: String) -> void:
	if _locked or mode != "note" or state.domains.is_empty() or phase_ready() or not _cases_read(): return
	if choice != "limited":
		_wrong("The directing-account field is withheld. This report does not yet identify the mastermind of the earlier cases." if choice == "identity" else "The independent service review corroborates these two deliveries. Similar wording alone would not prove a shared sender.")
		return
	_add("captures","connections")
	_confirmed()

func _confirmed() -> void:
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0

func _wrong(text: String) -> void:
	state.mistakes += 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(text)

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
	_reveal_last()

func _reveal_last() -> void:
	var last: Control = _content.get_child(-1) as Control
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	(func() -> void:
		if is_instance_valid(last) and is_instance_valid(scroll) and scroll.is_ancestor_of(last): scroll.ensure_control_visible(last)
	).call_deferred()

func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Delivery review"
	_status.text = "Afternoon"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()

func phase_ready() -> bool:
	var field: String = {"read":"read","route":"flags","match":"domains","note":"captures"}.get(mode,"")
	return not field.is_empty() and state.get(field,[]).has("connections")

func _close_app() -> void:
	_finish_phase()
