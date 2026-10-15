extends SceneTree
## All mutations target an isolated account. Never writes a participant save.
var Checkpoint: GDScript
var Catalog: GDScript
const Quiz = preload("res://src/gameplay/quiz_content.gd")
var failures: int = 0
var celebrations: int = 0


func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)

func settle() -> void:
	for i: int in 5:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/journey_" + name + ".png")

func answer(quiz: Control, correct: bool) -> void:
	if Quiz.is_multi(quiz.question):
		if correct and quiz.question.get("correct_indices", []).is_empty():
			quiz._pick_none()
		for i: int in quiz._choices.size():
			if int(quiz._choices[i].value) in Quiz._int_list(quiz.question.get("correct_indices", [])):
				quiz._pick(i)
		if not correct:
			quiz._pick(0)
			if quiz._selection.is_empty():
				quiz._pick(1)
	else:
		for i: int in quiz._choices.size():
			if Quiz.grade(quiz.question, quiz._choices[i].value) == correct:
				quiz._pick(i)
				break
	quiz.submit()

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

func _run() -> void:
	# Pin the initial landscape size; headless defaults differ from the renderer.
	root.size = Vector2i(1280, 720)
	await settle()
	root.get_node("SettingsService").text_speed = "instant"
	Checkpoint = load("res://src/ui/screens/intel/lesson_post_quiz.gd")
	Catalog = load("res://src/ui/screens/intel/lesson_catalog.gd")
	var memory_script: GDScript = GDScript.new()
	memory_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nvar writes: int = 0\nvar answers: int = 0\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\twrites += 1\nfunc update_mastery(skill_id: String, correct: bool, params: Dictionary = {}) -> void:\n\tanswers += 1\n\tvar prior: float = get_mastery(skill_id)\n\tvar post: float = _posterior(prior, correct, float(params.get(\"p_g\", P_GUESS)), float(params.get(\"p_s\", P_SLIP)))\n\tmastery_matrix[skill_id] = clampf(post + (1 - post) * float(params.get(\"p_t\", P_TRANSIT)), MIN_MASTERY, MAX_MASTERY)\nfunc complete_lesson_unit(module_id: String, total: int, _ids: Array[String]) -> void:\n\tlesson_progress[module_id] = mini(total, get_lesson_progress(module_id) + 1)\n\twrites += 1\n"
	memory_script.source_code = memory_script.source_code.replace("params: Dictionary = {}) -> void:", "params: Dictionary = {}, _persist: bool = true) -> void:")
	check(memory_script.reload() == OK, "In-memory account compiles")
	var account: Node = memory_script.new()
	check(account.can_access_lesson_module("mod_01") and not account.can_access_lesson_module("mod_02"), "Fresh account only opens Module 1")
	check(not account.record_lesson_post_quiz("mod_01", 25, 25), "Cannot pass before finishing lessons")
	account.lesson_progress["mod_01"] = 6
	check(not account.record_lesson_post_quiz("mod_01", 19, 25), "19/25 fails")
	check(not account.record_lesson_post_quiz("mod_01", 20, 24), "Incomplete attempts cannot unlock")
	check(not account.can_access_lesson_module("mod_02"), "Lesson completion alone does not unlock next module")
	check(account.record_lesson_post_quiz("mod_01", 20, 25), "20/25 passes")
	check(account.can_access_lesson_module("mod_02"), "Checkpoint opens next module")
	var snapshot: Dictionary = account.get_save_data()
	var restored: Node = memory_script.new()
	restored.apply_save_data(snapshot)
	check(restored.has_lesson_post_quiz("mod_01"), "Checkpoint round-trips through save")
	restored.apply_save_data({"lesson_progress": {"mod_03": 2}})
	check(not restored.has_lesson_post_quiz("mod_01") and restored.can_access_lesson_module("mod_03"), "Legacy progress survives; missing checkpoint data clears old account state")
	restored.free()
	account.lesson_progress.clear()
	account.lesson_post_quiz_scores.clear()
	var picker: Control = load("res://src/ui/screens/intel/lessons_screen.tscn").instantiate()
	picker.account = account
	root.add_child(picker)
	await settle()
	check(picker._cards.size() == 5 and picker._cards[1].disabled, "Timeline presents five gated modules")
	check(picker._overview.visible and not picker._detail.visible, "Initial screen shows only the timeline")
	var backdrop: Control = picker.get_node("JourneyBackdrop")
	check(backdrop.visible and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE and backdrop.focus_mode == Control.FOCUS_NONE, "Journey decoration never intercepts touch or keyboard input")
	check(not backdrop.is_processing() and backdrop.get_index() == 1, "Journey decoration is static and behind the interface")
	check(not picker._scroll.get_h_scroll_bar().visible, "Timeline scrollbar is hidden")
	verify_timeline_checkpoints(picker)
	picker._pan(1)
	await create_timer(0.4).timeout
	check(picker._scroll.scroll_horizontal > 0, "Arrow navigation reaches offscreen modules")
	picker._pan(-1)
	await create_timer(0.4).timeout
	check(picker._scroll.scroll_horizontal == 0, "Previous arrow returns to the start")
	await capture("timeline")
	root.size = Vector2i(844, 390)
	await settle()
	await capture("timeline_phone")
	verify_timeline_checkpoints(picker)
	picker._cards[0].pressed.emit()
	await create_timer(0.25).timeout
	await capture("transition_phone")
	await create_timer(0.65).timeout
	check(picker._detail.visible and not picker._overview.visible, "Module tap opens a separate detail view")
	check(not backdrop.visible, "Journey shapes do not overlap the module hologram")
	check(root.get_visible_rect().encloses(picker._tile.get_global_rect()), "Module entry fits phone")
	check(root.get_visible_rect().encloses(picker._status.get_global_rect()), "Module description fits phone")
	await capture("detail_phone")
	picker.on_resume()
	check(picker._detail.visible, "Returning from a lesson preserves module details")
	check(not picker.can_go_back(), "Back from details stays inside Lessons")
	await create_timer(0.5).timeout
	check(picker._overview.visible and not picker._detail.visible and picker.can_go_back(), "Back restores timeline before leaving Lessons")
	check(backdrop.visible, "Returning to the journey restores the shapes")
	root.size = Vector2i(1280, 720)
	await settle()
	picker._select(0)
	picker._select(0)
	await create_timer(0.9).timeout
	check(not picker._tile.disabled, "Repeated selection restores entry action")
	check(picker._ghost == null, "Rapid taps leave no animation ghost")
	await capture("detail")
	account.lesson_progress["mod_01"] = 6
	picker.on_resume()
	await settle()
	check(not picker._checkpoint.disabled, "Completed lessons enable the overview checkpoint action")
	var ready_group: Control = picker._track.get_child(0)
	check(not ready_group.get_node("Checkpoint1").disabled and ready_group.get_node("Connector").ready_for_test, "Six lessons illuminate the path to the checkpoint")
	check(picker._cards[1].disabled and not ready_group.get_node("Connector").passed, "Ready checkpoint does not unlock the next module before passing")
	picker._set_detail_visible(false)
	await settle()
	await capture("timeline_checkpoint_ready")
	var motion_preferences: Node = root.get_node("SettingsService")
	var motion_before: bool = motion_preferences.reduced_motion
	var ready_link: Control = ready_group.get_node("Connector")
	var ready_mark: Control = ready_group.get_node("Checkpoint1/CheckpointMark")
	motion_preferences.reduced_motion = true
	var link_clock: float = ready_link.clock
	var mark_clock: float = ready_mark.clock
	ready_link._process(1.0)
	ready_mark._process(1.0)
	check(ready_link.clock == link_clock and ready_mark.clock == mark_clock, "Reduced motion keeps checkpoint highlights static")
	motion_preferences.reduced_motion = false
	ready_link._process(0.5)
	ready_mark._process(0.5)
	check(ready_link.clock > link_clock and ready_mark.clock > mark_clock, "Ready checkpoint animates the incoming light and flag halo")
	motion_preferences.reduced_motion = motion_before
	account.lesson_post_quiz_scores["mod_01"] = 20
	picker.on_resume()
	await settle()
	check(not picker._cards[1].disabled and picker._track.get_child(0).get_node("Connector").passed, "Passing lights the onward connector and unlocks the next module")
	await capture("timeline_checkpoint_passed")
	account.lesson_post_quiz_scores.clear()
	picker._select(0, false)
	await create_timer(0.7).timeout
	await capture("detail_ready")
	account.lesson_progress.clear()
	picker.on_resume()
	check(picker._checkpoint.disabled, "Checkpoint remains locked until lessons complete")
	picker.can_go_back()
	picker._select(0)
	picker.can_go_back()
	await create_timer(0.9).timeout
	check(picker._ghost == null and not picker._detail.visible, "Back during transition cancels deferred animation")
	var settings: Node = root.get_node("SettingsService")
	var old_motion: bool = settings.reduced_motion
	settings.reduced_motion = true
	picker._select(0)
	check(not picker._tile.disabled and picker._ghost == null, "Reduced motion skips morph without blocking entry")
	settings.reduced_motion = old_motion
	picker.hide()
	var player: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	player.account = account
	root.add_child(player)
	player._load_module("mod_01")
	await settle()
	check(player._web.nodes.size() == 6, "Six main lesson nodes")
	check(not player._web._canvas.ready_for_test, "Incomplete lessons do not light the post-test connections")
	check(player._web._canvas.find_children("Lesson*Step*", "Button", false, false).size() == 12, "Each lesson has two satellites")
	player._open_step(1, 0)
	check(player._lesson_index == 0 and not player._in_lesson, "Future lesson is gated")
	player._open_step(0, 2)
	check(not player._in_lesson, "Simulation cannot bypass reading and quiz")
	player._open_post_quiz()
	check(not player._post_active, "Checkpoint route cannot bypass lessons")
	player._web.reveal_web()
	await create_timer(0.8).timeout
	settings.reduced_motion = true
	player._web.reveal_web()
	check(player._web._canvas.reveal == 1.0, "Reduced motion reveals the complete web immediately")
	settings.reduced_motion = old_motion
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(player._web.get_global_rect()), "Web viewport fits " + str(dimensions))
		check(root.get_visible_rect().encloses(player._start_button.get_global_rect()), "Start action fits " + str(dimensions))
		await capture("web_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	settings.text_speed = "normal"
	player._open_step(0, 0)
	check(player._revealing and player._reading_blocks[0].visible_characters == 0, "Reading starts with a progressive reveal")
	player._process(0.1)
	check(player._reading_blocks[0].visible_characters > 0, "Text advances at the configured speed")
	player._on_continue()
	check(not player._revealing and player._reading_page == 0, "First Continue reveals text without skipping the page")
	player._on_continue()
	await settle()
	check(player._reading_page == 1 and player._revealing, "Next reading page restarts progressive reveal")
	var annotated: String = ""
	for block: RichTextLabel in player._reading_blocks:
		annotated += block.text
	check(annotated.contains("[u]help@harb0r-civic.net[/u]") and annotated.contains("WHO /") and annotated.contains("PRESSURE /"), "School email highlights exact sender, request and pressure with matching callouts")
	root.size = Vector2i(844, 390)
	await settle()
	check(root.get_visible_rect().encloses(player._reveal_button.get_global_rect()), "Show All fits phone landscape")
	player._finish_reading_reveal()
	await capture("context_clues_phone")
	player._previous_page()
	settings.text_speed = "instant"
	player._process(0.1)
	check(not player._revealing and player._reading_blocks[0].visible_characters == -1, "Changing to Instant immediately reveals all reading text")
	settings.text_speed = "normal"
	settings.reduced_motion = true
	player._start_reading_reveal()
	check(not player._revealing, "Reduced motion displays reading text without animation")
	settings.reduced_motion = false
	player._start_reading_reveal()
	player.on_exit()
	check(not player._revealing, "Leaving the lesson stops text animation")
	settings.reduced_motion = old_motion
	settings.text_speed = "instant"
	root.size = Vector2i(1280, 720)
	player._open_step(0, 0)
	player._on_continue()
	player._on_continue()
	player._on_continue()
	await settle()
	var mini_before: int = account.answers
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(player._submit_button.get_global_rect()), "Mini-quiz submit fits landscape viewport")
		check(player._submit_button.disabled, "Mini-quiz requires a selected answer")
		await capture("mini_%dx%d" % [dimensions.x, dimensions.y])
	for index: int in 5:
		answer_mini(player, index < 2)
		player._check_quiz()
		if index < 4:
			player._on_continue()
	check(player._quiz_score == 2 and not player._quiz_passed and player._quiz_finished, "2/5 fails after all five questions")
	await settle()
	await capture("mini_failed_phone")
	check(account.answers == mini_before + 5, "Exactly five first-response BKT updates, including mistakes")
	player._set_phase(2)
	check(player._phase == 1 and player._simulation == null, "Failed quiz cannot enter simulation")
	player.can_go_back()
	player._open_step(0, 2)
	check(not player._in_lesson, "Simulation satellite cannot bypass failed attempt")
	player._open_step(0, 1)
	check(player._quiz_finished and player._quiz_score == 2, "Returning from path preserves failed result")
	player._on_continue()
	check(player._quiz_index == 0 and player._quiz_score == 0 and not player._quiz_finished, "Retry starts a fresh five-question attempt")
	for index: int in 5:
		answer_mini(player, index < 3)
		if index < 4:
			check(not player._quiz_passed, "Three correct does not skip the remaining questions")
			player._on_continue()
	check(player._quiz_passed and player._quiz_score == 3, "Exactly 3/5 unlocks simulation")
	await settle()
	check(root.get_visible_rect().encloses(player._submit_button.get_global_rect()), "Mini-quiz result action fits phone landscape")
	await capture("mini_passed_phone")
	root.size = Vector2i(1280, 720)
	check(account.answers == mini_before + 5, "Retry cannot farm repeated BKT updates")
	var mini_saved: Dictionary = account.get_save_data()
	var mini_restored: Node = memory_script.new()
	mini_restored.apply_save_data(mini_saved)
	check(not mini_restored.record_lesson_quiz_answer("mod_01", 0, str(player._quiz_items[0].id), true), "First responses remain deduplicated after save reload")
	check(mini_restored.answers == 0, "Reloaded repeated response leaves mastery unchanged")
	mini_restored.apply_save_data({})
	check(mini_restored.lesson_quiz_responses.is_empty(), "Account switch clears prior student's quiz evidence")
	mini_restored.free()
	player._on_continue()
	var sim: Control = player._simulation
	check(not sim._started, "Simulation begins with its mission briefing")
	await settle()
	sim._start_simulation()
	await settle()
	sim._act("open")
	sim._select_mail()
	sim._inspect_sender()
	sim._open_app("Directory")
	sim._search_directory("University IT")
	sim._compare_domains(true)
	sim._tap_quarantine()
	await settle()
	check(player._simulation_passed, "Original evidence simulation still completes")
	player._on_continue()
	player.lesson_celebrated.connect(func() -> void: celebrations += 1)
	player._finish_lesson()
	check(account.get_lesson_progress("mod_01") == 1 and player._lesson_index == 1, "Full lesson unlocks exactly one next node")
	player._finish_lesson()
	check(account.get_lesson_progress("mod_01") == 1, "Stale completion cannot increment again")
	check(celebrations == 1, "New completion celebrates once; stale completion never repeats it")
	await create_timer(0.9).timeout
	await capture("completed_path")
	account.lesson_progress["mod_01"] = 6
	player._load_module("mod_01")
	await settle()
	check(player._web._canvas.ready_for_test and not player._web._checkpoint.disabled, "All six lessons light every hub connection and enable the post-test")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		player._web.focus_current()
		await settle()
		check(player._web._scroll.get_global_rect().encloses(player._web._checkpoint.get_global_rect()), "Completed graph focuses the post-test at " + str(dimensions))
		await capture("web_ready_%dx%d" % [dimensions.x, dimensions.y])
	settings.reduced_motion = true
	player._web.celebrate(5)
	check(player._web._canvas.ready_for_test, "Reduced motion keeps completion highlight without animation")
	settings.reduced_motion = old_motion
	root.size = Vector2i(1280, 720)
	var router: Node = root.get_node("Router")
	var old_tutorial: bool = router.is_tutorial
	var ungraded_before: int = account.answers
	# Completed lesson review and the tutorial both retain the same 5-question
	# gate without recording fresh BKT evidence or completion.
	for tutorial: bool in [false, true]:
		router.is_tutorial = tutorial
		player._load_module("mod_01", not tutorial, tutorial)
		player._open_lesson()
		for page: int in 3:
			player._on_continue()
		for index: int in 5:
			answer_mini(player, true)
			if index < 4:
				player._on_continue()
		check(player._quiz_passed and player._quiz_score == 5, "Review/tutorial still requires five submitted answers")
		check(account.answers == ungraded_before, "Review/tutorial leaves mastery unchanged")
	router.is_tutorial = old_tutorial
	account.lesson_progress["mod_01"] = 0
	router.is_tutorial = true
	check(not account.record_lesson_quiz_answer("mod_01", 0, "tutorial-not-graded", true), "Account guard rejects tutorial evidence even if called directly")
	router.is_tutorial = old_tutorial
	check(not account.record_lesson_quiz_answer("mod_01", 2, "future-lesson", true), "Future lesson cannot submit evidence")
	check(not account.record_lesson_quiz_answer("mod_02", 0, "locked-module", true), "Locked module cannot submit evidence")
	player.queue_free()
	await settle()
	picker.queue_free()
	await settle()
	for module_id: String in Catalog.module_ids():
		account.lesson_progress[module_id] = 6
		account.lesson_post_quiz_scores.erase(module_id)
		var quiz: Control = Checkpoint.new()
		quiz.account = account
		var host: Control = Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		var ui: GDScript = load("res://src/ui/screens/intel/study_ui.gd")
		var shell: Dictionary = ui.shell(host, "MODULE CHECKPOINT", Callable())
		shell.layout.add_child(quiz)
		quiz.setup(module_id)
		quiz.begin()
		for item: Dictionary in quiz.pool:
			var options: Array[Dictionary] = Quiz.options(item)
			if Quiz.is_multi(item):
				for correct_index: int in Quiz._int_list(item.get("correct_indices", [])):
					check(correct_index >= 0 and correct_index < options.size(), "Every multi-select answer maps to a visible choice")
			else:
				var answerable: bool = false
				for option: Dictionary in options:
					answerable = answerable or Quiz.grade(item, option.value)
				check(answerable, "Every bank question has a selectable correct answer")
		var before: int = account.answers
		var difficulties: Dictionary = {}
		for index: int in 25:
			check(quiz.question.get("module_id", "") == module_id, "No cross-module question leakage")
			difficulties[str(quiz.question.difficulty)] = true
			if index == 0 and module_id == "mod_01":
				await settle()
				await capture("post_quiz")
				root.size = Vector2i(844, 390)
				await settle()
				check(root.get_visible_rect().encloses(quiz._action.get_global_rect()), "Post-quiz submit fits phone")
				await capture("post_quiz_phone")
				root.size = Vector2i(1280, 720)
			answer(quiz, index < 20)
			quiz.submit()
			check(account.answers == before + index + 1, "Each answer updates mastery once")
			if index < 24:
				quiz._advance()
		check(quiz.seen.size() == 25 and quiz.answered == 25, "25 unique questions per attempt")
		check(quiz.score == 20 and account.has_lesson_post_quiz(module_id), "Passing score records separate checkpoint")
		check(quiz.type_counts.size() == 8, "All eight authored question formats represented")
		check(difficulties.size() == 3, "Mixed difficulty retained")
		quiz._advance()
		await settle()
		if module_id == "mod_01":
			await capture("results")
		host.queue_free()
		await settle()
	# Review is read-only for mastery; failed runs are repeatable.
	var review: Control = Checkpoint.new()
	review.account = account
	root.add_child(review)
	review.setup("mod_01")
	review.begin()
	var before_review: int = account.answers
	answer(review, true)
	check(account.answers == before_review, "Passed-quiz review cannot farm mastery")
	review.queue_free()
	await settle()
	var pool: Array[Dictionary] = []
	for raw: Dictionary in root.get_node("ContentDB").get_module_questions("mod_01"):
		pool.append(raw)
	var lessons: Array[Dictionary] = Catalog.lessons_for("mod_01")
	var empty_used: Array[String] = []
	var easy: Dictionary = Checkpoint.select_next(pool, empty_used, {}, "easy", 3, lessons)
	var hard: Dictionary = Checkpoint.select_next(pool, empty_used, {}, "hard", 3, lessons)
	check(easy.difficulty == "easy" and hard.difficulty == "hard", "BKT band changes question difficulty while preserving lesson coverage")
	await verify_baseline(memory_script)
	account.free()
	print("[LESSON JOURNEY] failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func verify_timeline_checkpoints(picker: Control) -> void:
	for i: int in picker._cards.size():
		var group: Control = picker._track.get_child(i)
		var flag: Button = group.get_node("Checkpoint%d" % (i + 1))
		var orb: Control = picker._cards[i]
		var center: Vector2 = flag.get_global_rect().get_center()
		check(absf(center.y - orb.get_global_rect().get_center().y) <= 1.0, "Checkpoint lies on the module centerline: %s / %s" % [center, orb.get_global_rect().get_center()])
		check(not flag.get_global_rect().intersects(orb.get_global_rect()), "Checkpoint never overlaps its module")
		if i < picker._cards.size() - 1:
			var next_orb: Control = picker._cards[i + 1]
			check(absf(center.x - (orb.get_global_rect().get_center().x + next_orb.get_global_rect().get_center().x) * 0.5) <= 1.0, "Checkpoint is centered between its module and the next")
			check(not flag.get_global_rect().intersects(next_orb.get_global_rect()), "Checkpoint clears the next module")
		else:
			check(group.get_node("Connector").terminal, "Final checkpoint has no onward module branch")
			check(flag.get_global_rect().end.x <= picker._track.global_position.x + picker._track.custom_minimum_size.x, "Final checkpoint is reachable inside scroll content")
		check(flag.size.x >= 48 and flag.size.y >= 48, "Checkpoint retains a touch-sized hit target")

func verify_baseline(memory_script: GDScript) -> void:
	var account: Node = memory_script.new()
	var bank: GDScript = load("res://src/data/pretest_bank.gd")
	var answers: Array = []
	for question: Dictionary in bank._bank_for("mod_01"):
		answers.append({"id": question.id, "answer": question.answer})
	var mastery_before: Dictionary = account.mastery_matrix.duplicate(true)
	account.record_pretest_baseline("mod_01", answers)
	check(account.pretest_baseline("mod_01") == {"correct": 15, "total": 15}, "Baseline saves exact first score")
	answers[0].answer = -1
	account.record_pretest_baseline("mod_01", answers)
	check(account.pretest_baseline("mod_01").correct == 15, "Retry cannot replace the first baseline")
	check(account.mastery_matrix == mastery_before and account.answers == 0, "Storing baseline never updates BKT a second time")
	account.apply_save_data(JSON.parse_string(JSON.stringify(account.get_save_data())))
	check(account.pretest_baseline("mod_01").correct == 15, "Baseline survives JSON roundtrip")
	var picker: Control = load("res://src/ui/screens/intel/lessons_screen.tscn").instantiate()
	picker.account = account
	root.add_child(picker)
	picker._select(0, false)
	await settle()
	check(picker._baseline.text.contains("15 of 15") and picker._baseline.text.contains("not your current BKT"), "Overview separates initial knowledge from changing mastery")
	await capture("baseline_overview")
	account.apply_save_data({})
	check(account.pretest_baseline("mod_01").is_empty(), "New/legacy account never inherits another baseline")
	var auth: Node = root.get_node("AuthService")
	var prior_modules: Array = auth._completed_module_ids.duplicate()
	auth._completed_module_ids = ["mod_01"]
	picker._select(0, false)
	check(picker._baseline.text.contains("unavailable"), "Old completed pretest never invents a score")
	auth._completed_module_ids = prior_modules
	account.apply_save_data({"pretest_baselines": {"mod_01": {"correct": 20, "total": 15}}})
	check(account.pretest_baseline("mod_01").is_empty(), "Invalid baseline fails closed")
	var study: GDScript = load("res://src/ui/screens/intel/lesson_study_content.gd")
	for module_id: String in Catalog.module_ids():
		for index: int in 6:
			var data: Dictionary = study.build(module_id, index)
			var clues: Array[Dictionary] = study.context_clues(module_id, index)
			check(not clues.is_empty(), "Every lesson has contextual guidance")
			for clue: Dictionary in clues:
				check(not str(clue.quote).is_empty() and str(data.scenario).contains(str(clue.quote)) and not str(clue.note).is_empty(), "Every callout refers to text actually in that lesson's example")
	picker.queue_free()
	await settle()
	account.free()
