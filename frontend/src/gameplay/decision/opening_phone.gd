extends "res://src/gameplay/decision/story_phone.gd"

# Shared phone palette, including close-up investigation views.
const PHONE_FRAME_COLORS: Array[Color] = [Color("29252e"), Color("d1bda3"), Color("fff3d8"), Color("fffbed"), Color("302933"), Color("141b30")]
const PHONE_PAPER: Color = Color("fff7ed")
const PHONE_STATUS: Color = Color("cb8b8b")
const PHONE_HEADER: Color = Color("f6b5a6")
## Opening-only portrait skin. Inherits local email actions and tween cleanup.
var _alarm_pending: bool = true
var _dismiss: Button
var _dock: HBoxContainer
var _apps: GridContainer
var _alarm_art: Control

class AppArt extends Control:
	var app_id: int = 0
	func _draw() -> void:
		var pixel: float = maxf(1, floorf(minf(size.x, size.y) / 18))
		draw_set_transform((size - Vector2.ONE * 18 * pixel) * 0.5, 0, Vector2.ONE * pixel)
		var cream: Color = Color("fff3db")
		var ink: Color = Color("594c46")
		match app_id:
			0:
				draw_rect(Rect2(2, 3, 14, 13), cream)
				draw_rect(Rect2(2, 3, 14, 3), Color("b9504e"))
				for x: int in [5, 12]:
					draw_rect(Rect2(x, 1, 2, 4), cream)
				draw_rect(Rect2(8, 8, 2, 6), ink)
				draw_rect(Rect2(6, 13, 6, 1), ink)
			1:
				draw_rect(Rect2(2, 3, 7, 3), Color("ffe8a0"))
				draw_rect(Rect2(2, 6, 14, 10), Color("ffe09a"))
				draw_rect(Rect2(4, 4, 11, 2), Color("ae7941"))
				draw_rect(Rect2(3, 7, 12, 1), Color("fff3cd"))
			2:
				draw_rect(Rect2(1, 2, 16, 14), cream)
				draw_rect(Rect2(3, 4, 12, 10), Color("8ed6ef"))
				draw_circle(Vector2(12, 6), 2, Color("ffdb7c"), true, -1, false)
				draw_colored_polygon(PackedVector2Array([Vector2(3, 14), Vector2(3, 11), Vector2(7, 7), Vector2(11, 12), Vector2(13, 9), Vector2(15, 11), Vector2(15, 14)]), Color("81b76a"))
			3:
				draw_rect(Rect2(2, 4, 14, 10), cream)
				draw_line(Vector2(2, 4), Vector2(9, 10), Color("7394b1"), 1)
				draw_line(Vector2(9, 10), Vector2(16, 4), Color("7394b1"), 1)
				draw_line(Vector2(2, 14), Vector2(7, 9), Color("a8bdc5"), 1)
				draw_line(Vector2(16, 14), Vector2(11, 9), Color("a8bdc5"), 1)
			4:
				draw_colored_polygon(PackedVector2Array([Vector2(3, 2), Vector2(6, 2), Vector2(7, 6), Vector2(5, 8), Vector2(10, 13), Vector2(12, 10), Vector2(16, 12), Vector2(16, 15), Vector2(13, 17), Vector2(7, 14), Vector2(3, 9), Vector2(1, 5)]), cream)
			5:
				draw_rect(Rect2(2, 3, 13, 13), cream)
				for y: int in [6, 9, 12]:
					draw_rect(Rect2(4, y, 9, 1), Color("baa99a"))
				for x: int in [4, 8, 12]:
					draw_rect(Rect2(x, 1, 1, 4), ink)
				draw_line(Vector2(7, 15), Vector2(16, 5), Color("466887"), 3)
			7:
				draw_rect(Rect2(7, 2, 4, 9), cream)
				for y: int in [4, 6, 8]:
					draw_rect(Rect2(7, y, 4, 1), ink)
				draw_polyline(PackedVector2Array([Vector2(5, 7), Vector2(5, 12), Vector2(13, 12), Vector2(13, 7)]), cream, 1)
				draw_rect(Rect2(8, 12, 2, 4), cream)
				draw_rect(Rect2(5, 16, 8, 1), cream)
			8:
				var points: PackedVector2Array = []
				for point: int in 10:
					var angle: float = -PI / 2 + point * PI / 5
					points.append(Vector2(9, 9) + Vector2(cos(angle), sin(angle)) * (8 if point % 2 == 0 else 4))
				draw_colored_polygon(points, cream)
			9:
				draw_circle(Vector2(9, 9), 6, Color("72c2ba"), true, -1, false)
				draw_line(Vector2(1, 15), Vector2(17, 3), Color("ffdc7d"), 3)
				draw_circle(Vector2(9, 9), 4, Color("78c7d1"), true, -1, false)
			10:
				draw_rect(Rect2(1, 2, 16, 14), Color("b5cfb0"))
				draw_rect(Rect2(1, 6, 16, 2), cream)
				draw_rect(Rect2(5, 2, 2, 14), cream)
				draw_circle(Vector2(11, 7), 4, Color("dc8265"), true, -1, false)
				draw_colored_polygon(PackedVector2Array([Vector2(7, 8), Vector2(15, 8), Vector2(11, 16)]), Color("dc8265"))
				draw_circle(Vector2(11, 7), 1, ink)
			11:
				draw_rect(Rect2(2, 3, 14, 10), cream)
				draw_colored_polygon(PackedVector2Array([Vector2(4, 11), Vector2(4, 17), Vector2(10, 11)]), cream)
			13:
				draw_rect(Rect2(9, 9, 8, 8), Color("edaa65"))
				for origin: Vector2 in [Vector2(2, 5), Vector2(11, 5), Vector2(2, 13), Vector2(11, 12), Vector2(11, 15)]:
					draw_rect(Rect2(origin, Vector2(5, 1)), cream)
				draw_rect(Rect2(4, 3, 1, 5), cream)
			14:
				draw_circle(Vector2(9, 9), 8, cream, true, -1, false)
				draw_line(Vector2(9, 3), Vector2(9, 9), ink, 2)
				draw_line(Vector2(9, 9), Vector2(13, 11), ink, 2)
			16:
				draw_polyline(PackedVector2Array([Vector2(6, 14), Vector2(6, 5), Vector2(13, 3), Vector2(13, 12)]), cream, 2)
				draw_circle(Vector2(4, 14), 2, cream)
				draw_circle(Vector2(11, 12), 2, cream)
			_:
				draw_circle(Vector2(9, 9), 7, Color("bfc4c8"), false, 4, false)
				draw_circle(Vector2(9, 9), 3, cream, false, 1, false)
				for offset: Vector2 in [Vector2(7, 0), Vector2(7, 14), Vector2(0, 7), Vector2(14, 7)]:
					draw_rect(Rect2(offset, Vector2(4, 4)), Color("bfc4c8"))

