extends BaseScreen
## Command centre HUD over the city map. Chrome matches Intel OS windows.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const DEFAULT_MATERIALS := 200
const DEFAULT_THREAT_POINTS := 1000
const DEFAULT_CURRENT_STAGE := 1
const MODULE_PROGRESS := 80
const MODULE_LESSONS_DONE := 4
const MODULE_LESSONS_TOTAL := 5
const UNREAD_NOTIFICATIONS := 2

@onready var _safe: MarginContainer = $SafeAreaContainer
@onready var _profile_card: PanelContainer = %ProfileCard
@onready var _avatar_box: PanelContainer = %AvatarBox
@onready var _player_name: Label = %PlayerName
@onready var _rank: Label = %RankLabel
@onready var _exp: Label = %ExpLabel
@onready var _exp_bar: PanelContainer = %ExpBar
@onready var _exp_fill: ColorRect = %ExpBarFill
@onready var _threat_box: PanelContainer = %ThreatBox
@onready var _materials_box: PanelContainer = %MaterialsBox
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _inbox_button: Button = %InboxButton
@onready var _settings_button: Button = %SettingsButton
@onready var _inbox_badge: PanelContainer = %InboxBadge
@onready var _inbox_count: Label = %InboxCount
@onready var _at_risk: PanelContainer = %AtRiskBanner
@onready var _at_risk_sub: Label = %AtRiskSub
@onready var _at_risk_pill: Label = %AtRiskPill
@onready var _at_risk_title: Label = %AtRiskTitle
@onready var _mini_tracker: PanelContainer = %MiniTracker
@onready var _mini_title_bar: PanelContainer = %MiniTitleBar
@onready var _mini_well: PanelContainer = %MiniWell
@onready var _mini_label: Label = %MiniLabel
@onready var _mini_module: Label = %MiniModule
@onready var _mini_track: ColorRect = %MiniProgressTrack
@onready var _mini_fill: ColorRect = %MiniProgressFill
@onready var _mini_text: Label = %MiniProgressText
@onready var _mode_selector: Button = %ModeSelector
@onready var _mode_glyph: IntelPixelIcon = %ModeGlyph
@onready var _mode_text: Label = %ModeText
@onready var _deploy_button: Button = %DeployButton
@onready var _store_button: Button = %StoreButton
@onready var _intel_button: Button = %IntelButton
@onready var _progress_button: Button = %ProgressButton
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
	_mode_selector.pressed.connect(_open_mode_modal)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	%PreTestButton.pressed.connect(func() -> void: Router.push(&"pretest"))
	_lock_settings.pressed.connect(func() -> void: Router.push(&"settings"))
	_mode_modal.mode_confirmed.connect(_on_mode_confirmed)
	_profile_card.gui_input.connect(_on_profile_gui)
	_profile_card.mouse_entered.connect(_set_profile_hover.bind(true))
	_profile_card.mouse_exited.connect(_set_profile_hover.bind(false))
	_profile_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_make_card_click_through(_profile_card)


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
	_style_window(_profile_card, Palette.CYAN)
	_style_avatar()
	_style_exp_bar()
	_style_resource_pill(_threat_box)
	_style_resource_pill(_materials_box)
	_style_icon_button(_inbox_button)
	_style_icon_button(_settings_button)
	_style_icon_button(_lock_settings)
	_style_badge()
	_style_at_risk()
	_style_nav(_store_button, Palette.CYAN)
	_style_nav(_intel_button, Palette.CYAN)
	_style_nav(_progress_button, Palette.CYAN)
	_style_window(_mini_tracker, Palette.GOLD)
	_style_title_bar(_mini_title_bar, Palette.ORANGE)
	_style_well(_mini_well, Palette.ORANGE)
	_mini_track.color = Palette.BG_DEEP
	_mini_fill.color = Palette.TEXT_PRIMARY
	_exp_fill.color = Palette.CYAN
	_style_window(_lock_window, Palette.GOLD)
	_style_title_bar(_lock_title_bar, Palette.ORANGE)
	_style_well(_lock_well, Palette.ORANGE)
	_style_cta(%PreTestButton, Palette.GOLD, Palette.TEXT_ON_GOLD)
	_apply_label(_player_name, Palette.TEXT_PRIMARY, 12)
	_apply_label(_rank, Palette.GREEN, 10)
	_apply_label(_exp, Palette.TEXT_SECONDARY, 9)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_inbox_count, Palette.TEXT_PRIMARY, 9)
	_apply_label(_at_risk_title, Palette.TEXT_PRIMARY, 11)
	_apply_label(_at_risk_sub, Palette.TEXT_PRIMARY, 10)
	_apply_label(_at_risk_pill, Palette.TEXT_PRIMARY, 12)
	_apply_label(_mini_label, Palette.TEXT_PRIMARY, 10)
	_apply_label(_mini_module, Palette.TEXT_PRIMARY, 10)
	_apply_label(_mini_text, Palette.TEXT_PRIMARY, 10)
	_apply_label(_mode_text, Palette.TEXT_PRIMARY, 10)
	_apply_label(%LockTitle, Palette.TEXT_PRIMARY, 14)
	_apply_label(%LockBody, Palette.TEXT_PRIMARY, 11)
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
	_player_name.text = AuthService.display_name()
	_threat_value.text = str(_threat_points)
	_materials_value.text = str(_materials)
	_rank.text = AuthService.rank_title()
	_exp.text = "%d / %d EXP" % [AuthService.points(), AuthService.next_rank_points()]
	var span := maxi(AuthService.exp_rank_span(), 1)
	_exp_fill.anchor_right = clampf(float(AuthService.exp_into_rank()) / float(span), 0.05, 1.0)
	_exp_fill.offset_right = 0.0
	_store_button.text = tr("DASH_STORE").to_upper()
	_intel_button.text = tr("DASH_INTEL").to_upper()
	_progress_button.text = tr("DASH_PROGRESS").to_upper()
	_mini_module.text = tr("DASH_MODULE_NUM") % 1
	_mini_label.text = "MISSION.DAT"
	_mini_text.text = tr("DASH_MINI_PROGRESS") % [_current_stage, MODULE_LESSONS_DONE, MODULE_LESSONS_TOTAL]
	_at_risk_title.text = tr("DASH_AT_RISK_TITLE")
	_inbox_badge.visible = UNREAD_NOTIFICATIONS > 0
	_inbox_count.text = str(UNREAD_NOTIFICATIONS)
	_refresh_at_risk()
	if not AuthService.has_pre_test_completed():
		_at_risk.visible = false
	_refresh_mini_tracker()


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
	_mini_fill.offset_right = 0.0


