extends BaseScreen
## Loading screen after START GAME: settings, save, content, then Cloudinary
## asset sync into user://assets/. BREACH does not use this screen.

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
@onready var _retry: Button = %RetryButton
@onready var _loading_panel: Control = $SafeAreaContainer/Layout/LoadingGroup/Panel

var _tween: Tween
var _boot_token: int = 0


func _ready() -> void:
	_retry.pressed.connect(_on_retry_pressed)


func on_enter(_args: Dictionary) -> void:
	AssetManager.bind_texture(get_node_or_null("Background") as CanvasItem, "ui_loading")
	modulate.a = 0.0
	_retry.visible = false
	_retry.disabled = true
	_retry.text = tr("LOADING_ASSETS_RETRY")
	_tip.text = tr(TIP_KEYS.pick_random())
	_status.text = tr("LOADING_TITLE")
	_progress.value = 0.0
	_scale_loading_ui()
	if not get_tree().root.size_changed.is_connected(_scale_loading_ui):
		get_tree().root.size_changed.connect(_scale_loading_ui)
	_fade_in()
	_boot()


func on_exit() -> void:
	_boot_token += 1
	_disconnect_progress()
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
	_boot_token += 1
	var token: int = _boot_token
	var started_at := Time.get_ticks_msec()
	_retry.visible = false
	_retry.disabled = true

	_set_status("LOADING_SETTINGS", 0.15)
	await SettingsService.load_local()
	if not _still(token):
		return

	_set_status("LOADING_PROFILE", 0.40)
	await SaveService.load_local()
	if not _still(token):
		return

	_set_status("LOADING_CONTENT", 0.70)
	await ContentDB.load_all()
	if not _still(token):
		return

	_set_status("LOADING_GAME_ASSETS", 0.82)
	if not AssetManager.sync_progress.is_connected(_on_asset_progress):
		AssetManager.sync_progress.connect(_on_asset_progress)
	await AssetManager.ensure_ready()
	_disconnect_progress()
	if not _still(token):
		return
	if not AssetManager.has_required_gameplay_assets():
		_retry.visible = true
		_retry.disabled = false
		_status.text = tr("LOADING_ASSETS_MISSING")
		_tip.text = tr("LOADING_ASSETS_MISSING")
		_progress.value = 0.0
		return

	_set_status("LOADING_SESSION", 0.90)
	var has_session: bool = await AuthService.restore_session()
	if not _still(token):
		return
	if has_session:
		AuthService.start_background_refresh()
		SaveService.fetch_cloud_save()

	_set_status("LOADING_READY", 1.0)

	var elapsed := (Time.get_ticks_msec() - started_at) / 1000.0
	if elapsed < MIN_DISPLAY_SECONDS:
		await get_tree().create_timer(MIN_DISPLAY_SECONDS - elapsed).timeout
	if not _still(token):
		return

	Router.replace_all(&"dashboard" if has_session else &"login")


func _on_retry_pressed() -> void:
	_boot()


func _on_asset_progress(done: int, total: int, _status_text: String) -> void:
	_status.text = tr("LOADING_GAME_ASSETS")
	if total <= 0:
		return
	_progress.value = 82.0 + 8.0 * float(done) / float(total)


func _disconnect_progress() -> void:
	if AssetManager.sync_progress.is_connected(_on_asset_progress):
		AssetManager.sync_progress.disconnect(_on_asset_progress)


func _still(token: int) -> bool:
	return token == _boot_token and is_inside_tree()


func _set_status(key: String, target: float) -> void:
	_status.text = tr(key)
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_progress, "value", target * 100.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
