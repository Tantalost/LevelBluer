extends SceneTree
## Deterministic I/O stand-in; runs the production boot UI and transition logic.
var failures: int = 0
var screen: Control

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in 8:
		await process_frame

func until_stage(stage: String) -> void:
	var start: int = Time.get_ticks_msec()
	while screen._stage != stage and Time.get_ticks_msec() - start < 6000:
		await process_frame
	check(screen._stage == stage, "Reached stage: " + stage)

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/loading_" + label + ".png")

func _run() -> void:
	# Compile after autoloads are ready, avoiding editor-only singleton resolution.
	var fake: GDScript = GDScript.new()
	fake.source_code = """extends "res://src/ui/screens/intro/splash_screen.gd"
var hold_stage: String = "assets"
var assets_ok: bool = true
var session_ok: bool = true
var destinations: Array[StringName] = []
func _refresh_asset_snapshot() -> void:
	pass
func _perform_boot_step(step: String) -> void:
	var token: int = _boot_token
	while hold_stage == step and _still(token):
		await get_tree().process_frame
	if not _still(token):
		return
	if step == "assets":
		_assets_ready = assets_ok
	if step == "session":
		_has_session = session_ok
func _navigate(destination: StringName) -> void:
	destinations.append(destination)
"""
	check(fake.reload() == OK, "Test stand-in compiles")
	var player: Node = root.get_node("PlayerManager")
	var before: String = JSON.stringify(player.get_save_data())
	var assets: Node = root.get_node("AssetManager")
	var original: Dictionary = assets.get_sync_progress()
	assets._report_sync_progress(3, 7, "Cache test")
	var snapshot: Dictionary = assets.get_sync_progress()
	check(snapshot.done == 3 and snapshot.total == 7 and snapshot.label == "Cache test", "Late subscribers get current asset check counts")
	check(not snapshot.downloading and snapshot.received == 0, "Idle snapshot does not report stale transfer bytes")
	assets._report_sync_progress(original.done, original.total, original.label)
	var packed: PackedScene = load("res://src/ui/screens/intro/splash_screen.tscn")
	screen = packed.instantiate()
	screen.set_script(fake)
	root.add_child(screen)
	screen.on_enter({})
	await until_stage("assets")
	check(screen._target == 10.0, "Assets own the main progress range, not a tiny end segment")
	screen._on_asset_progress(2, 4, "School character atlas")
	check(is_equal_approx(screen._target, 47.5), "Half the catalog maps to real weighted progress")
	screen._apply_asset_snapshot({"done": 2, "total": 4, "label": "School character atlas", "downloading": true, "received": 1024, "bytes_total": 8192})
	check(screen._detail.text.contains("2 / 4") and screen._detail.text.contains("of"), "Asset count and known byte total shown")
	await create_timer(0.9).timeout
	var measured: float = screen._progress.value
	await create_timer(0.5).timeout
	check(is_equal_approx(screen._progress.value, measured) and measured <= 47.5, "Long pending request does not fake percentage progress")
	screen._apply_asset_snapshot({"done": 2, "total": 4, "label": "School character atlas", "downloading": true, "received": 1024, "bytes_total": -1})
	check(screen._detail.text.ends_with("received"), "Unknown byte length remains honest")
	screen._on_asset_progress(1, 4, "Repeated notification")
	check(is_equal_approx(screen._target, 47.5), "Duplicate or delayed progress cannot move percentage backward")
	screen._on_asset_progress(2, 4, "School character atlas")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(screen._loading_panel.get_global_rect()), "Loading controls fit landscape")
		check(is_equal_approx(-screen.get_node("BottomScrim").offset_top, screen._loading_panel.size.y + 64.0), "Scrim follows the laid-out footer instead of covering the artwork")
		check(screen._status.get_theme_font_size("font_size") * root.get_final_transform().get_scale().y >= 16.0, "Loading text stays readable")
		await capture("before_%dx%d" % [dimensions.x, dimensions.y])
	screen.hold_stage = "session"
	await until_stage("session")
	check(screen._target == 90.0 and screen._ready_art.modulate.a == 0.0, "Successful assets do not finish pending account work")
	screen.hold_stage = ""
	await until_stage("ready")
	check(screen._progress.value == 100.0 and screen.destinations.is_empty(), "Ready eyecatch precedes navigation")
	await create_timer(0.4).timeout
	await capture("after_844x390")
	check(screen._ready_art.modulate.a == 1.0 and not screen._sweep.visible, "Separate ready art fully replaces loading art")
	await until_stage("done")
	check(screen.destinations == [&"dashboard"], "Signed-in boot routes once after ready hold")
	# Retry must reset visual progress, reject double clicks and never reveal ready on error.
	screen.on_exit()
	screen.assets_ok = false
	screen.on_enter({})
	await until_stage("error")
	check(screen._retry.visible and not screen._retry.disabled and screen._ready_art.modulate.a == 0.0, "Missing required assets offer Retry without success art")
	await settle()
	check(root.get_visible_rect().encloses(screen._retry.get_global_rect()), "Retry stays reachable on mobile landscape")
	await capture("retry_844x390")
	screen.assets_ok = true
	screen.session_ok = false
	screen.hold_stage = "assets"
	screen._retry.pressed.emit()
	var retry_token: int = screen._boot_token
	screen._retry.pressed.emit()
	check(screen._boot_token == retry_token and screen._progress.value == 0.0, "One retry resets progress exactly once")
	await until_stage("assets")
	screen.hold_stage = ""
	await until_stage("done")
	check(screen.destinations == [&"dashboard", &"login"], "No-session boot routes to login")
	# Cancel during I/O and during ready hold; stale coroutines must never navigate.
	screen.on_exit()
	screen.hold_stage = "assets"
	screen.on_enter({})
	await until_stage("assets")
	screen.on_exit()
	screen.hold_stage = ""
	await create_timer(0.2).timeout
	check(not assets.sync_progress.is_connected(screen._on_asset_progress), "Exit disconnects the progress signal")
	screen.on_enter({})
	await until_stage("ready")
	screen.on_exit()
	await create_timer(1.8).timeout
	check(screen.destinations.size() == 2, "Exit during ready transition cancels navigation")
	var settings: Node = root.get_node("SettingsService")
	var old_motion: bool = settings.reduced_motion
	settings.reduced_motion = true
	screen.hold_stage = "assets"
	screen.on_enter({})
	await until_stage("assets")
	check(not screen._sweep.visible and not screen._sweep.is_processing(), "Reduced motion disables scan animation")
	screen.on_exit()
	settings.reduced_motion = old_motion
	check(JSON.stringify(player.get_save_data()) == before, "Presentation tests never change player progress")
	screen.queue_free()
	await settle()
	print("[LOADING SCREEN] failures=%d" % failures)
	quit(1 if failures else 0)
