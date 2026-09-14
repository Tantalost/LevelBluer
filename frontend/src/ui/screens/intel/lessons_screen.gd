class_name LessonsScreen
extends BaseScreen
## Deploy-style module carousel dedicated to learning. No upgrade controls.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var _modules: Array[Dictionary] = []
var _cards: Array[Button] = []
var _selected_index := 0
var _card_row: HBoxContainer
var _scroll: ScrollContainer
var _open: Button
var _status: Label

func _ready() -> void:
	var shell := UI.shell(self, "LESSON ARCHIVE", func() -> void: Router.request_back())
	var layout: VBoxContainer = shell.layout
	layout.add_child(UI.label("LEARN THE THREAT. PRACTICE THE RESPONSE.", 28, UI.TEAL))
	layout.add_child(UI.label("Choose a module  /  Definition > Mini quiz > Desktop simulation", 24, UI.MUTED))
	_scroll = ScrollContainer.new()
	_scroll.name = "ModuleCarousel"
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_scroll)
	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 24)
	_card_row.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.add_child(_card_row)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	layout.add_child(footer)
	_status = UI.label("", 24, UI.MUTED)
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(_status)
	_open = UI.button("OPEN MODULE  >", _on_open_pressed, true)
	_open.custom_minimum_size.x = 250
	footer.add_child(_open)
	_refresh_list_ui()

func on_enter(_args: Dictionary) -> void:
	_refresh_list_ui()

func on_resume() -> void:
	_refresh_list_ui()

func _refresh_list_ui() -> void:
	_modules = LessonCatalog.modules()
	UI.clear(_card_row)
	_cards.clear()
	for i in _modules.size():
		var locked := not _is_unlocked(i)
		var pretest := _needs_pretest(i)
		var accent := Color("b0b6bc") if locked else (UI.GOLD if pretest else UI.TEAL)
		var text_color := Color("b0b6bc") if locked else UI.TEXT
		var card := UI.button("", _select.bind(i))
		card.disabled = locked
		card.mouse_default_cursor_shape = CURSOR_ARROW if locked else CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("disabled", UI.box(Color("1b2027"), Color("48505a"), 10))
		card.tooltip_text = "Complete Module %d to unlock these lessons." % i if locked else ("Complete this module's pretest to begin studying." if pretest else "Select this lesson module.")
		card.name = "Module%d" % (i + 1)
		card.custom_minimum_size = Vector2(290, 360)
		card.size_flags_vertical = SIZE_EXPAND_FILL
		_card_row.add_child(card)
		_cards.append(card)
		var inset := MarginContainer.new()
		inset.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + edge, 24)
		inset.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(inset)
		var body := UI.column(inset, 18)
		body.mouse_filter = MOUSE_FILTER_IGNORE
		body.add_child(UI.label("MODULE  %02d" % (i + 1), 16, accent, true))
		var glyph := IntelPixelIcon.new()
		glyph.kind = [IntelPixelIcon.Kind.ENVELOPE, IntelPixelIcon.Kind.PHONE, IntelPixelIcon.Kind.PHONE, IntelPixelIcon.Kind.BADGE, IntelPixelIcon.Kind.BOOKS][i]
		if locked or pretest:
			glyph.kind = IntelPixelIcon.Kind.LOCK
			glyph.ink_override = accent
		glyph.name = "ModuleStatusIcon"
		glyph.custom_minimum_size = Vector2(0, 85)
		glyph.mouse_filter = MOUSE_FILTER_IGNORE
		body.add_child(glyph)
		body.add_child(UI.label(str(_modules[i].title).to_upper(), 20, text_color, true))
		var desc := UI.label(str(_modules[i].desc), 24, Color("8f969e") if locked else UI.MUTED)
		desc.size_flags_vertical = SIZE_EXPAND_FILL
		body.add_child(desc)
		var total := LessonCatalog.lesson_count(_module_id(i))
		var done := PlayerManager.get_lesson_progress(_module_id(i))
		var bar := ProgressBar.new()
		bar.max_value = total
		bar.value = done
		bar.show_percentage = false
		bar.custom_minimum_size.y = 7
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", UI.box(UI.BG, UI.BG, 0))
		bar.add_theme_stylebox_override("fill", UI.box(accent, accent, 0))
		body.add_child(bar)
		var state := "%d / %d TOPICS" % [done, total]
		if not _is_unlocked(i):
			state = "LOCKED / CLEAR MODULE %d" % i
		elif _needs_pretest(i):
			state = "PRETEST REQUIRED"
		elif _is_complete(i):
			state = "COMPLETE / REVIEW"
		body.add_child(UI.label(state, 20, accent if locked else UI.GOLD))
	_select(clampi(_selected_index, 0, maxi(0, _modules.size() - 1)))

func _select(index: int) -> void:
	_selected_index = index
	for i in _cards.size():
		_cards[i].add_theme_stylebox_override("normal", UI.box(Color("203c45") if i == index else UI.PANEL, UI.TEAL if i == index else Color("3b626a"), 10))
	if _modules.is_empty():
		_open.disabled = true
		_status.text = "No modules available."
		return
	_open.disabled = not _can_open(index)
	_open.text = "LOCKED" if not _can_open(index) else ("PRETEST  >" if _needs_pretest(index) else ("REVIEW  >" if _is_complete(index) else "STUDY MODULE  >"))
	_status.text = "Finish the previous module to unlock this archive." if not _can_open(index) else "MODULE %02d  /  %s" % [index + 1, str(_modules[index].title)]
	_scroll.ensure_control_visible.call_deferred(_cards[index])

func _module_id(index: int) -> String:
	return str(_modules[index].id) if index >= 0 and index < _modules.size() else ""

func _is_complete(index: int) -> bool:
	var id := _module_id(index)
	return not id.is_empty() and PlayerManager.get_lesson_progress(id) >= LessonCatalog.lesson_count(id)

func _is_unlocked(index: int) -> bool:
	return index == 0 or (index > 0 and _is_complete(index - 1))

func _needs_pretest(index: int) -> bool:
	return _is_unlocked(index) and not _is_complete(index) and not AuthService.has_module_pretest(_module_id(index))

func _can_open(index: int) -> bool:
	return index >= 0 and index < _modules.size() and _is_unlocked(index)

func _on_open_pressed() -> void:
	if not _can_open(_selected_index):
		return
	var module_id := _module_id(_selected_index)
	if _needs_pretest(_selected_index):
		Router.push(&"pretest", {"module_id": module_id})
	else:
		Router.push(&"lesson_player", {"module_id": module_id, "review": _is_complete(_selected_index)})
