extends Control
## Presentation only: emits intents, never grades or charges gold.
signal action(id: String, value: Variant)
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Quiz = preload("res://src/gameplay/quiz_content.gd")
const Battle = preload("res://src/gameplay/preview/battle_view.gd")
const Meter = preload("res://src/gameplay/preview/animated_meter.gd")
const Glyph = preload("res://src/gameplay/preview/tower_glyph.gd")
const ResourceIcon = preload("res://src/gameplay/preview/resource_icon.gd")
var battle: SubViewportContainer
var status: Label
var gold_label: Label
var health_label: Label
var health_icon: Control
var phase_label: Label
var preview_label: Label
var wave_progress: ProgressBar
var speed_button: Button
var start_button: Button
var body: Control
var side: PanelContainer
var side_content: VBoxContainer
var side_actions: VBoxContainer
var workspace: PanelContainer
var quiz_timer: ProgressBar
var quiz_time: Label
var quiz_progress: Label
var scenario: VBoxContainer
var answers: VBoxContainer
var feedback: Label
var submit: Button
var option_buttons: Array[Button] = []
var modal: PanelContainer
var modal_title: Label
var _row: HBoxContainer
var font_size := 26
var touch := 64.0
var intro: PanelContainer
var intro_title: Label
var intro_count: Label
var intro_meter: ProgressBar
var _intro_number := ""
var _intro_tween: Tween
var _footer: HBoxContainer
var _stat_labels: Dictionary = {}
var _upgrade_meter: ProgressBar
var result_overlay: CanvasLayer
var tower_grid: GridContainer
var build_details: PanelContainer
var build_content: VBoxContainer
var build_actions: VBoxContainer
var _phase_tween: Tween
var _shown_phase := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0c1419")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	var safe := SafeAreaContainer.new()
	safe.extra_margin = 12
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var layout := UI.column(safe, 8)
	var top := UI.panel(layout, Color("132127"))
	top.add_theme_stylebox_override("panel", UI.box(Color("132127"), Color("30494d"), 10))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	top.add_child(header)
	status = UI.label("")
	status.size_flags_horizontal = SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(status)
	gold_label = _resource_badge(header, "gold", UI.GOLD)
	health_label = _resource_badge(header, "health", Color("a3deb2"))
	speed_button = button("1x", "speed")
	speed_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(speed_button)
	var pause_button := button("Pause", "pause")
	pause_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(pause_button)
	_crt(top)
	var phases := HBoxContainer.new()
	layout.add_child(phases)
	phase_label = UI.label("", 24, UI.TEAL)
	phase_label.set_meta("font_boost", 14)
	phase_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	phase_label.size_flags_horizontal = SIZE_EXPAND_FILL
	phases.add_child(phase_label)
	# A non-expanding, wrapping label has effectively no minimum width in an
	# HBox. It collapsed to one character and made this entire row screen-tall.
	preview_label = UI.label("PREVIEW / NOTHING SAVED", 22, UI.MUTED)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	phases.add_child(preview_label)
	wave_progress = Meter.new()
	wave_progress.show_percentage = false
	wave_progress.custom_minimum_size.y = 8
	wave_progress.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	layout.add_child(wave_progress)
	body = Control.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(body)
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", 12)
	body.add_child(_row)
	battle = Battle.new()
	battle.size_flags_horizontal = SIZE_EXPAND_FILL
	_row.add_child(battle)
	build_details = UI.panel(_row, Color("101e25"))
	build_details.custom_minimum_size.x = 310
	var build_layout := UI.column(build_details, 8)
	build_content = UI.scroll_column(build_layout)
	build_actions = UI.column(build_layout, 8)
	build_details.hide()
	side = UI.panel(_row)
	side.custom_minimum_size.x = 350
	var side_layout := UI.column(side, 10)
	side_content = UI.scroll_column(side_layout)
	side_actions = UI.column(side_layout, 8)
	side.hide()
	_crt(side)
	_build_workspace()
	var bottom := HBoxContainer.new()
	_footer = bottom
	layout.add_child(bottom)
	var recenter_button := button("Recenter", "recenter")
	recenter_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom.add_child(recenter_button)
	var hint := UI.label("Drag to pan / pinch or scroll to zoom", 24, UI.MUTED)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	start_button = button("Start wave >", "defend", null, true)
	start_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom.add_child(start_button)
	_build_intro()
	# The final viewport scale is updated after size_changed is emitted.
	get_viewport().size_changed.connect(_queue_responsive)
	_responsive()
	_queue_responsive()

