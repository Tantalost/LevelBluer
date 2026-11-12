extends SceneTree
## In-memory validation only. Never invokes the save/finish operation.
var failures := 0
var investigation_passes: int = 0

func answer_mini(screen: Control, correct: bool) -> void:
	var item: Dictionary = screen._quiz_items[screen._quiz_index]
	if correct:
		for index: int in item.correct:
			screen._pick(index)
	else:
		for index: int in item.options.size():
			if index not in item.correct:
				screen._pick(index)
				break
	screen._check_quiz()

const SUCCESS_OPENER: String = "(?m)(^\\s*|[.!?]\\s+)(Correct|Right|Exactly|Yes)\\b"
# Wrong options whose authored debriefs describe neither outcome; content review pending.
const UNMATCHED_DEBRIEFS: Dictionary = {"mod01_cc_02": [2], "mod02_cc_02": [2], "mod05_cc_07": [0]}

func success_wording(text: String) -> bool:
	var pattern: RegEx = RegEx.create_from_string(SUCCESS_OPENER)
	return pattern.search(text.replace("Correct response:", "")) != null

func test_consequence_feedback() -> void:
	var quiz = load("res://src/gameplay/quiz_content.gd")
	var total: int = 0
	var wrong_options: int = 0
	for module_id: String in ["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"]:
		for raw: Dictionary in root.get_node("ContentDB").get_module_questions(module_id):
			if str(raw.get("type_id", "")) != "consequence_choice":
				continue
			total += 1
			var id: String = str(raw.id)
			var answer: int = int(raw.answer_index)
			var mapping: Dictionary = raw.get("debrief_for_option", {}) as Dictionary
			check(not mapping.is_empty() and not mapping.has(str(answer)), "Explicit debrief mapping excludes the safe answer: " + id)
			check(quiz.explanation(raw, true, answer) == "SECURE", "Correct consequence feedback unchanged: " + id)
			if answer == 2:
				check(mapping == {"0": "click_debrief", "1": "ignore_debrief"}, "Positional convention holds when the safe answer is last: " + id)
			for option: int in (raw.options as Array).size():
				if option == answer:
					continue
				wrong_options += 1
				var note: String = quiz.explanation(raw, false, option)
				check(not note.is_empty() and note != "MISS" and note != "SECURE", "Wrong consequence option has feedback: %s/%d" % [id, option])
				if mapping.has(str(option)):
					var key: String = str(mapping[str(option)])
					check(key in ["click_debrief", "ignore_debrief"] and note == str(raw[key]).strip_edges(), "Mapped debrief shown: %s/%d" % [id, option])
				else:
					check(option in (UNMATCHED_DEBRIEFS.get(id, []) as Array), "Only reviewed options lack a debrief: %s/%d" % [id, option])
					check(note == "Safer choice: %s." % str(raw.options[answer]).trim_suffix("."), "Unmatched option names the safe choice: %s/%d" % [id, option])
			if id == "mod03_cc_02":
				check(quiz.explanation(raw, false, 1) == str(raw.click_debrief) and quiz.explanation(raw, false, 2) == str(raw.ignore_debrief), "mod03_cc_02 pairs each wrong option with its own outcome")
			if id == "mod04_cc_05":
				check(quiz.explanation(raw, false, 1) == str(raw.ignore_debrief) and quiz.explanation(raw, false, 2) == str(raw.click_debrief), "mod04_cc_05 pairs each wrong option with its own outcome")
			var unmapped: Dictionary = raw.duplicate(true)
			unmapped.erase("debrief_for_option")
			if answer == 2:
				check(quiz.explanation(unmapped, false, 0) == str(raw.click_debrief).strip_edges(), "Positional fallback kept for last-position answers: " + id)
			else:
				check(quiz.explanation(unmapped, false, 1 if answer == 0 else 0).begins_with("Safer choice: "), "No positional guess when the safe answer moved: " + id)
	check(total == 50 and wrong_options == 100, "All 50 consequence questions and 100 wrong options checked")

