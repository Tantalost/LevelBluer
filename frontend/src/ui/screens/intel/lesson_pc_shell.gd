extends PanelContainer
## Presentation only. The simulation owns evidence, grading and app content.
signal app_requested(app: String)
signal back_requested
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const APPS: Array[String] = ["Inbox", "Browser", "Directory", "File Sandbox", "Evidence", "Quarantine"]
const NAMES: Array[String] = ["Mail", "Browser", "Directory", "Files", "Evidence", "Quarantine"]
const KINDS: Array[int] = [IntelPixelIcon.Kind.ENVELOPE, IntelPixelIcon.Kind.TERMINAL, IntelPixelIcon.Kind.BADGE, IntelPixelIcon.Kind.BOOKS, IntelPixelIcon.Kind.CODEX, IntelPixelIcon.Kind.LOCK]
const COLORS: Array[Color] = [Color("#4FE0D4"), Color("#4F8CFF"), Color("#FFB648"), Color("#8FF0E6"), Color("#F3ECD6"), Color("#FF5C5C")]
var body: VBoxContainer
var actions: HBoxContainer
var home: Control
var window: PanelContainer
var shortcuts: Array[Button] = []
var dock: Array[Button] = []
var active_app: String = ""
var unread: bool = true
var back_button: Button
var _title: Label
var _running: Button
var _surface: Control
var _home_grid: GridContainer
var _toast: Button
var _motion: Tween

class Wallpaper extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0A1730"))
		for y: int in range(0, int(size.y), 24):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.1, 0.3, 0.4, 0.09))
		var center: Vector2 = Vector2(size.x * 0.76, size.y * 0.46)
		for i: int in 4:
			var radius: float = 50 + float(i) * 30
			draw_arc(center, radius, 0, TAU, 32, Color(0.31, 0.88, 0.83, 0.08), 2)
		for i: int in 7:
			var origin: Vector2 = center + Vector2(-180 + i * 36, 100)
			draw_line(origin, origin + Vector2(80, 80), Color(0.31, 0.88, 0.83, 0.06), 6)
	func _ready() -> void:
		resized.connect(queue_redraw)

class AppShortcut extends Button:
	var badge: bool = false:
		set(value):
			badge = value
			queue_redraw()
	func _draw() -> void:
		if badge:
			draw_circle(Vector2(size.x - 17, 13), 8, Color("#FF5C5C"))
			draw_circle(Vector2(size.x - 17, 13), 3, Color("#F3ECD6"))

