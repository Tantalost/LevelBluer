extends RefCounted
## Read-only recommendations and milestones; no rewards or unlock changes.

static func build(progress: Dictionary) -> Dictionary:
	var milestones := [
		{"title": "FIRST LESSON", "description": "Complete one lesson topic.", "earned": progress.lesson_done > 0},
		{"title": "FIRST DEFENSE", "description": "Clear one authored stage.", "earned": progress.stage_done > 0},
		{"title": "MODULE 1 SECURED", "description": "Clear all ten Module 1 stages.", "earned": progress.stage_total > 0 and progress.stage_done == progress.stage_total},
		{"title": "ARCHIVE GRADUATE", "description": "Complete all thirty lesson topics.", "earned": progress.lesson_total > 0 and progress.lesson_done == progress.lesson_total},
	]
	var strongest: Dictionary = {}
	var practice: Dictionary = {}
	for row in progress.mastery:
		if not row.assessed:
			continue
		if strongest.is_empty() or row.value > strongest.value:
			strongest = row
		if practice.is_empty() or row.value < practice.value:
			practice = row
	var next: Dictionary = {}
	# Only suggest a deployment the existing access rules currently allow.
	for stage in progress.stages:
		if not stage.done and stage.status == "Available":
			next = {"title": "DEFEND THE NETWORK", "body": "Stage %d / %s is available. Choose it in Deploy when you are ready." % [stage.id, stage.name], "action": "OPEN DEPLOY", "route": &"stage_select"}
			break
	if next.is_empty():
		for module in progress.modules:
			if module.done < module.total and module.unlocked:
				var pretest: bool = not module.pretest
				next = {"title": "ESTABLISH YOUR BASELINE" if pretest else "CONTINUE YOUR TRAINING",
					"body": ("%s / Complete the module pre-test to begin its lessons." if pretest else "%s / %d of %d topics complete. Continue in the Lesson Archive.") % ([module.name] if pretest else [module.name, module.done, module.total]),
					"action": "OPEN LESSONS", "route": &"lessons"}
				break
	if next.is_empty():
		if not practice.is_empty() and practice.value < PlayerManager.PROFICIENT_MASTERY:
			next = {"title": "SHARPEN YOUR KNOWLEDGE", "body": "Review %s in the Codex. It is your lowest assessed topic; the estimate is not a quiz score." % practice.name, "action": "OPEN CODEX", "route": &"codex"}
		else:
			var all_complete: bool = progress.stage_done == progress.stage_total and progress.lesson_done == progress.lesson_total
			next = {"title": "MISSION RECORD COMPLETE" if all_complete else "REVIEW YOUR JOURNEY",
				"body": "All currently authored stages and lesson topics are complete. Explore your mastery and achievements." if all_complete else "Check your Journey for remaining stages and their access requirements.",
				"action": "VIEW PROGRESS", "route": &"progress"}
	return {"next": next, "milestones": milestones, "strongest": strongest, "practice": practice}
