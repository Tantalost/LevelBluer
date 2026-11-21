extends "res://src/gameplay/decision/opening_phone.gd"
## Chapter apps own local interaction only; the chapter screen owns persistence.
signal evidence_changed(snapshot: Dictionary)
signal thought_requested(text: String)
signal phase_finished
signal chat_speaker_changed(person: String, pose: int)
signal view_changed
signal story_art_changed(asset_id: String)
signal mail_finished(id: String)
var Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
var chat_entries: Array[Dictionary] = []
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Practice: GDScript = preload("res://src/gameplay/decision/tutorial_phone.gd")
const INK: Color = Color("101623")
var state: Dictionary = {}
var mode: String = "chat"
var selected: String = ""
var note_app: bool = false
var _domain: LineEdit
var _sender: LineEdit
var _copy_button: Button
var _paste_button: Button
var _clipboard: String = ""
var _note_id: String = ""
var _drafts: Dictionary[String, String] = {}
var _camera: Practice.CaptureFrame
var _capture_view: SubViewport
var _capture_serial: int = 0
var _taking: bool = false
var _feedback: Tween
var _previews: Dictionary = {}
var _chat_index: int = 0
var _chat_stage: String = "stopped"
var _chat_elapsed: float = 0.0
var _chat_history: Array[int] = []
var _chat_status: Label
var _chat_footer: VBoxContainer
var _chat_draft: RichTextLabel
var _chat_send: Button
const MAIL_ARRIVAL_INTERVAL: float = 0.65
const MAIL_POP_DURATION: float = 0.22
var _mail_arrivals: bool = false
var _mail_elapsed: float = 0.0
var _mail_cards: Array[Button] = []
var _mail_scroll_pending: bool = false
const REPLY_TYPE_SECONDS: float = 1.6
const REPLY_SEND_SECONDS: float = 0.6
const REPLY_SENT_SECONDS: float = 1.0
var _reply_stage: String = ""
var _reply_elapsed: float = 0.0
var _reply_draft: Label
var _reply_status: Label

func _ready() -> void:
	super._ready()
	# Bubble wrapping settles during container layout, after _render returns.
	_content.resized.connect(_scroll_chat)
	_content.resized.connect(_scroll_reply)
	_content.get_parent().resized.connect(_resize_camera)

func _process(delta: float) -> void:
	_tick_chat(delta)
	_tick_mail_arrivals(delta)
	_tick_reply(delta)
	if is_instance_valid(_copy_button) and is_instance_valid(_sender):
		_copy_button.disabled = _locked or not _sender.has_selection()

func _tick_mail_arrivals(delta: float) -> void:
	if not _mail_arrivals or _locked or not is_visible_in_tree() or _app != "mail" or not selected.is_empty(): return
	if _mail_scroll_pending:
		_mail_scroll_pending = false
		for index: int in range(_mail_cards.size()-1,-1,-1):
			if is_instance_valid(_mail_cards[index]) and _mail_cards[index].visible:
				(_content.get_parent() as ScrollContainer).ensure_control_visible(_mail_cards[index])
				break
	_mail_elapsed = minf(_mail_elapsed + delta, Chapter.MESSAGES.size() * MAIL_ARRIVAL_INTERVAL + MAIL_POP_DURATION)
	for index: int in _mail_cards.size():
		var card: Button = _mail_cards[index]
		if not is_instance_valid(card): continue
		var age: float = _mail_elapsed - (int(card.get_meta("arrival_index", index)) + 1) * MAIL_ARRIVAL_INTERVAL
		if age < -0.00001: continue
		if not card.visible:
			card.show()
			_mail_scroll_pending = true
			var entry: Dictionary = Chapter.message(str(card.get_meta("message_id", "")))
			notify_phone({"id":str(entry.get("id", "")), "app":"Mail", "sender":entry.get("sender", ""), "preview":entry.get("subject", ""), "duration":0.8})
		var progress: float = 1.0 if _reduced_motion() else clampf(age / MAIL_POP_DURATION,0.0,1.0)
		var eased: float = 1.0 - pow(1.0-progress,3.0)
		card.modulate.a = eased
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * lerpf(0.96,1.0,eased)

func _tick_chat(delta: float) -> void:
	# No detached timers: pause, home screen and scene exit stop the clock.
	if _locked or not is_visible_in_tree() or mode != "chat" or _app != "mail": return
	if _chat_stage in ["stopped", "done", "send"]: return
	_chat_elapsed += delta
	var entry: Dictionary = chat_entries[_chat_index]
	if _chat_stage == "draft":
		var letters: int = str(entry["text"]).length()
		_chat_draft.visible_characters = letters if SettingsService.text_speed == "instant" else mini(letters, int(_chat_elapsed * 28.0 * SettingsService.text_speed_multiplier()))
		if _chat_draft.visible_characters >= letters:
			_chat_stage = "send"
			_refresh()
	elif _chat_stage == "typing":
		var dots: String = "…" if _reduced_motion() else ".".repeat(1 + int(_chat_elapsed * 2.0) % 3)
		_chat_status.text = str(entry["who"]) + " is typing" + dots
		if _chat_elapsed >= 1.8: _deliver_chat()
	elif _chat_stage == "hold" and _chat_elapsed >= 2.4:
		_chat_index += 1
		_begin_chat_turn()

func _begin_chat_turn() -> void:
	_chat_elapsed = 0.0
	if _chat_index >= chat_entries.size():
		_chat_stage = "done"
		_render()
		return
	var entry: Dictionary = chat_entries[_chat_index]
	_chat_stage = "draft" if entry["who"] == "John" else "typing"
	chat_speaker_changed.emit(str(entry["who"]), int(entry["face"]))
	_render()

