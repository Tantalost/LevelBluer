extends SceneTree
## Presentation-only accessibility checks. No settings file or player save writes.

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 3:
		await process_frame

func _run() -> void:
	var Workspace: GDScript = load("res://src/gameplay/decision/decision_workspace.gd")
	var InvestigationPanel: GDScript = load("res://src/gameplay/decision/decision_investigation_panel.gd")
	var ReconstructionPanel: GDScript = load("res://src/gameplay/decision/decision_reconstruction_panel.gd")
	var CallPanel: GDScript = load("res://src/gameplay/decision/decision_call_panel.gd")
	var settings: Node = root.get_node("SettingsService")
	var prior_speed: String = settings.text_speed
	var before: Dictionary = root.get_node("PlayerManager").get_save_data()
	var workspace: Control = Workspace.new()
	root.add_child(workspace)
	await settle()
	var expected: Dictionary = {"slow": 0.55, "normal": 1.0, "fast": 1.8}
	var emotional_line: Array[Dictionary] = [{"speaker": "Daniel", "text": "This is the same full sentence.", "emotion": "crying"}]
	for mode: String in expected:
		settings.text_speed = mode
		workspace.show_story(emotional_line, "TEST")
		check(is_equal_approx(workspace._typing_speed, 0.75 * float(expected[mode])) and workspace._typing, "Text speed composes with emotional pacing: " + mode)
	settings.text_speed = "instant"
	var instant_line: Array[Dictionary] = [{"speaker": "Daniel", "text": "A complete line remains readable.", "emotion": "crying"}]
	workspace.show_story(instant_line, "TEST")
	check(not workspace._typing and workspace._speech.visible_characters == -1 and workspace._history.size() == 1, "Instant reveals the whole line without skipping emotional/story state")
	check(workspace._line_index == 0 and not workspace._dialogue_done, "Instant still requires manual story advancement")
	var empty_story: Array[Dictionary] = []
	var stage: Dictionary = DecisionScenarios.get_stage("mod_03", 1)
	var threats: Array[Dictionary] = DecisionScenarios.get_threats("mod_03", 1)
	var threat: Dictionary = threats[0]
	workspace.show_threat(threat, empty_story, 1, 3, "TEST")
	await settle()
	check(workspace._choice_buttons[0].has_focus(), "Decision choices receive keyboard/controller focus after dialogue")
	workspace.update_decision_timer(3.0, 14.0, "BANK ALERT")
	check(workspace._timer_text.text.contains("03s") and workspace._timer_text.text.contains("!"), "Timer urgency has a visible text cue")
	settings.text_speed = prior_speed
	workspace.queue_free()
	await settle()

	var investigation: Control = InvestigationPanel.new()
	root.add_child(investigation)
	investigation.configure({"title": "CHECK EVIDENCE", "prompt": "What does this prove?", "items": [
		{"label": "Caller ID", "valid": false, "analysis": "A display can be spoofed."},
		{"label": "Independent callback", "valid": true, "analysis": "The trusted channel confirms the case."},
	]})
	await settle()
	check(investigation._item_buttons[0].has_focus(), "Investigation initially focuses its first evidence item")
	investigation._select(1)
	await settle()
	check(investigation._analyze_button.has_focus(), "Investigation moves focus to Analyze after selection")
	investigation._analyze()
	await settle()
	check(investigation._continue_button.has_focus() and investigation._result_label.text.contains("ANALYSIS CONFIRMED"), "Investigation moves focus to text-labeled Continue")
	investigation.queue_free()
	await settle()
	var call_panel: Control = CallPanel.new()
	root.add_child(call_panel)
	call_panel.configure({"caller": "Bank Fraud Department", "number": "PRIVATE NUMBER", "status": "CONNECTED"})
	call_panel.update_duration(61.0)
	check(call_panel._caller_label.text.contains("BANK FRAUD") and call_panel._number_label.text == "PRIVATE NUMBER" and call_panel._status_label.text == "CONNECTED" and call_panel._duration_label.text == "01:01", "Call identity, number, status, and duration are textual")
	check(call_panel._mute_button.text == "MUTE: OFF" and call_panel._speaker_button.text == "SPEAKER: OFF", "Call control states are textual")
	call_panel._mute_button.grab_focus()
	check(call_panel._mute_button.has_focus(), "Call controls accept keyboard/controller focus")
	call_panel.queue_free()
	await settle()

	var panel: Control = ReconstructionPanel.new()
	root.add_child(panel)
	panel.configure(DecisionScenarios.reconstruction_data(stage))
	await settle()
	check(panel._continue.has_focus() and panel._scroll.visible, "Reconstruction Continue is keyboard-focusable and timeline scrollable")
	check(panel._timeline.get_child_count() == 6 and panel._techniques.get_child_count() == 4 and not panel._finding.text.is_empty(), "Reconstruction provides all evidence as text")
	panel.queue_free()
	await settle()

	var screen: Control = load("res://src/ui/screens/settings/settings_screen.tscn").instantiate()
	root.add_child(screen)
	await settle()
	screen.on_enter({})
	check(screen._reduced_motion_toggle != null and screen._timer_assist_select.item_count == 3 and screen._text_speed_select.item_count == 4, "Settings expose motion, timer assist, and text speed")
	var scroll: ScrollContainer = screen.get_node("SafeAreaContainer/ScreenLayout/ScrollContainer")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		for bottom: bool in [false, true]:
			scroll.scroll_vertical = 100000 if bottom else 0
			await settle()
			check(root.get_visible_rect().encloses(screen._feedback_button.get_global_rect()), "Feedback fits landscape header")
			check(root.get_visible_rect().encloses(screen._logout_button.get_global_rect()), "Logout fits landscape footer")
			check(screen._feedback_button.get_global_rect().end.y <= scroll.get_global_rect().position.y, "Feedback never scrolls with settings")
			check(screen._logout_button.get_global_rect().position.y >= scroll.get_global_rect().end.y, "Logout never scrolls with settings")
			check(scroll.size.y >= 200, "Settings retain usable scroll area")
			if "--render" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/settings-%dx%d-%s.png" % [dimensions.x, dimensions.y, "bottom" if bottom else "top"])
		check(screen._text_speed_select.get_popup().has_theme_stylebox_override("panel"), "Accessibility dropdown matches the game theme")
		check(screen._logout_button.focus_mode == Control.FOCUS_ALL, "Footer logout supports keyboard/controller focus")
		check(screen._sfx_toggle.text == ("ON" if settings.sound_enabled else "OFF"), "Toggle copy agrees with loaded preference")
	screen.on_exit()
	screen.queue_free()
	await settle()
	check(root.get_node("PlayerManager").get_save_data() == before, "Accessibility checks never mutate BKT, rewards, or progression")
	print("ACCESSIBILITY_CHECKS failures=%d" % failures)
	quit(0 if failures == 0 else 1)
