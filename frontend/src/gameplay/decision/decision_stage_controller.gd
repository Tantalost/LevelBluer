class_name DecisionStageController
extends RefCounted
## Pure state for a decision-based stage. No scene access, no saves, no BKT:
## LevelManager owns those side effects so this can be unit-tested headless.

const STATE_NOMINAL := "NOMINAL"
const STATE_ELEVATED := "ELEVATED"
const STATE_COMPROMISED := "COMPROMISED"

const FLOW_THREAT := "THREAT"
const FLOW_BREACH := "BREACH"
const FLOW_ENDING := "ENDING"
## Active only for a stage-level FINAL CONTAINMENT encounter (see has_finale):
## a mandatory Tower Defense wave after every threat is resolved, before the
## stage can actually finish. Parallels FLOW_BREACH but is never entered by a
## decision outcome — only by begin_finale() once all threats are resolved.
const FLOW_FINALE := "FINALE"

var module_id: String = ""
var stage_id: int = 0
var threats: Array[Dictionary] = []
var threat_index: int = 0
var resolved_threats: int = 0
var stage_failed: bool = false
var in_breach: bool = false
var security_state: String = STATE_NOMINAL
var last_outcome: String = ""
var safe_count: int = 0
var flow_state: String = FLOW_THREAT
var last_failure_critical: bool = false
var fail_tip: String = ""
## Whether this stage has an authored, data-driven FINAL CONTAINMENT encounter
## (see DecisionScenarios.has_finale). Set once in setup(); stages without one
## behave exactly as before this capability existed.
var has_finale: bool = false
## True once the finale's Tower Defense encounter has been won. Persisted, so
## a save/resume never replays it.
var finale_won: bool = false
var last_failure_finale: bool = false
var pending_choice_index: int = -1
var pending_outcome: String = ""
var pending_choice: Dictionary = {}
var pending_committed: bool = false
## A committed RISKY choice's authored story memory (see DecisionScenarios.
## choice_memory), held here rather than written immediately: the incident
## hasn't canonically resolved yet, only reached the breach — see
## contain_breach()/fail_breach(). Persisted through checkpoint_state()/
## restore() so a save/reload mid-breach still commits the right memory on a
## later TD win, and discarded outright on a TD loss/retry — an abandoned
## RISKY attempt must never be remembered. Never set for SAFE (which commits
## its own memory immediately at the caller's canonical-resolution point) or
## CRITICAL (which never resolves the incident at all).
var pending_breach_memory: Dictionary = {}
var retry_checkpoint: Dictionary = {}
## This attempt's choice presentation order, as original decision_scenarios
## indices (display_order[shown_slot] == original_choice_index). Generated
## once per attempt (see ensure_display_order()) so the same incident never
## reshuffles while it's on screen; cleared whenever an attempt ends, so the
## next one (a new threat, or a retry after failure) gets a fresh shuffle.
var display_order: Array[int] = []


func setup(p_module_id: String, p_stage_id: int, p_threats: Array[Dictionary], p_has_finale: bool = false) -> void:
	module_id = p_module_id.strip_edges()
	stage_id = p_stage_id
	threats = p_threats.duplicate(true)
	has_finale = p_has_finale
	reset_progress()


func reset_progress() -> void:
	threat_index = 0
	resolved_threats = 0
	stage_failed = false
	in_breach = false
	security_state = STATE_NOMINAL
	last_outcome = ""
	safe_count = 0
	flow_state = FLOW_THREAT
	last_failure_critical = false
	last_failure_finale = false
	fail_tip = ""
	finale_won = false
	_clear_pending()
	pending_breach_memory.clear()
	display_order.clear()
	capture_retry_checkpoint()


func total_threats() -> int:
	return threats.size()


## True once every threat is resolved AND, for a stage with a finale, the
## finale encounter has also been won. This is the single gate LevelManager
## and the live scene check before they're allowed to actually finish the
## stage (change_phase(VICTORY) / _finish(true)).
func is_complete() -> bool:
	if not all_threats_resolved():
		return false
	return not has_finale or finale_won


## True once every authored threat has been resolved, independent of whether
## a finale still needs to be played. Distinguishes "the story is done" from
## "the stage is actually over" now that a finale can sit between the two.
func all_threats_resolved() -> bool:
	return total_threats() > 0 and (flow_state == FLOW_ENDING or flow_state == FLOW_FINALE or resolved_threats >= total_threats())


