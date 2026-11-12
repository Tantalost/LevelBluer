extends PanelContainer
## Touch-operated CRT workspace. Register apps before adding this node to the tree.
## Connect app_requested to the activity controller. It opens the requested app with
## show_app(id), populates body/actions and supplies the terminal findings and results.
signal app_requested(app: String)
signal back_requested
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")
const INK: Color = Color("#051009")
const EDGE: Color = Color("#297942")
const GREEN: Color = Color("#55EE83")
const PAPER: Color = Color("#BAFBCB")
const RED: Color = Color("#FF7272")
class DesktopApp:
	var title: String
	var icon: IntelPixelIcon.Kind

	func _init(caption: String, kind: IntelPixelIcon.Kind) -> void:
		title = caption
		icon = kind

var session_title: String = "SYS://LOCAL"
var checklist_title: String = "STATUS"
var checklist: PackedStringArray = []
var _apps: Dictionary[String, DesktopApp] = {}
var _first_app: String = ""
var body: VBoxContainer
var actions: HBoxContainer
var home: PanelContainer
var window: PanelContainer
var shortcuts: Array[Button] = []
var dock: Array[Button] = []
var active_app: String = ""
var back_button: Button
var status: Label
var _running: Button
var _surface: Control
var _term: PanelContainer
var _term_button: Button
var _home_button: Button
var _buffer: PanelContainer
var _buffer_rows: Array[Label] = []
var _home_status: Label
var _log: RichTextLabel
var _history: PackedStringArray = []
var _typing: Tween
var _title: Label
var _motion: Tween
var _opening_outline: Panel
var _rail: ScrollContainer
var _overlay: PanelContainer
var _alert_body: Label
var _alert_title: Label
var _alert_motion: Tween
var _terminal_front: bool = false
## Register in the order shortcuts should appear. The first app is the Home launch action.
func add_app(id: String, caption: String, kind: IntelPixelIcon.Kind) -> void:
	if is_instance_valid(_surface) or id.is_empty() or _apps.has(id):
		push_error("Register each terminal app once, before adding the workspace to the tree.")
		return
	if _apps.is_empty():
		_first_app = id
	_apps[id] = DesktopApp.new(caption, kind)

static func box(fill: Color, border: Color, width: int = 1, radius: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 2
	return style

static func frame_style(fill: Color, border: Color, pad: int = 5) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(fill, border, 2)
	style.set_content_margin_all(pad)
	return style

static func label(value: String, font_size: int = 25, color: Color = PAPER) -> Label:
	var node: Label = UI.label(value, font_size, color)
	node.add_theme_font_override("font", FONT)
	return node

static func style_button(button: Button) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#81A48A"))
	button.add_theme_stylebox_override("normal", frame_style(Color("#0B2514"), EDGE, 6))
	button.add_theme_stylebox_override("hover", frame_style(Color("#123E22"), GREEN, 6))
	button.add_theme_stylebox_override("pressed", frame_style(GREEN, PAPER, 6))
	button.add_theme_stylebox_override("disabled", frame_style(INK, Color("#274532"), 6))
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, PAPER, 2))

static func _button(caption: String, action: Callable) -> Button:
	var button: Button = UI.button(caption, action)
	style_button(button)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	return button

