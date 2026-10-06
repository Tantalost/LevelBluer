@tool
extends BaseScreen
## Scenic command outpost. Menu geometry is shared with the original dashboard.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const DEFAULT_MATERIALS := 200
const DEFAULT_THREAT_POINTS := 1000
const DEFAULT_CURRENT_STAGE := 1
const STAGE_TOTAL := 10
const HEADER_FILL := Color("18252bf2")
const HEADER_TEXT := Color("e8e8da")
const HEADER_MUTED := Color("a4b8b7")
const HEADER_ACCENT := Color("8dc9bd")
const Access = preload("res://src/ui/screens/dashboard/world_access.gd")
const WorldJournal = preload("res://src/ui/screens/dashboard/world_journal.gd")
const StudyUI = preload("res://src/ui/screens/intel/study_ui.gd")
const PvpHub = preload("res://src/ui/screens/dashboard/dashboard_pvp_hub.gd")
signal mode_switch_finished(mode: StringName)

@onready var _game_title: Label = %GameTitle
@onready var _profile_button: HudGeoButton = %ProfileButton
@onready var _avatar_box: PanelContainer = %AvatarBox
@onready var _player_name: Label = %PlayerName
@onready var _rank: Label = %RankLabel
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _threat_caption: Label = %ThreatCaption
@onready var _materials_caption: Label = %MaterialsCaption
@onready var _top_bar_panel: PanelContainer = %HeaderBand
@onready var _map_dim: ColorRect = %MapDim
@onready var _inbox_button: HudGeoButton = %InboxButton
@onready var _settings_button: HudGeoButton = %SettingsButton
@onready var _inbox_badge: PanelContainer = %InboxBadge
@onready var _inbox_count: Label = %InboxCount
@onready var _at_risk: PanelContainer = %AtRiskBanner
@onready var _at_risk_sub: Label = %AtRiskSub
@onready var _at_risk_pill: Label = %AtRiskPill
@onready var _at_risk_title: Label = %AtRiskTitle
@onready var _world_button: HudGeoButton = %WorldButton
@onready var _mode_selector: HudGeoButton = %ModeSelector
@onready var _deploy_button: HudGeoButton = %DeployButton
@onready var _lessons_button: HudGeoButton = %LessonsButton
@onready var _codex_button: HudGeoButton = %CodexButton
@onready var _store_button: HudGeoButton = %StoreButton
@onready var _progress_button: HudGeoButton = %ProgressButton
@onready var _updates_title: Label = %UpdatesTitle
@onready var _updates_body: Label = %UpdatesBody
@onready var _mode_modal: DashboardModeModal = %ModeModal
@onready var _lock_window: PanelContainer = %LockWindow
@onready var _lock_title_bar: PanelContainer = %LockTitleBar
@onready var _lock_well: PanelContainer = %LockWell
@onready var _lock_settings: Button = %LockSettingsButton

var _pixel_font: Font
var _tutorial_gate: Control = null
var _selected_mode: StringName = &"SOLO"
var _materials: int = DEFAULT_MATERIALS
var _threat_points: int = DEFAULT_THREAT_POINTS
var _current_stage: int = DEFAULT_CURRENT_STAGE
var _menu_rects: Dictionary = {}
var _world_access: Dictionary = {}
var _access_modal: Control
var _access_action: Button
var _access_queued := false
var _world_status_copy: VBoxContainer
var _world_status_heading: Label
var _world_status_body: Label
var _pvp_hub: Control
var _power_overlay: PowerOverlay
var _power_tween: Tween
var _mode_transitioning: bool = false
var _pending_mode: StringName = &"SOLO"

