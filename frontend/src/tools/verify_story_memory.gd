extends SceneTree
## Regression suite for lightweight persistent story memory and reactive
## dialogue (DecisionScenarios.choice_memory/condition_met/
## filter_lines_by_memory + PlayerManager.story_memory). Covers schema
## parsing, the one generic condition evaluator, and PlayerManager's own
## persistence in isolation — full live-scene commit-timing (SAFE immediate,
## RISKY pending-through-breach, CRITICAL never, retry, save/reload) is
## covered by verify_stage_one_live.gd's Module 3 Stage 1 checks, since that
## needs a real running match.
##
## Run headless:  godot --headless --script res://src/tools/verify_story_memory.gd

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
	_test_choice_memory_parsing()
	_test_condition_met_exact_match()
	_test_condition_met_missing_key_is_false()
	_test_condition_met_not_exclusion()
	_test_condition_met_multiple_keys_is_and()
	_test_filter_lines_by_memory()
	_test_dialogue_lines_backward_compatible()
	_test_story_event_lines_when_support()
	_test_isolated_from_gameplay_state()
	_test_player_manager_story_memory_persists()
	_test_pending_breach_memory_checkpoint_roundtrip()
	_test_stage1_demo_ending_variants()

	print("STORY_MEMORY_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_choice_memory_parsing() -> void:
	print("== choice_memory(): authored 'memory' parses safely, absent means no change ==")
	check(DecisionScenarios.choice_memory({}).is_empty(), "A choice with no 'memory' key writes nothing")
	check(DecisionScenarios.choice_memory({"outcome": "SAFE"}).is_empty(), "An ordinary choice (outcome/consequence only) is unaffected — SAFE/RISKY/CRITICAL is never auto-derived into memory")
	var scalar_choice: Dictionary = {"memory": {"mod03_s1_bank_verification": "independent", "daniel_stayed_on_call": true, "attempts": 2}}
	var parsed: Dictionary = DecisionScenarios.choice_memory(scalar_choice)
	check(parsed.get("mod03_s1_bank_verification") == "independent", "String memory value is read exactly")
	check(parsed.get("daniel_stayed_on_call") == true, "Bool memory value is read exactly")
	check(parsed.get("attempts") == 2, "Int memory value is read exactly")
	check(DecisionScenarios.choice_memory({"memory": "not a dictionary"}).is_empty(), "A malformed (non-dictionary) 'memory' value is safely ignored")
	var mixed: Dictionary = DecisionScenarios.choice_memory({"memory": {"ok": true, "bad": ["array", "not", "scalar"], "": "empty key ignored"}})
	check(mixed.has("ok") and not mixed.has("bad") and mixed.size() == 1, "Non-scalar values and empty keys are dropped rather than corrupting story memory")


func _test_condition_met_exact_match() -> void:
	print("== condition_met(): exact key/value match, absent 'when' is always true ==")
	check(DecisionScenarios.condition_met({}, {}), "An empty 'when' is unconditional — true regardless of memory")
	check(DecisionScenarios.condition_met({}, {"x": "y"}), "An empty 'when' is unconditional even with unrelated memory present")
	check(DecisionScenarios.condition_met({"k": "v"}, {"k": "v"}), "An exact string match is true")
	check(not DecisionScenarios.condition_met({"k": "v"}, {"k": "other"}), "A mismatched value is false")
	check(DecisionScenarios.condition_met({"flag": true}, {"flag": true}), "An exact bool match is true")
	check(not DecisionScenarios.condition_met({"flag": true}, {"flag": false}), "A mismatched bool is false")


func _test_condition_met_missing_key_is_false() -> void:
	print("== condition_met(): a referenced memory key that was never set is always false, never a crash ==")
	check(not DecisionScenarios.condition_met({"never_set": "value"}, {}), "A 'when' referencing an unset key is false against empty memory")
	check(not DecisionScenarios.condition_met({"never_set": "value"}, {"other_key": "value"}), "A 'when' referencing an unset key is false even with other memory present")


func _test_condition_met_not_exclusion() -> void:
	print("== condition_met(): optional {'not': value} exclusion form ==")
	check(DecisionScenarios.condition_met({"k": {"not": "risky"}}, {"k": "safe"}), "not-exclusion is true when the actual value differs")
	check(not DecisionScenarios.condition_met({"k": {"not": "risky"}}, {"k": "risky"}), "not-exclusion is false when the actual value matches the excluded one")
	check(DecisionScenarios.condition_met({"k": {"not": "risky"}}, {}), "not-exclusion is true when the key was never set at all (never equals the excluded value)")


func _test_condition_met_multiple_keys_is_and() -> void:
	print("== condition_met(): multiple authored keys are an implicit AND, never OR ==")
	var when: Dictionary = {"a": "1", "b": "2"}
	check(DecisionScenarios.condition_met(when, {"a": "1", "b": "2"}), "Both keys matching is true")
	check(not DecisionScenarios.condition_met(when, {"a": "1", "b": "wrong"}), "One mismatched key among several is false")
	check(not DecisionScenarios.condition_met(when, {"a": "1"}), "One key present, one entirely missing, is false")


func _test_filter_lines_by_memory() -> void:
	print("== filter_lines_by_memory(): unconditional lines always pass; conditional lines gate on memory ==")
	var lines: Array[Dictionary] = [
		{"speaker": "A", "text": "always shows", "emotion": "", "when": {}},
		{"speaker": "B", "text": "shows if independent", "emotion": "", "when": {"k": "independent"}},
		{"speaker": "C", "text": "shows if caller_knowledge", "emotion": "", "when": {"k": "caller_knowledge"}},
	]
	var with_independent: Array[Dictionary] = DecisionScenarios.filter_lines_by_memory(lines, {"k": "independent"})
	check(with_independent.size() == 2, "Exactly the unconditional line plus the matching conditional line survive")
	check(str(with_independent[1].get("text", "")) == "shows if independent", "The matching variant is the one that survives, not the other")
	var with_nothing: Array[Dictionary] = DecisionScenarios.filter_lines_by_memory(lines, {})
	check(with_nothing.size() == 1 and str(with_nothing[0].get("text", "")) == "always shows", "With no memory at all, only the unconditional line survives")


func _test_dialogue_lines_backward_compatible() -> void:
	print("== dialogue_lines()/finale_dialogue_lines(): absent 'when' behaves exactly as before this system existed ==")
	for threat in DecisionScenarios.get_threats("mod_01", 1):
		var lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(threat, "story")
		for line in lines:
			check((line.get("when", {}) as Dictionary).is_empty(), "[Regression] Existing Module 1 lines author no 'when' condition")
	# Calling with no memory argument at all (every pre-existing call site)
	# must produce the exact same lines as calling with an explicit empty one.
	var stage3: Dictionary = DecisionScenarios.get_stage("mod_03", 1)
	check(DecisionScenarios.dialogue_lines(stage3, "opening") == DecisionScenarios.dialogue_lines(stage3, "opening", {}),
		"[Regression] Omitting the memory argument is identical to passing an empty one")


func _test_story_event_lines_when_support() -> void:
	print("== story_event_lines(): reuses the SAME condition_met() evaluator, filtered per event (title+body together) ==")
	var choice: Dictionary = {"story_event": [
		{"type": "status", "title": "ALWAYS", "text": "shown either way"},
		{"type": "status", "title": "ONLY IF SAFE", "text": "safe path", "when": {"k": "safe"}},
		{"type": "status", "title": "ONLY IF RISKY", "text": "risky path", "when": {"k": "risky"}},
	]}
	var safe_lines: Array[Dictionary] = DecisionScenarios.story_event_lines(choice, {"k": "safe"})
	check(safe_lines.size() == 4, "The unconditional event (2 lines) plus the matching conditional event (2 lines) survive")
	check(str(safe_lines[2].get("text", "")) == "ONLY IF SAFE", "The matching event's title/body stay together as one unit")
	var no_memory_lines: Array[Dictionary] = DecisionScenarios.story_event_lines(choice)
	check(no_memory_lines.size() == 2, "[Regression] Calling with no memory argument at all only shows the unconditional event, same as before 'when' existed")


func _test_isolated_from_gameplay_state() -> void:
	print("== Story memory schema code never touches BKT, save, or progression directly (only through the existing commit path) ==")
	var forbidden: PackedStringArray = [
		"update_mastery", "mark_stage_cleared", "SaveService", "StageManager", "TaskManager",
	]
	var text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_scenarios.gd")
	check(not text.is_empty(), "decision_scenarios.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not text.contains(symbol), "decision_scenarios.gd's memory/condition code does not reference %s" % symbol)


func _test_player_manager_story_memory_persists() -> void:
	print("== PlayerManager.story_memory: set/get and save/reload round-trip ==")
	var pm: Node = root.get_node("PlayerManager")
	pm.reset_to_defaults()
	check(pm.get_story_memory_snapshot().is_empty(), "reset_to_defaults() clears story memory")
	pm.set_story_memories({"mod03_s1_bank_verification": "independent", "daniel_stayed_on_call": true})
	check(pm.get_story_memory("mod03_s1_bank_verification") == "independent", "A committed string value reads back exactly")
	check(pm.get_story_memory("daniel_stayed_on_call") == true, "A committed bool value reads back exactly")
	check(pm.get_story_memory("never_set") == null, "An unset key reads back null, never a guessed default")
	# Save/reload round-trip, without touching the real save file (mirrors
	# the pattern already used for mastery_matrix/decision_stage_state).
	var saved: Dictionary = pm.get_save_data()
	pm.reset_to_defaults()
	check(pm.get_story_memory_snapshot().is_empty(), "Story memory is empty immediately after a reset, before reapplying save data")
	pm.apply_save_data(saved)
	check(pm.get_story_memory("mod03_s1_bank_verification") == "independent" and pm.get_story_memory("daniel_stayed_on_call") == true,
		"Story memory survives a get_save_data()/apply_save_data() round-trip")
	# A save with no "story_memory" key at all (an older save) starts empty,
	# never a crash.
	var legacy_save: Dictionary = saved.duplicate(true)
	legacy_save.erase("story_memory")
	pm.reset_to_defaults()
	pm.apply_save_data(legacy_save)
	check(pm.get_story_memory_snapshot().is_empty(), "[Regression] An older save with no story_memory key at all starts with empty memory, not a crash")
	pm.reset_to_defaults()


## Full live-scene RISKY commit-timing (SAFE immediate/RISKY pending/
## CRITICAL never/retry/TD loss) is covered by verify_stage_one_live.gd,
## since it needs a real running match — this test proves the underlying
## DATA LAYER (checkpoint_state()/restore()) correctly round-trips a
## pending RISKY breach's story memory intact, independent of whatever the
## live scene's OWN UI chooses to do with a reload mid-breach (it currently
## always reopens the incident as a fresh review — seeing this restored
## controller in isolation is what actually proves the checkpoint schema
## itself is exploit-safe and lossless).
func _test_pending_breach_memory_checkpoint_roundtrip() -> void:
	print("== Checkpoint round-trip: a pending RISKY breach's story memory survives restore() intact, and TD win still commits it correctly afterward ==")
	var threats: Array[Dictionary] = [{
		"id": "synthetic",
		"choices": [
			{"label": "safe", "outcome": "SAFE"},
			{"label": "risky", "outcome": "RISKY", "memory": {"k": "risky_value"}},
		],
	}]
	var ctrl := Controller.new()
	ctrl.setup("mod_test", 1, threats)
	ctrl.display_order = [0, 1]
	check(ctrl.choose(1).get("outcome", "") == "RISKY", "Stages the RISKY choice")
	ctrl.commit()
	check(ctrl.flow_state == Controller.FLOW_BREACH and ctrl.pending_breach_memory.get("k") == "risky_value",
		"commit() enters breach and holds the choice's memory pending, not yet committed anywhere")
	var snapshot: Dictionary = ctrl.checkpoint_state()
	check(snapshot.get("pending_breach_memory", {}).get("k") == "risky_value", "checkpoint_state() carries the pending memory")
	var restored := Controller.new()
	restored.setup("mod_test", 1, threats)
	check(restored.restore(snapshot) and restored.flow_state == Controller.FLOW_BREACH, "A fresh controller restores back into the same pending breach")
	check(restored.pending_breach_memory.get("k") == "risky_value", "The restored controller's pending memory is intact — a save/reload cannot lose or corrupt it")
	var won_memory: Dictionary = restored.contain_breach()
	check(won_memory.get("k") == "risky_value", "TD victory on the RESTORED controller still commits the correct memory")
	check(restored.pending_breach_memory.is_empty(), "Pending memory is cleared once committed — no duplicate commit is possible from the same attempt")

	# The counterpart: reopening a pending breach as a plain THREAT review
	# (see stage_one_live.gd's _configure_match()) is a fresh re-choice, so
	# the OLD pending memory correctly never survives into it.
	var reopened := Controller.new()
	reopened.setup("mod_test", 1, threats)
	var review: Dictionary = snapshot.duplicate(true)
	review["flow_state"] = Controller.FLOW_THREAT
	review["in_breach"] = false
	check(reopened.restore(review) and reopened.flow_state == Controller.FLOW_THREAT, "Reopening as a review restores as a plain THREAT, not BREACH")
	check(reopened.pending_breach_memory.is_empty(), "[Retry rule] Reopening a pending breach as a fresh review discards the old RISKY memory — an abandoned attempt is never remembered")


## Exhaustive per-variant coverage of the Module 3 Stage 1 demo's reactive
## ending line at the DATA layer (dialogue_lines() + a memory snapshot) —
## verify_stage_one_live.gd separately proves ONE variant end to end through
## a real playthrough, confirming memory actually reaches this same call.
func _test_stage1_demo_ending_variants() -> void:
	print("== Stage 1 demo: each memory variant shows its OWN reactive line; unauthored memory shows none; the rest of the ending always converges unchanged ==")
	var stage: Dictionary = DecisionScenarios.get_stage("mod_03", 1)
	check(not stage.is_empty(), "Module 3 Stage 1 data is present")
	var variants: Dictionary = {
		"independent": "Calling the bank myself was the only thing that actually answered anything.",
		"caller_knowledge": "I kept asking them to prove themselves with information they already had.",
		"inside_call": "I was checking the real app and still letting the caller control the conversation.",
	}
	for memory_value in variants.keys():
		var lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(stage, "ending", {"mod03_s1_bank_verification": memory_value})
		var texts: Array = []
		for line in lines:
			texts.append(str(line.get("text", "")))
		check(texts.has(variants[memory_value]), "'%s' memory shows its own reactive Daniel line" % memory_value)
		for other_value in variants.keys():
			if other_value != memory_value:
				check(not texts.has(variants[other_value]), "'%s' memory does NOT show the '%s' variant's line" % [memory_value, other_value])
		check(texts.has("BlueTech."), "[Convergence] The BlueTech transaction clue is unchanged for the '%s' variant" % memory_value)
		var has_cliffhanger := false
		for line in lines:
			if str(line.get("text", "")).contains("PRIVATE NUMBER"):
				has_cliffhanger = true
		check(has_cliffhanger, "[Convergence] The PRIVATE NUMBER cliffhanger is unchanged for the '%s' memory" % memory_value)
	# No memory at all (e.g. Incident 1 was never reached/resolved, or an
	# older save with no story memory) shows none of the three variants —
	# the ending degrades to its original, always-unconditional content.
	var unset_lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(stage, "ending", {})
	var unset_texts: Array = []
	for line in unset_lines:
		unset_texts.append(str(line.get("text", "")))
	for memory_value in variants.keys():
		check(not unset_texts.has(variants[memory_value]), "[Regression] With no memory set at all, the '%s' reactive line does not show" % memory_value)
	check(unset_texts.has("BlueTech."), "[Regression] The unchanged ending content still shows with no memory set at all")
