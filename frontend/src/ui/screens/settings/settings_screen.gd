extends BaseScreen
## Fixed account actions around a scrollable, themed settings workspace.
const UI: Script = preload("res://src/ui/screens/intel/study_ui.gd")

@onready var _safe: MarginContainer = $SafeAreaContainer
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel

# Audio controls
@onready var _master_slider: HSlider = %MasterVolumeSlider
@onready var _master_val: Label = %MasterVolumeVal
@onready var _sfx_toggle: CheckButton = %SfxToggle
@onready var _sfx_slider: HSlider = %SfxVolumeSlider
@onready var _sfx_val: Label = %SfxVolumeVal
@onready var _bgm_toggle: CheckButton = %BgmToggle
var _music_slider: HSlider
var _music_val: Label
var _dialogue_toggle: CheckButton

# Gameplay controls
@onready var _vibration_toggle: CheckButton = %VibrationToggle
@onready var _autodeploy_toggle: CheckButton = %AutoDeployToggle
@onready var _damage_toggle: CheckButton = %DamageNumToggle

# Notification controls
@onready var _push_toggle: CheckButton = %PushNotifToggle
@onready var _reminders_toggle: CheckButton = %RemindersToggle

# Display controls
@onready var _hq_toggle: CheckButton = %HqGraphicsToggle
@onready var _fps_toggle: CheckButton = %FpsCounterToggle

# Logout button
@onready var _logout_button: Button = %LogoutButton

var _pixel_font: Font
var _accessibility_labels: Array[Label] = []
var _reduced_motion_toggle: CheckButton
var _timer_assist_select: OptionButton
var _text_speed_select: OptionButton
var _feedback_button: Button


func _ready() -> void:
	_load_font()
	_build_music_volume()
	_build_dialogue_toggle()
	_build_accessibility_controls()
	_feedback_button = UI.button("SEND FEEDBACK", func() -> void:
		preload("res://src/ui/screens/settings/student_feedback.gd").open(self)
	)
	$SafeAreaContainer/ScreenLayout/HeaderBar.add_child(_feedback_button)
	var footer: HBoxContainer = $SafeAreaContainer/ScreenLayout/AccountFooter
	footer.get_node("FooterNote").hide()
	var replay: Button = UI.button("REPLAY TUTORIAL", func() -> void: Router.start_tutorial(true))
	replay.name = "ReplayTutorialButton"
	replay.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(replay)
	footer.move_child(replay, 0)
	var intro_replay: Button = UI.button("REPLAY INTRO", Router.replay_intro)
	intro_replay.name = "ReplayIntroButton"
	footer.add_child(intro_replay)
	footer.move_child(intro_replay, 0)
	var exit_button: Button = UI.button("EXIT GAME", Router.request_exit_game)
	exit_button.name = "ExitGameButton"
	footer.add_child(exit_button)
	_style_workspace()
	get_viewport().size_changed.connect(_apply_scale.call_deferred)

	_back_button.pressed.connect(func(): Router.request_back())
	_logout_button.pressed.connect(_on_logout_pressed)

	_setup_control_handlers()
	_apply_scale()


func on_enter(_args: Dictionary) -> void:
	_apply_scale()
	_load_ui_from_service()
	_update_localized_text()


func _load_font() -> void:
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		var file := load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
		if file != null:
			_pixel_font = file


func _build_music_volume() -> void:
	var section: VBoxContainer = %SecAudio.get_parent() as VBoxContainer
	var panel: PanelContainer = UI.panel(section)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var copy: VBoxContainer = UI.column(row, 8)
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	copy.add_child(UI.label("Music volume", 28))
	copy.add_child(UI.label("Set the background music level", 24, UI.MUTED))
	var column: VBoxContainer = UI.column(row, 8)
	_music_val = Label.new()
	column.add_child(_music_val)
	_music_slider = HSlider.new()
	_music_slider.name = "MusicVolumeSlider"
	_music_slider.max_value = 100.0
	_music_slider.step = 1.0
	_music_slider.custom_minimum_size = Vector2(240, 48)
	_music_slider.tooltip_text = "Music volume"
	column.add_child(_music_slider)
	_music_slider.value_changed.connect(func(value: float) -> void:
		SettingsService.music_volume = int(value)
		_music_val.text = "Music volume: %d%%" % int(value)
		SettingsService.save_settings()
	)

func _build_dialogue_toggle() -> void:
	var section: VBoxContainer = %SecAudio.get_parent() as VBoxContainer
	var panel: PanelContainer = UI.panel(section)
	var column: HBoxContainer = HBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var label: Label = UI.label("Retro character voices", 28)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_child(label)
	_dialogue_toggle = CheckButton.new()
	_dialogue_toggle.name = "DialogueBlipsToggle"
	_dialogue_toggle.text = "Dialogue blips"
	_dialogue_toggle.tooltip_text = "Retro speech blips and emotional reactions for Module 1 and 2 stories. Uses Sound Effects volume."
	column.add_child(_dialogue_toggle)
	_dialogue_toggle.toggled.connect(func(enabled: bool) -> void:
		SettingsService.dialogue_blips_enabled = enabled
		SettingsService.save_settings()
	)


