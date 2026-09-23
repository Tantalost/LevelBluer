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
	var story_memory: Dictionary = {}
	var story_memory_writes := 0
	func get_story_memory_snapshot() -> Dictionary:
		return story_memory.duplicate(true)
	func set_story_memories(entries: Dictionary) -> void:
		if entries.is_empty():
			return
		for key in entries.keys():
			story_memory[str(key)] = entries[key]
		story_memory_writes += 1
	func consume_intel_bonus_gold(value: int, _module: String) -> int:
		intel_uses += 1
		return value
	func has_cleared_stage(_module_id: String, _stage: int) -> bool:
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
	func mark_stage_cleared(_module_id: String, _id: int) -> void:
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

## Checks the currently-loaded dialogue block's lines (see
## decision_workspace.gd's _lines) for a substring — used to confirm
## authored story_event/timeout_story_event content is actually present on
## screen, not just parsed into data.
func overlay_dialogue_contains(overlay: Control, needle: String) -> bool:
	for line in overlay._lines:
		if str((line as Dictionary).get("text", "")).contains(needle):
			return true
	return false

## The banner (e.g. "TIME EXPIRED / BREACH DETECTED") is not a dedicated
## field on decision_workspace.gd — show_consequence() just adds it as a
## Label into _narrative. Reads its text back by scanning that container.
func overlay_banner_text(overlay: Control) -> String:
	for child in overlay._narrative.get_children():
		if child is Label:
			return (child as Label).text
	return ""

func mount(account: Account, context: MatchContext = null) -> Control:
	var match_node: Control = scene.instantiate()
	match_node.match_context = context if context != null else Context.stage_one_live()
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
	# Choices are shown in a randomized order (see DecisionStageController.
	# current_threat_for_display); find the outcome in THAT order, matching
	# what the overlay's buttons (and thus _choose(i)) actually display.
	var choices: Array = match_node.decision.current_threat_for_display().choices
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

