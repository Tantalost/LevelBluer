extends SceneTree
## Real live controller, in-memory account gateway. Never writes/restores a user save.
const Context = preload("res://src/gameplay/match_context.gd")
var failures := 0
var scene: PackedScene

class Account extends RefCounted:
	var checkpoint: Dictionary = {}
	var bkt: Array = []
	var writes := 0
	var credits := 0
	var clears := 0
	var cleared := false
	var intel_uses := 0
	var stage_tasks := 0
	var unlocked := ["base"]
	var bonus: Dictionary = {}
	func consume_intel_bonus_gold(value: int, _module: String) -> int:
		intel_uses += 1
		return value
	func has_cleared_stage(_stage: int) -> bool:
		return cleared
	func get_decision_stage_state(_key: String) -> Dictionary:
		return checkpoint.duplicate(true)
	func set_decision_stage_state(_key: String, state: Dictionary) -> void:
		checkpoint = state.duplicate(true)
		writes += 1
	func clear_decision_stage_state(_key: String) -> void:
		checkpoint.clear()
	func update_mastery(skill: String, correct: bool) -> void:
		bkt.append([skill, correct])
	func tower_capacity(_kind: String) -> int:
		return 3
	func is_tower_unlocked(kind: String) -> bool:
		return kind in unlocked
	func stats_bonus_for(_kind: String) -> Dictionary:
		return bonus
	func mark_stage_cleared(_id: int) -> void:
		clears += 1
		cleared = true
	func add_credits(value: int) -> void:
		credits += value
	func record_stage_cleared() -> void:
		stage_tasks += 1

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 10:
		await process_frame

func fingerprint() -> String:
	return JSON.stringify([root.get_node("PlayerManager").get_save_data(), root.get_node("TaskManager").daily_tasks, root.get_node("AuthService")._mastery, root.get_node("AuthService")._bkt_queue])

func mount(account: Account) -> Control:
	var match_node: Control = scene.instantiate()
	match_node.match_context = Context.stage_one_live()
	match_node.account = account
	match_node.tasks = account
	root.add_child(match_node)
	match_node.set_process(false)
	match_node.advance_briefing(4)
	return match_node

func unmount(match_node: Control) -> void:
	match_node.queue_free()
	await settle()

func choose(match_node: Control, outcome: String) -> void:
	if match_node.story_overlay._mode == &"story":
		read_page(match_node)
	if not match_node.story_overlay._dialogue_done:
		read_page(match_node)
	var choices: Array = match_node.decision.current_threat().choices
	for i in choices.size():
		if choices[i].outcome == outcome:
			match_node.story_overlay._choose(i)
			read_page(match_node)
			return
	check(false, "Missing authored outcome " + outcome)

func read_page(match_node: Control) -> void:
	var overlay: Control = match_node.story_overlay
	var line_count: int = maxi(1, overlay._lines.size())
	for i in line_count:
		if overlay._typing:
			overlay._continue() # Reveal without skipping or committing a choice.
		overlay._continue()

