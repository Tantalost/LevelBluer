extends Node
## Autoload singleton, registered as "PlayerManager".
## Lesson progress is persisted per signed-in participant.

const P_GUESS: float = 0.2
const P_SLIP: float = 0.1
const P_TRANSIT: float = 0.1
const DEFAULT_MASTERY: float = 0.25
const MIN_MASTERY: float = 0.01
const MAX_MASTERY: float = 0.99
const AT_RISK_MASTERY: float = 0.40
const PROFICIENT_MASTERY: float = 0.70
const ALL_MODULES_LESSON := "mod1_all"

var mastery_matrix: Dictionary = {
	"phishing": DEFAULT_MASTERY,
}
var unlocked_skills: Array[String] = []
var locked_stages: Dictionary = {}
var cleared_stages: Dictionary = {}
var completed_lessons: Array[String] = []
var lesson_progress: Dictionary = {}
var purchased_items: Array[String] = []
var unlocked_towers: Array[String] = ["base"]
var mock_max_stage_cleared: int = 1
var credits: int = 0
var module_1_complete: bool = false
var seen_module_intros: Array[String] = []
var _session_hydrated: bool = false


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
	mock_max_stage_cleared = 1
	credits = 0
	locked_stages.clear()
	cleared_stages.clear()
	completed_lessons.clear()
	lesson_progress.clear()
	purchased_items.clear()
	unlocked_skills.clear()
	unlocked_towers = ["base"]
	module_1_complete = false
	seen_module_intros.clear()
	mastery_matrix = {
		"phishing": DEFAULT_MASTERY,
	}


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	SaveService.save_game()


func spend_credits(amount: int) -> bool:
	if amount <= 0 or credits < amount:
		return false
	credits -= amount
	SaveService.save_game()
	return true


func _save_progress() -> void:
	SaveService.save_game()


func lock_stage(stage_id: int) -> void:
	if stage_id <= 0:
		return
	locked_stages[stage_id] = true
	SaveService.save_game()


func unlock_stage(stage_id: int) -> void:
	locked_stages.erase(stage_id)
	SaveService.save_game()


func is_stage_locked(stage_id: int) -> bool:
	return locked_stages.has(stage_id)


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


func has_seen_module_intro(module_id: String) -> bool:
	return not module_id.is_empty() and seen_module_intros.has(module_id)


func mark_module_intro_seen(module_id: String) -> void:
	if module_id.is_empty() or seen_module_intros.has(module_id):
		return
	seen_module_intros.append(module_id)
	SaveService.save_game()


func mark_stage_cleared(stage_id: int) -> void:
	if stage_id <= 0:
		return
	mock_max_stage_cleared = maxi(mock_max_stage_cleared, stage_id)
	cleared_stages[stage_id] = true
	SaveService.save_game()


func has_cleared_stage(stage_id: int) -> bool:
	if stage_id <= 0:
		return false
	return cleared_stages.has(stage_id)


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
		"[BKT] %s %s  P(L) %.3f -> %.3f  (G=%.2f S=%.2f T=%.2f)"
		% [key, "hit" if is_correct else "miss", p_learned, new_mastery, p_guess, p_slip, p_transit]
	)
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
		"mock_max_stage_cleared": mock_max_stage_cleared,
		"mastery_matrix": mastery_matrix.duplicate(true),
		"locked_stages": locked_stages.duplicate(true),
		"cleared_stages": cleared_stages.keys(),
		"completed_lessons": completed_lessons.duplicate(),
		"credits": credits,
		"unlocked_towers": unlocked_towers.duplicate(),
		"unlocked_skills": unlocked_skills.duplicate(),
		"lesson_progress": lesson_progress.duplicate(true),
		"purchased_items": purchased_items.duplicate(),
		"module_1_complete": module_1_complete,
		"seen_module_intros": seen_module_intros.duplicate(),
	}


func apply_save_data(data: Dictionary) -> void:
	if data.has("mock_max_stage_cleared"):
		mock_max_stage_cleared = int(data["mock_max_stage_cleared"])

	if data.has("mastery_matrix") and typeof(data["mastery_matrix"]) == TYPE_DICTIONARY:
		var saved_matrix: Dictionary = data["mastery_matrix"] as Dictionary
		var matrix_keys: Array = saved_matrix.keys()
		for i in matrix_keys.size():
			var skill_id: String = str(matrix_keys[i])
			if skill_id.is_empty():
				continue
			mastery_matrix[skill_id] = float(saved_matrix[matrix_keys[i]])

	if data.has("locked_stages") and typeof(data["locked_stages"]) == TYPE_DICTIONARY:
		var saved_locks: Dictionary = data["locked_stages"] as Dictionary
		locked_stages.clear()
		var lock_keys: Array = saved_locks.keys()
		for i in lock_keys.size():
			locked_stages[int(lock_keys[i])] = true

	cleared_stages.clear()
	if data.has("cleared_stages"):
		_ingest_cleared_stages(data["cleared_stages"])
	elif mock_max_stage_cleared > 1:
		for stage_n in range(1, mock_max_stage_cleared + 1):
			cleared_stages[stage_n] = true

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
			if not tower_id.is_empty() and not unlocked_towers.has(tower_id):
				unlocked_towers.append(tower_id)

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
	if module_1_complete:
		cleared_stages[10] = true
	_normalize_mastery_keys()


func _ingest_cleared_stages(raw: Variant) -> void:
	if typeof(raw) == TYPE_ARRAY:
		var rows: Array = raw as Array
		for i in rows.size():
			var stage_id: int = int(rows[i])
			if stage_id > 0:
				cleared_stages[stage_id] = true
		return
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var stored: Dictionary = raw as Dictionary
	var keys: Array = stored.keys()
	for i in keys.size():
		var stage_id: int = int(keys[i])
		if stage_id > 0:
			cleared_stages[stage_id] = true


func _normalize_mastery_keys() -> void:
	var phishing: float = DEFAULT_MASTERY
	if mastery_matrix.has("phishing"):
		phishing = float(mastery_matrix["phishing"])
	mastery_matrix = {
		"phishing": phishing,
	}
