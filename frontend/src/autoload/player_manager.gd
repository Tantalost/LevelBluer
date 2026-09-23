extends Node
## Autoload singleton, registered as "PlayerManager".
## Lesson progress is persisted per signed-in participant.

const P_GUESS: float = 0.2
const P_SLIP: float = 0.1
const P_TRANSIT: float = 0.1
const DEFAULT_MASTERY: float = 0.10
const MIN_MASTERY: float = 0.01
const MAX_MASTERY: float = 0.99
const AT_RISK_MASTERY: float = 0.40
const PROFICIENT_MASTERY: float = 0.70
const ALL_MODULES_LESSON := "mod1_all"
const _OFFICIAL_SKILLS: PackedStringArray = [
	"phishing",
	"smishing",
	"vishing",
	"pretexting",
	"baiting",
]

var mastery_matrix: Dictionary = {
	"phishing": DEFAULT_MASTERY,
}
var unlocked_skills: Array[String] = []
## Both keyed by the canonical "module_id:stage_id" string (see
## stage_progress_key()) — e.g. "mod_01:1" and "mod_02:1" never collide.
## Never key either of these by raw stage number alone.
var locked_stages: Dictionary = {}
var cleared_stages: Dictionary = {}
var completed_lessons: Array[String] = []
var lesson_progress: Dictionary = {}
var purchased_items: Array[String] = []
var unlocked_towers: Array[String] = ["base"]
var tech_ranks: Dictionary = {}
var has_stateful_inspection: bool = false
## Per-module progression ceiling: max_stage_cleared_by_module["mod_01"] is
## the highest stage cleared in Module 1, independent of every other module.
## Absent means "no clears recorded yet" — see max_stage_cleared().
var max_stage_cleared_by_module: Dictionary = {}
var credits: int = 0
var module_1_complete: bool = false
var seen_module_intros: Array[String] = []
var tutorial_complete: bool = false
var has_intel_bonus: bool = false
var intel_bonus_module: String = ""
var _session_hydrated: bool = false
const TRACE_MODULE_IDS: PackedStringArray = ["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"]
var trace_seen_by_module: Dictionary = {}
var trace_missed_by_module: Dictionary = {}
## Resume checkpoints for decision-based stages, keyed "mod_01:1".
## Only in-progress stages are stored; a cleared stage erases its entry.
var decision_stage_state: Dictionary = {}
## Lightweight, permanent story memory for reactive dialogue (see
## DecisionScenarios.condition_met / choice_memory) — a flat, free-form
## key -> scalar (bool/String/int/float) dictionary, authored explicitly per
## choice, never auto-derived from SAFE/RISKY/CRITICAL. Deliberately separate
## from mastery_matrix/decision_stage_state/cleared_stages/credits: this is
## narrative continuity only, never BKT, mastery, stage progression, the
## Case Board, or TD balance. Keys are free-form authored strings (e.g.
## "mod03_s1_bank_verification"), not scoped by code to any one module or
## stage, so a later module/stage can read an earlier one's memory with no
## special wiring — see get_story_memory_snapshot().
var story_memory: Dictionary = {}


func has_skill(skill_id: String) -> bool:
	return unlocked_skills.has(skill_id)


func unlock_skill(skill_id: String) -> void:
	if skill_id.is_empty() or unlocked_skills.has(skill_id):
		return
	unlocked_skills.append(skill_id)
	SaveService.save_game()


func unlock_tower(tower_id: String) -> void:
	if tower_id.is_empty() or unlocked_towers.has(tower_id):
		return
	unlocked_towers.append(tower_id)
	SaveService.save_game()


func is_tower_unlocked(tower_id: String) -> bool:
	if tower_id.is_empty():
		return false
	return unlocked_towers.has(tower_id)


