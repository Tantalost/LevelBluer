extends "res://src/gameplay/preview/preview_match.gd"
## Production decision-story stage: existing decision state and persistence,
## approved geometric combat/UI. Content (title, dialogue, threats, breach HP
## scale) loads entirely from DecisionScenarios for whichever module_id/stage_id
## match_context carries — no stage is hardcoded here. The disposable preview
## never instantiates this class. Injectable account/task gateways let tests
## exercise writes without a real save.
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
## Optional per-threat countdown (see DecisionScenarios.has_timer). Most
## threats are untimed, so decision_timer_active stays false for the whole
## incident in the common case — see _decision_ready(). The fallback here
## only matters for a malformed/missing "seconds" value on an authored timer
## (DecisionScenarios.timer_seconds has the real default).
const DEFAULT_DECISION_SECONDS := 15.0
## ~1.75x an authored duration under the "extended" accessibility mode (see
## SettingsService.timed_decision_assist) — comfortably longer without being
## effectively unlimited.
const EXTENDED_TIMER_MULTIPLIER := 1.75
var decision_seconds_total := DEFAULT_DECISION_SECONDS
var decision_seconds_left := 0.0
var decision_timer_active := false
## Optional per-threat phone-call presentation (see DecisionScenarios.
## has_call). A separate clock from the decision countdown above — see
## advance_call_duration() — since call duration is purely presentational
## and counts up for as long as the call is connected, independent of
## whether (or when) a timed decision is also running.
var call_active := false
var call_duration_elapsed := 0.0
## Set from the checkpoint by _configure_match() when it holds a
## mid-countdown "timer_seconds_left" — consumed exactly once, by the next
## _decision_ready() activation, so a save/reload during an active timed
## choice resumes at the time it actually had left instead of a fresh full
## duration (the exploit this guards against: reload-for-a-new-clock).
## -1.0 means "no restored remaining time", i.e. start at full duration.
var _restored_timer_seconds_left := -1.0
## Throttle for persisting decision_seconds_left mid-countdown (see
## advance_decision_timer()): account.set_decision_stage_state() triggers a
## real disk write + cloud sync attempt every call, so this saves at most
## once per whole second of countdown, never every frame.
var _timer_last_saved_whole_second := -1

func _valid_context() -> bool:
	return match_context != null and not match_context.preview and match_context.persistent \
		and match_context.geometric and match_context.footprint == 1 \
		and DecisionScenarios.is_decision_stage(match_context.module_id, match_context.stage_id)

func _configure_match() -> void:
	if account == null:
		account = PlayerManager
	if tasks == null:
		tasks = TaskManager
	config = StageManager.get_stage_config(match_context.stage_id).duplicate(true)
	story = DecisionScenarios.get_stage(match_context.module_id, match_context.stage_id)
	config["name"] = str(story.get("title", config.get("name", "Stage %d" % match_context.stage_id)))
	gold = account.consume_intel_bonus_gold(int(config.get("starting_gold", 2)), match_context.module_id)
	mastery_frozen = account.has_cleared_stage(match_context.module_id, match_context.stage_id)
	decision = DecisionStageController.new()
	decision.setup(match_context.module_id, match_context.stage_id, DecisionScenarios.get_threats(match_context.module_id, match_context.stage_id), DecisionScenarios.has_finale(story))
	var checkpoint: Dictionary = account.get_decision_stage_state(_key())
	decision.restore(checkpoint)
	var reviewed_index := int(checkpoint.get("reviewed_breach_index", -1))
	if reviewed_index == decision.threat_index:
		reviewed_breach_index = reviewed_index
	# Only trusted immediately after a genuine restore, for THIS resumed
	# threat's very next timer activation — _decision_ready() consumes and
	# clears it the first time it runs, so it can never leak into a later,
	# genuinely fresh incident or retry.
	if checkpoint.has("timer_seconds_left") and decision.flow_state == DecisionStageController.FLOW_THREAT:
		_restored_timer_seconds_left = maxf(0.0, float(checkpoint.get("timer_seconds_left", -1.0)))
	if decision.is_breach_active():
		reviewed_breach_index = decision.threat_index
		# Preserve resolved incidents and security, but reopen this incident's
		# dialogue/evidence/choices instead of jumping into the saved battle.
		var review := decision.checkpoint_state()
		review["flow_state"] = DecisionStageController.FLOW_THREAT
		review["in_breach"] = false
		decision.restore(review)
	elif decision.is_finale_active():
		# Same idea for the stage-level finale: reopen its DEPLOY prompt
		# instead of resuming mid-battle. Never replays Incident 3.
		var review_finale := decision.checkpoint_state()
		review_finale["flow_state"] = DecisionStageController.FLOW_ENDING
		decision.restore(review_finale)

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
	story_overlay.end_call_requested.connect(_end_call_requested)

