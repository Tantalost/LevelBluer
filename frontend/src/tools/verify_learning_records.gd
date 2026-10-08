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
	player.finish_learning_attempt(attempt, "mod_01", 1, "failed")
	player.record_learning_event("mastery", "mod_01", {"mastery":0.0})
	check(player.learning_events.size() == 3, "Stage start, result, and zero mastery queued")
	var snapshot: Dictionary = player.get_save_data()
	var first_id: String = str(player.learning_events[0].event_id)
	player.apply_save_data(snapshot)
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
	auth._signed_in = signed_in
	auth._participant_code = participant
	player.free()
	print("LEARNING_RECORDS_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
