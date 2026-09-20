extends "res://src/gameplay/preview/preview_match.gd"
## Production Stage 1: existing decision state and persistence, approved geometric
## combat/UI. Other stages and the disposable preview never instantiate this class.
## Injectable account/task gateways let tests exercise writes without a real save.
var account: Object
var tasks: Object
var decision: DecisionStageController
var story: Dictionary
var story_overlay: Control
var story_next: Callable
var mastery_frozen := false
# Reopening an already-graded breach is a story review, not another assessment.
# Persist this marker through exits before the player chooses again.
var reviewed_breach_index := -1
const DECISION_SECONDS := 45.0
var decision_seconds_left := DECISION_SECONDS
var decision_timer_active := false

func _valid_context() -> bool:
	return match_context != null and not match_context.preview and match_context.persistent \
		and match_context.geometric and match_context.footprint == 1 \
		and match_context.stage_id == 1 and match_context.module_id == "mod_01" \
		and DecisionScenarios.is_decision_stage("mod_01", 1)

func _configure_match() -> void:
	if account == null:
		account = PlayerManager
	if tasks == null:
		tasks = TaskManager
	config = StageManager.get_stage_config(1).duplicate(true)
	story = DecisionScenarios.get_stage("mod_01", 1)
	config["name"] = str(story.get("title", config.get("name", "Stage 1")))
	gold = account.consume_intel_bonus_gold(int(config.get("starting_gold", 2)), "mod_01")
	mastery_frozen = account.has_cleared_stage(1)
	decision = DecisionStageController.new()
	decision.setup("mod_01", 1, DecisionScenarios.get_threats("mod_01", 1))
	var checkpoint: Dictionary = account.get_decision_stage_state(_key())
	decision.restore(checkpoint)
	var reviewed_index := int(checkpoint.get("reviewed_breach_index", -1))
	if reviewed_index == decision.threat_index:
		reviewed_breach_index = reviewed_index
	if decision.is_breach_active():
		reviewed_breach_index = decision.threat_index
		# Preserve resolved incidents and security, but reopen this incident's
		# dialogue/evidence/choices instead of jumping into the saved battle.
		var review := decision.checkpoint_state()
		review["flow_state"] = DecisionStageController.FLOW_THREAT
		review["in_breach"] = false
		decision.restore(review)

func _ready() -> void:
	super._ready()
	if hud == null:
		return
	hud.preview_label.text = "MODULE 01 / STORY MISSION"
	story_overlay = preload("res://src/gameplay/decision/decision_workspace.gd").new()
	story_overlay.name = "DecisionOverlay"
	hud.body.add_child(story_overlay)
	story_overlay.hide()
	story_overlay.story_continued.connect(_story_continued)
	story_overlay.choice_selected.connect(_choice_selected)
	story_overlay.consequence_continued.connect(_consequence_continued)
	story_overlay.decision_ready.connect(_decision_ready)

func _process(delta: float) -> void:
	super._process(delta)
	advance_decision_timer(delta)

func _decision_ready() -> void:
	if phase != "Incident" or story_overlay._mode != &"threat" or decision_timer_active:
		return
	decision_seconds_left = DECISION_SECONDS
	decision_timer_active = true
	story_overlay.update_decision_timer(decision_seconds_left, DECISION_SECONDS)

func advance_decision_timer(delta: float) -> void:
	if not decision_timer_active or paused or phase != "Incident" or story_overlay._review_open:
		return
	decision_seconds_left = maxf(0, decision_seconds_left - maxf(0, delta))
	story_overlay.update_decision_timer(decision_seconds_left, DECISION_SECONDS)
	if decision_seconds_left <= 0:
		_expire_decision()

func _expire_decision() -> void:
	if not decision_timer_active or paused or story_overlay._review_open:
		return
	decision_timer_active = false
	var choices: Array = decision.current_threat().get("choices", [])
	for i in choices.size():
		if str(choices[i].get("outcome", "")) == DecisionScenarios.OUTCOME_RISKY:
			decision.choose(i)
			# Timeout is assessed as risk, but never claim the player chose an action.
			_commit_decision()
			story_overlay.show_consequence(DecisionScenarios.OUTCOME_RISKY,
				"No response was made within 45 seconds. The threat remained uncontained and a breach was detected on %s." % _affected_system(),
				"Deploy defenses to contain the threat before it spreads.", _header(), "DEPLOY DEFENSES", "TIME EXPIRED / BREACH DETECTED")
			return