func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_surface = Control.new()
	add_child(_surface)
	_surface.draw.connect(_draw_computer)
	status = label(session_title, 24, PAPER)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_surface.add_child(status)
	_term_button = _button("TERMINAL", _toggle_terminal)
	_surface.add_child(_term_button)
	_home_button = _button("FILES", hide_window.bind(false))
	_surface.add_child(_home_button)
	_rail = ScrollContainer.new()
	_rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_surface.add_child(_rail)
	var rail_items: VBoxContainer = UI.column(_rail, 4)
	rail_items.size_flags_horizontal = SIZE_EXPAND_FILL
	home = PanelContainer.new()
	_surface.add_child(home)
	var desktop: VBoxContainer = _window_body(home, "FILES   /   LOCAL")
	_home_status = label("LOCAL  /  APPLICATIONS", 23, GREEN)
	desktop.add_child(_home_status)
	var grid_scroll: ScrollContainer = ScrollContainer.new()
	grid_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desktop.add_child(grid_scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = clampi(_apps.size(), 1, 3)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid_scroll.add_child(grid)
	for id: String in _apps:
		var shortcut: Button = _shortcut(id)
		grid.add_child(shortcut)
		shortcuts.append(shortcut)
		var side: Button = _shortcut(id)
		rail_items.add_child(side)
		dock.append(side)
	_running = _button("Open " + _apps[_first_app].title if not _apps.is_empty() else "", func() -> void:
		_request(_first_app if active_app.is_empty() else active_app)
	)
	_running.visible = not _apps.is_empty()
	desktop.add_child(_running)
	window = PanelContainer.new()
	_surface.add_child(window)
	var frame: VBoxContainer = _window_body(window, "")
	var bar: HBoxContainer = frame.get_child(0) as HBoxContainer
	_title = bar.get_child(0) as Label
	back_button = _button("BACK", func() -> void: back_requested.emit())
	bar.add_child(back_button)
	back_button.hide()
	var minimize: Button = _button("–", hide_window.bind(false))
	minimize.name = "MinimizeApp"
	minimize.accessibility_name = "Minimize window"
	minimize.custom_minimum_size.x = 80
	bar.add_child(minimize)
	var close: Button = _button("×", hide_window.bind(true))
	close.accessibility_name = "Close window"
	close.name = "CloseApp"
	close.custom_minimum_size.x = 80
	bar.add_child(close)
	body = UI.scroll_column(frame)
	body.add_theme_constant_override("separation", 8)
	actions = HBoxContainer.new()
	frame.add_child(actions)
	window.hide()
	_opening_outline = Panel.new()
	_opening_outline.mouse_filter = MOUSE_FILTER_IGNORE
	_opening_outline.add_theme_stylebox_override("panel", box(Color.TRANSPARENT, GREEN, 2))
	_opening_outline.hide()
	_surface.add_child(_opening_outline)
	_term = PanelContainer.new()
	_surface.add_child(_term)
	var console: VBoxContainer = _window_body(_term, "TERMINAL")
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_vertical = SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", FONT)
	_log.add_theme_font_size_override("normal_font_size", 28)
	_log.add_theme_color_override("default_color", GREEN)
	console.add_child(_log)
	_buffer = PanelContainer.new()
	_surface.add_child(_buffer)
	var registers: VBoxContainer = _window_body(_buffer, checklist_title)
	for item: String in checklist:
		var row: Label = label(item, 22)
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		registers.add_child(row)
		_buffer_rows.append(row)
	_overlay = PanelContainer.new()
	_overlay.hide()
	_surface.add_child(_overlay)
	var dialog: VBoxContainer = _window_body(_overlay, "SYSTEM")
	_alert_title = dialog.get_child(0).get_child(0) as Label
	var alert_text: VBoxContainer = UI.scroll_column(dialog)
	_alert_body = label("")
	alert_text.add_child(_alert_body)
	var dismiss: Button = _button("OK", _overlay.hide)
	dialog.add_child(dismiss)
	var glass: Control = Control.new()
	glass.mouse_filter = MOUSE_FILTER_IGNORE
	_surface.add_child(glass)
	glass.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glass.draw.connect(draw_scanlines.bind(glass))
	_surface.resized.connect(_layout)
	_layout.call_deferred()

func _window_body(panel: PanelContainer, caption: String) -> VBoxContainer:
	panel.add_theme_stylebox_override("panel", frame_style(INK, EDGE, 5))
	var column: VBoxContainer = UI.column(panel, 6)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title: Label = label(caption, 24, PAPER)
	title.add_theme_stylebox_override("normal", frame_style(Color("#16522A"), EDGE, 3))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.size_flags_vertical = SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	return column

func _shortcut(id: String) -> Button:
	var app: DesktopApp = _apps[id]
	var button: Button = _button(app.title.to_upper(), _request.bind(id))
	button.accessibility_name = app.title
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(104, 84)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 23)
	var content: VBoxContainer = UI.column(button, 0)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = app.icon
	icon.ink_override = GREEN
	icon.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(icon)
	var caption: Label = label(button.text, 22, GREEN)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(caption)
	button.text = ""
	return button

