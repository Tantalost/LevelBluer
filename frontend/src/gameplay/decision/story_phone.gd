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
var _nav: HBoxContainer
var _unlock_button: Button
var _unlocked: bool = false
var _zoom_tween: Tween
var _zoom: float = 0.0:
	set(value):
		_zoom = value
		_fit_shell()
var _close: Button
var _confirm: Button
var _guide: RichTextLabel
var _guide_panel: PanelContainer
var _wallpaper_clip: PackedVector2Array = []
var _data: Dictionary = {}
var _message: Dictionary = {}
var _items: Array[Dictionary] = []
var _inspected: Dictionary = {}
var _revealed_fields: Dictionary = {}
var _expanded_id: String = ""
var _card_data: Dictionary = {}
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
	frame.content_margin_left = 28
	frame.content_margin_right = 28
	frame.content_margin_top = 50
	frame.content_margin_bottom = 28
	_shell.add_theme_stylebox_override("panel", frame)
	_shell.draw.connect(_draw_frame)
	var layout: VBoxContainer = UI.column(_shell, 8)
	_status = UI.label("07:35", 18, Color("F3ECD6"))
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout.add_child(_status)
	_title = UI.label("HOME", 24, UI.GOLD)
	layout.add_child(_title)
	_guide = RichTextLabel.new()
	_guide.bbcode_enabled = true
	_guide.add_theme_font_override("normal_font", UI.FONT)
	_guide.add_theme_color_override("default_color", Color("8FF0E6"))
	_guide.size_flags_vertical = SIZE_EXPAND_FILL
	_guide.scroll_active = true
	_guide.focus_mode = FOCUS_ALL
	_guide.accessibility_name = "Phone investigation checklist"
	_content = UI.scroll_column(layout)
	_guide_panel = UI.panel(self, Color("0A1730"))
	_guide_panel.name = "PhoneGuide"
	var guide_layout: VBoxContainer = UI.column(_guide_panel, 14)
	guide_layout.add_child(UI.label("CHECKLIST", 22, Color("F3ECD6")))
	guide_layout.add_child(_guide)
	_confirm = UI.button("", _finish, true)
	guide_layout.add_child(_confirm)
	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 12)
	add_child(_nav)
	_back = UI.button("< BACK", _go_back)
	_close = UI.button("CLOSE", _request_close)
	_close.accessibility_name = "Close phone and return to story"
	for button: Button in [_back, _close]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		_nav.add_child(button)
	resized.connect(_queue_metrics)
	get_viewport().size_changed.connect(_queue_metrics)
	hide()

func _queue_metrics() -> void:
	_metrics.call_deferred()

func configure(data: Dictionary) -> void:
	_data = data.duplicate(true)
	_status.text = str(_data.get("clock", "07:35"))
	_unlocked = false

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
	_revealed_fields.clear()
	_expanded_id = ""
	_card_data = {}
	for entry: Dictionary in config.get("items", []):
		_items.append(entry.duplicate(true))

func receive_message(message: Dictionary) -> void:
	_message = message.duplicate(true)
	_read = false
	_sender_revealed = false
	if visible:
		_render()

func open_phone(investigating: bool = false) -> void:
	if _locked or visible:
		return
	_investigating = investigating
	show()
	_app = "home" if _unlocked else "lock"
	_zoom = 0.0
	_reading = false
	_card_open = false
	_render()
	_metrics()
	var settings: Node = get_node_or_null("/root/SettingsService")
	if settings == null or not bool(settings.get("reduced_motion")):
		_shell.modulate.a = 0.0
		_transition = create_tween()
		_transition.finished.connect(func() -> void: _transition = null)
		_transition.tween_property(_shell, "modulate:a", 1.0, 0.18)
	if _app == "lock":
		_unlock_button.grab_focus()
	else:
		_close.grab_focus()

func _unlock() -> void:
	if _locked or not visible or _app != "lock":
		return
	_unlocked = true
	_navigate("home")

