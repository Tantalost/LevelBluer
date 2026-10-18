extends SceneTree
## Disposable training only; never confirms the persistent completion/reward actions.
var failures: int = 0
var game: Control
var player: Node
var router: Node


func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in 8:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/tutorial_" + label + ".png")

func finish_dialogue() -> void:
	var view: Control = game.story_view
	for step: int in 20:
		if view._mail_open or view._dialogue_done:
			break
		view._continue()

func response_index(outcome: String) -> int:
	var choices: Array = game.threat.choices
	for index: int in choices.size():
		if str(choices[index].outcome) == outcome:
			return index
	return -1

func _run() -> void:
	player = root.get_node("PlayerManager")
	router = root.get_node("Router")
	if "--opening-only" in OS.get_cmdline_user_args():
		await _run_opening_only()
		return
	var before: String = JSON.stringify(player.get_save_data())
	var old_tutorial: bool = router.is_tutorial
	var settings: Node = root.get_node("SettingsService")
	var previous_assist: String = settings.timed_decision_assist
	settings.timed_decision_assist = "normal"
	router.is_tutorial = true
	var context: MatchContext = router._context_for_stage(0)
	check(context.tutorial and context.geometric and not context.persistent and not context.account_bonuses, "Router isolates training from stage/account state")
	check(router._scene_for_context(context) == router.TUTORIAL_SCENE, "Router chooses current battlefield training")
	game = load(router.TUTORIAL_SCENE).instantiate()
	game.match_context = context
	root.add_child(game)
	game.set_process(false)
	await settle()
	check(game.hud != null and game.phase == "Training", "Training scene initializes")
	await capture("intro")
	game._begin_investigation()
	check(not game.deciding, "No countdown while reading or investigating")
	game._choose_training_response(response_index("SAFE"))
	check(game.phase == "Investigate", "Cannot bypass evidence with a choice")
	finish_dialogue()
	var phone: Control = game.story_view._phone
	check(phone.visible and phone._app == "lock", "First message opens real phone lockscreen")
	phone._unlock()
	phone._navigate("mail")
	phone._open_message()
	phone._request_close()
	finish_dialogue()
	check(phone.visible and phone._investigating, "Evidence investigation opens before decisions")
	phone._finish()
	check(not game.decision_open, "Uninspected evidence blocks decision")
	phone._navigate("mail")
	phone._open_message()
	phone._inspect("sender")
	phone._inspect("destination")
	phone._navigate("contacts")
	phone._inspect("directory")
	check(phone.is_complete(), "All actual phone evidence tasks checked")
	await capture("evidence")
	root.size = Vector2i(844, 390)
	await settle()
	check(phone._guide.get_theme_font_size("normal_font_size") * root.get_final_transform().get_scale().y >= 20.0, "Phone checklist keeps larger tutorial text")
	check(root.get_visible_rect().encloses(phone._guide_panel.get_global_rect()), "Larger phone checklist fits mobile landscape")
	await capture("evidence_844x390")
	phone._finish()
	check(game.phase == "Decision" and game.evidence_complete, "Confirmed evidence enables choices")
	await settle()
	await capture("decision")
	for choice: Button in game.story_view._choice_buttons:
		check(root.get_visible_rect().encloses(choice.get_global_rect()), "Larger decisions fit mobile landscape")
	game._choose_training_response(response_index("CRITICAL"))
	check(game.training_hp == 2 and game.phase == "Feedback", "Failed practice response demonstrates one HP loss")
	game._choose_training_response(response_index("CRITICAL"))
	check(game.training_hp == 2, "Duplicate response cannot deduct twice")
	settings.timed_decision_assist = "extended"
	game._after_response()
	finish_dialogue()
	check(is_equal_approx(game.decision_duration, 78.75), "Practice respects extended decision time")
	game.deciding = true
	game.decision_remaining = 0.01
	game._process(0.02)
	check(game.phase == "Feedback" and game.training_hp == 1, "Timeout gives explainable retry feedback")
	settings.timed_decision_assist = "off"
	game._after_response()
	finish_dialogue()
	game._process(100.0)
	check(not game.deciding and game.phase == "Decision", "Timer-off accessibility never expires a practice choice")
	game._choose_training_response(response_index("SAFE"))
	check(game.training_hp == 1 and game.last_outcome == "SAFE", "Safe answer accepted without forced mistake")
	game._after_response()
	check(game.phase == "Build", "Safe response leads to separately labeled defense drill")
	game.begin_defend()
	check(game.phase == "Build", "Defense waits for actual placements")
	var placed: int = 0
	for y: int in 12:
		for x: int in 20:
			var cell: Vector2i = Vector2i(x, y)
			if placed < 2 and game.cell_reason(cell, "base").is_empty():
				game.select_cell(cell)
				game.pick_tower("base")
				if game.place_tower():
					placed += 1
	check(placed == 2 and not game.hud.start_button.disabled, "Two nodes unlock Start Defense")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		game._refresh_build_guide()
		await settle()
		check(root.get_visible_rect().encloses(game.coach._dialogue_box.get_global_rect()), "Checklist fits landscape viewport")
		check(game.coach._body_label.get_theme_font_size("font_size") * root.get_final_transform().get_scale().x >= 20.0, "Coach text stays at least 20 screen pixels")
		check(game.coach._body_label.get_visible_line_count() == game.coach._body_label.get_line_count(), "Larger checklist text is not clipped")
		await capture("build_%dx%d" % [dimensions.x, dimensions.y])
	game.begin_defend()
	check(game.phase == "Defend" and not game.coach.visible, "Defense starts on the geometric battlefield")
	check(game._enemy_task_gateway() == null, "Practice enemies do not grant mission rewards")
	game.set_process(true)
	game.speed = 4.0
	Engine.time_scale = 4.0
	for tick: int in 1200:
		if game.phase == "Results":
			break
		await create_timer(0.05, true, false, true).timeout
	check(game.health > 0 and game.spawned == 3 and game.waves_completed == 1, "Real practice wave runs to completion")
	check(game.phase == "Results" and game.hud.modal.visible, "Defense success offers the upgrade handoff")
	game.queue_free()
	await settle()
	game = load(router.TUTORIAL_SCENE).instantiate()
	game.match_context = context
	root.add_child(game)
	game.set_process(false)
	game.phase = "Investigate"
	game._decision_available()
	game._choose_training_response(response_index("RISKY"))
	check(game.last_outcome == "RISKY" and game.training_hp == 3, "Risky response does not reduce HP")
	game._after_response()
	check(game.phase == "Build", "Risky response reaches containment practice")
	game.queue_free()
	await settle()
	var host: Control = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var coach_script: GDScript = load("res://src/gameplay/tutorial/tutorial_overlay.gd")
	var overlay: Control = coach_script.mount_on(host)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		overlay.setup_explore()
		overlay._finish_line()
		await settle()
		check(overlay._name_label.text == TranslationServer.translate("TUTORIAL_COMPLETE_TITLE"), "Explicit tutorial completion title")
		check(overlay._choice_list.get_child_count() == 1 and overlay._choice_list.get_child(0).text == TranslationServer.translate("TUTORIAL_CHOICE_EXPLORE"), "Completion has one clear next step")
		check(root.get_visible_rect().encloses(overlay._choice_list.get_global_rect()), "Completion action fits landscape")
		check(overlay._body_label.get_visible_line_count() == overlay._body_label.get_line_count(), "Completion copy is fully visible at larger size")
		check(overlay._dialogue_box.get_global_rect().end.y <= overlay._choice_list.get_global_rect().position.y, "Completion copy does not overlap its action")
		await capture("complete_%dx%d" % [dimensions.x, dimensions.y])
	host.queue_free()
	await settle()
	var previous_beat: StringName = router.tutorial_beat
	router.tutorial_beat = &"lesson"
	var lesson: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	root.add_child(lesson)
	lesson.on_enter({"module_id": "mod_01", "tutorial": true})
	await settle()
	lesson._on_tutorial_file_requested()
	check(lesson._in_lesson and lesson._workspace.visible and not lesson._tutorial_overlay.visible, "Start Lesson opens Learn directly instead of leaving player on the old file gate")
	lesson.queue_free()
	await settle()
	router.tutorial_beat = previous_beat
	check(JSON.stringify(player.get_save_data()) == before, "Practice has no account, mastery, reward or stage writes")
	router.is_tutorial = old_tutorial
	if not old_tutorial:
		var live_context: MatchContext = router._context_for_stage(0)
		check(not live_context.tutorial and live_context.persistent, "Real-stage routing still uses persistent context")
	settings.timed_decision_assist = previous_assist
	await _check_navigation()
	await _stop_test_audio()
	print("[TUTORIAL] failures=%d" % failures)
	quit(1 if failures else 0)