func _send_chat() -> void:
	if _locked or not is_visible_in_tree() or _app != "mail" or _chat_stage != "send": return
	_deliver_chat()

func _deliver_chat() -> void:
	_chat_history.append(_chat_index)
	_chat_stage = "hold"
	_chat_elapsed = 0.0
	AudioManager.play_sfx("ui_confirm")
	_render()

func _build_chat() -> void:
	for index: int in _chat_history:
		var entry: Dictionary = chat_entries[index]
		var own: bool = entry["who"] == "John"
		var bubble: PanelContainer = UI.panel(_content)
		var style: StyleBoxFlat = UI.box(Color("153B37") if own else Color("FFFFFF"), Color("d9cbb8"), 14)
		style.set_corner_radius_all(16)
		bubble.add_theme_stylebox_override("panel", style)
		var body: VBoxContainer = UI.column(bubble, 8)
		body.add_child(UI.label(str(entry["who"]), 22, Color("4FE0D4") if own else Color("365b63")))
		body.add_child(UI.label(str(entry["text"]), 26, Color("F3ECD6") if own else INK))
	_chat_status = UI.label("", 22, Color("365b63"))
	_content.add_child(_chat_status)
	if _chat_stage == "typing":
		_chat_status.text = str(chat_entries[_chat_index]["who"]) + " is typing…"
	elif _chat_stage in ["draft", "send"]:
		_chat_status.text = "John · Writing a message"
	elif _chat_stage == "done":
		_chat_status.text = "Seen by everyone"
	# The composer stays below the scroll viewport, never inside chat history.
	_chat_footer = UI.column(_content.get_parent().get_parent(), 8)
	_chat_footer.name = "ChatComposer"
	_chat_footer.visible = _chat_stage in ["draft", "send"]
	var composer_row: HBoxContainer = HBoxContainer.new()
	composer_row.add_theme_constant_override("separation", 8)
	_chat_footer.add_child(composer_row)
	_chat_draft = RichTextLabel.new()
	_chat_draft.add_theme_font_override("normal_font", UI.FONT)
	_chat_draft.add_theme_color_override("default_color", INK)
	_chat_draft.add_theme_stylebox_override("normal", UI.box(Color("FFFFFF"), Color("b6a998"), 10))
	_chat_draft.scroll_following = true
	_chat_draft.mouse_filter = MOUSE_FILTER_IGNORE
	_chat_draft.size_flags_horizontal = SIZE_EXPAND_FILL
	composer_row.add_child(_chat_draft)
	if _chat_footer.visible:
		_chat_draft.text = str(chat_entries[_chat_index]["text"])
		_chat_draft.visible_characters = _chat_draft.text.length() if _chat_stage == "send" else int(_chat_elapsed * 28.0 * SettingsService.text_speed_multiplier())
	_chat_send = UI.button("↑", _send_chat, true)
	_chat_send.accessibility_name = "Send John's message"
	_chat_send.tooltip_text = "Send John's message"
	_chat_send.size_flags_vertical = SIZE_SHRINK_END
	var send_style: StyleBoxFlat = UI.box(Color("4FE0D4"), Color("8FF0E6"), 8)
	send_style.set_corner_radius_all(24)
	_chat_send.add_theme_stylebox_override("normal", send_style)
	composer_row.add_child(_chat_send)
	_scroll_chat.call_deferred()

func _scroll_chat() -> void:
	if mode == "chat" and is_instance_valid(_chat_status) and _chat_status.is_inside_tree():
		(_content.get_parent() as ScrollContainer).ensure_control_visible(_chat_status)

class MessageCard extends Button:
	var message_id: String = ""
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled:
			return null
		var preview: Label = UI.label(text, 22, Color("101623"))
		set_drag_preview(preview)
		return {"survey_card":message_id}

class ReplyButton extends Button:
	func _draw() -> void:
		var unit: float = minf(size.x,size.y) / 32.0
		var origin: Vector2 = (size - Vector2.ONE * 24.0 * unit) * 0.5
		var points: PackedVector2Array = []
		for point: Vector2 in [Vector2(3,10),Vector2(10,3),Vector2(10,7),Vector2(15,7),Vector2(19,9),Vector2(21,13),Vector2(21,20),Vector2(17,16),Vector2(14,14),Vector2(10,14),Vector2(10,18)]:
			points.append(origin + point * unit)
		draw_colored_polygon(points,Color("918b83") if disabled else Color("365b63"))

func _reply_action() -> void:
	var button: ReplyButton = ReplyButton.new()
	button.name = "ReplyAction"
	button.accessibility_name = "Reply to this email as John"
	button.tooltip_text = "Reply"
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	button.set_meta("reply_icon",true)
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	for style: String in ["pressed","hover","focus"]:
		button.add_theme_stylebox_override(style,UI.box(Color("dcefe2"),Color("85c5d5"),4))
	button.pressed.connect(acknowledge)
	button.resized.connect(button.queue_redraw)
	_content.add_child(button)

