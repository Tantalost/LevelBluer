extends Control
## Reusable five-topic radar. Missing values never become zero-score vertices.
signal topic_selected(index: int)
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var rows: Array = []
var selected := 0
var font_size := 26
var touch_height := 64.0
var _labels: Array[Button] = []
var _vertices := PackedVector2Array()

func _ready() -> void:
	custom_minimum_size = Vector2(360, 500)
	mouse_filter = MOUSE_FILTER_PASS
	resized.connect(_layout_labels)
	for i in 5:
		var button := UI.button("", _select.bind(i))
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", UI.box(Color("203c45"), UI.TEAL, 4))
		button.add_theme_color_override("font_hover_color", UI.TEXT)
		button.mouse_filter = MOUSE_FILTER_PASS
		add_child(button)
		_labels.append(button)
	_layout_labels()

func configure(data: Array, selection: int) -> void:
	rows = data.duplicate(true)
	selected = clampi(selection, 0, 4)
	if is_node_ready():
		_layout_labels()
	queue_redraw()

func _center() -> Vector2:
	return size * Vector2(0.5, 0.55)

func _radius() -> float:
	return maxf(35, minf((size.x - 220) * 0.5, size.y * 0.28))

func _direction(index: int) -> Vector2:
	return Vector2.from_angle(-PI * 0.5 + TAU * index / 5.0)

func _layout_labels() -> void:
	if _labels.size() != 5:
		return
	for i in 5:
		var label := _labels[i]
		label.add_theme_font_size_override("font_size", font_size)
		label.custom_minimum_size = Vector2(150, touch_height)
		label.size = Vector2(maxf(160, font_size * 6.1), maxf(touch_height, font_size * 2.7))
		var pos := _center() + _direction(i) * (_radius() + 64) - label.size * 0.5
		label.position = pos.clamp(Vector2.ZERO, (size - label.size).max(Vector2.ZERO))
		label.add_theme_color_override("font_color", UI.TEAL if i == selected else UI.TEXT)
		if i < rows.size():
			label.text = "%s\n%s" % [rows[i].name, ("%d%%" % roundi(float(rows[i].value) * 100)) if rows[i].assessed else "Not assessed"]
	queue_redraw()

func _draw() -> void:
	if rows.size() != 5:
		return
	var center := _center()
	var radius := _radius()
	var all_assessed := true
	_vertices.clear()
	for i in 5:
		var end := center + _direction(i) * radius
		if rows[i].assessed:
			draw_line(center, end, Color("3b626a"), 1.5, true)
		else:
			all_assessed = false
			draw_dashed_line(center, end, Color("3b626a"), 1.5, 6, true)
		_vertices.append(center + _direction(i) * radius * float(rows[i].value))
	for ring in range(1, 6):
		var polygon := PackedVector2Array()
		for i in 6:
			polygon.append(center + _direction(i % 5) * radius * ring / 5.0)
		draw_polyline(polygon, Color("34515b"), 1.5, true)
		# Top label has reserved space above the plot, including on short phones.
		var tick := center + Vector2(8, -radius * ring / 5.0 + 6)
		var tick_size := maxi(20, font_size - 6)
		draw_rect(Rect2(tick + Vector2(-1, -tick_size + 4), Vector2(tick_size * 1.6, tick_size)), UI.BG)
		draw_string(UI.FONT, tick, "%d" % (ring * 20), HORIZONTAL_ALIGNMENT_LEFT, -1, tick_size, UI.MUTED)
	if all_assessed:
		# All-zero measured data has no area and cannot be triangulated.
		var area := 0.0
		for i in 5:
			area += _vertices[i].cross(_vertices[(i + 1) % 5])
		if absf(area) > 0.1:
			draw_colored_polygon(_vertices, Color(UI.TEAL, 0.22))
	for i in 5:
		var next := (i + 1) % 5
		if rows[i].assessed and rows[next].assessed:
			draw_line(_vertices[i], _vertices[next], UI.TEAL, 3, true)
		if rows[i].assessed:
			draw_circle(_vertices[i], 6, UI.TEAL, true, -1, true)
			if i == selected:
				draw_circle(_vertices[i], 11, UI.GOLD, false, 2, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_select_at(event.position)

func _select_at(point: Vector2) -> void:
	var closest := -1
	var distance := touch_height * 0.5
	for i in _vertices.size():
		if rows[i].assessed and point.distance_to(_vertices[i]) < distance:
			distance = point.distance_to(_vertices[i])
			closest = i
	if closest >= 0:
		_select(closest)

func _select(index: int) -> void:
	selected = index
	_layout_labels()
	topic_selected.emit(index)
