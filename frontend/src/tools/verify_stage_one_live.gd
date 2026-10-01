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
	var clear_keys: Array[String] = []
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
		clear_keys.append("%s:%d" % [_module_id, _id])
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
	inspect_school_email(match_node)
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
	var line_count: int = maxi(1, overlay._lines.size() - overlay._line_index)
	for i in line_count:
		if overlay._typing:
			overlay._continue() # Reveal without skipping or committing a choice.
		if not overlay._mail.is_empty() and not overlay._mail_read:
			overlay._open_mail()
			if overlay._phone_enabled:
				overlay._phone._unlock()
				overlay._phone._navigate("mail")
				overlay._phone._open_message()
			overlay._close_mail()
		overlay._continue()

func inspect_school_email(match_node: Control) -> void:
	var workspace: Control = match_node.story_overlay
	if workspace._phone_enabled and not workspace._investigation_config.is_empty():
		workspace._open_phone_investigation()
		var phone: Control = workspace._phone
		phone._unlock()
		phone._navigate("mail")
		phone._open_message()
		for item: Dictionary in phone._items:
			var app: String = str(item.get("phone_app", "mail"))
			var id: String = str(item.get("id", ""))
			phone._navigate(app)
			if app == "mail":
				phone._open_message()
				phone._inspect(id)
			else:
				for card: Dictionary in phone._data.get(app, []):
					if str(card.get("evidence_id", "")) == id:
						phone._open_card(card)
						break
			var fields: Array = item.get("fields", [])
			for field_index: int in fields.size():
				phone._reveal_field(id, field_index)
		check(phone.is_complete(), "All authored phone evidence must be inspected")
		phone._finish()
		drain_until_dialogue_done(match_node)
		return
	var panel: Control = match_node.story_overlay._investigation_panel
	if not panel.visible:
		return
	if panel._inspection_mode:
		for button: Button in panel._item_buttons:
			button.pressed.emit()
	else:
		# Later-module test playthroughs must also use their actual evidence
		# gate instead of invoking an invisible decision button directly.
		for index: int in panel._items.size():
			if bool(panel._items[index].get("valid", false)):
				panel._select(index)
				panel._analyze()
				break
	panel._confirm_continue()
	drain_until_dialogue_done(match_node)

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
		if not overlay._mail.is_empty() and not overlay._mail_read:
			overlay._open_mail()
			if overlay._phone_enabled:
				overlay._phone._unlock()
				overlay._phone._navigate("mail")
				overlay._phone._open_message()
			overlay._close_mail()
		overlay._continue()

func shot(match_node: Control, name: String) -> void:
	await settle()
	var rect := root.get_visible_rect()
	check(rect.encloses(match_node.hud.body.get_global_rect()), name + ": battlefield fits")
	if match_node.hud.pause_button.is_visible_in_tree():
		check(rect.encloses(match_node.hud.pause_button.get_global_rect()), name + ": pause fits")
	if match_node.story_overlay.is_visible_in_tree():
		if match_node.story_overlay._window.is_visible_in_tree():
			check(rect.encloses(match_node.story_overlay._window.get_global_rect()), name + ": story fits")
		if match_node.story_overlay._school_cast and is_instance_valid(match_node.story_overlay._conversation) and match_node.story_overlay._conversation.visible:
			for portrait: Control in match_node.story_overlay._portraits:
				if portrait.is_visible_in_tree():
					var face_bottom: float = portrait.global_position.y + portrait.size.y * 0.28 if portrait.body_texture != null else portrait.get_global_rect().end.y
					check(face_bottom <= match_node.story_overlay._speech_box.global_position.y, name + ": face stays above dialogue")
		if match_node.story_overlay._review_open:
			check(rect.encloses(match_node.story_overlay._review_panel.get_global_rect()), name + ": review fits")
			check(rect.encloses(match_node.story_overlay._review_close.get_global_rect()), name + ": review return fits")
		if match_node.story_overlay._continue_button.is_visible_in_tree():
			check(rect.encloses(match_node.story_overlay._continue_button.get_global_rect()), name + ": story Continue fits")
		if match_node.story_overlay._story_pause.is_visible_in_tree():
			check(rect.encloses(match_node.story_overlay._story_pause.get_global_rect()), name + ": compact story pause fits")
		if match_node.story_overlay._phone_enabled and match_node.story_overlay._choices_scroll.is_visible_in_tree():
			for card: Button in match_node.story_overlay._choice_buttons:
				check(rect.encloses(card.get_global_rect()), name + ": all three decision cards fit without scrolling")
	check(not match_node.hud.preview_label.text.contains("NOTHING SAVED"), "Normal session is not labeled preview")
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/live_stage_" + name + ".png")

func _verify_school_stage_three() -> void:
	print("-- [School Stage 3] Phone investigation, recovery, class warning and distinct map --")
	var context: MatchContext = Context.stage_one_live()
	context.stage_id = 3
	context.module_id = "mod_01"
	var account: Account = Account.new()
	var game: Control = mount(account, context)
	check(game.config.name == "Someone Got In" and game._key() == "mod_01:3", "[School Stage 3] Correct story and isolated checkpoint")
	check(game.story_overlay._mode == &"story" and game.story_overlay._phone_enabled and game.story_hp == 3, "[School Stage 3] Opening, phone and three hearts enabled")
	check(game.story.guide_speaker == "Ms. Reyes" and is_equal_approx(game._enemy_health_scale(), 0.7), "[School Stage 3] School cast with existing difficulty")
	var board: Node2D = game.hud.battle.board
	check(board.path_cells.size() == 29 and board.waypoints.size() == 8, "[School Stage 3] New inward route preserves travel distance")
	check(board.waypoints[0] == Vector2i(0, 3) and board.waypoints.back() == Vector2i(8, 3), "[School Stage 3] Distinct entry and inner home position")
	check(board.cell_reason(Vector2i(2, 2)) != "" and board.cell_reason(Vector2i(6, 2)) == "", "[School Stage 3] Placement follows new path")
	check(game.hud.battle.track.curve.get_point_position(7) == board.center(Vector2i(8, 3)), "[School Stage 3] Enemy path reaches the visible home")
	check(board.get_node("Terrain").path_cells == board.path_cells, "[School Stage 3] Shared geometric terrain uses the authored route")
	await shot(game, "stage3_school_opening")
	read_page(game)
	read_page(game)
	check(not game.decision_timer_active and not game.story_overlay._choices_scroll.visible, "[School Stage 3] Reading and inspection precede timed choices")
	var phone: Control = game.story_overlay._phone
	phone._finish()
	check(not game.decision_timer_active and phone._confirm.disabled, "[School Stage 3] Cannot skip the evidence checklist")
	inspect_school_email(game)
	check(game.decision_timer_active and phone.is_complete(), "[School Stage 3] Checklist confirmation starts decision timer")
	await shot(game, "stage3_school_decision")
	choose(game, "SAFE")
	check(game.decision.threat_index == 1 and account.bkt.size() == 1, "[School Stage 3] SAFE advances once")
	choose(game, "RISKY")
	check(game.decision.awaiting_breach_deploy() and game.story_hp == 3, "[School Stage 3] RISKY preserves hearts and waits for deployment")
	game._consequence_continued()
	check(game.phase == "Build" and game.gold == 16, "[School Stage 3] Incident 2 retains its gold budget")
	await shot(game, "stage3_school_map")
	game.begin_defend()
	game._wave_cleared()
	check(game.decision.resolved_threats == 2 and game.story_overlay._mode == &"story", "[School Stage 3] Containment returns to dialogue")
	check(account.bkt.size() == 2, "[School Stage 3] Containment does not double-grade")
	read_page(game)
	check(game.decision.threat_index == 2, "[School Stage 3] Earlier forwarded invite follows recovery")
	choose(game, "CRITICAL")
	check(game.story_hp == 2 and account.checkpoint.threat_index == 2 and account.clears == 0, "[School Stage 3] Failure keeps Incident 3 with one less heart")
	await unmount(game)
	game = mount(account, context)
	check(game.story_hp == 2 and game.decision.threat_index == 2, "[School Stage 3] Reload preserves hearts and current incident")
	read_page(game)
	check(not game.decision_timer_active and game.story_overlay._phone._inspected.is_empty(), "[School Stage 3] Retry requires fresh inspection")
	inspect_school_email(game)
	game.story_overlay._review_button.pressed.emit()
	check(game.story_overlay._review_open, "[School Stage 3] Logs open while deciding")
	game.advance_decision_timer(44.0)
	check(game.story_hp == 2, "[School Stage 3] Full 45-second allowance")
	game.advance_decision_timer(1.1)
	check(game.story_hp == 1 and not game.decision.is_breach_active(), "[School Stage 3] Timer runs in Logs; expiry costs one heart")
	read_page(game)
	choose(game, "CRITICAL")
	check(game.story_hp == 0, "[School Stage 3] Third failure leaves the established last chance")
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.checkpoint.is_empty() and account.clears == 0, "[School Stage 3] Fourth failure discards attempt even at Incident 3")
	await unmount(game)
	game = mount(account, context)
	check(game.story_hp == 3 and game.decision.threat_index == 0 and game.story_overlay._mode == &"story", "[School Stage 3] Exhaustion restarts at the opening")
	await unmount(game)

	account = Account.new()
	game = mount(account, context)
	for incident: int in range(3):
		if game.story_overlay._mode == &"story":
			read_page(game)
		read_page(game)
		check(not game.decision_timer_active, "[School Stage 3] Incident %d waits for inspection" % incident)
		var evidence_phone: Control = game.story_overlay._phone
		evidence_phone._unlock()
		var reference: Dictionary = evidence_phone._items[2]
		var app: String = str(reference.phone_app)
		evidence_phone._navigate(app)
		for card: Dictionary in evidence_phone._data[app]:
			if str(card.get("evidence_id", "")) == str(reference.id):
				evidence_phone._open_card(card)
				break
		root.size = Vector2i(844, 390)
		await shot(game, "stage3_school_phone_%d" % incident)
		check(root.get_visible_rect().encloses(evidence_phone._guide_panel.get_global_rect()), "[School Stage 3] Checklist fits small landscape")
		check(root.get_visible_rect().encloses(evidence_phone._close.get_global_rect()), "[School Stage 3] Phone Close remains reachable")
		root.size = Vector2i(1280, 720)
		inspect_school_email(game)
		check(game.story_overlay._phone.is_complete(), "[School Stage 3] All evidence cards reachable for incident %d" % incident)
		await shot(game, "stage3_school_choices_%d" % incident)
		choose(game, "SAFE")
	read_page(game)
	check(game.phase == "Results" and account.clears == 1 and account.bkt.size() == 3, "[School Stage 3] All SAFE reaches ending and completes once")
	check(account.stage_tasks == 1 and account.credits == 50 + game.gold, "[School Stage 3] Standard rewards preserved")
	await unmount(game)

