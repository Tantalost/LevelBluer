extends "res://src/gameplay/preview/preview_match.gd"
## Disposable training on the production phone and battlefield. No account gateway,
## grading, checkpoints, stage unlocks or task rewards are available to this scene.
const Workspace: GDScript = preload("res://src/gameplay/decision/decision_workspace.gd")
var story_view: Control
var coach: TutorialOverlay
var threat: Dictionary
var training_hp: int = 3
var decision_remaining: float = 0.0
var decision_duration: float = 45.0
var deciding: bool = false
var decision_open: bool = false
var evidence_complete: bool = false
var last_outcome: String = ""
var lesson_handoff: bool = false

func _valid_context() -> bool:
	return match_context != null and match_context.tutorial and match_context.geometric \
		and not match_context.preview and not match_context.persistent and not match_context.account_bonuses

func _configure_match() -> void:
	config = {"name": "Guided training", "incident_chance": 0.0,
		"waves": [{"enemy_count": 3, "enemy_type": "basic", "spawn_delay": 2.0, "health_multiplier": 0.5}]}
	gold = 8
	health = 5
	threat = DecisionScenarios.get_threats("mod_01", 1)[0].duplicate(true)

func _ready() -> void:
	super._ready()
	if hud == null:
		return
	hud.hide_intro()
	hud.pause_button.hide()
	story_view = Workspace.new()
	story_view.minimum_text_pixels = 20.0
	hud.body.add_child(story_view)
	story_view._phone.guide_text_pixels = 20.0
	story_view.set_story_art("mod_01", "Ms. Reyes")
	story_view.configure_phone(DecisionScenarios.get_stage("mod_01", 1).get("phone", {}))
	story_view.story_continued.connect(_begin_investigation)
	story_view.choice_selected.connect(_choose_training_response)
	story_view.decision_ready.connect(_decision_available)
	story_view.consequence_continued.connect(_after_response)
	coach = TutorialOverlay.mount_on(self)
	coach.hide()
	_set_phase("Training")
	var lines: Array[Dictionary] = [{"speaker": "Ms. Reyes", "text": tr("TUTORIAL_PHONE_INTRO")}]
	story_view.show_story(lines, tr("TUTORIAL_PRACTICE"), tr("TUTORIAL_PHONE_START"))
	_update_hud()

func _begin_investigation() -> void:
	if phase != "Training":
		return
	phase = "Investigate"
	var source_lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(threat, "story")
	var lines: Array[Dictionary] = [source_lines[0].duplicate(true),
		{"speaker": "Ms. Reyes", "text": tr("TUTORIAL_PHONE_CHECK")},
		{"speaker": "Ms. Reyes", "text": tr("TUTORIAL_TIMER_HINT")}]
	story_view.show_threat(threat, lines, 1, 1, tr("TUTORIAL_PRACTICE"))
	story_view.set_story_hp(training_hp)
	story_view.set_investigation(DecisionScenarios.investigation_config(threat))
	_update_hud()

func _decision_available() -> void:
	if phase != "Investigate" or decision_open:
		return
	evidence_complete = true
	decision_open = true
	phase = "Decision"
	var assist: String = str(SettingsService.timed_decision_assist)
	decision_duration = 45.0 * (1.75 if assist == "extended" else 1.0)
	decision_remaining = decision_duration
	deciding = assist != "off"
	story_view.set_decision_timer_visible(deciding)
	story_view.update_decision_timer(decision_remaining, decision_duration, tr("TUTORIAL_PRACTICE"))
	_update_hud()

func _process(delta: float) -> void:
	super._process(delta)
	if not deciding or paused or phase != "Decision":
		return
	decision_remaining = maxf(0.0, decision_remaining - delta)
	story_view.update_decision_timer(decision_remaining, decision_duration, tr("TUTORIAL_PRACTICE"))
	if decision_remaining <= 0.0:
		_resolve_training("CRITICAL", tr("TUTORIAL_TIMER_EXPIRED"))

func _choose_training_response(index: int) -> void:
	if phase != "Decision" or not decision_open or not evidence_complete:
		return
	var choices: Array = threat.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	if deciding and decision_remaining <= 0.0:
		_resolve_training("CRITICAL", tr("TUTORIAL_TIMER_EXPIRED"))
		return
	var choice: Dictionary = choices[index]
	_resolve_training(str(choice.outcome), str(choice.consequence))

