extends SceneTree
## Question timeout = Game Over with no BKT change. Runs the real LevelManager
## (in-memory loss payout) and the real assessment controller (in-memory
## account). Never writes the user save. No GUI automation.
##
## Run headless:  godot --headless --path frontend --script res://src/tools/verify_question_timeout.gd
const Context = preload("res://src/gameplay/match_context.gd")
const PHASE_QUIZ := 1
const PHASE_GAME_OVER := 4
var failures := 0

class Account extends RefCounted:
	var bkt: Array = []
	var credits := 0
	var clears := 0
	var trace_results: Array[Dictionary] = []
	var exam_locks: Array[String] = []
	var unlocked := ["base"]
	func record_enemy_defeated(_kind: String) -> void:
		pass
	func record_trace_result(module_id: String, question_id: String, correct: bool) -> void:
		trace_results.append({"module": module_id, "id": question_id, "correct": correct})
	func lock_stage(module_id: String, stage_id: int) -> void:
		exam_locks.append("%s:%d" % [module_id, stage_id])
	func unlock_stage(_module_id: String, _stage_id: int) -> void:
		pass
	func get_story_memory_snapshot() -> Dictionary:
		return {}
	func set_story_memories(_entries: Dictionary) -> void:
		pass
	func consume_intel_bonus_gold(value: int, _module: String) -> int:
		return value
	func has_cleared_stage(_module_id: String, _stage: int) -> bool:
		return false
	func get_decision_stage_state(_key: String) -> Dictionary:
		return {}
	func set_decision_stage_state(_key: String, _state: Dictionary) -> void:
		pass
	func clear_decision_stage_state(_key: String) -> void:
		pass
	func update_mastery(skill: String, correct: bool, _params: Dictionary = {}) -> void:
		bkt.append([skill, correct])
	func tower_capacity(_kind: String) -> int:
		return 3
	func is_tower_unlocked(kind: String) -> bool:
		return kind in unlocked
	func stats_bonus_for(_kind: String) -> Dictionary:
		return {}
	func mark_stage_cleared(_module_id: String, _id: int) -> void:
		clears += 1
	func add_credits(value: int) -> void:
		credits += value
	func record_stage_cleared() -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	await _check_level_manager_timeout()
	await _check_assessment_timeout()
	print("[QUESTION TIMEOUT] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _check_level_manager_timeout() -> void:
	print("== LevelManager stage quiz timeout ==")
	var router: Node = root.get_node("Router")
	var player: Node = root.get_node("PlayerManager")
	router.is_tutorial = false
	router.active_module_id = "mod_04"
	router.active_stage_index = 0
	var probe: GDScript = GDScript.new()
	probe.source_code = "extends \"res://src/tools/defeat_test_manager.gd\"\nvar bkt_calls: int = 0\nfunc _record_bkt(_skill_id: String, _is_correct: bool, _params: Dictionary = {}) -> void:\n\tbkt_calls += 1\n"
	check(probe.reload() == OK, "In-memory BKT-counting manager compiles")
	var level: Node = load("res://src/gameplay/level_base.tscn").instantiate()
	var manager: Node = level.get_node("LevelManager")
	manager.set_script(probe)
	root.add_child(level)
	await _frames(3)
	var saved_matrix: Dictionary = (player.mastery_matrix as Dictionary).duplicate(true)
	var old_credits: int = player.credits
	manager.change_phase(PHASE_QUIZ)
	check(manager.current_phase == PHASE_QUIZ and not (manager.current_question as Dictionary).is_empty(), "Quiz phase loaded a question")
	var skill: String = manager._current_skill_id()
	player.mastery_matrix[skill] = 0.80
	var asked: int = manager.exam_questions_asked
	manager._quiz_time_left = 0.0
	manager._on_quiz_time_expired()
	check(manager.current_phase == PHASE_GAME_OVER, "Timeout enters the existing GAME_OVER phase")
	check(manager.test_awards == 1, "Timeout runs the existing loss flow once")
	check(manager.bkt_calls == 0, "Timeout never reaches the BKT recorder (update_mastery not executed)")
	check(float(player.mastery_matrix[skill]) == 0.80, "Mastery stays exactly 0.80 after a timeout")
	check(manager.exam_questions_asked == asked, "Timeout is not counted as an answered question")
	check(not manager._quiz_modal.visible, "Timeout does not continue to another question")
	manager._on_quiz_time_expired()
	check(manager.test_awards == 1 and manager.bkt_calls == 0, "A repeated expiry cannot re-run the loss flow or grade")
	player.mastery_matrix = saved_matrix
	check(player.credits == old_credits, "Test did not mutate the wallet")
	level.queue_free()
	await _frames(2)
	Engine.time_scale = 1.0


func _check_assessment_timeout() -> void:
	print("== Final assessment question timeout ==")
	var scene: PackedScene = load("res://src/gameplay/assessment_live.tscn") as PackedScene
	var context: MatchContext = Context.stage_one_live()
	context.stage_id = 10
	var account: Account = Account.new()
	var game: Control = _mount(scene, account, context)
	game.start_assessment()
	check(game.phase == "Trace" and game.answered == 0, "Assessment opens its first question")
	game.time_left = 0.0
	game._process(0.016)
	check(game.phase == "Results", "Timeout ends the assessment through the existing failure result")
	check(account.bkt.is_empty(), "Timeout never calls update_mastery")
	check(account.trace_results.is_empty() and game.answered == 0, "Timeout is not graded as a wrong answer")
	check(account.clears == 0, "Timeout never clears the stage")
	game.resolve_answer(true)
	check(account.bkt.is_empty() and game.phase == "Results", "A late expiry cannot grade after Game Over")
	game.queue_free()
	await _frames(2)

	account = Account.new()
	game = _mount(scene, account, context)
	game.start_assessment()
	game.time_left = 0.0
	_pick(game, true)
	check(game.phase == "Results" and account.bkt.is_empty(), "Deadline beats a queued correct submit without grading")
	game.queue_free()
	await _frames(2)

	account = Account.new()
	game = _mount(scene, account, context)
	game.start_assessment()
	_pick(game, false)
	check(account.bkt == [["phishing", false]], "A submitted wrong answer still updates BKT once")
	game.continue_question()
	_pick(game, true)
	check(account.bkt.size() == 2 and account.bkt[1] == ["phishing", true], "A submitted correct answer still updates BKT")
	check(game.phase == "Trace", "Submitted answers continue the exam normally")
	game.queue_free()
	await _frames(2)


func _mount(scene: PackedScene, account: Account, context: MatchContext) -> Control:
	var game: Control = scene.instantiate()
	game.match_context = context
	game.account = account
	game.tasks = account
	root.add_child(game)
	game.set_process(false)
	game.advance_briefing(4)
	return game


func _pick(game: Control, want_correct: bool) -> void:
	var quiz: GDScript = preload("res://src/gameplay/quiz_content.gd")
	if quiz.is_multi(game.question) and want_correct:
		for index: Variant in game.question.correct_indices:
			game.choose_answer(int(index))
	else:
		for option: Dictionary in quiz.options(game.question):
			if quiz.grade(game.question, option.value) == want_correct:
				game.choose_answer(option.value)
				break
	game.resolve_answer()
