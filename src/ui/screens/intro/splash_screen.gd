extends BaseScreen
## Intro / loading screen.
##
## This screen has a real job beyond showing the logo: it decides whether the
## player goes to login or straight to the dashboard. Structuring it as a list
## of boot steps now means wiring real asset preloading later is adding entries
## to _boot(), not rewriting the screen.

## Minimum time the splash stays up. Without a floor, a fast boot flashes the
## logo for 80ms and reads as a glitch.
const MIN_DISPLAY_SECONDS := 1.8

## Rotating loading tips. Translation keys, not literal strings — these render
## in Tagalog too. Worth writing as real advice: this is the one screen every
## student sees every session, so it is free teaching time.
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

var _tween: Tween


func on_enter(_args: Dictionary) -> void:
	_tip.text = tr(TIP_KEYS.pick_random())
	_progress.value = 0.0
	_boot()


func can_go_back() -> bool:
	# Backing out of a loading screen has no meaning, and on Android it would
	# fire quit_requested before the app has finished starting.
	return false


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

	# Hold the floor so the bar visibly completes rather than snapping.
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
