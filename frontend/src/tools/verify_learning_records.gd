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
	memory_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nfunc _ready() -> void:\n\tpass\nfunc _save_progress() -> void:\n\tpass\n"
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
	_test_account_readiness(auth, player)
	auth._signed_in = signed_in
	auth._participant_code = participant
	player.free()
	print("LEARNING_RECORDS_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


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
	dashboard.free()
	var snapshot: Dictionary = account.get_save_data()
	fixture.apply_save_data(JSON.parse_string(JSON.stringify(snapshot)) as Dictionary)
	fixture.acknowledge_learning_events([])
	check(fixture.learning_support_eligible(first + 72 * 3600), "Evidence survives JSON reload and event acknowledgments")
	fixture.apply_save_data({"mastery_matrix": {"phishing": 0.2}})
	check(fixture.learning_evidence.is_empty() and not fixture.learning_support_eligible(first + 72 * 3600), "Legacy saves never manufacture response counts or age")
	fixture._restore_learning_evidence({"topics": {"phishing": "bad"}, "sessions": "bad"})
	check(fixture.learning_evidence.is_empty(), "Malformed evidence fails closed")
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
