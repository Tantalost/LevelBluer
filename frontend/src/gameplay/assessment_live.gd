extends "res://src/gameplay/preview/preview_match.gd"
## Module 1 assessment adapter. Combat/HUD are shared; story decisions never grade
## this exam. Gateways are injectable so regression tests cannot touch user saves.
var account: Object
var tasks: Object
var mastery_frozen: bool = false
var remediation_required: bool = false
var assessment_started: bool = false
const ROUTE: Array[Vector2i] = [Vector2i(0, 3), Vector2i(2, 3), Vector2i(2, 0), Vector2i(11, 0), Vector2i(11, 6), Vector2i(4, 6), Vector2i(4, 3), Vector2i(8, 3)]

func _valid_context() -> bool:
	return match_context != null and not match_context.preview and match_context.persistent \
		and match_context.geometric and match_context.footprint == 1 \
		and match_context.module_id == "mod_01" and match_context.stage_id == 10

func _configure_match() -> void:
	if account == null:
		account = PlayerManager
	if tasks == null:
		tasks = TaskManager
	config = StageManager.get_stage_config(10).duplicate(true)
	gold = account.consume_intel_bonus_gold(int(config.get("starting_gold", 20)), match_context.module_id)
	mastery_frozen = account.has_cleared_stage(match_context.module_id, 10)
	var pool: Array[Dictionary] = []
	for raw: Variant in ContentDB.get_module_questions(match_context.module_id):
		if not raw is Dictionary:
			continue
		var row: Dictionary = (raw as Dictionary).duplicate(true)
		if str(row.get("module_id", match_context.module_id)).strip_edges() != match_context.module_id:
			continue
		if str(row.get("skill_id", "")).strip_edges().is_empty():
			row["skill_id"] = "phishing"
		if str(row.skill_id).strip_edges().to_lower() == "phishing":
			pool.append(row)
	question_pool = Quiz.build_exam_deck(pool, match_context.module_id)

func _ready() -> void:
	super._ready()
	if hud == null:
		return
	hud.hide_intro()
	hud.battle.configure_route(ROUTE)
	hud.preview_label.text = "HARBOR HIGH / FINAL ASSESSMENT"
	hud.show_modal("READY FOR THE NEXT MESSAGE",
		"Ms. Reyes: This time, the evidence and decisions are yours.\n\n15 questions / 5 before each defense wave.\nPass: 12 of 15 correct AND survive all 3 waves.\nGold: starting budget + enemy bounties; no answer rewards.\n\nRead feedback at your own pace. Leaving restarts the attempt, but keeps your answer history.",
		[{"text": "BEGIN ASSESSMENT", "id": "assessment_start", "primary": true}, {"text": "BACK", "id": "exit"}])

func advance_briefing(_delta: float) -> void:
	# Explicit start gives the player time to read the assessment rules.
	pass

func start_assessment() -> void:
	if phase != "Briefing" or paused or assessment_started:
		return
	assessment_started = true
	hud.close_modal()
	if question_pool.size() != int(config.get("exam_question_count", 15)):
		hud.show_modal("ASSESSMENT UNAVAILABLE", "The complete question bank could not be loaded. Return and try again. No score or clear was recorded.", [{"text": "BACK", "id": "exit"}])
		return
	_set_phase("Trace")
	_next_question()

func _next_question() -> void:
	# Never wrap/repeat a deck, even if a stale Continue signal arrives.
	if answered >= int(config.get("exam_question_count", 15)):
		return
	super._next_question()
	hud.quiz_progress.text = "ASSESSMENT %d / 15  /  ROUND %d OF 3" % [answered + 1, wave + 1]

func _answer_gold(_correct: bool) -> int:
	return 0

func resolve_answer(expired: bool = false) -> void:
	var previous: int = answered
	var previous_correct: int = correct_answers
	super.resolve_answer(expired)
	if answered == previous:
		return
	var correct: bool = correct_answers > previous_correct
	if not mastery_frozen:
		account.update_mastery("phishing", correct, PlayerManager.bkt_params_from(question))
	account.record_trace_result(match_context.module_id, Quiz._question_key(question), correct)

