extends Node
## Autoload singleton, registered as "TaskManager".
## Definitions live here; counters and payout receipts live in the account save.
signal progress_changed

const DAILY_TASKS: Array[Dictionary] = [
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

var _observed_day: String = ""
var _day_check_left: float = 0.0


func _ready() -> void:
	_observed_day = _today()
	PlayerManager.progress_changed.connect(_account_changed)


func _process(delta: float) -> void:
	_day_check_left -= delta
	if _day_check_left > 0.0:
		return
	_day_check_left = 1.0
	var today: String = _today()
	if today != _observed_day:
		_observed_day = today
		progress_changed.emit()


func _account_changed() -> void:
	progress_changed.emit()


func _today() -> String:
	return Time.get_date_string_from_system(true)


func get_active_tasks() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	var state: Dictionary = PlayerManager.mission_progress
	var stored: Variant = state.get("tasks", {}) if str(state.get("day", "")) == _today() else {}
	for definition: Dictionary in DAILY_TASKS:
		var task: Dictionary = definition.duplicate(true)
		var entry: Variant = stored.get(str(task.id), {}) if stored is Dictionary else {}
		var current: int = 0
		var rewarded: bool = false
		if entry is Dictionary:
			var raw: Variant = entry.get("current", 0)
			if (raw is int or raw is float) and is_finite(float(raw)):
				current = int(clampf(float(raw), 0.0, float(task.target)))
			var receipt: Variant = entry.get("rewarded", false)
			rewarded = receipt is bool and receipt
		# A receipt is authoritative for an already paid objective. Never pay on load.
		task.current = int(task.target) if rewarded else current
		task["rewarded"] = rewarded or current >= int(task.target)
		copy.append(task)
	return copy


func record_enemy_defeated(type: String) -> void:
	if type == "fast":
		_add_progress("defeat_fast", 1)


func record_stage_cleared() -> void:
	_add_progress("clear_stages", 1)


func _add_progress(task_id: String, amount: int) -> void:
	if task_id.is_empty() or amount <= 0 or Router.is_tutorial or PlayerManager.needs_tutorial():
		return
	var tasks: Array[Dictionary] = get_active_tasks()
	for task: Dictionary in tasks:
		if str(task.get("id", "")) != task_id:
			continue
		var target: int = int(task.get("target", 0))
		var current: int = int(task.get("current", 0))
		if current >= target:
			return
		current = mini(current + amount, target)
		task["current"] = current
		task["rewarded"] = current >= target
		var saved_tasks: Dictionary = {}
		for row: Dictionary in tasks:
			saved_tasks[str(row.id)] = {"current": int(row.current), "rewarded": bool(row.rewarded)}
		PlayerManager.mission_progress = {"day": _today(), "tasks": saved_tasks}
		# The receipt and reward are serialized in the same snapshot. Partial
		# counters write locally immediately, but use the existing cloud retry queue.
		if bool(task.rewarded):
			PlayerManager.add_credits(int(task.get("reward", 0)))
		else:
			SaveService.save_game(true, true)
		progress_changed.emit()
		return