func advance_briefing(delta: float) -> void:
	if phase != "Briefing" or paused:
		return
	intro_elapsed = minf(4, intro_elapsed + delta)
	hud.show_intro(str(config.name), intro_elapsed)
	if intro_elapsed < 4:
		return
	hud.hide_intro()
	if decision.is_complete():
		_show_story("ending", _finish_investigation, "FILE REPORT")
	elif account.get_decision_stage_state(_key()).is_empty():
		_show_story("opening", _show_threat)
	else:
		_show_threat()

func _update_hud() -> void:
	super._update_hud()
	if decision != null:
		hud.status.text = "STAGE 01 / INCIDENT %d/%d" % [decision.current_threat_number(), decision.total_threats()]

func _capacity(kind: String) -> int:
	return account.tower_capacity(kind)

func _access_reason(kind: String) -> String:
	return "" if account.is_tower_unlocked(kind) else "Unlock this tower in Upgrades before deploying it."

func _research_bonus(kind: String) -> Dictionary:
	return account.stats_bonus_for(kind) if kind == "base" else {}

func _enemy_health_scale() -> float:
	return LevelManager.DECISION_BREACH_ENEMY_HP_MULTIPLIER

func _key() -> String:
	return DecisionScenarios.stage_key("mod_01", 1)

func _save_checkpoint() -> void:
	var checkpoint := decision.checkpoint_state()
	if reviewed_breach_index == decision.threat_index:
		checkpoint["reviewed_breach_index"] = reviewed_breach_index
	account.set_decision_stage_state(_key(), checkpoint)

func _header() -> String:
	return str(story.get("company", "BlueTech Solutions")).to_upper() + " // SECURITY DESK"

func _present_story() -> void:
	decision_timer_active = false
	_set_phase("Incident")
	Engine.time_scale = 1.0
	hud.battle.enabled = false
	hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED
	story_overlay.show()

func _show_story(key: String, next: Callable, caption: String = "CONTINUE") -> void:
	var lines := DecisionScenarios.dialogue_lines(story, key)
	if lines.is_empty():
		next.call()
		return
	_present_story()
	story_next = next
	story_overlay.show_story(lines, _header(), caption)

func _story_continued() -> void:
	if paused or phase != "Incident":
		return
	var next := story_next
	story_next = Callable()
	if next.is_valid():
		next.call()

func _show_threat() -> void:
	if decision.is_complete():
		_show_story("ending", _finish_investigation, "FILE REPORT")
		return
	decision.capture_retry_checkpoint()
	_save_checkpoint()
	_present_story()
	story_overlay.show_threat(decision.current_threat(), decision.current_threat_number(), decision.total_threats(), _header())

func _choice_selected(index: int) -> void:
	if paused or phase != "Incident" or story_overlay._mode != &"threat" or not decision_timer_active or story_overlay._review_open:
		return
	if decision_seconds_left <= 0:
		_expire_decision()
		return
	var result := decision.choose(index)
	if result.is_empty():
		return
	decision_timer_active = false
	story_overlay.show_consequence(str(result.outcome), str(result.choice.get("consequence", "")), str(result.threat.get("explanation", "")), _header(), "DAMAGE REPORT" if result.outcome == DecisionScenarios.OUTCOME_CRITICAL else "CONTINUE")

func _commit_decision() -> Dictionary:
	var result := decision.commit()
	if result.is_empty():
		return result
	# Capture the committed threat's skill, not the next threat after SAFE advances.
	var skill := str(result.threat.get("bkt_skill", story.get("bkt_skill", "phishing")))
	if not mastery_frozen and int(result.threat_index) != reviewed_breach_index:
		account.update_mastery(skill, bool(result.bkt_correct))
	_save_checkpoint()
	return result

func _consequence_continued() -> void:
	if paused or phase != "Incident" or story_overlay._mode != &"consequence":
		return
	if decision.awaiting_breach_deploy():
		_begin_breach()
		return
	var result := _commit_decision()
	if result.is_empty():
		return
	match str(result.outcome):
		DecisionScenarios.OUTCOME_SAFE:
			_show_threat()
		DecisionScenarios.OUTCOME_RISKY:
			story_overlay.show_consequence(DecisionScenarios.OUTCOME_RISKY,
				"Malicious activity has been detected on %s." % _affected_system(),
				"The threat is attempting to spread through the internal network.", _header(), "DEPLOY DEFENSES", "BREACH DETECTED")
		DecisionScenarios.OUTCOME_CRITICAL:
			_finish(false)

func _affected_system() -> String:
	var value := str(decision.current_threat().get("affected_system", "")).strip_edges()
	return value if not value.is_empty() else "the affected workstation"