func _check_navigation() -> void:
	var memory_script: GDScript = GDScript.new()
	memory_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\tpass\n"
	check(memory_script.reload() == OK, "Memory-only account fixture compiles")
	var fixture: Node = memory_script.new()
	fixture.reset_to_defaults()
	var original: Dictionary = fixture.get_save_data()
	fixture.skip_tutorial()
	check(not fixture.needs_tutorial() and fixture.tutorial_skipped and not fixture.tutorial_complete, "Skip dismisses onboarding without claiming completion")
	var skipped: Dictionary = fixture.get_save_data()
	var expected: Dictionary = original.duplicate(true)
	expected["tutorial_skipped"] = true
	check(skipped == expected, "Skip changes only onboarding preference, not mastery, upgrades, lessons or rewards")
	fixture.apply_save_data(JSON.parse_string(JSON.stringify(skipped)) as Dictionary)
	check(not fixture.needs_tutorial() and fixture.tutorial_skipped, "Skip survives save reload")
	fixture.mark_tutorial_complete()
	check(fixture.tutorial_complete and not fixture.tutorial_skipped, "Later completion replaces skipped status")
	fixture.apply_save_data({})
	check(fixture.needs_tutorial() and not fixture.tutorial_skipped, "Another or legacy account does not inherit the skipped flag")
	fixture.free()
	var snapshot: Dictionary = player.get_save_data()
	player.tutorial_complete = true # All route tests avoid real persistence writes.
	player.tutorial_skipped = false
	var replay_before: Dictionary = player.get_save_data()
	var shell: Control = load("res://src/main.tscn").instantiate() as Control
	var navigation_script: GDScript = GDScript.new()
	navigation_script.source_code = "extends \"res://src/main.gd\"\nfunc _ready() -> void:\n\t_setup_navigation()\n"
	check(navigation_script.reload() == OK, "Navigation-only shell fixture compiles")
	shell.set_script(navigation_script)
	root.add_child(shell)
	player.tutorial_complete = false
	await router.replace_all(&"dashboard")
	await settle()
	check(shell._tutorial_bar.visible, "New accounts can skip before starting any practice")
	check(shell._tutorial_bar.size.y < root.get_visible_rect().size.y * 0.25, "First-visit controls stay a compact header, not a full-screen panel")
	await capture("first_visit")
	router.request_back()
	check(shell._pending_action == &"dashboard", "Back also leaves the initial tutorial introduction")
	shell._cancel_confirmation()
	player.tutorial_complete = true
	await router.replace_all(&"settings")
	await settle()
	var settings_screen: Control = router._stack.back()
	check(settings_screen.find_child("ReplayTutorialButton", true, false) != null and settings_screen.find_child("ExitGameButton", true, false) != null, "Settings exposes persistent replay and exit actions")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		var footer: Control = settings_screen.get_node("SafeAreaContainer/ScreenLayout/AccountFooter")
		check(root.get_visible_rect().encloses(footer.get_global_rect()), "Account actions fit landscape without scrolling")
		await capture("settings_%dx%d" % [dimensions.x, dimensions.y])
	await router.start_defense_training(true)
	await settle()
	check(router.is_tutorial and router.tutorial_replay and is_instance_valid(router._gameplay), "Completed account can replay disposable training")
	check(shell._tutorial_bar.visible and not router._gameplay.coach.visible, "Navigation remains visible while the coach is hidden")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(shell._tutorial_bar.get_global_rect()), "Tutorial controls fit landscape")
		check(router._gameplay.get_global_rect().position.y >= shell._tutorial_bar.get_global_rect().end.y, "Controls do not cover the tutorial workspace")
		await capture("navigation_%dx%d" % [dimensions.x, dimensions.y])
	router.request_back()
	await settle()
	check(shell._quit_dialog.visible and paused, "Back opens a cancellable tutorial exit and freezes practice")
	check(not router._gameplay.can_process(), "Practice cannot advance behind its confirmation")
	check(root.get_visible_rect().encloses(shell._confirm_card.get_global_rect()), "Confirmation fits phone landscape with both actions visible")
	await capture("leave_confirmation")
	router.request_back()
	check(not paused and router.is_tutorial, "Cancel resumes the same tutorial")
	check(router._gameplay.can_process(), "Cancel restores gameplay processing")
	router.request_exit_game()
	check(shell._pending_action == &"exit" and shell._quit_dialog.visible, "Explicit exit uses confirmation instead of signing out")
	shell._quit_dialog.hide()
	shell._cancel_confirmation()
	await router.open_tutorial_upgrades()
	await settle()
	check(router.is_tutorial and router.tutorial_replay and router.tutorial_beat == &"upgrade", "Replay remains isolated across gameplay teardown and upgrade handoff")
	await router.open_tutorial_lesson()
	await settle()
	var lesson: Control = router._stack.back()
	lesson._phase = lesson.Phase.COMPLETE
	lesson._quiz_passed = true
	lesson._simulation_passed = true
	lesson._busy = false
	lesson._finish_lesson()
	check(player.get_save_data() == replay_before, "Replayed lesson cannot grant intel bonus or learning credit")
	await router.open_tutorial_dashboard()
	await settle()
	check(router._stack.back()._tutorial_gate.visible, "Completed accounts see replay completion coach")
	shell._show_confirmation(&"skip")
	shell._quit_dialog.hide()
	await shell._on_quit_confirmed()
	await settle()
	check(not router.is_tutorial and not router.tutorial_replay and router.tutorial_beat == &"", "Leave clears all tutorial session flags")
	check(router.current_screen_id() == &"dashboard" and not shell._tutorial_bar.visible and not paused and is_equal_approx(Engine.time_scale, 1.0), "Leaving restores dashboard, input and normal time")
	check(player.get_save_data() == replay_before, "Replay and leaving preserve account state")
	await _check_opening()
	for screen: BaseScreen in router._stack:
		screen.on_exit()
	router._stack.clear()
	router.register_host(null)
	shell.queue_free()
	await settle()
	player.apply_save_data(snapshot)


