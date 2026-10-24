extends "res://src/gameplay/decision/advisor_phone.gd"
## Case-local manipulation; shared screen owns saves, chapter flow and rewards.
var _event_done: bool = false
var _picked_event: String = ""
var _picked_pin: String = ""
var _minutes: LineEdit
var _after: LineEdit
var _board: PinBoard
var _glitch: MemoryGlitch
var _glitch_elapsed: float = -1.0

class RecordCard extends Button:
	var record_id: String = ""
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled: return null
		var preview: Label = Label.new()
		preview.text = text
		set_drag_preview(preview)
		return {"prize_record":record_id}

class TimelineSlot extends Button:
	signal record_dropped(id: String, index: int)
	var slot_index: int = 0
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.get("prize_record", "") in ["survey","eric","jobert","prize"]
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if _can_drop_data(_at, data): record_dropped.emit(str(data.prize_record), slot_index)

class Pin extends Button:
	signal linked(source: String, target: String)
	signal drag_started(id: String)
	var pin_id: String = ""
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled: return null
		var preview: Label = Label.new()
		preview.text = "Connect evidence"
		set_drag_preview(preview)
		drag_started.emit(pin_id)
		return {"prize_pin":pin_id}
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.get("prize_pin", "") in ["coffee","group","typo","earlier","time","jobert","amount","eric"] and data.prize_pin != pin_id
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if _can_drop_data(_at, data): linked.emit(str(data.prize_pin), pin_id)

class PinBoard extends Control:
	var links: Array = []
	var pending: String = ""
	var dragging: bool = false
	func _process(_delta: float) -> void:
		if dragging and not get_viewport().gui_is_dragging():
			dragging = false
			pending = ""
			queue_redraw()
		if not pending.is_empty(): queue_redraw()
	func _center(id: String) -> Vector2:
		for node: Node in get_children():
			if node is Pin and node.pin_id == id: return (node as Control).get_rect().get_center()
		return Vector2.ZERO
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("eee2ce"))
		for x: int in range(10, int(size.x), 26):
			for y: int in range(10, int(size.y), 26): draw_circle(Vector2(x,y), 1, Color("b6a998", 0.3))
		for key: String in links:
			var ids: PackedStringArray = key.split("|")
			draw_line(_center(ids[0]), _center(ids[1]), Color("33D17A"), 4, true)
		if not pending.is_empty(): draw_line(_center(pending), get_local_mouse_position(), Color("4FE0D4"), 3, true)
	func fit() -> void:
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		var columns: int = 4 if size.x * physical >= 900 else 2
		var gap: float = 20 / physical
		var cell: Vector2 = Vector2((size.x - gap * (columns + 1)) / columns, 100 / physical)
		custom_minimum_size.y = (260 if columns == 4 else 500) / physical
		for index: int in get_child_count():
			var pin: Control = get_child(index) as Control
			pin.position = Vector2(gap + (index % columns) * (cell.x + gap), gap + (index / columns) * (cell.y + gap))
			pin.size = cell
		queue_redraw()

class MemoryGlitch extends Control:
	var elapsed: float = 0.0
	var gentle: bool = false
	func _draw() -> void:
		var progress: float = clampf(elapsed / 1.25, 0, 1)
		draw_rect(Rect2(Vector2.ZERO,size), Color(0,0,0,progress))
		if gentle: return
		for index: int in 7:
			var y: float = size.y * (0.10 + index * 0.12)
			var offset: float = sin(elapsed * 12 + index) * size.x * 0.025
			draw_rect(Rect2(offset, y, size.x, 3 + index % 3), Color("4FE0D4", 0.16 * (1.0 - progress)))

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/prize_chapter.gd")

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_event_done = false
	_picked_event = ""
	_picked_pin = ""
	stop()
	super.configure_chapter(next_mode, snapshot)
	if next_mode == "chat": _begin_chat_turn()
	if next_mode == "read" and _event() == "notification": AudioManager.play_sfx("ui_notification")

func _event() -> String:
	return str(Chapter.STORY[int(state.get("beat",0))].get("event", ""))