func _build_accessibility_controls() -> void:
	var content: VBoxContainer = get_node("SafeAreaContainer/ScreenLayout/ScrollContainer/ContentVBox") as VBoxContainer
	var section := VBoxContainer.new()
	section.name = "AccessibilitySection"
	section.add_theme_constant_override("separation", 10)
	content.add_child(section)
	content.move_child(section, content.get_node("LogoutSpacer").get_index())
	var heading := Label.new()
	heading.text = "ACCESSIBILITY"
	heading.add_theme_color_override("font_color", Color("4fe0d4"))
	section.add_child(heading)
	_accessibility_labels.append(heading)
	var motion_label := Label.new()
	motion_label.text = "Reduce dialogue motion"
	section.add_child(motion_label)
	_accessibility_labels.append(motion_label)
	_reduced_motion_toggle = CheckButton.new()
	_reduced_motion_toggle.text = "Reduce motion"
	_reduced_motion_toggle.tooltip_text = "Reduce screen shake, portrait jolts, and animated interface effects."
	section.add_child(_reduced_motion_toggle)
	var timer_label := Label.new()
	timer_label.text = "Timed decisions"
	section.add_child(timer_label)
	_accessibility_labels.append(timer_label)
	_timer_assist_select = OptionButton.new()
	for mode: String in SettingsService.TIMED_DECISION_ASSIST_MODES:
		_timer_assist_select.add_item(mode.to_upper())
	section.add_child(_timer_assist_select)
	var speed_label := Label.new()
	speed_label.text = "Dialogue text speed"
	section.add_child(speed_label)
	_accessibility_labels.append(speed_label)
	_text_speed_select = OptionButton.new()
	for mode: String in SettingsService.TEXT_SPEED_MODES:
		_text_speed_select.add_item(mode.to_upper())
	section.add_child(_text_speed_select)


func _update_localized_text() -> void:
	_back_button.text = tr("SETT_BACK")
	_title_label.text = tr("SETT_TITLE")
	_logout_button.text = tr("SETT_LOGOUT")

	%SecAudio.text = tr("SETT_SEC_AUDIO")
	%MasterVolLabel.text = tr("SETT_MASTER_VOL")
	%MasterVolSub.text = tr("SETT_MASTER_VOL_DESC")
	%SfxLabel.text = tr("SETT_SFX")
	%SfxSub.text = tr("SETT_SFX_DESC")
	%SfxVolLabel.text = tr("SETT_SFX_VOL")
	%SfxVolSub.text = tr("SETT_SFX_VOL_DESC")
	%BgmLabel.text = tr("SETT_BGM")
	%BgmSub.text = tr("SETT_BGM_DESC")

	%SecGameplay.text = tr("SETT_SEC_GAMEPLAY")
	%VibrationLabel.text = tr("SETT_VIBRATION")
	%VibrationSub.text = tr("SETT_VIBRATION_DESC")
	%AutoDeployLabel.text = tr("SETT_AUTODEPLOY")
	%AutoDeploySub.text = tr("SETT_AUTODEPLOY_DESC")
	%DamageNumLabel.text = tr("SETT_DMG_NUM")
	%DamageNumSub.text = tr("SETT_DMG_NUM_DESC")

	%SecNotif.text = tr("SETT_SEC_NOTIF")
	%PushNotifLabel.text = tr("SETT_PUSH_NOTIF")
	%PushNotifSub.text = tr("SETT_PUSH_NOTIF_DESC")
	%RemindersLabel.text = tr("SETT_REMINDERS")
	%RemindersSub.text = tr("SETT_REMINDERS_DESC")

	%SecDisplay.text = tr("SETT_SEC_DISPLAY")
	%HqGraphicsLabel.text = tr("SETT_HQ_GRAPHICS")
	%HqGraphicsSub.text = tr("SETT_HQ_GRAPHICS_DESC")
	%FpsCounterLabel.text = tr("SETT_SHOW_FPS")
	%FpsCounterSub.text = tr("SETT_SHOW_FPS_DESC")


