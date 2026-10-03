extends SceneTree
## In-memory validation only. Never invokes the save/finish operation.
var failures := 0
var investigation_passes: int = 0

func record_investigation_pass() -> void:
	investigation_passes += 1

func test_investigation(sim: Control) -> void:
	sim.passed.connect(record_investigation_pass)
	var payload: Dictionary = {"kind": "policy_email", "source": sim}
	check(not sim._can_quarantine_drop(Vector2.ZERO, payload), "Cannot quarantine without evidence")
	sim._select_mail()
	sim._tap_quarantine()
	check(not sim._passed, "Tap quarantine also requires evidence")
	sim._act("verify")
	sim._act("report")
	check(not sim._passed and not sim._verified, "Legacy shortcuts cannot bypass investigation")
	sim._open_app("Directory")
	sim._search_directory("")
	sim._search_directory("School")
	check(not sim._directory_found, "Directory requires matching department search")
	sim._search_directory("  UNIVERSITY   IT  ")
	check(sim._directory_found, "Department search tolerates capitalization and spacing")
	sim._compare_domains(true)
	check(not sim._verified, "Directory alone cannot prove mismatch")
	sim._open_app("Inbox")
	sim._inspect_sender()
	sim._compare_domains(false)
	check(not sim._verified, "Wrong comparison cannot unlock quarantine")
	sim._compare_domains(true)
	check(sim._verified, "Both sources and correct comparison establish mismatch")
	check(not sim._can_quarantine_drop(Vector2.ZERO, {"kind": "policy_email", "source": self}), "Reject email from another desktop")
	check(not sim._can_quarantine_drop(Vector2.ZERO, "invalid"), "Reject unrelated drag payload")
	check(sim._can_quarantine_drop(Vector2.ZERO, payload), "Evidence unlocks native drop")
	check(not sim._passed, "Collecting evidence does not automatically complete")
	sim._tap_quarantine()
	sim._drop_quarantine(Vector2.ZERO, payload)
	sim._tap_quarantine()
	check(sim._passed and investigation_passes == 1, "Quarantine emits passed exactly once")

func mouse_move_to(point: Vector2, relative: Vector2 = Vector2.ZERO, held: bool = false) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(motion, true)

func mouse_left_at(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)