func tech_rank(tower_id: String, track_id: String) -> int:
	if tower_id.is_empty() or track_id.is_empty():
		return 0
	if not tech_ranks.has(tower_id):
		return 0
	var stored: Variant = tech_ranks[tower_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return 0
	var tracks: Dictionary = stored as Dictionary
	return maxi(0, int(tracks.get(track_id, 0)))


func tower_capacity(tower_id: String) -> int:
	var base_cap: int = ContentDB.default_capacity(tower_id)
	var ranks: int = tech_rank(tower_id, "capacity")
	# Rank 1 is the default allotment (Basic starts at 2). Later ranks add slots.
	var extra: int = maxi(0, ranks - 1)
	return maxi(0, base_cap + extra)


func stats_bonus_for(tower_id: String) -> Dictionary:
	return ContentDB.tech_stats_bonus(tower_id, tech_rank(tower_id, "stats"))


func grant_tutorial_capacity_rank() -> void:
	if tech_rank("base", "capacity") >= 1:
		return
	_set_tech_rank("base", "capacity", 1)
	SaveService.save_game()


func purchase_tech_rank(tower_id: String, track_id: String) -> bool:
	var next_rank: int = tech_rank(tower_id, track_id) + 1
	var max_rank: int = ContentDB.tech_max_rank(tower_id, track_id)
	if next_rank <= 0 or next_rank > max_rank:
		return false
	var cost: int = ContentDB.tech_rank_cost(tower_id, track_id, next_rank)
	if cost < 0:
		return false
	if not spend_credits(cost):
		return false
	_set_tech_rank(tower_id, track_id, next_rank)
	_apply_rank_effects(tower_id, track_id, next_rank)
	SaveService.save_game()
	return true


func _set_tech_rank(tower_id: String, track_id: String, rank: int) -> void:
	if tower_id.is_empty() or track_id.is_empty():
		return
	var tracks: Dictionary = {}
	if tech_ranks.has(tower_id) and typeof(tech_ranks[tower_id]) == TYPE_DICTIONARY:
		tracks = (tech_ranks[tower_id] as Dictionary).duplicate(true)
	tracks[track_id] = maxi(0, rank)
	tech_ranks[tower_id] = tracks


func _apply_rank_effects(tower_id: String, track_id: String, rank: int) -> void:
	var entry: Dictionary = ContentDB.tech_rank_entry(tower_id, track_id, rank)
	if entry.is_empty():
		return
	var flag: String = str(entry.get("flag", ""))
	if flag == "has_stateful_inspection":
		has_stateful_inspection = true
	var unlock_id: String = str(entry.get("unlock_tower", ""))
	if not unlock_id.is_empty():
		unlock_tower(unlock_id)


func _ready() -> void:
	AuthService.session_changed.connect(_on_session_changed)
	if AuthService.is_signed_in():
		_hydrate_signed_in_session()


func _on_session_changed(signed_in: bool) -> void:
	if not signed_in:
		_session_hydrated = false
		reset_to_defaults()
		return
	if _session_hydrated:
		return
	await _hydrate_signed_in_session()


func _hydrate_signed_in_session() -> void:
	reset_to_defaults()
	SaveService.load_game()
	_session_hydrated = true
	SaveService.fetch_cloud_save()


func get_lesson_progress(module_id: String) -> int:
	if module_id.is_empty() or not lesson_progress.has(module_id):
		return 0
	return int(lesson_progress[module_id])


func complete_lesson_unit(module_id: String, total: int, all_module_ids: Array[String]) -> void:
	if module_id.is_empty():
		return
	var clamped_total: int = maxi(1, total)
	var done: int = get_lesson_progress(module_id)
	if done >= clamped_total:
		return
	done += 1
	lesson_progress[module_id] = done
	grant_intel_bonus(module_id)
	if done >= clamped_total:
		complete_lesson(module_id)
		if _all_modules_complete(all_module_ids):
			complete_lesson(ALL_MODULES_LESSON)
	_save_progress()


func complete_module(module_id: String, total: int, all_module_ids: Array[String]) -> void:
	if module_id.is_empty():
		return
	var clamped_total: int = maxi(1, total)
	lesson_progress[module_id] = clamped_total
	complete_lesson(module_id)
	if _all_modules_complete(all_module_ids):
		complete_lesson(ALL_MODULES_LESSON)
	_save_progress()


func _all_modules_complete(all_module_ids: Array[String]) -> bool:
	if all_module_ids.is_empty():
		return false
	for i in all_module_ids.size():
		if not has_completed_lesson(all_module_ids[i]):
			return false
	return true


func reset_to_defaults() -> void:
	max_stage_cleared_by_module.clear()
	credits = 0
	locked_stages.clear()
	cleared_stages.clear()
	completed_lessons.clear()
	lesson_progress.clear()
	purchased_items.clear()
	unlocked_skills.clear()
	unlocked_towers = ["base"]
	tech_ranks.clear()
	_ensure_default_capacity_rank()
	has_stateful_inspection = false
	module_1_complete = false
	seen_module_intros.clear()
	tutorial_complete = false
	has_intel_bonus = false
	intel_bonus_module = ""
	trace_seen_by_module = _empty_trace_history()
	trace_missed_by_module = _empty_trace_history()
	decision_stage_state = {}
	story_memory = {}
	mastery_matrix = {
		"phishing": DEFAULT_MASTERY,
	}


func get_decision_stage_state(stage_key: String) -> Dictionary:
	var key: String = stage_key.strip_edges()
	if key.is_empty() or not decision_stage_state.has(key):
		return {}
	var stored: Variant = decision_stage_state[key]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return (stored as Dictionary).duplicate(true)


func set_decision_stage_state(stage_key: String, state: Dictionary) -> void:
	var key: String = stage_key.strip_edges()
	if key.is_empty():
		return
	decision_stage_state[key] = state.duplicate(true)
	SaveService.save_game()


func clear_decision_stage_state(stage_key: String) -> void:
	var key: String = stage_key.strip_edges()
	if key.is_empty() or not decision_stage_state.has(key):
		return
	decision_stage_state.erase(key)
	SaveService.save_game()


## Read-only snapshot for reactive dialogue's condition checks (see
## DecisionScenarios.condition_met/dialogue_lines) — a duplicate, so callers
## can never mutate story memory by editing what this returns.
func get_story_memory_snapshot() -> Dictionary:
	return story_memory.duplicate(true)


func get_story_memory(key: String) -> Variant:
	return story_memory.get(key.strip_edges(), null)


## Commits one choice's whole authored "memory" block (see
## DecisionScenarios.choice_memory) in a single save, never one write per
## key — this is the one and only place story memory is ever persisted, so
## every commit path (SAFE's immediate resolution, RISKY's TD-win) reaches
## exactly this same, exactly-once write.
func set_story_memories(entries: Dictionary) -> void:
	if entries.is_empty():
		return
	for key in entries.keys():
		var trimmed: String = str(key).strip_edges()
		if trimmed.is_empty():
			continue
		story_memory[trimmed] = entries[key]
	SaveService.save_game()


func _normalize_decision_state(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var stored: Dictionary = raw as Dictionary
	for key in stored.keys():
		var entry: Variant = stored[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry as Dictionary
		var retry_cp: Dictionary = {}
		if typeof(row.get("retry_checkpoint")) == TYPE_DICTIONARY:
			retry_cp = (row["retry_checkpoint"] as Dictionary).duplicate(true)
		result[str(key)] = {
			"threat_index": int(row.get("threat_index", 0)),
			"resolved_threats": int(row.get("resolved_threats", 0)),
			"flow_state": str(row.get("flow_state", "")),
			"in_breach": bool(row.get("in_breach", false)),
			"security_state": str(row.get("security_state", "NOMINAL")),
			"safe_count": int(row.get("safe_count", 0)),
			"retry_checkpoint": retry_cp,
		}
		# Optional live Stage 1 review marker; older checkpoints remain unchanged.
		var reviewed_index := int(row.get("reviewed_breach_index", -1))
		if reviewed_index >= 0 and reviewed_index == int(row.get("threat_index", 0)):
			result[str(key)]["reviewed_breach_index"] = reviewed_index
	return result


## Older saves have no "story_memory" key at all; they simply start with no
## memory, exactly the same as a fresh account. Only scalar values
## (bool/String/int/float) are trusted from a save file — anything else
## (an array, a nested dictionary) is dropped rather than risking a
## condition_met() comparison against an unexpected type.
func _normalize_story_memory(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var stored: Dictionary = raw as Dictionary
	for key in stored.keys():
		var trimmed: String = str(key).strip_edges()
		if trimmed.is_empty():
			continue
		var value: Variant = stored[key]
		var value_type: int = typeof(value)
		if value_type == TYPE_BOOL or value_type == TYPE_STRING or value_type == TYPE_STRING_NAME or value_type == TYPE_INT or value_type == TYPE_FLOAT:
			result[trimmed] = value
	return result


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	SaveService.save_game()


func grant_intel_bonus(module_id: String) -> void:
	if module_id.is_empty():
		return
	has_intel_bonus = true
	intel_bonus_module = module_id
	SaveService.save_game()


func consume_intel_bonus_gold(base_gold: int, module_id: String) -> int:
	var gold: int = maxi(0, base_gold)
	if not has_intel_bonus:
		return gold
	if not intel_bonus_module.is_empty() and intel_bonus_module != module_id:
		return gold
	has_intel_bonus = false
	intel_bonus_module = ""
	SaveService.save_game()
	var boosted: int = int(ceil(float(gold) * 1.15))
	print("[Intel] Threat Intel Bonus +15%% gold. %d -> %d" % [gold, boosted])
	return boosted


func intel_module_for_stage(stage_id: int) -> String:
	var active: String = str(Router.active_module_id).strip_edges()
	if not active.is_empty():
		return active
	if stage_id >= 1 and stage_id <= 10:
		return "mod_01"
	return ""


func spend_credits(amount: int) -> bool:
	if amount <= 0 or credits < amount:
		return false
	credits -= amount
	SaveService.save_game()
	return true


func _save_progress() -> void:
	SaveService.save_game()


## Canonical identity for stage-progression state (cleared/locked/ceiling).
## Use this everywhere instead of rebuilding the string manually, and never
## represent a stage's completion/lock state by raw stage number alone —
## mod_01:1 and mod_02:1 must never collide.
static func stage_progress_key(module_id: String, stage_id: int) -> String:
	return "%s:%d" % [module_id.strip_edges(), stage_id]


## Highest stage cleared within module_id, independent of every other
## module. Defaults to 1 (no clears yet) — the same baseline every module
## has always started from, now scoped per module instead of shared.
func max_stage_cleared(module_id: String) -> int:
	var mid: String = module_id.strip_edges()
	if mid.is_empty() or not max_stage_cleared_by_module.has(mid):
		return 1
	return int(max_stage_cleared_by_module[mid])


func lock_stage(module_id: String, stage_id: int) -> void:
	if stage_id <= 0 or module_id.strip_edges().is_empty():
		return
	locked_stages[stage_progress_key(module_id, stage_id)] = true
	SaveService.save_game()


func unlock_stage(module_id: String, stage_id: int) -> void:
	locked_stages.erase(stage_progress_key(module_id, stage_id))
	SaveService.save_game()


func is_stage_locked(module_id: String, stage_id: int) -> bool:
	return locked_stages.has(stage_progress_key(module_id, stage_id))


func owns_store_item(item_id: String) -> bool:
	return not item_id.is_empty() and purchased_items.has(item_id)


func purchase_store_item(item_id: String, price: int) -> bool:
	if item_id.is_empty() or owns_store_item(item_id):
		return false
	if not spend_credits(price):
		return false
	purchased_items.append(item_id)
	_save_progress()
	return true


func complete_lesson(lesson_id: String) -> void:
	if lesson_id.is_empty() or completed_lessons.has(lesson_id):
		return
	completed_lessons.append(lesson_id)
	if lesson_id != ALL_MODULES_LESSON:
		_try_grant_module_unlock()
	SaveService.save_game()


func _try_grant_module_unlock() -> void:
	for i in ContentDB.CORE_LESSON_IDS.size():
		var core_id: String = String(ContentDB.CORE_LESSON_IDS[i])
		if not has_completed_lesson(core_id):
			return
	if has_completed_lesson(ALL_MODULES_LESSON):
		return
	completed_lessons.append(ALL_MODULES_LESSON)


func has_completed_lesson(lesson_id: String) -> bool:
	return completed_lessons.has(lesson_id)


func is_module_deploy_unlocked(module_id: String) -> bool:
	return has_completed_lesson(module_id)


func has_seen_module_intro(module_id: String) -> bool:
	return not module_id.is_empty() and seen_module_intros.has(module_id)


func mark_module_intro_seen(module_id: String) -> void:
	if module_id.is_empty() or seen_module_intros.has(module_id):
		return
	seen_module_intros.append(module_id)
	SaveService.save_game()


func needs_tutorial() -> bool:
	return not tutorial_complete


func mark_tutorial_complete() -> void:
	if tutorial_complete:
		return
	tutorial_complete = true
	SaveService.save_game()


func mark_stage_cleared(module_id: String, stage_id: int) -> void:
	var mid: String = module_id.strip_edges()
	if stage_id <= 0 or mid.is_empty():
		return
	max_stage_cleared_by_module[mid] = maxi(max_stage_cleared(mid), stage_id)
	cleared_stages[stage_progress_key(mid, stage_id)] = true
	SaveService.save_game()


func has_cleared_stage(module_id: String, stage_id: int) -> bool:
	if stage_id <= 0:
		return false
	return cleared_stages.has(stage_progress_key(module_id, stage_id))


func get_weakest_skill() -> String:
	if mastery_matrix.is_empty():
		return "phishing"
	var weakest_skill: String = ""
	var lowest_score: float = 1.0
	var skill_ids: Array = mastery_matrix.keys()
	for i in skill_ids.size():
		var skill_id: String = str(skill_ids[i])
		var stored: Variant = mastery_matrix[skill_id]
		var score: float = float(stored)
		if score < lowest_score:
			lowest_score = score
			weakest_skill = skill_id
	if weakest_skill.is_empty():
		return "phishing"
	return weakest_skill


func get_mastery(skill_id: String = "phishing") -> float:
	var key: String = skill_id if not skill_id.is_empty() else "phishing"
	return clampf(_mastery_of(key), 0.0, 1.0)


func preferred_difficulty(skill_id: String = "phishing") -> String:
	var p_learned: float = get_mastery(skill_id)
	if p_learned < AT_RISK_MASTERY:
		return "easy"
	if p_learned < PROFICIENT_MASTERY:
		return "medium"
	return "hard"


func get_trace_seen(module_id: String) -> Array[String]:
	return _trace_id_list(trace_seen_by_module, module_id)


func get_trace_missed(module_id: String) -> Array[String]:
	return _trace_id_list(trace_missed_by_module, module_id)


func record_trace_result(module_id: String, question_id: String, is_correct: bool) -> void:
	var mid: String = module_id.strip_edges()
	var qid: String = question_id.strip_edges()
	if mid.is_empty() or qid.is_empty():
		return
	_ensure_trace_history()
	var seen: Array[String] = get_trace_seen(mid)
	if not seen.has(qid):
		seen.append(qid)
	trace_seen_by_module[mid] = seen
	var missed: Array[String] = get_trace_missed(mid)
	if is_correct:
		var missed_index: int = missed.find(qid)
		if missed_index >= 0:
			missed.remove_at(missed_index)
	elif not missed.has(qid):
		missed.append(qid)
	trace_missed_by_module[mid] = missed
	SaveService.save_game()


func _empty_trace_history() -> Dictionary:
	var history: Dictionary = {}
	for i in TRACE_MODULE_IDS.size():
		history[str(TRACE_MODULE_IDS[i])] = []
	return history


func _ensure_trace_history() -> void:
	if trace_seen_by_module.is_empty():
		trace_seen_by_module = _empty_trace_history()
	if trace_missed_by_module.is_empty():
		trace_missed_by_module = _empty_trace_history()
	for i in TRACE_MODULE_IDS.size():
		var module_id: String = str(TRACE_MODULE_IDS[i])
		if not trace_seen_by_module.has(module_id) or typeof(trace_seen_by_module[module_id]) != TYPE_ARRAY:
			trace_seen_by_module[module_id] = []
		if not trace_missed_by_module.has(module_id) or typeof(trace_missed_by_module[module_id]) != TYPE_ARRAY:
			trace_missed_by_module[module_id] = []


func _trace_id_list(store: Dictionary, module_id: String) -> Array[String]:
	_ensure_trace_history()
	var result: Array[String] = []
	var mid: String = module_id.strip_edges()
	if mid.is_empty() or not store.has(mid):
		return result
	var stored: Variant = store[mid]
	if typeof(stored) != TYPE_ARRAY:
		return result
	var rows: Array = stored as Array
	for i in rows.size():
		var qid: String = str(rows[i]).strip_edges()
		if qid.is_empty() or result.has(qid):
			continue
		result.append(qid)
	return result


func _normalize_trace_history(raw: Variant) -> Dictionary:
	var history: Dictionary = _empty_trace_history()
	if typeof(raw) != TYPE_DICTIONARY:
		return history
	var saved: Dictionary = raw as Dictionary
	for i in TRACE_MODULE_IDS.size():
		var module_id: String = str(TRACE_MODULE_IDS[i])
		if not saved.has(module_id) or typeof(saved[module_id]) != TYPE_ARRAY:
			continue
		var ids: Array[String] = []
		var rows: Array = saved[module_id] as Array
		for j in rows.size():
			var qid: String = str(rows[j]).strip_edges()
			if qid.is_empty() or ids.has(qid):
				continue
			ids.append(qid)
		history[module_id] = ids
	return history


func quiz_gold_reward(is_correct: bool, skill_id: String = "phishing") -> int:
	var base_gold: int = 5 if is_correct else 2
	var p_learned: float = get_mastery(skill_id)
	var mult: float = 1.0
	if p_learned >= PROFICIENT_MASTERY:
		mult = 1.5
	elif p_learned >= AT_RISK_MASTERY:
		mult = 1.25
	return maxi(1, int(ceil(float(base_gold) * mult)))


func bkt_params_from(question: Dictionary) -> Dictionary:
	var stored: Variant = question.get("bkt", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func update_mastery(skill_id: String, is_correct: bool, params: Dictionary = {}) -> void:
	var key: String = skill_id if not skill_id.is_empty() else "phishing"
	var p_guess: float = _bkt_param(params, ["p_g", "p_guess"], P_GUESS)
	var p_slip: float = _bkt_param(params, ["p_s", "p_slip"], P_SLIP)
	var p_transit: float = _bkt_param(params, ["p_t", "p_transit"], P_TRANSIT)
	var p_learned: float = _mastery_of(key)
	var p_post: float = _posterior(p_learned, is_correct, p_guess, p_slip)
	var new_mastery: float = clampf(p_post + ((1.0 - p_post) * p_transit), MIN_MASTERY, MAX_MASTERY)
	mastery_matrix[key] = new_mastery
	print(
		"[BKT] local %s %s  P(L) %.3f -> %.3f  (G=%.2f S=%.2f T=%.2f)"
		% [key, "hit" if is_correct else "miss", p_learned, new_mastery, p_guess, p_slip, p_transit]
	)
	SaveService.save_game()


func apply_official_mastery(skill_id: String, probability_known: float) -> void:
	var key: String = skill_id if not skill_id.is_empty() else "phishing"
	mastery_matrix[key] = clampf(probability_known, MIN_MASTERY, MAX_MASTERY)


func seed_from_official_mastery() -> void:
	var official: Dictionary = AuthService.mastery()
	var changed := false
	for i in _OFFICIAL_SKILLS.size():
		var skill_id: String = _OFFICIAL_SKILLS[i]
		var titled: String = skill_id.capitalize()
		var value: float = float(official.get(titled, official.get(skill_id, 0.0)))
		if value <= 0.0:
			continue
		apply_official_mastery(skill_id, value)
		changed = true
		print("[BKT] seeded %s from official P(L)=%.3f" % [skill_id, value])
	if changed:
		SaveService.save_game()


func pull_official_bkt() -> void:
	if not AuthService.is_signed_in():
		seed_from_official_mastery()
		return
	var gameplay: Dictionary = await AuthService.fetch_bkt_state()
	if gameplay.is_empty():
		seed_from_official_mastery()
		return
	var keys: Array = gameplay.keys()
	for i in keys.size():
		var skill_id: String = str(keys[i]).strip_edges().to_lower()
		if skill_id.is_empty():
			continue
		apply_official_mastery(skill_id, float(gameplay[keys[i]]))
	print("[BKT] pulled official gameplay matrix ", gameplay)
	SaveService.save_game()


func _mastery_of(skill_id: String) -> float:
	if not mastery_matrix.has(skill_id):
		return DEFAULT_MASTERY
	return float(mastery_matrix[skill_id])


func _bkt_param(params: Dictionary, keys: Array, fallback: float) -> float:
	for i in keys.size():
		var key: String = str(keys[i])
		if not params.has(key):
			continue
		var stored: Variant = params[key]
		if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
			return clampf(float(stored), 0.01, 0.5)
	return fallback


func _posterior(p_learned: float, is_correct: bool, p_guess: float = P_GUESS, p_slip: float = P_SLIP) -> float:
	if is_correct:
		var numer: float = p_learned * (1.0 - p_slip)
		var denom: float = numer + ((1.0 - p_learned) * p_guess)
		if denom <= 0.0:
			return p_learned
		return numer / denom
	var numer_wrong: float = p_learned * p_slip
	var denom_wrong: float = numer_wrong + ((1.0 - p_learned) * (1.0 - p_guess))
	if denom_wrong <= 0.0:
		return p_learned
	return numer_wrong / denom_wrong


func get_save_data() -> Dictionary:
	return {
		"max_stage_cleared_by_module": max_stage_cleared_by_module.duplicate(true),
		# Legacy field kept for older clients/detection only (see
		# SaveService._looks_like_save()); it mirrors Module 1's own ceiling,
		# since Module 1 was the sole module with real stage content when
		# this field was the single source of truth.
		"mock_max_stage_cleared": max_stage_cleared("mod_01"),
		"mastery_matrix": mastery_matrix.duplicate(true),
		"locked_stages": locked_stages.duplicate(true),
		"cleared_stages": cleared_stages.keys(),
		"completed_lessons": completed_lessons.duplicate(),
		"credits": credits,
		"unlocked_towers": unlocked_towers.duplicate(),
		"unlocked_skills": unlocked_skills.duplicate(),
		"tech_ranks": tech_ranks.duplicate(true),
		"has_stateful_inspection": has_stateful_inspection,
		"lesson_progress": lesson_progress.duplicate(true),
		"purchased_items": purchased_items.duplicate(),
		"module_1_complete": module_1_complete,
		"seen_module_intros": seen_module_intros.duplicate(),
		"tutorial_complete": tutorial_complete,
		"has_intel_bonus": has_intel_bonus,
		"intel_bonus_module": intel_bonus_module,
		"trace_seen_by_module": trace_seen_by_module.duplicate(true),
		"trace_missed_by_module": trace_missed_by_module.duplicate(true),
		"decision_stage_state": decision_stage_state.duplicate(true),
		"story_memory": story_memory.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	max_stage_cleared_by_module.clear()
	if data.has("max_stage_cleared_by_module") and typeof(data["max_stage_cleared_by_module"]) == TYPE_DICTIONARY:
		var saved_ceilings: Dictionary = data["max_stage_cleared_by_module"] as Dictionary
		var ceiling_keys: Array = saved_ceilings.keys()
		for i in ceiling_keys.size():
			var mid: String = str(ceiling_keys[i]).strip_edges()
			if not mid.is_empty():
				max_stage_cleared_by_module[mid] = maxi(1, int(saved_ceilings[ceiling_keys[i]]))
	elif data.has("mock_max_stage_cleared"):
		# Legacy global counter only ever tracked Module 1 — the sole module
		# with real stage content before Module 2 existed — so it migrates
		# there rather than being guessed at for any other module.
		max_stage_cleared_by_module["mod_01"] = maxi(1, int(data["mock_max_stage_cleared"]))

	if data.has("mastery_matrix") and typeof(data["mastery_matrix"]) == TYPE_DICTIONARY:
		var saved_matrix: Dictionary = data["mastery_matrix"] as Dictionary
		var matrix_keys: Array = saved_matrix.keys()
		for i in matrix_keys.size():
			var skill_id: String = str(matrix_keys[i])
			if skill_id.is_empty():
				continue
			mastery_matrix[skill_id] = float(saved_matrix[matrix_keys[i]])

	locked_stages.clear()
	if data.has("locked_stages"):
		_ingest_stage_progress_set(data["locked_stages"], locked_stages)

	cleared_stages.clear()
	if data.has("cleared_stages"):
		_ingest_stage_progress_set(data["cleared_stages"], cleared_stages)
	elif max_stage_cleared("mod_01") > 1:
		for stage_n in range(1, max_stage_cleared("mod_01") + 1):
			cleared_stages[stage_progress_key("mod_01", stage_n)] = true

	if data.has("completed_lessons") and typeof(data["completed_lessons"]) == TYPE_ARRAY:
		var saved_lessons: Array = data["completed_lessons"] as Array
		completed_lessons.clear()
		for i in saved_lessons.size():
			var lesson_id: String = str(saved_lessons[i])
			if not lesson_id.is_empty() and not completed_lessons.has(lesson_id):
				completed_lessons.append(lesson_id)

	if data.has("lesson_progress") and typeof(data["lesson_progress"]) == TYPE_DICTIONARY:
		var saved_progress: Dictionary = data["lesson_progress"] as Dictionary
		lesson_progress.clear()
		var progress_keys: Array = saved_progress.keys()
		for i in progress_keys.size():
			var module_id: String = str(progress_keys[i])
			if module_id.is_empty():
				continue
			lesson_progress[module_id] = int(saved_progress[progress_keys[i]])

	if data.has("credits"):
		var credits_raw: Variant = data["credits"]
		var credits_type: int = typeof(credits_raw)
		if credits_type == TYPE_INT or credits_type == TYPE_FLOAT:
			credits = maxi(0, int(credits_raw))

	if data.has("purchased_items") and typeof(data["purchased_items"]) == TYPE_ARRAY:
		var saved_items: Array = data["purchased_items"] as Array
		purchased_items.clear()
		for i in saved_items.size():
			var item_id: String = str(saved_items[i])
			if not item_id.is_empty() and not purchased_items.has(item_id):
				purchased_items.append(item_id)

	if data.has("unlocked_towers") and typeof(data["unlocked_towers"]) == TYPE_ARRAY:
		var saved_towers: Array = data["unlocked_towers"] as Array
		unlocked_towers.clear()
		unlocked_towers.append("base")
		for i in saved_towers.size():
			var tower_id: String = str(saved_towers[i])
			if tower_id.is_empty() or tower_id == "network" or tower_id == "crypto":
				continue
			if not unlocked_towers.has(tower_id):
				unlocked_towers.append(tower_id)

	if data.has("tech_ranks") and typeof(data["tech_ranks"]) == TYPE_DICTIONARY:
		tech_ranks = (data["tech_ranks"] as Dictionary).duplicate(true)
	else:
		tech_ranks.clear()
	_sanitize_tech_ranks()
	_ensure_default_capacity_rank()

	if data.has("has_stateful_inspection"):
		var flag_raw: Variant = data["has_stateful_inspection"]
		var flag_type: int = typeof(flag_raw)
		if flag_type == TYPE_BOOL:
			has_stateful_inspection = flag_raw
		elif flag_type == TYPE_INT or flag_type == TYPE_FLOAT:
			has_stateful_inspection = int(flag_raw) != 0
	has_stateful_inspection = has_stateful_inspection or tech_rank("base", "skill") >= 1
	_sync_evolution_unlocks()

	if data.has("unlocked_skills") and typeof(data["unlocked_skills"]) == TYPE_ARRAY:
		var saved_skills: Array = data["unlocked_skills"] as Array
		unlocked_skills.clear()
		for i in saved_skills.size():
			var skill_id: String = str(saved_skills[i])
			if not skill_id.is_empty() and not unlocked_skills.has(skill_id):
				unlocked_skills.append(skill_id)

	if data.has("module_1_complete"):
		var complete_raw: Variant = data["module_1_complete"]
		var complete_type: int = typeof(complete_raw)
		if complete_type == TYPE_BOOL:
			module_1_complete = complete_raw
		elif complete_type == TYPE_INT or complete_type == TYPE_FLOAT:
			module_1_complete = int(complete_raw) != 0

	if data.has("seen_module_intros") and typeof(data["seen_module_intros"]) == TYPE_ARRAY:
		var saved_intros: Array = data["seen_module_intros"] as Array
		seen_module_intros.clear()
		for i in saved_intros.size():
			var intro_id: String = str(saved_intros[i])
			if not intro_id.is_empty() and not seen_module_intros.has(intro_id):
				seen_module_intros.append(intro_id)

	if data.has("tutorial_complete"):
		var tutorial_raw: Variant = data["tutorial_complete"]
		var tutorial_type: int = typeof(tutorial_raw)
		if tutorial_type == TYPE_BOOL:
			tutorial_complete = tutorial_raw
		elif tutorial_type == TYPE_INT or tutorial_type == TYPE_FLOAT:
			tutorial_complete = int(tutorial_raw) != 0

	if data.has("has_intel_bonus"):
		var bonus_raw: Variant = data["has_intel_bonus"]
		var bonus_type: int = typeof(bonus_raw)
		if bonus_type == TYPE_BOOL:
			has_intel_bonus = bonus_raw
		elif bonus_type == TYPE_INT or bonus_type == TYPE_FLOAT:
			has_intel_bonus = int(bonus_raw) != 0
	if data.has("intel_bonus_module"):
		intel_bonus_module = str(data["intel_bonus_module"])

	if data.has("trace_seen_by_module"):
		trace_seen_by_module = _normalize_trace_history(data["trace_seen_by_module"])
	else:
		trace_seen_by_module = _empty_trace_history()
	if data.has("trace_missed_by_module"):
		trace_missed_by_module = _normalize_trace_history(data["trace_missed_by_module"])
	else:
		trace_missed_by_module = _empty_trace_history()
	# Older saves have no decision checkpoints; they simply start Stage 1 fresh.
	decision_stage_state = _normalize_decision_state(data.get("decision_stage_state", {}))
	story_memory = _normalize_story_memory(data.get("story_memory", {}))

	if module_1_complete:
		cleared_stages[stage_progress_key("mod_01", 10)] = true
	_normalize_mastery_keys()


## Normalizes either representation of a stage-progress set (cleared_stages
## or locked_stages) into module-scoped keys. Accepts already-canonical
## "module_id:stage_id" strings unchanged (idempotent — re-ingesting a
## normalized save reproduces the identical set, no duplicates) and migrates
## legacy raw stage numbers (int, float, or a bare numeric string) into
## Module 1, the only module with real stage content before Module 2 existed.
func _ingest_stage_progress_set(raw: Variant, target: Dictionary) -> void:
	var entries: Array = []
	if typeof(raw) == TYPE_ARRAY:
		entries = raw as Array
	elif typeof(raw) == TYPE_DICTIONARY:
		entries = (raw as Dictionary).keys()
	else:
		return
	for i in entries.size():
		var key: String = _normalize_stage_progress_key(entries[i])
		if not key.is_empty():
			target[key] = true


func _normalize_stage_progress_key(entry: Variant) -> String:
	if typeof(entry) == TYPE_INT or typeof(entry) == TYPE_FLOAT:
		var stage_id: int = int(entry)
		return stage_progress_key("mod_01", stage_id) if stage_id > 0 else ""
	if typeof(entry) != TYPE_STRING and typeof(entry) != TYPE_STRING_NAME:
		return ""
	var text: String = str(entry).strip_edges()
	if text.is_empty():
		return ""
	var colon: int = text.find(":")
	if colon > 0:
		var module_part: String = text.substr(0, colon).strip_edges()
		var stage_part: String = text.substr(colon + 1).strip_edges()
		if not module_part.is_empty() and stage_part.is_valid_int() and int(stage_part) > 0:
			return stage_progress_key(module_part, int(stage_part))
		return ""
	if text.is_valid_int():
		var legacy_id: int = int(text)
		return stage_progress_key("mod_01", legacy_id) if legacy_id > 0 else ""
	return ""


func _normalize_mastery_keys() -> void:
	var next: Dictionary = {}
	for i in _OFFICIAL_SKILLS.size():
		var skill_id: String = _OFFICIAL_SKILLS[i]
		var value: float = DEFAULT_MASTERY
		if mastery_matrix.has(skill_id):
			value = float(mastery_matrix[skill_id])
		next[skill_id] = value
	mastery_matrix = next


func _ensure_default_capacity_rank() -> void:
	if tech_rank("base", "capacity") >= 1:
		return
	_set_tech_rank("base", "capacity", 1)


func _sanitize_tech_ranks() -> void:
	var clean: Dictionary = {}
	var tower_keys: Array = tech_ranks.keys()
	for i in tower_keys.size():
		var tower_id: String = str(tower_keys[i])
		if tower_id.is_empty() or typeof(tech_ranks[tower_keys[i]]) != TYPE_DICTIONARY:
			continue
		var tracks: Dictionary = tech_ranks[tower_keys[i]] as Dictionary
		var next_tracks: Dictionary = {}
		var track_keys: Array = tracks.keys()
		for j in track_keys.size():
			var track_id: String = str(track_keys[j])
			if track_id.is_empty():
				continue
			next_tracks[track_id] = maxi(0, int(tracks[track_keys[j]]))
		clean[tower_id] = next_tracks
	tech_ranks = clean


func _sync_evolution_unlocks() -> void:
	var evo: int = tech_rank("base", "evolution")
	if evo >= 1 and not unlocked_towers.has("scanner"):
		unlocked_towers.append("scanner")
	if evo >= 2 and not unlocked_towers.has("sandbox"):
		unlocked_towers.append("sandbox")
