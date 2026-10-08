class_name LessonsScreen
extends BaseScreen
## Module timeline -> selected tile -> lesson web. Progress remains account-owned.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const CYAN: Color = Color("#4FE0D4")
const GREEN: Color = Color("#33D17A")
var account: Object
var _modules: Array[Dictionary] = []
var _cards: Array[Button] = []
var _selected_index: int = 0
var _scroll: ScrollContainer
var _track: Control
var _tile: Button
var _title: Label
var _description: Label
var _status: Label
var _progress_text: Label
var _liquid: LiquidBar
var _transition: Tween
var _fill_tween: Tween
var _ghost: Orb
var _pending_open: bool = false
var _selection_revision: int = 0
var _overview: VBoxContainer
var _detail: PanelContainer
var _heading: Label
var _back: Button
var _showing_detail: bool = false
var _selection_origin: Vector2
var _info: VBoxContainer
var _hero: VBoxContainer
var _hero_label: Label
var _hero_icon: IntelPixelIcon
var _checkpoint: Button
var _checkpoint_status: Label
var _hologram: Hologram
var _previous: Button
var _next: Button
var _page_label: Label
var _pan_tween: Tween
var _returning: bool = false
var _lane_width: float = 340.0

class Hologram extends Control:
	var clock: float = 0.0
	var emblem: Control
	var caption: Control
	func _process(delta: float) -> void:
		if is_visible_in_tree() and not SettingsService.reduced_motion:
			clock += delta
			queue_redraw()
	func _draw() -> void:
		var ink: Color = Color("#4FE0D4")
		for x: int in range(0, int(size.x), 48):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(ink, 0.025))
		for y: int in range(0, int(size.y), 48):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(ink, 0.025))
		if not is_instance_valid(emblem):
			return
		var center: Vector2 = emblem.get_global_rect().get_center() - global_position
		var radius: float = minf(minf(size.x * 0.19, size.y * 0.39), minf(center.x - 40, center.y - 40))
		for ring: int in 3:
			var r: float = radius + float(ring) * 14.0
			draw_arc(center, r, 0, TAU, 64, Color(ink, 0.06), 1)
			var phase: float = float(ring) * 2.1 + (0.0 if SettingsService.reduced_motion else clock * 0.12)
			draw_arc(center, r, phase, phase + 0.8, 16, Color(ink, 0.24), 2)
		var base: Vector2 = Vector2(center.x, minf(size.y - 24, caption.get_global_rect().end.y - global_position.y + 54))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-60, 0), center + Vector2(-radius, 0), center + Vector2(radius, 0), base + Vector2(60, 0)]), Color(ink, 0.035))
		for i: int in 3:
			var points: PackedVector2Array = []
			for n: int in 65:
				var angle: float = TAU * float(n) / 64.0
				points.append(base + Vector2(cos(angle) * (95 + i * 15), sin(angle) * (12 + i * 4)))
			draw_polyline(points, Color(ink, 0.16 - float(i) * 0.035), 2)
		for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size]:
			var direction: Vector2 = Vector2(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
			draw_line(corner, corner + Vector2(direction.x * 30, 0), Color(ink, 0.5), 2)
			draw_line(corner, corner + Vector2(0, direction.y * 30), Color(ink, 0.5), 2)

class FlagMark extends Control:
	func _draw() -> void:
		draw_line(Vector2(5, 3), Vector2(5, 31), Color("#8FF0E6"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(7, 4), Vector2(30, 4), Vector2(24, 13), Vector2(30, 21), Vector2(7, 21)]), Color("#4FE0D4"))

