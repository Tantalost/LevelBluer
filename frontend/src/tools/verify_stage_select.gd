extends SceneTree
## In-memory fixtures; no gameplay launch, backend writes, or save calls.
var failures := 0

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
		root.get_texture().get_image().save_png("res://.godot/stage_select_" + label + ".png")

func fingerprint(p: Node, a: Node) -> String:
	return str([p.lesson_progress, p.completed_lessons, p.cleared_stages, p.locked_stages, p.mock_max_stage_cleared, p.credits, a._mastery, a._points])

func _run() -> void:
	var p := root.get_node("PlayerManager")
	var a := root.get_node("AuthService")
	var stages := root.get_node("StageManager")
	p.lesson_progress = {}
	p.completed_lessons.clear()
	p.cleared_stages = {}
	p.locked_stages = {}
	p.credits = 229
	p.mock_max_stage_cleared = 1
	var screen: Control = load("res://src/ui/screens/deploy/module_stage_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({"module_index": 0})
	await settle()
	check(screen._rows.size() == 10 and screen._authored_count() == 10, "Ten authored Module 1 stages")
	check(screen.get_node("CRTOverlay").visible, "Shared permanent CRT")
	check(screen._breach_button.disabled, "Fresh user gated by lessons")
	check(screen._lock_reason(0).contains("lessons"), "Lesson gate explained")
	check(screen._cleared_count() == 0, "Mock progression not counted as stage clears")
	check(screen._rows[1].get_theme_stylebox("normal").bg_color != screen.COMPLETED_FILL, "Uncleared stage has no completion tint")
	var before := fingerprint(p, a)
	var teasers := {}
	for i in 10:
		screen._rows[i].pressed.emit()
		await settle()
		check(screen._selected == i, "All locked stages can be inspected")
		check(screen._breach_button.disabled, "Locked inspection cannot enable launch")
		var teaser: String = screen._teaser_label.text
		check(not teaser.is_empty() and teaser.split(" ", false).size() <= 35, "Stage overview is short")
		check(not teasers.has(teaser), "Every authored stage has a distinct briefing")
		teasers[teaser] = true
		check(not teaser.to_lower().contains("boss"), "Briefing does not reveal encounter lineup")
	check(fingerprint(p, a) == before, "Selection does not mutate account")
	screen._select_stage(0)
	await settle()
	await capture("fresh_1280")
	p.lesson_progress = {"mod_01": 6}
	p.completed_lessons.assign(["mod_01", "mod1_all"])
	p.mock_max_stage_cleared = 3
	p.cleared_stages = {1: true, 3: true}
	screen.on_resume()
	await settle()
	check(screen._cleared_count() == 2, "Counts explicit clears, not highest stage")
	check(screen._rows[0].get_theme_stylebox("normal").bg_color == screen.COMPLETED_SELECTED_FILL, "Selected completed stage stays green")
	check(screen._rows[2].get_theme_stylebox("normal").bg_color == screen.COMPLETED_FILL, "Unselected completed stage is green")
	check(screen._rows[1].get_theme_stylebox("normal").bg_color != screen.COMPLETED_FILL, "Available but uncleared stage stays neutral")
	check(screen._rows[0].get_theme_stylebox("hover").bg_color.g > screen._rows[0].get_theme_stylebox("hover").bg_color.b, "Completed hover remains green")
	check(screen._status(0).begins_with("COMPLETED"), "Completed stages marked")
	check(screen._breach_button.text.begins_with("REPLAY") and not screen._breach_button.disabled, "Replay enabled for cleared mission")
	for i in 10:
		check(screen._is_unlocked(i) == stages.access_reason(i + 1, "mod_01").is_empty(), "Existing stage access preserved")
		check(screen._launch_index(i) == i, "Zero-based gameplay route index preserved")
	screen._select_stage(2)
	await settle()
	await capture("partial_1280")
	screen._select_stage(9)
	await settle()
	check(screen._lock_reason(9).contains("preceding"), "Sequential gate explained")
	await capture("locked_1280")
	p.locked_stages = {1: true}
	screen._select_stage(0)
	await settle()
	check(screen._lock_reason(0).contains("exam") and screen._breach_button.disabled, "Exam lock still prevents replay")
	check(screen._rows[0].get_theme_stylebox("normal").bg_color == screen.COMPLETED_SELECTED_FILL, "Exam lock does not erase completion tint")
	p.locked_stages.clear()
	screen._select_stage(0)
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		if dimensions.x == 844:
			var units := 1.0 / root.get_final_transform().get_scale().x
			for child in screen.get_children():
				if child is SafeAreaContainer:
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units))
			await settle()
		for control in [screen._body, screen._settings, screen._breach_button]:
			check(root.get_visible_rect().encloses(control.get_global_rect()), "Body and pinned actions fit viewport")
		check(screen._profile.get_parent() == screen._header and screen._settings.get_parent() == screen._header, "Profile and navigation share one header")
		check(screen._body.position.y <= screen._header.position.y + screen._header.size.y + 24, "No separate account band consumes content height")
		check(root.get_visible_rect().encloses(screen._profile.get_global_rect()), "Compact profile remains visible")
		check(root.get_visible_rect().encloses(screen._wallet.get_global_rect()), "Wallet remains visible")
		for button in [screen._back, screen._breach_button, screen._settings]:
			check(button.size.y * root.get_final_transform().get_scale().y >= 47, "48px physical touch target")
		check((screen._stage_list.get_parent() as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "No horizontal scrolling required")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
		var original_name: String = a._display_name
		a._display_name = "COMMANDER_WITH_A_VERY_LONG_DISPLAY_NAME"
		screen._refresh_all()
		await settle()
		check(root.get_visible_rect().encloses(screen._settings.get_global_rect()), "Long player name cannot push settings off screen")
		check(screen._profile_name.size.x < screen._profile.size.x, "Long name stays inside profile button")
		a._display_name = original_name
		screen._refresh_all()
		await settle()
		var scroll := screen._stage_list.get_parent() as ScrollContainer
		scroll.scroll_vertical = 99999
		await settle()
		check(scroll.get_global_rect().intersects(screen._rows[9].get_global_rect()), "Last stage reachable by vertical scrolling")
	p.mock_max_stage_cleared = 10
	for i in range(1, 11):
		p.cleared_stages[i] = true
	screen.on_resume()
	await settle()
	check(screen._completion.value == 10 and screen._cleared_count() == 10, "Full completion shown")
	screen.on_enter({"module_index": 1})
	await settle()
	check(screen._authored_count() == 10, "Ten authored Module 2 stages")
	for i in 10:
		check(screen._launch_index(i) == i, "Module 2 uses the same zero-based gameplay route index")
	screen.on_enter({"module_index": 2})
	await settle()
	check(screen._authored_count() == 10, "Ten authored Module 3 stages")
	for i in 10:
		check(screen._launch_index(i) == i, "Module 3 uses the same zero-based gameplay route index")
	screen.on_enter({"module_index": 3})
	await settle()
	check(screen._authored_count() == 10, "Ten authored Module 4 stages")
	for i in 10:
		check(screen._launch_index(i) == i, "Module 4 uses the same zero-based gameplay route index")
	screen.on_enter({"module_index": 4})
	await settle()
	check(screen._authored_count() == 10, "Ten authored Module 5 stages")
	for i in 10:
		check(screen._launch_index(i) == i, "Module 5 uses the same zero-based gameplay route index")
	await capture("all_authored")
	screen.on_enter({"module_index": 0})
	p.lesson_progress.clear()
	p.completed_lessons.clear()
	a.session_changed.emit(false)
	await settle()
	check(screen._selected == 0 and screen._breach_button.disabled, "Account change refreshes prerequisites")
	screen.on_exit()
	check(not screen.visible and not screen.is_processing(), "Exit stops refresh polling")
	screen.on_resume()
	await settle()
	check(screen.visible, "Resume restores screen")
	screen.on_exit()
	screen.queue_free()
	await settle()
	print("STAGE_SELECT_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
