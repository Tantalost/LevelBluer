extends SceneTree
## In-memory fixtures only: no AuthService persistence, gameplay completion or API calls.
var failures := 0
var Data: GDScript
var auth: Node
var player: Node

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 8:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/progress_" + name + ".png")

func fresh() -> void:
	auth._mastery = {}
	auth._completed_module_ids = []
	auth._bkt_queue.clear()
	auth._signed_in = false
	auth._participant_code = "progress-test"
	auth._points = 0
	player.mastery_matrix = {"phishing": 0.1}
	player.cleared_stages = {}
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.locked_stages = {}
	player.max_stage_cleared_by_module = {}
	player.credits = 123

func fingerprint() -> String:
	return JSON.stringify([auth._mastery, auth._completed_module_ids, auth._bkt_queue, auth._points,
		player.mastery_matrix, player.cleared_stages, player.lesson_progress, player.completed_lessons,
		player.locked_stages, player.credits, player.unlocked_towers])

func _run() -> void:
	auth = root.get_node("AuthService")
	player = root.get_node("PlayerManager")
	Data = load("res://src/ui/screens/progress/progress_data.gd")
	fresh()
	auth._mastery = {
		"Phishing": 0.42,
		"Smishing": 0.68,
		"Vishing": 0.55,
		"Pretexting": 0.73,
		"Baiting": 0.31,
	}
	player.mastery_matrix = {"phishing": 0.1}
	player.seed_from_official_mastery()
	check(is_equal_approx(float(player.mastery_matrix.get("phishing", 0.0)), 0.42), "Seed phishing snapshot")
	check(is_equal_approx(float(player.mastery_matrix.get("smishing", 0.0)), 0.68), "Seed smishing snapshot")
	check(is_equal_approx(float(player.mastery_matrix.get("vishing", 0.0)), 0.55), "Seed vishing snapshot")
	check(is_equal_approx(float(player.mastery_matrix.get("pretexting", 0.0)), 0.73), "Seed pretexting snapshot")
	check(is_equal_approx(float(player.mastery_matrix.get("baiting", 0.0)), 0.31), "Seed baiting snapshot")
	player._normalize_mastery_keys()
	check(is_equal_approx(float(player.mastery_matrix.get("smishing", 0.0)), 0.68), "Normalize keeps non-phishing skills")
	fresh()
	var state: Dictionary = Data.snapshot()
	check(state.stage_done == 0 and state.stage_total == 10, "Fresh account has 0/10 clears, not mock counter")
	check(state.lesson_done == 0 and state.lesson_total == 30, "Lesson count is 0/30")
	check(state.assessed == 0, "Default gameplay prior is not assessed mastery")
	check(state.modules[0].status == "Pre-test required" and state.modules[1].status == "Locked", "Fresh lesson access states")
	check(Data.mastery_status(0.3999, true) == "Needs practice", "Below 40%")
	check(Data.mastery_status(0.4, true) == "Developing", "40% boundary")
	check(Data.mastery_status(0.6999, true) == "Developing", "Below 70%")
	check(Data.mastery_status(0.7, true) == "Proficient", "70% boundary")
	check(Data.mastery_status(0, false) == "Not assessed", "Missing mastery label")
	var before := fingerprint()
	var screen: Control = load("res://src/ui/screens/progress/progress_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	await settle()
	check(screen._tab == "Overview", "Dashboard route opens Overview")
	check(screen.get_node("CRTOverlay").visible, "CRT always enabled")
	await capture("fresh")
	screen._select_tab("Mastery")
	await settle()
	check(screen._radar.size.x >= 360, "Radar minimum readable width")
	check(screen._radar.rows.all(func(row: Dictionary) -> bool: return not row.assessed), "Missing axes remain unassessed")
	await capture("unassessed")
	check(fingerprint() == before, "Opening screen does not mutate account or gameplay state")
	auth._mastery = {"phishing": 0.25, "Smishing": 0.4, "Vishing": 0.70, "Pretexting": 0.85, "Baiting": 0.95}
	auth._points = 1230
	auth._completed_module_ids = ["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"]
	player.cleared_stages = {"mod_01:1": true, "mod_01:3": true}
	player.lesson_progress = {"mod_01": 6, "mod_02": 3}
	player.completed_lessons.assign(["mod_01"])
	state = Data.snapshot()
	check(state.stage_done == 2, "Noncontiguous clears counted exactly")
	check(state.lesson_done == 9 and state.modules[2].status == "Locked", "Partial lessons and next module lock")
	check(state.assessed == 5 and is_equal_approx(float(state.average), 0.63), "Average uses assessed values")
	check(state.rank == "OPERATIVE I" and state.rank_value == 230, "Rank points and rank span")
	before = fingerprint()
	screen._select_tab("Overview")
	await settle()
	await capture("overview")
	screen._select_tab("Mastery")
	await settle()
	for i in 5:
		screen._radar._select(i)
		check(screen._topic == i, "Radar selection: %d" % i)
		screen._topic_buttons[(i+1)%5].pressed.emit()
		check(screen._topic == (i+1)%5, "Topic row selection")
	screen._radar._select_at(screen._radar._vertices[2])
	check(screen._topic == 2, "Tap vertex selects topic")
	await capture("mastery")
	screen._open_journey("Stages")
	await settle()
	for i in screen._snapshot.stages.size():
		screen._journey_buttons[i].pressed.emit()
		check(screen._stage == i, "Stage tile selection")
	screen._select_stage(0)
	await capture("stages")
	screen._open_journey("Lessons")
	await settle()
	for i in 5:
		screen._journey_buttons[i].pressed.emit()
		check(screen._module == i, "Lesson module selection")
	screen._select_module(1)
	await capture("lessons")
	check(fingerprint() == before, "Browsing does not mutate progress")
	# Pending gameplay has priority only for its current account and topic.
	auth._signed_in = true
	player.mastery_matrix["phishing"] = 0.88
	auth._bkt_queue.append({"participant_code": "progress-test", "skill_id": "phishing", "is_correct": true})
	state = Data.snapshot()
	check(state.mastery[0].pending and is_equal_approx(float(state.mastery[0].value), 0.88), "Pending local estimate wins")
	auth._participant_code = "another-student"
	state = Data.snapshot()
	check(not state.mastery[0].pending and is_equal_approx(float(state.mastery[0].value), 0.25), "Previous account pending estimate excluded")
	auth._participant_code = "progress-test"
	auth._bkt_queue.clear()
	auth._mastery = {"Phishing": 0.5, "Smishing": 0.0, "Vishing": NAN}
	auth._completed_module_ids = []
	state = Data.snapshot()
	check(state.assessed == 1 and state.average == 0.5, "Zeros and invalid values excluded from average")
	screen._select_tab("Mastery")
	await settle()
	await capture("partial_mastery")
	# Completion and maximum rank fixtures.
	auth._points = 9999
	for module in state.modules:
		player.lesson_progress[module.id] = module.total
	for id in range(1, 11):
		player.cleared_stages[player.stage_progress_key("mod_01", id)] = true
	state = Data.snapshot()
	check(state.max_rank and state.rank_value == state.rank_span, "Maximum rank full bar")
	check(state.stage_done == 10 and state.lesson_done == 30, "Full completion")
	auth.progress_changed.emit()
	await settle()
	check(screen._snapshot.max_rank, "Live progress signal refreshes screen")
	fresh()
	auth.session_changed.emit(false)
	await settle()
	check(screen._tab == "Overview" and screen._snapshot.assessed == 0, "Session change clears previous student display")
	# Shared deployment gate parity: keep progression and remediation behavior unchanged.
	var stage_manager := root.get_node("StageManager")
	for unlocked in [false, true]:
		player.completed_lessons.clear()
		if unlocked:
			player.completed_lessons.assign(["mod_01"])
		for ceiling in [1, 5, 10]:
			player.max_stage_cleared_by_module = {"mod_01": ceiling}
			player.locked_stages = {"mod_01:3": true}
			for id in range(1, 11):
				var config: Dictionary = stage_manager.get_stage_config(id)
				var req := str(config.get("req_lesson", ""))
				var old_rule: bool = player.is_module_deploy_unlocked("mod_01") and not config.is_empty() and id <= ceiling + 1 and (req.is_empty() or player.has_completed_lesson(req)) and not player.is_stage_locked("mod_01", id)
				check(stage_manager.access_reason(id).is_empty() == old_rule, "Shared stage access parity")
	auth._mastery = {"Phishing": 0.25, "Smishing": 0.4, "Vishing": 0.7, "Pretexting": 0.85, "Baiting": 0.95}
	# Render real viewport scaling with phone-landscape safe-area simulation.
	for resolution in [Vector2i(960,600), Vector2i(844,390)]:
		root.size = resolution
		await settle()
		var safe := screen.find_child("*", true, false)
		for child in screen.get_children():
			if child is SafeAreaContainer:
				safe = child
		if resolution.x == 844:
			var units_per_pixel: float = 1.0 / root.get_final_transform().get_scale().x
			safe.add_theme_constant_override("margin_left", 24 + ceili(32 * units_per_pixel))
			safe.add_theme_constant_override("margin_right", 24 + ceili(24 * units_per_pixel))
			safe.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units_per_pixel))
		for tab in ["Overview", "Mastery", "Journey"]:
			screen._select_tab(tab)
			await settle()
			check(screen._body.get_parent().get_global_rect().end.x <= root.get_visible_rect().end.x, "No horizontal overflow")
			check(screen._back.size.y * root.get_final_transform().get_scale().y >= 47.9, "Back touch target remains 48px")
			if tab == "Mastery":
				check(screen._radar.size.x >= 360, "Phone radar stays large")
				var radar: Control = screen._radar
				var tick_top: float = radar._center().y - radar._radius() + 10 - maxi(20, radar.font_size - 6)
				check(radar._labels[0].get_rect().end.y <= tick_top, "Top topic and ring labels do not overlap")
			await capture("%d_%s" % [resolution.x, tab.to_lower()])
	before = fingerprint()
	screen.on_exit()
	screen.queue_free()
	await process_frame
	check(before == fingerprint(), "Closing Progress does not mutate progress")
	print("[PROGRESS SCREEN] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
