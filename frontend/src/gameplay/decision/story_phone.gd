extends Control
## Local story prop. Emits inspection intents; never grades, saves or opens URLs.
signal closed
signal message_read
signal detail_inspected(id: String)
signal investigation_confirmed

const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var _shell: PanelContainer
var _content: VBoxContainer
var _title: Label
var _status: Label
var _back: Button
var _home: Button
var _close: Button
var _confirm: Button
var _guide: Label
var _data: Dictionary = {}
var _message: Dictionary = {}
var _items: Array[Dictionary] = []
var _inspected: Dictionary = {}
var _app: String = "home"
var _reading: bool = false
var _card_open: bool = false
var _sender_revealed: bool = false
var _read: bool = false
var _investigating: bool = false
var _locked: bool = false
var _transition: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_meta("owns_responsive_metrics", true)
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	var dim: ColorRect = ColorRect.new()
	dim.color = Color("050B18", 0.65)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	_shell = UI.panel(self, Color("0A1730"))
	_shell.name = "PixelPhone"
	var frame: StyleBoxEmpty = StyleBoxEmpty.new()
	frame.content_margin_left = 26
	frame.content_margin_right = 26
	frame.content_margin_top = 44
	frame.content_margin_bottom = 26
	_shell.add_theme_stylebox_override("panel", frame)
	_shell.draw.connect(_draw_frame)
	var layout: VBoxContainer = UI.column(_shell, 8)
	_status = UI.label("ALEX'S PHONE", 18, UI.TEAL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_status)
	_title = UI.label("HOME", 24, UI.GOLD)
	layout.add_child(_title)
	_guide = UI.label("", 22, Color("8FF0E6"))
	layout.add_child(_guide)
	_content = UI.scroll_column(layout)
	_confirm = UI.button("", _finish, true)
	layout.add_child(_confirm)
	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	layout.add_child(nav)
	_back = UI.button("< BACK", _go_back)
	_home = UI.button("HOME", _navigate.bind("home"))
	_close = UI.button("CLOSE", _request_close)
	_close.accessibility_name = "Close phone and return to story"
	for button: Button in [_back, _home, _close]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		nav.add_child(button)
	resized.connect(_queue_metrics)
	get_viewport().size_changed.connect(_queue_metrics)
	hide()

func _queue_metrics() -> void:
	_metrics.call_deferred()

func configure(data: Dictionary) -> void:
	_data = data.duplicate(true)

func reset_incident(config: Dictionary = {}) -> void:
	stop()
	_message.clear()
	_items.clear()
	_inspected.clear()
	_read = false
	_sender_revealed = false
	_investigating = false
	_locked = false
	set_investigation(config)

func set_investigation(config: Dictionary) -> void:
	_items.clear()
	_inspected.clear()
	for entry: Dictionary in config.get("items", []):
		_items.append(entry.duplicate(true))

func receive_message(message: Dictionary) -> void:
	_message = message.duplicate(true)
	_read = false
	_sender_revealed = false

func open_phone(investigating: bool = false) -> void:
	if _locked or visible:
		return
	_investigating = investigating
	show()
	_navigate("home")
	_metrics()
	var settings: Node = get_node_or_null("/root/SettingsService")
	if settings == null or not bool(settings.get("reduced_motion")):
		_shell.modulate.a = 0.0
		_transition = create_tween()
		_transition.tween_property(_shell, "modulate:a", 1.0, 0.18)
	_home.grab_focus()

func stop() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = null
	_shell.modulate = Color.WHITE
	hide()

func set_locked(value: bool) -> void:
	_locked = value
	if _transition != null and _transition.is_valid():
		if value:
			_transition.pause()
		else:
			_transition.play()
	_refresh()

func is_complete() -> bool:
	return not _items.is_empty() and _inspected.size() == _items.size()

func _navigate(app: String) -> void:
	if _locked or not visible:
		return
	_app = app
	_reading = false
	_card_open = false
	_render()

