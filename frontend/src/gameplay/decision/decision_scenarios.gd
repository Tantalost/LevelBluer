class_name DecisionScenarios
extends RefCounted
## Read-only accessor for decision-based stage data.
## Kept separate from the 400-question TRACE bank in questions.json.

const DATA_PATH := "res://data/decision_scenarios.json"
const OUTCOME_SAFE := "SAFE"
const OUTCOME_RISKY := "RISKY"
const OUTCOME_CRITICAL := "CRITICAL"
const OUTCOMES: PackedStringArray = ["SAFE", "RISKY", "CRITICAL"]

static var _cache: Array = []
static var _loaded: bool = false


static func stage_key(module_id: String, stage_id: int) -> String:
	return "%s:%d" % [module_id.strip_edges(), stage_id]


static func is_decision_stage(module_id: String, stage_id: int) -> bool:
	return not get_stage(module_id, stage_id).is_empty()


static func get_stage(module_id: String, stage_id: int) -> Dictionary:
	_ensure_loaded()
	var mid: String = module_id.strip_edges()
	for i in _cache.size():
		var row: Variant = _cache[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = row as Dictionary
		if str(stage.get("module_id", "")).strip_edges() != mid:
			continue
		if int(stage.get("stage", -1)) != stage_id:
			continue
		return stage.duplicate(true)
	return {}


static func get_threats(module_id: String, stage_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stage: Dictionary = get_stage(module_id, stage_id)
	var stored: Variant = stage.get("threats", [])
	if typeof(stored) != TYPE_ARRAY:
		return result
	var rows: Array = stored as Array
	for i in rows.size():
		if typeof(rows[i]) == TYPE_DICTIONARY:
			result.append((rows[i] as Dictionary).duplicate(true))
	return result


static func dialogue_lines(stage: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stored: Variant = stage.get(key, [])
	if typeof(stored) != TYPE_ARRAY:
		return result
	var rows: Array = stored as Array
	for i in rows.size():
		if typeof(rows[i]) == TYPE_DICTIONARY:
			var line: Dictionary = rows[i] as Dictionary
			result.append({
				"speaker": str(line.get("speaker", "")).strip_edges(),
				"text": str(line.get("text", "")).strip_edges(),
			})
	return result


static func choice_outcome(threat: Dictionary, choice_index: int) -> String:
	var choices: Array = threat.get("choices", []) as Array
	if choice_index < 0 or choice_index >= choices.size():
		return ""
	var choice: Variant = choices[choice_index]
	if typeof(choice) != TYPE_DICTIONARY:
		return ""
	var outcome: String = str((choice as Dictionary).get("outcome", "")).strip_edges().to_upper()
	if OUTCOMES.has(outcome):
		return outcome
	return ""


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_cache = []
	if not FileAccess.file_exists(DATA_PATH):
		push_error("DecisionScenarios: missing " + DATA_PATH)
		return
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("DecisionScenarios: cannot open " + DATA_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("DecisionScenarios: JSON parse error in " + DATA_PATH)
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DecisionScenarios: root is not a Dictionary")
		return
	var stages: Variant = (data as Dictionary).get("stages", [])
	if typeof(stages) != TYPE_ARRAY:
		push_error("DecisionScenarios: stages is not an Array")
		return
	_cache = stages as Array
	print("[DecisionScenarios] Loaded ", _cache.size(), " decision stage(s)")
