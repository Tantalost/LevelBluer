extends RefCounted
## Presentation snapshot only. Opening Progress never writes to player state.

static func mastery_status(value: float, assessed: bool) -> String:
	if not assessed:
		return "Not assessed"
	if value < PlayerManager.AT_RISK_MASTERY:
		return "Needs practice"
	if value < PlayerManager.PROFICIENT_MASTERY:
		return "Developing"
	return "Proficient"

static func snapshot() -> Dictionary:
	var mastery := AuthService.progress_mastery_snapshot()
	var assessed := 0
	var total_mastery := 0.0
	for row in mastery:
		row["status"] = mastery_status(float(row.value), bool(row.assessed))
		if row.assessed:
			assessed += 1
			total_mastery += float(row.value)
	var stages: Array[Dictionary] = []
	var cleared := 0
	for id in range(1, 11):
		var config := StageManager.get_stage_config(id)
		if config.is_empty():
			continue
		var done := PlayerManager.has_cleared_stage(id)
		var reason := StageManager.access_reason(id)
		if done:
			cleared += 1
		stages.append({"id": id, "name": str(config.get("name", "Stage %d" % id)), "done": done,
			"status": "Completed" if done else ("Available" if reason.is_empty() else "Locked"), "reason": reason})
	var modules: Array[Dictionary] = []
	var lesson_done := 0
	var lesson_total := 0
	var previous_complete := true
	for module in LessonCatalog.modules():
		var id := str(module.id)
		var lessons := LessonCatalog.lessons_for(id)
		var done := clampi(PlayerManager.get_lesson_progress(id), 0, lessons.size())
		var pretest := AuthService.has_module_pretest(id)
		var state := "Completed" if done == lessons.size() else ("Locked" if not previous_complete else ("Available" if pretest else "Pre-test required"))
		modules.append({"id": id, "name": str(module.title), "done": done, "total": lessons.size(),
			"lessons": lessons, "status": state, "pretest": pretest, "unlocked": previous_complete})
		previous_complete = done == lessons.size()
		lesson_done += done
		lesson_total += lessons.size()
	return {"rank": AuthService.rank_title(), "points": AuthService.points(),
		"rank_index": AuthService.RANKS.find(AuthService.rank_title()), "rank_value": AuthService.exp_into_rank(),
		"rank_span": AuthService.exp_rank_span(), "next_points": AuthService.next_rank_points(),
		"max_rank": AuthService.rank_title() == AuthService.RANKS[-1],
		"mastery": mastery, "assessed": assessed, "average": total_mastery / assessed if assessed > 0 else 0.0,
		"stages": stages, "stage_done": cleared, "stage_total": stages.size(),
		"modules": modules, "lesson_done": lesson_done, "lesson_total": lesson_total}
