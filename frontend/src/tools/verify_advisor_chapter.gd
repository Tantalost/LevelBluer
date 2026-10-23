extends SceneTree
const Case: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const Survey: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
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
		root.get_texture().get_image().save_png("res://.godot/chapter2_" + label + ".png")

func finish_beat() -> void:
	var beat: int = screen.state.beat
	for index: int in 40:
		screen._advance()
		if screen.state.beat != beat or screen._revealing: return
	check(false, "Story beat advances: %d" % beat)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var player: Node = root.get_node("PlayerManager")
	var auth: Node = root.get_node("AuthService")
	var settings: Node = root.get_node("SettingsService")
	var original: Dictionary = player.get_save_data()
	auth._signed_in = false
	player.reset_to_defaults()
	player.lesson_progress = {"mod_01":1}
	settings.text_speed = "instant"
	settings.reduced_motion = true
	check(player.begin_story_attempt(Case.ID, false, false).is_empty(), "Chapter 2 cannot bypass Chapter 1")
	var first: Dictionary = Survey.fresh()
	for entry: Dictionary in Survey.MESSAGES:
		first.read.append(entry.id)
		first.sorted.append(entry.id)
	for field: String in ["flags","domains","captures"]: first[field] = Survey.suspicious_ids()
	first.sealed = true
	first.completed = true
	player.save_survey_chapter(first, false)
	var first_record: String = JSON.stringify(player.chapter_progress[Survey.ID])
	check(player.story_unlocked(Case.ID), "Chapter 1 unlocks Chapter 2")
	check(not player.story_unlocked("mod_01_ch_03"), "Chapter 3 remains unavailable")
	player.owned_perks = Perks.ids(["recap","perspective","reference"])
	player.perk_loadout = Perks.ids(["perspective","reference"],2)
	screen = load("res://src/ui/screens/deploy/survey_chapter_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"test":true,"chapter_id":Case.ID})
	await settle()
	check(screen._caption.text.contains("Four days"), "Chapter 2 opening caption")
	await capture("opening")
	# Walk every authored beat through the same screen, including the actual chat clock.
	for beat_index: int in Case.STORY.size():
		check(screen.state.beat == beat_index, "Sequential story beat")
		var beat: Dictionary = Case.STORY[beat_index]
		if beat.has("caption"):
			check(not screen._phone.visible, "Phone stays hidden during anonymous caption")
			screen._advance()
		if beat.get("mail", false):
			await settle()
			if beat_index == 1:
				check(screen._phone._lead_in == "notification", "Email arrives as a notification before opening")
				check(root.get_node("AudioManager")._sounds.has("ui_notification"), "Notification sound is available")
				check(not screen._phone.phase_ready(), "Notification cannot count as reading the email")
				await capture("notification")
				screen._phone.set_locked(true)
				screen._phone._open_notification()
				check(screen._phone._lead_in == "notification", "Paused notification cannot open")
				screen._phone.set_locked(false)
				screen._phone._content.find_child("OpenNotification", true, false).pressed.emit()
				check(screen._phone._lead_in.is_empty(), "Tapping notification opens email")
				await settle()
				await capture("advisor_email")
			screen._phone._add("read", str(beat.email))
		if beat.get("chat", false):
			screen._sentence = screen._sentences.size() - 1
			screen._show_sentence()
			screen._chat_started = true
			screen._open_chat(screen._seq)
			if beat.chat_id == "private":
				settings.reduced_motion = false
				check(screen._phone._lead_in == "contacts", "Private message begins in Contacts")
				screen._phone._tick_chat(20.0)
				check(screen._phone._chat_history.is_empty(), "No messages arrive while selecting a contact")
				screen._phone.set_locked(true)
				screen._phone._tick_lead_in(5.0)
				screen._phone._select_jobert()
				check(screen._phone._lead_elapsed == 0.0 and screen._phone._lead_in == "contacts", "Contacts pause with menu")
				screen._phone.set_locked(false)
				await settle()
				screen._phone._tick_lead_in(2.0)
				check((screen._phone._content.get_parent() as ScrollContainer).scroll_vertical > 0, "Contact list scrolls to Jobert")
				await capture("contacts")
				screen._phone._contact_button.pressed.emit()
				check(screen._phone._lead_in == "contact_tap", "Jobert selection receives tap feedback")
				screen._phone._tick_lead_in(0.4)
				check(screen._phone._lead_in.is_empty(), "Jobert opens before composing first message")
				settings.reduced_motion = true
			for turn: int in screen._phone.chat_entries.size():
				if screen._phone._chat_stage == "draft":
					screen._phone._tick_chat(10.0)
					screen._phone._send_chat()
				else: screen._phone._tick_chat(2.0)
				screen._phone._tick_chat(3.0)
			check(screen._phone.phase_ready(), "Animated conversation finishes")
			check(screen._phone._chat_status.text.contains("Private") if beat.chat_id == "private" else screen._phone._chat_status.text == "Seen by everyone", "Read receipt matches chat privacy")
			check(not screen._cast.jobert.visible and not screen._cast.eric.visible, "Chat participants remain remote")
			await settle()
			await capture(str(beat.chat_id) + "_chat")
		if beat_index == 21:
			check(screen._poses.john == 6, "John uses the dedicated laughing pose")
			await capture("laugh")
			screen._sentence = 2
			screen._show_sentence()
			check(screen._poses.john == 0, "John becomes thoughtful for the final sentence")
		if beat.get("time", "") == "night":
			check(not screen._cast_stage.visible, "Night illustration does not duplicate John")
			check(screen._bg.texture == root.get_node("AssetManager").get_texture("story_bg_john_bed_night"), "Chapter 2 uses its bed background")
			if "--render" in OS.get_cmdline_user_args(): check(screen._bg.texture != null, "Night artwork is cached for visual verification")
			if beat_index == 24: await capture("bed_night")
		finish_beat()
		await settle()
	check(screen._revealing, "Shared investigation reveal runs")
	screen._finish_investigation_reveal()
	check(screen.state.phase == "compare", "Chapter 2 begins with comparison, not sorting")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		await capture("compare_%d" % dimensions.x)
		check(screen._phone.get_global_rect().end.x <= root.get_visible_rect().end.x + 2, "Comparison fits viewport")
		for field: String in ["domain", "format", "wording", "signature"]:
			screen._phone._comparison_field = field
			screen._phone._render()
			await settle()
			var cards: HBoxContainer = screen._phone._content.get_node("ComparisonCards") as HBoxContainer
			check(absf(cards.get_child(0).size.x - cards.get_child(1).size.x) < 2, "Comparison cards have equal width")
			check(cards.get_global_rect().end.x <= screen._phone._shell.get_global_rect().end.x, "Comparison cards do not overflow")
			var value_a: Label = cards.get_child(0).find_child("ComparisonValue", true, false) as Label
			var value_b: Label = cards.get_child(1).find_child("ComparisonValue", true, false) as Label
			check(value_a.get_theme_font_size("font_size") == value_b.get_theme_font_size("font_size"), "Comparison values use matching readable typography")
			var mark: Button = cards.find_child("MarkDifference", true, false) as Button
			check((mark.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == screen._phone.PHONE_HEADER, "Comparison reuses the established phone accent")
			check(mark.get_theme_color("font_color") == screen._phone.INK, "Comparison retains ink-on-light phone controls")
			check(mark.size.y * root.get_final_transform().get_scale().y >= 47, "Comparison has a mobile-sized action target")
			await capture("compare_%s_%d" % [field, dimensions.x])
	var phone: Control = screen._phone
	screen._toggle_menu()
	phone._mark_difference("domain")
	check(screen.state.flags.is_empty(), "Paused activities cannot collect evidence")
	screen._toggle_menu()
	phone._mark_difference("format")
	check(screen.state.mistakes == 1 and screen.state.flags.is_empty(), "Shared format is not a mismatch")
	for field: String in ["domain","wording","signature"]: phone._mark_difference(field)
	check((phone._content.find_child("MarkDifference", true, false) as Button).disabled, "Collected evidence cannot be marked again")
	check(screen.state.captures == ["real","fake"], "Comparison preserves both messages as exhibits")
	phone._finish_phase()
	check(screen.state.phase == "report", "Comparison advances to report")
	phone._report_input.text = "school.example"
	phone._submit_report()
	check(screen.state.domains.is_empty(), "Genuine domain is not accepted as transcription of fake domain")
	phone._report_input.text = "schoo1.example"
	phone._draft_changed("schoo1.example")
	phone._submit_report()
	check(screen.state.domains == ["fake"], "Exact fake domain accepted")
	await settle()
	await capture("report_844")
	var saved: Dictionary = player.get_save_data()
	player.apply_save_data(saved)
	check(player.begin_story_attempt(Case.ID, false, false).domains == ["fake"], "Mid-investigation resume retains evidence")
	phone._finish_phase()
	check(screen.state.phase == "headers", "Report advances to raw header")
	phone._match_header("From","Reply-To")
	check(screen.state.headers.is_empty(), "Incorrect header does not progress")
	var first_target: Button = phone._content.get_node("Header_From") as Button
	check(first_target != null and first_target.has_signal("matched"), "Raw header exposes a drop target")
	check(first_target._can_drop_data(Vector2.ZERO, {"advisor_header":"From"}), "Header target accepts valid dragged labels")
	check(not first_target._can_drop_data(Vector2.ZERO, {"advisor_header":"Unknown"}), "Header target rejects unrelated drag payloads")
	first_target._drop_data(Vector2.ZERO, {"advisor_header":"From"})
	phone._picked_header = "Reply-To"
	# The same pressed signal used by touch completes the next field.
	var reply_target: Button = phone._content.get_node("Header_Reply_To") as Button
	reply_target.pressed.emit()
	phone._match_header("Subject", "Subject")
	check(phone.phase_ready(), "All header fields matched")
	await settle()
	await capture("headers_844")
	screen._open_perks()
	screen._use_perk("perspective")
	check(screen.state.perk_run.uses.get("perspective", 0) == 1, "Chapter 2 contextual hint records use")
	screen._close_perks()
	screen._open_perks()
	screen._use_perk("reference")
	check(screen.state.perk_run.uses.get("reference", 0) == 1, "Cross-Reference works with collected comparison")
	screen._close_perks()
	for context: String in ["checkpoint","short_check","research_test"]:
		check(not Perks.allowed(screen.state.perk_run,"reference",context,"headers",screen.state.captures), "Chapter 2 perks denied in tests")
	phone._finish_phase()
	check(screen.state.phase == "seal" and Case.complete_evidence(screen.state), "Three complete evidence bundles required")
	screen._seal_exhibit()
	await create_timer(0.2).timeout
	check(screen.state.phase == "sleep", "Sealing leads to closing story")
	for index: int in 12:
		if screen.state.phase == "sleep": screen._advance()
	check(screen.state.phase == "closing" and screen._caption.visible, "Anonymous ending shown on black")
	await settle()
	await capture("closing")
	var credits: int = player.credits
	for index: int in 8:
		if screen.state.phase == "closing": screen._advance()
	check(screen.state.completed and player.credits == credits + 100, "Assisted clear awards base reward once")
	screen._save()
	check(player.credits == credits + 100, "Repeated save cannot duplicate coins")
	check(JSON.stringify(player.chapter_progress[Survey.ID]) == first_record, "Chapter 2 never changes Chapter 1 exhibit")
	check(screen._result_actions.get_child(0).disabled, "Chapter 3 CTA remains unavailable")
	await settle()
	await capture("complete")
	var replay: Dictionary = player.begin_story_attempt(Case.ID, true, false)
	check(replay.perk_run.id != screen.state.perk_run.id, "Replay creates separate attempt")
	player.save_story_attempt(replay, true, false, Case.ID)
	player.apply_save_data(player.get_save_data())
	check(player.story_checkpoint(Case.ID,true).perk_run.id == replay.perk_run.id, "Chapter-keyed replay survives reload")
	check(not Case.clean({"completed":true,"sealed":true,"phase":"done"}).completed, "Malformed completion cannot unlock next chapter")
	var clean_clear: Dictionary = screen.state.duplicate(true)
	clean_clear.mistakes = 0
	clean_clear.hint_used = false
	var empty_loadout: Array[String] = []
	clean_clear.perk_run = Perks.new_run("clean-case2", empty_loadout, false, true, Case.ID)
	check(Case.clean(clean_clear).reward == 125, "Unassisted Chapter 2 preserves clean-work bonus")
	check(Survey.clean(clean_clear).perk_run.is_empty(), "Chapter 2 perk records cannot attach to Chapter 1")
	screen.on_exit()
	screen.queue_free()
	await settle()
	player.apply_save_data(original)
	print("ADVISOR_CHAPTER_CHECKS failures=" + str(failures))
	quit(1 if failures else 0)
