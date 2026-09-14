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
			check(bank._is_correct(q, q.answer), "Canonical answer: %s/%s" % [module_id, q.id])
			check(not bank._is_correct(q, null), "Null is not correct")
			if q.type == "short_answer":
				check(bank._is_correct(q, "  " + str(q.answer).to_upper() + ". "), "Normalized recall")
				check(bank._is_correct(q, int(q.legacy_answer)), "Old queued choice remains valid")
				check(not bank._is_correct(q, "not " + str(q.answer)), "No substring false positives")
				check(not bank._is_correct(q, ""), "Empty recall is incorrect")
		check(kinds.size() == 3, "Three formats in " + module_id)
		var grade: Dictionary = bank.grade(module_id, answers, 0)
		check(grade.ok and grade.pre_score == 100, "Perfect score across mixed formats")
		for q in bank.public_questions(module_id):
			check(not q.has("answer") and not q.has("accepted_answers"), "Public questions do not reveal answers")
	var screen: Control = load("res://src/ui/screens/pretest/pretest_screen.tscn").instantiate()
	root.add_child(screen)
	screen._module_id = "mod_01"
	screen._questions = bank.public_questions("mod_01")
	screen._show_question()
	await settle()
	check(screen._bar.value == 0 and screen._next.disabled, "Initial progress and unanswered state")
	await capture("pretest_choice")
	screen._select_option(screen._options.get_child(0), 0)
	screen._on_next_pressed()
	check(screen._bar.value == 1 and screen._index == 1, "Answer advances progress")
	await settle()
	await capture("pretest_true_false")
	screen._select_option(screen._options.get_child(1), false)
	check(not screen._next.disabled, "False counts as an answer")
	screen._on_next_pressed()
	check(screen._recall_input != null, "Recall card has text input")
	screen._on_text_changed("   ... ")
	check(screen._next.disabled, "Blank punctuation cannot advance")
	screen._recall_input.text = "Phishing"
	screen._on_text_changed("Phishing")
	await settle()
	await capture("pretest_recall")
	screen._set_busy(true)
	var before: int = screen._index
	screen._on_next_pressed()
	check(screen._index == before and not screen.can_go_back(), "Submission busy guard")
	screen._set_busy(false)
	screen._on_next_pressed()
	check(screen._answers[3] == "Phishing", "Recall preserved as text")
	check(screen._payload().is_empty(), "Incomplete test cannot submit")
	for q in bank._bank_for("mod_01"):
		screen._answers[int(q.id)] = q.answer
	check(screen._payload().size() == 15, "Mixed payload complete")
	screen._answers[3] = "wrong"
	screen._show_results()
	screen._review_move(2)
	await settle()
	check(screen._bar.value == 15 and screen._finished, "Results show completed progress")
	check(not screen._review[2].correct, "Review shows missed recall")
	await capture("pretest_review")
	root.size = Vector2i(960, 600)
	await settle()
	check(root.get_visible_rect().encloses(screen._next.get_global_rect()), "Compact action stays visible")
	await capture("pretest_compact")
	screen.queue_free()
	await process_frame
	print("[PRETEST CARDS] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