func _check_opening() -> void:
	var assets: Node = root.get_node("AssetManager")
	var prior_art: Dictionary = assets._textures.duplicate()
	if assets._syncing:
		await assets.sync_finished
	for entry: Dictionary in assets._ui_catalog():
		var asset_id: String = str(entry.asset_id)
		if not asset_id.begins_with("opening_"):
			continue
		if "--download-opening-art" in OS.get_cmdline_user_args():
			assets._ensure_assets_dir()
			check(await assets._sync_entry(entry), "Cloudinary opening asset downloads: " + asset_id)
			check(assets.get_texture(asset_id) != null, "Downloaded opening texture decodes: " + asset_id)
		elif assets.get_texture(asset_id) == null:
			# Deterministic offline fixture; no bundled art or network dependency.
			var fixture_image: Image = Image.create(16, 9, false, Image.FORMAT_RGB8)
			fixture_image.fill(Color("102040"))
			assets._textures[asset_id] = ImageTexture.create_from_image(fixture_image)
	# Headless windows otherwise default to a square; this game is landscape.
	root.size = Vector2i(1280, 720)
	await settle()
	var memory_script: GDScript = GDScript.new()
	memory_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\tpass\n"
	check(memory_script.reload() == OK, "Opening account fixture compiles")
	var fixture: Node = memory_script.new()
	fixture.reset_to_defaults()
	var fresh: Dictionary = fixture.get_save_data()
	fixture.save_onboarding({"intro_status": "completed", "tutorial_status": "in_progress", "step": "message"})
	check(fixture.needs_opening(), "In-progress first login resumes onboarding")
	var expected: Dictionary = fresh.duplicate(true)
	expected["onboarding_state"] = fixture.onboarding_state.duplicate(true)
	check(fixture.get_save_data() == expected, "Intro progress changes only presentation snapshot")
	fixture.save_onboarding({"intro_status": "completed", "tutorial_status": "completed"}, "completed")
	expected["onboarding_state"] = fixture.onboarding_state.duplicate(true)
	expected["tutorial_complete"] = true
	check(fixture.get_save_data() == expected and not fixture.needs_opening(), "Completion grants no mastery, records, rewards or lesson unlocks")
	fixture.apply_save_data(fresh)
	fixture.save_onboarding({"intro_status": "skipped", "tutorial_status": "skipped"}, "skipped")
	check(fixture.tutorial_skipped and not fixture.tutorial_complete and not fixture.needs_opening(), "Skip is distinct from completion")
	var disk: Dictionary = JSON.parse_string(JSON.stringify(fixture.get_save_data())) as Dictionary
	fixture.apply_save_data(disk)
	check(not fixture.needs_opening(), "Skip survives persisted JSON snapshot")
	fixture.free()
	var before: Dictionary = player.get_save_data()
	player.tutorial_complete = false
	player.tutorial_skipped = false
	player.onboarding_state = {}
	await router.replace_all(&"login")
	# Replay flag is a fixture-only argument to avoid writing an actual profile.
	await router.replace_all(&"dashboard", {"replay": true})
	check(router.current_screen_id() == &"opening", "Login-to-home navigation automatically selects opening for a fresh account")
	player.apply_save_data(before)
	# Save loading normalizes legacy defaults; compare replay with that loaded baseline.
	before = player.get_save_data()
	await router.replay_intro()
	await settle()
	var opening: Control = router._stack.back()
	check(opening.screen_id == &"opening" and opening.part == "intro", "Settings route opens intro replay")
	check(opening.replay and opening.intro_index == 0, "Replay starts at the first beat without persistence")
	var dialogue_settings: Node = root.get_node("SettingsService")
	var original_reduced: bool = dialogue_settings.reduced_motion
	dialogue_settings.reduced_motion = false
	opening._render()
	check(not opening._dialogue_ready and not opening._advance_button.visible, "Advance prompt waits for the text reveal")
	check(not opening._footer.visible, "Narrative scenes have no wide Continue footer")
	opening._advance_pressed()
	check(opening.intro_index == 0, "Advance cannot skip unfinished dialogue")
	await create_timer(0.15).timeout
	check(opening._waking and opening._wake_phase == "alarm" and not opening._dialogue.visible, "Alarm sounds before the eye-opening reveal")
	opening._open_menu()
	var wake_elapsed: float = opening._motion.get_total_elapsed_time()
	await create_timer(0.15).timeout
	check(is_equal_approx(wake_elapsed, opening._motion.get_total_elapsed_time()), "Menu pauses the alarm-to-eye-opening timeline")
	opening._close_menu()
	await create_timer(0.85).timeout
	check(opening._wake_phase == "opening" and opening._dialogue.visible, "Thump and narration start as the eyes open")
	opening._open_menu()
	opening._close_menu()
	check(opening._typing.is_running(), "Resuming mid-eye-opening also resumes narration")
	await create_timer(1.6).timeout
	check(not opening._waking, "Eye-opening finishes before advancing is enabled")
	var reveal_tap: InputEventMouseButton = InputEventMouseButton.new()
	reveal_tap.button_index = MOUSE_BUTTON_LEFT
	reveal_tap.pressed = true
	await settle()
	reveal_tap.position = opening._dialogue_copy.global_position + Vector2(20, 12)
	root.push_input(reveal_tap, true)
	var reveal_release: InputEventMouseButton = reveal_tap.duplicate() as InputEventMouseButton
	reveal_release.pressed = false
	root.push_input(reveal_release, true)
	await settle()
	check(opening._dialogue_ready and opening._advance_button.visible and opening.intro_index == 0, "Dialogue tap reveals text without advancing")
	opening._advance_pressed()
	opening._finish_reveal()
	opening._advance_pressed()
	check(opening.intro_index == 1, "Rapid duplicate advances do not skip a beat")
	opening._back()
	check(not opening._dialogue_ready, "Back restarts the current line cleanly")
	var legacy_opening: Dictionary = {"version": 1, "intro_index": 1, "history": [{"intro_index": 0}, {"intro_index": 4}]}
	opening._migrate_art_sequence(legacy_opening)
	check(legacy_opening.intro_index == 2 and legacy_opening.history[0].intro_index == 0 and legacy_opening.history[1].intro_index == 6, "New illustrated shots preserve legacy resume and Back destinations")
	opening._migrate_art_sequence(legacy_opening)
	check(legacy_opening.intro_index == 2, "Opening cursor migration runs only once")
	var version_two: Dictionary = {"version": 2, "intro_index": 4, "history": [{"intro_index": 3}, {"intro_index": 10}]}
	opening._migrate_art_sequence(version_two)
	check(version_two.intro_index == 5 and version_two.history[0].intro_index == 3 and version_two.history[1].intro_index == 8, "Version 2 resumes map to the new claim and closing scenes")
	var version_three: Dictionary = {"version": 3, "intro_index": 9, "history": [{"intro_index": 6}, {"intro_index": 10}, {"intro_index": 11}]}
	opening._migrate_art_sequence(version_three)
	check(version_three.version == 4 and version_three.intro_index == 7 and version_three.history[0].intro_index == 6 and version_three.history[1].intro_index == 7 and version_three.history[2].intro_index == 8, "Separate victim previews migrate to the montage, preserving meeting and closing")
	opening._back()
	check(opening._menu.visible, "Back on first scene offers menu, never a dead end")
	var paused_characters: int = opening._typed_labels[0].visible_characters
	await create_timer(0.15).timeout
	check(opening._typed_labels[0].visible_characters == paused_characters, "Menu pauses the text reveal")
	opening._dialogue_input(reveal_tap)
	check(not opening._dialogue_ready, "Menu blocks dialogue reveal input")
	check(opening._header.find_child("SkipButton", true, false).disabled, "Menu blocks underlying keyboard actions")
	for action: String in ["ResumeButton", "SkipOpeningButton", "ReplayIntroButton", "ExitButton"]:
		check(opening._menu.find_child(action, true, false) != null, "Opening menu exposes " + action)
	opening._close_menu()
	check(not opening._header.find_child("SkipButton", true, false).disabled, "Resume restores opening controls")
	await create_timer(4.0).timeout
	check(opening._dialogue_ready and opening._advance_button.visible, "Text completion naturally reveals the circular prompt")
	for index: int in opening._intro().size():
		check(opening.intro_index == index, "Intro beats remain ordered: expected %d, actual %d" % [index, opening.intro_index])
		check(opening._header.find_child("SkipButton", true, false).visible, "Intro skip stays visible")
		await settle()
		opening._finish_reveal()
		await settle()
		if index >= 5:
			check(opening._cinematic_active and not opening._dialogue.visible, "Cinematic art is not obscured by a dialogue panel")
			check(opening._cinematic_busy and not opening._cinematic_next.visible, "Cinematic advance waits for the visual reveal")
			opening.advance()
			check(opening.intro_index == index, "Direct advance cannot cut off the ending effect")
			opening._open_menu()
			var elapsed: float = opening._cinematic_tween.get_total_elapsed_time()
			await create_timer(0.2).timeout
			check(is_equal_approx(elapsed, opening._cinematic_tween.get_total_elapsed_time()), "Menu pauses cinematic timeline")
			check(not root.get_node("AudioManager").dialogue_player.playing, "Menu stops source-owned laugh")
			opening._close_menu()
			if index == 5:
				await create_timer(0.35).timeout
				check(opening._red_wash.modulate.a > 0.5, "Takeover covers the scene in red before the phone reveal")
				await capture_opening(opening, "red_takeover")
			elif index == 8:
				await create_timer(1.0).timeout
				check(opening._closing_caption.text == "And this is how it began…" and opening._closing_caption.modulate.a > 0.9, "Closing caption overlays the montage")
				await capture_opening(opening, "closing_caption")
			await create_timer(4.2).timeout
			check(not opening._cinematic_busy and opening._cinematic_next.visible, "Cinematic finishes with an accessible advance prompt")
			if index == 5:
				check(opening._art_id == "opening_john_got_you_v1" and opening._scene_art.texture == assets.get_texture(opening._art_id), "Red takeover reveals the cached Cloudinary Got You phone")
				_check_opening_laugh(opening)
			if index == 8:
				check(is_equal_approx(opening._black_fade.modulate.a, 1.0) and is_zero_approx(opening._closing_caption.modulate.a), "Final image and caption fade completely to black")
			if index == 6:
				check(opening._laugh_captions.size() == 5, "Meeting uses five scattered laughing captions")
				for laugh: Label in opening._laugh_captions:
					check(laugh.text == "HAHAHAHA", "Meeting captions express laughter rather than label it")
					check(laugh.visible and laugh.modulate.a == 1.0 and root.get_visible_rect().encloses(laugh.get_global_rect()), "Laughing caption is visible and fits landscape")
			await capture_opening(opening, "cinematic_%d" % index)
			root.size = Vector2i(844, 390)
			await settle()
			check(root.get_visible_rect().encloses(opening._cinematic_next.get_global_rect()), "Cinematic prompt fits small landscape")
			await capture_opening(opening, "cinematic_%d_844x390" % index)
			root.size = Vector2i(1280, 720)
			await settle()
		check(opening._scene_art.get_global_rect().encloses(opening._dialogue.get_global_rect()), "Dialogue overlays the full-screen artwork")
		if not opening._scene_art.get_global_rect().encloses(opening._dialogue.get_global_rect()):
			print("[OVERLAY LAYOUT] beat=", index, " art=", opening._scene_art.get_global_rect(), " dialogue=", opening._dialogue.get_global_rect())
		check(opening._scene_art.size.is_equal_approx(opening.size), "Artwork is independent of dialogue height")
		check(opening._dialogue.get_theme_stylebox("panel").bg_color.a < 0.8, "Dialogue surface remains translucent")
		if index in [0, 1]:
			check(opening._scene_art.visible and opening._scene_art.texture != null, "Wake and search use cached Cloudinary artwork")
			check(opening._hero.find_child("PracticePhone", true, false) == null, "Room scenes do not reveal the prize prematurely")
		if index == 2:
			var unlocking: Control = opening._phone_view
			check(unlocking._app == "lock" and unlocking._alarm_pending, "Phone starts at the morning alarm")
			await capture_opening(opening, "phone_alarm")
			var alarm_window: Vector2i = root.size
			root.size = Vector2i(844, 390)
			await settle()
			check(absf(unlocking._shell.size.x / unlocking._shell.size.y - 0.52) < 0.03, "Alarm retains portrait phone proportions in landscape")
			check(root.get_visible_rect().encloses(unlocking._dismiss.get_global_rect()), "Alarm dismissal stays reachable in small landscape")
			await capture_opening(opening, "phone_alarm_844x390")
			root.size = alarm_window
			await settle()
			unlocking._dismiss_alarm()
			await settle()
			opening._open_menu()
			var pin_before: String = unlocking._pin_dots.text
			await create_timer(0.5).timeout
			check(unlocking._pin_dots.text == pin_before and not unlocking._unlocked, "Menu pauses dummy PIN animation")
			opening._close_menu()
			await capture_opening(opening, "phone_lock")
		if index in [0, 1, 2, 3, 4, 5, 6]:
			await create_timer(1.6).timeout
			await capture_opening(opening, "intro_%d" % index)
		if index in [0, 1]:
			var original_size: Vector2i = root.size
			root.size = Vector2i(844, 390)
			await settle()
			check(root.get_visible_rect().encloses(opening._dialogue.get_global_rect()), "Art-scene dialogue fits small landscape")
			check(root.get_visible_rect().encloses(opening._advance_button.get_global_rect()), "Circular Continue remains reachable in small landscape")
			check(opening._dialogue.get_global_rect().encloses(opening._advance_button.get_global_rect()), "Circular Continue stays inside the dialogue")
			await capture_opening(opening, "intro_%d_844x390" % index)
			root.size = original_size
			await settle()
		if index in [2, 3]:
			var phone: Control = opening._phone_view
			check(is_instance_valid(phone) and phone._embedded, "Opening reuses the gameplay phone")
			check(not phone._guide_panel.visible and not phone._dim.visible, "Opening phone omits redundant checklist and dim layer")
			check(not opening._advance_button.visible, "Phone actions replace Continue")
			opening.advance()
			check(opening.intro_index == index, "Continue cannot bypass the phone action")
			var old_size: Vector2i = root.size
			root.size = Vector2i(844, 390)
			await settle()
			check(phone.get_global_rect().encloses(phone._shell.get_global_rect()), "Whole phone fits its fixed viewport in small landscape")
			check(opening._dialogue.get_global_rect().end.x <= opening._phone_host.get_global_rect().position.x, "Bottom-left dialogue does not cover phone controls")
			await capture_opening(opening, "phone_%d_844x390" % index)
			if index == 3:
				var small_scroll: ScrollContainer = phone._content.get_parent() as ScrollContainer
				var subject: Label = phone._content.get_child(0) as Label
				var email_body: Label = phone.find_child("EmailBody", true, false) as Label
				check(email_body.global_position.y + 20 < small_scroll.get_global_rect().end.y, "Small landscape shows the start of the email body without scrolling")
				check(subject.get_theme_font_size("font_size") * root.get_final_transform().get_scale().y >= 19.9, "Phone text remains at least 20 physical pixels")
				var wheel: InputEventMouseButton = InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				wheel.position = small_scroll.get_global_rect().get_center()
				root.push_input(wheel, true)
				var wheel_release: InputEventMouseButton = wheel.duplicate() as InputEventMouseButton
				wheel_release.pressed = false
				root.push_input(wheel_release, true)
				await settle()
				check(small_scroll.scroll_vertical > 0, "Pointer wheel scrolls the email content")
			root.size = old_size
			await settle()
			if index == 2:
				check(phone._unlocked and phone._app == "home", "Dummy PIN animation ends at the unread email notification")
				check(phone.find_child("MailBanner", true, false) != null and phone.find_child("UnreadBadge", true, false) != null, "Unread mail has a notification and icon badge")
				opening._open_menu()
				phone._open_story_email()
				check(not phone._read, "Menu blocks phone interaction")
				opening._close_menu()
				phone._open_story_email()
			else:
				var email_scroll: ScrollContainer = phone._content.get_parent() as ScrollContainer
				check(email_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Email scrolls internally without a visible scrollbar")
				var frame_before: Rect2 = phone._shell.get_global_rect()
				email_scroll.scroll_vertical = 1000
				await settle()
				check(phone._shell.get_global_rect() == frame_before, "Scrolling email does not move the device")
				await capture_opening(opening, "claim_button")
				check(phone._nav.visible and phone._close.text == "× CLOSE", "Zoomed app has its own Close button")
				var app_width: float = phone._shell.size.x
				var close_tap: InputEventMouseButton = InputEventMouseButton.new()
				close_tap.button_index = MOUSE_BUTTON_LEFT
				close_tap.pressed = true
				close_tap.position = phone._close.get_global_rect().get_center()
				close_tap.global_position = close_tap.position
				close_tap.button_mask = MOUSE_BUTTON_MASK_LEFT
				var close_motion: InputEventMouseMotion = InputEventMouseMotion.new()
				close_motion.position = close_tap.position
				close_motion.global_position = close_tap.position
				root.push_input(close_motion, true)
				await settle()
				root.push_input(close_tap, true)
				var close_release: InputEventMouseButton = close_tap.duplicate() as InputEventMouseButton
				close_release.pressed = false
				close_release.button_mask = 0
				root.push_input(close_release, true)
				await settle()
				await create_timer(0.3).timeout
				check(phone._app == "home" and not phone._nav.visible and phone._shell.size.x < app_width, "Close restores portrait home: app=%s width=%s previous=%s" % [phone._app, phone._shell.size.x, app_width])
				check(phone.find_child("MailBanner", true, false) == null and phone.find_child("UnreadBadge", true, false) == null, "Reading clears the banner and badge when returning home")
				phone._open_story_email()
				await settle()
				check(opening.intro_index == index and phone._reading, "Reopening Mail preserves the current story beat")
				phone._claim()
				phone._claim()
			await settle()
			check(opening.intro_index == index + 1, "Phone action advances exactly one beat")
		elif index >= 5:
			var cinematic_tap: InputEventMouseButton = InputEventMouseButton.new()
			cinematic_tap.button_index = MOUSE_BUTTON_LEFT
			cinematic_tap.button_mask = MOUSE_BUTTON_MASK_LEFT
			cinematic_tap.pressed = true
			cinematic_tap.position = opening._cinematic_next.get_global_rect().get_center()
			cinematic_tap.global_position = cinematic_tap.position
			var cinematic_motion: InputEventMouseMotion = InputEventMouseMotion.new()
			cinematic_motion.position = cinematic_tap.position
			cinematic_motion.global_position = cinematic_tap.position
			root.push_input(cinematic_motion, true)
			await settle()
			root.push_input(cinematic_tap, true)
			cinematic_tap.pressed = false
			cinematic_tap.button_mask = 0
			root.push_input(cinematic_tap, true)
			await settle()
			check(opening.intro_index == index + 1 or opening.part == "tutorial", "Cinematic advance receives real pointer input above the empty workspace")
		else:
			opening.advance()
	check(opening.part == "tutorial" and opening.step == "wake", "Full intro hands control to tutorial")
	opening._back()
	check(opening.part == "intro" and opening.intro_index == opening._intro().size() - 1, "Tutorial Back returns to previous intro scene")
	await create_timer(4.2).timeout
	opening.advance()
	opening.go("inbox")
	opening.go("message")
	opening.go("respond")
	opening.respond("link")
	check(opening.step == "failure", "Uninspected link shows explanatory retry, not game over")
	await settle()
	await capture_opening(opening, "failure")
	opening.retry()
	check(opening.step == "message", "Retry returns to the same practice message")
	opening.go("respond")
	opening.respond("report")
	check(opening.step == "review", "Safe response without evidence requests practice inspection")
	opening.go("inspect")
	opening.save_clue("sender")
	check(opening.clues.is_empty(), "Cannot save an uninspected clue")
	for id: String in ["sender", "link", "pressure"]:
		opening.go("inspect")
		opening.inspect_clue(id)
		opening.save_clue(id)
		opening.save_clue(id)
	check(opening.clues.size() == 3, "Binder holds three distinct inspected clues without duplicates")
	opening.go("binder")
	await settle()
	await capture_opening(opening, "binder")
	opening.go("respond")
	opening.respond("link")
	check(opening.step == "failure", "Inspecting does not make the unsafe link safe")
	opening.retry()
	opening.go("respond")
	opening.respond("report")
	check(opening.step == "success", "Evidence plus safe response succeeds")
	for response_id: String in ["ignore", "delete"]:
		opening.go("respond")
		opening.respond(response_id)
		check(opening.step == "success", "Evidence plus " + response_id + " is a safe response")
	opening.finish()
	check(opening.step == "summary" and opening.state.pending_outcome == "completed", "Explicit tutorial completion then controls summary")
	check(player.get_save_data() == before, "Replay changes no account, mastery, reward, lesson or assessment fields")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(opening._header.get_global_rect()), "Opening header fits landscape")
		check(root.get_visible_rect().encloses(opening._footer.get_global_rect()), "Opening summary action fits landscape")
		if not root.get_visible_rect().encloses(opening._footer.get_global_rect()):
			print("[OPENING LAYOUT] viewport=", root.get_visible_rect(), " footer=", opening._footer.get_global_rect(), " minimum=", opening._layout.get_combined_minimum_size())
		await capture_opening(opening, "summary_%dx%d" % [dimensions.x, dimensions.y])
		opening._open_menu()
		await settle()
		check(root.get_visible_rect().encloses(opening._menu_card.get_global_rect()), "Opening menu fits landscape")
		await capture_opening(opening, "menu_%dx%d" % [dimensions.x, dimensions.y])
		opening._close_menu()
	await opening._hub()
	while router.is_busy():
		await process_frame
	await settle()
	check(router.current_screen_id() == &"dashboard", "Replay returns to existing hub")
	await router.start_tutorial(true)
	await settle()
	opening = router._stack.back()
	check(opening.part == "tutorial" and opening.step == "wake", "Replay Tutorial bypasses intro")
	(opening.data["message"] as Dictionary)["channel"] = "text"
	opening.go("inbox")
	var has_text_label: bool = false
	for label: Node in opening._hero.find_children("*", "Label", true, false):
		if (label as Label).text == str(opening.data.message.text_label):
			has_text_label = true
	check(has_text_label, "Notification channel switches from data only")
	opening.go("wake")
	opening.skip()
	check(opening.step == "summary", "Tutorial skip shows controls summary")
	opening._back()
	check(opening.step == "wake", "Summary Back returns to skipped prompt")
	opening._open_menu()
	opening._replay_intro()
	check(opening.part == "intro" and opening.intro_index == 0, "Menu replays intro")
	opening.skip()
	check(opening.part == "tutorial" and opening.step == "wake", "Intro skip goes to tutorial")
	var settings: Node = root.get_node("SettingsService")
	var reduced: bool = settings.reduced_motion
	settings.reduced_motion = true
	opening.go("respond")
	opening.respond("link")
	check(opening._motion == null, "Reduced motion suppresses shake and strong visual effects")
	opening.go("wake")
	check(opening._eyelids == null, "Reduced motion suppresses eyelid effect")
	check(opening._dialogue_ready and opening._typing == null and opening._prompt_tween == null, "Reduced motion shows complete text and a static advance prompt")
	opening._open_menu()
	opening._replay_intro()
	await create_timer(1.0).timeout
	opening.advance()
	opening.advance()
	opening._phone_view._dismiss_alarm()
	await create_timer(0.5).timeout
	check(opening._phone_view._unlocked and opening._phone_view._pin_tween == null, "Reduced motion skips the PIN keystroke animation")
	opening._back()
	check(opening.intro_index == 1 and opening._phone_view == null, "Back removes the phone and cancels its animation")
	for cinematic_index: int in [5, 6, 7, 8]:
		opening.intro_index = cinematic_index
		opening._render()
		check(not opening._cinematic_busy and opening._cinematic_tween == null and opening._scene_art.position == Vector2.ZERO, "Reduced motion skips cinematic shake and timed effects")
		if cinematic_index == 8:
			check(opening._closing_caption.modulate.a == 1.0, "Reduced motion keeps the closing words readable")
	settings.reduced_motion = false
	opening.intro_index = 5
	opening._render()
	await create_timer(1.1).timeout
	opening.skip()
	check(opening._cinematic_tween == null and not opening._cinematic.visible and not root.get_node("AudioManager").dialogue_player.playing, "Skip cancels cinematic layers, callbacks and laugh")
	await create_timer(2.0).timeout
	check(opening.part == "tutorial" and opening.step == "wake", "Cancelled cinematic cannot advance a later screen")
	settings.reduced_motion = reduced
	opening._open_menu()
	opening._skip_opening()
	check(opening.step == "summary", "Skip Opening bypasses both parts with summary")
	check(player.get_save_data() == before, "Every replay path remains isolated")
	# Round-trip a presentation snapshot in memory, including a JSON transport.
	var sample: Dictionary = before.duplicate(true)
	sample["tutorial_complete"] = false
	sample["tutorial_skipped"] = false
	sample["onboarding_state"] = {"part": "tutorial", "step": "binder", "intro_status": "completed", "tutorial_status": "in_progress", "clues": ["sender", "link", "pressure"]}
	player.apply_save_data(JSON.parse_string(JSON.stringify(sample)) as Dictionary)
	check(router.student_home_screen() == &"opening", "Interrupted onboarding remains eligible after reload")
	check(player.onboarding_state.clues.size() == 3 and player.onboarding_state.step == "binder", "Clues and resume step survive snapshot serialization")
	player.tutorial_skipped = true
	check(router.student_home_screen() == &"dashboard", "Skipped account goes to hub")
	player.tutorial_skipped = false
	player.tutorial_complete = true
	check(router.student_home_screen() == &"dashboard", "Completed legacy account goes to hub")
	player.apply_save_data({})
	check(player.onboarding_state.is_empty() and router.student_home_screen() == &"opening", "New account does not inherit opening state")
	player.apply_save_data(before)
	dialogue_settings.reduced_motion = original_reduced
	opening._set_art("opening_missing_fixture")
	check(opening._scene_art.texture == null and opening._art_fallback.visible, "Offline missing art clears stale imagery and supplies a readable fallback")
	opening._set_art("opening_john_room_wake_v1")
	assets.sync_finished.emit(true)
	check(not opening._art_fallback.visible and opening._art_id == "opening_john_room_wake_v1", "Late asset sync refreshes only the current scene")
	assets._textures = prior_art


