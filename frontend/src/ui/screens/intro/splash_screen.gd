extends BaseScreen
## Paired local eyecatches. Percentages represent completed boot work, not a timer.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const READY_HOLD_SECONDS: float = 1.1
const ASSET_START: float = 10.0
const ASSET_END: float = 85.0
const TIP_KEYS: Array[String] = ["TIP_UPGRADE_DEFENSES", "TIP_CHECK_SENDER", "TIP_HOVER_LINK", "TIP_URGENCY_IS_A_TELL", "TIP_NEVER_SHARE_OTP"]

@onready var _progress: ProgressBar = %ProgressBar
@onready var _status: Label = %StatusLabel
@onready var _tip: Label = %TipLabel
@onready var _retry: Button = %RetryButton
@onready var _headline: Label = %Headline
@onready var _percent: Label = %Percent
@onready var _detail: Label = %AssetDetail
@onready var _ready_art: TextureRect = %ReadyArt
@onready var _loading_panel: Control = $SafeAreaContainer/Layout/LoadingGroup/Panel
var _sweep: ActivitySweep
var _transition: Tween
var _boot_token: int = 0
var _active: bool = false
var _stage: String = ""
var _target: float = 0.0
var _has_session: bool = false
var _assets_ready: bool = false
var _poll: float = 0.0

class ActivitySweep extends Control:
	var travel: float = 0.0
	func _process(delta: float) -> void:
		travel = fmod(travel + delta * 0.45, 1.0)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2((travel * 1.2 - 0.2) * size.x, 0), Vector2(size.x * 0.16, size.y)), Color(0.56, 0.94, 0.90, 0.25))

func _ready() -> void:
	_retry.pressed.connect(_on_retry_pressed)
	_loading_panel.resized.connect(_fit_scrim)
	$SafeAreaContainer.resized.connect(_scale_loading_ui)
	_retry.add_theme_stylebox_override("normal", UI.box(Color("#102040"), Color("#4FE0D4"), 12))
	_retry.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, Color("#FFB648"), 12))
	_sweep = ActivitySweep.new()
	_sweep.mouse_filter = MOUSE_FILTER_IGNORE
	_progress.clip_contents = true
	_progress.add_child(_sweep)
	_sweep.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_process(false)

func on_enter(_args: Dictionary) -> void:
	_active = true
	if not get_viewport().size_changed.is_connected(_scale_loading_ui):
		get_viewport().size_changed.connect(_scale_loading_ui)
	_scale_loading_ui()
	_boot()

func on_exit() -> void:
	_active = false
	_boot_token += 1
	_disconnect_progress()
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if get_viewport().size_changed.is_connected(_scale_loading_ui):
		get_viewport().size_changed.disconnect(_scale_loading_ui)
	set_process(false)
	_sweep.set_process(false)

func _exit_tree() -> void:
	on_exit()

func can_go_back() -> bool:
	return false

func _scale_loading_ui() -> void:
	var ratio: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var available: float = $SafeAreaContainer.size.x - 64.0
	var width: float = minf(1000.0, minf(available, get_viewport_rect().size.x * 0.86))
	_loading_panel.custom_minimum_size.x = width
	_progress.custom_minimum_size = Vector2(width, maxf(18.0, ceilf(10.0 / ratio)))
	for label: Label in [_status, _percent, _detail, _tip]:
		label.add_theme_font_size_override("font_size", maxi(22, ceili(16.0 / ratio)))
	_headline.add_theme_font_size_override("font_size", maxi(32, ceili(22.0 / ratio)))
	_retry.add_theme_font_size_override("font_size", maxi(26, ceili(18.0 / ratio)))
	_retry.custom_minimum_size = Vector2(240, maxf(64.0, ceilf(48.0 / ratio)))
	_tip.visible = get_window().size.y >= 500 and _stage != "error"
	_fit_scrim.call_deferred()

func _fit_scrim() -> void:
	if is_inside_tree():
		$BottomScrim.offset_top = -(_loading_panel.size.y + 64.0)

func _boot() -> void:
	_boot_token += 1
	var token: int = _boot_token
	_disconnect_progress()
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_stage = "settings"
	_assets_ready = false
	_has_session = false
	_target = 0.0
	_progress.value = 0.0
	_percent.text = "0%"
	_ready_art.modulate.a = 0.0
	_headline.text = "POWERING UP"
	_headline.add_theme_color_override("font_color", Color("#4FE0D4"))
	_retry.hide()
	_retry.disabled = true
	_retry.text = tr("LOADING_ASSETS_RETRY")
	_tip.text = tr(TIP_KEYS.pick_random())
	_detail.text = "Preparing your session"
	_scale_loading_ui()
	modulate.a = 0.0
	_transition = create_tween()
	_transition.tween_property(self, "modulate:a", 1.0, 0.35)
	set_process(true)
	_set_activity(true)
	# Paint the starting state before synchronous local work begins.
	await get_tree().process_frame
	for step: String in ["settings", "profile", "content", "assets", "session"]:
		if not _still(token):
			return
		_stage = step
		_status.text = tr({"settings": "LOADING_SETTINGS", "profile": "LOADING_PROFILE", "content": "LOADING_CONTENT", "assets": "LOADING_GAME_ASSETS", "session": "LOADING_SESSION"}[step])
		if step == "assets":
			AssetManager.sync_progress.connect(_on_asset_progress)
			_refresh_asset_snapshot()
		elif step == "session":
			_detail.text = "Restoring your session and checking account progress"
		await _perform_boot_step(step)
		if not _still(token):
			return
		if step == "assets":
			_disconnect_progress()
			if not _assets_ready:
				_show_error()
				return
		_set_target(float({"settings": 3.0, "profile": 6.0, "content": ASSET_START, "assets": 90.0, "session": 100.0}[step]))
		await get_tree().process_frame
	if _still(token):
		await _show_ready(token)