class Orb extends Button:
	var morph: float = 0.0:
		set(value):
			morph = value
			queue_redraw()
	var accent: Color = Color("#4FE0D4")
	var selected: bool = false
	var holographic: bool = false
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.43
		var points: PackedVector2Array = []
		for i: int in 32:
			var direction: Vector2 = Vector2.from_angle(TAU * float(i) / 32.0)
			var square: Vector2 = direction / maxf(absf(direction.x), absf(direction.y))
			points.append(center + direction.lerp(square, morph) * radius)
		draw_colored_polygon(points, Color(0.02, 0.12, 0.2, 0.72) if holographic else (Color("#153B37") if selected else Color("#102040")))
		points.append(points[0])
		draw_polyline(points, Color("#173058") if disabled else accent, 3.0, false)
		if selected:
			draw_arc(center, radius + 6.0, 0, TAU, 32, Color(accent, 0.28), 3.0)
		if is_hovered() and not disabled:
			draw_arc(center, radius + 3.0, 0, TAU, 48, Color(accent, 0.65), 3)
		if holographic:
			draw_arc(center, radius - 10, 0, TAU, 48, Color(accent, 0.18), 1)
			for y: int in range(int(center.y - radius * 0.65), int(center.y + radius * 0.65), 8):
				draw_line(Vector2(center.x - radius * 0.65, y), Vector2(center.x + radius * 0.65, y), Color(accent, 0.035))
		if has_focus():
			draw_arc(center, radius + 10, 0, TAU, 48, Color("#FFB648"), 2)

class LiquidBar extends Control:
	var amount: float = 0.0:
		set(value):
			amount = clampf(value, 0.0, 1.0)
			queue_redraw()
	var clock: float = 0.0
	func _process(delta: float) -> void:
		if not is_visible_in_tree() or SettingsService.reduced_motion:
			return
		clock += delta
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0A1730"))
		var width: float = floorf(size.x * amount)
		draw_rect(Rect2(0, 0, width, size.y), Color("#2E6BFF"))
		for x: int in range(0, int(width), 4):
			var wave: float = 5.0 if SettingsService.reduced_motion else 5.0 + sin(float(x) * 0.07 + clock * 2.0) * 2.0
			draw_rect(Rect2(x, 0, minf(4, width - x), wave), Color("#4FE0D4"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#173058"), false, 2)

func _ready() -> void:
	if account == null:
		account = PlayerManager
	var shell: Dictionary = UI.shell(self, "LEARNING JOURNEY", func() -> void: Router.request_back())
	var layout: VBoxContainer = shell.layout
	var school_button: Button = UI.button("School Content", func() -> void: Router.push(&"school_content"))
	school_button.custom_minimum_size.x = 200
	shell.title.get_parent().add_child(school_button)
	_heading = shell.title
	_back = shell.back
	_overview = UI.column(layout, 20)
	_overview.size_flags_vertical = SIZE_EXPAND_FILL
	_overview.add_child(UI.label("CHOOSE YOUR NEXT CHALLENGE", 24, CYAN))
	var timeline_center: VBoxContainer = UI.column(_overview, 0)
	timeline_center.size_flags_vertical = SIZE_EXPAND_FILL
	timeline_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_scroll = ScrollContainer.new()
	_scroll.name = "ModuleTimeline"
	_scroll.custom_minimum_size.y = 380
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_h_scroll_bar().value_changed.connect(_update_navigation.unbind(1))
	_scroll.scroll_ended.connect(_snap_timeline)
	timeline_center.add_child(_scroll)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(1800, 372)
	_scroll.add_child(_track)
	var navigation: HBoxContainer = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 24)
	_overview.add_child(navigation)
	_previous = UI.button("<", _pan.bind(-1))
	_previous.tooltip_text = "Previous modules"
	navigation.add_child(_previous)
	_page_label = UI.label("", 22, UI.MUTED)
	_page_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(_page_label)
	_next = UI.button(">", _pan.bind(1))
	_next.tooltip_text = "Next modules"
	navigation.add_child(_next)
	_detail = UI.panel(layout, Color("#050B18"))
	_detail.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.06, 0.12, 0.7), Color("#173058"), 30))
	_detail.name = "ModuleDetail"
	_detail.size_flags_vertical = SIZE_EXPAND_FILL
	_detail.hide()
	_hologram = Hologram.new()
	_hologram.mouse_filter = MOUSE_FILTER_IGNORE
	_detail.add_child(_hologram)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	_detail.add_child(row)
	_hero = UI.column(row, 20)
	_hero.size_flags_horizontal = SIZE_EXPAND_FILL
	_hero.size_flags_stretch_ratio = 0.8
	_hero.alignment = BoxContainer.ALIGNMENT_CENTER
	_tile = Orb.new()
	(_tile as Orb).selected = true
	(_tile as Orb).holographic = true
	_tile.pressed.connect(_on_open_pressed)
	_tile.name = "EnterModule"
	_tile.custom_minimum_size = Vector2(240, 240)
	_tile.size_flags_horizontal = SIZE_SHRINK_CENTER
	_tile.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_tile.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_hero.add_child(_tile)
	_hero_icon = IntelPixelIcon.new()
	_hero_icon.ink_override = CYAN
	_hero_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_tile.add_child(_hero_icon)
	_hero_icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hero_icon.offset_left = 72
	_hero_icon.offset_top = 72
	_hero_icon.offset_right = -72
	_hero_icon.offset_bottom = -72
	_hero_label = UI.label("", 27, Color("#F3ECD6"))
	_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero.add_child(_hero_label)
	_hologram.emblem = _tile
	_hologram.caption = _hero_label
	_tile.item_rect_changed.connect(_hologram.queue_redraw)
	_hero.item_rect_changed.connect(_hologram.queue_redraw)
	_hero_label.item_rect_changed.connect(_hologram.queue_redraw)
	_hologram.resized.connect(_hologram.queue_redraw)
	_info = UI.column(row, 18)
	_info.size_flags_horizontal = SIZE_EXPAND_FILL
	_info.size_flags_stretch_ratio = 1.2
	_info.size_flags_vertical = SIZE_SHRINK_CENTER
	_title = UI.label("", 32, Color("#F3ECD6"))
	_info.add_child(_title)
	_description = UI.label("", 25, UI.MUTED)
	_info.add_child(_description)
	var progress_panel: PanelContainer = UI.panel(_info, Color("#0A1730"))
	var progress_info: VBoxContainer = UI.column(progress_panel, 12)
	_progress_text = UI.label("", 22, CYAN)
	progress_info.add_child(_progress_text)
	_liquid = LiquidBar.new()
	_liquid.custom_minimum_size.y = 24
	progress_info.add_child(_liquid)
	progress_info.add_child(UI.label("LEARN  /  QUIZ  /  SIMULATE", 20, UI.MUTED))
	var checkpoint_panel: PanelContainer = UI.panel(_info, Color("#0A1730"))
	var checkpoint_row: HBoxContainer = HBoxContainer.new()
	checkpoint_row.add_theme_constant_override("separation", 16)
	checkpoint_panel.add_child(checkpoint_row)
	_checkpoint_status = UI.label("", 22, UI.MUTED)
	_checkpoint_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_checkpoint_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	checkpoint_row.add_child(_checkpoint_status)
	_checkpoint = UI.button("POST-QUIZ", func() -> void: _open_checkpoint(_selected_index))
	checkpoint_row.add_child(_checkpoint)
	_status = UI.label("", 22, UI.MUTED)
	_info.add_child(_status)
	_scroll.resized.connect(_layout_timeline)
	get_viewport().size_changed.connect(_fit_touch)
	_refresh_list_ui()

