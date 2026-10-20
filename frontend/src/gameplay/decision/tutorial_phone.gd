extends "res://src/gameplay/decision/opening_phone.gd"
## Local-only tutorial apps. Reports intents/evidence; never saves or sends data.
signal practice_action(action: String)
signal evidence_changed(snapshot: Dictionary)
signal photo_taken(preview: Texture2D)
signal thought_requested(text: String, flags_complete: bool)

const INK: Color = Color("101623")
var mode: String = "read"
var evidence: Dictionary = {}
var _note: Label
var _domain_input: LineEdit
var _passage: RichTextLabel
var _camera: CaptureFrame
var _send_tween: Tween
var _sending: bool = false
var _envelope: SealArt
var _preview: Texture2D
var _continue: Button
var _taking: bool = false
var _capture_generation: int = 0
var _capture_viewport: SubViewport
var _camera_tools: Button
var _frame_controls: GridContainer
var _tools_open: bool = false
var _password_tween: Tween
var _password_started: bool = false
var _password_ready: bool = false
var _password_field: Button
var _password_submit: Button
var _keyboard: GridContainer
var _notepad_open: bool = false

func _ready() -> void:
	super._ready()
	_camera_tools = UI.button("TOOLS", _toggle_camera_tools)
	_camera_tools.name = "CameraTools"
	_nav.add_child(_camera_tools)
	_camera_tools.hide()

class CaptureFrame extends Control:
	signal framing_changed(value: Array[float])
	var frame: Rect2 = Rect2(0.15, 0.20, 0.65, 0.45)
	var locked: bool = false
	var _dragging: bool = false
	var _resizing: bool = false
	var _finger: int = -1
	var _origin: Vector2
	var _initial: Rect2
	var _sheet: Label
	const REQUIRED: Rect2 = Rect2(0.08, 0.08, 0.84, 0.82)
	func _ready() -> void:
		custom_minimum_size = Vector2(100, 350)
		mouse_filter = MOUSE_FILTER_STOP
		focus_mode = FOCUS_ALL
		accessibility_name = "Evidence frame. Drag to move; drag the lower-right corner to resize. Tap controls are below."
		_sheet = UI.label("FROM  Prize Desk\nawards@prize-claim.example\n\nYou won ₱1,000,000\n\nClaim within 10 minutes.\nConfirm your account password\nto release the prize.", 22, Color("101623"))
		_sheet.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_sheet)
		_sheet.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_sheet.offset_left = 20
		_sheet.offset_right = -20
		_sheet.offset_top = 20
		resized.connect(_layout_sheet)
		_layout_sheet()
	func _layout_sheet() -> void:
		_sheet.offset_left = size.x * 0.10
		_sheet.offset_right = -size.x * 0.10
		_sheet.offset_top = size.y * 0.10
		_sheet.offset_bottom = -size.y * 0.12
		_sheet.add_theme_font_size_override("font_size", maxi(12, int(minf(size.y / 12.0, size.x / 22.0))))
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("F3ECD6"))
	func _gui_input(event: InputEvent) -> void:
		if locked:
			return
		if event is InputEventScreenTouch:
			if event.pressed and _finger == -1:
				_finger = event.index
				_begin(event.position)
			elif not event.pressed and event.index == _finger:
				_finger = -1
				_dragging = false
			accept_event()
		elif event is InputEventScreenDrag and event.index == _finger:
			_move(event.position)
			accept_event()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _finger == -1:
			if event.pressed:
				_begin(event.position)
			else:
				_dragging = false
			accept_event()
		elif event is InputEventMouseMotion and _dragging and _finger == -1:
			_move(event.position)
			accept_event()
	func _begin(point: Vector2) -> void:
		var actual: Rect2 = Rect2(frame.position * size, frame.size * size)
		_resizing = point.distance_to(actual.end) <= 38.0
		_dragging = _resizing or actual.has_point(point)
		_origin = point
		_initial = frame
	func _move(point: Vector2) -> void:
		if not _dragging:
			return
		var delta: Vector2 = (point - _origin) / size
		frame = _initial
		if _resizing:
			frame.size += delta
		else:
			frame.position += delta
		_commit()
	func _commit() -> void:
		frame.size = frame.size.clamp(Vector2(0.25, 0.25), Vector2.ONE)
		frame.position = frame.position.clamp(Vector2.ZERO, Vector2.ONE - frame.size)
		frame.size = frame.size.min(Vector2.ONE - frame.position)
		var value: Array[float] = [frame.position.x, frame.position.y, frame.size.x, frame.size.y]
		framing_changed.emit(value)
		queue_redraw()
	func nudge(delta: Vector2) -> void:
		if not locked:
			frame.position += delta
			_commit()
	func grow_frame(delta: Vector2) -> void:
		if not locked:
			frame.size += delta
			_commit()
	func complete() -> bool:
		return frame.grow(0.002).encloses(REQUIRED)
	func cancel_drag() -> void:
		_dragging = false
		_finger = -1