class AlarmArt extends Control:
	func _draw() -> void:
		var unit: float = minf(size.x, size.y) / 140.0
		var center: Vector2 = size * 0.5
		for radius: int in [64, 53, 43]:
			draw_circle(center, radius * unit, Color(1, 1, 1, 0.14), false, 8 * unit, false)
		draw_circle(center, 38 * unit, Color("f8edd5"), true, -1, false)
		draw_circle(center, 30 * unit, Color("765548"), true, -1, false)
		draw_circle(center, 24 * unit, Color("fff7e9"), true, -1, false)
		for direction: float in [-1.0, 1.0]:
			draw_rect(Rect2(center + Vector2(direction * 26 - 8, -34) * unit, Vector2(16, 12) * unit), Color("d0a279"))
			draw_line(center + Vector2(direction * 18, 25) * unit, center + Vector2(direction * 26, 36) * unit, Color("765548"), 7 * unit)
		draw_line(center, center + Vector2(0, -18) * unit, Color("553b34"), 6 * unit)
		draw_line(center, center + Vector2(13, 9) * unit, Color("553b34"), 6 * unit)
		for index: int in 2:
			var star: Vector2 = center + Vector2(35 + index * 24, -41 - index * 22) * unit
			var points: PackedVector2Array = []
			for point: int in 10:
				var angle: float = -PI * 0.5 + point * PI / 5
				points.append(star + Vector2(cos(angle), sin(angle)) * (15 if point % 2 == 0 else 7) * unit)
			draw_colored_polygon(points, Color("ffd67e"))

