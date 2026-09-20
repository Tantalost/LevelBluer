extends SceneTree
## Headless check for the Module 1 Stage 1 decision flow.
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
	await _test_required_scenarios()
	await _test_regression()

	_restore_save()
	print("DECISION_STAGE_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_data_model(threats: Array[Dictionary]) -> void:
	print("== data model ==")
	check(DecisionScenarios.is_decision_stage("mod_01", 1), "Module 1 Stage 1 is decision-based")
	check(not DecisionScenarios.is_decision_stage("mod_01", 2), "Module 1 Stage 2 is not decision-based")
	check(not DecisionScenarios.is_decision_stage("mod_02", 1), "Module 2 Stage 1 is not decision-based")
	check(threats.size() == 3, "Stage 1 has three threats")
	for i in threats.size():
		var outcomes: Array[String] = []
		for c in 3:
			outcomes.append(DecisionScenarios.choice_outcome(threats[i], c))
		check(outcomes.has("SAFE") and outcomes.has("RISKY") and outcomes.has("CRITICAL"), "Threat %d offers SAFE, RISKY and CRITICAL" % (i + 1))


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
	check(overlay._choice_buttons[0].get_theme_font_size("font_size") == 10, "Choice text is not shrunk")
	for i in threats.size():
		overlay.show_threat(threats[i], i + 1, threats.size(), "BLUETECH SOLUTIONS  //  SECURITY DESK")
		await settle(20)
		check(overlay._window.size.y <= 680.0, "Threat %d window stays inside 1280x720 (%dpx)" % [i + 1, int(overlay._window.size.y)])
		check(overlay._window.size.x <= 1280.0, "Threat %d window width fits the viewport" % (i + 1))
		var focused := 0
		var reachable := 0
		for b in overlay._choice_buttons.size():
			var button: Button = overlay._choice_buttons[b]
			if not button.visible:
				continue
			check(not button.clip_text, "Threat %d choice %s does not clip text" % [i + 1, char(65 + b)])
			check(button.custom_minimum_size.y >= 56.0, "Threat %d choice %s grows with its label" % [i + 1, char(65 + b)])
			check(button.size.y + 0.5 >= button.custom_minimum_size.y, "Threat %d choice %s is tall enough for wrapped text" % [i + 1, char(65 + b)])
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
	var ctrl := DecisionStageController.new()
	ctrl.setup("mod_01", 1, threats)
	check(ctrl.choose(1).get("outcome", "") == "SAFE", "Threat 1 option B is SAFE")
	check(ctrl.resolved_threats == 0 and ctrl.safe_count == 0, "choose() does not commit progress")
	var first_commit: Dictionary = ctrl.commit()
	check(first_commit.get("committed", false) and ctrl.commit().is_empty(), "The same decision cannot be committed twice")
	check(not ctrl.is_complete() and ctrl.resolved_threats == 1, "One SAFE decision does not clear the stage")
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
	t1.choose(0)
	t1.commit()
	check(t1.stage_failed and t1.threat_index == 0 and t1.security_state == DecisionStageController.STATE_NOMINAL, "CRITICAL fails without persisting COMPROMISED")
	var t1_snap: Dictionary = t1.checkpoint_state()
	check(int(t1_snap.get("threat_index", -1)) == 0 and str(t1_snap.get("flow_state", "")) == DecisionStageController.FLOW_THREAT, "Threat 1 failure still writes a checkpoint")
	var t1_again := DecisionStageController.new()
	t1_again.setup("mod_01", 1, threats)
	check(t1_again.restore(t1_snap) and t1_again.threat_index == 0 and not t1_again.stage_failed and t1_again.flow_state == DecisionStageController.FLOW_THREAT, "Threat 1 checkpoint is a resume, not a fresh run")

	check(ctrl.choose(1).get("outcome", "") == "SAFE", "Threat 3 option B is SAFE")
	ctrl.commit()
	check(ctrl.is_complete() and ctrl.flow_state == DecisionStageController.FLOW_ENDING, "Stage completes after all three threats")
	var ending_snap: Dictionary = ctrl.checkpoint_state()
	var ending_restore := DecisionStageController.new()
	ending_restore.setup("mod_01", 1, threats)
	check(ending_restore.restore(ending_snap) and ending_restore.flow_state == DecisionStageController.FLOW_ENDING and ending_restore.is_complete(), "Ending checkpoint restores the ending, not Threat 1")

	var lost := DecisionStageController.new()
	lost.setup("mod_01", 1, threats)
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
	overlay._choice_buttons[1].pressed.emit()
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
	overlay._choice_buttons[1].pressed.emit()
	await settle()
	check(is_equal_approx(_player.get_mastery("phishing"), pl_before_pending), "Uncommitted SAFE has not touched BKT")
	await _stop_match()
	level = await _start_match("mod_01", 0)
	lm = _level_manager(level)
	overlay = lm._decision_overlay
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Reload after uncommitted choice returns to Threat 2")
	check(is_equal_approx(_player.get_mastery("phishing"), pl_before_pending), "Reload did not apply the uncommitted BKT update")

	print("-- 4. Threat 2 CRITICAL, real restart, Threat 2 restored --")
	overlay._choice_buttons[0].pressed.emit()
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
	await _pick(overlay, 1)
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
	overlay._choice_buttons[0].pressed.emit()
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
		await _pick(overlay, 0)
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
	await _pick(overlay, 2)
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
	await _pick(overlay, 1)
	check(lm._decision.resolved_threats == 1, "Threat 1 resolved")
	check(overlay._mode == &"threat" and overlay._header_right.text == "INCIDENT 2 / 3", "Threat 2 appears")
	await _pick(overlay, 2)
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
	await _pick(overlay, 2)
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
	await _pick(overlay, 2)
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
	await _pick(overlay, 2)
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
	await _pick(overlay, 1)
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
	await _pick(overlay, 1)
	check(is_equal_approx(_player.get_mastery("phishing"), pl_replay), "Replay keeps P(L) frozen")
	await _stop_match()


func _test_regression() -> void:
	print("== regression: other stages keep TRACE and TD loss payout ==")
	_player.reset_to_defaults()
	_router.active_module_id = "mod_01"
	var level: Node = await _start_match("mod_01", 1)
	var lm = _level_manager(level)
	check(lm._decision == null and lm.current_phase == lm.GamePhase.PHASE_1_QUIZ and lm._quiz_modal.visible, "Module 1 Stage 2 still opens the TRACE quiz")
	check(level.get_node("GameplayCanvas").get_node_or_null("DecisionOverlay") == null, "No decision overlay on Stage 2")
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
	await _router.start_level(stage_index, module_id)
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


func _pick(overlay, choice_index: int) -> void:
	overlay._choice_buttons[choice_index].pressed.emit()
	await settle()
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