class SortBin extends Button:
	signal card_dropped(id: String)
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.has("survey_card")
	func _drop_data(_at: Vector2, data: Variant) -> void:
		card_dropped.emit(str(data["survey_card"]))

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	if not _reply_stage.is_empty() and next_mode == mode and snapshot.get("beat",-1) == state.get("beat",-2): return
	_reply_stage = ""
	var arrival_time: float = _mail_elapsed if _mail_arrivals and next_mode == mode and snapshot.get("beat",-1) == state.get("beat",-2) else 0.0
	chat_entries.assign(Chapter.CHAT_MESSAGES)
	if Chapter.STORY[int(snapshot.beat)].has("messages"):
		chat_entries.assign(Chapter.STORY[int(snapshot.beat)].messages)
	if snapshot.get("phase", "") == "sleep" and Chapter.get("SLEEP_CHAT") is Array:
		chat_entries.assign(Chapter.get("SLEEP_CHAT"))
	if Chapter.ID == "mod_01_ch_02" and Chapter.STORY[int(snapshot.beat)].get("chat_id", "") == "private":
		chat_entries.assign(Chapter.PRIVATE_CHAT)
	_clipboard = ""
	_drafts.clear()
	_domain = null
	_capture_serial += 1
	_taking = false
	if is_instance_valid(_capture_view):
		_capture_view.queue_free()
		_capture_view = null
	mode = next_mode
	_chat_index = 0
	_chat_history.clear()
	_chat_stage = "draft" if mode == "chat" else "stopped"
	_chat_elapsed = 0.0
	state = snapshot.duplicate(true)
	_mail_arrivals = Chapter.ID == "mod_01_ch_01" and mode == "read" and str(state.get("phase","")) == "day" and (state.get("read",[]) as Array).is_empty()
	_mail_elapsed = arrival_time
	_mail_scroll_pending = false
	selected = ""
	note_app = false
	configure({"embedded":true})
	_notifications.set_scope(Chapter.ID + ":" + str(state.get("perk_run", {}).get("id", "")) + ":" + str(state.get("beat", 0)) + ":" + mode)
	_alarm_pending = false
	_unlocked = true
	_read = true # Never inherit the opening's Prize Desk notification.
	_app = "mail"
	_zoom = 1.0
	show()
	_render()

func _render() -> void:
	if not is_instance_valid(_content):
		return
	_camera = null
	_mail_cards.clear()
	_mail_scroll_pending = false
	_remember_note()
	_domain = null
	_sender = null
	_copy_button = null
	_paste_button = null
	if is_instance_valid(_chat_footer):
		_chat_footer.get_parent().remove_child(_chat_footer)
		_chat_footer.queue_free()
	_chat_footer = null
	_chat_send = null
	UI.clear(_content)
	_content.size_flags_vertical = SIZE_EXPAND_FILL if _app == "home" else SIZE_FILL
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	if _app == "home":
		_render_story_home()
	elif mode == "chat":
		_build_chat()
	elif note_app:
		_build_notes()
	elif selected.is_empty():
		_build_inbox()
	else:
		_build_message()
	_refresh()
	_metrics()
	view_changed.emit()

func _story_icon(parent: Control, app_id: int, color: Color, mail: bool) -> void:
	super._story_icon(parent, app_id, color, mail)
	if mode == "notes" and app_id == 5:
		var tile: Button = parent.get_child(parent.get_child_count() - 1) as Button
		tile.name = "NotepadIcon"
		tile.accessibility_name = "Open Notepad"
		tile.focus_mode = FOCUS_ALL
		tile.mouse_filter = MOUSE_FILTER_STOP
		tile.pressed.connect(_open_notes)

func _open_story_email() -> void:
	_open_mail()

func _action(caption: String, callback: Callable) -> Button:
	var button: Button = UI.button(caption, callback)
	button.add_theme_stylebox_override("normal", UI.box(Color("f0e5d6"), Color("b6a998"), 12))
	var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.set_corner_radius_all(10)
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", INK)
	button.custom_minimum_size.x = 0
	_content.add_child(button)
	return button

## One policy for every email investigation step. New steps register their saved
## evidence field here so ordering, appearance and input locking stay together.
const MAIL_TASKS: Dictionary = {
	"sort": {"field":"sorted", "pending":"TO SORT", "done":"SORTED"},
	"highlight": {"field":"flags", "pending":"FIND THE CLUE", "done":"CLUE COLLECTED"},
	"notes": {"field":"domains", "pending":"CHECK SENDER", "done":"SENDER NOTE SAVED"},
	"capture": {"field":"captures", "pending":"CAPTURE EVIDENCE", "done":"EVIDENCE CAPTURED"},
}

func _completed_mail_ids() -> Array:
	return state.get(str(MAIL_TASKS.get(mode, {}).get("field", "read")), [])

func _mail_task_done(id: String) -> bool:
	return MAIL_TASKS.has(mode) and id in _completed_mail_ids()

func _build_inbox() -> void:
	var ids: Array = Chapter.suspicious_ids() if mode in ["highlight", "notes", "capture"] else []
	# Reading during the story and completing an investigation task are distinct.
	var read_ids: Array = _completed_mail_ids()
	for entry: Dictionary in AppViews.ordered_mail(Chapter.MESSAGES, read_ids):
		var id: String = str(entry["id"])
		if not ids.is_empty() and not ids.has(id):
			continue
		var done: bool = read_ids.has(id)
		var arrival_index: int = Chapter.MESSAGES.find(entry)
		# Keep the original message number when read entries move below unread mail.
		var row_entry: Dictionary = entry.duplicate()
		if mode == "sort":
			row_entry.sender = ("SORTED · SUSPICIOUS" if bool(entry.suspicious) else "SORTED · LEGIT") if done else "TO SORT · " + str(entry.sender)
		elif MAIL_TASKS.has(mode):
			row_entry.sender = str(MAIL_TASKS[mode].done) if done else str(MAIL_TASKS[mode].pending) + " · " + str(entry.sender)
		var card: Button = AppViews.mail_row(_content, row_entry, done, _select.bind(id), arrival_index + 1)
		card.name = "Message_" + id
		card.set_meta("arrival_index", arrival_index)
		_mail_cards.append(card)
		card.visible = not _mail_arrivals or _mail_elapsed >= (arrival_index + 1) * MAIL_ARRIVAL_INTERVAL
	if phase_ready():
		_action("CONTINUE →", _finish_phase)

