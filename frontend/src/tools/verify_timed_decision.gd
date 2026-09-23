extends SceneTree
## Regression suite for optional authored countdown decisions
## (DecisionScenarios.has_timer/timer_* + DecisionStageController.choose_by_outcome).
## Covers schema parsing and the deterministic controller-level commit path
## only — full live-scene flow/pacing/save/accessibility behavior is covered
## by verify_stage_one_live.gd's Module 3 Stage 1 timed-demo checks, since
## that needs a real running match.
##
## Run headless:  godot --headless --script res://src/tools/verify_timed_decision.gd

const Controller = preload("res://src/gameplay/decision/decision_stage_controller.gd")

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
	_test_untimed_is_the_default()
	_test_timer_schema_parsing()
	_test_timeout_outcome_fallback()
	_test_timeout_story_event_reuses_story_event_lines()
	_test_choose_by_outcome_is_deterministic_regardless_of_shuffle()
	_test_choose_by_outcome_supports_all_three_outcomes_generically()
	_test_choose_by_outcome_guards_like_choose()
	_test_timer_isolated_from_gameplay_state()

	print("TIMED_DECISION_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_untimed_is_the_default() -> void:
	print("== Untimed is the overwhelming default: absent/disabled/malformed timer data all mean no timer ==")
	check(not DecisionScenarios.has_timer({}), "A threat with no 'timer' key at all has no timer")
	check(not DecisionScenarios.has_timer({"timer": {"enabled": false, "seconds": 10}}), "enabled=false has no timer even with other fields present")
	check(not DecisionScenarios.has_timer({"timer": "not a dictionary"}), "A malformed (non-dictionary) 'timer' value safely has no timer")
	check(not DecisionScenarios.has_timer({"timer": {}}), "An empty timer object has no timer (enabled defaults false)")
	# Real, already-authored Module 1/2 threats must be unaffected.
	for threat in DecisionScenarios.get_threats("mod_01", 1):
		check(not DecisionScenarios.has_timer(threat), "[Regression] Existing Module 1 Stage 1 threats remain untimed")
	for threat in DecisionScenarios.get_threats("mod_02", 1):
		check(not DecisionScenarios.has_timer(threat), "[Regression] Existing Module 2 Stage 1 threats remain untimed")


func _test_timer_schema_parsing() -> void:
	print("== Timer schema: seconds/label/enabled parse safely ==")
	var threat: Dictionary = {"timer": {"enabled": true, "seconds": 12, "label": "DECIDE BEFORE THE TRANSFER PROCESSES"}}
	check(DecisionScenarios.has_timer(threat), "enabled=true with a positive duration is timed")
	check(is_equal_approx(DecisionScenarios.timer_seconds(threat, 99.0), 12.0), "Authored seconds is read exactly")
	check(DecisionScenarios.timer_label(threat) == "DECIDE BEFORE THE TRANSFER PROCESSES", "Authored label is read exactly")
	check(DecisionScenarios.timer_label({}) == "", "A threat with no label authors an empty string, not a crash")
	check(is_equal_approx(DecisionScenarios.timer_seconds({"timer": {"enabled": true, "seconds": -5}}, 20.0), 20.0),
		"A non-positive authored duration safely falls back to the caller's default")
	check(is_equal_approx(DecisionScenarios.timer_seconds({"timer": {"enabled": true}}, 20.0), 20.0),
		"A missing 'seconds' field falls back to the caller's default")


func _test_timeout_outcome_fallback() -> void:
	print("== timeout_outcome defaults to RISKY and rejects invalid values ==")
	check(DecisionScenarios.timer_timeout_outcome({"timer": {"timeout_outcome": "SAFE"}}) == "SAFE", "SAFE is honored when authored")
	check(DecisionScenarios.timer_timeout_outcome({"timer": {"timeout_outcome": "CRITICAL"}}) == "CRITICAL", "CRITICAL is honored when authored")
	check(DecisionScenarios.timer_timeout_outcome({"timer": {"timeout_outcome": "risky"}}) == "RISKY", "Case-insensitive authoring is normalized")
	check(DecisionScenarios.timer_timeout_outcome({"timer": {}}) == "RISKY", "No authored timeout_outcome defaults to RISKY (pressure-induced hesitation)")
	check(DecisionScenarios.timer_timeout_outcome({"timer": {"timeout_outcome": "PANIC"}}) == "RISKY", "An invalid timeout_outcome safely falls back to RISKY, never a crash or empty outcome")


func _test_timeout_story_event_reuses_story_event_lines() -> void:
	print("== timeout_story_event reuses the exact same story_event parser as a choice's own story_event ==")
	var threat: Dictionary = {"timer": {"timeout_story_event": [
		{"type": "status", "title": "CALL STATUS", "text": "The caller remains connected while Daniel hesitates."},
		{"type": "dialogue", "speaker": "Daniel", "text": "I waited too long.", "emotion": "worried"},
	]}}
	var lines: Array[Dictionary] = DecisionScenarios.timer_timeout_story_event_lines(threat)
	check(lines.size() == 3, "A status (2 lines) + a dialogue (1 line) produce 3 lines total, same rules as choice story_event")
	check(str(lines[0].get("text", "")) == "CALL STATUS", "Status title line comes first")
	check(str(lines[2].get("speaker", "")) == "Daniel" and str(lines[2].get("emotion", "")) == "worried", "Dialogue line carries speaker/emotion through, reaching the existing emotion system")
	check(DecisionScenarios.timer_timeout_story_event_lines({}).is_empty(), "A threat with no timer/timeout_story_event produces no lines")
	check(DecisionScenarios.timer_timeout_story_event_lines({"timer": {}}).is_empty(), "A timer with no timeout_story_event key produces no lines")


func _test_choose_by_outcome_is_deterministic_regardless_of_shuffle() -> void:
	print("== choose_by_outcome() always resolves the SAME authored choice, independent of shuffled display order ==")
	var threats: Array[Dictionary] = [{
		"id": "synthetic",
		"choices": [
			{"label": "critical option", "outcome": "CRITICAL"},
			{"label": "safe option", "outcome": "SAFE"},
			{"label": "first risky option", "outcome": "RISKY"},
			{"label": "second risky option", "outcome": "RISKY"},
		],
	}]
	var chosen_labels: Dictionary = {}
	for attempt in 30:
		var controller := Controller.new()
		controller.setup("mod_test", 1, threats)
		controller.ensure_display_order(4)
		# Force a fresh shuffle every attempt so a real spread of display
		# orders is actually exercised, not just whatever setup() happened
		# to produce once.
		controller.display_order.shuffle()
		var result: Dictionary = controller.choose_by_outcome("RISKY")
		check(not result.is_empty(), "choose_by_outcome() finds a RISKY choice regardless of shuffle (attempt %d)" % attempt)
		chosen_labels[str(result.get("choice", {}).get("label", ""))] = true
	check(chosen_labels.size() == 1 and chosen_labels.has("first risky option"),
		"Across many shuffles, the SAME original choice ('first risky option') is always the one chosen — never the other RISKY option, never shuffle-dependent")


func _test_choose_by_outcome_supports_all_three_outcomes_generically() -> void:
	print("== choose_by_outcome() works generically for SAFE/RISKY/CRITICAL, not just RISKY ==")
	var threats: Array[Dictionary] = [{
		"id": "synthetic",
		"choices": [
			{"label": "critical option", "outcome": "CRITICAL"},
			{"label": "safe option", "outcome": "SAFE"},
			{"label": "risky option a", "outcome": "RISKY"},
			{"label": "risky option b", "outcome": "RISKY"},
		],
	}]
	for outcome in ["SAFE", "RISKY", "CRITICAL"]:
		var controller := Controller.new()
		controller.setup("mod_test", 1, threats)
		var result: Dictionary = controller.choose_by_outcome(outcome)
		check(not result.is_empty() and str(result.get("outcome", "")) == outcome,
			"choose_by_outcome('%s') resolves a matching choice generically" % outcome)
		check(str(controller.pending_outcome) == outcome and not controller.pending_choice.is_empty(),
			"choose_by_outcome('%s') stages pending state exactly like a manual choose()" % outcome)
		var commit_result: Dictionary = controller.commit()
		check(bool(commit_result.get("bkt_correct", outcome != "SAFE")) == (outcome == "SAFE"),
			"choose_by_outcome('%s') commits through the same BKT semantics as a manual choice (SAFE=correct, RISKY/CRITICAL=incorrect)" % outcome)


func _test_choose_by_outcome_guards_like_choose() -> void:
	print("== choose_by_outcome() shares choose()'s exact guard conditions (stage_failed / wrong flow_state / already committed) ==")
	var threats: Array[Dictionary] = [{
		"id": "synthetic",
		"choices": [
			{"label": "safe option", "outcome": "SAFE"},
			{"label": "risky option", "outcome": "RISKY"},
		],
	}]
	var controller := Controller.new()
	controller.setup("mod_test", 1, threats)
	check(controller.choose_by_outcome("CRITICAL").is_empty(), "A threat with no CRITICAL choice authored safely returns empty, never a wrong pick")
	check(not controller.choose_by_outcome("SAFE").is_empty(), "A valid outcome resolves normally")
	# Re-staging before commit is allowed, exactly like calling choose() twice
	# in a row is allowed today — only pending_committed actually locks it.
	check(not controller.choose_by_outcome("RISKY").is_empty() and controller.pending_outcome == "RISKY",
		"Re-staging a different outcome before commit overwrites the pending choice, same as choose() already does")
	controller.commit()
	check(controller.choose_by_outcome("SAFE").is_empty(), "Once committed, choose_by_outcome() can no longer stage anything for this threat")


func _test_timer_isolated_from_gameplay_state() -> void:
	print("== Timer schema/config code never touches BKT, save, or progression directly (only through the existing commit path) ==")
	var forbidden: PackedStringArray = [
		"PlayerManager", "update_mastery", "mark_stage_cleared", "SaveService", "StageManager", "TaskManager",
	]
	var text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_scenarios.gd")
	check(not text.is_empty(), "decision_scenarios.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not text.contains(symbol), "decision_scenarios.gd's timer code does not reference %s" % symbol)
	var controller_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_stage_controller.gd")
	for symbol in forbidden:
		check(not controller_text.contains(symbol), "decision_stage_controller.gd does not reference %s" % symbol)