func _verify_school_stage_four() -> void:
	print("-- [School Stage 4] Authority checks, private sharing, timers and switchback map --")
	var context: MatchContext = Context.stage_one_live()
	context.stage_id = 4
	context.module_id = "mod_01"
	var account: Account = Account.new()
	var game: Control = mount(account, context)
	check(game._key() == "mod_01:4" and game.config.name == "The Impostor Inside", "[School Stage 4] Isolated stage and school story")
	check(game.story_overlay._mode == &"story" and game.story_overlay._phone_enabled and game.story_hp == 3, "[School Stage 4] Opening, phone and three hearts enabled")
	check(game.story.guide_speaker == "Ms. Reyes" and is_equal_approx(game._enemy_health_scale(), 0.75), "[School Stage 4] Existing cast and combat difficulty")
	var board: Node2D = game.hud.battle.board
	check(board.path_cells.size() == 29 and board.waypoints.size() == 8 and board.waypoints != board.WAYPOINTS, "[School Stage 4] Distinct switchbacks preserve route length")
	check(board.cell_reason(Vector2i(3, 4)) != "" and board.cell_reason(Vector2i(4, 4)) == "", "[School Stage 4] Placement follows the new route")
	check(game.hud.battle.track.curve.get_point_position(7) == board.center(Vector2i(12, 5)), "[School Stage 4] Enemy path reaches the displayed home")
	check(board.get_node("Terrain").path_cells == board.path_cells, "[School Stage 4] Painted path and gameplay path agree")
	await shot(game, "stage4_school_opening")
	for incident: int in range(3):
		if game.story_overlay._mode == &"story":
			read_page(game)
		read_page(game)
		check(not game.decision_timer_active and not game.story_overlay._choices_scroll.visible, "[School Stage 4] Investigation gates choices and timer")
		var phone: Control = game.story_overlay._phone
		phone._finish()
		check(phone._confirm.disabled and not game.decision_timer_active, "[School Stage 4] Unfinished checklist cannot be skipped")
		phone._unlock()
		var reference: Dictionary = phone._items.back()
		var app: String = str(reference.phone_app)
		phone._navigate(app)
		for card: Dictionary in phone._data[app]:
			if str(card.get("evidence_id", "")) == str(reference.id):
				phone._open_card(card)
				break
		root.size = Vector2i(844, 390)
		await shot(game, "stage4_school_phone_%d" % incident)
		check(root.get_visible_rect().encloses(phone._guide_panel.get_global_rect()), "[School Stage 4] Side checklist fits small landscape")
		check(root.get_visible_rect().encloses(phone._close.get_global_rect()), "[School Stage 4] Phone Close is reachable")
		inspect_school_email(game)
		check(phone.is_complete() and game.decision_timer_active, "[School Stage 4] All authored evidence reachable before deciding")
		check(phone._items.size() == (4 if incident == 2 else 3), "[School Stage 4] Security request includes both trusted sources")
		await shot(game, "stage4_school_choices_%d" % incident)
		root.size = Vector2i(1280, 720)
		choose(game, "SAFE")
		check(account.bkt.size() == incident + 1, "[School Stage 4] Each safe choice grades exactly once")
	read_page(game)
	check(game.phase == "Results" and account.clears == 1 and account.stage_tasks == 1, "[School Stage 4] Ending completes stage once")
	check(account.credits == 50 + game.gold, "[School Stage 4] Standard reward preserved")
	await unmount(game)

	account = Account.new()
	game = mount(account, context)
	for incident: int in range(3):
		choose(game, "RISKY")
		check(game.decision.awaiting_breach_deploy() and game.story_hp == 3, "[School Stage 4] Risky choices preserve story hearts")
		game._consequence_continued()
		check(game.phase == "Build" and game.gold == 20 + incident * 2, "[School Stage 4] Original incident gold budgets preserved")
		if incident == 0:
			await shot(game, "stage4_school_map")
		game.begin_defend()
		game._wave_cleared()
		check(game.decision.resolved_threats == incident + 1 and account.bkt.size() == incident + 1, "[School Stage 4] Containment resolves once without double grading")
		read_page(game)
	if game.phase != "Results":
		read_page(game)
	check(game.phase == "Results" and account.clears == 1, "[School Stage 4] Risky/containment route can finish all incidents")
	await unmount(game)

	account = Account.new()
	game = mount(account, context)
	choose(game, "SAFE")
	choose(game, "SAFE")
	choose(game, "CRITICAL")
	check(game.story_hp == 2 and account.checkpoint.threat_index == 2 and account.clears == 0, "[School Stage 4] Failed decision costs one heart at Incident 3")
	await unmount(game)
	game = mount(account, context)
	check(game.story_hp == 2 and game.decision.threat_index == 2, "[School Stage 4] Reload retains current incident and HP")
	read_page(game)
	check(not game.decision_timer_active and game.story_overlay._phone._inspected.is_empty(), "[School Stage 4] Retry clears evidence, not earlier incident progress")
	inspect_school_email(game)
	game.story_overlay._review_button.pressed.emit()
	check(game.story_overlay._review_open, "[School Stage 4] Logs remain available while deciding")
	game.advance_decision_timer(44.0)
	check(game.story_hp == 2, "[School Stage 4] Full 45-second allowance")
	game.advance_decision_timer(1.1)
	check(game.story_hp == 1 and not game.decision.is_breach_active(), "[School Stage 4] Expiry in Logs costs one heart, not containment")
	read_page(game)
	choose(game, "CRITICAL")
	check(game.story_hp == 0, "[School Stage 4] Third failure leaves last chance")
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.checkpoint.is_empty() and account.clears == 0, "[School Stage 4] Fourth failure discards the whole attempt")
	await unmount(game)
	game = mount(account, context)
	check(game.story_hp == 3 and game.decision.threat_index == 0 and game.story_overlay._mode == &"story", "[School Stage 4] Exhausted attempt restarts at opening")
	await unmount(game)