func _process(delta: float) -> void:
	super._process(delta)
	advance_decision_timer(delta)
	advance_call_duration(delta)

## Reads SettingsService.timed_decision_assist defensively — an invalid or
## unrecognized stored value behaves as "normal", never as "off" (a typo/
## corrupt setting must not silently disable urgency system-wide, and must
## never silently block story progress either way).
func _timed_decision_assist() -> String:
	var mode: String = str(SettingsService.timed_decision_assist).strip_edges().to_lower()
	return mode if SettingsService.TIMED_DECISION_ASSIST_MODES.has(mode) else "normal"

## Starts the countdown ONLY when the current threat authored an enabled
## timer (see DecisionScenarios.has_timer) — most threats have none, and for
## those decision_timer_active simply never becomes true for the whole
## incident, which is what keeps every existing untimed decision working
## exactly as before. "off" accessibility mode behaves the same as an
## unauthored timer: no automatic timeout, choices stay manually selectable.
func _decision_ready() -> void:
	if phase != "Incident" or story_overlay._mode != &"threat" or decision_timer_active:
		return
	var threat: Dictionary = decision.current_threat()
	var assist: String = _timed_decision_assist()
	# Consumed here regardless of outcome, so a restored value can never leak
	# into a later activation (an "off" threat, an untimed threat, or a
	# genuinely fresh incident reached right after this one).
	var restored_seconds_left: float = _restored_timer_seconds_left
	_restored_timer_seconds_left = -1.0
	if not DecisionScenarios.has_timer(threat) or assist == "off":
		story_overlay.set_decision_timer_visible(false)
		return
	var authored_seconds: float = DecisionScenarios.timer_seconds(threat, DEFAULT_DECISION_SECONDS)
	decision_seconds_total = authored_seconds * (EXTENDED_TIMER_MULTIPLIER if assist == "extended" else 1.0)
	# A save/reload mid-countdown resumes at the time it actually had left
	# (clamped to this activation's own total, in case assist mode changed
	# in between) — never a fresh full duration. See _restored_timer_seconds_left.
	decision_seconds_left = clampf(restored_seconds_left, 0.0, decision_seconds_total) if restored_seconds_left >= 0.0 else decision_seconds_total
	decision_timer_active = true
	_timer_last_saved_whole_second = ceili(decision_seconds_left)
	story_overlay.set_decision_timer_visible(true)
	story_overlay.update_decision_timer(decision_seconds_left, decision_seconds_total, DecisionScenarios.timer_label(threat))
	_save_checkpoint()

func advance_decision_timer(delta: float) -> void:
	if not decision_timer_active or paused or phase != "Incident" or story_overlay._review_open:
		return
	decision_seconds_left = maxf(0, decision_seconds_left - maxf(0, delta))
	story_overlay.update_decision_timer(decision_seconds_left, decision_seconds_total, DecisionScenarios.timer_label(decision.current_threat()))
	# Persist remaining time at most once per whole second of countdown, not
	# every frame — a reload can only ever hand back at most ~1 second of
	# slack, never a reset to the full authored duration.
	var whole_second := ceili(decision_seconds_left)
	if whole_second != _timer_last_saved_whole_second:
		_timer_last_saved_whole_second = whole_second
		_save_checkpoint()
	if decision_seconds_left <= 0:
		_expire_decision()

