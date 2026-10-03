extends VBoxContainer
## Presentation only: authored positions, native touch scrolling, bounded zoom.
signal step_selected(index: int, step: int)
signal checkpoint_requested
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const PathNode = preload("res://src/ui/screens/intel/lesson_path_node.gd")
const WORLD: Vector2 = Vector2(1480, 720)
const HUB: Vector2 = Vector2(740, 350)
const POINTS: Array[Vector2] = [Vector2(220, 190), Vector2(740, 80), Vector2(1260, 190), Vector2(1260, 510), Vector2(740, 620), Vector2(220, 510)]
const SATELLITES: Array[Vector2] = [Vector2(72, 112), Vector2(200, 0), Vector2(72, 112), Vector2(72, 112), Vector2(200, 0), Vector2(72, 112)]
var nodes: Array[Button] = []
var _scroll: ScrollContainer
var _extent: Control
var _canvas: WebCanvas
var _zoom: float = 0.75
var _preferred_zoom: float = 0.75
var _focus: int = 0
var _reveal: Tween
var _checkpoint: Button
var _zoom_label: Label
var _toolbar: HBoxContainer
var _hint: Label
var _celebration: Tween

class CheckpointNode extends Button:
	var ready_for_test: bool = false
	var passed: bool = false
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var color: Color = Color("#33D17A") if passed else Color("#4FE0D4")
		if not ready_for_test:
			color = Color("#335074")
		var points: PackedVector2Array = []
		for i: int in 6:
			points.append(center + Vector2.from_angle(TAU * float(i) / 6 - PI / 6) * 118)
		draw_colored_polygon(points, Color("#0E2A28") if ready_for_test else Color("#0A1730"))
		points.append(points[0])
		draw_polyline(points, Color(color, 0.12), 12)
		draw_polyline(points, color, 2)
		if has_focus() or is_hovered():
			draw_arc(center, 124, 0, TAU, 48, Color("#FFB648"), 2)
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

class WebCanvas extends Control:
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()
	var progress: int = 0
	var pulse: float = -1.0:
		set(value):
			pulse = value
			queue_redraw()
	var from_index: int = 0
	var ready_for_test: bool = false
	var passed: bool = false
	var clock: float = 0.0
	func sequence_point(index: int, amount: float) -> Vector2:
		var target: Vector2 = POINTS[index + 1] if index < 5 else HUB
		var point: Vector2 = POINTS[index].lerp(target, amount)
		# Bow the upper routes below the two labels beside lesson 2.
		if index < 2:
			point.y += sin(amount * PI) * 65.0
		return point
	func _process(delta: float) -> void:
		if ready_for_test and is_visible_in_tree() and not SettingsService.reduced_motion:
			clock += delta
			queue_redraw()
	func _draw() -> void:
		for x: int in range(20, int(WORLD.x), 40):
			for y: int in range(20, int(WORLD.y), 40):
				draw_rect(Rect2(x, y, 2, 2), Color("#173058"))
		var hub_ink: Color = Color("#33D17A") if passed else Color("#4FE0D4")
		for i: int in POINTS.size():
			var target: Vector2 = HUB.lerp(POINTS[i], reveal)
			if ready_for_test:
				draw_line(HUB, target, Color(hub_ink, 0.08), 12)
				draw_line(HUB, target, Color(hub_ink, 0.2), 6)
				draw_line(HUB, target, hub_ink, 2)
				if not SettingsService.reduced_motion and not passed:
					var travel: float = fmod(clock * 0.35, 1.0)
					var spark: Vector2 = target.lerp(HUB, travel)
					draw_circle(spark, 7, Color(hub_ink, 0.2))
					draw_circle(spark, 3, hub_ink)
			else:
				draw_line(HUB, target, Color("#173058"), 1)
			if i < 5:
				var color: Color = Color("#33D17A") if i < progress else Color("#335074")
				var route: PackedVector2Array = []
				for n: int in 25:
					route.append(sequence_point(i, float(n) / 24.0 * reveal))
				draw_polyline(route, color, 3)
				var arrow: Vector2 = sequence_point(i, 0.5)
				var direction: Vector2 = (sequence_point(i, 0.52) - sequence_point(i, 0.48)).normalized()
				draw_polyline(PackedVector2Array([arrow - direction.rotated(-0.6) * 12, arrow, arrow - direction.rotated(0.6) * 12]), color, 3)
			for step: int in [1, 2]:
				draw_line(target, target + SATELLITES[i] * Vector2(-1 if step == 1 else 1, 1) * reveal, Color("#33D17A") if i < progress else Color("#335074"), 2)
		draw_arc(HUB, 132, 0, TAU, 48, Color(hub_ink, 0.25) if ready_for_test else Color("#173058"), 2)
		for i: int in 6:
			var indicator: Vector2 = HUB + Vector2.from_angle(TAU * float(i) / 6 - PI / 2) * 142
			draw_circle(indicator, 5, hub_ink if i < progress else Color("#173058"))
		if reveal < 1:
			for i: int in 16:
				var p: Vector2 = HUB + Vector2.from_angle(TAU * float(i) / 16) * (40 + reveal * 210)
				draw_rect(Rect2(p, Vector2(7, 7)), Color(0.31, 0.88, 0.83, 1.0 - reveal))
		if pulse >= 0.0:
			var position_on_path: Vector2 = sequence_point(from_index, pulse)
			draw_circle(position_on_path, 12, Color("#4FE0D4"))
			draw_circle(position_on_path, 5, Color("#F3ECD6"))

