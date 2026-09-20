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
	var before := JSON.stringify([player.credits, player.tech_ranks, player.unlocked_towers])
	var screen: Control = load("res://src/ui/screens/deploy/upgrade_screen.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	_check(screen._select_cards.size() == 3, "Three research cards")
	var portrait_script = load("res://src/ui/screens/deploy/research_portrait.gd")
	_check(portrait_script.get_script_constant_map().get("Glyphs") == load("res://src/gameplay/preview/unit_glyphs.gd"), "Armory shares the actual gameplay shape renderer")
	for id in screen._select_cards:
		var portraits := 0
		for node in screen._select_cards[id].find_children("*", "Control", true, false):
			if node.get_script() == portrait_script:
				portraits += 1
				_check(node.tower_id == id and node.unlocked == screen._is_tower_selectable(id), "Card shape and lock state match tower: " + id)
		_check(portraits == 1, "One geometric portrait per tower card")
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
	_check(screen._root_button.tower_id == "base", "Research core uses selected tower silhouette")
	screen._inspect_rank("stats", 1)
	_check(screen._purchase_button.disabled, "Insufficient credits cannot buy")
	_check(screen._detail_state.text.contains("18"), "Exact missing credits displayed")
	await _capture("research_tree_new")
	_check(before == JSON.stringify([player.credits, player.tech_ranks, player.unlocked_towers]), "Inspecting does not spend or mutate progression")
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
	var network_scroll: ScrollContainer = screen._tree_canvas.get_parent()
	network_scroll.scroll_vertical = 10000
	await _settle()
	await _capture("research_tree_lower")
	network_scroll.scroll_vertical = 0
	screen._inspect_rank("stats", 3)
	_check(screen._purchase_button.disabled, "Cannot skip rank")
	screen._inspect_rank("stats", 1)
	_check(screen._purchase_button.disabled, "Cannot rebuy owned rank")
	await screen._open_tower("scanner")
	await _settle()
	_check(screen._empty_hint.visible, "Unconfigured tracks get honest empty state")
	_check(screen._track_nodes.is_empty(), "No invented scanner upgrades")
	_check(screen._detail_icon.is_root and screen._detail_icon.tower_id == "scanner", "Inspector uses selected scanner shape")
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
	root.size = Vector2i(844, 390)
	await _settle()
	for child in screen.get_children():
		if child is SafeAreaContainer:
			var units := 1.0 / root.get_final_transform().get_scale().x
			child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
			child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
			child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units))
	await _settle()
	await _capture("research_armory_phone")
	await screen._open_tower("base")
	await _settle()
	screen._inspect_rank("stats", 2)
	await _settle()
	var scale_y := root.get_final_transform().get_scale().y
	_check(screen._back_button.size.y * scale_y >= 47.9, "Phone back target")
	_check(screen._purchase_button.size.y * scale_y >= 47.9, "Phone purchase target")
	_check(screen._tree_screen.get_global_rect().end.x <= root.get_visible_rect().end.x, "Phone layout fits horizontally")
	_check(root.get_visible_rect().encloses(screen._purchase_button.get_global_rect()), "Phone level-up button visible")
	for track in screen._track_nodes:
		for node in screen._track_nodes[track]:
			_check(node.size.x * scale_y >= 48 and node.size.y * scale_y >= 48, "Touch-sized orbit node")
	await _capture("research_tree_phone")
	# Every configured rank is inspectable without buying; tutorial only enables its original target.
	before = JSON.stringify([player.credits, player.tech_ranks, player.unlocked_towers])
	for track in screen._track_nodes:
		for node in screen._track_nodes[track]:
			screen._inspect_rank(track, node.rank)
			_check(screen._selected_rank == node.rank and screen._selected_track == track, "Rank selection updates inspector")
	_check(before == JSON.stringify([player.credits, player.tech_ranks, player.unlocked_towers]), "Inspecting all ranks is read only")
	router.is_tutorial = true
	screen._rebuild_tree()
	_check(not screen._capacity_rank1_button.disabled, "Tutorial capacity target remains enabled")
	for track in screen._track_nodes:
		for node in screen._track_nodes[track]:
			if not (track == "capacity" and node.rank == 1):
				_check(node.disabled, "Tutorial other nodes disabled")
	router.is_tutorial = false
	player.tech_ranks = {"base": {"stats": 3, "capacity": 3, "skill": 1, "evolution": 2}}
	screen._rebuild_tree()
	screen._inspect_rank("stats", 3)
	_check(screen._purchase_button.disabled and screen._rank_state("stats", 3) == "OWNED", "Maximum rank cannot repurchase")
	screen._session_changed(false)
	_check(screen._active_tower.is_empty() and screen._selection_screen.visible, "Account change returns to armory")
	print("[RESEARCH UI] failures=%d" % failures)
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