func on_enter(_args: Dictionary) -> void:
	_set_detail_visible(false)
	_refresh_list_ui()

func can_go_back() -> bool:
	if _returning:
		return false
	if not _showing_detail:
		return true
	var origin: Vector2 = _tile.global_position - global_position
	_stop_transition()
	_set_detail_visible(false)
	if SettingsService.reduced_motion:
		_cards[_selected_index].grab_focus()
	else:
		_returning = true
		_overview.modulate.a = 0.0
		_animate_return.call_deferred(origin, _selection_revision)
	return false

func _set_detail_visible(value: bool) -> void:
	_showing_detail = value
	_overview.visible = not value
	_detail.visible = value
	_heading.text = "MODULE OVERVIEW" if value else "LEARNING JOURNEY"
	_back.text = "< MAP" if value else "< BACK"

func on_resume() -> void:
	_refresh_list_ui()
	if _pending_open:
		_pending_open = false
		if AuthService.has_module_pretest(_module_id(_selected_index)):
			_on_open_pressed()

func _refresh_list_ui() -> void:
	_stop_transition()
	_modules = LessonCatalog.modules()
	UI.clear(_track)
	_cards.clear()
	for i: int in _modules.size():
		var group: Control = Control.new()
		group.name = "ModuleGroup%d" % (i + 1)
		group.mouse_filter = MOUSE_FILTER_PASS
		_track.add_child(group)
		var x: float = 98.0
		var id: String = _module_id(i)
		if i < _modules.size() - 1:
			var line: ColorRect = ColorRect.new()
			line.name = "Connector"
			line.color = GREEN if account.has_lesson_post_quiz(id) else Color("#173058")
			line.position = Vector2(x + 144, 112)
			line.size = Vector2(196, 2)
			line.mouse_filter = MOUSE_FILTER_IGNORE
			group.add_child(line)
		var orb: Orb = Orb.new()
		orb.name = "Module%d" % (i + 1)
		orb.position = Vector2(x, 40)
		orb.size = Vector2(144, 144)
		orb.disabled = not _is_unlocked(i)
		orb.accent = GREEN if account.has_lesson_post_quiz(id) else CYAN
		orb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		orb.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		orb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		orb.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		orb.pressed.connect(_select.bind(i))
		orb.tooltip_text = str(_modules[i].title) if not orb.disabled else "Pass the previous module's post-quiz."
		group.add_child(orb)
		var icon: IntelPixelIcon = IntelPixelIcon.new()
		icon.name = "ModuleStatusIcon"
		icon.kind = [IntelPixelIcon.Kind.ENVELOPE, IntelPixelIcon.Kind.PHONE, IntelPixelIcon.Kind.PHONE, IntelPixelIcon.Kind.BADGE, IntelPixelIcon.Kind.BOOKS][i] if not orb.disabled else IntelPixelIcon.Kind.LOCK
		icon.ink_override = orb.accent if not orb.disabled else UI.MUTED
		icon.position = Vector2(44, 44)
		icon.size = Vector2(56, 56)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		orb.add_child(icon)
		_cards.append(orb)
		var number: Label = UI.label("MODULE %02d" % (i + 1), 20, CYAN if not orb.disabled else UI.MUTED)
		number.position = Vector2(50, 2)
		number.size = Vector2(240, 28)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(number)
		var caption: Label = UI.label(str(_modules[i].title), 26, UI.TEXT if not orb.disabled else UI.MUTED)
		caption.position = Vector2(30, 196)
		caption.size = Vector2(280, 44)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(caption)
		var stem: ColorRect = ColorRect.new()
		stem.position = Vector2(169, 242)
		stem.size = Vector2(2, 28)
		stem.color = GREEN if account.has_lesson_post_quiz(id) else Color("#173058")
		stem.mouse_filter = MOUSE_FILTER_IGNORE
		group.add_child(stem)
		var flag: Button = UI.button("POST-QUIZ", _open_checkpoint.bind(i))
		flag.name = "Checkpoint%d" % (i + 1)
		flag.position = Vector2(50, 274)
		flag.size = Vector2(240, 72)
		flag.add_theme_font_size_override("font_size", 20)
		flag.add_theme_stylebox_override("disabled", UI.box(Color("#0A1730"), Color("#173058"), 10))
		flag.add_theme_stylebox_override("normal", UI.box(Color("#0E2A28"), Color("#4FE0D4"), 10))
		var mark: FlagMark = FlagMark.new()
		mark.position = Vector2(14, 19)
		mark.size = Vector2(36, 34)
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		flag.add_child(mark)
		flag.text = "    POST-QUIZ"
		flag.disabled = not _is_complete(i) or not _is_unlocked(i)
		flag.tooltip_text = "25 questions / 20 correct to pass" if not flag.disabled else "Finish all six lessons, quizzes and simulations first."
		if account.has_lesson_post_quiz(id):
			flag.text = "    PASSED"
			flag.add_theme_stylebox_override("normal", UI.box(Color("#153B37"), GREEN, 8))
		group.add_child(flag)
	_select(clampi(_selected_index, 0, _modules.size() - 1), false, _showing_detail)
	_fit_touch.call_deferred()
	_layout_timeline.call_deferred()

