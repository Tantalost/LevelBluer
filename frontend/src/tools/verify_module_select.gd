extends SceneTree
## Read-only screen verification using in-memory account fixtures.
var failures: int = 0
var intro_checks_finished: bool = false
var intro_fixture: Control
var fixture_focus: bool = true

func _process(_delta: float) -> bool:
	# The human may use another window while rendered checks run.
	# Disable this override around explicit focus-loss assertions below.
	if fixture_focus and is_instance_valid(intro_fixture) and intro_fixture.is_node_ready() and intro_fixture._focus_lost:
		intro_fixture._focus_lost = false
		intro_fixture._apply_pause()
	return false

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 10:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/module_select_" + label + ".png")

func fingerprint(player: Node, auth: Node) -> String:
	return JSON.stringify([player.lesson_progress, player.completed_lessons, player.cleared_stages,
		player.credits, auth._mastery, auth._points])

func _run() -> void:
	var assets: Node = root.get_node("AssetManager")
	if "--sync-chapter-covers" in OS.get_cmdline_user_args():
		for entry: Dictionary in assets._school_story_catalog():
			if str(entry.asset_id) in ["story_chapter3_cover", "story_chapter4_cover"]:
				check(await assets._sync_entry(entry), "Hosted chapter cover downloads: " + str(entry.asset_id))
				assets._textures.erase(str(entry.asset_id))
				check(assets.get_texture(str(entry.asset_id)) != null, "Cover reloads from disk cache")
	var player := root.get_node("PlayerManager")
	var auth := root.get_node("AuthService")
	auth._signed_in = false
	auth._points = 1250
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.cleared_stages = {}
	player.credits = 229
	player.seen_module_intros.clear()
	player.chapter_progress = {}
	var screen: Control = load("res://src/ui/screens/deploy/stage_select_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	await settle()
	check(screen._cards.size() == 5, "All five modules shown")
	check(screen.get_node("CRTOverlay").visible, "Permanent subtle CRT")
	check(screen._breach_button.disabled, "Fresh account cannot deploy")
	check(screen._lock_reason(0).contains("Module 1"), "First operation explains lesson prerequisite")
	var before := fingerprint(player, auth)
	for i in 5:
		screen._cards[i].pressed.emit()
		await settle()
		check(screen._selected == i, "Locked module %d selectable for explanation" % i)
		check(screen._breach_button.disabled, "Locked CTA remains disabled")
	screen._preview_module(0)
	await settle()
	await capture("locked_1280")
	check(fingerprint(player, auth) == before, "Viewing all modules does not change account")
	player.lesson_progress = {"mod_01": 6, "mod_02": 3}
	player.completed_lessons.assign(["mod_01"])
	player.cleared_stages = {"mod_01:1": true, "mod_01:3": true}
	screen.on_resume()
	await settle()
	check(screen._is_unlocked(0) and screen._is_unlocked(1), "Modules open after their own first lesson")
	player.lesson_progress["mod_02"] = 0
	check(not screen._is_unlocked(1), "Completed Module 1 alone cannot open Module 2")
	player.lesson_progress["mod_02"] = 1
	check(screen._is_unlocked(1), "Module 2 Lesson 1 opens Module 2")
	check(not screen._is_unlocked(2), "Partial previous lessons do not unlock next module")
	check(not screen._breach_button.disabled, "Open CTA enabled for available operation")
	check(screen._module_route(0).route == &"module_intro", "First module keeps introduction route")
	player.seen_module_intros.append("mod_01")
	check(screen._module_route(0).route == &"module_stages" and screen._module_route(0).args.chapters, "Seen intro goes directly to chapter selection")
	var intro_save: Dictionary = player.get_save_data()
	player.seen_module_intros.clear()
	player.apply_save_data(intro_save)
	check(screen._module_route(0).route == &"module_stages", "Seen intro survives save reload")
	player.seen_module_intros.clear()
	player.chapter_progress = {"mod_01_ch_01": {"beat":4}}
	check(screen._module_route(0).route == &"module_stages", "Existing chapter progress skips intro for older saves")
	player.chapter_progress = {}
	var chapters: Control = load("res://src/ui/screens/deploy/module_stage_screen.tscn").instantiate()
	root.add_child(chapters)
	chapters.on_enter({"module_index":0, "chapters":true})
	await settle()
	check(chapters._rows.size() == 5 and chapters._title.text == "CHAPTER\nSELECT", "Module 1 has five story chapters, not ten legacy stages")
	check(not chapters._breach_button.disabled, "First chapter can start")
	check(chapters._rows[0].find_child("CompletionBadge", true, false) == null, "Fresh chapter has no completion badge")
	check(chapters._chapter_preview.chapter == 1 and not chapters._chapter_preview.sealed, "Fresh chapter preview reflects progress")
	check(chapters._intro_button.autowrap_mode == TextServer.AUTOWRAP_OFF, "Replay intro stays on one line")
	for state_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var chapter_style: StyleBoxFlat = chapters._breach_button.get_theme_stylebox(state_name) as StyleBoxFlat
		var module_style: StyleBoxFlat = screen._breach_button.get_theme_stylebox(state_name) as StyleBoxFlat
		check(chapter_style.bg_color == module_style.bg_color and chapter_style.border_color == module_style.border_color and chapter_style.corner_radius_top_left == module_style.corner_radius_top_left, "Chapter action matches Deploy theme: " + state_name)
	check(chapters._breach_button.get_theme_color("font_color") == screen._breach_button.get_theme_color("font_color"), "Mint chapter action uses Deploy's dark text")
	var chapter_card: StyleBoxFlat = chapters._rows[0].get_theme_stylebox("normal") as StyleBoxFlat
	var module_card: StyleBoxFlat = screen._cards[0].get_theme_stylebox("normal") as StyleBoxFlat
	check(chapter_card.bg_color == module_card.bg_color and chapter_card.border_color == module_card.border_color and chapter_card.corner_radius_top_left == 0, "Chapter cards match the selected Deploy card surface")
	await capture("chapters_1280")
	root.size = Vector2i(844,390)
	await settle()
	await capture("chapters_844")
	check(chapters._breach_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Chapter launch button fits mobile viewport")
	check(chapters._intro_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Replay intro fits mobile viewport")
	check(chapters._settings.get_global_rect().end.x <= root.get_visible_rect().end.x, "Chapter header fits mobile viewport")
	check(chapters._rows[0].size.y * root.get_final_transform().get_scale().y >= 48, "Chapter cards retain mobile touch targets")
	root.size = Vector2i(1280,720)
	await settle()
	chapters._select_chapter(1)
	check(chapters._breach_button.disabled, "Chapter 2 requires Chapter 1 completion")
	await settle()
	await capture("chapters_pending")
	check(chapters._chapter_preview.chapter == 2, "Pending selection updates preview")
	player.chapter_progress = {"mod_01_ch_01": {"beat":4}}
	chapters._select_chapter(0)
	check(chapters._breach_button.text == "CONTINUE", "Started chapter has Continue action")
	player.chapter_progress = {"mod_01_ch_01": {"completed":true}}
	chapters.on_resume()
	await settle()
	check(chapters._chapter_preview.sealed and chapters._breach_button.text == "REPLAY", "Completed chapter has sealed preview and Replay action")
	check(chapters._completion.value == 1, "Completion progress counts sealed chapter")
	chapters._select_chapter(1)
	check(not chapters._breach_button.disabled and chapters._breach_button.text == "START", "Chapter 2 unlocks after sealing Chapter 1")
	check(chapters._chapter_preview.artwork == root.get_node("AssetManager").get_texture("story_chapter2_cover"), "Chapter 2 uses its own cover")
	chapters._chapter_preview.artwork = null
	chapters._chapter_art_ready(true)
	check(chapters._chapter_preview.artwork == root.get_node("AssetManager").get_texture("story_chapter2_cover"), "Late sync preserves selected Chapter 2 artwork")
	await settle()
	await capture("chapter2_cover")
	chapters._select_chapter(2)
	check(chapters._breach_button.disabled, "Chapter 3 remains unavailable")
	for index: int in [2,3]:
		chapters._select_chapter(index)
		var cover_id: String = "story_chapter%d_cover" % (index+1)
		check(chapters._chapter_preview.artwork == assets.get_texture(cover_id), "Selected chapter uses its own cover: " + cover_id)
		chapters._chapter_preview.artwork = null
		chapters._chapter_art_ready(true)
		check(chapters._chapter_preview.artwork == assets.get_texture(cover_id), "Late sync restores the selected cover: " + cover_id)
		await settle()
		await capture("chapter%d_cover" % (index+1))
	chapters._select_chapter(0)
	await capture("chapters_complete")
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		var badge: Label = chapters._rows[0].find_child("CompletionBadge", true, false) as Label
		check(badge != null and badge.text == "COMPLETED", "Completed chapter has an explicit right-side badge")
		if badge != null:
			check(chapters._rows[0].get_global_rect().encloses(badge.get_global_rect()), "Completion badge fits inside card")
			var copy: Control = badge.get_parent().get_child(1) as Control
			check(copy.get_global_rect().end.x <= badge.get_global_rect().position.x, "Completion badge does not overlap chapter copy")
		check(chapters._rows[0].accessibility_name.contains("Completed"), "Completion is announced without relying on color")
		var complete_style: StyleBoxFlat = chapters._rows[0].get_theme_stylebox("normal") as StyleBoxFlat
		check(complete_style.bg_color == chapters.COMPLETED_SELECTED_FILL, "Selected completed chapter uses green surface")
		await capture("chapters_complete_%d" % dimensions.x)
	chapters._select_chapter(1)
	var unselected_complete: StyleBoxFlat = chapters._rows[0].get_theme_stylebox("normal") as StyleBoxFlat
	check(unselected_complete.bg_color == chapters.COMPLETED_FILL, "Completed chapter stays green when another chapter is selected")
	check(chapters._rows[1].find_child("CompletionBadge", true, false) == null, "Coming Soon chapter never displays completion badge")
	root.size = Vector2i(1280,720)
	chapters._select_chapter(0)
	await settle()
	chapters._chapter_preview.artwork = null
	chapters._chapter_preview.queue_redraw()
	await settle()
	check(not chapters._breach_button.disabled, "Missing cached art does not prevent chapter launch")
	await capture("chapters_fallback")
	chapters._chapter_art_ready(true)
	check(chapters._chapter_preview.artwork == root.get_node("AssetManager").get_texture("story_bg_john_desk_night"), "Late artwork sync refreshes preview without resetting progress")
	var chapter_settings: Node = root.get_node("SettingsService")
	var chapter_motion: bool = chapter_settings.reduced_motion
	chapter_settings.reduced_motion = true
	chapters._select_chapter(4)
	check(is_equal_approx(chapters._detail.modulate.a, 1.0), "Reduced motion keeps chapter preview fully readable")
	await settle()
	check(chapters._rows[4].has_focus(), "Last chapter remains focusable and scrolls into view")
	chapter_settings.reduced_motion = chapter_motion
	player.chapter_progress = {}
	chapters.on_exit()
	chapters.queue_free()
	await settle()
	check(screen._module_route(4).route == &"module_stages", "Other modules keep stage route")
	check(screen._module_route(4).args.module_index == 4, "Route module index preserved")
	await capture("available_1280")
	screen._preview_module(1)
	await settle()
	await capture("coming_soon")
	screen._preview_module(0)
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		if dimensions.x == 844:
			var units_per_pixel := 1.0 / root.get_final_transform().get_scale().x
			for child in screen.get_children():
				if child is SafeAreaContainer:
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units_per_pixel))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units_per_pixel))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units_per_pixel))
			await settle()
		check(screen._body.get_global_rect().end.x <= screen.size.x, "Body fits viewport")
		check(screen._title.get_global_rect().end.x <= screen.size.x, "Header fits viewport")
		var physical_scale := root.get_final_transform().get_scale().y
		check(screen._back.size.y * physical_scale >= 47, "Back touch target >=48 physical pixels")
		check(screen._settings.size.y * physical_scale >= 47, "Settings touch target >=48 physical pixels")
		check(screen._breach_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Open action always visible")
		check(screen._breach_button.size.y * physical_scale >= 47, "Open action touch target")
		check(screen._settings.get_global_rect().end.x <= root.get_visible_rect().end.x, "Header action fits safe area")
		for card in screen._cards:
			check(card.size.y * physical_scale >= 47, "Module card touch target")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
	player.lesson_progress.clear()
	player.completed_lessons.clear()
	auth.session_changed.emit(false)
	await settle()
	check(screen._selected == 0 and screen._breach_button.disabled, "Account change clears selected/access presentation")
	screen.on_exit()
	check(not screen.visible, "Exit hides screen")
	screen.on_resume()
	await settle()
	check(screen.visible, "Resume restores screen")
	screen.queue_free()
	await settle()
	await check_intro(player, auth)
	check(intro_checks_finished, "Intro checks reached completion")
	print("MODULE_SELECT_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)

func check_intro(player: Node, auth: Node) -> void:
	var assets: Node = root.get_node("AssetManager")
	if "--download-art" in OS.get_cmdline_user_args():
		for entry: Dictionary in assets._ui_catalog():
			if str(entry.asset_id) in ["module1_email_tricks_title_v1", "opening_five_victims_john_v4"]:
				check(await assets._download_and_store(entry), "New cinematic art downloads and caches")
	var settings: Node = root.get_node("SettingsService")
	var previous_motion: bool = settings.reduced_motion
	var previous_speed: String = settings.text_speed
	settings.reduced_motion = false
	settings.text_speed = "normal"
	root.size = Vector2i(1280, 720)
	var intro: Control = load("res://src/ui/screens/deploy/module_intro_screen.tscn").instantiate()
	intro_fixture = intro
	root.add_child(intro)
	var before: String = fingerprint(player, auth)
	var seen_before: String = JSON.stringify(player.seen_module_intros)
	intro.on_enter({"module_index": 0})
	await settle()
	check(intro._skip_button.visible, "First-time readers can skip to title card")
	check(intro._index == 0 and not intro._ending, "Intro begins with John's email")
	intro._advance()
	check(intro._index == 0 and intro._dialogue_text.visible_characters == -1, "First tap reveals line without skipping it")
	intro._last_advance = -1000
	intro._advance()
	check(intro._index == 1, "Next tap advances exactly one beat")
	fixture_focus = false
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var characters: int = intro._dialogue_text.visible_characters
	await create_timer(0.2).timeout
	intro._last_advance = -1000
	intro._advance()
	check(intro._index == 1 and intro._dialogue_text.visible_characters == characters, "Focus loss freezes typing and input")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	fixture_focus = true
	settings.reduced_motion = true
	intro._settings_changed()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		for beat: int in [0, 2, 7]:
			intro._index = beat
			intro._show_beat()
			await settle()
			var dialog_bounds: Rect2 = intro._dialogue.get_global_rect()
			check(dialog_bounds.end.y <= intro.size.y + 1, "Narration fits viewport at beat %d / %d" % [beat, dimensions.x])
			if intro._item.visible:
				check(intro._item.get_global_rect().end.y <= dialog_bounds.position.y, "Item stays above narration at beat %d / %d" % [beat, dimensions.x])
				check(intro._item.position.x < intro.size.x * 0.1 and intro._item.size.x < intro.size.x * 0.45, "Email evidence stays compact on the left")
			check(intro._advance_button.size.y * root.get_final_transform().get_scale().y >= 47, "Intro advance has a mobile touch target")
			await capture("intro_%d_%d" % [dimensions.x, beat])
		for beat: int in [3, 4, 5, 6, 8]:
			intro._index = beat
			intro._show_beat()
			await create_timer(0.45).timeout
			check(intro._caption.visible and not intro._dialogue.visible and not intro._item.visible, "Thought captions hide narration and explanation cards")
			check(intro._caption.text == str(intro.BEATS[beat]["line"]), "Only the current thought appears")
			await capture("intro_%d_thought_%d" % [dimensions.x, beat])
		intro._last_advance = -1000
		intro._advance()
		check(intro._ending, "Final line leads to title card")
		await create_timer(0.4).timeout
		check(not intro._start_button.disabled, "Title card offers Continue after reveal")
		check(intro._chapter_label.text == "MODULE 1" and intro._ending_title.text == "Email Tricks", "Requested title card wording")
		check(intro._start_button.get_global_rect().end.y <= intro.size.y + 1, "Title card Continue fits viewport")
		await capture("intro_title_%d" % dimensions.x)
		intro._restart()
		check(intro._index == 0 and not intro._ending, "Replay resets narrative")
	intro._index = 3
	intro._show_beat()
	await create_timer(2.9).timeout
	check(intro._index == 4, "Centered thought fades out and advances automatically")
	intro._skip()
	await create_timer(3.0).timeout
	check(intro._ending and not intro._caption.visible, "Skipped thought cannot resume its abandoned sequence")
	intro._restart()
	settings.reduced_motion = false
	intro._skip()
	check(intro._ending, "Skip still presents module title")
	check(intro._start_button.disabled, "Normal-motion title waits for artwork reveal")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	var reveal: float = intro._art.reveal
	await create_timer(0.2).timeout
	check(is_equal_approx(intro._art.reveal, reveal), "App suspension pauses title reveal")
	intro._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(1.1).timeout
	check(not intro._start_button.disabled and is_equal_approx(intro._art.reveal, 1.0), "Normal-motion title finishes after resume")
	intro.on_exit()
	check(not intro.visible and intro._motion == null and intro._typing == null, "Exit cancels owned animations")
	intro.on_resume()
	check(intro.visible and not intro._start_button.disabled, "Resuming title cannot strand Continue")
	check(fingerprint(player, auth) == before and JSON.stringify(player.seen_module_intros) == seen_before, "Reading, skipping and replaying never award progress or write seen status")
	intro.free()
	settings.reduced_motion = previous_motion
	settings.text_speed = previous_speed
	intro_checks_finished = true
