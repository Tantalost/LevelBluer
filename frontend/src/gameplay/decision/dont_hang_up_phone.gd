extends "res://src/gameplay/decision/survey_phone.gd"
## Fixed footer permits a safe exit even while the alert or transcript is scrolled.
const CallPanel: GDScript = preload("res://src/gameplay/decision/decision_call_panel.gd")
var _call: Control
var _source: String = "call"
var _feedback_text: String = ""
var _rang: bool = false
func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/dont_hang_up_chapter.gd")
func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_feedback_text = ""
	_source = "call" if next_mode == "read" and not snapshot.call_ended else "alert"
	super.configure_chapter(next_mode, snapshot)
	if next_mode == "read" and not snapshot.call_started and not snapshot.call_ended and not _rang:
		_rang = true
		AudioManager.play_sfx("ui_notification")
func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	_call = null
	if mode == "read":
		_choices("CALL", _switch_source.bind("call"), "WALLET ALERT", _switch_source.bind("alert"))
		if _source == "alert":
			_activity_text(Chapter.ALERT)
			if not state.alert_read: _action("I HAVE READ THE ALERT", _read_alert)
			else: _activity_success("Alert saved. The code stays private.")
		elif not state.call_started and not state.call_ended:
			_activity_text("INCOMING CALL / ACCOUNT SECURITY\nIdentity unverified. You may decline without penalty.")
			_action("ANSWER", _answer)
		else:
			_received_notes()
			_call = CallPanel.new()
			_content.add_child(_call)
			_call.configure({"caller":"Account Security","number":"Identity unverified","status":"Connected","allow_end_call":true,"show_duration":false,"touch_unit":1.0/maxf(.25,get_viewport().get_final_transform().get_scale().y)})
			_call.end_call_requested.connect(_end_call)
			if state.call_ended: _call.set_ended()
			if not state.call_ended and state.call_received == 1 and state.alert_read:
				_action("YOU SAID PAYMENT. THIS SAYS RESET.", _receive_next)
		if state.call_ended and not state.alert_read:
			_action("READ THE WALLET ALERT", _switch_source.bind("alert"))
	elif mode == "purpose":
		if phase_ready():
			_activity_success("RESET PASSWORD\nThe code authorizes a password reset. It does not cancel a payment.")
		else:
			_activity_text(Chapter.ALERT)
			_activity_text("Tap the action this code authorizes.")
			_choices("RESET PASSWORD", _confirm_purpose, "STOP A PAYMENT", _wrong.bind("Read the alert's stated purpose: reset your password. The caller cannot change what the code authorizes."))
	elif mode == "contradiction":
		if phase_ready():
			_activity_success("RESET PASSWORD ≠ STOP PAYMENT\nThe instructions describe different actions. A genuine alert does not verify the person asking for its code.")
		_choices("WALLET ALERT", _switch_source.bind("alert"), "CALL REVIEW", _switch_source.bind("call"))
		if _source == "alert":
			_activity_text("WALLET ALERT / Use this code to reset your password.")
			_mark_button("reset", "RESET PASSWORD")
		else:
			_activity_text("RECEIVED STATEMENT" if state.call_received > 0 else "REVIEW GUIDANCE / NOT RECEIVED CALL EVIDENCE")
			_activity_text(Chapter.CALL_LINES[0])
			_mark_button("payment", "STOP PAYMENT")
		if not phase_ready(): _activity_text("Highlight the different actions in both sources. %d / 2 marked." % state.sorted.size())
	elif mode == "refusal":
		if phase_ready():
			_activity_success("CODE KEPT PRIVATE / CALL ENDED\nVerify through Support in the wallet app you already use. No code was shared; the reset's outcome still needs independent confirmation.")
		else:
			_activity_text("CALL ENDED / NO PENALTY\nWhat should Liza do with the code?")
			_choices("KEEP PRIVATE / CHECK SUPPORT", _keep_private, "SHARE IT TO STOP THE PAYMENT", _wrong.bind("The alert says the code resets a password. Keep it private and verify through the wallet's own Support route."))
		_activity_text("RECEIVED PRESSURE" if state.call_received > 0 else "REVIEW GUIDANCE / NOT RECEIVED CALL EVIDENCE")
		_activity_text("The claim that hanging up ends protection discourages an independent check. It does not authenticate the caller.")
		_activity_text("SAVED CALL NOTES")
		_received_notes()
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()
func _mark_button(id: String, caption: String) -> void:
	if state.sorted.has(id): _activity_success(caption + " / highlighted")
	else: _action("HIGHLIGHT / " + caption, _mark.bind(id))
