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

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await settle()
	var player := root.get_node("PlayerManager")
	var auth := root.get_node("AuthService")
	var access: GDScript = load("res://src/ui/screens/dashboard/world_access.gd")
	auth._token = ""
	auth._signed_in = false
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
	var journal: Control = screen._access_modal
	check(journal._cards.get_child_count() == 5, "Journal lists five worlds")
	check(journal._list_page.visible and journal._detail_page.visible, "Desktop journal has two pages")
	await tap(journal._cards.get_child(1) as Control)
	check(journal._selected == 1, "Native world card click updates selection")
	journal._close.grab_focus()
	for index: int in 10:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_focus_next"
		event.pressed = true
		root.push_input(event, true)
		check(journal.is_ancestor_of(root.gui_get_focus_owner()), "Keyboard focus stays inside journal")
	journal._set_filter(true)
	check(journal._selected == -1 and journal.action.disabled, "Empty completed filter cannot deploy")
	await settle()
	await capture("empty_completed")
	journal._set_filter(false)
	journal.select_world(1)
	check(journal._route == &"lessons", "Future world routes only to lessons")
	journal.select_world(0)
	check(journal._route == &"lessons", "Locked first world routes to lessons")
	await settle()
	await capture("journal_locked")
	check(screen._world_access.modules.size() == 5 and screen._world_access.stages.size() == 10, "Complete module and stage access list")
	check(not screen.can_go_back() and not screen._access_modal.visible, "Back closes briefing first")
	check(before == JSON.stringify([player.lesson_progress, player.completed_lessons, player.cleared_stages, player.locked_stages, player.credits]), "Reading guidance changes no progression")
	auth._completed_module_ids = ["mod_01"]
	player.lesson_progress = {"mod_01": 3}
	screen._refresh_world()
	check(screen._world_access.heading == "STAGE 1 READY", "Partial lesson completion already opens deployment")
	player.lesson_progress = {"mod_01": 6}
	player.completed_lessons.assign(["mod_01"])
	screen._refresh_world()
	check(screen._world_access.heading == "STAGE 1 READY", "Cleared module unlocks actual stage")
	check(screen._world_access.modules[1].reason.contains("Module 2 Lesson 1"), "Module 2 explains its own lesson requirement")
	player.lesson_progress["mod_02"] = 1
	screen._refresh_world()
	journal.refresh(screen._world_access)
	journal.select_world(1)
	check(journal._route == &"stage_select" and journal.action.text == "OPEN DEPLOY", "World 2 offers deployment after its own Lesson 1")
	check(screen._world_access.modules[1].stages[0].status == "AVAILABLE" and screen._world_access.modules[1].stages[2].reason.contains("Lesson 2"), "World 2 checklist uses its own per-stage lesson gates")
	# Use the real completion APIs, not a manual UI refresh.
	screen._show_access()
	var tested_modules: Array[String] = ["mod_01", "mod_02"]
	player.complete_lesson_unit("mod_02", 6, tested_modules)
	player.mark_stage_cleared("mod_02", 1)
	await settle()
	check(journal.visible and journal._snapshot.modules[1].done == 2 and journal._snapshot.modules[1].stages[0].done, "Open World journal reacts to lesson and stage completion signals")
	check(not journal._snapshot.modules[0].stages[0].done, "Module 2 clear never ticks Module 1's checklist")
	journal.select_world(0)
	await settle()
	await capture("ready")
	player.cleared_stages = {"mod_01:1": true, "mod_01:2": true}
	screen._refresh_world()
	check(screen._world_access.heading == "STAGE 3 READY" and screen._world_access.route == &"stage_select", "Explicit Stage 1 and 2 clears open Stage 3 without a stale ceiling")
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
	check(journal._compact and journal._list_page.visible and not journal._detail_page.visible, "Phone starts on full-width list")
	await capture("phone_list")
	journal.select_world(0)
	await settle()
	check(journal._detail_page.visible and not journal._list_page.visible, "Phone selection opens separate details page")
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
	var detail_scroll: ScrollContainer = journal._details.get_parent() as ScrollContainer
	detail_scroll.scroll_vertical = 100000
	await settle()
	check(detail_scroll.scroll_vertical > 0, "Hidden scrollbar still permits checklist scrolling")
	await capture("phone_checklist")
	check(not screen.can_go_back() and journal.visible and journal._list_page.visible, "Mobile Back returns to world list first")
	check(not screen.can_go_back() and not journal.visible, "Second mobile Back closes journal")
	screen._access_session_changed(false)
	check(not screen._access_modal.visible, "Account change closes old access details")
	player.locked_stages = {}
	for id in range(1, 11):
		player.cleared_stages[player.stage_progress_key("mod_01", id)] = true
	state = access.snapshot()
	check(state.heading == "MODULE 1 CLEARED" and state.route == &"progress", "Completion has truthful coming-soon message")
	player.max_stage_cleared_by_module = {"mod_01": 10}
	root.size = Vector2i(1280, 720)
	await settle()
	screen._show_access()
	journal._set_filter(true)
	await settle()
	check(journal._selected == -1 and journal.action.disabled, "World is not fully completed while its post-test remains pending")
	player.lesson_post_quiz_scores["mod_01"] = 20
	player.progress_changed.emit()
	await settle()
	check(journal._cards.get_child_count() == 1 and journal._selected == 0, "Completed tab contains only cleared authored world")
	check(journal.action.text == "VIEW PROGRESS", "Cleared world offers actual progress route")
	await capture("completed_journal")
	for node: Node in journal.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = node as ScrollContainer
		check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Journal scrollbars hidden without disabling scrolling")
	screen.on_exit()
	screen.queue_free()
	await settle()
	await verify_missions()
	await verify_mission_tracking()
	print("WORLD_ACCESS_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)

func verify_missions() -> void:
	var manager: Node = root.get_node("TaskManager")
	var player: Node = root.get_node("PlayerManager")
	var settings: Node = root.get_node("SettingsService")
	var original: Dictionary = player.mission_progress.duplicate(true)
	var credits: int = player.credits
	var reduced: bool = settings.reduced_motion
	# Presentation fixture only: never invoke payouts or persistence.
	player.mission_progress = {"day": manager._today(), "tasks": {"defeat_fast": {"current": 20}, "clear_stages": {"current": 3, "rewarded": true}}}
	var fixture: Dictionary = player.mission_progress.duplicate(true)
	var state_before: String = JSON.stringify(manager.get_active_tasks())
	root.size = Vector2i(1280, 720)
	await settle()
	var missions: Control = load("res://src/ui/screens/deploy/missions_screen.tscn").instantiate()
	root.add_child(missions)
	settings.reduced_motion = true
	missions.on_enter({})
	await settle()
	check(missions._modal_card.modulate.a == 1.0, "Missions reduced motion skips opening fade")
	check(missions._cards.get_child_count() == 2, "Missions shows live task cards")
	check(missions._list_page.visible and missions._detail_page.visible, "Missions desktop uses two pages")
	check(has_label(missions._details, "20 / 50") and has_label(missions._details, "+100 CR"), "Mission details show real progress and reward")
	await capture("missions_desktop")
	await tap(missions._cards.get_child(1) as Control)
	check(missions._selected_id == "clear_stages", "Native mission card activation selects task")
	check(has_label(missions._details, "OBJECTIVE COMPLETED"), "Completed mission displays completed status")
	var checks: Array[Node] = missions.find_children("CompletionMark", "Control", true, false)
	check(checks.size() == 1 and bool(checks[0].get_meta("complete")), "Completed mission checkbox is checked")
	for node: Node in missions._details.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == "3 / 3":
			check(label.get_line_count() == 1, "Mission count stays on one line")
	await capture("missions_complete")
	await tap(missions._tabs[1])
	check(missions._tasks.is_empty() and has_label(missions._cards, "No story directives yet."), "Main tab has truthful empty state")
	await tap(missions._tabs[2])
	check(has_label(missions._cards, "No active event."), "Event tab has truthful empty state")
	await capture("missions_empty")
	player.mission_progress = {"day": manager._today(), "tasks": "malformed"}
	missions._set_tab(0)
	check(missions._tasks.size() == 2 and missions._tasks[0].current == 0, "Malformed mission counters cannot replace authored definitions")
	player.mission_progress = fixture
	missions.on_resume()
	missions._close.grab_focus()
	for index: int in 8:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_focus_next"
		event.pressed = true
		root.push_input(event, true)
		check(missions.is_ancestor_of(root.gui_get_focus_owner()), "Missions traps keyboard focus")
	for dimensions: Vector2i in [Vector2i(844, 390), Vector2i(960, 540)]:
		root.size = dimensions
		missions._return_to_list()
		await settle()
		check(missions._compact and missions._list_page.visible and not missions._detail_page.visible, "Mobile missions starts on list")
		await capture("missions_list_%dx%d" % [dimensions.x, dimensions.y])
		await tap(missions._cards.get_child(0) as Control)
		check(not missions._list_page.visible and missions._detail_page.visible, "Mobile mission opens full-width detail")
		check(root.get_visible_rect().encloses(missions._close.get_global_rect()), "Mission close fits mobile viewport")
		check(missions._close.size.y * root.get_final_transform().get_scale().y >= 47.9, "Mission close retains 48px touch target")
		await capture("missions_details_%dx%d" % [dimensions.x, dimensions.y])
		check(not missions.can_go_back() and missions._list_page.visible, "Mobile mission Back returns to list")
		check(missions.can_go_back(), "Second mission Back permits router dismissal")
	check(player.credits == credits and JSON.stringify(manager.get_active_tasks()) == state_before, "Browsing missions never changes credits or task progress")
	settings.reduced_motion = false
	missions.on_enter({})
	missions.on_exit()
	check(not missions._tween.is_running(), "Leaving missions cancels opening animation")
	missions.queue_free()
	await settle()
	settings.reduced_motion = reduced
	player.mission_progress = original

func verify_mission_tracking() -> void:
	var player: Node = root.get_node("PlayerManager")
	var manager: Node = root.get_node("TaskManager")
	var router: Node = root.get_node("Router")
	var saves: Node = root.get_node("SaveService")
	var original: Dictionary = player.get_save_data().duplicate(true)
	var tutorial: bool = router.is_tutorial
	player.reset_to_defaults()
	router.is_tutorial = false
	manager.record_stage_cleared()
	manager.record_enemy_defeated("fast")
	check(player.mission_progress.is_empty(), "Fresh tutorial account earns no mission progress")
	player.tutorial_complete = true
	router.is_tutorial = true
	manager.record_stage_cleared()
	manager.record_enemy_defeated("fast")
	check(player.mission_progress.is_empty(), "Replayed tutorial earns no mission progress")
	router.is_tutorial = false
	var missions: Control = load("res://src/ui/screens/deploy/missions_screen.tscn").instantiate()
	root.add_child(missions)
	missions.on_enter({})
	manager.record_enemy_defeated("basic")
	check(manager.get_active_tasks()[0].current == 0, "Wrong enemy type does not count")
	await defeat_mission_enemy(MatchContext.stage_one_live(), false)
	check(manager.get_active_tasks()[0].current == 1, "Real fast enemy defeat counts once despite repeated lethal damage")
	await settle()
	check(has_label(missions._details, "1 / 50"), "Open mission view refreshes from gameplay signal")
	await defeat_mission_enemy(MatchContext.stage_one_live(), true)
	await defeat_mission_enemy(MatchContext.stage_one_preview(), false)
	await defeat_mission_enemy(MatchContext.guided_training(), false)
	check(manager.get_active_tasks()[0].current == 1, "Leaks, preview and training enemies never count")
	manager.record_stage_cleared()
	check(manager.get_active_tasks()[1].current == 1, "Stage clear increments its separate objective")
	player.reset_to_defaults()
	saves.load_game()
	check(manager.get_active_tasks()[0].current == 1 and manager.get_active_tasks()[1].current == 1, "Partial counters survive an actual local save/load")
	for index: int in 49:
		manager.record_enemy_defeated("fast")
	manager.record_stage_cleared()
	manager.record_stage_cleared()
	check(player.credits == 350 and player.pvp_tokens == 0, "Both missions award exactly 350 Solo CR, never PvP currency")
	var account_a: Dictionary = player.get_save_data().duplicate(true)
	player.reset_to_defaults()
	saves.load_game()
	for index: int in 3:
		manager.record_stage_cleared()
		manager.record_enemy_defeated("fast")
	check(player.credits == 350, "Reloading completed missions cannot pay twice")
	player._on_session_changed(false)
	check(manager.get_active_tasks()[0].current == 0 and player.credits == 0, "Logout clears the previous student's counters and wallet")
	player.apply_save_data({"tutorial_complete": true})
	check(player.mission_progress.is_empty(), "Legacy/new account starts with no inherited mission data")
	manager.record_stage_cleared()
	var account_b: Dictionary = player.get_save_data().duplicate(true)
	player.apply_save_data(account_a)
	check(manager.get_active_tasks()[1].current == 3 and player.credits == 350, "Returning to account A restores only A's progress and receipts")
	player.apply_save_data(account_b)
	check(manager.get_active_tasks()[1].current == 1 and player.credits == 0, "Account B remains independent")
	player.mission_progress = {"day": "2000-01-01", "tasks": {"clear_stages": {"current": 3, "rewarded": true}}}
	check(manager.get_active_tasks()[1].current == 0, "Previous day's missions read as fresh without awarding rewards")
	manager.record_stage_cleared()
	check(player.mission_progress.day == manager._today() and manager.get_active_tasks()[1].current == 1, "First new-day event creates the new daily counters")
	player.mission_progress.day = "2000-01-01"
	manager._observed_day = "2000-01-01"
	manager._day_check_left = 0.0
	manager._process(1.0)
	await settle()
	check(has_label(missions._details, "0 / 50"), "Open journal refreshes when the UTC day changes")
	player.mission_progress = {"day": manager._today(), "tasks": {"defeat_fast": {"current": -8}, "clear_stages": {"current": 900, "reward": 999999}}}
	check(manager.get_active_tasks()[0].current == 0 and manager.get_active_tasks()[1].current == 3 and manager.get_active_tasks()[1].reward == 250, "Malformed counts are clamped and save cannot redefine rewards")
	manager.record_stage_cleared()
	check(player.credits == 0, "Reading/restoring a completed counter never issues a retroactive payout")
	# Synthetic offline accounts verify actual per-student save files and the
	# in-flight upload race. Empty token prevents all network requests.
	var auth: Node = root.get_node("AuthService")
	var database: Node = root.get_node("StudentDatabase")
	var previous_id: String = auth._participant_code
	check(database.upsert_student({"id": "mission-test-a"}), "Create isolated mission account A")
	check(database.upsert_student({"id": "mission-test-b"}), "Create isolated mission account B")
	auth._participant_code = "mission-test-a"
	auth._signed_in = true
	player.apply_save_data({"tutorial_complete": true})
	saves._sync_in_flight = true
	manager.record_stage_cleared()
	check(saves._resync_queued and database.has_pending_sync("mission-test-a"), "Partial mission update queues a newer snapshot during an in-flight upload")
	saves._on_sync_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), "mission-test-a")
	check(database.has_pending_sync("mission-test-a"), "Old upload acknowledgement cannot discard newer mission progress")
	await settle()
	check(not saves._sync_in_flight, "Offline test made no follow-up network request")
	auth._participant_code = "mission-test-b"
	player.apply_save_data({"tutorial_complete": true})
	manager.record_enemy_defeated("fast")
	auth._participant_code = "mission-test-a"
	player.reset_to_defaults()
	saves.load_game()
	check(manager.get_active_tasks()[1].current == 1 and manager.get_active_tasks()[0].current == 0, "Account A's actual save file contains only A's counters")
	auth._participant_code = "mission-test-b"
	player.reset_to_defaults()
	saves.load_game()
	check(manager.get_active_tasks()[1].current == 0 and manager.get_active_tasks()[0].current == 1, "Account B's actual save file contains only B's counters")
	auth._signed_in = false
	auth._participant_code = previous_id
	missions.queue_free()
	await settle()
	player.apply_save_data(original)
	router.is_tutorial = tutorial
	saves.save_game(false)
	await settle()

func defeat_mission_enemy(context: MatchContext, leak: bool) -> void:
	var path: Path2D = Path2D.new()
	path.curve = Curve2D.new()
	path.curve.add_point(Vector2.ZERO)
	path.curve.add_point(Vector2(100, 0))
	root.add_child(path)
	var enemy: EnemyBase = EnemyBase.new()
	enemy.match_context = context
	enemy.task_gateway = root.get_node("TaskManager")
	enemy._type_id = "fast"
	path.add_child(enemy)
	enemy.set_physics_process(false)
	if leak:
		enemy.mark_leaked()
	enemy.take_damage(100)
	enemy.take_damage(100)
	await settle()
	path.queue_free()
	await settle()

func has_label(parent: Node, text: String) -> bool:
	for node: Node in parent.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false
