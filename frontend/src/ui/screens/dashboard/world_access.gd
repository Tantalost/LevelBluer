extends RefCounted
## Read-only dashboard guidance. StageManager remains the authority for deployment.

static func snapshot() -> Dictionary:
	var modules: Array[Dictionary] = []
	var lessons := LessonCatalog.modules()
	for i in lessons.size():
		var id := str(lessons[i].id)
		var total := LessonCatalog.lesson_count(id)
		var done := clampi(PlayerManager.get_lesson_progress(id), 0, total)
		var accessible := PlayerManager.is_module_deploy_unlocked(id) if i == 0 else PlayerManager.get_lesson_progress(str(lessons[i - 1].id)) >= LessonCatalog.lesson_count(str(lessons[i - 1].id))
		var required := 0 if i == 0 else i - 1
		modules.append({"title": "MODULE %d / %s" % [i + 1, lessons[i].title], "status": "AVAILABLE" if accessible else "LOCKED",
			"reason": ("Module access unlocked." if accessible else "Complete Module %d (%s) lessons to unlock module access." % [required + 1, lessons[required].title]) + (" Stages coming soon; lesson completion cannot unlock unauthored stages." if i > 0 else ""),
			"done": done, "total": total})
	var stages: Array[Dictionary] = []
	var next: Dictionary = {}
	for id in range(1, 11):
		var config := StageManager.get_stage_config(id)
		if config.is_empty():
			continue
		var reason := StageManager.access_reason(id, "mod_01")
		var done := PlayerManager.has_cleared_stage("mod_01", id)
		# A completed stage may still have a replay lock; do not hide that restriction.
		var status := "LOCKED" if not reason.is_empty() else ("CLEARED" if done else "AVAILABLE")
		var row := {"id": id, "title": "STAGE %d / %s" % [id, config.get("name", "")], "status": status, "done": done, "reason": reason}
		stages.append(row)
		if next.is_empty() and not done:
			next = row
	var result := {"modules": modules, "stages": stages, "badge": "!", "route": &"lessons", "action": "OPEN LESSONS", "locked": true}
	if PlayerManager.needs_tutorial():
		result.merge({"heading": "TUTORIAL REQUIRED", "short": "Use DEPLOY to\nfinish the tutorial", "explanation": "Complete the guided tutorial using Deploy before opening World."})
	elif not PlayerManager.is_module_deploy_unlocked("mod_01"):
		var done := clampi(PlayerManager.get_lesson_progress("mod_01"), 0, LessonCatalog.lesson_count("mod_01"))
		var pretest := AuthService.has_module_pretest("mod_01")
		result.merge({"heading": "MODULE 1 LOCKED", "short": "Finish lessons\n%d / %d complete" % [done, LessonCatalog.lesson_count("mod_01")],
			"explanation": "Module 1 deployment is locked. " + ("Complete its pre-test in Lessons, then finish its lesson topics, quizzes and simulations." if not pretest else "Finish the Module 1 lesson topics, quizzes and simulations in Lessons.")})
	elif next.is_empty():
		result.merge({"heading": "MODULE 1 CLEARED", "short": "More stages\ncoming soon", "explanation": "All authored Module 1 stages are cleared. Later modules have no authored stages yet; completing lessons will not create those stages."})
		result.locked = false
		result.badge = "OK"
		result.route = &"progress"
		result.action = "VIEW PROGRESS"
	elif next.status == "LOCKED":
		var explanation := str(next.reason)
		var short := "Open briefing\nfor requirements"
		if int(next.id) > PlayerManager.max_stage_cleared("mod_01") + 1:
			short = "Clear preceding\nstages in DEPLOY"
			result.route = &"stage_select"
			result.action = "OPEN DEPLOY"
		elif PlayerManager.is_stage_locked("mod_01", int(next.id)):
			short = "Review lessons\nExam lock active"
			explanation = "An exam lock is active. Review the required material in Lessons. The current game does not automatically clear this recorded lock when you review."
		result.merge({"heading": "STAGE %d LOCKED" % next.id, "short": short, "explanation": str(next.title) + "\n" + explanation})
	else:
		result.merge({"heading": "STAGE %d READY" % next.id, "short": "Open DEPLOY\nTap for access info", "explanation": str(next.title) + " is available. Later stages can still require preceding clears or lesson completion; see the access list below."})
		result.locked = false
		result.badge = "GO"
		result.route = &"stage_select"
		result.action = "OPEN DEPLOY"
	return result
