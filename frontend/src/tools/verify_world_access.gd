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
	print("WORLD_ACCESS_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)

func verify_missions() -> void:
	var manager: Node = root.get_node("TaskManager")
	var player: Node = root.get_node("PlayerManager")
	var settings: Node = root.get_node("SettingsService")
	var original: Array[Dictionary] = manager.daily_tasks.duplicate(true)
	var credits: int = player.credits
	var reduced: bool = settings.reduced_motion
	# Presentation fixture only: never invoke payouts or persistence.
	manager.daily_tasks[0]["current"] = 20
	manager.daily_tasks[1]["current"] = 3
	var state_before: String = JSON.stringify(manager.daily_tasks)
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
	manager.daily_tasks.clear()
	missions._set_tab(0)
	check(has_label(missions._cards, "No daily missions available."), "Empty daily list handled safely")
	manager.daily_tasks.assign(original)
	manager.daily_tasks[0]["current"] = 20
	manager.daily_tasks[1]["current"] = 3
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
	check(player.credits == credits and JSON.stringify(manager.daily_tasks) == state_before, "Browsing missions never changes credits or task progress")
	settings.reduced_motion = false
	missions.on_enter({})
	missions.on_exit()
	check(not missions._tween.is_running(), "Leaving missions cancels opening animation")
	missions.queue_free()
	await settle()
	settings.reduced_motion = reduced
	manager.daily_tasks.assign(original)

func has_label(parent: Node, text: String) -> bool:
	for node: Node in parent.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false
