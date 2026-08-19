extends Node
## Autoload singleton, registered as "PlayerManager".
## Lesson progress is persisted per signed-in participant.

const P_GUESS: float = 0.2
const P_SLIP: float = 0.1
const P_TRANSIT: float = 0.1
const DEFAULT_MASTERY: float = 0.25
const ALL_MODULES_LESSON := "mod1_all"

var mastery_matrix: Dictionary = {
	"ports": DEFAULT_MASTERY,
	"firewalls": DEFAULT_MASTERY,
	"crypto": DEFAULT_MASTERY,
}
var unlocked_skills: Array[String] = ["firewall_1"]
var locked_stages: Dictionary = {}
var completed_lessons: Array[String] = []
var lesson_progress: Dictionary = {}
var purchased_items: Array[String] = []
var mock_max_stage_cleared: int = 9


func has_skill(skill_id: String) -> bool:
	return unlocked_skills.has(skill_id)


func unlock_skill(skill_id: String) -> void:
	if skill_id.is_empty() or unlocked_skills.has(skill_id):
		return
	unlocked_skills.append(skill_id)


func _ready() -> void:
	AuthService.session_changed.connect(_on_session_changed)
	if AuthService.is_signed_in():
		_load_progress()


func _on_session_changed(signed_in: bool) -> void:
	if signed_in:
		_load_progress()
		return
	_reset_lesson_state()


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


func _reset_lesson_state() -> void:
	completed_lessons.clear()
	lesson_progress.clear()
	purchased_items.clear()


func _progress_path() -> String:
	var code := AuthService.participant_code().strip_edges()
	var safe := code.validate_filename()
	if safe.is_empty():
		safe = "guest"
	return "user://lesson_progress_%s.json" % safe


func _load_progress() -> void:
	_reset_lesson_state()
	var path := _progress_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var done_raw: Variant = data.get("completed_lessons", [])
	if typeof(done_raw) == TYPE_ARRAY:
		var done_arr: Array = done_raw
		for i in done_arr.size():
			var lesson_id := str(done_arr[i])
			if not lesson_id.is_empty() and not completed_lessons.has(lesson_id):
				completed_lessons.append(lesson_id)
	var progress_raw: Variant = data.get("lesson_progress", {})
	if typeof(progress_raw) == TYPE_DICTIONARY:
		var progress_dict: Dictionary = progress_raw
		var keys: Array = progress_dict.keys()
		for i in keys.size():
			var module_id := str(keys[i])
			if not module_id.is_empty():
				lesson_progress[module_id] = int(progress_dict[module_id])
	var owned_raw: Variant = data.get("purchased_items", [])
	if typeof(owned_raw) == TYPE_ARRAY:
		var owned_arr: Array = owned_raw
		for i in owned_arr.size():
			var item_id := str(owned_arr[i])
			if not item_id.is_empty() and not purchased_items.has(item_id):
				purchased_items.append(item_id)


func _save_progress() -> void:
	var payload := {
		"completed_lessons": completed_lessons,
		"lesson_progress": lesson_progress,
		"purchased_items": purchased_items,
	}
	var file := FileAccess.open(_progress_path(), FileAccess.WRITE)
	if file == null:
		push_warning("PlayerManager: could not save lesson progress.")
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func lock_stage(stage_id: int) -> void:
	if stage_id <= 0:
		return
	locked_stages[stage_id] = true


func unlock_stage(stage_id: int) -> void:
	locked_stages.erase(stage_id)


func is_stage_locked(stage_id: int) -> bool:
	return locked_stages.has(stage_id)


func owns_store_item(item_id: String) -> bool:
	return not item_id.is_empty() and purchased_items.has(item_id)


func purchase_store_item(item_id: String, price: int) -> bool:
	if item_id.is_empty() or owns_store_item(item_id):
		return false
	if not AuthService.spend_threat_points(price):
		return false
	purchased_items.append(item_id)
	_save_progress()
	return true


func complete_lesson(lesson_id: String) -> void:
	if lesson_id.is_empty() or completed_lessons.has(lesson_id):
		return
	completed_lessons.append(lesson_id)
	_save_progress()


func has_completed_lesson(lesson_id: String) -> bool:
	return completed_lessons.has(lesson_id)


func mark_stage_cleared(stage_id: int) -> void:
	if stage_id <= 0:
		return
	mock_max_stage_cleared = maxi(mock_max_stage_cleared, stage_id)


func get_weakest_skill() -> String:
	if mastery_matrix.is_empty():
		return "ports"
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
		return "ports"
	return weakest_skill


func update_mastery(skill_id: String, is_correct: bool) -> void:
	if skill_id.is_empty():
		push_warning("PlayerManager: empty skill_id")
		return
	var p_learned: float = _mastery_of(skill_id)
	var p_post: float = _posterior(p_learned, is_correct)
	var new_mastery: float = p_post + ((1.0 - p_post) * P_TRANSIT)
	mastery_matrix[skill_id] = new_mastery
	print("[BKT] " + skill_id + " updated: " + str(p_learned) + " -> " + str(new_mastery))


func _mastery_of(skill_id: String) -> float:
	if not mastery_matrix.has(skill_id):
		return DEFAULT_MASTERY
	return float(mastery_matrix[skill_id])


func _posterior(p_learned: float, is_correct: bool) -> float:
	if is_correct:
		var numer: float = p_learned * (1.0 - P_SLIP)
		var denom: float = numer + ((1.0 - p_learned) * P_GUESS)
		if denom <= 0.0:
			return p_learned
		return numer / denom
	var numer_wrong: float = p_learned * P_SLIP
	var denom_wrong: float = numer_wrong + ((1.0 - p_learned) * (1.0 - P_GUESS))
	if denom_wrong <= 0.0:
		return p_learned
	return numer_wrong / denom_wrong
