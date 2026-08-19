extends BaseScreen
## Command centre: slash menu, mission diamond, hero art. Palette-only chrome.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const DEFAULT_MATERIALS := 200
const DEFAULT_THREAT_POINTS := 1000
const DEFAULT_CURRENT_STAGE := 1
const MODULE_PROGRESS := 80
const MODULE_LESSONS_DONE := 4
const MODULE_LESSONS_TOTAL := 5
const UNREAD_NOTIFICATIONS := 2

@onready var _game_title: Label = %GameTitle
@onready var _profile_button: HudGeoButton = %ProfileButton
@onready var _avatar_box: PanelContainer = %AvatarBox
@onready var _player_name: Label = %PlayerName
@onready var _rank: Label = %RankLabel
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
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
@onready var _store_button: HudGeoButton = %StoreButton
@onready var _intel_button: HudGeoButton = %IntelButton
@onready var _progress_button: HudGeoButton = %ProgressButton
@onready var _mode_modal: DashboardModeModal = %ModeModal
@onready var _lock_window: PanelContainer = %LockWindow
@onready var _lock_title_bar: PanelContainer = %LockTitleBar
@onready var _lock_well: PanelContainer = %LockWell
@onready var _lock_settings: Button = %LockSettingsButton

var _pixel_font: Font
var _selected_mode: StringName = &"SOLO"
var _materials: int = DEFAULT_MATERIALS
var _threat_points: int = DEFAULT_THREAT_POINTS
var _current_stage: int = DEFAULT_CURRENT_STAGE


func _ready() -> void:
	_load_font()
	_style_chrome()
	_store_button.pressed.connect(func() -> void: Router.push(&"store"))
	_intel_button.pressed.connect(func() -> void: Router.push(&"intel_hub"))
	_progress_button.pressed.connect(func() -> void: Router.push(&"progress"))
	_inbox_button.pressed.connect(func() -> void: push_warning("Inbox screen not built yet"))
	_settings_button.pressed.connect(func() -> void: Router.push(&"settings"))
	_profile_button.pressed.connect(func() -> void: Router.push(&"profile"))
	_world_button.pressed.connect(_on_deploy_pressed)
	_mode_selector.pressed.connect(_open_mode_modal)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	%PreTestButton.pressed.connect(func() -> void: Router.push(&"pretest"))
	_lock_settings.pressed.connect(func() -> void: Router.push(&"settings"))
	_mode_modal.mode_confirmed.connect(_on_mode_confirmed)


func on_enter(_args: Dictionary) -> void:
	_refresh_data()
	_apply_lock_state()
	_update_mode_ui()


func on_resume() -> void:
	_refresh_data()
	_apply_lock_state()


func on_exit() -> void:
	_mode_modal.visible = false


func _style_chrome() -> void:
	_style_avatar()
	_style_badge()
	_style_at_risk()
	_style_icon_button(_lock_settings)
	_style_window(_lock_window, Palette.GOLD)
	_style_title_bar(_lock_title_bar, Palette.ORANGE)
	_style_well(_lock_well, Palette.ORANGE)
	_style_cta(%PreTestButton, Palette.GOLD, Palette.TEXT_ON_GOLD)
	_apply_label(_game_title, Palette.CYAN, 14)
	_apply_label(_player_name, Palette.TEXT_PRIMARY, 13)
	_apply_label(_rank, Palette.CYAN, 10)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_inbox_count, Palette.TEXT_PRIMARY, 10)
	_apply_label(_at_risk_title, Palette.TEXT_PRIMARY, 13)
	_apply_label(_at_risk_sub, Palette.TEXT_PRIMARY, 11)
	_apply_label(_at_risk_pill, Palette.TEXT_PRIMARY, 16)
	_apply_label(%LockTitle, Palette.TEXT_PRIMARY, 16)
	_apply_label(%LockBody, Palette.TEXT_PRIMARY, 12)
	var lock_file: Label = _lock_title_bar.find_child("LockFile", true, false) as Label
	if lock_file != null:
		_apply_label(lock_file, Palette.TEXT_PRIMARY, 11)


func _apply_lock_state() -> void:
	var locked := not AuthService.has_pre_test_completed()
	%PreTestLock.visible = locked
	if not locked:
		return
	_at_risk.visible = false
	%LockTitle.text = tr("PRETEST_LOCK_TITLE")
	%LockBody.text = tr("PRETEST_LOCK_BODY")
	%PreTestButton.text = tr("PRETEST_BUTTON") + "  >"
	_style_cta(%PreTestButton, Palette.GOLD, Palette.TEXT_ON_GOLD)
	if _pixel_font != null:
		%LockTitle.add_theme_font_override("font", _pixel_font)
		%LockBody.add_theme_font_override("font", _pixel_font)
		%PreTestButton.add_theme_font_override("font", _pixel_font)


