extends SceneTree
const Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
var failures: int = 0
var screen: Control
var fixture_focus: bool = true

func _process(_delta: float) -> bool:
	# Desktop users may work in another window during rendered verification.
	# Keep this fixture active until the explicit focus-loss tests below.
	if fixture_focus and is_instance_valid(screen) and screen.is_node_ready():
		screen._backgrounded = false
		screen._apply_pause()
	return false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i: int in 8: await process_frame

func finish_beat() -> void:
	var beat: int = int(screen.state.beat)
	var phase: String = str(screen.state.phase)
	for i: int in 20:
		screen._advance()
		if int(screen.state.beat) != beat or str(screen.state.phase) != phase or screen._revealing: return
	check(false, "Dialogue beat can finish without a pagination deadlock")

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		check(screen.visible, "Rendered chapter remains visible: " + label)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/chapter1_" + label + ".png")

func click(control: Control) -> void:
	if DisplayServer.get_name() == "headless":
		(control as Button).pressed.emit()
		await settle()
		return
	var location: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = location
	root.push_input(motion)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = location
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await settle()

func _run() -> void:
	# Headless windows have no desktop size; use the same baseline as render QA.
	root.size = Vector2i(1280, 720)
	var player: Node = root.get_node("PlayerManager")
	var auth: Node = root.get_node("AuthService")
	var settings: Node = root.get_node("SettingsService")
	var original: Dictionary = player.get_save_data()
	auth._signed_in = false
	settings.text_speed = "instant"
	settings.reduced_motion = true
	player.chapter_progress = {}
	player.credits = 50
	# Normalize the fixture through the existing save loader before fingerprinting.
	player.apply_save_data(player.get_save_data())
	var legacy: String = JSON.stringify([player.onboarding_state, player.mastery_matrix, player.cleared_stages])
	# Same Cloudinary/user:// cache as gameplay; no repository PNG fixtures.
	var assets: Node = root.get_node("AssetManager")
	assets._ensure_assets_dir()
	for entry: Dictionary in assets._school_story_catalog():
		var asset_id: String = str(entry.asset_id)
		if not asset_id.begins_with("chapter1_") and asset_id != "story_bg_john_desk_night": continue
		var download: bool = "--download-art" in OS.get_cmdline_user_args() or ("--download-night" in OS.get_cmdline_user_args() and asset_id == "story_bg_john_desk_night")
		if download:
			check(await assets._download_and_store(entry), "Chapter art downloads into cache: " + asset_id)
			check(assets._is_cache_current(asset_id, entry.cloudinary_url, entry.version, entry.local_path), "Downloaded chapter art uses current Cloudinary URL: " + asset_id)
		check(assets.get_texture(asset_id) != null, "Missing cached chapter art: " + asset_id + ". Run once with -- --download-art.")
	if failures > 0:
		player.apply_save_data(original)
		quit(1)
		return
	screen = load("res://src/ui/screens/deploy/survey_chapter_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"test":true})
	await settle()
	await capture("day")
	await click(screen._advance_button)
	check(screen.state.beat == 0 and screen._sentence == 1, "Real pointer advances one sentence, not the entire beat")
	check(screen._line.text == "And here I was, late again.", "Only the current sentence appears")
	finish_beat()
	await settle()
	await capture("eric_updated")
	check(screen._portrait.texture is AtlasTexture and screen._portrait.texture.get_size() == Vector2(608,550), "Body poses share one stable canvas")
	for beat_index: int in [6,7,9]:
		screen.state.beat = beat_index
		screen._render()
		await settle()
		var pose_texture: AtlasTexture = screen._portrait.texture as AtlasTexture
		check(pose_texture != null and pose_texture.get_size() == Vector2(608,550), "Questioning, nervous and caution poses retain canvas size")
		await capture("pose_" + str(beat_index))
	screen.state.beat = 1
	screen._render()
	for i: int in 3: finish_beat()
	await settle()
	check(not screen._phone.visible, "Phone stays hidden before John's invitation to ask")
	check(screen._cast["john"].visible and not screen._cast["eric"].visible and not screen._cast["jobert"].visible, "Only John is physically present once his friends step outside")
	screen._advance()
	check(not screen._phone.visible, "Departure lead-in does not open chat early")
	screen._advance()
	check(not screen._phone.visible, "Final lead-in sentence has a readable hold before opening")
	screen._process(0.9)
	await settle()
	check(screen._phone.visible and screen._phone.mode == "chat", "Last lead-in sentence opens Club Chat")
	check(screen._phone._chat_history.is_empty(), "Chat opens without future messages")
	check(not screen._dialogue.visible, "Chat does not repeat dialogue outside the phone")
	screen._advance()
	check(screen.state.beat == 4, "Chat cannot be skipped by dialogue advance")
	screen._phone._tick_chat(1.0)
	await settle()
	await click(screen._phone._chat_send)
	screen._phone._send_chat()
	check(screen._phone._chat_history.size() == 1, "Send creates one bubble; double-send ignored")
	screen._phone._tick_chat(2.5)
	await settle()
	check(screen._phone._chat_stage == "typing" and screen._phone._chat_history.size() == 1, "Eric types before his message arrives")
	check(screen._cast["john"].visible and not screen._cast["eric"].visible and not screen._cast["jobert"].visible, "Remote chat senders never appear beside John")
	check(screen._cast["john"].modulate == Color.WHITE and screen._portrait == screen._cast["john"], "John stays lit while reading remote replies")
	var john_slot: Vector2 = screen._cast["john"].position
	await capture("chat_typing")
	screen._toggle_menu()
	var chat_clock: float = screen._phone._chat_elapsed
	screen._phone._tick_chat(10.0)
	check(screen._phone._chat_elapsed == chat_clock, "Menu freezes chat typing")
	screen._toggle_menu()
	screen._phone._close_app()
	screen._phone._tick_chat(10.0)
	check(screen._phone._chat_elapsed == chat_clock, "Returning to phone home freezes chat timing")
	screen._phone._close_app()
	screen.on_exit()
	screen._phone._tick_chat(10.0)
	screen.on_resume()
	check(screen._phone._chat_history.size() == 1 and screen._phone._chat_stage == "typing", "Settings return preserves in-flight chat")
	check(not screen._cast["eric"].visible and not screen._cast["jobert"].visible, "Settings return does not respawn remote senders")
	screen._phone._tick_chat(2.0)
	check(screen._phone._chat_history.size() == 2, "Eric's reply arrives alone")
	screen._phone._tick_chat(2.5)
	check(screen._cast["john"].position == john_slot, "Speaker focus does not move character slots")
	screen._phone._tick_chat(2.0)
	check(screen._phone._chat_history.size() == 3, "Jobert replies after Eric")
	check(screen._portrait == screen._cast["john"] and not screen._cast["jobert"].visible, "Jobert's reply stays in the phone only")
	screen._phone._tick_chat(2.5)
	screen._phone._tick_chat(1.0)
	await settle()
	await capture("chat_reply")
	await click(screen._phone._chat_send)
	screen._phone._tick_chat(2.5)
	check(screen._phone.phase_ready(), "Final sent reply unlocks Continue")
	await capture("chat")
	screen._phone._close_app()
	check(screen.state.beat == 5, "Chat Continue returns to face-to-face story")
	check(screen._cast["eric"].visible and screen._cast["jobert"].visible, "Room cast returns for the subsequent face-to-face scene")
	for i: int in 6: finish_beat()
	check(screen.state.beat == 11, "Afternoon inbox")
	for i: int in 6: screen._advance()
	check(screen.state.beat == 11, "Unread messages block story advance")
	for entry: Dictionary in Chapter.MESSAGES:
		screen._phone._select(entry.id)
		screen._phone.acknowledge()
	screen._phone._finish_phase()
	finish_beat()
	await settle()
	check(screen.state.beat == 12 and screen.state.phase == "day", "Night story keeps existing saved beat IDs")
	check(screen._heading.text.contains("NIGHT"), "Night header begins with the nighttime story, not only investigation")
	check(screen._bg.texture != null and screen._bg.texture == assets.get_texture("story_bg_john_desk_night"), "Night story uses the desk artwork")
	check(not screen._cast_stage.visible, "Seated artwork does not receive a duplicate standing portrait")
	await capture("night_desk")
	finish_beat()
	check(screen._revealing and screen._reveal.gentle, "Final night sentence starts reduced-motion investigation reveal")
	check(not screen._phone.visible and not screen._dialogue.visible and not screen._journal.visible, "Reveal hides gameplay panels")
	screen._advance()
	check(screen.state.phase == "day", "Repeated taps cannot skip title or mutate saved phase")
	screen._toggle_menu()
	var reveal_time: float = screen._reveal.elapsed
	await create_timer(0.2).timeout
	check(is_equal_approx(screen._reveal.elapsed, reveal_time), "Investigation reveal pauses with menu")
	screen._toggle_menu()
	await create_timer(1.7).timeout
	await capture("investigation_gentle")
	await create_timer(2.6).timeout
	check(screen.state.phase == "sort", "Night begins after reading six messages")
	check(not screen._revealing and not screen._reveal.visible and screen._phone.visible, "Title completion reveals playable investigation")
	check(is_equal_approx(root.get_node("AudioManager")._story_duck_gain, 1.0), "Music gain restored after reveal")
	check(screen._bg.texture == assets.get_texture("story_bg_john_desk_night"), "Investigation retains nighttime desk")
	screen._toggle_menu()
	screen._phone.sort_message("survey",true)
	check(screen.state.sorted.is_empty(), "Paused phone cannot change evidence")
	screen._toggle_menu()
	screen._phone.sort_message("survey",false)
	check(screen.state.mistakes == 1 and screen.state.sorted.is_empty(), "Incorrect sorting retries without awarding evidence")
	screen._phone._select("survey")
	for node: Node in screen._phone._content.get_children():
		if node is Button and node.text == "SUSPICIOUS":
			check(node._can_drop_data(Vector2.ZERO,{"survey_card":"survey"}), "Sorting bin accepts message drag payload")
			node._drop_data(Vector2.ZERO,{"survey_card":"survey"})
			break
	check(screen.state.sorted.has("survey"), "Drag-drop signal sorts the selected message")
	for entry: Dictionary in Chapter.MESSAGES:
		screen._phone.sort_message(entry.id,entry.suspicious)
	await settle()
	await capture("sort")
	screen._phone._finish_phase()
	check(screen.state.phase == "highlight", "Sorting leads to highlighting")
	var checkpoint: Dictionary = player.get_save_data()
	player.apply_save_data(checkpoint)
	screen.on_exit()
	screen.on_enter({"test":true})
	check(screen.state.phase == "highlight" and screen.state.sorted.size() == 6, "Mid-investigation checkpoint resumes")
	check(screen.visible, "Re-entered checkpoint is visible")
	for id: String in Chapter.suspicious_ids():
		screen._phone._select(id)
		screen._phone.mark_flag()
		screen._phone.mark_flag()
	check(screen.state.flags.size() == 3, "Duplicate flags do not count twice")
	await settle()
	await capture("highlight")
	screen._phone._finish_phase()
	for id: String in Chapter.suspicious_ids():
		screen._phone._select(id)
		await settle()
		check(screen._phone.find_child("MessageHeader", true, false) != null and screen._phone.find_child("MessageBody", true, false) != null, "Message metadata and body have separate surfaces")
		screen._phone._sender.select(0, 6)
		screen._phone._copy_sender()
		check(screen._phone._clipboard == str(Chapter.message(id).address).substr(0, 6), "Copy preserves arbitrary selected sender text, not an automatic answer")
		screen._phone._select_domain()
		(screen._phone._content.get_parent() as ScrollContainer).ensure_control_visible(screen._phone._copy_button)
		await settle()
		await click(screen._phone._copy_button)
		var expected_domain: String = str(Chapter.message(id).address).get_slice("@", 1)
		check(screen._phone._clipboard == expected_domain, "Selected domain copied to private phone clipboard")
		if id == "survey": await capture("sender_selection")
		screen._phone._notes_home()
		await settle()
		check(screen._phone.find_child("NotepadIcon",true,false) != null, "Notepad uses the existing home-screen icon")
		check(not screen._phone._nav.visible and screen._app_shortcuts.visible, "App navigation is outside the home-screen wallpaper")
		if id == "survey": await capture("notes_home")
		screen._phone._open_notes()
		await settle()
		screen._toggle_menu()
		screen._phone._paste_note()
		check(screen._phone._domain.text.is_empty(), "Paused clipboard cannot change notes")
		screen._toggle_menu()
		screen._phone._paste_note()
		check(screen._phone._domain.text == expected_domain, "Paste restores selected text without memorizing it")
		screen._phone._open_mail()
		screen._phone._open_notes()
		check(screen._phone._domain.text == expected_domain, "Switching apps preserves the current draft")
		if id == "survey": await capture("notepad")
		screen._phone._domain.text = "gmai1.com"
		screen._phone.check_domain()
		check(not screen.state.domains.has(id), "Lookalike domain rejected")
		screen._phone._domain.text = " " + str(Chapter.message(id).address).get_slice("@",1).to_upper() + " "
		screen._phone.check_domain()
	check(screen.state.domains.size() == 3, "Canonical sender notes saved")
	screen._phone._finish_phase()
	screen._phone._select("survey")
	screen._phone.take_photo()
	check(screen.state.captures.is_empty(), "Incomplete framing blocked")
	await settle()
	var camera: Control = screen._phone._camera
	var before_drag: Vector2 = camera.frame.position
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = camera.frame.get_center() * camera.size
	camera._gui_input(touch)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch.position + Vector2(12,8)
	camera._gui_input(drag)
	touch.pressed = false
	camera._gui_input(touch)
	check(camera.frame.position != before_drag, "Touch drag moves evidence frame")
	await capture("camera")
	for id: String in Chapter.suspicious_ids():
		screen._phone._select(id)
		await settle()
		var capture_camera: Control = screen._phone._camera
		check(not screen._app_shortcuts.get_child(2).disabled, "Opening a message enables external Capture through view_changed")
		var required: Rect2 = capture_camera.required_pixels()
		capture_camera.frame = Rect2(required.position / capture_camera.size, required.size / capture_camera.size)
		check(capture_camera.complete(), "Framing actual text succeeds without blank bottom space")
		capture_camera.frame.size.y -= 0.05
		check(not capture_camera.complete(), "Cutting off the request is still rejected")
		capture_camera.frame.size.y += 0.05
		screen._phone._camera._commit()
		await screen._phone.take_photo()
	check(screen.state.captures.size() == 3, "Three contextual captures")
	screen._phone._finish_phase()
	check(screen.state.phase == "seal", "Evidence review gates sealing")
	await settle()
	await capture("seal")
	screen._seal_exhibit()
	screen._seal_exhibit()
	screen._toggle_menu()
	await create_timer(0.15).timeout
	check(screen.state.phase == "seal", "Sealing pauses with menu")
	screen._toggle_menu()
	await create_timer(0.2).timeout
	check(screen.state.phase == "sleep", "Seal animation ends in sleep")
	settings.reduced_motion = false
	finish_beat()
	check(screen.state.phase == "done", "Chapter completes")
	check(screen.state.next_chapter_unlocked, "Next chapter access earned without publishing unfinished content")
	check(player.credits == 150, "One base reward with no clean bonus after mistake")
	check(screen._results.visible and not screen._journal.visible, "Completion uses the dedicated celebration card")
	check(screen._result_actions.get_child(0).disabled, "Unimplemented next chapter is clearly unavailable")
	check(screen._result_actions.get_child(1).text == "UPGRADES", "Completion exposes the existing Upgrades destination")
	check(screen._result_audio.stream != null and screen._result_audio.stream.get_length() >= 5.5, "Original celebration music loads")
	await create_timer(1.2).timeout
	screen._toggle_menu()
	var reward_clock: float = screen._results.elapsed
	await create_timer(0.2).timeout
	check(is_equal_approx(screen._results.elapsed, reward_clock), "Celebration pauses with menu")
	check(screen._result_audio.stream_paused, "Celebration music pauses with menu")
	screen._toggle_menu()
	await capture("complete_counting")
	await create_timer(2.0).timeout
	check(player.credits == 150, "Visual credit count-up never awards a second payout")
	if DisplayServer.get_name() != "headless":
		check(screen._results.shown_award == 100 and screen._results.shown_balance == 150, "Displayed credit and wallet totals match persisted reward")
	screen._save()
	check(player.credits == 150, "Repeat save cannot award twice")
	check(JSON.stringify([player.onboarding_state,player.mastery_matrix,player.cleared_stages]) == legacy, "Legacy progress and BKT unchanged")
	await settle()
	await capture("complete")
	settings.reduced_motion = true
	screen._settings_changed()
	check(screen._results.gentle, "Reduced-motion completion disables flying coins and confetti")
	var saved_music: bool = settings.music_enabled
	settings.music_enabled = false
	screen._settings_changed()
	check(not screen._result_audio.playing, "Music mute stops the celebration flourish")
	check(is_equal_approx(root.get_node("AudioManager")._story_duck_gain, 1.0), "Muting celebration releases background music duck")
	settings.music_enabled = saved_music
	screen._settings_changed()
	check(not screen._result_audio.playing, "Unmute does not replay the completed reward flourish")
	var stored: Dictionary = player.get_save_data()
	player.apply_save_data(stored)
	check(player.chapter_progress[Chapter.ID].completed and player.credits == 150, "Completion survives serialization")
	screen._replay()
	screen._advance()
	check(player.chapter_progress[Chapter.ID].completed and player.credits == 150, "Replay isolated from original exhibit")
	var bad: Dictionary = Chapter.clean({"phase":"done","sealed":true,"completed":true,"flags":"bad"})
	check(not bad.completed and bad.phase == "day", "Malformed/incomplete saves repair safely")
	var clean: Dictionary = stored.chapter_progress[Chapter.ID].duplicate(true)
	clean.mistakes = 0
	check(Chapter.clean(clean).reward == 125, "Clean work earns 25 bonus")
	clean.hint_used = true
	check(Chapter.clean(clean).reward == 100, "Hints remove clean-work bonus only")
	player.apply_save_data({})
	check(player.chapter_progress.is_empty(), "Absent chapter state cannot leak between accounts")
	player.apply_save_data(stored)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(844,390)]:
		root.size = dimensions
		screen.state = Chapter.clean(stored.chapter_progress[Chapter.ID])
		screen.state.phase = "highlight"
		screen.state.completed = false
		screen._render()
		await settle()
		screen._phone._select("survey")
		await settle()
		check(screen._phone.get_global_rect().end.x <= root.get_visible_rect().end.x + 2, "Phone fits viewport")
		check(screen._header.get_global_rect().end.x <= root.get_visible_rect().end.x + 2, "Header fits viewport")
		check(screen._journal.get_global_rect().position.x >= screen._phone.get_global_rect().position.x, "Task bar is on the right")
		check(screen._journal.get_global_rect().end.y <= screen._phone.get_global_rect().position.y, "Task bar does not overlap the phone")
		await capture("investigate_" + str(dimensions.x))
		screen.state.phase = "notes"
		screen._render()
		screen._phone._select("profile")
		await settle()
		screen._phone._select_domain()
		screen._phone._copy_sender()
		await capture("sender_" + str(dimensions.x))
		screen._phone._open_notes()
		screen._phone._paste_note()
		await settle()
		check(screen._phone._domain.get_global_rect().end.y <= screen._phone.get_global_rect().end.y, "Notepad field stays inside phone")
		check(screen._phone._paste_button.get_global_rect().size.x >= 80, "Paste has a real touch width, not a collapsed column")
		check(screen._phone._paste_button.get_global_rect().end.y <= (screen._phone._content.get_parent() as Control).get_global_rect().end.y, "Paste stays visible in the note viewport")
		await capture("notepad_" + str(dimensions.x))
		screen.state.phase = "capture"
		screen._render()
		screen._phone._select("profile")
		await settle()
		var mobile_camera: Control = screen._phone._camera
		var bounds: Rect2 = mobile_camera.required_pixels()
		mobile_camera.frame = Rect2(bounds.position / mobile_camera.size, bounds.size / mobile_camera.size)
		mobile_camera._commit()
		check(mobile_camera.complete(), "Wrapped screenshot text accepted at " + str(dimensions.x))
		check(mobile_camera.get_global_rect().end.y <= (mobile_camera.get_parent().get_parent() as Control).get_global_rect().end.y + 2, "Whole capture sheet is visible without scrolling")
		await capture("framing_" + str(dimensions.x))
		for entry: Dictionary in Chapter.MESSAGES:
			if not entry.has("thought"): continue
			screen._set_line(str(entry.thought))
			for sentence: String in screen._sentences:
				await settle()
				check(screen._line.get_content_height() <= screen._line.size.y + 2, "Evidence sentence fits without scrolling: " + sentence)
				screen._advance()
		screen._set_line("One thought. Another thought? Last thought!")
		check(screen._line.text == "One thought.", "Investigation thoughts are also paginated")
		screen._advance()
		check(screen._line.text == "Another thought?", "Thought continuation stays available during investigation")
		screen._advance()
		check(not screen._advance_button.visible, "Last thought returns control to the phone")
		screen.state = Chapter.fresh()
		screen._render()
		await settle()
		await capture("dialogue_" + str(dimensions.x))
		check(screen._dialogue.get_global_rect().end.y <= root.get_visible_rect().end.y + 2, "Dialogue and nameplate remain on-screen")
		for beat: Dictionary in Chapter.STORY:
			screen._set_line(str(beat.line))
			for i: int in screen._sentences.size():
				screen._sentence = i
				screen._show_sentence()
				await settle()
				check(screen._line.get_content_height() <= screen._line.size.y + 2, "Story sentence fits at " + str(dimensions.x))
		screen.state.beat = 4
		screen._render()
		for sentence_index: int in range(screen._sentences.size() - 1): screen._advance()
		screen._process(0.9)
		screen._phone._tick_chat(1.0)
		await settle()
		check(screen._phone._chat_send.get_global_rect().end.y <= root.get_visible_rect().end.y, "Chat Send fits at " + str(dimensions.x))
		check(screen._phone._content.get_parent().size.y > 40, "Chat history retains a scrollable viewport")
		await capture("chat_draft_" + str(dimensions.x))
		screen._phone._send_chat()
		screen._phone._tick_chat(2.5)
		screen._phone._tick_chat(2.0)
		await settle()
		var chat_view: ScrollContainer = screen._phone._content.get_parent() as ScrollContainer
		check(screen._phone._chat_status.get_global_rect().end.y <= chat_view.get_global_rect().end.y + 2, "Incoming reply scrolls into view after layout")
		await capture("chat_incoming_" + str(dimensions.x))
		screen.state.beat = 12
		screen._render()
		await settle()
		await capture("night_desk_" + str(dimensions.x))
		screen.state = Chapter.clean(stored.chapter_progress[Chapter.ID])
		screen.replay = false
		screen._render()
		await settle()
		await capture("complete_" + str(dimensions.x))
		check(screen._heading.text.is_empty(), "Completion does not repeat the card title in the header")
		screen._toggle_menu()
		await settle()
		await capture("pause_" + str(dimensions.x))
		var modal: Rect2 = screen._menu.get_global_rect()
		check(modal.end.y <= root.get_visible_rect().end.y and modal.position.y >= 0, "Pause panel stays entirely on screen")
		check(absf(modal.size.x - modal.size.y) < 3, "Pause menu is square rather than stretched")
		check(modal.get_center().distance_to(screen._area.get_global_rect().get_center()) < 3, "Pause menu is centered")
		check(screen._menu_backdrop.visible and screen._menu_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "Pause backdrop blocks clicks behind modal")
		screen._toggle_menu()
		check(not screen._menu_backdrop.visible, "Resume removes input-blocking backdrop")
		check(screen._results.get_global_rect().end.y <= root.get_visible_rect().end.y, "Reward card fits viewport")
		for button: Node in screen._result_actions.get_children():
			check((button as Control).get_global_rect().size.y * root.get_final_transform().get_scale().y >= 63, "Primary result buttons retain large touch targets")
		check(not screen._result_audio.playing, "Reopening completed results never repeats celebration music")
	# The dramatic version is presentation-only and restarts safely after Settings.
	settings.reduced_motion = false
	screen._start_investigation_reveal()
	await create_timer(1.7).timeout
	await capture("investigation_title")
	fixture_focus = false
	screen._backgrounded = true
	screen._apply_pause()
	reveal_time = screen._reveal.elapsed
	await create_timer(0.2).timeout
	check(is_equal_approx(screen._reveal.elapsed, reveal_time), "Reveal pauses in background")
	screen._backgrounded = false
	screen._apply_pause()
	fixture_focus = true
	screen.on_exit()
	check(not screen._revealing and not screen._reveal.visible, "Exit cancels title and hides overlay")
	check(is_equal_approx(root.get_node("AudioManager")._story_duck_gain, 1.0), "Exit restores music gain")
	screen.on_resume()
	check(screen._revealing, "Returning from Settings restarts interrupted title")
	settings.reduced_motion = true
	screen._settings_changed()
	check(screen._reveal.gentle, "Live reduced-motion setting removes movement without skipping reveal")
	await create_timer(4.3).timeout
	check(screen.state.phase == "sort" and not screen._revealing, "Resumed reveal completes once")
	# Background/menu typing cannot silently advance; callbacks die on exit.
	fixture_focus = false
	settings.text_speed = "normal"
	settings.reduced_motion = false
	screen._phone.configure_chapter("chat", screen.state)
	screen._phone.set_locked(false)
	screen._phone._tick_chat(0.1)
	check(screen._phone._chat_draft.visible_characters > 0 and screen._phone._chat_draft.visible_characters < screen._phone._chat_draft.text.length(), "John's draft visibly types before Send")
	screen._phone._send_chat()
	check(screen._phone._chat_history.is_empty(), "Send cannot bypass unfinished draft")
	screen._phone.stop()
	screen._phone._tick_chat(10.0)
	check(screen._phone._chat_history.is_empty(), "Stopped phone cannot deliver messages")
	screen.state = Chapter.fresh()
	screen._render()
	screen._advance()
	check(screen._sentence == 0 and screen._line.visible_characters == -1, "First tap reveals text without skipping a sentence")
	screen._advance()
	check(screen._sentence == 1, "Second tap starts the next sentence")
	screen._toggle_menu()
	var letters: int = screen._line.visible_characters
	await create_timer(0.2).timeout
	check(screen._line.visible_characters == letters, "Typing pauses with menu")
	screen._toggle_menu()
	screen._backgrounded = true
	screen._apply_pause()
	letters = screen._line.visible_characters
	await create_timer(0.15).timeout
	check(screen._line.visible_characters == letters, "Typing pauses when backgrounded")
	screen._backgrounded = false
	screen._apply_pause()
	var old_owner: String = auth._participant_code
	auth._participant_code = "chapter-test-other-account"
	screen._session_changed(false)
	check(not screen._active and not screen.visible, "Account switch cancels and hides chapter")
	auth._participant_code = old_owner
	screen.on_exit()
	screen.queue_free()
	await settle()
	player.apply_save_data(original)
	print("Chapter 1 verification: %d failures" % failures)
	quit(1 if failures else 0)
