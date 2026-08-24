extends Node
## Autoload singleton, registered as "TaskManager".
## In-memory daily directives for this session. Not persisted this milestone.

var daily_tasks: Array[Dictionary] = [
	{
		"id": "defeat_fast",
		"title": "Intercept 50 Fast Packets",
		"target": 50,
		"current": 0,
		"reward": 100,
	},
	{
		"id": "clear_stages",
		"title": "Clear 3 Stages",
		"target": 3,
		"current": 0,
		"reward": 250,
	},
]


func get_active_tasks() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for i in daily_tasks.size():
		copy.append(daily_tasks[i].duplicate())
	return copy


func record_enemy_defeated(type: String) -> void:
	if type == "fast":
		_add_progress("defeat_fast", 1)


func record_stage_cleared() -> void:
	_add_progress("clear_stages", 1)


func _add_progress(task_id: String, amount: int) -> void:
	if task_id.is_empty() or amount <= 0:
		return
	for i in daily_tasks.size():
		var task: Dictionary = daily_tasks[i]
		if str(task.get("id", "")) != task_id:
			continue
		var target: int = int(task.get("target", 0))
		var current: int = int(task.get("current", 0))
		if current >= target:
			return
		current = mini(current + amount, target)
		task["current"] = current
		daily_tasks[i] = task
		if current >= target:
			PlayerManager.add_credits(int(task.get("reward", 0)))
		return
