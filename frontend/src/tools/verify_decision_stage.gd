extends SceneTree
## Legacy-scene regression for the Module 1 Stage 1 decision flow.
## Normal deployment is covered by the isolated verify_stage_one_live.gd harness.
## Run from frontend/:  godot --headless --script res://src/tools/verify_decision_stage.gd
## The local guest save is backed up before the run and restored afterwards.

const FORBIDDEN_WORDS: PackedStringArray = ["QUESTION", "CORRECT ANSWER", "QUIZ", "EXAM", "WRONG"]
const Emotion = preload("res://src/gameplay/decision/dialogue_emotion.gd")

var failures := 0
var _save_path := ""
var _save_backup := ""
var _had_save := false
var _router: Node
var _player: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func settle(frames: int = 12) -> void:
	for i in frames:
		await process_frame


func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func one_bkt_step(p: Node, before: float, correct: bool) -> float:
	var post: float = p._posterior(before, correct, p.P_GUESS, p.P_SLIP)
	return clampf(post + ((1.0 - post) * p.P_TRANSIT), p.MIN_MASTERY, p.MAX_MASTERY)


func _run() -> void:
	_player = root.get_node("PlayerManager")
	_router = root.get_node("Router")
	var save := root.get_node("SaveService")
	_save_path = save._resolve_save_path()
	_had_save = FileAccess.file_exists(_save_path)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(_save_path)
	_ensure_host()

	var threats := DecisionScenarios.get_threats("mod_01", 1)
	await _test_data_model(threats)
	await _test_overlay_layout(threats)
	await _test_controller(threats)
	await _test_save_compat()
	await _test_choice_randomization()
	await _test_required_scenarios()
	await _test_breach_transition()
	await _test_stage2()
	await _test_stage3()
	await _test_stage4()
	await _test_stage5()
	await _test_stage6()
	await _test_stage7()
	await _test_stage8()
	await _test_stage9()
	await _test_module2_stage1()
	await _test_module2_stage2()
	await _test_module2_stage3()
	await _test_module2_stage4()
	await _test_module2_stage5()
	await _test_module2_stage6()
	await _test_module2_stage7()
	await _test_module2_stage8()
	await _test_module2_stage9()
	await _test_module3_stage1()
	await _test_module3_stage2()
	await _test_module3_stage3()
	await _test_module3_stage4()
	await _test_module3_stage5()
	await _test_module3_stage1_story_consequences()
	await _test_legacy_story_memory_parity()
	await _test_regression()

	_restore_save()
	print("DECISION_STAGE_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_data_model(threats: Array[Dictionary]) -> void:
	print("== data model ==")
	check(DecisionScenarios.is_decision_stage("mod_01", 1), "Module 1 Stage 1 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 2), "[Stage 2] Module 1 Stage 2 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 3), "[Stage 3] Module 1 Stage 3 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 4), "[Stage 4] Module 1 Stage 4 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 5), "[Stage 5] Module 1 Stage 5 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 6), "[Stage 6] Module 1 Stage 6 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 7), "[Stage 7] Module 1 Stage 7 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 8), "[Stage 8] Module 1 Stage 8 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_01", 9), "[Stage 9] Module 1 Stage 9 is decision-based")
	check(not DecisionScenarios.is_decision_stage("mod_01", 10), "Module 1 Stage 10 is not decision-based (post-assessment stays separate)")
	check(threats.size() == 3, "Stage 1 has three threats")
	for i in threats.size():
		var outcomes: Array[String] = []
		for c in 3:
			outcomes.append(DecisionScenarios.choice_outcome(threats[i], c))
		check(outcomes.has("SAFE") and outcomes.has("RISKY") and outcomes.has("CRITICAL"), "Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
	var stage2_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 2)
	check(stage2_threats.size() == 3, "[Stage 2] Stage 2 has three threats")
	for i in stage2_threats.size():
		check(int(stage2_threats[i].get("stage", -1)) == 2, "[Stage 2] Threat %d belongs to stage 2 only" % (i + 1))
		check(str(stage2_threats[i].get("module_id", "")) == "mod_01", "[Stage 2] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes2: Array[String] = []
		for c in 3:
			outcomes2.append(DecisionScenarios.choice_outcome(stage2_threats[i], c))
		check(outcomes2.has("SAFE") and outcomes2.has("RISKY") and outcomes2.has("CRITICAL"), "[Stage 2] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
	var stage3_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 3)
	check(stage3_threats.size() == 3, "[Stage 3] Stage 3 has three threats")
	var trivial_phrases: PackedStringArray = ["give them your password", "give attacker the password", "ignore it", "ignore everything", "looks safe"]
	for i in stage3_threats.size():
		check(int(stage3_threats[i].get("stage", -1)) == 3, "[Stage 3] Threat %d belongs to stage 3 only" % (i + 1))
		check(str(stage3_threats[i].get("module_id", "")) == "mod_01", "[Stage 3] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes3: Array[String] = []
		var choices3: Array = stage3_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes3.append(DecisionScenarios.choice_outcome(stage3_threats[i], c))
		check(outcomes3.has("SAFE") and outcomes3.has("RISKY") and outcomes3.has("CRITICAL"), "[Stage 3] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		# Difficulty-content check: no obviously trivial choice text.
		for choice in choices3:
			var label_lower: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases:
				check(not label_lower.contains(phrase), "[Stage 3] Threat %d choice avoids the trivial phrase '%s'" % [i + 1, phrase])
	var stage4_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 4)
	check(stage4_threats.size() == 3, "[Stage 4] Stage 4 has three threats")
	var trivial_phrases4: PackedStringArray = ["give.*password", "ignore.*request", "ignore everything", "trust blindly", "looks safe", "ignore it"]
	for i in stage4_threats.size():
		check(int(stage4_threats[i].get("stage", -1)) == 4, "[Stage 4] Threat %d belongs to stage 4 only" % (i + 1))
		check(str(stage4_threats[i].get("module_id", "")) == "mod_01", "[Stage 4] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes4: Array[String] = []
		var choices4: Array = stage4_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes4.append(DecisionScenarios.choice_outcome(stage4_threats[i], c))
		check(outcomes4.has("SAFE") and outcomes4.has("RISKY") and outcomes4.has("CRITICAL"), "[Stage 4] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		for choice in choices4:
			var label_lower4: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases4:
				var rx := RegEx.new()
				rx.compile(phrase)
				check(not rx.search(label_lower4), "[Stage 4] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var stage5_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 5)
	check(stage5_threats.size() == 3, "[Stage 5] Stage 5 has three threats")
	var trivial_phrases5: PackedStringArray = ["give.*mfa code", "give.*code", "ignore everything", "approve because attacker", "ignore it", "looks safe"]
	for i in stage5_threats.size():
		check(int(stage5_threats[i].get("stage", -1)) == 5, "[Stage 5] Threat %d belongs to stage 5 only" % (i + 1))
		check(str(stage5_threats[i].get("module_id", "")) == "mod_01", "[Stage 5] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes5: Array[String] = []
		var choices5: Array = stage5_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes5.append(DecisionScenarios.choice_outcome(stage5_threats[i], c))
		check(outcomes5.has("SAFE") and outcomes5.has("RISKY") and outcomes5.has("CRITICAL"), "[Stage 5] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		for choice in choices5:
			var label_lower5: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases5:
				var rx5 := RegEx.new()
				rx5.compile(phrase)
				check(not rx5.search(label_lower5), "[Stage 5] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var stage6_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 6)
	check(stage6_threats.size() == 3, "[Stage 6] Stage 6 has three threats")
	var trivial_phrases6: PackedStringArray = ["give.*password", "ignore the warning", "ignore everything", "open anything immediately", "ignore it", "looks safe"]
	for i in stage6_threats.size():
		check(int(stage6_threats[i].get("stage", -1)) == 6, "[Stage 6] Threat %d belongs to stage 6 only" % (i + 1))
		check(str(stage6_threats[i].get("module_id", "")) == "mod_01", "[Stage 6] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes6: Array[String] = []
		var choices6: Array = stage6_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes6.append(DecisionScenarios.choice_outcome(stage6_threats[i], c))
		check(outcomes6.has("SAFE") and outcomes6.has("RISKY") and outcomes6.has("CRITICAL"), "[Stage 6] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		for choice in choices6:
			var label_lower6: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases6:
				var rx6 := RegEx.new()
				rx6.compile(phrase)
				check(not rx6.search(label_lower6), "[Stage 6] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var stage7_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 7)
	check(stage7_threats.size() == 3, "[Stage 7] Stage 7 has three threats")
	var trivial_phrases7: PackedStringArray = ["send money immediately", "ignore the supplier", "trust it because it looks real", "ignore it", "ignore everything", "looks safe"]
	for i in stage7_threats.size():
		check(int(stage7_threats[i].get("stage", -1)) == 7, "[Stage 7] Threat %d belongs to stage 7 only" % (i + 1))
		check(str(stage7_threats[i].get("module_id", "")) == "mod_01", "[Stage 7] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes7: Array[String] = []
		var choices7: Array = stage7_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes7.append(DecisionScenarios.choice_outcome(stage7_threats[i], c))
		check(outcomes7.has("SAFE") and outcomes7.has("RISKY") and outcomes7.has("CRITICAL"), "[Stage 7] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		for choice in choices7:
			var label_lower7: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases7:
				var rx7 := RegEx.new()
				rx7.compile(phrase)
				check(not rx7.search(label_lower7), "[Stage 7] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var stage8_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 8)
	check(stage8_threats.size() == 3, "[Stage 8] Stage 8 has three threats")
	var trivial_phrases8: PackedStringArray = ["ignore everything", "do nothing", "give access", "trust the attacker", "ignore it", "looks safe"]
	for i in stage8_threats.size():
		check(int(stage8_threats[i].get("stage", -1)) == 8, "[Stage 8] Threat %d belongs to stage 8 only" % (i + 1))
		check(str(stage8_threats[i].get("module_id", "")) == "mod_01", "[Stage 8] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes8: Array[String] = []
		var choices8: Array = stage8_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes8.append(DecisionScenarios.choice_outcome(stage8_threats[i], c))
		check(outcomes8.has("SAFE") and outcomes8.has("RISKY") and outcomes8.has("CRITICAL"), "[Stage 8] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		for choice in choices8:
			var label_lower8: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases8:
				var rx8 := RegEx.new()
				rx8.compile(phrase)
				check(not rx8.search(label_lower8), "[Stage 8] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var stage9_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", 9)
	check(stage9_threats.size() == 3, "[Stage 9] Stage 9 has three threats")
	var trivial_phrases9: PackedStringArray = ["ignore everything", "do nothing", "give access", "trust the attacker", "ignore it", "looks safe"]
	for i in stage9_threats.size():
		check(int(stage9_threats[i].get("stage", -1)) == 9, "[Stage 9] Threat %d belongs to stage 9 only" % (i + 1))
		check(str(stage9_threats[i].get("module_id", "")) == "mod_01", "[Stage 9] Threat %d belongs to mod_01 only" % (i + 1))
		var outcomes9: Array[String] = []
		var choices9: Array = stage9_threats[i].get("choices", []) as Array
		for c in 3:
			outcomes9.append(DecisionScenarios.choice_outcome(stage9_threats[i], c))
		check(outcomes9.has("SAFE") and outcomes9.has("RISKY") and outcomes9.has("CRITICAL"), "[Stage 9] Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))
		for choice in choices9:
			var label_lower9: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in trivial_phrases9:
				var rx9 := RegEx.new()
				rx9.compile(phrase)
				check(not rx9.search(label_lower9), "[Stage 9] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var stage9_data: Dictionary = DecisionScenarios.get_stage("mod_01", 9)
	check(DecisionScenarios.has_finale(stage9_data), "[Stage 9] Finale capability is enabled via data, not a hardcoded stage check")
	check(is_equal_approx(DecisionScenarios.finale_hp_multiplier(stage9_data, -1.0), 1.0), "[Stage 9] Finale enemy HP multiplier is 1.0")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(stage9_data, -1.0), 1.0), "[Stage 9] Stage breach HP multiplier is 1.0")
	check(not DecisionScenarios.has_finale(DecisionScenarios.get_stage("mod_01", 8)), "[Stage 8] Has no finale (data-driven, not stage-numbered)")
	check(not DecisionScenarios.has_finale({}), "An empty/absent stage has no finale")

	# Module 2 begins a new 4-choice format (1 SAFE / 2 RISKY / 1 CRITICAL).
	# The engine reads threat["choices"].size() everywhere, so this is purely
	# a content difference, never a module_id branch anywhere in the code.
	check(DecisionScenarios.is_decision_stage("mod_02", 1), "[Mod2 Stage 1] Module 2 Stage 1 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 2), "[Mod2 Stage 2] Module 2 Stage 2 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 3), "[Mod2 Stage 3] Module 2 Stage 3 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 4), "[Mod2 Stage 4] Module 2 Stage 4 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 5), "[Mod2 Stage 5] Module 2 Stage 5 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 6), "[Mod2 Stage 6] Module 2 Stage 6 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 7), "[Mod2 Stage 7] Module 2 Stage 7 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 8), "[Mod2 Stage 8] Module 2 Stage 8 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_02", 9), "[Mod2 Stage 9] Module 2 Stage 9 is decision-based")
	check(not DecisionScenarios.is_decision_stage("mod_02", 10), "Module 2 Stage 10 remains the non-decision post-assessment")
	check(DecisionScenarios.is_decision_stage("mod_03", 1), "[Mod3 Stage 1] Module 3 Stage 1 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_03", 2), "Module 3 Stage 2 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_03", 3), "Module 3 Stage 3 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_03", 4), "Module 3 Stage 4 is decision-based")
	check(DecisionScenarios.is_decision_stage("mod_03", 5), "Module 3 Stage 5 is decision-based")
	var mod2_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 1)
	check(mod2_threats.size() == 3, "[Mod2 Stage 1] Exactly 3 incidents")
	var mod2_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_threats.size():
		check(int(mod2_threats[i].get("stage", -1)) == 1, "[Mod2 Stage 1] Threat %d belongs to stage 1 only" % (i + 1))
		check(str(mod2_threats[i].get("module_id", "")) == "mod_02", "[Mod2 Stage 1] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2: Array = mod2_threats[i].get("choices", []) as Array
		check(choices_m2.size() == 4, "[Mod2 Stage 1] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2: Array[String] = []
		for c in choices_m2.size():
			outcomes_m2.append(DecisionScenarios.choice_outcome(mod2_threats[i], c))
		check(outcomes_m2.count("SAFE") == 1 and outcomes_m2.count("RISKY") == 2 and outcomes_m2.count("CRITICAL") == 1,
			"[Mod2 Stage 1] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		var risky_labels: Array[String] = []
		for c in choices_m2:
			if str((c as Dictionary).get("outcome", "")) == "RISKY":
				risky_labels.append(str((c as Dictionary).get("label", "")))
		check(risky_labels.size() == 2 and risky_labels[0] != risky_labels[1], "[Mod2 Stage 1] Threat %d's two RISKY choices are distinct" % (i + 1))
		for choice in choices_m2:
			var label_lower_m2: String = str((choice as Dictionary).get("label", "")).to_lower()
			for phrase in mod2_trivial:
				var rx_m2 := RegEx.new()
				rx_m2.compile(phrase)
				check(not rx_m2.search(label_lower_m2), "[Mod2 Stage 1] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
	var mod2_stage2: Dictionary = DecisionScenarios.get_stage("mod_02", 2)
	var mod2_stage2_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 2)
	check(mod2_stage2_threats.size() == 3, "[Mod2 Stage 2] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 2] Breach HP multiplier is 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 1] Breach HP multiplier remains 0.65")
	var mod2_stage2_trivial: PackedStringArray = ["ignore it", "ignore everything", "looks safe", "trust blindly", "pay immediately"]
	for i in mod2_stage2_threats.size():
		var threat_m2s2: Dictionary = mod2_stage2_threats[i]
		check(int(threat_m2s2.get("stage", -1)) == 2, "[Mod2 Stage 2] Threat %d belongs to stage 2 only" % (i + 1))
		check(str(threat_m2s2.get("module_id", "")) == "mod_02", "[Mod2 Stage 2] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s2: Array = threat_m2s2.get("choices", []) as Array
		check(choices_m2s2.size() == 4, "[Mod2 Stage 2] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s2: Array[String] = []
		var risky_labels_m2s2: Array[String] = []
		for choice in choices_m2s2:
			var choice_data: Dictionary = choice as Dictionary
			var outcome: String = str(choice_data.get("outcome", ""))
			outcomes_m2s2.append(outcome)
			if outcome == "RISKY":
				risky_labels_m2s2.append(str(choice_data.get("label", "")))
			var label_lower: String = str(choice_data.get("label", "")).to_lower()
			for phrase in mod2_stage2_trivial:
				check(not label_lower.contains(phrase), "[Mod2 Stage 2] Threat %d choice avoids trivial wording '%s'" % [i + 1, phrase])
		check(outcomes_m2s2.count("SAFE") == 1 and outcomes_m2s2.count("RISKY") == 2 and outcomes_m2s2.count("CRITICAL") == 1,
			"[Mod2 Stage 2] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s2.size() == 2 and risky_labels_m2s2[0] != risky_labels_m2s2[1], "[Mod2 Stage 2] Threat %d has two distinct RISKY choices" % (i + 1))
	var has_mia_cliffhanger := false
	for line in mod2_stage2.get("ending", []) as Array:
		if typeof(line) == TYPE_DICTIONARY and str((line as Dictionary).get("text", "")).contains("This one's from you"):
			has_mia_cliffhanger = true
			break
	check(has_mia_cliffhanger, "[Mod2 Stage 2] Ending contains the Mia-impersonation cliffhanger")

	var mod2_stage3: Dictionary = DecisionScenarios.get_stage("mod_02", 3)
	var mod2_stage3_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 3)
	check(mod2_stage3_threats.size() == 3, "[Mod2 Stage 3] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 3] Breach HP multiplier is 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 3] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 3] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage3_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage3_threats.size():
		var threat_m2s3: Dictionary = mod2_stage3_threats[i]
		check(int(threat_m2s3.get("stage", -1)) == 3, "[Mod2 Stage 3] Threat %d belongs to stage 3 only" % (i + 1))
		check(str(threat_m2s3.get("module_id", "")) == "mod_02", "[Mod2 Stage 3] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s3: Array = threat_m2s3.get("choices", []) as Array
		check(choices_m2s3.size() == 4, "[Mod2 Stage 3] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s3: Array[String] = []
		var risky_labels_m2s3: Array[String] = []
		for choice in choices_m2s3:
			var choice_data3: Dictionary = choice as Dictionary
			var outcome3: String = str(choice_data3.get("outcome", ""))
			outcomes_m2s3.append(outcome3)
			if outcome3 == "RISKY":
				risky_labels_m2s3.append(str(choice_data3.get("label", "")))
			var label_lower3: String = str(choice_data3.get("label", "")).to_lower()
			for phrase in mod2_stage3_trivial:
				var rx_m2s3 := RegEx.new()
				rx_m2s3.compile(phrase)
				check(not rx_m2s3.search(label_lower3), "[Mod2 Stage 3] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s3.count("SAFE") == 1 and outcomes_m2s3.count("RISKY") == 2 and outcomes_m2s3.count("CRITICAL") == 1,
			"[Mod2 Stage 3] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s3.size() == 2 and risky_labels_m2s3[0] != risky_labels_m2s3[1], "[Mod2 Stage 3] Threat %d has two distinct RISKY choices" % (i + 1))
	var has_otp_setup := false
	for line in mod2_stage3.get("ending", []) as Array:
		if typeof(line) == TYPE_DICTIONARY and str((line as Dictionary).get("text", "")).contains("verification code"):
			has_otp_setup = true
			break
	check(has_otp_setup, "[Mod2 Stage 3] Ending contains the unexpected-OTP setup for Stage 4")

	var mod2_stage4: Dictionary = DecisionScenarios.get_stage("mod_02", 4)
	var mod2_stage4_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 4)
	check(mod2_stage4_threats.size() == 3, "[Mod2 Stage 4] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage4, -1.0), 0.80), "[Mod2 Stage 4] Breach HP multiplier is 0.80")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 4] Stage 3's own multiplier is untouched at 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 4] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 4] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage4_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage4_threats.size():
		var threat_m2s4: Dictionary = mod2_stage4_threats[i]
		check(int(threat_m2s4.get("stage", -1)) == 4, "[Mod2 Stage 4] Threat %d belongs to stage 4 only" % (i + 1))
		check(str(threat_m2s4.get("module_id", "")) == "mod_02", "[Mod2 Stage 4] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s4: Array = threat_m2s4.get("choices", []) as Array
		check(choices_m2s4.size() == 4, "[Mod2 Stage 4] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s4: Array[String] = []
		var risky_labels_m2s4: Array[String] = []
		for choice in choices_m2s4:
			var choice_data4: Dictionary = choice as Dictionary
			var outcome4: String = str(choice_data4.get("outcome", ""))
			outcomes_m2s4.append(outcome4)
			if outcome4 == "RISKY":
				risky_labels_m2s4.append(str(choice_data4.get("label", "")))
			var label_lower4: String = str(choice_data4.get("label", "")).to_lower()
			for phrase in mod2_stage4_trivial:
				var rx_m2s4 := RegEx.new()
				rx_m2s4.compile(phrase)
				check(not rx_m2s4.search(label_lower4), "[Mod2 Stage 4] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s4.count("SAFE") == 1 and outcomes_m2s4.count("RISKY") == 2 and outcomes_m2s4.count("CRITICAL") == 1,
			"[Mod2 Stage 4] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s4.size() == 2 and risky_labels_m2s4[0] != risky_labels_m2s4[1], "[Mod2 Stage 4] Threat %d has two distinct RISKY choices" % (i + 1))
	var has_lockout_setup := false
	for line in mod2_stage4.get("ending", []) as Array:
		if typeof(line) == TYPE_DICTIONARY and str((line as Dictionary).get("text", "")).contains("locked out"):
			has_lockout_setup = true
			break
	check(has_lockout_setup, "[Mod2 Stage 4] Ending contains the lockout setup for Stage 5")

	var mod2_stage5: Dictionary = DecisionScenarios.get_stage("mod_02", 5)
	var mod2_stage5_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 5)
	check(mod2_stage5_threats.size() == 3, "[Mod2 Stage 5] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage5, -1.0), 0.85), "[Mod2 Stage 5] Breach HP multiplier is 0.85")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage4, -1.0), 0.80), "[Mod2 Stage 5] Stage 4's own multiplier is untouched at 0.80")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 5] Stage 3's own multiplier is untouched at 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 5] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 5] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage5_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage5_threats.size():
		var threat_m2s5: Dictionary = mod2_stage5_threats[i]
		check(int(threat_m2s5.get("stage", -1)) == 5, "[Mod2 Stage 5] Threat %d belongs to stage 5 only" % (i + 1))
		check(str(threat_m2s5.get("module_id", "")) == "mod_02", "[Mod2 Stage 5] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s5: Array = threat_m2s5.get("choices", []) as Array
		check(choices_m2s5.size() == 4, "[Mod2 Stage 5] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s5: Array[String] = []
		var risky_labels_m2s5: Array[String] = []
		for choice in choices_m2s5:
			var choice_data5: Dictionary = choice as Dictionary
			var outcome5: String = str(choice_data5.get("outcome", ""))
			outcomes_m2s5.append(outcome5)
			if outcome5 == "RISKY":
				risky_labels_m2s5.append(str(choice_data5.get("label", "")))
			var label_lower5: String = str(choice_data5.get("label", "")).to_lower()
			for phrase in mod2_stage5_trivial:
				var rx_m2s5 := RegEx.new()
				rx_m2s5.compile(phrase)
				check(not rx_m2s5.search(label_lower5), "[Mod2 Stage 5] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s5.count("SAFE") == 1 and outcomes_m2s5.count("RISKY") == 2 and outcomes_m2s5.count("CRITICAL") == 1,
			"[Mod2 Stage 5] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s5.size() == 2 and risky_labels_m2s5[0] != risky_labels_m2s5[1], "[Mod2 Stage 5] Threat %d has two distinct RISKY choices" % (i + 1))
	var has_impersonation_content := false
	var has_uncertain_entry_point_hedge := false
	var has_definitive_blame_phrase := false
	var has_no_service_cliffhanger := false
	var mod2_stage5_all_lines: Array = (mod2_stage5.get("ending", []) as Array) + (mod2_stage5_threats[1].get("story", []) as Array) + (mod2_stage5_threats[2].get("story", []) as Array)
	var definitive_blame_phrases: PackedStringArray = ["the click caused", "the click was how they got in", "that click let them in", "confirmed the entry point was", "confirmed that click"]
	for line in mod2_stage5_all_lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var text5: String = str((line as Dictionary).get("text", ""))
		var text5_lower: String = text5.to_lower()
		if text5.contains("asking everyone for money") or text5.contains("talking to my family as me"):
			has_impersonation_content = true
		if text5.contains("We still don't know that's how they got in") or text5.contains("wrong entry point"):
			has_uncertain_entry_point_hedge = true
		for phrase in definitive_blame_phrases:
			if text5_lower.contains(phrase):
				has_definitive_blame_phrase = true
		if text5.contains("No Service"):
			has_no_service_cliffhanger = true
	check(has_impersonation_content, "[Mod2 Stage 5] Story contains compromised-account impersonation content")
	check(has_uncertain_entry_point_hedge, "[Mod2 Stage 5] Story explicitly keeps the true entry point uncertain")
	check(not has_definitive_blame_phrase, "[Mod2 Stage 5] Story does not definitively state Leah's Stage 1 click caused the compromise")
	check(has_no_service_cliffhanger, "[Mod2 Stage 5] Ending contains the No Service cliffhanger for Stage 6")

	var mod2_stage6: Dictionary = DecisionScenarios.get_stage("mod_02", 6)
	var mod2_stage6_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 6)
	check(mod2_stage6_threats.size() == 3, "[Mod2 Stage 6] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage6, -1.0), 0.90), "[Mod2 Stage 6] Breach HP multiplier is 0.90")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage5, -1.0), 0.85), "[Mod2 Stage 6] Stage 5's own multiplier is untouched at 0.85")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage4, -1.0), 0.80), "[Mod2 Stage 6] Stage 4's own multiplier is untouched at 0.80")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 6] Stage 3's own multiplier is untouched at 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 6] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 6] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage6_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage6_threats.size():
		var threat_m2s6: Dictionary = mod2_stage6_threats[i]
		check(int(threat_m2s6.get("stage", -1)) == 6, "[Mod2 Stage 6] Threat %d belongs to stage 6 only" % (i + 1))
		check(str(threat_m2s6.get("module_id", "")) == "mod_02", "[Mod2 Stage 6] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s6: Array = threat_m2s6.get("choices", []) as Array
		check(choices_m2s6.size() == 4, "[Mod2 Stage 6] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s6: Array[String] = []
		var risky_labels_m2s6: Array[String] = []
		for choice in choices_m2s6:
			var choice_data6: Dictionary = choice as Dictionary
			var outcome6: String = str(choice_data6.get("outcome", ""))
			outcomes_m2s6.append(outcome6)
			if outcome6 == "RISKY":
				risky_labels_m2s6.append(str(choice_data6.get("label", "")))
			var label_lower6: String = str(choice_data6.get("label", "")).to_lower()
			for phrase in mod2_stage6_trivial:
				var rx_m2s6 := RegEx.new()
				rx_m2s6.compile(phrase)
				check(not rx_m2s6.search(label_lower6), "[Mod2 Stage 6] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s6.count("SAFE") == 1 and outcomes_m2s6.count("RISKY") == 2 and outcomes_m2s6.count("CRITICAL") == 1,
			"[Mod2 Stage 6] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s6.size() == 2 and risky_labels_m2s6[0] != risky_labels_m2s6[1], "[Mod2 Stage 6] Threat %d has two distinct RISKY choices" % (i + 1))
	var has_esim_content := false
	var has_predates_reveal := false
	var has_not_only_target := false
	var has_overclaim_phrase := false
	var has_sim_swap_named := false
	var mod2_stage6_all_lines: Array = (mod2_stage6.get("opening", []) as Array) + (mod2_stage6.get("ending", []) as Array) + (mod2_stage6_threats[0].get("story", []) as Array)
	var overclaim_phrases: PackedStringArray = ["every account was compromised", "automatically compromised", "controlled every account"]
	for line in mod2_stage6_all_lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var text6: String = str((line as Dictionary).get("text", ""))
		var text6_lower: String = text6.to_lower()
		if text6.contains("eSIM"):
			has_esim_content = true
		if text6.contains("Before the first text") or text6.contains("Then the text wasn't the beginning"):
			has_predates_reveal = true
		if text6.contains("wasn't the only target"):
			has_not_only_target = true
		if text6.contains("SIM swap"):
			has_sim_swap_named = true
		for phrase in overclaim_phrases:
			if text6_lower.contains(phrase):
				has_overclaim_phrase = true
	check(has_esim_content, "[Mod2 Stage 6] Story explicitly includes the unauthorized eSIM/SIM activation")
	check(has_predates_reveal, "[Mod2 Stage 6] Ending reveals attacker activity predates Leah's Stage 1 click")
	check(has_not_only_target, "[Mod2 Stage 6] Ending establishes Leah was not the only target")
	check(not has_overclaim_phrase, "[Mod2 Stage 6] Story does not claim phone-number control automatically compromises every account")
	check(not has_sim_swap_named, "[Mod2 Stage 6] Story does not explicitly name a SIM swap yet")

	var mod2_stage7: Dictionary = DecisionScenarios.get_stage("mod_02", 7)
	var mod2_stage7_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 7)
	check(mod2_stage7_threats.size() == 3, "[Mod2 Stage 7] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage7, -1.0), 0.95), "[Mod2 Stage 7] Breach HP multiplier is 0.95")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage6, -1.0), 0.90), "[Mod2 Stage 7] Stage 6's own multiplier is untouched at 0.90")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage5, -1.0), 0.85), "[Mod2 Stage 7] Stage 5's own multiplier is untouched at 0.85")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage4, -1.0), 0.80), "[Mod2 Stage 7] Stage 4's own multiplier is untouched at 0.80")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 7] Stage 3's own multiplier is untouched at 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 7] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 7] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage7_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage7_threats.size():
		var threat_m2s7: Dictionary = mod2_stage7_threats[i]
		check(int(threat_m2s7.get("stage", -1)) == 7, "[Mod2 Stage 7] Threat %d belongs to stage 7 only" % (i + 1))
		check(str(threat_m2s7.get("module_id", "")) == "mod_02", "[Mod2 Stage 7] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s7: Array = threat_m2s7.get("choices", []) as Array
		check(choices_m2s7.size() == 4, "[Mod2 Stage 7] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s7: Array[String] = []
		var risky_labels_m2s7: Array[String] = []
		for choice in choices_m2s7:
			var choice_data7: Dictionary = choice as Dictionary
			var outcome7: String = str(choice_data7.get("outcome", ""))
			outcomes_m2s7.append(outcome7)
			if outcome7 == "RISKY":
				risky_labels_m2s7.append(str(choice_data7.get("label", "")))
			var label_lower7: String = str(choice_data7.get("label", "")).to_lower()
			for phrase in mod2_stage7_trivial:
				var rx_m2s7 := RegEx.new()
				rx_m2s7.compile(phrase)
				check(not rx_m2s7.search(label_lower7), "[Mod2 Stage 7] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s7.count("SAFE") == 1 and outcomes_m2s7.count("RISKY") == 2 and outcomes_m2s7.count("CRITICAL") == 1,
			"[Mod2 Stage 7] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s7.size() == 2 and risky_labels_m2s7[0] != risky_labels_m2s7[1], "[Mod2 Stage 7] Threat %d has two distinct RISKY choices" % (i + 1))
	var has_paolo_intro := false
	var has_paolo_not_bluetech := false
	var has_three_victims := false
	var has_bluetech_security_sms := false
	var has_active_leah := false
	var has_coordinated_wave := false
	var has_ultimate_motive_leak := false
	var mod2_stage7_all_lines: Array = (mod2_stage7.get("opening", []) as Array) + (mod2_stage7.get("ending", []) as Array) + (mod2_stage7_threats[0].get("story", []) as Array) + (mod2_stage7_threats[1].get("story", []) as Array) + (mod2_stage7_threats[2].get("story", []) as Array)
	var motive_leak_phrases: PackedStringArray = ["because bluetech", "in order to steal", "their ultimate goal is", "the reason bluetech is being targeted is"]
	for line in mod2_stage7_all_lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var text7: String = str((line as Dictionary).get("text", ""))
		var text7_lower: String = text7.to_lower()
		if text7.contains("keep your brother on Wi-Fi"):
			has_paolo_intro = true
		if text7_lower.contains("does not work for bluetech") or text7_lower.contains("none of the victims work for bluetech"):
			has_paolo_not_bluetech = true
		if text7.contains("Three people"):
			has_three_victims = true
		if text7.contains("BLUETECH SECURITY"):
			has_bluetech_security_sms = true
		if text7.contains("This is yours too"):
			has_active_leah = true
		if text7.contains("hitting everyone they found"):
			has_coordinated_wave = true
		for phrase in motive_leak_phrases:
			if text7_lower.contains(phrase):
				has_ultimate_motive_leak = true
	check(has_paolo_intro, "[Mod2 Stage 7] Paolo is introduced as Ramon's brother")
	check(has_paolo_not_bluetech or str(mod2_stage7_threats[1].get("situation", "")).contains("does not work for BlueTech"), "[Mod2 Stage 7] Story explicitly states a victim does not work for BlueTech")
	check(has_three_victims, "[Mod2 Stage 7] Story establishes at least 3 independent victims")
	check(has_bluetech_security_sms, "[Mod2 Stage 7] Incident 3 uses a fake BlueTech Security SMS")
	check(has_active_leah, "[Mod2 Stage 7] Leah becomes an active participant in the investigation")
	check(has_coordinated_wave, "[Mod2 Stage 7] Ending launches a coordinated wave affecting multiple people")
	check(not has_ultimate_motive_leak, "[Mod2 Stage 7] Story does not reveal the attacker's ultimate motive")
	check(mod2_stage7.get("next_stage_title", "").contains("Close to Home"), "[Mod2 Stage 7] Next stage title is Close to Home")

	var mod2_stage8: Dictionary = DecisionScenarios.get_stage("mod_02", 8)
	var mod2_stage8_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 8)
	check(mod2_stage8_threats.size() == 3, "[Mod2 Stage 8] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage8, -1.0), 1.00), "[Mod2 Stage 8] Breach HP multiplier is 1.00")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage7, -1.0), 0.95), "[Mod2 Stage 8] Stage 7's own multiplier is untouched at 0.95")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage6, -1.0), 0.90), "[Mod2 Stage 8] Stage 6's own multiplier is untouched at 0.90")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage5, -1.0), 0.85), "[Mod2 Stage 8] Stage 5's own multiplier is untouched at 0.85")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage4, -1.0), 0.80), "[Mod2 Stage 8] Stage 4's own multiplier is untouched at 0.80")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 8] Stage 3's own multiplier is untouched at 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 8] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 8] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage8_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage8_threats.size():
		var threat_m2s8: Dictionary = mod2_stage8_threats[i]
		check(int(threat_m2s8.get("stage", -1)) == 8, "[Mod2 Stage 8] Threat %d belongs to stage 8 only" % (i + 1))
		check(str(threat_m2s8.get("module_id", "")) == "mod_02", "[Mod2 Stage 8] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s8: Array = threat_m2s8.get("choices", []) as Array
		check(choices_m2s8.size() == 4, "[Mod2 Stage 8] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s8: Array[String] = []
		var risky_labels_m2s8: Array[String] = []
		for choice in choices_m2s8:
			var choice_data8: Dictionary = choice as Dictionary
			var outcome8: String = str(choice_data8.get("outcome", ""))
			outcomes_m2s8.append(outcome8)
			if outcome8 == "RISKY":
				risky_labels_m2s8.append(str(choice_data8.get("label", "")))
			var label_lower8: String = str(choice_data8.get("label", "")).to_lower()
			for phrase in mod2_stage8_trivial:
				var rx_m2s8 := RegEx.new()
				rx_m2s8.compile(phrase)
				check(not rx_m2s8.search(label_lower8), "[Mod2 Stage 8] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s8.count("SAFE") == 1 and outcomes_m2s8.count("RISKY") == 2 and outcomes_m2s8.count("CRITICAL") == 1,
			"[Mod2 Stage 8] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s8.size() == 2 and risky_labels_m2s8[0] != risky_labels_m2s8[1], "[Mod2 Stage 8] Threat %d has two distinct RISKY choices" % (i + 1))
	var i1_story_m2s8: String = ""
	for line in mod2_stage8_threats[0].get("story", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			i1_story_m2s8 += str((line as Dictionary).get("text", "")) + " "
	var i2_story_m2s8: String = ""
	for line in mod2_stage8_threats[1].get("story", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			i2_story_m2s8 += str((line as Dictionary).get("text", "")) + " "
	var i3_story_m2s8: String = ""
	for line in mod2_stage8_threats[2].get("story", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			i3_story_m2s8 += str((line as Dictionary).get("text", "")) + " "
	var ending_m2s8: String = ""
	for line in mod2_stage8.get("ending", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			ending_m2s8 += str((line as Dictionary).get("text", "")) + " "
	check(i1_story_m2s8.contains("do not contact her directly") and i1_story_m2s8.contains("Do not contact her until"), "[Mod2 Stage 8] Incident 1 uses mirrored Mia/Leah manipulation")
	check(i2_story_m2s8.contains("Paolo") and i2_story_m2s8.contains("Ramon") and i2_story_m2s8.contains("OTP"), "[Mod2 Stage 8] Incident 2 uses Ramon/Paolo cross-validation with a real OTP")
	var i2_critical_consequence_m2s8: String = ""
	for choice in mod2_stage8_threats[1].get("choices", []) as Array:
		if str((choice as Dictionary).get("outcome", "")) == "CRITICAL":
			i2_critical_consequence_m2s8 = str((choice as Dictionary).get("consequence", ""))
	check(i2_critical_consequence_m2s8.contains("code") or str(mod2_stage8_threats[1].get("explanation", "")).contains("real code"), "[Mod2 Stage 8] A choice explicitly demonstrates a real OTP being misused in an attacker-created workflow")
	check(i3_story_m2s8.contains("coordinated wave"), "[Mod2 Stage 8] Incident 3 is a coordinated multi-victim campaign")
	check(i3_story_m2s8.contains("two messages that convince each other"), "[Mod2 Stage 8] Story establishes the mirrored-message validation technique")
	check(i3_story_m2s8.contains("So did mine"), "[Mod2 Stage 8] Leah actively helps another victim recognize the pattern")
	check(ending_m2s8.to_lower().contains("leverage"), "[Mod2 Stage 8] Story reveals victims are being used as leverage against BlueTech employees")
	check(ending_m2s8.to_lower().contains("recovery authority") or ending_m2s8.contains("approve, reset, verify, or recover"), "[Mod2 Stage 8] Story reveals targeted employees share recovery/approval authority")
	check(ending_m2s8.contains("recovery request") and ending_m2s8.contains("Not a personal one"), "[Mod2 Stage 8] Ending includes a new, unresolved BlueTech recovery request")
	check(mod2_stage8.get("next_stage_title", "").contains("Trust No Number"), "[Mod2 Stage 8] Next stage title is Trust No Number")
	var forbidden_leak_m2s8: PackedStringArray = ["admin console", "master key", "root access to bluetech", "the final target is"]
	var has_final_target_leak := false
	for phrase in forbidden_leak_m2s8:
		if ending_m2s8.to_lower().contains(phrase):
			has_final_target_leak = true
	check(not has_final_target_leak, "[Mod2 Stage 8] Story does not reveal the exact final BlueTech target")

	var mod2_stage9: Dictionary = DecisionScenarios.get_stage("mod_02", 9)
	var mod2_stage9_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", 9)
	check(mod2_stage9_threats.size() == 3, "[Mod2 Stage 9] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage9, -1.0), 1.00), "[Mod2 Stage 9] Breach HP multiplier is 1.00")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage8, -1.0), 1.00), "[Mod2 Stage 9] Stage 8's own multiplier is untouched at 1.00")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage7, -1.0), 0.95), "[Mod2 Stage 9] Stage 7's own multiplier is untouched at 0.95")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage6, -1.0), 0.90), "[Mod2 Stage 9] Stage 6's own multiplier is untouched at 0.90")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage5, -1.0), 0.85), "[Mod2 Stage 9] Stage 5's own multiplier is untouched at 0.85")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage4, -1.0), 0.80), "[Mod2 Stage 9] Stage 4's own multiplier is untouched at 0.80")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage3, -1.0), 0.75), "[Mod2 Stage 9] Stage 3's own multiplier is untouched at 0.75")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage2, -1.0), 0.70), "[Mod2 Stage 9] Stage 2's own multiplier is untouched at 0.70")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(DecisionScenarios.get_stage("mod_02", 1), -1.0), 0.65), "[Mod2 Stage 9] Stage 1's own multiplier is untouched at 0.65")
	var mod2_stage9_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod2_stage9_threats.size():
		var threat_m2s9: Dictionary = mod2_stage9_threats[i]
		check(int(threat_m2s9.get("stage", -1)) == 9, "[Mod2 Stage 9] Threat %d belongs to stage 9 only" % (i + 1))
		check(str(threat_m2s9.get("module_id", "")) == "mod_02", "[Mod2 Stage 9] Threat %d belongs to mod_02 only" % (i + 1))
		var choices_m2s9: Array = threat_m2s9.get("choices", []) as Array
		check(choices_m2s9.size() == 4, "[Mod2 Stage 9] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m2s9: Array[String] = []
		var risky_labels_m2s9: Array[String] = []
		for choice in choices_m2s9:
			var choice_data9: Dictionary = choice as Dictionary
			var outcome9: String = str(choice_data9.get("outcome", ""))
			outcomes_m2s9.append(outcome9)
			if outcome9 == "RISKY":
				risky_labels_m2s9.append(str(choice_data9.get("label", "")))
			var label_lower9: String = str(choice_data9.get("label", "")).to_lower()
			for phrase in mod2_stage9_trivial:
				var rx_m2s9 := RegEx.new()
				rx_m2s9.compile(phrase)
				check(not rx_m2s9.search(label_lower9), "[Mod2 Stage 9] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m2s9.count("SAFE") == 1 and outcomes_m2s9.count("RISKY") == 2 and outcomes_m2s9.count("CRITICAL") == 1,
			"[Mod2 Stage 9] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m2s9.size() == 2 and risky_labels_m2s9[0] != risky_labels_m2s9[1], "[Mod2 Stage 9] Threat %d has two distinct RISKY choices" % (i + 1))
	check(DecisionScenarios.has_finale(mod2_stage9), "[Mod2 Stage 9] Stage 9 is configured with the existing generic finale system")
	check(is_equal_approx(DecisionScenarios.finale_hp_multiplier(mod2_stage9, -1.0), 1.00), "[Mod2 Stage 9] Finale enemy HP multiplier is 1.00")
	var mod2_stage9_finale: Dictionary = DecisionScenarios.finale_config(mod2_stage9)
	check(str(mod2_stage9_finale.get("affected_system", "")) == "BLUETECH IDENTITY RECOVERY SERVICE", "[Mod2 Stage 9] Finale targets the BlueTech identity-recovery service")
	check(str(mod2_stage9_finale.get("complete_banner", "")) == "MODULE 2 STORY COMPLETE", "[Mod2 Stage 9] Finale completion banner reads MODULE 2 STORY COMPLETE")
	var mod2_stage9_case_summary: Dictionary = mod2_stage9_finale.get("case_summary", {}) as Dictionary
	check(str(mod2_stage9_case_summary.get("subtitle", "")) == "SIGNAL LOST", "[Mod2 Stage 9] Case-closed summary includes the SIGNAL LOST arc name")
	var ending_m2s9: String = ""
	for line in mod2_stage9.get("ending", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			ending_m2s9 += str((line as Dictionary).get("text", "")) + " "
	var opening_m2s9: String = ""
	for line in mod2_stage9.get("opening", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			opening_m2s9 += str((line as Dictionary).get("text", "")) + " "
	check(opening_m2s9.to_lower().contains("identity recovery administrator"), "[Mod2 Stage 9] Final reveal identifies the privileged BlueTech identity-recovery account")
	check(ending_m2s9.contains("reset authentication factors and recovery methods"), "[Mod2 Stage 9] Story explains this access enables additional authentication/recovery attacks")
	check(ending_m2s9.to_lower().contains("leverage"), "[Mod2 Stage 9] Family/personal victims are explicitly revealed as leverage")
	var overreach_phrases_m2s9: PackedStringArray = ["access to every account", "access to every system", "own all of bluetech"]
	var has_overreach_m2s9 := false
	for phrase in overreach_phrases_m2s9:
		if opening_m2s9.to_lower().contains(phrase) or ending_m2s9.to_lower().contains(phrase):
			has_overreach_m2s9 = true
	check(not has_overreach_m2s9, "[Mod2 Stage 9] Story does not claim automatic access to every BlueTech account/system")
	check(opening_m2s9.to_lower().contains("don't automatically own bluetech"), "[Mod2 Stage 9] Story explicitly denies automatic ownership of all of BlueTech")
	var i3_explanation_m2s9: String = str(mod2_stage9_threats[2].get("explanation", ""))
	check(i3_explanation_m2s9.to_lower().contains("caller id") and i3_explanation_m2s9.to_lower().contains("genuine"), "[Mod2 Stage 9] Incident 3 explains caller ID + fresh info + a genuine code still isn't proof of identity")

	var mod3_stage1: Dictionary = DecisionScenarios.get_stage("mod_03", 1)
	var mod3_stage1_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_03", 1)
	check(mod3_stage1_threats.size() == 3, "[Mod3 Stage 1] Exactly 3 incidents")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod3_stage1, -1.0), 0.65), "[Mod3 Stage 1] Breach HP multiplier is 0.65")
	check(is_equal_approx(DecisionScenarios.breach_hp_multiplier(mod2_stage9, -1.0), 1.00), "[Mod3 Stage 1] Module 2 Stage 9's own multiplier is untouched at 1.00")
	check(str(mod3_stage1.get("bkt_skill", "")) == "vishing", "[Mod3 Stage 1] Uses the vishing BKT skill, a new Module 3 domain")
	var mod3_stage1_trivial: PackedStringArray = ["give.*password", "ignore it", "ignore everything", "looks safe", "trust it because it looks real"]
	for i in mod3_stage1_threats.size():
		var threat_m3s1: Dictionary = mod3_stage1_threats[i]
		check(int(threat_m3s1.get("stage", -1)) == 1, "[Mod3 Stage 1] Threat %d belongs to stage 1 only" % (i + 1))
		check(str(threat_m3s1.get("module_id", "")) == "mod_03", "[Mod3 Stage 1] Threat %d belongs to mod_03 only" % (i + 1))
		var choices_m3s1: Array = threat_m3s1.get("choices", []) as Array
		check(choices_m3s1.size() == 4, "[Mod3 Stage 1] Threat %d has exactly 4 choices" % (i + 1))
		var outcomes_m3s1: Array[String] = []
		var risky_labels_m3s1: Array[String] = []
		for choice in choices_m3s1:
			var choice_data_m3s1: Dictionary = choice as Dictionary
			var outcome_m3s1: String = str(choice_data_m3s1.get("outcome", ""))
			outcomes_m3s1.append(outcome_m3s1)
			if outcome_m3s1 == "RISKY":
				risky_labels_m3s1.append(str(choice_data_m3s1.get("label", "")))
			var label_lower_m3s1: String = str(choice_data_m3s1.get("label", "")).to_lower()
			for phrase in mod3_stage1_trivial:
				var rx_m3s1 := RegEx.new()
				rx_m3s1.compile(phrase)
				check(not rx_m3s1.search(label_lower_m3s1), "[Mod3 Stage 1] Threat %d choice avoids the trivial phrase pattern '%s'" % [i + 1, phrase])
		check(outcomes_m3s1.count("SAFE") == 1 and outcomes_m3s1.count("RISKY") == 2 and outcomes_m3s1.count("CRITICAL") == 1,
			"[Mod3 Stage 1] Threat %d has exactly 1 SAFE / 2 RISKY / 1 CRITICAL" % (i + 1))
		check(risky_labels_m3s1.size() == 2 and risky_labels_m3s1[0] != risky_labels_m3s1[1], "[Mod3 Stage 1] Threat %d has two distinct RISKY choices" % (i + 1))
	var opening_m3s1: String = ""
	for line in mod3_stage1.get("opening", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			opening_m3s1 += str((line as Dictionary).get("text", "")) + " "
	var ending_m3s1: String = ""
	for line in mod3_stage1.get("ending", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			ending_m3s1 += str((line as Dictionary).get("text", "")) + " "
	var i2_story_m3s1: String = ""
	for line in mod3_stage1_threats[1].get("story", []) as Array:
		if typeof(line) == TYPE_DICTIONARY:
			i2_story_m3s1 += str((line as Dictionary).get("text", "")) + " "
	check(opening_m3s1.contains("Fraud Prevention Department"), "[Mod3 Stage 1] Story contains caller-ID spoofing / fake fraud-department impersonation")
	check(str(mod3_stage1_threats[0].get("affected_system", "")) == "DANIEL'S BUSINESS BANK ACCOUNT", "[Mod3 Stage 1] Incident 1 impersonates Daniel's real bank")
	var safe_labels_m3s1: Array[String] = []
	for threat in mod3_stage1_threats:
		for choice in threat.get("choices", []) as Array:
			if str((choice as Dictionary).get("outcome", "")) == "SAFE":
				safe_labels_m3s1.append(str((choice as Dictionary).get("label", "")).to_lower())
	var teaches_callback := false
	for label in safe_labels_m3s1:
		if label.contains("independently") or label.contains("known official channel") or label.contains("previously trusted channel"):
			teaches_callback = true
	check(teaches_callback, "[Mod3 Stage 1] SAFE choices teach independent callback verification")
	check(i2_story_m3s1.to_lower().contains("stay on this call"), "[Mod3 Stage 1] The attacker explicitly tells Daniel to remain on the line")
	check(ending_m3s1.contains("BlueTech"), "[Mod3 Stage 1] Ending includes the BlueTech transaction clue")
	check(ending_m3s1.contains("Probably nothing"), "[Mod3 Stage 1] Ending keeps the campaign connection as only a small, unconfirmed clue")
	var campaign_leak_phrases_m3s1: PackedStringArray = ["the same attacker who targeted bluetech", "this is part of the phishing campaign", "connected to the smishing campaign"]
	var has_campaign_leak_m3s1 := false
	for phrase in campaign_leak_phrases_m3s1:
		if ending_m3s1.to_lower().contains(phrase):
			has_campaign_leak_m3s1 = true
	check(not has_campaign_leak_m3s1, "[Mod3 Stage 1] Ending does not reveal the larger cross-module campaign")
	check(mod3_stage1.get("next_stage_title", "").contains("Stay on the Line"), "[Mod3 Stage 1] Next stage title is Stay on the Line")
	var mod3_stage1_all_lines: Array = (mod3_stage1.get("opening", []) as Array) + (mod3_stage1.get("ending", []) as Array)
	for threat in mod3_stage1_threats:
		mod3_stage1_all_lines += threat.get("story", []) as Array
	var emotions_found_m3s1: Dictionary = {}
	for line in mod3_stage1_all_lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var raw_emotion: Variant = (line as Dictionary).get("emotion", null)
		if raw_emotion != null:
			emotions_found_m3s1[str(raw_emotion)] = true
	check(emotions_found_m3s1.size() > 0, "[Mod3 Stage 1] Dialogue contains explicit emotion metadata")
	var required_emotions_m3s1: PackedStringArray = ["worried", "frustrated", "angry", "sad", "shocked", "determined"]
	for required_emotion in required_emotions_m3s1:
		check(emotions_found_m3s1.has(required_emotion), "[Mod3 Stage 1] Emotion '%s' appears naturally in the dialogue" % required_emotion)
	check(not emotions_found_m3s1.has("crying"), "[Mod3 Stage 1] Crying is not used yet — saved for a later stage")
	var invalid_emotions_m3s1: Array[String] = []
	for emotion_key in emotions_found_m3s1.keys():
		if not Emotion.VALID_EMOTIONS.has(str(emotion_key)):
			invalid_emotions_m3s1.append(str(emotion_key))
	check(invalid_emotions_m3s1.is_empty(), "[Mod3 Stage 1] Every authored emotion value is one the presentation layer recognizes: %s" % str(invalid_emotions_m3s1))
	# Emotion must track character story moments, not answer correctness: no
	# single emotion may appear on the CRITICAL choice's consequence line (the
	# consequence text itself has no emotion field at all — choices are plain
	# strings, never carrying "emotion" — so this is really a structural
	# guarantee, confirmed here so a future stage can't accidentally add one).
	for threat in mod3_stage1_threats:
		for choice in threat.get("choices", []) as Array:
			check(not (choice as Dictionary).has("emotion"), "[Mod3 Stage 1] Choice labels never carry emotion metadata (outcomes stay hidden from presentation)")

	# Module 1's own 3-choice stages must still work exactly as authored —
	# adding a 4-choice format must not change how a 3-choice threat behaves.
	check(DecisionScenarios.get_threats("mod_01", 1)[0].get("choices", []).size() == 3, "[Mod2 audit] Module 1 Stage 1 still authors 3 choices per incident")
	check(not DecisionScenarios.is_decision_stage("mod_01", 10), "[Mod2 audit] Module 1 Stage 10 remains unaffected and non-decision")


func _test_overlay_layout(threats: Array[Dictionary]) -> void:
	print("== decision overlay layout ==")
	root.size = Vector2i(1280, 720)
	await settle()
	var overlay := DecisionOverlay.new()
	overlay.name = "LayoutProbe"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.size = Vector2(1280, 720)
	root.add_child(overlay)
	await settle()
	var hover: StyleBoxFlat = overlay._choice_buttons[0].get_theme_stylebox("hover") as StyleBoxFlat
	var focus: StyleBoxFlat = overlay._choice_buttons[0].get_theme_stylebox("focus") as StyleBoxFlat
	var normal: StyleBoxFlat = overlay._choice_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	var selected: StyleBoxFlat = overlay._choice_buttons[0].get_theme_stylebox("pressed") as StyleBoxFlat
	check(hover != null and focus != null and normal != null and selected != null, "Choice buttons have distinct styleboxes")
	check(hover.bg_color != focus.bg_color or hover.border_color != focus.border_color, "Keyboard focus does not reuse the hover fill")
	check(focus.bg_color == normal.bg_color, "Focus keeps the normal background")
	check(selected.bg_color != hover.bg_color, "Selected/pressed is distinct from hover")
	check(overlay._choice_buttons[0].get_theme_font_size("font_size") == 14, "[UI-1.1] Choice text uses the larger story-decision font")
	# [UI-1.1] Story-layout proportions: prominent portrait, wide choice
	# column, and a dialogue box that is actually the dominant element.
	check(overlay._portrait_panel.custom_minimum_size.x >= 260.0, "[UI-1.1] Portrait column is at least 260px wide")
	check(overlay._choices_panel.custom_minimum_size.x >= 300.0, "[UI-1.1] Choice column is at least 300px wide")
	for i in threats.size():
		overlay.show_threat(threats[i], DecisionScenarios.dialogue_lines(threats[i], "story"), i + 1, threats.size(), "BLUETECH SOLUTIONS  //  SECURITY DESK")
		await settle(20)
		check(overlay._window.size.y <= 680.0, "Threat %d window stays inside 1280x720 (%dpx)" % [i + 1, int(overlay._window.size.y)])
		check(overlay._window.size.x <= 1280.0, "Threat %d window width fits the viewport" % (i + 1))
		# _dialogue_panel's own .size can exceed the visible box (it's the
		# scrollable content, which is allowed to be taller than its
		# viewport) — _body_scroll.size is the actual visible dialogue box.
		check(overlay._body_scroll.size.y >= 160.0, "[UI-1.1] Threat %d dialogue box is at least 160px tall (%dpx)" % [i + 1, int(overlay._body_scroll.size.y)])
		# [UI-1.2] The dialogue CONTENT column must actually use the width the
		# dialogue panel has, not collapse to a narrow word-wrapped minimum.
		check(overlay._dialogue_box.size.x >= overlay._dialogue_panel.size.x * 0.8, "[UI-1.2] Threat %d dialogue content uses >=80%% of the dialogue panel width (%d/%dpx)" % [i + 1, int(overlay._dialogue_box.size.x), int(overlay._dialogue_panel.size.x)])
		var focused := 0
		var reachable := 0
		for b in overlay._choice_buttons.size():
			var button: Button = overlay._choice_buttons[b]
			if not button.visible:
				continue
			check(not button.clip_text, "Threat %d choice %s does not clip text" % [i + 1, char(65 + b)])
			check(button.custom_minimum_size.y >= 80.0, "[UI-1.1] Threat %d choice %s uses the larger choice height" % [i + 1, char(65 + b)])
			check(button.size.y + 0.5 >= button.custom_minimum_size.y, "Threat %d choice %s is tall enough for wrapped text" % [i + 1, char(65 + b)])
			check(button.size.x >= overlay._choices_panel.size.x - 4.0, "[UI-1.2] Threat %d choice %s uses almost the full choice-column width" % [i + 1, char(65 + b)])
			if button.has_focus():
				focused += 1
			var window_rect: Rect2 = overlay._window.get_global_rect()
			var button_rect: Rect2 = button.get_global_rect()
			var in_window: bool = window_rect.grow(4.0).encloses(button_rect) or window_rect.intersects(button_rect)
			var can_scroll: bool = overlay._body_scroll.get_v_scroll_bar() != null and overlay._body_scroll.get_v_scroll_bar().max_value > 1.0
			if in_window or can_scroll:
				reachable += 1
		check(focused == 0, "Threat %d does not auto-select a choice with keyboard focus" % (i + 1))
		check(reachable == 3, "Threat %d keeps all three choices reachable by layout or scroll" % (i + 1))
		check(overlay._prompt.visible and overlay._prompt.text == "CHOOSE AN ACTION", "Threat %d still shows Choose an Action" % (i + 1))
		check(overlay._situation_title.visible and overlay._evidence_box.get_child_count() > 0, "Threat %d still shows incident title and evidence" % (i + 1))
	# [UI-1.1] Incident 3 (index 2) has the longest choice labels in the data —
	# confirm they still wrap into the button rather than clipping or
	# overflowing past the window.
	var incident3_choices: Array = (threats[2].get("choices", []) as Array)
	for b in mini(overlay._choice_buttons.size(), incident3_choices.size()):
		var long_button: Button = overlay._choice_buttons[b]
		check(not long_button.clip_text and long_button.size.y >= long_button.custom_minimum_size.y, "[UI-1.1] Incident 3 choice %s wraps without clipping" % char(65 + b))
	# [UI-1.2] The dialogue box now correctly uses the full panel width, which
	# means most real dialogue lines wrap into far fewer lines than before —
	# genuinely long content must still overflow into a scrollbar rather than
	# ever clipping or forcing the window past the viewport.
	var long_lines: Array[Dictionary] = [
		{"speaker": "Security Assistant", "text": "This is a deliberately long line of dialogue text repeated to force the dialogue box content past its visible height so the scrollbar must activate. ".repeat(6)},
	]
	overlay.show_story(long_lines, "TEST", "CONTINUE")
	await settle(20)
	check(overlay._window.size.y <= 680.0, "[UI-1.2] Overlay stays within the viewport even with overflowing dialogue text")
	var long_scroll_bar: VScrollBar = overlay._body_scroll.get_v_scroll_bar()
	check(long_scroll_bar != null and long_scroll_bar.max_value > 1.0, "[UI-1.2] Dialogue box scrolls when content genuinely overflows")

	overlay.show_threat(threats[0], DecisionScenarios.dialogue_lines(threats[0], "story"), 1, 3, "TEST")
	await settle()
	overlay._choice_buttons[1].grab_focus()
	await settle()
	check(overlay._choice_buttons[1].has_focus() and not overlay._choice_buttons[0].has_focus(), "Only one choice can hold keyboard focus")
	var focused_box: StyleBoxFlat = overlay._choice_buttons[1].get_theme_stylebox("focus") as StyleBoxFlat
	check(focused_box.bg_color == overlay._style_normal.bg_color, "Focused choice is not painted as selected")
	overlay.queue_free()
	await settle()


func _test_controller(threats: Array[Dictionary]) -> void:
	print("== controller ==")
	# This function tests the controller's own state machine (commit, resolve,
	# checkpoint, restore), not choice randomization — that has its own
	# dedicated test. Pin display_order to identity before each choose() so
	# "option B" / "index 2" keep meaning the authored option at that JSON
	# position, exactly as before randomization existed.
	var ctrl := DecisionStageController.new()
	ctrl.setup("mod_01", 1, threats)
	ctrl.display_order = [0, 1, 2]
	check(ctrl.choose(1).get("outcome", "") == "SAFE", "Threat 1 option B is SAFE")
	check(ctrl.resolved_threats == 0 and ctrl.safe_count == 0, "choose() does not commit progress")
	var first_commit: Dictionary = ctrl.commit()
	check(first_commit.get("committed", false) and ctrl.commit().is_empty(), "The same decision cannot be committed twice")
	check(not ctrl.is_complete() and ctrl.resolved_threats == 1, "One SAFE decision does not clear the stage")
	ctrl.display_order = [0, 1, 2]
	check(ctrl.choose(2).get("outcome", "") == "RISKY", "Threat 2 option C is RISKY")
	ctrl.commit()
	check(ctrl.in_breach and ctrl.flow_state == DecisionStageController.FLOW_BREACH, "RISKY commit enters breach")
	check(ctrl.security_state == DecisionStageController.STATE_NOMINAL, "Failed-or-pending RISKY does not elevate security until TD win")
	ctrl.contain_breach()
	check(ctrl.resolved_threats == 2 and not ctrl.in_breach and not ctrl.is_complete(), "Breach win resolves threat 2 without clearing")
	check(ctrl.security_state == DecisionStageController.STATE_ELEVATED, "Successful containment elevates security")
	var snapshot := ctrl.checkpoint_state()
	var restored := DecisionStageController.new()
	restored.setup("mod_01", 1, threats)
	check(restored.restore(snapshot) and restored.threat_index == 2 and restored.resolved_threats == 2 and restored.flow_state == DecisionStageController.FLOW_THREAT, "Checkpoint round-trips")
	check(not DecisionStageController.new().restore({}), "Empty checkpoint is a fresh start")

	var t1 := DecisionStageController.new()
	t1.setup("mod_01", 1, threats)
	t1.display_order = [0, 1, 2]
	t1.choose(0)
	t1.commit()
	check(t1.stage_failed and t1.threat_index == 0 and t1.security_state == DecisionStageController.STATE_NOMINAL, "CRITICAL fails without persisting COMPROMISED")
	var t1_snap: Dictionary = t1.checkpoint_state()
	check(int(t1_snap.get("threat_index", -1)) == 0 and str(t1_snap.get("flow_state", "")) == DecisionStageController.FLOW_THREAT, "Threat 1 failure still writes a checkpoint")
	var t1_again := DecisionStageController.new()
	t1_again.setup("mod_01", 1, threats)
	check(t1_again.restore(t1_snap) and t1_again.threat_index == 0 and not t1_again.stage_failed and t1_again.flow_state == DecisionStageController.FLOW_THREAT, "Threat 1 checkpoint is a resume, not a fresh run")

	ctrl.display_order = [0, 1, 2]
	check(ctrl.choose(1).get("outcome", "") == "SAFE", "Threat 3 option B is SAFE")
	ctrl.commit()
	check(ctrl.is_complete() and ctrl.flow_state == DecisionStageController.FLOW_ENDING, "Stage completes after all three threats")
	var ending_snap: Dictionary = ctrl.checkpoint_state()
	var ending_restore := DecisionStageController.new()
	ending_restore.setup("mod_01", 1, threats)
	check(ending_restore.restore(ending_snap) and ending_restore.flow_state == DecisionStageController.FLOW_ENDING and ending_restore.is_complete(), "Ending checkpoint restores the ending, not Threat 1")

	var lost := DecisionStageController.new()
	lost.setup("mod_01", 1, threats)
	lost.display_order = [0, 1, 2]
	lost.choose(2)
	lost.commit()
	lost.fail_breach()
	check(lost.stage_failed and not lost.in_breach and lost.threat_index == 0, "Lost breach keeps the checkpoint on the same threat")
	check(lost.security_state == DecisionStageController.STATE_NOMINAL, "Lost breach does not persist COMPROMISED")
	var lost_again := DecisionStageController.new()
	lost_again.setup("mod_01", 1, threats)
	check(lost_again.restore(lost.checkpoint_state()) and not lost_again.stage_failed, "Retry after a lost breach clears the failure flag")


func _test_save_compat() -> void:
	print("== save compatibility ==")
	_player.reset_to_defaults()
	_player.decision_stage_state = {"mod_01:1": {"threat_index": 2, "resolved_threats": 2, "flow_state": "THREAT", "in_breach": false, "security_state": "ELEVATED", "safe_count": 1}}
	var data: Dictionary = _player.get_save_data()
	check(data.has("decision_stage_state") and data.has("mastery_matrix"), "Save payload carries decision checkpoints alongside existing keys")
	_player.decision_stage_state = {}
	_player.apply_save_data(data)
	check(_player.get_decision_stage_state("mod_01:1").get("threat_index", -1) == 2, "Checkpoint survives save/load")
	check(str(_player.get_decision_stage_state("mod_01:1").get("flow_state", "")) == "THREAT", "flow_state survives save/load")
	var old_save: Dictionary = data.duplicate(true)
	old_save.erase("decision_stage_state")
	_player.apply_save_data(old_save)
	check(_player.decision_stage_state.is_empty(), "Old saves without checkpoints still load")


func _same_choice_order(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str((a[i] as Dictionary).get("label", "")) != str((b[i] as Dictionary).get("label", "")):
			return false
	return true


## Tests the reusable engine's shuffle mechanics directly against the
## controller, for every authored threat in every decision stage that
## currently exists (Stage 1 and Stage 2) — nothing here is stage-specific.
func _test_choice_randomization() -> void:
	print("== choice randomization (generic, applies to every decision stage, any choice count) ==")
	# Discovers every authored decision stage across BOTH modules generically,
	# so this test automatically covers new stages (3-choice or 4-choice)
	# without needing another manual edit each time one is added.
	var all_threats: Array[Dictionary] = []
	var covered_stages: Array[String] = []
	var expected_threat_total := 0
	for stage_number in range(1, 10):
		if DecisionScenarios.is_decision_stage("mod_01", stage_number):
			var mod1_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_01", stage_number)
			all_threats.append_array(mod1_threats)
			expected_threat_total += mod1_threats.size()
			covered_stages.append("mod_01:%d" % stage_number)
		if DecisionScenarios.is_decision_stage("mod_02", stage_number):
			var mod2_threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_02", stage_number)
			all_threats.append_array(mod2_threats)
			expected_threat_total += mod2_threats.size()
			covered_stages.append("mod_02:%d" % stage_number)
	check(all_threats.size() == expected_threat_total and all_threats.size() == covered_stages.size() * 3, "Sampling covers exactly 3 threats per authored decision stage %s" % [covered_stages])

	var safe_position_counts: Dictionary = {}
	var critical_position_counts: Dictionary = {}
	var samples := 40
	for _sample in samples:
		for threat in all_threats:
			var threat_id: String = str(threat.get("id", ""))
			var module_id: String = str(threat.get("module_id", "mod_01"))
			var stage_id: int = int(threat.get("stage", 1))
			var authored_choice_count: int = (threat.get("choices", []) as Array).size()
			var ctrl := DecisionStageController.new()
			ctrl.setup(module_id, stage_id, [threat])
			var displayed: Array = ctrl.current_threat_for_display().get("choices", [])
			# 1. Every threat displays exactly as many choices as it authored
			# (3 for Module 1, 4 starting with Module 2) — never a hardcoded count.
			check(displayed.size() == authored_choice_count, "%s displays exactly %d choices" % [threat_id, authored_choice_count])
			# 2. Every displayed set contains exactly one SAFE, one CRITICAL, and
			# fills every remaining slot with RISKY (1 for a 3-choice incident, 2
			# for a 4-choice one) — generalized from the choice count itself.
			var outcomes: Array = []
			for c in displayed:
				outcomes.append(str((c as Dictionary).get("outcome", "")))
			var expected_risky: int = displayed.size() - 2
			check(outcomes.count("SAFE") == 1 and outcomes.count("RISKY") == expected_risky and outcomes.count("CRITICAL") == 1,
				"%s shows exactly one SAFE, %d RISKY and one CRITICAL" % [threat_id, expected_risky])
			# 3. Selecting each displayed button produces the outcome attached
			# to THAT choice, regardless of screen position.
			for i in displayed.size():
				var probe := DecisionStageController.new()
				probe.setup(module_id, stage_id, [threat])
				probe.display_order = ctrl.display_order.duplicate()
				var result: Dictionary = probe.choose(i)
				check(str(result.get("outcome", "")) == str((displayed[i] as Dictionary).get("outcome", "")),
					"%s slot %d selection produces the outcome shown at that slot" % [threat_id, i])
				check(str((result.get("choice", {}) as Dictionary).get("label", "")) == str((displayed[i] as Dictionary).get("label", "")),
					"%s slot %d selection produces the label shown at that slot" % [threat_id, i])
			var safe_pos: int = outcomes.find("SAFE")
			if not safe_position_counts.has(threat_id):
				safe_position_counts[threat_id] = {}
			var per_threat: Dictionary = safe_position_counts[threat_id]
			per_threat[safe_pos] = int(per_threat.get(safe_pos, 0)) + 1
			var critical_pos: int = outcomes.find("CRITICAL")
			if not critical_position_counts.has(threat_id):
				critical_position_counts[threat_id] = {}
			var per_threat_crit: Dictionary = critical_position_counts[threat_id]
			per_threat_crit[critical_pos] = int(per_threat_crit.get(critical_pos, 0)) + 1

	# 4. Across many samples, SAFE is not permanently button 1 / the middle
	# slot (or any other fixed slot) for any threat.
	for threat in all_threats:
		var threat_id: String = str(threat.get("id", ""))
		var per_threat: Dictionary = safe_position_counts.get(threat_id, {})
		check(per_threat.size() > 1, "%s: SAFE is not pinned to one screen position across %d samples (positions seen: %s)" % [threat_id, samples, per_threat.keys()])

	# 4-choice-format-specific (Module 2 onward): SAFE and CRITICAL must each
	# be able to land in EVERY one of the 4 displayed positions across enough
	# samples, not merely "more than one" — button position never determines
	# the outcome.
	for threat in all_threats:
		var choice_count: int = (threat.get("choices", []) as Array).size()
		if choice_count != 4:
			continue
		var threat_id: String = str(threat.get("id", ""))
		var safe_positions: Dictionary = safe_position_counts.get(threat_id, {})
		var critical_positions: Dictionary = critical_position_counts.get(threat_id, {})
		for slot in range(4):
			check(safe_positions.has(slot), "%s: SAFE appears at displayed position %d across %d samples" % [threat_id, slot, samples])
			check(critical_positions.has(slot), "%s: CRITICAL appears at displayed position %d across %d samples" % [threat_id, slot, samples])

	# 12. The same active attempt never reshuffles while it's on screen.
	var stable := DecisionStageController.new()
	stable.setup("mod_01", 1, DecisionScenarios.get_threats("mod_01", 1))
	var first_display: Array = stable.current_threat_for_display().get("choices", []).duplicate(true)
	for _i in 5:
		var again: Array = stable.current_threat_for_display().get("choices", [])
		check(_same_choice_order(first_display, again), "Repeated display of the same attempt keeps the same order")

	# Save/reload before choosing preserves the exact order already shown
	# (checkpoint captures display_order once it has actually been generated).
	var saved_state: Dictionary = stable.checkpoint_state()
	check(not (saved_state.get("display_order", []) as Array).is_empty(), "An unresolved attempt's checkpoint carries its display order")
	var reloaded := DecisionStageController.new()
	reloaded.setup("mod_01", 1, DecisionScenarios.get_threats("mod_01", 1))
	reloaded.restore(saved_state)
	var reload_display: Array = reloaded.current_threat_for_display().get("choices", [])
	check(_same_choice_order(first_display, reload_display), "Save/reload before choosing preserves the same displayed order")

	# 11. Retry after a failure is a new attempt: its checkpoint must not
	# carry the failed attempt's order forward (a fresh shuffle follows).
	var retry_ctrl := DecisionStageController.new()
	retry_ctrl.setup("mod_01", 1, DecisionScenarios.get_threats("mod_01", 1))
	var pre_fail_display: Array = retry_ctrl.current_threat_for_display().get("choices", [])
	var risky_slot := 0
	for i in pre_fail_display.size():
		if str((pre_fail_display[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slot = i
			break
	retry_ctrl.choose(risky_slot)
	retry_ctrl.commit()
	check(retry_ctrl.is_breach_active(), "RISKY still launches the breach flow after randomization")
	retry_ctrl.fail_breach()
	var post_fail_checkpoint: Dictionary = retry_ctrl.checkpoint_state()
	check((post_fail_checkpoint.get("display_order", ["not empty"]) as Array).is_empty(), "A failed attempt's checkpoint does not persist its display order, so retry may reshuffle")

	# CRITICAL failure: same guarantee.
	var critical_ctrl := DecisionStageController.new()
	critical_ctrl.setup("mod_01", 1, DecisionScenarios.get_threats("mod_01", 1))
	var pre_critical_display: Array = critical_ctrl.current_threat_for_display().get("choices", [])
	var critical_slot := 0
	for i in pre_critical_display.size():
		if str((pre_critical_display[i] as Dictionary).get("outcome", "")) == "CRITICAL":
			critical_slot = i
			break
	critical_ctrl.choose(critical_slot)
	var critical_result: Dictionary = critical_ctrl.commit()
	check(str(critical_result.get("outcome", "")) == "CRITICAL", "CRITICAL still Game Overs after randomization")
	var critical_checkpoint: Dictionary = critical_ctrl.checkpoint_state()
	check((critical_checkpoint.get("display_order", ["not empty"]) as Array).is_empty(), "A CRITICAL failure's checkpoint does not persist its display order either")

	# SAFE: still resolves the threat and advances, after randomization.
	var safe_ctrl := DecisionStageController.new()
	safe_ctrl.setup("mod_01", 1, DecisionScenarios.get_threats("mod_01", 1))
	var pre_safe_display: Array = safe_ctrl.current_threat_for_display().get("choices", [])
	var safe_slot := 0
	for i in pre_safe_display.size():
		if str((pre_safe_display[i] as Dictionary).get("outcome", "")) == "SAFE":
			safe_slot = i
			break
	safe_ctrl.choose(safe_slot)
	var safe_result: Dictionary = safe_ctrl.commit()
	check(str(safe_result.get("outcome", "")) == "SAFE" and safe_ctrl.resolved_threats == 1, "SAFE still resolves the threat after randomization")

	# Same save/reload and retry-reshuffle guarantees, explicitly against the
	# new 4-choice format (Module 2 Stage 1), not just the 3-choice one above.
	var stable4 := DecisionStageController.new()
	stable4.setup("mod_02", 1, DecisionScenarios.get_threats("mod_02", 1))
	var first_display4: Array = stable4.current_threat_for_display().get("choices", []).duplicate(true)
	check(first_display4.size() == 4, "[Mod2 randomization] A 4-choice incident displays 4 choices")
	for _i in 5:
		var again4: Array = stable4.current_threat_for_display().get("choices", [])
		check(_same_choice_order(first_display4, again4), "[Mod2 randomization] Repeated display of the same attempt keeps the same 4-choice order")
	var saved_state4: Dictionary = stable4.checkpoint_state()
	check((saved_state4.get("display_order", []) as Array).size() == 4, "[Mod2 randomization] An unresolved 4-choice attempt's checkpoint carries a full display order")
	var reloaded4 := DecisionStageController.new()
	reloaded4.setup("mod_02", 1, DecisionScenarios.get_threats("mod_02", 1))
	reloaded4.restore(saved_state4)
	var reload_display4: Array = reloaded4.current_threat_for_display().get("choices", [])
	check(_same_choice_order(first_display4, reload_display4), "[Mod2 randomization] Save/reload before choosing preserves the same 4-choice displayed order")
	var retry_ctrl4 := DecisionStageController.new()
	retry_ctrl4.setup("mod_02", 1, DecisionScenarios.get_threats("mod_02", 1))
	var pre_fail_display4: Array = retry_ctrl4.current_threat_for_display().get("choices", [])
	var risky_slot4 := 0
	for i in pre_fail_display4.size():
		if str((pre_fail_display4[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slot4 = i
			break
	retry_ctrl4.choose(risky_slot4)
	retry_ctrl4.commit()
	check(retry_ctrl4.is_breach_active(), "[Mod2 randomization] Either RISKY choice still launches the breach flow after 4-way randomization")
	retry_ctrl4.fail_breach()
	var post_fail_checkpoint4: Dictionary = retry_ctrl4.checkpoint_state()
	check((post_fail_checkpoint4.get("display_order", ["not empty"]) as Array).is_empty(), "[Mod2 randomization] A failed 4-choice attempt's checkpoint does not persist its display order, so retry may reshuffle")


func _test_required_scenarios() -> void:
	print("== required restart scenarios ==")
	_player.reset_to_defaults()
	_router.is_tutorial = false
	_router.active_module_id = "mod_01"

	print("-- 1. Fresh Stage 1, Threat 1 SAFE, Threat 2 appears --")
	var level: Node = await _start_match("mod_01", 0)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	check(lm._decision != null, "Stage 1 uses the decision controller")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "No TRACE quiz opened for Stage 1")
	check(overlay != null and overlay.visible and overlay._mode == &"story", "Opening story shown")
	_assert_decision_mode(lm, "Opening story")
	check(_no_forbidden_words(overlay), "Incident UI avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "Threat 1 shown after opening")
	_assert_decision_mode(lm, "Threat 1")
	var pl0: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "SAFE")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "THREAT CONTAINED", "SAFE shows THREAT CONTAINED")
	check(is_equal_approx(_player.get_mastery("phishing"), pl0), "BKT is not applied until consequence CONTINUE")
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1 and not _player.has_cleared_stage("mod_01", 1), "SAFE on Threat 1 does not clear the stage")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Threat 2 follows")
	check(_player.get_decision_stage_state("mod_01:1").get("threat_index", -1) == 1, "Checkpoint written after Threat 1")

	print("-- 7. Close before consequence CONTINUE does not double-apply BKT --")
	var pl_before_pending: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "SAFE")].pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("phishing"), pl_before_pending), "Uncommitted SAFE has not touched BKT")
	await _stop_match()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Reload after uncommitted choice returns to Threat 2")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_before_pending), "Reload did not apply the uncommitted BKT update")

	print("-- 4. Threat 2 CRITICAL, real restart, Threat 2 restored --")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "CRITICAL is an immediate Game Over")
	var _crit_card = level.get_node("BaseDefeatOverlay")
	check(_crit_card._title.text == "SYSTEM COMPROMISED", "[M5] CRITICAL defeat card title is SYSTEM COMPROMISED")
	check(not _crit_card._advisory.text.is_empty(), "[M5] CRITICAL defeat card body is non-empty (shows consequence)")
	check(_crit_card._buttons[0].text == "RETRY", "[M5] CRITICAL card first button is RETRY")
	check(_crit_card._buttons[1].text == "EXIT MISSION", "[M5] CRITICAL card second button is EXIT MISSION")
	check(not _crit_card._buttons[2].visible, "[M5] CRITICAL card has no third button visible")
	check(int(_player.get_decision_stage_state("mod_01:1").get("threat_index", -1)) == 1, "CRITICAL checkpoint stays on Threat 2")
	var credits_after_crit: int = _player.credits
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Real restart after Threat 2 CRITICAL returns to Threat 2")
	check(not lm._decision.stage_failed, "Retry is not permanently failed")
	check(lm._decision.security_state != DecisionStageController.STATE_COMPROMISED, "COMPROMISED does not leak into the retry")
	check(_player.credits == credits_after_crit, "CRITICAL Game Over does not award farmable credits")

	print("-- 9. CRITICAL retry then SAFE continues normally --")
	var pl_retry: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "SAFE on retried Threat 2 continues to Threat 3")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl_retry, true)), "Retry SAFE applies one BKT update")
	await _stop_match()

	print("-- 2. Threat 1 CRITICAL, real restart, skip opening --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var pl_c0: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("phishing"), pl_c0), "CRITICAL BKT waits for CONTINUE")
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl_c0, false)), "CRITICAL commit applies exactly one negative BKT update")
	check(lm.current_phase == lm.GamePhase.GAME_OVER and not _player.has_cleared_stage("mod_01", 1), "CRITICAL never clears the stage")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "Real restart after Threat 1 CRITICAL returns directly to Threat 1")
	check(overlay._continue_button.visible == false, "Opening is not replayed on Threat 1 retry")
	check(not lm._decision.stage_failed, "No previous failure flag remains active")

	print("-- 10. Repeated CRITICAL cannot farm credits --")
	var wallet: int = _player.credits
	for attempt in 3:
		await _pick(lm, overlay, "CRITICAL")
		check(lm.current_phase == lm.GamePhase.GAME_OVER, "Repeated CRITICAL still Game Over")
		check(_player.credits == wallet, "Decision-stage loss payout stays at 0 (attempt %d)" % (attempt + 1))
		level = await _restart_from_game_over(level)
		lm = _level_manager(level)
		overlay = lm._decision_overlay
	check(overlay._header_right.text == "INCIDENT 1 / 3", "After farming attempts the retry is still Threat 1")
	await _stop_match()

	print("-- 3. Threat 1 RISKY, TD loss, real restart --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var pl_r0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and lm.current_wave_index == 0, "RISKY launches Tower Defense on wave 1")
	_assert_fresh_breach(lm, 0, "Threat 1 RISKY")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl_r0, false)), "RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "TD loss during a breach is Game Over")
	var _risky_card = level.get_node("BaseDefeatOverlay")
	check(_risky_card._title.text == "CONTAINMENT FAILED", "[M5] RISKY+TD defeat card title is CONTAINMENT FAILED")
	check("SYSTEM BREACH" in _risky_card._stage.text, "[M5] RISKY+TD subtitle contains SYSTEM BREACH")
	check(not _risky_card._advisory.text.is_empty(), "[M5] RISKY+TD body is non-empty (shows explanation)")
	check(_risky_card._buttons[0].text == "RETRY", "[M5] RISKY+TD first button is RETRY")
	check(_risky_card._buttons[1].text == "EXIT MISSION", "[M5] RISKY+TD second button is EXIT MISSION")
	check(not _risky_card._buttons[2].visible, "[M5] RISKY+TD card has no UPGRADE button visible")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "TD loss applies no BKT update")
	check(_player.credits == 0, "RISKY + TD loss does not award farmable credits")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "Real restart after Threat 1 TD loss returns to Threat 1")
	check(lm._decision.security_state == DecisionStageController.STATE_NOMINAL, "Lost breach retry restores pre-attempt security")
	await _stop_match()

	print("-- Milestone 4: Threat 1 SAFE -> Threat 2 RISKY -> TD LOSS -> RETRY --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1, "Threat 1 resolved")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Threat 2 appears")
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "Threat 2 RISKY starts breach build")
	var pl_after_m4_commit: float = _player.get_mastery("phishing")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "TD loss results in Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._buttons[0].text == "RETRY", "Defeat overlay displays RETRY button (primary slot)")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Retry returns to same Threat 2")
	check(lm._decision.threat_index == 1, "Threat index is 1 (Threat 2)")
	check(lm._decision.resolved_threats == 1, "Threat 1 remains resolved (resolved_threats == 1)")
	var max_hp_m4: int = lm._heart_icons.size() if not lm._heart_icons.is_empty() else 5
	check(lm.base_health == max_hp_m4, "Base HP restored to max (%d)" % max_hp_m4)
	check(lm.active_enemies == 0, "Active enemies == 0")
	check(_alive_track_enemies(lm) == 0, "Track enemies == 0")
	check(_count_projectiles(level) == 0, "Projectiles == 0")
	check(lm.current_wave_index == 0 and lm._wave_kills == 0, "Wave index and kills reset")
	check(level.get_node_or_null("BaseDefeatOverlay") == null, "Defeat overlay is gone")
	check(lm._tower_placer != null and lm._tower_placer.process_mode == Node.PROCESS_MODE_DISABLED, "Combat interaction disabled")
	check(overlay.visible, "Decision overlay is visible")
	check(not lm._decision.stage_failed, "Old failure flag is not leaked")
	check(lm._decision.security_state != DecisionStageController.STATE_COMPROMISED, "Security state is not compromised")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_after_m4_commit), "BKT is not updated again on retry")
	await _stop_match()

	print("-- 11. Threat 1 RISKY, TD WIN, then Threat 2 RISKY starts fresh --")
	_player.reset_to_defaults()
	var mastery_before: float = _player.get_mastery("phishing")
	var credits_before: int = _player.credits
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	_assert_fresh_breach(lm, 0, "Threat 1 RISKY before dirtied state")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 1, "Threat 1 TD win returns to the story")
	check(not _player.has_cleared_stage("mod_01", 1), "Persistent stage progress is not granted by a single contained breach")
	check(_player.credits == credits_before, "Persistent credits are unchanged by the encounter reset")
	_dirty_breach_runtime(lm)
	check(lm.base_health == 1, "Test dirtied leftover HP")
	check(lm.current_gold == 80, "Test dirtied leftover gold")
	check(lm.current_wave_index == 2, "Test dirtied leftover wave")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Threat 2 follows the contained first breach")
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "Threat 2 RISKY launches Tower Defense")
	_assert_fresh_breach(lm, 1, "Threat 2 RISKY after Threat 1 TD win")
	_assert_td_mode(lm, "Threat 2 RISKY after prior win")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, one_bkt_step(_player, mastery_before, false), false)), "Persistent BKT from both RISKY commits is kept")
	await _stop_match()

	print("-- 5. Threat 2 RISKY, TD win, Threat 3 --")
	_player.reset_to_defaults()
	_player.decision_stage_state = {"mod_01:1": {"threat_index": 1, "resolved_threats": 1, "flow_state": "THREAT", "in_breach": false, "security_state": "NOMINAL", "safe_count": 1}}
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Injected checkpoint lands on Threat 2")
	var pl_r2: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "Threat 2 RISKY launches Tower Defense")
	_assert_fresh_breach(lm, 1, "Injected Threat 2 RISKY")
	_assert_td_mode(lm, "Threat 2 RISKY build")
	check(str(_player.get_decision_stage_state("mod_01:1").get("flow_state", "")) == "BREACH", "Checkpoint records BREACH")
	var pl_after_risky: float = _player.get_mastery("phishing")
	check(is_equal_approx(pl_after_risky, one_bkt_step(_player, pl_r2, false)), "RISKY BKT applied once")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "TD win returns to the story and resolves Threat 2")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_after_risky), "TD win applies no BKT update")
	check(overlay.visible and overlay._mode == &"story", "Breach-contained dialogue shown")
	_assert_decision_mode(lm, "After TD win")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "Threat 3 follows the contained breach")

	print("-- 8. RISKY then TD win changed BKT only once --")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_after_risky), "BKT is unchanged after the TD win")

	print("-- 6. Threat 3 SAFE, ending, save/reload, Stage Complete --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT" and not _player.has_cleared_stage("mod_01", 1), "Ending story plays before the stage clears")
	check(str(_player.get_decision_stage_state("mod_01:1").get("flow_state", "")) == "ENDING", "Ending checkpoint is persisted before victory")
	await _stop_match()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT" and not _player.has_cleared_stage("mod_01", 1), "Reload during ending restores the ending dialogue")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 1), "Stage 1 clears after the restored ending")
	check(_player.get_decision_stage_state("mod_01:1").is_empty(), "Checkpoint cleared after stage-clear commit")
	var clear_overlay = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay != null and clear_overlay._title.text == "STAGE 1 COMPLETE", "Stage clear card uses the story title")
	check(clear_overlay != null and clear_overlay._advisory.text.contains("STAGE 2"), "Stage clear card points to Stage 2")
	await _stop_match()

	print("-- replay freeze --")
	_player.reset_to_defaults()
	_player.cleared_stages[_player.stage_progress_key("mod_01", 1)] = true
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var pl_replay: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_replay), "Replay keeps P(L) frozen")
	await _stop_match()


func _test_breach_transition() -> void:
	print("== Milestone 7 / 7.1: RISKY breach transition + affected-system polish ==")
	_player.reset_to_defaults()
	var level: Node = await _start_match("mod_01", 0)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	await _skip_opening(overlay)

	print("-- Threat 1 RISKY: SECURITY WARNING -> BREACH DETECTED (WORKSTATION-07) --")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "Threat 1 RISKY choice shows the SECURITY WARNING consequence")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "TD has not started after the consequence beat")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay.visible and overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "Breach transition beat uses a distinct BREACH DETECTED banner")
	check(overlay._body_scroll.size.y >= 160.0, "[UI-1.1] BREACH DETECTED dialogue box is at least 160px tall (%dpx)" % int(overlay._body_scroll.size.y))
	check(_dialogue_contains(overlay, "WORKSTATION-07"), "Threat 1 breach transition names WORKSTATION-07, not the threat title")
	check(not _dialogue_contains(overlay, "Account Suspension Notice"), "Threat 1 breach transition does not fall back to the threat title")
	check(overlay._continue_button.text == "DEPLOY DEFENSES", "Breach transition offers DEPLOY DEFENSES")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "TD still has not started before DEPLOY DEFENSES is pressed")
	check(not lm._gold_label.visible and not lm._heart_hud.visible, "TD HUD stays hidden during the breach transition")
	check(_no_forbidden_words(overlay), "Breach transition avoids quiz vocabulary")

	print("-- Press DEPLOY DEFENSES: overlay closes, TD HUD appears, combat begins --")
	overlay._continue_button.pressed.emit()
	await settle()
	check(not overlay.visible, "Decision overlay closes once defenses are deployed")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "Tower Defense starts only after DEPLOY DEFENSES")
	_assert_td_mode(lm, "After DEPLOY DEFENSES")

	print("-- TD WIN: BREACH CONTAINED names the same affected system, no next threat yet --")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "Combat stops once the breach is contained")
	check(overlay.visible and overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "BREACH CONTAINED banner is shown instead of jumping ahead")
	check(overlay._body_scroll.size.y >= 160.0, "[UI-1.1] BREACH CONTAINED dialogue box is at least 160px tall (%dpx)" % int(overlay._body_scroll.size.y))
	check(_dialogue_contains(overlay, "WORKSTATION-07"), "BREACH CONTAINED names WORKSTATION-07, matching the breach transition")
	check(overlay._continue_button.text == "CONTINUE INVESTIGATION", "Breach-contained beat offers CONTINUE INVESTIGATION")
	check(overlay._header_right.text == "", "Next threat is not shown until Continue Investigation is pressed")
	check(not lm._gold_label.visible and not lm._heart_hud.visible, "TD HUD hidden during BREACH CONTAINED")
	if lm._tower_placer != null:
		check(lm._tower_placer.process_mode == Node.PROCESS_MODE_DISABLED, "Combat interaction disabled during BREACH CONTAINED")

	print("-- Press CONTINUE INVESTIGATION: Threat 2 appears, decision UI active --")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Continue Investigation reveals the next threat")
	_assert_decision_mode(lm, "After Continue Investigation")

	print("-- SAFE never shows BREACH DETECTED or DEPLOY DEFENSES --")
	overlay._choice_buttons[_button_for_outcome(lm, "SAFE")].pressed.emit()
	await settle()
	check(overlay._continue_button.text != "DEPLOY DEFENSES", "SAFE consequence never offers DEPLOY DEFENSES")
	check(overlay._banner.text != "BREACH DETECTED", "SAFE consequence never shows the BREACH DETECTED banner")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "SAFE proceeds normally to the next threat")

	print("-- Threat 3 RISKY: uses its own configured affected system --")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "Threat 3 breach transition also uses BREACH DETECTED")
	check(_dialogue_contains(overlay, "EMPLOYEE ACCOUNT / MAIL SYSTEM"), "Threat 3 breach transition names its configured affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "Threat 3 RISKY still reaches Tower Defense through the transition")

	print("-- TD LOSS after the breach transition: existing CONTAINMENT FAILED flow --")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "TD loss is still Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[M7 regression] CONTAINMENT FAILED screen is unchanged")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[M7 regression] RETRY works exactly as Milestone 4")
	await _stop_match()

	print("-- Threat 2 RISKY (standalone): affected system = FINANCE-WS-03 --")
	_player.reset_to_defaults()
	_player.decision_stage_state = {"mod_01:1": {"threat_index": 1, "resolved_threats": 1, "flow_state": "THREAT", "in_breach": false, "security_state": "NOMINAL", "safe_count": 1}}
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._header_right.text == "INCIDENT 2 / 3", "Injected checkpoint lands on Threat 2")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "Threat 2 breach transition uses BREACH DETECTED")
	check(_dialogue_contains(overlay, "FINANCE-WS-03"), "Threat 2 breach transition names FINANCE-WS-03")
	await _stop_match()

	print("-- CRITICAL: existing SYSTEM COMPROMISED flow unchanged --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[M7 regression] CRITICAL banner is unchanged")
	check(overlay._body_scroll.size.y >= 160.0, "[UI-1.1] SYSTEM COMPROMISED dialogue box is at least 160px tall (%dpx)" % int(overlay._body_scroll.size.y))
	check(overlay._continue_button.text == "DAMAGE REPORT", "[M7 regression] CRITICAL still shows DAMAGE REPORT, not DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[M7 regression] CRITICAL is still an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[M7 regression] SYSTEM COMPROMISED screen is unchanged")
	await _stop_match()


