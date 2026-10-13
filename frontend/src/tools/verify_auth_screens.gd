extends SceneTree
## Offline UI regression checks. Never signs in or submits a password.
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for frame: int in 6:
		await process_frame

func _run() -> void:
	var scene: PackedScene = load("res://src/ui/screens/login/login_screen.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var login: Control = scene.instantiate() as Control
	root.add_child(login)
	await settle()
	var modal: Control = login.get_node("PasswordChangeModal") as Control
	var email: LineEdit = login.get_node("%EmailField") as LineEdit
	var password: LineEdit = login.get_node("%PasswordField") as LineEdit
	login.call("_attempt_login")
	check((login.get_node("%ErrorPanel") as Control).visible, "Empty login validates without a request")
	login.call("_hide_error")
	login.call("_toggle_visibility")
	check(not password.secret, "Login reveal toggle works")
	login.call("_toggle_visibility")
	check(password.secret, "Login masks password again")
	login.call("_set_busy", true)
	check(not email.editable and (login.get_node("%TogglePassword") as Button).disabled, "Login is locked while busy")
	login.call("_set_busy", false)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		# Match the project's canvas_items scale on landscape phones.
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		await settle()
		for mode: String in ["login", "password"]:
			if mode == "password":
				modal.call("open")
			else:
				modal.call("close")
			await settle()
			var screen: Control = modal if mode == "password" else login
			var panel: Control = screen.get_node("SafeArea") as Control
			var card: Control = screen.get_node("%AuthCard") as Control
			var scroll: ScrollContainer = screen.get_node("%AuthScroll") as ScrollContainer
			check(card.size.x <= scroll.size.x + 1, "%s fits width at %s" % [mode, dimensions])
			check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "No horizontal scrolling")
			check(card.get_global_rect().position.x >= 0, "Card starts on screen")
			check(scroll.get_global_rect().encloses(card.get_global_rect()), "%s opens fully visible without keyboard at %s" % [mode, dimensions])
			var button: Button = screen.get_node("%SubmitButton" if mode == "password" else "%LoginButton") as Button
			check(button.size.y * root.get_final_transform().get_scale().y >= 47.9, "Touch target is at least 48 physical pixels")
			print("[AUTH] %s %s card=%s scroll=%s" % [mode, dimensions, card.get_global_rect(), scroll.get_global_rect()])
			if "--render" in OS.get_cmdline_user_args():
				await create_timer(0.3).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/auth_%s_%d.png" % [mode, dimensions.x])
			panel.set_process(false)
			panel.set("_keyboard_height", 170)
			panel.call("_layout")
			await settle()
			button.grab_focus()
			await settle()
			var visible_bottom: float = scroll.get_global_rect().end.y * root.get_final_transform().get_scale().y
			check(visible_bottom <= dimensions.y - 170 + 1, "Scroll viewport clears simulated keyboard")
			check(scroll.get_global_rect().encloses(button.get_global_rect()), "Submit can be scrolled into view above keyboard")
			panel.set("_keyboard_height", 0)
			panel.call("_layout")
			panel.set_process(true)
	modal.call("open")
	var new_password: LineEdit = modal.get_node("%NewPasswordField") as LineEdit
	var confirm: LineEdit = modal.get_node("%ConfirmPasswordField") as LineEdit
	new_password.text = "weak"
	confirm.text = "weak"
	modal.call("_attempt_change")
	check((modal.get_node("%ErrorPanel") as Control).visible and not bool(modal.get("_busy")), "Weak password is rejected locally")
	new_password.text = "UiOnlyExample9!"
	confirm.text = "different"
	modal.call("_attempt_change")
	check(not bool(modal.get("_busy")), "Mismatch is rejected locally")
	confirm.text = new_password.text
	modal.call("_refresh")
	check((modal.get_node("%MatchLabel") as Label).text == tr("PWD_MATCH"), "Matching passwords show confirmation")
	modal.call("_toggle_new_visibility")
	check(not new_password.secret, "Password setup reveal works")
	modal.call("_set_busy", true)
	check(not confirm.editable and (modal.get_node("%ToggleNewPassword") as Button).disabled, "Setup locks inputs while busy")
	modal.call("_set_busy", false)
	modal.call("close")
	check(new_password.text.is_empty() and confirm.text.is_empty() and new_password.secret, "Closing wipes and masks password fields")
	TranslationServer.set_locale("tl")
	modal.call("_apply_copy")
	modal.call("open")
	await settle()
	var translated_scroll: ScrollContainer = modal.get_node("%AuthScroll") as ScrollContainer
	check((modal.get_node("%AuthCard") as Control).size.x <= translated_scroll.size.x + 1, "Tagalog setup fits landscape width")
	TranslationServer.set_locale("en")
	login.queue_free()
	await settle()
	var standalone_scene: PackedScene = load("res://src/ui/screens/login/password_change_screen.tscn") as PackedScene
	var standalone: Control = standalone_scene.instantiate() as Control
	root.add_child(standalone)
	standalone.call("on_enter", {})
	await settle()
	check((standalone.get_node("PasswordChangeModal") as Control).visible, "Direct password-change route still opens the shared form")
	standalone.queue_free()
	await settle()
	print("[AUTH] failures=%d" % failures)
	quit(1 if failures else 0)
