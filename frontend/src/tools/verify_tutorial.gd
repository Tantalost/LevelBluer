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
	print("[TUTORIAL] failures=%d" % failures)
	quit(1 if failures else 0)
