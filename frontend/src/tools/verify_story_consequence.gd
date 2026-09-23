extends SceneTree
## Regression suite for the reusable, data-driven "story_event" consequence
## system (DecisionScenarios.story_event_lines). Covers schema parsing only —
## end-to-end flow/BKT/TD/save behavior is covered by
## verify_decision_stage.gd's Module 3 Stage 1 story-consequence checks,
## since that needs a real running match.
##
## Run headless:  godot --headless --script res://src/tools/verify_story_consequence.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func _run() -> void:
	_test_absent_consequence_preserves_old_behavior()
	_test_notification_type()
	_test_status_type()
	_test_message_type()
	_test_dialogue_type_reaches_emotion_system()
	_test_array_of_events_in_order()
	_test_malformed_input_is_safe()
	_test_isolated_from_gameplay_state()

	print("STORY_CONSEQUENCE_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_absent_consequence_preserves_old_behavior() -> void:
	print("== Absent 'story_event' produces zero lines (old choices behave exactly as before) ==")
	check(DecisionScenarios.story_event_lines({}).is_empty(), "A choice with no 'story_event' key produces no lines")
	check(DecisionScenarios.story_event_lines({"label": "x", "outcome": "SAFE", "consequence": "y"}).is_empty(),
		"An ordinary authored choice (label/outcome/consequence only) is unaffected")


func _test_notification_type() -> void:
	print("== 'notification' type parses safely into title + body narration lines ==")
	var lines: Array[Dictionary] = DecisionScenarios.story_event_lines({
		"story_event": {"type": "notification", "title": "NEW LOGIN ATTEMPT", "text": "An unfamiliar device is requesting access."}
	})
	check(lines.size() == 2, "notification produces exactly a title line and a body line")
	check(str(lines[0].get("speaker", "")) == "" and str(lines[0].get("text", "")) == "NEW LOGIN ATTEMPT", "notification's first line is the title, narrated (no speaker)")
	check(str(lines[1].get("text", "")) == "An unfamiliar device is requesting access.", "notification's second line is the body text")


func _test_status_type() -> void:
	print("== 'status' type parses safely (same shape as notification, different semantic type) ==")
	var lines: Array[Dictionary] = DecisionScenarios.story_event_lines({
		"story_event": {"type": "status", "title": "ACCOUNT STATUS", "text": "SESSION ACTIVE"}
	})
	check(lines.size() == 2 and str(lines[0].get("text", "")) == "ACCOUNT STATUS" and str(lines[1].get("text", "")) == "SESSION ACTIVE",
		"status produces a title line and a state-readout line")
	var title_only: Array[Dictionary] = DecisionScenarios.story_event_lines({"story_event": {"type": "status", "title": "ONLY A TITLE"}})
	check(title_only.size() == 1, "status with no body text produces only the title line, never an empty second line")


func _test_message_type() -> void:
	print("== 'message' type reuses the same narration presentation, no new phone UI ==")
	var lines: Array[Dictionary] = DecisionScenarios.story_event_lines({
		"story_event": {"type": "message", "title": "UNKNOWN NUMBER", "text": "This is your bank. Call us back immediately."}
	})
	check(lines.size() == 2, "message produces a sender/subject line and a body line")
	check(str(lines[0].get("text", "")) == "UNKNOWN NUMBER", "message's title line reads as the sender/subject")


func _test_dialogue_type_reaches_emotion_system() -> void:
	print("== 'dialogue' type reuses the existing speaker/emotion presentation exactly ==")
	var lines: Array[Dictionary] = DecisionScenarios.story_event_lines({
		"story_event": {"type": "dialogue", "speaker": "Daniel", "text": "They're doing something right now.", "emotion": "shocked"}
	})
	check(lines.size() == 1, "dialogue produces exactly one line")
	check(str(lines[0].get("speaker", "")) == "Daniel" and str(lines[0].get("text", "")) == "They're doing something right now.",
		"dialogue line carries the authored speaker and text")
	check(str(lines[0].get("emotion", "")) == "shocked", "dialogue line carries the authored emotion, reaching the existing emotion system")
	var neutral_dialogue: Array[Dictionary] = DecisionScenarios.story_event_lines({"story_event": {"type": "dialogue", "speaker": "Mia", "text": "..."}})
	check(neutral_dialogue.size() == 1 and str(neutral_dialogue[0].get("emotion", "")) == "", "dialogue with no emotion authored leaves the field empty, defaulting to neutral at the presentation layer")


func _test_array_of_events_in_order() -> void:
	print("== A choice may author multiple story-event beats, rendered in authored order ==")
	var lines: Array[Dictionary] = DecisionScenarios.story_event_lines({
		"story_event": [
			{"type": "notification", "title": "SECURITY ACTIVITY", "text": "A new request appears."},
			{"type": "dialogue", "speaker": "Daniel", "text": "They're doing something.", "emotion": "shocked"},
		]
	})
	check(lines.size() == 3, "Two authored events (one 2-line notification, one 1-line dialogue) produce 3 lines total")
	check(str(lines[0].get("text", "")) == "SECURITY ACTIVITY", "First event's lines come first")
	check(str(lines[2].get("speaker", "")) == "Daniel" and str(lines[2].get("emotion", "")) == "shocked", "Second event's dialogue line comes after, with its emotion intact")


func _test_malformed_input_is_safe() -> void:
	print("== Malformed/unrecognized story_event data safely produces zero lines ==")
	check(DecisionScenarios.story_event_lines({"story_event": "not a dictionary or array"}).is_empty(), "A plain string 'story_event' is safely ignored")
	check(DecisionScenarios.story_event_lines({"story_event": 42}).is_empty(), "A numeric 'story_event' is safely ignored")
	check(DecisionScenarios.story_event_lines({"story_event": {"type": "unknown_type", "title": "x", "text": "y"}}).is_empty(),
		"An unrecognized 'type' safely produces no lines")
	check(DecisionScenarios.story_event_lines({"story_event": {"title": "no type field"}}).is_empty(),
		"A story_event with no 'type' at all safely produces no lines")
	check(DecisionScenarios.story_event_lines({"story_event": {"type": "dialogue", "speaker": "Daniel"}}).is_empty(),
		"A dialogue event with no text produces no lines rather than an empty line")
	check(DecisionScenarios.story_event_lines({"story_event": [{"type": "notification"}, "garbage", 5]}).is_empty(),
		"An array mixing a title-less/text-less event with garbage entries safely produces no lines")


func _test_isolated_from_gameplay_state() -> void:
	print("== The story-event system never touches BKT, decision outcomes, or progression ==")
	var forbidden: PackedStringArray = [
		"PlayerManager", "update_mastery", "mark_stage_cleared", "SaveService",
		"StageManager", "TaskManager", "pending_outcome", "bkt_correct",
	]
	var text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_scenarios.gd")
	check(not text.is_empty(), "decision_scenarios.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not text.contains(symbol), "decision_scenarios.gd's story-event code does not reference %s" % symbol)