## Small test seam: verification replaces I/O, not the real presentation flow.
func _perform_boot_step(step: String) -> void:
	var token: int = _boot_token
	match step:
		"settings": await SettingsService.load_local()
		"profile": await SaveService.load_local()
		"content": await ContentDB.load_all()
		"assets":
			await AssetManager.ensure_ready()
			if _still(token):
				_assets_ready = AssetManager.has_required_gameplay_assets()
		"session":
			var restored: bool = await AuthService.restore_session()
			if not _still(token):
				return
			_has_session = restored
			if _has_session:
				AuthService.start_background_refresh()
				SaveService.fetch_cloud_save()
				await SaveService.wait_for_cloud_fetch()
				if _still(token):
					await PlayerManager.pull_official_bkt()

func _set_activity(enabled: bool) -> void:
	var animate: bool = enabled and not SettingsService.reduced_motion
	_sweep.visible = animate
	_sweep.set_process(animate)

func _process(delta: float) -> void:
	# Smoothing is capped at measured work. No elapsed-time percentage inflation.
	_progress.value = move_toward(_progress.value, _target, delta * 65.0)
	_percent.text = "%d%%" % floori(_progress.value)
	_poll += delta
	if _stage == "assets" and _poll >= 0.1:
		_poll = 0.0
		_refresh_asset_snapshot()

func _set_target(value: float) -> void:
	_target = maxf(_target, clampf(value, 0.0, 100.0))

func _refresh_asset_snapshot() -> void:
	var snapshot: Dictionary = AssetManager.get_sync_progress()
	if bool(snapshot.active):
		_apply_asset_snapshot(snapshot)

func _on_asset_progress(done: int, total: int, label: String) -> void:
	if _active and _stage == "assets":
		_apply_asset_snapshot({"done": done, "total": total, "label": label})

func _apply_asset_snapshot(snapshot: Dictionary) -> void:
	var done: int = int(snapshot.get("done", 0))
	var total: int = int(snapshot.get("total", 0))
	if total <= 0:
		_detail.text = "Checking the local asset cache"
		return
	var count: int = clampi(done, 0, total)
	_set_target(ASSET_START + (ASSET_END - ASSET_START) * float(count) / float(total))
	var label: String = str(snapshot.get("label", ""))
	_status.text = "Checking: " + label
	_status.tooltip_text = label
	_detail.text = "ASSETS CHECKED  %d / %d" % [count, total]
	var received: int = int(snapshot.get("received", 0))
	var bytes_total: int = int(snapshot.get("bytes_total", 0))
	if bool(snapshot.get("downloading", false)):
		_detail.text += "  /  " + String.humanize_size(received)
		if bytes_total > 0:
			_detail.text += " of " + String.humanize_size(bytes_total)
		else:
			_detail.text += " received"
	# Counts are checks, not successful downloads; readiness is validated afterward.

func _show_error() -> void:
	_stage = "error"
	_set_activity(false)
	_headline.text = "CONNECTION CHECK"
	AudioManager.play_sfx("ui_error")
	_headline.add_theme_color_override("font_color", Color("#FFB648"))
	_status.text = tr("LOADING_ASSETS_MISSING")
	_detail.text = "Required assets are missing. Check your connection, then retry."
	_tip.hide()
	_retry.show()
	_retry.disabled = false
	_retry.grab_focus()
	_fit_scrim.call_deferred()

func _show_ready(token: int) -> void:
	_stage = "finishing"
	_status.text = "All checks complete"
	# Catch the visual bar up to the completed work before the ready eyecatch.
	while _still(token) and _progress.value < 99.99:
		await get_tree().process_frame
	if not _still(token):
		return
	_stage = "ready"
	_progress.value = 100.0
	_percent.text = "100%"
	_set_activity(false)
	_headline.text = "DEFENSES ONLINE"
	AudioManager.play_sfx("loading_ready")
	_status.text = "Ready to play"
	_detail.text = "Your next move matters. Make it a smart one."
	_tip.text = "LET'S DO THIS, DEFENDER."
	_transition = create_tween()
	_transition.tween_property(_ready_art, "modulate:a", 1.0, 0.3)
	await _transition.finished
	if not _still(token):
		return
	await get_tree().create_timer(READY_HOLD_SECONDS).timeout
	if not _still(token):
		return
	_transition = create_tween()
	_transition.tween_property(self, "modulate:a", 0.0, 0.3)
	await _transition.finished
	if _still(token):
		_stage = "done"
		set_process(false)
		_navigate(&"dashboard" if _has_session else &"login")

func _navigate(destination: StringName) -> void:
	Router.replace_all(destination)

func _on_retry_pressed() -> void:
	if _active and _stage == "error" and not _retry.disabled:
		_boot()

func _disconnect_progress() -> void:
	if AssetManager.sync_progress.is_connected(_on_asset_progress):
		AssetManager.sync_progress.disconnect(_on_asset_progress)

func _still(token: int) -> bool:
	return _active and token == _boot_token and is_inside_tree()
