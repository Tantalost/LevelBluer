extends SceneTree
## Regression suite for module-scoped stage progression.
##
## Root cause under test: cleared_stages / max_stage_cleared_by_module /
## locked_stages must identify a stage by module_id + stage_id
## (PlayerManager.stage_progress_key, e.g. "mod_01:1" / "mod_02:1"), never by
## raw stage number alone — mod_01:1 and mod_02:1 must never collide.
##
## Run headless:  godot --headless --script res://src/tools/verify_stage_progression.gd
## The local guest save is backed up before the run and restored afterwards.

var failures := 0
var _player: Node
var _stages: Node
var _save_path := ""
var _save_backup := ""
var _had_save := false


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func settle(frames: int = 6) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	_player = root.get_node("PlayerManager")
	_stages = root.get_node("StageManager")
	var save := root.get_node("SaveService")
	_save_path = save._resolve_save_path()
	_had_save = FileAccess.file_exists(_save_path)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(_save_path)

	_test_new_player_state()
	_test_clearing_mod1_stage1_is_isolated()
	_test_clearing_mod2_stage1_is_isolated()
	_test_clearing_mod1_stage5_does_not_touch_mod2_stage5()
	await _test_mastery_frozen_scoping()
	_test_module_progression_stays_inside_its_module()
	_test_module1_progression_through_stage10()
	_test_cross_module_ids_never_collide()
	_test_save_reload_preserves_module_scoped_state()
	_test_legacy_save_migration()
	_test_migration_is_idempotent()
	_test_decision_checkpoint_keys_unchanged()

	_restore_save()
	print("STAGE_PROGRESSION_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_new_player_state() -> void:
	print("== 1. New player: no stage cleared in any module ==")
	_player.reset_to_defaults()
	check(not _player.has_cleared_stage("mod_01", 1), "Fresh player: mod_01:1 is not cleared")
	check(not _player.has_cleared_stage("mod_02", 1), "Fresh player: mod_02:1 is not cleared")


func _test_clearing_mod1_stage1_is_isolated() -> void:
	print("== 2. Clearing mod_01:1 does not clear mod_02:1 ==")
	_player.reset_to_defaults()
	_player.mark_stage_cleared("mod_01", 1)
	check(_player.has_cleared_stage("mod_01", 1), "mod_01:1 is cleared")
	check(not _player.has_cleared_stage("mod_02", 1), "mod_02:1 is still NOT cleared")


func _test_clearing_mod2_stage1_is_isolated() -> void:
	print("== 3. Clearing mod_02:1 does not affect mod_01:1's independent clear ==")
	# Continues from the previous test's state: mod_01:1 already cleared.
	_player.mark_stage_cleared("mod_02", 1)
	check(_player.has_cleared_stage("mod_02", 1), "mod_02:1 is cleared")
	check(_player.has_cleared_stage("mod_01", 1), "mod_01:1 remains independently cleared")


func _test_clearing_mod1_stage5_does_not_touch_mod2_stage5() -> void:
	print("== 4. Clearing mod_01:5 does not mark mod_02:5 cleared ==")
	_player.reset_to_defaults()
	_player.mark_stage_cleared("mod_01", 5)
	check(_player.has_cleared_stage("mod_01", 5), "mod_01:5 is cleared")
	check(not _player.has_cleared_stage("mod_02", 5), "mod_02:5 is not cleared")


## Exercises the REAL production code path (stage_one_live.gd's
## _configure_match(), using the real PlayerManager autoload, not a fake) to
## prove mastery_frozen is derived from has_cleared_stage(module_id, stage_id).
func _test_mastery_frozen_scoping() -> void:
	print("== 5/6. mastery_frozen is scoped by module+stage, not raw stage number ==")
	var scene: PackedScene = load("res://src/gameplay/decision/stage_one_live.tscn")

	_player.reset_to_defaults()
	_player.mark_stage_cleared("mod_01", 1)

	# 5. Replaying an already-cleared mod_01:1 freezes mastery (existing behavior).
	var replay_context := MatchContext.stage_one_live()
	replay_context.module_id = "mod_01"
	replay_context.stage_id = 1
	var replay_node: Control = scene.instantiate()
	replay_node.match_context = replay_context
	root.add_child(replay_node)
	await settle()
	check(replay_node.mastery_frozen, "[5] Replaying mod_01:1 (already cleared) freezes mastery")
	replay_node.queue_free()
	await settle()

	# 6. First-playing mod_02:1 must NOT be frozen just because mod_01:1 was cleared.
	var fresh_context := MatchContext.stage_one_live()
	fresh_context.module_id = "mod_02"
	fresh_context.stage_id = 1
	var fresh_node: Control = scene.instantiate()
	fresh_node.match_context = fresh_context
	root.add_child(fresh_node)
	await settle()
	check(not fresh_node.mastery_frozen, "[6] First play of mod_02:1 is NOT frozen despite mod_01:1 being cleared")
	fresh_node.queue_free()
	await settle()


func _test_module_progression_stays_inside_its_module() -> void:
	print("== 7/9. Per-module progression: clearing mod_02 stages never touches mod_01's gating ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_01", "mod_02"])
	# Stage 3 requires its OWN module's Stage 2 to be cleared first.
	check(not _stages.access_reason(3, "mod_02").is_empty(), "mod_02 Stage 3 is gated before mod_02 Stage 2 is cleared")
	_player.mark_stage_cleared("mod_02", 1)
	_player.mark_stage_cleared("mod_02", 2)
	check(_stages.access_reason(3, "mod_02").is_empty(), "Clearing mod_02:1 and mod_02:2 unlocks mod_02 Stage 3")
	check(not _stages.access_reason(3, "mod_01").is_empty(), "mod_01 Stage 3 remains gated: mod_02 progress never unlocks it")
	check(_player.max_stage_cleared("mod_01") == 1, "mod_01's ceiling is untouched by mod_02 progress")
	check(_player.max_stage_cleared("mod_02") == 2, "mod_02's ceiling reflects only mod_02's own clears")