func _reduced_motion() -> bool:
	var settings: Node = get_node_or_null("/root/SettingsService")
	return settings != null and bool(settings.get("reduced_motion"))

func stop() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = null
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = null
	_shell.modulate = Color.WHITE
	hide()

func set_locked(value: bool) -> void:
	_locked = value
	if _transition != null and _transition.is_valid():
		if value:
			_transition.pause()
		else:
			_transition.play()
	if _zoom_tween != null and _zoom_tween.is_valid():
		if value:
			_zoom_tween.pause()
		else:
			_zoom_tween.play()
	_refresh()

func is_complete() -> bool:
	return not _items.is_empty() and _inspected.size() == _items.size()

func _navigate(app: String) -> void:
	if _locked or not visible or (not _unlocked and app != "lock"):
		return
	if app not in ["lock", "home", "mail", "contacts", "pages"]:
		return
	_app = app
	_reading = false
	_card_open = false
	_expanded_id = ""
	_render()
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var target: float = 0.0 if app in ["lock", "home"] else 1.0
	if _reduced_motion():
		_zoom = target
	else:
		_zoom_tween = create_tween()
		_zoom_tween.finished.connect(func() -> void: _zoom_tween = null)
		_zoom_tween.tween_property(self, "_zoom", target, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _render() -> void:
	UI.clear(_content)
	_content.size_flags_vertical = SIZE_EXPAND_FILL if _app in ["lock", "home"] else SIZE_FILL
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0
	var titles: Dictionary = _data.get("app_titles", {"home": "HOME", "mail": "MAIL", "contacts": "SCHOOL CONTACTS", "pages": "SAVED PAGES"})
	_title.text = str(titles.get(_app, "PHONE"))
	if _card_open:
		_render_card()
		_refresh()
		_metrics()
		return
	match _app:
		"lock", "home":
			var time: Label = UI.label(str(_data.get("time", "07:35")), 64, Color("F3ECD6"))
			time.set_meta("phone_clock", true)
			time.add_theme_color_override("font_outline_color", Color("173058"))
			time.add_theme_constant_override("outline_size", 4)
			time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_content.add_child(time)
			var date: Label = UI.label(str(_data.get("day", "MONDAY")), 20, Color("F3ECD6"))
			date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_content.add_child(date)
			var space: CenterContainer = CenterContainer.new()
			space.size_flags_vertical = SIZE_EXPAND_FILL
			space.mouse_filter = MOUSE_FILTER_IGNORE
			_content.add_child(space)
			if _app == "lock":
				var lock_icon: IntelPixelIcon = IntelPixelIcon.new()
				lock_icon.kind = IntelPixelIcon.Kind.LOCK
				lock_icon.ink_override = Color("F3ECD6")
				lock_icon.custom_minimum_size = Vector2(48, 48)
				space.add_child(lock_icon)
				_unlock_button = UI.button("TAP TO UNLOCK", _unlock, true)
				_unlock_button.accessibility_name = "Unlock Alex's " + str(_data.get("device_name", "phone"))
				_content.add_child(_unlock_button)
				_style_navigation(_unlock_button, true)
			else:
				var dock: PanelContainer = UI.panel(_content)
				dock.add_theme_stylebox_override("panel", _raised_style(Color("0A1730", 0.88), Color("8FF0E6", 0.6), 8))
				var apps: GridContainer = GridContainer.new()
				apps.columns = 3
				apps.add_theme_constant_override("h_separation", 10)
				dock.add_child(apps)
				_app_tile(apps, "mail", str(_data.get("message_app", "Mail")), IntelPixelIcon.Kind.ENVELOPE, Color("4FE0D4"))
				_app_tile(apps, "contacts", "Contacts", IntelPixelIcon.Kind.BADGE, Color("FFB648"))
				_app_tile(apps, "pages", "Saved", IntelPixelIcon.Kind.TERMINAL, Color("8faef5"))
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
			_content.add_child(UI.label(str(_data.get("contacts_origin", "Saved from the school handbook")) if _app == "contacts" else "Bookmarks saved before this message", 22, UI.MUTED))
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
	button.tooltip_text = caption
	button.set_meta("phone_app", app)
	parent.add_child(button)
	_guide_button(button, app)
	var face: Control = Control.new()
	face.mouse_filter = MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	face.offset_top = 8
	face.offset_bottom = -8
	button.add_child(face)
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = kind
	icon.ink_override = Color("F3ECD6")
	icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_right = -8
	face.add_child(icon)
	var app_style: StyleBoxFlat = _raised_style(ink.darkened(0.38), ink.lightened(0.25), 4)
	button.add_theme_stylebox_override("normal", app_style)
	button.add_theme_stylebox_override("hover", _raised_style(ink.darkened(0.15), Color("F3ECD6"), 4))
	button.add_theme_stylebox_override("pressed", _raised_style(ink.darkened(0.5), ink, 4))
	button.add_theme_stylebox_override("focus", _raised_style(Color.TRANSPARENT, Color("FFB648"), 0))
	if app == "mail" and not _message.is_empty() and not _read:
		var badge: Panel = Panel.new()
		badge.name = "UnreadBadge"
		var badge_style: StyleBoxFlat = UI.box(Color("FF5C5C"), Color("F3ECD6"), 0)
		badge_style.set_corner_radius_all(10)
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
		badge.offset_left = -16
		badge.offset_right = 4
		badge.offset_top = -4
		badge.offset_bottom = 16
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
	for item: Dictionary in _items:
		if str(item.get("id", "")) == _expanded_id and not (item.get("fields", []) as Array).is_empty():
			_render_evidence(item)
			return
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
		if _inspected.has(id) or _expanded_id == id:
			_render_evidence(item)

## Optional source fields add inspection without a second grading system.
## Revealing a preview never executes an attachment or follows a URL.
func _render_evidence(item: Dictionary) -> void:
	var id: String = str(item.get("id", ""))
	var fields: Array = item.get("fields", [])
	var panel: PanelContainer = UI.panel(_content, Color("102040"))
	var column: VBoxContainer = UI.column(panel, 12)
	if not fields.is_empty():
		column.add_child(UI.label(str(item.get("view_title", "EVIDENCE PREVIEW")), 22, UI.GOLD))
		var seen: Array = _revealed_fields.get(id, [])
		for index: int in fields.size():
			var field: Dictionary = fields[index]
			var revealed: bool = index in seen
			var button: Button = UI.button(("[x] " if revealed else "[ ] ") + str(field.get("label", "Detail")), _reveal_field.bind(id, index))
			column.add_child(button)
			_guide_button(button, "%s:%d" % [id, index])
			if revealed:
				column.add_child(UI.label(str(field.get("value", "")), 22, Color("8FF0E6")))
	if _inspected.has(id):
		# Structured source values stay visible; the interpretation lives in Logs
		# instead of repeating a paragraph underneath the same evidence.
		column.add_child(UI.label(str(item.get("analysis", "")) if fields.is_empty() else "DETAILS RECORDED IN LOGS", 22, UI.TEXT if fields.is_empty() else Color("33D17A")))

func _reveal_field(id: String, index: int) -> void:
	if _locked or not visible:
		return
	for item: Dictionary in _items:
		if str(item.get("id", "")) != id or str(item.get("phone_app", "mail")) != _app:
			continue
		if (_app == "mail" and (not _reading or _expanded_id != id)) or (_app != "mail" and (not _card_open or str(_card_data.get("evidence_id", "")) != id)):
			return
		var fields: Array = item.get("fields", [])
		if index < 0 or index >= fields.size():
			return
		var seen: Array = _revealed_fields.get(id, [])
		if index not in seen:
			seen.append(index)
		_revealed_fields[id] = seen
		if seen.size() == fields.size() and not _inspected.has(id):
			_inspected[id] = true
			detail_inspected.emit(id)
		var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
		var previous_scroll: int = scroll.scroll_vertical
		_render()
		scroll.set_deferred("scroll_vertical", previous_scroll)
		return

func _inspect(id: String) -> void:
	if _locked or not visible:
		return
	for item: Dictionary in _items:
		if str(item.get("id", "")) != id or str(item.get("phone_app", "mail")) != _app or (_app == "mail" and not _reading):
			continue
		var fields: Array = item.get("fields", [])
		_expanded_id = id if not fields.is_empty() else ""
		if fields.is_empty() and not _inspected.has(id):
			_inspected[id] = true
			detail_inspected.emit(id)
		var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
		var previous_scroll: int = scroll.scroll_vertical
		_render()
		scroll.set_deferred("scroll_vertical", previous_scroll)
		return

func _open_card(card: Dictionary) -> void:
	if _locked or not visible or _app not in ["contacts", "pages"] or card not in _data.get(_app, []):
		return
	_card_data = card.duplicate(true)
	var evidence_id: String = str(card.get("evidence_id", ""))
	if not evidence_id.is_empty():
		_inspect(evidence_id)
	_card_open = true
	_render()

func _render_card() -> void:
	_content.add_child(UI.label(str(_card_data.get("title", "")), 24, UI.GOLD))
	_content.add_child(UI.label(str(_card_data.get("body", "")), 22))
	for item: Dictionary in _items:
		if str(item.get("id", "")) == str(_card_data.get("evidence_id", "")):
			_render_evidence(item)

func _go_back() -> void:
	if _locked:
		return
	if _app == "mail" and _reading and not _expanded_id.is_empty():
		_expanded_id = ""
		_render()
	elif _card_open:
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
	_back.visible = _app not in ["lock", "home"]
	_back.disabled = _locked
	_title.visible = _app not in ["lock", "home"]
	_confirm.visible = _investigating and _app != "lock"
	_confirm.disabled = _locked or not is_complete()
	_confirm.text = "DECIDE / USE FINDINGS" if is_complete() else "INSPECTED %d / %d" % [_inspected.size(), _items.size()]
	var next: String = _next_step()
	_refresh_checklist()
	_guide_button(_back, next if _app != "home" and next in ["mail", "contacts", "pages", "evidence_back"] else "")
	_guide_button(_close, "close")
	_guide_button(_confirm, "decide")
	_style_navigation(_back, false)
	_style_navigation(_close, next == "close")

## Completion comes from real phone actions, not a second progress state.
func _checklist_tasks() -> Array[Dictionary]:
	var tasks: Array[Dictionary] = [
		{"id": "unlock", "text": "Unlock your phone", "done": _unlocked},
		{"id": "read", "text": "Mail: read the message", "done": _read},
	]
	for item: Dictionary in _items:
		var id: String = str(item.get("id", ""))
		var app: String = str(item.get("phone_app", "mail"))
		var caption: String = str({"mail": "Mail", "contacts": "Contacts", "pages": "Saved"}.get(app, "Phone"))
		tasks.append({"id": id, "text": caption + ": " + str(item.get("label", "Inspect details")), "done": _inspected.has(id)})
		var fields: Array = item.get("fields", [])
		var seen: Array = _revealed_fields.get(id, [])
		for index: int in fields.size():
			var field: Dictionary = fields[index]
			tasks.append({"id": "%s:%d" % [id, index], "text": "  Reveal " + str(field.get("label", "detail")).to_lower(), "done": index in seen})
	return tasks

func _refresh_checklist() -> void:
	var scroll_position: float = _guide.get_v_scroll_bar().value
	_guide.clear()
	for task: Dictionary in _checklist_tasks():
		var done: bool = bool(task["done"])
		_guide.push_color(Color("33D17A") if done else Color("F3ECD6"))
		_guide.add_text("[x] " if done else "[ ] ")
		if done:
			_guide.push_underline()
		_guide.add_text(str(task["text"]))
		if done:
			_guide.pop()
		_guide.pop()
		_guide.add_text("\n\n")
	_guide.get_v_scroll_bar().set_deferred("value", scroll_position)

func _raised_style(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = UI.box(fill, edge, padding)
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.shadow_offset = Vector2(0, 3)
	style.shadow_size = 0
	return style

func _style_navigation(button: Button, primary: bool) -> void:
	var fill: Color = Color("8FF0E6") if primary else Color("F3ECD6")
	button.add_theme_stylebox_override("normal", _raised_style(fill, Color("8c9d9b"), 8))
	button.add_theme_stylebox_override("hover", _raised_style(Color("8FF0E6"), Color("F3ECD6"), 8))
	button.add_theme_stylebox_override("pressed", _raised_style(Color("4FE0D4"), Color("173058"), 8))
	button.add_theme_color_override("font_color", Color("101623"))

func _next_step() -> String:
	if _app == "lock":
		return "unlock"
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
		if (app == "mail" and not _expanded_id.is_empty() and _expanded_id != id) or (app != "mail" and _card_open and str(_card_data.get("evidence_id", "")) != id):
			return "evidence_back"
		if (app == "mail" and _expanded_id == id) or (app != "mail" and _card_open and str(_card_data.get("evidence_id", "")) == id):
			var fields: Array = item.get("fields", [])
			var seen: Array = _revealed_fields.get(id, [])
			for index: int in fields.size():
				if index not in seen:
					return "%s:%d" % [id, index]
		return id
	return "decide" if _investigating else "close"

func _guide_button(button: Button, action: String) -> void:
	var highlighted: bool = not action.is_empty() and action == _next_step()
	var style: StyleBoxFlat = UI.box(Color("153B37") if highlighted else Color("102040"), Color("4FE0D4") if highlighted else Color("173058"), 10)
	style.set_border_width_all(3 if highlighted else 1)
	button.add_theme_stylebox_override("normal", style)
	button.tooltip_text = ("Next: " if highlighted else "") + button.accessibility_name

func _metrics() -> void:
	if not is_instance_valid(_shell):
		return
	var scale_factor: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_guide.add_theme_font_size_override("normal_font_size", maxi(22, ceili(16.0 / scale_factor)))
	for node: Node in find_children("*", "Control", true, false):
		if node is Label or node is Button:
			(node as Control).add_theme_font_size_override("font_size", maxi(22, ceili((40.0 if node.has_meta("phone_clock") else 16.0) / scale_factor)))
		if node is Button:
			(node as Button).custom_minimum_size.y = maxf(48.0 / scale_factor, 52.0)
	_fit_shell.call_deferred()
	_shell.queue_redraw()

func _fit_shell() -> void:
	if not is_instance_valid(_shell) or not is_instance_valid(_nav):
		return
	var scale_factor: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var nav_height: float = maxf(52.0, 48.0 / scale_factor)
	var gap: float = 24.0 / scale_factor
	var side_guide: bool = size.x >= size.y
	var guide_width: float = minf(240.0 / scale_factor, size.x * 0.29) if side_guide else size.x - 40.0
	var guide_height: float = minf(420.0 / scale_factor, size.y - 120.0 / scale_factor) if side_guide else minf(240.0 / scale_factor, size.y * 0.35)
	_guide_panel.size = Vector2(guide_width, guide_height)
	var available_width: float = size.x - 40.0 - (guide_width + gap if side_guide else 0.0)
	var height: float = maxf(160.0, size.y - nav_height - 36.0 - (0.0 if side_guide else guide_height + gap))
	var home_width: float = minf(available_width, maxf(230.0 / scale_factor, height * 0.52))
	var app_width: float = minf(available_width, maxf(home_width * 1.6, 520.0 / scale_factor))
	var width: float = lerpf(home_width, app_width, _zoom)
	var group_width: float = width + (guide_width + gap if side_guide else 0.0)
	var group_left: float = floorf((size.x - group_width) * 0.5)
	# Keep the phone clear of the story hearts at the top-left on small screens.
	_shell.position = Vector2(group_left + (guide_width + gap if side_guide else 0.0), 12.0)
	_shell.size = Vector2(width, height)
	var nav_width: float = width - 24.0
	_nav.position = Vector2(_shell.position.x + 12.0, height + 26.0)
	_nav.size = Vector2(nav_width, nav_height)
	_guide_panel.position = Vector2(group_left, maxf(100.0 / scale_factor, (size.y - guide_height) * 0.5)) if side_guide else Vector2(20.0, _nav.position.y + nav_height + gap)
	for node: Node in _content.find_children("*", "Button", true, false):
		if node.has_meta("phone_app"):
			(node as Button).custom_minimum_size.y = maxf(48.0 / scale_factor, minf(96.0, (width - 92.0) / 3.0))
	_shell.queue_redraw()

func _draw_frame() -> void:
	if not is_instance_valid(_shell):
		return
	# Only the decorative device continues below the viewport in close-up;
	# scrollable app content and navigation remain inside the safe area.
	var rect: Rect2 = Rect2(Vector2.ZERO, _shell.size + Vector2(0, 220.0 * _zoom))
	_shell.draw_colored_polygon(_bezel(Rect2(rect.position + Vector2(4, 7), rect.size).grow(3), 36), Color("050B18"))
	_shell.draw_colored_polygon(_bezel(rect, 36), Color("727a83"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-3), 32), Color("b4b3a7"))
	_shell.draw_colored_polygon(_bezel(Rect2(Vector2(3, 3), rect.size - Vector2(10, 12)), 30), Color("F3ECD6"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-8), 26), Color("fff7e4"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-14), 22), Color("101623"))
	_shell.draw_colored_polygon(_bezel(rect.grow(-20), 16), Color("0A1730") if _app not in ["lock", "home"] else Color("235789"))
	# Static, code-drawn wallpaper: no texture downloads or idle animation.
	if _app in ["lock", "home"]:
		_draw_wallpaper(rect.grow(-26))
	# Thin rails catch light on one side and shade the other.
	_shell.draw_rect(Rect2(Vector2(5, 42), Vector2(3, rect.size.y - 84)), Color("fff7e4"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x - 8, 42), Vector2(3, rect.size.y - 84)), Color("727a83"))
	# Hardware and status marks sit above the wallpaper, never underneath it.
	_shell.draw_colored_polygon(_bezel(Rect2(Vector2(rect.size.x * 0.5 - 42, 24), Vector2(84, 17)), 6), Color("101623"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 24, 30), Vector2(36, 3)), Color("748d91"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x * 0.5 + 23, 29), Vector2(5, 5)), Color("4FE0D4"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 24, rect.size.y - 16), Vector2(48, 4)), Color("748d91"))
	for i: int in 3:
		_shell.draw_rect(Rect2(Vector2(rect.size.x - 80 + i * 6, 66 - i * 4), Vector2(4, 5 + i * 4)), Color("F3ECD6"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x - 53, 57), Vector2(21, 12)), Color("F3ECD6"), false, 2)
	_shell.draw_rect(Rect2(Vector2(rect.size.x - 50, 60), Vector2(13, 6)), Color("8FF0E6"))
	_shell.draw_rect(Rect2(Vector2(rect.size.x - 31, 61), Vector2(3, 4)), Color("F3ECD6"))
	_shell.draw_rect(Rect2(Vector2(-4, 88), Vector2(4, 32)), Color("748d91"))
	_shell.draw_rect(Rect2(Vector2(rect.end.x, 100), Vector2(4, 46)), Color("748d91"))