func _process(delta: float) -> void:
	super._process(delta)
	if _locked or not is_visible_in_tree() or _glitch_elapsed < 0: return
	_glitch_elapsed += delta
	if is_instance_valid(_glitch):
		_glitch.elapsed = _glitch_elapsed
		_glitch.queue_redraw()
	if _glitch_elapsed >= 1.25:
		_glitch_elapsed = -1.0
		state.claimed = true
		evidence_changed.emit(state.duplicate(true))
		phase_finished.emit()

func _build_chat() -> void:
	super._build_chat()
	_chat_status.text = "Delivered · No reply\nJobert is offline · Last seen 08:13:50" if _chat_stage == "done" else "Jobert is offline"

func _render() -> void:
	if not is_instance_valid(_content): return
	if mode == "chat" or _app == "home":
		super._render()
		return
	UI.clear(_content)
	if is_instance_valid(_chat_footer):
		_chat_footer.get_parent().remove_child(_chat_footer)
		_chat_footer.queue_free()
	_chat_footer = null
	_minutes = null
	_after = null
	_board = null
	match mode:
		"read": _story_email()
		"timeline": _timeline()
		"board": _pattern_board()
		"case_note": _case_note()
		"epilogue":
			_ink("STORY EPILOGUE / THAT SAME MORNING")
			_ink("John's scripted choice is not your answer. Your evidence is already saved.")
			_ink("You won ₱1,000,000\nClaim within 10 minutes.\nConfirm your account password.")
			_action("CLAIM PRIZE", _claim)
	if not _notice_text.is_empty() and not (mode == "board" and phase_ready()): _ink(_notice_text)
	_refresh()
	_metrics()
	view_changed.emit()

func _story_email() -> void:
	match _event():
		"notification":
			_ink("MAIL · PRIZE DESK\nYou won ₱1,000,000")
			_action("OPEN EMAIL", _complete_event)
		"coffee":
			_ink("CLUB CHAT / SAVED MESSAGE · CHAPTER 1")
			_ink("John: I miss coffee. I need a side gig before my wallet gives up.")
			_ink("Visible to everyone in the group.")
			_action("KEEP THIS RECORD", _complete_event)
		_:
			_ink("PRIZE DESK · 08:14:00\nawards@prize-claim.example")
			_ink(str(Chapter.MESSAGES[0].subject))
			_ink(str(Chapter.MESSAGES[0].body))
			_ink("[ CLAIM PRIZE ]")
			_action("ASK JOBERT FIRST", _complete_event)
	if _event_done: _ink("✓ Record kept / Continue")

func _complete_event() -> void:
	if _locked or _event_done: return
	_event_done = true
	_add("read", "prize")
	phase_finished.emit()

func _success(text: String, parent: Control = null) -> void:
	var panel: PanelContainer = UI.panel(_content if parent == null else parent, PHONE_PAPER.lerp(Color("33D17A"), 0.16))
	panel.add_theme_stylebox_override("panel", UI.box(PHONE_PAPER.lerp(Color("33D17A"), 0.16), Color("33D17A"), 14))
	_ink("✓ " + text, panel)

func _record(id: String) -> String:
	for entry: Dictionary in Chapter.TIMELINE:
		if entry.id == id: return str(entry.time) + " / " + str(entry.label)
	return "Empty slot"

func _timeline() -> void:
	_ink("Earliest → Latest / Drag records into slots, or select then tap a slot.")
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	_content.add_child(columns)
	var records: VBoxContainer = UI.column(columns, 10)
	var slots: VBoxContainer = UI.column(columns, 10)
	records.size_flags_horizontal = SIZE_EXPAND_FILL
	slots.size_flags_horizontal = SIZE_EXPAND_FILL
	for id: String in ["prize","eric","survey","jobert"]:
		var card: RecordCard = RecordCard.new()
		card.record_id = id
		card.name = "Record_" + id
		card.text = ("SELECTED / " if _picked_event == id else "") + _record(id)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_header_button(card)
		records.add_child(card)
		card.pressed.connect(func() -> void:
			if not _locked and not phase_ready():
				_picked_event = id
				_render())
	for index: int in 4:
		var slot: TimelineSlot = TimelineSlot.new()
		slot.slot_index = index
		slot.name = "TimelineSlot_%d" % index
		slot.text = "%02d / %s" % [index+1, _record(str(state.timeline_order[index]))]
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_header_button(slot)
		slots.add_child(slot)
		slot.record_dropped.connect(_place_record)
		slot.pressed.connect(func() -> void: _place_record(_picked_event,index))
	if phase_ready():
		_success("ORDER VERIFIED / Survey reply → email: 2 minutes.\nLast seen → email: Jobert 10 seconds; Eric 15 seconds. Timing does not identify the sender.")
		_action("CONTINUE TO PATTERN BOARD", _finish_phase)
	else: _action("CHECK TIMELINE", _check_timeline)

