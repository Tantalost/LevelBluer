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
	var visible_rect: Rect2 = control.get_global_rect().intersection(root.get_visible_rect())
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	check(visible_rect.has_area(), "Tapped control has a visible touch region")
	var point: Vector2 = visible_rect.get_center()
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
	check(screen._library_home and screen._library_buttons.size() == 3, "Codex opens its library index")
	await settle()
	await capture("codex_library_home")
	await tap(screen._library_buttons[&"characters"])
	check(not screen._library_home and screen._character_buttons.size() == 3, "Library card opens character collection")
	var fresh: Dictionary = Field.story_snapshot({})
	check(Field.discovery_progress(fresh) == {"found":0,"total":9}, "Fresh archive starts at zero discovered observations")
	screen._set_section(&"evidence")
	check(not screen._record_buttons.has("client_claim"), "Undiscovered records have no searchable spoiler content")
	screen._filter_archive("client")
	check(screen._record_buttons.is_empty(), "Search cannot reveal an undiscovered record")
	screen._open_record("client_claim")
	check(screen._selected_record.is_empty(), "An undiscovered reading page cannot be opened directly")
	screen._filter_archive("")
	check((screen._archive_body.find_child("CollectionSummary", true, false) as Label).text.contains("0 of 9"), "Collection summary reflects the fresh save")
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
	check(screen._archive_body.find_child("ReadingPage", true, false) != null, "Character opens a readable reference page")
	await capture("codex_eric")
	screen._refresh_archive()
	check(screen._selected_character == "eric", "Asset/progress refresh preserves selected profile")
	check(not screen.can_go_back() and screen._selected_character.is_empty(), "Profile Back returns to Characters without leaving Codex")
	screen._archive_search.text_changed.emit("jobert")
	check(screen._character_buttons.size() == 1 and screen._character_buttons.has("jobert"), "Typing a name filters the character collection")
	screen._open_character("jobert")
	# Use the saved authored record, so the reader returns to the actual source profile.
	var jobert_records: Array = Field.character("jobert", complete).interactions
	if not jobert_records.is_empty():
		screen._open_record(str(jobert_records[0].id))
		check(not screen._selected_record.is_empty(), "A character discovery opens its evidence reader")
		check(not screen.can_go_back() and screen._selected_character == "jobert", "Reader Back returns to its character profile")
	check(not screen.can_go_back() and screen._character_buttons.size() == 1, "Returning to collection preserves the search")
	await tap(screen._section_buttons[&"evidence"])
	check(screen._section == &"evidence", "Evidence tab switches by tap")
	check(Field.observations(screen._story_snapshot)[3].status == "Unverified", "Completing Chapter 1 never verifies Eric's claim")
	check((screen._archive_body.find_child("CollectionSummary", true, false) as Label).text.contains("9 of 9"), "Completed archive displays all nine discoveries")
	check(screen._record_buttons.size() == 9, "All discovered evidence has an entry card")
	screen._filter_archive("client")
	check(screen._record_buttons.has("client_claim") and not screen._record_buttons.has("offer"), "Search filters the discovered record text")
	screen._filter_archive("no matching record")
	check(screen._record_buttons.is_empty(), "Unmatched query has no stale cards")
	screen._filter_archive("")
	var claim_button: Button = screen._record_buttons["client_claim"]
	check(claim_button.accessibility_name.contains("Unverified"), "Status is conveyed in words, not color alone")
	await capture("codex_evidence")
	await settle()
	screen._archive_scroll.ensure_control_visible(claim_button)
	await settle()
	await tap(claim_button)
	check(screen._selected_record == "client_claim" and screen._archive_body.find_child("ReadingPage", true, false) != null, "Evidence opens a dedicated reading page")
	var page: PanelContainer = screen._archive_body.find_child("ReadingPage", true, false) as PanelContainer
	check((page.get_child(0).get_child(2) as Label).text.contains(str(Field.observations(complete)[3].source)), "Reading page retains the original source")
	await capture("codex_evidence_expanded")
	check(not screen.can_go_back() and screen._selected_record.is_empty(), "Evidence Back returns to the collection")
	for dimensions: Vector2i in [Vector2i(844,390), Vector2i(720,360), Vector2i(390,844)]:
		root.size = dimensions
		screen._show_library()
		await settle()
		await capture("codex_library_%d" % dimensions.x)
		for card: Button in screen._library_buttons.values():
			check(card.get_global_rect().end.x <= root.get_visible_rect().end.x, "Library cards fit phone width")
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
		check(not screen.can_go_back() and not screen.can_go_back() and screen._library_home and screen.can_go_back(), "Mobile Back returns to cards, library, then permits exit")
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

func completed_archive(number: int) -> Dictionary:
	var chapter: GDScript = Field.chapter_definition(number)
	var state: Dictionary = chapter.fresh()
	state.phase = "done"
	state.sealed = true
	state.completed = true
	match number:
		2:
			state.flags = ["domain","wording","signature"]
			state.domains = ["fake"]
			state.headers = ["From","Reply-To","Subject"]
		3:
			state.revealed = ["payout"]
			state.expanded = ["payout"]
			state.hotspots = ["domain","http","security"]
			state.reviewed = true
		4:
			state.timeline_order = chapter.ORDER.duplicate()
			state.timeline_checked = ["prize"]
			state.connections = chapter.PAIRS.keys()
			state.minutes_draft = "2"
			state.event_draft = "survey confirmation reply"
			state.notes = ["prize"]
			state.claimed = true
		5:
			for key: String in ["briefed","theory_done","final_matched","admitted","comic_checked","animatic_done","aftermath_done","lights_done"]: state[key] = true
			state.solved = [0,1,2,3]
			state.admission_step = chapter.ADMISSION.size() - 1
			state.comic_order = chapter.COMIC_ORDER.duplicate()
			state.animatic_step = 5
			state.aftermath_step = chapter.AFTERMATH.size() - 1
	return Field.story_snapshot(state, number)