## True exactly when all threats are resolved, this stage has a finale, and
## that finale has neither been won nor is currently in progress — i.e. the
## moment the player should be shown the finale's intro and DEPLOY button.
func finale_pending() -> bool:
	return has_finale and not finale_won and flow_state == FLOW_ENDING and all_threats_resolved()


func is_finale_active() -> bool:
	return flow_state == FLOW_FINALE


## Starts the finale's Tower Defense encounter. Only valid once every threat
## is resolved and the finale hasn't already been won.
func begin_finale() -> void:
	if not finale_pending():
		return
	flow_state = FLOW_FINALE


## Tower Defense win for the finale encounter. Never touches BKT — callers
## must not record a mastery update for this transition.
func win_finale() -> void:
	if flow_state != FLOW_FINALE:
		return
	finale_won = true
	flow_state = FLOW_ENDING


## Tower Defense loss for the finale encounter. Reverts to the pre-finale
## beat so retry replays the finale's DEPLOY prompt, never Incident 3 and
## never another BKT update.
func fail_finale() -> void:
	if flow_state != FLOW_FINALE:
		return
	flow_state = FLOW_ENDING
	last_failure_finale = true
	_clear_pending()
	display_order.clear()


func has_current_threat() -> bool:
	return flow_state == FLOW_THREAT and not stage_failed and threat_index >= 0 and threat_index < total_threats()


func current_threat() -> Dictionary:
	if flow_state == FLOW_ENDING:
		return {}
	if threat_index < 0 or threat_index >= threats.size():
		return {}
	return threats[threat_index]


func current_threat_number() -> int:
	if flow_state == FLOW_ENDING or flow_state == FLOW_FINALE:
		return total_threats()
	return threat_index + 1


## Generates this attempt's display order the first time it's needed, and
## leaves it untouched on every later call for the same attempt (idempotent:
## it only (re)shuffles when the stored order is empty or no longer matches
## the current threat's choice count).
func ensure_display_order(choice_count: int) -> void:
	if choice_count <= 0:
		display_order.clear()
		return
	if display_order.size() == choice_count:
		var still_valid: bool = true
		for original_index in display_order:
			if original_index < 0 or original_index >= choice_count:
				still_valid = false
				break
		if still_valid:
			return
	display_order.clear()
	for i in choice_count:
		display_order.append(i)
	display_order.shuffle()


## Same as current_threat(), but with "choices" reordered into this attempt's
## randomized display order. Presentation layers (DecisionOverlay,
## decision_workspace) must build their choice buttons from THIS, not from
## current_threat() directly — choose() expects the index of a choice as
## shown here, not its original decision_scenarios.json position.
func current_threat_for_display() -> Dictionary:
	var threat: Dictionary = current_threat()
	var choices: Array = threat.get("choices", []) as Array
	if threat.is_empty() or choices.is_empty():
		return threat
	ensure_display_order(choices.size())
	var reordered: Array = []
	for original_index in display_order:
		reordered.append(choices[original_index])
	var display_threat: Dictionary = threat.duplicate(true)
	display_threat["choices"] = reordered
	return display_threat


## Stores the player's choice for the consequence screen. Does not commit BKT,
## security, or progress — that happens once in commit(). choice_index is the
## DISPLAYED slot (see current_threat_for_display()), never the original
## decision_scenarios.json position; it is mapped back via display_order so
## the outcome always travels with the choice the player actually saw.
func choose(choice_index: int) -> Dictionary:
	if stage_failed or flow_state != FLOW_THREAT or pending_committed:
		return {}
	var threat: Dictionary = current_threat()
	if threat.is_empty():
		return {}
	var choices: Array = threat.get("choices", []) as Array
	ensure_display_order(choices.size())
	if choice_index < 0 or choice_index >= display_order.size():
		return {}
	var original_index: int = display_order[choice_index]
	var outcome: String = DecisionScenarios.choice_outcome(threat, original_index)
	if outcome.is_empty():
		return {}
	var choice: Dictionary = (choices[original_index] as Dictionary).duplicate(true)
	pending_choice_index = original_index
	pending_outcome = outcome
	pending_choice = choice
	last_outcome = outcome
	return {
		"outcome": outcome,
		"choice": choice,
		"threat": threat.duplicate(true),
		"threat_index": threat_index,
		"committed": false,
	}