func _check_opening_laugh(opening: Control) -> void:
	var audio: Node = root.get_node("AudioManager")
	var settings: Node = root.get_node("SettingsService")
	var previous: Array = [settings.sound_enabled, settings.sfx_volume, settings.master_volume, settings.dialogue_blips_enabled, settings.text_speed, audio._focus_lost]
	settings.sound_enabled = true
	settings.sfx_volume = 50
	settings.master_volume = 50
	settings.dialogue_blips_enabled = false
	settings.text_speed = "instant"
	audio._focus_lost = false
	audio.play_opening_laugh(opening)
	check(audio.dialogue_player.playing and audio._dialogue_owner.get_ref() == opening, "Laugh is owned by opening and independent of text speed / blips")
	var laugh: AudioStreamWAV = audio.dialogue_player.stream as AudioStreamWAV
	check(laugh != null and absf(laugh.get_length() - 1.65) < 1.0 / 22050.0 and laugh.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Robotic laugh is a bounded original non-looping effect")
	opening._open_menu()
	check(not audio.dialogue_player.playing, "Menu immediately stops robotic laughter")
	opening._close_menu()
	check(not audio.dialogue_player.playing, "Resume does not replay laughter")
	settings.sound_enabled = false
	audio.play_opening_laugh(opening)
	check(not audio.dialogue_player.playing, "Muted sound blocks the robotic laugh")
	settings.sound_enabled = previous[0]
	settings.sfx_volume = previous[1]
	settings.master_volume = previous[2]
	settings.dialogue_blips_enabled = previous[3]
	settings.text_speed = previous[4]
	audio._focus_lost = previous[5]


func capture_opening(_opening: Control, label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/opening_" + label + ".png")


func _run_opening_only() -> void:
	var snapshot: Dictionary = player.get_save_data()
	player.tutorial_complete = true
	var shell: Control = load("res://src/main.tscn").instantiate() as Control
	var navigation_script: GDScript = GDScript.new()
	navigation_script.source_code = "extends \"res://src/main.gd\"\nfunc _ready() -> void:\n\t_setup_navigation()\n"
	check(navigation_script.reload() == OK, "Opening-only navigation fixture compiles")
	shell.set_script(navigation_script)
	root.add_child(shell)
	await _check_opening()
	for screen: BaseScreen in router._stack:
		screen.on_exit()
	router._stack.clear()
	router.register_host(null)
	shell.queue_free()
	await settle()
	player.apply_save_data(snapshot)
	print("[OPENING] failures=%d" % failures)
	await _stop_test_audio()
	quit(1 if failures else 0)


func _stop_test_audio() -> void:
	var audio: Node = root.get_node("AudioManager")
	audio._kill_bgm_tween()
	audio._stop_music()
	audio._stop_effects()
	await create_timer(0.15).timeout