func _layout_timeline() -> void:
	if not is_instance_valid(_track) or _modules.is_empty():
		return
	var visible_count: int = clampi(floori((_scroll.size.x - 64.0) / 340.0), 1, _modules.size())
	_lane_width = maxf(340.0, (_scroll.size.x - 64.0) / float(visible_count))
	_track.custom_minimum_size.x = _lane_width * _modules.size() + 64.0
	for i: int in _track.get_child_count():
		var group: Control = _track.get_child(i) as Control
		group.position = Vector2(32 + i * _lane_width + (_lane_width - 340) * 0.5, 0)
		group.size = Vector2(340, 372)
		var connector: ColorRect = group.get_node_or_null("Connector") as ColorRect
		if connector != null:
			connector.size.x = _lane_width - 144
	_update_navigation.call_deferred()

func _update_navigation() -> void:
	if not is_instance_valid(_next):
		return
	var bar: HScrollBar = _scroll.get_h_scroll_bar()
	_previous.disabled = bar.value <= 1
	_next.disabled = bar.value >= bar.max_value - bar.page - 1
	_page_label.text = "SWIPE OR USE ARROWS  /  5 MODULES" if bar.max_value > bar.page + 1 else "5 MODULES  /  PASS EACH CHECKPOINT TO ADVANCE"

