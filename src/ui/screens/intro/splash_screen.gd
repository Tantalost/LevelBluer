extends BaseScreen
## Intro / loading screen — full-bleed loading art with a bottom progress group,
## matching the React Native prototype layout.

const MIN_DISPLAY_SECONDS := 1.8
const FADE_IN_SECONDS := 0.45

const TIP_KEYS: Array[String] = [
	"TIP_UPGRADE_DEFENSES",
	"TIP_CHECK_SENDER",
	"TIP_HOVER_LINK",
	"TIP_URGENCY_IS_A_TELL",
	"TIP_NEVER_SHARE_OTP",
]

@onready var _progress: ProgressBar = %ProgressBar
@onready var _status: Label = %StatusLabel
@onready var _tip: Label = %TipLabel
@onready var _loading_panel: Control = $SafeAreaContainer/Layout/LoadingGroup/Panel

var _tween: Tween


func on_enter(_args: Dictionary) -> void:
	modulate.a = 0.0
	_tip.text = tr(TIP_KEYS.pick_random())
	_status.text = tr("LOADING_TITLE")
	_progress.value = 0.0
	_scale_loading_ui()
	get_tree().root.size_changed.connect(_scale_loading_ui)
	_fade_in()
	_boot()


func on_exit() -> void:
	if get_tree().root.size_changed.is_connected(_scale_loading_ui):
		get_tree().root.size_changed.disconnect(_scale_loading_ui)


func can_go_back() -> bool:
	return false


func _fade_in() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _scale_loading_ui() -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	var bar_w := clampf(view_w * 0.55, 320.0, 520.0)
	_loading_panel.custom_minimum_size.x = bar_w
	_progress.custom_minimum_size.x = bar_w


func _boot() -> void:
	var started_at := Time.get_ticks_msec()

	_set_status("LOADING_SETTINGS", 0.15)
	await SettingsService.load_local()

	_set_status("LOADING_PROFILE", 0.40)
	await SaveService.load_local()

	_set_status("LOADING_CONTENT", 0.70)
	await ContentDB.load_all()

	_set_status("LOADING_SESSION", 0.90)
	var has_session: bool = await AuthService.restore_session()

	_set_status("LOADING_READY", 1.0)

	var elapsed := (Time.get_ticks_msec() - started_at) / 1000.0
	if elapsed < MIN_DISPLAY_SECONDS:
		await get_tree().create_timer(MIN_DISPLAY_SECONDS - elapsed).timeout

	Router.replace_all(&"dashboard" if has_session else &"login")


func _set_status(key: String, target: float) -> void:
	_status.text = tr(key)
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_progress, "value", target * 100.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
