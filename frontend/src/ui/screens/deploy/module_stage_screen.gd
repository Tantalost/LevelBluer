extends BaseScreen
## Mission briefing terminal. StageManager remains the authority for deployment.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Briefings = preload("res://src/ui/screens/deploy/stage_briefings.gd")
const ACCENTS := [Color("8dc9bd"), Color("adcca6"), Color("a8bfd7"), Color("c8baa0"), Color("c3b6cf")]
const STAGE_COUNT := 10
const COMPLETED_INK := Color("a0dcae")
const COMPLETED_FILL := Color("193a2b")
const COMPLETED_SELECTED_FILL := Color("254c36")

var _modules: Array[Dictionary] = []
var _module_index := 0
var _selected := 0
var current_selected_stage := 0
var _active := false
var _queued := false
var _font := 28
var _touch := 64.0
var _poll := 0.0
var _seen := ""
var _rows: Array[Button] = []
var _back: Button
var _settings: Button
var _profile: Button
var _avatar: TextureRect
var _title: Label
var _wallet: Label
var _body: HBoxContainer
var _detail: VBoxContainer
var _stage_list: VBoxContainer
var _summary: Label
var _completion: ProgressBar
var _breach_button: Button
var _preview_button: Button
var _reason_label: Label
var _header: HBoxContainer
var _profile_name: Label
var _profile_rank: Label
var _teaser_label: Label
var _briefing_tween: Tween

func _ready() -> void:
	_modules = LessonCatalog.modules()
	var shell := UI.shell(self, "MISSION\nSELECT", func() -> void: Router.request_back())
	_back = shell.back
	_title = shell.title
	_header = _title.get_parent()
	_header.add_theme_constant_override("separation", 14)
	_profile = UI.button("", func() -> void: Router.push(&"profile"))
	_profile.size_flags_horizontal = SIZE_EXPAND_FILL
	_profile.size_flags_stretch_ratio = 1.3
	for state in ["normal", "hover", "pressed"]:
		_profile.add_theme_stylebox_override(state, UI.box(Color("20373d") if state != "normal" else Color("13232c"), Color("48635f"), 10))
	_header.add_child(_profile)
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 12)
	band.mouse_filter = MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	band.offset_left = 12
	band.offset_right = -12
	band.offset_top = 8
	band.offset_bottom = -8
	_profile.add_child(band)
	_avatar = TextureRect.new()
	_avatar.custom_minimum_size = Vector2(48, 48)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.mouse_filter = MOUSE_FILTER_IGNORE
	band.add_child(_avatar)
	var identity := UI.column(band, 3)
	identity.mouse_filter = MOUSE_FILTER_IGNORE
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.size_flags_vertical = SIZE_SHRINK_CENTER
	_profile_name = UI.label("")
	_profile_rank = UI.label("", 24, UI.MUTED)
	for label in [_profile_name, _profile_rank]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		identity.add_child(label)
	_wallet = UI.label("", 24)
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_wallet)
	_settings = UI.button("SETTINGS", func() -> void: Router.push(&"settings"))
	_header.add_child(_settings)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 20)
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	shell.layout.add_child(_body)
	var briefing := UI.column(_body, 12)
	briefing.size_flags_horizontal = SIZE_EXPAND_FILL
	briefing.size_flags_stretch_ratio = 0.55
	_detail = UI.scroll_column(briefing)
	_breach_button = UI.button("DEPLOY  >", _on_breach_pressed, true)
	briefing.add_child(_breach_button)
	_preview_button = UI.button("Try Gameplay Preview — Nothing Saved", _on_preview_pressed)
	briefing.add_child(_preview_button)
	var missions := UI.column(_body, 12)
	missions.size_flags_horizontal = SIZE_EXPAND_FILL
	missions.size_flags_stretch_ratio = 0.45
	_summary = UI.label("")
	missions.add_child(_summary)
	_completion = ProgressBar.new()
	_completion.show_percentage = false
	_completion.custom_minimum_size.y = 8
	_completion.mouse_filter = MOUSE_FILTER_IGNORE
	_completion.add_theme_stylebox_override("background", UI.box(UI.PANEL, UI.PANEL, 0))
	_completion.add_theme_stylebox_override("fill", UI.box(UI.TEAL, UI.TEAL, 0))
	missions.add_child(_completion)
	_stage_list = UI.scroll_column(missions)
	_stage_list.add_theme_constant_override("separation", 10)
	get_viewport().size_changed.connect(_request_refresh)
	AuthService.progress_changed.connect(_request_refresh)
	AuthService.session_changed.connect(_session_changed)
	set_process(false)

