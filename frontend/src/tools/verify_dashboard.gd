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

func _tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func _check_profile_info(screen: Control) -> void:
	var main: Control = screen.get_node("SafeAreaContainer/ScreenLayout/MainRow")
	var profile: Rect2 = screen.get_node("HeaderBand/HeaderLayer/ProfileButton").get_global_rect()
	var progress: Rect2 = main.get_node("UpdatesPanel").get_global_rect()
	_check(absf(progress.get_center().x - profile.get_center().x) < 1, "Field progress centered beneath profile")
	_check(progress.position.y > profile.end.y, "Field progress below profile")
	_check(progress.end.y < main.get_node("DeployButton").get_global_rect().position.y, "Profile info clears menu")

func _verify_modes(screen: Control) -> void:
	var player: Node = root.get_node("PlayerManager")
	var settings: Node = root.get_node("SettingsService")
	var prior_tutorial: bool = player.tutorial_complete
	var prior_reduced: bool = settings.reduced_motion
	var progress_before: Dictionary = player.lesson_progress.duplicate(true)
	# Memory-only setup. Do not invoke tutorial completion or settings/save APIs.
	player.tutorial_complete = true
	settings.reduced_motion = false
	var selector: Control = screen._mode_selector
	var modal: Control = screen._mode_modal
	var completed: Array[StringName] = []
	screen.mode_switch_finished.connect(func(mode: StringName) -> void: completed.append(mode))
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await _settle()
		_check(selector.is_visible_in_tree(), "OS switch is visible on Solo")
		_check(root.get_visible_rect().encloses(selector.get_global_rect()), "OS switch fits %s" % dimensions)
		await _tap(selector)
		_check(modal.visible, "Dashboard switch opens selector")
		await create_timer(0.3).timeout
		await _capture("mode_solo_%dx%d" % [dimensions.x, dimensions.y])
		await _tap(modal._bands[1])
		_check(modal.get_mode_name() == &"PVP", "Native pointer selects the red side")
		await create_timer(0.3).timeout
		_check(screen._selected_mode == &"SOLO", "Preview does not commit mode")
		_check(root.get_visible_rect().encloses(modal._confirm.get_global_rect()), "Confirm fits %s" % dimensions)
		_check(root.get_visible_rect().encloses(modal._cancel.get_global_rect()), "Cancel fits %s" % dimensions)
		for band: Button in modal._bands:
			_check(root.get_visible_rect().encloses(band.get_global_rect()), "Both choices fit %s" % dimensions)
			_check(is_equal_approx(band.size.y, modal.size.y), "Mode artwork fills the screen height")
			_check(is_equal_approx(band.size.x, modal.size.x * 0.5), "Each mode occupies half the screen")
			_check(band.copy.get_rect().end.y < band.size.y, "Mode copy stays inside its side at %s: bottom=%s height=%s" % [dimensions, band.copy.get_rect().end.y, band.size.y])
			_check(band.copy.get_global_rect().end.y < modal._confirm.get_global_rect().position.y, "Mode text clears floating footer")
		_check(is_equal_approx(modal._bands[0].get_global_rect().end.x, modal._bands[1].get_global_rect().position.x), "Full-bleed halves meet with no gap")
		await _capture("mode_pvp_%dx%d" % [dimensions.x, dimensions.y])
		await _tap(modal._cancel)
		_check(not modal.visible and screen._selected_mode == &"SOLO", "Cancel preserves Solo")
	# Current mode confirmation must never trigger the power cycle.
	selector.pressed.emit()
	var focus_before: Control = root.gui_get_focus_owner()
	var tab: InputEventKey = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	for index: int in 4:
		root.push_input(tab, true)
		await process_frame
	_check(root.gui_get_focus_owner() == focus_before, "Tab cycles only inside the selector")
	modal._confirm.pressed.emit()
	_check(not screen._mode_transitioning and completed.is_empty(), "Same-mode confirm closes without reboot")
	selector.pressed.emit()
	modal._bands[1].pressed.emit()
	await _tap(modal._confirm)
	_check(screen._mode_transitioning and screen._power_overlay.visible, "Change starts input-blocking shutter")
	_check(screen._selected_mode == &"SOLO", "Mode remains Solo until shutter is shut")
	screen._on_mode_confirmed(&"SOLO")
	_check(screen._pending_mode == &"PVP", "Repeated confirm cannot replace an active switch")
	await create_timer(0.2).timeout
	await _capture("mode_power_closing")
	await create_timer(0.27).timeout
	_check(screen._selected_mode == &"PVP", "Mode changes behind closed screen")
	_check(is_equal_approx(screen._power_overlay.closure, 1.0), "OS commit is completely covered")
	await _capture("mode_power_off")
	await create_timer(0.85).timeout
	_check(not screen._mode_transitioning and not screen._power_overlay.visible, "Power-on releases input")
	_check(completed == [&"PVP"], "Switch completes exactly once")
	_check(screen._pvp_hub.visible and not screen.get_node("SafeAreaContainer").visible, "PvP has its own workspace")
	_check(screen._pvp_hub._queue.disabled, "Unimplemented matchmaking cannot be started")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await _settle()
		_check(root.get_visible_rect().encloses(screen._pvp_hub._switch.get_global_rect()), "PvP return switch fits")
		_check(not screen._pvp_hub._status.get_global_rect().intersects(screen._pvp_hub._switch.get_global_rect()), "PvP copy clears return control")
		await _capture("pvp_workspace_%dx%d" % [dimensions.x, dimensions.y])
	screen._pvp_hub._switch.pressed.emit()
	_check(modal.visible and modal.get_mode_name() == &"PVP", "PvP switch opens selector with current mode")
	modal._bands[0].pressed.emit()
	modal._confirm.pressed.emit()
	await create_timer(1.3).timeout
	_check(screen._selected_mode == &"SOLO" and not screen._pvp_hub.visible, "Reverse power cycle restores Solo")
	_check(screen.get_node("SafeAreaContainer").visible and screen.get_node("HeaderBand").visible, "Solo controls restored")
	_check(completed == [&"PVP", &"SOLO"], "Both directions complete once")
	settings.reduced_motion = true
	screen._on_mode_confirmed(&"PVP")
	_check(screen._power_overlay.reduced, "Reduced motion uses fade instead of shutter")
	await create_timer(0.45).timeout
	_check(not screen._mode_transitioning and screen._selected_mode == &"PVP", "Reduced-motion transition completes")
	screen._on_mode_confirmed(&"SOLO")
	screen.on_exit()
	await create_timer(0.45).timeout
	_check(not screen._power_overlay.visible and not screen._mode_transitioning, "Screen exit cancels transition")
	_check(screen._selected_mode == &"PVP", "Cancelled pre-commit switch cannot mutate mode later")
	_check(player.lesson_progress == progress_before, "Switching OS preserves lesson progress")
	player.tutorial_complete = prior_tutorial
	settings.reduced_motion = prior_reduced

