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

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func verify_archive(screen: Control, player: Node) -> void:
	var Survey: GDScript = Field.Survey
	var original_chapters: Dictionary = player.chapter_progress.duplicate(true)
	var original_replay: Dictionary = player.chapter_replay_progress.duplicate(true)
	player.chapter_progress.erase(Survey.ID)
	screen.on_enter({})
	check(screen._section == &"characters" and screen._character_buttons.size() == 3, "Codex defaults to three Chapter 1 character files")
	var fresh: Dictionary = Field.story_snapshot({})
	check(Field.discovery_progress(fresh) == {"found":0,"total":9}, "Fresh archive starts at zero discovered observations")
	screen._set_section(&"evidence")
	check(screen._archive_body.find_child("Toggle_record_client_claim", true, false) == null, "Undiscovered records have no expandable spoiler content")
	check((screen._archive_body.find_child("DiscoveryProgress", true, false) as ProgressBar).value == 0, "Progress UI reflects the fresh save")
	screen._set_section(&"characters")
	for id: String in Field.CHARACTER_IDS:
		check(Field.character(id, fresh).interactions.is_empty(), "Fresh save hides undiscovered interactions for " + id)
		var portrait: TextureRect = screen._character_buttons[id].find_children("*", "TextureRect", true, false)[0] as TextureRect
		var sheet: Texture2D = root.get_node("AssetManager").get_texture("chapter1_" + id)
		check((portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas == sheet) if sheet != null else portrait.texture == null, "Character portrait reuses the existing asset or handles offline absence")
	for item: Dictionary in Field.observations(fresh):
		check(not item.discovered and item.status == "Unknown" and item.title == "Undiscovered observation", "Undiscovered evidence does not leak its title or details")
	var partial: Dictionary = Survey.fresh()
	partial.beat = 4
	check(not Field.observations(partial)[1].discovered, "Current chat beat is not treated as completed")
	partial.beat = 5
	check(Field.discovery_progress(partial).found == 3, "Completed chat advances discovery count to three")
	check(Field.observations(partial)[1].discovered and not Field.observations(partial)[3].discovered, "Completed chat unlocks the offer but not the later client claim")
	partial.beat = 6
	check(Field.observations(partial)[3].status == "Unverified", "Eric's personal connection is a claim, not a verified fact")
	partial.beat = 8
	check(Field.discovery_progress(partial).found == 5, "Discovered unresolved information counts as discovered, not verified")
	check(Field.observations(partial)[4].discovered and Field.observations(partial)[4].status == "Unknown", "Client identity remains unknown after Eric's reply")
	partial.beat = 9
	check(not Field.observations(partial)[5].discovered, "Jobert's current dialogue does not prematurely unlock verification advice")
	partial.beat = 10
	check(Field.observations(partial)[5].discovered, "Finished Jobert dialogue unlocks the verification recommendation")
	partial.read = ["survey"]
	check(Field.observations(partial)[6].discovered and not Field.observations(partial)[7].discovered, "Only read messages reveal their observations")
	partial.flags = ["survey"]
	partial.domains = ["survey"]
	partial.captures = ["survey"]
	check(Field.observations(partial)[6].text.contains("gmail.com") and Field.observations(partial)[6].text.contains("capture saved"), "Existing investigation flags add domain and capture context")
	var complete: Dictionary = Survey.fresh()
	for message: Dictionary in Survey.MESSAGES:
		complete.read.append(message.id)
		complete.sorted.append(message.id)
	for field: String in ["flags", "domains", "captures"]: complete[field] = Survey.suspicious_ids()
	complete.sealed = true
	complete.completed = true
	complete = Field.story_snapshot(complete)
	player.chapter_progress[Survey.ID] = complete
	player.chapter_replay_progress = Survey.fresh()
	screen.on_resume()
	check(screen._story_snapshot.completed, "Restarting a replay does not erase discoveries from the original chapter")
	var serialized: Dictionary = player.get_save_data()
	check(Field.story_snapshot(serialized.chapter_progress[Survey.ID]) == complete, "Existing serialized Chapter 1 save is sufficient; no archive fields required")
	var before: Dictionary = player.get_save_data()
	await settle()
	await capture("codex_characters")
	await tap(screen._character_buttons["eric"])
	check(screen._selected_character == "eric", "Character card opens Eric's profile")
	check(Field.discovery_progress(complete, "eric") == {"found":3,"total":3}, "Character progress counts only related observations")
	for section: String in ["background", "relationships", "discoveries"]:
		var body: Control = screen._archive_body.find_child("Details_" + section, true, false) as Control
		check(body != null and not body.visible, "Profile section starts collapsed: " + section)
	await capture("codex_eric")
	var background_toggle: Button = screen._archive_body.find_child("Toggle_background", true, false) as Button
	await tap(background_toggle)
	check((screen._archive_body.find_child("Details_background", true, false) as Control).visible, "Tapping Background expands the original profile text")
	screen._refresh_archive()
	check((screen._archive_body.find_child("Details_background", true, false) as Control).visible, "Asset/progress refresh preserves expanded sections")
	check(not screen.can_go_back() and screen._selected_character.is_empty(), "Profile Back returns to Characters without leaving Codex")
	await tap(screen._section_buttons[&"evidence"])
	check(screen._section == &"evidence", "Evidence tab switches by tap")
	check(Field.observations(screen._story_snapshot)[3].status == "Unverified", "Completing Chapter 1 never verifies Eric's claim")
	check((screen._archive_body.find_child("DiscoveryProgress", true, false) as ProgressBar).value == 9, "Completed archive displays all nine discoveries")
	var claim_body: Control = screen._archive_body.find_child("Details_record_client_claim", true, false) as Control
	check(not claim_body.visible, "Evidence details and sources are collapsed initially")
	var known_button: Button = screen._archive_body.find_child("Toggle_record_offer", true, false) as Button
	var claim_button: Button = screen._archive_body.find_child("Toggle_record_client_claim", true, false) as Button
	var unknown_button: Button = screen._archive_body.find_child("Toggle_record_client_identity", true, false) as Button
	check(known_button.text.contains("KNOWN") and claim_button.text.contains("UNVERIFIED") and unknown_button.text.contains("UNKNOWN"), "Status indicators include labels, not color alone")
	check(known_button.get_theme_color("font_color") != claim_button.get_theme_color("font_color") and claim_button.get_theme_color("font_color") != unknown_button.get_theme_color("font_color"), "Evidence statuses have distinct colors")
	await capture("codex_evidence")
	screen._archive_scroll.ensure_control_visible(claim_button)
	await settle()
	await tap(claim_button)
	check(claim_body.visible and (claim_body.get_child(1) as Label).text.begins_with("SOURCE / "), "Evidence expands its full details and original source")
	await capture("codex_evidence_expanded")
	await tap(claim_button)
	check(not claim_body.visible, "Evidence can collapse again")
	for dimensions: Vector2i in [Vector2i(844,390), Vector2i(720,360), Vector2i(390,844)]:
		root.size = dimensions
		screen._set_section(&"characters")
		await settle()
		check(root.get_visible_rect().encloses(screen._archive_scroll.get_global_rect()), "Archive viewport fits mobile screen")
		for button: Button in screen._section_buttons.values():
			check(root.get_visible_rect().encloses(button.get_global_rect()), "All archive tabs fit mobile screen")
			check(button.size.y * root.get_final_transform().get_scale().y >= 47.5, "Archive tabs have mobile touch targets")
		await capture("codex_characters_%d" % dimensions.x)
		screen._open_character("jobert")
		await settle()
		check(screen._archive_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "Character details allow vertical scrolling when needed")
		await capture("codex_profile_%d" % dimensions.x)
		var discoveries_toggle: Button = screen._archive_body.find_child("Toggle_discoveries", true, false) as Button
		screen._archive_scroll.ensure_control_visible(discoveries_toggle)
		await settle()
		await tap(discoveries_toggle)
		check((screen._archive_body.find_child("Details_discoveries", true, false) as Control).visible, "Discoveries expand by tap at each mobile size")
		check(discoveries_toggle.size.y * root.get_final_transform().get_scale().y >= 47.5, "Expandable sections keep 48-pixel touch targets")
		screen._archive_scroll.scroll_vertical = 100000
		await settle()
		var last_action: Control = screen._archive_body.get_child(screen._archive_body.get_child_count()-1) as Control
		check(screen._archive_scroll.get_global_rect().encloses(last_action.get_global_rect()), "The final profile action is reachable at every mobile size")
		check(not screen.can_go_back() and screen.can_go_back(), "Mobile Back returns to cards, then allows normal exit")
	check(player.get_save_data() == before, "Archive browsing does not mutate player data, progress, rewards or locks")
	player.chapter_progress.erase(Survey.ID)
	screen._open_character("john")
	root.get_node("AuthService").session_changed.emit(false)
	check(screen._selected_character.is_empty() and not screen._story_snapshot.completed, "Account switch clears the previous dossier and discoveries")
	player.chapter_progress = original_chapters
	player.chapter_replay_progress = original_replay
	root.size = Vector2i(1280,720)
	screen._set_section(&"combat")
	await settle()
	check(screen._panes.visible and not screen._archive_scroll.visible, "Combat Intel retains the existing field guide")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await settle()
	# Load after autoload initialization (SceneTree --script compiles before it).
	Field = load("res://src/ui/screens/intel/codex_field_data.gd")
	var Enemy: GDScript = load("res://src/gameplay/enemy_base.gd")
	var player := root.get_node("PlayerManager")
	var progress: Dictionary = player.lesson_progress.duplicate(true)
	var locks: Dictionary = player.locked_stages.duplicate(true)
	var credits: int = player.credits
	var settings: Node = root.get_node("SettingsService")
	var original_motion: bool = settings.reduced_motion
	settings.reduced_motion = true
	var screen: Control = load("res://src/ui/screens/intel/codex_screen.tscn").instantiate()
	root.add_child(screen)
	await settle()
	await verify_archive(screen, player)
	check(screen._visible_ids.size() == 3, "All three defenders indexed")
	check(screen._current_unit_id == "base", "Basic Node is initial entry")
	check(screen._preview != null, "Entry includes reusable artwork preview")
	check(not screen._resource_label.visible, "Irrelevant currency readout hidden")
	check(screen._roster.get_parent().size.y > 200, "Roster has space for visible entries")
	await capture("codex_defender")
	await tap(screen._matchup_buttons[2])
	check(screen._matchup_detail.text.contains("STRONG AGAINST / Heavy"), "Native matchup tile tap reveals counter")
	await tap(screen._entry_buttons["scanner"])
	check(screen._current_unit_id == "scanner", "Native illustrated roster tap selects entry")
	check(screen._detail.modulate.a == 1.0, "Reduced motion skips entry fade")
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
			check(not screen._tactics_body.visible, "Tactics start collapsed")
			screen._toggle_tactics()
			check(screen._tactics_body.visible, "Tactics expand on demand")
			screen._toggle_tactics()
			for index: int in screen._matchup_rows.size():
				screen._select_matchup(index)
				check(screen._matchup_detail.text.contains(str(screen._matchup_rows[index].effect)), "Selecting matchup reveals actual effect")
			var angle: float = screen._preview.angle
			screen._rotate_preview()
			check(screen._preview.angle != angle, "Preview rotates without combat nodes")
			check(screen._preview.get_script().Glyphs.resource_path == "res://src/gameplay/preview/unit_glyphs.gd", "Specimen shares the gameplay renderer")
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
	for dimensions: Vector2i in [Vector2i(844, 390), Vector2i(960, 540)]:
		root.size = dimensions
		screen.load_topic("")
		await settle()
		check(screen._list_panel.visible and not screen._detail_panel.visible, "Mobile opens on collection")
		check(screen._roster.get_parent().size.y * root.get_final_transform().get_scale().y >= 96, "Combat list retains room for accessible rows below archive tabs")
		await capture("codex_collection_%dx%d" % [dimensions.x, dimensions.y])
		screen._pick_entry("scanner")
		await settle()
		check(screen._detail_panel.visible and not screen._list_panel.visible, "Entry opens separate mobile detail")
		check(root.get_visible_rect().encloses(screen._detail_panel.get_global_rect()), "Mobile details fit viewport")
		await capture("codex_detail_%dx%d" % [dimensions.x, dimensions.y])
		check(not screen.can_go_back() and screen._list_panel.visible, "Mobile Back returns to collection")
		check(screen.can_go_back(), "Second Back permits exit")
	check(player.locked_stages == locks, "Mobile page navigation leaves stage locks unchanged")
	check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("towers").is_empty(), "Codex previews never instantiate combat actors")
	check(player.lesson_progress == progress and player.credits == credits, "Browsing does not modify progression or credits")
	screen.queue_free()
	await process_frame
	settings.reduced_motion = original_motion
	print("[CODEX FIELD GUIDE] entries=%d failures=%d" % [entries, failures])
	quit(0 if failures == 0 else 1)
