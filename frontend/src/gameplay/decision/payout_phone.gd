extends "res://src/gameplay/decision/advisor_phone.gd"
## Reuses the cream phone shell and chat clock. All destinations are inert text.
var _hold_timer: Timer
var _link_revealed: bool = false
var _short_selected: bool = false
var _event_done: bool = false
var _event_clock: float = 0.0
var _ringing: bool = false
var _username: Label
var _selected_clue: String = ""
var _chat_contact: String = "Jobert"

class ShortLink extends Button:
	func _get_drag_data(_at: Vector2) -> Variant:
		if disabled: return null
		var preview: Label = Label.new()
		preview.text = text
		set_drag_preview(preview)
		return {"payout_link":"payout"}

class Expander extends Button:
	signal link_dropped
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and data.get("payout_link", "") == "payout"
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if _can_drop_data(_at, data): link_dropped.emit()

func _init() -> void:
	Chapter = preload("res://src/gameplay/decision/payout_chapter.gd")

func _ready() -> void:
	super._ready()
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = 0.65
	add_child(_hold_timer)
	_hold_timer.timeout.connect(_reveal_destination)
	visibility_changed.connect(_cancel_hold)

func configure_chapter(next_mode: String, snapshot: Dictionary) -> void:
	_cancel_hold()
	_event_done = false
	_event_clock = 0.0
	_ringing = false
	_username = null
	_link_revealed = snapshot.get("revealed", []).has("payout")
	_short_selected = false
	_selected_clue = ""
	_chat_contact = "Jobert" if snapshot.get("phase", "") == "sleep" else str(Chapter.STORY[int(snapshot.beat)].get("contact", "Jobert"))
	super.configure_chapter(next_mode, snapshot)
	if next_mode == "chat": _begin_chat_turn()
	if next_mode == "read" and _event() == "notification": AudioManager.play_sfx("ui_notification")

func _event() -> String:
	return str(Chapter.STORY[int(state.get("beat", 0))].get("event", ""))

func _process(delta: float) -> void:
	super._process(delta)
	if _locked or not is_visible_in_tree() or _app != "mail" or mode != "read" or _event() != "interrupt" or _event_done or _ringing: return
	_event_clock += delta
	if is_instance_valid(_username): _username.text = "john_demo".left(mini(9, int(_event_clock * 4)))
	if _event_clock >= 1.8:
		_ringing = true
		AudioManager.play_sfx("ui_notification")
		_render()

func _render() -> void:
	if not is_instance_valid(_content): return
	_cancel_hold()
	if mode == "chat" or _app == "home":
		super._render()
		return
	UI.clear(_content)
	if is_instance_valid(_chat_footer):
		_chat_footer.get_parent().remove_child(_chat_footer)
		_chat_footer.queue_free()
	_chat_footer = null
	_chat_send = null
	match mode:
		"read": _payout_story()
		"reveal": _link_inspection()
		"expand": _link_expander()
		"flaws": _flaw_hunt()
	if not _notice_text.is_empty(): _ink(_notice_text)
	_refresh()
	_metrics()
	view_changed.emit()

func _payout_story() -> void:
	match _event():
		"notification":
			_ink("✉ MAIL · JUST NOW\nSurvey Rewards\nYour payout is ready.")
			_action("OPEN EMAIL", _complete_event)
		"email", "open_link":
			var entry: Dictionary = Chapter.MESSAGES[0]
			_ink(str(entry.subject))
			_ink("FROM / " + str(entry.sender))
			_ink(str(entry.body))
			_ink("Verify your e-wallet\n" + Chapter.DISPLAY_URL)
			_action("VERIFY YOUR E-WALLET" if _event() == "open_link" else "KEEP EMAIL / CONTINUE", _complete_event)
		"interrupt":
			if _ringing:
				_ink(("CALL CONNECTED" if _event_done else "INCOMING CALL") + "\nJOBERT")
				_ink("Typing stopped. Nothing was submitted.")
				if not _event_done: _action("ANSWER CALL", _complete_event)
			else:
				_ink("PocketWallet\nSign in to receive your payout")
				_ink("USERNAME · STORY SIMULATION")
				_username = _ink("", UI.panel(_content, Color.WHITE))
				_ink("Scripted demo only. Never enter real credentials.")
		"screenshot":
			_ink("JOBERT / PRIVATE CHAT")
			_ink("Screenshot attached · Login page\nNo credentials submitted.")
			_action("SEND SCREENSHOT", func() -> void:
				if not _locked:
					_add("captures", "payout")
					_complete_event())
	if _event_done: _ink("✓ " + ("Screenshot sent to Jobert" if _event() == "screenshot" else "Continue the conversation"))

func _complete_event() -> void:
	if _locked or _event_done: return
	_event_done = true
	_add("read", "payout")
	AudioManager.play_sfx("ui_confirm")
	_render()
	phase_finished.emit()

func _build_chat() -> void:
	super._build_chat()
	if _chat_stage == "done": _chat_status.text = "Private conversation · " + _chat_contact

