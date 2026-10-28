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
var _reason_label: Label
var _header: HBoxContainer
var _profile_name: Label
var _profile_rank: Label
var _teaser_label: Label
var _briefing_tween: Tween
var _chapters: bool = false
var _chapter_preview: ChapterPreview
var _intro_button: Button
var _practice_button: Button

class ChapterPreview extends Control:
	var artwork: Texture2D
	var chapter: int = 1
	var sealed: bool = false
	var started: bool = false
	var unlocked: bool = true

	func _text(value: String, point: Vector2, pixels: int, ink: Color) -> void:
		draw_string(UI.FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, ink)

	func _draw() -> void:
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		var u: float = 1.0 / physical
		var bounds: Rect2 = Rect2(Vector2.ZERO, size)
		var panel: StyleBoxFlat = UI.box(Color("13242d"), Color("8dc9bd"), 0)
		draw_style_box(panel, bounds)
		if artwork != null and chapter <= 5:
			var source: Vector2 = artwork.get_size()
			var ratio: float = maxf(size.x / source.x, size.y / source.y)
			var crop: Vector2 = size / ratio
			draw_texture_rect_region(artwork, bounds.grow(-2), Rect2((source - crop) * 0.5, crop))
		# Darken only enough to keep cream text readable, with a stronger lower fade.
		for band: int in 64:
			var p: float = float(band) / 63.0
			var opacity: float = lerpf(0.18, 0.98, smoothstep(0.12, 0.82, p))
			draw_rect(Rect2(2, 2 + band * (size.y - 4) / 64.0, size.x - 4, (size.y - 4) / 64.0), Color(UI.BG, opacity))
		var margin: float = 20 * u
		var small: int = ceili(16 * u)
		_text("MODULE 01   /   EMAIL TRICKS", Vector2(margin, 30 * u), small, UI.TEAL)
		var title_y: float = maxf(95 * u, size.y - (70 if sealed else 102) * u)
		_text("CHAPTER %02d" % chapter, Vector2(margin, title_y - 34 * u), small, UI.TEAL)
		_text("The Survey" if chapter == 1 else ("The Advisor Email" if chapter == 2 else ("The Payout" if chapter == 3 else ("The Prize" if chapter == 4 else "Confrontation"))), Vector2(margin, title_y), ceili(32 * u), UI.TEXT)
		_text("A friendly offer. Six messages." if chapter == 1 else ("A familiar name. An unfamiliar address." if chapter == 2 else ("The reward is ready. One more step." if chapter == 3 else ("The same morning. The same button." if chapter == 4 else "Four exhibits. One confrontation."))), Vector2(margin, title_y + 28 * u), ceili(16 * u), UI.TEXT)
		_text("Something doesn't add up." if chapter == 1 else ("One character changes everything." if chapter == 2 else ("Read the destination. Not the promise." if chapter == 3 else ("Now you know what came before." if chapter == 4 else "Challenge the claim. Follow the evidence."))), Vector2(margin, title_y + 50 * u), ceili(16 * u), UI.TEXT)
		if sealed: return
		var status: String = ("COMPLETE CHAPTER %d" % (chapter - 1) if not unlocked else ("IN PROGRESS" if started else "READY TO BEGIN")) if chapter <= 5 else "COMING SOON"
		var badge: Rect2 = Rect2(margin, size.y - 31 * u, UI.FONT.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 20 * u, 24 * u)
		var badge_style: StyleBoxFlat = UI.box(Color("203a40") if chapter == 1 else UI.PANEL, Color("48635f"), 0)
		draw_style_box(badge_style, badge)
		_text(status, badge.position + Vector2(10, 17) * u, small, UI.TEAL)

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
	_intro_button = UI.button("REPLAY INTRO", func() -> void: Router.push(&"module_intro", {"module_index":0}))
	_intro_button.hide()
	var chapter_actions: HBoxContainer = HBoxContainer.new()
	chapter_actions.add_theme_constant_override("separation",12)
	chapter_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	briefing.add_child(chapter_actions)
	chapter_actions.add_child(_intro_button)
	_practice_button = UI.button("PRACTICE",func() -> void: Router.push(&"lesson_player",{"practice":true}))
	chapter_actions.add_child(_practice_button)
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
	AssetManager.sync_finished.connect(_chapter_art_ready)
	(_detail.get_parent() as ScrollContainer).resized.connect(_fit_chapter_preview)
	set_process(false)