func shot(match_node: Control, name: String) -> void:
	await settle()
	var rect := root.get_visible_rect()
	check(rect.encloses(match_node.hud.body.get_global_rect()), name + ": battlefield fits")
	if match_node.hud.pause_button.is_visible_in_tree():
		check(rect.encloses(match_node.hud.pause_button.get_global_rect()), name + ": pause fits")
	if match_node.story_overlay.is_visible_in_tree():
		check(rect.encloses(match_node.story_overlay._window.get_global_rect()), name + ": story fits")
		if match_node.story_overlay._review_open:
			check(rect.encloses(match_node.story_overlay._review_panel.get_global_rect()), name + ": review fits")
			check(rect.encloses(match_node.story_overlay._review_close.get_global_rect()), name + ": review return fits")
		if match_node.story_overlay._continue_button.visible:
			check(rect.encloses(match_node.story_overlay._continue_button.get_global_rect()), name + ": story Continue fits")
	check(not match_node.hud.preview_label.text.contains("NOTHING SAVED"), "Normal session is not labeled preview")
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/live_stage_" + name + ".png")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var tower_script = load("res://src/gameplay/tower_base.gd")
	var before := fingerprint()
	scene = load("res://src/gameplay/decision/stage_one_live.tscn")
	var router := root.get_node("Router")
	router.active_module_id = "mod_01"
	check(router._scene_for_context(router._context_for_stage(0)) == router.STAGE_ONE_LIVE_SCENE, "Normal Stage 1 routes to new scene")
	for i in range(1, 10):
		check(router._scene_for_context(router._context_for_stage(i)) == router.LEVEL_SCENE, "Later stage remains legacy")
	router.is_tutorial = true
	check(not router._context_for_stage(0).geometric, "Tutorial remains legacy")
	router.is_tutorial = false
	router.active_module_id = "mod_02"
	check(not router._context_for_stage(0).geometric, "Other module remains legacy")
	router.active_module_id = "mod_01"
	check(router._scene_for_context(Context.stage_one_preview()) == router.PREVIEW_SCENE, "Preview remains separate")
	var account := Account.new()
	var game := mount(account)
	check(game.story_overlay._mode == &"story", "Fresh launch includes opening dialogue")
	check(game.config.name == "The First Warning", "Uses authored story title")
	var dialogue: Control = game.story_overlay
	dialogue.set_process(false)
	check(dialogue._portraits.size() == 2 and dialogue._typing, "Two temporary portraits and typewriter are mounted")
	dialogue._process(0.15)
	check(dialogue._speech.visible_characters > 0 and dialogue._typing, "Text reveals progressively")
	var revealed: int = dialogue._speech.visible_characters
	game.toggle_pause()
	dialogue._process(2)
	dialogue._continue()
	check(dialogue._speech.visible_characters == revealed and dialogue._line_index == 0, "Pause freezes typing and advance")
	game.toggle_pause()
	dialogue._continue()
	check(not dialogue._typing and dialogue._line_index == 0, "First tap reveals full line without skipping")
	await shot(game, "opening")
	dialogue._continue()
	check(dialogue._portraits[0].speaking and dialogue._portraits[0].get_parent().visible and not dialogue._portraits[1].get_parent().visible, "First speaker Security Assistant appears on the left")
	dialogue._continue()
	dialogue._continue()
	check(dialogue._portraits[1].speaking and dialogue._portraits[1].get_parent().visible and not dialogue._portraits[0].get_parent().visible, "Second speaker Mia appears on the right")
	dialogue._continue()
	await shot(game, "conversation")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "conversation_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	dialogue._continue()
	check(dialogue._mode == &"threat" and not dialogue._dialogue_done, "Opening completes before incident dialogue")
	check(not dialogue._choices_scroll.visible and not dialogue._timer_row.visible, "Choices and timer are hidden during conversation")
	game.advance_decision_timer(90)
	check(not game.decision_timer_active and account.bkt.is_empty(), "Dialogue has no running decision timer")
	dialogue._choose(0)
	check(game.decision.pending_choice_index == -1, "Choices cannot skip unread dialogue")
	read_page(game)
	check(dialogue._dialogue_done and dialogue._evidence.visible and not dialogue._choice_buttons[0].disabled, "Evidence and choices unlock after dialogue")
	check(not dialogue._conversation.visible and dialogue._choices_scroll.visible and dialogue._timer_row.visible, "Scenario replaces dialogue and opens timed choices")
	check(game.decision_seconds_left == 45 and game.decision_timer_active, "Decision gets the full 45 seconds")
	await shot(game, "decision")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "decision_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	game.advance_decision_timer(5)
	dialogue._open_review()
	check(dialogue._review_open and dialogue._review_content.get_child_count() == 4, "Review contains only revealed opening and incident lines")
	game.advance_decision_timer(100)
	dialogue._choose(0)
	check(game.decision_seconds_left == 40 and game.decision.pending_choice_index == -1, "Review pauses the timer and blocks underlying choices")
	await shot(game, "dialogue_review")
	root.size = Vector2i(844, 390)
	await shot(game, "dialogue_review_844x390")
	root.size = Vector2i(1280, 720)
	dialogue._close_review()
	check(game.decision_seconds_left == 40, "Closing review does not reset the timer")
	game.toggle_pause()
	game.advance_decision_timer(100)
	game._choice_selected(0)
	check(game.decision.pending_choice_index == -1 and game.decision_seconds_left == 40, "Pause freezes timed decisions")
	game.toggle_pause()
	for i in game.decision.total_threats():
		choose(game, "SAFE")
	check(account.clears == 0, "Must file ending report before stage clear")
	game._story_continued()
	check(game.phase == "Results", "All SAFE completes story")
	check(account.bkt.size() == game.decision.total_threats(), "Exactly one BKT update per decision")
	check(account.credits == 50 + game.gold and account.clears == 1 and account.stage_tasks == 1, "Production victory rewards match existing rules")
	game._finish(true)
	check(account.clears == 1 and account.stage_tasks == 1, "Duplicate finish cannot duplicate awards")
	game.hud.result_overlay.finish_reveal()
	await shot(game, "victory")
	await unmount(game)

	account = Account.new()
	account.bonus = root.get_node("PlayerManager").stats_bonus_for("base")
	game = mount(account)
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.credits == 0 and account.clears == 0, "Critical decision fails without invented loss rewards")
	check(account.checkpoint.threat_index == 0 and account.bkt.size() == 1, "Critical retry preserves incident and grades once")
	game.hud.result_overlay.finish_reveal()
	await shot(game, "critical")
	await unmount(game)
	game = mount(account)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 0, "Retry resumes incident rather than opening story")
	choose(game, "RISKY")
	check(game.phase == "Incident" and game.decision.awaiting_breach_deploy(), "Risky warning waits for Deploy Defenses")
	game._consequence_continued()
	check(game.phase == "Build" and game.health == 5 and game.gold == int(game.decision.current_threat().breach_gold), "Breach uses authored health and gold reset")
	check(game.match_context.persistent and game.match_context.footprint == 1, "Normal context uses one-cell gameplay")
	check(game._enemy_health_scale() == 0.6, "Existing Stage 1 breach HP scaling retained")
	check(game.hud.battle.track.curve.point_count > 1, "Preview route is mounted")
	await shot(game, "build")
	game.select_cell(Vector2i(2, 0))
	game.pick_tower("scanner")
	check(not game.place_tower(), "Account-locked tower cannot be placed")
	await shot(game, "locked_tower")
	game.pick_tower("base")
	var gold_before: int = game.gold
	check(game.place_tower(), "Unlocked tower places")
	check(game.gold == gold_before - tower_script.cost_for("base"), "Placement charged once")
	check(not game.place_tower(), "Rapid Place cannot charge twice")
	check(game.occupied.size() == 1 and not game.cell_reason(Vector2i(2, 0)).is_empty(), "One-cell occupancy enforced")
	game.select_cell(Vector2i(2, 0))
	await shot(game, "inspector")
	var placed: Node = game.selected_tower
	check(placed.base_damage == tower_script.damage_at("base", 0) + int(account.bonus.get("damage", 0)), "Live tower applies account damage research")
	check(is_equal_approx(placed.fire_rate, float(tower_script.entry_for("base").get("fire_rate", 1)) + float(account.bonus.get("fire_rate", 0))), "Live tower applies account attack-speed research")
	var upgrade_cost: int = placed.next_upgrade_cost()
	gold_before = game.gold
	check(game.upgrade_tower() and game.gold == gold_before - upgrade_cost, "Existing upgrade charges exactly its catalog cost")
	game.begin_move()
	game.select_cell(Vector2i(2, 2))
	gold_before = game.gold
	check(game.confirm_move() and game.gold == gold_before - 1, "Confirmed move retains one-gold cost")
	check(not game.occupied.has(Vector2i(2, 0)) and game.occupied.has(Vector2i(2, 2)), "Move releases only original tile")
	check(not game.confirm_move(), "Repeated move confirmation does not charge again")
	game.gold = 100
	for cell in [Vector2i(3, 0), Vector2i(4, 0)]:
		game.select_cell(cell)
		game.pick_tower("base")
		check(game.place_tower(), "Research capacity allows three base towers")
	check(game.cell_reason(Vector2i(7, 0), "base").contains("Capacity"), "Production capacity limit enforced")
	account.unlocked = ["base", "scanner", "sandbox"]
	for kind in ["scanner", "sandbox"]:
		game.select_cell(Vector2i(5 if kind == "scanner" else 6, 0))
		game.pick_tower(kind)
		check(game.place_tower(), "Unlocked " + kind + " can be placed")
	game.gold = 0
	check(game.cell_reason(Vector2i(7, 0), "scanner").contains("gold"), "Insufficient funds are revalidated")
	game.gold = 12
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		game.cancel_selection()
		await shot(game, "build_%dx%d" % [dimensions.x, dimensions.y])
		game.select_cell(Vector2i(4, 0))
		game.pick_tower("base")
		await shot(game, "picker_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	game.begin_defend()
	check(not game.incident_due, "No unrelated incident quizzes in authored decision combat")
	check(not game.upgrade_tower() and not game.place_tower(), "Defend cannot build or upgrade")
	game._spawn_enemy()
	var enemy: Node = game.hud.battle.track.get_child(0)
	check(enemy.match_context.persistent and enemy.match_context.geometric, "Live enemies retain production task accounting")
	# Test-only actor boundary: prevent TaskManager from writing a real user task.
	# The live controller and its reward/checkpoint calls still run against Account.
	enemy.match_context = Context.stage_one_preview()
	enemy.take_damage(9999)
	check(game.match_kills == 1, "Enemy death reaches live match bounty accounting")
	game._wave_cleared()
	check(game.phase == "Incident" and game.decision.resolved_threats == 1, "Containment returns to story, not preview quiz loop")
	check(game.story_overlay._mode == &"story", "Containment dialogue renders before next incident")
	game._story_continued()
	choose(game, "RISKY")
	game._consequence_continued()
	check(game.occupied.is_empty() and game.health == 5, "Next breach resets prior towers and health")
	game.begin_defend()
	for i in 5:
		game._enemy_leaked()
	check(game.phase == "Results" and account.clears == 0, "Lost containment does not clear stage")
	check(account.checkpoint.threat_index == 1, "Loss checkpoint remains at failed incident")
	game.hud.result_overlay.finish_reveal()
	await shot(game, "containment_failed")
	await unmount(game)

	# Resume a saved live breach with story/choices, without grading it twice.
	account = Account.new()
	game = mount(account)
	choose(game, "SAFE")
	choose(game, "RISKY")
	# Simulate an older checkpoint without the new marker, including JSON reload.
	account.checkpoint = JSON.parse_string(JSON.stringify(account.checkpoint))
	await unmount(game)
	var count := account.bkt.size()
	game = mount(account)
	check(game.phase == "Incident" and game.story_overlay._mode == &"threat", "Saved breach reopens original incident choices")
	check(game.decision.threat_index == 1 and game.decision.resolved_threats == 1 and game.decision.safe_count == 1, "Review preserves completed incident progress")
	check(not game.decision.is_breach_active() and not game.hud.battle.enabled, "Review does not start combat")
	check(game.story_overlay._choice_buttons.size() == game.decision.current_threat().choices.size(), "All authored decisions are visible on resume")
	game._begin_breach()
	game._story_continued()
	check(game.phase == "Incident" and account.bkt.size() == count, "Continue or deploy without a decision cannot skip review")
	await shot(game, "resumed_incident")
	# Exiting before choosing must not lose deduplication on a real save reload.
	var player := root.get_node("PlayerManager")
	var normalized: Dictionary = player._normalize_decision_state({"mod_01:1": JSON.parse_string(JSON.stringify(account.checkpoint))})
	account.checkpoint = normalized["mod_01:1"]
	check(account.checkpoint.get("reviewed_breach_index", -1) == 1, "Review marker survives production save normalization")
	await unmount(game)
	game = mount(account)
	choose(game, "RISKY")
	check(game.phase == "Incident" and account.bkt.size() == count, "Reconsidered risky choice waits for Deploy without duplicate BKT")
	game._consequence_continued()
	check(game.phase == "Build" and game.gold == 14, "Reviewed risk still launches authored defenses explicitly")
	await unmount(game)
	game = mount(account)
	check(game.story_overlay._mode == &"threat", "Repeated battle exit returns to decisions")
	choose(game, "SAFE")
	check(account.bkt.size() == count and game.decision.resolved_threats == 2, "Safe review advances once without regrading original assessment")
	check(not account.checkpoint.has("reviewed_breach_index"), "Resolved review no longer tags the next incident")
	choose(game, "SAFE")
	check(account.bkt.size() == count + 1, "Next unassessed incident still updates mastery normally")
	await unmount(game)
	game = mount(account)
	check(game.story_overlay._mode == &"story" and game.decision.is_complete(), "Ending checkpoint still requires final story report")
	game._story_continued()
	check(account.clears == 1 and account.stage_tasks == 1, "Reviewed story finishes through normal production completion")
	await unmount(game)
	account = Account.new()
	account.cleared = true
	game = mount(account)
	choose(game, "SAFE")
	check(account.bkt.is_empty(), "Cleared-stage replay freezes mastery")
	await unmount(game)
	# Every incident times out as a single risky assessment, never a guessed action.
	for incident_index in 3:
		account = Account.new()
		account.checkpoint = {"threat_index": incident_index, "resolved_threats": incident_index, "flow_state": "THREAT", "safe_count": incident_index}
		game = mount(account)
		read_page(game)
		game.advance_decision_timer(44.9)
		check(account.bkt.is_empty() and game.decision_timer_active, "No early timeout")
		game.advance_decision_timer(0.2)
		check(game.decision.is_breach_active() and not game.decision_timer_active and account.bkt == [["phishing", false]], "Timeout commits risk exactly once")
		check(account.checkpoint.flow_state == "BREACH" and game.story_overlay._lines[0].text.begins_with("No response"), "Timeout saves breach and explains inaction honestly")
		game.advance_decision_timer(100)
		game._expire_decision()
		game._choice_selected(1)
		check(account.bkt.size() == 1, "Late click and repeated timeout cannot regrade")
		if incident_index == 0:
			game.story_overlay._reveal_line()
			await shot(game, "decision_timeout")
		read_page(game)
		check(game.phase == "Build" and game.gold == 12 + incident_index * 2, "Timeout deploys authored containment budget")
		await unmount(game)
	# A choice accepted before the deadline stops the clock before consequence text.
	account = Account.new()
	game = mount(account)
	read_page(game)
	read_page(game)
	game.advance_decision_timer(44.9)
	game.story_overlay._choose(1)
	game.advance_decision_timer(100)
	check(game.decision.pending_outcome == "SAFE" and not game.decision_timer_active and account.bkt.is_empty(), "Accepted answer wins over a subsequent timeout")
	read_page(game)
	check(account.bkt == [["phishing", true]], "Accepted safe answer grades once after consequence")
	await unmount(game)
	check(fingerprint() == before, "Tests left actual player/mastery/tasks/queue unchanged")
	print("[LIVE STAGE ONE] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