func _dialogue_contains(overlay, needle: String) -> bool:
	var texts: Array[String] = []
	_collect_texts(overlay, texts)
	for text in texts:
		if text.contains(needle):
			return true
	return false


func _test_stage2() -> void:
	print("== Module 1 Stage 2: They Know Who We Are ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 2 launches the decision controller with 3 stage-2-only incidents --")
	var level: Node = await _start_match("mod_01", 1)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 2] Stage 2 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 2] No TRACE quiz opened for Stage 2")
	check(lm._decision.total_threats() == 3, "[Stage 2] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 2] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 2] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 2] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 2] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 2] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 2] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 2] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 2] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "HR PORTAL / EMPLOYEE ACCOUNTS"), "[Stage 2] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 2] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 2] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 2] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 2] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 2] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 2] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 2] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 2 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 2] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 2] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 2] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 2] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 2] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 2] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 2] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 2] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 2 Complete --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 2] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 2] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 2] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 2), "[Stage 2] Stage 2 clears after the ending")
	var clear_overlay = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay != null and clear_overlay._title.text == "STAGE 2 COMPLETE", "[Stage 2] Stage clear card uses the authored title")
	check(clear_overlay != null and clear_overlay._advisory.text.contains("STAGE 3"), "[Stage 2] Stage clear card points to Stage 3")
	await _stop_match()