## A timeout is itself a committed decision (see DecisionStageController.
## choose_by_outcome): it resolves the threat's AUTHORED timeout_outcome —
## always the same original choice regardless of the shuffled display order
## — grades BKT exactly once via the existing _commit_decision(), then shows
## the authored (or a generic) consequence through the same show_consequence
## screen a manual choice uses, before continuing through the unchanged
## SAFE/RISKY/CRITICAL flow in _consequence_continued().
func _expire_decision() -> void:
	if not decision_timer_active or paused or story_overlay._review_open:
		return
	decision_timer_active = false
	var threat: Dictionary = decision.current_threat()
	var outcome: String = DecisionScenarios.timer_timeout_outcome(threat)
	if decision.choose_by_outcome(outcome).is_empty():
		return
	var result: Dictionary = _commit_decision()
	if result.is_empty():
		return
	var banner: String = "TIME EXPIRED"
	var continue_text: String = "CONTINUE"
	match outcome:
		DecisionScenarios.OUTCOME_RISKY:
			banner = "TIME EXPIRED / BREACH DETECTED"
			continue_text = "DEPLOY DEFENSES"
		DecisionScenarios.OUTCOME_CRITICAL:
			banner = "TIME EXPIRED / SYSTEM COMPROMISED"
			continue_text = "DAMAGE REPORT"
	story_overlay.show_consequence(outcome,
		"No response was made in time on %s." % _affected_system(),
		str(result.threat.get("explanation", "")),
		_header(), continue_text, banner,
		DecisionScenarios.timer_timeout_story_event_lines(threat, _memory()))

## Shows/hides and (re)configures the call presentation for whatever threat
## is about to be shown — called unconditionally from _show_threat() so a
## call from one incident can never bleed into the next (an empty dict from
## DecisionScenarios.call_config() when the threat has none simply hides the
## row, exactly like set_decision_timer_visible(false)).
func _configure_call(threat: Dictionary) -> void:
	call_active = DecisionScenarios.has_call(threat)
	call_duration_elapsed = 0.0
	story_overlay.set_call(DecisionScenarios.call_config(threat) if call_active else {})

## Call duration is presentation only, on its own clock, separate from
## decision_seconds_left — it counts up for as long as the call is
## connected, whether or not a timed decision is also currently running (see
## DecisionScenarios.call_show_duration). Frozen consistently with the same
## conditions that already freeze the decision timer (paused/phase/dialogue
## review), never persisted — a call always resumes at 00:00 on reload,
## exactly like re-reading the incident's own dialogue already does.
func advance_call_duration(delta: float) -> void:
	if not call_active or paused or phase != "Incident" or story_overlay._review_open:
		return
	call_duration_elapsed += maxf(0.0, delta)
	story_overlay.update_call_duration(call_duration_elapsed)

## Ending a call and deciding what to do next are separate concepts: this
## never grades BKT, never selects a choice, and never bypasses the
## decision — it only stops the call's own clock/status and, if authored,
## plays a short narrative beat through the existing dialogue reader before
## the player is exactly where they already were (still mid-dialogue, or
## already choosing). Only reachable at all when the current threat's call
## explicitly authored allow_end_call — most calls (including the Module 3
## Stage 1 demo) leave it disabled and are otherwise unaffected.
func _end_call_requested() -> void:
	if not call_active or paused or phase != "Incident":
		return
	var threat: Dictionary = decision.current_threat()
	if not DecisionScenarios.call_allow_end(threat):
		return
	call_active = false
	story_overlay.end_call(DecisionScenarios.call_end_story_event_lines(threat, _memory()))

func advance_briefing(delta: float) -> void:
	if phase != "Briefing" or paused:
		return
	intro_elapsed = minf(4, intro_elapsed + delta)
	hud.show_intro(str(config.name), intro_elapsed)
	if intro_elapsed < 4:
		return
	hud.hide_intro()
	if decision.all_threats_resolved():
		# _configure_match() already reopens a mid-finale checkpoint as the
		# finale's own DEPLOY prompt (see its is_finale_active() branch), the
		# same way it reopens a mid-breach checkpoint as the incident screen.
		_show_ending_or_finale()
	elif account.get_decision_stage_state(_key()).is_empty():
		_show_story("opening", _show_threat)
	else:
		_show_threat()

## The stage's authored "ending" beat is shared by two outcomes, decided
## purely from data (DecisionScenarios.has_finale): a plain stage finishes
## right after it, while a stage with an enabled finale uses the same beat to
## introduce the FINAL CONTAINMENT encounter instead.
func _finale_deploy_label() -> String:
	var finale: Dictionary = story.get("finale", {}) as Dictionary
	return str(finale.get("deploy_label", "DEPLOY FINAL DEFENSES"))

func _show_ending_or_finale() -> void:
	if decision.finale_pending():
		_show_story("ending", _begin_finale, _finale_deploy_label())
	else:
		_show_story("ending", _finish_investigation, "FILE REPORT")

func _update_hud() -> void:
	super._update_hud()
	if decision != null:
		hud.status.text = "STAGE %02d / INCIDENT %d/%d" % [match_context.stage_id, decision.current_threat_number(), decision.total_threats()]