func on_enter(args: Dictionary) -> void:
	_modules = LessonCatalog.modules()
	_module_index = clampi(int(args.get("module_index", 0)), 0, maxi(0, _modules.size() - 1))
	_selected = _first_playable()
	current_selected_stage = maxi(0, _launch_index(_selected))
	_active = true
	visible = true
	AssetManager.bind_texture(_avatar, "ui_pfp")
	_refresh_all()
	(_stage_list.get_parent() as ScrollContainer).set_deferred("scroll_vertical", 0)
	(_detail.get_parent() as ScrollContainer).set_deferred("scroll_vertical", 0)
	set_process(true)

func on_resume() -> void:
	_active = true
	visible = true
	_refresh_all()
	set_process(true)

func on_exit() -> void:
	if _briefing_tween != null:
		_briefing_tween.kill()
	_active = false
	visible = false
	set_process(false)

func _session_changed(_signed_in: bool) -> void:
	_selected = 0
	current_selected_stage = maxi(0, _launch_index(0))
	_request_refresh()

func _state_key() -> String:
	return str([PlayerManager.mock_max_stage_cleared, PlayerManager.cleared_stages,
		PlayerManager.lesson_progress, PlayerManager.completed_lessons,
		PlayerManager.locked_stages, PlayerManager.credits])

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0
	if _state_key() != _seen:
		_request_refresh()

func _request_refresh() -> void:
	if not _active or _queued:
		return
	_queued = true
	_refresh_all.call_deferred()

func _refresh_all() -> void:
	_queued = false
	if not _active or not is_inside_tree():
		return
	_seen = _state_key()
	var scale_y := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_font = maxi(28, ceili(16 / scale_y))
	_touch = maxf(64, ceilf(48 / scale_y))
	for button in [_back, _settings, _profile, _breach_button, _preview_button]:
		button.custom_minimum_size.y = _touch
		button.add_theme_font_size_override("font_size", _font)
	for button in [_back, _settings]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = 120 if button == _back else 148
	_title.add_theme_font_size_override("font_size", maxi(20, ceili(12 / scale_y)))
	_profile.custom_minimum_size = Vector2(260, maxf(_touch, _font * 2 + 24))
	_profile_name.text = AuthService.display_name().to_upper()
	_profile_rank.text = AuthService.rank_title().to_upper()
	_profile.tooltip_text = "%s / %s — Open profile" % [AuthService.display_name(), AuthService.rank_title()]
	_profile_name.add_theme_font_size_override("font_size", _font)
	_profile_rank.add_theme_font_size_override("font_size", _font - 4)
	_wallet.text = "THREAT   %d\nCREDITS  %d" % [maxi(0, AuthService.wallet_threat_points()), maxi(0, PlayerManager.credits)]
	_wallet.add_theme_font_size_override("font_size", _font - 2)
	_summary.text = "OPERATIONS  /  %d OF %d CLEARED" % [_cleared_count(), _authored_count()]
	_summary.add_theme_font_size_override("font_size", _font - 2)
	_completion.max_value = maxi(1, _authored_count())
	_completion.value = _cleared_count()
	_rebuild_rows()
	_refresh_detail()

func _label(text: String, color: Color = UI.TEXT, extra: int = 0) -> Label:
	return UI.label(text, _font + extra, color)

