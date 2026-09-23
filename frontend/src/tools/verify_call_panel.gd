extends SceneTree
## Regression suite for the optional live phone-call presentation
## (DecisionScenarios.call_* + decision_call_panel.gd). Covers schema parsing
## and the reusable panel's own presentation-only behavior in isolation —
## full live-scene coexistence with dialogue/timer/story_event/emotions on
## the Module 3 Stage 1 demo is covered by verify_stage_one_live.gd, since
## that needs a real running match.
##
## Run headless:  godot --headless --script res://src/tools/verify_call_panel.gd

const CallPanel = preload("res://src/gameplay/decision/decision_call_panel.gd")

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
	_test_absent_call_preserves_old_behavior()
	_test_call_schema_parsing()
	_test_call_fallback_defaults()
	_test_call_end_story_event_reuses_story_event_lines()
	_test_isolated_from_gameplay_state()
	await _test_panel_renders_and_updates()
	await _test_mute_speaker_are_purely_local()
	await _test_end_call_marks_ended_and_stops_duration()
	await _test_end_call_disabled_unless_authored()
	await _test_reduced_motion_does_not_change_call_state()

	print("CALL_PANEL_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_absent_call_preserves_old_behavior() -> void:
	print("== Absent/disabled/malformed 'call' data all mean no call, exactly like before this system existed ==")
	check(not DecisionScenarios.has_call({}), "A threat with no 'call' key at all has no call")
	check(not DecisionScenarios.has_call({"call": {"enabled": false, "caller": "X"}}), "enabled=false has no call even with other fields present")
	check(not DecisionScenarios.has_call({"call": "not a dictionary"}), "A malformed (non-dictionary) 'call' value safely has no call")
	check(not DecisionScenarios.has_call({"call": {}}), "An empty call object has no call (enabled defaults false)")
	for threat in DecisionScenarios.get_threats("mod_01", 1):
		check(not DecisionScenarios.has_call(threat), "[Regression] Existing Module 1 Stage 1 threats remain call-free")
	for threat in DecisionScenarios.get_threats("mod_02", 1):
		check(not DecisionScenarios.has_call(threat), "[Regression] Existing Module 2 Stage 1 threats remain call-free")


func _test_call_schema_parsing() -> void:
	print("== Call schema: caller/number/status/show_duration/allow_end_call parse safely ==")
	var threat: Dictionary = {"call": {
		"enabled": true, "caller": "metro bank fraud department", "number": "+63 2 8888 1234",
		"status": "connected", "show_duration": false, "allow_end_call": true,
	}}
	check(DecisionScenarios.has_call(threat), "enabled=true is a call")
	check(DecisionScenarios.call_caller(threat) == "METRO BANK FRAUD DEPARTMENT", "Caller name is read and normalized to upper case")
	check(DecisionScenarios.call_number(threat) == "+63 2 8888 1234", "Authored number is read exactly, not reformatted")
	check(DecisionScenarios.call_status(threat) == "CONNECTED", "Status is read and normalized to upper case")
	check(not DecisionScenarios.call_show_duration(threat), "Authored show_duration=false is honored")
	check(DecisionScenarios.call_allow_end(threat), "Authored allow_end_call=true is honored")


func _test_call_fallback_defaults() -> void:
	print("== Missing individual call fields fall back safely, never a crash or blank display ==")
	var bare: Dictionary = {"call": {"enabled": true}}
	check(DecisionScenarios.call_caller(bare) == "UNKNOWN CALLER", "Missing caller falls back to UNKNOWN CALLER")
	check(DecisionScenarios.call_number(bare) == "UNKNOWN NUMBER", "Missing number falls back to UNKNOWN NUMBER — never blank, never inferring legitimacy")
	check(DecisionScenarios.call_status(bare) == "CONNECTED", "Missing status falls back to CONNECTED")
	check(DecisionScenarios.call_show_duration(bare), "Missing show_duration defaults true")
	check(not DecisionScenarios.call_allow_end(bare), "Missing allow_end_call defaults false — ending a call is opt-in, not opt-out")


func _test_call_end_story_event_reuses_story_event_lines() -> void:
	print("== call_end_story_event reuses the exact same story_event parser as a choice's own story_event ==")
	var threat: Dictionary = {"call": {"call_end_story_event": [
		{"type": "status", "title": "CALL STATUS", "text": "The line goes quiet."},
		{"type": "dialogue", "speaker": "Daniel", "text": "That's done, at least.", "emotion": "relieved"},
	]}}
	var lines: Array[Dictionary] = DecisionScenarios.call_end_story_event_lines(threat)
	check(lines.size() == 3, "A status (2 lines) + a dialogue (1 line) produce 3 lines total, same rules as choice/timer story_event")
	check(str(lines[2].get("speaker", "")) == "Daniel" and str(lines[2].get("emotion", "")) == "relieved", "Dialogue line carries speaker/emotion through, reaching the existing emotion system")
	check(DecisionScenarios.call_end_story_event_lines({}).is_empty(), "A threat with no call/call_end_story_event produces no lines")
	check(DecisionScenarios.call_end_story_event_lines({"call": {}}).is_empty(), "A call with no call_end_story_event key produces no lines")


func _test_isolated_from_gameplay_state() -> void:
	print("== Call schema/panel code never touches BKT, save, decision outcomes, or progression directly ==")
	var forbidden: PackedStringArray = [
		"PlayerManager", "update_mastery", "mark_stage_cleared", "SaveService", "StageManager", "TaskManager",
		"pending_outcome", "bkt_correct",
	]
	var scenarios_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_scenarios.gd")
	check(not scenarios_text.is_empty(), "decision_scenarios.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not scenarios_text.contains(symbol), "decision_scenarios.gd's call code does not reference %s" % symbol)
	var panel_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_call_panel.gd")
	check(not panel_text.is_empty(), "decision_call_panel.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not panel_text.contains(symbol), "decision_call_panel.gd (mute/speaker/end call) does not reference %s — structurally cannot grade BKT or pick an outcome" % symbol)


func _mount_panel() -> Control:
	var panel: Control = CallPanel.new()
	root.add_child(panel)
	await process_frame
	return panel


func _test_panel_renders_and_updates() -> void:
	print("== The panel renders caller/number/status and updates duration independently ==")
	var panel: Control = await _mount_panel()
	panel.configure({"caller": "Bank Fraud Department", "number": "PRIVATE NUMBER", "status": "connected", "show_duration": true})
	check(panel._caller_label.text == "BANK FRAUD DEPARTMENT", "Caller renders, normalized to upper case")
	check(panel._number_label.text == "PRIVATE NUMBER", "Number renders exactly as authored")
	check(panel._status_label.text == "CONNECTED", "Status renders, normalized to upper case")
	check(panel._duration_label.text == "00:00", "Duration starts at 00:00 on configure")
	panel.update_duration(7.0)
	check(panel._duration_label.text == "00:07", "Duration formats seconds as MM:SS")
	panel.update_duration(125.0)
	check(panel._duration_label.text == "02:05", "Duration formats minutes correctly past 60 seconds")
	panel.queue_free()
	await process_frame


func _test_mute_speaker_are_purely_local() -> void:
	print("== MUTE/SPEAKER toggle visual state only, with zero gameplay effect ==")
	var panel: Control = await _mount_panel()
	panel.configure({"caller": "X"})
	check(not panel.is_muted() and not panel.is_speaker_on(), "A fresh call starts unmuted, speaker off")
	panel._toggle_mute()
	check(panel.is_muted() and panel._mute_button.text == "UNMUTE", "Toggling mute flips the visual state and label")
	panel._toggle_mute()
	check(not panel.is_muted() and panel._mute_button.text == "MUTE", "Toggling mute again restores it")
	panel._toggle_speaker()
	check(panel.is_speaker_on() and panel._speaker_button.text.contains("ON"), "Toggling speaker flips the visual state and label")
	# A fresh call (e.g. the next incident) always resets both, never carrying
	# over a previous incident's muted/speaker state.
	panel.configure({"caller": "Y"})
	check(not panel.is_muted() and not panel.is_speaker_on(), "configure() resets mute/speaker for a brand-new call")
	panel.queue_free()
	await process_frame


func _test_end_call_marks_ended_and_stops_duration() -> void:
	print("== Ending the call marks it ENDED and freezes the duration display, without picking any outcome ==")
	var panel: Control = await _mount_panel()
	panel.configure({"caller": "X", "allow_end_call": true})
	# An Array, not a plain int: GDScript lambdas capture local variables by
	# value, so a plain counter incremented inside the closure would never be
	# visible out here — an Array/Dictionary is captured by reference.
	var ended_calls: Array = []
	panel.end_call_requested.connect(func() -> void: ended_calls.append(true))
	panel.update_duration(5.0)
	panel._request_end_call()
	check(ended_calls.size() == 1, "Pressing END CALL emits end_call_requested exactly once")
	panel.set_ended()
	check(panel._status_label.text == "ENDED", "set_ended() shows ENDED in text, not just a color/icon change")
	panel.update_duration(9.0)
	check(panel._duration_label.text == "00:05", "Duration stops updating once the call has ended")
	panel._request_end_call()
	check(ended_calls.size() == 1, "END CALL cannot be pressed again once already ended (no duplicate request)")
	panel.queue_free()
	await process_frame


func _test_end_call_disabled_unless_authored() -> void:
	print("== END CALL is hidden unless the threat explicitly authored allow_end_call ==")
	var panel: Control = await _mount_panel()
	panel.configure({"caller": "X"})
	check(not panel._end_button.visible, "allow_end_call defaults false — END CALL is not offered unless explicitly authored")
	panel.configure({"caller": "X", "allow_end_call": true})
	check(panel._end_button.visible, "allow_end_call=true offers END CALL")
	panel.queue_free()
	await process_frame


func _test_reduced_motion_does_not_change_call_state() -> void:
	print("== reduced_motion has no functional effect on call state (the panel has no motion to reduce) ==")
	var settings: Node = root.get_node("SettingsService")
	var reduced_motion_before: bool = settings.reduced_motion
	var panel: Control = await _mount_panel()
	settings.reduced_motion = true
	panel.configure({"caller": "X", "number": "Y", "status": "CONNECTED"})
	panel.update_duration(42.0)
	var with_reduced_motion := {"caller": panel._caller_label.text, "number": panel._number_label.text, "status": panel._status_label.text, "duration": panel._duration_label.text}
	settings.reduced_motion = false
	panel.configure({"caller": "X", "number": "Y", "status": "CONNECTED"})
	panel.update_duration(42.0)
	var without_reduced_motion := {"caller": panel._caller_label.text, "number": panel._number_label.text, "status": panel._status_label.text, "duration": panel._duration_label.text}
	check(with_reduced_motion == without_reduced_motion, "reduced_motion changes nothing about call caller/number/status/duration presentation")
	settings.reduced_motion = reduced_motion_before
	panel.queue_free()
	await process_frame
