extends RefCounted
## Read-only dashboard guidance. StageManager remains the authority for deployment.

static func snapshot() -> Dictionary:
	var modules: Array[Dictionary] = []
	var lessons := LessonCatalog.modules()
	for i in lessons.size():
		var id := str(lessons[i].id)
		var total := LessonCatalog.lesson_count(id)
		var done: int = PlayerManager.deployment_lesson_count(id)
		var accessible: bool = PlayerManager.is_module_deploy_unlocked(id)
		modules.append({"id": id, "name": str(lessons[i].title), "summary": str(lessons[i].get("desc", "")), "title": "MODULE %d / %s" % [i + 1, lessons[i].title], "status": "AVAILABLE" if accessible else "LOCKED",
			"reason": "Lesson 1 completed. Continue this module's lessons and clear stages in order. Stage 10 also requires its lesson post-test." if accessible else StageManager.lesson_access_reason(1, id),
			"done": done, "total": total, "stages": stage_rows(id)})
	var stages: Array[Dictionary] = stage_rows("mod_01")
	var next: Dictionary = {}
	for row: Dictionary in stages:
		if next.is_empty() and not bool(row.done):
			next = row
	var result := {"modules": modules, "stages": stages, "badge": "!", "route": &"lessons", "action": "OPEN LESSONS", "locked": true}
	if PlayerManager.needs_tutorial():
		result.merge({"heading": "TUTORIAL REQUIRED", "short": "Use DEPLOY to\nfinish the tutorial", "hint": "Finish the guided tutorial in Deploy.", "explanation": "Complete the guided tutorial using Deploy before opening World."})
	elif not PlayerManager.is_module_deploy_unlocked("mod_01"):
		var done := clampi(PlayerManager.get_lesson_progress("mod_01"), 0, LessonCatalog.lesson_count("mod_01"))
		var pretest := AuthService.has_module_pretest("mod_01")
		result.merge({"heading": "MODULE 1 LOCKED", "short": "Finish lessons\n%d / %d complete" % [done, LessonCatalog.lesson_count("mod_01")],
			"hint": "Complete the pre-test, then Lesson 1 with its mini quiz and simulation." if not pretest else StageManager.lesson_access_reason(1, "mod_01"),
			"explanation": "Module 1 deployment is locked. " + ("Complete its pre-test in Lessons, then finish Lesson 1, its mini quiz and simulation." if not pretest else StageManager.lesson_access_reason(1, "mod_01"))})
	elif next.is_empty():
		result.merge({"heading": "MODULE 1 CLEARED", "short": "All ten stages\ncomplete", "hint": "Continue the next module in Lessons. Its first lesson unlocks its deployment.", "explanation": "All Module 1 stages are cleared. Each other module uses its own lesson and stage progress."})
		result.locked = false
		result.badge = "OK"
		result.route = &"progress"
		result.action = "VIEW PROGRESS"
	elif next.status == "LOCKED":
		var explanation := str(next.reason)
		var short := "Open briefing\nfor requirements"
		var exam_lock: bool = str(next.reason).contains("exam lock")
		if str(next.reason).begins_with("Clear the preceding"):
			short = "Clear preceding\nstages in DEPLOY"
			result.route = &"stage_select"
			result.action = "OPEN DEPLOY"
		elif exam_lock:
			short = "Review lessons\nExam lock active"
			explanation = "An exam lock is active. Review the required material in Lessons. The current game does not automatically clear this recorded lock when you review."
		result.merge({"heading": "STAGE %d LOCKED" % next.id, "short": short, "hint": "Review the required material in Lessons. Reviewing alone does not remove the recorded exam lock." if exam_lock else str(next.reason), "explanation": str(next.title) + "\n" + explanation})
	elif next.status == "REVIEW":
		result.merge({"heading": "STAGE %d REVIEW" % next.id, "short": "Finish targeted\nreview in DEPLOY", "hint": "Open this stage in Deploy to complete your mistake-specific review before retrying.", "explanation": "Targeted review is required. Completing unrelated lessons does not bypass it."})
		result.route = &"stage_select"
		result.action = "OPEN TARGETED REVIEW"
	else:
		result.merge({"heading": "STAGE %d READY" % next.id, "short": "Open DEPLOY\nTap for access info", "hint": "Continue in Deploy. Clear each stage to reach the next challenge.", "explanation": str(next.title) + " is available. Later stages can still require preceding clears or lesson completion; see the access list below."})
		result.locked = false
		result.badge = "GO"
		result.route = &"stage_select"
		result.action = "OPEN DEPLOY"
	return result


static func stage_rows(module_id: String) -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	for id: int in range(1, 11):
		var config: Dictionary = StageManager.get_stage_config(id)
		if config.is_empty():
			continue
		var reason: String = StageManager.access_reason(id, module_id)
		var done: bool = PlayerManager.has_cleared_stage(module_id, id)
		var review: bool = StageRemediation.pending(PlayerManager, module_id, id)
		stages.append({"id": id, "title": "STAGE %d / %s" % [id, config.get("name", "")],
			"status": "LOCKED" if not reason.is_empty() else ("REVIEW" if review else ("CLEARED" if done else "AVAILABLE")),
			"done": done, "reason": reason})
	return stages
