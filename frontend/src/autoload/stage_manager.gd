extends Node
## Autoload singleton, registered as "StageManager".
## Stage configs and combat tables are loaded from ContentDB JSON.


func get_stage_config(stage_id: int) -> Dictionary:
	return ContentDB.get_stage(str(stage_id))


func access_reason(stage_id: int, module_id: String = "mod_01") -> String:
	# Shared by deployment and the read-only Progress screen. Preserve gate order.
	if not module_id.is_empty() and not PlayerManager.is_module_deploy_unlocked(module_id):
		return "Complete this module's lessons to unlock deployment."
	if stage_id <= 0 or get_stage_config(stage_id).is_empty():
		return "Coming soon: this stage has not been authored."
	if stage_id > PlayerManager.mock_max_stage_cleared + 1:
		return "Clear the preceding stages first."
	var requirement := str(get_stage_config(stage_id).get("req_lesson", ""))
	if not requirement.is_empty() and not PlayerManager.has_completed_lesson(requirement):
		return "Complete the required lesson before deploying."
	if PlayerManager.is_stage_locked(stage_id):
		return "Review the required material to clear this exam lock."
	return ""