func _test_stage3() -> void:
	print("== Module 1 Stage 3: Someone Got In ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 3 launches the decision controller with 3 stage-3-only incidents --")
	var level: Node = await _start_match("mod_01", 2)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 3] Stage 3 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 3] No TRACE quiz opened for Stage 3")
	check(lm._decision.total_threats() == 3, "[Stage 3] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 3] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 3] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 3] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 3] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 3] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 3] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 3] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 3] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "RAMON'S ACCOUNT SESSION"), "[Stage 3] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 3] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 3] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 3] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 3] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 3] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 3] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 3] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 3 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 3] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 3] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 3] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 3] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 3] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 3] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 3] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 3] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 3 Complete, unlocks Stage 4 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 3] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 3] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 3] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 3), "[Stage 3] Stage 3 clears after the ending")
	var clear_overlay = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay != null and clear_overlay._title.text == "STAGE 3 COMPLETE", "[Stage 3] Stage clear card uses the authored title")
	check(clear_overlay != null and clear_overlay._advisory.text.contains("STAGE 4"), "[Stage 3] Stage clear card points to Stage 4")
	await _stop_match()


func _test_stage4() -> void:
	print("== Module 1 Stage 4: The Impostor Inside ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 4 launches the decision controller with 3 stage-4-only incidents --")
	var level: Node = await _start_match("mod_01", 3)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 4] Stage 4 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 4] No TRACE quiz opened for Stage 4")
	check(lm._decision.total_threats() == 3, "[Stage 4] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 4] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 4] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 4] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 4] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 4] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 4] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 4] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 4] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "CONFIDENTIAL PROJECT FOLDER"), "[Stage 4] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 4] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 4] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 4] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 4] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 4] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 4] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 4] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 4 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 4] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 4] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 4] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 4] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 4] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 4] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 4] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 4] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 4 Complete, unlocks Stage 5 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 4] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 4] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 4] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 4), "[Stage 4] Stage 4 clears after the ending")
	var clear_overlay4 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay4 != null and clear_overlay4._title.text == "STAGE 4 COMPLETE", "[Stage 4] Stage clear card uses the authored title")
	check(clear_overlay4 != null and clear_overlay4._advisory.text.contains("STAGE 5"), "[Stage 4] Stage clear card points to Stage 5")
	await _stop_match()