func _select(id: String) -> void:
	if _locked or _taking or not _reply_stage.is_empty() or Chapter.message(id).is_empty():
		return
	if _mail_task_done(id): return
	_notifications.dismiss()
	selected = id
	_render()

func _build_message() -> void:
	var entry: Dictionary = Chapter.message(selected)
	if mode == "capture":
		_build_camera(entry)
		return
	if mode == "read":
		# The opening already owns the email reader presentation; keep one renderer.
		_message = entry.duplicate(true)
		_message.sender = str(entry.sender) + "\n" + str(entry.address)
		_message.received = "Today, 15:08"
		_message.body = str(entry.body) + ("\n\n" + str(entry.phrase) if entry.has("phrase") else "")
		super._render_message()
		if not _reply_stage.is_empty():
			_build_reply(entry)
			return
		if not state.get("read", []).has(selected):
			if bool(entry.suspicious): _reply_action()
			_action("FINISHED READING", acknowledge)
		_action("INBOX", _inbox)
		return
	var header: PanelContainer = UI.panel(_content, Color("e9efed"))
	header.name = "MessageHeader"
	header.add_theme_stylebox_override("panel", UI.box(Color("e9efed"), Color("c8d4cf"), 14))
	var metadata: VBoxContainer = UI.column(header, 10)
	var subject: Label = UI.label(str(entry["subject"]), 28, INK)
	subject.set_meta("mail_subject", true)
	metadata.add_child(subject)
	var sender_name: Label = UI.label("FROM  " + str(entry["sender"]), 22, Color("365b63"))
	sender_name.set_meta("mail_metadata", true)
	metadata.add_child(sender_name)
	if mode == "notes":
		_sender = LineEdit.new()
		_sender.text = str(entry["address"])
		_sender.editable = false
		_sender.context_menu_enabled = false
		_sender.shortcut_keys_enabled = false
		_sender.virtual_keyboard_enabled = false
		_sender.deselect_on_focus_loss_enabled = false
		_sender.expand_to_text_length = false
		_sender.add_theme_font_override("font", UI.FONT)
		_sender.add_theme_color_override("font_uneditable_color", INK)
		_sender.add_theme_color_override("font_selected_color", INK)
		_sender.add_theme_color_override("selection_color", Color("4FE0D4", 0.55))
		_sender.add_theme_stylebox_override("read_only", UI.box(Color("FFFFFF"), Color("8aa9a3"), 8))
		_sender.accessibility_name = "Sender address. Select text, then Copy. Select domain is also available."
		metadata.add_child(_sender)
		var selection_tools: HBoxContainer = HBoxContainer.new()
		metadata.add_child(selection_tools)
		var select_domain: Button = UI.button("SELECT DOMAIN", _select_domain)
		select_domain.size_flags_horizontal = SIZE_EXPAND_FILL
		selection_tools.add_child(select_domain)
		_copy_button = UI.button("COPY", _copy_sender, true)
		_copy_button.focus_mode = FOCUS_NONE
		selection_tools.add_child(_copy_button)
	else:
		var address: Label = UI.label(str(entry["address"]), 22, Color("365b63"))
		address.set_meta("sender_address", str(entry["address"]))
		address.set_meta("mail_metadata", true)
		metadata.add_child(address)
	var body_panel: PanelContainer = UI.panel(_content, Color("fffaf2"))
	body_panel.name = "MessageBody"
	body_panel.add_theme_stylebox_override("panel", UI.box(Color("fffaf2"), Color("e5dacb"), 14))
	var body: VBoxContainer = UI.column(body_panel, 14)
	if mode == "highlight":
		body.add_child(UI.label("Select the passage that makes this request suspicious.", 24, INK))
	body.add_child(UI.label(str(entry["body"]), 24, INK))
	if entry.has("phrase"):
		if mode == "highlight":
			var passage: RichTextLabel = RichTextLabel.new()
			passage.bbcode_enabled = true
			passage.fit_content = true
			passage.scroll_active = false
			passage.add_theme_font_override("normal_font", UI.FONT)
			passage.add_theme_font_size_override("normal_font_size", 24)
			passage.add_theme_color_override("default_color", INK)
			var phrase: String = str(entry["phrase"])
			if state["flags"].has(selected):
				phrase = "[bgcolor=#ffda86]" + phrase + "[/bgcolor]"
			passage.text = "[url=flag]" + phrase + "[/url]"
			passage.meta_clicked.connect(func(_meta: Variant) -> void: mark_flag())
			body.add_child(passage)
		else:
			body.add_child(UI.label(str(entry["phrase"]), 24, INK))
	match mode:
		"read":
			_action("READ / JOHN REPLIES" if bool(entry["suspicious"]) else "MARK READ", acknowledge)
		"sort":
			var card: MessageCard = MessageCard.new()
			card.message_id = selected
			card.text = "DRAG THIS MESSAGE\nor tap a bin below"
			card.custom_minimum_size.y = 60
			card.add_theme_font_override("font", UI.FONT)
			card.add_theme_font_size_override("font_size", 22)
			_content.add_child(card)
			for suspicious: bool in [false, true]:
				var bin: SortBin = SortBin.new()
				bin.text = "SUSPICIOUS" if suspicious else "LOOKS FINE"
				bin.custom_minimum_size.y = 52
				bin.add_theme_font_override("font", UI.FONT)
				bin.add_theme_font_size_override("font_size", 22)
				bin.add_theme_stylebox_override("normal", UI.box(Color("0A1730"), Color("4FE0D4"), 10))
				bin.pressed.connect(sort_message.bind(selected, suspicious))
				bin.card_dropped.connect(func(id: String) -> void: sort_message(id, suspicious))
				_content.add_child(bin)
	_action("INBOX", _inbox)

