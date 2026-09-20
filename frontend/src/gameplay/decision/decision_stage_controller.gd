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
var pending_choice_index: int = -1
var pending_outcome: String = ""
var pending_choice: Dictionary = {}
var pending_committed: bool = false
var retry_checkpoint: Dictionary = {}


func setup(p_module_id: String, p_stage_id: int, p_threats: Array[Dictionary]) -> void:
	module_id = p_module_id.strip_edges()
	stage_id = p_stage_id
	threats = p_threats.duplicate(true)
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
	fail_tip = ""
	_clear_pending()
	capture_retry_checkpoint()


func total_threats() -> int:
	return threats.size()


func is_complete() -> bool:
	return total_threats() > 0 and (flow_state == FLOW_ENDING or resolved_threats >= total_threats())


func has_current_threat() -> bool:
	return flow_state == FLOW_THREAT and not stage_failed and threat_index >= 0 and threat_index < total_threats()


func current_threat() -> Dictionary:
	if flow_state == FLOW_ENDING:
		return {}
	if threat_index < 0 or threat_index >= threats.size():
		return {}
	return threats[threat_index]


func current_threat_number() -> int:
	if flow_state == FLOW_ENDING:
		return total_threats()
	return threat_index + 1


## Stores the player's choice for the consequence screen. Does not commit BKT,
## security, or progress — that happens once in commit().
func choose(choice_index: int) -> Dictionary:
	if stage_failed or flow_state != FLOW_THREAT or pending_committed:
		return {}
	var threat: Dictionary = current_threat()
	if threat.is_empty():
		return {}
	var outcome: String = DecisionScenarios.choice_outcome(threat, choice_index)
	if outcome.is_empty():
		return {}
	var choices: Array = threat.get("choices", []) as Array
	var choice: Dictionary = (choices[choice_index] as Dictionary).duplicate(true)
	pending_choice_index = choice_index
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


## Commits the pending choice exactly once. SAFE/RISKY/CRITICAL side effects
## apply here; callers should then update BKT and persist the checkpoint.
func commit() -> Dictionary:
	if pending_committed or pending_outcome.is_empty():
		return {}
	pending_committed = true
	var outcome: String = pending_outcome
	var record: Dictionary = {
		"outcome": outcome,
		"choice": pending_choice.duplicate(true),
		"threat": current_threat().duplicate(true),
		"threat_index": threat_index,
		"bkt_correct": outcome == DecisionScenarios.OUTCOME_SAFE,
		"committed": true,
	}
	match outcome:
		DecisionScenarios.OUTCOME_RISKY:
			in_breach = true
			flow_state = FLOW_BREACH
		DecisionScenarios.OUTCOME_CRITICAL:
			in_breach = false
			stage_failed = true
			last_failure_critical = true
			fail_tip = str(pending_choice.get("consequence", ""))
			flow_state = FLOW_THREAT
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
	if resolved_threats >= total_threats():
		flow_state = FLOW_ENDING
		threat_index = total_threats()
	else:
		flow_state = FLOW_THREAT
		capture_retry_checkpoint()


## Tower Defense win during a RISKY breach. Elevates security only after the
## containment succeeds, then advances.
func contain_breach() -> void:
	if flow_state != FLOW_BREACH:
		return
	if security_state == STATE_NOMINAL:
		security_state = STATE_ELEVATED
	resolve_current()


## Tower Defense loss during a RISKY breach. Failure flags are session-only;
## the persisted security state stays at the pre-attempt value.
func fail_breach() -> void:
	in_breach = false
	stage_failed = true
	last_failure_critical = false
	flow_state = FLOW_THREAT
	_clear_pending()
	if not retry_checkpoint.is_empty():
		security_state = str(retry_checkpoint.get("security_state", security_state))


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
		"threat_index": threat_index if flow_state != FLOW_ENDING else total_threats(),
		"resolved_threats": resolved_threats,
		"flow_state": flow_state,
		"in_breach": flow_state == FLOW_BREACH,
		"security_state": _persisted_security(),
		"safe_count": safe_count,
		"retry_checkpoint": retry_checkpoint.duplicate(true),
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
	if flow != FLOW_THREAT and flow != FLOW_BREACH and flow != FLOW_ENDING:
		if resolved >= total_threats() or idx >= total_threats():
			flow = FLOW_ENDING
		elif stored_breach:
			flow = FLOW_BREACH
		else:
			flow = FLOW_THREAT
	safe_count = clampi(int(state.get("safe_count", 0)), 0, total_threats())
	security_state = _sanitize_security(str(state.get("security_state", STATE_NOMINAL)))
	if flow == FLOW_ENDING:
		resolved_threats = total_threats()
		threat_index = total_threats()
		flow_state = FLOW_ENDING
		in_breach = false
		safe_count = clampi(safe_count, 0, total_threats())
		_prepare_retry()
		flow_state = FLOW_ENDING
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
	if state.has("retry_checkpoint") and typeof(state["retry_checkpoint"]) == TYPE_DICTIONARY and not (state["retry_checkpoint"] as Dictionary).is_empty():
		retry_checkpoint = (state["retry_checkpoint"] as Dictionary).duplicate(true)
	else:
		capture_retry_checkpoint()
	_prepare_retry()
	return true


func _prepare_retry() -> void:
	stage_failed = false
	last_outcome = ""
	last_failure_critical = false
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