class FrameInk extends Control:
	var camera: CaptureFrame
	func _draw() -> void:
		if camera == null:
			return
		var box: Rect2 = Rect2(camera.frame.position * size, camera.frame.size * size)
		draw_rect(box, Color("4FE0D4"), false, 3)
		draw_rect(Rect2(box.end - Vector2(16, 16), Vector2(32, 32)), Color("2E6BFF"))

class SealArt extends Control:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()
	func _ready() -> void:
		custom_minimum_size.y = 140
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center: Vector2 = size * Vector2(0.5, 0.65)
		var letter: Rect2 = Rect2(center + Vector2(-45, -90 + progress * 70), Vector2(90, 65))
		draw_rect(letter, Color("F3ECD6"))
		draw_rect(letter, Color("173058"), false, 2)
		for line: int in 3:
			draw_line(letter.position + Vector2(12, 16 + line * 12), letter.position + Vector2(75, 16 + line * 12), Color("173058"), 2)
		var envelope: Rect2 = Rect2(center - Vector2(75, 15), Vector2(150, 60))
		draw_rect(envelope, Color("173058"))
		draw_polyline(PackedVector2Array([envelope.position, center + Vector2(0, 22), Vector2(envelope.end.x, envelope.position.y)]), Color("4FE0D4"), 3)
		if progress >= 0.99:
			draw_circle(center + Vector2(0, 22), 16, Color("33D17A"))
			draw_polyline(PackedVector2Array([center + Vector2(-8, 22), center + Vector2(-2, 28), center + Vector2(9, 14)]), Color("101623"), 3)

func configure_practice(next_mode: String, snapshot: Dictionary, preview: Texture2D = null) -> void:
	mode = next_mode
	evidence = snapshot.duplicate(true)
	_preview = preview
	configure({"embedded": true, "claim_enabled": false, "device_name": "John's phone"})

func _build_password_page() -> void:
	_heading("Claim your prize", "Account password")
	_password_field = UI.button("Tap to type password", _type_password)
	_password_field.name = "SimulatedPasswordField"
	_content.add_child(_password_field)
	_keyboard = GridContainer.new()
	_keyboard.name = "SimulatedKeyboard"
	_keyboard.columns = 10
	_keyboard.add_theme_constant_override("h_separation", 3)
	_keyboard.add_theme_constant_override("v_separation", 3)
	_content.add_child(_keyboard)
	for key: String in "QWERTYUIOPASDFGHJKLZXCVBNM1234567".split(""):
		var tile: PanelContainer = UI.panel(_keyboard)
		tile.size_flags_horizontal = SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", UI.box(Color("173058"), Color("4FE0D4"), 3))
		var letter: Label = UI.label(key, 18, Color("F3ECD6"))
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(letter)
	_keyboard.hide()
	_password_submit = _action_button("SUBMIT", "failure")
	_password_submit.hide()