func _select_domain() -> void:
	if _locked or not is_instance_valid(_sender): return
	var start: int = _sender.text.find("@") + 1
	_sender.grab_focus()
	_sender.caret_column = _sender.text.length()
	_sender.select(start, _sender.text.length())

func _copy_sender() -> void:
	if _locked or not is_instance_valid(_sender) or not _sender.has_selection(): return
	_clipboard = _sender.get_selected_text()
	_copy_button.text = "COPIED"
	AudioManager.play_sfx("ui_confirm")

func _paste_note() -> void:
	if _locked or _clipboard.is_empty() or not is_instance_valid(_domain): return
	# This clipboard belongs only to this simulation; never read the OS clipboard.
	_domain.text = _clipboard
	_domain.caret_column = _domain.text.length()
	_remember_note()

func _remember_note() -> void:
	if is_instance_valid(_domain) and not _note_id.is_empty():
		_drafts[_note_id] = _domain.text

func acknowledge() -> void:
	if _locked or mode != "read" or selected.is_empty() or not _reply_stage.is_empty():
		return
	if state.get("read", []).has(selected):
		_inbox()
		return
	var entry: Dictionary = Chapter.message(selected)
	if bool(entry["suspicious"]) and Chapter.ID == Survey.ID:
		_reply_stage = "typing"
		_reply_elapsed = 0.0
		_render()
		return
	_complete_read()

func _build_reply(entry: Dictionary) -> void:
	var panel: PanelContainer = UI.panel(_content,Color("f0e5d6"))
	panel.name = "ReplyComposer"
	panel.add_theme_stylebox_override("panel",UI.box(Color("f0e5d6"),Color("85c5d5"),12))
	var body: VBoxContainer = UI.column(panel,10)
	body.add_child(UI.label("JOHN / REPLY",22,INK))
	var recipient: Label = UI.label("To: " + str(entry.address),22,Color("544650"))
	recipient.set_meta("opening_mail_metadata",true)
	body.add_child(recipient)
	_reply_draft = UI.label({"survey":"I'm ready to start the survey job.","urgent":"Here is my contact number.\n[John's phone number]","profile":"Here are my details.\n[John's birth date]\n[John's home address]"}.get(selected,"Here are the requested details."),24,INK)
	_reply_draft.visible_characters = 0
	body.add_child(_reply_draft)
	_reply_status = UI.label("John is typing…",22,Color("544650"))
	_reply_status.set_meta("opening_mail_metadata",true)
	body.add_child(_reply_status)
	# Keep the composer in view after the scroll container has laid out its text.
	_scroll_reply.call_deferred()

func _scroll_reply() -> void:
	if not _reply_stage.is_empty() and is_instance_valid(_reply_status) and _reply_status.is_inside_tree():
		(_content.get_parent() as ScrollContainer).ensure_control_visible(_reply_status)

func _tick_reply(delta: float) -> void:
	if _reply_stage.is_empty() or _locked or not is_visible_in_tree() or _app != "mail": return
	_reply_elapsed += delta
	if _reply_stage == "typing":
		_reply_draft.visible_characters = -1 if _reduced_motion() else int(_reply_draft.text.length() * clampf(_reply_elapsed / REPLY_TYPE_SECONDS,0.0,1.0))
		if _reply_elapsed >= REPLY_TYPE_SECONDS:
			_reply_draft.visible_characters = -1
			_reply_stage = "sending"
			_reply_elapsed = 0.0
			_reply_status.text = "Sending…"
	elif _reply_stage == "sending" and _reply_elapsed >= REPLY_SEND_SECONDS:
		_reply_stage = "sent"
		_reply_elapsed = 0.0
		_reply_status.text = "✓ Reply sent"
		_reply_status.add_theme_color_override("font_color",Color("24634b"))
		AudioManager.play_sfx("ui_confirm")
	elif _reply_stage == "sent" and _reply_elapsed >= REPLY_SENT_SECONDS:
		_reply_stage = ""
		_complete_read()

func _complete_read() -> void:
	var entry: Dictionary = Chapter.message(selected)
	_add("read", selected)
	mail_finished.emit(selected)
	thought_requested.emit(Survey.REPLIED if bool(entry["suspicious"]) else Survey.EXPECTED)
	_inbox()

func sort_message(id: String, suspicious: bool) -> void:
	if _locked or mode != "sort" or Chapter.message(id).is_empty() or state["sorted"].has(id):
		return
	if bool(Chapter.message(id)["suspicious"]) != suspicious:
		state["mistakes"] = int(state["mistakes"]) + 1
		Survey.block_star(state, "sort")
		evidence_changed.emit(state.duplicate(true))
		thought_requested.emit("Look at the request and its context—not just whether the sender name sounds familiar.")
		AudioManager.play_sfx("ui_error")
		if not _reduced_motion():
			if _feedback != null and _feedback.is_valid():
				_feedback.kill()
			_feedback = create_tween()
			_feedback.tween_property(_shell, "rotation", 0.008, 0.12)
			_feedback.tween_property(_shell, "rotation", -0.008, 0.12)
			_feedback.tween_property(_shell, "rotation", 0.0, 0.12)
		return
	_add("sorted", id)
	AudioManager.play_sfx("ui_confirm")
	_inbox()

