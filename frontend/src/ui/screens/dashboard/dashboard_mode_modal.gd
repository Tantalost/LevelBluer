class_name DashboardModeModal
extends Control
## Presentation and selection only; the dashboard owns the OS switch.
signal mode_confirmed(mode: StringName)
signal cancelled

enum Mode { SOLO, PVP }
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const BLUE: Color = Color("#4FE0D4")
const RED: Color = Color("#FF5C5C")
var selected_mode: Mode = Mode.SOLO
var _bands: Array[ModeBand] = []
var _title: Label
var _subtitle: Label
var _confirm: Button
var _cancel: Button
var _wash: ColorRect
var _motion: Tween
var _previous_focus: WeakRef

class ModeBand extends Button:
	var art: Texture2D
	var accent: Color = Color("#4FE0D4")
	var right_side: bool = false
	var power: float = 0.0:
		set(value):
			power = value
			queue_redraw()
	var copy: VBoxContainer
	var tag: Label
	var heading: Label
	var description: Label
	func polygon() -> PackedVector2Array:
		return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point, polygon())
	func _draw() -> void:
		var points: PackedVector2Array = polygon()
		draw_colored_polygon(points, Color("#0A1730") if not right_side else Color("#170A12"))
		if art != null and size.x > 0 and size.y > 0:
			var uv: PackedVector2Array = PackedVector2Array()
			# Cover each full-height half without stretching. Favor the hacker's
			# eyes on the right rather than the image's empty UI space.
			var ratio: float = (size.x / size.y) / (float(art.get_width()) / art.get_height())
			var crop: Vector2 = Vector2(minf(1.0, ratio), minf(1.0, 1.0 / ratio)) / (1.0 + power * 0.035)
			var focal_x: float = 0.76 if right_side else 0.48
			var origin: Vector2 = Vector2(clampf(focal_x - crop.x * 0.5, 0.0, 1.0 - crop.x), (1.0 - crop.y) * 0.42)
			for point: Vector2 in points:
				uv.append(origin + point / size * crop)
			var shade: Color = Color(0.3, 0.34, 0.4).lerp(Color.WHITE, power)
			draw_polygon(points, PackedColorArray([shade]), uv, art)
		var tint: Color = Color("#2E6BFF") if not right_side else accent
		draw_colored_polygon(points, Color(tint, 0.05 + 0.13 * power))
		# Floating text over cinematic gradients, not bordered cards.
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y * 0.3), Vector2(0, size.y * 0.3)]),
			PackedColorArray([Color(0.01, 0.02, 0.04, 0.85), Color(0.01, 0.02, 0.04, 0.85), Color(0.01, 0.02, 0.04, 0), Color(0.01, 0.02, 0.04, 0)]))
		draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.47), Vector2(size.x, size.y * 0.47), size, Vector2(0, size.y)]),
			PackedColorArray([Color(0.01, 0.02, 0.04, 0), Color(0.01, 0.02, 0.04, 0), Color(0.01, 0.02, 0.04, 0.97), Color(0.01, 0.02, 0.04, 0.97)]))
		if right_side:
			draw_line(Vector2.ZERO, Vector2(0, size.y), Color(accent, 0.35 + power * 0.5), 2)
		if has_focus():
			draw_line(copy.position - Vector2(0, 10), copy.position + Vector2(72, -10), Color("#F3ECD6"), 3)
	func _ready() -> void:
		resized.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func fit_copy() -> void:
		# Wrapped labels briefly report tall minimums before their first layout.
		# Shrink the free-standing column when its real minimum settles.
		copy.size.y = 0.0

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	_wash = ColorRect.new()
	_wash.color = Color("#050B18")
	_wash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_title = UI.label("CHOOSE YOUR SIDE", 28, Color("#F3ECD6"), true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_subtitle = UI.label("One identity. Two operating systems.", 24, BLUE)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_subtitle)
	for index: int in 2:
		var band: ModeBand = ModeBand.new()
		band.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		band.name = "SoloSide" if index == 0 else "PvpSide"
		band.right_side = index == 1
		band.accent = BLUE if index == 0 else RED
		band.art = AssetManager.get_texture("ui_dashboard_scenic" if index == 0 else "ui_dashboard_pvp")
		band.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		band.tooltip_text = "Select Solo campaign" if index == 0 else "Select PvP command center"
		for state: String in ["normal", "hover", "pressed", "focus"]:
			band.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_child(band)
		band.copy = VBoxContainer.new()
		band.copy.mouse_filter = MOUSE_FILTER_IGNORE
		band.copy.add_theme_constant_override("separation", 8)
		band.add_child(band.copy)
		band.tag = UI.label("", 20, band.accent)
		band.heading = UI.label("SOLO" if index == 0 else "PVP", 42, Color("#F3ECD6"), true)
		band.description = UI.label("Learn. Investigate. Defend.\nYour campaign, your pace." if index == 0 else "Enter the rival network.\nPlayer-versus-player command.", 24)
		band.copy.add_child(band.tag)
		band.copy.add_child(band.heading)
		band.copy.add_child(band.description)
		band.copy.minimum_size_changed.connect(band.fit_copy)
		band.pressed.connect(_select_mode.bind(index as Mode))
		_bands.append(band)
	# Headings and footer float above the full-bleed selectable artwork.
	move_child(_title, get_child_count() - 1)
	move_child(_subtitle, get_child_count() - 1)
	_confirm = UI.button("CONFIRM SOLO", _confirm_selection, true)
	_confirm.name = "ConfirmMode"
	add_child(_confirm)
	_cancel = UI.button("CANCEL", close)
	add_child(_cancel)
	var focus_order: Array[Control] = [_bands[0], _bands[1], _confirm, _cancel]
	for index: int in focus_order.size():
		var control: Control = focus_order[index]
		control.focus_next = control.get_path_to(focus_order[(index + 1) % focus_order.size()])
		control.focus_previous = control.get_path_to(focus_order[(index + focus_order.size() - 1) % focus_order.size()])
		control.focus_neighbor_bottom = control.focus_next
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_right = control.focus_next
	resized.connect(_layout)
	AssetManager.sync_finished.connect(_refresh_art)
	_layout.call_deferred()