func _type_password() -> void:
	if _locked or _password_started or mode != "claim":
		return
	_password_started = true
	_password_field.disabled = true
	_keyboard.show()
	(_content.get_parent() as ScrollContainer).ensure_control_visible(_keyboard)
	_password_tween = create_tween()
	for index: int in 8:
		_password_tween.tween_callback(_password_keystroke.bind(index))
		_password_tween.tween_interval(0.16 if not _reduced_motion() else 0.05)
	_password_tween.tween_callback(func() -> void:
		_password_ready = true
		_keyboard.hide()
		_password_submit.show()
		_refresh()
		(_content.get_parent() as ScrollContainer).ensure_control_visible(_password_submit)
	)

func _password_keystroke(index: int) -> void:
	_password_field.text = "•".repeat(index + 1)
	for key: Node in _keyboard.get_children():
		(key as Control).modulate = Color.WHITE
	if not _reduced_motion():
		(_keyboard.get_child((index * 7 + 2) % _keyboard.get_child_count()) as Control).modulate = Color("FFB648")

func _render_apps() -> void:
	super._render_apps()
	if mode == "notes":
		var note: Button = UI.button("NOTEPAD", _open_notepad, true)
		note.name = "NotepadApp"
		_content.add_child(note)
		_content.move_child(note, 0)

func show_notes_home() -> void:
	_alarm_pending = false
	_stop_pin()
	_unlocked = true
	_read = true
	_app = "home"
	_notepad_open = false
	_render()
	_zoom_app(0.0)

func _story_icon(parent: Control, app_id: int, color: Color, mail: bool) -> void:
	super._story_icon(parent, app_id, color, mail)
	if mode == "notes" and app_id == 5:
		var tile: Button = parent.get_child(parent.get_child_count() - 1) as Button
		tile.name = "NotepadIcon"
		tile.accessibility_name = "Open Notepad"
		tile.focus_mode = FOCUS_ALL
		tile.mouse_filter = MOUSE_FILTER_STOP
		tile.pressed.connect(_open_notepad)

func _open_notepad() -> void:
	if _locked or mode != "notes" or not bool(evidence.get("sender_opened", false)):
		return
	_notepad_open = true
	_reading = true
	_app = "mail" # Reuse the enlarged app viewport, not the email content.
	_render()
	_zoom_app(1.0)

func _open_story_email() -> void:
	if _locked:
		return
	_notepad_open = false
	super._open_story_email()

func _render_message() -> void:
	_camera = null
	_domain_input = null
	_continue = null
	match mode:
		"read":
			super._render_message()
		"claim":
			_build_password_page()
		"inspect": _build_inspection()
		"sender", "notes":
			if _notepad_open: _build_notepad()
			else: _build_sender()
		"capture": _build_capture()
		"submit": _build_submission()
		"deleted":
			_heading("Inbox clear", "The prize request is deleted. No link followed. No password shared.")
			_action_button("INVESTIGATE A PRACTICE COPY", "inspect")
			_action_button("LEAVE FOR NOW", "leave")
	_note = UI.label("", 22, INK)
	_note.name = "PracticeFeedback"
	_content.add_child(_note)
	if mode in ["inspect", "capture"]:
		_content.move_child(_note, mini(2, _content.get_child_count() - 1))
	_content.add_theme_constant_override("separation", 6 if mode == "choice" else 14)

func _heading(title: String, subtitle: String) -> void:
	_content.add_child(UI.label(title, 28, INK))
	_content.add_child(UI.label(subtitle, 22, Color("544650")))

func _action_button(caption: String, action: String) -> Button:
	var button: Button = UI.button(caption, func() -> void: _request_action(action), true)
	button.name = action.to_pascal_case() + "Action"
	_content.add_child(button)
	return button