func on_enter(args: Dictionary) -> void:
	_modules = LessonCatalog.modules()
	_module_index = clampi(int(args.get("module_index", 0)), 0, maxi(0, _modules.size() - 1))
	_chapters = _module_index == 0 and bool(args.get("chapters", false))
	_selected = _first_playable()
	if _chapters: _selected = 0
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
	return str([PlayerManager.max_stage_cleared_by_module, PlayerManager.cleared_stages,
		PlayerManager.lesson_progress, PlayerManager.completed_lessons,
		PlayerManager.locked_stages, PlayerManager.credits, PlayerManager.pvp_tokens, PlayerManager.chapter_progress])

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
	for button in [_back, _settings, _profile, _breach_button]:
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
	_wallet.text = "THREAT   %d\nCREDITS  %d" % [PlayerManager.pvp_tokens, maxi(0, PlayerManager.credits)]
	_wallet.add_theme_font_size_override("font_size", _font - 2)
	_title.text = "CHAPTER\nSELECT" if _chapters else "MISSION\nSELECT"
	_intro_button.visible = _chapters
	_practice_button.visible = _chapters and not LessonCatalog.practice_recommendation(PlayerManager).is_empty()
	if _chapters:
		_profile.size_flags_horizontal = SIZE_SHRINK_END
		_profile.custom_minimum_size = Vector2(210 / scale_y, _touch)
		_profile_name.add_theme_font_size_override("font_size", ceili(20 / scale_y))
		_profile_rank.add_theme_font_size_override("font_size", ceili(16 / scale_y))
		_wallet.text = "%d CREDITS" % maxi(0, PlayerManager.credits)
		_wallet.add_theme_color_override("font_color", UI.TEXT)
		for button: Button in [_back, _settings, _intro_button, _practice_button]: UI.style_button(button)
		UI.style_button(_breach_button, true)
		_intro_button.custom_minimum_size.y = _touch
		_practice_button.custom_minimum_size.y = _touch
		_practice_button.add_theme_font_size_override("font_size",ceili(16 / scale_y))
		_intro_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		_intro_button.add_theme_font_size_override("font_size", ceili(16 / scale_y))
		_intro_button.size_flags_horizontal = SIZE_SHRINK_CENTER
		_body.add_theme_constant_override("separation", ceili(24 / scale_y))
		_build_chapters()
		return
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
		var completed := PlayerManager.has_cleared_stage(_module_id(), _stage_id(i))
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
	var note := Briefings.get_note(_stage_id(_selected), str(_module_entry().get("id", "")))
	var panel := UI.panel(_detail, Color("13242d"))
	panel.add_theme_stylebox_override("panel", UI.box(Color("13242d"), _accent(), 20))
	var content := UI.column(panel, 12)
	content.add_child(_label("M%02d / %02d   —   %s" % [_module_index + 1, _selected + 1, note.eyebrow] if not config.is_empty() else "OPERATION PENDING", _accent(), -2))
	content.add_child(_label(_stage_name(_selected) if not config.is_empty() else "OPERATIONS IN PREPARATION", UI.TEXT, 10))
	var status_ink := COMPLETED_INK if PlayerManager.has_cleared_stage(_module_id(), _stage_id(_selected)) else _accent()
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
	_breach_button.text = ("REPLAY STAGE %02d  >" if PlayerManager.has_cleared_stage(_module_id(), _stage_id(_selected)) else "DEPLOY STAGE %02d  >") % (_selected + 1)
	if StageRemediation.pending(PlayerManager, _module_id(), _stage_id(_selected)):
		_breach_button.text = "CONTINUE TARGETED REVIEW"
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
	if _chapters:
		var chapter_id: String = "mod_01_ch_%02d" % (_selected + 1)
		if _active and _selected < 5 and PlayerManager.story_unlocked(chapter_id):
			Router.push(&"confrontation" if _selected == 4 else &"upgrades", {"deploy":true, "chapter_id":chapter_id, "replay": bool(PlayerManager.chapter_progress.get(chapter_id, {}).get("completed", false))})
		return
	if not _active or not _can_play(_selected):
		return
	current_selected_stage = _launch_index(_selected)
	Router.start_level(current_selected_stage, str(_module_entry().get("id", "mod_01")))