func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	var rim: StyleBoxFlat = UI.box(Color("#050B18"), Color("#335074"), 10)
	rim.set_border_width_all(5)
	rim.border_color = Color("#335074")
	rim.shadow_color = Color(0, 0, 0, 0.5)
	rim.shadow_size = 6
	add_theme_stylebox_override("panel", rim)
	var monitor: VBoxContainer = UI.column(self, 0)
	_surface = Control.new()
	_surface.size_flags_vertical = SIZE_EXPAND_FILL
	_surface.custom_minimum_size.y = 230
	monitor.add_child(_surface)
	var wallpaper: Wallpaper = Wallpaper.new()
	wallpaper.mouse_filter = MOUSE_FILTER_IGNORE
	_surface.add_child(wallpaper)
	wallpaper.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	home = Control.new()
	home.name = "DesktopHome"
	_surface.add_child(home)
	home.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_home_grid = GridContainer.new()
	_home_grid.columns = 3
	_home_grid.add_theme_constant_override("h_separation", 16)
	_home_grid.add_theme_constant_override("v_separation", 14)
	_home_grid.position = Vector2(24, 24)
	home.add_child(_home_grid)
	for i: int in APPS.size():
		var shortcut: Button = _icon_button(i, true)
		shortcut.name = "Desktop" + NAMES[i]
		_home_grid.add_child(shortcut)
		shortcuts.append(shortcut)
	var brand: Label = UI.label("LEVEL BLUE\nSTUDENT WORKSPACE", 28, Color("#335074"))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.mouse_filter = MOUSE_FILTER_IGNORE
	home.add_child(brand)
	brand.anchor_left = 0.58
	brand.anchor_right = 0.96
	brand.anchor_top = 0.32
	brand.anchor_bottom = 0.56
	_toast = UI.button("NEW MAIL\nOpen your inbox to investigate", _request.bind("Inbox"))
	_toast.name = "MailNotification"
	home.add_child(_toast)
	_toast.anchor_left = 0.55
	_toast.anchor_right = 0.98
	_toast.anchor_top = 0.72
	_toast.anchor_bottom = 0.96
	_toast.add_theme_stylebox_override("normal", UI.box(Color("#102040"), Color("#4FE0D4"), 14))
	window = PanelContainer.new()
	window.name = "ApplicationWindow"
	window.add_theme_stylebox_override("panel", UI.box(Color("#0A1730"), Color("#4F8CFF"), 10))
	_surface.add_child(window)
	window.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	window.offset_left = 18
	window.offset_top = 14
	window.offset_right = -18
	window.offset_bottom = -14
	var frame: VBoxContainer = UI.column(window, 10)
	var titlebar: HBoxContainer = HBoxContainer.new()
	titlebar.add_theme_constant_override("separation", 10)
	frame.add_child(titlebar)
	back_button = UI.button("<", func() -> void: back_requested.emit())
	back_button.tooltip_text = "Back to inbox"
	back_button.custom_minimum_size.x = 64
	titlebar.add_child(back_button)
	back_button.hide()
	_title = UI.label("", 24, Color("#8FF0E6"))
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titlebar.add_child(_title)
	var minimize: Button = UI.button("_", hide_window.bind(false))
	minimize.name = "MinimizeApp"
	minimize.tooltip_text = "Minimize to taskbar"
	minimize.custom_minimum_size.x = 64
	titlebar.add_child(minimize)
	var close: Button = UI.button("X", hide_window.bind(true))
	close.name = "CloseApp"
	close.tooltip_text = "Close window (evidence is kept)"
	close.custom_minimum_size.x = 64
	titlebar.add_child(close)
	body = UI.scroll_column(frame)
	(body.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	(body.get_parent() as ScrollContainer).custom_minimum_size.y = 80
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	frame.add_child(actions)
	window.hide()
	var taskbar_panel: PanelContainer = UI.panel(monitor, Color("#102040"))
	taskbar_panel.add_theme_stylebox_override("panel", UI.box(Color("#102040"), Color("#335074"), 6))
	var taskbar: HBoxContainer = HBoxContainer.new()
	taskbar.add_theme_constant_override("separation", 8)
	taskbar_panel.add_child(taskbar)
	var start: Button = UI.button("HOME", hide_window.bind(false))
	start.autowrap_mode = TextServer.AUTOWRAP_OFF
	start.name = "ShowDesktop"
	taskbar.add_child(start)
	for i: int in APPS.size():
		var button: Button = _icon_button(i, false)
		taskbar.add_child(button)
		dock.append(button)
	_running = UI.button("No app open", func() -> void:
		if not active_app.is_empty():
			_request(active_app)
	)
	_running.size_flags_horizontal = SIZE_EXPAND_FILL
	_running.autowrap_mode = TextServer.AUTOWRAP_OFF
	_running.clip_text = true
	taskbar.add_child(_running)
	var status: Label = UI.label("OFFLINE\n09:00", 18, Color("#8FF0E6"))
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	taskbar.add_child(status)
	refresh_badges()
	_surface.resized.connect(_fit_window)
	_fit_window.call_deferred()

func _icon_button(index: int, labeled: bool) -> Button:
	var button: AppShortcut = AppShortcut.new()
	button.custom_minimum_size = Vector2(184, 120) if labeled else Vector2(82, 48)
	button.tooltip_text = NAMES[index]
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", UI.box(Color(0.02, 0.06, 0.13, 0.35), Color("#173058"), 4))
	button.add_theme_stylebox_override("hover", UI.box(Color("#173058"), COLORS[index], 4))
	button.add_theme_stylebox_override("pressed", UI.box(Color("#153B37"), COLORS[index], 4))
	button.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, Color("#FFB648"), 4))
	button.pressed.connect(_request.bind(APPS[index]))
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = KINDS[index] as IntelPixelIcon.Kind
	icon.ink_override = COLORS[index]
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	icon.offset_left = 52 if labeled else 16
	icon.offset_right = -52 if labeled else -16
	icon.offset_top = 8
	icon.offset_bottom = -42 if labeled else -8
	if labeled:
		var label: Label = UI.label(NAMES[index], 22)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_child(label)
		label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		label.offset_top = -38
		label.offset_bottom = -6
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button

func _request(app: String) -> void:
	app_requested.emit(app)

func show_app(app: String) -> void:
	var changed: bool = not window.visible or active_app != app
	active_app = app
	var index: int = APPS.find(app)
	_title.text = NAMES[index] + "  /  SCHOOL PC" if index >= 0 else app
	_running.text = NAMES[index] if index >= 0 else app
	_running.disabled = false
	home.hide()
	window.show()
	refresh_badges()
	if _motion != null:
		_motion.kill()
	window.modulate.a = 1.0
	if changed and not SettingsService.reduced_motion:
		window.modulate.a = 0.0
		_motion = create_tween()
		_motion.tween_property(window, "modulate:a", 1.0, 0.16)

func hide_window(close: bool = false) -> void:
	if _motion != null:
		_motion.kill()
	window.modulate.a = 1.0
	window.hide()
	home.show()
	if close:
		active_app = ""
		_running.text = "No app open"
		_running.disabled = true
	elif not active_app.is_empty():
		_running.text = "Restore " + NAMES[APPS.find(active_app)]
	refresh_badges()

func refresh_badges() -> void:
	for buttons: Array[Button] in [shortcuts, dock]:
		for i: int in buttons.size():
			(buttons[i] as AppShortcut).badge = i == 0 and unread
	_toast.visible = unread

func _fit_window() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var physical: float = float(get_window().size.y) / get_viewport_rect().size.y
	var inset: float = 4.0 if physical < 0.8 else 18.0
	window.offset_left = inset
	window.offset_right = -inset
	window.offset_top = inset
	window.offset_bottom = -inset
