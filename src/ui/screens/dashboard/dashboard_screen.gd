extends BaseScreen
## Main command centre — matches DashboardScreen.tsx from the React Native prototype.

const DEFAULT_MATERIALS := 200
const DEFAULT_THREAT_POINTS := 1000
const DEFAULT_CURRENT_STAGE := 1
const MODULE_PROGRESS := 80
const MODULE_LESSONS_DONE := 4
const MODULE_LESSONS_TOTAL := 5
const UNREAD_NOTIFICATIONS := 2

var SOLO_DEPLOY_GRADIENT := PackedColorArray([
	Color("#ffe28a"), Color("#ffa634"), Color("#d94d10"),
])
var PVP_DEFEND_GRADIENT := PackedColorArray([
	Color("#ff6688"), Color("#cc1133"), Color("#880022"),
])

@onready var _safe: MarginContainer = $SafeAreaContainer
@onready var _player_name: Label = %PlayerName
@onready var _rank: Label = %RankLabel
@onready var _exp: Label = %ExpLabel
@onready var _exp_fill: ColorRect = %ExpBarFill
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _inbox_badge: PanelContainer = %InboxBadge
@onready var _inbox_count: Label = %InboxCount
@onready var _at_risk: PanelContainer = %AtRiskBanner
@onready var _at_risk_sub: Label = %AtRiskSub
@onready var _at_risk_pill: Label = %AtRiskPill
@onready var _mini_tracker: PanelContainer = %MiniTracker
@onready var _mini_module: Label = %MiniModule
@onready var _mini_fill: ColorRect = %MiniProgressFill
@onready var _mini_text: Label = %MiniProgressText
@onready var _mode_icon: Label = %ModeIcon
@onready var _mode_text: Label = %ModeText
@onready var _deploy_outer: PanelContainer = %DeployOuter
@onready var _deploy_gradient: GradientRect = %DeployGradient
@onready var _deploy_label: Label = %DeployLabel
@onready var _mode_modal: DashboardModeModal = %ModeModal

var _pixel_font: Font
var _selected_mode: StringName = &"SOLO"
var _materials: int = DEFAULT_MATERIALS
var _threat_points: int = DEFAULT_THREAT_POINTS
var _current_stage: int = DEFAULT_CURRENT_STAGE


func _ready() -> void:
	_load_font()
	get_viewport().size_changed.connect(_apply_scale)
	_deploy_gradient.set_colors(SOLO_DEPLOY_GRADIENT, true)

	%StoreButton.pressed.connect(func(): Router.push(&"store"))
	%IntelButton.pressed.connect(func(): Router.push(&"intel_hub"))
	%ProgressButton.pressed.connect(func(): Router.push(&"progress"))
	%InboxButton.pressed.connect(func(): push_warning("Inbox screen not built yet"))
	%SettingsButton.pressed.connect(func(): Router.push(&"settings"))
	%ModeSelector.pressed.connect(_open_mode_modal)
	%DeployButton.pressed.connect(_on_deploy_pressed)
	%PreTestButton.pressed.connect(func(): Router.push(&"pretest"))
	%LockSettingsButton.pressed.connect(func(): Router.push(&"settings"))

	_mode_modal.mode_confirmed.connect(_on_mode_confirmed)


func on_enter(_args: Dictionary) -> void:
	_refresh_data()
	_apply_lock_state()
	_apply_scale()
	_update_mode_ui(false)


func on_resume() -> void:
	_refresh_data()
	_apply_lock_state()


func on_exit() -> void:
	_mode_modal.visible = false


func _apply_lock_state() -> void:
	var locked := not AuthService.has_pre_test_completed()
	%PreTestLock.visible = locked
	if locked:
		_at_risk.visible = false
		%LockTitle.text = tr("PRETEST_LOCK_TITLE")
		%LockBody.text = tr("PRETEST_LOCK_BODY")
		%PreTestButton.text = tr("PRETEST_BUTTON")
		if _pixel_font:
			%LockTitle.add_theme_font_override("font", _pixel_font)
			%LockBody.add_theme_font_override("font", _pixel_font)
			%PreTestButton.add_theme_font_override("font", _pixel_font)
		_style_pretest_button()
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(0.0705882, 0.141176, 0.227451, 0.85)
		icon_style.border_color = Color("3a6a8a")
		icon_style.set_border_width_all(2)
		icon_style.set_corner_radius_all(8)
		%LockSettingsButton.add_theme_stylebox_override("normal", icon_style)
		%LockSettingsButton.add_theme_stylebox_override("hover", icon_style)
		%LockSettingsButton.add_theme_stylebox_override("pressed", icon_style)


