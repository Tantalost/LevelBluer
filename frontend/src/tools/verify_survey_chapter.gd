extends SceneTree
const Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
var failures: int = 0
var screen: Control

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i: int in 8: await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
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
	# Read-only local art fixtures: runtime continues to use Cloudinary/cache only.
	var assets: Node = root.get_node("AssetManager")
	if "--download-art" in OS.get_cmdline_user_args():
		for entry: Dictionary in assets._school_story_catalog():
			if str(entry.asset_id).begins_with("chapter1_"):
				check(await assets._download_and_store(entry), "Character sprite downloads into cache")
	for person: String in ["john","eric","jobert"]:
		if "--download-art" in OS.get_cmdline_user_args(): continue
		var path: String = ProjectSettings.globalize_path("res://../output/imagegen/chapter1/" + person + "_expressions_v1.png")
		var image: Image = Image.load_from_file(path)
		if image != null: assets._textures["chapter1_" + person] = ImageTexture.create_from_image(image)
	screen = load("res://src/ui/screens/deploy/survey_chapter_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"test":true})
	await settle()
	await capture("day")
	await click(screen._advance_button)
	check(screen.state.beat == 1, "Real pointer advances dialogue")
	for i: int in 3: screen._advance()
	await settle()
	check(screen._phone.mode == "chat", "Club chat uses phone")
	await capture("chat")
	for i: int in 7: screen._advance()
	check(screen.state.beat == 11, "Afternoon inbox")
	screen._advance()
	check(screen.state.beat == 11, "Unread messages block story advance")
	for entry: Dictionary in Chapter.MESSAGES:
		screen._phone._select(entry.id)
		screen._phone.acknowledge()
	screen._phone._finish_phase()
	screen._advance()
	check(screen.state.phase == "sort", "Night begins after reading six messages")
	screen._toggle_menu()
	screen._phone.sort_message("survey",true)
	check(screen.state.sorted.is_empty(), "Paused phone cannot change evidence")
	screen._toggle_menu()
	screen._phone.sort_message("survey",false)
	check(screen.state.mistakes == 1 and screen.state.sorted.is_empty(), "Incorrect sorting retries without awarding evidence")
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
		screen._phone._notes_home()
		screen._phone._open_notes()
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
	for id: String in Chapter.suspicious_ids():
		screen._phone._select(id)
		screen._phone._camera.frame = Rect2(0.02,0.02,0.96,0.96)
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
	screen._advance()
	check(screen.state.phase == "done", "Chapter completes")
	check(screen.state.next_chapter_unlocked, "Next chapter access earned without publishing unfinished content")
	check(player.credits == 150, "One base reward with no clean bonus after mistake")
	screen._save()
	check(player.credits == 150, "Repeat save cannot award twice")
	check(JSON.stringify([player.onboarding_state,player.mastery_matrix,player.cleared_stages]) == legacy, "Legacy progress and BKT unchanged")
	await settle()
	await capture("complete")
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
		await capture("investigate_" + str(dimensions.x))
	# Background/menu typing cannot silently advance; callbacks die on exit.
	settings.text_speed = "normal"
	settings.reduced_motion = false
	screen.state = Chapter.fresh()
	screen._render()
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