func test_mini_feedback_contract() -> void:
	var catalog = load("res://src/ui/screens/intel/lesson_catalog.gd")
	var study = load("res://src/ui/screens/intel/lesson_study_content.gd")
	var trust_items: int = 0
	for module_id: String in catalog.module_ids():
		var bank: Dictionary = {}
		for raw: Dictionary in root.get_node("ContentDB").get_module_questions(module_id):
			bank[str(raw.id)] = raw
		for index: int in catalog.lesson_count(module_id):
			var mini: Array[Dictionary] = study.mini_quiz(module_id, index)
			var lesson: Dictionary = study.build(module_id, index)
			check(mini.size() == study.MINI_COUNT and str(mini[0].feedback) == str(lesson.feedback), "Lesson-authored feedback preserved: %s/%d" % [module_id, index])
			for item: Dictionary in mini:
				check(item.module_id == module_id and item.has("bkt") and item.correct.size() >= 1, "Mini item keeps key, module and BKT: " + str(item.id))
				var wrong: String = study.quiz_feedback(item, false)
				var right: String = study.quiz_feedback(item, true)
				check(not success_wording(wrong), "Wrong answer has no success wording: %s -> %s" % [item.id, wrong])
				check(not right.is_empty(), "Correct answer keeps feedback: " + str(item.id))
				if bank.has(item.id):
					var raw: Dictionary = bank[item.id]
					var neutral: String = str(raw.get("explanation", "")).strip_edges()
					if not neutral.is_empty():
						check(right == neutral and wrong == neutral, "Neutral explanation used for both results: " + str(item.id))
					if str(raw.type_id) == "trust_verdict":
						trust_items += 1
	check(trust_items == 15, "All 15 mini-quiz trust verdict items checked (%d)" % trust_items)
	check(study.MINI_COUNT == 5 and study.MINI_PASS == 3, "Mini quiz stays 3/5")

