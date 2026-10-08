extends "res://src/gameplay/preview/preview_match.gd"
## School/college assessment adapter. Combat/HUD are shared; story decisions never grade
## this exam. Gateways are injectable so regression tests cannot touch user saves.
var account: Object
var tasks: Object
var mastery_frozen: bool = false
var remediation_required: bool = false
var assessment_started: bool = false
var college: bool = false
var story: Dictionary = {}
var story_overlay: Control
var evidence_round: int = -1
var closing_read: bool = false
var college_ready: bool = false
var missed_questions: Array[Dictionary] = []
var review_index: int = -1
const ROUTE: Array[Vector2i] = [Vector2i(0, 3), Vector2i(2, 3), Vector2i(2, 0), Vector2i(11, 0), Vector2i(11, 6), Vector2i(4, 6), Vector2i(4, 3), Vector2i(8, 3)]

func _valid_context() -> bool:
	return match_context != null and not match_context.preview and match_context.persistent \
		and match_context.geometric and match_context.footprint == 1 \
		and match_context.module_id in ["mod_01", "mod_02"] and match_context.stage_id == 10

func _configure_match() -> void:
	if account == null:
		account = PlayerManager
	if tasks == null:
		tasks = TaskManager
	config = StageManager.get_stage_config(10).duplicate(true)
	college = match_context.module_id == "mod_02"
	if college:
		story = DecisionScenarios.get_stage("mod_02", 10)
		config.merge(story.get("assessment", {}) as Dictionary, true)
	gold = account.consume_intel_bonus_gold(int(config.get("starting_gold", 20)), match_context.module_id)
	mastery_frozen = account.has_cleared_stage(match_context.module_id, 10)
	if college:
		_configure_college_deck()
		return
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
	if college:
		_ready_college()
		return
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
	if question_pool.size() != int(config.get("exam_question_count", 15)) or (college and not college_ready):
		hud.show_modal("ASSESSMENT UNAVAILABLE", "The complete question bank could not be loaded. Return and try again. No score or clear was recorded.", [{"text": "BACK", "id": "exit"}])
		return
	if college:
		_set_phase("Opening")
		story_overlay.show()
		story_overlay.show_story(DecisionScenarios.dialogue_lines(story, "opening"), "FINAL CHECKPOINT", "OPEN CASE 1")
		return
	_set_phase("Trace")
	_next_question()

func _next_question() -> void:
	# Never wrap/repeat a deck, even if a stale Continue signal arrives.
	if answered >= int(config.get("exam_question_count", 15)) or (college and (phase != "Trace" or evidence_round != wave)):
		return
	super._next_question()
	hud.quiz_progress.text = "ASSESSMENT %d / 15  /  ROUND %d OF 3" % [answered + 1, wave + 1]

func _answer_gold(_correct: bool) -> int:
	return 0

func _allows_answer_patch() -> bool:
	return not college

func _enemy_health_scale() -> float:
	return float(story.get("enemy_hp_multiplier", 1.0)) if college else 1.0

func _enemy_task_gateway() -> Object:
	return tasks if college else null

func begin_defend() -> void:
	super.begin_defend()
	if college:
		incident_due = false

func resolve_answer(expired: bool = false) -> void:
	var previous: int = answered
	var previous_correct: int = correct_answers
	super.resolve_answer(expired)
	if answered == previous:
		return
	if answered == int(config.get("exam_question_count", 15)) and account == PlayerManager:
		PlayerManager.record_learning_event("posttest", match_context.module_id, {"attempt_id":_learning_attempt, "instrument":"stage-exam-v1", "correct":correct_answers, "answered":answered, "total":15})
	var correct: bool = correct_answers > previous_correct
	if college and not correct:
		missed_questions.append(question.duplicate(true))
	if not mastery_frozen:
		account.update_mastery("smishing" if college else "phishing", correct, PlayerManager.bkt_params_from(question))
	account.record_trace_result(match_context.module_id, Quiz._question_key(question), correct)

func resolve_incident(correct: bool) -> void:
	if college or not incident_active or phase != "Defend" or paused:
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
		if college:
			_show_college_case()
			return
		_set_phase("Trace")
		_next_question()

func _finish(won: bool) -> void:
	if phase == "Results" or paused:
		return
	# Only a complete passing exam AND all defense waves may clear this stage.
	if won and (answered != int(config.exam_question_count) or waves_completed != config.waves.size() \
		or float(correct_answers) / float(config.exam_question_count) < float(config.exam_required_score)):
		return
	if college and won and not closing_read:
		if phase != "Closing":
			_set_phase("Closing")
			hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED
			story_overlay.show()
			story_overlay.show_story(DecisionScenarios.dialogue_lines(story, "ending"), "HARBOR COLLEGE", "COMPLETE MODULE 2", "FINAL CHECKPOINT PASSED")
		return
	if is_instance_valid(story_overlay):
		story_overlay.hide()
	super._finish(won)

