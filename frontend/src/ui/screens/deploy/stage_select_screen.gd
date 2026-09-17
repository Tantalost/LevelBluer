extends BaseScreen
## Deployment terminal. Presentation only; prerequisite and route rules are unchanged.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Art = preload("res://src/ui/screens/deploy/module_signal_art.gd")
const ACCENTS := [Color("8dc9bd"), Color("adcca6"), Color("a8bfd7"), Color("c8baa0"), Color("c3b6cf")]

var _modules: Array[Dictionary] = []
var _selected := 0
var current_selected_stage := 0
var _cards: Array[Button] = []
var _body: HBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _action_area: VBoxContainer
var _profile: Button
var _wallet: Label
var _back: Button
var _title: Label
var _upgrades: Button
var _settings: Button
var _breach_button: Button
var _avatar: TextureRect
var _font := 28
var _touch := 64.0
var _active := true
var _queued := false

func _ready() -> void:
	var shell := UI.shell(self, "DEPLOY / MODULES", func() -> void: Router.request_back())
	_back = shell.back
	_title = shell.title
	var header: HBoxContainer = _title.get_parent()
	_upgrades = UI.button("UPGRADES", func() -> void: Router.push(&"upgrades"))
	header.add_child(_upgrades)
	_settings = UI.button("SETTINGS", func() -> void: Router.push(&"settings"))
	header.add_child(_settings)
	var account := UI.panel(shell.layout, Color("18252b"))
	account.add_theme_stylebox_override("panel", UI.box(Color("18252b"), Color("48635f"), 12))
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 18)
	account.add_child(band)
	_avatar = TextureRect.new()
	_avatar.name = "AvatarImage"
	_avatar.custom_minimum_size = Vector2(56, 56)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.mouse_filter = MOUSE_FILTER_IGNORE
	band.add_child(_avatar)
	_profile = UI.button("", func() -> void: Router.push(&"profile"))
	_profile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_profile.size_flags_horizontal = SIZE_EXPAND_FILL
	_profile.add_theme_stylebox_override("normal", UI.box(Color("18252b"), Color("18252b"), 10))
	band.add_child(_profile)
	_wallet = UI.label("", 28, UI.TEXT)
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(_wallet)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 20)
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	shell.layout.add_child(_body)
	_list = UI.scroll_column(_body)
	_list.get_parent().size_flags_stretch_ratio = 0.36
	_list.add_theme_constant_override("separation", 8)
	var briefing := UI.column(_body, 12)
	briefing.size_flags_horizontal = SIZE_EXPAND_FILL
	briefing.size_flags_stretch_ratio = 0.64
	_detail = UI.scroll_column(briefing)
	_action_area = UI.column(briefing, 0)
	_modules = LessonCatalog.modules()
	get_viewport().size_changed.connect(_request_refresh)
	AuthService.progress_changed.connect(_request_refresh)
	AuthService.session_changed.connect(_session_changed)
	_refresh()

func on_enter(_args: Dictionary) -> void:
	visible = true
	_active = true
	_modules = LessonCatalog.modules()
	_selected = _first_unlocked()
	AssetManager.bind_texture(_avatar, "ui_pfp")
	_refresh()

func on_resume() -> void:
	visible = true
	_active = true
	_refresh()

func on_exit() -> void:
	_active = false
	visible = false

func _session_changed(_signed_in: bool) -> void:
	_selected = 0
	_request_refresh()

func _request_refresh() -> void:
	if not _active or _queued:
		return
	_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_queued = false
	if not is_inside_tree() or not _active:
		return
	var scale_y := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_font = maxi(28, ceili(16 / scale_y))
	_touch = maxf(64, ceilf(48 / scale_y))
	for button in [_back, _upgrades, _settings, _profile]:
		button.custom_minimum_size.y = _touch
		button.add_theme_font_size_override("font_size", _font)
	for button in [_back, _upgrades, _settings]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = maxf(120, button.text.length() * _font * 0.7 + 24)
	_title.add_theme_font_size_override("font_size", maxi(20, ceili(12 / scale_y)))
	_profile.text = "%s  /  %s" % [AuthService.display_name().to_upper(), AuthService.rank_title()]
	_wallet.text = "THREAT  %d    |    CREDITS  %d" % [maxi(0, AuthService.wallet_threat_points()), maxi(0, PlayerManager.credits)]
	_wallet.add_theme_font_size_override("font_size", _font)
	_rebuild_cards()
	_build_detail()

func _label(text: String, color: Color = UI.TEXT, extra: int = 0) -> Label:
	return UI.label(text, _font + extra, color)

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := UI.button(text, callback, primary)
	button.custom_minimum_size.y = _touch
	button.add_theme_font_size_override("font_size", _font)
	return button

