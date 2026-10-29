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
	auth._token = ""
	auth._participant_code = "progress-test"
	auth._points = 0
	player.mastery_matrix = {"phishing": 0.1}
	player.cleared_stages = {}
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.chapter_progress = {}
	player.chapter_replay_progress = {}
	player.chapter_replays = {}
	player.lesson_post_quiz_scores = {}
	player.pretest_baselines = {}
	player.practice_responses = {}
	player.learning_events.clear()
	player.learning_evidence = {}
	player.locked_stages = {}
	player.max_stage_cleared_by_module = {}
	player.credits = 123

func fingerprint() -> String:
	return JSON.stringify([auth._mastery, auth._completed_module_ids, auth._bkt_queue, auth._points,
		player.mastery_matrix, player.cleared_stages, player.lesson_progress, player.completed_lessons,
		player.locked_stages, player.credits, player.unlocked_towers, player.chapter_progress,
		player.lesson_post_quiz_scores, player.pretest_baselines, player.practice_responses, player.learning_events])

func _run() -> void:
	auth = root.get_node("AuthService")
	player = root.get_node("PlayerManager")
	root.get_node("SaveService").set_process(false)
	Data = load("res://src/ui/screens/progress/progress_data.gd")
	fresh()
	var state: Dictionary = Data.snapshot()
	check(state.chapter_done == 0 and state.chapter_total == 5, "Fresh account has 0/5 authored chapters")
	check(state.checkpoint_done == 0 and state.checkpoint_total == 5, "Fresh account has 0/5 passed checkpoints")
	check(state.next.args == {"module_id":"mod_01"}, "Fresh learner is routed to a lesson/pretest, not unassessed practice")
	check(state.sync_label == "On this device only", "Guest progress never claims cloud sync")
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
	player.chapter_progress = {"mod_01_ch_01":{"completed":true, "hint_used":true}, "mod_01_ch_03":{"completed":true}}
	player.chapter_replays = {"mod_01_ch_02":{"completed":true}}
	state = Data.snapshot()
	check(state.chapter_done == 2 and state.chapter_total == 5, "Original chapter records counted exactly; replays and old stages excluded")
	check(state.chapters[0].assistance == "assisted" and state.chapters[2].assistance == "unknown", "Story assistance is separate and missing evidence stays unknown")
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
	screen._open_journey("Story")
	await settle()
	for i in screen._snapshot.chapters.size():
		screen._journey_buttons[i].pressed.emit()
		check(screen._chapter == i, "Chapter tile selection")
	screen._select_chapter(0)
	await capture("story")
	screen._open_journey("Lessons")
	await settle()
	for i in 5:
		screen._journey_buttons[i].pressed.emit()
		check(screen._module == i, "Lesson module selection")
	screen._select_module(1)
	await capture("lessons")
	screen._open_journey("Checkpoints")
	await settle()
	await capture("checkpoints")
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
	check(state.chapter_done == 2 and state.lesson_done == 30, "Legacy stages never inflate story completion")
	auth.progress_changed.emit()
	await settle()
	check(screen._snapshot.max_rank, "Live progress signal refreshes screen")
	fresh()
	auth.session_changed.emit(false)
	await settle()
	check(screen._tab == "Overview" and screen._snapshot.assessed == 0, "Session change clears previous student display")
	# Progress must display the authoritative lesson/checkpoint and story gates.
	player.completed_lessons.clear()
	player.remediation_state = {}
	player.lesson_post_quiz_scores = {}
	for lesson_count: int in [0, 1, 3, 6]:
		player.lesson_progress = {"mod_01": lesson_count}
		for cleared_count: int in [0, 2, 9]:
			player.cleared_stages = {}
			for id: int in range(1, cleared_count + 1):
				player.cleared_stages[player.stage_progress_key("mod_01", id)] = true
			# An old maximum must not manufacture missing clears.
			player.max_stage_cleared_by_module = {"mod_01": 10}
			player.locked_stages = {"mod_01:3": true}
			state = Data.snapshot()
			for row: Dictionary in state.chapters:
				var expected: String = "Completed" if row.done else ("Available" if player.story_unlocked(str(row.id)) else "Locked")
				check(row.status == expected, "Progress uses the same story access rules as Deploy")
			for row: Dictionary in state.modules:
				check(row.unlocked == player.can_access_lesson_module(str(row.id)), "Lesson access matches the playable screen")
	check(not state.modules[1].unlocked, "Six lessons alone do not unlock module two")
	player.lesson_post_quiz_scores = {"mod_01": 20}
	state = Data.snapshot()
	check(state.modules[1].unlocked and state.checkpoint_done == 1, "Passed checkpoint unlocks the next module and counts separately")
	player.lesson_post_quiz_scores = {"mod_01": 0}
	state = Data.snapshot()
	check(state.checkpoint_done == 0 and state.modules[0].best == 0, "A zero score never counts as a passed checkpoint")
	# Recommendation changes with mastery and respects the real module gates.
	player.lesson_progress = {"mod_01":6, "mod_02":1}
	player.lesson_post_quiz_scores = {"mod_01":20}
	player.learning_evidence = {"topics":{"phishing":1,"smishing":1}}
	player.mastery_matrix = {"phishing":0.8,"smishing":0.25}
	state = Data.snapshot()
	check(state.next.title == "Practise Smishing" and state.next.args == {"practice":true}, "Weakest topic points into existing adaptive practice")
	player.mastery_matrix = {"phishing":0.2,"smishing":0.8}
	player.progress_changed.emit()
	await settle()
	check(screen._snapshot.next.title == "Practise Phishing", "Player update refreshes the displayed recommendation")
	player.mastery_matrix = {"phishing":0.8,"smishing":0.8}
	state = Data.snapshot()
	check(state.next.args == {"module_id":"mod_02"}, "Proficient learner continues unfinished lessons")
	player.lesson_progress = {"mod_01":6}
	player.lesson_post_quiz_scores = {}
	state = Data.snapshot()
	check(state.next.args == {"module_id":"mod_01","post_quiz":true}, "Completed lessons lead to an unpassed checkpoint")
	# Exercise the CTA with a route-capture override, without opening gameplay.
	var route_script: GDScript = GDScript.new()
	route_script.source_code = "extends \"res://src/ui/screens/progress/progress_screen.gd\"\nvar forwarded: Dictionary = {}\nfunc _open_learning(args: Dictionary) -> void:\n\tforwarded = args.duplicate(true)\n"
	check(route_script.reload() == OK, "Recommendation route probe compiles")
	var route_probe: Control = route_script.new()
	root.add_child(route_probe)
	await settle()
	player.mastery_matrix.phishing = 0.2
	route_probe._open_next()
	check(route_probe.forwarded == {"practice":true}, "CTA recalculates a stale recommendation at tap time")
	route_probe.forwarded.clear()
	route_probe._owner = "previous-account"
	route_probe._open_next()
	check(route_probe.forwarded.is_empty(), "A stale-account CTA cannot navigate")
	route_probe.queue_free()
	await settle()
	auth._signed_in = true
	player.learning_events.append({"event_id":"pending-probe"})
	state = Data.snapshot()
	check(state.sync_pending and state.sync_label == "Changes waiting to sync", "Unacknowledged evidence marks account pending")
	player.learning_events.clear()
	root.get_node("SaveService").cloud_sync_completed.emit(true)
	await settle()
	check(not screen._snapshot.sync_pending and screen._snapshot.sync_label == "No pending changes", "Sync acknowledgement refreshes the visible status")
	auth._signed_in = false
	# Local account-save round trip preserves distinct completion records.
	var saved: Dictionary = player.get_save_data()
	player.reset_to_defaults()
	player.apply_save_data(saved)
	state = Data.snapshot()
	check(state.lesson_done == 6 and state.chapter_done == 0 and state.checkpoint_done == 0, "Account-save reload preserves independent measures")
	fresh()
	auth.session_changed.emit(false)
	await settle()
	check(screen._snapshot.lesson_done == 0 and screen._snapshot.next.args == {"module_id":"mod_01"}, "Account change clears old totals and recommendation")
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
			if tab == "Overview":
				(screen._body.get_parent() as ScrollContainer).scroll_vertical = 350
				await settle()
				await capture("%d_totals" % resolution.x)
		for section: String in ["Lessons", "Checkpoints"]:
			screen._open_journey(section)
			await settle()
			check(screen._journey_detail.get_global_rect().end.x <= root.get_visible_rect().end.x, "Journey details fit the phone safe area")
			await capture("%d_%s" % [resolution.x, section.to_lower()])
	before = fingerprint()
	screen.on_exit()
	screen.queue_free()
	await process_frame
	check(before == fingerprint(), "Closing Progress does not mutate progress")
	print("[PROGRESS SCREEN] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
