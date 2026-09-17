extends SceneTree
var Preview: PackedScene
const Context = preload("res://src/gameplay/match_context.gd")
const Quiz = preload("res://src/gameplay/quiz_content.gd")
var failures := 0
var render := false

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, copy: String) -> void:
	if not ok:
		failures += 1
		push_error(copy)

func fingerprint() -> String:
	return JSON.stringify([root.get_node("PlayerManager").get_save_data(), root.get_node("TaskManager").daily_tasks, root.get_node("AuthService")._mastery, root.get_node("AuthService")._bkt_queue])

func settle() -> void:
	for i in 8:
		await process_frame

func shot(label: String) -> void:
	await settle()
	for child in root.get_children():
		if child is Control and child.get("hud") != null:
			check_layout(child, label)
	if not render:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/preview_" + label + ".png")

func check_layout(match_node: Control, label: String) -> void:
	var hud: Control = match_node.hud
	var viewport_rect := root.get_visible_rect()
	check(hud.body.size.y >= viewport_rect.size.y * 0.4, label + ": battlefield/quiz retains usable height")
	check(hud.phase_label.size.y < 70, label + ": phase row cannot wrap vertically")
	for control in [hud.body, hud.submit if hud.workspace.visible else hud.battle]:
		var rect: Rect2 = control.get_global_rect()
		check(rect.position.y >= 0 and rect.end.y <= viewport_rect.end.y + 1, label + ": essential content stays on screen")
	var scale_y: float = root.get_final_transform().get_scale().y
	check(hud.font_size * scale_y >= 15.9, label + ": body text at least 16 physical pixels")
	check(hud.speed_button.size.y * scale_y >= 47.9, label + ": control height at least 48 physical pixels")

func answer(match_node: Node) -> void:
	var q: Dictionary = match_node.question
	if Quiz.is_multi(q):
		for value in q.get("correct_indices", []):
			match_node.choose_answer(value)
	elif q.has("answer_index"):
		match_node.choose_answer(int(q.answer_index))
	elif q.has("answer"):
		match_node.choose_answer(bool(q.answer))
	else:
		match_node.choose_answer(q.get("correct_answer", "phishing"))
	match_node.resolve_answer()
	match_node.continue_question()