func _rebuild_rows() -> void:
	var focused := -1
	for i in _rows.size():
		if _rows[i].has_focus():
			focused = i
	UI.clear(_stage_list)
	_rows.clear()
	if _authored_count() == 0:
		_stage_list.add_child(_label("COMING SOON", UI.GOLD, 8))
		_stage_list.add_child(_label("This module's missions are still being prepared. No stages are available to deploy yet.", UI.MUTED))
		return
	for i in STAGE_COUNT:
		var completed := PlayerManager.has_cleared_stage(_stage_id(i))
		var selected := i == _selected
		var ink := COMPLETED_INK if completed else (_accent() if _can_play(i) else UI.MUTED)
		var fill := (COMPLETED_SELECTED_FILL if selected else COMPLETED_FILL) if completed else (Color("203a40") if selected else Color("13232c"))
		var border := UI.GOLD if selected else (Color("5b936a") if completed else Color("364951"))
		var row := UI.button("", _select_stage.bind(i))
		row.name = "Stage%02d" % (i + 1)
		row.custom_minimum_size.y = maxf(104, _touch + 28)
		row.tooltip_text = _stage_name(i) + " / " + _status(i)
		row.add_theme_stylebox_override("normal", UI.box(fill, border, 14))
		row.add_theme_stylebox_override("hover", UI.box(Color("30543d") if completed else Color("29444a"), UI.GOLD if selected else ink, 14))
		row.add_theme_stylebox_override("pressed", UI.box(COMPLETED_SELECTED_FILL if completed else Color("304c50"), UI.GOLD, 14))
		_stage_list.add_child(row)
		_rows.append(row)
		var content := HBoxContainer.new()
		content.mouse_filter = MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		content.offset_left = 16
		content.offset_right = -16
		content.offset_top = 12
		content.offset_bottom = -12
		content.add_theme_constant_override("separation", 16)
		row.add_child(content)
		var number := _label("%02d" % (i + 1), ink, 10)
		number.custom_minimum_size.x = 48
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(number)
		var lines := UI.column(content, 4)
		lines.mouse_filter = MOUSE_FILTER_IGNORE
		lines.size_flags_horizontal = SIZE_EXPAND_FILL
		lines.size_flags_vertical = SIZE_SHRINK_CENTER
		lines.add_child(_label(_stage_name(i)))
		lines.add_child(_label(_status(i), ink, -3))
		if not _can_play(i):
			var lock := IntelPixelIcon.new()
			lock.kind = IntelPixelIcon.Kind.LOCK
			lock.ink_override = UI.MUTED
			lock.custom_minimum_size = Vector2(48, 48)
			lock.mouse_filter = MOUSE_FILTER_IGNORE
			content.add_child(lock)
		content.resized.connect(_fit_row.bind(row, content))
		_fit_row.call_deferred(row, content)
	if focused >= 0 and focused < _rows.size():
		_rows[focused].grab_focus()

func _fit_row(row: Button, content: Container) -> void:
	if not is_instance_valid(row) or not is_instance_valid(content):
		return
	# Wrapped mission names must increase row height, never overlap the next card.
	row.custom_minimum_size.y = maxf(maxf(104, _touch + 28), content.get_combined_minimum_size().y + 24)

func _refresh_detail() -> void:
	if _briefing_tween != null:
		_briefing_tween.kill()
	_detail.modulate.a = 1.0
	UI.clear(_detail)
	var module := _module_entry()
	var config := _stage_config(_selected)
	var note := Briefings.get_note(_stage_id(_selected))
	var panel := UI.panel(_detail, Color("13242d"))
	panel.add_theme_stylebox_override("panel", UI.box(Color("13242d"), _accent(), 20))
	var content := UI.column(panel, 12)
	content.add_child(_label("M%02d / %02d   —   %s" % [_module_index + 1, _selected + 1, note.eyebrow] if not config.is_empty() else "OPERATION PENDING", _accent(), -2))
	content.add_child(_label(_stage_name(_selected) if not config.is_empty() else "OPERATIONS IN PREPARATION", UI.TEXT, 10))
	var status_ink := COMPLETED_INK if PlayerManager.has_cleared_stage(_stage_id(_selected)) else _accent()
	_reason_label = _label(_status(_selected), status_ink if _can_play(_selected) else UI.GOLD, -3)
	content.add_child(_reason_label)
	if not _can_play(_selected):
		content.add_child(_label(_lock_reason(_selected), UI.MUTED))
	_teaser_label = _label(note.teaser)
	content.add_child(_teaser_label)
	content.add_child(_label(note.hint, UI.GOLD, -2))
	if not config.is_empty():
		var waves: Array = config.get("waves", [])
		var intel := UI.panel(content, Color("0e1e26"))
		var facts := UI.column(intel, 8)
		facts.add_child(_label("KNOWN INTEL", _accent(), -3))
		facts.add_child(_label("%d WAVES    /    %d START GOLD" % [waves.size(), int(config.get("starting_gold", 0))]))
		facts.add_child(_label("Encounter details withheld. Discover the rest in the field.", UI.MUTED, -2))
	var id := str(module.get("id", ""))
	var total := LessonCatalog.lesson_count(id)
	content.add_child(_label("%s  /  LESSONS %d OF %d" % [str(module.get("title", "")).to_upper(), clampi(PlayerManager.get_lesson_progress(id), 0, total), total], UI.MUTED, -3))
	_breach_button.disabled = not _can_play(_selected)
	_preview_button.visible = _module_index == 0 and _selected == 0
	_preview_button.disabled = not _can_play(_selected)
	_breach_button.text = ("REPLAY STAGE %02d  >" if PlayerManager.has_cleared_stage(_stage_id(_selected)) else "DEPLOY STAGE %02d  >") % (_selected + 1)
	if _breach_button.disabled:
		_breach_button.text = "COMING SOON" if config.is_empty() else "LOCKED / SEE REQUIREMENTS"

