extends RefCounted
## Presentation only: reads the same records and access rules as playable screens.

static func mastery_status(value: float, assessed: bool) -> String:
	if not assessed: return "Not assessed"
	if value < PlayerManager.AT_RISK_MASTERY: return "Needs practice"
	if value < PlayerManager.PROFICIENT_MASTERY: return "Developing"
	return "Proficient"

static func snapshot() -> Dictionary:
	var mastery: Array[Dictionary] = AuthService.progress_mastery_snapshot()
	var assessed: int = 0
	var total_mastery: float = 0.0
	for row: Dictionary in mastery:
		row["status"] = mastery_status(float(row.value), bool(row.assessed))
		if row.assessed:
			assessed += 1
			total_mastery += float(row.value)
	var chapters: Array[Dictionary] = []
	var chapter_done: int = 0
	for number: int in range(1, 6):
		var id: String = "mod_01_ch_%02d" % number
		var definition: GDScript = PlayerManager.story_definition(id)
		var record: Dictionary = PlayerManager.story_checkpoint(id, false)
		var done: bool = bool(record.get("completed", false))
		var unlocked: bool = PlayerManager.story_unlocked(id)
		var reason: String = "Complete Chapter %d first." % (number - 1)
		if not PlayerManager.is_module_deploy_unlocked("mod_01"):
			reason = "Complete the first Email Tricks lesson to unlock Deploy."
		if done: chapter_done += 1
		chapters.append({"id":id, "number":number, "name":definition.TITLE, "done":done,
			"status":"Completed" if done else ("Available" if unlocked else "Locked"),
			"reason":"" if unlocked else reason,
			"assistance":PlayerManager.StoryPerks.status(record.get("perk_run", {}), bool(record.get("hint_used", false)))})
	var modules: Array[Dictionary] = []
	var lesson_done: int = 0
	var lesson_total: int = 0
	var checkpoint_done: int = 0
	for module: Dictionary in LessonCatalog.modules():
		var id: String = str(module.id)
		var lessons: Array[Dictionary] = LessonCatalog.lessons_for(id)
		var done: int = clampi(PlayerManager.get_lesson_progress(id), 0, lessons.size())
		var unlocked: bool = PlayerManager.can_access_lesson_module(id)
		var pretest: bool = AuthService.has_module_pretest(id)
		var passed: bool = PlayerManager.has_lesson_post_quiz(id)
		var state: String = "Completed" if done == lessons.size() else ("Locked" if not unlocked else ("Available" if pretest else "Pre-test required"))
		var checkpoint: String = "Passed" if passed else ("Ready" if unlocked and done == lessons.size() else "Locked")
		if passed: checkpoint_done += 1
		modules.append({"id":id, "name":str(module.title), "done":done, "total":lessons.size(),
			"lessons":lessons, "status":state, "pretest":pretest, "unlocked":unlocked,
			"checkpoint":checkpoint, "passed":passed,
			"best":clampi(int(PlayerManager.lesson_post_quiz_scores.get(id, 0)), 0, 25)})
		lesson_done += done
		lesson_total += lessons.size()
	var signed_in: bool = AuthService.is_signed_in()
	var pending: bool = signed_in and (StudentDatabase.has_pending_sync(AuthService.participant_code()) or not PlayerManager.learning_events.is_empty())
	return {"account":AuthService.display_name() if signed_in else "Guest", "signed_in":signed_in,
		"sync_pending":pending, "sync_label":("Changes waiting to sync" if pending else "No pending changes") if signed_in else "On this device only",
		"rank":AuthService.rank_title(), "points":AuthService.points(),
		"rank_index":AuthService.RANKS.find(AuthService.rank_title()), "rank_value":AuthService.exp_into_rank(),
		"rank_span":AuthService.exp_rank_span(), "next_points":AuthService.next_rank_points(),
		"max_rank":AuthService.rank_title() == AuthService.RANKS[-1],
		"mastery":mastery, "assessed":assessed, "average":total_mastery / assessed if assessed > 0 else 0.0,
		"chapters":chapters, "chapter_done":chapter_done, "chapter_total":chapters.size(),
		"modules":modules, "lesson_done":lesson_done, "lesson_total":lesson_total,
		"checkpoint_done":checkpoint_done, "checkpoint_total":modules.size(), "next":next_step(modules)}

static func next_step(modules: Array[Dictionary]) -> Dictionary:
	var practice: Dictionary = LessonCatalog.practice_recommendation(PlayerManager)
	if not practice.is_empty() and float(practice.mastery) < PlayerManager.PROFICIENT_MASTERY:
		return practice_step(practice)
	for module: Dictionary in modules:
		if not module.unlocked: continue
		if int(module.done) < int(module.total):
			return {"title":("Continue " if module.pretest else "Start ") + str(module.name),
				"reason":"Lesson %d of %d is next." % [int(module.done) + 1, int(module.total)] if module.pretest else "Take this topic's pre-test to establish your starting estimate.",
				"button":"OPEN LESSON", "args":{"module_id":module.id}}
		if not module.passed:
			return {"title":str(module.name) + " checkpoint", "reason":"Your lessons are complete. The module checkpoint is your next step.",
				"button":"OPEN CHECKPOINT", "args":{"module_id":module.id, "post_quiz":true}}
	if not practice.is_empty(): return practice_step(practice)
	return {"title":"Review Email Tricks", "reason":"Revisit a lesson and practise spotting suspicious requests.",
		"button":"OPEN LESSON", "args":{"module_id":"mod_01", "review":true}}

static func practice_step(practice: Dictionary) -> Dictionary:
	return {"title":"Practise " + str(practice.domain).capitalize(),
		"reason":"Your lowest eligible BKT estimate is %d%%. Start five questions focused on this topic, with broader review when available." % roundi(float(practice.mastery) * 100),
		"button":"START PRACTICE", "args":{"practice":true}}
