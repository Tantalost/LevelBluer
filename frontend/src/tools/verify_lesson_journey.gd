extends SceneTree
## All mutations target an isolated account. Never writes a participant save.
var Checkpoint: GDScript
var Catalog: GDScript
const Quiz = preload("res://src/gameplay/quiz_content.gd")
var failures: int = 0


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

func _run() -> void:
	await settle()
	Checkpoint = load("res://src/ui/screens/intel/lesson_post_quiz.gd")
	Catalog = load("res://src/ui/screens/intel/lesson_catalog.gd")
	var memory_script: GDScript = GDScript.new()
	memory_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nvar writes: int = 0\nvar answers: int = 0\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\twrites += 1\nfunc update_mastery(skill_id: String, correct: bool, params: Dictionary = {}) -> void:\n\tanswers += 1\n\tvar prior: float = get_mastery(skill_id)\n\tvar post: float = _posterior(prior, correct, float(params.get(\"p_g\", P_GUESS)), float(params.get(\"p_s\", P_SLIP)))\n\tmastery_matrix[skill_id] = clampf(post + (1 - post) * float(params.get(\"p_t\", P_TRANSIT)), MIN_MASTERY, MAX_MASTERY)\nfunc complete_lesson_unit(module_id: String, total: int, _ids: Array[String]) -> void:\n\tlesson_progress[module_id] = mini(total, get_lesson_progress(module_id) + 1)\n\twrites += 1\n"
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
	check(not picker._scroll.get_h_scroll_bar().visible, "Timeline scrollbar is hidden")
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
	picker._cards[0].pressed.emit()
	await create_timer(0.25).timeout
	await capture("transition_phone")
	await create_timer(0.65).timeout
	check(picker._detail.visible and not picker._overview.visible, "Module tap opens a separate detail view")
	check(root.get_visible_rect().encloses(picker._tile.get_global_rect()), "Module entry fits phone")
	check(root.get_visible_rect().encloses(picker._status.get_global_rect()), "Module description fits phone")
	await capture("detail_phone")
	picker.on_resume()
	check(picker._detail.visible, "Returning from a lesson preserves module details")
	check(not picker.can_go_back(), "Back from details stays inside Lessons")
	await create_timer(0.5).timeout
	check(picker._overview.visible and not picker._detail.visible and picker.can_go_back(), "Back restores timeline before leaving Lessons")
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
	player._open_step(0, 0)
	player._on_continue()
	player._on_continue()
	player._on_continue()
	for value: int in player._data.correct:
		player._pick(value)
	player._check_quiz()
	check(player._quiz_passed, "Original mini quiz still grades")
	player._on_continue()
	var sim: Control = player._simulation
	sim._act("open")
	sim._select_mail()
	sim._inspect_sender()
	sim._open_app("Directory")
	sim._search_directory("University IT")
	sim._compare_domains(true)
	sim._tap_quarantine()
	check(player._simulation_passed, "Original evidence simulation still completes")
	player._on_continue()
	player._finish_lesson()
	check(account.get_lesson_progress("mod_01") == 1 and player._lesson_index == 1, "Full lesson unlocks exactly one next node")
	player._finish_lesson()
	check(account.get_lesson_progress("mod_01") == 1, "Stale completion cannot increment again")
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
	account.free()
	print("[LESSON JOURNEY] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
