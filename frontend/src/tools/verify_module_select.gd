extends SceneTree
## Read-only screen verification using in-memory account fixtures.
var failures: int = 0
var intro_checks_finished: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 10:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/module_select_" + label + ".png")

func fingerprint(player: Node, auth: Node) -> String:
	return JSON.stringify([player.lesson_progress, player.completed_lessons, player.cleared_stages,
		player.credits, auth._mastery, auth._points])

func _run() -> void:
	var player := root.get_node("PlayerManager")
	var auth := root.get_node("AuthService")
	auth._signed_in = false
	auth._points = 1250
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.cleared_stages = {}
	player.credits = 229
	var screen: Control = load("res://src/ui/screens/deploy/stage_select_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	await settle()
	check(screen._cards.size() == 5, "All five modules shown")
	check(screen.get_node("CRTOverlay").visible, "Permanent subtle CRT")
	check(screen._breach_button.disabled, "Fresh account cannot deploy")
	check(screen._lock_reason(0).contains("Module 1"), "First operation explains lesson prerequisite")
	var before := fingerprint(player, auth)
	for i in 5:
		screen._cards[i].pressed.emit()
		await settle()
		check(screen._selected == i, "Locked module %d selectable for explanation" % i)
		check(screen._breach_button.disabled, "Locked CTA remains disabled")
	screen._preview_module(0)
	await settle()
	await capture("locked_1280")
	check(fingerprint(player, auth) == before, "Viewing all modules does not change account")
	player.lesson_progress = {"mod_01": 6, "mod_02": 3}
	player.completed_lessons.assign(["mod_01"])
	player.cleared_stages = {"mod_01:1": true, "mod_01:3": true}
	screen.on_resume()
	await settle()
	check(screen._is_unlocked(0) and screen._is_unlocked(1), "Modules open after their own first lesson")
	player.lesson_progress["mod_02"] = 0
	check(not screen._is_unlocked(1), "Completed Module 1 alone cannot open Module 2")
	player.lesson_progress["mod_02"] = 1
	check(screen._is_unlocked(1), "Module 2 Lesson 1 opens Module 2")
	check(not screen._is_unlocked(2), "Partial previous lessons do not unlock next module")
	check(not screen._breach_button.disabled, "Open CTA enabled for available operation")
	check(screen._module_route(0).route == &"module_intro", "First module keeps introduction route")
	check(screen._module_route(4).route == &"module_stages", "Other modules keep stage route")
	check(screen._module_route(4).args.module_index == 4, "Route module index preserved")
	await capture("available_1280")
	screen._preview_module(1)
	await settle()
	await capture("coming_soon")
	screen._preview_module(0)
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		if dimensions.x == 844:
			var units_per_pixel := 1.0 / root.get_final_transform().get_scale().x
			for child in screen.get_children():
				if child is SafeAreaContainer:
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units_per_pixel))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units_per_pixel))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units_per_pixel))
			await settle()
		check(screen._body.get_global_rect().end.x <= screen.size.x, "Body fits viewport")
		check(screen._title.get_global_rect().end.x <= screen.size.x, "Header fits viewport")
		var physical_scale := root.get_final_transform().get_scale().y
		check(screen._back.size.y * physical_scale >= 47, "Back touch target >=48 physical pixels")
		check(screen._settings.size.y * physical_scale >= 47, "Settings touch target >=48 physical pixels")
		check(screen._breach_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Open action always visible")
		check(screen._breach_button.size.y * physical_scale >= 47, "Open action touch target")
		check(screen._settings.get_global_rect().end.x <= root.get_visible_rect().end.x, "Header action fits safe area")
		for card in screen._cards:
			check(card.size.y * physical_scale >= 47, "Module card touch target")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
	player.lesson_progress.clear()
	player.completed_lessons.clear()
	auth.session_changed.emit(false)
	await settle()
	check(screen._selected == 0 and screen._breach_button.disabled, "Account change clears selected/access presentation")
	screen.on_exit()
	check(not screen.visible, "Exit hides screen")
	screen.on_resume()
	await settle()
	check(screen.visible, "Resume restores screen")
	screen.queue_free()
	await settle()
	await check_intro(player, auth)
	check(intro_checks_finished, "Intro checks reached completion")
	print("MODULE_SELECT_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)

func check_intro(player: Node, auth: Node) -> void:
	var assets: Node = root.get_node("AssetManager")
	if "--download-art" in OS.get_cmdline_user_args():
		for entry: Dictionary in assets._ui_catalog():
			if str(entry.asset_id) in ["module1_email_tricks_title_v1", "opening_five_victims_john_v4"]:
				check(await assets._download_and_store(entry), "New cinematic art downloads and caches")
	var settings: Node = root.get_node("SettingsService")
	var previous_motion: bool = settings.reduced_motion
	var previous_speed: String = settings.text_speed
	settings.reduced_motion = false
	settings.text_speed = "normal"
	root.size = Vector2i(1280, 720)
	var intro: Control = load("res://src/ui/screens/deploy/module_intro_screen.tscn").instantiate()
	root.add_child(intro)
	var before: String = fingerprint(player, auth)
	var seen_before: String = JSON.stringify(player.seen_module_intros)
	intro.on_enter({"module_index": 0})
	await settle()
	check(intro._skip_button.visible, "First-time readers can skip to title card")
	check(intro._index == 0 and not intro._ending, "Intro begins with John's email")
	intro._advance()
	check(intro._index == 0 and intro._dialogue_text.visible_characters == -1, "First tap reveals line without skipping it")
	intro._last_advance = -1000
	intro._advance()
	check(intro._index == 1, "Next tap advances exactly one beat")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var characters: int = intro._dialogue_text.visible_characters
	await create_timer(0.2).timeout
	intro._last_advance = -1000
	intro._advance()
	check(intro._index == 1 and intro._dialogue_text.visible_characters == characters, "Focus loss freezes typing and input")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	settings.reduced_motion = true
	intro._settings_changed()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		for beat: int in [0, 2, 7]:
			intro._index = beat
			intro._show_beat()
			await settle()
			var dialog_bounds: Rect2 = intro._dialogue.get_global_rect()
			check(dialog_bounds.end.y <= intro.size.y + 1, "Narration fits viewport at beat %d / %d" % [beat, dimensions.x])
			if intro._item.visible:
				check(intro._item.get_global_rect().end.y <= dialog_bounds.position.y, "Item stays above narration at beat %d / %d" % [beat, dimensions.x])
				check(intro._item.position.x < intro.size.x * 0.1 and intro._item.size.x < intro.size.x * 0.45, "Email evidence stays compact on the left")
			check(intro._advance_button.size.y * root.get_final_transform().get_scale().y >= 47, "Intro advance has a mobile touch target")
			await capture("intro_%d_%d" % [dimensions.x, beat])
		for beat: int in [3, 4, 5, 6, 8]:
			intro._index = beat
			intro._show_beat()
			await create_timer(0.45).timeout
			check(intro._caption.visible and not intro._dialogue.visible and not intro._item.visible, "Thought captions hide narration and explanation cards")
			check(intro._caption.text == str(intro.BEATS[beat]["line"]), "Only the current thought appears")
			await capture("intro_%d_thought_%d" % [dimensions.x, beat])
		intro._last_advance = -1000
		intro._advance()
		check(intro._ending, "Final line leads to title card")
		await create_timer(0.4).timeout
		check(not intro._start_button.disabled, "Title card offers Continue after reveal")
		check(intro._chapter_label.text == "MODULE 1" and intro._ending_title.text == "Email Tricks", "Requested title card wording")
		check(intro._start_button.get_global_rect().end.y <= intro.size.y + 1, "Title card Continue fits viewport")
		await capture("intro_title_%d" % dimensions.x)
		intro._restart()
		check(intro._index == 0 and not intro._ending, "Replay resets narrative")
	intro._index = 3
	intro._show_beat()
	await create_timer(2.9).timeout
	check(intro._index == 4, "Centered thought fades out and advances automatically")
	intro._skip()
	await create_timer(3.0).timeout
	check(intro._ending and not intro._caption.visible, "Skipped thought cannot resume its abandoned sequence")
	intro._restart()
	settings.reduced_motion = false
	intro._skip()
	check(intro._ending, "Skip still presents module title")
	check(intro._start_button.disabled, "Normal-motion title waits for artwork reveal")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	var reveal: float = intro._art.reveal
	await create_timer(0.2).timeout
	check(is_equal_approx(intro._art.reveal, reveal), "App suspension pauses title reveal")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(1.1).timeout
	check(not intro._start_button.disabled and is_equal_approx(intro._art.reveal, 1.0), "Normal-motion title finishes after resume")
	intro.on_exit()
	check(not intro.visible and intro._motion == null and intro._typing == null, "Exit cancels owned animations")
	intro.on_resume()
	check(intro.visible and not intro._start_button.disabled, "Resuming title cannot strand Continue")
	check(fingerprint(player, auth) == before and JSON.stringify(player.seen_module_intros) == seen_before, "Reading, skipping and replaying never award progress or write seen status")
	intro.free()
	settings.reduced_motion = previous_motion
	settings.text_speed = previous_speed
	intro_checks_finished = true