func drag_email(sim: Control, target: Vector2) -> void:
	var origin: Vector2 = sim._mail_card.get_global_rect().get_center()
	mouse_move_to(origin)
	mouse_left_at(origin, true)
	await settle()
	mouse_move_to(origin + Vector2(28, 0), Vector2(28, 0), true)
	await settle()
	check(root.gui_is_dragging(), "Native email drag starts")
	mouse_move_to(target, target - origin, true)
	await settle()
	mouse_left_at(target, false)
	await settle()

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _run() -> void:
	var player: Node = load("res://src/autoload/player_manager.gd").new()
	player.lesson_progress = {}
	var catalog = load("res://src/ui/screens/intel/lesson_catalog.gd")
	var study = load("res://src/ui/screens/intel/lesson_study_content.gd")
	var picker: Control = load("res://src/ui/screens/intel/lessons_screen.tscn").instantiate()
	picker.account = player
	root.add_child(picker)
	await settle()
	check(picker._cards.size() == 5, "Five module cards")
	check(picker.find_child("UpgradesCard", true, false) == null, "No upgrades in lesson picker")
	check(picker._is_unlocked(0) and not picker._is_unlocked(1), "Sequential module lock retained")
	check(picker._cards[1].disabled, "Locked module visibly disabled")
	check(picker._cards[1].find_child("ModuleStatusIcon", true, false).kind == 4, "Locked module has padlock")
	check(not picker._cards[0].disabled, "First module/pretest remains actionable")
	await capture("lessons_module_picker")
	picker.hide()
	var screen: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	screen.account = player
	root.add_child(screen)
	screen._load_module("mod_01")
	await settle()
	var locked_topics: int = 0
	for node: Button in screen._web.nodes:
		if node.disabled:
			locked_topics += 1
	check(locked_topics == 5, "Five future topics visibly locked")
	check(not screen._in_lesson and not screen._workspace.visible, "Module opens on web")
	check(screen._start_button.text == "START LESSON", "Explicit start lesson action")
	check(screen._web._canvas.find_children("Lesson*Step*", "Button", false, false).size() == 12, "Six topics have quiz and simulation satellites")
	screen._open_step(0, 2)
	check(screen._phase == 0 and not screen._simulation_passed, "Roadmap cannot bypass quiz")
	screen._open_lesson()
	check(not screen.can_go_back() and not screen._in_lesson, "Back from lesson returns to path")
	check(screen.can_go_back(), "Back from path returns to module picker")
	await capture("lessons_locked_topics")
	var count := 0
	for id in catalog.module_ids():
		for index in catalog.lesson_count(id):
			var content: Dictionary = study.build(id, index)
			check(not str(content.scenario).is_empty(), "Scenario: " + id)
			check(not content.correct.is_empty(), "Quiz has correct answer")
			for answer in content.correct:
				check(answer >= 0 and answer < content.options.size(), "Valid quiz index")
			player.lesson_progress[id] = index
			screen._load_module(id, true)
			screen._select_topic(index)
			check(not screen._can_complete(), "Cannot finish definition")
			screen._set_phase(2)
			check(screen._phase == 0, "Cannot skip quiz")
			screen._set_phase(1)
			check(screen._phase == 0, "Cannot skip reading")
			screen._open_lesson()
			screen._on_continue()
			check(screen._reading_page == 1, "Definition advances to visual example")
			check(screen._content.has_node("VisualExample"), "Authored example has visual message presentation")
			screen.can_go_back()
			screen._select_topic(index)
			screen._open_lesson()
			check(screen._reading_page == 1, "Return to path and reselect retains reading position")
			screen._on_continue()
			screen._on_continue()
			screen._check_quiz()
			check(not screen._quiz_passed, "Empty quiz cannot pass")
			for i in content.options.size():
				if i not in content.correct:
					screen._pick(i)
					break
			screen._check_quiz()
			check(not screen._quiz_passed, "Wrong answer cannot pass")
			check(screen._answer_effect._active and screen._answer_effect._ink == screen.Feedback.ERROR, "Wrong quiz shows red feedback")
			screen._picks.clear()
			for answer in content.correct:
				screen._pick(answer)
			screen._check_quiz()
			check(screen._quiz_passed, "Correct answer passes: %s/%d" % [id, index])
			check(screen._answer_effect._ink == screen.Feedback.SUCCESS and not screen._answer_effect._moving, "Correct quiz replaces error with green and stops shake")
			screen._on_continue()
			check(not screen._answer_effect._active, "Phase change clears quiz feedback")
			var sim = screen._simulation
			if id == "mod_01":
				check(sim._pc_mode and sim._pc.home.visible and not sim._pc.window.visible, "Each Module 1 simulation starts at the desktop")
				check(sim._pc.shortcuts.size() == 6 and sim._pc.dock.size() == 6, "Desktop and taskbar offer six icon apps")
				await settle()
				await capture("pc_lesson_%d_home" % (index + 1))
				sim._pc.shortcuts[0].pressed.emit()
				check(sim._pc.unread, "Unread badge remains until the message is read")
				sim._read_message()
				check(not sim._pc.unread and sim._message_open, "Opening a message clears its unread badge")
				sim._pc.hide_window(false)
				check(sim._pc.home.visible and sim._pc.active_app == "Inbox", "Minimize retains the active app")
				sim._pc._running.pressed.emit()
				check(sim._pc.window.visible and sim._message_open, "Taskbar restores the open message")
				await settle()
				await capture("pc_lesson_%d_mail" % (index + 1))
				for app: String in ["Browser", "File Sandbox", "Directory", "Evidence", "Quarantine"]:
					sim._open_app(app)
					await settle()
					check(not sim._passed, "Visiting apps never completes the lesson")
					if index == 3:
						await capture("pc_lesson_4_" + app.replace(" ", "_"))
				sim._pc.hide_window(true)
				check(sim._pc.home.visible and sim._pc.active_app.is_empty(), "Close returns to desktop")
			else:
				check(not sim._pc_mode, "Other modules retain their existing simulations")
			sim._act("report")
			check(not screen._simulation_passed, "Guessing report is blocked")
			sim._act("open")
			sim._act("unsafe")
			check(not screen._simulation_passed, "Unsafe action cannot pass")
			check(sim._answer_effect._active and sim._answer_effect._ink == screen.Feedback.ERROR, "Unsafe simulation shows red feedback")
			if id == "mod_01" and index == 0:
				test_investigation(sim)
			else:
				check(not sim._investigation, "Other lesson simulations unchanged")
				sim._act("inspect")
				if id == "mod_01":
					sim._pc.hide_window(true)
					sim._open_app("Directory")
					check(sim._inspected, "Closing a window preserves collected evidence")
				sim._act("verify")
				sim._act("report")
			check(screen._simulation_passed, "Safe sequence passes")
			check(sim._answer_effect._ink == screen.Feedback.SUCCESS, "Safe simulation turns green")
			screen._on_continue()
			check(screen._can_complete(), "Both checks permit completion")
			check(player.get_lesson_progress(id) == index, "No topic progress written before finish")
			count += 1
	player.lesson_progress.clear()
	screen._load_module("mod_01", true)
	screen._open_lesson()
	await settle()
	await capture("lessons_definition")
	screen._on_continue()
	await settle()
	await capture("lessons_visual_example")
	screen._on_continue()
	screen._on_continue()
	await settle()
	await capture("lessons_mini_quiz")
	var resting_position: Vector2 = screen._answer_effect._target.position
	screen._check_quiz()
	await create_timer(0.08).timeout
	screen._check_quiz()
	await create_timer(0.65).timeout
	check(screen._answer_effect._target.position.is_equal_approx(resting_position), "Repeated error shakes restore panel position")
	await capture("lessons_quiz_incorrect")
	for answer in screen._data.correct:
		screen._pick(answer)
	screen._check_quiz()
	await create_timer(0.35).timeout
	check(screen._answer_effect._active, "Success remains visible after animation")
	await capture("lessons_quiz_correct")
	screen._on_continue()
	await settle()
	await capture("pc_home_desktop")
	screen._simulation._act("open")
	screen._simulation._read_message()
	await settle()
	await capture("lessons_desktop_sim")
	var desktop: Control = screen._simulation
	check(not desktop._inspected and not desktop._directory_found and not desktop._passed, "Reentry starts a fresh investigation")
	desktop._inspect_sender()
	desktop._open_app("Directory")
	desktop._search_directory("University IT")
	desktop._compare_domains(true)
	desktop._open_app("Inbox")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(desktop.size.x <= screen._content.size.x + 1, "Desktop has no required horizontal scrolling")
		check(root.get_visible_rect().encloses(desktop._mail_card.get_global_rect()), "Email stays visible at %s" % dimensions)
		check(root.get_visible_rect().encloses(desktop._quarantine.get_global_rect()), "Quarantine stays visible at %s" % dimensions)
		await capture("lessons_investigation_%dx%d" % [dimensions.x, dimensions.y])
		if dimensions.x == 844:
			check((desktop._pc.body.get_parent() as Control).size.y >= 100, "Phone mail keeps a usable scrolling viewport")
			desktop._pc.hide_window(false)
			await settle()
			check(root.get_visible_rect().encloses(desktop._pc.shortcuts[5].get_global_rect()), "All desktop apps fit the phone")
			for shortcut: Button in desktop._pc.shortcuts:
				var caption: Label = shortcut.get_child(1) as Label
				check(shortcut.get_global_rect().encloses(caption.get_global_rect()), "Desktop caption fits: " + caption.text)
			await capture("pc_home_phone")
			desktop._open_app("Inbox")
			await settle()
	await drag_email(desktop, desktop._task.get_global_rect().get_center())
	check(not desktop._passed, "Cancelled native drag cannot complete investigation")
	await drag_email(desktop, desktop._quarantine.get_global_rect().get_center())
	check(desktop._passed and screen._simulation_passed, "Native drag completes the validated investigation")
	check(root.gui_is_drag_successful(), "Godot accepts the native quarantine drop")
	check(root.get_visible_rect().encloses(screen._submit_button.get_global_rect()), "Result action fits the phone after quarantine")
	await capture("lessons_investigation_quarantined")
	root.size = Vector2i(960, 600)
	await settle()
	check(root.get_visible_rect().encloses(screen._submit_button.get_global_rect()), "Compact CTA remains visible")
	check(not screen._panes.visible, "Full-screen activity hides duplicate left brief")
	await capture("lessons_compact")
	screen.can_go_back()
	player.lesson_progress = {"mod_01": 2}
	screen._load_module("mod_01")
	screen._select_topic(0)
	await settle()
	var completed: Button = screen._web.nodes[0]
	check(completed.get_theme_stylebox("normal").border_color == Color("#33D17A"), "Completed topic has a green completion border")
	for step: Button in screen._web._canvas.find_children("Lesson1Step*", "Button", false, false):
		check(step.complete, "Completed topic has checked satellites")
	await capture("lessons_roadmap_completed")
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(screen._start_button.get_global_rect()), "Start visible at %s" % dimensions)
		check(root.get_visible_rect().encloses(screen._panes.get_global_rect()), "Roadmap fits without horizontal scrolling")
		await capture("lessons_path_%dx%d" % [dimensions.x, dimensions.y])
		screen._open_lesson()
		await settle()
		check(root.get_visible_rect().encloses(screen._submit_button.get_global_rect()), "Lesson CTA visible at %s" % dimensions)
		await capture("lessons_fullscreen_%dx%d" % [dimensions.x, dimensions.y])
		screen.can_go_back()
	screen.queue_free()
	picker.show()
	await settle()
	await capture("lessons_picker_compact")
	picker.queue_free()
	await process_frame
	player.free()
	print("[LESSONS WORKSPACE] topics=%d failures=%d" % [count, failures])
	quit(0 if failures == 0 else 1)