func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var tools_row: HBoxContainer = HBoxContainer.new()
	_toolbar = tools_row
	add_child(tools_row)
	_hint = UI.label("LEARN  /  QUIZ  /  SIMULATE", 22, Color("#8FF0E6"))
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tools_row.add_child(_hint)
	tools_row.add_theme_constant_override("separation", 12)
	tools_row.add_child(UI.button("FOCUS", focus_current))
	var minus: Button = UI.button("-", change_zoom.bind(-0.15))
	minus.custom_minimum_size.x = 56
	tools_row.add_child(minus)
	_zoom_label = UI.label("100%", 22)
	_zoom_label.custom_minimum_size.x = 80
	_zoom_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tools_row.add_child(_zoom_label)
	var plus: Button = UI.button("+", change_zoom.bind(0.15))
	plus.custom_minimum_size.x = 56
	tools_row.add_child(plus)
	_scroll = ScrollContainer.new()
	_scroll.name = "WebViewport"
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_extent = Control.new()
	_extent.size_flags_horizontal = SIZE_EXPAND_FILL
	_extent.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.add_child(_extent)
	_canvas = WebCanvas.new()
	_canvas.mouse_filter = MOUSE_FILTER_IGNORE
	_canvas.size = WORLD
	_extent.add_child(_canvas)
	resized.connect(func() -> void:
		_fit_zoom()
		focus_current.call_deferred()
	)
	_fit_zoom.call_deferred()

func configure(module_id: String, lessons: Array[Dictionary], progress: int, selected: int, checks: Array[bool], tutorial: bool, passed: bool) -> void:
	if _reveal != null:
		_reveal.kill()
	if _celebration != null:
		_celebration.kill()
	UI.clear(_canvas)
	nodes.clear()
	_canvas.progress = progress
	_canvas.ready_for_test = progress >= lessons.size() and not tutorial
	_canvas.passed = passed
	_canvas.clock = 0
	_canvas.pulse = -1
	_canvas.reveal = 1.0
	_focus = selected
	_hint.text = "POST-TEST PASSED  /  MODULE COMPLETE" if passed else ("6 / 6 COMPLETE  /  POST-TEST READY" if _canvas.ready_for_test else "%d / 6 COMPLETE  /  FOLLOW THE LIT PATH" % progress)
	_checkpoint = CheckpointNode.new()
	(_checkpoint as CheckpointNode).ready_for_test = _canvas.ready_for_test
	(_checkpoint as CheckpointNode).passed = passed
	_checkpoint.pressed.connect(func() -> void: checkpoint_requested.emit())
	_checkpoint.name = "ModuleCheckpoint"
	_checkpoint.position = HUB - Vector2(120, 120)
	_checkpoint.size = Vector2(240, 240)
	_checkpoint.disabled = progress < lessons.size() or tutorial
	_checkpoint.tooltip_text = "25 questions / 20 correct to pass" if _canvas.ready_for_test else "Finish every lesson, quiz and simulation to unlock the post-test."
	_checkpoint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_checkpoint.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_canvas.add_child(_checkpoint)
	var hub_label: Label = UI.label("MODULE %s\nPOST-TEST\n\n%s" % [module_id.right(2), "PASSED" if passed else ("READY / ENTER" if _canvas.ready_for_test else "%d / 6 COMPLETE" % progress)], 24, Color("#F3ECD6") if _canvas.ready_for_test else UI.MUTED)
	_checkpoint.add_child(hub_label)
	hub_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_label.offset_left = 18
	hub_label.offset_right = -18
	hub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for i: int in lessons.size():
		var finished: bool = i < progress
		var locked: bool = i > progress or (tutorial and i != 0)
		var learn: Button = UI.button("%02d / %s" % [i + 1, str(lessons[i].title)], _select_step.bind(i, 0))
		learn.name = "Lesson%d" % (i + 1)
		learn.size = Vector2(270, 96)
		learn.position = POINTS[i] - learn.size * 0.5
		learn.disabled = locked
		var color: Color = Color("#33D17A") if finished else (Color("#4FE0D4") if i == selected else Color("#335074"))
		var style: StyleBoxFlat = UI.box(Color("#0E2A28") if finished else Color("#102040"), color, 12)
		style.set_corner_radius_all(8)
		style.border_width_left = 5
		style.shadow_color = Color(color, 0.25)
		style.shadow_size = 7 if i == selected else 0
		learn.add_theme_stylebox_override("normal", style)
		var locked_style: StyleBoxFlat = UI.box(Color("#0A1730"), Color("#173058"), 12)
		locked_style.set_corner_radius_all(8)
		locked_style.border_width_left = 5
		learn.add_theme_stylebox_override("disabled", locked_style)
		learn.tooltip_text = "Complete lesson %d first" % i if locked else "Read definitions and examples"
		_canvas.add_child(learn)
		nodes.append(learn)
		for step: int in [1, 2]:
			var node: Button = PathNode.new()
			node.name = "Lesson%dStep%d" % [i + 1, step]
			node.set("kind", step)
			var complete: bool = finished or (i == selected and checks[step])
			node.set("complete", complete)
			node.disabled = locked or (not finished and (i != selected or not checks[step - 1]))
			node.set("ink", Color("#33D17A") if complete else (UI.MUTED if node.disabled else Color("#4FE0D4")))
			node.size = Vector2(72, 72)
			node.position = POINTS[i] + SATELLITES[i] * Vector2(-1 if step == 1 else 1, 1) - node.size * 0.5
			var node_style: StyleBoxFlat = UI.box(Color("#153B37") if complete else Color("#102040"), Color("#33D17A") if complete else Color("#4FE0D4"), 4)
			node_style.set_corner_radius_all(36)
			node.add_theme_stylebox_override("normal", node_style)
			node.add_theme_stylebox_override("hover", UI.box(Color("#173058"), Color("#FFB648"), 4))
			var locked_node_style: StyleBoxFlat = UI.box(Color("#0A1730"), Color("#173058"), 4)
			locked_node_style.set_corner_radius_all(36)
			node.add_theme_stylebox_override("disabled", locked_node_style)
			node.pressed.connect(_select_step.bind(i, step))
			node.tooltip_text = "Mini quiz" if step == 1 else "Simulation"
			_canvas.add_child(node)
			var label: Label = UI.label("Quiz" if step == 1 else "Simulation", 22, UI.MUTED if node.disabled else Color("#8FF0E6"))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.position = node.position + Vector2(-24, 78)
			label.size = Vector2(120, 32)
			_canvas.add_child(label)
	_fit_zoom()
	_canvas.queue_redraw()

