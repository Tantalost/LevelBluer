extends SceneTree
## Read-only screen verification using in-memory account fixtures.
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
		root.get_texture().get_image().save_png("res://.godot/module_select_" + label + ".png")

func fingerprint(player: Node, auth: Node) -> String:
	return JSON.stringify([player.lesson_progress, player.completed_lessons, player.cleared_stages,
		player.credits, auth._mastery, auth._points])

func _run() -> void:
	var player := root.get_node("PlayerManager")
	var auth := root.get_node("AuthService")
	auth._signed_in = false
	auth._points = 1250
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.cleared_stages = {}
	player.credits = 229
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
	player.cleared_stages = {1: true, 3: true}
	screen.on_resume()
	await settle()
	check(screen._is_unlocked(0) and screen._is_unlocked(1), "Existing first/second module rules preserved")
	check(not screen._is_unlocked(2), "Partial previous lessons do not unlock next module")
	check(not screen._breach_button.disabled, "Open CTA enabled for available operation")
	check(screen._module_route(0).route == &"module_intro", "First module keeps introduction route")
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
	print("MODULE_SELECT_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
