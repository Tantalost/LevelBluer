extends SceneTree
## Legacy-scene regression for the Module 1 Stage 1 decision flow.
## Normal deployment is covered by the isolated verify_stage_one_live.gd harness.
## Run from frontend/:  godot --headless --script res://src/tools/verify_decision_stage.gd
## The local guest save is backed up before the run and restored afterwards.

const FORBIDDEN_WORDS: PackedStringArray = ["QUESTION", "CORRECT ANSWER", "QUIZ", "EXAM", "WRONG"]

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
	check(not DecisionScenarios.is_decision_stage("mod_02", 1), "Module 2 Stage 1 is not decision-based")
	check(not DecisionScenarios.is_decision_stage("mod_02", 2), "Module 2 Stage 2 is not decision-based")
	check(not DecisionScenarios.is_decision_stage("mod_02", 3), "Module 2 Stage 3 is not decision-based")
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
		overlay.show_threat(threats[i], i + 1, threats.size(), "BLUETECH SOLUTIONS  //  SECURITY DESK")
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

	overlay.show_threat(threats[0], 1, 3, "TEST")
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
	print("== choice randomization (generic, applies to every decision stage) ==")
	# Discovers every authored Module 1 decision stage generically, so this
	# test automatically covers Stage 3 and any future Stage 4-9 without
	# needing another manual edit each time one is added.
	var all_threats: Array[Dictionary] = []
	var covered_stages: Array[int] = []
	for stage_number in range(1, 10):
		if DecisionScenarios.is_decision_stage("mod_01", stage_number):
			all_threats.append_array(DecisionScenarios.get_threats("mod_01", stage_number))
			covered_stages.append(stage_number)
	check(all_threats.size() == covered_stages.size() * 3, "Sampling covers exactly 3 threats per authored decision stage %s" % [covered_stages])

	var safe_position_counts: Dictionary = {}
	var samples := 40
	for _sample in samples:
		for threat in all_threats:
			var threat_id: String = str(threat.get("id", ""))
			var module_id: String = str(threat.get("module_id", "mod_01"))
			var stage_id: int = int(threat.get("stage", 1))
			var ctrl := DecisionStageController.new()
			ctrl.setup(module_id, stage_id, [threat])
			var displayed: Array = ctrl.current_threat_for_display().get("choices", [])
			# 1. Every threat still displays exactly 3 choices.
			check(displayed.size() == 3, "%s displays exactly 3 choices" % threat_id)
			# 2. Every displayed set contains exactly one SAFE/RISKY/CRITICAL.
			var outcomes: Array = []
			for c in displayed:
				outcomes.append(str((c as Dictionary).get("outcome", "")))
			check(outcomes.count("SAFE") == 1 and outcomes.count("RISKY") == 1 and outcomes.count("CRITICAL") == 1,
				"%s shows exactly one SAFE, one RISKY and one CRITICAL" % threat_id)
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

	# 4. Across many samples, SAFE is not permanently button 1 / the middle
	# slot (or any other fixed slot) for any threat.
	for threat in all_threats:
		var threat_id: String = str(threat.get("id", ""))
		var per_threat: Dictionary = safe_position_counts.get(threat_id, {})
		check(per_threat.size() > 1, "%s: SAFE is not pinned to one screen position across %d samples (positions seen: %s)" % [threat_id, samples, per_threat.keys()])

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
	check(lm._decision.resolved_threats == 1 and not _player.has_cleared_stage(1), "SAFE on Threat 1 does not clear the stage")
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
	check(lm.current_phase == lm.GamePhase.GAME_OVER and not _player.has_cleared_stage(1), "CRITICAL never clears the stage")
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
	check(not _player.has_cleared_stage(1), "Persistent stage progress is not granted by a single contained breach")
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
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT" and not _player.has_cleared_stage(1), "Ending story plays before the stage clears")
	check(str(_player.get_decision_stage_state("mod_01:1").get("flow_state", "")) == "ENDING", "Ending checkpoint is persisted before victory")
	await _stop_match()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"story" and overlay._continue_button.text == "FILE REPORT" and not _player.has_cleared_stage(1), "Reload during ending restores the ending dialogue")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(1), "Stage 1 clears after the restored ending")
	check(_player.get_decision_stage_state("mod_01:1").is_empty(), "Checkpoint cleared after stage-clear commit")
	var clear_overlay = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay != null and clear_overlay._title.text == "STAGE 1 COMPLETE", "Stage clear card uses the story title")
	check(clear_overlay != null and clear_overlay._advisory.text.contains("STAGE 2"), "Stage clear card points to Stage 2")
	await _stop_match()

	print("-- replay freeze --")
	_player.reset_to_defaults()
	_player.cleared_stages[1] = true
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(2), "[Stage 2] Stage 2 clears after the ending")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(3), "[Stage 3] Stage 3 clears after the ending")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(4), "[Stage 4] Stage 4 clears after the ending")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(5), "[Stage 5] Stage 5 clears after the ending")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(6), "[Stage 6] Stage 6 clears after the ending")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(7), "[Stage 7] Stage 7 clears after the ending")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(8), "[Stage 8] Stage 8 clears after the ending")
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
	check(not _player.has_cleared_stage(9), "[Stage 9] Stage is not marked cleared before the finale is played")
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

	print("-- 10. FINAL CONTAINMENT TD WIN -> CONTAINMENT COMPLETE -> CASE CLOSED -> MODULE 1 STORY COMPLETE -> Stage 9 clears, unlocks Stage 10 --")
	var pl_before_finale_win: float = _player.get_mastery("phishing")
	overlay._continue_button.pressed.emit()
	await settle()
	check(lm.current_phase == lm.GamePhase.PHASE_2_BUILD, "[Stage 9] Retrying DEPLOY FINAL DEFENSES restarts the finale Tower Defense")
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
	check(lm.current_phase == lm.GamePhase.VICTORY and _player.has_cleared_stage(9), "[Stage 9] Stage 9 clears only after the finale and its epilogue")
	var clear_overlay9 = level.get_node_or_null("StageClearOverlay")
	check(clear_overlay9 != null and clear_overlay9._title.text == "STAGE 9 COMPLETE", "[Stage 9] Stage clear card uses the authored title")
	check(clear_overlay9 != null and clear_overlay9._advisory.text.contains("STAGE 10"), "[Stage 9] Stage clear card points to Stage 10")
	await _stop_match()

	print("-- 11. Stage 10 stays the existing post-assessment, never the decision-story live scene --")
	check(not DecisionScenarios.is_decision_stage("mod_01", 10), "[Stage 9] Stage 10 remains a non-decision (TRACE/post-assessment) stage")
	await _stop_match()


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
	level = await _start_match("mod_02", 0)
	lm = _level_manager(level)
	check(lm._decision == null and lm.current_phase == lm.GamePhase.PHASE_1_QUIZ, "Module 2 Stage 1 still opens the TRACE quiz")
	check(not lm.current_question.is_empty() and str(lm.current_question.get("module_id", "")) == "mod_02", "Module 2 selects Smishing questions")
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