func _test_stage5() -> void:
	print("== Module 1 Stage 5: The Second Key ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 5 launches the decision controller with 3 stage-5-only incidents --")
	var level: Node = await _start_match("mod_01", 4)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 5] Stage 5 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 5] No TRACE quiz opened for Stage 5")
	check(lm._decision.total_threats() == 3, "[Stage 5] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 5] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 5] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 5] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 5] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 5] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 5] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 5] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 5] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "CLOUD ACCOUNT / ACTIVE SESSION"), "[Stage 5] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 5] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 5] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 5] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 5] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 5] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 5] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 5] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 5 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 5] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 5] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 5] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 5] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 5] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 5] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 5] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 5] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 5 Complete, unlocks Stage 6 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 5] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 5] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 5] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 5), "[Stage 5] Stage 5 clears after the ending")
	var clear_overlay5 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay5 != null and clear_overlay5._title.text == "STAGE 5 COMPLETE", "[Stage 5] Stage clear card uses the authored title")
	check(clear_overlay5 != null and clear_overlay5._advisory.text.contains("STAGE 6"), "[Stage 5] Stage clear card points to Stage 6")
	await _stop_match()


func _test_stage6() -> void:
	print("== Module 1 Stage 6: Trusted Files ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 6 launches the decision controller with 3 stage-6-only incidents --")
	var level: Node = await _start_match("mod_01", 5)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 6] Stage 6 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 6] No TRACE quiz opened for Stage 6")
	check(lm._decision.total_threats() == 3, "[Stage 6] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 6] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 6] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 6] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 6] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 6] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 6] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 6] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 6] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "MAILBOX / CLOUD STORAGE"), "[Stage 6] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 6] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 6] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 6] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 6] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 6] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 6] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 6] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 6 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 5)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 6] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 6] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 6] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 6] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 5)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 6] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 6] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 6] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 6] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 6 Complete, unlocks Stage 7 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 5)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 6] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 6] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 6] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 6), "[Stage 6] Stage 6 clears after the ending")
	var clear_overlay6 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay6 != null and clear_overlay6._title.text == "STAGE 6 COMPLETE", "[Stage 6] Stage clear card uses the authored title")
	check(clear_overlay6 != null and clear_overlay6._advisory.text.contains("STAGE 7"), "[Stage 6] Stage clear card points to Stage 7")
	await _stop_match()


func _test_stage7() -> void:
	print("== Module 1 Stage 7: Trusted Supplier ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 7 launches the decision controller with 3 stage-7-only incidents --")
	var level: Node = await _start_match("mod_01", 6)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 7] Stage 7 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 7] No TRACE quiz opened for Stage 7")
	check(lm._decision.total_threats() == 3, "[Stage 7] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 7] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 7] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 7] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 7] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 7] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 7] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 7] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 7] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "PROCUREMENT-WS-02"), "[Stage 7] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 7] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 7] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 7] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 7] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 7] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 7] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 7] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 7 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 6)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 7] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 7] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 7] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 7] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 6)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 7] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 7] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 7] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 7] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 7 Complete, unlocks Stage 8 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 6)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 7] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 7] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 7] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 7), "[Stage 7] Stage 7 clears after the ending")
	var clear_overlay7 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay7 != null and clear_overlay7._title.text == "STAGE 7 COMPLETE", "[Stage 7] Stage clear card uses the authored title")
	check(clear_overlay7 != null and clear_overlay7._advisory.text.contains("STAGE 8"), "[Stage 7] Stage clear card points to Stage 8")
	await _stop_match()


func _test_stage8() -> void:
	print("== Module 1 Stage 8: All Hands ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 8 launches the decision controller with 3 stage-8-only incidents --")
	var level: Node = await _start_match("mod_01", 7)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 8] Stage 8 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 8] No TRACE quiz opened for Stage 8")
	check(lm._decision.total_threats() == 3, "[Stage 8] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 8] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 8] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 8] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 8] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 8] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 8] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 8] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 8] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "SALES ACCOUNT / CLOUD SESSION"), "[Stage 8] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 8] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 8] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 8] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 8] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 8] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 8] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 8] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 8 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 7)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 8] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 8] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 8] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 8] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 7)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 8] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 8] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 8] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 8] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> Stage 8 Complete, unlocks Stage 9 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 7)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 8] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 8] Incident 2 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Stage 8] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 8), "[Stage 8] Stage 8 clears after the ending")
	var clear_overlay8 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay8 != null and clear_overlay8._title.text == "STAGE 8 COMPLETE", "[Stage 8] Stage clear card uses the authored title")
	check(clear_overlay8 != null and clear_overlay8._advisory.text.contains("STAGE 9"), "[Stage 8] Stage clear card points to Stage 9")
	await _stop_match()


