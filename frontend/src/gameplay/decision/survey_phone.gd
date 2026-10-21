extends "res://src/gameplay/decision/opening_phone.gd"
## Chapter apps own local interaction only; the chapter screen owns persistence.
signal evidence_changed(snapshot: Dictionary)
signal thought_requested(text: String)
signal phase_finished
const Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Practice: GDScript = preload("res://src/gameplay/decision/tutorial_phone.gd")
const INK: Color = Color("101623")
var state: Dictionary = {}
var mode: String = "chat"
var selected: String = ""
var note_app: bool = false
var _domain: LineEdit
var _camera: Practice.CaptureFrame
var _capture_view: SubViewport
var _capture_serial: int = 0
var _taking: bool = false
var _feedback: Tween
var _previews: Dictionary = {}

class MessageCard extends Button:
	var message_id: String = ""
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled:
			return null
		var preview: Label = UI.label(text, 22, Color("101623"))
		set_drag_preview(preview)
		return {"survey_card":message_id}

class SortBin extends Button:
	signal card_dropped(id: String)
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.has("survey_card")
	func _drop_data(_at: Vector2, data: Variant) -> void:
		card_dropped.emit(str(data["survey_card"]))

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_capture_serial += 1
	_taking = false
	if is_instance_valid(_capture_view):
		_capture_view.queue_free()
		_capture_view = null
	mode = next_mode
	state = snapshot.duplicate(true)
	selected = ""
	note_app = false
	configure({"embedded":true})
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
	_domain = null
	UI.clear(_content)
	_content.size_flags_vertical = SIZE_EXPAND_FILL if _app == "home" else SIZE_FILL
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	if _app == "home":
		_render_story_home()
	elif mode == "chat":
		_content.add_child(UI.label(Chapter.CHAT, 24, INK))
	elif note_app:
		_build_notes()
	elif selected.is_empty():
		_build_inbox()
	else:
		_build_message()
	_refresh()
	_metrics()

func _render_apps() -> void:
	super._render_apps()
	if mode == "notes":
		var notebook: Button = _action("▤ OPEN NOTEPAD", _open_notes)
		_content.move_child(notebook, 0)

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
	button.add_theme_color_override("font_color", INK)
	button.custom_minimum_size.x = 0
	_content.add_child(button)
	return button

func _build_inbox() -> void:
	var ids: Array = Chapter.suspicious_ids() if mode in ["highlight", "notes", "capture"] else []
	for entry: Dictionary in Chapter.MESSAGES:
		var id: String = str(entry["id"])
		if not ids.is_empty() and not ids.has(id):
			continue
		var field: String = {"read":"read", "sort":"sorted", "highlight":"flags", "notes":"domains", "capture":"captures"}.get(mode, "read")
		var done: bool = (state.get(field, []) as Array).has(id)
		var caption: String = ("✓ " if done else "") + str(entry["sender"]) + "\n" + str(entry["subject"])
		var card: Button = _action(caption, _select.bind(id))
		card.name = "Message_" + id
	if phase_ready():
		_action("CONTINUE →", _finish_phase)

func _select(id: String) -> void:
	if _locked or _taking or Chapter.message(id).is_empty():
		return
	selected = id
	_render()

func _build_message() -> void:
	var entry: Dictionary = Chapter.message(selected)
	_content.add_child(UI.label(str(entry["subject"]), 28, INK))
	_content.add_child(UI.label("From: " + str(entry["sender"]) + "\n" + str(entry["address"]), 22, INK))
	if mode == "capture":
		_build_camera(entry)
		return
	_content.add_child(UI.label(str(entry["body"]), 24, INK))
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
			_content.add_child(passage)
			_action("MARK THIS REQUEST", mark_flag)
		else:
			_content.add_child(UI.label(str(entry["phrase"]), 24, INK))
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
		"notes":
			_action("OPEN NOTEPAD", _notes_home)
	_action("← INBOX", _inbox)

func acknowledge() -> void:
	if _locked or mode != "read" or selected.is_empty():
		return
	var entry: Dictionary = Chapter.message(selected)
	_add("read", selected)
	thought_requested.emit("I replied with the requested details. At the time, it felt like another step toward getting paid." if bool(entry["suspicious"]) else "This matches something I already arranged. No unexpected action is being demanded.")
	_inbox()

func sort_message(id: String, suspicious: bool) -> void:
	if _locked or mode != "sort" or Chapter.message(id).is_empty() or state["sorted"].has(id):
		return
	if bool(Chapter.message(id)["suspicious"]) != suspicious:
		state["mistakes"] = int(state["mistakes"]) + 1
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