## read_page()'s line_count is _lines.size() at call time — correct when a
## fresh screen just replaced _lines outright, but an investigation's
## resolved_story_event beat (see decision_workspace.gd's
## _on_investigation_resolved()) APPENDS to the same still-open threat's
## _lines instead, so _lines.size() already includes everything already
## read. Calling read_page() there would over-advance _continue() well past
## the point choices become actionable, incorrectly re-locking interaction
## (the same fallback _continue() uses to end a story/consequence screen).
## This drains only up to the next natural stopping point instead.
func drain_until_dialogue_done(match_node: Control) -> void:
	var overlay: Control = match_node.story_overlay
	for i in 12:
		if overlay._dialogue_done:
			return
		if overlay._typing:
			overlay._continue()
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
	check(router._scene_for_context(router._context_for_stage(0)) == router.STAGE_ONE_LIVE_SCENE, "Normal Stage 1 routes to the live decision scene")
	check(router._scene_for_context(router._context_for_stage(1)) == router.STAGE_ONE_LIVE_SCENE, "Stage 2 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(2)) == router.STAGE_ONE_LIVE_SCENE, "Stage 3 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(3)) == router.STAGE_ONE_LIVE_SCENE, "Stage 4 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(4)) == router.STAGE_ONE_LIVE_SCENE, "Stage 5 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(5)) == router.STAGE_ONE_LIVE_SCENE, "Stage 6 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(6)) == router.STAGE_ONE_LIVE_SCENE, "Stage 7 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(7)) == router.STAGE_ONE_LIVE_SCENE, "Stage 8 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(8)) == router.STAGE_ONE_LIVE_SCENE, "Stage 9 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(9)) == router.LEVEL_SCENE, "Stage 10 (the post-assessment, no decision data) remains legacy")
	router.is_tutorial = true
	check(not router._context_for_stage(0).geometric, "Tutorial remains legacy")
	router.is_tutorial = false
	router.active_module_id = "mod_02"
	check(router._scene_for_context(router._context_for_stage(0)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 1 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(1)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 2 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(2)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 3 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(3)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 4 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(4)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 5 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(5)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 6 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(6)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 7 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(7)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 8 also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(8)) == router.STAGE_ONE_LIVE_SCENE, "Module 2 Stage 9 (final story stage, with a finale) also routes to the same live decision scene")
	check(router._scene_for_context(router._context_for_stage(9)) == router.LEVEL_SCENE, "Module 2 Stage 10 (the post-assessment) remains legacy")
	router.active_module_id = "mod_03"
	check(router._scene_for_context(router._context_for_stage(0)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 1 also routes to the live decision scene (it is decision-based too)")
	check(router._scene_for_context(router._context_for_stage(1)) == router.LEVEL_SCENE, "Module 3 Stage 2 (no decision data yet) remains legacy")
	router.active_module_id = "mod_04"
	check(not router._context_for_stage(0).geometric, "A module with no decision content remains legacy")
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
	# Module 1 Stage 1's incidents author no "timer" block — untimed is the
	# overwhelming default (see DecisionScenarios.has_timer). Choices open
	# normally with no countdown row at all; the manual-click path must not
	# depend on decision_timer_active, since it stays false for the whole
	# incident here. Full timer/review/pause-freeze mechanics are covered
	# separately using Module 3 Stage 1's authored timed demo, below.
	check(not dialogue._conversation.visible and dialogue._choices_scroll.visible and not dialogue._timer_row.visible, "Scenario replaces dialogue and opens choices with no timer row")
	check(not game.decision_timer_active, "An untimed incident never activates a timer")
	await shot(game, "decision")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "decision_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	dialogue._open_review()
	check(dialogue._review_open and dialogue._review_content.get_child_count() == 4, "Review contains only revealed opening and incident lines")
	await shot(game, "dialogue_review")
	root.size = Vector2i(844, 390)
	await shot(game, "dialogue_review_844x390")
	root.size = Vector2i(1280, 720)
	dialogue._close_review()
	game.toggle_pause()
	game._choice_selected(0)
	check(game.decision.pending_choice_index == -1, "Pause still blocks a manual choice on an untimed incident")
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
	# Module 1 Stage 1's incidents author no "timer" block (see
	# DecisionScenarios.has_timer) — untimed is the overwhelming default, so
	# no amount of elapsed time can commit a decision here; only a genuine
	# manual choice can. Full timeout/race mechanics are covered using
	# Module 3 Stage 1's authored timed demo, further below.
	for incident_index in 3:
		account = Account.new()
		account.checkpoint = {"threat_index": incident_index, "resolved_threats": incident_index, "flow_state": "THREAT", "safe_count": incident_index}
		game = mount(account)
		read_page(game)
		check(not game.decision_timer_active, "Untimed incident %d never activates a timer" % incident_index)
		game.advance_decision_timer(9999.0)
		check(account.bkt.is_empty() and not game.decision.is_breach_active(), "Untimed incident %d cannot time out no matter how much time passes" % incident_index)
		game._expire_decision()
		check(account.bkt.is_empty(), "_expire_decision() is a safe no-op when no timer is active")
		choose(game, "SAFE")
		check(account.bkt.size() == 1, "The incident still requires and accepts a genuine manual choice")
		await unmount(game)

	# Module 1 Stage 2 runs through the exact same live scene/controller as
	# Stage 1, driven purely by DecisionScenarios data for stage 2.
	print("-- [Stage 2] Same live scene, its own data --")
	var stage2 := Context.stage_one_live()
	stage2.stage_id = 2
	stage2.module_id = "mod_01"
	account = Account.new()
	game = mount(account, stage2)
	check(game.story_overlay._mode == &"story", "[Stage 2] Fresh launch includes opening dialogue")
	check(game.config.name == "They Know Who We Are", "[Stage 2] Uses its own authored story title, not Stage 1's")
	check(game.decision.total_threats() == 3, "[Stage 2] Exactly 3 incidents load")
	check(is_equal_approx(game._enemy_health_scale(), 0.65), "[Stage 2] Breach HP scale is 0.65, independent of Stage 1's 0.60")
	check(game._key() == "mod_01:2", "[Stage 2] Checkpoint key is stage-specific")
	read_page(game)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 0, "[Stage 2] Incident 1 shown after opening")
	choose(game, "SAFE")
	check(game.decision.resolved_threats == 1 and game.decision.threat_index == 1, "[Stage 2] SAFE resolves Incident 1 and advances to Incident 2")
	check(account.bkt == [["phishing", true]], "[Stage 2] SAFE grades BKT correct exactly once")
	choose(game, "RISKY")
	check(game.phase == "Incident" and game.decision.awaiting_breach_deploy(), "[Stage 2] RISKY warning waits for Deploy Defenses")
	check(account.bkt.size() == 2 and account.bkt[1] == ["phishing", false], "[Stage 2] RISKY commit grades BKT incorrect exactly once, before Tower Defense")
	game._consequence_continued()
	check(game.phase == "Build" and game.gold == int(game.decision.current_threat().breach_gold), "[Stage 2] Breach uses Incident 2's authored gold budget")
	game.begin_defend()
	game._wave_cleared()
	check(game.phase == "Incident" and game.decision.resolved_threats == 2, "[Stage 2] TD win resolves Incident 2 and returns to story")
	check(game.story_overlay._mode == &"story", "[Stage 2] BREACH CONTAINED story shown before Incident 3")
	check(account.bkt.size() == 2, "[Stage 2] TD win applies no additional BKT update")
	game._story_continued()
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 2, "[Stage 2] Incident 3 follows containment")
	await unmount(game)

	print("-- [Stage 2] CRITICAL -> Game Over -> retry same incident --")
	account = Account.new()
	game = mount(account, stage2)
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.credits == 0 and account.clears == 0, "[Stage 2] CRITICAL fails without inventing loss rewards")
	check(account.checkpoint.threat_index == 0 and account.bkt.size() == 1, "[Stage 2] CRITICAL retry preserves the same incident and grades once")
	await unmount(game)
	game = mount(account, stage2)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 0, "[Stage 2] Retry resumes Incident 1, not a fresh opening")
	await unmount(game)

	print("-- [Stage 2] All incidents resolved -> Stage 2 Complete --")
	account = Account.new()
	game = mount(account, stage2)
	for i in game.decision.total_threats():
		choose(game, "SAFE")
	game._story_continued()
	check(game.phase == "Results" and account.clears == 1, "[Stage 2] All SAFE completes the story and clears the stage")
	check(account.credits == 50 + game.gold and account.stage_tasks == 1, "[Stage 2] Victory rewards match the existing production rules")
	await unmount(game)

	check(DecisionScenarios.stage_key("mod_01", 1) != DecisionScenarios.stage_key("mod_01", 2), "[Stage 2] Stage 1 and Stage 2 checkpoint keys never collide")

	# Module 3 Stage 1 introduces the reusable dialogue-emotion system (see
	# DialogueEmotion / DialogueScreenShake / DialoguePortrait). The legacy
	# overlay tested by verify_decision_stage.gd has no live portrait system
	# at all, so this is the one place that proves emotion metadata actually
	# reaches a real Portrait and triggers the shared screen-shake helper —
	# no Stage-1-specific animation code exists anywhere for this to work.
	print("-- [Mod3 Stage 1] Reusable emotion system: an authored 'angry' line reaches Daniel's portrait and the shared screen shake --")
	var stage3 := Context.stage_one_live()
	stage3.stage_id = 1
	stage3.module_id = "mod_03"
	account = Account.new()
	game = mount(account, stage3)
	check(game.story_overlay._mode == &"story", "[Mod3 Stage 1] Fresh launch includes opening dialogue")
	check(game.decision.total_threats() == 3, "[Mod3 Stage 1] Exactly 3 incidents load")
	check(is_equal_approx(game._enemy_health_scale(), 0.65), "[Mod3 Stage 1] Breach HP scale is 0.65, a new Module 3 curve independent of Module 2 Stage 9's 1.00")
	read_page(game)
	choose(game, "SAFE")
	choose(game, "SAFE")
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 2, "[Mod3 Stage 1] Incident 3 follows two SAFE resolutions with no breach in between")
	var overlay: Control = game.story_overlay
	var daniel_index: int = overlay._cast.find("Daniel")
	check(daniel_index != -1, "[Mod3 Stage 1] Daniel is a recognized speaker in Incident 3's cast, through the existing generic portrait system")
	var reached_angry := false
	var shake_triggered := false
	for i in 20:
		if daniel_index != -1 and overlay._portraits[daniel_index].emotion == "angry":
			reached_angry = true
			shake_triggered = overlay._window.has_meta("_shake_tween")
			break
		overlay._continue()
	check(reached_angry, "[Mod3 Stage 1] Daniel's portrait reaches the 'angry' emotion during the DRAMA beat")
	check(shake_triggered, "[Mod3 Stage 1] The angry beat triggers the existing reusable screen-shake helper")

	# Milestone: emotion pacing & presentation — Incident 3's DRAMA beat
	# authors TWO consecutive "angry" Daniel lines back to back. The second
	# one must not re-trigger a fresh shake (restraint rule), and the
	# following "sad" line must cleanly end the shake state.
	var first_shake_tween: Variant = overlay._window.get_meta("_shake_tween")
	overlay._continue()
	check(overlay._portraits[daniel_index].emotion == "angry", "[Mod3 Stage 1] The very next authored line is also 'angry' (two consecutive angry lines)")
	var second_shake_tween: Variant = overlay._window.get_meta("_shake_tween") if overlay._window.has_meta("_shake_tween") else null
	check(second_shake_tween == first_shake_tween, "[Mod3 Stage 1] The second consecutive 'angry' line does not spam a new screen shake")
	var reached_sad := false
	for i in 10:
		if overlay._portraits[daniel_index].emotion == "sad":
			reached_sad = true
			break
		overlay._continue()
	check(reached_sad, "[Mod3 Stage 1] The story continues on to Daniel's 'sad' line right after the angry beat")
	check(not overlay._window.has_meta("_shake_tween"), "[Mod3 Stage 1] Transitioning to 'sad' cleanly ends the angry shake state, no leftover")
	await unmount(game)

	# Milestone: evidence/investigation moments. Incident 3 ("Security
	# Callback") authors an investigation demo — see DecisionScenarios.
	# has_investigation — teaching that caller ID plus accurate/fresh
	# details still aren't independent identity proof.
	print("-- [Investigation] Incident 3's investigation shows only after its own dialogue is read, holds choices/timer, and never touches BKT/progression --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "SAFE")
	choose(game, "SAFE")
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 2, "[Investigation] Reached Incident 3 via two SAFE resolutions")
	check(not game.story_overlay._investigation_panel.visible, "[Investigation] The panel is not shown while Incident 3's own dialogue is still unread")
	var bkt_before_investigation: int = account.bkt.size()
	read_page(game)
	check(game.story_overlay._investigation_panel.visible, "[Investigation] The panel shows once Incident 3's dialogue is fully read")
	check(game.story_overlay._investigation_panel._title_label.text == "VERIFY THE CALLER", "[Investigation] The authored title renders")
	check(game.story_overlay._investigation_panel._prompt_label.text == "Which detail independently verifies that this caller is actually the bank?", "[Investigation] The authored prompt renders exactly")
	check(not game.story_overlay._choices_scroll.visible, "[Investigation] Choices are not actionable while the investigation is pending")
	check(not game.decision_timer_active, "[Timer] The decision timer never activates while the investigation is pending")
	var invalid_idx := -1
	for i in game.story_overlay._investigation_panel._items.size():
		if str(game.story_overlay._investigation_panel._items[i].get("id", "")) == "mod03_s1_i3_caller_id":
			invalid_idx = i
			break
	game.story_overlay._investigation_panel._select(invalid_idx)
	game.story_overlay._investigation_panel._analyze()
	check(game.story_overlay._investigation_panel._result_label.text.begins_with("EVIDENCE INSUFFICIENT") and game.story_overlay._investigation_panel._result_label.text.contains("Caller ID can be spoofed."),
		"[Investigation] An invalid item shows EVIDENCE INSUFFICIENT with its authored analysis")
	check(not game.story_overlay._choices_scroll.visible and account.bkt.size() == bkt_before_investigation,
		"[Investigation] An invalid attempt does not unlock choices, update BKT, or otherwise change progression")
	var valid_idx := -1
	for i in game.story_overlay._investigation_panel._items.size():
		if str(game.story_overlay._investigation_panel._items[i].get("id", "")) == "mod03_s1_i3_none":
			valid_idx = i
			break
	game.story_overlay._investigation_panel._select(valid_idx)
	game.story_overlay._investigation_panel._analyze()
	check(game.story_overlay._investigation_panel._result_label.text.begins_with("ANALYSIS CONFIRMED") and game.story_overlay._investigation_panel._result_label.text.contains("Daniel must verify through the independently established bank channel."),
		"[Investigation] The valid item shows ANALYSIS CONFIRMED with its authored analysis")
	game.story_overlay._investigation_panel._confirm_continue()
	check(overlay_dialogue_contains(game.story_overlay, "So everything they're showing me can be real..."), "[Investigation] The authored post-investigation reactive beat plays through the existing dialogue reader")
	drain_until_dialogue_done(game)
	check(game.story_overlay._choices_scroll.visible or game.story_overlay._mode == &"threat", "[Investigation] Choices are reachable once the post-investigation beat is read")
	check(not game.decision_timer_active, "[Timer] Incident 3 authors no timer, so it still correctly stays untimed after the investigation")
	check(account.bkt.size() == bkt_before_investigation, "[Investigation] Nothing about the investigation itself ever updates BKT")
	await unmount(game)

	print("-- [Investigation] Incident 3's four existing choices/outcomes are unchanged, and a TD-loss retry safely replays the investigation --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "SAFE")
	choose(game, "SAFE")
	read_page(game)
	var retry_valid_idx := -1
	for i in game.story_overlay._investigation_panel._items.size():
		if str(game.story_overlay._investigation_panel._items[i].get("id", "")) == "mod03_s1_i3_none":
			retry_valid_idx = i
			break
	game.story_overlay._investigation_panel._select(retry_valid_idx)
	game.story_overlay._investigation_panel._analyze()
	game.story_overlay._investigation_panel._confirm_continue()
	drain_until_dialogue_done(game)
	var incident3_choices: Array = game.decision.current_threat_for_display().choices
	var incident3_risky_idx := -1
	for i in incident3_choices.size():
		if str(incident3_choices[i].get("outcome", "")) == "RISKY":
			incident3_risky_idx = i
			break
	game.story_overlay._choose(incident3_risky_idx)
	read_page(game)
	check(game.decision.flow_state == "BREACH", "[Investigation] Incident 3's RISKY outcome still enters breach exactly as authored, unaffected by the investigation")
	game._consequence_continued()
	game.begin_defend()
	for i in 5:
		game._enemy_leaked()
	check(game.phase == "Results", "[Investigation] Simulated TD loss reaches Results, same as the existing loss path")
	await unmount(game)
	game = mount(account, stage3)
	check(game.decision.threat_index == 2, "[Investigation] Retry resumes Incident 3, not a fresh Incident 1")
	read_page(game)
	check(game.story_overlay._investigation_panel.visible and not game.story_overlay._investigation_panel.is_resolved(),
		"[Investigation] The retried attempt safely replays the investigation from scratch — no memory of the earlier attempt's selection")
	game.story_overlay._investigation_panel._select(retry_valid_idx)
	game.story_overlay._investigation_panel._analyze()
	game.story_overlay._investigation_panel._confirm_continue()
	drain_until_dialogue_done(game)
	choose(game, "SAFE")
	check(game.story_overlay._mode == &"story" and overlay_dialogue_contains(game.story_overlay, "isn't a random robocall"),
		"[Investigation] SAFE after the retried investigation still reaches Stage 1's unchanged ending")
	await unmount(game)

	# Milestone: optional timed decisions. Module 3 Stage 1 Incident 2 ("Stay
	# on the Line") authors ONE demo timer (14s, timeout_outcome RISKY) —
	# every other choice on Stage 1 stays manually selectable exactly as
	# before. This is the one place these mechanics can be proven end to
	# end: the legacy overlay tested by verify_decision_stage.gd has no
	# timer system at all.
	print("-- [Timer] The countdown only runs once Incident 2's own dialogue is fully read --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "SAFE")
	check(not game.decision_timer_active, "[Timer] Incident 1 (untimed) never activates a timer")
	check(game.story_overlay._mode == &"threat" and not game.story_overlay._dialogue_done, "[Timer] Incident 2's own dialogue is unread yet")
	check(not game.decision_timer_active and not game.story_overlay._timer_row.visible, "[Timer] Timer does not run during Incident 2's opening dialogue/typing")
	read_page(game)
	check(game.decision_timer_active, "[Timer] Timer activates the moment Incident 2's choices become actionable")
	check(is_equal_approx(game.decision_seconds_left, 14.0) and is_equal_approx(game.decision_seconds_total, 14.0),
		"[Timer] The authored 14-second duration is used exactly under normal accessibility mode")
	check(game.story_overlay._timer_row.visible, "[Timer] The countdown row is visible for a timed incident")
	check(game.story_overlay._timer_text.text.contains("THE CALLER SAYS THE TRANSFER MAY PROCESS"),
		"[Timer] The authored pressure label is shown, not just a generic 'DECIDE'")
	await unmount(game)

	print("-- [Timer] Pause and dialogue review both freeze the countdown; neither resets it --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.toggle_pause()
	game.advance_decision_timer(5.0)
	check(is_equal_approx(game.decision_seconds_left, 14.0), "[Timer] Pause freezes the countdown exactly, no drift")
	game.toggle_pause()
	game.story_overlay._open_review()
	game.advance_decision_timer(5.0)
	check(is_equal_approx(game.decision_seconds_left, 14.0), "[Timer] Opening the dialogue review also freezes the countdown")
	game.story_overlay._close_review()
	check(is_equal_approx(game.decision_seconds_left, 14.0), "[Timer] Closing the review does not reset or otherwise change the countdown")
	await unmount(game)

	print("-- [Timer] A manual choice before expiry stops the timer immediately; it cannot fire afterward --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.advance_decision_timer(5.0)
	var safe_choices: Array = game.decision.current_threat_for_display().choices
	var safe_idx := 0
	for i in safe_choices.size():
		if safe_choices[i].outcome == "SAFE":
			safe_idx = i
			break
	game.story_overlay._choose(safe_idx)
	check(not game.decision_timer_active, "[Timer] A manual choice immediately stops the timer")
	game.advance_decision_timer(100.0)
	# Incident 1's own SAFE choice already graded one BKT entry on the way
	# here (see the leading choose(game, "SAFE") above) — this incident's
	# choice is staged but not yet committed until its consequence screen is
	# read, so the bkt log must still show exactly that ONE prior entry.
	check(game.decision.pending_outcome == "SAFE" and account.bkt.size() == 1, "[Timer] The timer cannot fire after commit; advancing it further changes nothing")
	read_page(game)
	check(account.bkt == [["vishing", true], ["vishing", true]], "[Timer] The manually accepted SAFE choice still grades exactly once, normally")
	await unmount(game)

	print("-- [Timer] Click-vs-timeout race: a click processed the same frame the deadline is crossed cannot double-commit --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.advance_decision_timer(100.0)
	check(not game.decision_timer_active and game.decision.is_breach_active() and account.bkt.size() == 2, "[Timer] The timeout itself commits exactly once")
	game._choice_selected(0)
	check(account.bkt.size() == 2, "[Timer] A stale click delivered right after expiry cannot add a second commit/grade")
	await unmount(game)

	print("-- [Timer] Timeout resolves the authored RISKY choice deterministically, independent of display shuffle --")
	var timed_out_labels: Dictionary = {}
	for attempt in 8:
		account = Account.new()
		game = mount(account, stage3)
		read_page(game); choose(game, "SAFE"); read_page(game)
		game.advance_decision_timer(13.9)
		check(game.decision_timer_active and account.bkt.size() == 1, "[Timer] No early timeout before the deadline (attempt %d)" % attempt)
		game.advance_decision_timer(0.2)
		check(not game.decision_timer_active and game.decision.is_breach_active(), "[Timer] Timeout commits RISKY and enters breach (attempt %d)" % attempt)
		check(account.bkt.size() == 2 and account.bkt[1] == ["vishing", false], "[Timer] Timeout grades BKT exactly once, negatively (attempt %d)" % attempt)
		check(game.story_overlay._mode == &"consequence" and overlay_banner_text(game.story_overlay) == "TIME EXPIRED / BREACH DETECTED",
			"[Timer] Timeout shows the TIME EXPIRED / BREACH DETECTED banner (attempt %d)" % attempt)
		check(overlay_dialogue_contains(game.story_overlay, "CALL STATUS") and overlay_dialogue_contains(game.story_overlay, "I waited too long"),
			"[Timer] The authored timeout_story_event content is visible on screen (attempt %d)" % attempt)
		timed_out_labels[str(game.decision.pending_choice.get("label", ""))] = true
		await unmount(game)
	check(timed_out_labels.size() == 1, "[Timer] The SAME authored RISKY choice times out every attempt, across 8 independent shuffles")

	print("-- [Timer] Retry after a TD loss starts a brand-new, full-duration timer for the next attempt --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.advance_decision_timer(100.0)
	game._consequence_continued() # DEPLOY DEFENSES
	check(game.phase == "Build", "[Timer] Timeout still reaches Tower Defense through the unchanged breach flow")
	game.begin_defend()
	for i in 5:
		game._enemy_leaked()
	check(game.phase == "Results", "[Timer] Simulated TD loss reaches Results, same as the existing loss path")
	await unmount(game)
	game = mount(account, stage3)
	read_page(game)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 1, "[Timer] Retry resumes Incident 2, not a fresh Incident 1")
	read_page(game)
	check(game.decision_timer_active and is_equal_approx(game.decision_seconds_left, 14.0),
		"[Timer] The retried attempt gets a brand-new, full 14-second timer — not wherever the failed attempt left off")
	await unmount(game)

	print("-- [Timer] Save/reload near expiry cannot reset the countdown back to full duration --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.advance_decision_timer(12.0)
	check(is_equal_approx(game.decision_seconds_left, 2.0), "[Timer] Countdown is nearly expired just before the simulated exit")
	# The checkpoint now persists the remaining time whenever a timed
	# decision is actively counting down (see _save_checkpoint()/
	# advance_decision_timer()'s once-per-second throttle) — resuming still
	# replays the incident's own (unread) dialogue from the top exactly as
	# before, but once that's read again the timer resumes at the time it
	# actually had left, never a fresh full duration. This is the fix for the
	# "reload for a new clock" exploit.
	await unmount(game)
	game = mount(account, stage3)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 1 and not game.story_overlay._dialogue_done,
		"[Timer] Resuming mid-decision still replays Incident 2's own dialogue from the top")
	check(not game.decision_timer_active, "[Timer] No timer is active until that replayed dialogue is read again")
	read_page(game)
	check(game.decision_timer_active and is_equal_approx(game.decision_seconds_left, 2.0),
		"[Timer] Re-reading the dialogue resumes the STALE ~2 seconds left, never a fresh full 14")
	game.advance_decision_timer(2.1)
	check(not game.decision_timer_active and game.decision.is_breach_active(),
		"[Timer] The resumed countdown still expires at (approximately) when it originally would have, not 14 fresh seconds later")
	await unmount(game)

	print("-- [Timer] Repeated near-expiry save/reload cannot loop for infinite time: remaining time only ever shrinks --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.advance_decision_timer(9.0)
	await unmount(game)
	game = mount(account, stage3)
	read_page(game)
	var first_remaining: float = game.decision_seconds_left
	check(first_remaining < 6.0, "[Timer] First reload resumes with well under the full 14 seconds (~5 left)")
	game.advance_decision_timer(2.0)
	await unmount(game)
	game = mount(account, stage3)
	read_page(game)
	check(game.decision_seconds_left < first_remaining, "[Timer] A second reload resumes with even LESS time than the first — remaining time only ever shrinks, never resets")
	await unmount(game)

	print("-- [Timer] A checkpoint saved before the timer ever activated still grants the normal full duration (regression) --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE")
	await unmount(game)
	game = mount(account, stage3)
	check(not game.decision_timer_active, "[Timer] No timer is active before Incident 2's dialogue is (re-)read")
	read_page(game)
	check(game.decision_timer_active and is_equal_approx(game.decision_seconds_left, 14.0),
		"[Timer] Reloading BEFORE the timer ever started still grants the full authored duration — the fix only ever removes stale slack, never legitimate time")
	await unmount(game)

	print("-- [Timer] Accessibility: timed_decision_assist normal/extended/off ==")
	var settings := root.get_node("SettingsService")
	var assist_before: String = settings.timed_decision_assist
	settings.timed_decision_assist = "extended"
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	check(game.decision_timer_active and is_equal_approx(game.decision_seconds_total, 14.0 * 1.75),
		"[Timer] 'extended' scales the authored duration by ~1.75x")
	await unmount(game)

	settings.timed_decision_assist = "off"
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	check(not game.decision_timer_active and not game.story_overlay._timer_row.visible, "[Timer] 'off' suppresses the automatic timeout and hides the countdown entirely")
	game.advance_decision_timer(9999.0)
	check(account.bkt.size() == 1 and not game.decision.is_breach_active(), "[Timer] 'off' means no amount of elapsed time can time out the decision")
	choose(game, "RISKY")
	check(account.bkt.size() == 2, "[Timer] 'off' never blocks story progression — the decision remains manually selectable and still resolves")
	await unmount(game)

	settings.timed_decision_assist = "normal"
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	check(game.decision_timer_active and is_equal_approx(game.decision_seconds_total, 14.0), "[Timer] 'normal' restores the plain authored duration")
	await unmount(game)
	settings.timed_decision_assist = assist_before

	print("-- [Timer] reduced_motion changes presentation only, never timer duration/logic --")
	var reduced_motion_before: bool = settings.reduced_motion
	settings.reduced_motion = true
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	check(game.decision_timer_active and is_equal_approx(game.decision_seconds_total, 14.0), "[Timer] reduced_motion=true does not change the authored duration")
	game.advance_decision_timer(13.9)
	check(game.decision_timer_active, "[Timer] reduced_motion=true does not change expiry timing (no early timeout)")
	game.advance_decision_timer(0.2)
	check(not game.decision_timer_active and game.decision.is_breach_active(), "[Timer] reduced_motion=true still times out normally at the authored deadline")
	settings.reduced_motion = reduced_motion_before
	await unmount(game)

	# Milestone: interactive vishing call interface. Module 3 Stage 1 Incident
	# 2 also authors a "call" block (see DecisionScenarios.has_call) — the
	# same incident used for the timer demo above, so this proves the call
	# presentation coexists with dialogue/emotions/the decision timer/
	# story_event, not just that it renders in isolation.
	print("-- [Call] The call panel activates with Incident 2's own screen and coexists with dialogue/timer/story_event --")
	account = Account.new()
	game = mount(account, stage3)
	check(not game.call_active and not game.story_overlay._call_panel.visible, "[Call] Incident 1 (no call authored) never activates the call presentation")
	read_page(game)
	choose(game, "SAFE")
	check(game.call_active and game.story_overlay._call_panel.visible, "[Call] Incident 2's authored call activates immediately with its screen (not gated on dialogue being fully read, unlike the decision timer)")
	check(game.story_overlay._call_panel._caller_label.text == "BANK FRAUD DEPARTMENT", "[Call] Caller name renders as authored")
	check(game.story_overlay._call_panel._number_label.text == "PRIVATE NUMBER", "[Call] Number renders as authored")
	check(game.story_overlay._call_panel._status_label.text == "CONNECTED", "[Call] Status renders as authored")
	check(not game.story_overlay._call_panel._end_button.visible, "[Call] END CALL is not offered for the Stage 1 demo — its SAFE choice already IS 'end the call', so exposing a separate END CALL control here would conflict with the authored decision semantics (explicitly allowed to stay disabled)")
	read_page(game)
	check(game.decision_timer_active, "[Call] The decision timer still activates normally once Incident 2's dialogue is fully read, alongside the call")
	game.advance_call_duration(5.0)
	game.advance_decision_timer(3.0)
	check(is_equal_approx(game.call_duration_elapsed, 5.0) and is_equal_approx(game.decision_seconds_left, 11.0),
		"[Call] Call duration and the decision countdown are independent clocks — advancing one never changes the other")
	check(game.story_overlay._call_panel._duration_label.text == "00:05" and game.story_overlay._timer_text.text.contains("11s"),
		"[Call] Both the call duration and the decision countdown render their own separate values on screen at once")
	await unmount(game)

	print("-- [Call] MUTE/SPEAKER are purely local — no BKT, outcome, or progression effect --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	game.story_overlay._call_panel._toggle_mute()
	game.story_overlay._call_panel._toggle_speaker()
	check(game.story_overlay._call_panel.is_muted() and game.story_overlay._call_panel.is_speaker_on(), "[Call] Mute/speaker toggle their own visual state")
	# account.bkt already holds Incident 1's own SAFE grade from the leading
	# choose(game, "SAFE") above — Incident 2's own choice is still only
	# staged, not yet committed, so the log must show exactly that one prior entry.
	check(account.bkt.size() == 1 and game.decision.pending_outcome.is_empty() and game.decision_timer_active,
		"[Call] Toggling mute/speaker leaves BKT, the pending choice, and the still-running decision timer completely untouched")
	await unmount(game)

	print("-- [Call] The call panel coexists with an authored story_event and Daniel's portrait/emotion presentation --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game)
	check(not game.story_overlay._portraits.is_empty(), "[Call] Emotion/portrait presentation still renders normally with the call panel visible")
	var critical_choices: Array = game.decision.current_threat_for_display().choices
	var critical_idx := 0
	for i in critical_choices.size():
		if critical_choices[i].outcome == "CRITICAL":
			critical_idx = i
			break
	game.story_overlay._choose(critical_idx)
	check(overlay_dialogue_contains(game.story_overlay, "ACCOUNT SECURITY REQUEST"), "[Call] The chosen choice's own authored story_event still renders through the same dialogue reader")
	# The call row is scoped to the threat's OWN show_threat() screen, exactly
	# like the decision timer row (see set_decision_timer_visible()) — the
	# consequence screen doesn't re-authorize it, so it hides here the same
	# way the timer row already does. Nothing about the story_event content
	# itself was disrupted by the call having been visible right before it.
	check(not game.story_overlay._call_panel.visible, "[Call] The call row hides on the consequence screen, consistent with the timer row's own scoping — the story_event content it hands off to isn't affected")
	await unmount(game)

	print("-- [Call] Modules 1/2 and every other Module 3 Stage 1 incident remain call-free (regression) --")
	account = Account.new()
	game = mount(account)
	check(not game.call_active and not game.story_overlay._call_panel.visible, "[Call] Module 1 Stage 1 (no call authored anywhere) never shows the call panel")
	await unmount(game)
	account = Account.new()
	game = mount(account, stage3)
	read_page(game); choose(game, "SAFE"); read_page(game); choose(game, "SAFE"); read_page(game)
	check(not game.call_active and not game.story_overlay._call_panel.visible, "[Call] Incident 3 (no call authored) is unaffected by Incident 2's call")
	await unmount(game)

	# Milestone: character memory / reactive dialogue. Module 3 Stage 1
	# Incident 1 authors "memory" on its SAFE and both RISKY choices (see
	# mod03_s1_bank_verification in decision_scenarios.json) — the same
	# incident used below to prove canonical-resolution commit timing
	# end to end, since that needs a real running match/TD encounter.
	print("-- [Memory] A resolved SAFE choice commits its authored memory exactly once, immediately --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "SAFE")
	check(account.story_memory.get("mod03_s1_bank_verification") == "independent" and account.story_memory_writes == 1,
		"[Memory] SAFE's own canonical resolution point (right here) commits its memory exactly once")
	await unmount(game)

	print("-- [Memory] A RISKY choice's memory stays pending through the breach; TD victory is its canonical resolution point --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	if not game.story_overlay._dialogue_done:
		read_page(game)
	var caller_knowledge_choices: Array = game.decision.current_threat_for_display().choices
	var caller_knowledge_idx := -1
	for i in caller_knowledge_choices.size():
		if str(caller_knowledge_choices[i].get("memory", {}).get("mod03_s1_bank_verification", "")) == "caller_knowledge":
			caller_knowledge_idx = i
			break
	game.story_overlay._choose(caller_knowledge_idx)
	read_page(game)
	check(game.decision.flow_state == "BREACH" and account.story_memory.is_empty() and account.story_memory_writes == 0,
		"[Memory] Committing RISKY enters the breach but writes nothing yet")
	check(game.decision.pending_breach_memory.get("mod03_s1_bank_verification") == "caller_knowledge",
		"[Memory] The choice's own memory is held pending, keyed exactly as authored")
	game._consequence_continued()
	check(game.phase == "Build", "[Memory] Still reaches Tower Defense through the unchanged breach flow")
	game.begin_defend()
	game._spawn_enemy()
	var win_enemy: Node = game.hud.battle.track.get_child(0)
	win_enemy.match_context = Context.stage_one_preview()
	win_enemy.take_damage(9999)
	game._wave_cleared()
	check(account.story_memory.get("mod03_s1_bank_verification") == "caller_knowledge" and account.story_memory_writes == 1,
		"[Memory] TD victory — the incident's canonical resolution — commits the pending RISKY memory exactly once")
	check(game.decision.pending_breach_memory.is_empty(), "[Memory] Pending memory is cleared once committed, so it can never be committed twice")
	game._wave_cleared()
	check(account.story_memory_writes == 1, "[Memory] A stray extra _wave_cleared() call (already resolved) cannot duplicate the commit")
	await unmount(game)

	print("-- [Memory] A RISKY TD loss discards the pending memory outright; it is never remembered --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	if not game.story_overlay._dialogue_done:
		read_page(game)
	var loss_choices: Array = game.decision.current_threat_for_display().choices
	var loss_idx := -1
	for i in loss_choices.size():
		if str(loss_choices[i].get("memory", {}).get("mod03_s1_bank_verification", "")) == "caller_knowledge":
			loss_idx = i
			break
	game.story_overlay._choose(loss_idx)
	read_page(game)
	game._consequence_continued()
	game.begin_defend()
	for i in 5:
		game._enemy_leaked()
	check(game.phase == "Results", "[Memory] Simulated TD loss reaches Results, same as the existing loss path")
	check(account.story_memory.is_empty() and account.story_memory_writes == 0, "[Memory] TD loss commits nothing — the abandoned RISKY attempt is never remembered")
	check(game.decision.pending_breach_memory.is_empty(), "[Memory] The pending memory is discarded, not merely left uncommitted")
	await unmount(game)

	print("-- [Memory] Retry after that TD loss can commit a DIFFERENT final memory — the canonical, not the abandoned, attempt --")
	game = mount(account, stage3)
	read_page(game)
	check(game.decision.threat_index == 0, "[Memory] Retry resumes Incident 1 fresh, not wherever the failed attempt left off")
	choose(game, "SAFE")
	check(account.story_memory.get("mod03_s1_bank_verification") == "independent" and account.story_memory_writes == 1,
		"[Memory] The retried attempt's own SAFE choice commits its OWN memory — the earlier abandoned RISKY attempt's memory is nowhere in the log")
	await unmount(game)

	print("-- [Memory] CRITICAL never persists memory — Game Over rewinds the incident entirely --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "CRITICAL")
	check(game.phase == "Results", "[Memory] CRITICAL still reaches Game Over through the unchanged flow")
	check(account.story_memory.is_empty() and account.story_memory_writes == 0, "[Memory] CRITICAL commits no memory at all — an unresolved incident is never remembered")
	await unmount(game)

	print("-- [Memory] Reloading mid-breach reopens the incident as a fresh review, correctly discarding the old pending memory (retry rule) --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	if not game.story_overlay._dialogue_done:
		read_page(game)
	var reload_choices: Array = game.decision.current_threat_for_display().choices
	var reload_idx := -1
	for i in reload_choices.size():
		if str(reload_choices[i].get("memory", {}).get("mod03_s1_bank_verification", "")) == "caller_knowledge":
			reload_idx = i
			break
	game.story_overlay._choose(reload_idx)
	read_page(game)
	check(game.decision.pending_breach_memory.get("mod03_s1_bank_verification") == "caller_knowledge", "[Memory] Pending memory is set just before the simulated reload")
	await unmount(game)
	game = mount(account, stage3)
	check(game.decision.flow_state == "THREAT" and game.decision.pending_breach_memory.is_empty(),
		"[Memory] Reopening mid-breach as a review clears the old pending memory — it reflects a fresh re-choice, not the abandoned RISKY attempt")
	read_page(game)
	choose(game, "SAFE")
	check(account.story_memory.get("mod03_s1_bank_verification") == "independent" and account.story_memory_writes == 1,
		"[Memory] The reopened review's own new choice commits correctly, with no leftover writes from the discarded attempt")
	await unmount(game)

	print("-- [Memory] Stage 1 demo end to end: a real playthrough's memory reaches the reactive ending line, and Modules 1/2 stay unaffected --")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "SAFE")
	read_page(game); choose(game, "SAFE"); read_page(game)
	choose(game, "SAFE")
	read_page(game)
	check(overlay_dialogue_contains(game.story_overlay, "Calling the bank myself was the only thing that actually answered anything."),
		"[Memory] The SAFE playthrough's own reactive Daniel line actually appears once memory reaches the real live scene")
	check(not overlay_dialogue_contains(game.story_overlay, "I kept asking them to prove themselves with information they already had."),
		"[Memory] A non-matching variant's line does not appear")
	check(overlay_dialogue_contains(game.story_overlay, "BlueTech.") and overlay_dialogue_contains(game.story_overlay, "PRIVATE NUMBER"),
		"[Memory] Convergence: the BlueTech transaction clue and PRIVATE NUMBER cliffhanger are unchanged")
	await unmount(game)

	account = Account.new()
	game = mount(account)
	check(account.story_memory.is_empty(), "[Memory] [Regression] Module 1 Stage 1 authors no memory at all — resolving its own incidents writes nothing")
	read_page(game)
	choose(game, "SAFE")
	check(account.story_memory.is_empty(), "[Memory] [Regression] Module 1 Stage 1's own SAFE choice commits no memory (it authors none)")
	await unmount(game)
	account = Account.new()
	var mod2_stage1 := Context.stage_one_live()
	mod2_stage1.module_id = "mod_02"
	game = mount(account, mod2_stage1)
	read_page(game)
	choose(game, "SAFE")
	check(account.story_memory.is_empty(), "[Memory] [Regression] Module 2 Stage 1's own SAFE choice commits no memory (it authors none)")
	await unmount(game)

	check(fingerprint() == before, "Tests left actual player/mastery/tasks/queue unchanged")
	print("[LIVE STAGE ONE] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