func _test_stage9() -> void:
	print("== Module 1 Stage 9: Cut the Line (final story stage, with FINAL CONTAINMENT finale) ==")
	_player.reset_to_defaults()

	print("-- 1/2/3. Stage 9 launches the decision controller with 3 stage-9-only incidents --")
	var level: Node = await _start_match("mod_01", 8)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Stage 9] Stage 9 uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Stage 9] No TRACE quiz opened for Stage 9")
	check(lm._decision.total_threats() == 3, "[Stage 9] Exactly 3 incidents load")
	check(lm._decision.has_finale, "[Stage 9] Controller reports a finale is configured for this stage")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Stage 9] Opening story shown")
	check(_no_forbidden_words(overlay), "[Stage 9] Opening avoids quiz vocabulary")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 9] Incident 1 shown after opening")

	print("-- 4. Incident 1 SAFE -> Incident 2 --")
	var pl0: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 9] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl0, true)), "[Stage 9] SAFE commit applies exactly one positive BKT update")
	check(lm._decision.resolved_threats == 1, "[Stage 9] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY -> BREACH DETECTED -> DEPLOY DEFENSES -> TD WIN -> Incident 3 --")
	var pl1: float = _player.get_mastery("phishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Stage 9] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Stage 9] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "MAILBOX / CLOUD RULES"), "[Stage 9] Breach transition names Incident 2's affected system")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[Stage 9] TD has not started before DEPLOY DEFENSES")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 9] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl1, false)), "[Stage 9] RISKY commit applies BKT once before Tower Defense")
	var pl_td: float = _player.get_mastery("phishing")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Stage 9] TD win resolves Incident 2")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[Stage 9] BREACH CONTAINED shown")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_td), "[Stage 9] TD win applies no BKT update")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 9] Continue Investigation reveals Incident 3")
	await _stop_match()

	print("-- 6. RISKY TD LOSS -> RETRY same Stage 9 incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 9] Incident 1 RISKY reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 9] TD loss is Game Over")
	var defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card != null and defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 9] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 9] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 7. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Stage 9] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 9] CRITICAL is an immediate Game Over")
	var crit_card = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card != null and crit_card._title.text == "SYSTEM COMPROMISED", "[Stage 9] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Stage 9] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 8. All 3 incidents resolved -> FINAL CONTAINMENT, not an immediate Stage Complete --")
	_player.reset_to_defaults()
	level = await _start_match("mod_01", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Stage 9] Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Stage 9] Incident 2 resolved via SAFE")
	var pl_pre_finale: float = _player.get_mastery("phishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "DEPLOY FINAL DEFENSES", "[Stage 9] All 3 incidents resolved shows the FINAL CONTAINMENT prompt, not FILE REPORT")
	check(lm.current_phase != lm.GamePhase.VICTORY, "[Stage 9] Stage does not complete before the finale is played")
	check(not _player.has_cleared_stage("mod_01", 9), "[Stage 9] Stage is not marked cleared before the finale is played")
	check(is_equal_approx(_player.get_mastery("phishing"), one_bkt_step(_player, pl_pre_finale, true)), "[Stage 9] Incident 3's SAFE commit applies exactly one BKT update (the finale adds none)")

	print("-- 9. FINAL CONTAINMENT TD LOSS -> CONTAINMENT FAILED -> RETRY replays the finale, never Incident 3, no BKT change --")
	var pl_before_finale_loss: float = _player.get_mastery("phishing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 9] DEPLOY FINAL DEFENSES starts the finale Tower Defense")
	check(lm._decision.is_finale_active(), "[Stage 9] Controller reports the finale encounter is active")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Stage 9] Finale TD loss is Game Over")
	var finale_defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(finale_defeat_card != null and finale_defeat_card._title.text == "CONTAINMENT FAILED", "[Stage 9] CONTAINMENT FAILED shown on finale TD loss")
	check(finale_defeat_card != null and finale_defeat_card._stage.text == "BLUETECH CORE NETWORK", "[Stage 9] Finale defeat card names the finale's affected system, from data")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_before_finale_loss), "[Stage 9] Finale TD loss applies no BKT update")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(lm._decision.resolved_threats == 3, "[Stage 9] Retry after finale loss keeps all 3 incidents resolved")
	check(overlay._mode == &"story" and overlay._continue_button.text == "DEPLOY FINAL DEFENSES", "[Stage 9] Retry after finale loss replays the finale prompt, never Incident 3")

	print("-- [Boss/Finale] Exiting mid-active-finale and reloading preserves finale state (checkpoint_state()/restore()), never re-litigating Incident 3 --")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and lm._decision.is_finale_active(), "[Boss/Finale] Finale Tower Defense is active before the simulated exit")
	await _stop_match()
	level = await _start_match("mod_01", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(lm._decision.is_finale_active() and lm._decision.resolved_threats == 3, "[Boss/Finale] Reloading mid-finale restores the finale flow state and keeps all 3 incidents resolved")
	# mod01_stage9 authors no "resume_finale" text, so _show_decision_story()
	# finds nothing to show and calls straight through to _begin_decision_finale()
	# — the finale restarts immediately rather than pausing on a DEPLOY prompt.
	# Either way, the guarantee holds: never Incident 3, never a lost/duplicated attempt.
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and lm._decision.is_finale_active(),
		"[Boss/Finale] Reloading mid-finale goes straight back into the finale Tower Defense — never Incident 3, never stuck mid-battle with lost state")

	print("-- 10. FINAL CONTAINMENT TD WIN -> CONTAINMENT COMPLETE -> CASE CLOSED -> MODULE 1 STORY COMPLETE -> Stage 9 clears, unlocks Stage 10 --")
	var pl_before_finale_win: float = _player.get_mastery("phishing")
	# Already inside the finale Tower Defense from the reload check just above.
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("phishing"), pl_before_finale_win), "[Stage 9] Finale TD win applies no BKT update")
	check(overlay._mode == &"story" and overlay._banner.text == "CONTAINMENT COMPLETE", "[Stage 9] Finale win shows CONTAINMENT COMPLETE")
	check(lm.current_phase != lm.GamePhase.VICTORY, "[Stage 9] Stage still not complete before the case-closed epilogue plays")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"story" and overlay._banner.text == "CASE CLOSED", "[Stage 9] Case summary shows CASE CLOSED")
	check(_dialogue_contains(overlay, "Accounts Secured"), "[Stage 9] Case summary lists the authored case-closed items")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"story" and overlay._banner.text == "MODULE 1 STORY COMPLETE" and overlay._continue_button.text == "FILE REPORT", "[Stage 9] Closing dialogue shows MODULE 1 STORY COMPLETE with FILE REPORT")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_01", 9), "[Stage 9] Stage 9 clears only after the finale and its epilogue")
	var clear_overlay9 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay9 != null and clear_overlay9._title.text == "STAGE 9 COMPLETE", "[Stage 9] Stage clear card uses the authored title")
	check(clear_overlay9 != null and clear_overlay9._advisory.text.contains("STAGE 10"), "[Stage 9] Stage clear card points to Stage 10")
	await _stop_match()

	print("-- 11. Stage 10 stays the existing post-assessment, never the decision-story live scene --")
	check(not DecisionScenarios.is_decision_stage("mod_01", 10), "[Stage 9] Stage 10 remains a non-decision (TRACE/post-assessment) stage")
	await _stop_match()