func _select_stage(index: int) -> void:
	if index < 0 or index >= STAGE_COUNT:
		return
	_selected = index
	current_selected_stage = maxi(0, _launch_index(index))
	_rebuild_rows()
	_refresh_detail()
	(_detail.get_parent() as ScrollContainer).scroll_vertical = 0
	# Brief transmission reveal; text stays readable and clicks never wait on it.
	_detail.modulate.a = 0.72
	_briefing_tween = create_tween()
	_briefing_tween.tween_property(_detail, "modulate:a", 1.0, 0.16)

func _on_breach_pressed() -> void:
	if not _active or not _can_play(_selected):
		return
	current_selected_stage = _launch_index(_selected)
	Router.start_level(current_selected_stage, str(_module_entry().get("id", "mod_01")))

func _on_preview_pressed() -> void:
	if _active and _module_index == 0 and _selected == 0 and _can_play(_selected):
		Router.start_gameplay_preview()

func _status(index: int) -> String:
	if _stage_config(index).is_empty():
		return "COMING SOON"
	if not _is_unlocked(index):
		return "COMPLETED / REVIEW REQUIRED" if PlayerManager.has_cleared_stage(_stage_id(index)) else "LOCKED"
	return "COMPLETED / REPLAY AVAILABLE" if PlayerManager.has_cleared_stage(_stage_id(index)) else "AVAILABLE / READY TO DEPLOY"

func _lock_reason(index: int) -> String:
	if _stage_config(index).is_empty():
		return "This module's stages have not been authored yet. Check back for future operations."
	return StageManager.access_reason(_stage_id(index), str(_module_entry().get("id", "")))

func _first_playable() -> int:
	for i in STAGE_COUNT:
		if _can_play(i):
			return i
	return 0

func _is_unlocked(index: int) -> bool:
	return StageManager.access_reason(_stage_id(index), str(_module_entry().get("id", ""))).is_empty()

func _can_play(index: int) -> bool:
	return index >= 0 and index < STAGE_COUNT and _is_unlocked(index) and not _stage_config(index).is_empty()

func _stage_id(index: int) -> int:
	return index + 1 if _module_index in [0, 1, 2, 3, 4] and index >= 0 and index < STAGE_COUNT else -1

func _launch_index(index: int) -> int:
	return _stage_id(index) - 1 if _stage_id(index) > 0 else -1

func _stage_config(index: int) -> Dictionary:
	return StageManager.get_stage_config(_stage_id(index)) if _stage_id(index) > 0 else {}

func _stage_name(index: int) -> String:
	return str(_stage_config(index).get("name", "STAGE %d" % (index + 1))).to_upper()

func _module_entry() -> Dictionary:
	return _modules[_module_index] if _module_index >= 0 and _module_index < _modules.size() else {}

func _accent() -> Color:
	return ACCENTS[_module_index]

func _authored_count() -> int:
	var total := 0
	for i in STAGE_COUNT:
		if not _stage_config(i).is_empty():
			total += 1
	return total

func _cleared_count() -> int:
	var total := 0
	for i in STAGE_COUNT:
		if not _stage_config(i).is_empty() and PlayerManager.has_cleared_stage(_stage_id(i)):
			total += 1
	return total