func verify_later_archives(screen: Control, player: Node) -> void:
	var original: Dictionary = player.chapter_progress.duplicate(true)
	var original_replays: Dictionary = player.chapter_replays.duplicate(true)
	player.chapter_progress = {}
	screen._archive_session_changed(false)
	screen._select_chapter(5)
	check(screen._chapter == 1, "Locked chapter cannot be selected or reveal its archive")
	for number: int in range(2, 6):
		var chapter: GDScript = Field.chapter_definition(number)
		var fresh: Dictionary = Field.story_snapshot({}, number)
		check(Field.discovery_progress(fresh).found == 0, "Fresh chapter %d leaks no observations" % number)
		for item: Dictionary in Field.observations(fresh):
			check(item.title == "Undiscovered observation" and item.people.is_empty(), "Unknown chapter records do not reveal titles or implicated people")
		var completed: Dictionary = completed_archive(number)
		check(completed.completed, "Completed archive fixture satisfies chapter validation")
		var progress: Dictionary = Field.discovery_progress(completed)
		check(progress.found == progress.total, "Every observation is obtainable in chapter %d" % number)
		for record: Dictionary in Field.chapter_records(fresh):
			var probe: Dictionary = fresh.duplicate(true)
			if record.has("after_beat"):
				probe.beat = int(record.after_beat)
				var current: Array[Dictionary] = Field.observations(probe)
				for item: Dictionary in current:
					if item.id == record.id: check(not item.discovered, "Current dialogue cannot reveal its unfinished observation")
				probe.beat += 1
			else:
				if record.has("value"): probe[str(record.field)] = [record.value]
				else: probe[str(record.field)] = true
			for item: Dictionary in Field.observations(probe):
				if item.id == record.id: check(item.discovered, "Exact saved discovery gate unlocks " + str(record.id))
		player.chapter_progress[chapter.ID] = completed.duplicate(true)
		player.chapter_replays[chapter.ID] = chapter.fresh()
		screen._select_chapter(number)
		screen._set_section(&"evidence")
		check(screen._story_snapshot.completed, "A fresh replay never resets the original chapter's Codex")
		var before: Dictionary = player.get_save_data()
		root.size = Vector2i(844,390)
		await settle()
		await capture("codex_chapter%d_evidence" % number)
		for button: Button in screen._chapter_buttons:
			check(button.size.y * root.get_final_transform().get_scale().y >= 47.5, "Chapter selector remains touch-sized")
			check(button.get_global_rect().end.x <= root.get_visible_rect().end.x, "Chapter selector stays within the viewport")
		var records: Array[Dictionary] = Field.observations(completed)
		var toggle: Button = screen._record_buttons[str(records.back().id)]
		screen._archive_scroll.ensure_control_visible(toggle)
		await settle()
		await tap(toggle)
		check(screen._selected_record == str(records.back().id), "Later evidence opens with a touch")
		await capture("codex_chapter%d_expanded" % number)
		screen._set_section(&"characters")
		await settle()
		for id: String in Field.character_ids(completed):
			screen._open_character(id)
			check(not Field.character(id, completed).is_empty(), "Every chapter character has a readable file")
		check(player.get_save_data() == before, "Later archive browsing is read-only")
	var unresolved: Dictionary = completed_archive(5)
	unresolved.admitted = false
	unresolved.aftermath_done = false
	unresolved = Field.story_snapshot(unresolved, 5)
	player.chapter_progress[Field.Hearing.ID] = unresolved
	screen._set_section(&"evidence")
	check(not screen._record_buttons.has("c5_admission"), "Matching the typo cannot reveal the later admission")
	check(not screen._record_buttons.has("c5_outcome"), "Unfinished hearing cannot reveal its punishment")
	var invalid: Dictionary = Field.story_snapshot({"admitted":true,"completed":true,"aftermath_done":true}, 5)
	check(Field.discovery_progress(invalid).found == 0, "Malformed flags do not fabricate a resolved hearing")
	player.chapter_progress = {}
	screen._archive_session_changed(false)
	check(screen._chapter == 1 and screen._selected_character.is_empty() and screen._story_snapshot.beat == 0, "Account reset removes later chapter selections and discoveries")
	player.chapter_progress = original
	player.chapter_replays = original_replays
	screen._set_section(&"combat")
	root.size = Vector2i(1280,720)
	await settle()

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
	await verify_later_archives(screen, player)
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
		check(not screen.can_go_back() and screen._library_home and screen.can_go_back(), "Second Back returns to library, then permits exit")
	check(player.locked_stages == locks, "Mobile page navigation leaves stage locks unchanged")
	check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("towers").is_empty(), "Codex previews never instantiate combat actors")
	check(player.lesson_progress == progress and player.credits == credits, "Browsing does not modify progression or credits")
	screen.queue_free()
	await process_frame
	settings.reduced_motion = original_motion
	print("[CODEX FIELD GUIDE] entries=%d failures=%d" % [entries, failures])
	quit(0 if failures == 0 else 1)
