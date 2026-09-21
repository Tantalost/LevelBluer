extends SceneTree
## Real final-breach integration. Payout and navigation are captured in memory.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var router := root.get_node("Router")
	router.is_tutorial = false
	# Module 1 Stages 1-9 are decision-based (see verify_decision_stage.gd) and
	# Stage 10 is the module's summative post-assessment (different game-over
	# handling — see _is_summative()), so Module 1 no longer has a plain,
	# non-decision, non-exam Tower Defense stage. This test exercises exactly
	# that plain loss/reward flow, so it targets Module 2 Stage 3 instead.
	router.active_module_id = "mod_02"
	router.active_stage_index = 2
	var level: Node = load("res://src/gameplay/level_base.tscn").instantiate()
	var manager := level.get_node("LevelManager")
	manager.set_script(load("res://src/tools/defeat_test_manager.gd"))
	root.add_child(level)
	await _frames(3)
	_check(manager._decision == null, "Module 2 Stage 3 does not activate the decision flow")
	manager.change_phase(2)
	manager.current_phase = 3
	manager.base_health = 1
	manager._match_kills = 7
	var old_credits: int = root.get_node("PlayerManager").credits
	Engine.time_scale = 2
	manager._apply_base_breach()
	await _frames(1)
	var overlay: Node = manager._defeat_overlay
	_check(overlay != null, "Actual final breach mounts live defeat overlay")
	_check(manager.current_phase == 4, "Terminal phase committed before effects")
	_check(Engine.time_scale == 1, "Fast-forward is reset")
	_check(manager.base_health == 0, "Final HP is zero")
	_check(manager.test_awards == 1, "One defeat payout")
	_check(not level.get_node("GameplayCanvas").visible, "Gameplay HUD hidden")
	_check(level.get_node("Environment").process_mode == Node.PROCESS_MODE_DISABLED, "Combat frozen")
	var endpoints: Node = manager._map_endpoint_visuals
	var destruction := endpoints.get_node("BaseDestruction")
	_check(destruction != null and destruction.process_mode == Node.PROCESS_MODE_ALWAYS, "Destruction continues while actors are frozen")
	_check(not endpoints.get_node("HomeBaseSprite").visible, "Intact sprite replaced by destruction")
	_check(not overlay.results_ready and overlay._buttons[0].disabled, "No invisible early action buttons")
	manager._apply_base_breach()
	manager.change_phase(4)
	manager._on_enemy_died(10)
	_check(manager.test_awards == 1 and manager.base_health == 0, "Duplicate terminal callbacks ignored")
	_check(overlay._credits.text == "+10 CR", "Actual loss reward shown")
	_check(overlay._kills.text.ends_with("7"), "Match kills shown")
	_check(overlay._title.text == "BASE DESTROYED", "Base wording replaces castle")
	await _frames(30)
	_check(destruction.elapsed > 0.3, "Collapse actually animates under frozen environment")
	await _capture("base_defeat_impact")
	await _frames(105)
	await _capture("base_defeat_rewards")
	await _frames(95)
	_check(overlay.results_ready, "Results naturally reveal after animation")
	_check(not overlay._buttons[0].disabled, "Upgrade becomes interactive")
	await _capture("base_defeat_results")
	# Replay only the overlay timing to exercise the skip path.
	overlay.results_ready = false
	overlay.elapsed = 0
	overlay.finish_reveal()
	_check(overlay.results_ready, "Skip safely finishes the reveal")
	root.size = Vector2i(960, 600)
	await _frames(3)
	for button in overlay._buttons:
		_check(root.get_visible_rect().encloses(button.get_global_rect()), "Result action fits compact viewport")
	await _capture("base_defeat_compact")
	for i in overlay._buttons.size():
		overlay._leaving = false
		overlay._buttons[i].disabled = false
		overlay._buttons[i].pressed.emit()
	_check(manager.test_actions == [&"upgrade", &"restart", &"lessons", &"back"], "Every action reaches its controller handler")
	var clear_overlay: Node = load("res://src/ui/screens/victory/base_defeat_overlay.gd").new()
	root.add_child(clear_overlay)
	clear_overlay.configure({"won": true, "stage": 9, "credits": 50, "kills": 12, "accuracy": 1.0})
	_check(clear_overlay._title.text == "STAGE CLEARED", "Victory reuses animated result presentation")
	_check(clear_overlay._buttons[0].text == "NEXT STAGE", "Stages 1-9 offer next stage")
	_check(clear_overlay._button_actions[0] == &"next", "Next-stage action is routed")
	clear_overlay.configure({"won": true, "stage": 10, "final_stage": true})
	_check(clear_overlay._buttons[0].text != "NEXT STAGE", "Stage 10 has no next-stage button")
	_check(clear_overlay._button_actions[0] == &"certificate", "Stage 10 keeps certificate route")
	clear_overlay.queue_free()
	_check(root.get_node("PlayerManager").credits == old_credits, "Test did not mutate wallet or save")
	level.queue_free()
	await _frames(2)
	_check(get_nodes_in_group("level_root").is_empty(), "Level and effect clean up together")
	_check(Engine.time_scale == 1 and not paused, "Exit leaves timing and pause clean")
	print("[BASE DEFEAT] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