func _refresh_art(_success: bool = true) -> void:
	for index: int in _bands.size():
		_bands[index].art = AssetManager.get_texture("ui_dashboard_scenic" if index == 0 else "ui_dashboard_pvp")
		_bands[index].queue_redraw()

func open(initial_mode: Mode = Mode.SOLO, _viewport_width: float = 1280.0) -> void:
	_stop_motion()
	var focused: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	selected_mode = initial_mode
	_refresh_art()
	visible = true
	modulate.a = 1.0
	_refresh_selection(false)
	_layout()
	_bands[int(initial_mode)].grab_focus()
	if not SettingsService.reduced_motion:
		modulate.a = 0.0
		_motion = create_tween()
		_motion.tween_property(self, "modulate:a", 1.0, 0.22)

func close() -> void:
	if not visible:
		return
	_stop_motion()
	hide()
	_restore_focus()
	cancelled.emit()

func dismiss() -> void:
	_stop_motion()
	hide()

func get_mode_name() -> StringName:
	return &"SOLO" if selected_mode == Mode.SOLO else &"PVP"

func _select_mode(mode: Mode) -> void:
	if not visible:
		return
	selected_mode = mode
	_refresh_selection(true)

func _refresh_selection(animate: bool) -> void:
	_stop_motion()
	modulate.a = 1.0
	var accent: Color = BLUE if selected_mode == Mode.SOLO else RED
	_confirm.text = "CONFIRM " + String(get_mode_name())
	_confirm.add_theme_stylebox_override("normal", UI.box(accent.darkened(0.72), accent, 14))
	_confirm.add_theme_color_override("font_color", Color("#F3ECD6"))
	for state: String in ["hover", "pressed"]:
		_confirm.add_theme_stylebox_override(state, UI.box(accent, Color("#F3ECD6"), 14))
	_subtitle.add_theme_color_override("font_color", accent)
	var target: Color = Color("#061528") if selected_mode == Mode.SOLO else Color("#1B080F")
	if animate and not SettingsService.reduced_motion:
		_motion = create_tween().set_parallel(true)
		_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_motion.tween_property(_wash, "color", target, 0.28)
	else:
		_wash.color = target
	for index: int in _bands.size():
		var active: bool = index == int(selected_mode)
		var band: ModeBand = _bands[index]
		band.tag.text = ("SELECTED / " if active else "SELECT / ") + ("BLUE OS" if index == 0 else "RED OS")
		if animate and not SettingsService.reduced_motion:
			_motion.tween_property(band, "power", 1.0 if active else 0.0, 0.28)
		else:
			band.power = 1.0 if active else 0.0

func _confirm_selection() -> void:
	if not visible:
		return
	_stop_motion()
	hide()
	_restore_focus()
	mode_confirmed.emit(get_mode_name())

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _restore_focus() -> void:
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree():
			previous.grab_focus()

func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null

func _exit_tree() -> void:
	_stop_motion()

func _layout() -> void:
	if not is_inside_tree() or _confirm == null:
		return
	var physical: float = maxf(0.4, float(get_window().size.y) / get_viewport_rect().size.y)
	var readable: int = maxi(24, ceili(16.0 / physical))
	var inset: float = size.x * 0.055
	_title.position = Vector2(inset, size.y * 0.065)
	_title.size = Vector2(size.x - inset * 2, 46)
	_title.add_theme_font_size_override("font_size", maxi(28, ceili(19.0 / physical)))
	_subtitle.position = Vector2(inset, size.y * 0.125)
	_subtitle.size = Vector2(size.x - inset * 2, 40)
	_subtitle.add_theme_font_size_override("font_size", readable)
	for index: int in 2:
		var band: ModeBand = _bands[index]
		band.position = Vector2(size.x * 0.5 * index, 0)
		band.size = Vector2(size.x * 0.5, size.y)
		band.copy.position = Vector2(inset, size.y * 0.57)
		band.copy.size = Vector2(band.size.x - inset * 2, 0)
		band.tag.add_theme_font_size_override("font_size", maxi(20, ceili(14.0 / physical)))
		band.heading.add_theme_font_size_override("font_size", maxi(48, ceili(26.0 / physical)))
		band.description.add_theme_font_size_override("font_size", readable)
	var height: float = maxf(56, 44.0 / physical)
	_cancel.position = Vector2(inset, size.y * 0.85)
	_cancel.size = Vector2(size.x * 0.21, height)
	_confirm.position = Vector2(size.x * 0.53, size.y * 0.85)
	_confirm.size = Vector2(size.x * 0.415, height)
	_confirm.add_theme_font_size_override("font_size", readable)
	_cancel.add_theme_font_size_override("font_size", readable)