func mark_flag(candidate: String = "request") -> void:
	if _locked or mode != "highlight" or Chapter.message(selected).is_empty() or selected in state.flags:
		return
	if candidate != "request" or selected not in Chapter.suspicious_ids():
		Survey.block_star(state, "highlight")
		state.mistakes += 1
		evidence_changed.emit(state.duplicate(true))
		thought_requested.emit("That passage does not establish a suspicious demand. Check what you are being asked to do, what is promised, and whether you can verify it. This objective can be retried on your next run.")
		AudioManager.play_sfx("ui_error")
		return
	_add("flags", selected)
	thought_requested.emit(str(Chapter.message(selected)["thought"]))
	AudioManager.play_sfx("ui_confirm")
	_inbox()

func _notes_home() -> void:
	if _locked:
		return
	_app = "home"
	note_app = false
	_render()
	_zoom_app(0.0)

func _open_notes() -> void:
	if _locked or mode != "notes":
		return
	_app = "mail"
	note_app = true
	_render()
	_zoom_app(1.0)

func _open_mail() -> void:
	if _locked:
		return
	_app = "mail"
	note_app = false
	_render()
	_zoom_app(1.0)

func _build_notes() -> void:
	if selected.is_empty():
		_content.add_child(UI.label("Open a message in Mail first. Then copy the part after @ here.", 24, INK))
		return
	var title: Label = UI.label("DOMAIN NOTE", 22, INK)
	title.set_meta("mail_metadata", true)
	title.tooltip_text = "Sender: " + str(Chapter.message(selected)["sender"]) + "\n" + str(Chapter.message(selected)["subject"])
	_content.add_child(title)
	var entry_row: HBoxContainer = HBoxContainer.new()
	_content.add_child(entry_row)
	_domain = LineEdit.new()
	_note_id = selected
	_domain.text = _drafts.get(selected, "")
	_domain.context_menu_enabled = false
	_domain.shortcut_keys_enabled = false
	_domain.placeholder_text = "domain"
	_domain.expand_to_text_length = false
	_domain.size_flags_horizontal = SIZE_EXPAND_FILL
	_domain.add_theme_color_override("font_color", INK)
	_domain.add_theme_stylebox_override("normal", UI.box(Color.WHITE, Color("8aa9a3"), 10))
	_domain.max_length = 80
	_domain.custom_minimum_size = Vector2(0, 54)
	_domain.add_theme_font_override("font", UI.FONT)
	_domain.add_theme_font_size_override("font_size", 24)
	_domain.text_submitted.connect(func(_text: String) -> void: check_domain())
	entry_row.add_child(_domain)
	_paste_button = _action("PASTE", _paste_note)
	_paste_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_paste_button.reparent(entry_row)
	_action("SAVE NOTE", check_domain)

func check_domain() -> void:
	if _locked or mode != "notes" or not note_app or not is_instance_valid(_domain):
		return
	if not Chapter.domain_matches(_domain.text, selected):
		thought_requested.emit("Copy only the part after @. Check the spelling in Mail; a similar domain is not the same address.")
		return
	_add("domains", selected)
	thought_requested.emit(Survey.DOMAIN_SAVED)
	note_app = false
	_inbox()

func _build_camera(entry: Dictionary) -> void:
	_camera = Practice.CaptureFrame.new()
	_camera.minimum_font_pixels = 14.0
	_camera.sheet_text = "FROM " + str(entry["address"]) + "\n\n" + str(entry["subject"]) + "\n\n" + str(entry["phrase"])
	_content.add_child(_camera)
	var ink: Practice.FrameInk = Practice.FrameInk.new()
	ink.camera = _camera
	ink.mouse_filter = MOUSE_FILTER_IGNORE
	_camera.add_child(ink)
	ink.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_camera.framing_changed.connect(func(_value: Array[float]) -> void: ink.queue_redraw())
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	_content.add_child(grid)
	for direction: Vector2 in [Vector2(-0.05,0),Vector2(0.05,0),Vector2(0,-0.05),Vector2(0,0.05)]:
		var caption: String = "←" if direction.x < 0 else ("→" if direction.x > 0 else ("↑" if direction.y < 0 else "↓"))
		var button: Button = UI.button(caption, func() -> void:
			if not _locked and is_instance_valid(_camera): _camera.nudge(direction))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(button)
	for delta: float in [0.05, -0.05]:
		var button: Button = UI.button("LARGER +" if delta > 0 else "SMALLER −", func() -> void:
			if not _locked and is_instance_valid(_camera): _camera.grow_frame(Vector2.ONE * delta))
		grid.add_child(button)