func _test_module2_stage1() -> void:
	print("== Module 2 Stage 1: Unknown Number (new 4-choice format: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_router.active_module_id = "mod_02"

	print("-- 1/2/3. Stage launches the decision controller with 3 stage-1-only incidents, each with 4 choices --")
	var level: Node = await _start_match("mod_02", 0)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 1] Uses the decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 1] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 1] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 1] Opening story shown")
	check(_no_forbidden_words(overlay), "[Mod2 Stage 1] Opening avoids quiz vocabulary")
	check(_dialogue_contains(overlay, "I keep getting weird texts"), "[Mod2 Stage 1] Opening establishes Leah's personal-life setting, not a BlueTech workplace incident")
	check(_dialogue_contains(overlay, "LEAH"), "[Mod2 Stage 1] Leah is a supported, distinctly named speaker")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 1] Incident 1 shown after opening")
	var displayed1: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(displayed1.size() == 4, "[Mod2 Stage 1] Incident 1 displays 4 choices")
	var risky_indices: Array[int] = []
	for i in displayed1.size():
		if str((displayed1[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_indices.append(i)
	check(risky_indices.size() == 2, "[Mod2 Stage 1] Incident 1 displays exactly two RISKY choices")

	print("-- 4. Incident 1 SAFE -> Incident 2, BKT on the smishing skill --")
	var pl0: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 1] SAFE on Incident 1 continues to Incident 2")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, pl0, true)), "[Mod2 Stage 1] SAFE commit applies exactly one positive BKT update on smishing")
	check(lm._decision.resolved_threats == 1, "[Mod2 Stage 1] Incident 1 resolved")

	print("-- 5. Incident 2 RISKY (first of two) -> breach -> TD WIN -> Incident 3 shows the dramatic beat --")
	var pl1: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 1] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "BREACH DETECTED", "[Mod2 Stage 1] Breach transition shows BREACH DETECTED")
	check(_dialogue_contains(overlay, "LEAH'S E-WALLET"), "[Mod2 Stage 1] Breach transition names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 1] DEPLOY DEFENSES starts Tower Defense")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, pl1, false)), "[Mod2 Stage 1] RISKY commit applies BKT once before Tower Defense")
	await _force_td_win(lm)
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and lm._decision.resolved_threats == 2, "[Mod2 Stage 1] TD win resolves Incident 2")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 1] Continue Investigation reveals Incident 3")
	check(_dialogue_contains(overlay, "I opened one of the messages earlier"), "[Mod2 Stage 1] Incident 3 opens with Leah's dramatic-beat admission")
	check(_dialogue_contains(overlay, "we treat that interaction as evidence"), "[Mod2 Stage 1] Dramatic beat plays out without Mia attacking or insulting Leah")

	print("-- 6. Incident 3 SAFE -> ending -> Stage 1 clears, unlocks Module 2 Stage 2 --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT", "[Mod2 Stage 1] Ending story plays before the stage clears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 1), "[Mod2 Stage 1] Stage clears after the ending")
	var clear_overlay_m2 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay_m2 != null and clear_overlay_m2._title.text == "STAGE 1 COMPLETE", "[Mod2 Stage 1] Stage clear card uses the authored title")
	check(clear_overlay_m2 != null and clear_overlay_m2._advisory.text.contains("STAGE 2"), "[Mod2 Stage 1] Stage clear card points to Stage 2")
	await _stop_match()

	print("-- 7. The OTHER RISKY choice on Incident 1 also reaches the breach flow, and TD loss retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed1b: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_indices_b: Array[int] = []
	for i in displayed1b.size():
		if str((displayed1b[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_indices_b.append(i)
	overlay._choice_buttons[risky_indices_b[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 1] The second RISKY choice also reaches Tower Defense")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 1] TD loss is Game Over")
	var defeat_card_m2 = level.get_node_or_null("BaseDefeatOverlay")
	check(defeat_card_m2 != null and defeat_card_m2._title.text == "CONTAINMENT FAILED", "[Mod2 Stage 1] CONTAINMENT FAILED shown on TD loss")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 1] Retry after TD loss returns to the same incident")
	await _stop_match()

	print("-- 8. CRITICAL -> SYSTEM COMPROMISED -> RETRY same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var pl_crit: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 1] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 1] CRITICAL is an immediate Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, pl_crit, false)), "[Mod2 Stage 1] CRITICAL commit applies exactly one negative BKT update")
	var crit_card_m2 = level.get_node_or_null("BaseDefeatOverlay")
	check(crit_card_m2 != null and crit_card_m2._title.text == "SYSTEM COMPROMISED", "[Mod2 Stage 1] SYSTEM COMPROMISED card shown")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 1] Retry after CRITICAL returns to the same incident")
	await _stop_match()

	print("-- 9. No cross-module checkpoint collision: mod_01:1 progress never leaks into mod_02:1 --")
	_player.reset_to_defaults()
	_router.active_module_id = "mod_01"
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1, "[Cross-module] Module 1 Stage 1 advances to its own Incident 2")
	await _stop_match()
	_router.active_module_id = "mod_02"
	level = await _start_match("mod_02", 0)
	lm = _level_manager(level)
	check(lm._decision.resolved_threats == 0 and lm._decision.total_threats() == 3, "[Cross-module] Module 2 Stage 1 starts completely fresh despite Module 1 Stage 1 progress")
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	check(overlay._header_right.text == "INCIDENT 1 / 3", "[Cross-module] Module 2 Stage 1 shows its own Incident 1, not Module 1's Incident 2")
	await _stop_match()
	check(_player.decision_stage_state.get("mod_01:1", {}) != _player.decision_stage_state.get("mod_02:1", {}), "[Cross-module] mod_01:1 and mod_02:1 are distinct checkpoint entries")
	_router.active_module_id = "mod_01"


func _test_module2_stage2() -> void:
	print("== Module 2 Stage 2: Expected Delivery (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3. Stage 2 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 1)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 2] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 2] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 2] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 2] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "headphones I ordered three days ago"), "[Mod2 Stage 2] Opening continues Leah's delivery story")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 2] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 2] Incident 1 displays all 4 randomized choices")

	print("-- 4/11. SAFE resolves Incident 1 and applies one positive smishing BKT update --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 2] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 2] SAFE updates BKT positively exactly once")

	print("-- 6/12/15. One RISKY option commits once, enters breach TD, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 2] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "LEAH'S E-WALLET / PAYMENT DETAILS"), "[Mod2 Stage 2] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 2] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.70), "[Mod2 Stage 2] Active breach uses only its authored 0.70 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 2] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 2] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 2] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 2] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "The package is here"), "[Mod2 Stage 2] Incident 3 begins with the real-delivery dramatic beat")
	check(_dialogue_contains(overlay, "someone is reading my life"), "[Mod2 Stage 2] Leah's reaction preserves the requested tension")

	print("-- 16/17/18/22. Completion marks mod_02:2 only, unlocks mod_02:3, and preserves the cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "This one's from you"), "[Mod2 Stage 2] Ending contains the Mia-impersonation cliffhanger")
	check(_dialogue_contains(overlay, "I didn't send you anything"), "[Mod2 Stage 2] Ending stops on Mia denying the message")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 2), "[Mod2 Stage 2] Completion marks mod_02:2")
	check(not _player.has_cleared_stage("mod_01", 2), "[Mod2 Stage 2] Completion does not mark mod_01:2")
	check(root.get_node("StageManager").access_reason(3, "mod_02").is_empty(), "[Mod2 Stage 2] Completion unlocks mod_02:3")
	var clear_overlay = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay != null and clear_overlay._title.text == "STAGE 2 COMPLETE", "[Mod2 Stage 2] Stage clear uses the authored title")
	check(clear_overlay != null and clear_overlay._advisory.text.contains("STAGE 3"), "[Mod2 Stage 2] Stage clear points to Stage 3")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots: Array[int] = []
	for i in displayed.size():
		if str((displayed[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots.append(i)
	check(risky_slots.size() == 2 and risky_slots[0] != risky_slots[1], "[Mod2 Stage 2] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 2] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 2] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 2] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 2] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 2] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 2] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 2] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 2] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 2] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage3() -> void:
	print("== Module 2 Stage 3: Someone You Know (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4. Stage 3 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 2)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 3] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 3] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 3] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 3] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "This one's from you"), "[Mod2 Stage 3] Opening continues directly from Stage 2's cliffhanger")
	check(_dialogue_contains(overlay, "Mims"), "[Mod2 Stage 3] Opening establishes the attacker now impersonates people Leah knows")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 3] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 3] Incident 1 displays all 4 randomized choices")

	print("-- 11. SAFE resolves Incident 1 and applies one positive smishing BKT update --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 3] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 3] SAFE updates BKT positively exactly once")

	print("-- 12/15/22. One RISKY option commits once, enters breach TD at 0.75 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 3] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "LEAH'S E-WALLET / PERSONAL CONTACTS"), "[Mod2 Stage 3] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 3] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.75), "[Mod2 Stage 3] Active breach uses only its authored 0.75 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 3] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 3] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 3] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 3] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "building versions of us"), "[Mod2 Stage 3] Incident 3 opens with the dramatic beat about pieced-together identity")
	check(_dialogue_contains(overlay, "Please don't call Mom"), "[Mod2 Stage 3] Incident 3 includes the family-emergency message discouraging verification")

	print("-- 17/18/23. Completion marks mod_02:3 only, unlocks mod_02:4, and sets up the OTP cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "They used my mother"), "[Mod2 Stage 3] Ending reveals there was no real emergency")
	check(_dialogue_contains(overlay, "verification code"), "[Mod2 Stage 3] Ending contains the unexpected-OTP setup for Stage 4")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 3), "[Mod2 Stage 3] Completion marks mod_02:3")
	check(not _player.has_cleared_stage("mod_01", 3), "[Mod2 Stage 3] Completion does not mark mod_01:3 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(4, "mod_02").is_empty(), "[Mod2 Stage 3] Completion unlocks mod_02:4")
	var clear_overlay3 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay3 != null and clear_overlay3._title.text == "STAGE 3 COMPLETE", "[Mod2 Stage 3] Stage clear uses the authored title")
	check(clear_overlay3 != null and clear_overlay3._advisory.text.contains("STAGE 4"), "[Mod2 Stage 3] Stage clear points to Stage 4")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed3: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots3: Array[int] = []
	for i in displayed3.size():
		if str((displayed3[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots3.append(i)
	check(risky_slots3.size() == 2 and risky_slots3[0] != risky_slots3[1], "[Mod2 Stage 3] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots3[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 3] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 3] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 3] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 3] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 3] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 3] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 3] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 3] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 3] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage4() -> void:
	print("== Module 2 Stage 4: The Code (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4. Stage 4 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 3)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 4] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 4] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 4] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 4] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "It's a verification code"), "[Mod2 Stage 4] Opening continues directly from Stage 3's unrequested-OTP cliffhanger")
	check(_dialogue_contains(overlay, "The code can be real"), "[Mod2 Stage 4] Opening establishes the code itself can be genuine")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 4] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 4] Incident 1 displays all 4 randomized choices")

	print("-- 11. SAFE resolves Incident 1 and applies one positive smishing BKT update --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 4] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 4] SAFE updates BKT positively exactly once")

	print("-- 12/15/22. One RISKY option commits once, enters breach TD at 0.80 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 4] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "LEAH'S E-WALLET / ACCOUNT RECOVERY"), "[Mod2 Stage 4] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 4] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.80), "[Mod2 Stage 4] Active breach uses only its authored 0.80 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 4] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 4] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 4] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 4] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "I almost sent it"), "[Mod2 Stage 4] Incident 3 opens with the dramatic beat about the changed reason behind the same rule")
	check(_dialogue_contains(overlay, "took the rule I knew"), "[Mod2 Stage 4] Dramatic beat names the attacker reusing a known rule with a different reason")
	check(_dialogue_contains(overlay, "Account Protection Team"), "[Mod2 Stage 4] Incident 3 introduces the fake Account Protection Team narrative")

	print("-- 17/18/23. Completion marks mod_02:4 only, unlocks mod_02:5, and sets up the lockout cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "It just logged me out"), "[Mod2 Stage 4] Ending reveals Leah is logged out despite resolving every incident correctly")
	check(_dialogue_contains(overlay, "recovery number was changed"), "[Mod2 Stage 4] Ending shows the recovery method was already changed before Leah could act")
	check(_dialogue_contains(overlay, "I'm locked out"), "[Mod2 Stage 4] Ending contains the lockout setup for Stage 5")
	check(_dialogue_contains(overlay, "First, we find out what they changed"), "[Mod2 Stage 4] Ending frames the lockout as an investigation, not a punishment")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 4), "[Mod2 Stage 4] Completion marks mod_02:4")
	check(not _player.has_cleared_stage("mod_01", 4), "[Mod2 Stage 4] Completion does not mark mod_01:4 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(5, "mod_02").is_empty(), "[Mod2 Stage 4] Completion unlocks mod_02:5")
	var clear_overlay4 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay4 != null and clear_overlay4._title.text == "STAGE 4 COMPLETE", "[Mod2 Stage 4] Stage clear uses the authored title")
	check(clear_overlay4 != null and clear_overlay4._advisory.text.contains("STAGE 5"), "[Mod2 Stage 4] Stage clear points to Stage 5")
	await _stop_match()

	print("-- 23. A fully SAFE playthrough still reaches the identical lockout ending (escalation, not punishment) --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 4] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 4] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "I'm locked out"), "[Mod2 Stage 4] All-SAFE run still reaches the lockout ending")
	check(_dialogue_contains(overlay, "First, we find out what they changed"), "[Mod2 Stage 4] All-SAFE run's lockout is framed as story escalation, not a consequence of the correct SAFE decisions")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 4), "[Mod2 Stage 4] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed4: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots4: Array[int] = []
	for i in displayed4.size():
		if str((displayed4[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots4.append(i)
	check(risky_slots4.size() == 2 and risky_slots4[0] != risky_slots4[1], "[Mod2 Stage 4] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots4[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 4] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 4] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 4] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 4] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 4] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 4] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 4] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 4] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 4] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage5() -> void:
	print("== Module 2 Stage 5: Locked Out (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4. Stage 5 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 4)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 5] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 5] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 5] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 5] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "Try it again"), "[Mod2 Stage 5] Opening continues directly from Stage 4's lockout ending")
	check(_dialogue_contains(overlay, "They changed the recovery path"), "[Mod2 Stage 5] Opening establishes the recovery path itself was taken over")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 5] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 5] Incident 1 displays all 4 randomized choices")

	print("-- 11/24. SAFE resolves Incident 1, applies one positive smishing BKT update, and the impersonation drama plays regardless --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 5] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 5] SAFE updates BKT positively exactly once")
	check(_dialogue_contains(overlay, "asking everyone for money"), "[Mod2 Stage 5] Incident 2 opens with the impersonation dramatic beat")
	check(_dialogue_contains(overlay, "isn't hiding anymore"), "[Mod2 Stage 5] Dramatic beat confirms the attacker is now acting openly as Leah")

	print("-- 12/15/22. One RISKY option commits once, enters breach TD at 0.85 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 5] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "LEAH'S MESSAGING ACCOUNT / CONTACTS"), "[Mod2 Stage 5] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 5] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.85), "[Mod2 Stage 5] Active breach uses only its authored 0.85 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 5] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 5] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 5] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 5] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "I clicked one message four stages ago"), "[Mod2 Stage 5] Incident 3 opens with Leah's guilt over her Stage 1 click")
	check(_dialogue_contains(overlay, "We still don't know that's how they got in"), "[Mod2 Stage 5] Story explicitly leaves the true entry point unresolved")
	check(_dialogue_contains(overlay, "we may leave the real one open"), "[Mod2 Stage 5] Security Assistant explains why the entry point can't be assumed yet")

	print("-- 17/18/25. Completion marks mod_02:5 only, unlocks mod_02:6, and sets up the No Service cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "I'm back in"), "[Mod2 Stage 5] Ending shows Leah regains access to her account")
	check(_dialogue_contains(overlay, "It doesn't feel like mine anymore"), "[Mod2 Stage 5] Ending preserves Leah's emotional toll even after recovery")
	check(_dialogue_contains(overlay, "I have no signal"), "[Mod2 Stage 5] Ending contains the No Service cliffhanger for Stage 6")
	check(_dialogue_contains(overlay, "we may have found the next part of the attack"), "[Mod2 Stage 5] Ending frames the signal loss as the next unresolved thread, not a conclusion")
	check(not _dialogue_contains(overlay, "SIM swap"), "[Mod2 Stage 5] Ending does not explicitly name the SIM swap yet")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 5), "[Mod2 Stage 5] Completion marks mod_02:5")
	check(not _player.has_cleared_stage("mod_01", 5), "[Mod2 Stage 5] Completion does not mark mod_01:5 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(6, "mod_02").is_empty(), "[Mod2 Stage 5] Completion unlocks mod_02:6")
	var clear_overlay5 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay5 != null and clear_overlay5._title.text == "STAGE 5 COMPLETE", "[Mod2 Stage 5] Stage clear uses the authored title")
	check(clear_overlay5 != null and clear_overlay5._advisory.text.contains("STAGE 6"), "[Mod2 Stage 5] Stage clear points to Stage 6")
	await _stop_match()

	print("-- 24. A fully SAFE playthrough still includes Leah's guilt/emotional dialogue and reaches the same cliffhanger --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 5] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 5] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	check(_dialogue_contains(overlay, "I clicked one message four stages ago"), "[Mod2 Stage 5] All-SAFE run still includes Leah's guilt dialogue")
	check(_dialogue_contains(overlay, "But it's my name"), "[Mod2 Stage 5] All-SAFE run still includes Leah's emotional reaction to the impersonation")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "I have no signal"), "[Mod2 Stage 5] All-SAFE run still reaches the No Service cliffhanger")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 5), "[Mod2 Stage 5] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed5: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots5: Array[int] = []
	for i in displayed5.size():
		if str((displayed5[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots5.append(i)
	check(risky_slots5.size() == 2 and risky_slots5[0] != risky_slots5[1], "[Mod2 Stage 5] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots5[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 5] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 5] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 5] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 5] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 5] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 5] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 5] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 5] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 5] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage6() -> void:
	print("== Module 2 Stage 6: No Signal (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4. Stage 6 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 5)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 6] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 6] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 6] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 6] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "It still says No Service"), "[Mod2 Stage 6] Opening continues directly from Stage 5's No Service cliffhanger")
	check(_dialogue_contains(overlay, "eSIM activation"), "[Mod2 Stage 6] Opening establishes the unauthorized eSIM activation")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 6] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 6] Incident 1 displays all 4 randomized choices")

	print("-- 11/25. SAFE resolves Incident 1, applies one positive smishing BKT update, and the number-as-master-key drama plays regardless --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 6] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 6] SAFE updates BKT positively exactly once")
	check(_dialogue_contains(overlay, "They took my phone number"), "[Mod2 Stage 6] Incident 2 opens with the dramatic beat about the number as a recovery master key")
	check(_dialogue_contains(overlay, "How many codes did they get"), "[Mod2 Stage 6] Dramatic beat raises the scope of exposed recovery codes")

	print("-- 12/15/22. One RISKY option commits once, enters breach TD at 0.90 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 6] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "LEAH'S SMS RECOVERY ACCOUNTS"), "[Mod2 Stage 6] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 6] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.90), "[Mod2 Stage 6] Active breach uses only its authored 0.90 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 6] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 6] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 6] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 6] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "the attack wasn't random"), "[Mod2 Stage 6] Incident 3 opens with the mid-stage drama about the attack's specificity")
	check(_dialogue_contains(overlay, "We still need one more piece"), "[Mod2 Stage 6] Mid-stage drama withholds the BlueTech connection")
	check(_dialogue_contains(overlay, "fraud department"), "[Mod2 Stage 6] Incident 3 introduces the fake fraud-team caller")

	print("-- 17/18/24/26/27. Completion marks mod_02:6 only, unlocks mod_02:7, and sets up Ramon's brother reveal --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "I have service"), "[Mod2 Stage 6] Ending shows Leah's signal restored")
	check(_dialogue_contains(overlay, "Before the first text"), "[Mod2 Stage 6] Ending reveals attacker activity predates Leah's Stage 1 click")
	check(_dialogue_contains(overlay, "Because now I'm angry"), "[Mod2 Stage 6] Ending shows Leah's guilt shifting into determination")
	check(_dialogue_contains(overlay, "activated a new SIM on his account"), "[Mod2 Stage 6] Ending introduces Ramon's brother experiencing a similar takeover")
	check(_dialogue_contains(overlay, "wasn't the only target"), "[Mod2 Stage 6] Ending explicitly establishes Leah was not the only target")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 6), "[Mod2 Stage 6] Completion marks mod_02:6")
	check(not _player.has_cleared_stage("mod_01", 6), "[Mod2 Stage 6] Completion does not mark mod_01:6 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(7, "mod_02").is_empty(), "[Mod2 Stage 6] Completion unlocks mod_02:7")
	var clear_overlay6 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay6 != null and clear_overlay6._title.text == "STAGE 6 COMPLETE", "[Mod2 Stage 6] Stage clear uses the authored title")
	check(clear_overlay6 != null and clear_overlay6._advisory.text.contains("STAGE 7"), "[Mod2 Stage 6] Stage clear points to Stage 7")
	await _stop_match()

	print("-- 30. A fully SAFE playthrough still reaches the same narrative revelations --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 5)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 6] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 6] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	check(_dialogue_contains(overlay, "the attack wasn't random"), "[Mod2 Stage 6] All-SAFE run still includes the mid-stage drama")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "Before the first text"), "[Mod2 Stage 6] All-SAFE run still reveals the attack predates Stage 1")
	check(_dialogue_contains(overlay, "wasn't the only target"), "[Mod2 Stage 6] All-SAFE run still reaches the Ramon cliffhanger")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 6), "[Mod2 Stage 6] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 5)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed6: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots6: Array[int] = []
	for i in displayed6.size():
		if str((displayed6[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots6.append(i)
	check(risky_slots6.size() == 2 and risky_slots6[0] != risky_slots6[1], "[Mod2 Stage 6] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots6[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 6] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 6] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 6] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 6] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 6] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 5)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 6] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 6] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 6] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 6] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage7() -> void:
	print("== Module 2 Stage 7: Not Just Leah (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4. Stage 7 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 6)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 7] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 7] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 7] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 7] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "His phone still has no service"), "[Mod2 Stage 7] Opening continues directly from Stage 6's Ramon call")
	check(_dialogue_contains(overlay, "Leah may not be the only person being targeted"), "[Mod2 Stage 7] Opening establishes the multi-victim premise")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 7] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 7] Incident 1 displays all 4 randomized choices")
	check(_dialogue_contains(overlay, "Paolo"), "[Mod2 Stage 7] Incident 1 introduces Paolo")

	print("-- 11/22/23. SAFE resolves Incident 1, applies one positive smishing BKT update, and the BlueTech-link reveal plays regardless --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 7] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 7] SAFE updates BKT positively exactly once")
	check(_dialogue_contains(overlay, "...BlueTech."), "[Mod2 Stage 7] Incident 2 opens with the post-incident BlueTech-link reveal")
	check(_dialogue_contains(overlay, "Two cases aren't enough"), "[Mod2 Stage 7] Security Assistant withholds conclusion until a third case is found")

	print("-- 12/15/22. One RISKY option commits once, enters breach TD at 0.95 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 7] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "MULTIPLE PERSONAL MOBILE ACCOUNTS"), "[Mod2 Stage 7] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 7] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.95), "[Mod2 Stage 7] Active breach uses only its authored 0.95 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 7] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 7] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 7] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 7] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "This is yours too"), "[Mod2 Stage 7] Incident 3 opens with Leah asserting herself as part of the investigation")
	check(_dialogue_contains(overlay, "BLUETECH SECURITY"), "[Mod2 Stage 7] Incident 3 introduces the fake BlueTech Security SMS")

	print("-- 17/18/26/27/30/31. Completion marks mod_02:7 only, unlocks mod_02:8, and launches the coordinated wave cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "Every one of them is directly connected to someone who does"), "[Mod2 Stage 7] Ending confirms the common link is proximity to BlueTech, not employment")
	check(_dialogue_contains(overlay, "I don't know"), "[Mod2 Stage 7] Ending withholds the attacker's ultimate motive")
	check(_dialogue_contains(overlay, "hitting everyone they found"), "[Mod2 Stage 7] Ending launches the coordinated wave cliffhanger for Stage 8")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 7), "[Mod2 Stage 7] Completion marks mod_02:7")
	check(not _player.has_cleared_stage("mod_01", 7), "[Mod2 Stage 7] Completion does not mark mod_01:7 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(8, "mod_02").is_empty(), "[Mod2 Stage 7] Completion unlocks mod_02:8")
	var clear_overlay7 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay7 != null and clear_overlay7._title.text == "STAGE 7 COMPLETE", "[Mod2 Stage 7] Stage clear uses the authored title")
	check(clear_overlay7 != null and clear_overlay7._advisory.text.contains("STAGE 8"), "[Mod2 Stage 7] Stage clear points to Stage 8")
	await _stop_match()

	print("-- 34. A fully SAFE playthrough still reaches the same major story reveal --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 6)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 7] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 7] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	check(_dialogue_contains(overlay, "This is yours too"), "[Mod2 Stage 7] All-SAFE run still includes Leah's active-participant beat")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "Every one of them is directly connected to someone who does"), "[Mod2 Stage 7] All-SAFE run still reaches the major story reveal")
	check(_dialogue_contains(overlay, "hitting everyone they found"), "[Mod2 Stage 7] All-SAFE run still reaches the coordinated wave cliffhanger")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 7), "[Mod2 Stage 7] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 6)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed7: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots7: Array[int] = []
	for i in displayed7.size():
		if str((displayed7[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots7.append(i)
	check(risky_slots7.size() == 2 and risky_slots7[0] != risky_slots7[1], "[Mod2 Stage 7] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots7[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 7] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 7] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 7] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 7] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 7] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 6)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 7] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 7] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 7] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 7] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage8() -> void:
	print("== Module 2 Stage 8: Close to Home (4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4. Stage 8 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_02", 7)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 8] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 8] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 8] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 8] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "Multiple phones begin vibrating"), "[Mod2 Stage 8] Opening continues directly from Stage 7's coordinated-wave cliffhanger")
	check(_dialogue_contains(overlay, "and their families another"), "[Mod2 Stage 8] Opening establishes the attacker is messaging both employees and families")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 8] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 8] Incident 1 displays all 4 randomized choices")
	check(_dialogue_contains(overlay, "not to talk to each other"), "[Mod2 Stage 8] Incident 1 presents the mirrored Mia/Leah isolation messages")

	print("-- 11. SAFE resolves Incident 1 and applies one positive smishing BKT update --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 8] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 8] SAFE updates BKT positively exactly once")
	check(_dialogue_contains(overlay, "the code is real"), "[Mod2 Stage 8] Incident 2 opens establishing Paolo's OTP is genuinely real")
	check(_dialogue_contains(overlay, "using me to make him trust the code"), "[Mod2 Stage 8] Incident 2 shows Ramon's trust being exploited to move the real code")

	print("-- 12/15/22. One RISKY option commits once, enters breach TD at 1.00 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 8] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "RAMON / PAOLO / ACCOUNT RECOVERY"), "[Mod2 Stage 8] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 8] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 1.00), "[Mod2 Stage 8] Active breach uses only its authored 1.00 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 8] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 8] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 8] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 8] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "two messages that convince each other"), "[Mod2 Stage 8] Incident 3 opens with the mirrored-message dramatic beat")
	check(_dialogue_contains(overlay, "So did mine"), "[Mod2 Stage 8] Incident 3 shows Leah actively helping another victim recognize the pattern")
	check(_dialogue_contains(overlay, "coordinated wave"), "[Mod2 Stage 8] Incident 3 introduces the coordinated multi-victim campaign")

	print("-- 17/18/28/29/30/31. Completion marks mod_02:8 only, unlocks mod_02:9, and sets up the recovery-request cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "Leverage against the employees"), "[Mod2 Stage 8] Ending reveals the victims were leverage against BlueTech employees")
	check(_dialogue_contains(overlay, "Recovery authority"), "[Mod2 Stage 8] Ending reveals the shared trait among targeted employees is recovery/approval authority")
	check(_dialogue_contains(overlay, "Not a personal one"), "[Mod2 Stage 8] Ending introduces the new, unresolved BlueTech recovery request")
	check(not _dialogue_contains(overlay, "admin console") and not _dialogue_contains(overlay, "master key"), "[Mod2 Stage 8] Ending does not reveal the exact final BlueTech target")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 8), "[Mod2 Stage 8] Completion marks mod_02:8")
	check(not _player.has_cleared_stage("mod_01", 8), "[Mod2 Stage 8] Completion does not mark mod_01:8 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(9, "mod_02").is_empty(), "[Mod2 Stage 8] Completion unlocks mod_02:9")
	var clear_overlay8 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay8 != null and clear_overlay8._title.text == "STAGE 8 COMPLETE", "[Mod2 Stage 8] Stage clear uses the authored title")
	check(clear_overlay8 != null and clear_overlay8._advisory.text.contains("STAGE 9"), "[Mod2 Stage 8] Stage clear points to Stage 9")
	await _stop_match()

	print("-- 34. A fully SAFE playthrough still reaches the same major story reveal --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 7)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 8] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 8] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	check(_dialogue_contains(overlay, "So did mine"), "[Mod2 Stage 8] All-SAFE run still includes Leah's active-mentoring beat")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "Leverage against the employees"), "[Mod2 Stage 8] All-SAFE run still reaches the major story reveal")
	check(_dialogue_contains(overlay, "Not a personal one"), "[Mod2 Stage 8] All-SAFE run still reaches the recovery-request cliffhanger")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 8), "[Mod2 Stage 8] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 7)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed8: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots8: Array[int] = []
	for i in displayed8.size():
		if str((displayed8[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots8.append(i)
	check(risky_slots8.size() == 2 and risky_slots8[0] != risky_slots8[1], "[Mod2 Stage 8] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots8[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 8] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 8] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 8] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 8] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 8] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 7)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 8] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 8] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 8] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 8] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module2_stage9() -> void:
	print("== Module 2 Stage 9: Trust No Number (final story stage, with FINAL CONTAINMENT finale) ==")
	_player.reset_to_defaults()
	# Stage 10 is the shared post-assessment template (see stages.json), whose
	# req_lesson is authored as "mod_01" regardless of active module — a
	# realistic Module 2 player has already completed Module 1's lesson too,
	# so both are granted here to exercise the real mod_02:9 -> mod_02:10
	# progression unlock rather than an unrelated lesson-gate quirk.
	_player.completed_lessons.assign(["mod_01", "mod_02"])
	_router.active_module_id = "mod_02"

	print("-- 1/2/3/4/17/18. Stage 9 reuses the decision controller and the existing generic finale system --")
	var level: Node = await _start_match("mod_02", 8)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod2 Stage 9] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod2 Stage 9] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod2 Stage 9] Exactly 3 incidents load")
	check(lm._decision.has_finale, "[Mod2 Stage 9] Controller reports a finale is configured for this stage, from data only")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod2 Stage 9] Opening story shown in the reusable overlay")
	check(_dialogue_contains(overlay, "Not a personal account"), "[Mod2 Stage 9] Opening continues directly from Stage 8's recovery-request cliffhanger")
	check(_dialogue_contains(overlay, "identity recovery administrator"), "[Mod2 Stage 9] Opening identifies the privileged BlueTech identity-recovery account")
	check(_dialogue_contains(overlay, "They don't automatically own BlueTech"), "[Mod2 Stage 9] Opening explicitly denies unlimited access to every BlueTech system")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 9] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod2 Stage 9] Incident 1 displays all 4 randomized choices")

	print("-- 11/27. SAFE resolves Incident 1, applies one positive smishing BKT update, and the leverage reveal plays regardless --")
	var mastery_before_safe: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 9] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod2 Stage 9] SAFE updates BKT positively exactly once")
	check(_dialogue_contains(overlay, "Make you scared"), "[Mod2 Stage 9] Incident 2 opens with the post-incident reveal about pressuring the employees")
	check(_dialogue_contains(overlay, "rushing is what they've been trying to make us do"), "[Mod2 Stage 9] Reveal connects the pressure tactic back to the very first text")

	print("-- 12/15. One RISKY option commits once, enters normal breach TD at 1.00 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod2 Stage 9] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "BLUETECH RECOVERY APPROVAL WORKFLOW"), "[Mod2 Stage 9] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 9] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 1.00), "[Mod2 Stage 9] Active breach uses only its authored 1.00 HP multiplier")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod2 Stage 9] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("smishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_td), "[Mod2 Stage 9] Normal RISKY TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod2 Stage 9] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 9] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "Not the number"), "[Mod2 Stage 9] Incident 3 opens with the TRUST NO NUMBER dramatic beat")
	check(_dialogue_contains(overlay, "So what's left to trust"), "[Mod2 Stage 9] Dramatic beat frames the lesson as trusting the process, not any single channel")
	check(_dialogue_contains(overlay, "BlueTech Security"), "[Mod2 Stage 9] Incident 3 introduces the fake BlueTech Security caller")

	print("-- 16/17/28. All 3 incidents resolved -> FINAL CONTAINMENT prompt, not an immediate Stage Complete --")
	var mastery_before_final_pick: float = _player.get_mastery("smishing")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "DEPLOY FINAL DEFENSES", "[Mod2 Stage 9] All 3 incidents resolved shows the FINAL CONTAINMENT prompt, not FILE REPORT")
	check(lm.current_phase != lm.GamePhase.VICTORY, "[Mod2 Stage 9] Stage does not complete before the finale is played")
	check(not _player.has_cleared_stage("mod_02", 9), "[Mod2 Stage 9] Stage is not marked cleared before the finale is played")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_final_pick, true)), "[Mod2 Stage 9] Incident 3's SAFE commit applies exactly one BKT update (the finale adds none)")
	check(_dialogue_contains(overlay, "leverage") or _dialogue_contains(overlay, "Leverage"), "[Mod2 Stage 9] Ending reveals the family/personal victims were leverage against BlueTech employees")
	check(_dialogue_contains(overlay, "reset authentication factors and recovery methods"), "[Mod2 Stage 9] Ending explains the access could enable further authentication/recovery attacks")
	check(not _dialogue_contains(overlay, "access to every account"), "[Mod2 Stage 9] Ending does not claim automatic access to every BlueTech account")

	print("-- 19/20/21/22. FINAL CONTAINMENT TD LOSS -> CONTAINMENT FAILED -> RETRY replays the finale only, zero BKT change --")
	var mastery_before_finale_loss: float = _player.get_mastery("smishing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 9] DEPLOY FINAL DEFENSES starts the finale Tower Defense")
	check(lm._decision.is_finale_active(), "[Mod2 Stage 9] Controller reports the finale encounter is active")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 9] Finale TD loss is Game Over")
	var finale_defeat_card = level.get_node_or_null("BaseDefeatOverlay")
	check(finale_defeat_card != null and finale_defeat_card._title.text == "CONTAINMENT FAILED", "[Mod2 Stage 9] CONTAINMENT FAILED shown on finale TD loss")
	check(finale_defeat_card != null and finale_defeat_card._stage.text == "BLUETECH IDENTITY RECOVERY SERVICE", "[Mod2 Stage 9] Finale defeat card names the finale's affected system, from data")
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_finale_loss), "[Mod2 Stage 9] Finale TD loss applies zero BKT updates")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(lm._decision.resolved_threats == 3, "[Mod2 Stage 9] Retry after finale loss keeps all 3 incidents resolved")
	check(overlay._mode == &"story" and overlay._continue_button.text == "DEPLOY FINAL DEFENSES", "[Mod2 Stage 9] Retry after finale loss replays the finale prompt, never Incident 3")

	print("-- 23/32/33/34/39/40. FINAL CONTAINMENT TD WIN -> CASE CLOSED -> MODULE 2 STORY COMPLETE -> Stage 9 clears, unlocks Stage 10 --")
	var mastery_before_finale_win: float = _player.get_mastery("smishing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 9] Retrying DEPLOY FINAL DEFENSES restarts the finale Tower Defense")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("smishing"), mastery_before_finale_win), "[Mod2 Stage 9] Finale TD win applies zero BKT updates (no duplicate reward from the retry)")
	check(overlay._mode == &"story" and overlay._banner.text == "CONTAINMENT COMPLETE", "[Mod2 Stage 9] Finale win shows CONTAINMENT COMPLETE")
	check(lm.current_phase != lm.GamePhase.VICTORY, "[Mod2 Stage 9] Stage still not complete before the case-closed epilogue plays")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"story" and overlay._banner.text == "CASE CLOSED", "[Mod2 Stage 9] Case summary shows CASE CLOSED")
	check(_dialogue_contains(overlay, "SIGNAL LOST"), "[Mod2 Stage 9] Case summary subtitle names the SIGNAL LOST arc")
	check(_dialogue_contains(overlay, "Privileged Recovery Account Protected"), "[Mod2 Stage 9] Case summary lists the authored case-closed items")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._mode == &"story" and overlay._banner.text == "MODULE 2 STORY COMPLETE" and overlay._continue_button.text == "FILE REPORT", "[Mod2 Stage 9] Closing dialogue shows MODULE 2 STORY COMPLETE with FILE REPORT")
	check(_dialogue_contains(overlay, "Verify the process, not the story"), "[Mod2 Stage 9] Closing dialogue delivers Leah's final lesson")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 9), "[Mod2 Stage 9] Stage 9 clears only after the finale and its epilogue")
	check(not _player.has_cleared_stage("mod_01", 9), "[Mod2 Stage 9] Completion does not mark mod_01:9 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(10, "mod_02").is_empty(), "[Mod2 Stage 9] Completion unlocks mod_02:10")
	var clear_overlay9m2 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay9m2 != null and clear_overlay9m2._title.text == "STAGE 9 COMPLETE", "[Mod2 Stage 9] Stage clear card uses the authored title")
	check(clear_overlay9m2 != null and clear_overlay9m2._advisory.text.contains("STAGE 10"), "[Mod2 Stage 9] Stage clear card points to Stage 10")
	await _stop_match()

	print("-- 34. Stage 10 stays the existing post-assessment, never the decision-story live scene --")
	check(not DecisionScenarios.is_decision_stage("mod_02", 10), "[Mod2 Stage 9] Stage 10 remains a non-decision (TRACE/post-assessment) stage")

	print("-- 38. A fully SAFE playthrough still reaches the same final reveal and finale --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod2 Stage 9] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod2 Stage 9] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and overlay._continue_button.text == "DEPLOY FINAL DEFENSES", "[Mod2 Stage 9] All-SAFE run still reaches the FINAL CONTAINMENT prompt")
	check(_dialogue_contains(overlay, "leverage") or _dialogue_contains(overlay, "Leverage"), "[Mod2 Stage 9] All-SAFE run still reaches the leverage reveal")
	overlay._continue_button.pressed.emit()
	await settle()
	await _force_td_win(lm)
	check(overlay._mode == &"story" and overlay._banner.text == "CONTAINMENT COMPLETE", "[Mod2 Stage 9] All-SAFE run's finale still wins normally")
	overlay._continue_button.pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_02", 9), "[Mod2 Stage 9] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed9: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots9: Array[int] = []
	for i in displayed9.size():
		if str((displayed9[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots9.append(i)
	check(risky_slots9.size() == 2 and risky_slots9[0] != risky_slots9[1], "[Mod2 Stage 9] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("smishing")
	overlay._choice_buttons[risky_slots9[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod2 Stage 9] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod2 Stage 9] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 9] Normal RISKY TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 9] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod2 Stage 9] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_02", 8)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("smishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod2 Stage 9] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod2 Stage 9] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("smishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod2 Stage 9] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod2 Stage 9] CRITICAL retry restores the same incident")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module3_stage1() -> void:
	print("== Module 3 Stage 1: Unknown Caller (new module, vishing skill, 4 choices: 1 SAFE / 2 RISKY / 1 CRITICAL) ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	_router.active_module_id = "mod_03"

	print("-- 1/2/3/4. Stage 1 reuses the decision controller and loads only its 3 four-choice incidents --")
	var level: Node = await _start_match("mod_03", 0)
	var lm = _level_manager(level)
	check(lm._decision != null, "[Mod3 Stage 1] Uses the same decision controller, not TRACE")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH and not lm._quiz_modal.visible, "[Mod3 Stage 1] No TRACE quiz opened")
	check(lm._decision.total_threats() == 3, "[Mod3 Stage 1] Exactly 3 incidents load")
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible and overlay._mode == &"story", "[Mod3 Stage 1] Opening story shown in the reusable overlay")
	check(_no_forbidden_words(overlay), "[Mod3 Stage 1] Opening avoids quiz vocabulary")
	check(_dialogue_contains(overlay, "Fraud Prevention Department"), "[Mod3 Stage 1] Opening establishes the fake fraud-department voicemail")
	check(_dialogue_contains(overlay, "Daniel"), "[Mod3 Stage 1] Daniel is a supported, distinctly named speaker")
	await _skip_opening(overlay)
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod3 Stage 1] Incident 1 shown after opening")
	var incident1_choices: Array = lm._decision.current_threat_for_display().get("choices", [])
	check(incident1_choices.size() == 4, "[Mod3 Stage 1] Incident 1 displays all 4 randomized choices")
	check(_dialogue_contains(overlay, "we detected an attempted"), "[Mod3 Stage 1] Incident 1 uses caller-ID spoofing / fake bank impersonation")

	print("-- 11/29. SAFE resolves Incident 1, applies one positive vishing BKT update, and teaches independent callback verification --")
	var mastery_before_safe: float = _player.get_mastery("vishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and overlay._header_right.text == "INCIDENT 2 / 3", "[Mod3 Stage 1] SAFE resolves Incident 1 and advances")
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_safe, true)), "[Mod3 Stage 1] SAFE updates BKT positively exactly once")
	check(_dialogue_contains(overlay, "They knew a transaction from yesterday"), "[Mod3 Stage 1] Emotional beat plays after Incident 1")
	check(_dialogue_contains(overlay, "Stay on this call"), "[Mod3 Stage 1] Incident 2 shows the attacker telling Daniel to remain on the line")

	print("-- 12/15/30. One RISKY option commits once, enters breach TD at 0.65 HP, and TD win continues to Incident 3 --")
	var mastery_before_risky: float = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod3 Stage 1] RISKY shows SECURITY WARNING")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED" and _dialogue_contains(overlay, "DANIEL'S BANK / MOBILE DEVICE"), "[Mod3 Stage 1] Breach warning names Incident 2's affected system")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod3 Stage 1] RISKY launches the existing Tower Defense flow")
	check(is_equal_approx(lm._decision_breach_hp_scale(), 0.65), "[Mod3 Stage 1] Active breach uses only its authored 0.65 HP multiplier, a fresh Module 3 curve")
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_risky, false)), "[Mod3 Stage 1] RISKY updates BKT negatively exactly once")
	var mastery_before_td: float = _player.get_mastery("vishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("vishing"), mastery_before_td), "[Mod3 Stage 1] TD win does not update BKT")
	check(lm._decision.resolved_threats == 2 and overlay._banner.text == "BREACH CONTAINED", "[Mod3 Stage 1] TD win resolves Incident 2 and shows BREACH CONTAINED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod3 Stage 1] TD win continues to Incident 3")
	check(_dialogue_contains(overlay, "Someone knows my bank account"), "[Mod3 Stage 1] Incident 3 opens with the DRAMA beat's angry outburst")
	check(_dialogue_contains(overlay, "senior fraud investigator"), "[Mod3 Stage 1] Incident 3 introduces the fake senior-investigator callback")

	print("-- 17/18/22/31/32. Completion marks mod_03:1 only, unlocks mod_03:2, and sets up the BlueTech-clue cliffhanger --")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "isn't a random robocall"), "[Mod3 Stage 1] Ending confirms this is a coordinated caller, not a random scam")
	check(_dialogue_contains(overlay, "BlueTech"), "[Mod3 Stage 1] Ending includes the BlueTech transaction clue")
	check(_dialogue_contains(overlay, "Probably nothing"), "[Mod3 Stage 1] The BlueTech clue stays small and unconfirmed, not a full campaign reveal")
	check(_dialogue_contains(overlay, "PRIVATE NUMBER"), "[Mod3 Stage 1] Ending reaches the Stage 2 cliffhanger call")
	check(not _dialogue_contains(overlay, "same campaign that hit BlueTech"), "[Mod3 Stage 1] Ending does not reveal the larger Module 1/2 campaign")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase != lm.GamePhase.VICTORY and not _player.has_cleared_stage("mod_03", 1), "[Reconstruction] Ending does not award stage completion before reconstruction")
	var reconstruction_m3: Control = level.get_node_or_null("GameplayCanvas/DecisionReconstruction")
	check(reconstruction_m3 != null and reconstruction_m3.visible, "[Reconstruction] Module 3 Stage 1 shows reconstruction after ending")
	var reconstruction_credits: int = _player.credits
	var reconstruction_mastery: float = _player.get_mastery("vishing")
	var reconstruction_memory: Dictionary = _player.get_story_memory_snapshot()
	await _stop_match()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(lm._decision.resolved_threats == 3 and overlay._mode == &"story", "[Reconstruction] Legacy reload retains resolved incidents and replays ending")
	overlay._continue_button.pressed.emit()
	await settle()
	reconstruction_m3 = level.get_node_or_null("GameplayCanvas/DecisionReconstruction")
	check(reconstruction_m3 != null and reconstruction_m3.visible, "[Reconstruction] Legacy reload returns to reconstruction")
	check(_player.credits == reconstruction_credits and is_equal_approx(_player.get_mastery("vishing"), reconstruction_mastery) and _player.get_story_memory_snapshot() == reconstruction_memory and not _player.has_cleared_stage("mod_03", 1), "[Reconstruction] Legacy reload adds no rewards, BKT, memory, or clear")
	if reconstruction_m3 != null:
		reconstruction_m3._continue.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 1), "[Mod3 Stage 1] Completion marks mod_03:1")
	check(not _player.has_cleared_stage("mod_01", 1) and not _player.has_cleared_stage("mod_02", 1), "[Mod3 Stage 1] Completion does not mark mod_01:1 or mod_02:1 (no checkpoint collision)")
	check(root.get_node("StageManager").access_reason(2, "mod_03").is_empty(), "[Mod3 Stage 1] Completion unlocks mod_03:2")
	var clear_overlay_m3 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay_m3 != null and clear_overlay_m3._title.text == "STAGE 1 COMPLETE", "[Mod3 Stage 1] Stage clear uses the authored title")
	check(clear_overlay_m3 != null and clear_overlay_m3._advisory.text.contains("STAGE 2"), "[Mod3 Stage 1] Stage clear points to Stage 2")
	await _stop_match()

	print("-- 35. A fully SAFE playthrough still reaches the same emotional/story beats --")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[Mod3 Stage 1] All-SAFE run: Incident 1 resolved via SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod3 Stage 1] All-SAFE run: Incident 2 resolved via SAFE with no breach")
	check(_dialogue_contains(overlay, "Someone knows my bank account"), "[Mod3 Stage 1] All-SAFE run still includes the angry DRAMA beat")
	await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "BlueTech"), "[Mod3 Stage 1] All-SAFE run still reaches the BlueTech clue")
	check(_dialogue_contains(overlay, "PRIVATE NUMBER"), "[Mod3 Stage 1] All-SAFE run still reaches the Stage 2 cliffhanger")
	overlay._continue_button.pressed.emit()
	await settle()
	var safe_reconstruction_m3: Control = level.get_node_or_null("GameplayCanvas/DecisionReconstruction")
	if safe_reconstruction_m3 != null:
		safe_reconstruction_m3._continue.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 1), "[Mod3 Stage 1] All-SAFE run still clears the stage normally")
	await _stop_match()

	print("-- 6/10/12/14. The second RISKY button is independently selectable; TD loss retries Incident 1 --")
	_player.reset_to_defaults()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var displayed_m3: Array = lm._decision.current_threat_for_display().get("choices", [])
	var risky_slots_m3: Array[int] = []
	for i in displayed_m3.size():
		if str((displayed_m3[i] as Dictionary).get("outcome", "")) == "RISKY":
			risky_slots_m3.append(i)
	check(risky_slots_m3.size() == 2 and risky_slots_m3[0] != risky_slots_m3[1], "[Mod3 Stage 1] Both distinct RISKY buttons are independently addressable")
	var mastery_before_second_risky: float = _player.get_mastery("vishing")
	overlay._choice_buttons[risky_slots_m3[1]].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		overlay._continue_button.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Mod3 Stage 1] The second RISKY button also enters breach TD")
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_second_risky, false)), "[Mod3 Stage 1] The second RISKY button updates BKT exactly once")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod3 Stage 1] TD loss reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod3 Stage 1] TD-loss retry restores the same incident")
	check(lm._decision.resolved_threats == 0, "[Mod3 Stage 1] TD-loss retry preserves the clean pre-decision checkpoint")
	await _stop_match()

	print("-- 13. CRITICAL updates BKT once, reaches Game Over, and retries the same incident --")
	_player.reset_to_defaults()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_critical: float = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SYSTEM COMPROMISED", "[Mod3 Stage 1] CRITICAL shows SYSTEM COMPROMISED")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod3 Stage 1] CRITICAL reaches Game Over")
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_critical, false)), "[Mod3 Stage 1] CRITICAL updates BKT negatively exactly once")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 1 / 3", "[Mod3 Stage 1] CRITICAL retry restores the same incident")
	await _stop_match()

	print("-- 34. No cross-module checkpoint collision: mod_01:1 / mod_02:1 progress never leaks into mod_03:1 --")
	_player.reset_to_defaults()
	_router.active_module_id = "mod_01"
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1, "[Cross-module] Module 1 Stage 1 advances to its own Incident 2")
	await _stop_match()
	_router.active_module_id = "mod_03"
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	check(lm._decision.resolved_threats == 0 and lm._decision.total_threats() == 3, "[Cross-module] Module 3 Stage 1 starts completely fresh despite Module 1 Stage 1 progress")
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	check(overlay._header_right.text == "INCIDENT 1 / 3", "[Cross-module] Module 3 Stage 1 shows its own Incident 1, not Module 1's Incident 2")
	await _stop_match()
	check(_player.decision_stage_state.get("mod_01:1", {}) != _player.decision_stage_state.get("mod_03:1", {}), "[Cross-module] mod_01:1 and mod_03:1 are distinct checkpoint entries")
	check(_player.decision_stage_state.get("mod_02:1", {}) != _player.decision_stage_state.get("mod_03:1", {}), "[Cross-module] mod_02:1 and mod_03:1 are distinct checkpoint entries")
	_router.active_module_id = "mod_01"