func _ready() -> void:
	super._ready()
	clip_contents = true
	_close.text = "× CLOSE"
	_close.accessibility_name = "Close application and return to phone home screen"
	_close.pressed.disconnect(_request_close)
	_close.pressed.connect(_close_app)
	var frame: StyleBoxEmpty = _shell.get_theme_stylebox("panel") as StyleBoxEmpty
	frame.content_margin_top = 38
	frame.content_margin_left = 25
	frame.content_margin_right = 25
	frame.content_margin_bottom = 30

func configure(config: Dictionary) -> void:
	super.configure(config)
	_status.text = "07:00  •  LTE  ▰"
	_alarm_pending = true

func _animate_pin() -> void:
	if not _alarm_pending:
		super._animate_pin()

func _dismiss_alarm() -> void:
	if _locked or not visible or not _alarm_pending:
		return
	_alarm_pending = false
	_render()
	super._animate_pin()

func _render_story_home() -> void:
	_content.add_theme_constant_override("separation", 12)
	_dock = null
	_apps = null
	_alarm_art = null
	if _app == "home":
		_render_apps()
	elif _alarm_pending:
		var title: Label = UI.label("Morning Alarm", 26, Color.WHITE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(title)
		var time: Label = UI.label("07:00 AM", 40, Color.WHITE)
		time.set_meta("opening_clock", true)
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(time)
		_alarm_art = AlarmArt.new()
		_alarm_art.mouse_filter = MOUSE_FILTER_IGNORE
		_alarm_art.size_flags_vertical = SIZE_EXPAND_FILL
		_alarm_art.resized.connect(_alarm_art.queue_redraw)
		_content.add_child(_alarm_art)
		var greeting: Label = UI.label("Good morning!", 25, Color.WHITE)
		greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(greeting)
		var center: CenterContainer = CenterContainer.new()
		_content.add_child(center)
		_dismiss = UI.button("×", _dismiss_alarm)
		_dismiss.name = "DismissAlarm"
		_dismiss.accessibility_name = "Dismiss morning alarm"
		var circle: StyleBoxFlat = UI.box(Color("f3ecd6"), Color("93dfed"), 6)
		circle.set_corner_radius_all(90)
		circle.set_border_width_all(7)
		for style: String in ["normal", "hover", "pressed"]:
			_dismiss.add_theme_stylebox_override(style, circle)
		_dismiss.add_theme_color_override("font_color", Color("55b9de"))
		center.add_child(_dismiss)
	else:
		_pin_keys.clear()
		var title: Label = UI.label("Enter passcode", 24, Color.WHITE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(title)
		_pin_dots = UI.label("_ _ _ _", 26, Color.WHITE)
		_pin_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(_pin_dots)
		var keypad: GridContainer = GridContainer.new()
		keypad.columns = 3
		keypad.size_flags_vertical = SIZE_EXPAND_FILL
		keypad.add_theme_constant_override("h_separation", 6)
		keypad.add_theme_constant_override("v_separation", 6)
		_content.add_child(keypad)
		for digit: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", ""]:
			var key: PanelContainer = UI.panel(keypad, Color("367ea7"))
			key.size_flags_horizontal = SIZE_EXPAND_FILL
			key.size_flags_vertical = SIZE_EXPAND_FILL
			var caption: Label = UI.label(digit, 24, Color.WHITE)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key.add_child(caption)
			_pin_keys.append(key)

func _render_apps() -> void:
	if not _read:
		var notification: Button = UI.button("MAIL · 1 NEW\nPrize Desk", _open_story_email)
		notification.name = "MailBanner"
		notification.accessibility_name = "Open new email from Prize Desk"
		notification.set_meta("opening_notification", true)
		for style: String in ["normal", "hover", "pressed"]:
			notification.add_theme_stylebox_override(style, _raised_style(Color("fff3db", 0.94), Color("85c5d5"), 6))
		notification.add_theme_color_override("font_color", Color("173058"))
		_content.add_child(notification)
	_apps = GridContainer.new()
	_apps.columns = 4
	_apps.add_theme_constant_override("h_separation", 10)
	_apps.add_theme_constant_override("v_separation", 14)
	_content.add_child(_apps)
	var colors: Array[String] = ["c75b58", "f5bd58", "65b5c7", "739bd1", "8eaf6e", "b79472", "b9a2d7", "c77857", "d78bb2", "8992d7", "9ab279", "78b385", "9296a2", "b8a58a", "ddd5c5", "6b97c5"]
	for index: int in 16:
		if index in [6, 15]:
			_apps.add_child(Control.new())
		else:
			_story_icon(_apps, index, Color(colors[index]), index == 3)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var dock_panel: PanelContainer = UI.panel(_content, Color("fff5e3"))
	dock_panel.add_theme_stylebox_override("panel", _raised_style(Color("fff5e3", 0.92), Color("fff8ea"), 6))
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 8)
	dock_panel.add_child(_dock)
	for index: int in [4, 9, 7, 11]:
		_story_icon(_dock, 16 if index == 7 else index, Color("db8383") if index == 7 else Color(colors[index]), false)

func _story_icon(parent: Control, app_id: int, color: Color, mail: bool) -> void:
	var tile: Button = Button.new()
	tile.name = "EmailNotification" if mail else "DecorativeApp"
	tile.size_flags_horizontal = SIZE_EXPAND_FILL
	tile.set_meta("opening_app", true)
	tile.accessibility_name = ("Mail, read email" if _read else "Mail, one unread email") if mail else "Decorative app icon"
	tile.focus_mode = FOCUS_ALL if mail else FOCUS_NONE
	tile.mouse_filter = MOUSE_FILTER_STOP if mail else MOUSE_FILTER_IGNORE
	for style: String in ["normal", "hover", "pressed", "focus"]:
		var fill: Color = color.lightened(0.15) if style == "hover" else color
		var box: StyleBoxFlat = _raised_style(fill, color.darkened(0.55), 4)
		box.set_corner_radius_all(10)
		box.corner_detail = 1
		tile.add_theme_stylebox_override(style, box)
	if mail:
		var focus: StyleBoxFlat = UI.box(Color(0, 0, 0, 0), Color("fff8ea"), 0)
		focus.set_border_width_all(3)
		focus.set_corner_radius_all(10)
		tile.add_theme_stylebox_override("focus", focus)
	parent.add_child(tile)
	var glyph: AppArt = AppArt.new()
	glyph.app_id = app_id
	glyph.mouse_filter = MOUSE_FILTER_IGNORE
	glyph.resized.connect(glyph.queue_redraw)
	tile.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glyph.offset_left = 5
	glyph.offset_top = 5
	glyph.offset_right = -5
	glyph.offset_bottom = -5
	if mail:
		tile.pressed.connect(_open_story_email)
	if mail and not _read:
		var badge: Panel = Panel.new()
		badge.name = "UnreadBadge"
		var badge_style: StyleBoxFlat = UI.box(Color("e77f78"), Color("754d57"), 0)
		badge_style.set_corner_radius_all(12)
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		tile.add_child(badge)
		badge.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
		badge.offset_left = -14
		badge.offset_right = 4
		badge.offset_top = -5
		badge.offset_bottom = 13
		var count: Label = UI.label("1", 16, Color("101623"))
		count.set_meta("opening_badge", true)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.mouse_filter = MOUSE_FILTER_IGNORE
		badge.add_child(count)
		count.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _render_message() -> void:
	_content.add_theme_constant_override("separation", 12)
	var subject: Label = UI.label(str(_message.get("subject", "")), 28, Color("101623"))
	subject.set_meta("opening_subject", true)
	_content.add_child(subject)
	var sender_card: PanelContainer = UI.panel(_content, Color("f0e5d6"))
	sender_card.name = "SenderCard"
	sender_card.add_theme_stylebox_override("panel", UI.box(Color("f0e5d6"), Color("ddcdbb"), 8))
	var sender: VBoxContainer = UI.column(sender_card, 8)
	for text: String in ["FROM · " + str(_message.get("sender", "")), "To: me  ·  Today, 07:00"]:
		var metadata: Label = UI.label(text, 22, Color("544650"))
		metadata.set_meta("opening_mail_metadata", true)
		sender.add_child(metadata)
	var body: Label = UI.label(str(_message.get("body", "")), 24, Color("473d42"))
	body.name = "EmailBody"
	_content.add_child(body)
	if bool(_data.get("claim_enabled", false)):
		var claim: Button = UI.button("CLAIM PRIZE", _claim, true)
		claim.name = "ClaimPrize"
		_content.add_child(claim)

func show_open_message() -> void:
	_alarm_pending = false
	super.show_open_message()
	_zoom_app(1.0)

func _open_story_email() -> void:
	if _locked or not visible or not _unlocked:
		return
	_app = "mail"
	_reading = true
	_read = true
	_render()
	_zoom_app(1.0)
	# Reopening the same email still emits an intent; the opening checks its beat.
	message_read.emit()

func _close_app() -> void:
	if _locked or not visible:
		return
	_app = "home"
	_reading = false
	_render()
	_zoom_app(0.0)

func _zoom_app(target: float) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = null
	if _reduced_motion():
		_zoom = target
		return
	_zoom_tween = create_tween()
	_zoom_tween.finished.connect(func() -> void: _zoom_tween = null)
	_zoom_tween.tween_property(self, "_zoom", target, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_locked(value: bool) -> void:
	if _alarm_pending:
		_locked = value
		_refresh()
	else:
		super.set_locked(value)

func _refresh() -> void:
	super._refresh()
	_status.visible = _app != "lock"
	_title.visible = _app == "mail"
	_title.text = "✦ Mail"
	_title.add_theme_color_override("font_color", Color("fff8ef"))
	_back.hide()
	_nav.visible = _app == "mail"
	_close.show()
	_close.disabled = _locked
	for style: String in ["normal", "hover", "pressed"]:
		_close.add_theme_stylebox_override(style, _raised_style(Color("e7e3db"), Color("918b83"), 8))
	_guide_panel.hide()

func _metrics() -> void:
	if not is_inside_tree() or not is_instance_valid(_shell):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	for node: Node in find_children("*", "Control", true, false):
		if node is Label or node is Button:
			var pixels: float = 20.0 if _app == "mail" else 16.0
			if node.has_meta("opening_clock"):
				pixels = 32.0
			elif node.has_meta("opening_subject"):
				pixels = 24.0
			elif node.has_meta("opening_mail_metadata"):
				pixels = 16.0
			(node as Control).add_theme_font_size_override("font_size", maxi(22, ceili(pixels / physical)))
			if node.has_meta("opening_badge"):
				(node as Control).add_theme_font_size_override("font_size", 15)
			if node.has_meta("opening_notification"):
				(node as Control).custom_minimum_size.y = 48 / physical
	_close.custom_minimum_size = Vector2(190, maxf(52, 48 / physical))
	if is_instance_valid(_dismiss):
		_dismiss.custom_minimum_size = Vector2.ONE * maxf(72, 48 / physical)
		_dismiss.add_theme_font_size_override("font_size", ceili(32 / physical))
	_fit_shell.call_deferred()

func _fit_shell() -> void:
	if not is_inside_tree() or not is_instance_valid(_shell):
		return
	var app_open: bool = _app == "mail"
	var frame: StyleBoxEmpty = _shell.get_theme_stylebox("panel") as StyleBoxEmpty
	frame.content_margin_left = 40 if app_open else 25
	frame.content_margin_right = 40 if app_open else 25
	var height: float = maxf(100, size.y - 14)
	var width: float = minf(size.x - 16, height * lerpf(0.52, 0.94, _zoom))
	_shell.position = Vector2((size.x - width) * 0.5, 4)
	_shell.size = Vector2(width, height - (_close.custom_minimum_size.y + 14 if app_open else 0))
	_nav.position = Vector2((size.x - _close.custom_minimum_size.x) * 0.5, size.y - _close.custom_minimum_size.y - 6)
	_nav.size = _close.custom_minimum_size
	var cell: float = maxf(20, (width - 80) / 4)
	for tile: Node in _content.find_children("*", "Button", true, false):
		if tile.has_meta("opening_app"):
			(tile as Button).custom_minimum_size = Vector2(cell, cell)
	_shell.queue_redraw()
	if is_instance_valid(_alarm_art):
		_alarm_art.queue_redraw()

func _draw_frame() -> void:
	if not is_instance_valid(_shell):
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(_shell.size.x, _shell.size.x / 0.52))
	for layer: int in 6:
		_shell.draw_colored_polygon(_bezel(rect.grow(-layer * 4), 32 - layer * 3), PHONE_FRAME_COLORS[layer])
	var screen: Rect2 = rect.grow(-24)
	_wallpaper_clip = _bezel(screen, 14)
	if _app == "mail":
		_wallpaper_rect(screen, PHONE_PAPER)
		var status_bottom: float = _status.position.y + _status.size.y + 20
		var header_bottom: float = _title.position.y + _title.size.y + 20
		_wallpaper_rect(Rect2(screen.position, Vector2(screen.size.x, status_bottom)), PHONE_STATUS)
		_wallpaper_rect(Rect2(screen.position + Vector2(0, status_bottom), Vector2(screen.size.x, header_bottom - status_bottom)), PHONE_HEADER)
	else:
		for band: int in 100:
			var ratio: float = band / 99.0
			var ink: Color = Color("28689e").lerp(Color("53c8ef"), ratio) if _app == "lock" else Color("298ec2").lerp(Color("b3a4e3"), ratio)
			_wallpaper_rect(Rect2(screen.position + Vector2(0, screen.size.y * ratio), Vector2(screen.size.x, screen.size.y / 99 + 1)), ink)
		for column: int in 40:
			var x: float = screen.position.x + column * screen.size.x / 40
			var y: float = screen.position.y + screen.size.y * (0.62 + sin(column * 0.12) * 0.24)
			_wallpaper_rect(Rect2(Vector2(x, y), Vector2(screen.size.x / 40 + 1, 13)), Color("92eaff", 0.25))
		for speck: int in 30:
			var at: Vector2 = screen.position + Vector2(fmod(speck * 47.0 + 11, screen.size.x), fmod(speck * 83.0 + 37, screen.size.y))
			# Keep tiny flecks clear of stepped corners: clipping subpixel slivers
			# while zooming can produce degenerate polygons in the renderer.
			if screen.grow(-16).encloses(Rect2(at, Vector2(3, 5))):
				_shell.draw_rect(Rect2(at, Vector2(3, 5)), Color(1, 1, 1, 0.18))
	_shell.draw_rect(Rect2(-3, 105, 4, 45), Color("dfceb3"))
	_shell.draw_rect(Rect2(rect.end.x - 1, 130, 4, 64), Color("dfceb3"))