func _render() -> void:
	UI.clear(_content)
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	_title.text = {"home": "HOME", "mail": "MAIL", "contacts": "SCHOOL CONTACTS", "pages": "SAVED PAGES"}.get(_app, "PHONE")
	match _app:
		"home":
			var apps: GridContainer = GridContainer.new()
			apps.columns = 3
			apps.add_theme_constant_override("h_separation", 10)
			_content.add_child(apps)
			_app_tile(apps, "mail", "Mail", IntelPixelIcon.Kind.ENVELOPE, Color("4FE0D4"))
			_app_tile(apps, "contacts", "Contacts", IntelPixelIcon.Kind.BADGE, Color("FFB648"))
			_app_tile(apps, "pages", "Saved", IntelPixelIcon.Kind.BOOKS, Color("8faef5"))
			if not _message.is_empty():
				var notice: Button = UI.button(("NEW MAIL / " if not _read else "MAIL / ") + str(_message.get("subject", "")), _navigate.bind("mail"))
				notice.alignment = HORIZONTAL_ALIGNMENT_LEFT
				_content.add_child(notice)
		"mail":
			if _message.is_empty():
				_content.add_child(UI.label("No new messages yet.", 22, UI.MUTED))
			elif not _reading:
				_content.add_child(UI.label("INBOX / " + ("1 UNREAD" if not _read else "1 MESSAGE"), 22, UI.TEAL))
				var sender: String = str(_message.get("sender", "")).get_slice("<", 0).strip_edges()
				var message_button: Button = UI.button(sender + "\n" + str(_message.get("subject", "")), _open_message)
				_content.add_child(message_button)
				_guide_button(message_button, "message")
			else:
				_render_message()
		"contacts", "pages":
			_content.add_child(UI.label("Saved from the school handbook" if _app == "contacts" else "Bookmarks saved before this message", 22, UI.MUTED))
			for card: Dictionary in _data.get(_app, []):
				var card_button: Button = UI.button(str(card.get("title", "")), _open_card.bind(card))
				_content.add_child(card_button)
				_guide_button(card_button, str(card.get("evidence_id", "")))
	_refresh()
	_metrics()

