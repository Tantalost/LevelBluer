extends SceneTree
## UI smoke checks. Only in-memory progression; never purchases or saves.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _capture(filename: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func _settle() -> void:
	for i in 4:
		await process_frame

func _run() -> void:
	var router := root.get_node("Router")
	var player := root.get_node("PlayerManager")
	router.is_tutorial = false
	player.credits = 132
	player.tech_ranks = {}
	player.unlocked_towers.assign(["base"])
	var screen: Control = load("res://src/ui/screens/deploy/upgrade_screen.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	_check(screen._select_cards.size() == 3, "Three research cards")
	_check(screen._is_tower_selectable("base"), "Base selectable")
	_check(not screen._is_tower_selectable("scanner"), "Scanner stays locked")
	await _capture("research_armory")
	screen._select_cards["scanner"].pressed.emit()
	_check(screen._active_tower.is_empty(), "Locked card cannot enter tree")
	await screen._open_tower("base")
	await _settle()
	var count := 0
	for track in screen._track_nodes:
		count += screen._track_nodes[track].size()
	_check(count == 9, "All nine existing ranks rendered")
	screen._inspect_rank("stats", 1)
	_check(screen._purchase_button.disabled, "Insufficient credits cannot buy")
	_check(screen._detail_state.text.contains("18"), "Exact missing credits displayed")
	await _capture("research_tree_new")
	player.tech_ranks = {"base": {"stats": 1, "capacity": 2, "evolution": 1}}
	player.credits = 350
	screen._refresh_coins_label()
	screen._rebuild_tree()
	screen._inspect_rank("capacity", 3)
	_check(not screen._purchase_button.disabled, "Next affordable rank enabled")
	_check(screen._rank_state("stats", 1) == "OWNED", "Owned state preserved")
	_check(screen._rank_state("stats", 3) == "LOCKED", "Sequential prerequisite preserved")
	_check(screen._is_tower_selectable("scanner"), "Evolution unlock works")
	_check(not screen._is_tower_selectable("sandbox"), "Rank two evolution still required")
	await _settle()
	await _capture("research_tree_progress")
	screen._inspect_rank("stats", 3)
	_check(screen._purchase_button.disabled, "Cannot skip rank")
	screen._inspect_rank("stats", 1)
	_check(screen._purchase_button.disabled, "Cannot rebuy owned rank")
	await screen._open_tower("scanner")
	await _settle()
	_check(screen._empty_hint.visible, "Unconfigured tracks get honest empty state")
	_check(screen._track_nodes.is_empty(), "No invented scanner upgrades")
	screen._on_back_pressed()
	_check(screen._selection_screen.visible, "Back returns to armory")
	# Check compact landscape layout and tutorial target without starting the coach/save flow.
	root.size = Vector2i(960, 600)
	await _settle()
	await screen._open_tower("base")
	await _settle()
	for track in screen._track_nodes:
		for button in screen._track_nodes[track]:
			_check(Rect2(Vector2.ZERO, screen._tree_canvas.size).encloses(button.get_rect()), "Node fits compact canvas: " + track)
	_check(screen._capacity_rank1_button != null, "Tutorial capacity target preserved")
	await _capture("research_tree_compact")
	screen._show_selection()
	await _settle()
	for card in screen._select_cards.values():
		_check(root.get_visible_rect().encloses(card.get_global_rect()), "Research card fits compact viewport")
	await _capture("research_armory_compact")
	print("[RESEARCH UI] failures=%d" % failures)
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