func _run() -> void:
	Preview = load("res://src/gameplay/preview/stage_one_preview.tscn")
	render = OS.get_cmdline_user_args().has("--render")
	root.size = Vector2i(1280, 720)
	var before := fingerprint()
	var match_node: Control = Preview.instantiate()
	match_node.match_context = Context.stage_one_preview()
	root.add_child(match_node)
	match_node.set_process(false)
	await settle()
	check(match_node.phase == "Briefing" and match_node.question.is_empty(), "Stage title appears before any quiz loads")
	await shot("briefing_1280")
	match_node.advance_briefing(1)
	check(match_node.hud.intro_count.text == "3", "Title reveal leads into 3-2-1 countdown")
	await shot("countdown_1280")
	match_node.toggle_pause()
	match_node.advance_briefing(1)
	check(match_node.intro_elapsed == 1, "Pausing freezes the countdown")
	match_node.toggle_pause()
	match_node.advance_briefing(1)
	check(match_node.hud.intro_count.text == "2", "Countdown second beat")
	match_node.advance_briefing(1)
	check(match_node.hud.intro_count.text == "1", "Countdown last beat")
	match_node.advance_briefing(1)
	check(match_node.time_left == match_node.time_limit and match_node.answered == 0, "Intro never consumes quiz time or resolves answers")
	match_node.set_process(true)
	check(match_node.phase == "Trace", "Preview begins with Trace")
	check(match_node.gold == 2, "Canonical Stage 1 starting gold, no account intel bonus")
	check(match_node.hud.battle.board.path_cells.size() == 29, "Route contains the expected winding path cells")
	await shot("trace_1280")
	for resolution in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = resolution
		await shot("trace_%d" % resolution.x)
	root.size = Vector2i(1280, 720)
	await settle()
	var initial_gold: int = match_node.gold
	match_node.choose_answer(0)
	check(match_node.gold == initial_gold and not match_node.resolved, "Selection does not grade or stop countdown")
	match_node.resolve_answer(true)
	match_node.resolve_answer(true)
	check(match_node.answered == 1 and match_node.gold == initial_gold + 2, "Timeout grades and pays exactly once")
	check(match_node.selected_answers.is_empty(), "Timeout discards pending choices")
	check(match_node.phase == "Trace", "Feedback waits for Continue")
	await shot("feedback_1280")
	match_node.continue_question()
	while match_node.phase == "Trace":
		answer(match_node)
	check(match_node.phase == "Build", "Three questions advance to Build")
	for cell in match_node.hud.battle.board.path_cells:
		check(not match_node.cell_reason(cell).is_empty(), "All path cells block placement")
	await shot("build_1280")
	match_node.select_cell(Vector2i(2, 2))
	check(match_node.hud.tower_grid.get_child_count() == 3 and match_node.hud.tower_grid.columns == 3, "Picker keeps all three geometric towers in a compact grid")
	check(match_node.hud.tower_grid.get_child(0).get_meta("tower_card", false), "Picker has reusable shape-over-name tower cards")
	var offset: float = match_node.hud.battle.board.route_offset
	match_node.hud.battle.board._process(0.1)
	check(match_node.hud.battle.board.route_offset != offset, "Route arrows animate toward the base")
	await shot("tower_picker_1280")
	match_node.pick_tower("base")
	check(match_node.hud.build_details.visible and match_node.hud.side.visible, "Tower details appear beside the persistent picker")
	check(match_node.occupied.is_empty(), "Inspecting a choice never places it")
	await shot("placement_1280")
	initial_gold = match_node.gold
	check(match_node.place_tower(), "Tower placement succeeds")
	check(not match_node.place_tower() and match_node.gold == initial_gold - 2, "Rapid repeat Place cannot double charge")
	check(match_node.occupied.size() == 1, "One cell occupied")
	match_node.select_cell(Vector2i(2, 2))
	match_node.begin_move()
	match_node.select_cell(Vector2i(3, 2))
	check(match_node.confirm_move(), "Move succeeds with explicit confirmation")
	check(not match_node.confirm_move(), "Rapid repeat Move is rejected")
	check(not match_node.occupied.has(Vector2i(2, 2)) and match_node.occupied.has(Vector2i(3, 2)), "Move frees only its original single cell")
	match_node.select_cell(Vector2i(3, 2))
	check(match_node.upgrade_tower(), "Existing power upgrade works")
	check(match_node.hud._stat_labels.has("totals") and match_node.hud._stat_labels.has("rate"), "Inspector exposes real match totals and characteristics")
	check(match_node.hud.battle.board.show_range, "Inspecting a tower shows its actual range")
	var tower: Node = match_node.selected_tower
	var test_enemy: Node = load("res://src/gameplay/enemy_base.tscn").instantiate()
	test_enemy.match_context = match_node.match_context
	test_enemy.initialize_stats("fast", 1)
	match_node.hud.battle.track.add_child(test_enemy)
	var enemy_hp: int = test_enemy.current_health
	var projectile: Node = load("res://src/gameplay/projectile_base.tscn").instantiate()
	projectile.match_context = match_node.match_context
	projectile.source_tower = weakref(tower)
	projectile.damage = 999
	projectile._hit_enemy(test_enemy)
	check(tower.preview_damage_dealt == enemy_hp and tower.preview_kills == 1, "Inspector combat counters use actual damage and kills")
	projectile.free()
	var bursts: Array = match_node.hud.battle.track.get_children().filter(func(node: Node) -> bool: return node.get("tint") != null)
	check(bursts.size() == 1 and bursts[0].tint == test_enemy._base_color, "Death burst matches the enemy color")
	check(bursts[0].get_child(0) is CPUParticles2D, "Enemy defeat emits particles")
	await shot("inspector_1280")
	match_node.cancel_selection()
	for resolution in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = resolution
		await settle()
		await shot("build_%d" % resolution.x)
		match_node.select_cell(Vector2i(7, 2))
		match_node.pick_tower("scanner")
		await shot("placement_%d" % resolution.x)
		match_node.cancel_selection()
		match_node.select_cell(Vector2i(3, 2))
		await shot("inspector_%d" % resolution.x)
		match_node.cancel_selection()
	root.size = Vector2i(1280, 720)
	match_node.begin_defend()
	check(match_node.phase == "Defend" and match_node.pending_cell.x < 0, "Defend closes construction state")
	check(not match_node.place_tower(), "Defend rejects placement")
	match_node.toggle_pause()
	check(match_node.paused, "Pause works")
	await shot("pause_1280")
	match_node.toggle_pause()
	# Drive all waves through actual actor death signals; no persistent death tasks.
	for frame in 500:
		if match_node.phase == "Trace":
			answer(match_node)
		elif match_node.phase == "Build":
			match_node.begin_defend()
		elif match_node.phase == "Defend":
			match_node.spawn_clock = 0
			for enemy in match_node.hud.battle.track.get_children():
				if enemy.has_method("take_damage"):
					enemy.take_damage(999)
			if match_node.incident_active:
				match_node.resolve_incident(true)
			match_node.intermission = 2
		if match_node.phase == "Results":
			break
		await process_frame
	check(match_node.waves_completed == 3 and match_node.phase == "Results", "Every Stage 1 wave reaches preview victory")
	check(match_node.hud.result_overlay.get_script().get_base_script() == load("res://src/ui/screens/victory/base_defeat_overlay.gd"), "Victory reuses the complete original results animation")
	await create_timer(3.8).timeout
	await shot("victory_1280")
	check(before == fingerprint(), "Preview victory/quiz/build/move/upgrade/kill leaves account fingerprint unchanged")
	match_node.queue_free()
	await settle()
	match_node = Preview.instantiate()
	match_node.match_context = Context.stage_one_preview()
	root.add_child(match_node)
	await settle()
	match_node.advance_briefing(4)
	while match_node.phase == "Trace":
		answer(match_node)
	match_node.begin_defend()
	for i in 5:
		match_node._enemy_leaked()
	check(match_node.health == 0 and match_node.phase == "Results", "Defeat uses preview result screen")
	check(match_node.hud.battle.shake_left > 0, "Base damage starts a short camera shake")
	check(match_node.hud.result_overlay._grade.shader == load("res://src/ui/screens/victory/defeat_tint.gdshader"), "Preview uses the existing result color effect")
	check(match_node.hud.battle.board.get_node_or_null("BaseDestruction") != null, "Defeat reuses the existing base collapse animation")
	check(match_node.hud.result_overlay._button_actions == [&"restart", &"back"], "Results expose only preview-safe retry and return")
	await create_timer(3.8).timeout
	check(match_node.hud.battle.camera.offset == Vector2.ZERO, "Hit shake restores camera position")
	await shot("defeat_1280")
	check(before == fingerprint(), "Defeat also leaves all account state unchanged")
	match_node.queue_free()
	await settle()
	print("GAMEPLAY_PREVIEW_CHECKS failures=", failures)
	quit(0 if failures == 0 else 1)