func _resolve_training(outcome: String, explanation: String) -> void:
	if not decision_open or phase != "Decision":
		return
	deciding = false
	decision_open = false
	last_outcome = outcome
	phase = "Feedback"
	if outcome == "CRITICAL":
		training_hp = maxi(0, training_hp - 1)
	var hint: String = tr("TUTORIAL_SAFE_FEEDBACK")
	if outcome == "CRITICAL":
		hint = tr("TUTORIAL_FAILED_FEEDBACK")
	elif outcome == "RISKY":
		hint = tr("TUTORIAL_RISKY_FEEDBACK")
	story_view.show_consequence(outcome, explanation, hint, tr("TUTORIAL_PRACTICE"),
		tr("TUTORIAL_TRY_RESPONSE") if outcome == "CRITICAL" else tr("TUTORIAL_PRACTICE_DEFENSE"))
	story_view.set_story_hp(training_hp)

func _after_response() -> void:
	if phase != "Feedback":
		return
	if last_outcome == "CRITICAL":
		# No real-stage penalty. Keep evidence, allow another considered response.
		phase = "Investigate"
		var lines: Array[Dictionary] = [{"speaker": "Ms. Reyes", "text": tr("TUTORIAL_RETRY_CLUE")}]
		story_view.show_threat(threat, lines, 1, 1, tr("TUTORIAL_PRACTICE"))
		story_view.set_story_hp(training_hp)
		return
	story_view.hide()
	_set_phase("Build")
	hud.battle.enabled = true
	_refresh_build_guide()

func _capacity(kind: String) -> int:
	return 2 if kind == "base" else 0

func _access_reason(kind: String) -> String:
	return "" if kind == "base" else tr("TUTORIAL_BASIC_ONLY")

func place_tower() -> bool:
	var placed: bool = super.place_tower()
	if placed:
		_refresh_build_guide()
	return placed

func select_cell(cell: Vector2i) -> void:
	if coach != null:
		coach.hide() # Leave the tile picker and its confirmation unobstructed.
	super.select_cell(cell)

func cancel_selection() -> void:
	super.cancel_selection()
	if coach != null and phase == "Build":
		_refresh_build_guide()

func _refresh_build_guide() -> void:
	var count: int = _count("base")
	coach.setup_task(tr("TUTORIAL_DEFENSE_TITLE"), tr("TUTORIAL_TILE_HINT"), [
		{"text": tr("TUTORIAL_PLACE_ONE"), "done": count >= 1},
		{"text": tr("TUTORIAL_PLACE_TWO"), "done": count >= 2}])
	_update_hud()
	if count >= 2:
		coach.set_glow_rect(hud.start_button.get_global_rect())

func begin_defend() -> void:
	if phase != "Build" or _count("base") < 2:
		return
	coach.hide()
	super.begin_defend()
	hud.preview_label.text = tr("TUTORIAL_BASE_HINT")

func _update_hud() -> void:
	if hud == null:
		return
	super._update_hud()
	hud.set_story_layout(phase in ["Training", "Investigate", "Decision", "Feedback"])
	hud.status.text = tr("TUTORIAL_PRACTICE")
	hud.preview_label.text = tr("TUTORIAL_BASE_HINT") if phase == "Defend" else tr("TUTORIAL_NO_SCORE")
	hud.start_button.disabled = _count("base") < 2
	hud.start_button.text = tr("TUTORIAL_CHOICE_DEFEND")
	hud.pause_button.hide()
	hud.speed_button.visible = phase == "Defend"
	hud.battle.enabled = phase in ["Build", "Defend"]

func _finish(won: bool) -> void:
	if phase == "Results":
		return
	_set_phase("Results")
	coach.hide()
	hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED
	var actions: Array[Dictionary] = [{"text": tr("TUTORIAL_RETRY_DEFENSE"), "id": "training_retry"}]
	if won:
		actions = [{"text": tr("TUTORIAL_CHOICE_UPGRADE"), "id": "training_upgrades", "primary": true}]
	hud.show_modal(tr("TUTORIAL_DEFENSE_DONE") if won else tr("TUTORIAL_DEFENSE_RETRY_TITLE"),
		tr("TUTORIAL_DEFENSE_SUCCESS") if won else tr("TUTORIAL_DEFENSE_RETRY"), actions)

func _intent(id: String, value: Variant) -> void:
	if phase == "Build" and id in ["move", "upgrade"] and _count("base") < 2:
		_notice(tr("TUTORIAL_BUILD_FIRST"))
		return # Preserve enough practice gold to satisfy the placement gate.
	if id == "training_upgrades" and phase == "Results" and health > 0 and not lesson_handoff:
		lesson_handoff = true
		Router.open_tutorial_upgrades()
		return
	if id == "training_retry" and phase == "Results":
		Router.restart_level()
		return
	if id in ["exit", "retry", "pause"]:
		return
	super._intent(id, value)

func toggle_pause() -> void:
	pass # Tutorial has no pause modal or route around the required steps.
