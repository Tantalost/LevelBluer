extends SceneTree
## In-memory account only: never modifies student saves, credits or lesson progress.
const R: GDScript = preload("res://src/gameplay/decision/stage_remediation.gd")
var failures: int = 0
var actions: Array[StringName] = []

class Account extends RefCounted:
	var remediation_state: Dictionary = {"sessions": []}
	var mastery: float = 0.3
	var grades: Array[bool] = []
	var writes: int = 0
	var ids: int = 0
	var checkpoint: Dictionary = {}
	var lesson_progress: Dictionary = {}
	var credits: int = 0
	var cleared_stages: Dictionary = {}
	var stage_tasks: int = 0
	var graded_skills: Array[String] = []
	var trace_results: Array[Dictionary] = []
	var exam_locks: Array[String] = []
	var module_1_complete: bool = false
	func record_trace_result(module_id: String, question_id: String, correct: bool) -> void:
		trace_results.append({"module": module_id, "id": question_id, "correct": correct})
	func lock_stage(module_id: String, stage: int) -> void:
		var key: String = DecisionScenarios.stage_key(module_id, stage)
		if key not in exam_locks: exam_locks.append(key)
	func unlock_stage(module_id: String, stage: int) -> void:
		exam_locks.erase(DecisionScenarios.stage_key(module_id, stage))
	func record_enemy_defeated(_kind: String) -> void:
		pass
	func learning_id() -> String:
		ids += 1
		return "test-%d" % ids
	func get_mastery(_skill: String) -> float:
		return mastery
	func update_mastery(_skill: String, correct: bool, _params: Dictionary = {}, _persist: bool = true) -> void:
		grades.append(correct)
		graded_skills.append(_skill)
		mastery = clampf(mastery + (0.05 if correct else -0.05), 0.01, 0.99)
	func save_remediation(state: Dictionary) -> void:
		remediation_state = R.restore(state)
		writes += 1
	func consume_intel_bonus_gold(value: int, _module: String) -> int:
		return value
	func has_cleared_stage(module_id: String, stage: int) -> bool:
		return cleared_stages.has(DecisionScenarios.stage_key(module_id, stage))
	func mark_stage_cleared(module_id: String, stage: int) -> void:
		cleared_stages[DecisionScenarios.stage_key(module_id, stage)] = true
	func add_credits(value: int) -> void:
		credits += value
	func record_stage_cleared() -> void:
		stage_tasks += 1
	func get_decision_stage_state(_key: String) -> Dictionary:
		return checkpoint.duplicate(true)
	func set_decision_stage_state(_key: String, state: Dictionary) -> void:
		checkpoint = state.duplicate(true)
	func clear_decision_stage_state(_key: String) -> void:
		checkpoint.clear()
	func get_story_memory_snapshot() -> Dictionary:
		return {}
	func set_story_memories(_entries: Dictionary) -> void:
		pass
	func tower_capacity(_kind: String) -> int:
		return 3
	func is_tower_unlocked(kind: String) -> bool:
		return kind == "base"
	func stats_bonus_for(_kind: String) -> Dictionary:
		return {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func observe(account: Account, id: String, outcome: String = "critical", timed_out: bool = false) -> void:
	R.observe(account, "mod_01", 1, {"threat": {"id": id}, "outcome": outcome.to_upper(), "bkt_correct": outcome == "safe"}, timed_out)

func settle() -> void:
	for frame: int in 5:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _run() -> void:
	var snapshot: String = JSON.stringify(root.get_node("PlayerManager").get_save_data())
	check(R.enabled("mod_01", 10) and R.enabled("mod_02", 10) and not R.enabled("mod_03", 1) and not R.enabled("mod_01", 11), "Only both authored ten-stage campaigns enabled")
	for id: String in R.MAPPINGS:
		if not id.begins_with("mod01_s1_"):
			continue
		var mapped: Account = Account.new()
		observe(mapped, id)
		var ticket: Dictionary = R.assign(mapped, "mod_01", 1)
		check(ticket.topic == R.MAPPINGS[id] and ticket.lesson_index == R.TOPICS[ticket.topic].lesson, "Exact authored lesson mapping " + id)
		check(ticket.question_count == 3 and ticket.support == "guided", "Low mastery gets guided practice")
		check(R.assign(mapped, "mod_01", 1).id == ticket.id, "Assignment is idempotent")
		check(R.questions(ticket.topic).size() == 3, "Every mapped topic has fresh questions")
	var account: Account = Account.new()
	account.mastery = 0.8
	observe(account, "mod01_s1_t1")
	observe(account, "mod01_s1_t1", "safe")
	check(account.grades.size() == 1, "Correction cannot grade original incident twice")
	R.assign(account, "mod_01", 1)
	check(R.latest(account, "mod_01", 1).question_count == 2, "Higher mastery gets focused practice")
	check(R.answer(account, "mod_01", 1, 0, 1).is_empty(), "Cannot answer before review")
	R.start_review(account, "mod_01", 1)
	check(not R.consume_review(account, "mod_01", 1), "Unfinished review cannot release retry gate")
	check(account.grades.size() == 1, "Reading does not update BKT")
	check(R.answer(account, "mod_01", 1, 1, 2).is_empty(), "Cannot skip a question")
	R.answer(account, "mod_01", 1, 0, 0)
	check(account.grades.size() == 2 and not account.grades.back(), "Wrong first practice answer is evidence")
	R.answer(account, "mod_01", 1, 0, 1)
	R.answer(account, "mod_01", 1, 0, 1)
	check(account.grades.size() == 2, "Corrected and double-clicked answers are not new evidence")
	var saved: Dictionary = R.restore(JSON.parse_string(JSON.stringify(account.remediation_state)))
	account.remediation_state = saved
	check(R.latest(account, "mod_01", 1).practice.m1s1_link_0_v1.solved, "Partial review resumes from persisted evidence")
	R.answer(account, "mod_01", 1, 1, 2)
	check(R.latest(account, "mod_01", 1).status == "ready" and R.pending(account, "mod_01", 1), "Completed practice still routes to explicit retry")
	account.checkpoint = {"story_hp": 1, "threat_index": 2}
	check(R.consume_review(account, "mod_01", 1) and account.checkpoint.is_empty(), "Review retry clears the failed incident checkpoint")
	check(not R.consume_review(account, "mod_01", 1), "Review retry cannot be consumed twice")
	check(not R.pending(account, "mod_01", 1), "Retry consumes review gate")
	observe(account, "mod01_s1_t1")
	check(account.grades.size() == 3, "Replayed original incident is not regraded")
	R.assign(account, "mod_01", 1)
	R.start_review(account, "mod_01", 1)
	R.answer(account, "mod_01", 1, 0, 1)
	check(account.grades.size() == 3, "Previously exposed practice remains unscored on repeat review")
	var tactical: Account = Account.new()
	observe(tactical, "mod01_s1_t1", "safe")
	check(R.assign(tactical, "mod_01", 1).is_empty(), "Combat failure alone does not diagnose a knowledge gap")
	R.mark(tactical, "mod_01", 1, "tactical_retry")
	observe(tactical, "mod01_s1_t1", "critical")
	check(not R.assign(tactical, "mod_01", 1).is_empty(), "New tactical retry still records current decisions")
	var timeout: Account = Account.new()
	observe(timeout, "mod01_s1_t1", "critical", true)
	check(timeout.grades.is_empty() and not R.assign(timeout, "mod_01", 1).is_empty(), "Timeout supplies support context, not fabricated incorrect BKT answer")
	check(R.restore({}).sessions.is_empty() and R.restore(null).sessions.is_empty(), "Legacy saves restore safely")
	var corrupt: Dictionary = account.remediation_state.duplicate(true)
	corrupt.sessions[0].practice["m1s1_link_0_v1"] = "broken"
	check(R.restore(corrupt).sessions.size() == 1, "Malformed practice row rejected without losing other session")
	corrupt = {"sessions": [{"stage": {}, "module_id": "mod_01"}]}
	check(R.restore(corrupt).sessions.is_empty(), "Malformed identity is rejected safely")
	var replay: Account = Account.new()
	R.observe(replay, "mod_01", 1, {"threat": {"id": "mod01_s1_t1"}, "outcome": "CRITICAL", "bkt_correct": false}, false, false)
	R.assign(replay, "mod_01", 1)
	R.start_review(replay, "mod_01", 1)
	R.answer(replay, "mod_01", 1, 0, 1)
	check(replay.grades.is_empty(), "Cleared-stage replay remains ungraded during review")
	test_real_account()
	test_router_gate(timeout)
	await test_review_ui(timeout)
	await test_live()
	await test_stage_two()
	test_all_content()
	await test_remaining_story_stages()
	await test_assessments()
	test_locked_review_access()
	check(account.lesson_progress.is_empty() and account.credits == 0, "Review cannot award progress or credits")
	check(JSON.stringify(root.get_node("PlayerManager").get_save_data()) == snapshot, "Verification never changes real account data")
	print("Stage remediation verification: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func test_real_account() -> void:
	var memory: GDScript = GDScript.new()
	memory.source_code = "extends \"res://src/autoload/player_manager.gd\"\nvar writes: int = 0\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\twrites += 1\n"
	check(memory.reload() == OK, "Isolated production account compiles")
	var account: Node = memory.new()
	account.mastery_matrix = {"phishing": 0.6}
	var before: float = account.get_mastery("phishing")
	R.observe(account, "mod_01", 1, {"threat": {"id": "mod01_s1_t1"}, "outcome": "CRITICAL", "bkt_correct": false}, false)
	check(account.writes == 1 and account.get_mastery("phishing") < before, "Production BKT and observation persist together once")
	R.assign(account, "mod_01", 1)
	R.observe(account, "mod_01", 2, {"threat": {"id": "mod01_stage02_incident03"}, "outcome": "RISKY", "bkt_correct": false}, false)
	R.assign(account, "mod_01", 2)
	var restored: Node = memory.new()
	restored.apply_save_data(JSON.parse_string(JSON.stringify(account.get_save_data())))
	check(R.pending(restored, "mod_01", 1), "Production save/load preserves review gate")
	check(R.pending(restored, "mod_01", 2) and R.latest(restored, "mod_01", 2).topic == "sharing_identity", "Production save/load preserves Stage 2 alongside Stage 1")
	check(is_equal_approx(restored.get_mastery("phishing"), account.get_mastery("phishing")), "Evidence and BKT survive same save")
	restored.apply_save_data({})
	check(not R.pending(restored, "mod_01", 1), "Loading a different/legacy account cannot retain review gate")
	restored.free()
	account.free()

func test_router_gate(account: Account, stage: int = 1, module_id: String = "mod_01") -> void:
	# Keep the production _begin_gameplay implementation. Replace only external
	# dependencies and screen creation in memory so no participant save is touched.
	var script: GDScript = GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://src/autoload/screen_router.gd").replace("PlayerManager", "_test_account").replace("StageManager.access_reason", "_test_access_reason").replace("func _push_now(", "func _production_push_now(")
	script.source_code += "\nvar _test_account: Object\nvar destination: Dictionary = {}\nfunc _test_access_reason(_stage: int, _module: String) -> String:\n\treturn \"\"\nfunc _push_now(id: StringName, args: Dictionary = {}) -> void:\n\tdestination = {\"screen\": id, \"args\": args}\n"
	check(script.reload() == OK, "Isolated router compiles")
	var router: Node = script.new()
	router._test_account = account
	var context: MatchContext = MatchContext.stage_one_live()
	context.stage_id = stage
	context.module_id = module_id
	router._begin_gameplay(stage - 1, context)
	check(router.destination.get("screen") == &"lesson_player" and router.destination.args.remediation_stage == stage, "Central deployment gate routes pending review to exact stage")
	check(router._gameplay == null, "Pending review does not instantiate another gameplay scene")
	router.free()

func test_review_ui(account: Account) -> void:
	var screen: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	screen.account = account
	root.add_child(screen)
	screen.on_enter({"module_id": "mod_01", "remediation_stage": 1})
	await settle()
	check(screen._lesson_index == 2 and not screen._panes.visible and not screen._can_complete(), "Review opens exact lesson, never ordinary completion")
	await capture("remediation_read")
	screen._on_continue()
	await settle()
	check(screen._submit_button.disabled, "Must select an answer")
	await capture("remediation_question")
	screen._choose_review_answer(0)
	screen._on_continue()
	await settle()
	check(screen._review_feedback and account.grades.size() == 1, "Real UI commits one first answer")
	screen.queue_free()
	await settle()
	screen = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	screen.account = account
	root.add_child(screen)
	screen.on_enter({"module_id": "mod_01", "remediation_stage": 1})
	await settle()
	screen._on_continue()
	check(screen._review_question == 0 and account.grades.size() == 1, "Reopened screen resumes unsolved question without regrading")
	screen._choose_review_answer(1)
	screen._on_continue()
	screen._on_continue()
	screen._choose_review_answer(2)
	screen._on_continue()
	screen._on_continue()
	screen._choose_review_answer(0)
	screen._on_continue()
	screen._on_continue()
	await settle()
	check(screen._review_step == "done" and account.grades.size() == 3, "UI completes 3-question review without correction inflation")
	await capture("remediation_complete")
	check(R.consume_review(account, "mod_01", 1), "UI completion releases retry")
	var retry: Control = load("res://src/gameplay/decision/stage_one_live.tscn").instantiate()
	retry.account = account
	retry.tasks = account
	retry.match_context = MatchContext.stage_one_live()
	root.add_child(retry)
	retry.set_process(false)
	check(retry.story_hp == 3 and retry.decision.threat_index == 0, "Actual retried stage begins at first incident with 3 HP")
	retry.queue_free()
	screen.queue_free()
	await settle()

func test_live() -> void:
	var account: Account = Account.new()
	var game: Control = load("res://src/gameplay/decision/stage_one_live.tscn").instantiate()
	game.account = account
	game.tasks = account
	game.match_context = MatchContext.stage_one_live()
	root.add_child(game)
	game.set_process(false)
	await settle()
	# Commit through the real controller; force only the terminal battle loss.
	game.decision.choose_by_outcome(DecisionScenarios.OUTCOME_CRITICAL)
	game._commit_decision()
	check(account.grades.size() == 1, "Live controller routes original decision through evidence policy")
	var data: Dictionary = game._result_data(false)
	check(data.get("remediation", false) and data.retry_label == "REVIEW LESSON", "Live defeat summary routes to targeted lesson")
	var overlay: CanvasLayer = load("res://src/ui/screens/victory/base_defeat_overlay.gd").new()
	root.add_child(overlay)
	overlay.configure(data)
	overlay.finish_reveal()
	overlay.action_requested.connect(func(action: StringName) -> void: actions.append(action))
	await settle()
	await capture("remediation_defeat")
	overlay._choose_button(0)
	overlay._choose_button(0)
	check(actions == [&"remediation"], "Defeat primary action dispatches once")
	overlay.queue_free()
	game.queue_free()
	await settle()

func _mount_stage_two(account: Account) -> Control:
	var game: Control = load("res://src/gameplay/decision/stage_one_live.tscn").instantiate()
	game.account = account
	game.tasks = account
	game.match_context = MatchContext.stage_one_live()
	game.match_context.stage_id = 2
	root.add_child(game)
	game.set_process(false)
	game.advance_briefing(4)
	return game

func _read_story(game: Control) -> void:
	var overlay: Control = game.story_overlay
	var lines: int = maxi(1, overlay._lines.size() - overlay._line_index)
	for line: int in lines:
		if overlay._typing:
			overlay._continue()
		if not overlay._mail.is_empty() and not overlay._mail_read:
			overlay._open_mail()
			overlay._phone._unlock()
			overlay._phone._navigate("mail")
			overlay._phone._open_message()
			overlay._close_mail()
		overlay._continue()

func _inspect_stage_two(game: Control) -> void:
	var overlay: Control = game.story_overlay
	if overlay._mode == &"story":
		_read_story(game)
	if not overlay._dialogue_done:
		_read_story(game)
	check(not game.decision_timer_active, "Stage 2 clock waits for phone evidence")
	overlay._open_phone_investigation()
	var phone: Control = overlay._phone
	phone._unlock()
	for item: Dictionary in phone._items:
		var app: String = str(item.get("phone_app", "mail"))
		var id: String = str(item.id)
		phone._navigate(app)
		if app == "mail":
			phone._open_message()
			phone._inspect(id)
		else:
			for card: Dictionary in phone._data.get(app, []):
				if str(card.get("evidence_id", "")) == id:
					phone._open_card(card)
					break
		for field: int in item.get("fields", []).size():
			phone._reveal_field(id, field)
	check(phone.is_complete(), "Stage 2 inspected all actual phone references")
	phone._finish()
	check(game.decision_timer_active, "Stage 2 clock starts after phone evidence")

func _stage_two_choice(game: Control, outcome: String) -> void:
	_inspect_stage_two(game)
	var choices: Array = game.decision.current_threat_for_display().choices
	for index: int in choices.size():
		if choices[index].outcome == outcome:
			game.story_overlay._choose(index)
			if game.phase != "Results":
				_read_story(game)
			return
	check(false, "Stage 2 outcome exists: " + outcome)

func test_stage_two() -> void:
	var topics: Array[String] = ["project_link", "urgent_identity", "sharing_identity"]
	var lessons: Array[int] = [2, 1, 1]
	var threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 2)
	check(threats.size() == 3, "Stage 2 mapping covers all three authored incidents")
	var cross: Account = Account.new()
	observe(cross, "mod01_s1_t1")
	R.assign(cross, "mod_01", 1)
	var original: Dictionary = R.latest(cross, "mod_01", 1)
	R.observe(cross, "mod_01", 2, {"threat": threats[0], "outcome": "CRITICAL", "bkt_correct": false}, false)
	R.assign(cross, "mod_01", 2)
	check(R.latest(cross, "mod_01", 1) == original and R.pending(cross, "mod_01", 2), "Stage 2 cannot overwrite Stage 1 evidence or gate")
	var corrupt: Dictionary = cross.remediation_state.duplicate(true)
	corrupt.sessions[1].topic = "link"
	check(R.restore(corrupt).sessions.size() == 1, "Reject a Stage 1 topic injected into a Stage 2 review")
	var wrong: Account = Account.new()
	R.observe(wrong, "mod_01", 1, {"threat": threats[0], "outcome": "CRITICAL", "bkt_correct": false}, false)
	check(wrong.grades.is_empty() and wrong.remediation_state.sessions.is_empty(), "Reject a threat from a different stage before grading")
	var ids: Array[String] = []
	for topic: String in R.TOPICS:
		if not R.ORIGINAL_TOPICS.has(topic):
			continue
		for question: Dictionary in R.questions(topic):
			check(str(question.id) not in ids, "Practice IDs are unique across both stages")
			ids.append(str(question.id))
	for incident: int in threats.size():
		var focused: Account = Account.new()
		focused.mastery = 0.8
		R.observe(focused, "mod_01", 2, {"threat": threats[incident], "outcome": "CRITICAL", "bkt_correct": false}, false)
		R.assign(focused, "mod_01", 2)
		check(R.latest(focused, "mod_01", 2).question_count == 2, "Every Stage 2 topic offers focused practice at higher mastery")
		R.start_review(focused, "mod_01", 2)
		for question_index: int in 2:
			R.answer(focused, "mod_01", 2, question_index, int(R.questions(topics[incident])[question_index].correct))
		check(R.latest(focused, "mod_01", 2).status == "ready", "Focused Stage 2 practice completes after exactly two questions")
		check(R.consume_review(focused, "mod_01", 2), "Focused practice releases Stage 2 retry")
		var graded: int = focused.grades.size()
		R.observe(focused, "mod_01", 2, {"threat": threats[incident], "outcome": "CRITICAL", "bkt_correct": false}, false)
		R.assign(focused, "mod_01", 2)
		R.start_review(focused, "mod_01", 2)
		R.answer(focused, "mod_01", 2, 0, int(R.questions(topics[incident])[0].correct))
		check(focused.grades.size() == graded, "Stage 2 repeated incident and practice do not regrade exposed items")
	for incident: int in threats.size():
		var account: Account = Account.new()
		account.cleared_stages["mod_01:1"] = true
		account.lesson_progress = {"mod_01": 6}
		var game: Control = _mount_stage_two(account)
		for prior: int in incident:
			_stage_two_choice(game, "SAFE")
		for failure: int in 4:
			_stage_two_choice(game, "CRITICAL")
			check(game.story_hp == 2 - failure, "Stage 2 preserves its four-failure HP rule")
			if failure < 3:
				check(not R.pending(account, "mod_01", 2), "A single failed choice does not prematurely force review")
		check(game.phase == "Results" and account.credits == 0, "Fourth failure ends Stage 2 without rewards")
		var ticket: Dictionary = R.latest(account, "mod_01", 2)
		check(ticket.get("topic") == topics[incident] and ticket.get("lesson_index") == lessons[incident], "Actual failure selects correct Stage 2 topic and lesson")
		check(account.grades.size() == incident + 1, "Four repeated failures grade original incident only once")
		test_router_gate(account, 2)
		game.queue_free()
		await settle()
		await _complete_stage_two_review(account, topics[incident], lessons[incident])
		check(account.cleared_stages == {"mod_01:1": true} and account.lesson_progress == {"mod_01": 6} and account.credits == 0, "Stage 2 review preserves Stage 1 completion, lessons and currency")
		check(R.consume_review(account, "mod_01", 2), "Completed Stage 2 review releases restart")
		game = _mount_stage_two(account)
		check(game.story_hp == 3 and game.decision.threat_index == 0 and game.story_overlay._mode == &"story", "Stage 2 retry returns to its own opening, not the failed incident")
		game.queue_free()
		await settle()
	await _stage_two_outcomes()

func _complete_stage_two_review(account: Account, topic: String, lesson: int) -> void:
	var screen: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	screen.account = account
	root.add_child(screen)
	screen.on_enter({"module_id": "mod_01", "remediation_stage": 2})
	await settle()
	check(screen._lesson_index == lesson and screen._progress_label.text.contains("STAGE 2"), "Stage 2 review displays its own lesson and stage")
	await capture("stage2_review_" + topic)
	screen._on_continue()
	var count: int = int(R.latest(account, "mod_01", 2).question_count)
	var grades_before: int = account.grades.size()
	for index: int in count:
		var question: Dictionary = R.questions(topic)[index]
		check(str(question.id).begins_with("m1s2_"), "Stage 2 practice IDs cannot collide with Stage 1")
		if index == 0:
			screen._choose_review_answer((int(question.correct) + 1) % 3)
			screen._on_continue()
			screen._on_continue()
			screen.queue_free()
			await settle()
			account.remediation_state = R.restore(JSON.parse_string(JSON.stringify(account.remediation_state)))
			screen = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
			screen.account = account
			root.add_child(screen)
			screen.on_enter({"module_id": "mod_01", "remediation_stage": 2})
			screen._on_continue()
			await settle()
			check(screen._review_question == 0, "Stage 2 reload resumes unresolved practice")
		await capture("stage2_practice_" + topic + "_" + str(index))
		screen._choose_review_answer(int(question.correct))
		screen._on_continue()
		screen._on_continue()
		await settle()
	check(screen._review_step == "done" and account.grades.size() == grades_before + count, "Stage 2 correction/reload cannot inflate BKT")
	check(screen._submit_button.text == "RETRY STAGE 2", "Completion action names Stage 2")
	await capture("stage2_review_complete_" + topic)
	screen.queue_free()
	await settle()

func _stage_two_outcomes() -> void:
	var account: Account = Account.new()
	var game: Control = _mount_stage_two(account)
	_inspect_stage_two(game)
	game.advance_decision_timer(45.1)
	check(game.story_hp == 2 and account.grades.is_empty(), "Stage 2 timeout costs HP but does not fabricate a BKT answer")
	_read_story(game)
	for failure: int in 3:
		_stage_two_choice(game, "CRITICAL")
	check(R.pending(account, "mod_01", 2) and account.grades.is_empty(), "Timed-out item stays ungraded and still supplies targeted support")
	game.queue_free()
	await settle()
	account = Account.new()
	game = _mount_stage_two(account)
	_stage_two_choice(game, "RISKY")
	check(game.story_hp == 3 and game.decision.awaiting_breach_deploy(), "Stage 2 risky choice keeps HP and offers containment")
	game._consequence_continued()
	game._finish(false)
	check(R.pending(account, "mod_01", 2) and account.grades.size() == 1, "Failed containment after risky decision routes to review without a second penalty")
	game.queue_free()
	await settle()
	account = Account.new()
	game = _mount_stage_two(account)
	_stage_two_choice(game, "RISKY")
	game._consequence_continued()
	game.begin_defend()
	game._wave_cleared()
	check(game.phase == "Incident" and account.grades.size() == 1 and not R.pending(account, "mod_01", 2), "Successful Stage 2 containment returns to story without extra BKT or mandatory review")
	game._story_continued()
	for incident: int in 2:
		_stage_two_choice(game, "SAFE")
	game._story_continued()
	check(account.has_cleared_stage("mod_01", 2) and R.latest(account, "mod_01", 2).status == "cleared", "Risky-then-recovered Stage 2 can clear without a pending review")
	game.queue_free()
	await settle()
	account = Account.new()
	game = _mount_stage_two(account)
	for incident: int in 3:
		_stage_two_choice(game, "SAFE")
	game._story_continued()
	check(game.phase == "Results" and account.has_cleared_stage("mod_01", 2) and not R.pending(account, "mod_01", 2), "All-safe Stage 2 clear has no remediation gate")
	check(account.credits == 50 + game.gold and account.stage_tasks == 1, "Successful Stage 2 retains existing rewards exactly once")
	game.queue_free()
	await settle()

func test_all_content() -> void:
	var canonical_questions: Dictionary = {}
	var catalog: GDScript = load("res://src/ui/screens/intel/lesson_catalog.gd")
	for topic: String in R.TOPICS:
		var data: Dictionary = R.TOPICS[topic]
		var module_id: String = str(data.get("module", "mod_01"))
		check(int(data.lesson) < catalog.lesson_count(module_id), "Real lesson exists: " + topic)
		var bank: Array[Dictionary] = R.questions(topic)
		check(bank.size() == 3, "Three authored practice items: " + topic)
		for question: Dictionary in bank:
			check(question.options.size() == 3 and int(question.correct) >= 0 and int(question.correct) < 3 and not str(question.feedback).is_empty(), "Complete practice answer/feedback: " + topic)
			if canonical_questions.has(question.id):
				check(canonical_questions[question.id] == question, "A shared practice ID always has identical content")
			canonical_questions[question.id] = question
	var covered: int = 0
	for module_id: String in ["mod_01", "mod_02"]:
		for stage: int in range(1, 11):
			var items: Array[Dictionary] = DecisionScenarios.get_threats(module_id, stage)
			if stage == 10:
				if module_id == "mod_01":
					for question: Dictionary in root.get_node("ContentDB").get_module_questions(module_id):
						items.append(question)
				else:
					for round_data: Dictionary in DecisionScenarios.get_stage(module_id, stage).rounds:
						for question: Dictionary in round_data.questions: items.append(question)
			check(items.size() == (80 if module_id == "mod_01" else 15) if stage == 10 else items.size() == 3, "Actual source item count: %s:%d" % [module_id, stage])
			for item: Dictionary in items:
				covered += 1
				check(R.MAPPINGS.has(str(item.id)), "Explicit mapping: " + str(item.id))
				if not R.MAPPINGS.has(str(item.id)): continue
				for mastery: float in [0.2, 0.8]:
					var account: Account = Account.new()
					account.mastery = mastery
					R.observe(account, module_id, stage, {"threat": item, "outcome": "CRITICAL", "bkt_correct": false}, false)
					var ticket: Dictionary = R.assign(account, module_id, stage)
					check(not ticket.is_empty(), "Assign source item: " + str(item.id))
					if ticket.is_empty(): continue
					check(ticket.topic == R.MAPPINGS[item.id] and ticket.lesson_index == R.TOPICS[ticket.topic].lesson, "Exact source-to-lesson mapping")
					check(ticket.question_count == (3 if mastery < 0.4 else 2), "Guided/focused threshold for each mapped item")
					check(account.graded_skills == [R.skill(module_id)], "Correct module's mastery only")
					R.start_review(account, module_id, stage)
					var bank: Array[Dictionary] = R.questions(str(ticket.topic))
					R.answer(account, module_id, stage, 0, (int(bank[0].correct) + 1) % 3)
					account.remediation_state = R.restore(JSON.parse_string(JSON.stringify(account.remediation_state)))
					for index: int in int(ticket.question_count):
						R.answer(account, module_id, stage, index, int(bank[index].correct))
					check(account.grades.size() == 1 + int(ticket.question_count), "Reload and correction grade first response only")
					check(R.latest(account, module_id, stage).status == "ready", "Every mapped item reaches ready")
					check(R.consume_review(account, module_id, stage), "Every mapped item releases its own retry")
					check(not R.consume_review(account, module_id, stage), "Cannot consume review twice")
	check(covered == 149 and R.MAPPINGS.size() == covered, "54 story decisions plus 95 possible exam questions, no invented IDs")
	check(canonical_questions.size() == 81, "18 original + 63 new unique practice questions")
	# Same transfer question in a later module is not fresh evidence.
	var shared: Account = Account.new()
	for entry: Array in [["mod_01", 4, "mod01_stage04_incident01"], ["mod_02", 2, "mod02_stage02_incident02"]]:
		var module_id: String = str(entry[0])
		var stage: int = int(entry[1])
		R.observe(shared, module_id, stage, {"threat": {"id": entry[2]}, "outcome": "CRITICAL", "bkt_correct": false}, false)
		var ticket: Dictionary = R.assign(shared, module_id, stage)
		R.start_review(shared, module_id, stage)
		for index: int in int(ticket.question_count):
			R.answer(shared, module_id, stage, index, int(R.questions(str(ticket.topic))[index].correct))
		check(R.consume_review(shared, module_id, stage), "Shared concept review completes in both modules")
	check(shared.grades.size() == 5, "Three shared questions grade once globally plus two distinct story decisions")
	var invalid: Account = Account.new()
	R.observe(invalid, "mod_01", 1, {"threat": {"id": "mod02_stage01_incident01"}, "outcome": "CRITICAL", "bkt_correct": false}, false)
	check(invalid.grades.is_empty(), "Cross-module observation rejected before grading")
	print("All 20 stage mappings and 81 unique practice items verified.")

func _mount_campaign(account: Account, module_id: String, stage: int) -> Control:
	var path: String = "res://src/gameplay/assessment_live.tscn" if stage == 10 else "res://src/gameplay/decision/stage_one_live.tscn"
	var game: Control = load(path).instantiate()
	game.account = account
	game.tasks = account
	game.match_context = MatchContext.stage_one_live()
	game.match_context.module_id = module_id
	game.match_context.stage_id = stage
	root.add_child(game)
	game.set_process(false)
	return game

func _complete_review(account: Account, module_id: String, stage: int, render: bool = false) -> void:
	var ticket: Dictionary = R.latest(account, module_id, stage)
	var screen: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	screen.account = account
	root.add_child(screen)
	screen.on_enter({"module_id": module_id, "remediation_stage": stage})
	await settle()
	check(screen._lesson_index == int(ticket.lesson_index) and screen._progress_label.text.begins_with("MODULE " + module_id.trim_prefix("mod_")), "Review shows correct module/lesson")
	check(not screen._can_complete(), "Review cannot award lesson progress")
	if render: await capture("review_%s_s%d" % [module_id, stage])
	screen._on_continue()
	for index: int in int(ticket.question_count):
		var question: Dictionary = R.questions(str(ticket.topic))[index]
		if render and index == 0:
			await settle()
			await capture("review_practice_%s_s%d" % [module_id, stage])
		screen._choose_review_answer(int(question.correct))
		screen._on_continue()
		screen._on_continue()
	await settle()
	check(screen._review_step == "done" and screen._submit_button.text == "RETRY STAGE %d" % stage, "Review completes with stage-specific retry")
	if render: await capture("review_done_%s_s%d" % [module_id, stage])
	screen.queue_free()
	await settle()

func test_remaining_story_stages() -> void:
	for module_id: String in ["mod_01", "mod_02"]:
		for stage: int in range(3 if module_id == "mod_01" else 1, 10):
			var threats: Array[Dictionary] = DecisionScenarios.get_threats(module_id, stage)
			for incident: int in threats.size():
				var account: Account = Account.new()
				var game: Control = _mount_campaign(account, module_id, stage)
				# Existing investigation UI is independently tested. Here drive the actual
				# controller at each incident; inject only terminal combat loss.
				game.decision.threat_index = incident
				check(not game.decision.choose_by_outcome("RISKY").is_empty(), "Authored risky decision exists")
				game._commit_decision()
				check(game.story_hp == 3 and account.grades == [false], "Risky preserves HP and records one knowledge response")
				game._finish(false)
				var ticket: Dictionary = R.latest(account, module_id, stage)
				check(ticket.get("topic") == R.MAPPINGS[threats[incident].id] and R.pending(account, module_id, stage), "Actual containment loss maps exact incident")
				check(account.credits == 0 and account.cleared_stages.is_empty(), "Story failure awards no clear or credits")
				test_router_gate(account, stage, module_id)
				game.queue_free()
				await settle()
				await _complete_review(account, module_id, stage, incident == 2 and stage == 9)
				check(R.consume_review(account, module_id, stage), "Review releases same story stage")
				game = _mount_campaign(account, module_id, stage)
				check(game.story_hp == 3 and game.decision.threat_index == 0, "Retry resets to own opening with 3 HP")
				game.queue_free()
				await settle()
			# Safe-only combat defeat, all-safe completion, critical and timeout evidence.
			for outcome: String in ["SAFE", "CRITICAL", "TIMEOUT", "CLEAR"]:
				var account: Account = Account.new()
				var game: Control = _mount_campaign(account, module_id, stage)
				game.decision.choose_by_outcome("SAFE" if outcome in ["SAFE", "CLEAR"] else "CRITICAL")
				game._commit_decision(outcome == "TIMEOUT")
				var count: int = account.grades.size()
				game._result_data(outcome == "CLEAR")
				check(account.grades.size() == count, "Result does not grade twice")
				check(R.pending(account, module_id, stage) == (outcome in ["CRITICAL", "TIMEOUT"]), "Only unsafe/timeout failure triggers knowledge review")
				if outcome == "TIMEOUT": check(account.grades.is_empty(), "Timeout is support evidence, not a fabricated answer")
				if outcome == "CLEAR": check(account.has_cleared_stage(module_id, stage), "Normal clear still works")
				game.queue_free()
				await settle()
			print("Story recovery verified: %s stage %d / all 3 incidents" % [module_id, stage])

func _exam_answer(game: Control, correct: bool, expired: bool = false) -> void:
	var quiz: GDScript = preload("res://src/gameplay/quiz_content.gd")
	if expired:
		game.resolve_answer(true)
		return
	if quiz.is_multi(game.question):
		game.selected_answers.clear()
		if correct:
			for option: Dictionary in quiz.options(game.question):
				if int(option.value) in quiz._int_list(game.question.get("correct_indices", [])):
					game.choose_answer(int(option.value))
		else:
			game.choose_answer(999)
	else:
		for option: Dictionary in quiz.options(game.question):
			if quiz.grade(game.question, option.value) == correct:
				game.choose_answer(option.value)
				break
	game.resolve_answer()

func _exam_case(game: Control) -> void:
	if not game.college: return
	_read_story(game)
	_read_story(game)
	var overlay: Control = game.story_overlay
	overlay._open_phone_investigation()
	var laptop: Control = overlay._phone
	laptop._unlock()
	for item: Dictionary in laptop._items:
		var id: String = str(item.id)
		var app: String = str(item.get("phone_app", "mail"))
		laptop._navigate(app)
		if app == "mail":
			laptop._open_message()
			laptop._inspect(id)
		else:
			for card: Dictionary in laptop._data.get(app, []):
				if str(card.get("evidence_id", "")) == id:
					laptop._open_card(card)
					break
		for field: int in item.get("fields", []).size(): laptop._reveal_field(id, field)
	# The actual laptop evidence gate must resolve before scored questions.
	check(laptop.is_complete(), "College exam evidence pack completed")
	laptop._finish()
	if not overlay._dialogue_done: _read_story(game)
	game._college_case_confirmed(0)
	check(game.phase == "Trace", "College case starts scored questions only after evidence")

func test_assessments() -> void:
	for module_id: String in ["mod_01", "mod_02"]:
		for mode: String in ["fail", "pass", "timeout", "combat"]:
			var account: Account = Account.new()
			var game: Control = _mount_campaign(account, module_id, 10)
			game.start_assessment()
			for wave: int in 3:
				_exam_case(game)
				for index: int in 5:
					var should_miss: bool = mode in ["fail", "timeout"] and wave == 0 and index < 4
					_exam_answer(game, not should_miss, mode == "timeout" and should_miss)
					var count: int = account.grades.size()
					game.resolve_answer(true)
					check(account.grades.size() == count, "Duplicate exam submit cannot grade twice")
					game.continue_question()
				check(game.phase == "Build", "Five exam questions lead to defense")
				game.begin_defend()
				if mode == "combat":
					game._finish(false)
					break
				game._wave_cleared()
			if mode == "pass" and game.college:
				_read_story(game)
			check(game.phase == "Results", "Assessment reaches terminal result")
			var score: int = game.correct_answers
			var total: int = game.answered
			check(score == (11 if mode in ["fail", "timeout"] else (5 if mode == "combat" else 15)), "Original formal exam score preserved")
			check(account.trace_results.size() == total, "Formal answer history preserved")
			check(account.grades.size() == total - (4 if mode == "timeout" else 0), "Exam BKT grades first actual responses, not timeout placeholders")
			if mode in ["fail", "timeout"]:
				check(R.pending(account, module_id, 10) and account.exam_locks == [module_id + ":10"], "Failed assessment gates exact module")
				test_router_gate(account, 10, module_id)
				game._advance_case_review()
				check(account.exam_locks.size() == 1, "Old case-review action cannot unlock targeted review")
				account.exam_locks.append("mod_03:10")
				# Router normally tears down gameplay before opening review. Keep this
				# fixture alive only to assert its score, without covering the review UI.
				game.hud.result_overlay.hide()
				await _complete_review(account, module_id, 10, mode == "fail")
				check(game.correct_answers == score and game.answered == total and account.trace_results.size() == total and account.cleared_stages.is_empty(), "Practice never rewrites exam results or grants a pass")
				check(R.consume_review(account, module_id, 10) and account.exam_locks == ["mod_03:10"], "Ready review clears only its assessment lock")
			else:
				check(not R.pending(account, module_id, 10) and account.exam_locks.is_empty(), "Pass or safe-only combat failure needs no knowledge review")
				check(account.has_cleared_stage(module_id, 10) == (mode == "pass"), "Only passing exam and surviving waves clears Stage 10")
			game.queue_free()
			await settle()
			game = _mount_campaign(account, module_id, 10)
			check(game.answered == 0 and game.wave == 0 and game.waves_completed == 0 and game.phase == "Briefing", "Stage 10 retry starts full assessment, never the failed wave")
			game.queue_free()
			await settle()
			print("Assessment recovery verified: %s / %s" % [module_id, mode])

func test_locked_review_access() -> void:
	# Production StageManager policy with only the account dependency replaced.
	var memory: GDScript = GDScript.new()
	memory.source_code = "extends \"res://src/autoload/player_manager.gd\"\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\tpass\nfunc is_module_deploy_unlocked(_module: String) -> bool:\n\treturn true\nfunc has_completed_lesson(_lesson: String) -> bool:\n\treturn true\n"
	check(memory.reload() == OK, "Isolated real account for exam gate compiles")
	var account: Node = memory.new()
	account.max_stage_cleared_by_module = {"mod_01": 9, "mod_02": 9}
	account.locked_stages = {"mod_02:10": true}
	var script: GDScript = GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://src/autoload/stage_manager.gd").replace("PlayerManager", "account") + "\nvar account: Object\n"
	check(script.reload() == OK, "Isolated StageManager compiles")
	var manager: Node = script.new()
	manager.account = account
	check(not manager.access_reason(10, "mod_02").is_empty(), "Legacy exam lock without review remains locked")
	R.observe(account, "mod_02", 10, {"threat": {"id": "mod02_final_08"}, "outcome": "CRITICAL", "bkt_correct": false}, false)
	R.assign(account, "mod_02", 10)
	check(manager.access_reason(10, "mod_02").is_empty(), "Pending review remains reachable through stage selector despite exam lock")
	account.max_stage_cleared_by_module["mod_02"] = 7
	check(not manager.access_reason(10, "mod_02").is_empty(), "Review cannot bypass preceding-stage requirement")
	var save: Dictionary = JSON.parse_string(JSON.stringify(account.get_save_data()))
	var restored: Node = memory.new()
	restored.apply_save_data(save)
	check(R.pending(restored, "mod_02", 10) and restored.is_stage_locked("mod_02", 10), "Real save/load preserves review and exam lock together")
	check(restored.get_mastery("phishing") == account.get_mastery("phishing"), "Smishing review leaves phishing mastery unchanged")
	manager.free()
	account.free()
	restored.free()
