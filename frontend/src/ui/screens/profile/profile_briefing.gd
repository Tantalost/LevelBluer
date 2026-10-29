extends RefCounted
## Read-only recommendations and milestones; no rewards or unlock changes.

static func build(progress: Dictionary) -> Dictionary:
	var milestones := [
		{"title": "FIRST LESSON", "description": "Complete one lesson topic.", "earned": progress.lesson_done > 0},
		{"title": "FIRST CASE", "description": "Complete one story chapter.", "earned": progress.chapter_done > 0},
		{"title": "MODULE 1 SECURED", "description": "Complete all five Email Tricks chapters.", "earned": progress.chapter_total > 0 and progress.chapter_done == progress.chapter_total},
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
	for chapter: Dictionary in progress.chapters:
		if not chapter.done and chapter.status == "Available":
			next = {"title": "CONTINUE THE STORY", "body": "Chapter %d / %s is available. Choose it in Deploy when you are ready." % [chapter.number, chapter.name], "action": "OPEN DEPLOY", "route": &"stage_select"}
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
			var all_complete: bool = progress.chapter_done == progress.chapter_total and progress.lesson_done == progress.lesson_total and progress.checkpoint_done == progress.checkpoint_total
			next = {"title": "MISSION RECORD COMPLETE" if all_complete else "REVIEW YOUR JOURNEY",
				"body": "All currently authored chapters, lessons and checkpoints are complete. Explore your mastery and achievements." if all_complete else "Check your Journey for remaining chapters, lessons and checkpoints.",
				"action": "VIEW PROGRESS", "route": &"progress"}
	return {"next": next, "milestones": milestones, "strongest": strongest, "practice": practice}
