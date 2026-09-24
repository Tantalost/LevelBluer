extends BaseScreen
## Settings screen — 100% matches SettingsScreen.tsx from the React Native prototype.

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


func _ready() -> void:
	_load_font()
	_build_accessibility_controls()
	get_viewport().size_changed.connect(_apply_scale)

	_back_button.pressed.connect(func(): Router.request_back())
	_logout_button.pressed.connect(_on_logout_pressed)

	_setup_control_handlers()


func on_enter(_args: Dictionary) -> void:
	_apply_scale()
	_load_ui_from_service()
	_update_localized_text()


func _load_font() -> void:
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		var file := load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
		if file != null:
			_pixel_font = file


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
	_reduced_motion_toggle.text = "NO SCREEN SHAKE OR PORTRAIT JOLTS"
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
	_master_slider.value = SettingsService.master_volume
	_master_val.text = "%d%%" % SettingsService.master_volume

	_sfx_toggle.button_pressed = SettingsService.sound_enabled

	_sfx_slider.value = SettingsService.sfx_volume
	_sfx_val.text = "%d%%" % SettingsService.sfx_volume

	_bgm_toggle.button_pressed = SettingsService.music_enabled

	_vibration_toggle.button_pressed = SettingsService.vibration_enabled
	_autodeploy_toggle.button_pressed = SettingsService.auto_deploy
	_damage_toggle.button_pressed = SettingsService.show_damage_numbers

	_push_toggle.button_pressed = SettingsService.push_notifications
	_reminders_toggle.button_pressed = SettingsService.mission_reminders

	_hq_toggle.button_pressed = SettingsService.high_quality_graphics
	_fps_toggle.button_pressed = SettingsService.show_fps_counter
	_reduced_motion_toggle.set_pressed_no_signal(SettingsService.reduced_motion)
	_timer_assist_select.select(maxi(0, SettingsService.TIMED_DECISION_ASSIST_MODES.find(SettingsService.timed_decision_assist)))
	_text_speed_select.select(maxi(0, SettingsService.TEXT_SPEED_MODES.find(SettingsService.text_speed)))


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
	var view_w := get_viewport().get_visible_rect().size.x
	var scaled := func(value: float) -> int: return UiScale.n(value, view_w)

	_safe.add_theme_constant_override("margin_left", scaled.call(24))
	_safe.add_theme_constant_override("margin_top", scaled.call(24))
	_safe.add_theme_constant_override("margin_right", scaled.call(24))
	_safe.add_theme_constant_override("margin_bottom", scaled.call(24))

	_apply_pixel_font_button(_back_button, scaled.call(14))
	_apply_pixel_font(_title_label, scaled.call(24))
	_apply_pixel_font_button(_logout_button, scaled.call(14))

	for title in [%SecAudio, %SecGameplay, %SecNotif, %SecDisplay]:
		_apply_pixel_font(title, scaled.call(12))

	for label in [
		%MasterVolLabel, %SfxLabel, %SfxVolLabel, %BgmLabel,
		%VibrationLabel, %AutoDeployLabel, %DamageNumLabel,
		%PushNotifLabel, %RemindersLabel,
		%HqGraphicsLabel, %FpsCounterLabel
	]:
		_apply_pixel_font(label, scaled.call(14))

	for sub in [
		%MasterVolSub, %SfxSub, %SfxVolSub, %BgmSub,
		%VibrationSub, %AutoDeploySub, %DamageNumSub,
		%PushNotifSub, %RemindersSub,
		%HqGraphicsSub, %FpsCounterSub
	]:
		_apply_pixel_font(sub, scaled.call(10))

	for val in [_master_val, _sfx_val]:
		_apply_pixel_font(val, scaled.call(10))
	for label: Label in _accessibility_labels:
		_apply_pixel_font(label, scaled.call(14))
	_apply_pixel_font_button(_reduced_motion_toggle, scaled.call(11))
	_apply_pixel_font_button(_timer_assist_select, scaled.call(12))
	_apply_pixel_font_button(_text_speed_select, scaled.call(12))


func _apply_pixel_font(label: Label, font_size: int) -> void:
	if _pixel_font:
		label.add_theme_font_override("font", _pixel_font)
	label.add_theme_font_size_override("font_size", font_size)


func _apply_pixel_font_button(button: Button, font_size: int) -> void:
	if _pixel_font:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", font_size)
