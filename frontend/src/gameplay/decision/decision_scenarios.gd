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


## memory: the player's current story memory snapshot (a flat key -> scalar
## dictionary — see get_story_memory_snapshot() on the account/profile
## singleton) — defaults to an empty dictionary, which is exactly the
## "no memory system" behavior every
## existing call site had before conditional dialogue existed (any line
## authoring "when" would be dropped since no key can ever match; every
## unconditional line is completely unaffected either way).
static func dialogue_lines(stage: Dictionary, key: String, memory: Dictionary = {}) -> Array[Dictionary]:
	return filter_lines_by_memory(_lines_from(stage.get(key, [])), memory)


## Same shape as dialogue_lines(), but reads from the stage's nested "finale"
## config instead of a top-level key. Kept separate so a stage without a
## finale (every stage but the last of a module) never needs to carry these
## keys at all.
static func finale_dialogue_lines(stage: Dictionary, key: String, memory: Dictionary = {}) -> Array[Dictionary]:
	return filter_lines_by_memory(_lines_from(finale_config(stage).get(key, [])), memory)


static func _lines_from(stored: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(stored) != TYPE_ARRAY:
		return result
	var rows: Array = stored as Array
	for i in rows.size():
		if typeof(rows[i]) == TYPE_DICTIONARY:
			var line: Dictionary = rows[i] as Dictionary
			# "emotion" and "when" are optional presentation/reactivity
			# metadata passed through unvalidated here — the presentation
			# layer normalizes emotion, and filter_lines_by_memory()
			# evaluates "when", exactly like every existing line that never
			# authors either at all.
			result.append({
				"speaker": str(line.get("speaker", "")).strip_edges(),
				"text": str(line.get("text", "")).strip_edges(),
				"emotion": str(line.get("emotion", "")).strip_edges(),
				"when": (line.get("when", {}) as Dictionary) if typeof(line.get("when", {})) == TYPE_DICTIONARY else {},
			})
	return result


## Minimal, data-driven condition check for reactive dialogue/story_event
## (see the "Character Memory / Reactive Dialogue" milestone). Deliberately
## NOT a scripting language: only exact key/value matches across every
## authored key (implicit AND), plus one small negation form — never nested
## boolean composition, never arbitrary code evaluation. An empty/absent
## "when" is always true (the line/event is unconditional, exactly like
## today). A referenced memory key that was never set is always false —
## never a crash, never a guessed default.
static func condition_met(when: Dictionary, memory: Dictionary) -> bool:
	if when.is_empty():
		return true
	for key in when.keys():
		var expected: Variant = when[key]
		var actual: Variant = memory.get(key, null)
		# {"key": {"not": value}} matches everything EXCEPT that one value,
		# including "never set at all" — the one exclusion form simple
		# enough to keep this a plain key/value matcher, not a parser.
		if typeof(expected) == TYPE_DICTIONARY and (expected as Dictionary).has("not"):
			if actual == (expected as Dictionary)["not"]:
				return false
			continue
		if actual != expected:
			return false
	return true


static func filter_lines_by_memory(lines: Array[Dictionary], memory: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in lines.size():
		var line: Dictionary = lines[i]
		if condition_met(line.get("when", {}) as Dictionary, memory):
			result.append(line)
	return result


## Optional "inspect evidence, reach a conclusion" moment before a threat's
## normal operational choices become actionable, authored as an
## "investigation" block on the threat itself (same placement convention as
## "timer"/"call"). Absent, malformed, or enabled=false all mean the
## existing flow unchanged — most threats have no investigation at all.
## First version: single-selection only, never BKT/TD/Game Over/outcome —
## see decision_investigation_panel.gd.
static func investigation_config(threat: Dictionary) -> Dictionary:
	var stored: Variant = threat.get("investigation", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


## True only when explicitly enabled AND at least one well-formed item
## parses (see investigation_items) — an authored-but-empty/malformed block
## is treated exactly like no investigation at all, never a panel with
## nothing to select.
static func has_investigation(threat: Dictionary) -> bool:
	if not bool(investigation_config(threat).get("enabled", false)):
		return false
	return not investigation_items(threat).is_empty()


static func investigation_title(threat: Dictionary) -> String:
	var value: String = str(investigation_config(threat).get("title", "")).strip_edges().to_upper()
	return value if not value.is_empty() else "INVESTIGATION"


static func investigation_prompt(threat: Dictionary) -> String:
	return str(investigation_config(threat).get("prompt", "")).strip_edges()


## Each item's "id" is a stable, authored identifier (see the milestone's own
## Case-Board-readiness rule) — future evidence integration can reference
## these ids without rewriting content. An item missing an id or a label is
## dropped rather than shown half-broken; "valid"/"analysis" default to
## false/empty so a malformed item never silently claims to verify anything.
static func investigation_items(threat: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stored: Variant = investigation_config(threat).get("items", [])
	if typeof(stored) != TYPE_ARRAY:
		return result
	for entry in (stored as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry as Dictionary
		var id: String = str(item.get("id", "")).strip_edges()
		var label: String = str(item.get("label", "")).strip_edges()
		if id.is_empty() or label.is_empty():
			continue
		result.append({
			"id": id,
			"label": label,
			"valid": bool(item.get("valid", false)),
			"analysis": str(item.get("analysis", "")).strip_edges(),
		})
	return result


## Reuses story_event_lines()'s exact parsing (same types, same safety, same
## "when" support) for the optional short narrative beat shown right after
## the investigation's valid item is confirmed, before the operational
## choices become actionable.
static func investigation_resolved_story_event_lines(threat: Dictionary, memory: Dictionary = {}) -> Array[Dictionary]:
	var cfg: Dictionary = investigation_config(threat)
	if not cfg.has("resolved_story_event"):
		return []
	return story_event_lines({"story_event": cfg.get("resolved_story_event")}, memory)


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


## Optional per-threat countdown, authored as a "timer" block on the threat
## itself (not on a choice — the deadline belongs to the whole decision, not
## any one option). Absent, malformed, or enabled=false all mean exactly the
## same thing: this threat is untimed, which is — and must remain — the
## overwhelming default. Reserve a timer for a threat where the ATTACK
## itself is what's manufacturing urgency (a caller demanding immediate
## action, a transfer allegedly processing), never for ordinary
## investigation, reading evidence, or emotional dialogue. Recommend at most
## ~0-2 timed incidents per stage — not a timer on every decision.
static func timer_config(threat: Dictionary) -> Dictionary:
	var stored: Variant = threat.get("timer", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


static func has_timer(threat: Dictionary) -> bool:
	return bool(timer_config(threat).get("enabled", false))


static func timer_seconds(threat: Dictionary, fallback: float = 15.0) -> float:
	var stored: Variant = timer_config(threat).get("seconds", fallback)
	var seconds: float = float(stored)
	return seconds if seconds > 0.0 else fallback


static func timer_label(threat: Dictionary) -> String:
	return str(timer_config(threat).get("label", "")).strip_edges()


## The outcome a timeout commits, deterministically — never a randomly/
## shuffle-dependent pick. Defaults to RISKY (pressure-induced hesitation),
## but any of SAFE/RISKY/CRITICAL may be authored. An invalid value also
## falls back to RISKY rather than silently doing nothing.
static func timer_timeout_outcome(threat: Dictionary) -> String:
	var raw: String = str(timer_config(threat).get("timeout_outcome", OUTCOME_RISKY)).strip_edges().to_upper()
	return raw if OUTCOMES.has(raw) else OUTCOME_RISKY


## Reuses story_event_lines()'s exact parsing (same types, same safety) for
## the optional visible consequence shown when a timer expires.
static func timer_timeout_story_event_lines(threat: Dictionary, memory: Dictionary = {}) -> Array[Dictionary]:
	var cfg: Dictionary = timer_config(threat)
	if not cfg.has("timeout_story_event"):
		return []
	return story_event_lines({"story_event": cfg.get("timeout_story_event")}, memory)


## Optional phone-call presentation for a threat's decision screen, authored
## as a "call" block on the threat itself (same shape/placement as "timer").
## Absent, malformed, or enabled=false all mean the existing plain decision
## presentation, unchanged — most threats have no call at all. This only
## renders whatever the CHARACTER'S PHONE displays (caller name/number/
## status as authored); it never carries or exposes whether that identity is
## actually legitimate or spoofed.
static func call_config(threat: Dictionary) -> Dictionary:
	var stored: Variant = threat.get("call", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


static func has_call(threat: Dictionary) -> bool:
	return bool(call_config(threat).get("enabled", false))


static func call_caller(threat: Dictionary) -> String:
	var value: String = str(call_config(threat).get("caller", "")).strip_edges().to_upper()
	return value if not value.is_empty() else "UNKNOWN CALLER"


static func call_number(threat: Dictionary) -> String:
	var value: String = str(call_config(threat).get("number", "")).strip_edges()
	return value if not value.is_empty() else "UNKNOWN NUMBER"


static func call_status(threat: Dictionary) -> String:
	var value: String = str(call_config(threat).get("status", "")).strip_edges().to_upper()
	return value if not value.is_empty() else "CONNECTED"


static func call_show_duration(threat: Dictionary) -> bool:
	return bool(call_config(threat).get("show_duration", true))


## Whether this call's authored END CALL control is offered at all. Ending a
## call and deciding what to do next are separate concepts — this never
## implies, selects, or biases any outcome (see call_end_story_event_lines);
## it only lets the player stop the call as its own authored interaction.
static func call_allow_end(threat: Dictionary) -> bool:
	return bool(call_config(threat).get("allow_end_call", false))


## Reuses story_event_lines()'s exact parsing (same types, same safety) for
## the optional narrative beat shown when the player ends the call.
static func call_end_story_event_lines(threat: Dictionary, memory: Dictionary = {}) -> Array[Dictionary]:
	var cfg: Dictionary = call_config(threat)
	if not cfg.has("call_end_story_event"):
		return []
	return story_event_lines({"story_event": cfg.get("call_end_story_event")}, memory)


## Optional narrative feedback shown once, right after a committed choice's
## own consequence/explanation text and before the existing SAFE/RISKY/
## CRITICAL flow continues (see DecisionStageController — this never changes
## which outcome was chosen; it is presentation only). Authored on a choice
## as "story_event": a single event object or an array of them, each turned
## into one or two ordinary dialogue lines (reusing the existing speaker/
## text/emotion presentation, never a new UI). Absent, malformed, or
## unrecognized data safely produces zero lines, so old stages are unaffected.
const STORY_EVENT_TYPES: PackedStringArray = ["notification", "status", "message", "dialogue"]

## memory: same story-memory snapshot as dialogue_lines() — reuses the exact
## same condition_met() evaluator, never a second one (see the milestone's
## explicit "one generic condition helper" rule). Filtered per EVENT, not
## per output line: a status/notification's title+body always show or hide
## together, never split.
static func story_event_lines(choice: Dictionary, memory: Dictionary = {}) -> Array[Dictionary]:
	var stored: Variant = choice.get("story_event", null)
	if stored == null:
		return []
	var events: Array = []
	if typeof(stored) == TYPE_ARRAY:
		events = stored as Array
	elif typeof(stored) == TYPE_DICTIONARY:
		events = [stored]
	else:
		return []
	var result: Array[Dictionary] = []
	for entry in events:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = entry as Dictionary
		var when: Dictionary = (event.get("when", {}) as Dictionary) if typeof(event.get("when", {})) == TYPE_DICTIONARY else {}
		if not condition_met(when, memory):
			continue
		result.append_array(_story_event_to_lines(event))
	return result


static func _story_event_to_lines(event: Dictionary) -> Array[Dictionary]:
	var type_id: String = str(event.get("type", "")).strip_edges().to_lower()
	if not STORY_EVENT_TYPES.has(type_id):
		return []
	var result: Array[Dictionary] = []
	if type_id == "dialogue":
		var line_text: String = str(event.get("text", "")).strip_edges()
		if line_text.is_empty():
			return []
		result.append({
			"speaker": str(event.get("speaker", "")).strip_edges(),
			"text": line_text,
			"emotion": str(event.get("emotion", "")).strip_edges(),
		})
		return result
	# notification / status / message all share the same shape: an optional
	# title line followed by an optional body line, both narrated (no
	# speaker) — a phone/security-style alert, a state readout, and an
	# incoming message all read fine through the same two plain lines.
	var title: String = str(event.get("title", "")).strip_edges()
	var body: String = str(event.get("text", "")).strip_edges()
	if not title.is_empty():
		result.append({"speaker": "", "text": title})
	if not body.is_empty():
		result.append({"speaker": "", "text": body})
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


## Optional persistent story-memory write, authored explicitly on a choice
## as "memory": {key: value, ...} (see the account/profile singleton's own
## story_memory dictionary). Absent means no memory change at all, exactly
## like every choice before this
## system existed — SAFE/RISKY/CRITICAL are never auto-derived into memory;
## only what's explicitly authored here is ever written. Values are read
## as-authored (bool/String/int/float); anything else is safely dropped
## rather than corrupting story memory with an unsupported type.
static func choice_memory(choice: Dictionary) -> Dictionary:
	var stored: Variant = choice.get("memory", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	var result: Dictionary = {}
	var source: Dictionary = stored as Dictionary
	for key in source.keys():
		var k: String = str(key).strip_edges()
		if k.is_empty():
			continue
		var value: Variant = source[key]
		var value_type: int = typeof(value)
		if value_type == TYPE_BOOL or value_type == TYPE_STRING or value_type == TYPE_STRING_NAME or value_type == TYPE_INT or value_type == TYPE_FLOAT:
			result[k] = value
	return result


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
