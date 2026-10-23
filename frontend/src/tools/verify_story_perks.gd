extends SceneTree
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
var failures: int = 0
var chapter_screen: Control

func _initialize() -> void:
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if is_instance_valid(chapter_screen) and chapter_screen.is_node_ready():
		chapter_screen._backgrounded = false
		chapter_screen._apply_pause()
	return false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for index: int in 12: await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/perks_" + label + ".png")

func evidence(snapshot: Dictionary) -> Dictionary:
	for entry: Dictionary in Chapter.MESSAGES:
		snapshot.read.append(entry.id)
		snapshot.sorted.append(entry.id)
	for key: String in ["flags", "domains", "captures"]: snapshot[key] = Chapter.suspicious_ids()
	snapshot.sealed = true
	snapshot.completed = true
	return snapshot

func _run() -> void:
	root.size = Vector2i(1280,720)
	var player: Node = root.get_node("PlayerManager")
	var auth: Node = root.get_node("AuthService")
	var settings: Node = root.get_node("SettingsService")
	var original: Dictionary = player.get_save_data()
	auth._signed_in = false
	player.reset_to_defaults()
	player.credits = 400
	player.lesson_progress = {"mod_01":1}
	player.apply_save_data(player.get_save_data())
	var legacy: String = JSON.stringify([player.tech_ranks, player.unlocked_towers, player.mastery_matrix, player.learning_evidence])
	check(player.owned_perks == ["recap"], "Case Recap is free, loadout optional")
	check(player.purchase_perk("perspective", false) and player.credits == 300, "Permanent perk purchase charges once")
	check(not player.purchase_perk("perspective", false) and player.credits == 300, "Duplicate purchase cannot charge")
	check(not player.purchase_perk("fake", false), "Unknown perk rejected")
	check(player.purchase_perk("reference", false), "Cross-Reference can be unlocked")
	check(player.equip_perk("recap", false) and player.equip_perk("perspective", false), "Two perks equip")
	check(not player.equip_perk("reference", false), "Third slot rejected")
	var first: Dictionary = player.begin_survey_attempt(false, false)
	var run: Dictionary = first.perk_run
	check(Perks.status(run) == "unassisted", "Equipped but unused is unassisted")
	for context: String in ["short_check", "checkpoint", "research_test", "assessment", "debate_test", "", "unknown"]:
		check(not Perks.activate(run, "recap", context, "day", 0, []), "Denied outside story: " + context)
	check(run.uses.is_empty(), "Denied contexts produce no perk effect or usage")
	for perk_id: String in Perks.IDS:
		var policy_loadout: Array[String] = [perk_id]
		var policy_run: Dictionary = Perks.new_run("policy-check", policy_loadout, false)
		for context: String in ["short_check", "checkpoint", "research_test", "assessment", ""]:
			check(not Perks.activate(policy_run, perk_id, context, "capture", 12, ["survey", "urgent"]), "Every perk denied in assessment contexts: " + perk_id)
		check(not Perks.allowed(policy_run, perk_id, "story_chapter", "unknown", []), "Unknown phases deny perks")
		policy_run.completed = true
		check(not Perks.allowed(policy_run, perk_id, "story_chapter", "capture", ["survey", "urgent"]), "Completed attempts deny perks")
	check(Perks.activate(run, "recap", "story_chapter", "day", 1, []), "Recap activates in story")
	check(not Perks.activate(run, "recap", "story_chapter", "day", 1, []), "Once-per-chapter use enforced")
	player.save_story_attempt(first, false, false)
	player.equip_perk("recap", false)
	player.equip_perk("reference", false)
	var saved: Dictionary = player.get_save_data()
	player.apply_save_data(saved)
	var resumed: Dictionary = player.begin_survey_attempt(false, false)
	check(resumed.perk_run.id == run.id and resumed.perk_run.loadout == ["recap", "perspective"], "Resume uses frozen loadout, not newly equipped perks")
	check(resumed.perk_run.uses.recap == 1, "Uses survive serialization")
	check(not Perks.allowed(resumed.perk_run, "reference", "story_chapter", "capture", ["survey", "urgent"]), "Unequipped reference denied")
	var completed: Dictionary = evidence(resumed)
	var before: int = player.credits
	player.save_story_attempt(completed, false, false)
	player.save_story_attempt(completed, false, false)
	check(player.credits == before + 100, "Assisted clear awards base once, without clean bonus")
	check(player.perk_attempts.size() == 1 and player.perk_attempts[0].assist_status == "assisted", "Attempt ledger records assistance")
	var original_clear: String = JSON.stringify(player.chapter_progress)
	var replay_state: Dictionary = player.begin_survey_attempt(true, false)
	check(replay_state.perk_run.id != run.id and replay_state.perk_run.replay, "Replay gets a distinct attempt")
	check(not Perks.allowed(replay_state.perk_run, "reference", "story_chapter", "capture", ["survey"]), "Compare requires two collected messages")
	check(Perks.activate(replay_state.perk_run, "reference", "story_chapter", "capture", 12, ["survey", "urgent"]), "Reference applies only after collection")
	player.save_story_attempt(replay_state, true, false)
	check(player.begin_survey_attempt(true, false).perk_run.uses.reference == 1, "Replay reload cannot refund assistance")
	player.save_story_attempt(evidence(replay_state), true, false)
	check(JSON.stringify(player.chapter_progress) == original_clear and player.credits == before + 100, "Replay never overwrites clear or awards coins")
	check(player.perk_attempts.size() == 2, "Replay remains in attempt ledger")
	check(Perks.status(Chapter.clean({}).perk_run) == "unknown", "Historical missing tracking is unknown")
	check(JSON.stringify([player.tech_ranks, player.unlocked_towers, player.mastery_matrix, player.learning_evidence]) == legacy, "Perks never modify tower ranks or assessment evidence")
	player.apply_save_data({"credits":20})
	check(player.perk_loadout.is_empty() and player.owned_perks == ["recap"] and player.perk_attempts.is_empty(), "Old saves and account reset cannot inherit perks or attempts")
	check(not player.purchase_perk("perspective", false) and player.credits == 20, "Insufficient coins do not charge")
	player.chapter_progress[Chapter.ID] = {"phase":"day", "hint_used":true}
	player.begin_survey_attempt(false, false)
	player.apply_save_data(player.get_save_data())
	check(player.perk_attempts[0].assist_status == "assisted", "Legacy hint evidence survives ledger reload")
	player.apply_save_data({})
	var unused: Dictionary = evidence(player.begin_survey_attempt(false, false))
	player.save_story_attempt(unused, false, false)
	check(player.chapter_progress[Chapter.ID].reward == 125 and player.perk_attempts[0].assist_status == "unassisted", "Unassisted clear retains clean bonus and tracking")
	player.apply_save_data({})
	player.credits = 400
	player.lesson_progress = {"mod_01":1}
	var screen: Control = load("res://src/ui/screens/deploy/perk_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"test":true,"deploy":true})
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(844,390)]:
		root.size = dimensions
		screen._selected = ""
		screen._refresh()
		await settle()
		await capture("collection_%d" % dimensions.x)
		check(screen._launch.get_global_rect().end.y <= screen.size.y, "Deploy fits viewport")
		screen._inspect("perspective")
		await settle()
		await capture("network_%d" % dimensions.x)
		check(screen._network.get_global_rect().end.x <= screen.size.x, "Perk network fits viewport")
	screen._action()
	check("perspective" in player.owned_perks, "UI unlock action works")
	screen._action()
	check("perspective" in player.perk_loadout, "UI equip action works")
	player.equip_perk("recap", false)
	player.begin_survey_attempt(false, false)
	screen._refresh()
	check(not screen._checkpoint().is_empty() and screen._notice.text.contains("locked"), "Resume screen locks the attempt loadout")
	screen.on_exit()
	screen.queue_free()
	await settle()
	root.size = Vector2i(1280,720)
	settings.text_speed = "instant"
	settings.reduced_motion = true
	chapter_screen = load("res://src/ui/screens/deploy/survey_chapter_screen.tscn").instantiate()
	root.add_child(chapter_screen)
	chapter_screen.on_enter({"test":true})
	chapter_screen._advance()
	chapter_screen._open_perks()
	check(chapter_screen._paused and chapter_screen._perk_panel.visible, "Perk modal pauses story")
	chapter_screen._use_perk("recap")
	check(chapter_screen.state.perk_run.uses.recap == 1, "Chapter recap records activation")
	check(not chapter_screen._recap_text().contains("survey gig"), "Recap does not reveal future beats")
	check(chapter_screen._recap_text().contains("late again") and not chapter_screen._recap_text().contains("Five days before"), "Recap keeps John's spoken line without attributing the anonymous caption to him")
	await settle()
	await capture("recap")
	chapter_screen._close_perks()
	chapter_screen.state = evidence(chapter_screen.state)
	chapter_screen.state.completed = false
	chapter_screen.state.sealed = false
	chapter_screen.state.phase = "highlight"
	chapter_screen._render()
	chapter_screen._open_perks()
	chapter_screen._use_perk("perspective")
	check(chapter_screen.state.perk_run.uses.perspective == 1, "Contextual hint activates without auto-solving evidence")
	await settle()
	await capture("hint")
	chapter_screen._close_perks()
	var reference_loadout: Array[String] = ["reference"]
	chapter_screen.state.perk_run = Perks.new_run("reference-ui", reference_loadout, true)
	chapter_screen.replay = true
	chapter_screen.state.phase = "capture"
	chapter_screen.state.captures = ["survey", "urgent"]
	chapter_screen._render()
	chapter_screen._open_perks()
	chapter_screen._use_perk("reference")
	check(chapter_screen.state.perk_run.uses.reference == 1, "Reference UI records use")
	var pickers: Array[Node] = chapter_screen._perk_body.find_children("*", "OptionButton", true, false)
	check(pickers.size() == 2, "Reference displays two comparison selectors")
	for picker: OptionButton in pickers:
		check(picker.item_count == 2, "Reference selectors contain captured messages only")
	root.size = Vector2i(844,390)
	await settle()
	await capture("reference_844")
	check(chapter_screen._perk_panel.get_global_rect().end.x <= root.get_visible_rect().end.x + 2, "Reference modal fits mobile width")
	var uses_before: int = chapter_screen.state.perk_run.uses.reference
	chapter_screen._owner = "different-account"
	chapter_screen._use_perk("reference")
	check(chapter_screen.state.perk_run.uses.reference == uses_before, "Account changes prevent stale modal activation")
	chapter_screen._owner = auth.participant_code()
	chapter_screen._close_perks()
	chapter_screen.on_exit()
	chapter_screen.queue_free()
	await settle()
	player.apply_save_data(original)
	print("STORY_PERKS_CHECKS failures=" + str(failures))
	quit(1 if failures else 0)
