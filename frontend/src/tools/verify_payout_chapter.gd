extends SceneTree
const Case: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Advisor: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
var failures: int = 0
var screen: Control

func _initialize() -> void:
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if is_instance_valid(screen) and screen.is_node_ready():
		screen._backgrounded = false
		screen._apply_pause()
	return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for index: int in 12: await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/chapter3_" + label + ".png")

func _run() -> void:
	root.size = Vector2i(1480,720)
	var player: Node = root.get_node("PlayerManager")
	var original: Dictionary = player.get_save_data()
	root.get_node("AuthService")._signed_in = false
	player.reset_to_defaults()
	player.lesson_progress = {"mod_01":1}
	root.get_node("SettingsService").text_speed = "instant"
	root.get_node("SettingsService").reduced_motion = true
	check(player.begin_story_attempt(Case.ID, false, false).is_empty(), "Chapter 3 is gated before prior exhibits")
	var first: Dictionary = Survey.fresh()
	for entry: Dictionary in Survey.MESSAGES:
		first.read.append(entry.id)
		first.sorted.append(entry.id)
	for field: String in ["flags","domains","captures"]: first[field] = Survey.suspicious_ids()
	first.sealed = true
	first.completed = true
	player.save_survey_chapter(first, false)
	check(not player.story_unlocked(Case.ID), "Chapter 1 alone cannot unlock Chapter 3")
	var second: Dictionary = Advisor.fresh()
	second.flags = ["domain","wording","signature"]
	second.domains = ["fake"]
	second.headers = ["From","Reply-To","Subject"]
	second.sealed = true
	second.completed = true
	player.save_chapter(second, Advisor.ID, false)
	check(player.story_unlocked(Case.ID), "Chapter 2 unlocks The Payout")
	check(not Case.clean({"sealed":true,"completed":true,"phase":"done"}).completed, "Malformed saves cannot fabricate completion")
	player.owned_perks = Perks.ids(["recap","perspective"])
	player.perk_loadout = Perks.ids(["recap","perspective"], 2)
	screen = load("res://src/ui/screens/deploy/survey_chapter_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"test":true,"chapter_id":Case.ID})
	await settle()
	var phone: Control = screen._phone
	check(screen.Chapter.ID == Case.ID, "Shared screen injects Chapter 3")
	for beat_index: int in Case.STORY.size():
		check(screen.state.beat == beat_index, "Sequential Chapter 3 story beat %d" % beat_index)
		var beat: Dictionary = Case.STORY[beat_index]
		if beat.has("caption"):
			for step: int in 8:
				if screen._is_caption_sentence(): screen._advance()
		if beat.get("chat", false):
			for step: int in 20:
				if not screen._chat_started: screen._advance()
			screen._process(2.0)
			await settle()
			check(phone.chat_entries.size() == (beat.messages as Array).size(), "Authored private chat injected")
			check(not phone._close.is_visible_in_tree(), "Continue is hidden until all chat messages finish")
			for step: int in 200:
				if phone.phase_ready(): break
				phone._tick_chat(3.0)
				if phone._chat_stage == "send": phone._send_chat()
			check(phone.phase_ready(), "Private chat completes")
			check(not phone._chat_status.text.contains("everyone"), "Private chat has no group read receipt")
			await settle()
			var continue_button: Button = phone._close as Button
			check(continue_button.is_visible_in_tree() and not continue_button.disabled, "Completed private chat exposes an enabled Continue button")
			check(continue_button.text.begins_with("CONTINUE"), "Completed chat uses the Continue action")
			if beat_index == 3: await capture("eric_chat")
			for dimensions: Vector2i in [Vector2i(844,390),Vector2i(720,360)]:
				root.size = dimensions
				await settle()
				var physical: float = root.get_final_transform().get_scale().y
				check(continue_button.size.y * physical >= 47.5, "Chat Continue is a mobile touch target")
				check(root.get_visible_rect().encloses(continue_button.get_global_rect()), "Chat Continue stays inside the mobile viewport")
				if beat_index == 3: await capture("eric_chat_%d" % dimensions.x)
			root.size = Vector2i(1480,720)
			await settle()
			phone.set_locked(true)
			continue_button.pressed.emit()
			check(screen.state.beat == beat_index, "Paused chat cannot continue")
			phone.set_locked(false)
			if continue_button.is_visible_in_tree():
				continue_button.pressed.emit()
				check(screen.state.beat == beat_index + 1, "Visible Continue advances the completed chat exactly once")
		elif beat.get("mail", false):
			await settle()
			if beat.get("event", "") == "interrupt":
				phone.set_locked(true)
				phone._process(3.0)
				check(not phone._ringing, "Paused story cannot advance interrupted typing")
				phone.set_locked(false)
				phone._process(2.0)
				check(phone._ringing and not phone.phase_ready(), "Incoming call stops typing and requires answer")
				check(phone._content.find_children("*", "LineEdit", true, false).is_empty(), "No real credential fields exist")
				await capture("call")
			phone._complete_event()
		for step: int in 50:
			if screen.state.beat != beat_index or screen._revealing: break
			screen._advance()
	check(screen._revealing, "Story ends with shared investigation reveal")
	screen._finish_investigation_reveal()
	await settle()
	check(screen.state.phase == "reveal", "First activity is hold to reveal")
	phone._mark_mismatch()
	check(screen.state.revealed.is_empty(), "Cannot mark before exposing address")
	phone._start_hold()
	check(not phone._hold_timer.is_stopped(), "Hold uses owned Timer")
	phone._cancel_hold()
	check(phone._hold_timer.is_stopped(), "Release cancels hold")
	phone._start_hold()
	phone.set_locked(true)
	check(phone._hold_timer.is_stopped(), "Pause cancels hold")
	phone.set_locked(false)
	phone._start_hold()
	await create_timer(0.75).timeout
	check(phone._link_revealed, "Sustained hold reveals actual URL")
	phone._mark_mismatch()
	check(screen.state.revealed == ["payout"], "Link mismatch evidence saved")
	await settle()
	await capture("link_revealed")
	phone._finish_phase()
	await settle()
	var target: Button = phone._content.get_node("ExpandTarget") as Button
	target.pressed.emit()
	check(not phone.phase_ready(), "Tap expander requires selecting a link first")
	(phone._content.get_node("ShortLink") as Button).pressed.emit()
	target = phone._content.get_node("ExpandTarget") as Button
	target.pressed.emit()
	check(phone.phase_ready(), "Select-then-tap expands the shortened link")
	target = phone._content.get_node("ExpandTarget") as Button
	check(not target._can_drop_data(Vector2.ZERO, {"unrelated":true}), "Expander rejects unrelated payloads")
	target._drop_data(Vector2.ZERO, {"payout_link":"payout"})
	check(phone.phase_ready(), "Drag expands shortened link")
	await settle()
	await capture("expanded")
	phone._finish_phase()
	await settle()
	phone._find_clue("unknown")
	check(screen.state.hotspots.is_empty(), "Unknown hotspot rejected")
	phone._find_clue("logo")
	phone._find_clue("logo")
	phone._find_clue("spelling")
	check(screen.state.hotspots.size() == 2 and not phone.phase_ready(), "Duplicate clues do not count and two are insufficient")
	phone._find_clue("security")
	check(not phone.phase_ready() and not Case.complete_evidence(screen.state), "Three clues still require key-finding review")
	await settle()
	await capture("three_clues_review")
	var saved: Dictionary = player.get_save_data()
	player.apply_save_data(saved)
	check(player.begin_story_attempt(Case.ID, false, false).hotspots.size() == 3, "Evidence resumes after reload")
	phone._review_findings()
	check(Case.complete_evidence(screen.state), "Key findings review unlocks evidence")
	phone._find_clue("domain")
	phone._find_clue("http")
	check(screen.state.hotspots.size() == 5, "All five clues remain inspectable")
	await settle()
	await capture("all_clues")
	root.size = Vector2i(844,390)
	await settle()
	await capture("flaws_mobile")
	phone._finish_phase()
	check(screen.state.phase == "seal", "Investigation reaches exhibit")
	screen._seal_exhibit()
	await create_timer(0.2).timeout
	screen._process(2.0)
	for step: int in 200:
		if phone.phase_ready(): break
		phone._tick_chat(3.0)
		if phone._chat_stage == "send": phone._send_chat()
	check(phone._chat_contact == "Eric" and phone._chat_history.size() == 1, "Eric's closing notification opens a separate private conversation")
	await settle()
	check(phone._close.is_visible_in_tree() and not phone._close.disabled, "Closing private chat also exposes Continue")
	await capture("closing_chat")
	var credits: int = player.credits
	phone._close.pressed.emit()
	check(screen.state.phase == "closing", "Closing chat Continue reaches the final caption")
	for step: int in 50:
		if not screen.state.completed: screen._advance()
	check(screen.state.completed and player.credits == credits + 125, "Unassisted clear grants reward once")
	screen._save()
	check(player.credits == credits + 125, "Repeated save does not duplicate reward")
	check(player.story_unlocked("mod_01_ch_04"), "The Payout unlocks The Prize")
	check(not player.story_unlocked("mod_01_ch_05"), "Chapter 5 remains unavailable")
	var replay: Dictionary = player.begin_story_attempt(Case.ID, true, false)
	check(replay.revealed.is_empty() and not replay.completed, "Replay is a separate attempt")
	check(not Perks.allowed(replay.perk_run,"perspective","research_test","reveal",[]), "Perks never apply to research tests")
	check(Perks.allowed(replay.perk_run,"perspective","story_chapter","reveal",[]), "Story perk supports Chapter 3 investigations")
	Perks.activate(replay.perk_run,"perspective","story_chapter","reveal",0,[])
	check(Perks.status(replay.perk_run,false) == "assisted", "Assist usage is recorded")
	phone._start_hold()
	screen.on_exit()
	check(phone._hold_timer.is_stopped(), "Scene exit cancels hold")
	screen.queue_free()
	await settle()
	player.apply_save_data(original)
	print("PAYOUT_CHAPTER_CHECKS failures=" + str(failures))
	quit(1 if failures else 0)