func _capacity(kind: String) -> int:
	return account.tower_capacity(kind)

func _access_reason(kind: String) -> String:
	return "" if account.is_tower_unlocked(kind) else "Unlock this tower in Upgrades before deploying it."

func _research_bonus(kind: String) -> Dictionary:
	return account.stats_bonus_for(kind) if kind == "base" else {}

func _enemy_health_scale() -> float:
	if decision.is_finale_active():
		return DecisionScenarios.finale_hp_multiplier(story, 1.0)
	return DecisionScenarios.breach_hp_multiplier(story, LevelManager.DECISION_BREACH_ENEMY_HP_MULTIPLIER)

func _key() -> String:
	return DecisionScenarios.stage_key(match_context.module_id, match_context.stage_id)

func _save_checkpoint() -> void:
	var checkpoint := decision.checkpoint_state()
	if reviewed_breach_index == decision.threat_index:
		checkpoint["reviewed_breach_index"] = reviewed_breach_index
	# Only ever present while a timed decision is actually counting down (see
	# advance_decision_timer()/_decision_ready()) — every other checkpoint
	# write (an untimed threat, a resolved/committed one) simply omits it, so
	# _configure_match() only ever restores a mid-countdown value for a
	# threat that genuinely still has one waiting.
	if decision_timer_active:
		checkpoint["timer_seconds_left"] = decision_seconds_left
	account.set_decision_stage_state(_key(), checkpoint)

func _header() -> String:
	return str(story.get("company", "BlueTech Solutions")).to_upper() + " // SECURITY DESK"

## Read-only snapshot for reactive dialogue's condition checks (see
## DecisionScenarios.condition_met). Re-read fresh at every dialogue/
## story_event call site rather than cached, so a memory committed mid-scene
## (e.g. a RISKY TD win) is visible to whatever's shown right after it.
func _memory() -> Dictionary:
	return account.get_story_memory_snapshot()

func _present_story() -> void:
	decision_timer_active = false
	_set_phase("Incident")
	Engine.time_scale = 1.0
	hud.battle.enabled = false
	hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED
	story_overlay.show()

func _show_story(key: String, next: Callable, caption: String = "CONTINUE") -> void:
	var lines := DecisionScenarios.dialogue_lines(story, key, _memory())
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
	if decision.all_threats_resolved():
		_show_ending_or_finale()
		return
	decision.capture_retry_checkpoint()
	# current_threat_for_display() lazily generates this attempt's randomized
	# order (see DecisionStageController.ensure_display_order) — resolve it
	# BEFORE saving the checkpoint, so a save/reload before any choice is
	# made still resumes the exact order the player is looking at, instead
	# of the checkpoint capturing an as-yet-ungenerated (empty) order.
	var display_threat: Dictionary = decision.current_threat_for_display()
	_save_checkpoint()
	_present_story()
	var threat_lines: Array[Dictionary] = DecisionScenarios.dialogue_lines(decision.current_threat(), "story", _memory())
	story_overlay.show_threat(display_threat, threat_lines, decision.current_threat_number(), decision.total_threats(), _header())
	_configure_call(decision.current_threat())
	# An authored investigation (see DecisionScenarios.has_investigation)
	# holds decision_ready — and with it the decision timer — until it
	# resolves; see decision_workspace.gd's _open_decision()/
	# _on_investigation_resolved(). Most threats have none, so this is a
	# no-op exactly like set_decision_timer_visible(false)/set_call({}).
	var threat: Dictionary = decision.current_threat()
	var has_investigation: bool = DecisionScenarios.has_investigation(threat)
	var investigation_followup: Array[Dictionary] = []
	if has_investigation:
		investigation_followup = DecisionScenarios.investigation_resolved_story_event_lines(threat, _memory())
	story_overlay.set_investigation(DecisionScenarios.investigation_config(threat) if has_investigation else {}, investigation_followup)