func _draw_wallpaper(screen: Rect2) -> void:
	_wallpaper_clip = _bezel(screen, 16.0)
	for i: int in 24:
		var y: float = screen.position.y + floorf(screen.size.y * float(i) / 24.0)
		var band: Color = Color("173058").lerp(Color("74b6ba"), float(i) / 24.0)
		_wallpaper_rect(Rect2(Vector2(screen.position.x, y), Vector2(screen.size.x, ceilf(screen.size.y / 24.0))), band)
	var unit: float = maxf(2.0, floorf(screen.size.x / 64.0))
	var sun: Vector2 = (screen.position + screen.size * Vector2(0.76, 0.36)).floor()
	_wallpaper_rect(Rect2(sun + Vector2(-3, -5) * unit, Vector2(6, 10) * unit), Color("f3dba8"))
	_wallpaper_rect(Rect2(sun + Vector2(-5, -3) * unit, Vector2(10, 6) * unit), Color("f3dba8"))
	for i: int in 7:
		var star: Vector2 = screen.position + Vector2(fmod(float(i * 37 + 12), screen.size.x - 12), screen.size.y * (0.27 + float(i % 3) * 0.06))
		_wallpaper_rect(Rect2(star.floor(), Vector2.ONE * unit), Color("F3ECD6", 0.65))
	_draw_ridge(screen, PackedFloat32Array([0.66, 0.60, 0.55, 0.50, 0.44, 0.40, 0.45, 0.49, 0.54, 0.59, 0.55, 0.51, 0.47, 0.52, 0.56, 0.62]), Color("3b798a"))
	_draw_ridge(screen, PackedFloat32Array([0.60, 0.63, 0.65, 0.68, 0.71, 0.73, 0.77, 0.74, 0.71, 0.66, 0.61, 0.56, 0.52, 0.55, 0.57, 0.61]), Color("235b70"))
	var water_y: float = floorf(screen.position.y + screen.size.y * 0.78)
	_wallpaper_rect(Rect2(Vector2(screen.position.x, water_y), Vector2(screen.size.x, screen.end.y - water_y)), Color("173b57"))
	for i: int in 8:
		var at: Vector2 = Vector2(screen.position.x + screen.size.x * (0.10 + float(i % 4) * 0.21), water_y + float(i + 1) * (screen.size.y * 0.02))
		_wallpaper_rect(Rect2(at.floor(), Vector2(unit * (5 + i % 3), unit)), Color("4e969c"))