func _request(app: String) -> void:
	_overlay.hide()
	_terminal_front = false
	app_requested.emit(app)

func show_app(app: String) -> void:
	if not _apps.has(app):
		return
	var opening: bool = not window.visible or active_app != app
	active_app = app
	_terminal_front = false
	_title.text = _apps[app].title.to_upper()
	_running.text = "Restore " + _apps[app].title
	home.hide()
	window.show()
	_layout()
	if opening:
		log_action("open " + _apps[app].title.to_lower())
		if _motion != null:
			_motion.kill()
		window.modulate.a = 1.0
		_opening_outline.hide()
		if not SettingsService.reduced_motion:
			# Animate the glass outline while native touch and drop targets stay in place.
			_opening_outline.pivot_offset = Vector2(0, window.size.y * 0.12)
			_opening_outline.scale = Vector2(0.06, 0.04)
			_opening_outline.show()
			window.modulate.a = 0.0
			_motion = window.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_motion.tween_property(_opening_outline, "scale:x", 1.0, 0.085)
			_motion.tween_property(_opening_outline, "scale:y", 1.0, 0.13)
			_motion.parallel().tween_property(window, "modulate:a", 1.0, 0.13)
			_motion.tween_callback(_opening_outline.hide)

func hide_window(close: bool = false) -> void:
	if _motion != null:
		_motion.kill()
	window.modulate.a = 1.0
	_opening_outline.hide()
	window.hide()
	_overlay.hide()
	home.show()
	_terminal_front = false
	if close:
		active_app = ""
		if not _apps.is_empty():
			_running.text = "Open " + _apps[_first_app].title
	_layout()

func set_app_badge(id: String, hint: String, highlighted: bool) -> void:
	var index: int = _apps.keys().find(id)
	if index < 0 or index >= shortcuts.size():
		return
	for button: Button in [shortcuts[index], dock[index]]:
		button.tooltip_text = hint if highlighted else _apps[id].title
		var icon: IntelPixelIcon = button.get_child(0).get_child(0) as IntelPixelIcon
		icon.ink_override = PAPER if highlighted else GREEN

func set_indicators(values: Array[bool]) -> void:
	if values.size() != _buffer_rows.size():
		return
	for i: int in _buffer_rows.size():
		_buffer_rows[i].text = ("[+] " if values[i] else "[ ] ") + checklist[i]
		_buffer_rows[i].add_theme_color_override("font_color", GREEN if values[i] else Color("#83A98D"))

func set_home_status(message: String) -> void:
	_home_status.text = message

func log_action(message: String) -> void:
	_history.append("> " + message)
	if _history.size() > 10:
		_history.remove_at(0)
	if _typing != null:
		_typing.kill()
	_log.text = "\n\n".join(_history) + "\n_"
	_log.visible_characters = -1
	if not SettingsService.reduced_motion:
		var total: int = _log.get_total_character_count()
		_log.visible_characters = maxi(0, total - message.length() - 2)
		_typing = _log.create_tween()
		_typing.tween_property(_log, "visible_characters", total, minf(0.45, message.length() * 0.012))

func show_result(caption: String, message: String, warning: bool) -> void:
	log_action(message)
	var ink: Color = RED if warning else GREEN
	_alert_title.text = caption
	_alert_title.add_theme_stylebox_override("normal", frame_style(Color("#531C20") if warning else Color("#16522A"), ink))
	_alert_body.text = message
	_overlay.add_theme_stylebox_override("panel", frame_style(Color("#1C1011") if warning else INK, ink, 8))
	_overlay.show()
	_layout()
	if _alert_motion != null:
		_alert_motion.kill()
	_overlay.scale = Vector2.ONE
	if not SettingsService.reduced_motion:
		_overlay.pivot_offset = _overlay.size / 2
		_overlay.scale = Vector2(0.88, 0.08)
		_alert_motion = _overlay.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_alert_motion.tween_property(_overlay, "scale", Vector2.ONE, 0.15)