func _test_module1_progression_through_stage10() -> void:
	print("== 8. Module 1 progression still works through Stage 10 ==")
	_player.reset_to_defaults()
	_player.completed_lessons.assign(["mod_01"])
	check(_stages.access_reason(1, "mod_01").is_empty(), "Stage 1 is open by default")
	check(_stages.access_reason(2, "mod_01").is_empty(), "Stage 2 is open by default (existing baseline preserved)")
	check(not _stages.access_reason(3, "mod_01").is_empty(), "Stage 3 is locked before Stage 2 is cleared")
	for stage_id in range(1, 11):
		_player.mark_stage_cleared("mod_01", stage_id)
		if stage_id < 10:
			check(_stages.access_reason(stage_id + 1, "mod_01").is_empty(), "Clearing mod_01:%d unlocks mod_01:%d" % [stage_id, stage_id + 1])
	check(_player.max_stage_cleared("mod_01") == 10, "Module 1 ceiling reaches Stage 10")
	check(_player.has_cleared_stage("mod_01", 10), "Module 1 Stage 10 is recorded as cleared")


func _test_cross_module_ids_never_collide() -> void:
	print("== 10. Cross-module stage IDs never collide ==")
	check(_player.stage_progress_key("mod_01", 1) != _player.stage_progress_key("mod_02", 1), "mod_01:1 key differs from mod_02:1 key")
	check(_player.stage_progress_key("mod_01", 1) == "mod_01:1", "Canonical key format is module_id:stage_id")
	check(_player.stage_progress_key("mod_02", 1) == "mod_02:1", "Canonical key format is module_id:stage_id")


func _test_save_reload_preserves_module_scoped_state() -> void:
	print("== 11. Save/reload preserves module-scoped completion ==")
	_player.reset_to_defaults()
	_player.mark_stage_cleared("mod_01", 1)
	_player.mark_stage_cleared("mod_01", 2)
	_player.mark_stage_cleared("mod_02", 1)
	_player.lock_stage("mod_01", 10)
	var saved: Dictionary = _player.get_save_data()
	_player.reset_to_defaults()
	check(not _player.has_cleared_stage("mod_01", 1), "State cleared before reload (sanity)")
	_player.apply_save_data(saved)
	check(_player.has_cleared_stage("mod_01", 1), "Reload preserves mod_01:1 cleared")
	check(_player.has_cleared_stage("mod_01", 2), "Reload preserves mod_01:2 cleared")
	check(_player.has_cleared_stage("mod_02", 1), "Reload preserves mod_02:1 cleared")
	check(not _player.has_cleared_stage("mod_02", 2), "Reload does not invent mod_02:2 as cleared")
	check(_player.is_stage_locked("mod_01", 10), "Reload preserves the mod_01:10 exam lock")
	check(_player.max_stage_cleared("mod_01") == 2, "Reload preserves mod_01's ceiling")
	check(_player.max_stage_cleared("mod_02") == 1, "Reload preserves mod_02's ceiling")