func _choice_selected(index: int) -> void:
	if paused or phase != "Incident" or story_overlay._mode != &"threat" or story_overlay._review_open:
		return
	# A manual click is always accepted here, whether or not this threat has
	# a timer — decision_timer_active is false for the whole incident on any
	# untimed threat (the overwhelming default), so gating on it would have
	# blocked every ordinary decision the moment timers became opt-in. The
	# only thing that still matters is a genuine race: a TIMED threat whose
	# clock already hit zero defers to the timeout instead of this stale click.
	if decision_timer_active and decision_seconds_left <= 0:
		_expire_decision()
		return
	var result := decision.choose(index)
	if result.is_empty():
		return
	decision_timer_active = false
	story_overlay.show_consequence(str(result.outcome), str(result.choice.get("consequence", "")), str(result.threat.get("explanation", "")), _header(), "DAMAGE REPORT" if result.outcome == DecisionScenarios.OUTCOME_CRITICAL else "CONTINUE", "", DecisionScenarios.story_event_lines(result.choice as Dictionary, _memory()))

func _commit_decision() -> Dictionary:
	var result := decision.commit()
	if result.is_empty():
		return result
	# Capture the committed threat's skill, not the next threat after SAFE advances.
	var skill := str(result.threat.get("bkt_skill", story.get("bkt_skill", "phishing")))
	if not mastery_frozen and int(result.threat_index) != reviewed_breach_index:
		account.update_mastery(skill, bool(result.bkt_correct))
	# Story memory follows the SAME "canonical resolution" rule as BKT just
	# above: SAFE resolves the incident right here, so its memory commits
	# now. RISKY only reaches a canonical resolution once its breach is
	# actually won (see _wave_cleared()/DecisionStageController.
	# contain_breach()) — commit() has already stashed it in
	# pending_breach_memory for that moment. CRITICAL never resolves the
	# incident at all (Game Over rewinds it), so its memory is never written.
	if str(result.outcome) == DecisionScenarios.OUTCOME_SAFE:
		var memory: Dictionary = result.get("memory", {}) as Dictionary
		if not memory.is_empty():
			account.set_story_memories(memory)
	_save_checkpoint()
	return result

func _consequence_continued() -> void:
	if paused or phase != "Incident" or story_overlay._mode != &"consequence":
		return
	if decision.awaiting_breach_deploy():
		_begin_breach()
		return
	if decision.pending_committed:
		# A timeout already resolved and graded this decision the instant it
		# expired (see _expire_decision()) — RISKY's own committed state is
		# caught by awaiting_breach_deploy() just above, so only SAFE/
		# CRITICAL ever reach here. This continue press only moves on to
		# whatever that already-locked-in outcome leads to next; it must
		# never call commit()/grade BKT again.
		if decision.last_outcome == DecisionScenarios.OUTCOME_CRITICAL:
			_finish(false)
		else:
			_show_threat()
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
	var budget := int(decision.current_threat().get("breach_gold", 0))
	_reset_combat_runtime(budget)

## Starts the stage-level FINAL CONTAINMENT encounter (see
## DecisionScenarios.has_finale). Mirrors _begin_breach() exactly, except its
## gold budget comes from the stage's "finale" config instead of a threat.
func _begin_finale() -> void:
	if paused or phase not in ["Incident", "Briefing"]:
		return
	decision.begin_finale()
	if not decision.is_finale_active():
		return
	var finale: Dictionary = story.get("finale", {}) as Dictionary
	var budget := int(finale.get("gold", 0))
	_reset_combat_runtime(budget)
	_save_checkpoint()

## Encounter-runtime reset shared by every decision-stage Tower Defense
## encounter — a RISKY breach or the stage-level finale. Each retains the
## authored fresh-encounter rule: no previous towers, bolts, enemies, lag,
## gold or damage carry into the next incident.
func _reset_combat_runtime(budget: int) -> void:
	cancel_selection()
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
	if not decision.is_breach_active() and not decision.is_finale_active():
		return
	super.begin_defend()
	# Decision encounters measure the authored choice; no unrelated incident BKT.
	incident_due = false

func _wave_cleared() -> void:
	if decision.is_finale_active() and phase == "Defend":
		_finale_cleared()
		return
	if not decision.is_breach_active() or phase != "Defend":
		return
	waves_completed += 1
	var system := _affected_system()
	# The RISKY choice's incident has just canonically resolved (contained,
	# not abandoned) — this is the one moment its pending story memory (see
	# DecisionStageController.pending_breach_memory) is actually written.
	var memory: Dictionary = decision.contain_breach()
	if not memory.is_empty():
		account.set_story_memories(memory)
	_save_checkpoint()
	_present_story()
	story_next = _show_threat
	var lines: Array[Dictionary] = [{"speaker": "", "text": "The threat on %s was isolated before reaching critical systems." % system}]
	story_overlay.show_story(lines, _header(), "CONTINUE INVESTIGATION", "BREACH CONTAINED")