func _style_pretest_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffd23f")
	style.border_color = Color("fff8d0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	%PreTestButton.add_theme_stylebox_override("normal", style)
	%PreTestButton.add_theme_stylebox_override("hover", style)
	%PreTestButton.add_theme_stylebox_override("pressed", style)


func _load_font() -> void:
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		var file := load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
		if file != null:
			_pixel_font = file


func _refresh_data() -> void:
	_materials = AuthService.materials() if AuthService.materials() >= 0 else DEFAULT_MATERIALS
	_threat_points = AuthService.threat_points() if AuthService.threat_points() >= 0 else DEFAULT_THREAT_POINTS
	_current_stage = AuthService.current_stage()

	_player_name.text = AuthService.display_name()
	_threat_value.text = str(_threat_points)
	_materials_value.text = str(_materials)
	_rank.text = tr("DASH_RANK")
	_exp.text = tr("DASH_EXP")
	%ThreatLabel.text = tr("DASH_THREAT_POINTS").to_upper()
	%MaterialsLabel.text = tr("DASH_MATERIALS").to_upper()
	%StoreButton.text = tr("DASH_STORE")
	%IntelButton.text = tr("DASH_INTEL")
	%ProgressButton.text = tr("DASH_PROGRESS")
	_mini_module.text = tr("DASH_MODULE_NUM") % 1
	_mini_text.text = tr("DASH_MINI_PROGRESS") % [_current_stage, MODULE_LESSONS_DONE, MODULE_LESSONS_TOTAL]

	_inbox_badge.visible = UNREAD_NOTIFICATIONS > 0
	_inbox_count.text = str(UNREAD_NOTIFICATIONS)

	_refresh_at_risk()
	if not AuthService.has_pre_test_completed():
		_at_risk.visible = false
	_refresh_mini_tracker()
	%AtRiskTitle.text = tr("DASH_AT_RISK_TITLE")
	%MiniLabel.text = tr("DASH_MINI_LABEL").to_upper()


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


func _refresh_mini_tracker() -> void:
	_mini_tracker.visible = _selected_mode == &"SOLO"
	_mini_fill.anchor_right = float(MODULE_PROGRESS) / 100.0


func _apply_scale() -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	var scaled := func(value: float) -> int: return UiScale.n(value, view_w)

	_safe.add_theme_constant_override("margin_left", scaled.call(24))
	_safe.add_theme_constant_override("margin_top", scaled.call(24))
	_safe.add_theme_constant_override("margin_right", scaled.call(24))
	_safe.add_theme_constant_override("margin_bottom", scaled.call(24))

	_apply_pixel_font(_player_name, scaled.call(22))
	_apply_pixel_font(_rank, scaled.call(15))
	_apply_pixel_font(_exp, scaled.call(11))
	_apply_pixel_font(_threat_value, scaled.call(16))
	_apply_pixel_font(_materials_value, scaled.call(16))
	_apply_pixel_font(_deploy_label, scaled.call(30))
	_apply_pixel_font(_mode_text, scaled.call(10))
	_apply_pixel_font(%ThreatLabel, scaled.call(8))
	_apply_pixel_font(%MaterialsLabel, scaled.call(8))
	_apply_pixel_font(_mini_module, scaled.call(10))
	_apply_pixel_font(%MiniLabel, scaled.call(8))
	_apply_pixel_font(_mini_text, scaled.call(9))
	_apply_pixel_font(%AtRiskTitle, scaled.call(11))
	_apply_pixel_font(_at_risk_sub, scaled.call(9))
	_apply_pixel_font(_at_risk_pill, scaled.call(12))
	_apply_pixel_font_button(%StoreButton, scaled.call(14))
	_apply_pixel_font_button(%IntelButton, scaled.call(14))
	_apply_pixel_font_button(%ProgressButton, scaled.call(14))
	_apply_pixel_font_button(%InboxButton, scaled.call(17))
	_apply_pixel_font_button(%SettingsButton, scaled.call(17))

	var store_style := %StoreButton.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	store_style.content_margin_left = scaled.call(120)
	store_style.content_margin_right = scaled.call(120)
	store_style.content_margin_top = scaled.call(30)
	store_style.content_margin_bottom = scaled.call(30)
	%StoreButton.add_theme_stylebox_override("normal", store_style)
	%StoreButton.add_theme_stylebox_override("hover", store_style)
	%StoreButton.add_theme_stylebox_override("pressed", store_style)

	var nav_style := %IntelButton.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	nav_style.content_margin_left = scaled.call(24)
	nav_style.content_margin_right = scaled.call(24)
	nav_style.content_margin_top = scaled.call(14)
	nav_style.content_margin_bottom = scaled.call(14)
	for btn in [%IntelButton, %ProgressButton]:
		var btn_style := nav_style.duplicate() as StyleBoxFlat
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style)
		btn.add_theme_stylebox_override("pressed", btn_style)

	var deploy_inner_style := %DeployInner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	deploy_inner_style.content_margin_left = scaled.call(30)
	deploy_inner_style.content_margin_right = scaled.call(30)
	deploy_inner_style.content_margin_top = scaled.call(30)
	deploy_inner_style.content_margin_bottom = scaled.call(30)
	%DeployInner.add_theme_stylebox_override("panel", deploy_inner_style)

	%AvatarBox.custom_minimum_size = Vector2(scaled.call(86), scaled.call(86))
	%ExpBar.custom_minimum_size = Vector2(scaled.call(280), scaled.call(13))
	%ThreatBox.custom_minimum_size = Vector2(scaled.call(140), 0)
	%MaterialsBox.custom_minimum_size = Vector2(scaled.call(140), 0)
	%InboxButton.custom_minimum_size = Vector2(scaled.call(46), scaled.call(46))
	%SettingsButton.custom_minimum_size = Vector2(scaled.call(46), scaled.call(46))
	%IntelButton.custom_minimum_size = Vector2(scaled.call(120), scaled.call(42))
	%ProgressButton.custom_minimum_size = Vector2(scaled.call(120), scaled.call(42))
	%ModeRing.custom_minimum_size = Vector2(scaled.call(60), scaled.call(60))
	%DeployInner.custom_minimum_size = Vector2(scaled.call(120), scaled.call(90))
	_mini_tracker.custom_minimum_size = Vector2(scaled.call(180), 0)