func _request_action(action: String) -> void:
	if not _locked and not _sending and is_visible_in_tree():
		if action == "failure" and not _password_ready:
			return
		if action == "notes" and mode == "notes":
			show_notes_home()
			return
		practice_action.emit(action)

func _build_inspection() -> void:
	_content.add_child(UI.label("You won ₱1,000,000", 28, INK))
	_passage = RichTextLabel.new()
	_passage.name = "FlagPassage"
	_passage.bbcode_enabled = true
	_passage.fit_content = true
	_passage.scroll_active = false
	_passage.selection_enabled = false
	_passage.add_theme_font_override("normal_font", UI.FONT)
	_passage.add_theme_font_size_override("normal_font_size", 24)
	_passage.add_theme_color_override("default_color", INK)
	_passage.add_theme_constant_override("line_separation", 8)
	_passage.meta_clicked.connect(func(value: Variant) -> void: mark_flag(str(value)))
	_content.add_child(_passage)
	_refresh_passage()
	_content.add_child(UI.button("NEED A HINT?", _hint))
	if flags_complete():
		_action_button("REVIEW FINDINGS", "flags_done")

func flags_complete() -> bool:
	var flags: Array = evidence.get("flags", [])
	return flags.has("reward") and flags.has("pressure") and flags.has("password")

func _build_sender() -> void:
	super._render_message()
	var sender: Button = UI.button("FROM · Prize Desk  ▾", _show_practice_sender)
	sender.name = "InspectSender"
	_content.add_child(sender)
	if bool(evidence.get("sender_opened", false)):
		_content.add_child(UI.label("awards@prize-claim.example", 22, INK))
		_action_button("OPEN NOTEPAD", "notes")

func _build_notepad() -> void:
	_heading("Sender notes", "Copy the domain you saw after @.")
	_domain_input = LineEdit.new()
	_domain_input.name = "DomainNote"
	_domain_input.placeholder_text = "Domain only — never a password"
	_domain_input.max_length = 64
	_domain_input.custom_minimum_size.y = 52
	_domain_input.text = str(evidence.get("domain", ""))
	_domain_input.add_theme_font_override("font", UI.FONT)
	_domain_input.add_theme_font_size_override("font_size", 24)
	_domain_input.text_submitted.connect(func(_value: String) -> void: check_domain())
	_content.add_child(_domain_input)
	var save: Button = UI.button("SAVE DOMAIN NOTE", check_domain, true)
	save.name = "SaveDomainNote"
	_content.add_child(save)
	var hint: Button = UI.button("NEED A HINT?", _hint)
	_content.add_child(hint)
	_continue = _action_button("NEXT / CAPTURE EVIDENCE", "capture")

func _refresh_passage() -> void:
	var phrases: Array[String] = ["Congratulations!", "Your address was selected for ₱1,000,000.", "Claim within 10 minutes.", "Follow the link and confirm your account password to release the prize."]
	var ids: Array[String] = ["greeting", "reward", "pressure", "password"]
	var flags: Array = evidence.get("flags", [])
	var pieces: PackedStringArray = []
	for index: int in phrases.size():
		var phrase: String = phrases[index]
		if flags.has(ids[index]):
			phrase = "[bgcolor=#FFB648][color=#101623]" + phrase + "[/color][/bgcolor]"
		pieces.append("[url=" + ids[index] + "]" + phrase + "[/url]")
	_passage.text = "\n\n".join(pieces)

func mark_flag(id: String) -> void:
	if _locked or mode != "inspect" or _app != "mail":
		return
	var explanations: Dictionary[String, String] = {
		"reward": "I never entered this selection. The reward needs checking independently.",
		"pressure": "The deadline rushes me. Urgency alone is not proof, but it discourages checking.",
		"password": "A prize does not need my account password. That request puts my account at risk."
	}
	if not explanations.has(id):
		thought_requested.emit("A friendly greeting is not evidence by itself. What is this message asking me to do?", false)
		return
	var flags: Array = evidence.get("flags", [])
	if not flags.has(id):
		flags.append(id)
	evidence["flags"] = flags
	_refresh_passage()
	_changed()
	thought_requested.emit(explanations[id], flags_complete())
	AudioManager.play_sfx("ui_confirm")

