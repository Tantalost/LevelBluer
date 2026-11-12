extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)

func _run() -> void:
	var auth: Node = root.get_node("AuthService")
	var signed_in: bool = auth._signed_in
	var participant: String = auth._participant_code
	var memory_script: GDScript = GDScript.new()
	memory_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nvar mastery_updates: int = 0\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\tpass\nfunc update_mastery(skill_id: String, is_correct: bool, params: Dictionary = {}, persist: bool = true) -> void:\n\tmastery_updates += 1\n\tsuper.update_mastery(skill_id, is_correct, params, false)\n"
	check(memory_script.reload() == OK, "Memory-only player fixture compiles")
	var player: Node = memory_script.new()
	auth._signed_in = false
	player.record_learning_event("mastery", "mod_01", {"mastery":0.0})
	check(player.learning_events.is_empty(), "Guest play does not create staff learning evidence")
	auth._signed_in = true
	auth._participant_code = "learning-records-memory-test"
	var attempt: String = player.begin_learning_attempt("mod_01", 1)
	player.finish_learning_attempt(attempt, "mod_01", 1, "failed", {"phase":"Trace", "health":0, "answered":2, "correct":0})
	check(player.learning_events[1].details.correct == 0, "Failed-stage details retain valid zero values")
	player.record_learning_event("mastery", "mod_01", {"mastery":0.0})
	check(player.learning_events.size() == 3, "Stage start, result, and zero mastery queued")
	var snapshot: Dictionary = player.get_save_data()
	var first_id: String = str(player.learning_events[0].event_id)
	player.apply_save_data(JSON.parse_string(JSON.stringify(snapshot)) as Dictionary)
	check(player.learning_events.size() == 3 and player.learning_events[0].event_id == first_id, "Save reload preserves retry identities")
	player.acknowledge_learning_events([first_id])
	check(player.learning_events.size() == 2, "Partial acknowledgment retains unsent events")
	player.acknowledge_learning_events([first_id])
	check(player.learning_events.size() == 2, "Repeated acknowledgment is harmless")
	player.apply_save_data({"mastery_matrix":{"phishing":0.4}, "cleared_stages":["mod_01:1"]})
	check(player.learning_events.is_empty(), "Legacy saves do not manufacture history")
	check(is_equal_approx(player.mastery_matrix.phishing, 0.4), "Existing mastery survives save compatibility")
	player.record_learning_event("mastery", "mod_01", {"mastery":0.2})
	player.reset_to_defaults()
	check(player.learning_events.is_empty(), "Account reset clears the in-memory queue")
	_test_checkpoint_classification(player)
	_test_account_readiness(auth, player)
	auth._signed_in = signed_in
	auth._participant_code = participant
	player.free()
	print("LEARNING_RECORDS_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_checkpoint_classification(player: Node) -> void:
	var catalog: GDScript = load("res://src/ui/screens/intel/lesson_catalog.gd")
	player.lesson_progress["mod_01"] = catalog.lesson_count("mod_01")
	var responses: Array[Dictionary] = [{"question_id": "checkpoint-item", "prompt": "Keep the code?", "options": ["No"], "selected_answer": "No", "correct_answer": "No", "correct": false}]
	var mastery_before: Dictionary = player.mastery_matrix.duplicate(true)
	check(not player.record_lesson_post_quiz("mod_01", 10, 25, responses), "10/25 stays unpassed")
	check(player.mastery_matrix == mastery_before and player.mastery_updates == 0, "Checkpoint snapshot does not apply another BKT update")
	var failed: Dictionary = player.learning_events[0]
	check(str(failed.kind) == "posttest" and str(failed.instrument) == "lesson-checkpoint-v1" and str(failed.assessment_role) == "formative" and failed.passed == false and int(failed.correct) == 10, "10/25 is a submitted formative failure")
	var first_attempt: String = str(failed.attempt_id)
	check(not player.record_lesson_post_quiz("mod_01", 10, 25), "A repeated failure remains recorded")
	check(player.learning_events.size() == 2 and str(player.learning_events[1].attempt_id) != first_attempt and str(player.learning_events[1].event_id) != str(failed.event_id) and player.learning_events[1].passed == false, "Repeated attempts keep separate identifiers")
	check(player.record_lesson_post_quiz("mod_01", 20, 25) and player.learning_events[2].passed == true and str(player.learning_events[2].assessment_role) == "formative", "20/25 is formative and passed")
	check(player.record_lesson_post_quiz("mod_01", 25, 25) and player.learning_events[3].passed == true and int(player.learning_events[3].correct) == 25, "25/25 is formative and passed")
	player.record_learning_event("mastery", "mod_01", {"mastery": 0.2})
	player.record_learning_event("pretest", "mod_01", {"answers": [{"id": "sample", "answer": false}]})
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(player.get_save_data())) as Dictionary
	player.apply_save_data(snapshot)
	var reloaded: Dictionary = player.learning_events[0]
	check(str(reloaded.assessment_role) == "formative" and reloaded.passed == false and str(reloaded.responses[0].question_id) == "checkpoint-item" and str(reloaded.attempt_id) == first_attempt, "Formative metadata and answers survive the local queue")
	var mastery_event: Dictionary = {}
	var pretest_event: Dictionary = {}
	for event: Dictionary in player.learning_events:
		if str(event.get("kind", "")) == "mastery":
			mastery_event = event
		elif str(event.get("kind", "")) == "pretest":
			pretest_event = event
	check(not mastery_event.is_empty() and not mastery_event.has("assessment_role") and not mastery_event.has("passed"), "Mastery events keep their classification")
	check(str(pretest_event.get("kind", "")) == "pretest" and not pretest_event.has("assessment_role") and not pretest_event.has("passed"), "Official pretest events keep their classification")
	var queued: int = player.learning_events.size()
	var updates: int = player.mastery_updates
	var quiz: Control = load("res://src/ui/screens/intel/lesson_post_quiz.gd").new()
	quiz.account = player
	var host: Control = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var ui: GDScript = load("res://src/ui/screens/intel/study_ui.gd")
	ui.shell(host, "MODULE CHECKPOINT", Callable()).layout.add_child(quiz)
	quiz.setup("mod_01")
	quiz.begin()
	check(quiz.review and quiz.answered == 0 and not quiz.question.is_empty(), "A passed checkpoint opens in review")
	_answer_checkpoint(quiz, true)
	check(quiz.resolved and quiz.answered == 1, "Review can submit an answer")
	quiz.answered = 24
	quiz.resolved = false
	_answer_checkpoint(quiz, true)
	check(quiz.answered == 25 and player.learning_events.size() == queued and player.mastery_updates == updates, "Review after passing creates no assessment event or BKT update")
	host.queue_free()


