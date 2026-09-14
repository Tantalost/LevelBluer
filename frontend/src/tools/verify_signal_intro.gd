extends SceneTree
## Intro-only checks: never starts loading, navigation, downloads or player writes.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 6:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/signal_intro_" + label + ".png")

func _run() -> void:
	var player := root.get_node("PlayerManager")
	var before := JSON.stringify([player.credits, player.lesson_progress, player.cleared_stages])
	var screen: Control = load("res://src/ui/screens/intro/intro_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	screen.set_process(false)
	await settle()
	check(screen.REVEAL_SECONDS <= 2, "Intro duration capped at two seconds")
	check(screen._start_button.disabled, "Start is gated only during reveal")
	check(not screen._skip_button.disabled, "Immediate Skip available")
	for seconds in [0.0, 0.55, 0.95, 1.35, 1.8]:
		screen._apply_time(seconds)
		if seconds == screen.REVEAL_SECONDS:
			screen._finish_reveal()
		await settle()
		await capture(str(seconds).replace(".", "_"))
	screen._skip_button.pressed.emit()
	check(screen._ready_for_start and not screen._start_button.disabled, "Skip reveals usable title without navigating")
	check(not screen.is_processing(), "Animation processing stops at title")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		if dimensions.x == 844:
			for child in screen.get_children():
				if child is SafeAreaContainer:
					var units := 1.0 / root.get_final_transform().get_scale().x
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units))
			await settle()
		check(root.get_visible_rect().encloses(screen._start_button.get_global_rect()), "Start visible on compact landscape")
		check(root.get_visible_rect().encloses(screen._art.get_global_rect()), "Art fits safe viewport")
		check(root.get_visible_rect().encloses(screen._wordmark.get_global_rect()), "Title fits viewport")
		check(screen._start_button.size.y * root.get_final_transform().get_scale().y >= 47.9, "Start has 48px physical touch target")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
	screen.on_exit()
	check(not screen.is_processing(), "Exit stops animation")
	screen.on_enter({})
	check(screen._skip_button.modulate.a == 1 and not screen._skip_button.disabled, "Re-entry resets Skip")
	var start := Time.get_ticks_msec()
	while not screen._ready_for_start and Time.get_ticks_msec() - start < 2500:
		await process_frame
	var elapsed := Time.get_ticks_msec() - start
	check(screen._ready_for_start and elapsed <= 2000, "Real-time title ready within two seconds: %dms" % elapsed)
	print("INTRO_READY_MS=" + str(elapsed))
	screen.on_enter({})
	# Low FPS/app suspension: advance wall clock, not delta integration.
	screen._started_usec = Time.get_ticks_usec() - 2100000
	screen._process(0.01)
	check(screen._ready_for_start, "Slow frame does not prolong animation")
	screen.on_exit()
	screen._finish_reveal()
	check(not screen.is_processing(), "No delayed callbacks restart exited screen")
	check(before == JSON.stringify([player.credits, player.lesson_progress, player.cleared_stages]), "Intro does not mutate player data")
	screen.queue_free()
	await settle()
	print("SIGNAL_INTRO_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