func _pan(direction: int) -> void:
	if _pan_tween != null:
		_pan_tween.kill()
	var bar: HScrollBar = _scroll.get_h_scroll_bar()
	var target: float = clampf((roundf(bar.value / _lane_width) + float(direction)) * _lane_width, 0, maxf(0, bar.max_value - bar.page))
	if SettingsService.reduced_motion:
		bar.value = target
	else:
		_pan_tween = create_tween()
		_pan_tween.tween_property(bar, "value", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _snap_timeline() -> void:
	_pan(0)

func _select(index: int, animate: bool = true, open_detail: bool = true) -> void:
	if index < 0 or index >= _modules.size() or not _is_unlocked(index):
		return
	_stop_transition()
	if not _showing_detail:
		_selection_origin = _cards[index].global_position - global_position
	_set_detail_visible(open_detail)
	_selected_index = index
	for i: int in _cards.size():
		var orb: Orb = _cards[i] as Orb
		orb.selected = i == index
		orb.queue_redraw()
	var id: String = _module_id(index)
	var done: int = clampi(account.get_lesson_progress(id), 0, 6)
	var checkpoint: bool = account.has_lesson_post_quiz(id)
	var ratio: float = float(done + (1 if checkpoint else 0)) / 7.0
	_title.text = str(_modules[index].title).to_upper()
	_description.text = str(_modules[index].desc) + "."
	_progress_text.text = "%d%% COMPLETE  /  %d OF 6 LESSONS" % [roundi(ratio * 100), done]
	_checkpoint_status.text = "CHECKPOINT PASSED\nNext module unlocked" if checkpoint else ("CHECKPOINT READY\n20 / 25 correct to pass" if done == 6 else "CHECKPOINT LOCKED\nFinish all 6 lessons first")
	if checkpoint and index == _modules.size() - 1:
		_checkpoint_status.text = "CHECKPOINT PASSED\nLearning journey complete"
	_checkpoint.disabled = done < 6
	_status.text = "Select the glowing emblem to continue your lessons."
	if _needs_pretest(index):
		_status.text = "Start with a short pretest to personalize your learning."
	_hero_label.text = "MODULE %02d\n%s" % [index + 1, "START PRETEST" if _needs_pretest(index) else "ENTER MODULE"]
	_tile.tooltip_text = _hero_label.text.replace("\n", " / ")
	_hero_icon.kind = (_cards[index].get_child(0) as IntelPixelIcon).kind
	_liquid.amount = ratio if SettingsService.reduced_motion else 0.0
	if not open_detail:
		return
	if animate and not SettingsService.reduced_motion:
		_tile.disabled = true
		_detail.modulate.a = 0.0
		_animate_selection.call_deferred(index, _selection_revision)
	else:
		_tile.disabled = false
		_tile.grab_focus()
		if not SettingsService.reduced_motion:
			_fill_tween = create_tween()
			_fill_tween.tween_property(_liquid, "amount", ratio, 0.6)

func _animate_selection(index: int, revision: int) -> void:
	await get_tree().process_frame
	if revision != _selection_revision or index != _selected_index or not is_visible_in_tree() or not _showing_detail:
		return
	_tile.disabled = true
	_tile.modulate.a = 0.0
	_create_ghost(_selection_origin, _cards[index].size)
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_ghost, "position", _tile.global_position - global_position, 0.48)
	_transition.tween_property(_ghost, "size", _tile.size, 0.48)
	_transition.tween_property(_detail, "modulate:a", 1.0, 0.32).set_delay(0.14)
	_transition.tween_property(_liquid, "amount", float(account.get_lesson_progress(_module_id(index)) + (1 if account.has_lesson_post_quiz(_module_id(index)) else 0)) / 7.0, 0.42).set_delay(0.18)
	_transition.chain().tween_callback(func() -> void:
		_tile.modulate.a = 1.0
		if is_instance_valid(_ghost):
			_ghost.queue_free()
			_ghost = null
		_tile.disabled = false
		_tile.grab_focus()
	)