func _result_data(won: bool) -> Dictionary:
	var payout: int = 50 + maxi(0, gold) if won else LevelManager.LOSS_CREDIT_PAYOUT
	if won:
		# Set before mark_stage_cleared saves, avoiding an extra direct SaveService write.
		if not college:
			account.set("module_1_complete", true)
		account.mark_stage_cleared(match_context.module_id, 10)
		tasks.record_stage_cleared()
	account.add_credits(payout)
	var score: float = float(correct_answers) / float(config.exam_question_count)
	return {"live": true, "won": won, "stage": 10, "wave": wave + 1, "waves": config.waves.size(),
		"credits": payout, "kills": correct_answers if won else match_kills, "kills_label": "ANSWERS CORRECT",
		"accuracy": score, "final_stage": true,
		"title": ("MODULE 2 COMPLETE" if college else "MODULE 1 COMPLETE") if won else ("REVIEW AND RETRY" if remediation_required else "DEFENSE INCOMPLETE"),
		"subtitle": "HARBOR COLLEGE / FINAL CHECKPOINT" if college else "HARBOR HIGH / FINAL ASSESSMENT",
		"advisory": "The team is ready for its presentation. Keep checking the next message." if college else "The Water Wise team is ready for the fair. Keep checking the next message.",
		"retry_label": ("REVIEW CASES" if college else "REVIEW LESSONS") if remediation_required else "RESTART",
		"tip": "Score: %d / 15. %s" % [correct_answers, ("Review the missed cases to unlock another attempt." if college else "Review Lessons to clear the assessment lock.") if remediation_required else "Defend through all three waves and score at least 12 / 15."]}

func _destroy_home_on_loss() -> bool:
	return health <= 0

func toggle_pause() -> void:
	# The intro uses the same modal slot as Pause. Do not replace the only Start
	# button with a pause modal before the exam has begun.
	if phase != "Briefing":
		super.toggle_pause()
		if is_instance_valid(story_overlay):
			story_overlay.set_interaction_locked(paused)

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
	if college and is_instance_valid(story_overlay):
		hud.set_story_layout(phase in ["Opening", "Investigation", "Closing"])

func _pause_title() -> String:
	return "Assessment paused"

func _pause_description() -> String:
	return "Resume this attempt, or return to Stage Select. Leaving restarts all fifteen questions and three waves; completed answers stay in learning history."

func _intent(id: String, value: Variant) -> void:
	if college and id == "assessment_review_next":
		_advance_case_review()
		return
	if college and id == "assessment_review_restart":
		if phase == "Results" and remediation_required and review_index == missed_questions.size():
			Router.restart_level()
		return
	if id == "assessment_start":
		start_assessment()
		return
	if id.begins_with("result_") and phase == "Results":
		match id:
			"result_restart":
				if remediation_required:
					if college:
						_begin_case_review()
					else:
						Router.open_lessons()
				else:
					Router.restart_level()
			"result_lessons": Router.open_lessons()
			"result_certificate": Router.open_certificate_screen(match_context.module_id)
			"result_upgrade": Router.open_defeat_upgrades()
			"result_back": Router.return_to_stage_select()
		return
	super._intent(id, value)

func _begin_case_review() -> void:
	if not college or phase != "Results" or not remediation_required or review_index >= 0 or missed_questions.is_empty():
		return
	review_index = 0
	hud.result_overlay.hide()
	_show_case_review()

func _show_case_review() -> void:
	var item: Dictionary = missed_questions[review_index]
	var answers: PackedStringArray = PackedStringArray()
	for option: Dictionary in Quiz.options(item):
		var correct: bool = int(option.value) in Quiz._int_list(item.get("correct_indices", [])) if Quiz.is_multi(item) else Quiz.grade(item, option.value)
		if correct:
			answers.append(str(option.text))
	hud.show_modal("REVIEW %d / %d" % [review_index + 1, missed_questions.size()],
		str(item.question) + "\n\nSupported answer:\n" + "\n".join(answers) + "\n\n" + str(item.explanation),
		[{"text": "NEXT REVIEW" if review_index + 1 < missed_questions.size() else "FINISH REVIEW", "id": "assessment_review_next", "primary": true}, {"text": "BACK TO STAGES", "id": "exit"}])

