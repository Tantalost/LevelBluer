extends SceneTree
## In-memory fixtures only: no login, publication, assessment or save writes.
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	await process_frame
	var db: Node = root.get_node("ContentDB")
	var player: Node = root.get_node("PlayerManager")
	var before: Dictionary = {"mastery":player.mastery_matrix.duplicate(true), "cleared":player.cleared_stages.duplicate(true), "lessons":player.completed_lessons.duplicate(), "unlocks":player.unlocked_skills.duplicate()}
	var catalog: Dictionary = {"schemaVersion":1,"releaseVersion":1,"items":[
		{"id":"lesson","revision":1,"title":"Verify the sender","kind":"lesson","topic":"Phishing","content":{"body":"Contact the school using a known number.","objectives":["Verify unexpected requests"]}},
		{"id":"quiz","revision":1,"title":"A suspicious message","kind":"quiz","topic":"Smishing","content":{"prompt":"What should you do?","options":["Verify independently","Share a password"],"correctOption":0,"explanation":"Use a trusted channel."}},
		{"id":"codex","revision":1,"title":"Unexpected USB drives","kind":"codex","topic":"Baiting","content":{"definition":"An attacker offers an enticing device.","warningSigns":["Unknown source"],"safeResponse":"Report it to school IT."}}
	]}
	check(db.valid_school_catalog(catalog), "Valid school catalog accepted")
	var malformed: Dictionary = catalog.duplicate(true)
	malformed.items[1].content.correctOption = 7
	check(not db.valid_school_catalog(malformed), "Out-of-range answer rejected")
	malformed = catalog.duplicate(true)
	malformed.items[0].content.body = []
	check(not db.valid_school_catalog(malformed), "Malformed text rejected")
	malformed = catalog.duplicate(true)
	malformed.items.append(malformed.items[0])
	check(not db.valid_school_catalog(malformed), "Duplicate resource rejected")
	for item: Dictionary in catalog.items:
		db.school_items.append(item)
	db.school_content_status = "Test release"
	var scene: PackedScene = load("res://src/ui/screens/intel/school_content_screen.tscn")
	var screen: Control = scene.instantiate()
	root.add_child(screen)
	root.content_scale_size = Vector2i.ZERO
	await process_frame
	check(screen._body.get_child_count() == 3, "All resource types visible")
	screen._open("lesson")
	check(not screen.can_go_back() and screen._selected.is_empty(), "Android back returns to list first")
	screen._kind.select(2)
	screen._filter_changed(2)
	check(screen._body.get_child_count() == 1, "Type filter scopes list")
	screen._open("quiz")
	screen._choose_answer(1, catalog.items[1].content)
	check(screen._answer.text.begins_with("Try again."), "Wrong answer gives explanation")
	screen._choose_answer(0, catalog.items[1].content)
	check(screen._answer.text.begins_with("Correct."), "Correct answer gives feedback")
	screen._open("codex")
	check(screen._body.get_child_count() >= 6, "Codex definition and safety notes rendered")
	for viewport: Vector2i in [Vector2i(1280,720),Vector2i(844,390),Vector2i(390,844)]:
		root.size = viewport
		await process_frame
		await process_frame
		check(screen.get_combined_minimum_size().x <= viewport.x, "Reader fits viewport width")
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/school-content-%dx%d.png" % [viewport.x, viewport.y])
	check(player.mastery_matrix == before.mastery and player.cleared_stages == before.cleared and player.completed_lessons == before.lessons and player.unlocked_skills == before.unlocks, "Browsing and practice preserve progress")
	db._school_feed_failed()
	check(db.school_items.size() == 3, "Transient failure retains current-session catalog")
	db._school_session_changed(false)
	check(db.school_items.is_empty(), "Sign out clears resources")
	screen.queue_free()
	await process_frame
	print("School content checks complete; failures=", failures)
	quit(1 if failures else 0)
