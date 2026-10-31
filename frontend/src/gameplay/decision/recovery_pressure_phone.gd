extends "res://src/gameplay/decision/survey_phone.gd"
## Simulated support only. The SMS deadline never limits the player's time.
var _notice: bool = false
var _support: String = ""
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/recovery_pressure_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and snapshot.read.is_empty()
	_support = ""
	_feedback_text = ""
	super.configure_chapter(next_mode,snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	if _notice:
		_activity_text("NEW SMS / RECOVERY DESK\nA warning about your mobile account.")
		_action("READ MESSAGE", _open_notice)
	elif mode == "read":
		_activity_text("RECOVERY DESK / UNVERIFIED SENDER\n" + Chapter.REQUEST)
		_activity_text("Contact: Recovery number supplied in this SMS")
		_action("SAVE MESSAGE / CONTINUE", _read_message)
	elif mode == "sequence":
		if phase_ready():
			_activity_success("SEQUENCE SAVED\nDelivery request → Wallet code → Copied identity → Recovery pressure\nThe story changes services while still seeking the wallet code.")
		else:
			var picked: PackedStringArray = []
			for id: String in state.sorted: picked.append(str(Chapter.EVENT_NAMES.get(id,id)))
			_activity_text("Tap events from earliest to latest.\n" + (" → ".join(picked) if not picked.is_empty() else "Timeline: no events placed"))
			_choices(_event_label("identity"), _place_event.bind("identity"), _event_label("delivery"), _place_event.bind("delivery"))
			_choices(_event_label("recovery"), _place_event.bind("recovery"), _event_label("code"), _place_event.bind("code"))
	elif mode == "route":
		if phase_ready():
			_activity_success("INDEPENDENT ROUTE SELECTED\nOpen wallet support from the installed app and carrier help through its saved official app. The SMS's contact is not your verification source.")
		else:
			_activity_text("SMS: Call our recovery desk and give the code.\nWhere should Amani verify this request?")
			_choices("CALL THE NUMBER IN THE SMS", _wrong.bind("That number was chosen by the warning's sender. Calling it would not independently verify the warning."), "OPEN MY SAVED SERVICE APPS", _choose_route)
	elif mode == "verify":
		if phase_ready():
			_activity_success("MESSAGES ATTACHED / CASE LB-204\nSaved in the wallet app. The code stays private. Carrier help is checking the signal issue separately; its cause is not confirmed.")
		elif not _support.is_empty():
			_activity_text(("WALLET / SUPPORT\n" + Chapter.WALLET_REPLY) if _support == "wallet_support" else ("CARRIER / SAVED OFFICIAL APP\n" + Chapter.CARRIER_REPLY))
			_action("KEEP RESPONSE / BACK TO MY APPS", _keep_response)
		else:
			_activity_text("Read both support responses, then attach the saved messages.")
			_choices(("✓ " if state.sorted.has("wallet_support") else "") + "WALLET SUPPORT", _open_support.bind("wallet_support"), ("✓ " if state.sorted.has("carrier_support") else "") + "CARRIER HELP", _open_support.bind("carrier_support"))
			if state.sorted.has("wallet_support") and state.sorted.has("carrier_support"):
				_action("ATTACH SAVED MESSAGES / CASE LB-204", _attach_messages)
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _event_label(id: String) -> String:
	return ("✓ " if state.sorted.has(id) else "") + str(Chapter.EVENT_NAMES[id]).to_upper()

func _refresh() -> void:
	super._refresh()
	_title.text = "Messages / Recovery check" if mode != "verify" else "My apps / Independent support"
	_status.text = "16:05  •  School Wi-Fi"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.accessibility_name = "Continue to the next story or investigation step"
	_close.disabled = _locked or not phase_ready()

func _open_notice() -> void:
	if _locked or mode != "read": return
	_notice = false
	_render()

func _read_message() -> void:
	if _locked or mode != "read" or _notice: return
	_add("read","recovery")
	_refresh()
	_finish_phase()

func _place_event(id: String) -> void:
	if _locked or mode != "sequence" or phase_ready() or state.sorted.has(id): return
	if id != Chapter.ORDER[state.sorted.size()]:
		_wrong("Think back to the first parcel message. The wallet code came next, then the copied-name message. The recovery warning arrived last.")
		return
	_add("sorted",id)
	if state.sorted.size() == Chapter.ORDER.size(): _add("flags","recovery")
	_feedback_text = ""
	_render()

func _choose_route() -> void:
	if _locked or mode != "route" or phase_ready(): return
	_add("domains","recovery")
	_feedback_text = ""
	_render()

func _open_support(id: String) -> void:
	if _locked or mode != "verify" or phase_ready() or id not in ["wallet_support","carrier_support"]: return
	_support = id
	_feedback_text = ""
	_render()

func _keep_response() -> void:
	if _locked or mode != "verify" or _support.is_empty(): return
	_add("sorted",_support)
	_support = ""
	_render()

func _attach_messages() -> void:
	if _locked or mode != "verify" or phase_ready() or not state.sorted.has("wallet_support") or not state.sorted.has("carrier_support"): return
	_add("captures","recovery")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _wrong(explanation: String) -> void:
	if _locked or phase_ready() or not Chapter.TASKS.has(mode): return
	state.mistakes = int(state.mistakes) + 1
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
	var field: String = {"read":"read","sequence":"flags","route":"domains","verify":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("recovery")

func _close_app() -> void:
	_finish_phase()
