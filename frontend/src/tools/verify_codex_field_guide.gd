extends SceneTree
## In-memory read-only Codex validation. Does not navigate, unlock or save progress.
var Field: GDScript
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 5:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _run() -> void:
	# Load after autoload initialization (SceneTree --script compiles before it).
	Field = load("res://src/ui/screens/intel/codex_field_data.gd")
	var Enemy: GDScript = load("res://src/gameplay/enemy_base.gd")
	var player := root.get_node("PlayerManager")
	var progress: Dictionary = player.lesson_progress.duplicate(true)
	var credits: int = player.credits
	var screen: Control = load("res://src/ui/screens/intel/codex_screen.tscn").instantiate()
	root.add_child(screen)
	await settle()
	check(screen._visible_ids.size() == 3, "All three defenders indexed")
	check(screen._current_unit_id == "base", "Basic Node is initial entry")
	check(screen._preview != null, "Entry includes reusable artwork preview")
	check(screen._resource_label.size.y < 40, "Resource readout stays on one line")
	check(screen._roster.get_parent().size.y > 200, "Roster has space for visible entries")
	await capture("codex_defender")
	var entries := 0
	for tab in [&"units", &"enemies"]:
		screen._set_tab(tab)
		for id in Field.ids(tab):
			screen._show_unit(id)
			await settle()
			var data: Dictionary = Field.entry(tab, id)
			check(screen._current_unit_id == id, "Selectable entry: " + id)
			check(not str(data.real_body).is_empty(), "Real-world notes: " + id)
			check(screen._matchup_rows.size() == 3, "Three matchup summaries: " + id)
			check(not screen._real_body.visible, "Real-world section starts collapsed")
			screen._toggle_real()
			check(screen._real_body.visible, "Real-world section can expand")
			screen._toggle_real()
			entries += 1
	for enemy_id in Field.ids(&"enemies"):
		var enemy: Node = Enemy.new()
		enemy.threat_profile = Enemy.profile_for_character(Enemy.character_for_wave(enemy_id))
		for tower_id in Field.ids(&"units"):
			var matchup: Dictionary = Field.matchup(tower_id, enemy_id)
			var actual: float = enemy.sandbox_slow_factor() if tower_id == "sandbox" else enemy.damage_multiplier_vs(tower_id)
			check(is_equal_approx(float(matchup.value), actual), "Live matchup parity: %s/%s" % [tower_id, enemy_id])
		enemy.free()
	check(Field.matchup("base", "heavy").tier == "strong", "Basic Node counters heavy")
	check(Field.matchup("scanner", "fast").tier == "strong", "Scanner counters swarm")
	check(Field.matchup("sandbox", "basic").effect == "60% slow", "Sandbox displays speed reduction, not remaining speed")
	screen.load_topic("phishing")
	await settle()
	check(screen._tab == &"enemies" and screen._current_unit_id == "fast", "Phishing remediation selects Phisherman")
	await capture("codex_threat")
	screen._toggle_real()
	await settle()
	(screen._detail.get_parent() as ScrollContainer).scroll_vertical = 10000
	await settle()
	await capture("codex_real_world")
	screen._search.text = "heavy"
	screen._rebuild_list()
	check(screen._visible_ids.size() == 2, "Search by heavy type includes boss")
	screen._search.text = "no-such-entry"
	screen._rebuild_list()
	check(screen._visible_ids.is_empty() and screen._current_unit_id.is_empty(), "No-result search clears stale entry")
	screen._set_tab(&"units")
	screen._step(1)
	check(screen._current_unit_id == "scanner", "Next entry follows roster order")
	screen._step(-1)
	check(screen._current_unit_id == "base", "Previous entry works")
	root.size = Vector2i(960, 600)
	screen.load_topic("")
	await settle()
	check(root.get_visible_rect().encloses(screen._panes.get_global_rect()), "Compact panels remain in viewport")
	check(screen._panes.get_child(0).size.x >= 230, "Compact index remains readable")
	await capture("codex_compact")
	check(player.lesson_progress == progress and player.credits == credits, "Browsing does not modify progression or credits")
	screen.queue_free()
	await process_frame
	print("[CODEX FIELD GUIDE] entries=%d failures=%d" % [entries, failures])
	quit(0 if failures == 0 else 1)