func _place_record(id: String, index: int) -> void:
	if _locked or mode != "timeline" or phase_ready() or id not in Chapter.ORDER or index < 0 or index >= 4: return
	var previous: int = state.timeline_order.find(id)
	var displaced: String = str(state.timeline_order[index])
	if previous >= 0: state.timeline_order[previous] = displaced
	state.timeline_order[index] = id
	_picked_event = ""
	_notice_text = ""
	evidence_changed.emit(state.duplicate(true))
	_render()

func _check_timeline() -> void:
	if _locked or mode != "timeline" or phase_ready(): return
	if state.timeline_order != Chapter.ORDER:
		_notice_text = "Check the seconds as well as the minutes. All four records must be in order."
		_render()
		return
	_add("timeline_checked", "prize")
	_notice_text = ""
	AudioManager.play_sfx("ui_confirm")
	_render()

func _pattern_board() -> void:
	_ink("✓ Three connections saved. Shared wording and timing do not prove authorship." if phase_ready() else "Connect the matching coffee reference, typo and ten-second gap.\nDrag between pins or tap two pins. Timing is not proof of guilt.")
	_board = PinBoard.new()
	_board.name = "PatternBoard"
	_board.links = state.connections.duplicate()
	_board.pending = _picked_pin
	_content.add_child(_board)
	_board.resized.connect(_board.fit)
	for id: String in ["coffee","earlier","amount","jobert","time","group","typo","eric"]:
		var entry: Dictionary = {}
		for candidate: Dictionary in Chapter.PINS:
			if candidate.id == id: entry = candidate
		var pin: Pin = Pin.new()
		pin.pin_id = str(entry.id)
		pin.name = "Pin_" + str(entry.id)
		pin.text = str(entry.text)
		pin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_header_button(pin)
		var connected: bool = false
		for key: String in state.connections:
			if pin.pin_id in key.split("|"): connected = true
		if connected:
			pin.text = "✓ " + pin.text
			for style: String in ["normal","hover","pressed"]: pin.add_theme_stylebox_override(style, UI.box(PHONE_PAPER.lerp(Color("33D17A"),0.2),Color("33D17A"),10))
		_board.add_child(pin)
		pin.linked.connect(_connect_pins)
		pin.drag_started.connect(func(id: String) -> void:
			_board.pending = id
			_board.dragging = true)
		pin.pressed.connect(_select_pin.bind(pin.pin_id))
	if phase_ready():
		_action("CONTINUE TO CASE NOTE", _finish_phase)

func _select_pin(id: String) -> void:
	if _locked or mode != "board" or phase_ready(): return
	if _picked_pin.is_empty():
		_picked_pin = id
		_board.pending = id
		_board.queue_redraw()
	elif id == _picked_pin:
		_picked_pin = ""
		_board.pending = ""
		_board.queue_redraw()
	else: _connect_pins(_picked_pin,id)

func _connect_pins(a: String, b: String) -> void:
	if _locked or mode != "board" or phase_ready() or a == b: return
	var ids: Array[String] = []
	for entry: Dictionary in Chapter.PINS: ids.append(str(entry.id))
	if a not in ids or b not in ids: return
	var key: String = Chapter.pair_key(a,b)
	_picked_pin = ""
	if Chapter.PAIRS.has(key):
		_add("connections", key)
		_notice_text = str(Chapter.PAIRS[key])
		AudioManager.play_sfx("ui_confirm")
	else:
		if not state.wrong_pairs.has(key):
			state.wrong_pairs.append(key)
			state.mistakes += 1
			evidence_changed.emit(state.duplicate(true))
		_notice_text = "That pair does not establish one of the three requested connections. One investigation mistake recorded for this pair; no coins deducted. Eric's last-seen gap is 15 seconds, not 10. Neither status proves authorship."
	_render()