func _build_chapters() -> void:
	if _briefing_tween != null: _briefing_tween.kill()
	_detail.modulate.a = 1.0
	var focused: int = -1
	for index: int in _rows.size():
		if _rows[index].has_focus(): focused = index
	var chapter_id: String = "mod_01_ch_%02d" % (_selected + 1)
	var progress: Dictionary = PlayerManager.chapter_progress.get(chapter_id, {})
	var complete: bool = bool(progress.get("completed", false))
	var sealed_count: int = 0
	for id: String in ["mod_01_ch_01", "mod_01_ch_02", "mod_01_ch_03", "mod_01_ch_04", "mod_01_ch_05"]:
		if PlayerManager.chapter_progress.get(id, {}).get("completed", false): sealed_count += 1
	_summary.text = "CHAPTERS    /    %d OF 5 SEALED" % sealed_count
	_summary.add_theme_font_size_override("font_size", _font - 2)
	_completion.max_value = 5
	_completion.value = sealed_count
	_completion.add_theme_stylebox_override("fill", UI.box(COMPLETED_INK if complete else UI.TEAL, COMPLETED_INK if complete else UI.TEAL, 0))
	UI.clear(_stage_list)
	_rows.clear()
	for index: int in 5:
		var id: String = "mod_01_ch_%02d" % (index + 1)
		var completed: bool = PlayerManager.chapter_progress.get(id, {}).get("completed", false)
		var unlocked: bool = PlayerManager.story_unlocked(id)
		var selected: bool = index == _selected
		var caption: String = "The Survey" if index == 0 else ("The Advisor Email" if index == 1 else ("The Payout" if index == 2 else ("The Prize" if index == 3 else "Confrontation")))
		var status: String = "AVAILABLE" if unlocked else "COMPLETE CHAPTER %d" % index
		var row: Button = UI.button("", _select_chapter.bind(index))
		row.accessibility_name = "Chapter %d. %s. %s" % [index + 1, caption, "Completed." if completed else status]
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		row.custom_minimum_size.y = 84 / physical
		var fill: Color = (COMPLETED_SELECTED_FILL if selected else COMPLETED_FILL) if completed else (Color("203a40") if selected else Color("13232c"))
		var border: Color = COMPLETED_INK if completed else (ACCENTS[0] if selected else Color("364951"))
		row.add_theme_stylebox_override("normal", UI.box(fill, border, 14))
		row.add_theme_stylebox_override("hover", UI.box(Color("30543d") if completed else Color("29444a"), border, 14))
		row.add_theme_stylebox_override("pressed", UI.box(COMPLETED_SELECTED_FILL if completed else Color("304c50"), UI.GOLD, 14))
		_stage_list.add_child(row)
		_rows.append(row)
		var content: HBoxContainer = HBoxContainer.new()
		content.mouse_filter = MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		content.offset_left = 18 / physical
		content.offset_right = -18 / physical
		content.offset_top = 12 / physical
		content.offset_bottom = -12 / physical
		content.add_theme_constant_override("separation", ceili(16 / physical))
		row.add_child(content)
		var number: Label = UI.label("%02d" % (index + 1), maxi(_font + 10, ceili(24 / physical)), COMPLETED_INK if completed else (ACCENTS[0] if index == 0 else UI.MUTED))
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.custom_minimum_size.x = 48 / physical
		content.add_child(number)
		var copy: VBoxContainer = UI.column(content, 6)
		copy.mouse_filter = MOUSE_FILTER_IGNORE
		copy.size_flags_vertical = SIZE_SHRINK_CENTER
		copy.size_flags_horizontal = SIZE_EXPAND_FILL
		copy.add_child(UI.label(caption, maxi(_font, ceili(21 / physical)), UI.TEXT))
		if not completed:
			copy.add_child(UI.label(status, maxi(_font - 3, ceili(14 / physical)), ACCENTS[0] if index == 0 else UI.MUTED))
		if completed:
			var badge: Label = UI.label("COMPLETED", ceili(14 / physical), COMPLETED_INK)
			badge.name = "CompletionBadge"
			badge.autowrap_mode = TextServer.AUTOWRAP_OFF
			badge.size_flags_vertical = SIZE_SHRINK_CENTER
			badge.add_theme_stylebox_override("normal", UI.box(Color("0e271b"), Color("5b936a"), ceili(8 / physical)))
			content.add_child(badge)
		if not unlocked:
			var lock: IntelPixelIcon = IntelPixelIcon.new()
			lock.kind = IntelPixelIcon.Kind.LOCK
			lock.ink_override = UI.MUTED
			lock.custom_minimum_size = Vector2(20,20) / physical
			lock.size_flags_vertical = SIZE_SHRINK_CENTER
			lock.mouse_filter = MOUSE_FILTER_IGNORE
			content.add_child(lock)
	UI.clear(_detail)
	_chapter_preview = ChapterPreview.new()
	_chapter_preview.chapter = _selected + 1
	_chapter_preview.sealed = complete
	_chapter_preview.started = not progress.is_empty()
	_chapter_preview.unlocked = PlayerManager.story_unlocked(chapter_id)
	_chapter_preview.artwork = _selected_chapter_art()
	_chapter_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_chapter_preview.accessibility_name = "The Survey. A friendly offer. Six messages." if _selected == 0 else ("The Advisor Email. A familiar name. An unfamiliar address." if _selected == 1 else ("The Payout. Read the destination, not the promise." if _selected == 2 else ("The Prize. Return to the morning from the intro." if _selected == 3 else "Confrontation. Challenge the claim. Follow the evidence.")))
	_detail.add_child(_chapter_preview)
	_fit_chapter_preview()
	if _selected < 5:
		_breach_button.text = "REPLAY" if complete else ("CONTINUE" if not progress.is_empty() else "START")
		_breach_button.disabled = not PlayerManager.story_unlocked(chapter_id)
		if _breach_button.disabled: _breach_button.text = "COMPLETE CHAPTER %d FIRST" % _selected if _selected > 0 else "COMPLETE LESSON FIRST"
	else:
		_breach_button.text = "COMING SOON"
		_breach_button.disabled = true
	if focused >= 0 and focused < _rows.size(): _rows[focused].grab_focus()