func _show_practice_sender() -> void:
	if _locked or mode not in ["sender", "notes"]:
		return
	evidence["sender_opened"] = true
	_changed()
	_render()
	thought_requested.emit("Prize Desk is only a display name. I need the full address. The domain is the part after @; I'll record it in Notepad.", false)

func check_domain() -> void:
	if _locked or mode != "notes" or not _notepad_open or not is_instance_valid(_domain_input):
		return
	var answer: String = _domain_input.text.strip_edges().to_lower()
	if not bool(evidence.get("sender_opened", false)):
		thought_requested.emit("I need to open FROM in Mail first.", false)
	elif answer != "prize-claim.example":
		thought_requested.emit("That doesn't match the sender's domain. I can return to Mail and check the part after @.", false)
	else:
		evidence["domain"] = answer
		_changed()
		thought_requested.emit("Domain saved. An address is a clue—not proof of who sent the offer. Next, I'll keep a screenshot with its context.", false)
		AudioManager.play_sfx("ui_confirm")

func _hint() -> void:
	if not _locked:
		evidence["hint_used"] = true
		_changed()
		thought_requested.emit("The domain is the part after @. Close Notepad and reopen Mail if you need another look." if mode == "notes" else "Look for an unexpected reward, a rushed deadline, and a request for a secret.", false)

func ready_for_capture() -> bool:
	var flags: Array = evidence.get("flags", [])
	return flags.has("reward") and flags.has("pressure") and flags.has("password") and str(evidence.get("domain", "")) == "prize-claim.example" and bool(evidence.get("sender_opened", false))

func _build_capture() -> void:
	_tools_open = false
	_camera = CaptureFrame.new()
	_camera.name = "EvidenceCamera"
	_content.add_child(_camera)
	var crop: Array = evidence.get("frame", [])
	if crop.size() == 4 and crop.all(func(value: Variant) -> bool: return (value is float or value is int) and is_finite(float(value))):
		_camera.frame = Rect2(float(crop[0]), float(crop[1]), float(crop[2]), float(crop[3]))
		_camera._commit()
	var ink: FrameInk = FrameInk.new()
	ink.name = "FrameOverlay"
	ink.camera = _camera
	ink.mouse_filter = MOUSE_FILTER_IGNORE
	_camera.add_child(ink)
	ink.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_camera.framing_changed.connect(func(value: Array[float]) -> void:
		if evidence.get("frame", []) != value:
			evidence.erase("captured")
			evidence.erase("sealed")
		evidence["frame"] = value
		ink.queue_redraw()
		_changed()
	)
	var grid: GridContainer = GridContainer.new()
	_frame_controls = grid
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for caption: String in ["← LEFT", "RIGHT →", "↑ UP", "DOWN ↓", "WIDER +", "NARROWER −", "TALLER +", "SHORTER −"]:
		var button: Button = UI.button(caption, _adjust_frame.bind(caption))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(button)
	var hint: Button = UI.button("HELP FRAME ALL DETAILS", _frame_hint)
	_content.add_child(hint)
	var take: Button = UI.button("CAPTURE", take_photo, true)
	take.name = "CaptureEvidence"
	_content.add_child(take)

func _toggle_camera_tools() -> void:
	if _locked or _app != "mail" or mode != "capture":
		return
	_tools_open = not _tools_open
	var scroll: ScrollContainer = _content.get_parent()
	scroll.ensure_control_visible(_frame_controls if _tools_open else _camera)
	_camera_tools.text = "FRAME" if _tools_open else "TOOLS"