func _refresh_data() -> void:
	_threat_points = AuthService.wallet_threat_points()
	_materials = AuthService.materials() if AuthService.materials() >= 0 else DEFAULT_MATERIALS
	_current_stage = AuthService.current_stage()
	_player_name.text = AuthService.display_name().to_upper()
	_threat_value.text = str(_threat_points)
	_materials_value.text = str(_materials)
	_rank.text = AuthService.rank_title().to_upper()
	_store_button.title = tr("DASH_STORE").to_upper()
	_intel_button.title = tr("DASH_INTEL").to_upper()
	_progress_button.title = tr("DASH_PROGRESS").to_upper()
	_progress_button.subtitle = ""
	_world_button.title = "MISSION"
	_world_button.subtitle = tr("DASH_MODULE_NUM") % 1
	_world_button.detail = (tr("DASH_MINI_PROGRESS") % [_current_stage, MODULE_LESSONS_DONE, MODULE_LESSONS_TOTAL]).to_upper()
	_world_button.progress = float(MODULE_PROGRESS) / 100.0
	_world_button.queue_redraw()
	_store_button.queue_redraw()
	_intel_button.queue_redraw()
	_progress_button.queue_redraw()
	_at_risk_title.text = tr("DASH_AT_RISK_TITLE")
	_inbox_badge.visible = UNREAD_NOTIFICATIONS > 0
	_inbox_count.text = str(UNREAD_NOTIFICATIONS)
	_refresh_at_risk()
	if not AuthService.has_pre_test_completed():
		_at_risk.visible = false
	_refresh_world()


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
	var show_mission := _selected_mode == &"SOLO"
	_world_button.visible = show_mission
	if show_mission:
		_world_button.progress = float(MODULE_PROGRESS) / 100.0
		_world_button.queue_redraw()


func _open_mode_modal() -> void:
	var mode := DashboardModeModal.Mode.SOLO if _selected_mode == &"SOLO" else DashboardModeModal.Mode.PVP
	_mode_modal.open(mode, get_viewport().get_visible_rect().size.x)


func _on_mode_confirmed(mode: StringName) -> void:
	_selected_mode = mode
	_update_mode_ui()


func _update_mode_ui() -> void:
	var is_solo := _selected_mode == &"SOLO"
	_mode_selector.title = "SOLO" if is_solo else "PVP"
	_mode_selector.border_key = "gold" if is_solo else "red"
	_mode_selector.fill_key = "panel"
	_mode_selector.queue_redraw()
	_deploy_button.title = tr("DASH_DEPLOY") if is_solo else tr("DASH_DEFEND")
	_deploy_button.subtitle = "SOLO" if is_solo else "PVP"
	_deploy_button.fill_key = "gold" if is_solo else "red"
	_deploy_button.border_key = "gold" if is_solo else "red"
	_deploy_button.queue_redraw()
	_world_button.border_key = "gold" if is_solo else "red"
	_refresh_world()


func _on_deploy_pressed() -> void:
	if _selected_mode == &"PVP":
		push_warning("PvP Hub screen not built yet")
	else:
		Router.push(&"stage_select")


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), accent, 0, 3)
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
	var style := _pixel_box(fill, Color(Palette.TEXT_PRIMARY, 0.16), 0, 2)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	well.add_theme_stylebox_override("panel", style)


func _style_avatar() -> void:
	var box := _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2)
	_avatar_box.add_theme_stylebox_override("panel", box)


func _style_icon_button(button: Button) -> void:
	var side := button.custom_minimum_size.x
	if side < 44.0:
		side = 44.0
	button.custom_minimum_size = Vector2(side, side)
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.CYAN, 0, 2)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.TEXT_PRIMARY, 0, 2))
	button.add_theme_stylebox_override("pressed", _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.GOLD, 0, 2))
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)


func _style_badge() -> void:
	var box := _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	_inbox_badge.add_theme_stylebox_override("panel", box)


func _style_at_risk() -> void:
	var box := _pixel_box(Color(Palette.RED_DEEP, 0.92), Palette.RED, 0, 2)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	_at_risk.add_theme_stylebox_override("panel", box)


func _style_cta(button: Button, fill: Color, text: Color) -> void:
	var box := _pixel_box(fill, Palette.BG_DEEP, 0, 2)
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