func take_photo() -> void:
	if _locked or _taking or mode != "capture" or not is_instance_valid(_camera):
		return
	if not _camera.complete():
		Survey.block_star(state, "capture")
		state.mistakes += 1
		evidence_changed.emit(state.duplicate(true))
		thought_requested.emit("Keep the sender, subject and complete request inside the frame. Drag the blue corner to resize, or use the buttons below.")
		return
	_taking = true
	var serial: int = _capture_serial
	var id: String = selected
	if DisplayServer.get_name() != "headless":
		_capture_view = SubViewport.new()
		var capture_size: Vector2i = Vector2i(_camera.size)
		var crop: Rect2i = Rect2i(Rect2(_camera.frame.position * _camera.size, _camera.frame.size * _camera.size))
		_capture_view.size = capture_size
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		var sheet: Practice.CaptureFrame = Practice.CaptureFrame.new()
		sheet.minimum_font_pixels = _camera.minimum_font_pixels
		sheet.capture_font_size = _camera._sheet.get_theme_font_size("font_size")
		sheet.sheet_text = _camera.sheet_text
		sheet.locked = true
		_capture_view.add_child(sheet)
		sheet.size = Vector2(capture_size)
		await RenderingServer.frame_post_draw
		if serial != _capture_serial or not is_instance_valid(_capture_view):
			return
		var preview: Image = _capture_view.get_texture().get_image()
		_capture_view.queue_free()
		_capture_view = null
		if preview == null or preview.is_empty():
			_taking = false
			return
		_previews[id] = ImageTexture.create_from_image(preview.get_region(crop.intersection(Rect2i(Vector2i.ZERO, preview.get_size()))))
	_taking = false
	if _locked or not is_inside_tree() or id != selected:
		return
	_add("captures", id)
	AudioManager.play_sfx("ui_confirm")
	thought_requested.emit(Survey.CAPTURE_SAVED)
	_inbox()

func _add(field: String, id: String) -> void:
	if not state[field].has(id):
		state[field].append(id)
		evidence_changed.emit(state.duplicate(true))

func phase_ready() -> bool:
	if not _reply_stage.is_empty(): return false
	if mode == "chat": return _chat_stage == "done"
	var field: String = "read" if mode == "read" else str(MAIL_TASKS.get(mode, {}).get("field", ""))
	return not field.is_empty() and (state.get(field, []) as Array).size() == (6 if mode in ["read", "sort"] else 3)

func _finish_phase() -> void:
	if not _locked and phase_ready():
		phase_finished.emit()

func _inbox() -> void:
	if _locked or not _reply_stage.is_empty():
		return
	selected = ""
	_render()

func _close_app() -> void:
	if _locked or _taking or not _reply_stage.is_empty():
		return
	if mode == "chat" and phase_ready():
		_finish_phase()
		return
	if _app == "mail":
		_notes_home()
	else:
		_open_mail()

func _refresh() -> void:
	super._refresh()
	_title.text = "✦ Club Chat" if mode == "chat" else ("▤ Notepad" if note_app else "✉ Mail")
	_status.text = "21:14  •  LTE  ▰" if mode not in ["read", "chat"] else "15:08  •  LTE  ▰"
	_nav.visible = true
	if mode in ["notes", "capture"]: _nav.visible = false
	_close.text = "× CLOSE" if _app == "mail" else ("OPEN CHAT" if mode == "chat" else "OPEN MAIL")
	_close.disabled = _locked or not _reply_stage.is_empty()
	if mode == "chat" and phase_ready(): _close.text = "CONTINUE →"
	if is_instance_valid(_chat_send): _chat_send.disabled = _locked or _chat_stage != "send"
	for node: Node in _content.find_children("*", "Button", true, false):
		(node as Button).disabled = _locked or _taking
		if node.has_meta("message_id") and _mail_task_done(str(node.get_meta("message_id"))):
			(node as Button).disabled = true
	if is_instance_valid(_paste_button): _paste_button.disabled = _locked or _clipboard.is_empty()
	if is_instance_valid(_copy_button): _copy_button.disabled = _locked or not _sender.has_selection()
	if is_instance_valid(_camera):
		_camera.locked = _locked or _taking
		if _locked: _camera.cancel_drag()
	if is_instance_valid(_domain): _domain.editable = not _locked

func _metrics() -> void:
	if not is_inside_tree(): return
	super._metrics()
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	for node: Node in _content.find_children("*", "Label", true, false):
		if is_instance_valid(_camera) and _camera.is_ancestor_of(node): continue
		(node as Label).add_theme_font_size_override("font_size", maxi(26, ceili(22 / physical)))
		if mode == "chat": (node as Label).add_theme_font_size_override("font_size", maxi(22, ceili(18 / physical)))
		if node.has_meta("mail_metadata"): (node as Label).add_theme_font_size_override("font_size", maxi(22, ceili(17 / physical)))
		if node.has_meta("opening_mail_metadata"): (node as Label).add_theme_font_size_override("font_size", maxi(22, ceili(16 / physical)))
		if node.has_meta("opening_subject"): (node as Label).add_theme_font_size_override("font_size", maxi(28, ceili(24 / physical)))
		if node.has_meta("mail_subject"): (node as Label).add_theme_font_size_override("font_size", maxi(28, ceili(22 / physical)))
		if node.has_meta("sender_address"):
			var address: Label = node as Label
			var full: String = str(address.get_meta("sender_address"))
			# Wrap at the address boundary instead of splitting gmail.com into pieces.
			address.text = full.replace("@", "\n@") if size.x * physical < 480 else full
		if Chapter.get("FULL_WIDTH_INVESTIGATION") == true:
			(node as Label).add_theme_font_size_override("font_size", ceili(16 / physical))
	if Chapter.get("FULL_WIDTH_INVESTIGATION") == true:
		_content.add_theme_constant_override("separation", ceili(10 / physical))
		for node: Node in _content.find_children("*", "Button", true, false):
			(node as Button).custom_minimum_size.y = maxf(54, 48 / physical)
	for node: Node in _content.find_children("*", "RichTextLabel", true, false):
		(node as RichTextLabel).add_theme_font_size_override("normal_font_size", maxi(26, ceili(22 / physical)))
	if is_instance_valid(_domain):
		_domain.add_theme_font_size_override("font_size", maxi(24, ceili(20 / physical)))
		_domain.custom_minimum_size.y = maxf(54, 48 / physical)
	if is_instance_valid(_paste_button):
		_paste_button.custom_minimum_size.x = maxf(100, 88 / physical)
	if is_instance_valid(_sender):
		_sender.add_theme_font_size_override("font_size", maxi(22, ceili(17 / physical)))
		_sender.custom_minimum_size.y = maxf(54, 48 / physical)
	if is_instance_valid(_camera):
		_resize_camera()
	if mode == "chat" and is_instance_valid(_chat_footer):
		_chat_draft.add_theme_font_size_override("normal_font_size", maxi(22, ceili(18 / physical)))
		_chat_draft.custom_minimum_size.y = 78 / physical
		_chat_send.custom_minimum_size = Vector2.ONE * maxf(48, 48 / physical)
		_chat_send.add_theme_font_size_override("font_size", maxi(22, ceili(18 / physical)))
	for card: Button in _mail_cards:
		if is_instance_valid(card):
			(card as AppViews.AppRow).refresh.call_deferred()
	for node: Node in _content.find_children("*", "Button", true, false):
		if node.has_meta("reply_icon"):
			(node as Button).custom_minimum_size = Vector2.ONE * 52 / physical
	for node: Node in _content.find_children("*", "Button", true, false):
		if node is AppViews.AppRow: node.refresh.call_deferred()