## Resolves a countdown timeout: stages the deterministically AUTHORED
## choice matching `outcome` — always the same original (pre-shuffle)
## choice for a given threat, regardless of which slot it currently
## displays in — exactly the same pending/commit path a manual choose()
## would use. Never a randomly/shuffle-dependent pick. Returns {} only if
## this threat has no choice with that outcome (a data-authoring error) or
## a choice is already pending/committed.
func choose_by_outcome(outcome: String) -> Dictionary:
	if stage_failed or flow_state != FLOW_THREAT or pending_committed:
		return {}
	var threat: Dictionary = current_threat()
	if threat.is_empty():
		return {}
	var choices: Array = threat.get("choices", []) as Array
	for original_index in choices.size():
		if DecisionScenarios.choice_outcome(threat, original_index) != outcome:
			continue
		var choice: Dictionary = (choices[original_index] as Dictionary).duplicate(true)
		pending_choice_index = original_index
		pending_outcome = outcome
		pending_choice = choice
		last_outcome = outcome
		return {
			"outcome": outcome,
			"choice": choice,
			"threat": threat.duplicate(true),
			"threat_index": threat_index,
			"committed": false,
		}
	return {}


## Commits the pending choice exactly once. SAFE/RISKY/CRITICAL side effects
## apply here; callers should then update BKT and persist the checkpoint.
func commit() -> Dictionary:
	if pending_committed or pending_outcome.is_empty():
		return {}
	pending_committed = true
	var outcome: String = pending_outcome
	var memory: Dictionary = DecisionScenarios.choice_memory(pending_choice)
	var record: Dictionary = {
		"outcome": outcome,
		"choice": pending_choice.duplicate(true),
		"threat": current_threat().duplicate(true),
		"threat_index": threat_index,
		"bkt_correct": outcome == DecisionScenarios.OUTCOME_SAFE,
		"committed": true,
		# Story memory this choice would write once the incident canonically
		# resolves — the caller applies this immediately for SAFE (resolved
		# right here) but must NOT apply it for RISKY (see
		# pending_breach_memory/contain_breach()) or CRITICAL (never resolves).
		"memory": memory,
	}
	match outcome:
		DecisionScenarios.OUTCOME_RISKY:
			in_breach = true
			flow_state = FLOW_BREACH
			pending_breach_memory = memory
		DecisionScenarios.OUTCOME_CRITICAL:
			in_breach = false
			stage_failed = true
			last_failure_critical = true
			fail_tip = str(pending_choice.get("consequence", ""))
			flow_state = FLOW_THREAT
			# A retry is a new attempt: it must not inherit this failed
			# attempt's display order from the persisted checkpoint.
			display_order.clear()
		_:
			in_breach = false
			safe_count += 1
			resolve_current()
	return record


## Marks the current threat handled and advances. SAFE calls this from commit();
## RISKY calls it after a Tower Defense win. Never clears the stage on its own:
## is_complete() turns true once every threat is resolved (flow_state ENDING).
func resolve_current() -> void:
	if stage_failed:
		return
	if threat_index >= total_threats():
		flow_state = FLOW_ENDING
		in_breach = false
		return
	resolved_threats += 1
	threat_index += 1
	in_breach = false
	_clear_pending()
	display_order.clear()
	if resolved_threats >= total_threats():
		flow_state = FLOW_ENDING
		threat_index = total_threats()
	else:
		flow_state = FLOW_THREAT
		capture_retry_checkpoint()


## Tower Defense win during a RISKY breach. Elevates security only after the
## containment succeeds, then advances. Returns the RISKY choice's pending
## story memory (see pending_breach_memory) for the caller to persist NOW —
## this is the incident's canonical resolution point for a RISKY attempt.
## Empty when the choice authored no memory, exactly like every choice
## before this system existed.
func contain_breach() -> Dictionary:
	if flow_state != FLOW_BREACH:
		return {}
	if security_state == STATE_NOMINAL:
		security_state = STATE_ELEVATED
	var memory: Dictionary = pending_breach_memory.duplicate(true)
	pending_breach_memory.clear()
	resolve_current()
	return memory