func _select_step(index: int, step: int) -> void:
	step_selected.emit(index, step)

func reveal_web() -> void:
	if SettingsService.reduced_motion:
		_canvas.reveal = 1.0
		return
	_canvas.reveal = 0.0
	_reveal = create_tween()
	_reveal.tween_property(_canvas, "reveal", 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for child: Node in _canvas.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		var destination: Vector2 = control.position
		control.position = HUB - control.size * 0.5
		control.modulate.a = 0
		_reveal.parallel().tween_property(control, "position", destination, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_reveal.parallel().tween_property(control, "modulate:a", 1.0, 0.45)

func celebrate(index: int) -> void:
	if SettingsService.reduced_motion:
		focus_current()
		return
	_canvas.from_index = index
	_canvas.pulse = 0
	if _celebration != null:
		_celebration.kill()
	_celebration = create_tween()
	_celebration.tween_property(_canvas, "pulse", 1.0, 0.85)
	_celebration.tween_callback(func() -> void:
		_canvas.pulse = -1
		focus_current()
	)

func _fit_zoom() -> void:
	if _canvas == null:
		return
	# 72px satellites and 22px labels remain >=48px and >=16px on-device.
	var physical: float = maxf(0.25, minf(float(get_window().size.x) / get_viewport_rect().size.x, float(get_window().size.y) / get_viewport_rect().size.y))
	_zoom = clampf(_preferred_zoom, maxf(0.75, 16.0 / (22.0 * physical)), 2.5)
	_canvas.scale = Vector2.ONE * _zoom
	_extent.custom_minimum_size = WORLD * _zoom
	_zoom_label.text = "%d%%" % roundi(_zoom * 100)
	UI.fit_touch(_toolbar)
	_center_canvas.call_deferred()

func _center_canvas() -> void:
	_canvas.position.x = maxf(0, (_extent.size.x - WORLD.x * _zoom) * 0.5)
	_canvas.position.y = maxf(0, (_extent.size.y - WORLD.y * _zoom) * 0.5)

func change_zoom(delta: float) -> void:
	_preferred_zoom = _zoom + delta
	_fit_zoom()
	focus_current.call_deferred()

func focus_current() -> void:
	if _canvas == null:
		return
	_center_canvas()
	var point: Vector2 = (HUB if _canvas.ready_for_test else POINTS[clampi(_focus, 0, 5)]) * _zoom + _canvas.position
	_scroll.scroll_horizontal = maxi(0, roundi(point.x - _scroll.size.x * 0.5))
	_scroll.scroll_vertical = maxi(0, roundi(point.y - _scroll.size.y * 0.5))