func _notification_opened(data: Dictionary) -> void:
	super._notification_opened(data)
	if mode == "read" and _app == "mail" and not Chapter.message(str(data.get("id", ""))).is_empty():
		_select(str(data.id))

func set_locked(value: bool) -> void:
	super.set_locked(value)
	if _feedback != null and _feedback.is_valid():
		if value: _feedback.pause()
		else: _feedback.play()

func _fit_shell() -> void:
	super._fit_shell()
	if not is_inside_tree() or not is_instance_valid(_shell): return
	if Chapter.get("FULL_WIDTH_INVESTIGATION") == true:
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		_shell.position.x = 8
		_shell.size.x = maxf(100, size.x - 16)
		_shell.size.y = maxf(100, size.y - (_close.custom_minimum_size.y + 22 / physical if _nav.visible else 12 / physical))
		var frame: StyleBoxEmpty = _shell.get_theme_stylebox("panel") as StyleBoxEmpty
		frame.content_margin_top = 20 / physical
		frame.content_margin_bottom = 12 / physical
		frame.content_margin_left = 22 / physical
		frame.content_margin_right = 22 / physical
		(_content.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		return
	if _app == "mail" and mode in ["sort", "highlight", "notes", "capture"]:
		# Open apps are a close-up of the phone, not a portrait phone shrunk
		# again when the task bar consumes vertical space on landscape screens.
		_shell.position.x = 8
		_shell.size.x = maxf(100, size.x - 16)
		if mode in ["notes", "capture"]: _shell.size.y = size.y - 10
		_shell.queue_redraw()

func _draw_frame() -> void:
	if Chapter.get("FULL_WIDTH_INVESTIGATION") != true:
		super._draw_frame()
		return
	if not is_instance_valid(_shell): return
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(_shell.size.x, _shell.size.x / 0.52))
	for layer: int in 6:
		_shell.draw_colored_polygon(_bezel(rect.grow(-layer * 4), 32 - layer * 3), PHONE_FRAME_COLORS[layer])
	var paper: Rect2 = rect.grow(-24)
	_wallpaper_clip = _bezel(paper, 14)
	_wallpaper_rect(paper, PHONE_PAPER)
	# Use actual container positions; a fixed header offset covered the first line.
	var header_bottom: float = _title.global_position.y - _shell.global_position.y + _title.size.y + 4
	var header_top: float = paper.position.y
	if _status.visible:
		header_top = _title.global_position.y - _shell.global_position.y - 4
		_wallpaper_rect(Rect2(paper.position, Vector2(paper.size.x, maxf(0, header_top - paper.position.y))), PHONE_STATUS)
	_wallpaper_rect(Rect2(Vector2(paper.position.x, header_top), Vector2(paper.size.x, maxf(0, header_bottom - header_top))), PHONE_HEADER)

func _activity_text(text: String) -> void:
	_content.add_child(UI.label(text, 24, INK))

func _activity_success(text: String) -> void:
	var panel: PanelContainer = UI.panel(_content, Color("dcefe2"))
	panel.add_theme_stylebox_override("panel", UI.box(Color("dcefe2"), Color("33D17A"), 14))
	panel.add_child(UI.label("✓ " + text, 24, INK))

func _resize_camera() -> void:
	if not is_instance_valid(_camera): return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var available: float = (_content.get_parent() as ScrollContainer).size.y
	_camera.custom_minimum_size.y = clampf(available * 0.95, 140 / physical, 210 / physical)
	_camera._layout_sheet()

func stop() -> void:
	_reply_stage = ""
	_reply_draft = null
	_reply_status = null
	_mail_arrivals = false
	_mail_cards.clear()
	_mail_scroll_pending = false
	_clipboard = ""
	_capture_serial += 1
	if is_instance_valid(_capture_view): _capture_view.queue_free()
	_capture_view = null
	if _feedback != null and _feedback.is_valid(): _feedback.kill()
	_feedback = null
	_shell.rotation = 0
	super.stop()

func _choices(first_text: String, first_action: Callable, second_text: String, second_action: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	var first: Button = _action(first_text, first_action)
	var second: Button = _action(second_text, second_action)
	for button: Button in [first, second]:
		button.reparent(row)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