func _queue_responsive() -> void:
	_responsive.call_deferred()

func _resource_badge(parent: Node, kind: String, color: Color) -> Label:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	parent.add_child(group)
	var icon := ResourceIcon.new()
	icon.kind = kind
	group.add_child(icon)
	if kind == "health":
		health_icon = icon
	var label := UI.label("", 26, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	group.add_child(label)
	return label

func update_resources(gold: int, health: int) -> void:
	gold_label.text = "GOLD %d" % gold
	health_label.text = "%d / 5" % health
	health_label.add_theme_color_override("font_color", Color("a3deb2") if health > 3 else (UI.GOLD if health > 1 else Color("ee8791")))
	health_icon.health = health
	health_icon.queue_redraw()

func button(copy: String, id: String, value: Variant = null, primary: bool = false) -> Button:
	var b := UI.button(copy, func() -> void: action.emit(id, value), primary)
	b.custom_minimum_size.y = touch
	b.add_theme_font_size_override("font_size", font_size)
	return b

func _responsive() -> void:
	var scale_y := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	font_size = maxi(26, ceili(16 / scale_y))
	touch = maxf(64, ceilf(48 / scale_y))
	side.custom_minimum_size.x = clampf(size.x * 0.30, 370, 440)
	build_details.custom_minimum_size.x = clampf(size.x * 0.24, 300, 350)
	_apply_metrics(self)

func _apply_metrics(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = 100 + font_size * 4 if node.get_meta("tower_card", false) else touch
		node.add_theme_font_size_override("font_size", font_size)
	elif node is Label:
		node.add_theme_font_size_override("font_size", font_size + int(node.get_meta("font_boost", 0)))
	for child in node.get_children():
		_apply_metrics(child)

func _build_workspace() -> void:
	workspace = UI.panel(body, Color("101c24"))
	workspace.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var layout := UI.column(workspace, 10)
	var timer_row := HBoxContainer.new()
	layout.add_child(timer_row)
	quiz_progress = UI.label("TRACE / QUESTION 1 OF 3")
	quiz_progress.size_flags_horizontal = SIZE_EXPAND_FILL
	timer_row.add_child(quiz_progress)
	quiz_time = UI.label("20s", 26, UI.GOLD)
	quiz_time.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_row.add_child(quiz_time)
	quiz_timer = Meter.new()
	quiz_timer.show_percentage = false
	quiz_timer.custom_minimum_size.y = 8
	quiz_timer.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	layout.add_child(quiz_timer)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(columns)
	var left := UI.panel(columns, Color("17282e"))
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.43
	scenario = UI.scroll_column(left)
	var right := UI.column(columns, 10)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.57
	answers = UI.scroll_column(right)
	submit = button("Submit answer", "submit", null, true)
	right.add_child(submit)
	_crt(workspace)
	workspace.hide()

func show_question(q: Dictionary, index: int, count: int) -> void:
	workspace.add_theme_stylebox_override("panel", UI.box(Color("101c24")))
	workspace.show()
	battle.modulate = Color(0.35, 0.35, 0.35)
	battle.enabled = false
	close_side()
	UI.clear(scenario)
	UI.clear(answers)
	option_buttons.clear()
	quiz_progress.text = "TRACE / %d OF %d  |  +5 correct / +2 miss" % [index, count]
	scenario.add_child(UI.label(str(q.get("type_id", "Scenario")).replace("_", " ").to_upper(), font_size, UI.TEAL))
	var copy: String = Quiz._format_scenario(q)
	scenario.add_child(UI.label(copy if not copy.is_empty() else "Consider the statement on the right. What would you do?", font_size))
	answers.add_child(UI.label(Quiz._format_prompt(q), font_size + 2))
	answers.add_child(UI.label("Select all that apply, then submit." if Quiz.is_multi(q) else "Choose an answer, then submit.", font_size, UI.MUTED))
	for row in Quiz.options(q):
		var b := button(str(row.text), "answer", row.value)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		answers.add_child(b)
		option_buttons.append(b)
	feedback = UI.label("", font_size)
	answers.add_child(feedback)
	submit.text = "Submit answer"
	submit.disabled = true
	(answers.get_parent() as ScrollContainer).scroll_vertical = 0
	(scenario.get_parent() as ScrollContainer).scroll_vertical = 0

func paint_selection(selected: Array) -> void:
	for i in option_buttons.size():
		var b := option_buttons[i]
		var on := selected.has(i)
		b.add_theme_stylebox_override("normal", UI.box(Color("285247") if on else UI.PANEL, UI.TEAL if on else Color("3b626a"), 12))
	submit.disabled = selected.is_empty()

func show_feedback(correct: bool, expired: bool, note: String) -> void:
	for b in option_buttons:
		b.disabled = true
	feedback.text = ("TIME EXPIRED / +2 gold\n" if expired else ("CORRECT / +5 gold\n" if correct else "INCORRECT / +2 gold\n")) + note
	feedback.add_theme_color_override("font_color", Color("a3deb2") if correct else Color("ed9999"))
	feedback.show()
	submit.text = "Continue >"
	submit.disabled = false
	var scroll := answers.get_parent() as ScrollContainer
	_scroll_feedback.call_deferred(scroll, feedback)
	workspace.add_theme_stylebox_override("panel", UI.box(Color("14271f") if correct else Color("2d1e25"), Color("91cda6") if correct else Color("d88d8d"), 18))
	if not correct:
		var tween := create_tween()
		for shift in [4.0, -4.0, 2.0, -2.0, 0.0]:
			tween.tween_property(workspace, "position:x", shift, 0.045)

func hide_quiz() -> void:
	workspace.hide()
	workspace.add_theme_stylebox_override("panel", UI.box(Color("101c24")))
	battle.modulate = Color.WHITE
	battle.enabled = true

func close_side() -> void:
	side.hide()
	build_details.hide()
	_stat_labels.clear()

func open_side(title: String, description: String, choices: Array, actions: Array) -> void:
	build_details.hide()
	_stat_labels.clear()
	UI.clear(side_content)
	UI.clear(side_actions)
	side_content.add_child(UI.label(title, font_size + 2, UI.TEAL))
	side_content.add_child(UI.label(description, font_size))
	for row in choices:
		var b := button(row.text, row.id, row.get("value"))
		b.disabled = row.get("disabled", false)
		side_content.add_child(b)
	for row in actions:
		var b := button(row.text, row.id, row.get("value"), row.get("primary", false))
		b.disabled = row.get("disabled", false)
		side_actions.add_child(b)
	side.show()

func set_phase(phase: String) -> void:
	if phase == _shown_phase:
		return
	_shown_phase = phase
	phase_label.text = phase.to_upper() + (" PHASE" if phase in ["Trace", "Build", "Defend"] else "")
	phase_label.add_theme_color_override("font_color", UI.GOLD if phase == "Defend" else UI.TEAL)
	_footer.visible = phase in ["Build", "Defend"]
	if _phase_tween != null:
		_phase_tween.kill()
	phase_label.modulate.a = 0.35
	_phase_tween = create_tween()
	_phase_tween.tween_property(phase_label, "modulate:a", 1.0, 0.3)

func _build_intro() -> void:
	intro = UI.panel(body, Color("101e25"))
	intro.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	intro.add_child(center)
	var column := UI.column(center, 12)
	column.custom_minimum_size.x = 420
	var level := UI.label("MODULE 01  /  STAGE 01", font_size, UI.TEAL)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(level)
	intro_title = UI.label("", font_size + 16)
	intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_title.set_meta("font_boost", 16)
	column.add_child(intro_title)
	intro_count = UI.label("GET READY", font_size + 30, UI.GOLD)
	intro_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_count.set_meta("font_boost", 30)
	column.add_child(intro_count)
	intro_meter = Meter.new()
	intro_meter.custom_minimum_size.y = 8
	intro_meter.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	column.add_child(intro_meter)
	_crt(intro)
	intro.hide()

func show_intro(stage_name: String, elapsed: float) -> void:
	intro.show()
	intro_title.text = stage_name
	battle.enabled = false
	intro_meter.set_progress(minf(elapsed, 4), 4, true)
	var next := "GET READY" if elapsed < 1 else str(maxi(1, 3 - int(elapsed - 1)))
	if next != _intro_number:
		_intro_number = next
		intro_count.text = next
		if _intro_tween != null:
			_intro_tween.kill()
		intro_count.modulate.a = 0.25
		_intro_tween = create_tween()
		_intro_tween.tween_property(intro_count, "modulate:a", 1.0, 0.18)

func hide_intro() -> void:
	intro.hide()

func show_build_picker(choices: Array, cell: Vector2i, selected: String = "", detail: Dictionary = {}) -> void:
	close_side()
	UI.clear(side_content)
	UI.clear(side_actions)
	side_content.add_child(UI.label("PLATFORM / %02d:%02d" % [cell.x + 1, cell.y + 1], font_size, UI.TEAL))
	side_content.add_child(UI.label("One tile. One defender.\nChoose a tower to inspect.", font_size, UI.MUTED))
	side_content.add_child(UI.label("TOWERS / REMAINING", font_size, UI.TEAL))
	tower_grid = GridContainer.new()
	tower_grid.columns = 3
	tower_grid.add_theme_constant_override("h_separation", 6)
	tower_grid.add_theme_constant_override("v_separation", 6)
	side_content.add_child(tower_grid)
	for row in choices:
		_add_tower_card(row, str(row.value) == selected)
	side_actions.add_child(button("Cancel placement", "cancel"))
	side.show()
	if selected.is_empty():
		return
	UI.clear(build_content)
	UI.clear(build_actions)
	build_content.add_child(UI.label(str(detail.name).to_upper(), font_size, UI.TEAL))
	var icon := Glyph.new()
	icon.kind = selected
	icon.custom_minimum_size.y = 74
	build_content.add_child(icon)
	build_content.add_child(UI.label(str(detail.description), font_size))
	for stat in detail.stats:
		build_content.add_child(UI.label(str(stat.text), font_size))
		var meter := Meter.new()
		meter.custom_minimum_size.y = 8
		meter.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
		build_content.add_child(meter)
		meter.set_progress(float(stat.value), float(stat.maximum))
	build_content.add_child(UI.label("%d of %d available" % [detail.remaining, detail.capacity], font_size, UI.TEAL))
	build_content.add_child(UI.label(str(detail.reason) if not str(detail.reason).is_empty() else "Range shown on the map. Place to confirm.", font_size, Color("ee8791") if not str(detail.reason).is_empty() else UI.MUTED))
	var place := button("Place / %d gold" % detail.cost, "place", null, true)
	place.disabled = not str(detail.reason).is_empty()
	build_actions.add_child(place)
	build_details.show()

func _add_tower_card(row: Dictionary, selected: bool) -> void:
	var card := button("", row.id, row.get("value"))
	card.set_meta("tower_card", true)
	card.custom_minimum_size = Vector2(0, 100 + font_size * 4)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var available := int(row.remaining) > 0 and bool(row.affordable)
	card.add_theme_stylebox_override("normal", UI.box(Color("254944") if selected else (UI.PANEL if available else Color("111b22")), UI.TEAL if selected else Color("30454d"), 4))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 8
	column.offset_bottom = -8
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(column)
	var icon := Glyph.new()
	icon.kind = str(row.value)
	icon.custom_minimum_size.y = 66
	icon.modulate = Color.WHITE if available else Color("7f9699")
	column.add_child(icon)
	var title := UI.label(str(row.name), font_size)
	title.custom_minimum_size.y = font_size * 2 + 4
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var count := UI.label("%d left" % int(row.remaining), font_size, UI.TEAL if int(row.remaining) > 0 else Color("ee8791"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(count)
	var cost := UI.label("%d G" % int(row.cost), font_size, UI.GOLD if bool(row.affordable) else Color("ee8791"))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(cost)
	tower_grid.add_child(card)

func show_tower_details(data: Dictionary, actions: Array) -> void:
	build_details.hide()
	UI.clear(side_content)
	UI.clear(side_actions)
	_stat_labels.clear()
	side_content.add_theme_constant_override("separation", 8)
	var identity := HBoxContainer.new()
	side_content.add_child(identity)
	var icon := Glyph.new()
	icon.kind = data.kind
	icon.custom_minimum_size = Vector2(64, 64)
	identity.add_child(icon)
	var title := _detail_label(identity, "title", UI.TEAL)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	side_content.add_child(UI.label("CHARACTERISTICS", font_size, UI.TEAL))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	side_content.add_child(grid)
	for key in ["range", "damage", "rate", "rotation", "projectile", "multiplier"]:
		var panel := UI.panel(grid, Color("101e25"))
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UI.box(Color("101e25"), Color("30494d"), 8))
		_detail_label(panel, key)
	_detail_label(side_content, "totals", UI.GOLD)
	_upgrade_meter = Meter.new()
	_upgrade_meter.custom_minimum_size.y = 10
	_upgrade_meter.add_theme_stylebox_override("fill", UI.box(UI.GOLD, UI.GOLD, 0))
	side_content.add_child(_upgrade_meter)
	_detail_label(side_content, "upgrades", UI.MUTED)
	_detail_label(side_content, "tile", UI.MUTED)
	side_content.add_child(UI.label("ABILITIES & EFFECTS", font_size, UI.TEAL))
	_detail_label(side_content, "effects")
	_detail_label(side_content, "next", UI.GOLD)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 8)
	for row in actions:
		var b := button(row.text, row.id, null, row.get("primary", false))
		b.disabled = row.get("disabled", false)
		if row.id == "upgrade":
			side_actions.add_child(b)
		else:
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			secondary.add_child(b)
	side_actions.add_child(secondary)
	side.show()
	update_tower_details(data)

func _detail_label(parent: Node, key: String, color: Color = UI.TEXT) -> Label:
	var label := UI.label("", font_size, color)
	parent.add_child(label)
	_stat_labels[key] = label
	return label

func update_tower_details(data: Dictionary) -> void:
	if _stat_labels.is_empty():
		return
	for key in _stat_labels:
		_stat_labels[key].text = str(data.get(key, ""))
	_upgrade_meter.set_progress(float(data.level), float(data.max_level))

func show_results(data: Dictionary) -> void:
	close_modal()
	close_side()
	for control in body.get_parent().get_children():
		if control != body:
			control.hide()
	result_overlay = preload("res://src/gameplay/preview/preview_result_overlay.gd").new()
	add_child(result_overlay)
	result_overlay.configure(data)
	result_overlay.action_requested.connect(func(id: StringName) -> void: action.emit("retry" if id == &"restart" else "exit", null))

func show_modal(title: String, copy: String, actions: Array) -> void:
	close_modal()
	modal = UI.panel(body, Color("132329"))
	modal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := UI.column(modal)
	var details := UI.scroll_column(box)
	modal_title = UI.label(title, font_size + 8, UI.TEAL)
	details.add_child(modal_title)
	details.add_child(UI.label(copy, font_size + 2))
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for row in actions:
		var b := button(row.text, row.id, row.get("value"), row.get("primary", false))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		buttons.add_child(b)
	_crt(modal)

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null

func _scroll_feedback(scroll: ScrollContainer, target: Control) -> void:
	if is_instance_valid(target) and scroll.is_ancestor_of(target):
		scroll.ensure_control_visible(target)

func _crt(panel: Control) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){COLOR=vec4(0.01,0.03,0.03,step(0.7,fract(FRAGCOORD.y/3.0))*0.025);}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	overlay.material = mat
	# Internal child: never participates in container minimum-size calculations.
	panel.add_child(overlay, false, Node.INTERNAL_MODE_BACK)