func _verify_school_inspection_stage(stage_id: int) -> void:
	var prefix: String = "[School Stage %d] " % stage_id
	print("-- " + prefix + "Source inspection, decisions, checkpoints and geometric map --")
	var context: MatchContext = Context.stage_one_live()
	context.stage_id = stage_id
	context.module_id = "mod_01"
	var account: Account = Account.new()
	var game: Control = mount(account, context)
	check(game._key() == "mod_01:%d" % stage_id and game.story.company == "Harbor High School", prefix + "School story routes to its own save key")
	check(game.story_hp == 3 and game.story_overlay._phone_enabled and game.story.guide_speaker == "Ms. Reyes", prefix + "Existing hearts, phone and cast")
	var health_scales: Dictionary = {5: 0.8, 6: 0.85, 7: 0.9, 8: 0.95}
	var starting_budgets: Dictionary = {5: 26, 6: 32, 7: 38, 8: 44}
	check(is_equal_approx(game._enemy_health_scale(), float(health_scales[stage_id])), prefix + "Combat difficulty retained")
	check(game.story.map_route != DecisionScenarios.get_stage("mod_01", stage_id - 1).map_route, prefix + "Map layout differs from the preceding stage")
	var board: Node2D = game.hud.battle.board
	check(board.path_cells.size() == 29 and board.waypoints.size() == 8 and board.waypoints != board.WAYPOINTS, prefix + "Distinct 28-cell-distance route accepted")
	check(board.get_node("Terrain").path_cells == board.path_cells, prefix + "Painted and actual route agree")
	check(game.hud.battle.track.curve.get_point_position(7) == board.center(board.waypoints.back()), prefix + "Enemy endpoint follows new route")
	for threat: Dictionary in game.story.threats:
		check(threat.story.size() >= 5 and threat.story.size() <= 7, prefix + "Short conversational beats")
		for line: Dictionary in threat.story:
			check(str(line.text).length() <= 160 and str(line.speaker) in ["Alex", "Mia", "Ms. Reyes"], prefix + "Teen cast without text walls")
	await shot(game, "stage%d_school_opening" % stage_id)
	for incident: int in range(3):
		if game.story_overlay._mode == &"story":
			read_page(game)
		read_page(game)
		check(not game.decision_timer_active and not game.story_overlay._choices_scroll.visible, prefix + "Reading and investigation stay untimed")
		var phone: Control = game.story_overlay._phone
		phone._unlock()
		var structured: Dictionary = {}
		for item: Dictionary in phone._items:
			if item.has("fields"):
				structured = item
				break
		check(not structured.is_empty(), prefix + "Each incident has inspectable source fields")
		var id: String = str(structured.id)
		var app: String = str(structured.get("phone_app", "mail"))
		phone._navigate("home")
		phone._reveal_field(id, 0)
		check(not phone._revealed_fields.has(id), prefix + "Hidden fields cannot be inspected from home")
		phone._navigate(app)
		if app == "mail":
			phone._open_message()
			phone._inspect(id)
		else:
			for card: Dictionary in phone._data[app]:
				if str(card.get("evidence_id", "")) == id:
					phone._open_card(card)
					break
		check(not phone._inspected.has(id), prefix + "Opening a panel alone does not complete its evidence")
		phone.set_locked(true)
		phone._reveal_field(id, 0)
		check(not phone._revealed_fields.has(id), prefix + "Locked phone rejects field actions")
		phone.set_locked(false)
		# Activate an actual visible button as well as testing guarded callbacks.
		for node: Node in phone._content.find_children("*", "Button", true, false):
			var field_button: Button = node as Button
			if field_button.text == "[ ] " + str(structured.fields[0].label):
				field_button.pressed.emit()
				break
		phone._reveal_field(id, 0)
		phone._reveal_field(id, 99)
		check(phone._revealed_fields[id].size() == 1 and not phone._inspected.has(id), prefix + "Repeated or invalid taps cannot complete unseen fields")
		phone._finish()
		check(not game.decision_timer_active, prefix + "Partial evidence cannot start decision")
		root.size = Vector2i(844, 390)
		await shot(game, "stage%d_school_inspection_%d" % [stage_id, incident])
		check(root.get_visible_rect().encloses(phone._guide_panel.get_global_rect()) and root.get_visible_rect().encloses(phone._close.get_global_rect()), prefix + "Checklist and navigation fit small landscape")
		phone.stop()
		phone.open_phone(true)
		check(phone._revealed_fields[id].size() == 1, prefix + "Closing the prop preserves current investigation")
		if app == "mail":
			phone._navigate("mail")
			phone._open_message()
			phone._inspect(id)
			phone._go_back()
			check(phone._reading and phone._expanded_id.is_empty(), prefix + "Back from details returns to the email, not home")
		inspect_school_email(game)
		check(phone.is_complete() and game.decision_timer_active and is_equal_approx(game.decision_seconds_total, 45.0), prefix + "Evidence gate opens the 45-second decision")
		await shot(game, "stage%d_school_choices_%d" % [stage_id, incident])
		root.size = Vector2i(1280, 720)
		choose(game, "SAFE")
		check(account.bkt.size() == incident + 1, prefix + "One mastery update per decision")
	read_page(game)
	check(game.phase == "Results" and account.clears == 1 and account.stage_tasks == 1 and account.credits == 50 + game.gold, prefix + "Safe path completes and rewards once")
	check(account.clear_keys == ["mod_01:%d" % stage_id], prefix + "Completion targets this module and stage only")
	await unmount(game)

	account = Account.new()
	game = mount(account, context)
	for incident: int in range(3):
		choose(game, "RISKY")
		check(game.decision.awaiting_breach_deploy() and game.story_hp == 3, prefix + "Risky response starts containment without heart loss")
		game._consequence_continued()
		check(game.phase == "Build" and game.gold == int(starting_budgets[stage_id]) + incident * 2, prefix + "Original incident gold budget retained")
		if incident == 0:
			await shot(game, "stage%d_school_map" % stage_id)
		game.begin_defend()
		game._wave_cleared()
		check(game.decision.resolved_threats == incident + 1 and account.bkt.size() == incident + 1, prefix + "Containment resolves once")
		read_page(game)
	if game.phase != "Results":
		read_page(game)
	check(game.phase == "Results" and account.clears == 1, prefix + "Containment path can finish all incidents")
	await unmount(game)

	account = Account.new()
	game = mount(account, context)
	choose(game, "SAFE")
	choose(game, "SAFE")
	choose(game, "CRITICAL")
	check(game.story_hp == 2 and account.checkpoint.threat_index == 2, prefix + "Failed decision costs one heart without losing earlier incidents")
	await unmount(game)
	game = mount(account, context)
	check(game.story_hp == 2 and game.decision.threat_index == 2, prefix + "Reload retains HP and incident")
	read_page(game)
	check(game.story_overlay._phone._revealed_fields.is_empty(), prefix + "Retry starts a fresh evidence inspection")
	inspect_school_email(game)
	game.story_overlay._review_button.pressed.emit()
	game.advance_decision_timer(44.0)
	check(game.story_hp == 2, prefix + "No early expiry")
	game.advance_decision_timer(1.1)
	check(game.story_hp == 1 and not game.decision.is_breach_active(), prefix + "Timeout in Logs costs a heart, not containment")
	read_page(game)
	choose(game, "CRITICAL")
	check(game.story_hp == 0, prefix + "Third failure leaves last chance")
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.checkpoint.is_empty() and account.clears == 0, prefix + "Fourth failure clears this attempt")
	await unmount(game)
	game = mount(account, context)
	check(game.story_hp == 3 and game.decision.threat_index == 0 and game.story_overlay._mode == &"story", prefix + "Exhausted attempt restarts at opening")
	await unmount(game)

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
	check(router._scene_for_context(router._context_for_stage(1)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 2 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(2)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 3 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(3)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 4 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(4)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 5 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(5)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 6 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(6)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 7 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(7)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 8 uses the reusable live decision scene")
	check(router._scene_for_context(router._context_for_stage(8)) == router.STAGE_ONE_LIVE_SCENE, "Module 3 Stage 9 (final story stage, with a finale) also routes to the same live decision scene")
	var module3_stage2_context := Context.stage_one_live()
	module3_stage2_context.module_id = "mod_03"
	module3_stage2_context.stage_id = 2
	var module3_stage2_account := Account.new()
	var module3_stage2_game: Control = mount(module3_stage2_account, module3_stage2_context)
	check(module3_stage2_game.decision.total_threats() == 3 and is_equal_approx(module3_stage2_game._enemy_health_scale(), 0.70), "Module 3 Stage 2 live scene loads three incidents with 0.70 HP scale")
	read_page(module3_stage2_game)
	choose(module3_stage2_game, "SAFE")
	check(module3_stage2_game.decision.threat_index == 1 and module3_stage2_game.story_overlay._call_panel.visible, "Module 3 Stage 2 Incident 2 presents the live call UI")
	await unmount(module3_stage2_game)
	var module3_stage3_context := Context.stage_one_live()
	module3_stage3_context.module_id = "mod_03"
	module3_stage3_context.stage_id = 3
	var module3_stage3_game: Control = mount(Account.new(), module3_stage3_context)
	check(module3_stage3_game.decision.total_threats() == 3 and is_equal_approx(module3_stage3_game._enemy_health_scale(), 0.75), "Module 3 Stage 3 live scene loads three incidents with 0.75 HP scale")
	read_page(module3_stage3_game)
	check(module3_stage3_game.story_overlay._call_panel.visible, "Module 3 Stage 3 Incident 1 presents Ana's call UI")
	await unmount(module3_stage3_game)
	var module3_stage4_context := Context.stage_one_live()
	module3_stage4_context.module_id = "mod_03"
	module3_stage4_context.stage_id = 4
	var module3_stage4_game: Control = mount(Account.new(), module3_stage4_context)
	check(module3_stage4_game.decision.total_threats() == 3 and is_equal_approx(module3_stage4_game._enemy_health_scale(), 0.80), "Module 3 Stage 4 live scene loads three incidents at 0.80 HP")
	read_page(module3_stage4_game)
	check(module3_stage4_game.story_overlay._call_panel.visible, "Module 3 Stage 4 Incident 1 presents BlueTech Security impersonation in call UI")
	await unmount(module3_stage4_game)
	var module3_stage5_context := Context.stage_one_live()
	module3_stage5_context.module_id = "mod_03"
	module3_stage5_context.stage_id = 5
	var module3_stage5_account := Account.new()
	var module3_stage5_game: Control = mount(module3_stage5_account, module3_stage5_context)
	check(module3_stage5_game.decision.total_threats() == 3 and is_equal_approx(module3_stage5_game._enemy_health_scale(), 0.85), "Module 3 Stage 5 live scene loads three incidents at 0.85 HP")
	read_page(module3_stage5_game)
	check(module3_stage5_game.story_overlay._call_panel.visible, "Module 3 Stage 5 Incident 1 presents the bank recovery caller in call UI")
	choose(module3_stage5_game, "SAFE")
	check(module3_stage5_account.story_memory.get("mod03_s5_recovery_response") == "verified_recovery", "Module 3 Stage 5 Incident 1 SAFE commits the canonical recovery-response memory")
	choose(module3_stage5_game, "SAFE")
	check(module3_stage5_game.story_overlay._mode == &"threat" and module3_stage5_game.decision.threat_index == 2, "Module 3 Stage 5 reaches Incident 3 (We Can Get It Back) after two SAFE resolutions")
	var stage5_daniel_index: int = module3_stage5_game.story_overlay._cast.find("Daniel")
	check(stage5_daniel_index != -1, "Module 3 Stage 5 Incident 3 recognizes Daniel as a portrait speaker")
	var stage5_reached_crying := false
	for i in 25:
		if stage5_daniel_index != -1 and module3_stage5_game.story_overlay._portraits[stage5_daniel_index].emotion == "crying":
			stage5_reached_crying = true
			break
		module3_stage5_game.story_overlay._continue()
	check(stage5_reached_crying, "Module 3 Stage 5 Incident 3 reaches Daniel's first crying scene, using the existing emotion system (no new animation code)")
	# drain_until_dialogue_done() is sized for a short spliced-in tail (a
	# couple of lines); Incident 3's own story array is long, and the crying
	# hunt above only advanced as far as the first crying line — read the
	# rest of it out directly, same reveal-then-advance rhythm as read_page().
	for i in 40:
		if module3_stage5_game.story_overlay._dialogue_done:
			break
		if module3_stage5_game.story_overlay._typing:
			module3_stage5_game.story_overlay._continue()
		module3_stage5_game.story_overlay._continue()
	check(module3_stage5_game.decision_timer_active, "Module 3 Stage 5 Incident 3's timer activates once its own dialogue is fully read")
	module3_stage5_game.advance_decision_timer(15.1)
	check(not module3_stage5_game.decision_timer_active and module3_stage5_game.decision.is_breach_active(), "Module 3 Stage 5 Incident 3's timeout deterministically resolves the authored RISKY outcome and enters breach")
	await unmount(module3_stage5_game)
	var module3_stage6_context := Context.stage_one_live()
	module3_stage6_context.module_id = "mod_03"
	module3_stage6_context.stage_id = 6
	var module3_stage6_account := Account.new()
	var module3_stage6_game: Control = mount(module3_stage6_account, module3_stage6_context)
	check(module3_stage6_game.decision.total_threats() == 3 and is_equal_approx(module3_stage6_game._enemy_health_scale(), 0.90), "Module 3 Stage 6 live scene loads three incidents at 0.90 HP")
	read_page(module3_stage6_game)
	check(module3_stage6_game.story_overlay._call_panel.visible, "Module 3 Stage 6 Incident 1 presents the fake Investigator Reyes call in call UI")
	choose(module3_stage6_game, "SAFE")
	check(module3_stage6_account.story_memory.get("mod03_s6_authority_response") == "independent_agency", "Module 3 Stage 6 Incident 1 SAFE commits the canonical authority-response memory")
	if not module3_stage6_game.story_overlay._dialogue_done:
		read_page(module3_stage6_game)
	check(module3_stage6_game.story_overlay._investigation_panel.visible, "Module 3 Stage 6 Incident 2 shows its investigation once dialogue is read")
	var stage6_valid_idx := -1
	for i in module3_stage6_game.story_overlay._investigation_panel._items.size():
		if str(module3_stage6_game.story_overlay._investigation_panel._items[i].get("id", "")) == "mod03_s6_i2_case_verification":
			stage6_valid_idx = i
			break
	check(stage6_valid_idx != -1, "Module 3 Stage 6 Incident 2's valid investigation item is present")
	var stage6_bkt_before_investigation: int = module3_stage6_account.bkt.size()
	module3_stage6_game.story_overlay._investigation_panel._select(stage6_valid_idx)
	module3_stage6_game.story_overlay._investigation_panel._analyze()
	module3_stage6_game.story_overlay._investigation_panel._confirm_continue()
	check(module3_stage6_account.bkt.size() == stage6_bkt_before_investigation, "Module 3 Stage 6 Incident 2's investigation applies zero BKT on its own")
	# The investigation's own resolved_story_event follow-up (2 lines) is now
	# playing — drain_until_dialogue_done() is the right-sized helper for
	# exactly this short spliced-in tail (see its own doc comment).
	drain_until_dialogue_done(module3_stage6_game)
	choose(module3_stage6_game, "SAFE")
	check(module3_stage6_game.decision.threat_index == 2, "Module 3 Stage 6 reaches Incident 3 (Confidential Cooperation) after resolving the investigation and two SAFE resolutions")
	check(overlay_dialogue_contains(module3_stage6_game.story_overlay, "eleven minutes before"), "Module 3 Stage 6 Incident 3 opens with the public-complaint-workflow reveal")
	await unmount(module3_stage6_game)
	var module3_stage7_context := Context.stage_one_live()
	module3_stage7_context.module_id = "mod_03"
	module3_stage7_context.stage_id = 7
	var module3_stage7_account := Account.new()
	var module3_stage7_game: Control = mount(module3_stage7_account, module3_stage7_context)
	check(module3_stage7_game.decision.total_threats() == 3 and is_equal_approx(module3_stage7_game._enemy_health_scale(), 0.95), "Module 3 Stage 7 live scene loads three incidents at 0.95 HP")
	read_page(module3_stage7_game)
	if not module3_stage7_game.story_overlay._dialogue_done:
		read_page(module3_stage7_game)
	check(module3_stage7_game.story_overlay._call_panel.visible, "Module 3 Stage 7 Incident 1 presents the supplier call in call UI")
	check(module3_stage7_game.story_overlay._investigation_panel.visible, "Module 3 Stage 7 Incident 1 shows its investigation once dialogue is read")
	var stage7_valid_idx := -1
	for i in module3_stage7_game.story_overlay._investigation_panel._items.size():
		if str(module3_stage7_game.story_overlay._investigation_panel._items[i].get("id", "")) == "mod03_s7_i1_needs_verification":
			stage7_valid_idx = i
			break
	check(stage7_valid_idx != -1, "Module 3 Stage 7 Incident 1's valid investigation item is present")
	var stage7_bkt_before_investigation: int = module3_stage7_account.bkt.size()
	module3_stage7_game.story_overlay._investigation_panel._select(stage7_valid_idx)
	module3_stage7_game.story_overlay._investigation_panel._analyze()
	module3_stage7_game.story_overlay._investigation_panel._confirm_continue()
	check(module3_stage7_account.bkt.size() == stage7_bkt_before_investigation, "Module 3 Stage 7 Incident 1's investigation applies zero BKT on its own")
	# The investigation's own resolved_story_event follow-up (3 lines) is now
	# playing — drain_until_dialogue_done() is the right-sized helper for
	# exactly this short spliced-in tail (see its own doc comment).
	drain_until_dialogue_done(module3_stage7_game)
	choose(module3_stage7_game, "SAFE")
	check(module3_stage7_account.story_memory.get("mod03_s7_audio_response") == "verified_process", "Module 3 Stage 7 Incident 1 SAFE commits the canonical audio-response memory")
	check(module3_stage7_game.decision.threat_index == 1 and overlay_dialogue_contains(module3_stage7_game.story_overlay, "Caller ID: DANIEL SANTOS"), "Module 3 Stage 7 reaches Incident 2 (My Own Voice) with the spoofed Daniel caller ID")
	choose(module3_stage7_game, "SAFE")
	check(module3_stage7_game.decision.threat_index == 2 and overlay_dialogue_contains(module3_stage7_game.story_overlay, "delivery-schedule change"), "Module 3 Stage 7 reaches Incident 3 (Out of Context) with the out-of-context recording reveal")
	# Incident 3's own story array (mid-stage beat + reveal) is long enough
	# that choose()'s internal read_page() does not always finish it in one
	# pass — drain the rest directly, same reveal-then-advance rhythm as
	# read_page() itself (see the identical pattern used for Stage 5's
	# Incident 3 above).
	for i in 40:
		if module3_stage7_game.story_overlay._dialogue_done:
			break
		if module3_stage7_game.story_overlay._typing:
			module3_stage7_game.story_overlay._continue()
		module3_stage7_game.story_overlay._continue()
	check(module3_stage7_game.decision_timer_active, "Module 3 Stage 7 Incident 3's timer activates once its own dialogue is fully read")
	module3_stage7_game.advance_decision_timer(15.1)
	check(not module3_stage7_game.decision_timer_active and module3_stage7_game.decision.is_breach_active(), "Module 3 Stage 7 Incident 3's timeout deterministically resolves the authored RISKY outcome and enters breach")
	await unmount(module3_stage7_game)
	var module3_stage8_context := Context.stage_one_live()
	module3_stage8_context.module_id = "mod_03"
	module3_stage8_context.stage_id = 8
	var module3_stage8_account := Account.new()
	var module3_stage8_game: Control = mount(module3_stage8_account, module3_stage8_context)
	check(module3_stage8_game.decision.total_threats() == 3 and is_equal_approx(module3_stage8_game._enemy_health_scale(), 1.00), "Module 3 Stage 8 live scene loads three incidents at 1.00 HP")
	read_page(module3_stage8_game)
	if not module3_stage8_game.story_overlay._dialogue_done:
		read_page(module3_stage8_game)
	check(module3_stage8_game.story_overlay._call_panel.visible, "Module 3 Stage 8 Incident 1 presents the five simultaneous calls in call UI")
	choose(module3_stage8_game, "SAFE")
	check(module3_stage8_game.decision.threat_index == 1 and overlay_dialogue_contains(module3_stage8_game.story_overlay, "They overlap."), "Module 3 Stage 8 reaches Incident 2 (They All Agree) with the post-incident overlap reveal")
	if not module3_stage8_game.story_overlay._dialogue_done:
		read_page(module3_stage8_game)
	check(module3_stage8_game.story_overlay._investigation_panel.visible, "Module 3 Stage 8 Incident 2 shows its investigation once dialogue is read")
	var stage8_valid_idx := -1
	for i in module3_stage8_game.story_overlay._investigation_panel._items.size():
		if str(module3_stage8_game.story_overlay._investigation_panel._items[i].get("id", "")) == "mod03_s8_i2_trusted_channel":
			stage8_valid_idx = i
			break
	check(stage8_valid_idx != -1, "Module 3 Stage 8 Incident 2's valid investigation item is present")
	var stage8_bkt_before_investigation: int = module3_stage8_account.bkt.size()
	module3_stage8_game.story_overlay._investigation_panel._select(stage8_valid_idx)
	module3_stage8_game.story_overlay._investigation_panel._analyze()
	module3_stage8_game.story_overlay._investigation_panel._confirm_continue()
	check(module3_stage8_account.bkt.size() == stage8_bkt_before_investigation, "Module 3 Stage 8 Incident 2's investigation applies zero BKT on its own")
	# The investigation's own resolved_story_event follow-up (3 lines) is now
	# playing — drain_until_dialogue_done() is the right-sized helper for
	# exactly this short spliced-in tail (see its own doc comment).
	drain_until_dialogue_done(module3_stage8_game)
	choose(module3_stage8_game, "SAFE")
	check(module3_stage8_account.story_memory.get("mod03_s8_coordination_response") == "source_tracing", "Module 3 Stage 8 Incident 2 SAFE commits the canonical coordination-response memory")
	check(module3_stage8_game.decision.threat_index == 2 and overlay_dialogue_contains(module3_stage8_game.story_overlay, "synchronized"), "Module 3 Stage 8 reaches Incident 3 (The Authorization Chain) with the synchronized-call timeline reveal")
	# Incident 3's own story array (timeline reveal + converging callers) is
	# long enough that choose()'s internal read_page() does not always finish
	# it in one pass — drain the rest directly (see the identical pattern
	# used for Stage 7's Incident 3 above).
	for i in 40:
		if module3_stage8_game.story_overlay._dialogue_done:
			break
		if module3_stage8_game.story_overlay._typing:
			module3_stage8_game.story_overlay._continue()
		module3_stage8_game.story_overlay._continue()
	check(module3_stage8_game.decision_timer_active, "Module 3 Stage 8 Incident 3's timer activates once its own dialogue is fully read")
	module3_stage8_game.advance_decision_timer(15.1)
	check(not module3_stage8_game.decision_timer_active and module3_stage8_game.decision.is_breach_active(), "Module 3 Stage 8 Incident 3's timeout deterministically resolves the authored RISKY outcome and enters breach")
	await unmount(module3_stage8_game)
	var module3_stage9_context := Context.stage_one_live()
	module3_stage9_context.module_id = "mod_03"
	module3_stage9_context.stage_id = 9
	var module3_stage9_game: Control = mount(Account.new(), module3_stage9_context)
	check(module3_stage9_game.decision.total_threats() == 3 and is_equal_approx(module3_stage9_game._enemy_health_scale(), 1.00), "Module 3 Stage 9 live scene loads three incidents at 1.00 HP")
	read_page(module3_stage9_game)
	if not module3_stage9_game.story_overlay._dialogue_done:
		read_page(module3_stage9_game)
	check(module3_stage9_game.story_overlay._call_panel.visible, "Module 3 Stage 9 Incident 1 presents the spoofed Mia call in call UI")
	await unmount(module3_stage9_game)
	router.active_module_id = "mod_04"
	check(not router._context_for_stage(0).geometric, "A module with no decision content remains legacy")
	router.active_module_id = "mod_01"
	check(router._scene_for_context(Context.stage_one_preview()) == router.PREVIEW_SCENE, "Preview remains separate")
	var account := Account.new()
	var game := mount(account)
	check(not game.hud.gold_label.is_visible_in_tree() and not game.hud.health_icon.is_visible_in_tree(), "Story hides gold and health badges")
	check(game.story_overlay._story_hp_row.is_visible_in_tree() and game.story_overlay._story_hearts.size() == 3, "Story shows three dedicated mistake hearts from the opening")
	check(not game.hud.speed_button.visible and not game.hud.wave_progress.visible, "Story hides battle speed and empty wave meter")
	check(not game.story_overlay._story_pause.is_visible_in_tree(), "Story screen has no pause button")
	check(not game.hud.status.is_visible_in_tree() and not game.hud.phase_label.is_visible_in_tree() and not game.hud.preview_label.is_visible_in_tree(), "Story removes all three gameplay header labels")
	check(not game.story_overlay._header.visible and not game.story_overlay._line_counter.visible, "Story hides its redundant title and line counter")
	check(game.story_overlay._speech_box.is_ancestor_of(game.story_overlay._continue_button), "Next is inside the dialogue panel")
	check(game.story_overlay._review_button.text == "LOGS", "Review entry is renamed Logs")
	check(game.story_overlay._mode == &"story", "Fresh launch includes opening dialogue")
	check(game.config.name == "Before the Bell", "Uses the approved high-school story title")
	var dialogue: Control = game.story_overlay
	dialogue.set_process(false)
	check(dialogue._portraits.size() == 2 and dialogue._typing, "Two portraits and typewriter are mounted")
	check(dialogue._illustrated and dialogue._background is ColorRect, "Module 1 no longer loads corporate artwork")
	check(dialogue._background_art.texture != null and dialogue._background_art.texture == root.get_node("AssetManager").get_texture("story_bg_school_gate_morning"), "Opening arrives at the cached school gate")
	check(dialogue._portraits[0].portrait_texture is AtlasTexture, "School character uses expressive portrait atlas")
	check(dialogue._guide_speaker == "Ms. Reyes" and not game._header().contains("SECURITY DESK"), "Teacher guides the school story")
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
	check(dialogue._portraits[0].speaking and dialogue._portraits[0].speaker == "Alex" and dialogue._portraits[0].get_parent().visible and dialogue._portraits[1].get_parent().visible, "Alex speaks on the left while Mia remains visible")
	check(dialogue._portraits[0].body_texture != null and dialogue._portraits[1].body_texture != null, "Alex and Mia both use modular full-body sprites")
	check(dialogue._portraits[1]._light < 0.6 and not dialogue._portraits[1].speaking, "Initial listener is dimmed")
	check(not dialogue._speaker_label.text.contains("SCENE"), "Opening stays in the character's viewpoint")
	dialogue._continue()
	check(dialogue._portraits[1].speaking and dialogue._portraits[1].get_parent().visible and dialogue._portraits[0].get_parent().visible, "Mia speaks on the right while Alex stays visible")
	check(dialogue._portraits[0].emotion == "worried" and not dialogue._portraits[0].talking, "Listening Alex retains his worried expression without talking motion")
	dialogue._continue()
	await shot(game, "conversation")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "conversation_%dx%d" % [dimensions.x, dimensions.y])
	# Simulated landscape notch and gesture bar without changing device settings.
	var safe_area: MarginContainer = game.hud.body.get_parent().get_parent() as MarginContainer
	var scale: float = maxf(0.1, root.get_final_transform().get_scale().y)
	safe_area.add_theme_constant_override("margin_left", ceili(44.0 / scale) + 12)
	safe_area.add_theme_constant_override("margin_right", ceili(44.0 / scale) + 12)
	safe_area.add_theme_constant_override("margin_bottom", ceili(21.0 / scale) + 12)
	await shot(game, "conversation_safe_844x390")
	dialogue._open_review()
	await shot(game, "logs_safe_844x390")
	dialogue._close_review()
	safe_area._apply()
	root.size = Vector2i(1280, 720)
	read_page(game)
	check(dialogue._mode == &"threat" and not dialogue._dialogue_done, "Opening completes before incident dialogue")
	check(dialogue._background_art.texture == root.get_node("AssetManager").get_texture("story_bg_hallway_day"), "First incident moves into the cached hallway")
	check(not dialogue._choices_scroll.visible and not dialogue._timer_row.visible, "Choices and timer are hidden during conversation")
	game.advance_decision_timer(90)
	check(not game.decision_timer_active and account.bkt.is_empty(), "Dialogue has no running decision timer")
	dialogue._choose(0)
	check(game.decision.pending_choice_index == -1, "Choices cannot skip unread dialogue")
	check(not dialogue._mail.is_empty() and dialogue._mail_notice.visible, "Authored email arrives alongside the character's reaction")
	var mail_writes: int = account.writes
	dialogue._reveal_line()
	await settle()
	var notice_settings: Node = root.get_node("SettingsService")
	var prior_notice_motion: bool = notice_settings.reduced_motion
	notice_settings.reduced_motion = false
	if dialogue._mail_tween != null and dialogue._mail_tween.is_valid():
		dialogue._mail_tween.kill()
	dialogue._animate_notice(dialogue._mail_generation)
	check(dialogue._notice_offset < 0.0, "Notification begins above its resting position")
	check(dialogue._background.has_meta("_shake_tween"), "Incoming phone mail triggers a short scene buzz")
	dialogue._mail_tween.custom_step(1.0)
	check(is_zero_approx(dialogue._notice_offset) and dialogue._mail_notice.scale.is_equal_approx(Vector2.ONE), "Slide and pop settle to a stable layout")
	notice_settings.reduced_motion = true
	dialogue._animate_notice(dialogue._mail_generation)
	check(is_zero_approx(dialogue._notice_offset), "Reduced motion skips the slide and pop")
	check(not dialogue._background.has_meta("_shake_tween") and dialogue._background.position == Vector2.ZERO, "Reduced motion cancels the phone buzz without leaving offsets")
	notice_settings.reduced_motion = prior_notice_motion
	await shot(game, "email_arrival")
	for dimensions: Vector2i in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "email_arrival_%dx%d" % [dimensions.x, dimensions.y])
		check(root.get_visible_rect().encloses(dialogue._mail_notice.get_global_rect()), "Email notification fits at " + str(dimensions))
		check(dialogue._mail_notice.size.y * root.get_final_transform().get_scale().y <= 100.0, "Notification remains a compact banner")
		for portrait: Control in dialogue._portraits:
			if portrait.is_visible_in_tree():
				check(not portrait.get_global_rect().intersects(dialogue._mail_notice.get_global_rect()), "Notification does not cover the speaker")
		check(dialogue._mail_notice.get_global_rect().end.y <= dialogue._conversation.global_position.y, "Notification stays above dialogue")
	root.size = Vector2i(1280, 720)
	dialogue._continue()
	check(dialogue._mail_open and dialogue._line_index == 0, "Continue opens unread mail instead of skipping it")
	var phone: Control = dialogue._phone
	check(phone.visible and phone._app == "lock", "First phone opening starts at the lock screen")
	phone._navigate("mail")
	check(phone._app == "lock" and not phone._read, "Lock screen prevents opening apps before unlocking")
	await shot(game, "phone_lock")
	root.size = Vector2i(844, 390)
	await shot(game, "phone_lock_844x390")
	check(root.get_visible_rect().encloses(phone._unlock_button.get_global_rect()), "Unlock remains reachable on small screens")
	dialogue._close_mail()
	dialogue._continue()
	check(phone._app == "lock", "Closing before unlocking does not bypass the lock screen")
	phone._unlock_button.pressed.emit()
	check(phone._app == "home" and not phone._read, "Unlock reaches home without consuming unread mail")
	check(phone.find_child("UnreadBadge", true, false) != null, "Unread mail shows a red badge")
	for dimensions: Vector2i in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "phone_icons_%dx%d" % [dimensions.x, dimensions.y])
		check(root.get_visible_rect().encloses(phone._shell.get_global_rect()), "Home phone fits " + str(dimensions))
	root.size = Vector2i(1280, 720)
	check(phone._guide.get_parsed_text().contains("Mail: read the message"), "Checklist names the app needed to read mail")
	check(bool(phone._checklist_tasks()[0].done) and not bool(phone._checklist_tasks()[1].done), "Unlock completes only its own checklist task")
	check(not phone._guide.get_parsed_text().contains(">"), "Checklist has no unnecessary arrow prefix")
	check(not phone._shell.is_ancestor_of(phone._guide), "Guidance lives outside the device")
	check(phone._inspected.is_empty(), "A new incident starts with no inherited inspection progress")
	dialogue._close_mail()
	check(not dialogue._mail_read, "Closing Home without reading cannot consume mail")
	dialogue._continue()
	phone._navigate("mail")
	check(not phone._read and phone._back.visible, "Opening Mail zooms in but does not mark its message read")
	if phone._zoom_tween != null:
		phone._zoom_tween.custom_step(0.3)
	check(is_equal_approx(phone._zoom, 1.0), "App transition reaches the close-up framing")
	phone._open_message()
	check(dialogue._mail_read, "Opening the message explicitly marks mail read")
	phone._go_back()
	check(phone._app == "mail" and not phone._reading, "Back from a message returns to its inbox")
	phone._go_back()
	if phone._zoom_tween != null:
		phone._zoom_tween.custom_step(0.3)
	check(phone._app == "home" and is_zero_approx(phone._zoom) and not phone._back.visible, "Back from an app returns to the full home phone")
	check(phone.find_child("UnreadBadge", true, false) == null, "Read mail clears its app badge")
	var phone_motion: bool = notice_settings.reduced_motion
	notice_settings.reduced_motion = true
	phone._navigate("mail")
	check(is_equal_approx(phone._zoom, 1.0), "Reduced motion switches app framing without animation")
	notice_settings.reduced_motion = phone_motion
	phone._open_message()
	dialogue._continue()
	check(dialogue._line_index == 0 and not dialogue._dialogue_done, "Reader blocks dialogue and decision advancement")
	game.toggle_pause()
	dialogue._close_mail()
	check(dialogue._mail_open, "Pause blocks closing the email")
	game.toggle_pause()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "email_reader_%dx%d" % [dimensions.x, dimensions.y])
		check(root.get_visible_rect().encloses(phone._shell.get_global_rect()), "Phone fits at " + str(dimensions))
		check(root.get_visible_rect().encloses(phone._close.get_global_rect()), "Phone close fits at " + str(dimensions))
		check(root.get_visible_rect().encloses(phone._guide_panel.get_global_rect()), "Side guide fits at " + str(dimensions))
		check(not phone._guide_panel.get_global_rect().intersects(phone._shell.get_global_rect()), "Guide never covers the device at " + str(dimensions))
		check(not dialogue._story_hp_row.get_global_rect().intersects(phone._shell.get_global_rect()), "Story hearts never cover phone content at " + str(dimensions))
		var phone_scale: float = root.get_final_transform().get_scale().y
		check(float(phone._close.get_theme_font_size("font_size")) * phone_scale >= 16.0, "Phone text is at least 16 physical pixels")
		check(phone._close.size.y * phone_scale >= 48.0, "Phone touch targets are at least 48 physical pixels")
	root.size = Vector2i(1280, 720)
	dialogue._close_mail()
	var mail_history: int = dialogue._history.size()
	dialogue._open_mail()
	dialogue._close_mail()
	check(dialogue._history.size() == mail_history, "Reopening email does not duplicate review entries")
	check(account.writes == mail_writes and account.bkt.is_empty() and not game.decision_timer_active, "Email inspection does not grade, save, or start the decision timer")
	read_page(game)
	check(dialogue._mail.is_empty() and not dialogue._mail_panel.visible, "Email UI clears on later dialogue lines")
	check(phone.visible and not dialogue._choices_scroll.visible, "School email requires phone investigation before deciding")
	var inspection_writes: int = account.writes
	phone._finish()
	dialogue._choose(0)
	check(game.decision.pending_choice_index == -1 and phone._confirm.disabled, "Unread evidence cannot be skipped by Continue or a choice")
	phone._navigate("mail")
	phone._open_message()
	phone._inspect("sender")
	phone._inspect("sender")
	check(phone._inspected.size() == 1 and phone._confirm.disabled, "Repeated inspection counts once")
	check(phone._checklist_tasks().size() == 5, "Completed tasks remain alongside all outstanding tasks")
	check(bool(phone._checklist_tasks()[2].done) and not bool(phone._checklist_tasks()[3].done), "Inspecting sender checks only that evidence task")
	check(phone._guide.get_parsed_text().contains("[x] Mail:"), "Completed tasks have a visible completion marker")
	phone._inspect("directory")
	check(phone._inspected.size() == 1, "Contact evidence cannot be inspected from Mail")
	game.toggle_pause()
	phone._inspect("destination")
	phone._navigate("contacts")
	check(phone._inspected.size() == 1 and phone._app == "mail", "Pause blocks evidence and phone navigation")
	game.toggle_pause()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "school_inspection_%dx%d" % [dimensions.x, dimensions.y])
		check(root.get_visible_rect().encloses(phone._confirm.get_global_rect()), "Inspection action fits at " + str(dimensions))
		check(root.get_visible_rect().encloses(phone._guide_panel.get_global_rect()), "Investigation side guide fits at " + str(dimensions))
	root.size = Vector2i(1280, 720)
	phone._request_close()
	check(dialogue._phone_prompt.visible and not dialogue._choices_scroll.visible, "Closing investigation returns to a reopen action, not choices")
	dialogue._open_phone_investigation()
	check(phone._inspected.size() == 1, "Reopening retains this attempt's evidence")
	await shot(game, "phone_home")
	check(bool(phone._checklist_tasks()[2].done) and not bool(phone._checklist_tasks()[3].done), "Closing and reopening preserves checklist completion")
	check(not phone._guide.get_parsed_text().contains("Back to Home"), "Checklist is stable instead of per-screen navigation hints")
	phone._navigate("contacts")
	phone._open_card(phone._data["contacts"][1])
	phone._go_back()
	check(phone._app == "contacts" and not phone._card_open, "Back from a contact returns to the contact list")
	await shot(game, "phone_contacts")
	phone._navigate("pages")
	await shot(game, "phone_saved_pages")
	root.size = Vector2i(844, 390)
	var phone_safe: MarginContainer = game.hud.body.get_parent().get_parent() as MarginContainer
	phone_safe.add_theme_constant_override("margin_left", 44)
	phone_safe.add_theme_constant_override("margin_right", 44)
	phone_safe.add_theme_constant_override("margin_bottom", 21)
	await shot(game, "phone_safe_844x390")
	check(game.hud.body.get_global_rect().encloses(phone._shell.get_global_rect()), "Phone respects landscape safe-area insets")
	phone_safe._apply()
	root.size = Vector2i(1280, 720)
	inspect_school_email(game)
	check(account.writes == inspection_writes + 1 and account.bkt.is_empty(), "Completing evidence starts one timer checkpoint, with no mastery effects")
	check(dialogue._dialogue_done and not dialogue._evidence.is_visible_in_tree() and not dialogue._choice_buttons[0].disabled, "Decision shows choices without the wall of evidence")
	check(not dialogue._conversation.visible and dialogue._choices_scroll.visible and dialogue._timer_row.visible, "Decision shows three choices with the timer")
	check(game.decision_timer_active and game.decision_seconds_left > 44.0, "45-second timer starts only after investigation")
	await shot(game, "decision")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await shot(game, "decision_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	dialogue._open_review()
	check(dialogue._review_open and dialogue._review_content.get_child_count() == 16, "Logs contain dialogue, email, and three inspected evidence records")
	var logs_seconds: float = game.decision_seconds_left
	game.advance_decision_timer(1.0)
	check(game.decision_seconds_left < logs_seconds and dialogue._review_hint.text.contains("Timer running"), "Stage 1 timer remains visible and running in Logs")
	await shot(game, "dialogue_review")
	root.size = Vector2i(844, 390)
	await shot(game, "dialogue_review_844x390")
	root.size = Vector2i(1280, 720)
	dialogue._close_review()
	var review_index: int = dialogue._line_index
	var review_history: int = dialogue._history.size()
	dialogue._open_review()
	check(dialogue._review_content.get_child(0).get_meta("player_side", false) and not dialogue._review_content.get_child(1).get_meta("player_side", true), "Logs put Alex and Mia on opposite sides")
	dialogue._continue()
	dialogue._choose(0)
	check(dialogue._line_index == review_index and game.decision.pending_choice_index == -1, "Logs blocks background continuation and choices")
	dialogue._close_review()
	check(dialogue._history.size() == review_history and not dialogue._review_scrim.visible, "Closing Logs restores the same state without duplicate history")
	game.toggle_pause()
	game._choice_selected(0)
	check(game.decision.pending_choice_index == -1, "System pause still blocks a manual choice")
	game.toggle_pause()
	for i in game.decision.total_threats():
		choose(game, "SAFE")
	check(account.clears == 0, "Must file ending report before stage clear")
	check(game.story_overlay._background_art.texture == root.get_node("AssetManager").get_texture("story_bg_classroom_day"), "Ending returns to the cached classroom")
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
	check(game.phase == "Incident" and game.story_hp == 2 and account.credits == 0 and account.clears == 0, "First failed decision loses HP and retries without ending the stage")
	check(account.checkpoint.threat_index == 0 and account.bkt.size() == 1, "Critical retry preserves incident and grades once")
	await shot(game, "critical")
	await unmount(game)
	game = mount(account)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 0, "Retry resumes incident rather than opening story")
	check(game.story_hp == 2, "Story HP survives reload")
	check(game.story_overlay._story_hearts[0].health == 1 and game.story_overlay._story_hearts[1].health == 1 and game.story_overlay._story_hearts[2].health == 0, "Reloaded hearts reflect two remaining story HP")
	choose(game, "RISKY")
	check(game.story_hp == 2, "Risky choice never consumes story HP")
	check(game.phase == "Incident" and game.decision.awaiting_breach_deploy(), "Risky warning waits for Deploy Defenses")
	game._consequence_continued()
	check(game.phase == "Build" and game.health == 5 and game.gold == int(game.decision.current_threat().breach_gold), "Breach uses authored health and gold reset")
	check(game.hud.gold_label.is_visible_in_tree() and game.hud.health_icon.is_visible_in_tree() and game.hud.speed_button.visible, "Combat restores resource badges and speed control")
	check(game.hud.status.is_visible_in_tree() and game.hud.pause_button.is_visible_in_tree(), "Containment restores the normal combat header and pause")
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
	check(not game.hud.gold_label.is_visible_in_tree() and not game.hud.health_icon.is_visible_in_tree(), "Returning from combat hides resources again")
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
	check(str(game.story_overlay._lines[0].text).contains("fair poster") and game.story_overlay._lines.size() == 10, "Incident 2 resume adds two character-led context lines before its conversation")
	check(game.story_overlay._mail.is_empty() and not game.decision_timer_active, "Resume recap does not fire its later email or decision early")
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
	# Every Stage 1 decision now runs its own 45-second timer, not its dialogue.
	for incident_index in 3:
		account = Account.new()
		account.checkpoint = {"threat_index": incident_index, "resolved_threats": incident_index, "flow_state": "THREAT", "safe_count": incident_index}
		game = mount(account)
		game.advance_decision_timer(90.0)
		check(game.story_hp == 3 and not game.decision_timer_active, "Dialogue remains untimed")
		read_page(game)
		inspect_school_email(game)
		check(game.decision_timer_active, "Incident %d starts its decision timer" % incident_index)
		game.advance_decision_timer(46.0)
		check(game.story_hp == 2 and account.bkt.size() == 1 and not game.decision.is_breach_active(), "Timeout consumes exactly one HP, not containment")
		game._expire_decision()
		check(game.story_hp == 2 and account.bkt.size() == 1, "Duplicate expiry cannot consume another HP")
		read_page(game)
		choose(game, "SAFE")
		check(account.bkt.size() == 2, "Retry still accepts a genuine manual decision")
		await unmount(game)
	account = Account.new()
	game = mount(account)
	choose(game, "CRITICAL")
	choose(game, "SAFE")
	choose(game, "CRITICAL")
	choose(game, "SAFE")
	choose(game, "CRITICAL")
	check(game.story_hp == 0 and game.decision.threat_index == 2 and game.phase == "Incident", "Third failure leaves a last chance in incident three")
	await unmount(game)
	account.checkpoint = root.get_node("PlayerManager")._normalize_decision_state({"mod_01:1": account.checkpoint})["mod_01:1"]
	game = mount(account)
	check(game.story_hp == 0 and game.decision.threat_index == 2, "Zero HP and incident three survive save normalization")
	read_page(game)
	game.advance_decision_timer(40.0)
	var saved_time: float = game.decision_seconds_left
	await unmount(game)
	account.checkpoint = root.get_node("PlayerManager")._normalize_decision_state({"mod_01:1": account.checkpoint})["mod_01:1"]
	game = mount(account)
	read_page(game)
	check(game.decision_seconds_left <= saved_time + 0.1, "Normalized reload cannot refill the timer")
	game.story_overlay._open_review()
	game.advance_decision_timer(10.0)
	check(game.phase == "Results" and game.story_hp == -1 and account.checkpoint.is_empty(), "Fourth failure in Logs ends the attempt and clears only this stage's checkpoint")
	var failures_graded: int = account.bkt.size()
	game._expire_decision()
	game._choice_selected(0)
	check(account.bkt.size() == failures_graded, "Late click and expiry cannot double grade")
	game.hud.result_overlay.finish_reveal()
	await shot(game, "fourth_failure")
	await unmount(game)
	game = mount(account)
	check(game.story_hp == 3 and game.decision.threat_index == 0 and game.story_overlay._mode == &"story", "Retry after fourth failure starts at the opening with 3 HP")
	await unmount(game)
	account = Account.new()
	account.checkpoint = {"threat_index": 2, "resolved_threats": 2, "flow_state": "THREAT", "safe_count": 2, "story_hp": 0}
	game = mount(account)
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.checkpoint.is_empty() and game.story_hp == -1, "A fourth manual failed decision also restarts the whole stage")
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
	check(game.config.name == "They Know Our Project", "[Stage 2] Uses its own school-project story title")
	check(game.story_overlay._phone_enabled and game.story_hp == 3, "[Stage 2] School phone and three story hearts enabled")
	var stage2_board: Node2D = game.hud.battle.board
	check(stage2_board.waypoints != stage2_board.WAYPOINTS, "[Stage 2] Route differs from Stage 1")
	check(stage2_board.path_cells.size() == 29, "[Stage 2] Preserves Stage 1 route travel distance")
	check(stage2_board.cell_reason(Vector2i(0, 5)) != "" and stage2_board.cell_reason(Vector2i(0, 1)) == "", "[Stage 2] Route and build tiles use the new layout")
	check(game.hud.battle.track.curve.get_point_position(0) == stage2_board.center(Vector2i(0, 5)), "[Stage 2] Enemy track starts at the visible entry")
	check(game.hud.battle.track.curve.get_point_position(5) == stage2_board.center(Vector2i(12, 1)), "[Stage 2] Enemy track ends at the visible home base")
	check(stage2_board.get_node("Terrain").path_cells == stage2_board.path_cells, "[Stage 2] Painted terrain matches placement and enemy route")
	var invalid_route: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 2)]
	check(not game.hud.battle.configure_route(invalid_route) and stage2_board.waypoints[0] == Vector2i(0, 5), "[Stage 2] Invalid route cannot corrupt the existing board")
	check(game.decision.total_threats() == 3, "[Stage 2] Exactly 3 incidents load")
	check(is_equal_approx(game._enemy_health_scale(), 0.65), "[Stage 2] Breach HP scale is 0.65, independent of Stage 1's 0.60")
	check(game._key() == "mod_01:2", "[Stage 2] Checkpoint key is stage-specific")
	await shot(game, "stage2_opening")
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
	check(game.story_hp == 3, "[Stage 2] Risky decision preserves story hearts")
	await shot(game, "stage2_map")
	game.begin_defend()
	game._wave_cleared()
	check(game.phase == "Incident" and game.decision.resolved_threats == 2, "[Stage 2] TD win resolves Incident 2 and returns to story")
	check(game.story_overlay._mode == &"story", "[Stage 2] BREACH CONTAINED story shown before Incident 3")
	check(account.bkt.size() == 2, "[Stage 2] TD win applies no additional BKT update")
	game._story_continued()
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 2, "[Stage 2] Incident 3 follows containment")
	await unmount(game)

	print("-- [Stage 2] Failed decision consumes one story heart --")
	account = Account.new()
	game = mount(account, stage2)
	choose(game, "CRITICAL")
	check(game.phase == "Incident" and game.story_hp == 2 and account.credits == 0 and account.clears == 0, "[Stage 2] CRITICAL loses one HP without ending the stage or rewarding it")
	check(account.checkpoint.threat_index == 0 and account.bkt.size() == 1, "[Stage 2] CRITICAL retry preserves the same incident and grades once")
	await unmount(game)
	game = mount(account, stage2)
	check(game.story_overlay._mode == &"threat" and game.decision.threat_index == 0, "[Stage 2] Retry resumes Incident 1, not a fresh opening")
	check(game.story_hp == 2, "[Stage 2] Story HP persists across reload")
	read_page(game)
	check(not game.decision_timer_active, "[Stage 2] Timer waits for investigation")
	inspect_school_email(game)
	check(game.decision_timer_active, "[Stage 2] Timer starts after inspecting all evidence")
	game.advance_decision_timer(44.0)
	check(game.story_hp == 2, "[Stage 2] Timer gives the full 45 seconds")
	game.advance_decision_timer(1.1)
	check(game.story_hp == 1 and not game.decision.is_breach_active(), "[Stage 2] Timeout loses one HP without containment")
	read_page(game)
	choose(game, "CRITICAL")
	check(game.story_hp == 0, "[Stage 2] Third failure allows last chance")
	choose(game, "CRITICAL")
	check(game.phase == "Results" and account.checkpoint.is_empty(), "[Stage 2] Fourth failure clears the stage attempt")
	await unmount(game)
	game = mount(account, stage2)
	check(game.story_hp == 3 and game.decision.threat_index == 0 and game.story_overlay._mode == &"story", "[Stage 2] Exhausted attempt restarts Stage 2 from its opening")
	await unmount(game)

	print("-- [Stage 2] All incidents resolved -> Stage 2 Complete --")
	account = Account.new()
	game = mount(account, stage2)
	for i in game.decision.total_threats():
		if game.story_overlay._mode == &"story":
			read_page(game)
		read_page(game)
		check(not game.decision_timer_active, "[Stage 2] Each incident waits for inspection before timing")
		game.story_overlay._open_phone_investigation()
		var stage2_phone: Control = game.story_overlay._phone
		stage2_phone._unlock()
		var reference_app: String = str(stage2_phone._items[2].phone_app)
		stage2_phone._navigate(reference_app)
		for card: Dictionary in stage2_phone._data[reference_app]:
			if str(card.get("evidence_id", "")) == str(stage2_phone._items[2].id):
				stage2_phone._open_card(card)
				break
		await shot(game, "stage2_reference_%d" % i)
		inspect_school_email(game)
		await shot(game, "stage2_decision_%d" % i)
		choose(game, "SAFE")
	game._story_continued()
	check(game.phase == "Results" and account.clears == 1, "[Stage 2] All SAFE completes the story and clears the stage")
	check(account.credits == 50 + game.gold and account.stage_tasks == 1, "[Stage 2] Victory rewards match the existing production rules")
	await unmount(game)

	check(DecisionScenarios.stage_key("mod_01", 1) != DecisionScenarios.stage_key("mod_01", 2), "[Stage 2] Stage 1 and Stage 2 checkpoint keys never collide")
	await _verify_school_stage_three()
	await _verify_school_stage_four()
	for stage_id: int in range(5, 9):
		await _verify_school_inspection_stage(stage_id)

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
	await settle()
	check(game.story_overlay._call_panel.size.y < 220.0 and game.story_overlay._call_panel._caller_label.size.x > 250.0,
		"[Call] Live workspace keeps the caller horizontal and the phone header compact")
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

	print("-- [Reconstruction] Authored timeline is presentation-only; reload before Continue cannot award twice --")
	var reconstruction_data: Dictionary = DecisionScenarios.reconstruction_data(DecisionScenarios.get_stage("mod_03", 1))
	check((reconstruction_data.get("events", []) as Array).size() == 6, "[Reconstruction] Six authored events load")
	check((reconstruction_data.get("events", []) as Array)[0]["time"] == "18:42" and (reconstruction_data.get("events", []) as Array)[5]["time"] == "18:57", "[Reconstruction] Timeline order preserved")
	check((reconstruction_data.get("techniques", []) as Array)[0] == "Vishing" and (reconstruction_data.get("techniques", []) as Array)[3] == "Knowledge-Based Impersonation", "[Reconstruction] Technique order preserved")
	check(DecisionScenarios.reconstruction_data(DecisionScenarios.get_stage("mod_01", 1)).is_empty(), "[Reconstruction] Absent data keeps older stages unchanged")
	check(DecisionScenarios.reconstruction_data(DecisionScenarios.get_stage("mod_01", 9)).is_empty(), "[Reconstruction] Existing finale has no reconstruction and keeps its current flow")
	check(DecisionScenarios.reconstruction_data({"reconstruction": {"enabled": false, "events": reconstruction_data["events"], "techniques": reconstruction_data["techniques"], "finding": "text"}}).is_empty(), "[Reconstruction] Disabled data keeps old completion path")
	check(DecisionScenarios.reconstruction_data({"reconstruction": {"enabled": true, "events": [], "finding": "text"}}).is_empty(), "[Reconstruction] Malformed data is ignored")
	check(DecisionScenarios.reconstruction_data({"reconstruction": {"enabled": true, "events": [{"id": "x", "time": "18:42"}], "techniques": ["Vishing"], "finding": "text"}}).is_empty(), "[Reconstruction] Incomplete event is ignored safely")
	account = Account.new()
	game = mount(account, stage3)
	read_page(game)
	choose(game, "SAFE")
	read_page(game); choose(game, "SAFE"); read_page(game)
	choose(game, "SAFE")
	read_page(game)
	check(game._reconstruction_panel != null and game._reconstruction_panel.visible, "[Reconstruction] Live ending opens shared reconstruction panel")
	if game._reconstruction_panel != null:
		check(root.get_visible_rect().encloses(game._reconstruction_panel.get_global_rect()), "[Reconstruction] Panel fits the 1280x720 viewport")
		check(game._reconstruction_panel._scroll != null and game._reconstruction_panel._scroll.visible, "[Reconstruction] Timeline remains scrollable")
		check(game._reconstruction_panel._timeline.get_child_count() == 6 and (game._reconstruction_panel._timeline.get_child(0) as Label).text.begins_with("18:42"), "[Reconstruction] Panel renders the authored timeline in order")
		check(game._reconstruction_panel._techniques.get_child_count() == 4 and (game._reconstruction_panel._techniques.get_child(0) as Label).text.contains("Vishing"), "[Reconstruction] Panel renders authored techniques in order")
	check(account.clears == 0 and account.credits == 0 and account.bkt.size() == 3, "[Reconstruction] Showing panel never awards or grades")
	var memory_writes_at_reconstruction: int = account.story_memory_writes
	await unmount(game)
	game = mount(account, stage3)
	check(game.decision.resolved_threats == 3 and game.story_overlay.visible, "[Reconstruction] Reload retains resolved incidents and replays ending")
	read_page(game)
	check(game._reconstruction_panel != null and game._reconstruction_panel.visible, "[Reconstruction] Reload can reach panel without repeating decisions")
	check(account.clears == 0 and account.credits == 0 and account.bkt.size() == 3 and account.story_memory_writes == memory_writes_at_reconstruction, "[Reconstruction] Reload adds no rewards, BKT, or memory")
	game._reconstruction_panel._continue.pressed.emit()
	await settle()
	check(game.phase == "Results" and account.clears == 1 and account.bkt.size() == 3, "[Reconstruction] Continue reaches canonical completion exactly once")
	var credits_after_reconstruction: int = account.credits
	game._reconstruction_panel._continue.pressed.emit()
	await settle()
	check(account.clears == 1 and account.credits == credits_after_reconstruction, "[Reconstruction] Repeated Continue cannot duplicate stage-clear rewards")
	await unmount(game)

	check(fingerprint() == before, "Tests left actual player/mastery/tasks/queue unchanged")
	print("[LIVE STAGE ONE] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