func _wallpaper_rect(rect: Rect2, ink: Color) -> void:
	_wallpaper_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), ink)

func _wallpaper_polygon(points: PackedVector2Array, ink: Color) -> void:
	for clipped: PackedVector2Array in Geometry2D.intersect_polygons(points, _wallpaper_clip):
		_shell.draw_colored_polygon(clipped, ink)

func _draw_ridge(screen: Rect2, heights: PackedFloat32Array, ink: Color) -> void:
	var points: PackedVector2Array = [Vector2(screen.position.x, screen.end.y)]
	var step: float = screen.size.x / float(heights.size())
	for i: int in heights.size():
		var y: float = floorf(screen.position.y + screen.size.y * heights[i])
		points.append(Vector2(floorf(screen.position.x + i * step), y))
		points.append(Vector2(floorf(screen.position.x + (i + 1) * step), y))
	points.append(screen.end)
	_wallpaper_polygon(points, ink)

func _exit_tree() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()

func _bezel(rect: Rect2, corner: float) -> PackedVector2Array:
	var a: Vector2 = rect.position
	var b: Vector2 = rect.end
	var half: float = floorf(corner * 0.5)
	return PackedVector2Array([Vector2(a.x + corner, a.y), Vector2(b.x - corner, a.y), Vector2(b.x - corner, a.y + half), Vector2(b.x - half, a.y + half), Vector2(b.x - half, a.y + corner), Vector2(b.x, a.y + corner), Vector2(b.x, b.y - corner), Vector2(b.x - half, b.y - corner), Vector2(b.x - half, b.y - half), Vector2(b.x - corner, b.y - half), Vector2(b.x - corner, b.y), Vector2(a.x + corner, b.y), Vector2(a.x + corner, b.y - half), Vector2(a.x + half, b.y - half), Vector2(a.x + half, b.y - corner), Vector2(a.x, b.y - corner), Vector2(a.x, a.y + corner), Vector2(a.x + half, a.y + corner), Vector2(a.x + half, a.y + half), Vector2(a.x + corner, a.y + half)])
