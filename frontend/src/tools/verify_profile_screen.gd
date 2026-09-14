extends SceneTree
## Only in-memory fixtures; no server calls, rewards, purchases or saves.
var failures := 0
var auth: Node
var player: Node
var screen: Control

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
		root.get_texture().get_image().save_png("res://.godot/profile_" + label + ".png")

func fresh() -> void:
	auth._token = ""
	auth._signed_in = false
	auth._display_name = "COMMANDER_X"
	auth._points = 0
	auth._mastery = {}
	auth._completed_module_ids = []
	auth._pre_test_completed = false
	auth._bkt_queue.clear()
	player.cleared_stages = {}
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.locked_stages = {}
	player.mastery_matrix = {"phishing": 0.1}
	player.credits = 229

func fingerprint() -> String:
	return JSON.stringify([auth._mastery, auth._points, auth._completed_module_ids, player.cleared_stages,
		player.lesson_progress, player.completed_lessons, player.credits, player.tech_ranks])

func _run() -> void:
	auth = root.get_node("AuthService")
	player = root.get_node("PlayerManager")
	fresh()
	screen = load("res://src/ui/screens/profile/profile_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	await settle()
	var before := fingerprint()
	check(screen.get_node("CRTOverlay").visible, "Permanent CRT shell")
	check(screen._dossier.next.route == &"lessons", "Fresh account points to lessons, not locked gameplay")
	check(screen._dossier.strongest.is_empty(), "Default BKT prior is not shown as assessed")
	check(screen._dossier.milestones.all(func(m: Dictionary) -> bool: return not m.earned), "Fresh milestones unearned")
	check(not screen._details_content.get_parent().visible, "Personal details collapsed by default")
	await capture("fresh")
	screen._toggle_details()
	check(screen._details_content.get_parent().visible, "Personal details expandable")
	screen._toggle_details()
	check(fingerprint() == before, "Inspecting profile is read only")
	auth._completed_module_ids = ["mod_01"]
	player.lesson_progress = {"mod_01": 2}
	screen._refresh()
	check(screen._dossier.next.title == "CONTINUE YOUR TRAINING", "Passed pretest recommends next lessons")
	check(root.get_node("Router").SCREENS.has(screen._dossier.next.route), "Suggested lesson route exists")
	auth._points = 1250
	auth._mastery = {"Phishing": 0.85, "Smishing": 0.35, "Vishing": 0.6}
	auth._completed_module_ids = ["mod_01"]
	player.lesson_progress = {"mod_01": 6, "mod_02": 2}
	player.completed_lessons.assign(["mod_01"])
	player.cleared_stages = {1: true, 3: true}
	player.mock_max_stage_cleared = 3
	screen.on_resume()
	await settle()
	check(screen._dossier.next.route == &"stage_select", "Available stage gives Deploy shortcut")
	check(screen._dossier.strongest.name == "Phishing", "Highest assessed mastery")
	check(screen._dossier.practice.name == "Smishing", "Practice focus uses lowest assessed topic")
	check(root.get_node("Router").SCREENS.has(screen._dossier.next.route), "Suggested deployment route exists")
	check(screen._snapshot.stage_done == 2 and screen._snapshot.lesson_done == 8, "Exact completion totals")
	check(screen._dossier.milestones[0].earned and screen._dossier.milestones[1].earned, "Recorded milestones earned")
	await capture("overview")
	auth._signed_in = true
	auth._participant_code = "profile-fixture"
	auth._bkt_queue.assign([{"participant_code": "profile-fixture", "skill_id": "smishing"}])
	player.mastery_matrix["smishing"] = 0.42
	screen._refresh()
	check(screen._dossier.practice.pending and is_equal_approx(float(screen._dossier.practice.value), 0.42), "Pending owned assessment uses local estimate and sync label")
	auth._signed_in = false
	auth._bkt_queue.clear()
	screen._refresh()
	(screen._briefing.get_parent() as ScrollContainer).scroll_vertical = 10000
	await settle()
	await capture("milestones")
	(screen._briefing.get_parent() as ScrollContainer).scroll_vertical = 0
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		if dimensions.x == 844:
			for child in screen.get_children():
				if child is SafeAreaContainer:
					var units := 1.0 / root.get_final_transform().get_scale().x
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units))
			await settle()
		check(screen._body.get_global_rect().end.x <= root.get_visible_rect().end.x, "No horizontal viewport overflow")
		for action in screen._actions:
			check(action.size.y * root.get_final_transform().get_scale().y >= 47.9, "48px physical touch targets")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
	auth._display_name = "COMMANDER WITH A VERY LONG DISPLAY NAME"
	auth._full_name = "A long full name for the personal account record"
	auth._email = "a.long.account.name@example.invalid"
	auth._section = "A very long section identifier for testing"
	screen._refresh()
	screen._toggle_details()
	await settle()
	await capture("long_identity")
	check(screen._body.get_global_rect().end.x <= root.get_visible_rect().end.x, "Long identity does not overflow horizontally")
	auth._points = 9000
	for module in screen._snapshot.modules:
		player.lesson_progress[module.id] = module.total
	for id in range(1, 11):
		player.cleared_stages[id] = true
	screen._refresh()
	check(screen._snapshot.max_rank, "Commander max rank state")
	check(screen._dossier.milestones.all(func(m: Dictionary) -> bool: return m.earned), "All milestones earned on full completion")
	check(screen._dossier.next.route == &"codex", "Completed player with low mastery gets review suggestion")
	auth._mastery = {"Phishing": 0.9, "Smishing": 0.8}
	screen._refresh()
	check(screen._dossier.next.route == &"progress", "Full completion routes to Progress")
	fresh()
	screen._session_changed(false)
	await settle()
	check(not screen._details_open and screen._dossier.strongest.is_empty(), "Account change clears previous identity detail and mastery")
	for action in screen._actions:
		check(action.pressed.get_connections().size() > 0, "Visible shortcuts have handlers")
	before = fingerprint()
	screen.on_exit()
	check(not screen.visible, "Exit hides profile")
	screen.on_resume()
	check(screen.visible, "Resume shows profile")
	check(fingerprint() == before, "Resume does not change progression")
	screen.queue_free()
	await settle()
	print("PROFILE_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