## Tower Defense loss during a RISKY breach. Failure flags are session-only;
## the persisted security state stays at the pre-attempt value. The pending
## RISKY choice's story memory is discarded outright — an abandoned attempt
## must never be remembered; only a retry's eventual canonical choice can
## commit memory for this incident.
func fail_breach() -> void:
	in_breach = false
	stage_failed = true
	last_failure_critical = false
	flow_state = FLOW_THREAT
	pending_breach_memory.clear()
	_clear_pending()
	# A retry is a new attempt: it must not inherit this failed attempt's
	# display order from the persisted checkpoint.
	display_order.clear()
	if not retry_checkpoint.is_empty():
		security_state = str(retry_checkpoint.get("security_state", security_state))


## True from a committed RISKY choice through TD win/loss. in_breach mirrors
## this by construction (see commit()/resolve_current()/fail_breach()/
## restore()); this query lets callers derive the same fact from flow_state
## instead of checking both.
func is_breach_active() -> bool:
	return flow_state == FLOW_BREACH


## True only between a committed RISKY choice and the player pressing DEPLOY
## DEFENSES on the breach-transition beat. Tower Defense has not started yet.
func awaiting_breach_deploy() -> bool:
	return flow_state == FLOW_BREACH and pending_committed


func capture_retry_checkpoint() -> Dictionary:
	retry_checkpoint = {
		"threat_index": threat_index,
		"resolved_threats": resolved_threats,
		"flow_state": FLOW_THREAT,
		"in_breach": false,
		"security_state": _persisted_security(),
		"safe_count": safe_count,
	}
	return retry_checkpoint.duplicate(true)


func restore_retry_checkpoint() -> bool:
	if retry_checkpoint.is_empty():
		return false
	var cp: Dictionary = retry_checkpoint.duplicate(true)
	var ok: bool = restore(cp)
	retry_checkpoint = cp
	return ok


func game_over_tip() -> String:
	if last_failure_finale:
		return "Malicious processes were still active when containment failed. Deploy final defenses again and stop them before they reach the remaining systems."
	if last_failure_critical:
		var tip: String = fail_tip.strip_edges()
		if tip.is_empty():
			tip = "A critical mistake gave the attacker access."
		return tip + " Retry the incident and choose the action that verifies first."
	return "The breach overwhelmed the defenses. Retry the incident and choose the action that contains the threat."


## Snapshot for the save system. Failure flags are not persisted: a retry
## restarts at the same threat with a clean attempt.
func checkpoint_state() -> Dictionary:
	return {
		"threat_index": threat_index if flow_state != FLOW_ENDING and flow_state != FLOW_FINALE else total_threats(),
		"resolved_threats": resolved_threats,
		"flow_state": flow_state,
		"in_breach": flow_state == FLOW_BREACH,
		"security_state": _persisted_security(),
		"safe_count": safe_count,
		"finale_won": finale_won,
		# Only ever non-empty while flow_state is BREACH (see commit()'s RISKY
		# branch/contain_breach()/fail_breach()) — lets a save/reload during a
		# pending RISKY breach still commit the right memory on a later TD
		# win, per the milestone's own "save during pending RISKY" rule.
		"pending_breach_memory": pending_breach_memory.duplicate(true),
		"retry_checkpoint": retry_checkpoint.duplicate(true),
		# Only ever non-empty while flow_state is THREAT and the attempt is
		# still unresolved (see resolve_current()/fail_breach()/commit()'s
		# CRITICAL branch, which all clear it once an attempt ends). Lets a
		# save/reload on the same live attempt keep the order the player was
		# already looking at, without carrying a failed attempt's order into
		# its retry.
		"display_order": display_order.duplicate(),
	}