func _toggle_terminal() -> void:
	_terminal_front = not _terminal_front
	_overlay.hide()
	_layout()

func _layout() -> void:
	if not is_instance_valid(_term) or not is_inside_tree():
		return
	var s: Vector2 = _surface.size
	var rail_w: float = clampf(s.x * 0.115, 105, 160)
	var x: float = 30 + rail_w
	var top_height: float = maxf(54, _term_button.get_combined_minimum_size().y)
	var y: float = top_height + 19
	var width: float = maxf(40, s.x - x - 29)
	var height: float = maxf(50, s.y - y - 35)
	status.position = Vector2(27, 18)
	status.size = Vector2(maxf(30, s.x - 350), 48)
	_term_button.position = Vector2(s.x - 207, 12)
	_term_button.size = Vector2(180, top_height)
	_home_button.position = Vector2(s.x - 316, 12)
	_home_button.size = Vector2(102, top_height)
	_rail.position = Vector2(22, y)
	_rail.size = Vector2(rail_w, height)
	var split: bool = width >= 850 and get_window().size.x >= 660
	var console_w: float = floorf(width * 0.31) if split else 0.0
	var gap: float = 12 if split else 0
	for panel: PanelContainer in [window, home]:
		panel.position = Vector2(x + console_w + gap, y)
		panel.size = Vector2(width - console_w - gap, height)
	_opening_outline.position = window.position
	_opening_outline.size = window.size
	_term.visible = split or _terminal_front
	_term.position = Vector2(x, y)
	var buffer_height: float = clampf(height * 0.32, 156, 200)
	_buffer.visible = not _buffer_rows.is_empty() and split and not _terminal_front and height >= 405
	_term.size = Vector2(width if _terminal_front else console_w, height - buffer_height - 9 if _buffer.visible else height)
	_buffer.position = Vector2(x, y + height - buffer_height)
	_buffer.size = Vector2(console_w, buffer_height)
	_term_button.text = "RETURN" if _terminal_front else "TERMINAL"
	_overlay.size = Vector2(minf(width, 690), minf(height, 300))
	_overlay.position = Vector2(x + width - _overlay.size.x, y + height - _overlay.size.y)
	_surface.queue_redraw()

func _draw_computer() -> void:
	draw_monitor(_surface)
	_surface.draw_rect(Rect2(24, 18, _surface.size.x - 48, 43), Color("#114021"))

## Also usable by workspaces with their own layout, such as the PvP match.
static func draw_monitor(canvas: Control) -> void:
	var s: Vector2 = canvas.size
	canvas.draw_style_box(box(Color("#A99E87"), Color("#E2D8BD"), 3, 13), Rect2(Vector2.ZERO, s))
	canvas.draw_style_box(box(Color("#393528"), Color("#786E56"), 3, 8), Rect2(12, 8, s.x - 24, s.y - 32))
	canvas.draw_style_box(box(INK, Color("#181E14"), 2, 5), Rect2(19, 14, s.x - 38, s.y - 45))
	canvas.draw_style_box(box(Color("#847B65"), Color("#514C3B"), 1, 2), Rect2(27, s.y - 22, 58, 10))
	for vent: int in 14:
		canvas.draw_rect(Rect2(s.x - 148 + vent * 5, s.y - 23, 2, 11), Color("#514C3B"))
	canvas.draw_rect(Rect2(s.x - 64, s.y - 18, 5, 3), GREEN)
	canvas.draw_style_box(box(Color("#BEB49C"), Color("#514C3B")), Rect2(s.x - 49, s.y - 24, 22, 13))
	canvas.draw_rect(Rect2(s.x - 43, s.y - 20, 9, 4), Color("#827862"))

static func draw_scanlines(canvas: Control) -> void:
	for y: int in range(22, int(canvas.size.y) - 32, 4):
		canvas.draw_line(Vector2(21, y), Vector2(canvas.size.x - 21, y), Color(0, 0, 0, 0.09))