func _open_mode_modal() -> void:
	var mode := DashboardModeModal.Mode.SOLO if _selected_mode == &"SOLO" else DashboardModeModal.Mode.PVP
	_mode_modal.open(mode, get_viewport().get_visible_rect().size.x)


func _on_mode_confirmed(mode: StringName) -> void:
	_selected_mode = mode
	_update_mode_ui()


func _update_mode_ui() -> void:
	var is_solo := _selected_mode == &"SOLO"
	_mode_glyph.kind = IntelPixelIcon.Kind.BADGE if is_solo else IntelPixelIcon.Kind.SKULL
	_mode_text.text = "SOLO" if is_solo else "PVP"
	_deploy_button.text = (tr("DASH_DEPLOY") if is_solo else tr("DASH_DEFEND")) + "  >"
	_style_mode_selector(is_solo)
	if is_solo:
		_style_cta(_deploy_button, Palette.GOLD, Palette.TEXT_ON_GOLD)
	else:
		_style_cta(_deploy_button, Palette.RED, Palette.TEXT_PRIMARY)
	_refresh_mini_tracker()


func _on_deploy_pressed() -> void:
	if _selected_mode == &"PVP":
		push_warning("PvP Hub screen not built yet")
	else:
		Router.push(&"stage_select")


func _on_profile_gui(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	Router.push(&"profile")


func _set_profile_hover(hovered: bool) -> void:
	_style_profile_frame(Palette.TEXT_PRIMARY if hovered else Palette.CYAN)


func _make_card_click_through(card: Control) -> void:
	var nodes: Array[Node] = [card]
	var i: int = 0
	while i < nodes.size():
		var node: Node = nodes[i]
		var kids: Array = node.get_children()
		for k in kids.size():
			var child: Node = kids[k] as Node
			if child != null:
				nodes.append(child)
		i += 1
	for n in nodes.size():
		if n == 0:
			continue
		var control := nodes[n] as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.92), accent, 0, 2)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("panel", style)


func _style_well(well: PanelContainer, fill: Color) -> void:
	var style := _pixel_box(fill, Color(Palette.TEXT_PRIMARY, 0.12), 0, 2)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	well.add_theme_stylebox_override("panel", style)


func _style_avatar() -> void:
	var box := _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2)
	_avatar_box.add_theme_stylebox_override("panel", box)
	_style_profile_frame(Palette.CYAN)


func _style_profile_frame(accent: Color) -> void:
	var frame := _pixel_box(Color(Palette.BG_HEADER, 0.92), accent, 0, 2)
	frame.content_margin_left = 8.0
	frame.content_margin_right = 10.0
	frame.content_margin_top = 8.0
	frame.content_margin_bottom = 8.0
	frame.shadow_color = Color(Palette.BG_DEEP, 0.7)
	frame.shadow_size = 1
	frame.shadow_offset = Vector2(4, 4)
	_profile_card.add_theme_stylebox_override("panel", frame)


func _style_exp_bar() -> void:
	var box := _pixel_box(Palette.BG_DEEP, Palette.CYAN_DIM, 0, 2)
	_exp_bar.add_theme_stylebox_override("panel", box)


func _style_resource_pill(box: PanelContainer) -> void:
	var style := _pixel_box(Color(Palette.FOREST_NIGHT, 0.92), Palette.TEXT_MUTED, 0, 2)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	box.add_theme_stylebox_override("panel", style)


func _style_icon_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(44, 44)
	var box := _pixel_box(Color(Palette.FOREST_NIGHT, 0.92), Palette.CYAN_DIM, 0, 2)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", _pixel_box(Color(Palette.FOREST_NIGHT, 0.92), Palette.CYAN, 0, 2))
	button.add_theme_stylebox_override("pressed", _pixel_box(Color(Palette.FOREST_NIGHT, 0.92), Palette.TEXT_PRIMARY, 0, 2))
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


func _style_nav(button: Button, accent: Color) -> void:
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.92), accent, 0, 2)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 12)


func _style_cta(button: Button, fill: Color, text: Color) -> void:
	var box := _pixel_box(fill, Palette.BG_DEEP, 0, 2)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", text)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 58)


func _style_mode_selector(is_solo: bool) -> void:
	var border := Palette.GOLD if is_solo else Palette.RED
	var box := _pixel_box(Color(Palette.FOREST_NIGHT, 0.92), border, 0, 2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	_mode_selector.add_theme_stylebox_override("normal", box)
	_mode_selector.add_theme_stylebox_override("hover", box)
	_mode_selector.add_theme_stylebox_override("pressed", box)


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