func _received_notes() -> void:
	if state.call_received == 0:
		_activity_text("Declined. No caller statements received.")
	else:
		for index: int in int(state.call_received):
			_activity_text("Caller: " + str(Chapter.CALL_LINES[index]))
		if state.call_received < Chapter.CALL_LINES.size(): _activity_text("Call ended before the next statement." if state.call_ended else "You can end the call now. There is no countdown.")
func _refresh() -> void:
	super._refresh()
	_title.text = "Phone / Keep control" if mode == "refusal" else "Phone / " + ("Wallet alert" if _source == "alert" else "Call review")
	_status.text = "15:35  /  Covered courtyard"
	_status.visible = mode == "read"
	_nav.visible = mode == "read" or phase_ready()
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()
	if mode == "read" and not state.call_ended:
		_close.text = "END CALL" if state.call_started else "DECLINE CALL"
		_close.disabled = _locked
	elif mode == "read" and not state.alert_read:
		_close.text = "READ WALLET ALERT"
		_close.disabled = _locked
	if is_instance_valid(_call): _call.set_interaction_locked(_locked)
func _switch_source(source: String) -> void:
	if _locked or mode not in ["read","contradiction"] or source not in ["call","alert"]: return
	_source = source
	_feedback_text = ""
	_render()
func _answer() -> void:
	if _locked or mode != "read" or state.call_started or state.call_ended: return
	state.call_started = true
	state.call_received = 1
	evidence_changed.emit(state.duplicate(true))
	_render()
func _receive_next() -> void:
	if _locked or mode != "read" or not state.call_started or state.call_ended or not state.alert_read or state.call_received != 1: return
	state.call_received = 2
	evidence_changed.emit(state.duplicate(true))
	_render()
func _read_alert() -> void:
	if _locked or mode != "read" or _source != "alert" or state.alert_read: return
	state.alert_read = true
	_commit_read()
	_render()
func _end_call() -> void:
	if _locked or mode != "read" or state.call_ended: return
	state.call_ended = true
	_commit_read()
	AudioManager.play_sfx("ui_confirm")
	_render()
func _commit_read() -> void:
	if state.call_ended and state.alert_read: _add("read", "call")
	else: evidence_changed.emit(state.duplicate(true))
func _confirm_purpose() -> void:
	if _locked or mode != "purpose" or phase_ready(): return
	_add("flags", "call")
	_feedback_text = ""
	_render()
func _mark(id: String) -> void:
	if _locked or mode != "contradiction" or state.sorted.has(id): return
	if (id == "reset" and _source != "alert") or (id == "payment" and _source != "call") or id not in ["reset","payment"]: return
	_add("sorted", id)
	if state.sorted.has("reset") and state.sorted.has("payment"): _add("domains", "call")
	_render()
func _keep_private() -> void:
	if _locked or mode != "refusal" or not state.call_ended or phase_ready(): return
	_add("captures", "call")
	_feedback_text = ""
	_render()
func _wrong(explanation: String) -> void:
	if _locked or mode not in ["purpose","refusal"] or phase_ready(): return
	state.mistakes += 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback(explanation)
func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()
func phase_ready() -> bool:
	var field: String = {"read":"read","purpose":"flags","contradiction":"domains","refusal":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("call")
func _close_app() -> void:
	if _locked: return
	if mode == "read" and not state.call_ended: _end_call()
	elif mode == "read" and not state.alert_read: _switch_source("alert")
	else: _finish_phase()