func _advance_case_review() -> void:
	if not college or phase != "Results" or not remediation_required or review_index < 0 or review_index >= missed_questions.size():
		return
	review_index += 1
	if review_index == missed_questions.size():
		account.unlock_stage("mod_02", 10)
		hud.show_modal("REVIEW COMPLETE", "The missed case decisions have been reviewed. Restart all three cases and defense waves for a new attempt. Your previous score and learning history remain recorded.",
			[{"text": "RESTART CHECKPOINT", "id": "assessment_review_restart", "primary": true}, {"text": "BACK TO STAGES", "id": "exit"}])
	else:
		_show_case_review()

func _configure_college_deck() -> void:
	question_pool.clear()
	var rounds: Array = story.get("rounds", []) as Array
	if rounds.size() != 3 or (config.waves as Array).size() != 3:
		return
	var ids: Dictionary = {}
	for raw: Variant in rounds:
		if not raw is Dictionary:
			question_pool.clear()
			return
		var round_data: Dictionary = raw as Dictionary
		var questions: Array = round_data.get("questions", []) as Array
		var inspection: Dictionary = round_data.get("investigation", {}) as Dictionary
		if questions.size() != 5 or (inspection.get("items", []) as Array).is_empty():
			question_pool.clear()
			return
		for entry: Variant in questions:
			if not entry is Dictionary:
				question_pool.clear()
				return
			var item: Dictionary = entry as Dictionary
			var id: String = str(item.get("id", ""))
			if id.is_empty() or ids.has(id) or str(item.get("module_id", "")) != "mod_02" or str(item.get("skill_id", "")) != "smishing":
				question_pool.clear()
				return
			ids[id] = true
			question_pool.append(item.duplicate(true))

func _ready_college() -> void:
	var routes: Array = []
	for raw: Array in story.get("map_routes", []):
		var points: Array[Vector2i] = []
		for pair: Array in raw:
			if pair.size() != 2:
				return
			points.append(Vector2i(int(pair[0]), int(pair[1])))
		routes.append(points)
	college_ready = question_pool.size() == 15 and routes.size() == 2 and hud.battle.configure_routes(routes)
	hud.battle.board.set_campus_style(true)
	hud.preview_label.text = "HARBOR COLLEGE / FINAL CHECKPOINT"
	story_overlay = preload("res://src/gameplay/decision/decision_workspace.gd").new()
	story_overlay.name = "AssessmentWorkspace"
	hud.body.add_child(story_overlay)
	story_overlay.set_story_art("mod_02", "Mia")
	story_overlay.configure_presentation(story)
	story_overlay.configure_laptop(story.get("laptop", {}) as Dictionary)
	story_overlay.set_background("college_commons")
	story_overlay.set_story_hp(-1)
	story_overlay.hide()
	story_overlay.story_continued.connect(_college_story_continued)
	story_overlay.choice_selected.connect(_college_case_confirmed)
	story_overlay.pause_requested.connect(toggle_pause)
	hud.show_modal("FINAL CHECKPOINT",
		"Three college cases. Inspect each laptop evidence pack, then answer five questions and defend both entrances.\n\nPass: 12 / 15 correct AND survive all 3 waves.\nNo answer gold or combat bonuses. Evidence reading is untimed; scored questions show their own time limit.\n\nLeaving restarts the attempt; completed answers stay in learning history.",
		[{"text": "BEGIN CHECKPOINT", "id": "assessment_start", "primary": true}, {"text": "BACK", "id": "exit"}])

func _college_story_continued() -> void:
	if paused or not is_instance_valid(story_overlay) or not story_overlay._dialogue_done:
		return
	if phase == "Opening":
		_show_college_case()
	elif phase == "Closing":
		closing_read = true
		_finish(true)

func _show_college_case() -> void:
	_set_phase("Investigation")
	Engine.time_scale = 1.0
	hud.battle.enabled = false
	var round_data: Dictionary = (story.rounds[wave] as Dictionary).duplicate(true)
	round_data["choices"] = [{"label": "BEGIN FIVE SCORED QUESTIONS"}]
	story_overlay.show()
	story_overlay.show_threat(round_data, DecisionScenarios.dialogue_lines(round_data, "story"), wave + 1, 3, "FINAL CHECKPOINT")
	story_overlay.set_investigation(round_data.investigation as Dictionary)

func _college_case_confirmed(index: int) -> void:
	if paused or phase != "Investigation" or index != 0 or not story_overlay._dialogue_done \
		or not story_overlay._investigation_config.is_empty() or not story_overlay._phone.is_complete():
		return
	evidence_round = wave
	story_overlay.hide()
	_set_phase("Trace")
	_next_question()
