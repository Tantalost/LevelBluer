extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 8:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/world_access_" + label + ".png")

func _run() -> void:
	var player := root.get_node("PlayerManager")
	var auth := root.get_node("AuthService")
	var access: GDScript = load("res://src/ui/screens/dashboard/world_access.gd")
	auth._token = ""
	auth._completed_module_ids = []
	player.tutorial_complete = false
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.cleared_stages = {}
	player.locked_stages = {}
	player.max_stage_cleared_by_module = {}
	check(access.snapshot().heading == "TUTORIAL REQUIRED", "Tutorial guidance first")
	player.tutorial_complete = true
	var state: Dictionary = access.snapshot()
	check(state.heading == "MODULE 1 LOCKED" and state.explanation.contains("pre-test"), "Fresh player gets actionable pretest guidance")
	var before := JSON.stringify([player.lesson_progress, player.completed_lessons, player.cleared_stages, player.locked_stages, player.credits])
	var screen: Control = load("res://src/ui/screens/dashboard/dashboard_screen.tscn").instantiate()
	root.add_child(screen)
	screen._bind_remote_art()
	screen._refresh_data()
	await settle()
	check(screen._inbox_count.text == "!", "Hard-coded unread number replaced with real lock indicator")
	await capture("locked")
	screen._on_mission_pressed()
	await settle()
	check(screen._access_modal.visible, "World opens access briefing")
	check(screen._world_access.modules.size() == 5 and screen._world_access.stages.size() == 10, "Complete module and stage access list")
	check(not screen.can_go_back() and not screen._access_modal.visible, "Back closes briefing first")
	check(before == JSON.stringify([player.lesson_progress, player.completed_lessons, player.cleared_stages, player.locked_stages, player.credits]), "Reading guidance changes no progression")
	auth._completed_module_ids = ["mod_01"]
	player.lesson_progress = {"mod_01": 3}
	screen._refresh_world()
	check(screen._world_access.short.contains("3 / 6") and not screen._world_access.explanation.contains("Complete its pre-test"), "Passed pretest shows remaining lesson requirement")
	player.lesson_progress = {"mod_01": 6}
	player.completed_lessons.assign(["mod_01"])
	screen._refresh_world()
	check(screen._world_access.heading == "STAGE 1 READY", "Cleared module unlocks actual stage")
	check(screen._world_access.modules[1].reason.contains("coming soon"), "Future maps not mistaken for unlockable authored stages")
	await settle()
	await capture("ready")
	player.cleared_stages = {"mod_01:1": true, "mod_01:2": true}
	screen._refresh_world()
	check(screen._world_access.heading == "STAGE 3 LOCKED" and screen._world_access.route == &"stage_select", "Sequential gate guidance matches actual ceiling")
	player.max_stage_cleared_by_module = {"mod_01": 3}
	player.locked_stages = {"mod_01:3": true}
	screen._refresh_world()
	check(screen._world_access.explanation.contains("does not automatically clear"), "No false promise of automatic exam unlock")
	screen._show_access()
	await settle()
	await capture("exam_briefing")
	auth.progress_changed.emit()
	await settle()
	check(screen._access_modal.visible, "Live refresh preserves open briefing")
	screen._close_access()
	root.size = Vector2i(844, 390)
	await settle()
	screen._refresh_world()
	await capture("phone_button")
	screen._show_access()
	await settle()
	# Simulate mobile safe-area insets on the briefing.
	for child in screen._access_modal.get_children():
		if child is SafeAreaContainer:
			var units := 1.0 / root.get_final_transform().get_scale().x
			child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
			child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
	await settle()
	check(root.get_visible_rect().encloses(screen._access_action.get_global_rect()), "Briefing action fits phone safe area")
	check(screen._access_action.size.y * root.get_final_transform().get_scale().y >= 47.9, "Briefing retains touch-sized action after resize")
	await capture("phone_briefing")
	screen._access_session_changed(false)
	check(not screen._access_modal.visible, "Account change closes old access details")
	player.locked_stages = {}
	for id in range(1, 11):
		player.cleared_stages[player.stage_progress_key("mod_01", id)] = true
	state = access.snapshot()
	check(state.heading == "MODULE 1 CLEARED" and state.route == &"progress", "Completion has truthful coming-soon message")
	screen.on_exit()
	screen.queue_free()
	await settle()
	print("WORLD_ACCESS_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