func _load_ui_from_service() -> void:
	_master_slider.set_value_no_signal(SettingsService.master_volume)
	_master_val.text = "%d%%" % SettingsService.master_volume

	_sfx_toggle.set_pressed_no_signal(SettingsService.sound_enabled)
	_dialogue_toggle.set_pressed_no_signal(SettingsService.dialogue_blips_enabled)

	_sfx_slider.set_value_no_signal(SettingsService.sfx_volume)
	_sfx_val.text = "%d%%" % SettingsService.sfx_volume

	_bgm_toggle.set_pressed_no_signal(SettingsService.music_enabled)
	_music_slider.set_value_no_signal(SettingsService.music_volume)
	_music_val.text = "Music volume: %d%%" % SettingsService.music_volume

	_vibration_toggle.set_pressed_no_signal(SettingsService.vibration_enabled)
	_autodeploy_toggle.set_pressed_no_signal(SettingsService.auto_deploy)
	_damage_toggle.set_pressed_no_signal(SettingsService.show_damage_numbers)

	_push_toggle.set_pressed_no_signal(SettingsService.push_notifications)
	_reminders_toggle.set_pressed_no_signal(SettingsService.mission_reminders)

	_hq_toggle.set_pressed_no_signal(SettingsService.high_quality_graphics)
	_fps_toggle.set_pressed_no_signal(SettingsService.show_fps_counter)
	_reduced_motion_toggle.set_pressed_no_signal(SettingsService.reduced_motion)
	_timer_assist_select.select(maxi(0, SettingsService.TIMED_DECISION_ASSIST_MODES.find(SettingsService.timed_decision_assist)))
	_text_speed_select.select(maxi(0, SettingsService.TEXT_SPEED_MODES.find(SettingsService.text_speed)))
	for toggle: CheckButton in [_sfx_toggle, _bgm_toggle, _vibration_toggle, _autodeploy_toggle, _damage_toggle, _push_toggle, _reminders_toggle, _hq_toggle, _fps_toggle]:
		toggle.text = "ON" if toggle.button_pressed else "OFF"


func _setup_control_handlers() -> void:
	_master_slider.value_changed.connect(func(v: float):
		SettingsService.master_volume = int(v)
		_master_val.text = "%d%%" % int(v)
		SettingsService.save_settings()
	)

	_sfx_toggle.toggled.connect(func(t: bool):
		SettingsService.sound_enabled = t
		SettingsService.save_settings()
	)

	_sfx_slider.value_changed.connect(func(v: float):
		SettingsService.sfx_volume = int(v)
		_sfx_val.text = "%d%%" % int(v)
		SettingsService.save_settings()
	)

	_bgm_toggle.toggled.connect(func(t: bool):
		SettingsService.music_enabled = t
		SettingsService.save_settings()
	)

	_vibration_toggle.toggled.connect(func(t: bool):
		SettingsService.vibration_enabled = t
		SettingsService.save_settings()
	)

	_autodeploy_toggle.toggled.connect(func(t: bool):
		SettingsService.auto_deploy = t
		SettingsService.save_settings()
	)

	_damage_toggle.toggled.connect(func(t: bool):
		SettingsService.show_damage_numbers = t
		SettingsService.save_settings()
	)

	_push_toggle.toggled.connect(func(t: bool):
		SettingsService.push_notifications = t
		SettingsService.save_settings()
	)

	_reminders_toggle.toggled.connect(func(t: bool):
		SettingsService.mission_reminders = t
		SettingsService.save_settings()
	)

	_hq_toggle.toggled.connect(func(t: bool):
		SettingsService.high_quality_graphics = t
		SettingsService.save_settings()
	)

	_fps_toggle.toggled.connect(func(t: bool):
		SettingsService.show_fps_counter = t
		SettingsService.save_settings()
	)
	_reduced_motion_toggle.toggled.connect(func(enabled: bool) -> void:
		SettingsService.reduced_motion = enabled
		SettingsService.save_settings()
	)
	_timer_assist_select.item_selected.connect(func(index: int) -> void:
		SettingsService.timed_decision_assist = SettingsService.TIMED_DECISION_ASSIST_MODES[index]
		SettingsService.save_settings()
	)
	_text_speed_select.item_selected.connect(func(index: int) -> void:
		SettingsService.text_speed = SettingsService.TEXT_SPEED_MODES[index]
		SettingsService.save_settings()
	)


func _on_logout_pressed() -> void:
	SaveService.flush()
	AuthService.sign_out()
	Router.replace_all(&"login")


func _apply_scale() -> void:
	if not is_instance_valid(_feedback_button):
		return
	var physical_scale: float = maxf(0.25, minf(float(get_window().size.x) / get_viewport_rect().size.x, float(get_window().size.y) / get_viewport_rect().size.y))
	UI.fit_touch(self)
	for control: Node in find_children("*", "HSlider", true, false):
		var slider: HSlider = control as HSlider
		slider.custom_minimum_size = Vector2(maxf(240, ceilf(140 / physical_scale)), maxf(48, ceilf(48 / physical_scale)))
	for select: OptionButton in [_timer_assist_select, _text_speed_select]:
		select.get_popup().add_theme_font_size_override("font_size", maxi(24, ceili(16 / physical_scale)))
		select.get_popup().add_theme_constant_override("v_separation", ceili(24 / physical_scale))