## Milestone: visible decision consequences (DecisionScenarios.story_event_lines).
## Exercises the 3 demo consequences authored on Module 3 Stage 1's choices
## end-to-end through the real flow: commit -> BKT once -> authored
## consequence -> existing SAFE/RISKY/CRITICAL continuation, unchanged.
func _test_module3_stage1_story_consequences() -> void:
	print("== Milestone: visible decision consequences (Module 3 Stage 1 demo) ==")
	_router.active_module_id = "mod_03"

	print("-- RISKY demo (Incident 1): consequence gates BKT/TD, then TD win continues; retry re-triggers it --")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	var level: Node = await _start_match("mod_03", 0)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	await _skip_opening(overlay)
	var mastery_before_risky_demo: float = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "Keep the caller on the line")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SECURITY WARNING", "[StoryEvent] Choosing the demo RISKY choice shows its own consequence screen first")
	check(_dialogue_contains(overlay, "SECURITY ACTIVITY"), "[StoryEvent] The authored notification beat is visible on the same screen")
	check(_dialogue_contains(overlay, "They're doing something while I'm talking to them"), "[StoryEvent] The authored dialogue reaction is visible on the same screen")
	check(is_equal_approx(_player.get_mastery("vishing"), mastery_before_risky_demo), "[StoryEvent] BKT has not committed yet while the consequence is still showing")
	check(lm.current_phase == lm.GamePhase.PRE_MATCH, "[StoryEvent] Tower Defense has not started while the consequence is still showing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._banner.text == "BREACH DETECTED", "[StoryEvent] Continuing past the consequence proceeds to the existing breach transition, unchanged")
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_risky_demo, false)), "[StoryEvent] BKT updates exactly once, at the same point as before this milestone")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[StoryEvent] DEPLOY DEFENSES still starts Tower Defense normally")
	var mastery_before_td_demo: float = _player.get_mastery("vishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("vishing"), mastery_before_td_demo), "[StoryEvent] TD win still applies no additional BKT update")
	check(overlay._mode == &"story" and overlay._banner.text == "BREACH CONTAINED", "[StoryEvent] TD win still continues the existing story flow")
	await _stop_match()

	print("-- Retry after a TD loss does not replay the consequence; a fresh commit on the SAME choice triggers it again --")
	_player.reset_to_defaults()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_label(lm, "Keep the caller on the line")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[StoryEvent] Demo choice reaches Tower Defense as usual")
	await _force_td_loss(lm)
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat", "[StoryEvent] Retry after TD loss returns to the incident choices, not a replayed consequence screen")
	check(not _dialogue_contains(overlay, "SECURITY ACTIVITY"), "[StoryEvent] The already-consumed consequence is not replayed on retry")
	var mastery_before_retry_commit: float = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "Keep the caller on the line")].pressed.emit()
	await settle()
	check(_dialogue_contains(overlay, "SECURITY ACTIVITY") and _dialogue_contains(overlay, "They're doing something while I'm talking to them"),
		"[StoryEvent] A fresh commit of the same choice on the new attempt triggers its consequence again normally")
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_retry_commit, false)), "[StoryEvent] The retried commit still grades BKT exactly once, not duplicated by the replayed consequence")
	await _stop_match()

	print("-- CRITICAL demo (Incident 2): consequence gates Game Over --")
	_player.reset_to_defaults()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 2 / 3", "[StoryEvent] Incident 1 resolved via SAFE to reach Incident 2")
	var mastery_before_critical_demo: float = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "Stay on the call because the caller's warning")].pressed.emit()
	await settle()
	check(overlay._mode == &"consequence" and overlay._banner.text == "SYSTEM COMPROMISED", "[StoryEvent] Choosing the demo CRITICAL choice shows its own consequence screen first")
	check(_dialogue_contains(overlay, "CALL STATUS") and _dialogue_contains(overlay, "08:14"), "[StoryEvent] The authored status beat is visible on the same screen")
	check(_dialogue_contains(overlay, "ACCOUNT SECURITY REQUEST"), "[StoryEvent] The authored notification beat is visible on the same screen")
	check(is_equal_approx(_player.get_mastery("vishing"), mastery_before_critical_demo), "[StoryEvent] BKT has not committed yet while the consequence is still showing")
	check(lm.current_phase != lm.GamePhase.GAME_OVER, "[StoryEvent] Game Over has not fired while the consequence is still showing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[StoryEvent] Continuing past the consequence still reaches the existing CRITICAL Game Over")
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_critical_demo, false)), "[StoryEvent] BKT updates exactly once for the CRITICAL commit")
	await _stop_match()

	print("-- SAFE demo (Incident 3): consequence still continues the existing story/ending, progression unaffected --")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[StoryEvent] Incidents 1-2 resolved via SAFE to reach Incident 3")
	var mastery_before_safe_demo: float = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "End the incoming call and reconnect")].pressed.emit()
	await settle()
	check(_dialogue_contains(overlay, "FRAUD CASE") and _dialogue_contains(overlay, "could not be verified"), "[StoryEvent] The authored status beat is visible on the SAFE consequence screen")
	check(is_equal_approx(_player.get_mastery("vishing"), mastery_before_safe_demo), "[StoryEvent] BKT has not committed yet while the consequence is still showing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, mastery_before_safe_demo, true)), "[StoryEvent] SAFE still updates BKT positively exactly once")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "isn't a random robocall"), "[StoryEvent] SAFE still continues into Stage 1's unchanged ending, not a new/different beat")
	overlay._continue_button.pressed.emit()
	await settle()
	var story_reconstruction_m3: Control = level.get_node_or_null("GameplayCanvas/DecisionReconstruction")
	if story_reconstruction_m3 != null:
		story_reconstruction_m3._continue.pressed.emit()
		await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 1), "[StoryEvent] Stage 1 still completes and clears normally with story-event choices in play")
	await _stop_match()
	_router.active_module_id = "mod_01"