func _begin_breach() -> void:
	if paused or not decision.is_breach_active() or phase not in ["Incident", "Briefing"]:
		return
	cancel_selection()
	# Each breach retains the authored fresh-encounter rule: no previous towers,
	# bolts, enemies, lag, gold or damage carry into the next incident.
	for child in hud.battle.world.get_children():
		if child != hud.battle.board and child != hud.battle.track and child != hud.battle.camera:
			hud.battle.world.remove_child(child)
			child.queue_free()
	for child in hud.battle.track.get_children():
		hud.battle.track.remove_child(child)
		child.queue_free()
	occupied.clear()
	global_patch = false
	wave = 0
	health = 5
	var budget := int(decision.current_threat().get("breach_gold", 0))
	gold = budget if budget > 0 else maxi(0, int(config.get("starting_gold", 0)))
	speed = 1
	spawned = 0
	defeated = 0
	active_enemies = 0
	incident_active = false
	hud.battle.shake_left = 0
	hud.battle.camera.offset = Vector2.ZERO
	hud.battle.world.process_mode = Node.PROCESS_MODE_INHERIT
	story_overlay.hide()
	_set_phase("Build")

func begin_defend() -> void:
	if not decision.is_breach_active():
		return
	super.begin_defend()
	# Decision encounters measure the authored choice; no unrelated incident BKT.
	incident_due = false

func _wave_cleared() -> void:
	if not decision.is_breach_active() or phase != "Defend":
		return
	waves_completed += 1
	var system := _affected_system()
	decision.contain_breach()
	_save_checkpoint()
	_present_story()
	story_next = _show_threat
	var lines: Array[Dictionary] = [{"speaker": "", "text": "The threat on %s was isolated before reaching critical systems." % system}]
	story_overlay.show_story(lines, _header(), "CONTINUE INVESTIGATION", "BREACH CONTAINED")

func _finish_investigation() -> void:
	if decision.is_complete():
		_finish(true)

func _finish(won: bool) -> void:
	if phase == "Results" or (won and not decision.is_complete()):
		return
	story_overlay.hide()
	super._finish(won)

func _destroy_home_on_loss() -> bool:
	return health <= 0

func _result_data(won: bool) -> Dictionary:
	var data := {"live": true, "won": won, "stage": 1, "wave": 1, "waves": config.waves.size(), "credits": 0, "kills": match_kills, "final_stage": false}
	if won:
		account.mark_stage_cleared(1)
		account.clear_decision_stage_state(_key())
		tasks.record_stage_cleared()
		var payout := 50 + maxi(0, gold)
		account.add_credits(payout)
		data.merge({"credits": payout, "title": str(story.get("clear_title", "STAGE CLEARED")),
			"subtitle": "MAP A1 / " + str(story.get("clear_subtitle", "DEFENSE SECURED")),
			"kills": decision.resolved_threats, "kills_label": "THREATS RESOLVED",
			"accuracy": float(decision.safe_count) / maxf(1, decision.total_threats()),
			"advisory": "NEXT: " + str(story.get("next_stage_title", "STAGE 2")).to_upper()}, true)
	else:
		if decision.is_breach_active():
			decision.fail_breach()
		_save_checkpoint()
		var critical := decision.last_failure_critical
		data.merge({"is_decision": true, "retry_label": "RETRY", "exit_label": "EXIT MISSION",
			"title": "SYSTEM COMPROMISED" if critical else "CONTAINMENT FAILED",
			"subtitle": "MAP A1 / " + ("CRITICAL DECISION" if critical else "SYSTEM BREACH"),
			"body": decision.fail_tip if critical else str(decision.current_threat().get("explanation", "Containment failed.")),
			"tip": decision.game_over_tip()}, true)
	return data

func _pause_title() -> String:
	return "Mission paused"

func _pause_description() -> String:
	return "Your incident checkpoint is saved. Returning reopens its story and choices before defenses. Completed incidents stay completed."

func toggle_pause() -> void:
	super.toggle_pause()
	if phase == "Incident":
		story_overlay.set_interaction_locked(paused)
	if not paused and phase == "Incident":
		hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED

func _intent(id: String, value: Variant) -> void:
	if id.begins_with("result_") and phase == "Results":
		match id:
			"result_restart": Router.restart_level()
			"result_next": Router.advance_level()
			"result_upgrade": Router.open_defeat_upgrades()
			"result_lessons": Router.open_lessons()
			"result_back": Router.return_to_stage_select()
		return
	super._intent(id, value)