func _create_ghost(origin: Vector2, dimensions: Vector2) -> void:
	_ghost = Orb.new()
	_ghost.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_ghost.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_ghost.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_ghost.mouse_filter = MOUSE_FILTER_IGNORE
	_ghost.focus_mode = FOCUS_NONE
	_ghost.selected = true
	_ghost.holographic = true
	_ghost.size = dimensions
	_ghost.position = origin
	add_child(_ghost)
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = _hero_icon.kind
	icon.ink_override = CYAN
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	_ghost.add_child(icon)
	icon.anchor_left = 0.3
	icon.anchor_top = 0.3
	icon.anchor_right = 0.7
	icon.anchor_bottom = 0.7

func _animate_return(origin: Vector2, revision: int) -> void:
	await get_tree().process_frame
	if revision != _selection_revision or not is_visible_in_tree() or not _returning:
		return
	_create_ghost(origin, _tile.size)
	_cards[_selected_index].modulate.a = 0.0
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_ghost, "position", _cards[_selected_index].global_position - global_position, 0.4)
	_transition.tween_property(_ghost, "size", _cards[_selected_index].size, 0.4)
	_transition.tween_property(_overview, "modulate:a", 1.0, 0.3)
	_transition.chain().tween_callback(func() -> void:
		if is_instance_valid(_ghost):
			_ghost.queue_free()
			_ghost = null
		_cards[_selected_index].modulate.a = 1.0
		_cards[_selected_index].grab_focus()
		_returning = false
	)

func _stop_transition() -> void:
	_selection_revision += 1
	if _transition != null:
		_transition.kill()
	if _fill_tween != null:
		_fill_tween.kill()
	if _pan_tween != null:
		_pan_tween.kill()
	if is_instance_valid(_ghost):
		_ghost.queue_free()
		_ghost = null
	if is_instance_valid(_tile):
		_tile.disabled = false
		_tile.modulate.a = 1.0
		_detail.modulate.a = 1.0
		_overview.modulate.a = 1.0
	for card: Button in _cards:
		if is_instance_valid(card):
			card.modulate.a = 1.0
	_returning = false

func _module_id(index: int) -> String:
	return str(_modules[index].id) if index >= 0 and index < _modules.size() else ""

func _is_complete(index: int) -> bool:
	return account.get_lesson_progress(_module_id(index)) >= LessonCatalog.lesson_count(_module_id(index))

func _is_unlocked(index: int) -> bool:
	return index >= 0 and index < _modules.size() and account.can_access_lesson_module(_module_id(index))

func _needs_pretest(index: int) -> bool:
	return _is_unlocked(index) and not _is_complete(index) and not AuthService.has_module_pretest(_module_id(index))

func _open_checkpoint(index: int) -> void:
	if _is_unlocked(index) and _is_complete(index):
		Router.push(&"lesson_player", {"module_id": _module_id(index), "review": true, "post_quiz": true})

func _on_open_pressed() -> void:
	if _tile.disabled or not _is_unlocked(_selected_index):
		return
	var id: String = _module_id(_selected_index)
	if _needs_pretest(_selected_index):
		_pending_open = true
		Router.push(&"pretest", {"module_id": id})
	else:
		Router.push(&"lesson_player", {"module_id": id, "review": _is_complete(_selected_index)})

func on_exit() -> void:
	_stop_transition()

func _fit_touch() -> void:
	UI.fit_touch(self)
	_layout_timeline()
	# Resize can invalidate an in-flight destination. Finish cleanly at the new layout.
	if _ghost != null or _returning:
		_stop_transition()