func _field(value: String, placeholder: String, parent: Control = null) -> LineEdit:
	var input: LineEdit = LineEdit.new()
	input.text = value
	input.placeholder_text = placeholder
	input.accessibility_name = placeholder
	input.expand_to_text_length = false
	input.max_length = 100
	input.add_theme_color_override("font_color",INK)
	input.add_theme_color_override("font_uneditable_color",INK)
	input.add_theme_color_override("font_placeholder_color",Color("607477"))
	input.add_theme_stylebox_override("normal",UI.box(Color.WHITE,Color("8aa9a3"),12))
	(_content if parent == null else parent).add_child(input)
	return input

func _case_note() -> void:
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation",24)
	_content.add_child(columns)
	var reference: PanelContainer = UI.panel(columns,Color("e8efed"))
	reference.size_flags_horizontal = SIZE_EXPAND_FILL
	reference.size_flags_stretch_ratio = 0.8
	_ink("REFERENCE / THIS MORNING\n\n08:12:00\nSurvey confirmation reply\n\n08:13:45 · Eric last seen\n08:13:50 · Jobert last seen\n\n08:14:00\nPrize email received",reference)
	var form: VBoxContainer = UI.column(columns,14)
	form.size_flags_horizontal = SIZE_EXPAND_FILL
	_ink("The prize email arrived ___ minutes after ___.",form)
	_ink("How many minutes later?",form)
	_minutes = _field(str(state.minutes_draft),"Enter the number of minutes",form)
	_minutes.max_length = 32
	_ink("Count from 08:12 to 08:14. Type how many minutes passed, not the clock time.",form)
	_ink("What happened first?",form)
	_after = _field(str(state.event_draft),"Name the earlier event",form)
	_ink("Look for the survey reply in the reference on the left.",form)
	_minutes.text_changed.connect(_save_note)
	_after.text_changed.connect(_save_note)
	_after.text_submitted.connect(func(_value: String) -> void: _check_note())
	if phase_ready():
		for input: LineEdit in [_minutes,_after]:
			input.editable = false
			input.add_theme_stylebox_override("read_only", UI.box(PHONE_PAPER.lerp(Color("33D17A"),0.16),Color("33D17A"),12))
		_success("CASE NOTE SAVED\n2 minutes after the survey reply; 10 seconds after Jobert's last seen. Neither identifies the sender.",form)
		_action("CONTINUE TO EXHIBIT", _finish_phase).reparent(form)
	else: _action("SAVE CASE NOTE", _check_note).reparent(form)

func _save_note(_value: String) -> void:
	if _locked or not is_instance_valid(_minutes) or phase_ready(): return
	state.minutes_draft = _minutes.text
	state.event_draft = _after.text
	evidence_changed.emit(state.duplicate(true))

func _check_note() -> void:
	if _locked or mode != "case_note" or phase_ready(): return
	_save_note("")
	if not Chapter.note_matches(state.minutes_draft,state.event_draft):
		_notice_text = "Try this: 08:12 → 08:13 is 1 minute, then 08:13 → 08:14 is 1 more. Type 2 in the first box and survey confirmation reply in the second. Jobert's last-seen time is a different clue."
		_render()
		return
	_notice_text = ""
	_add("notes","prize")
	_add("captures","prize")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _claim() -> void:
	if _locked or mode != "epilogue" or not state.get("sealed", false) or _glitch_elapsed >= 0 or state.get("claimed", false): return
	story_art_changed.emit(Chapter.CLAIM_ASSET)
	_glitch = MemoryGlitch.new()
	_glitch.gentle = SettingsService.reduced_motion
	_glitch.mouse_filter = Control.MOUSE_FILTER_STOP
	_glitch.z_index = 100
	add_child(_glitch)
	_glitch.set_as_top_level(true)
	_glitch.position = Vector2.ZERO
	_glitch.size = get_viewport_rect().size
	_glitch_elapsed = 0.0
	AudioManager.play_sfx("ui_transition")

