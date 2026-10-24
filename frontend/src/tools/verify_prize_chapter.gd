extends SceneTree
const Case: GDScript = preload("res://src/gameplay/decision/prize_chapter.gd")
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Advisor: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Payout: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
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
		root.get_texture().get_image().save_png("res://.godot/chapter4_" + label + ".png")

func _run() -> void:
	root.size = Vector2i(1480,720)
	var player: Node = root.get_node("PlayerManager")
	var original: Dictionary = player.get_save_data()
	root.get_node("AuthService")._signed_in = false
	player.reset_to_defaults()
	player.lesson_progress = {"mod_01":1}
	root.get_node("SettingsService").text_speed = "instant"
	root.get_node("SettingsService").reduced_motion = true
	check(player.begin_story_attempt(Case.ID,false,false).is_empty(), "Chapter 4 is gated before prior exhibits")
	var first: Dictionary = Survey.fresh()
	for entry: Dictionary in Survey.MESSAGES:
		first.read.append(entry.id)
		first.sorted.append(entry.id)
	for field: String in ["flags","domains","captures"]: first[field] = Survey.suspicious_ids()
	first.sealed = true
	first.completed = true
	player.save_survey_chapter(first,false)
	var second: Dictionary = Advisor.fresh()
	second.flags = ["domain","wording","signature"]
	second.domains = ["fake"]
	second.headers = ["From","Reply-To","Subject"]
	second.sealed = true
	second.completed = true
	player.save_chapter(second,Advisor.ID,false)
	check(not player.story_unlocked(Case.ID), "Chapter 2 alone cannot unlock Chapter 4")
	var third: Dictionary = Payout.fresh()
	third.revealed = ["payout"]
	third.expanded = ["payout"]
	third.hotspots = ["logo","spelling","security"]
	third.reviewed = true
	third.sealed = true
	third.completed = true
	player.save_chapter(third,Payout.ID,false)
	check(player.story_unlocked(Case.ID), "The Payout unlocks The Prize")
	check(not Case.clean({"sealed":true,"claimed":true,"completed":true,"phase":"done"}).completed, "Malformed completion is rejected")
	check(Case.note_matches(" Two ","The survey confirmation reply."), "Natural case-note variants accepted")
	check(not Case.note_matches("2","Jobert went offline"), "Two-minute interval cannot be attributed to last seen")
	player.owned_perks = Perks.ids(["recap","perspective"])
	player.perk_loadout = Perks.ids(["recap","perspective"],2)
	screen = load("res://src/ui/screens/deploy/survey_chapter_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"test":true,"chapter_id":Case.ID})
	await settle()
	var phone: Control = screen._phone
	check(screen.Chapter.ID == Case.ID, "Shared screen injects Chapter 4")
	for beat_index: int in Case.STORY.size():
		check(screen.state.beat == beat_index, "Sequential Chapter 4 story beat %d" % beat_index)
		var beat: Dictionary = Case.STORY[beat_index]
		check(beat.bg == "intro_morning", "Every story beat stays in the intro bedroom")
		if beat.has("caption"):
			for step: int in 12:
				if screen._is_caption_sentence(): screen._advance()
		if beat.get("chat",false):
			for step: int in 20:
				if not screen._chat_started: screen._advance()
			screen._process(2.0)
			await settle()
			for entry: Dictionary in phone.chat_entries: check(entry.who == "John", "Offline Jobert sends no replies")
			for step: int in 200:
				if phone.phase_ready(): break
				phone._tick_chat(3.0)
				if phone._chat_stage == "send": phone._send_chat()
			check(phone.phase_ready(), "Unanswered private chat completes")
			check(phone._chat_status.text.contains("No reply") and not phone._chat_status.text.contains("everyone"), "Offline private-chat receipt is accurate")
			for viewport_size: Vector2i in [Vector2i(1480,720), Vector2i(844,390)]:
				root.size = viewport_size
				await settle()
				var continue_button: Button = phone._close
				check(continue_button.is_visible_in_tree() and not continue_button.disabled, "Completed chat exposes an enabled Continue button at %s" % viewport_size)
				check(continue_button.text == "CONTINUE →", "Completed chat labels the next action")
				var button_rect: Rect2 = continue_button.get_global_rect()
				check(root.get_visible_rect().encloses(button_rect), "Chat Continue stays within the mobile viewport")
				check(button_rect.size.y * root.get_final_transform().get_scale().y >= 48.0, "Chat Continue retains a 48-pixel touch target")
			phone.set_locked(true)
			phone._close.pressed.emit()
			check(screen.state.beat == beat_index and phone._close.disabled, "Paused chat cannot continue")
			phone.set_locked(false)
			await capture("offline_chat")
			phone._close.pressed.emit()
			check(screen.state.beat == beat_index + 1, "Chat Continue advances to the next story beat")
			root.size = Vector2i(1480,720)
			await settle()
		elif beat.get("mail",false):
			check(not phone.phase_ready(), "Mail action gates the story")
			phone._claim()
			check(phone._glitch_elapsed < 0, "Cannot trigger scripted claim before evidence")
			phone._complete_event()
		for step: int in 50:
			if screen.state.beat != beat_index or screen._revealing: break
			screen._advance()
	check(screen._revealing, "Story reaches investigation reveal")
	screen._finish_investigation_reveal()
	await settle()
	check(screen.state.phase == "timeline", "Reconstruction starts with timeline")
	check(screen._heading.text.contains("INVESTIGATION") and not screen._heading.text.contains("NIGHT"), "HUD preserves morning continuity")
	await capture("timeline_unsolved")
	phone._check_timeline()
	check(not phone.phase_ready(), "Empty timeline is not accepted")
	phone.set_locked(true)
	phone._place_record("survey",0)
	check(phone.state.timeline_order[0] == "", "Paused timeline does not mutate")
	phone.set_locked(false)
	phone._place_record("prize",0)
	phone._place_record("survey",1)
	phone._place_record("survey",0)
	check(phone.state.timeline_order[1] == "prize", "Moving an existing record swaps occupied slots")
	for index: int in Case.ORDER.size(): phone._place_record(Case.ORDER[index],index)
	var slot: Button = phone._content.find_child("TimelineSlot_0",true,false) as Button
	check(not slot._can_drop_data(Vector2.ZERO,{"foreign":true}), "Timeline rejects foreign drag data")
	phone._check_timeline()
	check(phone.phase_ready() and screen.state.timeline_checked == ["prize"], "Correct order is persisted")
	await settle()
	await capture("timeline")
	phone._finish_phase()
	await settle()
	check(screen.state.phase == "board", "Timeline proceeds to pattern board")
	await capture("board_unsolved")
	var credits: int = player.credits
	phone._connect_pins("coffee","unknown")
	phone._connect_pins("coffee","coffee")
	check(screen.state.mistakes == 0, "Unknown and self connections are ignored")
	phone._connect_pins("time","eric")
	phone._connect_pins("eric","time")
	check(screen.state.mistakes == 1 and player.credits == credits, "Wrong pair penalized once without deducting wallet coins")
	phone.set_locked(true)
	phone._connect_pins("coffee","group")
	check(screen.state.connections.is_empty(), "Paused board cannot collect evidence")
	phone.set_locked(false)
	phone._select_pin("coffee")
	phone._select_pin("group")
	var pin: Button = phone._board.get_node("Pin_earlier") as Button
	check(not pin._can_drop_data(Vector2.ZERO,{"prize_pin":"unknown"}), "Board rejects unknown drag pins")
	pin._drop_data(Vector2.ZERO,{"prize_pin":"typo"})
	phone._connect_pins("time","jobert")
	check(phone.phase_ready() and screen.state.connections.size() == 3, "Tap and drag connections collect all three patterns")
	phone._connect_pins("amount","coffee")
	check(screen.state.mistakes == 1, "Completed board cannot incur additional penalties")
	await settle()
	await capture("board")
	root.size = Vector2i(844,390)
	await settle()
	await capture("board_mobile")
	phone._finish_phase()
	await settle()
	check(screen.state.phase == "case_note", "Pattern board proceeds to factual report")
	phone._minutes.text = "2"
	phone._after.text = "Jobert went offline"
	phone._check_note()
	check(not phone.phase_ready(), "Incorrect interval explanation is rejected")
	phone._minutes.text = "two"
	phone._after.text = "survey confirmation reply"
	phone._save_note("")
	var saved: Dictionary = player.get_save_data()
	player.apply_save_data(saved)
	check(player.begin_story_attempt(Case.ID,false,false).event_draft == "survey confirmation reply", "Case-note draft survives save reload")
	phone._check_note()
	check(phone.phase_ready() and Case.complete_evidence(screen.state), "Factual case note unlocks exhibit")
	var incomplete: Dictionary = screen.state.duplicate(true)
	incomplete.completed = true
	incomplete.claimed = true
	incomplete.sealed = false
	incomplete.phase = "done"
	check(not Case.clean(incomplete).completed and Case.clean(incomplete).phase == "seal", "Evidence alone cannot bypass sealing")
	check(not phone._minutes.editable and not phone._after.editable, "Saved report fields are read-only")
	await settle()
	await capture("note_mobile")
	root.size = Vector2i(1480,720)
	await settle()
	await capture("note")
	phone._finish_phase()
	check(screen.state.phase == "seal", "Report proceeds to exhibit")
	screen._seal_exhibit()
	await create_timer(0.2).timeout
	for step: int in 20:
		if phone.mode == "epilogue": break
		screen._advance()
	await settle()
	check(phone.mode == "epilogue" and screen.state.sealed, "Scripted claim is only available after seal and dialogue")
	screen._advance()
	check(not screen.state.completed and screen.state.phase == "sleep", "Advance cannot bypass claim")
	await capture("claim")
	phone._claim()
	check(phone._glitch_elapsed == 0, "Claim starts bounded glitch")
	screen._art_ready(true)
	check(screen._story_art_override == Case.CLAIM_ASSET, "Late artwork sync preserves the active claim scene")
	check(screen._bg.texture == root.get_node("AssetManager").get_texture(Case.CLAIM_ASSET), "Claim scene uses the original intro artwork")
	phone.set_locked(true)
	phone._process(2.0)
	check(not screen.state.claimed, "Pause freezes claim animation")
	phone.set_locked(false)
	phone._glitch.gentle = false
	phone._process(0.5)
	await capture("glitch")
	phone._process(1.3)
	check(screen.state.claimed and screen.state.mistakes == 1, "Scripted claim preserves evidence and is not a player mistake")
	for step: int in 50:
		if not screen.state.completed: screen._advance()
	check(screen.state.completed and player.credits == credits + 100, "Clear awards base reward with recorded investigation mistake")
	var clean_clear: Dictionary = screen.state.duplicate(true)
	clean_clear.mistakes = 0
	clean_clear.wrong_pairs = []
	check(Case.clean(clean_clear).reward == 125, "Clean unassisted clear retains the bonus")
	clean_clear.hint_used = true
	check(Case.clean(clean_clear).reward == 100, "Assisted clear keeps base reward without clean-work bonus")
	screen._save()
	check(player.credits == credits + 100, "Repeated save does not duplicate reward")
	check(player.story_unlocked("mod_01_ch_05"), "Sealed prize unlocks Chapter 5")
	var replay: Dictionary = player.begin_story_attempt(Case.ID,true,false)
	check(replay.connections.is_empty() and not replay.claimed, "Replay uses separate attempt")
	check(not Perks.allowed(replay.perk_run,"perspective","research_test","board",[]), "Perks never apply to research tests")
	check(Perks.allowed(replay.perk_run,"perspective","story_chapter","board",[]), "Chapter 4 supports story assists")
	Perks.activate(replay.perk_run,"perspective","story_chapter","board",0,[])
	check(Perks.status(replay.perk_run,false) == "assisted", "Assist usage is recorded")
	screen.on_exit()
	check(phone._glitch_elapsed < 0 and not is_instance_valid(phone._glitch), "Scene exit releases glitch")
	screen.queue_free()
	await settle()
	player.apply_save_data(original)
	print("PRIZE_CHAPTER_CHECKS failures=" + str(failures))
	quit(1 if failures else 0)