func _fit_chapter_preview() -> void:
	if not _chapters or not is_instance_valid(_chapter_preview): return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	_chapter_preview.custom_minimum_size.y = maxf(190 / physical, (_detail.get_parent() as Control).size.y - 2)
	_chapter_preview.queue_redraw()

func _chapter_art_ready(_success: bool) -> void:
	if not is_instance_valid(_chapter_preview): return
	_chapter_preview.artwork = _selected_chapter_art()
	_chapter_preview.queue_redraw()

func _selected_chapter_art() -> Texture2D:
	var covers: PackedStringArray = ["story_bg_john_desk_night", "story_chapter2_cover", "story_chapter3_cover", "story_chapter4_cover", "opening_collector_meeting_v2"]
	return AssetManager.get_texture(covers[clampi(_selected, 0, covers.size()-1)])

func _select_chapter(index: int) -> void:
	if _briefing_tween != null: _briefing_tween.kill()
	_selected = clampi(index, 0, 4)
	_build_chapters()
	_rows[_selected].grab_focus()
	_scroll_to_chapter.call_deferred()
	_detail.modulate.a = 1.0
	if not SettingsService.reduced_motion:
		_detail.modulate.a = 0.65
		_briefing_tween = create_tween()
		_briefing_tween.tween_property(_detail, "modulate:a", 1.0, 0.2)

func _scroll_to_chapter() -> void:
	# A resize or progress refresh can replace cards before the deferred layout.
	if _active and _chapters and _selected < _rows.size():
		(_stage_list.get_parent() as ScrollContainer).ensure_control_visible(_rows[_selected])

func _status(index: int) -> String:
	if _stage_config(index).is_empty():
		return "COMING SOON"
	if not _is_unlocked(index):
		return "COMPLETED / REVIEW REQUIRED" if PlayerManager.has_cleared_stage(_module_id(), _stage_id(index)) else "LOCKED"
	if StageRemediation.pending(PlayerManager, _module_id(), _stage_id(index)):
		return "TARGETED REVIEW / CONTINUE BEFORE RETRY"
	return "COMPLETED / REPLAY AVAILABLE" if PlayerManager.has_cleared_stage(_module_id(), _stage_id(index)) else "AVAILABLE / READY TO DEPLOY"

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
	# Decision-story stages carry their own authored title; every other stage
	# keeps the shared stages.json name (used by all 5 modules alike).
	var module_id: String = str(_module_entry().get("id", ""))
	var decision_title: String = str(DecisionScenarios.get_stage(module_id, _stage_id(index)).get("title", "")).strip_edges()
	if not decision_title.is_empty():
		return decision_title.to_upper()
	return str(_stage_config(index).get("name", "STAGE %d" % (index + 1))).to_upper()

func _module_entry() -> Dictionary:
	return _modules[_module_index] if _module_index >= 0 and _module_index < _modules.size() else {}

func _module_id() -> String:
	return str(_module_entry().get("id", ""))

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
		if not _stage_config(i).is_empty() and PlayerManager.has_cleared_stage(_module_id(), _stage_id(i)):
			total += 1
	return total
