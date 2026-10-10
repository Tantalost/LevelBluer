extends SceneTree
## Exercises presentation and pure scoring, never AuthService submission or saves.
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
	var bank = load("res://src/data/pretest_bank.gd")
	for module_id in ["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"]:
		var answers: Array = []
		var kinds: Dictionary = {}
		for q in bank._bank_for(module_id):
			kinds[q.type] = true
			answers.append({"id": q.id, "answer": q.answer})
			check(q.type == "multiple_choice", "MC type: %s/%s" % [module_id, q.id])
			check(q.options.size() == 4, "Four options: %s/%s" % [module_id, q.id])
			check(bank._is_correct(q, q.answer), "Canonical answer: %s/%s" % [module_id, q.id])
			check(not bank._is_correct(q, null), "Null is not correct")
			check(not bank._is_correct(q, -1), "Out of range is not correct")
		check(kinds.size() == 1 and kinds.has("multiple_choice"), "Only multiple_choice in " + module_id)
		var grade: Dictionary = bank.grade(module_id, answers, 0)
		check(grade.ok and grade.pre_score == 100, "Perfect score across multiple choice")
		for q in bank.public_questions(module_id):
			check(not q.has("answer") and not q.has("difficulty") and not q.has("skill"), "Public questions do not reveal answers")
	var screen: Control = load("res://src/ui/screens/pretest/pretest_screen.tscn").instantiate()
	root.add_child(screen)
	screen._module_id = "mod_01"
	screen._questions = bank.public_questions("mod_01")
	screen._show_question()
	await settle()
	check(screen._bar.value == 0 and screen._next.disabled, "Initial progress and unanswered state")
	check(screen._options.get_child_count() == 4, "Four-option UI")
	await capture("pretest_choice")
	screen._select_option(screen._options.get_child(0), 0)
	screen._on_next_pressed()
	check(screen._bar.value == 1 and screen._index == 1, "Answer advances progress")
	await settle()
	await capture("pretest_second")
	screen._select_option(screen._options.get_child(1), 1)
	check(not screen._next.disabled, "Second choice counts as an answer")
	screen._set_busy(true)
	var before: int = screen._index
	screen._on_next_pressed()
	check(screen._index == before and not screen.can_go_back(), "Submission busy guard")
	screen._set_busy(false)
	screen._on_next_pressed()
	check(screen._answers[2] == 1, "Choice preserved as index")
	check(screen._payload().is_empty(), "Incomplete test cannot submit")
	# The pilot is tied to one authored item, not a card index or matching keyword.
	check(bank.visual_example("mod_02", 9, "changed").is_empty(), "Other modules do not inherit the email")
	check(bank.visual_example("mod_01", 9, "Changed server question").is_empty(), "Changed server content fails closed")
	screen._index = 8
	screen._show_question()
	await settle()
	check(screen._example.visible and not screen._brief.get_parent().visible, "Email replaces generic instructions only for pilot")
	var evidence: PanelContainer = screen._example.find_child("SenderEvidence", true, false)
	check(not evidence.get_meta("highlighted"), "No answer cue before baseline submission")
	check(screen._options.get_child_count() == 4 and screen._next.disabled, "Visual does not select an answer")
	await capture("pretest_email_desktop")
	root.size = Vector2i(844, 390)
	await settle()
	await capture("pretest_email_phone")
	check(root.get_visible_rect().encloses(screen._next.get_global_rect()) and root.get_visible_rect().encloses(screen._enlarge.get_global_rect()), "Landscape actions remain inside screen")
	for option: Control in screen._options.get_children():
		check((screen._card.get_parent() as Control).get_global_rect().encloses(option.get_global_rect()), "All four visual choices visible without scrolling")
	var baseline: Dictionary = screen._answers.duplicate(true)
	screen._open_example()
	await settle()
	check(is_instance_valid(screen._preview), "Email enlarges")
	screen._select_option(screen._options.get_child(0), 0)
	check(screen._selected == null, "Modal prevents background selection")
	await capture("pretest_email_enlarged")
	var mail: VBoxContainer = screen._preview.find_child("EmailContent", true, false)
	(mail.get_parent() as ScrollContainer).scroll_vertical = 10000
	await settle()
	await capture("pretest_email_attachment")
	check(screen.consume_back() and not is_instance_valid(screen._preview), "System back closes example first")
	check(screen._answers == baseline, "Inspecting never records or changes an answer")
	screen._select_option(screen._options.get_child(2), 2)
	screen._open_example()
	screen._on_next_pressed()
	check(screen._index == 8, "Modal blocks background submission")
	screen._close_example()
	screen._on_next_pressed()
	check(screen._answers[9] == 2 and not screen._example.visible, "Choice keeps original index and next item restores standard layout")
	for q in bank._bank_for("mod_01"):
		screen._answers[int(q.id)] = q.answer
	check(screen._payload().size() == 15, "Multiple-choice payload complete")
	screen._answers[3] = 0 if int(bank._bank_for("mod_01")[2].answer) != 0 else 1
	screen._show_results()
	screen._review_move(2)
	await settle()
	check(screen._bar.value == 15 and screen._finished, "Results show completed progress")
	check(not screen._review[2].correct, "Review shows missed choice")
	await capture("pretest_review")
	screen._review_move(6)
	await settle()
	evidence = screen._example.find_child("SenderEvidence", true, false)
	check(screen._example.visible and evidence.get_meta("highlighted"), "Submitted baseline review highlights sender evidence")
	var recorded: Array = screen._payload().duplicate(true)
	await capture("pretest_email_review")
	screen._open_example()
	await settle()
	await capture("pretest_email_review_enlarged")
	screen.on_exit()
	check(not is_instance_valid(screen._preview) and recorded == screen._payload(), "Exit clears modal without regrading baseline")
	root.size = Vector2i(844, 390)
	await settle()
	check(root.get_visible_rect().encloses(screen._next.get_global_rect()), "Compact action stays visible")
	await capture("pretest_compact")
	screen.queue_free()
	await process_frame
	print("[PRETEST CARDS] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