func _begin_chat_turn() -> void:
	if _chat_index < chat_entries.size() and chat_entries[_chat_index].has("channel"):
		_chat_contact = str(chat_entries[_chat_index].channel)
		_chat_history.clear()
		AudioManager.play_sfx("ui_notification")
	super._begin_chat_turn()

func _success(text: String) -> void:
	var panel: PanelContainer = UI.panel(_content, PHONE_PAPER.lerp(Color("33D17A"), 0.16))
	panel.add_theme_stylebox_override("panel", UI.box(PHONE_PAPER.lerp(Color("33D17A"), 0.16), Color("33D17A"), 16))
	_ink("✓ " + text, panel)

func _link_inspection() -> void:
	_ink("Hold, hover or focus on the displayed link. No website will open.")
	var link: Button = _action(Chapter.DISPLAY_URL, func() -> void: pass)
	link.name = "InspectLink"
	link.button_down.connect(_start_hold)
	link.button_up.connect(_cancel_hold)
	link.mouse_entered.connect(_start_hold)
	link.mouse_exited.connect(_cancel_hold)
	link.focus_entered.connect(_start_hold)
	link.focus_exited.connect(_cancel_hold)
	if _link_revealed:
		if phase_ready():
			_success("MISMATCH SAVED\nDisplayed: " + Chapter.DISPLAY_URL + "\nActual: " + Chapter.SHORT_URL + "\nThe displayed text is not the destination.")
			_action("CONTINUE TO EXPAND LINK", _finish_phase)
		else:
			_ink("ACTUAL LINK\n" + Chapter.SHORT_URL)
			_action("MARK ADDRESS MISMATCH", _mark_mismatch)

func _start_hold() -> void:
	if _locked or mode != "reveal" or _link_revealed or _app != "mail" or not is_visible_in_tree(): return
	if is_instance_valid(_hold_timer) and _hold_timer.is_stopped(): _hold_timer.start()

func _cancel_hold() -> void:
	if is_instance_valid(_hold_timer): _hold_timer.stop()

func _reveal_destination() -> void:
	if _locked or mode != "reveal" or not is_visible_in_tree() or _app != "mail": return
	_link_revealed = true
	_render()

func _mark_mismatch() -> void:
	if _locked or not _link_revealed or mode != "reveal": return
	_add("revealed", "payout")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _link_expander() -> void:
	_ink("Drag the shortened link into the box, or select it and tap the box.")
	var link: ShortLink = ShortLink.new()
	link.name = "ShortLink"
	link.text = ("SELECTED / " if _short_selected else "") + Chapter.SHORT_URL
	_style_header_button(link)
	_content.add_child(link)
	link.pressed.connect(func() -> void:
		if not _locked:
			_short_selected = true
			_render())
	var target: Expander = Expander.new()
	target.name = "ExpandTarget"
	target.text = "EXPAND LINK\nDrop here / Tap after selecting"
	_style_header_button(target)
	_content.add_child(target)
	target.link_dropped.connect(_expand_link)
	target.pressed.connect(func() -> void:
		if _short_selected: _expand_link())
	if phase_ready():
		_success("DESTINATION REVEALED\n" + Chapter.DESTINATION + "\nShort links hide the destination. Shortening alone does not prove a scam.")
		_action("INSPECT LOGIN SCREENSHOT", _finish_phase)

func _expand_link() -> void:
	if _locked or mode != "expand": return
	_add("expanded", "payout")
	AudioManager.play_sfx("ui_confirm")
	_render()

func _hotspot(text: String, id: String, parent: Control) -> Button:
	var found: bool = state.hotspots.has(id)
	var button: Button = _action(("✓ " if found else "") + text, _find_clue.bind(id))
	button.name = "Hotspot_" + id
	button.reparent(parent)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if id in ["security", "http"]: button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	for font_state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(font_state, INK)
	button.accessibility_name = text + (", discovered" if found else ", inspect")
	if id != "spelling":
		for style: String in ["normal","hover","pressed","focus"]:
			button.add_theme_stylebox_override(style, UI.box(Color.WHITE, Color("8aa9a3") if style != "normal" else Color.WHITE, 6))
	if found:
		for style: String in ["normal","hover","pressed","focus"]:
			button.add_theme_stylebox_override(style, UI.box(PHONE_PAPER.lerp(Color("33D17A"), 0.16), Color("33D17A"), 12))
	return button

