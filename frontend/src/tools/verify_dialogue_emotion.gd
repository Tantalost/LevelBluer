extends SceneTree
## Regression suite for the reusable, data-driven dialogue emotion system
## (DialogueEmotion / DialogueScreenShake / DialoguePortrait emotion support).
##
## Run headless:  godot --headless --script res://src/tools/verify_dialogue_emotion.gd

const Emotion = preload("res://src/gameplay/decision/dialogue_emotion.gd")
const ScreenShake = preload("res://src/gameplay/decision/dialogue_screen_shake.gd")
const Portrait = preload("res://src/gameplay/decision/dialogue_portrait.gd")
const Workspace = preload("res://src/gameplay/decision/decision_workspace.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	_test_recognized_emotions()
	_test_neutral_default_and_fallback()
	await _test_animation_reset_and_no_accumulation()
	_test_screen_shake_profiles_and_reduced_motion()
	_test_presentation_is_isolated_from_gameplay_state()
	_test_authored_emotion_survives_dialogue_line_normalization()
	_test_module1_and_module2_still_load()
	_test_existing_dialogue_without_emotion_renders_normally()
	await _test_daniel_supported_generically()

	# Milestone: emotion pacing & presentation.
	_test_every_emotion_resolves_a_valid_profile()
	await _test_shake_anti_spam_and_re_entry()
	await _test_typing_speed_and_pause_are_wired_and_skip_safe()
	await _test_reduced_motion_keeps_expression_and_pacing()
	_test_pacing_isolated_from_gameplay_state()

	print("DIALOGUE_EMOTION_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)


func _test_recognized_emotions() -> void:
	print("== 2-10. Every supported emotion is recognized ==")
	var supported: PackedStringArray = [
		"angry", "crying", "scared", "shocked", "worried",
		"frustrated", "sad", "determined", "relieved",
	]
	for name in supported:
		check(Emotion.of({"speaker": "Daniel", "text": "...", "emotion": name}) == name,
			"[Emotion] '%s' is recognized" % name)
	check(supported.size() + 1 == Emotion.VALID_EMOTIONS.size(),
		"[Emotion] VALID_EMOTIONS lists exactly neutral + the 9 supported emotions")


func _test_neutral_default_and_fallback() -> void:
	print("== 1/11. Missing/invalid emotion defaults to neutral ==")
	check(Emotion.of({"speaker": "Leah", "text": "Hi."}) == Emotion.NEUTRAL,
		"[Emotion] A line with no 'emotion' key defaults to neutral")
	check(Emotion.of({"speaker": "Leah", "text": "Hi.", "emotion": ""}) == Emotion.NEUTRAL,
		"[Emotion] An empty emotion string defaults to neutral")
	check(Emotion.of({"speaker": "Leah", "text": "Hi.", "emotion": "furious"}) == Emotion.NEUTRAL,
		"[Emotion] An unrecognized emotion ('furious') safely falls back to neutral")
	check(Emotion.normalize("  ANGRY  ") == "angry",
		"[Emotion] normalize() trims whitespace and lowercases valid values")
	check(Emotion.normalize("NOT_A_REAL_EMOTION") == Emotion.NEUTRAL,
		"[Emotion] normalize() falls back to neutral for garbage input")


func _test_animation_reset_and_no_accumulation() -> void:
	print("== 12/13. Advancing emotions resets state; repeats never accumulate ==")
	var portrait: Control = Portrait.new()
	root.add_child(portrait)
	await settle()

	portrait.configure("Daniel", true, false, "angry")
	await settle()
	var clock_after_angry: float = portrait._emotion_clock
	check(portrait.emotion == "angry" and clock_after_angry > 0.0,
		"[Portrait] Angry emotion is applied and its clock advances")

	portrait.configure("Daniel", true, false, "sad")
	check(portrait.emotion == "sad" and portrait._emotion_clock == 0.0,
		"[Portrait] Switching to a new emotion resets the previous animation's clock to zero")

	# Re-configuring with the SAME emotion (as happens every time a line's
	# typing finishes, or the dialogue review opens/closes) must not reset
	# the clock again, and — since presentation is a pure function of
	# (emotion, clock) with no additive tween/offset state — repeated calls
	# at the same clock value must produce byte-identical output.
	var clock_before_repeat: float = portrait._emotion_clock
	var transform_before: Dictionary = portrait._emotion_transform()
	portrait.configure("Daniel", true, false, "sad")
	portrait.configure("Daniel", true, false, "sad")
	portrait.configure("Daniel", true, false, "sad")
	var transform_after: Dictionary = portrait._emotion_transform()
	check(is_equal_approx(portrait._emotion_clock, clock_before_repeat),
		"[Portrait] Re-configuring with the same emotion does not reset its clock")
	check(transform_before.get("offset", Vector2.ZERO) == transform_after.get("offset", Vector2.ZERO),
		"[Portrait] Repeated dialogue at the same emotion/time produces the same transform (no accumulation)")

	# Becoming inactive (another character is now speaking) always presents
	# neutral, regardless of whatever emotion this portrait last had.
	portrait.configure("Daniel", false, false, "angry")
	check(portrait.emotion == Emotion.NEUTRAL,
		"[Portrait] An inactive (non-speaking) portrait always presents neutral")

	portrait.queue_free()


func _test_screen_shake_profiles_and_reduced_motion() -> void:
	print("== Screen shake: only angry/shocked shake; reduced_motion suppresses it ==")
	for calm in ["neutral", "worried", "scared", "crying", "sad", "determined", "relieved", "frustrated"]:
		check(Emotion.shake_profile(calm).is_empty(),
			"[ScreenShake] '%s' does not trigger a screen shake" % calm)
	check(not Emotion.shake_profile("angry").is_empty(), "[ScreenShake] angry has a shake profile")
	check(not Emotion.shake_profile("shocked").is_empty(), "[ScreenShake] shocked has a (tiny) shake profile")
	check(float(Emotion.shake_profile("angry").get("duration", 0.0)) <= 0.30,
		"[ScreenShake] angry's shake stays short (<= 0.30s), never a continuous shake")

	var settings := root.get_node("SettingsService")
	var node := Control.new()
	root.add_child(node)
	node.position = Vector2(40, 20)
	var reduced_before: bool = settings.reduced_motion
	settings.reduced_motion = true
	ScreenShake.apply(node, "angry")
	check(not node.has_meta("_shake_tween"),
		"[ScreenShake] reduced_motion suppresses the full screen shake")
	settings.reduced_motion = false
	ScreenShake.apply(node, "angry")
	check(node.has_meta("_shake_tween"), "[ScreenShake] Shake runs normally when reduced_motion is off")
	ScreenShake.apply(node, "worried")
	check(not node.has_meta("_shake_tween"),
		"[ScreenShake] Applying a non-shaking emotion cancels any prior shake cleanly")
	check(is_equal_approx(node.position.x, 40.0) and is_equal_approx(node.position.y, 20.0),
		"[ScreenShake] Cancelling a shake restores the original position exactly")
	settings.reduced_motion = reduced_before
	node.queue_free()


func _test_presentation_is_isolated_from_gameplay_state() -> void:
	print("== 14/15/16. Emotion presentation never touches BKT, outcomes, or progression ==")
	var forbidden: PackedStringArray = [
		"PlayerManager", "update_mastery", "mark_stage_cleared", "SaveService",
		"StageManager", "DecisionStageController", "TaskManager",
	]
	var presentation_only_files: PackedStringArray = [
		"res://src/gameplay/decision/dialogue_emotion.gd",
		"res://src/gameplay/decision/dialogue_screen_shake.gd",
	]
	for path in presentation_only_files:
		var text: String = FileAccess.get_file_as_string(path)
		check(not text.is_empty(), "[Isolation] %s is readable for the isolation check" % path)
		for symbol in forbidden:
			check(not text.contains(symbol), "[Isolation] %s does not reference %s" % [path, symbol])


func _test_authored_emotion_survives_dialogue_line_normalization() -> void:
	print("== Authored 'emotion' metadata actually survives DecisionScenarios.dialogue_lines()/get_threats() ==")
	var mod3_opening: Array[Dictionary] = DecisionScenarios.dialogue_lines(DecisionScenarios.get_stage("mod_03", 1), "opening")
	var found_worried := false
	for line in mod3_opening:
		if Emotion.of(line) == "worried":
			found_worried = true
	check(found_worried, "[Regression] An authored 'emotion' on an opening line survives dialogue_lines() normalization")
	var incident3: Dictionary = DecisionScenarios.get_threats("mod_03", 1)[2]
	var story: Array[Dictionary] = DecisionScenarios.dialogue_lines(incident3, "story")
	var found_angry := false
	for line in story:
		if Emotion.of(line) == "angry":
			found_angry = true
	check(found_angry, "[Regression] An authored 'emotion' on a threat's story line survives dialogue_lines() normalization")


func _test_module1_and_module2_still_load() -> void:
	print("== 17/18. Module 1 and Module 2 decision content still loads ==")
	check(DecisionScenarios.is_decision_stage("mod_01", 1), "[Regression] Module 1 Stage 1 still loads")
	check(DecisionScenarios.get_threats("mod_01", 1).size() == 3, "[Regression] Module 1 Stage 1 still has 3 incidents")
	check(DecisionScenarios.is_decision_stage("mod_02", 1), "[Regression] Module 2 Stage 1 still loads")
	check(DecisionScenarios.get_threats("mod_02", 1).size() == 3, "[Regression] Module 2 Stage 1 still has 3 incidents")


func _test_existing_dialogue_without_emotion_renders_normally() -> void:
	print("== 19. Existing Module 1/2 dialogue (no 'emotion' key) still renders normally ==")
	var mod1_raw_opening: Array = DecisionScenarios.get_stage("mod_01", 1).get("opening", []) as Array
	for raw_line in mod1_raw_opening:
		check(not (raw_line as Dictionary).has("emotion"), "[Regression] Existing Module 1 line's authored JSON carries no 'emotion' key")
	var mod1_opening: Array[Dictionary] = DecisionScenarios.dialogue_lines(DecisionScenarios.get_stage("mod_01", 1), "opening")
	check(not mod1_opening.is_empty(), "[Regression] Module 1 Stage 1 opening dialogue is present")
	for line in mod1_opening:
		check(Emotion.of(line) == Emotion.NEUTRAL, "[Regression] Existing Module 1 line resolves to neutral")
	var mod2_opening: Array[Dictionary] = DecisionScenarios.dialogue_lines(DecisionScenarios.get_stage("mod_02", 1), "opening")
	for line in mod2_opening:
		check(Emotion.of(line) == Emotion.NEUTRAL, "[Regression] Existing Module 2 line resolves to neutral")


func _test_daniel_supported_generically() -> void:
	print("== 20. DANIEL (Module 3's new character) is supported generically, not via special-cased logic ==")
	var portrait_source: String = FileAccess.get_file_as_string("res://src/gameplay/decision/dialogue_portrait.gd")
	check(not portrait_source.to_lower().contains("daniel"),
		"[Daniel] dialogue_portrait.gd contains no Daniel-specific branch — the generic fallback handles him")
	var portrait: Control = Portrait.new()
	root.add_child(portrait)
	await settle()
	portrait.configure("DANIEL", true, true, "worried")
	check(portrait.speaker == "DANIEL" and portrait.emotion == "worried",
		"[Daniel] Configuring a DANIEL portrait with an emotion works with zero Daniel-specific code")
	portrait.queue_free()


func _test_every_emotion_resolves_a_valid_profile() -> void:
	print("== Milestone: every emotion resolves a complete, valid presentation profile ==")
	for emotion in Emotion.VALID_EMOTIONS:
		var profile: Dictionary = Emotion.profile(emotion)
		check(profile.has("typing_speed") and profile.has("pause_before") and profile.has("pause_after"),
			"[Profile] '%s' resolves a complete profile (typing_speed/pause_before/pause_after)" % emotion)
		check(float(profile.get("typing_speed", 0.0)) > 0.0, "[Profile] '%s' has a positive typing speed multiplier" % emotion)
		check(float(profile.get("pause_before", -1.0)) >= 0.0 and float(profile.get("pause_after", -1.0)) >= 0.0,
			"[Profile] '%s' has non-negative pauses" % emotion)
	check(is_equal_approx(Emotion.typing_speed(Emotion.NEUTRAL), 1.0), "[Profile] neutral types at exactly the normal rate")
	check(is_equal_approx(Emotion.pause_before(Emotion.NEUTRAL), 0.0) and is_equal_approx(Emotion.pause_after(Emotion.NEUTRAL), 0.0),
		"[Profile] neutral has no pauses")
	check(Emotion.profile("not_a_real_emotion") == Emotion.profile(Emotion.NEUTRAL), "[Profile] An invalid emotion resolves to exactly the neutral profile")
	check(Emotion.typing_speed("angry") > 1.0, "[Profile] angry types faster than normal")
	check(Emotion.typing_speed("crying") < Emotion.typing_speed("sad") and Emotion.typing_speed("sad") < 1.0,
		"[Profile] crying types slower than sad, which types slower than normal")


func _test_shake_anti_spam_and_re_entry() -> void:
	print("== Milestone: consecutive same-emotion lines don't re-shake; leaving and re-entering can trigger it again ==")
	var ws: Control = Workspace.new()
	root.add_child(ws)
	await settle()

	ws._apply_line_emotion_fx("angry")
	check(ws._window.has_meta("_shake_tween"), "[AntiSpam] The first 'angry' line triggers a screen shake")
	var first_tween: Variant = ws._window.get_meta("_shake_tween")

	ws._apply_line_emotion_fx("angry")
	var second_tween: Variant = ws._window.get_meta("_shake_tween") if ws._window.has_meta("_shake_tween") else null
	check(second_tween == first_tween, "[AntiSpam] A second consecutive 'angry' line does not start a new shake (same tween, or none re-created)")

	ws._apply_line_emotion_fx("sad")
	check(not ws._window.has_meta("_shake_tween"), "[AntiSpam] Transitioning to a non-shaking emotion cleans up any shake state")

	ws._apply_line_emotion_fx("angry")
	check(ws._window.has_meta("_shake_tween"), "[AntiSpam] Re-entering 'angry' after leaving it triggers a shake again")
	var third_tween: Variant = ws._window.get_meta("_shake_tween")
	check(third_tween != first_tween, "[AntiSpam] The re-triggered shake is a genuinely new tween, not a stale leftover")

	ws.queue_free()
	await settle()


func _test_typing_speed_and_pause_are_wired_and_skip_safe() -> void:
	print("== Milestone: typing speed/pause are wired from the emotion profile, and skipping still works ==")
	var ws: Control = Workspace.new()
	root.add_child(ws)
	await settle()
	var angry_lines: Array[Dictionary] = [{"speaker": "Daniel", "text": "They're doing something right now.", "emotion": "angry"}]
	ws.show_story(angry_lines, "HEADER")
	await settle()
	check(is_equal_approx(ws._typing_speed, Emotion.typing_speed("angry")), "[Pacing] An angry line's typing speed matches its profile")
	check(is_equal_approx(ws._pause_remaining, Emotion.pause_before("angry")), "[Pacing] An angry line's pre-typing pause matches its profile")

	var crying_lines: Array[Dictionary] = [{"speaker": "Daniel", "text": "I don't like not knowing who's on the other side of the phone.", "emotion": "crying"}]
	ws.show_story(crying_lines, "HEADER")
	# Checked synchronously, before any frame advance: pause_remaining ticks
	# down in _process(), so waiting even one frame here would make this
	# assertion racy against real frame timing.
	check(is_equal_approx(ws._typing_speed, Emotion.typing_speed("crying")) and Emotion.typing_speed("crying") < 1.0,
		"[Pacing] A crying line types slower than normal, per its profile")
	check(is_equal_approx(ws._pause_remaining, Emotion.pause_before("crying")) and ws._pause_remaining > 0.0,
		"[Pacing] A crying line starts with its full authored pre-typing pause active")
	check(ws._typing, "[Pacing] The line is still mid-typing (pause included) before any input")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	ws._speech_input(touch)
	await settle()
	check(not ws._typing and ws._speech.visible_characters == -1,
		"[Pacing] A tap during the pre-typing pause still skips straight to the full line — pauses never block player input")

	ws.queue_free()
	await settle()


func _test_reduced_motion_keeps_expression_and_pacing() -> void:
	print("== Milestone: reduced_motion suppresses jolt/shake but keeps tears and pacing ==")
	var settings := root.get_node("SettingsService")
	var reduced_before: bool = settings.reduced_motion

	var portrait: Control = Portrait.new()
	root.add_child(portrait)
	await settle()
	portrait.configure("Daniel", true, false, "crying")
	var fx: Dictionary = portrait._emotion_transform()
	check(bool(fx.get("crying", false)), "[ReducedMotion] Crying's tear flag is present in the raw emotion transform")
	check(bool(fx.get("slow_talk", false)), "[ReducedMotion] Crying's slowed-talk flag is present in the raw emotion transform")

	settings.reduced_motion = true
	check(portrait._reduced_motion(), "[ReducedMotion] The portrait correctly reads SettingsService.reduced_motion")
	var fx_still: Dictionary = portrait._emotion_transform()
	check(bool(fx_still.get("crying", false)) and bool(fx_still.get("slow_talk", false)),
		"[ReducedMotion] reduced_motion does not strip the tear/pacing signals from the emotion transform itself — only _draw() gates the motion offset/scale")
	settings.reduced_motion = false
	check(not portrait._reduced_motion(), "[ReducedMotion] reduced_motion=false is also read correctly")
	portrait.queue_free()

	var node := Control.new()
	root.add_child(node)
	settings.reduced_motion = true
	ScreenShake.apply(node, "angry")
	check(not node.has_meta("_shake_tween"), "[ReducedMotion] Screen shake is still suppressed for angry under reduced_motion")
	node.queue_free()

	settings.reduced_motion = reduced_before


func _test_pacing_isolated_from_gameplay_state() -> void:
	print("== Milestone: pacing/anti-spam code never touches BKT, outcomes, or progression ==")
	var forbidden: PackedStringArray = [
		"PlayerManager", "update_mastery", "mark_stage_cleared", "SaveService",
		"StageManager", "DecisionStageController", "TaskManager",
	]
	var text: String = FileAccess.get_file_as_string("res://src/gameplay/decision/decision_workspace.gd")
	check(not text.is_empty(), "[Isolation] decision_workspace.gd is readable for the isolation check")
	for symbol in forbidden:
		check(not text.contains(symbol), "[Isolation] decision_workspace.gd does not reference %s" % symbol)
