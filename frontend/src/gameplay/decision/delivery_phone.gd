extends "res://src/gameplay/decision/survey_phone.gd"
## SMS activity inside the existing phone shell. No URL or credential submission.
var _hold: Timer
var _hold_progress: ProgressBar
var _notice: bool = false
var _selected_link: bool = false
var _order_open: bool = false
var _feedback_text: String = ""

class LinkChip extends Button:
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled: return null
		var preview: Label = Label.new()
		preview.text = "Saved delivery link"
		set_drag_preview(preview)
		return {"delivery_link":true}

class ExpandTarget extends Button:
	signal link_received
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.get("delivery_link", false) == true
	func _drop_data(_at: Vector2, _data: Variant) -> void:
		link_received.emit()

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/delivery_chapter.gd")

func _ready() -> void:
	super._ready()
	_hold = Timer.new()
	_hold.one_shot = true
	_hold.wait_time = 0.7
	add_child(_hold)
	_hold.timeout.connect(_reveal)

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_cancel_hold()
	_notice = next_mode == "read" and not snapshot.read.has("parcel")
	_selected_link = false
	_order_open = false
	_feedback_text = ""
	super.configure_chapter(next_mode, snapshot)
	if _notice: AudioManager.play_sfx("ui_notification")

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_hold_progress) and is_instance_valid(_hold):
		_hold_progress.value = 1.0 - _hold.time_left / _hold.wait_time if not _hold.is_stopped() else 0.0

func _ink(text: String) -> void:
	_content.add_child(UI.label(text, 24, INK))

func _good(text: String) -> void:
	var panel: PanelContainer = UI.panel(_content, Color("dcefe2"))
	panel.add_theme_stylebox_override("panel", UI.box(Color("dcefe2"), Color("33D17A"), 14))
	panel.add_child(UI.label("✓ " + text, 24, INK))

func _render() -> void:
	if not is_instance_valid(_content): return
	UI.clear(_content)
	_hold_progress = null
	if _notice:
		_ink("NEW TEXT MESSAGE · JUST NOW")
		_ink("Parcel Update\nYou have a delivery message.")
		_action("OPEN MESSAGE", _open_notice)
	elif mode == "read":
		_ink("SMS / Parcel Update\nUnknown sender")
		_ink(str(Chapter.MESSAGES[0].body) + "\n\nTrack delivery:\n" + Chapter.SHORT_URL)
		_action("KEEP MESSAGE / CONTINUE", _read_message)
	elif mode == "reveal":
		_ink("SMS says: Pay ₱18 to reschedule today.\nHold the link to inspect it without visiting it.")
		var link: Button = _action("TRACK DELIVERY / HOLD", func() -> void: pass)
		link.button_down.connect(_start_hold)
		link.button_up.connect(_cancel_hold)
		_hold_progress = ProgressBar.new()
		_hold_progress.max_value = 1.0
		_hold_progress.show_percentage = false
		_hold_progress.custom_minimum_size.y = 10
		_content.add_child(_hold_progress)
		_action("INSPECT ADDRESS / TAP", _reveal)
		if not state.flags.is_empty(): _good("Address revealed: " + Chapter.SHORT_URL + "\nThe visible delivery label does not show the full address. Next, expand this short link.")
	elif mode == "expand":
		_ink("Expand the saved link locally. No website is opened.")
		var chip: LinkChip = LinkChip.new()
		chip.text = ("✓ SELECTED / " if _selected_link else "SELECT LINK / ") + Chapter.SHORT_URL
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(chip)
		chip.pressed.connect(_select_link)
		var target: ExpandTarget = ExpandTarget.new()
		target.text = "EXPAND LINK / TAP OR DROP HERE"
		_content.add_child(target)
		target.pressed.connect(_expand_selected)
		target.link_received.connect(_expand_drop)
		if not state.domains.is_empty(): _good("Destination: " + Chapter.DESTINATION + "\nThe short link hid a payment destination. Verify the request using the service you already know.")
	elif mode == "verify":
		_ink("The SMS wants ₱18. Open your order through its own app, not the message.")
		_action("OPEN MY SAVED ORDER / PARCEL APP", _open_order)
		if _order_open or not state.captures.is_empty():
			_ink("MY ORDER / " + Chapter.KNOWN_URL + "\nEvent materials · Paid\nOut for delivery · No redelivery fee requested")
			if state.captures.is_empty():
				_action("PAY / THE FEE IS ONLY ₱18", _wrong_choice)
				_action("STOP / THE PAYMENT REQUEST CONFLICTS", _confirm_order)
			else: _good("Order comparison saved. The independently opened order does not support this new fee. A small payment is still a payment to an unverified destination.")
	if not _feedback_text.is_empty(): _ink(_feedback_text)
	_refresh()
	_metrics()

func _refresh() -> void:
	super._refresh()
	_title.text = "Messages / Delivery" if mode == "read" else "Delivery / Investigation"
	_status.text = "12:15  •  LTE  ▰"
	_nav.visible = not _notice
	_close.text = "CONTINUE →"
	_close.disabled = _locked or not phase_ready()

func _fit_shell() -> void:
	super._fit_shell()
	if is_instance_valid(_shell) and mode != "read":
		_shell.position.x = 8
		_shell.size.x = maxf(100, size.x - 16)

func _open_notice() -> void:
	if _locked: return
	_notice = false
	AudioManager.play_sfx("ui_click")
	_render()

func _read_message() -> void:
	if _locked: return
	_add("read", "parcel")
	_finish_phase()

func _start_hold() -> void:
	if not _locked and mode == "reveal": _hold.start()

func _cancel_hold() -> void:
	if is_instance_valid(_hold): _hold.stop()

func _reveal() -> void:
	_cancel_hold()
	if _locked or mode != "reveal" or not is_visible_in_tree(): return
	_add("flags", "parcel")
	_render()

func _select_link() -> void:
	if _locked: return
	_selected_link = true
	_render()

func _expand_selected() -> void:
	if _locked: return
	if not _selected_link:
		show_feedback("Tap the saved link first, then tap Expand.")
		return
	_expand_drop()

func _expand_drop() -> void:
	if _locked or mode != "expand": return
	_add("domains", "parcel")
	_feedback_text = ""
	_render()

func _open_order() -> void:
	if _locked: return
	_order_open = true
	_render()

func _wrong_choice() -> void:
	if _locked or not _order_open or not state.captures.is_empty(): return
	state.mistakes = int(state.mistakes) + 1
	evidence_changed.emit(state.duplicate(true))
	show_feedback("The amount does not verify the recipient. Your paid order requests no extra fee. Compare the two requests before paying.")

func _confirm_order() -> void:
	if _locked or not _order_open or mode != "verify": return
	_add("captures", "parcel")
	_feedback_text = ""
	_render()

func show_feedback(text: String) -> void:
	_feedback_text = text
	_render()

func phase_ready() -> bool:
	var field: String = {"read":"read","reveal":"flags","expand":"domains","verify":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).has("parcel")

func _close_app() -> void:
	_finish_phase()

func set_locked(value: bool) -> void:
	if value: _cancel_hold()
	super.set_locked(value)

func stop() -> void:
	_cancel_hold()
	super.stop()
