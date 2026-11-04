extends "res://src/gameplay/decision/survey_phone.gd"
## Simulated call; the chapter owner persists every received excerpt and end action.
const CallPanel: GDScript = preload("res://src/gameplay/decision/decision_call_panel.gd")
var _call: Control
var _feedback_text: String = ""
var _service_open: bool = false
var _rang: bool = false
func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/helpful_caller_chapter.gd")
func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_feedback_text = ""
	_service_open = false
	super.configure_chapter(next_mode,snapshot)
	if next_mode == "read" and not snapshot.call_started and not snapshot.call_ended and not _rang:
		_rang = true
		AudioManager.play_sfx("ui_notification")
func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	_call = null
	if mode == "read":
		if not state.call_started and not state.call_ended:
			_activity_text("INCOMING CALL\nAccount Security\nDisplayed label / Identity unverified")
			_choices("ANSWER",_answer,"DECLINE & REVIEW",_end_call)
		else:
			_call = CallPanel.new()
			_content.add_child(_call)
			_call.configure({"caller":"Account Security","number":"Identity unverified","status":"Connected","allow_end_call":true,"show_duration":false,"touch_unit":1.0/maxf(.25,get_viewport().get_final_transform().get_scale().y)})
			_call.end_call_requested.connect(_end_call)
			if state.call_ended: _call.set_ended()
			_received_notes()
			if not state.call_ended and state.call_received < Chapter.CALL_LINES.size():
				_action("LISTEN TO NEXT STATEMENT",_receive_next)
			elif not state.call_ended:
				_activity_text("You can end the call and check independently. No code or personal information is required.")
	elif mode == "claims":
		_activity_text("CLASSIFY WHAT YOU KNOW\nYour saved call: " + ("declined" if not state.call_started else "%d statement(s) received" % int(state.call_received)))
		var items: Array[Dictionary] = [
			{"id":"claim","line":"The caller is Account Security.","answer":"CLAIM"},
			{"id":"observed","line":"The phone received an incoming call.","answer":"OBSERVED"},
			{"id":"unverified","line":"The service independently confirmed the caller's identity.","answer":"NOT VERIFIED"}]
		var pending: Dictionary = {}
		for item: Dictionary in items:
			if state.sorted.has(item.id): _activity_success(str(item.answer)+" / "+str(item.line))
			elif pending.is_empty(): pending = item
		if not pending.is_empty():
			_activity_text(str(pending.line))
			for category: String in ["CLAIM","OBSERVED","NOT VERIFIED"]:
				_action(category,_classify.bind(str(pending.id),category == pending.answer))
	elif mode == "identity":
		_received_notes()
		if phase_ready():
			_activity_success("IDENTITY STILL UNVERIFIED\nNeither the label nor a self-supplied reference authenticates a caller. A professional voice does not settle it either.")
		else:
			_activity_text("Does the displayed label independently establish who called?")
			_choices("YES / THE LABEL IS OFFICIAL",_wrong.bind("A label is what the phone displays. It is not independent confirmation from the service."),"NO / VERIFY THROUGH THE SERVICE",_confirm_identity)
	elif mode == "verify":
		if phase_ready():
			_activity_success("INDEPENDENT ROUTE SAVED\nOpen the wallet app you already use and find Support there. The route is selected; the caller's identity has not yet been confirmed.")
		elif _service_open:
			_activity_text("MY EXISTING WALLET APP / SUPPORT\nThis is where I can check the unexpected call. I reached it myself, outside the caller's conversation.")
			_action("SAVE THIS VERIFICATION ROUTE",_save_route)
		else:
			_activity_text("Where should Liza verify the account-security claim?")
			_choices("ASK THE SAME CALLER TO CONFIRM",_wrong.bind("Repeating a claim does not independently verify it. Choose a route the caller did not supply."),"OPEN MY EXISTING WALLET APP",_open_service)
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()
func _received_notes() -> void:
	_activity_text("SAVED CALL NOTES / DISPLAYED LABEL: ACCOUNT SECURITY")
	if state.call_received == 0:
		_activity_text("Call declined. No caller statements were received. The label alone does not identify the caller.")
	else:
		for index: int in int(state.call_received):
			_activity_text("Caller: “"+str(Chapter.CALL_LINES[index])+"”")
func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Call review"
	_status.text = "15:20  •  Covered walkway"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()
	if is_instance_valid(_call): _call.set_interaction_locked(_locked)
func _answer() -> void:
	if _locked or mode != "read" or state.call_started or state.call_ended: return
	state.call_started = true
	state.call_received = 1
	evidence_changed.emit(state.duplicate(true))
	_render()
func _receive_next() -> void:
	if _locked or mode != "read" or not state.call_started or state.call_ended: return
	state.call_received = mini(Chapter.CALL_LINES.size(),int(state.call_received)+1)
	evidence_changed.emit(state.duplicate(true))
	_render()
func _end_call() -> void:
	if _locked or mode != "read" or state.call_ended: return
	state.call_ended = true
	_add("read","call")
	AudioManager.play_sfx("ui_confirm")
	_render()
func _classify(id: String, correct: bool) -> void:
	if _locked or mode != "claims" or state.sorted.has(id) or phase_ready(): return
	if not correct:
		_wrong("A claimed role, an observed incoming call and independent confirmation are different kinds of information. The service has not verified this caller.")
		return
	_add("sorted",id)
	if state.sorted.size() == 3: _add("flags","call")
	_feedback_text = ""
	_render()
func _confirm_identity() -> void:
	if _locked or mode != "identity" or phase_ready(): return
	_add("domains","call")
	_feedback_text = ""
	_render()
func _open_service() -> void:
	if _locked or mode != "verify" or phase_ready(): return
	_service_open = true
	_feedback_text = ""
	_render()
func _save_route() -> void:
	if _locked or mode != "verify" or not _service_open or phase_ready(): return
	_add("captures","call")
	_render()
func _wrong(explanation: String) -> void:
	if _locked or phase_ready(): return
	state.mistakes += 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(explanation)
func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
func phase_ready() -> bool:
	var field: String = {"read":"read","claims":"flags","identity":"domains","verify":"captures"}.get(mode,"")
	return not field.is_empty() and (state.get(field,[]) as Array).has("call")
func _close_app() -> void:
	_finish_phase()