## Legacy-engine parity for the "Character Memory / Reactive Dialogue"
## milestone (see stage_one_live.gd's _commit_decision()/_wave_cleared() and
## DecisionStageController.pending_breach_memory) — one shared
## implementation, exercised here through level_manager.gd/decision_overlay.gd
## instead of the live scene. Reuses Module 3 Stage 1 Incident 1's own
## authored "memory" (mod03_s1_bank_verification), the same content the live
## engine's own tests already use.
func _test_legacy_story_memory_parity() -> void:
	print("== Legacy engine (level_manager.gd/decision_overlay.gd): story-memory parity with stage_one_live.gd ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	_router.active_module_id = "mod_03"

	print("-- SAFE commits its authored memory exactly once, immediately --")
	var level: Node = await _start_match("mod_03", 0)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	check(_player.get_story_memory("mod03_s1_bank_verification") == "independent", "[Legacy Memory] SAFE's own canonical resolution point commits its memory exactly once")
	await _stop_match()

	print("-- RISKY memory stays pending through the breach; TD victory is its canonical resolution point --")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_label(lm, "identify additional recent transactions")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(_player.get_story_memory("mod03_s1_bank_verification") == null, "[Legacy Memory] Committing RISKY enters the breach but writes nothing yet")
	check(lm._decision.pending_breach_memory.get("mod03_s1_bank_verification") == "caller_knowledge", "[Legacy Memory] The choice's own memory is held pending, keyed exactly as authored")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Legacy Memory] Still reaches Tower Defense through the unchanged breach flow")
	await _force_td_win(lm)
	check(_player.get_story_memory("mod03_s1_bank_verification") == "caller_knowledge", "[Legacy Memory] TD victory — the incident's canonical resolution — commits the pending RISKY memory exactly once")
	check(lm._decision.pending_breach_memory.is_empty(), "[Legacy Memory] Pending memory is cleared once committed, so it can never be committed twice")
	await _stop_match()

	print("-- RISKY TD loss discards the pending memory; retry commits a DIFFERENT final memory --")
	_player.reset_to_defaults()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_label(lm, "identify additional recent transactions")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Legacy Memory] TD loss reaches Game Over")
	check(_player.get_story_memory("mod03_s1_bank_verification") == null, "[Legacy Memory] TD loss commits nothing — the abandoned RISKY attempt is never remembered")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(lm._decision.pending_breach_memory.is_empty(), "[Legacy Memory] Retry starts with no leftover pending memory")
	await _pick(lm, overlay, "SAFE")
	check(_player.get_story_memory("mod03_s1_bank_verification") == "independent", "[Legacy Memory] The retried attempt's own SAFE choice commits its OWN memory — the earlier abandoned RISKY attempt's memory is nowhere in the log")
	await _stop_match()

	print("-- CRITICAL never persists memory — Game Over rewinds the incident entirely --")
	_player.reset_to_defaults()
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Legacy Memory] CRITICAL still reaches Game Over through the unchanged flow")
	check(_player.get_story_memory("mod03_s1_bank_verification") == null, "[Legacy Memory] CRITICAL commits no memory at all — an unresolved incident is never remembered")
	await _stop_match()

	print("-- Reactive 'when' dialogue reaches the legacy overlay too, through the same condition_met() evaluator --")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "SAFE")
	await _pick(lm, overlay, "SAFE")
	check(overlay._header_right.text == "INCIDENT 3 / 3", "sanity: an all-SAFE run reaches Incident 3 exactly as it always has")
	await _pick(lm, overlay, "SAFE")
	check(_dialogue_contains(overlay, "Calling the bank myself was the only thing that actually answered anything."),
		"[Legacy Memory] The reactive Daniel ending line reaches the legacy overlay via decision_overlay.gd's show_story(), using the same story-memory system as the live scene")
	check(not _dialogue_contains(overlay, "I kept asking them to prove themselves with information they already had."), "[Legacy Memory] A non-matching variant's line does not appear")
	check(_dialogue_contains(overlay, "BlueTech"), "[Legacy Memory] Convergence: the unchanged ending content still appears")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module3_stage2() -> void:
	print("== Module 3 Stage 2: Stay on the Line ==")
	var stage: Dictionary = DecisionScenarios.get_stage("mod_03", 2)
	var threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_03", 2)
	check(str(stage.get("title", "")) == "Stay on the Line" and is_equal_approx(float(stage.get("breach_hp_multiplier", 0.0)), 0.70), "[Mod3 Stage 2] Authored title and 0.70 breach HP")
	check(threats.size() == 3 and DecisionScenarios.is_decision_stage("mod_03", 3), "[Mod3 Stage 2] Three incidents; Stage 3 now follows as decision story")
	check(not stage.has("reconstruction"), "[Mod3 Stage 2] No reconstruction is authored")
	for i in threats.size():
		var threat: Dictionary = threats[i]
		var choices: Array = threat.get("choices", []) as Array
		var counts: Dictionary = {"SAFE": 0, "RISKY": 0, "CRITICAL": 0}
		for choice in choices:
			var label: String = str((choice as Dictionary).get("label", "")).to_lower()
			var outcome: String = str((choice as Dictionary).get("outcome", ""))
			counts[outcome] = int(counts.get(outcome, 0)) + 1
			check(not label.contains("give password") and not label.contains("ignore everything") and not label.contains("trust blindly"), "[Mod3 Stage 2] Incident %d has no trivial choice wording" % (i + 1))
		check(str(threat.get("module_id", "")) == "mod_03" and int(threat.get("stage", -1)) == 2 and choices.size() == 4 and counts == {"SAFE": 1, "RISKY": 2, "CRITICAL": 1}, "[Mod3 Stage 2] Incident %d has four correctly scoped outcomes" % (i + 1))
	check(bool((threats[1].get("timer", {}) as Dictionary).get("enabled", false)) and str((threats[1].get("timer", {}) as Dictionary).get("timeout_outcome", "")) == "RISKY", "[Mod3 Stage 2] Two Calls has a deterministic RISKY timer")
	check(bool((threats[2].get("investigation", {}) as Dictionary).get("enabled", false)), "[Mod3 Stage 2] Genuine prompt requires investigation")
	for memory_value in ["independent", "caller_knowledge", "inside_call"]:
		var filtered: Array[Dictionary] = DecisionScenarios.dialogue_lines(stage, "opening", {"mod03_s1_bank_verification": memory_value})
		var variant_count: int = 0
		for line in filtered:
			if str((line as Dictionary).get("text", "")).contains("Calling the bank myself") or str((line as Dictionary).get("text", "")).contains("I wasted too much") or str((line as Dictionary).get("text", "")).contains("I was checking the real app"):
				variant_count += 1
		check(variant_count == 1, "[Mod3 Stage 2] Stage 1 memory %s selects exactly one reactive opening line" % memory_value)
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	_router.active_module_id = "mod_03"
	var level: Node = await _start_match("mod_03", 1)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	check(lm._decision != null and lm._decision.total_threats() == 3 and overlay._mode == &"story", "[Mod3 Stage 2] Reusable controller opens the story")
	await _skip_opening(overlay)
	check(lm._decision.current_threat_for_display().get("choices", []).size() == 4, "[Mod3 Stage 2] Four randomized choices are displayed")
	var before: float = _player.get_mastery("vishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, true)), "[Mod3 Stage 2] SAFE resolves Incident 1 with one BKT step")
	before = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "Put the first caller on hold")].pressed.emit()
	await settle()
	check(overlay._banner.text == "SECURITY WARNING", "[Mod3 Stage 2] RISKY consequence appears")
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, false)), "[Mod3 Stage 2] RISKY updates BKT once")
	check(overlay._banner.text == "BREACH DETECTED", "[Mod3 Stage 2] RISKY displays breach transition")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and is_equal_approx(lm._decision_breach_hp_scale(), 0.70), "[Mod3 Stage 2] RISKY deploys existing TD with 0.70 HP")
	var td_mastery: float = _player.get_mastery("vishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("vishing"), td_mastery) and lm._decision.resolved_threats == 2, "[Mod3 Stage 2] TD win resolves Incident 2 without BKT")
	check(_player.get_story_memory("mod03_s2_channel_response") == "cross_validated", "[Mod3 Stage 2] Canonical response memory commits after breach win")
	overlay._continue_button.pressed.emit()
	await settle()
	check(overlay._header_right.text == "INCIDENT 3 / 3", "[Mod3 Stage 2] TD returns to Incident 3")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER and _player.get_story_memory("mod03_s2_channel_response") == null, "[Mod3 Stage 2] TD loss does not commit incident memory")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._header_right.text == "INCIDENT 1 / 3", "[Mod3 Stage 2] TD loss retries the same incident")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	before = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, false)), "[Mod3 Stage 2] CRITICAL updates BKT once")
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod3 Stage 2] CRITICAL reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	check(lm._decision.threat_index == 0, "[Mod3 Stage 2] CRITICAL retries Incident 1")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 1)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	for incident in 3:
		await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "ANA SANTOS") and _dialogue_contains(overlay, "Kuya?"), "[Mod3 Stage 2] Ana cliffhanger appears after three resolved incidents")
	check(not _player.has_cleared_stage("mod_03", 2), "[Mod3 Stage 2] Stage does not clear before the ending")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 2), "[Mod3 Stage 2] Ending completes mod_03:2")
	check(root.get_node("StageManager").access_reason(3, "mod_03").is_empty(), "[Mod3 Stage 2] Completion unlocks Stage 3")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module3_stage3() -> void:
	print("== Module 3 Stage 3: A Familiar Voice ==")
	var stage: Dictionary = DecisionScenarios.get_stage("mod_03", 3)
	var threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_03", 3)
	check(str(stage.get("title", "")) == "A Familiar Voice" and is_equal_approx(float(stage.get("breach_hp_multiplier", 0.0)), 0.75), "[Mod3 Stage 3] Title and 0.75 breach HP authored")
	check(threats.size() == 3 and DecisionScenarios.is_decision_stage("mod_03", 4), "[Mod3 Stage 3] Three incidents; Stage 4 follows as decision story")
	check(not stage.has("reconstruction") and not stage.has("finale"), "[Mod3 Stage 3] No reconstruction or finale")
	for i in threats.size():
		var threat: Dictionary = threats[i]
		var choices: Array = threat.get("choices", []) as Array
		var counts: Dictionary = {"SAFE": 0, "RISKY": 0, "CRITICAL": 0}
		for choice in choices:
			var outcome: String = str((choice as Dictionary).get("outcome", ""))
			counts[outcome] = int(counts.get(outcome, 0)) + 1
		check(int(threat.get("stage", -1)) == 3 and str(threat.get("module_id", "")) == "mod_03" and choices.size() == 4 and counts == {"SAFE": 1, "RISKY": 2, "CRITICAL": 1}, "[Mod3 Stage 3] Incident %d has four scoped choices and 1S/2R/1C" % (i + 1))
		check(not threat.has("investigation"), "[Mod3 Stage 3] Incident %d has no investigation" % (i + 1))
	var timer: Dictionary = threats[2].get("timer", {}) as Dictionary
	check(bool(timer.get("enabled", false)) and int(timer.get("seconds", 0)) == 15 and str(timer.get("timeout_outcome", "")) == "RISKY", "[Mod3 Stage 3] Incident 3 has a 15-second deterministic RISKY timeout")
	for memory_value in ["independent_channel", "stayed_connected", "cross_validated"]:
		var lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(stage, "opening", {"mod03_s2_channel_response": memory_value})
		var variants: int = 0
		for line in lines:
			var line_text: String = str(line.get("text", ""))
			if line_text.contains("Last time I stopped") or line_text.contains("I already know what happens") or line_text.contains("I compared two callers"):
				variants += 1
		check(variants == 1, "[Mod3 Stage 3] Stage 2 memory %s selects exactly one opening response" % memory_value)
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	_router.active_module_id = "mod_03"
	var level: Node = await _start_match("mod_03", 2)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	check(lm._decision != null and lm._decision.total_threats() == 3 and overlay._mode == &"story", "[Mod3 Stage 3] Generic decision engine loads familiar-voice opening")
	await _skip_opening(overlay)
	check(lm._decision.current_threat_for_display().get("choices", []).size() == 4, "[Mod3 Stage 3] Four shuffled choices display")
	var before: float = _player.get_mastery("vishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, true)), "[Mod3 Stage 3] SAFE resolves Incident 1 with one BKT step")
	check(_dialogue_contains(overlay, "I'm fine") and _dialogue_contains(overlay, "Then whose voice"), "[Mod3 Stage 3] Real Ana independently denies the suspicious call")
	before = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "Compare the new voice message")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, false)) and overlay._banner.text == "BREACH DETECTED", "[Mod3 Stage 3] RISKY commits once and enters breach warning")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and is_equal_approx(lm._decision_breach_hp_scale(), 0.75), "[Mod3 Stage 3] Existing TD uses 0.75 breach HP")
	await _force_td_win(lm)
	check(lm._decision.resolved_threats == 2 and _player.get_story_memory("mod03_s3_voice_response") == "voice_comparison", "[Mod3 Stage 3] TD win resolves Incident 2 and commits canonical memory")
	overlay._continue_button.pressed.emit()
	await settle()
	check(_dialogue_contains(overlay, "PAYROLL AUTHORIZATION REQUIRED"), "[Mod3 Stage 3] Genuine payroll alert reaches Incident 3")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER and _player.get_story_memory("mod03_s3_voice_response") == null, "[Mod3 Stage 3] CRITICAL Game Over writes no canonical memory")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	check(lm._decision.threat_index == 0, "[Mod3 Stage 3] CRITICAL retries same incident")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 2)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	for i in 3:
		await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "BlueTech jobs") and _dialogue_contains(overlay, "BLUETECH SECURITY"), "[Mod3 Stage 3] Ending keeps small BlueTech clue and Stage 4 cliffhanger")
	check(not _player.has_cleared_stage("mod_03", 3), "[Mod3 Stage 3] No completion before ending")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 3), "[Mod3 Stage 3] Ending completes mod_03:3")
	check(root.get_node("StageManager").access_reason(4, "mod_03").is_empty(), "[Mod3 Stage 3] Completion unlocks Stage 4")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module3_stage4() -> void:
	print("== Module 3 Stage 4: Don't Hang Up ==")
	var stage: Dictionary = DecisionScenarios.get_stage("mod_03", 4)
	var threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_03", 4)
	check(str(stage.get("title", "")) == "Don't Hang Up" and is_equal_approx(float(stage.get("breach_hp_multiplier", 0.0)), 0.80), "[Mod3 Stage 4] Title and 0.80 HP authored")
	check(threats.size() == 3 and DecisionScenarios.is_decision_stage("mod_03", 5), "[Mod3 Stage 4] Three incidents; Stage 5 now follows as decision story")
	check(not stage.has("reconstruction") and not stage.has("finale"), "[Mod3 Stage 4] No reconstruction or finale")
	for i in threats.size():
		var threat: Dictionary = threats[i]
		var choices: Array = threat.get("choices", []) as Array
		var counts: Dictionary = {"SAFE": 0, "RISKY": 0, "CRITICAL": 0}
		for choice in choices:
			var outcome: String = str((choice as Dictionary).get("outcome", ""))
			counts[outcome] = int(counts.get(outcome, 0)) + 1
		check(int(threat.get("stage", -1)) == 4 and str(threat.get("module_id", "")) == "mod_03" and choices.size() == 4 and counts == {"SAFE": 1, "RISKY": 2, "CRITICAL": 1}, "[Mod3 Stage 4] Incident %d is scoped and has 1S/2R/1C" % (i + 1))
	check(bool((threats[0].get("call", {}) as Dictionary).get("allow_end_call", false)), "[Mod3 Stage 4] Incident 1 supports presentation-only END CALL")
	var investigation: Dictionary = threats[1].get("investigation", {}) as Dictionary
	check(bool(investigation.get("enabled", false)) and (investigation.get("items", []) as Array).size() == 4, "[Mod3 Stage 4] Incident 2 has four investigation items")
	var timer: Dictionary = threats[2].get("timer", {}) as Dictionary
	check(bool(timer.get("enabled", false)) and int(timer.get("seconds", 0)) == 15 and str(timer.get("timeout_outcome", "")) == "RISKY", "[Mod3 Stage 4] Incident 3 has deterministic RISKY timeout")
	for memory_value in ["independent_verification", "voice_comparison", "knowledge_challenge"]:
		var lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(stage, "opening", {"mod03_s3_voice_response": memory_value})
		var variants: int = 0
		for line in lines:
			var line_text: String = str(line.get("text", ""))
			if line_text.contains("familiar doesn't mean") or line_text.contains("compared the voice") or line_text.contains("answers they shouldn't"):
				variants += 1
		check(variants == 1, "[Mod3 Stage 4] Stage 3 memory %s selects one reactive line" % memory_value)
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	_router.active_module_id = "mod_03"
	var level: Node = await _start_match("mod_03", 3)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	check(lm._decision != null and lm._decision.total_threats() == 3 and overlay._mode == &"story", "[Mod3 Stage 4] Existing decision engine opens the stage")
	await _skip_opening(overlay)
	check(lm._decision.current_threat_for_display().get("choices", []).size() == 4, "[Mod3 Stage 4] Four randomized choices shown")
	var before: float = _player.get_mastery("vishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, true)), "[Mod3 Stage 4] SAFE resolves Incident 1 with one BKT step")
	before = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_label(lm, "Keep the caller connected while Mia")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, false)) and overlay._banner.text == "BREACH DETECTED", "[Mod3 Stage 4] RISKY updates BKT once and reaches breach warning")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and is_equal_approx(lm._decision_breach_hp_scale(), 0.80), "[Mod3 Stage 4] Existing TD uses 0.80 HP scale")
	var td_mastery: float = _player.get_mastery("vishing")
	await _force_td_win(lm)
	check(is_equal_approx(_player.get_mastery("vishing"), td_mastery) and _player.get_story_memory("mod03_s4_isolation_response") == "delegated_response", "[Mod3 Stage 4] TD win adds no BKT and commits canonical memory")
	overlay._continue_button.pressed.emit()
	await settle()
	check(_dialogue_contains(overlay, "someone claiming to be Daniel"), "[Mod3 Stage 4] Incident 3 exposes business impersonation")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	await _pick(lm, overlay, "RISKY")
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER and _player.get_story_memory("mod03_s4_isolation_response") == null, "[Mod3 Stage 4] TD loss does not commit unresolved memory")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	check(lm._decision.threat_index == 0, "[Mod3 Stage 4] TD loss retries same incident")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.GAME_OVER and _player.get_story_memory("mod03_s4_isolation_response") == null, "[Mod3 Stage 4] CRITICAL Game Over commits no memory")
	await _stop_match()
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 3)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	for i in 3:
		await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "before we started warning everyone") and _dialogue_contains(overlay, "They said they were you"), "[Mod3 Stage 4] All-SAFE ending reveals the pre-existing payment and impersonation")
	check(_dialogue_contains(overlay, "And they used my voice on someone else"), "[Mod3 Stage 4] Stage 5 cliffhanger is present")
	check(not _player.has_cleared_stage("mod_03", 4), "[Mod3 Stage 4] Stage does not clear before ending")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 4), "[Mod3 Stage 4] Ending completes mod_03:4")
	check(root.get_node("StageManager").access_reason(5, "mod_03").is_empty(), "[Mod3 Stage 4] Completion unlocks Stage 5")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_module3_stage5() -> void:
	print("== Module 3 Stage 5: Too Late ==")
	var stage: Dictionary = DecisionScenarios.get_stage("mod_03", 5)
	var threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_03", 5)
	check(str(stage.get("title", "")) == "Too Late" and is_equal_approx(float(stage.get("breach_hp_multiplier", 0.0)), 0.85), "[Mod3 Stage 5] Title and 0.85 breach HP authored")
	check(threats.size() == 3, "[Mod3 Stage 5] Three incidents")
	check(not stage.has("reconstruction") and not stage.has("finale"), "[Mod3 Stage 5] No reconstruction or finale")
	for i in threats.size():
		var threat: Dictionary = threats[i]
		check(not threat.has("investigation"), "[Mod3 Stage 5] Incident %d has no investigation (this milestone explicitly avoids it)" % (i + 1))
		var choices: Array = threat.get("choices", []) as Array
		var counts: Dictionary = {"SAFE": 0, "RISKY": 0, "CRITICAL": 0}
		for choice in choices:
			var outcome: String = str((choice as Dictionary).get("outcome", ""))
			counts[outcome] = int(counts.get(outcome, 0)) + 1
			if outcome == "CRITICAL":
				check(not (choice as Dictionary).has("memory"), "[Mod3 Stage 5] Incident %d's CRITICAL choice authors no memory" % (i + 1))
		check(int(threat.get("stage", -1)) == 5 and str(threat.get("module_id", "")) == "mod_03" and choices.size() == 4 and counts == {"SAFE": 1, "RISKY": 2, "CRITICAL": 1}, "[Mod3 Stage 5] Incident %d has four scoped choices and 1S/2R/1C" % (i + 1))
	# The payment predates Stage 5 and is canonical from Stage 4's own ending
	# (₱18,600) — Stage 5 must never introduce a different figure.
	var incident1_text: String = JSON.stringify(threats[0])
	check(incident1_text.contains("18,600") and not incident1_text.contains("84,750"), "[Mod3 Stage 5] The payment amount matches Stage 4's own canonical figure, never a new number")
	var timer: Dictionary = threats[2].get("timer", {}) as Dictionary
	check(bool(timer.get("enabled", false)) and int(timer.get("seconds", 0)) == 15 and str(timer.get("timeout_outcome", "")) == "RISKY", "[Mod3 Stage 5] Incident 3 has a 15-second deterministic RISKY timeout")
	var memory_values: Dictionary = {}
	for choice in (threats[0].get("choices", []) as Array):
		var mem: Dictionary = (choice as Dictionary).get("memory", {}) as Dictionary
		if mem.has("mod03_s5_recovery_response"):
			memory_values[str(mem["mod03_s5_recovery_response"])] = true
	check(memory_values.size() == 3 and memory_values.has("verified_recovery") and memory_values.has("case_crosscheck") and memory_values.has("caller_explanation"),
		"[Mod3 Stage 5] Incident 1 authors exactly the three canonical recovery-response memory values")
	var stage_text_lower: String = JSON.stringify(stage).to_lower()
	for word in ["foolish", "stupid", "careless", "idiot"]:
		check(not stage_text_lower.contains(word), "[Mod3 Stage 5] Liza is never described as %s — she is competent, not foolish" % word)
	var ending_text: String = JSON.stringify(stage.get("ending", []))
	check(ending_text.contains("Maybe") and not ending_text.to_lower().contains("full refund") and not ending_text.to_lower().contains("fully refunded"),
		"[Mod3 Stage 5] Recovery outcome stays realistic and uncertain, never an instant full refund")
	check(ending_text.contains("CYBERCRIME INVESTIGATION UNIT") and ending_text.contains("Investigator Reyes"), "[Mod3 Stage 5] Ending sets up the Cybercrime Investigation Unit cliffhanger")
	check(str(stage.get("next_stage_title", "")) == "Stage 6 — The Officer", "[Mod3 Stage 5] Points to Stage 6 — The Officer")

	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	_router.active_module_id = "mod_03"
	var level: Node = await _start_match("mod_03", 4)
	var lm = _level_manager(level)
	var overlay = lm._decision_overlay
	check(lm._decision != null and lm._decision.total_threats() == 3 and overlay._mode == &"story", "[Mod3 Stage 5] Generic decision engine opens Too Late")
	# The legacy overlay shows a story block's lines all at once (see
	# decision_overlay.gd's _fill_dialogue()) — check the opening's own
	# content before _skip_opening() dismisses it for Incident 1.
	# The opening speaks the canonical amount naturally ("Eighteen thousand...
	# Six hundred.") rather than as a numeral — the numeral itself is
	# authored on Incident 1's own situation text (checked separately above).
	check(_dialogue_contains(overlay, "Eighteen thousand") and _dialogue_contains(overlay, "Liza"), "[Mod3 Stage 5] Opening confirms the canonical payment and introduces Liza")
	await _skip_opening(overlay)
	check(lm._decision.current_threat_for_display().get("choices", []).size() == 4, "[Mod3 Stage 5] Four randomized choices display")
	var before: float = _player.get_mastery("vishing")
	await _pick(lm, overlay, "SAFE")
	check(lm._decision.resolved_threats == 1 and is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, true)), "[Mod3 Stage 5] SAFE resolves Incident 1 with one BKT step")
	check(_player.get_story_memory("mod03_s5_recovery_response") == "verified_recovery", "[Mod3 Stage 5] SAFE commits the canonical recovery-response memory immediately")
	check(_dialogue_contains(overlay, "I'm sorry") and _dialogue_contains(overlay, "You thought you did"), "[Mod3 Stage 5] Liza/Daniel post-incident scene plays before Incident 2's own threat")
	before = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_outcome(lm, "RISKY")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, false)) and overlay._banner.text == "BREACH DETECTED", "[Mod3 Stage 5] RISKY commits once and enters breach warning")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD and is_equal_approx(lm._decision_breach_hp_scale(), 0.85), "[Mod3 Stage 5] Existing TD uses 0.85 breach HP")
	await _force_td_win(lm)
	# mod03_s5_recovery_response is only ever authored on Incident 1's own
	# choices — Incident 2 doesn't touch it at all, so it stays exactly what
	# Incident 1's SAFE choice committed above.
	check(lm._decision.resolved_threats == 2 and _player.get_story_memory("mod03_s5_recovery_response") == "verified_recovery", "[Mod3 Stage 5] TD win resolves Incident 2 without disturbing Incident 1's own committed memory")
	overlay._continue_button.pressed.emit()
	await settle()
	check(_dialogue_contains(overlay, "I was angry at her") and _dialogue_contains(overlay, "They used my bank"), "[Mod3 Stage 5] Incident 3 opens with Daniel's crying breakdown, reached through Incident 2's own resolution")
	await _stop_match()

	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	overlay._choice_buttons[_button_for_label(lm, "Keep the recovery caller connected while comparing")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	await _force_td_loss(lm)
	check(lm.current_phase == lm.GamePhase.GAME_OVER and _player.get_story_memory("mod03_s5_recovery_response") == null, "[Mod3 Stage 5] TD loss commits no memory — the abandoned RISKY attempt is never remembered")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	check(lm._decision.threat_index == 0, "[Mod3 Stage 5] TD loss retries Incident 1")
	await _stop_match()

	_player.reset_to_defaults()
	level = await _start_match("mod_03", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	before = _player.get_mastery("vishing")
	overlay._choice_buttons[_button_for_outcome(lm, "CRITICAL")].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("vishing"), one_bkt_step(_player, before, false)), "[Mod3 Stage 5] CRITICAL updates BKT once")
	check(lm.current_phase == lm.GamePhase.GAME_OVER, "[Mod3 Stage 5] CRITICAL reaches Game Over")
	level = await _restart_from_game_over(level)
	lm = _level_manager(level)
	check(lm._decision.threat_index == 0, "[Mod3 Stage 5] CRITICAL retries Incident 1")
	await _stop_match()

	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_03"])
	level = await _start_match("mod_03", 4)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	await _skip_opening(overlay)
	for i in 3:
		await _pick(lm, overlay, "SAFE")
	check(overlay._mode == &"story" and _dialogue_contains(overlay, "I can live with maybe") and _dialogue_contains(overlay, "We were both being used"), "[Mod3 Stage 5] All-SAFE ending reaches the uncertain recovery and Liza/Daniel reconciliation")
	check(_dialogue_contains(overlay, "CYBERCRIME INVESTIGATION UNIT") and _dialogue_contains(overlay, "We need your cooperation"), "[Mod3 Stage 5] Stage 6 cliffhanger plays")
	check(not _player.has_cleared_stage("mod_03", 5), "[Mod3 Stage 5] Stage does not clear before the ending")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage("mod_03", 5), "[Mod3 Stage 5] Ending completes mod_03:5")
	check(root.get_node("StageManager").access_reason(6, "mod_03").is_empty(), "[Mod3 Stage 5] Completion unlocks Stage 6")
	check(not DecisionScenarios.is_decision_stage("mod_03", 6), "[Mod3 Stage 5] Stage 6 remains non-decision (The Officer stays TRACE/post-assessment for now)")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _test_regression() -> void:
	print("== regression: other stages keep TRACE and TD loss payout ==")
	_player.reset_to_defaults()
	_router.active_module_id = "mod_01"
	# Module 1 Stages 1-9 are now decision-based (see _test_stage2 through _test_stage9).
	# Stage 10 is the next TRACE stage (the existing post-assessment) and the
	# correct "still normal" baseline.
	var level: Node = await _start_match("mod_01", 9)
	var lm = _level_manager(level)
	check(lm._decision == null and lm.current_phase == lm.GamePhase.PHASE_1_QUIZ and lm._quiz_modal.visible, "Module 1 Stage 10 still opens the TRACE quiz")
	check(level.get_node("GameplayCanvas").get_node_or_null("DecisionOverlay") == null, "No decision overlay on Stage 10")
	lm.base_health = 0
	lm.change_phase(lm.GamePhase.GAME_OVER)
	await settle()
	check(_player.credits == lm.LOSS_CREDIT_PAYOUT, "Normal Tower Defense stages still award the existing loss payout")
	await _stop_match()
	# Module 2 Stages 1-9 are decision-based (Stage 9 is the module's final
	# story stage, with a generic finale — see _test_module2_stage9()).
	# Stage 10 remains the existing summative post-assessment and is the
	# correct "still normal" baseline.
	level = await _start_match("mod_02", 9)
	lm = _level_manager(level)
	check(lm._decision == null and lm.current_phase == lm.GamePhase.PHASE_1_QUIZ and lm._quiz_modal.visible, "Module 2 Stage 10 still opens the TRACE post-assessment quiz")
	check(not lm.current_question.is_empty() and str(lm.current_question.get("module_id", "")) == "mod_02", "Module 2 selects Smishing questions")
	await _stop_match()
	# Module 3 Stages 1-5 are decision-based. Stage 6 remains TRACE.
	level = await _start_match("mod_03", 5)
	lm = _level_manager(level)
	check(lm._decision == null and lm.current_phase == lm.GamePhase.PHASE_1_QUIZ, "Module 3 Stage 6 still opens the TRACE quiz")
	check(not lm.current_question.is_empty() and str(lm.current_question.get("module_id", "")) == "mod_03", "Module 3 selects Vishing questions")
	await _stop_match()
	_router.active_module_id = "mod_01"


func _ensure_host() -> void:
	if _router._host != null:
		return
	var host := Control.new()
	host.name = "ScreenHost"
	root.add_child(host)
	_router.register_host(host)


func _start_match(module_id: String, stage_index: int) -> Node:
	if _router._gameplay != null and is_instance_valid(_router._gameplay):
		await _router.return_to_stage_select()
		await settle()
	_router.is_tutorial = false
	_router.active_module_id = module_id
	# Explicit legacy context: normal start_level now uses the geometric scene.
	var legacy := MatchContext.new()
	legacy.module_id = module_id
	_router._begin_gameplay(stage_index, legacy)
	await settle(30)
	check(_router._gameplay != null and is_instance_valid(_router._gameplay), "Router started gameplay for %s stage %d" % [module_id, stage_index + 1])
	return _router._gameplay


func _stop_match() -> void:
	if _router._gameplay != null and is_instance_valid(_router._gameplay):
		await _router.return_to_stage_select()
	await settle()


func _restart_from_game_over(level: Node) -> Node:
	var overlay: Node = level.get_node_or_null("BaseDefeatOverlay")
	if overlay == null:
		check(false, "Game Over overlay present for real restart")
		return await _start_match(_router.active_module_id, _router.active_stage_index)
	var old: Node = _router._gameplay
	overlay.action_requested.emit(&"restart")
	for i in 120:
		await process_frame
		if _router._gameplay != null and _router._gameplay != old and is_instance_valid(_router._gameplay):
			break
	await settle(30)
	check(_router._gameplay != null and _router._gameplay != old, "Router.restart_level replaced the running match")
	return _router._gameplay


func _assert_decision_mode(lm, label: String) -> void:
	if lm == null:
		check(false, label + ": LevelManager missing")
		return
	var overlay = lm._decision_overlay
	check(overlay != null and overlay.visible, "%s: decision overlay is shown" % label)
	check(not lm._gold_label.visible, "%s: gold HUD hidden" % label)
	check(not lm._heart_hud.visible, "%s: heart HUD hidden" % label)
	check(not lm._map_label.visible, "%s: map label hidden" % label)
	check(not lm._phase_label.visible, "%s: phase label hidden" % label)
	check(not lm._shop_row.visible, "%s: tower build controls hidden" % label)
	check(not lm._start_wave_button.visible, "%s: start-wave control hidden" % label)
	check(not lm._btn_speed.visible, "%s: speed control hidden" % label)
	var wave_frame: CanvasItem = lm._wave_label.get_parent() as CanvasItem
	check(wave_frame == null or not wave_frame.visible, "%s: wave counter hidden" % label)
	if lm._tower_placer != null:
		check(lm._tower_placer.process_mode == Node.PROCESS_MODE_DISABLED, "%s: combat interaction disabled" % label)


func _assert_fresh_breach(lm, threat_index: int, label: String) -> void:
	if lm == null:
		check(false, label + ": LevelManager missing")
		return
	var threats := DecisionScenarios.get_threats("mod_01", 1)
	var expected_gold: int = 0
	if threat_index >= 0 and threat_index < threats.size():
		expected_gold = int(threats[threat_index].get("breach_gold", 0))
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "%s: BUILD phase" % label)
	check(lm.current_wave_index == 0, "%s: wave counter reset to wave 1" % label)
	var max_hp: int = lm._heart_icons.size() if not lm._heart_icons.is_empty() else 5
	check(lm.base_health == max_hp, "%s: base HP restored to max (%d)" % [label, max_hp])
	check(lm.current_gold == expected_gold, "%s: gold is the breach budget (%d), not leftover" % [label, expected_gold])
	check(lm.active_enemies == 0, "%s: no leftover enemies" % label)
	check(_alive_track_enemies(lm) == 0, "%s: track is empty" % label)
	check(lm._wave_kills == 0 and lm._wave_total_enemies == 0, "%s: wave counters cleared" % label)
	check(lm._is_wave_intermission == false, "%s: intermission flag cleared" % label)
	check(lm._defeat_started == false, "%s: previous defeat state cleared" % label)
	check(lm._global_patch_active == false, "%s: temporary combat flags cleared" % label)
	check(is_equal_approx(lm._shake_intensity, 0.0), "%s: camera shake cleared" % label)
	if lm._tower_placer != null:
		check(lm._tower_placer.placed_count() == 0, "%s: no leftover towers" % label)
		check(lm._tower_placer.occupied_cells.is_empty(), "%s: build grid cleared" % label)


func _dirty_breach_runtime(lm) -> void:
	lm.base_health = 1
	lm.current_gold = 80
	lm.current_wave_index = 2
	lm.active_enemies = 4
	lm._wave_kills = 9
	lm._wave_total_enemies = 10
	lm._global_patch_active = true
	lm._defeat_started = true
	lm._shake_intensity = 12.0
	lm._is_wave_intermission = true
	if lm._tower_placer != null:
		lm._tower_placer.occupied_cells[Vector2i(3, 3)] = Node.new()


func _count_projectiles(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 0
	if node is ProjectileBase:
		count += 1
	for child in node.get_children():
		count += _count_projectiles(child)
	return count


func _alive_track_enemies(lm) -> int:
	if lm == null or lm._track == null:
		return 0
	var count: int = 0
	for child in lm._track.get_children():
		if child is EnemyBase and is_instance_valid(child) and not child.is_queued_for_deletion():
			count += 1
	return count


func _assert_td_mode(lm, label: String) -> void:
	if lm == null:
		check(false, label + ": LevelManager missing")
		return
	var overlay = lm._decision_overlay
	check(overlay == null or not overlay.visible, "%s: decision overlay hidden" % label)
	check(lm._gold_label.visible, "%s: gold HUD restored" % label)
	check(lm._heart_hud.visible, "%s: heart HUD restored" % label)
	check(lm._map_label.visible, "%s: map label restored" % label)
	var wave_frame: CanvasItem = lm._wave_label.get_parent() as CanvasItem
	check(wave_frame != null and wave_frame.visible, "%s: wave counter restored" % label)
	check(lm._shop_row.visible, "%s: tower build controls restored" % label)
	if lm._tower_placer != null:
		check(lm._tower_placer.process_mode == Node.PROCESS_MODE_INHERIT, "%s: combat interaction enabled" % label)


func _level_manager(level: Node) -> Node:
	if level == null:
		return null
	return level.get_node_or_null("LevelManager")


func _skip_opening(overlay) -> void:
	if overlay == null:
		return
	if overlay._mode == &"story":
		overlay._continue_button.pressed.emit()
		await settle()


## Choices are now displayed in a randomized order (see
## DecisionStageController.current_threat_for_display); tests must find a
## button by the OUTCOME it currently shows, never by a fixed position.
func _button_for_outcome(lm, outcome: String) -> int:
	var displayed: Array = lm._decision.current_threat_for_display().get("choices", [])
	for i in displayed.size():
		if str((displayed[i] as Dictionary).get("outcome", "")) == outcome:
			return i
	check(false, "No displayed choice currently has outcome " + outcome)
	return -1


## Choices are randomized, and some tests need one SPECIFIC authored choice
## (e.g. the one demo choice carrying a "story_event") rather than merely
## "any RISKY" — this finds it by a distinguishing label substring, in
## whatever slot it currently displays at.
func _button_for_label(lm, label_substring: String) -> int:
	var displayed: Array = lm._decision.current_threat_for_display().get("choices", [])
	for i in displayed.size():
		if str((displayed[i] as Dictionary).get("label", "")).contains(label_substring):
			return i
	check(false, "No displayed choice currently has a label containing '%s'" % label_substring)
	return -1


func _pick(lm, overlay, outcome: String) -> void:
	overlay._choice_buttons[_button_for_outcome(lm, outcome)].pressed.emit()
	await settle()
	overlay._continue_button.pressed.emit()
	await settle()
	if overlay._mode == &"consequence" and overlay._continue_button.text == "DEPLOY DEFENSES":
		# RISKY: the breach-transition beat needs its own DEPLOY DEFENSES press.
		overlay._continue_button.pressed.emit()
		await settle()


func _force_td_win(lm) -> void:
	lm._on_start_wave_pressed()
	await settle()
	lm._wave_token += 1
	lm._clear_track_enemies()
	lm._wave_finished_spawning = true
	lm.active_enemies = 0
	lm._check_wave_cleared()
	await wait_seconds(2.6)
	await settle()


func _force_td_loss(lm) -> void:
	lm._on_start_wave_pressed()
	await settle()
	lm._wave_token += 1
	lm._clear_track_enemies()
	lm.base_health = 1
	lm._apply_base_breach()
	await settle()


func _no_forbidden_words(node: Node) -> bool:
	var texts: Array[String] = []
	_collect_texts(node, texts)
	for text in texts:
		var upper: String = text.to_upper()
		for word in FORBIDDEN_WORDS:
			if upper.contains(word):
				push_error("Forbidden word '%s' in: %s" % [word, text])
				return false
	return true


func _collect_texts(node: Node, out: Array[String]) -> void:
	if node is Label or node is Button:
		var text: String = str(node.get("text"))
		if not text.is_empty() and node.is_visible_in_tree():
			out.append(text)
	for child in node.get_children():
		_collect_texts(child, out)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(_save_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_save_backup)
			file.close()
	elif FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
