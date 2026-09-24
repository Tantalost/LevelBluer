extends SceneTree
## Regression suite for the "Boss / Final-Stage Scenario Framework" milestone.
## Deliberately small: the exhaustive Stage 9 win/loss/retry/BKT/Stage-10
## behavior for both modules is already covered end to end by
## verify_decision_stage.gd's _test_stage9()/_test_module2_stage9() (which
## also now covers reload mid-finale) — this file only adds what those don't:
## a structural guarantee that no second boss/finale engine exists, and that
## unauthored "boss" metadata (this milestone deliberately does not add any
## production schema for it — see decision_scenarios.gd's finale_config()
## doc comment) can never affect gameplay even if someone adds it later.
##
## Run headless:  godot --headless --script res://src/tools/verify_boss_finale.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func _run() -> void:
	_test_stage9_uses_the_generic_finale_system()
	_test_no_second_boss_engine_exists()
	_test_unauthored_boss_metadata_is_inert()

	print("BOSS_FINALE_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


## The one thing worth re-confirming at the data layer here (full live-scene
## coverage lives in verify_decision_stage.gd): both existing boss stages are
## driven entirely by the SAME data-driven has_finale()/finale_config() any
## stage can opt into — never a stage-number check, never a second schema.
func _test_stage9_uses_the_generic_finale_system() -> void:
	print("== Module 1/2 Stage 9 already use the existing generic finale system, not a boss-specific one ==")
	var mod1_stage9: Dictionary = DecisionScenarios.get_stage("mod_01", 9)
	var mod2_stage9: Dictionary = DecisionScenarios.get_stage("mod_02", 9)
	check(DecisionScenarios.has_finale(mod1_stage9) and DecisionScenarios.get_threats("mod_01", 9).size() == 3,
		"[Boss] Module 1 Stage 9: 3 operational incidents + the generic finale, exactly the authored boss shape")
	check(DecisionScenarios.has_finale(mod2_stage9) and DecisionScenarios.get_threats("mod_02", 9).size() == 3,
		"[Boss] Module 2 Stage 9: 3 operational incidents + the generic finale, exactly the authored boss shape")
	# has_finale() is purely data-driven — Stage 8 of the same module (no
	# finale authored) proves it's never a hardcoded "stage == 9" check.
	check(not DecisionScenarios.has_finale(DecisionScenarios.get_stage("mod_01", 8)), "[Boss] Finale capability is opt-in per stage, never implied by being 'the last story stage'")
	check(not DecisionScenarios.get_stage("mod_03", 1).has("finale"), "[Boss] Module 3 Stage 1 (not a boss stage) authors no finale block at all")


## Grep-based structural guarantee (same pattern already used elsewhere in
## this project for isolation checks) that nobody has since added a second
## finale/boss controller, combat engine, or BKT rule. A boss stage must
## reach Tower Defense only through DecisionStageController's own
## begin_finale()/win_finale()/fail_finale() — the exact same path a RISKY
## breach uses — never a parallel implementation.
func _test_no_second_boss_engine_exists() -> void:
	print("== No boss-specific controller, combat engine, or second finale/BKT system exists ==")
	var decision_dir := "res://src/gameplay/decision/"
	var dir := DirAccess.open(decision_dir)
	check(dir != null, "decision/ directory is readable for the structural check")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var checked_any := false
	while name != "":
		if name.ends_with(".gd"):
			checked_any = true
			var text: String = FileAccess.get_file_as_string(decision_dir + name)
			var lower: String = name.to_lower()
			check(not lower.contains("boss"), "No file in decision/ is named as a boss-specific script (%s)" % name)
			check(not text.contains("class_name Boss") and not text.contains("BossController") and not text.contains("BossCombat"),
				"%s does not define or reference a second boss controller/combat engine" % name)
		name = dir.get_next()
	dir.list_dir_end()
	check(checked_any, "At least one decision/ script was actually scanned")
	# The finale system itself lives in exactly one place: the shared
	# DecisionStageController, reused by both engines.
	var controller_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_stage_controller.gd")
	check(controller_text.contains("func begin_finale") and controller_text.contains("func win_finale") and controller_text.contains("func fail_finale"),
		"The one finale state machine (begin/win/fail) lives in the shared DecisionStageController")


## This milestone deliberately does NOT add a "boss": {...} production
## schema (finale_config()'s own fields already cover presentation/
## identification — see its doc comment). This proves that guarantee holds
## even if authored content, or a future author, adds an unrecognized
## "boss" key anyway: nothing in the data layer reads it, so it can never
## change BKT, outcome logic, TD rules, or progression.
func _test_unauthored_boss_metadata_is_inert() -> void:
	print("== An unauthored/unrecognized 'boss' key has zero effect — proven both by absence and by deliberately adding one ==")
	var plain_stage: Dictionary = DecisionScenarios.get_stage("mod_01", 9)
	var with_boss_key: Dictionary = plain_stage.duplicate(true)
	with_boss_key["boss"] = {"enabled": true, "title": "FINAL OPERATION"}
	check(DecisionScenarios.has_finale(with_boss_key) == DecisionScenarios.has_finale(plain_stage),
		"[Boss] Adding an arbitrary 'boss' key does not change has_finale()")
	check(DecisionScenarios.finale_config(with_boss_key) == DecisionScenarios.finale_config(plain_stage),
		"[Boss] Adding an arbitrary 'boss' key does not change finale_config()'s own fields")
	# A code pattern, not a bare substring match — finale_config()'s own doc
	# comment mentions a hypothetical "boss": {...} block in prose to explain
	# why one isn't needed, which would be a false positive for a plain
	# "boss" substring scan.
	var scenarios_text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_scenarios.gd")
	check(not scenarios_text.contains(".get(\"boss\"") and not scenarios_text.contains("func boss_config") and not scenarios_text.contains("func has_boss"),
		"[Boss] decision_scenarios.gd defines no 'boss' schema/accessor at all — presentation/identification already comes from finale_config()")