func resolve_incident(correct: bool) -> void:
	if not incident_active or phase != "Defend" or paused:
		return
	if not mastery_frozen:
		account.update_mastery("phishing", correct, {})
	super.resolve_incident(correct)

func _wave_cleared() -> void:
	if phase != "Defend" or paused:
		return
	waves_completed = wave + 1
	if waves_completed >= config.waves.size():
		remediation_required = float(correct_answers) / float(config.exam_question_count) < float(config.exam_required_score)
		if remediation_required:
			account.lock_stage(match_context.module_id, 10)
		_finish(not remediation_required)
	else:
		wave += 1
		question_index = 0
		_set_phase("Trace")
		_next_question()

func _finish(won: bool) -> void:
	if phase == "Results":
		return
	# Only a complete passing exam AND all defense waves may clear this stage.
	if won and (answered != int(config.exam_question_count) or waves_completed != config.waves.size() \
		or float(correct_answers) / float(config.exam_question_count) < float(config.exam_required_score)):
		return
	super._finish(won)

func _result_data(won: bool) -> Dictionary:
	var payout: int = 50 + maxi(0, gold) if won else LevelManager.LOSS_CREDIT_PAYOUT
	if won:
		# Set before mark_stage_cleared saves, avoiding an extra direct SaveService write.
		account.set("module_1_complete", true)
		account.mark_stage_cleared(match_context.module_id, 10)
		tasks.record_stage_cleared()
	account.add_credits(payout)
	var score: float = float(correct_answers) / float(config.exam_question_count)
	return {"live": true, "won": won, "stage": 10, "wave": wave + 1, "waves": config.waves.size(),
		"credits": payout, "kills": correct_answers if won else match_kills, "kills_label": "ANSWERS CORRECT",
		"accuracy": score, "final_stage": true,
		"title": "MODULE 1 COMPLETE" if won else ("REVIEW AND RETRY" if remediation_required else "DEFENSE INCOMPLETE"),
		"subtitle": "HARBOR HIGH / FINAL ASSESSMENT",
		"advisory": "The Water Wise team is ready for the fair. Keep checking the next message.",
		"retry_label": "REVIEW LESSONS" if remediation_required else "RESTART",
		"tip": "Score: %d / 15. %s" % [correct_answers, "Review Lessons to clear the assessment lock." if remediation_required else "Defend through all three waves and score at least 12 / 15."]}

func _destroy_home_on_loss() -> bool:
	return health <= 0

func toggle_pause() -> void:
	# The intro uses the same modal slot as Pause. Do not replace the only Start
	# button with a pause modal before the exam has begun.
	if phase != "Briefing":
		super.toggle_pause()

func _capacity(kind: String) -> int:
	return account.tower_capacity(kind)

func _access_reason(kind: String) -> String:
	return "" if account.is_tower_unlocked(kind) else "Unlock this tower in Upgrades before deploying it."

func _research_bonus(kind: String) -> Dictionary:
	return account.stats_bonus_for(kind) if kind == "base" else {}

func _update_hud() -> void:
	super._update_hud()
	hud.status.text = "STAGE 10 / WAVE %d/%d" % [wave + 1, config.waves.size()]
	hud.phase_label.text = "ASSESSMENT" if phase == "Trace" else phase.to_upper()
	hud.pause_button.visible = phase not in ["Briefing", "Results"]

func _pause_title() -> String:
	return "Assessment paused"

func _pause_description() -> String:
	return "Resume this attempt, or return to Stage Select. Leaving restarts all fifteen questions and three waves; completed answers stay in learning history."

func _intent(id: String, value: Variant) -> void:
	if id == "assessment_start":
		start_assessment()
		return
	if id.begins_with("result_") and phase == "Results":
		match id:
			"result_restart":
				if remediation_required:
					Router.open_lessons()
				else:
					Router.restart_level()
			"result_lessons": Router.open_lessons()
			"result_certificate": Router.open_certificate_screen()
			"result_upgrade": Router.open_defeat_upgrades()
			"result_back": Router.return_to_stage_select()
		return
	super._intent(id, value)