func _answer_checkpoint(quiz: Control, correct: bool) -> void:
	var Quiz = preload("res://src/gameplay/quiz_content.gd")
	if Quiz.is_multi(quiz.question):
		if correct and quiz.question.get("correct_indices", []).is_empty():
			quiz._pick_none()
		for i: int in quiz._choices.size():
			if int(quiz._choices[i].value) in Quiz._int_list(quiz.question.get("correct_indices", [])):
				quiz._pick(i)
		if not correct and quiz._selection.is_empty():
			quiz._pick(0)
	else:
		for i: int in quiz._choices.size():
			if Quiz.grade(quiz.question, quiz._choices[i].value) == correct:
				quiz._pick(i)
				break
	quiz.submit()


func _test_account_readiness(auth: Node, fixture: Node) -> void:
	var router: Node = root.get_node("Router")
	var save: Node = root.get_node("SaveService")
	var account: Node = root.get_node("PlayerManager")
	var old_tutorial: bool = router.is_tutorial
	var old_mastery: Dictionary = auth._mastery.duplicate(true)
	var old_pretests: Array = auth._completed_module_ids.duplicate()
	var old_token: String = auth._token
	var original: Dictionary = account.get_save_data()
	auth._token = ""
	auth._mastery = {"Phishing": 0.1, "Smishing": 0.1}
	auth._completed_module_ids = []
	router.is_tutorial = false
	account.reset_to_defaults()
	check(auth.average_mastery() == -1.0 and auth.weak_mastery_topics().is_empty(), "Synced starting priors are Not assessed, not low mastery")
	var dashboard: Control = load("res://src/ui/screens/dashboard/dashboard_screen.tscn").instantiate() as Control
	root.add_child(dashboard)
	dashboard._refresh_at_risk()
	check(not dashboard._at_risk.visible, "Dashboard hides support banner for a new account")
	check(account.tech_rank("base", "skill") == 1 and account.has_stateful_inspection, "Inspection is installed in the starter kit")
	check(account.tech_rank("base", "stats") == 0 and account.tech_rank("base", "evolution") == 0 and account.tower_capacity("base") == 2, "No earned upgrades; default two deploy slots preserved")
	check(not account.learning_support_eligible(), "Fresh account cannot receive learning-support alert")
	account.tutorial_complete = true
	check(not account.learning_support_eligible(), "Completing tutorial alone never enables alerts")
	router.is_tutorial = true
	var before: Dictionary = account.mastery_matrix.duplicate(true)
	account.update_mastery("phishing", true, {}, false)
	check(account.mastery_matrix == before and account.learning_evidence.is_empty(), "Tutorial cannot change BKT or record graded evidence")
	router.is_tutorial = false
	var first: int = 1700000000
	for i: int in 9:
		account._record_graded_response("phishing", first + i)
	check(not account.learning_support_eligible(first + 4 * 86400), "Nine answers are insufficient even after grace period")
	account._record_graded_response("phishing", first + 9)
	check(not account.learning_support_eligible(first + 4 * 86400), "Ten answers in one session are insufficient")
	account._record_graded_response("phishing", first + 1809)
	check(not account.learning_support_eligible(first + 72 * 3600 - 1), "Grace period is a full 72 hours from first graded response")
	check(account.learning_support_eligible(first + 72 * 3600), "Ten or more answers, two sessions, and 72 hours enable eligibility")
	check(not account.learning_support_eligible(first - 1), "Clock rollback cannot trigger early support")
	account.mastery_matrix["phishing"] = 0.25
	check(is_equal_approx(auth.average_mastery(), 0.25) and auth.weak_mastery_topics() == PackedStringArray(["Phishing"]), "Only assessed topics contribute to average and recommendations")
	dashboard._refresh_at_risk()
	check(dashboard._at_risk.visible and not dashboard._at_risk_sub.text.to_lower().contains("mentor"), "Eligible low-mastery student gets practice guidance, not a fictional mentor")
	account.mastery_matrix["phishing"] = 0.75
	dashboard._refresh_at_risk()
	check(not dashboard._at_risk.visible, "Improved mastery hides the support banner")
	account.mastery_matrix["phishing"] = 0.25
	account.tutorial_complete = false
	dashboard._refresh_at_risk()
	check(not dashboard._at_risk.visible, "Even old evidence cannot surface the alert during unfinished onboarding")
	account.tutorial_complete = true
	account.mastery_matrix["phishing"] = 0.40
	dashboard._refresh_at_risk()
	check(account.learning_support_eligible() and is_equal_approx(auth.average_mastery(), 0.40) and not dashboard._at_risk.visible, "Assessed average of exactly 0.40 shows no low-mastery banner")
	account.mastery_matrix["phishing"] = 0.25
	var saved_evidence: Dictionary = account.learning_evidence.duplicate(true)
	var clock: int = int(Time.get_unix_time_from_system())
	for ancient: int in [1, 1500000000]:
		account._restore_learning_evidence({"topics": {"phishing": 10}, "responses": 10, "sessions": 2, "first_at": ancient, "last_at": clock - 60})
		dashboard._refresh_at_risk()
		check(not account.learning_evidence.has("first_at") and account.has_graded_evidence("phishing") and int(account.learning_evidence.responses) == 10 and int(account.learning_evidence.sessions) == 2, "Pre-2020 first_at %d is ignored; graded evidence is kept" % ancient)
		check(not account.learning_support_eligible(clock) and not dashboard._at_risk.visible, "Pre-2020 first_at %d cannot satisfy the 72-hour rule or show the banner" % ancient)
	account.apply_save_data(JSON.parse_string(JSON.stringify(account.get_save_data())) as Dictionary)
	check(account.has_graded_evidence("phishing") and not account.learning_evidence.has("first_at"), "Evidence without a valid first_at survives save reload without gaining one")
	account.mastery_matrix["phishing"] = 0.25
	var future: int = clock + 365 * 86400
	account._restore_learning_evidence({"topics": {"phishing": 10}, "responses": 10, "sessions": 2, "first_at": future, "last_at": future})
	check(not account.learning_evidence.has("first_at") and not account.learning_evidence.has("last_at") and account.has_graded_evidence("phishing"), "Far-future first_at and last_at are ignored; graded evidence is kept")
	account._record_graded_response("phishing", clock)
	check(int(account.learning_evidence.get("first_at", 0)) == clock, "The next real graded response starts the support clock after a rejected first_at")
	check(account.learning_support_eligible(clock + 72 * 3600), "A rejected far-future timestamp does not block later legitimate eligibility")
	account._restore_learning_evidence({"topics": {"phishing": 10}, "responses": 10, "sessions": 2, "first_at": clock - 72 * 3600, "last_at": clock - 3600})
	check(account.learning_support_eligible(clock), "A valid first_at exactly 72 hours earlier keeps eligibility with 10 responses and 2 sessions")
	account._restore_learning_evidence({"topics": {"phishing": 10}, "responses": 10, "sessions": 2, "first_at": clock - 72 * 3600, "last_at": future})
	check(int(account.learning_evidence.get("first_at", 0)) == clock - 72 * 3600 and int(account.learning_evidence.get("last_at", 0)) != future, "A far-future last_at is ignored while a valid first_at is kept")
	account._restore_learning_evidence({"topics": {"phishing": 10}, "responses": 10, "sessions": 2, "first_at": clock - 5 * 60, "last_at": clock + 5 * 60})
	check(int(account.learning_evidence.get("first_at", 0)) == clock - 5 * 60 and int(account.learning_evidence.get("last_at", 0)) == clock + 5 * 60, "Timestamps within the 10-minute clock skew remain valid")
	account.learning_evidence = saved_evidence
	dashboard.free()
	var snapshot: Dictionary = account.get_save_data()
	fixture.apply_save_data(JSON.parse_string(JSON.stringify(snapshot)) as Dictionary)
	fixture.acknowledge_learning_events([])
	check(fixture.learning_support_eligible(first + 72 * 3600), "Evidence survives JSON reload and event acknowledgments")
	fixture.apply_save_data({"mastery_matrix": {"phishing": 0.2}})
	check(fixture.learning_evidence.is_empty() and not fixture.learning_support_eligible(first + 72 * 3600), "Legacy saves never manufacture response counts or age")
	fixture._restore_learning_evidence({"topics": {"phishing": "bad"}, "sessions": "bad"})
	check(fixture.learning_evidence.is_empty(), "Malformed evidence fails closed")
	account._restore_learning_evidence({"topics": {"pretexting": 2}})
	check(account.has_graded_evidence("pretexting") and not account.learning_evidence.has("first_at") and not account.learning_support_eligible(first + 72 * 3600), "Topic counts without first_at stay evidence but cannot start the support clock")
	account.apply_save_data({
		"mastery_matrix": {"phishing": 0.10, "pretexting": 0.10},
		"learning_evidence": {
			"topics": {"pretexting": 2},
			"responses": 2,
			"sessions": 1,
			"first_at": 1700000000,
			"last_at": 1700000100,
		},
	})
	auth._mastery = {
		"Phishing": 0.10, "Smishing": 0.10, "Vishing": 0.10, "Pretexting": 0.10, "Baiting": 0.10,
	}
	check(int(account.learning_evidence.get("first_at", 0)) == 1700000000, "Loader keeps the stored first_at")
	var data: GDScript = load("res://src/ui/screens/progress/progress_data.gd")
	var restored: Dictionary = data.snapshot()
	var assessed_names: Array[String] = []
	for row: Dictionary in restored.mastery:
		if bool(row.get("assessed", false)):
			assessed_names.append(str(row.get("id", "")))
	check(assessed_names == ["pretexting"], "Progress screen assesses restored Pretexting 0.10 only")
	var consistent := {
		"topics": {"phishing": 4, "pretexting": 2},
		"responses": 6,
		"sessions": 1,
		"first_at": 1700000000,
		"last_at": 1700000100,
	}
	account._restore_learning_evidence(consistent)
	check(int(account.learning_evidence.get("responses", 0)) == 6, "Loader keeps a topic-total response count")
	check(int(account.learning_evidence.get("first_at", 0)) == 1700000000 and int(account.learning_evidence.get("last_at", 0)) == 1700000100, "Loader keeps an ordered evidence interval")
	account._restore_learning_evidence({
		"topics": {"phishing": 4, "pretexting": 2},
		"responses": 4,
		"sessions": 1,
		"first_at": 1700000200,
		"last_at": 1700000100,
	})
	check(int(account.learning_evidence.get("responses", 0)) == 6 and int(account.learning_evidence.get("last_at", 0)) == 1700000200, "Loader would correct inconsistent responses and last_at")
	account.reset_to_defaults()
	auth._mastery = {"Phishing": 0.1, "Smishing": 0.1}
	auth._completed_module_ids = []
	auth._completed_module_ids = ["mod_01"]
	account.reset_to_defaults()
	check(bool(auth.progress_mastery_snapshot()[0].assessed), "A real completed pretest can legitimately assess a prior-valued estimate")
	check(not account.learning_support_eligible(), "Pretest alone cannot trigger learning support")
	auth._completed_module_ids = []
	# Use synthetic identities with no token: read-only hydration, no cloud writes.
	auth._participant_code = "readiness-regression-a"
	account._on_session_changed(true)
	account.tech_ranks = {"base": {"skill": 1, "capacity": 3, "stats": 2, "evolution": 2}}
	account.unlocked_towers.assign(["base", "scanner", "sandbox"])
	account.credits = 777
	var a_snapshot: Dictionary = account.get_save_data()
	var path_a: String = save._resolve_save_path()
	account._on_session_changed(true)
	check(account.credits == 777, "Repeated same-account sign-in signal does not erase upgrades")
	auth._participant_code = "readiness-regression-b"
	account._on_session_changed(true)
	check(save._resolve_save_path() != path_a, "Accounts resolve to distinct local save files")
	check(account.credits == 0 and account.tech_rank("base", "stats") == 0 and account.unlocked_towers == ["base"], "Direct A-to-B switch resets purchased ranks, credits, and towers")
	var b_snapshot: Dictionary = account.get_save_data()
	save._on_fetch_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(a_snapshot).to_utf8_buffer(), "readiness-regression-a")
	save._on_sync_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), "readiness-regression-a")
	check(account.get_save_data() == b_snapshot, "Late cloud responses from A cannot mutate B")
	account.apply_save_data(JSON.parse_string(JSON.stringify(a_snapshot)) as Dictionary)
	check(account.credits == 777 and account.tech_rank("base", "stats") == 2 and account.is_tower_unlocked("sandbox"), "Returning account retains its purchased upgrades through save roundtrip")
	account.apply_save_data({"mastery_matrix": {"phishing": 0.1}})
	check(account.credits == 0 and account.tech_rank("base", "stats") == 0 and not account.is_tower_unlocked("sandbox"), "Incomplete legacy snapshot cannot inherit previous account fields")
	account._on_session_changed(false)
	check(account.tech_rank("base", "skill") == 1 and account.learning_evidence.is_empty(), "Sign-out clears evidence and restores starter defaults")
	account.apply_save_data(original)
	router.is_tutorial = old_tutorial
	auth._mastery = old_mastery
	auth._completed_module_ids = old_pretests
	auth._token = old_token
