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
	return _lines_from(stage.get(key, []))


## Same shape as dialogue_lines(), but reads from the stage's nested "finale"
## config instead of a top-level key. Kept separate so a stage without a
## finale (every stage but the last of a module) never needs to carry these
## keys at all.
static func finale_dialogue_lines(stage: Dictionary, key: String) -> Array[Dictionary]:
	return _lines_from(finale_config(stage).get(key, []))


static func _lines_from(stored: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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


## A stage-level FINAL CONTAINMENT encounter: a mandatory Tower Defense wave
## after every threat is resolved, before the stage can clear. Data-driven so
## any decision stage can opt in — no module/stage-number checks anywhere
## else in the engine. Absent or malformed data behaves exactly like a stage
## with no finale.
static func finale_config(stage: Dictionary) -> Dictionary:
	var stored: Variant = stage.get("finale", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


static func has_finale(stage: Dictionary) -> bool:
	return bool(finale_config(stage).get("enabled", false))


## Mirrors breach_hp_multiplier(): the finale's own Tower Defense encounter
## scales enemy HP the same data-driven way a RISKY breach does, just from a
## different field so authoring a finale never collides with a stage's own
## breach_hp_multiplier.
static func finale_hp_multiplier(stage: Dictionary, fallback: float) -> float:
	var stored: Variant = finale_config(stage).get("enemy_hp_multiplier", fallback)
	var scale: float = float(stored)
	return scale if scale > 0.0 else fallback


## Shared by every presentation of decision-story RISKY breaches (the legacy
## LevelManager flow and the live geometric scene) so the fallback logic for
## an unauthored/invalid multiplier lives in exactly one place.
static func breach_hp_multiplier(stage: Dictionary, fallback: float) -> float:
	var stored: Variant = stage.get("breach_hp_multiplier", fallback)
	var scale: float = float(stored)
	return scale if scale > 0.0 else fallback


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