func _apply_pixel_font(label: Label, font_size: int) -> void:
	if _pixel_font:
		label.add_theme_font_override("font", _pixel_font)
	label.add_theme_font_size_override("font_size", font_size)


func _apply_pixel_font_button(button: Button, font_size: int) -> void:
	if _pixel_font:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", font_size)


func _open_mode_modal() -> void:
	var mode := DashboardModeModal.Mode.SOLO if _selected_mode == &"SOLO" else DashboardModeModal.Mode.PVP
	_mode_modal.open(mode, get_viewport().get_visible_rect().size.x)


func _on_mode_confirmed(mode: StringName) -> void:
	_selected_mode = mode
	_update_mode_ui(true)


func _update_mode_ui(_animate: bool) -> void:
	var is_solo := _selected_mode == &"SOLO"
	_mode_icon.text = "⚔️" if is_solo else "🛡️"
	_mode_text.text = "SOLO" if is_solo else "PVP"
	_deploy_label.text = tr("DASH_DEPLOY") if is_solo else tr("DASH_DEFEND")
	_deploy_gradient.set_colors(
		SOLO_DEPLOY_GRADIENT if is_solo else PVP_DEFEND_GRADIENT,
		true,
	)

	var outer_style := _deploy_outer.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if is_solo:
		outer_style.bg_color = Color("#ffd23f")
		outer_style.shadow_color = Color("#ffb13d")
	else:
		outer_style.bg_color = Color("#ff4466")
		outer_style.shadow_color = Color("#ff2244")
	_deploy_outer.add_theme_stylebox_override("panel", outer_style)

	_refresh_mini_tracker()


func _on_deploy_pressed() -> void:
	if _selected_mode == &"PVP":
		push_warning("PvP Hub screen not built yet")
	else:
		push_warning("Mission Briefing screen not built yet")