func test_mini_feedback_flow() -> void:
	var verdict_explanation: String = ""
	for raw: Dictionary in root.get_node("ContentDB").get_module_questions("mod_01"):
		if str(raw.id) == "mod01_tv_03":
			verdict_explanation = str(raw.get("explanation", "")).strip_edges()
	check(not verdict_explanation.is_empty(), "mod01_tv_03 has a neutral explanation")
	var learner: Node = load("res://src/autoload/player_manager.gd").new()
	learner.lesson_progress = {"mod_01": 3}
	var lesson: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	lesson.account = learner
	root.add_child(lesson)
	lesson._load_module("mod_01")
	lesson._select_topic(3)
	lesson._open_lesson()
	for page: int in 3:
		lesson._on_continue()
	await settle()
	check(lesson._phase == 1 and str(lesson._quiz_items[1].id) == "mod01_tv_03", "Mod 1 lesson 4 asks a trust verdict second")
	answer_mini(lesson, true)
	lesson._on_continue()
	answer_mini(lesson, false)
	check(lesson._status_label.text.begins_with("Not quite.") and not success_wording(lesson._status_label.text), "Wrong trust verdict shows no success wording: " + lesson._status_label.text)
	for remaining: int in 3:
		lesson._on_continue()
		answer_mini(lesson, remaining == 2)
	check(lesson._quiz_finished and not lesson._quiz_passed and lesson._quiz_score == 2, "2/5 still fails the mini quiz")
	var cards: String = ""
	for node: Node in lesson._content.find_children("*", "Label", true, false):
		cards += (node as Label).text + "\n"
	check(cards.contains("REVISIT QUESTION 2") and not success_wording(cards), "Revisit cards show no success wording")
	var responses: String = var_to_str(learner.lesson_quiz_responses)
	var mastery: String = var_to_str(learner.mastery_matrix)
	var steps: int = learner._unconfirmed_bkt_log.size()
	check((learner.lesson_quiz_responses.get("mod_01", {}) as Dictionary).size() == 5 and steps == 5, "One BKT step per first response (responses=%d steps=%d)" % [(learner.lesson_quiz_responses.get("mod_01", {}) as Dictionary).size(), steps])
	lesson._on_continue()
	for question: int in 5:
		if question > 0:
			lesson._on_continue()
		answer_mini(lesson, true)
		if question == 1:
			check(lesson._status_label.text.begins_with("Correct.") and lesson._status_label.text.contains(verdict_explanation), "Correct trust verdict keeps its explanation")
	check(lesson._quiz_passed, "Retry can pass")
	check(var_to_str(learner.lesson_quiz_responses) == responses and var_to_str(learner.mastery_matrix) == mastery and learner._unconfirmed_bkt_log.size() == steps, "Retry adds no BKT update or evidence")
	lesson.queue_free()
	await process_frame
	learner.free()

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
	root.get_node("SettingsService").text_speed = "instant"
	var fixture: GDScript = GDScript.new()
	fixture.source_code = "extends \"res://src/autoload/player_manager.gd\"\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\tpass\nfunc update_mastery(_skill: String, _correct: bool, _params: Dictionary = {}, _official: bool = true) -> void:\n\tpass\n"
	check(fixture.reload() == OK,"Isolated fixture compiles")
	var player: Node = fixture.new()
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
			var mini: Array[Dictionary] = study.mini_quiz(id, index)
			check(mini.size() == 5, "Five curated questions: %s/%d" % [id, index])
			if mini.size() != 5:
				quit(1)
				return
			var unique: Dictionary = {}
			for item: Dictionary in mini:
				check(not unique.has(item.id) and item.module_id == id, "Unique questions stay in their module")
				unique[item.id] = true
				check(not str(item.feedback).is_empty() and not item.correct.is_empty(), "Every question has an explanation and answer")
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
			check(not screen._quiz_resolved, "Empty submission does not consume a question")
			var first_item: Dictionary = screen._quiz_items[0]
			if bool(first_item.multi) and first_item.correct.size() > 1:
				screen._pick(int(first_item.correct[0]))
				screen._check_quiz()
				check(screen._quiz_score == 0, "Partial multi-select earns no point")
			else:
				answer_mini(screen, false)
			check(not screen._quiz_passed, "Wrong answer cannot pass")
			check(screen._answer_effect._active and screen._answer_effect._ink == screen.Feedback.ERROR, "Wrong quiz shows red feedback")
			screen._check_quiz()
			check(screen._quiz_score == 0, "Repeated submit cannot change the first answer")
			for question_index: int in range(1, 5):
				screen._on_continue()
				answer_mini(screen, true)
				if question_index < 4:
					check(not screen._quiz_passed, "Must answer all five even after reaching three correct")
			check(screen._quiz_passed and screen._quiz_score == 4, "4/5 passes: %s/%d" % [id, index])
			check(screen._answer_effect._ink == screen.Feedback.SUCCESS and not screen._answer_effect._moving, "Correct quiz replaces error with green and stops shake")
			screen._on_continue()
			check(not screen._answer_effect._active, "Phase change clears quiz feedback")
			var sim = screen._simulation
			if id == "mod_01":
				check(is_instance_valid(sim._briefing) and not sim._started and sim._pc == null, "Each Module 1 simulation waits at its mission briefing")
				check(not str(content.simulation_briefing.mission).is_empty() and not str(content.simulation_briefing.why).is_empty(), "Briefing explains the task and its purpose")
				sim._act("open")
				sim._act("report")
				sim._open_app("Inbox")
				check(not sim._opened and not sim._passed and sim._pc == null, "Briefing cannot start apps or grant completion")
				for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
					root.size = dimensions
					await settle()
					check(root.get_visible_rect().encloses(sim._start_button.get_global_rect()), "Briefing start action stays visible in landscape")
					check(sim.size.x <= screen._content.size.x + 1, "Briefing has no horizontal overflow")
					await capture("briefing_%d_%dx%d" % [index + 1, dimensions.x, dimensions.y])
				root.size = Vector2i(1280, 720)
				sim._start_button.pressed.emit()
				var first_pc: Control = sim._pc
				sim._start_simulation()
				check(sim._started and sim._pc == first_pc and not screen._simulation_passed, "Start is idempotent and never awards completion")
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
						if app == "File Sandbox":
							var attachment: Button = sim._pc.body.find_child("InspectAttachmentFile", true, false)
							attachment.pressed.emit()
							check(sim._file_selected and not sim._passed, "File properties open without execution or credit")
							sim._act("unsafe")
							check(sim._pc._overlay.visible and sim._pc._alert_body.text.contains("FINE_NOTICE.PDF.exe"), "Sandbox warning identifies the attempted file")
							await capture("lesson_terminal_file_warning")
							sim._pc._overlay.hide()
						await capture("pc_lesson_4_" + app.replace(" ", "_"))
				sim._pc.hide_window(true)
				check(sim._pc.home.visible and sim._pc.active_app.is_empty(), "Close returns to desktop")
			else:
				check(not sim._pc_mode, "Other modules retain their existing simulations")
				check(sim._pc.home.visible and sim._pc.case_app == content.domain.app, "Case desktop presents the module's app")
				sim._pc.shortcuts[0].pressed.emit()
				check(sim._pc.window.visible and sim._opened and not sim._inspected, "Opening a case is separate from inspection")
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
	player.lesson_quiz_sessions.clear()
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
	answer_mini(screen, false)
	await create_timer(0.08).timeout
	screen._check_quiz()
	await create_timer(0.65).timeout
	check(screen._answer_effect._target.position.is_equal_approx(resting_position), "Repeated error shakes restore panel position")
	await capture("lessons_quiz_incorrect")
	for question_index: int in range(1, 5):
		screen._on_continue()
		answer_mini(screen, true)
	await create_timer(0.35).timeout
	check(screen._answer_effect._active, "Success remains visible after animation")
	await capture("lessons_quiz_correct")
	screen._on_continue()
	await settle()
	check(not screen._simulation._started, "Reentry shows the briefing again")
	screen._simulation._start_button.pressed.emit()
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
				var caption: Label = shortcut.find_children("*", "Label", true, false)[0] as Label
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
	test_consequence_feedback()
	test_mini_feedback_contract()
	await test_mini_feedback_flow()
	player.free()
	print("[LESSONS WORKSPACE] topics=%d failures=%d" % [count, failures])
	quit(0 if failures == 0 else 1)
