extends SceneTree
## In-memory validation only. Never invokes the save/finish operation.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _run() -> void:
	var player := root.get_node("PlayerManager")
	player.lesson_progress = {}
	var catalog = load("res://src/ui/screens/intel/lesson_catalog.gd")
	var study = load("res://src/ui/screens/intel/lesson_study_content.gd")
	var picker: Control = load("res://src/ui/screens/intel/lessons_screen.tscn").instantiate()
	root.add_child(picker)
	await settle()
	check(picker._cards.size() == 5, "Five module cards")
	check(picker.find_child("UpgradesCard", true, false) == null, "No upgrades in lesson picker")
	check(picker._can_open(0) and not picker._can_open(1), "Sequential module lock retained")
	check(picker._cards[1].disabled, "Locked module visibly disabled")
	check(picker._cards[1].find_child("ModuleStatusIcon", true, false).kind == 4, "Locked module has padlock")
	check(not picker._cards[0].disabled, "First module/pretest remains actionable")
	await capture("lessons_module_picker")
	picker.hide()
	var screen: Control = load("res://src/ui/screens/intel/lesson_player_screen.tscn").instantiate()
	root.add_child(screen)
	screen._load_module("mod_01")
	await settle()
	var locked_topics := 0
	for child in screen._side.get_children():
		if child is Button and child.disabled:
			locked_topics += 1
			check(child.text.begins_with("LOCKED / ") and child.has_node("LockIcon"), "Locked topic has visible label and icon")
	check(locked_topics == 5, "Five future topics visibly locked")
	await capture("lessons_locked_topics")
	var count := 0
	for id in catalog.module_ids():
		for index in catalog.lesson_count(id):
			var content: Dictionary = study.build(id, index)
			check(not str(content.scenario).is_empty(), "Scenario: " + id)
			check(not content.correct.is_empty(), "Quiz has correct answer")
			for answer in content.correct:
				check(answer >= 0 and answer < content.options.size(), "Valid quiz index")
			screen._load_module(id, true)
			screen._select_topic(index)
			check(not screen._can_complete(), "Cannot finish definition")
			screen._set_phase(2)
			check(screen._phase == 0, "Cannot skip quiz")
			screen._on_continue()
			screen._check_quiz()
			check(not screen._quiz_passed, "Empty quiz cannot pass")
			for i in content.options.size():
				if i not in content.correct:
					screen._pick(i)
					break
			screen._check_quiz()
			check(not screen._quiz_passed, "Wrong answer cannot pass")
			check(screen._answer_effect._active and screen._answer_effect._ink == screen.Feedback.ERROR, "Wrong quiz shows red feedback")
			screen._picks.clear()
			for answer in content.correct:
				screen._pick(answer)
			screen._check_quiz()
			check(screen._quiz_passed, "Correct answer passes: %s/%d" % [id, index])
			check(screen._answer_effect._ink == screen.Feedback.SUCCESS and not screen._answer_effect._moving, "Correct quiz replaces error with green and stops shake")
			screen._on_continue()
			check(not screen._answer_effect._active, "Phase change clears quiz feedback")
			var sim = screen._simulation
			sim._act("report")
			check(not screen._simulation_passed, "Guessing report is blocked")
			sim._act("open")
			sim._act("unsafe")
			check(not screen._simulation_passed, "Unsafe action cannot pass")
			check(sim._answer_effect._active and sim._answer_effect._ink == screen.Feedback.ERROR, "Unsafe simulation shows red feedback")
			sim._act("inspect")
			sim._act("verify")
			sim._act("report")
			check(screen._simulation_passed, "Safe sequence passes")
			check(sim._answer_effect._ink == screen.Feedback.SUCCESS, "Safe simulation turns green")
			screen._on_continue()
			check(screen._can_complete(), "Both checks permit completion")
			count += 1
	check(player.lesson_progress.is_empty(), "No progress written before finish")
	screen._load_module("mod_01", true)
	await settle()
	await capture("lessons_definition")
	screen._on_continue()
	await settle()
	await capture("lessons_mini_quiz")
	var resting_position: Vector2 = screen._answer_effect._target.position
	screen._check_quiz()
	await create_timer(0.08).timeout
	screen._check_quiz()
	await create_timer(0.65).timeout
	check(screen._answer_effect._target.position.is_equal_approx(resting_position), "Repeated error shakes restore panel position")
	await capture("lessons_quiz_incorrect")
	for answer in screen._data.correct:
		screen._pick(answer)
	screen._check_quiz()
	await create_timer(0.35).timeout
	check(screen._answer_effect._active, "Success remains visible after animation")
	await capture("lessons_quiz_correct")
	screen._on_continue()
	screen._simulation._act("open")
	await settle()
	await capture("lessons_desktop_sim")
	root.size = Vector2i(960, 600)
	await settle()
	check(root.get_visible_rect().encloses(screen._submit_button.get_global_rect()), "Compact CTA remains visible")
	check(screen._panes.get_child(0).size.x > 200, "Readable left pane")
	await capture("lessons_compact")
	screen.queue_free()
	picker.show()
	await settle()
	await capture("lessons_picker_compact")
	picker.queue_free()
	await process_frame
	print("[LESSONS WORKSPACE] topics=%d failures=%d" % [count, failures])
	quit(0 if failures == 0 else 1)
