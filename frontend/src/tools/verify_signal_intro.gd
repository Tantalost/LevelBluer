extends SceneTree
## Intro/title integration only. No Start press, downloads, or saved player writes.
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
	var assets := root.get_node("AssetManager")
	# Isolated in-memory fixtures only when artwork is not already cached.
	for id in ["ui_intro_preview", "ui_logo"]:
		if assets.get_texture(id) == null:
			print("TEST_TEXTURE_FIXTURE=" + id)
			assets._textures[id] = load("res://assets/ui/logo.png" if id == "ui_logo" else "res://assets/ui/background.png")
	var screen: Control = load("res://src/ui/screens/intro/intro_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	var cinematic: Control = screen._cinematic
	cinematic.set_process(false)
	await settle()
	check(cinematic.DURATION <= 2.0, "Intro duration capped")
	check(screen._start_button.disabled and not screen._cta_layer.visible, "Original Start hidden during intro")
	check(not cinematic._skip.disabled, "Skip immediately available")
	check(cinematic.find_children("*", "Button", true, false).size() == 1, "Intro contains Skip only, not a title/Start button")
	for seconds in [0.0, 0.55, 0.95, 1.35]:
		cinematic._art.timeline = seconds
		await settle()
		await capture(str(seconds).replace(".", "_"))
	cinematic._skip.pressed.emit()
	check(not cinematic.visible and not cinematic.is_processing(), "Skip closes intro")
	check(screen._cta_layer.visible and not screen._start_button.disabled, "Skip reveals original Start")
	check(screen._logo.texture == assets.get_texture("ui_logo"), "Original logo texture restored")
	check(screen._art.texture == assets.get_texture("ui_intro_preview"), "Original preview background restored")
	check(screen._start_button.custom_minimum_size == Vector2(340, 60), "Original button geometry preserved")
	check(screen._logo_layer.custom_minimum_size == Vector2(960, 320), "Original logo layout preserved")
	check(screen._start_button.get_theme_stylebox("normal").border_color.is_equal_approx(Color(0.180392, 0.419608, 1, 1)), "Original blue button style preserved")
	await settle()
	await capture("original_title")
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		screen.on_enter({})
		cinematic.set_process(false)
		await settle()
		if dimensions.x == 844:
			for child in cinematic.get_children():
				if child is SafeAreaContainer:
					var units := 1.0 / root.get_final_transform().get_scale().x
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units))
			await settle()
		cinematic._art.timeline = 0.95
		check(root.get_visible_rect().encloses(cinematic._art.get_global_rect()), "Intro art fits compact landscape")
		check(root.get_visible_rect().encloses(cinematic._caption.get_global_rect()), "Caption fits compact landscape")
		check(cinematic._skip.size.y * root.get_final_transform().get_scale().y >= 47.9, "Skip has 48px physical touch target")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
		cinematic._skip.pressed.emit()
		await settle()
		check(root.get_visible_rect().encloses(screen._start_button.get_global_rect()), "Restored title button fits viewport")
		await capture("title_%dx%d" % [dimensions.x, dimensions.y])
	screen.on_enter({})
	var started := Time.get_ticks_msec()
	while cinematic._playing and Time.get_ticks_msec() - started < 2500:
		await process_frame
	var elapsed := Time.get_ticks_msec() - started
	check(not cinematic.visible and not screen._start_button.disabled and elapsed <= 2000, "Automatic handoff within two seconds")
	print("INTRO_HANDOFF_MS=" + str(elapsed))
	screen.on_enter({})
	cinematic._started_usec = Time.get_ticks_usec() - 2100000
	cinematic._process(0.01)
	check(not cinematic.visible, "Slow frame completes intro immediately")
	screen.on_enter({})
	screen.on_exit()
	cinematic._finish()
	check(not cinematic.is_processing() and screen._start_button.disabled, "Exit cancels handoff")
	screen.on_resume()
	check(not cinematic.visible and not screen._start_button.disabled, "Resume returns to existing title without replay")
	check(before == JSON.stringify([player.credits, player.lesson_progress, player.cleared_stages]), "Player data unchanged")
	screen.on_exit()
	screen.queue_free()
	await settle()
	print("SIGNAL_INTRO_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)