func _adjust_frame(caption: String) -> void:
	if _locked or not is_instance_valid(_camera):
		return
	match caption:
		"← LEFT": _camera.nudge(Vector2(-0.05, 0))
		"RIGHT →": _camera.nudge(Vector2(0.05, 0))
		"↑ UP": _camera.nudge(Vector2(0, -0.05))
		"DOWN ↓": _camera.nudge(Vector2(0, 0.05))
		"WIDER +": _camera.grow_frame(Vector2(0.05, 0))
		"NARROWER −": _camera.grow_frame(Vector2(-0.05, 0))
		"TALLER +": _camera.grow_frame(Vector2(0, 0.05))
		"SHORTER −": _camera.grow_frame(Vector2(0, -0.05))

func _frame_hint() -> void:
	if _locked or not is_instance_valid(_camera):
		return
	evidence["hint_used"] = true
	_camera.frame = Rect2(0.02, 0.02, 0.96, 0.96)
	_camera._commit()
	_note.text = "Sender, subject and request are inside the frame. Capture when ready."

func take_photo() -> void:
	if _locked or _taking or mode != "capture" or not ready_for_capture() or not is_instance_valid(_camera):
		return
	if not _camera.complete():
		_note.text = "Some context is outside the frame. Include the sender at the top and the password request below."
		(_content.get_parent() as ScrollContainer).ensure_control_visible(_note)
		AudioManager.play_sfx("ui_error")
		return
	# Capture only the simulated evidence sheet, never the rest of the screen.
	# Serialized progress stores source/crop metadata; no screenshots leave the app.
	_taking = true
	var generation: int = _capture_generation
	evidence["frame"] = [_camera.frame.position.x, _camera.frame.position.y, _camera.frame.size.x, _camera.frame.size.y]
	if DisplayServer.get_name() != "headless":
		# Render the immutable message separately: scrolling the phone must never
		# capture the room, controls, or other content outside its viewport.
		_capture_viewport = SubViewport.new()
		_capture_viewport.size = Vector2i(480, 350)
		_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_viewport)
		var sheet: CaptureFrame = CaptureFrame.new()
		sheet.locked = true
		_capture_viewport.add_child(sheet)
		sheet.size = Vector2(480, 350)
		await RenderingServer.frame_post_draw
		if generation != _capture_generation or not is_instance_valid(_capture_viewport):
			return
		var image: Image = _capture_viewport.get_texture().get_image()
		var region: Rect2i = Rect2i(Rect2(_camera.frame.position * Vector2(480, 350), _camera.frame.size * Vector2(480, 350)))
		if region.has_area():
			_preview = ImageTexture.create_from_image(image.get_region(region))
		_capture_viewport.queue_free()
		_capture_viewport = null
	_taking = false
	if _locked or not is_inside_tree():
		return
	evidence["captured"] = true
	photo_taken.emit(_preview)
	_changed()
	AudioManager.play_sfx("ui_confirm")
	practice_action.emit("submit")

func _build_submission() -> void:
	_heading("Practice Evidence Desk", "Local simulation only. Nothing is sent to a teacher or outside the game.")
	if _preview != null:
		var photo: TextureRect = TextureRect.new()
		photo.texture = _preview
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size.y = 160
		_content.add_child(photo)
	else:
		# Reconstruct the saved exhibit from its immutable source after a reload.
		_content.add_child(UI.label("SAVED CAPTURE\nPrize Desk · awards@prize-claim.example\nYou won ₱1,000,000\nClaim within 10 minutes; confirm your account password.", 22, INK))
	_content.add_child(UI.label("ATTACHMENTS\n✓ Message capture\n✓ Sender domain: " + str(evidence.get("domain", "")) + "\n✓ Unexpected reward · urgency · password request", 22, INK))
	_envelope = SealArt.new()
	_envelope.name = "EvidenceEnvelope"
	_content.add_child(_envelope)
	var send: Button = UI.button("SEND EVIDENCE", send_evidence, true)
	send.name = "SendEvidence"
	_content.add_child(send)

