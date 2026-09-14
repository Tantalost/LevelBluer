extends SceneTree
## Read-only dashboard smoke test: no login, sync, navigation or progression writes.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _settle() -> void:
	for i in 4:
		await process_frame

func _capture(filename: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func _check_profile_info(screen: Control) -> void:
	var main: Control = screen.get_node("SafeAreaContainer/ScreenLayout/MainRow")
	var profile: Rect2 = screen.get_node("HeaderBand/HeaderLayer/ProfileButton").get_global_rect()
	var progress: Rect2 = main.get_node("UpdatesPanel").get_global_rect()
	_check(absf(progress.get_center().x - profile.get_center().x) < 1, "Field progress centered beneath profile")
	_check(progress.position.y > profile.end.y, "Field progress below profile")
	_check(progress.end.y < main.get_node("DeployButton").get_global_rect().position.y, "Profile info clears menu")

func _run() -> void:
	var screen: Control = load("res://src/ui/screens/dashboard/dashboard_screen.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	screen._bind_remote_art()
	screen._refresh_data()
	screen._update_mode_ui()
	screen.get_node("PreTestLock").hide()
	var handler: Control = screen.get_node("SafeAreaContainer/ScreenLayout/MainRow/Companion")
	_check(screen.get_node_or_null("HeroArt") == null, "Duplicate temporary art removed")
	_check(screen.get_node("Background").texture != null, "Scenic background loaded from synced catalog")
	_check(handler._portrait.texture != null, "Existing handler expression cached")
	await _settle()
	_check_profile_info(screen)
	await _capture("dashboard_scenic_idle")
	var main: Control = screen.get_node("SafeAreaContainer/ScreenLayout/MainRow")
	var world: Control = main.get_node("WorldButton")
	_check(world.get_global_rect().end.x + 20 < handler.get_global_rect().position.x, "Companion has spacing from menu")
	var shapes := {"DeployButton": 5, "LessonsButton": 5, "CodexButton": 7, "StoreButton": 8, "ProgressButton": 9, "WorldButton": 1}
	for name: String in shapes:
		_check(main.get_node(name).geo == shapes[name], "Preserved menu shape: " + name)
	var store: Control = main.get_node("StoreButton")
	var progress: Control = main.get_node("ProgressButton")
	_check(is_equal_approx(store.position.y, progress.position.y), "Store and Progress share a baseline")
	_check(is_equal_approx(store.size.x, progress.size.x), "Store and Progress have equal width")
	var utility_gap: float = progress.position.x - (store.position.x + store.size.x)
	_check(utility_gap >= 0.0 and utility_gap <= 12.0, "Store and Progress keep a narrow visual seam")
	_check(int(store.get("title_size")) == int(progress.get("title_size")), "Store and Progress use consistent label spacing")
	_check(store.z_index == world.z_index and progress.z_index == world.z_index, "Utility pair does not leak above stacked screens")
	_check(store.get_index() > world.get_index() and progress.get_index() > world.get_index(), "Utility buttons render locally above World")
	handler._portrait_button.pressed.emit()
	_check(handler._dialogue.visible and handler._typing, "Click opens compact typewriter dialogue")
	handler.talk()
	_check(not handler._typing and handler._body.visible_characters == -1, "Click during typing reveals line")
	await _settle()
	await _capture("dashboard_scenic_dialogue")
	_check(root.get_visible_rect().encloses(handler._dialogue.get_global_rect()), "Dialogue fits screen")
	_check(not world.get_global_rect().intersects(handler._dialogue.get_global_rect()), "Dialogue does not cover World")
	handler.talk()
	_check(handler._dialogue.visible and handler._typing, "Next starts a random line")
	_check(handler._line >= 0 and handler._line < handler.LINES.size(), "Random line is valid")
	handler.set_interaction_enabled(false)
	handler.talk()
	_check(not handler._dialogue.visible, "Tutorial/pretest lock suppresses companion")
	handler.set_interaction_enabled(true)
	handler.talk()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	handler._unhandled_key_input(escape)
	_check(not handler._dialogue.visible, "Escape closes only companion")
	root.size = Vector2i(960, 600)
	await _settle()
	handler.talk()
	handler._finish_line()
	await _settle()
	_check(world.get_global_rect().end.x + 12 < handler.get_global_rect().position.x, "Compact menu has spacing")
	_check(root.get_visible_rect().encloses(handler._dialogue.get_global_rect()), "Compact dialogue fits")
	_check_profile_info(screen)
	await _capture("dashboard_scenic_compact")
	for name: String in shapes:
		_check(root.get_visible_rect().encloses(main.get_node(name).get_global_rect()), "Compact button fits: " + name)
	# Simulate missing remote art in memory only, then a completed asset sync.
	var assets := root.get_node("AssetManager")
	var idle: Texture2D = assets.get_texture("npc_calm")
	if idle == null:
		idle = assets.get_texture("npc_smile")
	assets._textures["npc_calm"] = null
	assets._textures["npc_smile"] = null
	handler._portrait.texture = null
	handler._expression = ""
	handler.close_dialogue()
	_check(not handler._portrait_button.text.is_empty(), "Missing art has a clickable fallback")
	assets._textures["npc_calm"] = idle
	assets._textures["npc_smile"] = idle
	handler._on_assets_ready(true)
	_check(handler._portrait.texture == idle, "Late asset sync restores portrait")
	screen._apply_lock_state()
	var auth := root.get_node("AuthService")
	if not auth.has_pre_test_completed():
		_check(not handler._enabled, "Actual pretest state disables handler")
	screen.on_exit()
	_check(not handler._dialogue.visible, "Leaving screen closes dialogue")
	print("[DASHBOARD UI] failures=%d" % failures)
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