func _app_tile(parent: Control, app: String, caption: String, kind: IntelPixelIcon.Kind, ink: Color) -> void:
	var button: Button = UI.button("", _navigate.bind(app))
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 104)
	button.accessibility_name = caption
	parent.add_child(button)
	_guide_button(button, app)
	var face: VBoxContainer = VBoxContainer.new()
	face.mouse_filter = MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	face.offset_top = 8
	face.offset_bottom = -8
	button.add_child(face)
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = kind
	icon.ink_override = ink
	icon.custom_minimum_size.y = 48
	icon.size_flags_vertical = SIZE_EXPAND_FILL
	face.add_child(icon)
	var label: Label = UI.label(caption, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(label)
	if app == "mail" and not _message.is_empty() and not _read:
		var badge: ColorRect = ColorRect.new()
		badge.color = Color("FF5C5C")
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
		badge.offset_left = -18
		badge.offset_right = -8
		badge.offset_top = 8
		badge.offset_bottom = 18
		button.add_child(badge)

func _open_message() -> void:
	if _locked or not visible or _app != "mail" or _message.is_empty():
		return
	_reading = true
	if not _read:
		_read = true
		message_read.emit()
	_render()

func _render_message() -> void:
	_content.add_child(UI.label(str(_message.get("subject", "")), 24, UI.GOLD))
	_content.add_child(UI.label("From: " + str(_message.get("sender", "")).get_slice("<", 0).strip_edges(), 22, UI.TEAL))
	_content.add_child(UI.label(str(_message.get("body", "")), 22))
	if _items.is_empty():
		_content.add_child(UI.button("VIEW SENDER DETAILS", _show_sender))
		if _sender_revealed:
			_content.add_child(UI.label(str(_message.get("sender", "")), 22, UI.TEAL))
	_add_details("mail")
	_content.add_child(UI.label("Preview only. Links and replies are inactive.", 20, UI.MUTED))

func _show_sender() -> void:
	if _locked or not visible or not _reading or _sender_revealed:
		return
	_sender_revealed = true
	_render()

func _add_details(app: String) -> void:
	for item: Dictionary in _items:
		if str(item.get("phone_app", "mail")) != app:
			continue
		var id: String = str(item.get("id", ""))
		var detail_button: Button = UI.button(("[+] " if _inspected.has(id) else "") + str(item.get("label", "Inspect")), _inspect.bind(id))
		_content.add_child(detail_button)
		_guide_button(detail_button, id)
		if _inspected.has(id):
			var panel: PanelContainer = UI.panel(_content, Color("153B37"))
			panel.add_child(UI.label(str(item.get("analysis", "")), 22))

func _inspect(id: String) -> void:
	if _locked or not visible:
		return
	for item: Dictionary in _items:
		if str(item.get("id", "")) != id or str(item.get("phone_app", "mail")) != _app or (_app == "mail" and not _reading):
			continue
		if not _inspected.has(id):
			_inspected[id] = true
			detail_inspected.emit(id)
		var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
		var previous_scroll: int = scroll.scroll_vertical
		_render()
		scroll.set_deferred("scroll_vertical", previous_scroll)
		return

func _open_card(card: Dictionary) -> void:
	if _locked or not visible:
		return
	var evidence_id: String = str(card.get("evidence_id", ""))
	if not evidence_id.is_empty():
		_inspect(evidence_id)
	_card_open = true
	UI.clear(_content)
	_content.add_child(UI.label(str(card.get("title", "")), 24, UI.GOLD))
	_content.add_child(UI.label(str(card.get("body", "")), 22))
	for item: Dictionary in _items:
		if str(item.get("id", "")) == evidence_id:
			var evidence: PanelContainer = UI.panel(_content, Color("153B37"))
			evidence.add_child(UI.label(str(item.get("analysis", "")), 22))
	_refresh()
	_metrics()

func _go_back() -> void:
	if _locked:
		return
	if _card_open:
		_navigate(_app)
	elif _reading:
		_navigate("mail")
	else:
		_navigate("home")

func _request_close() -> void:
	if _locked or not visible:
		return
	closed.emit()

func _finish() -> void:
	if _locked or not visible or not _investigating or not is_complete():
		return
	_investigating = false
	investigation_confirmed.emit()

func _refresh() -> void:
	for node: Node in find_children("*", "Button", true, false):
		(node as Button).disabled = _locked
	_back.disabled = _locked or _app == "home"
	_confirm.visible = _investigating
	_confirm.disabled = _locked or not is_complete()
	_confirm.text = "DECIDE / USE FINDINGS" if is_complete() else "INSPECTED %d / %d" % [_inspected.size(), _items.size()]
	var next: String = _next_step()
	var instructions: Dictionary = {"mail": "Open Mail", "message": "Tap the message to read it", "sender": "Scroll down to sender details", "destination": "Preview the link below", "contacts": "Go Home, then open Contacts", "directory": "Open the saved School IT card", "decide": "Ready? Use your findings below", "close": "Close the phone to continue talking"}
	_guide.text = "> NEXT / " + str(instructions.get(next, "Explore your saved details"))
	_guide_button(_home, next if _app != "home" and next in ["mail", "contacts"] else "")
	_guide_button(_close, "close")
	_guide_button(_confirm, "decide")

func _next_step() -> String:
	if not _read:
		return "message" if _app == "mail" else "mail"
	for item: Dictionary in _items:
		var id: String = str(item.get("id", ""))
		if _inspected.has(id):
			continue
		var app: String = str(item.get("phone_app", "mail"))
		if _app != app:
			return app
		if app == "mail" and not _reading:
			return "message"
		return id
	return "decide" if _investigating else "close"

func _guide_button(button: Button, action: String) -> void:
	var highlighted: bool = not action.is_empty() and action == _next_step()
	var style: StyleBoxFlat = UI.box(Color("153B37") if highlighted else Color("102040"), Color("4FE0D4") if highlighted else Color("173058"), 10)
	style.set_border_width_all(3 if highlighted else 1)
	button.add_theme_stylebox_override("normal", style)
	button.tooltip_text = "Next step" if highlighted else ""

func _metrics() -> void:
	if not is_instance_valid(_shell):
		return
	var scale_factor: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	for node: Node in find_children("*", "Control", true, false):
		if node is Label or node is Button:
			(node as Control).add_theme_font_size_override("font_size", maxi(22, ceili(16.0 / scale_factor)))
		if node is Button:
			(node as Button).custom_minimum_size.y = maxf(48.0 / scale_factor, 52.0 if (node as Button).accessibility_name not in ["Mail", "Contacts", "Saved"] else 104.0)
	_fit_shell.call_deferred()
	_shell.queue_redraw()

func _fit_shell() -> void:
	var scale_factor: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var compact: bool = size.y * scale_factor < 500.0
	var height: float = maxf(0.0, size.y - 32.0)
	var width: float = minf(size.x - 32.0, (720.0 if compact else 420.0) / scale_factor)
	_shell.position = Vector2(floorf((size.x - width) * 0.5), 12)
	_shell.size = Vector2(width, height)

func _draw_frame() -> void:
	if not is_instance_valid(_shell):
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, _shell.size)
	_shell.draw_colored_polygon(_bezel(Rect2(rect.position + Vector2(4, 7), rect.size).grow(3), 24), Color("050B18"))
	_shell.draw_colored_polygon(_bezel(rect, 24), Color("748d91"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-3), 22), Color("F3ECD6"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-9), 17), Color("253c48"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-13), 14), Color("0A1730"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 30, 22), Vector2(48, 5)), Color("748d91"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x * 0.5 + 28, 20), Vector2(7, 7)), Color("4FE0D4"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 24, rect.size.y - 18), Vector2(48, 4)), Color("748d91"))
	# Sparse pixel wallpaper keeps Home recognizable without obscuring evidence.
	if _app == "home":
		for i: int in 6:
			var step: float = 16.0 * float(i)
			_shell.draw_rect(Rect2(Vector2(rect.size.x - 100 - step, rect.size.y * 0.58 + step), Vector2(64, 8)), Color("153B37", 0.6))
	_shell.draw_rect(Rect2(Vector2(-4, 88), Vector2(4, 32)), Color("748d91"))
	_shell.draw_rect(Rect2(Vector2(rect.end.x, 100), Vector2(4, 46)), Color("748d91"))

func _bezel(rect: Rect2, corner: float) -> PackedVector2Array:
	var a: Vector2 = rect.position
	var b: Vector2 = rect.end
	var half: float = floorf(corner * 0.5)
	return PackedVector2Array([Vector2(a.x + corner, a.y), Vector2(b.x - corner, a.y), Vector2(b.x - corner, a.y + half), Vector2(b.x - half, a.y + half), Vector2(b.x - half, a.y + corner), Vector2(b.x, a.y + corner), Vector2(b.x, b.y - corner), Vector2(b.x - half, b.y - corner), Vector2(b.x - half, b.y - half), Vector2(b.x - corner, b.y - half), Vector2(b.x - corner, b.y), Vector2(a.x + corner, b.y), Vector2(a.x + corner, b.y - half), Vector2(a.x + half, b.y - half), Vector2(a.x + half, b.y - corner), Vector2(a.x, b.y - corner), Vector2(a.x, a.y + corner), Vector2(a.x + half, a.y + corner), Vector2(a.x + half, a.y + half), Vector2(a.x + corner, a.y + half)])
