extends SceneTree
## Presentation-only smoke test; does not enter lessons or save player progress.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths := [
		"res://src/ui/screens/intel/lessons_screen.tscn",
		"res://src/ui/screens/intel/lesson_player_screen.tscn",
		"res://src/ui/screens/pretest/pretest_screen.tscn",
		"res://src/ui/screens/intel/codex_screen.tscn",
	]
	for path in paths:
		var screen: Control = load(path).instantiate()
		root.add_child(screen)
		await process_frame
		var overlay := screen.get_node_or_null("CRTOverlay") as ColorRect
		if overlay == null or not overlay.is_visible_in_tree() or overlay.material == null:
			failures += 1
			push_error("CRT must remain enabled: " + path)
		for button in screen.find_children("*", "Button", true, false):
			if button.text.begins_with("CRT:"):
				failures += 1
				push_error("CRT toggle must be absent: " + path)
		screen.queue_free()
		await process_frame
	print("[STUDY CRT] screens=%d failures=%d" % [paths.size(), failures])
	quit(0 if failures == 0 else 1)
