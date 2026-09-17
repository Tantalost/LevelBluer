extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func stack_ids(router: Node) -> Array:
	var ids := []
	for screen in router._stack:
		ids.append(screen.screen_id)
	return ids

func back(router: Node) -> void:
	router.request_back()
	while router._busy:
		await process_frame
	await process_frame

func _run() -> void:
	var player := root.get_node("PlayerManager")
	var auth := root.get_node("AuthService")
	var before := str([player.credits, player.cleared_stages, player.lesson_progress, player.locked_stages, auth._mastery])
	var router: Node = load("res://src/tools/intel_navigation_test_router.gd").new()
	root.add_child(router)
	var host := Control.new()
	root.add_child(host)
	router.register_host(host)
	check(not router.SCREENS.has(&"intel_hub"), "Retired Intel Hub has no registered route")
	await router.replace_all(&"dashboard")
	await router.push(&"victory", {"won": false})
	await router.open_lessons()
	check(stack_ids(router) == [&"dashboard", &"lessons"], "Failed results -> Lessons has Dashboard as its only parent")
	await back(router)
	check(stack_ids(router) == [&"dashboard"], "Lessons Back returns directly to Dashboard")
	# Gameplay-overlay shortcut uses the same helper and must tear down the level.
	var gameplay := Node.new()
	root.add_child(gameplay)
	router._gameplay = gameplay
	host.hide()
	Engine.time_scale = 2.0
	await router.open_lessons()
	check(router._gameplay == null and host.visible, "Defeat overlay -> Lessons exits gameplay and restores UI")
	check(Engine.time_scale == 1.0, "Gameplay speed reset on exit")
	check(stack_ids(router) == [&"dashboard", &"lessons"], "Gameplay shortcut has no hidden Intel parent")
	await router.push(&"lesson_player", {"module_id": "mod_01"})
	await back(router)
	check(router.current_screen_id() == &"lessons", "Lesson workspace still returns to lesson module selection")
	await back(router)
	check(router.current_screen_id() == &"dashboard", "Lesson selection then returns to Dashboard")
	await router.open_codex("phishing")
	check(stack_ids(router) == [&"dashboard", &"codex"], "Codex shortcut also omits retired hub")
	await back(router)
	check(router.current_screen_id() == &"dashboard", "Codex Back returns to Dashboard")
	await router.open_certificate_screen()
	check(stack_ids(router) == [&"dashboard", &"certificate"], "Certificate has no retired hub parent")
	await router.open_dashboard()
	check(stack_ids(router) == [&"dashboard"], "Certificate return/retreat destination is Dashboard")
	# Header Back and Android Back share request_back; exercise the notification path.
	await router.push(&"lessons")
	router._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	while router._busy:
		await process_frame
	check(router.current_screen_id() == &"dashboard", "Android Back returns from Lessons to Dashboard")
	check(before == str([player.credits, player.cleared_stages, player.lesson_progress, player.locked_stages, auth._mastery]), "Navigation does not change progress, rewards, locks or mastery")
	host.queue_free()
	router.queue_free()
	await process_frame
	print("INTEL_NAVIGATION_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