class PowerOverlay extends Control:
	var closure: float = 0.0:
		set(value):
			closure = value
			queue_redraw()
	var accent: Color = Color("#4FE0D4")
	var reduced: bool = false
	var boot_text: Label
	func _draw() -> void:
		if reduced:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.03, closure))
			return
		var height: float = size.y * 0.5 * closure
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, height)), Color("#020306"))
		draw_rect(Rect2(Vector2(0, size.y - height), Vector2(size.x, height)), Color("#020306"))
		if closure > 0.1 and closure < 1.0:
			var alpha: float = minf(0.7, (1.0 - closure) * 12.0)
			draw_line(Vector2(0, height), Vector2(size.x, height), Color(accent, alpha), 2)
			draw_line(Vector2(0, size.y - height), Vector2(size.x, size.y - height), Color(accent, alpha), 2)
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		focus_mode = FOCUS_ALL
		resized.connect(queue_redraw)
		boot_text = StudyUI.label("", 30, Color("#F3ECD6"))
		boot_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boot_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(boot_text)
		boot_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		boot_text.hide()
	func _input(event: InputEvent) -> void:
		if visible and (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
			get_viewport().set_input_as_handled()


func _ready() -> void:
	_load_font()
	_style_chrome()
	_setup_surroundings()
	if Engine.is_editor_hint():
		return
	_setup_mode_workspace()
	_store_button.pressed.connect(func() -> void: Router.push(&"store"))
	_lessons_button.pressed.connect(func() -> void: Router.push(&"lessons"))
	_codex_button.pressed.connect(func() -> void: Router.push(&"codex"))
	_progress_button.pressed.connect(func() -> void: Router.push(&"progress"))
	_inbox_button.pressed.connect(func() -> void: push_warning("Inbox screen not built yet"))
	_settings_button.pressed.connect(func() -> void: Router.push(&"settings"))
	_profile_button.pressed.connect(func() -> void: Router.push(&"profile"))
	_world_button.pressed.connect(_on_mission_pressed)
	_mode_selector.pressed.connect(_open_mode_modal)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	_mode_modal.mode_confirmed.connect(_on_mode_confirmed)
	AuthService.progress_changed.connect(_queue_access_refresh)
	AuthService.session_changed.connect(_access_session_changed)
	get_viewport().size_changed.connect(_queue_access_refresh)


func on_enter(_args: Dictionary) -> void:
	SaveService.push_pending_sync()
	_bind_remote_art()
	_refresh_data()
	_apply_lock_state()
	_update_mode_ui()
	_apply_tutorial_gate()


func _bind_remote_art() -> void:
	# Separate ID: legacy dashboard art is still used inside the central buttons.
	# The scenic background is downloaded and cached by AssetManager.
	AssetManager.bind_texture($Background as CanvasItem, "ui_dashboard_scenic")
	AssetManager.bind_texture(find_child("AvatarImage", true, false) as CanvasItem, "ui_pfp")
	AssetManager.bind_texture(find_child("SettingsIcon", true, false) as CanvasItem, "ui_setting")
	AssetManager.bind_texture(find_child("LockSettingsIcon", true, false) as CanvasItem, "ui_setting")


func on_resume() -> void:
	_refresh_data()
	_apply_lock_state()
	_apply_tutorial_gate()
	_update_mode_ui()


func on_exit() -> void:
	_close_access()
	_mode_modal.dismiss()
	_cancel_mode_transition()
	%Companion.close_dialogue()


func _style_chrome() -> void:
	_map_dim.color = Color("101c262e")
	_style_top_bar()
	_style_avatar()
	_style_badge()
	_style_at_risk()
	_style_icon_button(_lock_settings)
	_style_window(_lock_window, Palette.PRIMARY_BLUE)
	_style_title_bar(_lock_title_bar, Palette.NAVY_700)
	_style_well(_lock_well, Palette.TEAL_800)
	_style_cta(%PreTestButton, Palette.PRIMARY_BLUE, Palette.CREAM)
	_apply_label(_game_title, HEADER_TEXT, 14)
	_apply_label(_player_name, HEADER_TEXT, 11)
	_apply_label(_rank, HEADER_ACCENT, 8)
	_apply_label(_threat_caption, HEADER_MUTED, 8)
	_apply_label(_materials_caption, HEADER_MUTED, 8)
	_materials_caption.text = "CREDITS"
	_apply_label(_threat_value, Palette.CREAM, 10)
	_apply_label(_materials_value, Palette.CREAM, 10)
	_apply_label(_inbox_count, Palette.CREAM, 10)
	_apply_label(_at_risk_title, Palette.CREAM, 13)
	_apply_label(_at_risk_sub, Palette.CREAM, 11)
	_apply_label(_at_risk_pill, Palette.CREAM, 16)
	_apply_label(_updates_title, HEADER_ACCENT, 8)
	_apply_label(_updates_body, HEADER_TEXT, 9)
	_apply_label(%LockTitle, Palette.CREAM, 16)
	_apply_label(%LockBody, Palette.CREAM, 12)
	var lock_file: Label = _lock_title_bar.find_child("LockFile", true, false) as Label
	if lock_file != null:
		_apply_label(lock_file, Palette.CREAM, 11)


func _apply_lock_state() -> void:
	%PreTestLock.visible = false


func _refresh_data() -> void:
	_threat_points = AuthService.wallet_threat_points()
	_materials = PlayerManager.credits
	_current_stage = AuthService.current_stage()
	_player_name.text = AuthService.display_name().to_upper()
	_threat_value.text = str(_threat_points)
	_materials_value.text = str(_materials)
	_rank.text = AuthService.rank_title().to_upper()
	_deploy_button.title = "DEPLOY"
	_deploy_button.subtitle = ""
	_lessons_button.title = "LESSONS"
	_lessons_button.subtitle = ""
	_codex_button.title = "CODEX"
	_codex_button.subtitle = ""
	_store_button.title = tr("DASH_STORE").to_upper()
	_progress_button.title = tr("DASH_PROGRESS").to_upper()
	_progress_button.subtitle = ""
	_world_button.title = "WORLD"
	_world_button.subtitle = "CONTINUE"
	_world_button.detail = ""
	_world_button.progress = -1.0
	_world_button.queue_redraw()
	_deploy_button.queue_redraw()
	_lessons_button.queue_redraw()
	_codex_button.queue_redraw()
	_store_button.queue_redraw()
	_progress_button.queue_redraw()
	_at_risk_title.text = tr("DASH_AT_RISK_TITLE")
	_refresh_at_risk()
	_refresh_world()
	_refresh_updates()


func _refresh_at_risk() -> void:
	var avg := AuthService.average_mastery()
	var weak := AuthService.weak_mastery_topics()
	var is_at_risk := avg >= 0.0 and avg < 0.40
	_at_risk.visible = is_at_risk
	if not is_at_risk:
		return
	var pct := avg * 100.0
	var weak_text := ""
	if not weak.is_empty():
		weak_text = tr("DASH_AT_RISK_WEAK") % ", ".join(weak)
	_at_risk_sub.text = tr("DASH_AT_RISK_BODY") % [pct, weak_text]
	_at_risk_pill.text = "%d%%" % int(round(pct))


func _refresh_world() -> void:
	_world_button.visible = true
	_world_button.title = "WORLD"
	if Engine.is_editor_hint():
		return
	_world_access = Access.snapshot()
	_world_button.subtitle = str(_world_access.heading)
	_world_button.subtitle_size = 12
	_world_button.detail = str(_world_access.short)
	_world_button.detail_size = 12
	_world_button.progress = -1.0
	if _world_status_copy == null:
		_world_status_copy = VBoxContainer.new()
		_world_status_copy.name = "AccessStatus"
		_world_status_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world_status_copy.position = Vector2(60, 108)
		_world_status_copy.size = Vector2(240, 148)
		_world_status_copy.alignment = BoxContainer.ALIGNMENT_CENTER
		_world_status_copy.add_theme_constant_override("separation", 8)
		_world_button.add_child(_world_status_copy)
		var title := StudyUI.label("WORLD", 26, Palette.INK, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_world_status_copy.add_child(title)
		_world_status_heading = StudyUI.label("", 24, Palette.INK)
		_world_status_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_world_status_copy.add_child(_world_status_heading)
		_world_status_body = StudyUI.label("", 24, Palette.INK)
		_world_status_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_world_status_copy.add_child(_world_status_body)
	_world_status_heading.text = str(_world_access.heading)
	_world_status_body.text = str(_world_access.short)
	_world_button.title = ""
	_world_button.subtitle = ""
	_world_button.detail = ""
	_world_button.tooltip_text = str(_world_access.explanation)
	_inbox_badge.visible = true
	_inbox_count.text = str(_world_access.badge)
	_inbox_count.add_theme_font_size_override("font_size", 10)
	var accent := StudyUI.GOLD if _world_access.locked else StudyUI.TEAL
	_inbox_badge.add_theme_stylebox_override("panel", StudyUI.box(Color("18252b"), accent, 6))
	_inbox_count.add_theme_color_override("font_color", accent)
	_world_button.queue_redraw()

func _queue_access_refresh() -> void:
	if _access_queued:
		return
	_access_queued = true
	_refresh_access.call_deferred()

func _access_session_changed(_signed_in: bool) -> void:
	_close_access()
	_queue_access_refresh()

func _refresh_access() -> void:
	_access_queued = false
	if not is_inside_tree():
		return
	_refresh_world()
	if is_instance_valid(_access_modal) and _access_modal.visible:
		_fill_access()

func _close_access() -> void:
	if is_instance_valid(_access_modal):
		_access_modal.close()

func can_go_back() -> bool:
	if is_instance_valid(_access_modal) and _access_modal.visible:
		_access_modal.back()
		return false
	return true

func _show_access() -> void:
	%Companion.close_dialogue()
	_refresh_world()
	if not is_instance_valid(_access_modal):
		_access_modal = WorldJournal.new()
		_access_modal.name = "WorldJournal"
		add_child(_access_modal)
		_access_modal.route_requested.connect(_access_go)
		_access_modal.missions_requested.connect(_access_missions)
		_access_action = _access_modal.action
	_access_modal.open(_world_access)

func _fill_access() -> void:
	_access_modal.refresh(_world_access)

func _access_go(route: StringName) -> void:
	_close_access()
	Router.push(route)

func _access_missions() -> void:
	_close_access()
	Router.open_missions_screen()


func _refresh_updates() -> void:
	_updates_title.text = "FIELD PROGRESS"
	var stage_cleared: int = clampi(PlayerManager.max_stage_cleared("mod_01"), 0, STAGE_TOTAL)
	var lesson_done: int = LessonCatalog.completed_units()
	var lesson_total: int = LessonCatalog.total_units()
	_updates_body.text = "STAGE %d/%d    /    LESSONS %d/%d" % [stage_cleared, STAGE_TOTAL, lesson_done, lesson_total]


func _open_mode_modal() -> void:
	if PlayerManager.needs_tutorial() or _mode_transitioning:
		return
	%Companion.close_dialogue()
	var mode := DashboardModeModal.Mode.SOLO if _selected_mode == &"SOLO" else DashboardModeModal.Mode.PVP
	_mode_modal.open(mode, get_viewport().get_visible_rect().size.x)


func _on_mode_confirmed(mode: StringName) -> void:
	if _mode_transitioning or mode not in [&"SOLO", &"PVP"]:
		return
	if mode == _selected_mode:
		return
	_pending_mode = mode
	_mode_transitioning = true
	_mode_modal.dismiss()
	_close_access()
	%Companion.close_dialogue()
	_power_overlay.reduced = SettingsService.reduced_motion
	_power_overlay.accent = Color("#4FE0D4") if _selected_mode == &"SOLO" else Color("#FF5C5C")
	_power_overlay.closure = 0.0
	_power_overlay.boot_text.hide()
	_power_overlay.show()
	move_child(_power_overlay, get_child_count() - 1)
	_power_overlay.grab_focus()
	_power_tween = create_tween()
	_power_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_power_tween.tween_property(_power_overlay, "closure", 1.0, 0.12 if SettingsService.reduced_motion else 0.42)
	_power_tween.tween_callback(_commit_mode_switch)
	_power_tween.tween_interval(0.1 if SettingsService.reduced_motion else 0.28)
	_power_tween.tween_callback(_power_overlay.boot_text.hide)
	_power_tween.tween_property(_power_overlay, "closure", 0.0, 0.12 if SettingsService.reduced_motion else 0.46)
	_power_tween.tween_callback(_finish_mode_transition)


func _setup_mode_workspace() -> void:
	var main: Control = $SafeAreaContainer/ScreenLayout/MainRow
	_mode_selector.reparent(main)
	_mode_selector.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_mode_selector.custom_minimum_size = Vector2(104, 104)
	_mode_selector.size = Vector2(104, 104)
	_mode_selector.geo = HudGeoButton.Geo.DIAMOND
	_mode_selector.tooltip_text = "Switch between Solo and PvP"
	_mode_selector.focus_mode = Control.FOCUS_ALL
	_mode_selector.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			_open_mode_modal()
			_mode_selector.accept_event()
	)
	var glyph: IntelPixelIcon = %ModeGlyph
	glyph.kind = IntelPixelIcon.Kind.SWAP
	glyph.ink_override = Color("#101623")
	glyph.show()
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glyph.position = Vector2(24, 24)
	glyph.size = Vector2(56, 56)
	_pvp_hub = PvpHub.new()
	_pvp_hub.name = "PvpWorkspace"
	add_child(_pvp_hub)
	_pvp_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pvp_hub.switch_requested.connect(_open_mode_modal)
	_pvp_hub.hide()
	# Keep the selector above either OS without global z-indices leaking through Router.
	move_child(_mode_modal, get_child_count() - 1)
	_power_overlay = PowerOverlay.new()
	_power_overlay.name = "OSPowerTransition"
	add_child(_power_overlay)
	_power_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_overlay.hide()
	_layout_surroundings()


func _commit_mode_switch() -> void:
	_selected_mode = _pending_mode
	_update_mode_ui()
	_power_overlay.accent = Color("#4FE0D4") if _selected_mode == &"SOLO" else Color("#FF5C5C")
	_power_overlay.boot_text.text = ("BLUE OS" if _selected_mode == &"SOLO" else "RED OS") + " / INITIALIZING"
	_power_overlay.boot_text.add_theme_color_override("font_color", _power_overlay.accent)
	_power_overlay.boot_text.show()


func _finish_mode_transition() -> void:
	_power_overlay.hide()
	_power_overlay.boot_text.hide()
	_mode_transitioning = false
	if _selected_mode == &"PVP":
		_pvp_hub._switch.grab_focus()
	else:
		_mode_selector.grab_focus()
	mode_switch_finished.emit(_selected_mode)


func _cancel_mode_transition() -> void:
	if _power_tween != null:
		_power_tween.kill()
	_mode_transitioning = false
	if is_instance_valid(_power_overlay):
		_power_overlay.hide()
		_power_overlay.closure = 0.0
		_power_overlay.boot_text.hide()


func _exit_tree() -> void:
	_cancel_mode_transition()


func _update_mode_ui() -> void:
	var is_solo := _selected_mode == &"SOLO"
	_mode_selector.title = ""
	_mode_selector.border_key = "cyan" if is_solo else "red"
	_mode_selector.fill_key = "frost"
	_mode_selector.queue_redraw()
	_deploy_button.title = "DEPLOY"
	_deploy_button.subtitle = ""
	_deploy_button.fill_key = "frost"
	_deploy_button.border_key = "cream"
	_deploy_button.queue_redraw()
	_world_button.fill_key = "frost"
	_world_button.border_key = "cream"
	_refresh_world()
	if is_instance_valid(_pvp_hub):
		_pvp_hub.visible = not is_solo
		$SafeAreaContainer.visible = is_solo
		$HeaderBand.visible = is_solo
		if not is_solo:
			_pvp_hub.refresh_identity()


func _on_mission_pressed() -> void:
	if PlayerManager.needs_tutorial():
		return
	if _selected_mode == &"PVP":
		return
	else:
		_show_access()


func _on_deploy_pressed() -> void:
	if _selected_mode == &"PVP":
		return
	if PlayerManager.needs_tutorial():
		Router.start_tutorial()
		return
	Router.open_module_select_screen()


func _apply_tutorial_gate() -> void:
	var gated: bool = PlayerManager.needs_tutorial()
	if not gated:
		_lock_chrome(false)
		if _tutorial_gate != null:
			_tutorial_gate.visible = false
		return
	if Router.tutorial_beat == &"dash":
		_lock_chrome(false)
		_show_explore_overlay()
		return
	if Router.tutorial_beat != &"" and Router.tutorial_beat != &"match":
		_lock_chrome(true)
		if _tutorial_gate != null:
			_tutorial_gate.visible = false
		return
	_lock_chrome(true)
	if _tutorial_gate == null:
		_tutorial_gate = TutorialOverlay.mount_on(self)
		var overlay: TutorialOverlay = _tutorial_gate as TutorialOverlay
		if overlay != null:
			overlay.deploy_requested.connect(_on_deploy_pressed)
	if _tutorial_gate != null:
		_tutorial_gate.visible = true
	await get_tree().process_frame
	if _tutorial_gate == null or not is_instance_valid(_tutorial_gate):
		return
	var coach: TutorialOverlay = _tutorial_gate as TutorialOverlay
	if coach != null:
		coach.setup_dashboard(_deploy_button.get_global_rect())


func _show_explore_overlay() -> void:
	if _tutorial_gate == null:
		_tutorial_gate = TutorialOverlay.mount_on(self)
	if _tutorial_gate == null:
		Router.finish_tutorial()
		_lock_chrome(false)
		return
	_tutorial_gate.visible = true
	var overlay: TutorialOverlay = _tutorial_gate as TutorialOverlay
	if overlay == null:
		Router.finish_tutorial()
		_lock_chrome(false)
		return
	if not overlay.dismiss_requested.is_connected(_on_tutorial_dismissed):
		overlay.dismiss_requested.connect(_on_tutorial_dismissed)
	overlay.setup_explore()


func _on_tutorial_dismissed() -> void:
	Router.finish_tutorial()
	if _tutorial_gate != null:
		_tutorial_gate.visible = false
	_lock_chrome(false)
	%Companion.set_interaction_enabled(AuthService.has_pre_test_completed())


func _lock_chrome(locked: bool) -> void:
	var locked_nodes: Array[Control] = [
		_store_button,
		_lessons_button,
		_codex_button,
		_progress_button,
		_world_button,
		_mode_selector,
		_inbox_button,
		_settings_button,
		_profile_button,
	]
	for i in locked_nodes.size():
		var node: Control = locked_nodes[i]
		if node == null:
			continue
		node.modulate = Color(1.0, 1.0, 1.0, 0.38) if locked else Color.WHITE
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box := _pixel_box(Color(Palette.NAVY_900, 0.94), accent, 0, 3)
	box.shadow_color = Color(accent, 0.28)
	box.shadow_size = 2
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("panel", style)


func _style_well(well: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, Color(Palette.CREAM, 0.16), 0, 2)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	well.add_theme_stylebox_override("panel", style)


func _style_top_bar() -> void:
	var style := _pixel_box(HEADER_FILL, Color("4c686a"), 0, 0)
	style.border_width_bottom = 1
	style.content_margin_left = 18.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_top_bar_panel.add_theme_stylebox_override("panel", style)
	_style_updates()


func _style_avatar() -> void:
	var box := _pixel_box(HEADER_FILL, HEADER_ACCENT, 0, 1)
	_avatar_box.add_theme_stylebox_override("panel", box)


func _style_icon_button(button: Button) -> void:
	var side := button.custom_minimum_size.x
	if side < 44.0:
		side = 44.0
	button.custom_minimum_size = Vector2(side, side)
	var box := _pixel_box(Color(Palette.NAVY_900, 0.94), Palette.CYAN_400, 0, 2)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", _pixel_box(Color(Palette.NAVY_900, 0.94), Palette.BLUE_400, 0, 2))
	button.add_theme_stylebox_override("pressed", _pixel_box(Color(Palette.NAVY_900, 0.94), Palette.PRIMARY_BLUE, 0, 2))
	button.add_theme_color_override("font_color", Palette.CREAM)


func _style_badge() -> void:
	var box := _pixel_box(Palette.DANGER, Palette.DANGER, 0, 2)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	_inbox_badge.add_theme_stylebox_override("panel", box)


func _style_updates() -> void:
	var card: PanelContainer = %UpdatesCard
	var box := _pixel_box(Color("18252bca"), Color("4c686a"), 0, 0)
	box.border_width_left = 2
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", box)


func _setup_surroundings() -> void:
	# Preserve all six authored button shapes, relative positions and click targets.
	for button: Control in [_deploy_button, _lessons_button, _codex_button, _store_button, _progress_button, _world_button]:
		_menu_rects[button] = Rect2(Vector2(button.offset_left, button.offset_top), button.size)
	for chip: HudGeoButton in [%ThreatBox, %MaterialsBox, _settings_button]:
		chip.geo = HudGeoButton.Geo.CHIP
		chip.fill_key = "header"
		chip.border_key = "muted"
		chip.shear = 6
		chip.queue_redraw()
	%ThreatBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%MaterialsBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main: Control = $SafeAreaContainer/ScreenLayout/MainRow
	# Draw the joined utility pair after World without raising its global
	# z-index; raised child z-indices leak through screens pushed above Dashboard.
	main.move_child(_store_button, main.get_child_count() - 1)
	main.move_child(_progress_button, main.get_child_count() - 1)
	main.resized.connect(_layout_surroundings)
	_layout_surroundings.call_deferred()


func _layout_surroundings() -> void:
	var main: Control = $SafeAreaContainer/ScreenLayout/MainRow
	if main.size.x <= 0 or _menu_rects.is_empty():
		return
	# Scale the composition as one unit on compact landscape displays.
	var layout_scale := minf(1.0, minf(main.size.x / 1248.0, main.size.y / 590.0))
	for button: Control in _menu_rects:
		var rect: Rect2 = _menu_rects[button]
		button.scale = Vector2.ONE * layout_scale
		button.position = Vector2(rect.position.x * layout_scale, main.size.y * 0.5 + rect.position.y * layout_scale)
	var companion: Control = %Companion
	companion.scale = Vector2.ONE * layout_scale
	companion.size = Vector2(348, 510)
	companion.position = Vector2(main.size.x - 384 * layout_scale, maxf(24, (main.size.y - 510 * layout_scale) * 0.5))
	var updates: Control = $SafeAreaContainer/ScreenLayout/MainRow/UpdatesPanel
	# Keep the outpost/progress block centered beneath the profile, independent
	# of the menu and companion columns.
	var profile_center := main.get_global_transform().affine_inverse() * _profile_button.get_global_rect().get_center()
	var info_width := 499.0
	updates.scale = Vector2.ONE * layout_scale
	updates.position = Vector2(profile_center.x - info_width * layout_scale * 0.5, 34 * layout_scale)
	if _mode_selector.get_parent() == main:
		_mode_selector.scale = Vector2.ONE * layout_scale
		_mode_selector.position = Vector2(40 * layout_scale, main.size.y * 0.5 + 98 * layout_scale)


func _style_at_risk() -> void:
	var box := _pixel_box(Color(Palette.DANGER, 0.92), Palette.DANGER, 0, 2)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	_at_risk.add_theme_stylebox_override("panel", box)


func _style_cta(button: Button, fill: Color, text: Color) -> void:
	var box := _pixel_box(fill, Palette.DEEP_SPACE, 0, 2)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", text)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(int(button.custom_minimum_size.x), 64)


func _apply_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