func _verify_remote_pvp_art(screen: Control) -> void:
	var assets: Node = root.get_node("AssetManager")
	var entry_found: bool = false
	var workspace_found: bool = false
	for entry: Dictionary in assets._ui_catalog():
		if str(entry.asset_id) == "ui_dashboard_pvp_workspace":
			workspace_found = str(entry.cloudinary_url) == "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791168774/pvp_workspace_muted_v1.png"
		if str(entry.asset_id) == "ui_dashboard_pvp":
			entry_found = str(entry.cloudinary_url) == "https://res.cloudinary.com/nfd5bhkz/image/upload/v1791049225/pvp_command_v1.png"
	_check(entry_found, "PvP catalog uses the supplied Cloudinary URL")
	_check(workspace_found, "Muted workspace uses its separate supplied Cloudinary URL")
	_check(assets._bundled_path("ui_dashboard_pvp").is_empty(), "PvP no longer depends on a bundled image")
	var original: Texture2D = assets.get_texture("ui_dashboard_pvp")
	var original_workspace: Texture2D = assets.get_texture("ui_dashboard_pvp_workspace")
	_check(assets._bundled_path("ui_dashboard_pvp_workspace").is_empty(), "Workspace is remote-only")
	var workspace_image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	workspace_image.fill(Color("301018"))
	var workspace: Texture2D = ImageTexture.create_from_image(workspace_image)
	assets._textures["ui_dashboard_pvp_workspace"] = workspace
	assets._textures["ui_dashboard_pvp"] = null
	screen._mode_modal._refresh_art()
	screen._pvp_hub._refresh_art()
	_check(screen._mode_modal._bands[1].art == null, "Missing selector cache leaves usable color fallback")
	_check(screen._pvp_hub._backdrop.texture == workspace, "Missing selector art does not affect workspace")
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("#FF5C5C"))
	var downloaded: Texture2D = ImageTexture.create_from_image(image)
	assets._textures["ui_dashboard_pvp"] = downloaded
	# Even a partially successful catalog sync must refresh available artwork.
	assets.sync_finished.emit(false)
	_check(screen._mode_modal._bands[1].art == downloaded, "Selector refreshes after a late download")
	_check(screen._pvp_hub._backdrop.texture == workspace, "Selector downloads cannot replace calm workspace art")
	assets._textures["ui_dashboard_pvp_workspace"] = null
	screen._pvp_hub._refresh_art()
	_check(screen._pvp_hub._backdrop.texture == null, "Workspace supports native fallback when art is missing")
	assets._textures["ui_dashboard_pvp_workspace"] = workspace
	assets.sync_finished.emit(false)
	_check(screen._pvp_hub._backdrop.texture == workspace, "Workspace refreshes independently after asset sync")
	if original != null:
		assets._textures["ui_dashboard_pvp"] = original
	else:
		assets._textures.erase("ui_dashboard_pvp")
	if original_workspace != null:
		assets._textures["ui_dashboard_pvp_workspace"] = original_workspace
	else:
		assets._textures.erase("ui_dashboard_pvp_workspace")
	screen._mode_modal._refresh_art()
	screen._pvp_hub._refresh_art()

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
	if FileAccess.file_exists("user://assets/ui_dashboard_scenic.png"):
		_check(screen.get_node("Background").texture != null, "Scenic background loaded from synced catalog")
	else:
		print("[SKIP DASHBOARD ART] Scenic background is not cached locally")
	if FileAccess.file_exists("user://assets/npc_calm.png"):
		_check(handler._portrait.texture != null, "Existing handler expression cached")
	else:
		print("[SKIP DASHBOARD ART] Handler portrait is not cached locally")
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
	# _apply_lock_state() only hides the retired pre-test lock overlay now
	# (see the "pre test fix" commit) — it no longer touches the companion's
	# interaction state, which is set once after tutorial dismissal instead
	# (see _on_tutorial_dismissed()). Confirm that intentional, current
	# behavior directly rather than asserting the old side effect.
	screen._apply_lock_state()
	_check(not screen.get_node("PreTestLock").visible, "_apply_lock_state() hides the retired pre-test lock overlay")
	_verify_remote_pvp_art(screen)
	await _verify_modes(screen)
	screen.on_exit()
	_check(not handler._dialogue.visible, "Leaving screen closes dialogue")
	print("[DASHBOARD UI] failures=%d" % failures)
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
