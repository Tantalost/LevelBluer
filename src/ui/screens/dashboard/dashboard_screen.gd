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

	_mode_modal.mode_confirmed.connect(_on_mode_confirmed)


func on_enter(_args: Dictionary) -> void:
	_refresh_data()
	_apply_scale()
	_update_mode_ui(false)


func on_exit() -> void:
	_mode_modal.visible = false


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
	var s := func(size: float) -> int: return UiScale.n(size, view_w)
	var bw := func(size: float) -> int: return UiScale.bw(size, view_w)

	_safe.add_theme_constant_override("margin_left", s.call(24))
	_safe.add_theme_constant_override("margin_top", s.call(24))
	_safe.add_theme_constant_override("margin_right", s.call(24))
	_safe.add_theme_constant_override("margin_bottom", s.call(24))

	_apply_pixel_font(_player_name, s.call(22))
	_apply_pixel_font(_rank, s.call(15))
	_apply_pixel_font(_exp, s.call(11))
	_apply_pixel_font(_threat_value, s.call(16))
	_apply_pixel_font(_materials_value, s.call(16))
	_apply_pixel_font(_deploy_label, s.call(30))
	_apply_pixel_font(_mode_text, s.call(10))
	_apply_pixel_font(%ThreatLabel, s.call(8))
	_apply_pixel_font(%MaterialsLabel, s.call(8))
	_apply_pixel_font(_mini_module, s.call(10))
	_apply_pixel_font(%MiniLabel, s.call(8))
	_apply_pixel_font(_mini_text, s.call(9))
	_apply_pixel_font(%AtRiskTitle, s.call(11))
	_apply_pixel_font(_at_risk_sub, s.call(9))
	_apply_pixel_font(_at_risk_pill, s.call(12))
	_apply_pixel_font_button(%StoreButton, s.call(14))
	_apply_pixel_font_button(%IntelButton, s.call(14))
	_apply_pixel_font_button(%ProgressButton, s.call(14))
	_apply_pixel_font_button(%InboxButton, s.call(17))
	_apply_pixel_font_button(%SettingsButton, s.call(17))

	var store_style := %StoreButton.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	store_style.content_margin_left = s.call(120)
	store_style.content_margin_right = s.call(120)
	store_style.content_margin_top = s.call(30)
	store_style.content_margin_bottom = s.call(30)
	%StoreButton.add_theme_stylebox_override("normal", store_style)
	%StoreButton.add_theme_stylebox_override("hover", store_style)
	%StoreButton.add_theme_stylebox_override("pressed", store_style)

	var nav_style := %IntelButton.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	nav_style.content_margin_left = s.call(24)
	nav_style.content_margin_right = s.call(24)
	nav_style.content_margin_top = s.call(14)
	nav_style.content_margin_bottom = s.call(14)
	for btn in [%IntelButton, %ProgressButton]:
		var btn_style := nav_style.duplicate() as StyleBoxFlat
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style)
		btn.add_theme_stylebox_override("pressed", btn_style)

	var deploy_inner_style := %DeployInner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	deploy_inner_style.content_margin_left = s.call(30)
	deploy_inner_style.content_margin_right = s.call(30)
	deploy_inner_style.content_margin_top = s.call(30)
	deploy_inner_style.content_margin_bottom = s.call(30)
	%DeployInner.add_theme_stylebox_override("panel", deploy_inner_style)

	%AvatarBox.custom_minimum_size = Vector2(s.call(86), s.call(86))
	%ExpBar.custom_minimum_size = Vector2(s.call(280), s.call(13))
	%ThreatBox.custom_minimum_size = Vector2(s.call(140), 0)
	%MaterialsBox.custom_minimum_size = Vector2(s.call(140), 0)
	%InboxButton.custom_minimum_size = Vector2(s.call(46), s.call(46))
	%SettingsButton.custom_minimum_size = Vector2(s.call(46), s.call(46))
	%IntelButton.custom_minimum_size = Vector2(s.call(120), s.call(42))
	%ProgressButton.custom_minimum_size = Vector2(s.call(120), s.call(42))
	%ModeRing.custom_minimum_size = Vector2(s.call(60), s.call(60))
	%DeployInner.custom_minimum_size = Vector2(s.call(120), s.call(90))
	_mini_tracker.custom_minimum_size = Vector2(s.call(180), 0)


func _apply_pixel_font(label: Label, size: int) -> void:
	if _pixel_font:
		label.add_theme_font_override("font", _pixel_font)
	label.add_theme_font_size_override("font_size", size)


func _apply_pixel_font_button(button: Button, size: int) -> void:
	if _pixel_font:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", size)


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
