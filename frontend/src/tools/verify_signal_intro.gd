extends SceneTree
## Intro/title integration only. No Start press, downloads, or saved player writes.
var failures: int = 0
var completions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in 8:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/signal_intro_" + label + ".png")

func record_completion() -> void:
	completions += 1

func _run() -> void:
	var player: Node = root.get_node("PlayerManager")
	var before: String = JSON.stringify(player.get_save_data())
	var assets: Node = root.get_node("AssetManager")
	# In-memory stand-ins keep title integration independent of network/cache state.
	for id: String in ["ui_intro_preview", "ui_logo"]:
		if assets.get_texture(id) == null:
			var fixture: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			fixture.fill(Color("#0A1730"))
			assets._textures[id] = ImageTexture.create_from_image(fixture)
	var screen: Control = load("res://src/ui/screens/intro/intro_screen.tscn").instantiate()
	root.add_child(screen)
	var disclaimer: Control = screen._cinematic
	disclaimer.finished.connect(record_completion)
	var expected: String = "LEVELBLUE is an academic project for educational and research purposes only and is not intended for commercial use. Third-party names, trademarks, and intellectual property belong to their respective owners. Any unintended similarities or associations are purely coincidental."
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		screen.on_enter({})
		check(disclaimer._stack.modulate.a == 0.0, "Intro begins on black")
		check(screen._start_button.disabled and not screen._cta_layer.visible, "Title is unavailable during disclaimer")
		check(disclaimer._continue.disabled, "Continue cannot bypass the initial fade")
		disclaimer._finish()
		check(disclaimer._playing, "Early input does not skip disclaimer")
		await create_timer(0.9).timeout
		await settle()
		if dimensions.x == 844:
			for child: Node in disclaimer.get_children():
				if child is SafeAreaContainer:
					var safe: SafeAreaContainer = child as SafeAreaContainer
					var units: float = 1.0 / root.get_final_transform().get_scale().x
					safe.add_theme_constant_override("margin_left", 28 + ceili(32 * units))
					safe.add_theme_constant_override("margin_right", 28 + ceili(24 * units))
					safe.add_theme_constant_override("margin_bottom", 28 + ceili(12 * units))
			await settle()
		check(disclaimer._caption.text == expected, "Disclaimer wording matches user text exactly")
		check(disclaimer._heading.text == "DISCLAIMER", "No trigger-warning heading")
		check(disclaimer.find_children("*", "Button", true, false).size() == 1, "Only Continue, no game-mode banner or Skip")
		for texture: Node in disclaimer.find_children("*", "TextureRect", true, false):
			# Godot 4.7 creates internal TextureRects for scroll-edge effects.
			check(texture.get_parent() == disclaimer._scroll, "No logo/art reveal outside native scroll decoration")
		check(root.get_visible_rect().encloses(disclaimer._heading.get_global_rect()), "Heading fits landscape")
		check(root.get_visible_rect().encloses(disclaimer._continue.get_global_rect()), "Continue fits landscape safe area")
		check(disclaimer._caption.size.y <= disclaimer._scroll.size.y + 1.0, "Entire disclaimer fits without scrolling at tested sizes")
		check(disclaimer._caption.get_theme_font_size("font_size") * root.get_final_transform().get_scale().y >= 20.0, "Body stays readable at 20 screen pixels")
		check(disclaimer._continue.size.y * root.get_final_transform().get_scale().y >= 47.9, "Continue has 48px touch target")
		await capture("disclaimer_%dx%d" % [dimensions.x, dimensions.y])
		await create_timer(1.3).timeout
		check(disclaimer.visible and disclaimer._playing and not disclaimer._continue.disabled, "No automatic advance after old intro timeout")
		var previous: int = completions
		disclaimer._continue.pressed.emit()
		disclaimer._continue.pressed.emit()
		check(disclaimer._continue.disabled, "Repeated Continue is blocked during exit fade")
		await create_timer(0.45).timeout
		check(completions == previous + 1, "Exactly one title handoff")
		check(not disclaimer.visible and not screen._start_button.disabled, "Continue returns to existing title")
		check(screen._logo.texture == assets.get_texture("ui_logo"), "Existing title logo preserved")
		check(screen._art.texture == assets.get_texture("ui_intro_preview"), "Existing title background preserved")
		await capture("title_%dx%d" % [dimensions.x, dimensions.y])
	# Stop during either fade must cancel navigation, including after reentry.
	var previous: int = completions
	screen.on_enter({})
	screen.on_exit()
	await create_timer(0.9).timeout
	check(completions == previous and not disclaimer._playing and disclaimer._continue.disabled, "Exit cancels fade-in")
	screen.on_enter({})
	await create_timer(0.9).timeout
	disclaimer._continue.pressed.emit()
	screen.on_exit()
	await create_timer(0.45).timeout
	check(completions == previous and screen._start_button.disabled, "Exit cancels pending title handoff")
	screen.on_resume()
	check(not disclaimer.visible and not screen._start_button.disabled, "Resume returns to title without replay")
	check(before == JSON.stringify(player.get_save_data()), "Intro never changes player data")
	screen.on_exit()
	screen.queue_free()
	await settle()
	print("DISCLAIMER_INTRO_CHECKS failures=%d" % failures)
	quit(0 if failures == 0 else 1)