func _test_legacy_save_migration() -> void:
	print("== 12. Legacy raw-stage-number saves migrate to Module 1 ==")
	_player.reset_to_defaults()
	var legacy_save: Dictionary = {
		"mastery_matrix": {"phishing": 0.4},
		"mock_max_stage_cleared": 4,
		"cleared_stages": [1, 2, 3, 4],
		"locked_stages": {5: true},
	}
	_player.apply_save_data(legacy_save)
	check(_player.has_cleared_stage("mod_01", 1), "Legacy stage 1 migrates to mod_01:1")
	check(_player.has_cleared_stage("mod_01", 2), "Legacy stage 2 migrates to mod_01:2")
	check(_player.has_cleared_stage("mod_01", 3), "Legacy stage 3 migrates to mod_01:3")
	check(_player.has_cleared_stage("mod_01", 4), "Legacy stage 4 migrates to mod_01:4")
	check(not _player.has_cleared_stage("mod_02", 1), "Legacy data never invents mod_02 progress")
	check(_player.is_stage_locked("mod_01", 5), "Legacy locked_stages entry migrates to mod_01:5")
	check(_player.max_stage_cleared("mod_01") == 4, "Legacy mock_max_stage_cleared migrates to mod_01's ceiling")
	check(_player.cleared_stages.size() == 4, "No duplicate entries created by migration")


func _test_migration_is_idempotent() -> void:
	print("== 13. Migration is idempotent: reapplying the normalized save changes nothing ==")
	var normalized: Dictionary = _player.get_save_data()
	var cleared_before: String = JSON.stringify(_player.cleared_stages.keys())
	var locked_before: String = JSON.stringify(_player.locked_stages.keys())
	var ceilings_before: String = JSON.stringify(_player.max_stage_cleared_by_module)
	_player.apply_save_data(normalized)
	check(JSON.stringify(_player.cleared_stages.keys()) == cleared_before, "cleared_stages is identical after re-applying the normalized save")
	check(JSON.stringify(_player.locked_stages.keys()) == locked_before, "locked_stages is identical after re-applying the normalized save")
	check(JSON.stringify(_player.max_stage_cleared_by_module) == ceilings_before, "max_stage_cleared_by_module is identical after re-applying the normalized save")
	# Re-applying twice more must still be a no-op (fully idempotent, not just once).
	_player.apply_save_data(normalized)
	_player.apply_save_data(normalized)
	check(JSON.stringify(_player.cleared_stages.keys()) == cleared_before, "Repeated re-application stays stable, no duplicate entries")


func _test_decision_checkpoint_keys_unchanged() -> void:
	print("== 16. Existing decision checkpoint keys remain unchanged ==")
	check(DecisionScenarios.stage_key("mod_01", 1) == "mod_01:1", "Decision checkpoint key format for mod_01:1 is unchanged")
	check(DecisionScenarios.stage_key("mod_02", 1) == "mod_02:1", "Decision checkpoint key format for mod_02:1 is unchanged")
	_player.reset_to_defaults()
	_player.set_decision_stage_state("mod_01:1", {"threat_index": 1})
	_player.set_decision_stage_state("mod_02:1", {"threat_index": 2})
	check(_player.get_decision_stage_state("mod_01:1").get("threat_index") == 1, "mod_01:1 decision checkpoint independent")
	check(_player.get_decision_stage_state("mod_02:1").get("threat_index") == 2, "mod_02:1 decision checkpoint independent")
	check(_player.decision_stage_state.keys().size() == 2, "Decision checkpoints remain a flat module:stage-keyed map, unaffected by the progression fix")


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(_save_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_save_backup)
			file.close()
	elif FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