func _style_workspace() -> void:
	$Background.color = Color("#050B18")
	var header: HBoxContainer = $SafeAreaContainer/ScreenLayout/HeaderBar
	header.get_node("HeaderSpacerLeft").hide()
	header.get_node("HeaderSpacerRight").hide()
	header.get_node("HeaderRightPad").hide()
	header.add_theme_constant_override("separation", 24)
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var scroll: ScrollContainer = $SafeAreaContainer/ScreenLayout/ScrollContainer
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var content: VBoxContainer = scroll.get_node("ContentVBox")
	content.get_node("LogoutSpacer").hide()
	content.add_theme_constant_override("separation", 24)
	for node: Node in find_children("*", "Control", true, false):
		if node is Label:
			var label: Label = node as Label
			label.add_theme_font_override("font", UI.FONT)
			label.add_theme_font_size_override("font_size", 24 if str(label.name).ends_with("Sub") else 28)
			label.add_theme_color_override("font_color", Color("#A0B7BB") if str(label.name).ends_with("Sub") else Color("#F3ECD6"))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif node is PanelContainer:
			(node as PanelContainer).add_theme_stylebox_override("panel", UI.box(Color("#102040"), Color("#173058"), 20))
		elif node is Button:
			var button: Button = node as Button
			button.focus_mode = FOCUS_ALL
			button.size_flags_vertical = SIZE_SHRINK_CENTER
			button.add_theme_font_override("font", UI.FONT)
			button.add_theme_font_size_override("font_size", 24)
			button.add_theme_color_override("font_color", Color("#F3ECD6"))
			button.add_theme_color_override("font_hover_color", Color("#8FF0E6"))
			button.add_theme_stylebox_override("normal", UI.box(Color("#0A1730"), Color("#173058"), 12))
			button.add_theme_stylebox_override("hover", UI.box(Color("#153B37"), Color("#4FE0D4"), 12))
			button.add_theme_stylebox_override("pressed", UI.box(Color("#0E2A28"), Color("#4FE0D4"), 12))
			button.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, Color("#FFB648"), 0))
			if button is CheckButton and button.text.is_empty():
				button.text = "ON" if button.button_pressed else "OFF"
				button.toggled.connect(func(enabled: bool) -> void: button.text = "ON" if enabled else "OFF")
	for heading: Label in [%SecAudio, %SecGameplay, %SecNotif, %SecDisplay, _accessibility_labels[0]]:
		heading.add_theme_color_override("font_color", Color("#8FF0E6"))
		heading.add_theme_font_size_override("font_size", 26)
	_apply_pixel_font(_title_label, 20)
	_title_label.add_theme_constant_override("shadow_outline_size", 0)
	for row: Node in content.find_children("Row", "HBoxContainer", true, false):
		(row as HBoxContainer).add_theme_constant_override("separation", 24)
	for slider: HSlider in [_master_slider, _sfx_slider, _music_slider]:
		slider.focus_mode = FOCUS_ALL
		var track: StyleBoxFlat = UI.box(Color("#050B18"), Color("#173058"), 5)
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", UI.box(Color("#2E6BFF"), Color("#4FE0D4"), 5))
		slider.add_theme_stylebox_override("grabber_area_highlight", UI.box(Color("#4F8CFF"), Color("#8FF0E6"), 5))
	for select: OptionButton in [_timer_assist_select, _text_speed_select]:
		var popup: PopupMenu = select.get_popup()
		popup.add_theme_font_override("font", UI.FONT)
		popup.add_theme_color_override("font_color", Color("#F3ECD6"))
		popup.add_theme_color_override("font_hover_color", Color("#8FF0E6"))
		popup.add_theme_stylebox_override("panel", UI.box(Color("#0A1730"), Color("#4FE0D4"), 12))
		popup.add_theme_stylebox_override("hover", UI.box(Color("#153B37"), Color("#4FE0D4"), 8))
	_logout_button.add_theme_color_override("font_color", Color("#FF5C5C"))
	_logout_button.add_theme_stylebox_override("normal", UI.box(Color("#0A1730"), Color("#FF5C5C"), 12))

func on_exit() -> void:
	_timer_assist_select.get_popup().hide()
	_text_speed_select.get_popup().hide()


func _apply_pixel_font(label: Label, font_size: int) -> void:
	if _pixel_font:
		label.add_theme_font_override("font", _pixel_font)
	label.add_theme_font_size_override("font_size", font_size)


func _apply_pixel_font_button(button: Button, font_size: int) -> void:
	if _pixel_font:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", font_size)
