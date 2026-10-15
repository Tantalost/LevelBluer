extends SceneTree
## In-memory fixtures only: no login, publication, assessment or save writes.
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame: int in 5:
		await process_frame
func capture(filename: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")
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
	await settle()
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
	check(screen._body.get_child_count() == 5 and screen._reader_header.visible, "Codex definition and separate warning/response panels rendered")
	for viewport: Vector2i in [Vector2i(1280,720),Vector2i(844,390)]:
		root.size = viewport
		await settle()
		check(root.get_visible_rect().encloses(screen._reader_header.get_global_rect()), "Fixed reader navigation fits landscape")
		await capture("school-reader-%dx%d" % [viewport.x, viewport.y])
		screen._open("")
		screen._kind.select(0)
		screen._filter_changed(0)
		await settle()
		check(screen._count.text == "03 RESOURCES", "Resource count reflects filters")
		check(screen._count.get_line_count() == 1, "Resource count stays on one line")
		check((screen._body.get_parent() as Control).size.y >= 200, "Landscape library keeps room for resource cards")
		check(root.get_visible_rect().encloses(screen._filters.get_global_rect()), "Filters fit landscape")
		check(not (screen._body.get_parent() as ScrollContainer).get_v_scroll_bar().visible, "Resource scrollbar is hidden without removing scrolling")
		await capture("school-library-%dx%d" % [viewport.x, viewport.y])
		for filter: OptionButton in [screen._topic, screen._kind]:
			var popup: PopupMenu = filter.get_popup()
			check(popup.has_theme_font_override("font") and popup.has_theme_stylebox_override("panel") and popup.has_theme_stylebox_override("hover"), "Expanded filter uses game styling")
			filter.show_popup()
			await settle()
			check(popup.visible, "Filter popup opens")
			await capture("school-%s-%dx%d" % [filter.name, viewport.x, viewport.y])
			screen.on_exit()
			check(not popup.visible, "Leaving school content closes popup")
		screen._topic.select(3)
		screen._filter_changed(3)
		check(screen._count.text == "00 RESOURCES" and screen._body.get_child_count() == 1, "Empty filters show guidance")
		screen._topic.select(0)
		screen._open("codex")
	check(player.mastery_matrix == before.mastery and player.cleared_stages == before.cleared and player.completed_lessons == before.lessons and player.unlocked_skills == before.unlocks, "Browsing and practice preserve progress")
	db._school_feed_failed()
	check(db.school_items.size() == 3, "Transient failure retains current-session catalog")
	db._school_session_changed(false)
	check(db.school_items.is_empty(), "Sign out clears resources")
	screen.queue_free()
	await process_frame
	print("School content checks complete; failures=", failures)
	quit(1 if failures else 0)