func _login_snapshot(parent: Control) -> void:
	var page: PanelContainer = UI.panel(parent, Color.WHITE)
	page.size_flags_horizontal = SIZE_EXPAND_FILL
	var snapshot: VBoxContainer = UI.column(page, 8)
	var bar: HBoxContainer = HBoxContainer.new()
	snapshot.add_child(bar)
	_hotspot("ⓘ", "security", bar).accessibility_name = "Connection information: no secure indicator. Inspect."
	_hotspot("http://", "http", bar)
	var domain: Button = _hotspot("pocket-wallet-verify.example/login", "domain", snapshot)
	domain.add_theme_font_size_override("font_size", 18)
	var logo: Button = _hotspot("PocketWallet", "logo", snapshot)
	logo.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.2, 0.5))
	logo.add_theme_constant_override("shadow_offset_x", 2)
	logo.add_theme_constant_override("shadow_offset_y", 1)
	_ink("Sign in to receive your payout", snapshot)
	var fields: PanelContainer = UI.panel(snapshot, Color("f2f4f3"))
	_ink("Username: john_d…\nPassword: [not entered]", fields)
	_hotspot("LOGN IN", "spelling", snapshot)

func _flaw_hunt() -> void:
	_ink("Find 3 of 5 clues · Tap suspicious parts of this frozen page.")
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	_content.add_child(columns)
	_login_snapshot(columns)
	var notes: VBoxContainer = UI.column(columns, 14)
	notes.size_flags_horizontal = SIZE_EXPAND_FILL
	_ink("%d / 5 CLUES FOUND" % state.hotspots.size(), notes)
	_ink(Chapter.CLUES.get(_selected_clue, "Inspect the address bar, branding and button. Select a discovered clue again to reread its explanation."), notes)
	if state.hotspots.size() >= 3:
		_ink("KEY FINDINGS REVIEW\n" + Chapter.DESTINATION + "\n\nKnown wallet: pocketwallet.example\nThis page uses a different domain and HTTP. Do not enter login details. HTTPS alone would not prove it is genuine.\n\nHTTP and the missing secure indicator describe the same issue.", notes)
		if not state.reviewed:
			var save: Button = _action("REVIEWED / SAVE PAGE EVIDENCE", _review_findings)
			save.reparent(notes)
		else:
			_success("PAGE EVIDENCE SAVED\nOdd domain and insecure HTTP connection. No login was submitted.")
			_action("CONTINUE TO EXHIBIT", _finish_phase)

func _find_clue(id: String) -> void:
	if _locked or mode != "flaws" or not Chapter.CLUES.has(id): return
	_selected_clue = id
	_add("hotspots", id)
	AudioManager.play_sfx("ui_confirm")
	_render()

func _review_findings() -> void:
	if _locked or mode != "flaws" or state.hotspots.size() < 3: return
	state.reviewed = true
	_add("captures", "payout")
	evidence_changed.emit(state.duplicate(true))
	_render()

func _refresh() -> void:
	super._refresh()
	if state.is_empty(): return
	# Story chats finish through the shared footer; hiding it strands the beat.
	_nav.visible = mode == "chat" and phase_ready()
	if _nav.visible:
		_close.accessibility_name = "Continue the story"
		_close.tooltip_text = "Continue the story"
	_status.visible = mode in ["read","chat"]
	if mode not in Chapter.TASKS: _title.visible = true
	_title.text = _chat_contact + " / Private chat" if mode == "chat" else "✉ Mail / " + {"read":"Survey Rewards", "reveal":"Inspect Link", "expand":"Expand Link", "flaws":"Login Screenshot"}.get(mode, "Payout")
	_title.add_theme_color_override("font_color", INK)

func _fit_shell() -> void:
	super._fit_shell()
	if not is_instance_valid(_shell) or mode not in Chapter.TASKS or _app != "mail": return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var frame: StyleBoxEmpty = _shell.get_theme_stylebox("panel") as StyleBoxEmpty
	var padding: float = (40.0 if _title.visible else 28.0) / physical
	(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", ceili(18 / physical))
	for edge: String in ["left","right","top","bottom"]: frame.set("content_margin_" + edge, padding)
	var width: float = minf(size.x - 16, 1140 / physical)
	_shell.position = Vector2((size.x - width) * 0.5, 0)
	_shell.size = Vector2(width, minf(size.y - 8, _content.get_combined_minimum_size().y + (_title.get_combined_minimum_size().y + 16 / physical if _title.visible else 0.0) + padding * 2))
	(_content.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_shell.queue_redraw()

func _metrics() -> void:
	super._metrics()
	if mode not in Chapter.TASKS: return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	_title.visible = get_viewport_rect().size.y * physical >= 500
	for node: Node in _content.find_children("*", "Label", true, false):
		(node as Label).add_theme_font_size_override("font_size", ceili(18 / physical))
	for node: Node in _content.find_children("*", "Button", true, false):
		(node as Button).custom_minimum_size.y = 48 / physical
		(node as Button).add_theme_font_size_override("font_size", ceili(18 / physical))

func phase_ready() -> bool:
	match mode:
		"read": return _event_done
		"chat": return _chat_stage == "done"
		"reveal": return state.get("revealed", []).has("payout")
		"expand": return state.get("expanded", []).has("payout")
		"flaws": return state.get("hotspots", []).size() >= 3 and state.get("reviewed", false)
	return false

func set_locked(value: bool) -> void:
	if value: _cancel_hold()
	super.set_locked(value)

func stop() -> void:
	_cancel_hold()
	super.stop()