## Tower Defense win for the stage-level finale. Never touches BKT. Chains
## three purely data-driven story beats (victory, case summary, closing)
## before the stage is finally allowed to finish.
func _finale_cleared() -> void:
	waves_completed += 1
	decision.win_finale()
	_save_checkpoint()
	_present_story()
	var finale: Dictionary = story.get("finale", {}) as Dictionary
	var banner: String = str(finale.get("victory_banner", "CONTAINMENT COMPLETE"))
	var lines: Array[Dictionary] = DecisionScenarios.finale_dialogue_lines(story, "ending")
	if lines.is_empty():
		_show_case_summary()
		return
	story_next = _show_case_summary
	story_overlay.show_story(lines, _header(), "CONTINUE", banner)

func _show_case_summary() -> void:
	var finale: Dictionary = story.get("finale", {}) as Dictionary
	var summary: Dictionary = finale.get("case_summary", {}) as Dictionary
	var title: String = str(summary.get("title", "")).strip_edges()
	var lines: Array[Dictionary] = []
	var subtitle: String = str(summary.get("subtitle", "")).strip_edges()
	if not subtitle.is_empty():
		lines.append({"speaker": "", "text": subtitle})
	var items: Array = summary.get("items", []) as Array
	for i in items.size():
		var item_text: String = str(items[i]).strip_edges()
		if not item_text.is_empty():
			lines.append({"speaker": "", "text": "> " + item_text})
	if title.is_empty() or lines.is_empty():
		_show_finale_closing()
		return
	_present_story()
	story_next = _show_finale_closing
	story_overlay.show_story(lines, _header(), "CONTINUE", title)

func _show_finale_closing() -> void:
	var finale: Dictionary = story.get("finale", {}) as Dictionary
	var banner: String = str(finale.get("complete_banner", ""))
	var lines: Array[Dictionary] = DecisionScenarios.finale_dialogue_lines(story, "closing")
	if lines.is_empty():
		_finish_investigation()
		return
	_present_story()
	story_next = _finish_investigation
	story_overlay.show_story(lines, _header(), "FILE REPORT", banner)

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
	var stage_id: int = match_context.stage_id
	var data := {"live": true, "won": won, "stage": stage_id, "wave": 1, "waves": config.waves.size(), "credits": 0, "kills": match_kills, "final_stage": false}
	if won:
		account.mark_stage_cleared(match_context.module_id, stage_id)
		account.clear_decision_stage_state(_key())
		tasks.record_stage_cleared()
		var payout := 50 + maxi(0, gold)
		account.add_credits(payout)
		data.merge({"credits": payout, "title": str(story.get("clear_title", "STAGE CLEARED")),
			"subtitle": "MAP A%d / " % stage_id + str(story.get("clear_subtitle", "DEFENSE SECURED")),
			"kills": decision.resolved_threats, "kills_label": "THREATS RESOLVED",
			"accuracy": float(decision.safe_count) / maxf(1, decision.total_threats()),
			"advisory": "NEXT: " + str(story.get("next_stage_title", "STAGE %d" % (stage_id + 1))).to_upper()}, true)
	else:
		var was_finale := decision.is_finale_active()
		if was_finale:
			decision.fail_finale()
		elif decision.is_breach_active():
			decision.fail_breach()
		_save_checkpoint()
		var critical := decision.last_failure_critical
		if was_finale:
			var finale: Dictionary = story.get("finale", {}) as Dictionary
			var system_name: String = str(finale.get("affected_system", "")).strip_edges()
			data.merge({"is_decision": true, "retry_label": "RETRY", "exit_label": "EXIT MISSION",
				"title": str(finale.get("failure_title", "CONTAINMENT FAILED")),
				"subtitle": system_name.to_upper() if not system_name.is_empty() else "FINAL CONTAINMENT",
				"body": "Malicious processes were still active when containment failed. Deploy final defenses again and stop them before they spread.",
				"tip": decision.game_over_tip()}, true)
		else:
			data.merge({"is_decision": true, "retry_label": "RETRY", "exit_label": "EXIT MISSION",
				"title": "SYSTEM COMPROMISED" if critical else "CONTAINMENT FAILED",
				"subtitle": "MAP A%d / " % stage_id + ("CRITICAL DECISION" if critical else "SYSTEM BREACH"),
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
