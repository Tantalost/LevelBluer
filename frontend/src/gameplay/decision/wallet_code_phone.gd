extends "res://src/gameplay/decision/survey_phone.gd"
## Local simulation: fixed fictional code, no input field and no network action.
var _notice: bool = false
var _sms_open: bool = false
var _wallet_open: bool = false
var _feedback_text: String = ""

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/wallet_code_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_notice = next_mode == "read" and not snapshot.read.has("wallet")
	_sms_open = false
	_wallet_open = false
	_feedback_text = ""
	super.configure_chapter(next_mode, snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	if _notice:
		_activity_text("WALLET ALERT · JUST NOW\nA new-device code you didn't request.")
		_action("READ WALLET ALERT", _open_notice)
	elif mode == "read":
		if not _sms_open:
			_activity_text("WALLET / SECURITY ALERT")
			_activity_text(Chapter.ALERT)
			_activity_text("Fictional code · For this story only")
			_action("OPEN NEW SMS / DELIVERY SUPPORT", _open_sms)
		else:
			_activity_text("SMS / DELIVERY SUPPORT\nUnknown sender")
			_activity_text(Chapter.REQUEST)
			_action("KEEP BOTH MESSAGES / CONTINUE", _read_messages)
	elif mode == "purpose":
		_activity_text("WALLET: “Use code 824106 to authorize a new device. Do not share it.”")
		if phase_ready():
			_activity_success("AUTHORIZE A NEW DEVICE\nThe code grants access. It is not a cancellation code. Keep it private.")
		else:
			_activity_text("What action does this code authorize?")
			_choices("CANCEL THE DELIVERY PAYMENT", _wrong.bind("A genuine wallet alert does not authenticate the separate delivery sender. Read the action in the wallet's own message."), "AUTHORIZE A NEW DEVICE", _record.bind("flags"))
	elif mode == "contradiction":
		_activity_text("WALLET: Authorize a new device. Do not share it.\nSMS: Reply with the code to cancel it.")
		if phase_ready():
			_activity_success("“REPLY WITH THE CODE TO CANCEL IT”\nThis contradicts the alert: the code authorizes access. A real code does not make the sender's explanation true.")
		else:
			_activity_text("Tap the instruction that reverses the code's purpose.")
			_choices("“REPLY WITH THE CODE TO CANCEL IT”", _record.bind("domains"), "“DO NOT SHARE IT”", _wrong.bind("That is the wallet's protective instruction. The contradiction is the separate sender claiming that an authorization code cancels access."))
	elif mode == "verify":
		if phase_ready():
			_activity_success("REQUEST REJECTED AND REPORTED\nOpened from Amani's own wallet app. The unfamiliar device request was rejected; the code was never shared. The sender remains unknown.")
		elif _wallet_open:
			_activity_text("WALLET / DEVICE REQUESTS\nNew device · Not recognized\nStatus: Awaiting authorization")
			_choices("REJECT AND REPORT", _reject_request, "APPROVE DEVICE", _wrong.bind("Approve would authorize this unfamiliar device. Reject the request you did not initiate and report it through the wallet."))
		else:
			_activity_text("MESSAGES CLOSED / MY APPS\nChoose where to check the device request.")
			_choices("OPEN WALLET / INSTALLED APP", _open_wallet, "RETURN TO SMS / ASK THE SENDER", _wrong.bind("Do not let the sender verify their own story. Open the installed wallet independently and inspect its device request."))
	if not _feedback_text.is_empty(): _activity_text(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Wallet / Device request" if _wallet_open else "Messages / Security code"
	_status.text = "12:18  •  LTE  ▰"
	_status.visible = mode == "read"
	_nav.visible = phase_ready()
	_close.text = "CONTINUE →"
	_close.accessibility_name = "Continue to the next story or investigation step"
	_close.disabled = _locked or not phase_ready()

func _open_notice() -> void:
	if _locked or mode != "read": return
	_notice = false
	_render()

func _open_sms() -> void:
	if _locked or mode != "read" or _notice: return
	_sms_open = true
	AudioManager.play_sfx("ui_notification")
	_render()

func _read_messages() -> void:
	if _locked or mode != "read" or not _sms_open: return
	_add("read", "wallet")
	_refresh()
	_finish_phase()

func _record(field: String) -> void:
	if _locked or phase_ready() or {"purpose":"flags","contradiction":"domains"}.get(mode, "") != field: return
	_add(field, "wallet")
	_feedback_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _open_wallet() -> void:
	if _locked or mode != "verify" or phase_ready(): return
	_wallet_open = true
	_feedback_text = ""
	_render()

func _reject_request() -> void:
	if _locked or mode != "verify" or not _wallet_open or phase_ready(): return
	_add("captures", "wallet")
	_feedback_text = ""
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

func phase_ready() -> bool:
	var field: String = {"read":"read","purpose":"flags","contradiction":"domains","verify":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("wallet")

func _close_app() -> void:
	_finish_phase()
