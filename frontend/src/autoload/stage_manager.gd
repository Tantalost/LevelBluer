extends Node
## Autoload singleton, registered as "StageManager".
## Stage configs and combat tables are loaded from ContentDB JSON.


func get_stage_config(stage_id: int) -> Dictionary:
	return ContentDB.get_stage(str(stage_id))


func access_reason(stage_id: int, module_id: String = "mod_01") -> String:
	# One authority for selectors, direct launch, retries and next-stage routes.
	if module_id not in LessonCatalog.module_ids() or stage_id <= 0 or stage_id > 10 or get_stage_config(stage_id).is_empty():
		return "Coming soon: this stage has not been authored."
	var lesson_reason: String = lesson_access_reason(stage_id, module_id)
	if not lesson_reason.is_empty():
		return lesson_reason
	# The old maximum starts at 1 even for new players. Explicit clears prevent
	# Stage 2 (or a gap in a legacy save) from bypassing the preceding stage.
	for previous: int in range(1, stage_id):
		if not PlayerManager.has_cleared_stage(module_id, previous):
			return "Clear the preceding stages first (Stage %d in this module)." % previous
	if PlayerManager.is_stage_locked(module_id, stage_id):
		# A pending review grants access to the review route, never to gameplay.
		# Router enforces the gate; module/preceding-stage/lesson checks stay above it.
		if StageRemediation.pending(PlayerManager, module_id, stage_id):
			return ""
		return "Review the required material to clear this exam lock."
	return ""


func required_lesson_count(stage_id: int) -> int:
	if stage_id < 1 or stage_id > 10:
		return 0
	return 6 if stage_id == 10 else ceili(float(stage_id) / 2.0)


func lesson_access_reason(stage_id: int, module_id: String) -> String:
	var required: int = required_lesson_count(stage_id)
	if required == 0 or module_id not in LessonCatalog.module_ids():
		return "This module or stage is unavailable."
	if PlayerManager.deployment_lesson_count(module_id) < required:
		return "Complete Module %d Lesson %d, including its mini quiz and simulation, to unlock Stage %d." % [LessonCatalog.module_ids().find(module_id) + 1, required, stage_id]
	if stage_id == 10 and not PlayerManager.has_lesson_post_quiz(module_id):
		return "Pass this module's lesson post-test (20/25) to unlock Stage 10."
	return ""