func mark_flag() -> void:
	if _locked or mode != "highlight" or selected not in Chapter.suspicious_ids():
		return
	_add("flags", selected)
	thought_requested.emit(str(Chapter.message(selected)["thought"]))
	_render()

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
		_action("OPEN MAIL", _open_mail)
		return
	_content.add_child(UI.label("Sender note / " + str(Chapter.message(selected)["sender"]), 26, INK))
	_content.add_child(UI.label("Copy the email domain (the part after @).", 22, INK))
	_domain = LineEdit.new()
	_domain.placeholder_text = "domain only"
	_domain.max_length = 80
	_domain.custom_minimum_size = Vector2(0, 54)
	_domain.add_theme_font_override("font", UI.FONT)
	_domain.add_theme_font_size_override("font_size", 24)
	_domain.text_submitted.connect(func(_text: String) -> void: check_domain())
	_content.add_child(_domain)
	_action("SAVE NOTE", check_domain)
	_action("CHECK MAIL AGAIN", _open_mail)

func check_domain() -> void:
	if _locked or mode != "notes" or not note_app or not is_instance_valid(_domain):
		return
	if not Chapter.domain_matches(_domain.text, selected):
		thought_requested.emit("Copy only the part after @. Check the spelling in Mail; a similar domain is not the same address.")
		return
	_add("domains", selected)
	thought_requested.emit("A free mailbox doesn't prove a scam. But these senders don't establish who the client is, especially alongside the unusual requests.")
	note_app = false
	_inbox()

func _build_camera(entry: Dictionary) -> void:
	_camera = Practice.CaptureFrame.new()
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
	_action("CAPTURE", take_photo)
	_action("← INBOX", _inbox)

func take_photo() -> void:
	if _locked or _taking or mode != "capture" or not is_instance_valid(_camera):
		return
	if not _camera.complete():
		thought_requested.emit("Keep the sender, subject and complete request inside the frame. Drag the blue corner to resize, or use the buttons below.")
		return
	_taking = true
	var serial: int = _capture_serial
	var id: String = selected
	if DisplayServer.get_name() != "headless":
		_capture_view = SubViewport.new()
		_capture_view.size = Vector2i(480,350)
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		var sheet: Practice.CaptureFrame = Practice.CaptureFrame.new()
		sheet.sheet_text = _camera.sheet_text
		sheet.locked = true
		_capture_view.add_child(sheet)
		sheet.size = Vector2(480,350)
		await RenderingServer.frame_post_draw
		if serial != _capture_serial or not is_instance_valid(_capture_view):
			return
		var preview: Image = _capture_view.get_texture().get_image()
		_capture_view.queue_free()
		_capture_view = null
		if preview == null or preview.is_empty():
			_taking = false
			return
		_previews[id] = ImageTexture.create_from_image(preview)
	_taking = false
	if _locked or not is_inside_tree() or id != selected:
		return
	_add("captures", id)
	AudioManager.play_sfx("ui_confirm")
	thought_requested.emit("Capture saved to the exhibit: sender, subject and request together.")
	_inbox()

func _add(field: String, id: String) -> void:
	if not state[field].has(id):
		state[field].append(id)
		evidence_changed.emit(state.duplicate(true))

func phase_ready() -> bool:
	var field: String = {"read":"read", "sort":"sorted", "highlight":"flags", "notes":"domains", "capture":"captures"}.get(mode, "")
	return not field.is_empty() and (state.get(field, []) as Array).size() == (6 if mode in ["read", "sort"] else 3)

func _finish_phase() -> void:
	if not _locked and phase_ready():
		phase_finished.emit()

func _inbox() -> void:
	if _locked:
		return
	selected = ""
	_render()

func _close_app() -> void:
	if _locked or _taking:
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
	_close.text = "× CLOSE" if _app == "mail" else ("OPEN CHAT" if mode == "chat" else "OPEN MAIL")
	for node: Node in _content.find_children("*", "Button", true, false):
		(node as Button).disabled = _locked or _taking
	if is_instance_valid(_camera):
		_camera.locked = _locked or _taking
		if _locked: _camera.cancel_drag()
	if is_instance_valid(_domain): _domain.editable = not _locked

func _metrics() -> void:
	super._metrics()
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	for node: Node in _content.find_children("*", "RichTextLabel", true, false):
		(node as RichTextLabel).add_theme_font_size_override("normal_font_size", maxi(24, ceili(20 / physical)))
	if is_instance_valid(_domain):
		_domain.add_theme_font_size_override("font_size", maxi(24, ceili(20 / physical)))
		_domain.custom_minimum_size.y = maxf(54, 48 / physical)

func set_locked(value: bool) -> void:
	super.set_locked(value)
	if _feedback != null and _feedback.is_valid():
		if value: _feedback.pause()
		else: _feedback.play()

func stop() -> void:
	_capture_serial += 1
	if is_instance_valid(_capture_view): _capture_view.queue_free()
	_capture_view = null
	if _feedback != null and _feedback.is_valid(): _feedback.kill()
	_feedback = null
	_shell.rotation = 0
	super.stop()
