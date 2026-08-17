extends Node
## Autoload singleton, registered as "PlayerManager".
## In-memory BKT mastery only. Persistence is out of scope.

const P_GUESS: float = 0.2
const P_SLIP: float = 0.1
const P_TRANSIT: float = 0.1
const DEFAULT_MASTERY: float = 0.25

var mastery_matrix: Dictionary = {
	"ports": DEFAULT_MASTERY,
	"firewalls": DEFAULT_MASTERY,
}
var unlocked_skills: Array[String] = ["firewall_1"]


func has_skill(skill_id: String) -> bool:
	return unlocked_skills.has(skill_id)


func unlock_skill(skill_id: String) -> void:
	if skill_id.is_empty() or unlocked_skills.has(skill_id):
		return
	unlocked_skills.append(skill_id)


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