func _refresh() -> void:
	super._refresh()
	if state.is_empty(): return
	# The shared navigation button is the only exit from the completed chat.
	_nav.visible = mode == "chat" and phase_ready()
	_status.visible = mode in ["read","chat"]
	_status.text = "08:14  •  LTE  ▰"
	_title.visible = mode not in Chapter.TASKS or get_viewport_rect().size.y * get_viewport().get_final_transform().get_scale().y >= 500
	_title.text = {"read":"Mail / Prize Desk", "chat":"Jobert / Offline", "timeline":"Records / Timeline", "board":"Evidence / Pattern Board", "case_note":"Evidence / Case Note", "epilogue":"Prize Desk / Story Replay"}.get(mode,"Prize Desk")
	_title.add_theme_color_override("font_color",INK)
	if mode == "timeline" and phase_ready():
		for node: Node in _content.find_children("*","Button",true,false):
			if node is RecordCard or node is TimelineSlot:
				(node as Button).disabled = true
				if node is TimelineSlot: (node as Button).add_theme_stylebox_override("disabled",UI.box(PHONE_PAPER.lerp(Color("33D17A"),0.2),Color("33D17A"),10))

func _fit_shell() -> void:
	super._fit_shell()
	if not is_instance_valid(_shell) or mode not in Chapter.TASKS or _app != "mail": return
	var physical: float = maxf(0.25,get_viewport().get_final_transform().get_scale().y)
	var padding: float = (40.0 if _title.visible else 28.0) / physical
	var frame: StyleBoxEmpty = _shell.get_theme_stylebox("panel") as StyleBoxEmpty
	for edge: String in ["left","right","top","bottom"]: frame.set("content_margin_"+edge,padding)
	(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation",ceili(16/physical))
	var width: float = minf(size.x-16,1140/physical)
	_shell.position = Vector2((size.x-width)*0.5,0)
	_shell.size = Vector2(width,minf(size.y-8,_content.get_combined_minimum_size().y+padding*2+(_title.get_combined_minimum_size().y+16/physical if _title.visible else 0.0)))
	(_content.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_shell.queue_redraw()

func _metrics() -> void:
	super._metrics()
	if mode not in Chapter.TASKS: return
	var physical: float = maxf(0.25,get_viewport().get_final_transform().get_scale().y)
	_title.visible = get_viewport_rect().size.y*physical >= 500
	for node: Node in _content.find_children("*","Label",true,false): (node as Label).add_theme_font_size_override("font_size",ceili(18/physical))
	for node: Node in _content.find_children("*","Button",true,false):
		(node as Button).custom_minimum_size.y = (48 if mode == "timeline" else 56)/physical
		(node as Button).add_theme_font_size_override("font_size",ceili(16/physical))
	for node: Node in _content.find_children("*","LineEdit",true,false):
		(node as LineEdit).custom_minimum_size.y = 52/physical
		(node as LineEdit).add_theme_font_size_override("font_size",ceili(20/physical))
	if is_instance_valid(_board):
		_board.fit()

func phase_ready() -> bool:
	match mode:
		"read": return _event_done
		"chat": return _chat_stage == "done"
		"timeline": return state.get("timeline_checked",[]).has("prize")
		"board": return state.get("connections",[]).size() == 3
		"case_note": return state.get("notes",[]).has("prize")
		"epilogue": return state.get("claimed",false)
	return false

func set_locked(value: bool) -> void:
	super.set_locked(value)
	for input: LineEdit in [_minutes,_after]:
		if is_instance_valid(input): input.editable = not value and not phase_ready()
	if value and is_instance_valid(_board):
		_board.pending = ""
		_picked_pin = ""
		_board.queue_redraw()

func stop() -> void:
	_glitch_elapsed = -1.0
	if is_instance_valid(_glitch):
		remove_child(_glitch)
		_glitch.queue_free()
	_glitch = null
	super.stop()