func send_evidence() -> void:
	if _locked or _sending or mode != "submit" or not bool(evidence.get("captured", false)) or not ready_for_capture():
		return
	_sending = true
	_refresh()
	_note.text = "Packaging the practice exhibit…"
	(_content.get_parent() as ScrollContainer).ensure_control_visible(_envelope)
	_send_tween = create_tween()
	if not _reduced_motion():
		_send_tween.tween_property(_envelope, "progress", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		_envelope.progress = 1.0
		_send_tween.tween_interval(0.4)
	_send_tween.tween_interval(0.4)
	_send_tween.tween_callback(func() -> void:
		_sending = false
		evidence["sealed"] = true
		_changed()
		practice_action.emit("sealed")
	)

func _changed() -> void:
	evidence_changed.emit(evidence.duplicate(true))
	if is_instance_valid(_continue):
		_continue.disabled = _locked or not ready_for_capture()

func _refresh() -> void:
	super._refresh()
	if is_instance_valid(_camera_tools):
		_camera_tools.visible = mode == "capture" and _app == "mail"
		_camera_tools.disabled = _locked
	if _notepad_open and _app == "mail":
		_title.text = "Notepad"
	if mode == "claim":
		_close.hide()
		if is_instance_valid(_password_field):
			_password_field.disabled = _locked or _password_started
		if is_instance_valid(_password_submit):
			_password_submit.disabled = _locked or not _password_ready
	if is_instance_valid(_continue):
		_continue.disabled = _locked or not ready_for_capture()
	if _sending:
		for node: Node in _content.find_children("*", "Button", true, false):
			(node as Button).disabled = true
		_close.disabled = true
	if is_instance_valid(_domain_input):
		_domain_input.editable = not _locked
	if is_instance_valid(_camera):
		_camera.locked = _locked
		if _locked:
			_camera.cancel_drag()

func _metrics() -> void:
	super._metrics()
	if not is_inside_tree():
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	if is_instance_valid(_passage):
		_passage.add_theme_font_size_override("normal_font_size", maxi(24, ceili(20.0 / physical)))
	if is_instance_valid(_domain_input):
		_domain_input.add_theme_font_size_override("font_size", maxi(24, ceili(18.0 / physical)))
		_domain_input.expand_to_text_length = false
	if is_instance_valid(_camera):
		var available: float = (_content.get_parent() as ScrollContainer).size.y
		_camera.custom_minimum_size.y = maxf(180, available * 0.96)
		_camera._layout_sheet()

func _fit_shell() -> void:
	super._fit_shell()
	if is_instance_valid(_camera_tools) and _camera_tools.visible:
		_camera_tools.custom_minimum_size = Vector2(140, _close.custom_minimum_size.y)
		_nav.size.x = maxf(_shell.size.x - 24, _nav.get_combined_minimum_size().x)
		_nav.position.x = (size.x - _nav.size.x) * 0.5
		_close.size_flags_horizontal = SIZE_EXPAND_FILL
		_camera_tools.size_flags_horizontal = SIZE_EXPAND_FILL

func set_locked(value: bool) -> void:
	super.set_locked(value)
	if _password_tween != null and _password_tween.is_valid():
		if value: _password_tween.pause()
		else: _password_tween.play()
	if _send_tween != null and _send_tween.is_valid():
		if value: _send_tween.pause()
		else: _send_tween.play()

func _close_app() -> void:
	if not _sending and mode != "claim":
		_notepad_open = false
		super._close_app()

func stop() -> void:
	if _password_tween != null and _password_tween.is_valid():
		_password_tween.kill()
	_password_tween = null
	_capture_generation += 1
	_taking = false
	if is_instance_valid(_capture_viewport):
		_capture_viewport.queue_free()
	_capture_viewport = null
	if _send_tween != null and _send_tween.is_valid():
		_send_tween.kill()
	_send_tween = null
	_sending = false
	super.stop()