## Restores an in-progress snapshot. Returns false only when there is genuinely
## no checkpoint (fresh stage). A Threat 1 retry (index 0) is a valid resume.
func restore(state: Dictionary) -> bool:
	if state.is_empty() or total_threats() == 0:
		return false
	var flow: String = str(state.get("flow_state", "")).strip_edges().to_upper()
	var idx: int = int(state.get("threat_index", 0))
	var resolved: int = int(state.get("resolved_threats", 0))
	var stored_breach: bool = bool(state.get("in_breach", false))
	finale_won = has_finale and bool(state.get("finale_won", false))
	if flow == FLOW_FINALE and not has_finale:
		flow = FLOW_ENDING
	if flow != FLOW_THREAT and flow != FLOW_BREACH and flow != FLOW_ENDING and flow != FLOW_FINALE:
		if resolved >= total_threats() or idx >= total_threats():
			flow = FLOW_ENDING
		elif stored_breach:
			flow = FLOW_BREACH
		else:
			flow = FLOW_THREAT
	safe_count = clampi(int(state.get("safe_count", 0)), 0, total_threats())
	security_state = _sanitize_security(str(state.get("security_state", STATE_NOMINAL)))
	if flow == FLOW_ENDING or flow == FLOW_FINALE:
		resolved_threats = total_threats()
		threat_index = total_threats()
		flow_state = flow
		in_breach = false
		safe_count = clampi(safe_count, 0, total_threats())
		display_order.clear()
		pending_breach_memory.clear()
		_prepare_retry()
		flow_state = flow
		return true
	idx = clampi(idx, 0, total_threats() - 1)
	resolved = clampi(resolved, 0, total_threats() - 1)
	if resolved != idx:
		idx = mini(idx, resolved)
		resolved = idx
	threat_index = idx
	resolved_threats = resolved
	flow_state = FLOW_BREACH if flow == FLOW_BREACH or stored_breach else FLOW_THREAT
	in_breach = flow_state == FLOW_BREACH
	safe_count = clampi(safe_count, 0, resolved)
	# Tied to the RESULTING flow_state, not blindly trusted from the incoming
	# dict — a breach reopened as a plain THREAT review (see
	# stage_one_live.gd's _configure_match()) is a fresh re-choice, so any
	# old pending memory correctly never survives into it.
	if flow_state == FLOW_BREACH and state.has("pending_breach_memory") and typeof(state["pending_breach_memory"]) == TYPE_DICTIONARY:
		pending_breach_memory = (state["pending_breach_memory"] as Dictionary).duplicate(true)
	else:
		pending_breach_memory.clear()
	if state.has("retry_checkpoint") and typeof(state["retry_checkpoint"]) == TYPE_DICTIONARY and not (state["retry_checkpoint"] as Dictionary).is_empty():
		retry_checkpoint = (state["retry_checkpoint"] as Dictionary).duplicate(true)
	else:
		capture_retry_checkpoint()
	_restore_display_order(state.get("display_order", []))
	_prepare_retry()
	return true


## Trusts a saved display order only if it is a genuine permutation of this
## threat's current choice indices (defends against a corrupted/edited save,
## a stale order from before an authoring change, or simply none present —
## e.g. a fresh attempt, or one that ended in failure and was cleared before
## saving). Anything else just clears it, so the next display shuffles fresh.
func _restore_display_order(stored: Variant) -> void:
	display_order.clear()
	if flow_state != FLOW_THREAT:
		return
	var choices: Array = current_threat().get("choices", []) as Array
	if choices.is_empty() or typeof(stored) != TYPE_ARRAY:
		return
	var stored_array: Array = stored as Array
	if stored_array.size() != choices.size():
		return
	var seen: Dictionary = {}
	var candidate: Array[int] = []
	for value in stored_array:
		var original_index: int = int(value)
		if original_index < 0 or original_index >= choices.size() or seen.has(original_index):
			return
		seen[original_index] = true
		candidate.append(original_index)
	display_order = candidate


func _prepare_retry() -> void:
	stage_failed = false
	last_outcome = ""
	last_failure_critical = false
	last_failure_finale = false
	fail_tip = ""
	_clear_pending()
	in_breach = flow_state == FLOW_BREACH
	if security_state == STATE_COMPROMISED:
		security_state = STATE_ELEVATED if resolved_threats > 0 and safe_count < resolved_threats else STATE_NOMINAL


func _clear_pending() -> void:
	pending_choice_index = -1
	pending_outcome = ""
	pending_choice = {}
	pending_committed = false


func _persisted_security() -> String:
	if security_state == STATE_COMPROMISED:
		return STATE_NOMINAL
	return security_state


func _sanitize_security(raw: String) -> String:
	var stored: String = raw.strip_edges().to_upper()
	if stored == STATE_ELEVATED:
		return STATE_ELEVATED
	return STATE_NOMINAL