func _rebuild_cards() -> void:
	var focused := -1
	for i in _cards.size():
		if _cards[i].has_focus():
			focused = i
	UI.clear(_list)
	_cards.clear()
	_list.add_child(_label("OPERATIONS / 5 MODULES", UI.MUTED, -2))
	for i in _modules.size():
		var module: Dictionary = _modules[i]
		var available := _is_unlocked(i)
		var ink: Color = ACCENTS[i] if available else UI.MUTED
		var card := _button("", _select_module.bind(i))
		card.name = "Module%d" % (i + 1)
		card.custom_minimum_size.y = maxf(80, _touch + 16)
		card.add_theme_stylebox_override("normal", UI.box(Color("203a40") if _selected == i else Color("13232c"), ACCENTS[i] if _selected == i else Color("364951"), 14))
		# Children retain high contrast on hover, not the button's light text background.
		card.add_theme_stylebox_override("hover", UI.box(Color("29444a"), ACCENTS[i], 14))
		card.add_theme_stylebox_override("pressed", UI.box(Color("304c50"), UI.GOLD, 14))
		_list.add_child(card)
		_cards.append(card)
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		row.offset_left = 16
		row.offset_right = -16
		row.offset_top = 12
		row.offset_bottom = -12
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var number := _label("%02d" % (i + 1), ink, 10)
		number.custom_minimum_size.x = 48
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(number)
		var text := UI.column(row, 3)
		text.mouse_filter = MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.size_flags_vertical = SIZE_SHRINK_CENTER
		text.add_child(_label(str(module.title), UI.TEXT))
		text.add_child(_label("AVAILABLE" if available else "LOCKED", ink, -3))
		if not available:
			var lock := IntelPixelIcon.new()
			lock.kind = IntelPixelIcon.Kind.LOCK
			lock.ink_override = UI.MUTED
			lock.custom_minimum_size = Vector2(32, 32)
			row.add_child(lock)
	if focused >= 0:
		_cards[focused].grab_focus()

func _build_detail() -> void:
	UI.clear(_detail)
	UI.clear(_action_area)
	var module: Dictionary = _modules[_selected]
	var accent: Color = ACCENTS[_selected]
	var available := _is_unlocked(_selected)
	var panel := UI.panel(_detail, Color("13242d"))
	panel.add_theme_stylebox_override("panel", UI.box(Color("13242d"), accent, 20))
	var content := UI.column(panel, 12)
	content.add_child(_label("OPERATION %02d  /  %s" % [_selected + 1, str(module.domain).to_upper()], accent, -1))
	if not available:
		content.add_child(_label("LOCKED / " + _lock_reason(_selected), UI.GOLD, -1))
	var art := Art.new()
	art.accent = accent
	art.module_index = _selected
	art.custom_minimum_size.y = 120
	content.add_child(art)
	content.add_child(_label(str(module.title).to_upper(), UI.TEXT, 12))
	content.add_child(_label(str(module.desc) + ".", UI.MUTED))
	var module_id := str(module.id)
	var total := LessonCatalog.lesson_count(module_id)
	var done := clampi(PlayerManager.get_lesson_progress(module_id), 0, total)
	content.add_child(_label("LESSON PREPARATION  /  %d OF %d" % [done, total], accent, -2))
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, total)
	bar.value = done
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UI.box(UI.BG, UI.BG, 0))
	bar.add_theme_stylebox_override("fill", UI.box(accent, accent, 0))
	content.add_child(bar)
	if _selected == 0:
		var clears := 0
		for stage_id in range(1, 11):
			if PlayerManager.has_cleared_stage(stage_id):
				clears += 1
		content.add_child(_label("10 STAGES  /  %d CLEARED" % clears, UI.TEXT, -1))
	else:
		content.add_child(_label("STAGES COMING SOON", UI.GOLD, -1))
	if available:
		content.add_child(_label("Choose a stage and defend the network." if _selected == 0 else "Module access unlocked. Authored stages are coming soon.", UI.MUTED, -1))
	_breach_button = _button("OPEN MODULE  >", _on_breach_pressed, true)
	_breach_button.disabled = not available
	if not available:
		_breach_button.text = "LOCKED / COMPLETE LESSONS"
	_action_area.add_child(_breach_button)

func _lock_reason(index: int) -> String:
	if _is_unlocked(index):
		return ""
	var required := 0 if index == 0 else index - 1
	return "Complete the %s lessons in Module %d to unlock this operation." % [str(_modules[required].title), required + 1]

func _preview_module(index: int) -> void:
	if index < 0 or index >= _modules.size():
		return
	_selected = index
	current_selected_stage = maxi(0, _td_index_for(index))
	_rebuild_cards()
	_build_detail()
	(_detail.get_parent() as ScrollContainer).scroll_vertical = 0

func _select_module(index: int) -> void:
	if index < 0 or index >= _modules.size():
		return
	_preview_module(index)
	# Keep the established one-tap route for unlocked operations.
	if _is_unlocked(index):
		_open_module(index)

func _first_unlocked() -> int:
	for i in _modules.size():
		if _is_unlocked(i):
			return i
	return 0

func _is_unlocked(index: int) -> bool:
	if index < 0 or index >= _modules.size():
		return false
	if index == 0:
		return PlayerManager.is_module_deploy_unlocked(str(_modules[index].id))
	return _is_complete(index - 1)

func _is_complete(index: int) -> bool:
	if index < 0 or index >= _modules.size():
		return false
	var module_id := str(_modules[index].id)
	return PlayerManager.get_lesson_progress(module_id) >= LessonCatalog.lesson_count(module_id)

func _td_index_for(module_index: int) -> int:
	# Compatibility with the existing selection property, not an authored-stage count.
	return module_index if module_index in [0, 1, 2, 3, 4] else -1

func _can_open() -> bool:
	return not _modules.is_empty() and _is_unlocked(_selected)

func _on_breach_pressed() -> void:
	if _can_open():
		_open_module(_selected)

func _module_route(index: int) -> Dictionary:
	return {"route": &"module_intro" if index == 0 else &"module_stages", "args": {"module_index": index}}

func _open_module(index: int) -> void:
	if not _is_unlocked(index):
		return
	var destination := _module_route(index)
	Router.push(destination.route, destination.args)
