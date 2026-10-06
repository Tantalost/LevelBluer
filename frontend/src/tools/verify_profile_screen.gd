extends SceneTree
## Only in-memory fixtures; no server calls, rewards, purchases or saves.
var failures := 0
var auth: Node
var player: Node
var screen: Control

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 10:
		await process_frame

func capture(label: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/profile_" + label + ".png")

func fresh() -> void:
	auth._token = ""
	auth._signed_in = false
	auth._display_name = "COMMANDER_X"
	auth._points = 0
	auth._mastery = {}
	auth._completed_module_ids = []
	auth._pre_test_completed = false
	auth._bkt_queue.clear()
	player.cleared_stages = {}
	player.lesson_progress = {}
	player.completed_lessons.clear()
	player.locked_stages = {}
	player.mastery_matrix = {"phishing": 0.1}
	player.credits = 229

func fingerprint() -> String:
	return JSON.stringify([auth._mastery, auth._points, auth._completed_module_ids, player.cleared_stages,
		player.lesson_progress, player.completed_lessons, player.credits, player.tech_ranks])

func _run() -> void:
	auth = root.get_node("AuthService")
	player = root.get_node("PlayerManager")
	fresh()
	screen = load("res://src/ui/screens/profile/profile_screen.tscn").instantiate()
	root.add_child(screen)
	screen.on_enter({})
	await settle()
	var before := fingerprint()
	await verify_avatars()
	check(screen.get_node("CRTOverlay").visible, "Permanent CRT shell")
	check(screen._dossier.next.route == &"lessons", "Fresh account points to lessons, not locked gameplay")
	check(screen._dossier.strongest.is_empty(), "Default BKT prior is not shown as assessed")
	check(screen._dossier.milestones.all(func(m: Dictionary) -> bool: return not m.earned), "Fresh milestones unearned")
	check(not screen._details_content.get_parent().visible, "Personal details collapsed by default")
	await capture("fresh")
	screen._toggle_details()
	check(screen._details_content.get_parent().visible, "Personal details expandable")
	screen._toggle_details()
	check(fingerprint() == before, "Inspecting profile is read only")
	auth._completed_module_ids = ["mod_01"]
	player.lesson_progress = {"mod_01": 2}
	screen._refresh()
	check(screen._dossier.next.title == "CONTINUE YOUR TRAINING", "Passed pretest recommends next lessons")
	check(root.get_node("Router").SCREENS.has(screen._dossier.next.route), "Suggested lesson route exists")
	auth._points = 1250
	auth._mastery = {"Phishing": 0.85, "Smishing": 0.35, "Vishing": 0.6}
	auth._completed_module_ids = ["mod_01"]
	player.lesson_progress = {"mod_01": 6, "mod_02": 2}
	player.completed_lessons.assign(["mod_01"])
	player.cleared_stages = {"mod_01:1": true, "mod_01:3": true}
	player.max_stage_cleared_by_module = {"mod_01": 3}
	screen.on_resume()
	await settle()
	check(screen._dossier.next.route == &"stage_select", "Available stage gives Deploy shortcut")
	check(screen._dossier.strongest.name == "Phishing", "Highest assessed mastery")
	check(screen._dossier.practice.name == "Smishing", "Practice focus uses lowest assessed topic")
	check(root.get_node("Router").SCREENS.has(screen._dossier.next.route), "Suggested deployment route exists")
	check(screen._snapshot.stage_done == 2 and screen._snapshot.lesson_done == 8, "Exact completion totals")
	check(screen._dossier.milestones[0].earned and screen._dossier.milestones[1].earned, "Recorded milestones earned")
	await capture("overview")
	auth._signed_in = true
	auth._participant_code = "profile-fixture"
	auth._bkt_queue.assign([{"participant_code": "profile-fixture", "skill_id": "smishing"}])
	player.mastery_matrix["smishing"] = 0.42
	screen._refresh()
	check(screen._dossier.practice.pending and is_equal_approx(float(screen._dossier.practice.value), 0.42), "Pending owned assessment uses local estimate and sync label")
	auth._signed_in = false
	auth._bkt_queue.clear()
	screen._refresh()
	(screen._briefing.get_parent() as ScrollContainer).scroll_vertical = 10000
	await settle()
	await capture("milestones")
	(screen._briefing.get_parent() as ScrollContainer).scroll_vertical = 0
	for dimensions in [Vector2i(960, 600), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		if dimensions.x == 844:
			for child in screen.get_children():
				if child is SafeAreaContainer:
					var units := 1.0 / root.get_final_transform().get_scale().x
					child.add_theme_constant_override("margin_left", 24 + ceili(32 * units))
					child.add_theme_constant_override("margin_right", 24 + ceili(24 * units))
					child.add_theme_constant_override("margin_bottom", 24 + ceili(12 * units))
			await settle()
		check(screen._body.get_global_rect().end.x <= root.get_visible_rect().end.x, "No horizontal viewport overflow")
		for action in screen._actions:
			check(action.size.y * root.get_final_transform().get_scale().y >= 47.9, "48px physical touch targets")
		await capture("%dx%d" % [dimensions.x, dimensions.y])
	auth._display_name = "COMMANDER WITH A VERY LONG DISPLAY NAME"
	auth._full_name = "A long full name for the personal account record"
	auth._email = "a.long.account.name@example.invalid"
	auth._section = "A very long section identifier for testing"
	screen._refresh()
	screen._toggle_details()
	await settle()
	await capture("long_identity")
	check(screen._body.get_global_rect().end.x <= root.get_visible_rect().end.x, "Long identity does not overflow horizontally")
	auth._points = 9000
	for module in screen._snapshot.modules:
		player.lesson_progress[module.id] = module.total
	for id in range(1, 11):
		player.cleared_stages[player.stage_progress_key("mod_01", id)] = true
	screen._refresh()
	check(screen._snapshot.max_rank, "Commander max rank state")
	check(screen._dossier.milestones.all(func(m: Dictionary) -> bool: return m.earned), "All milestones earned on full completion")
	check(screen._dossier.next.route == &"codex", "Completed player with low mastery gets review suggestion")
	auth._mastery = {"Phishing": 0.9, "Smishing": 0.8}
	screen._refresh()
	check(screen._dossier.next.route == &"progress", "Full completion routes to Progress")
	fresh()
	screen._session_changed(false)
	await settle()
	check(not screen._details_open and screen._dossier.strongest.is_empty(), "Account change clears previous identity detail and mastery")
	for action in screen._actions:
		check(action.pressed.get_connections().size() > 0, "Visible shortcuts have handlers")
	before = fingerprint()
	screen.on_exit()
	check(not screen.visible, "Exit hides profile")
	screen.on_resume()
	check(screen.visible, "Resume shows profile")
	check(fingerprint() == before, "Resume does not change progression")
	screen.queue_free()
	await settle()
	print("PROFILE_CHECKS failures=" + str(failures))
	quit(0 if failures == 0 else 1)

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func verify_avatars() -> void:
	var portraits: GDScript = load("res://src/ui/screens/profile/avatar_portrait.gd")
	var assets: Node = root.get_node("AssetManager")
	var versions: Dictionary = {"byte_bot": "1791177053", "cyber_cat": "1791177071", "commander": "1791177054", "operative": "1791177072", "neon_fox": "1791177084", "circuit_owl": "1791177053", "glitch_ghost": "1791177069", "pixel_bunny": "1791177053", "cyber_axolotl": "1791177067", "masked_raccoon": "1791177068"}
	var remote_count: int = 0
	for asset: Dictionary in assets._ui_catalog():
		var asset_id: String = str(asset.asset_id)
		if not asset_id.begins_with("ui_avatar_"):
			continue
		var avatar_file: String = asset_id.trim_prefix("ui_avatar_")
		remote_count += 1
		check(str(asset.cloudinary_url) == "https://res.cloudinary.com/nfd5bhkz/image/upload/v%s/%s_v1.png" % [str(versions.get(avatar_file, "")), avatar_file], "Exact supplied avatar URL: " + avatar_file)
	check(remote_count == 10, "All ten avatars registered for cached downloads")
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nvar writes: int = 0\nfunc _save_progress() -> void:\n\twrites += 1\n"
	check(probe_script.reload() == OK, "Avatar persistence probe compiles")
	var probe: Node = probe_script.new()
	var free_count: int = 0
	var paid_count: int = 0
	for avatar: Dictionary in portraits.ENTRIES:
		check(assets._bundled_path("ui_avatar_" + str(avatar.file)).is_empty(), "Avatar is remote-only: " + str(avatar.id))
		if int(avatar.price) == 0:
			free_count += 1
			check(probe.can_use_avatar(str(avatar.id)), "Free avatar requires no purchase")
		else:
			paid_count += 1
			check(not probe.select_avatar(str(avatar.id)), "Unowned avatar cannot equip")
			check(int(probe.store_item(str(avatar.id)).price) == int(avatar.price), "Picker and store share price")
	check(free_count == 2 and paid_count == 8, "Exactly two free and eight paid portraits")
	check(not probe.select_avatar("not_real"), "Unknown IDs rejected")
	probe.credits = 9000
	probe.pvp_tokens = 0
	check(not probe.purchase_store_item("p1"), "Solo credits cannot buy an avatar")
	check(probe.select_avatar("cyber_cat") and probe.writes == 1, "Free selection persists once")
	probe.pvp_tokens = 800
	check(probe.purchase_store_item("p1") and probe.pvp_tokens == 0, "PvP purchase unlocks legacy Commander ID")
	check(probe.current_avatar_id() == "cyber_cat", "Purchase does not auto-equip")
	check(probe.select_avatar("p1"), "Purchased avatar can equip")
	var saved: Dictionary = probe.get_save_data()
	probe.apply_save_data(saved)
	check(probe.current_avatar_id() == "p1", "Selection and ownership survive reload")
	saved["selected_avatar_id"] = "p8"
	probe.apply_save_data(saved)
	check(probe.current_avatar_id() == "byte_bot", "Unowned saved selection falls back to free avatar")
	saved.erase("selected_avatar_id")
	probe.apply_save_data(saved)
	check(probe.can_use_avatar("p1") and probe.current_avatar_id() == "byte_bot", "Legacy purchase survives avatar migration")
	probe.apply_save_data({})
	check(not probe.can_use_avatar("p1"), "Missing ownership cannot leak across account loads")
	probe.free()
	var original_id: String = player.selected_avatar_id
	var original_items: Array = player.purchased_items.duplicate()
	player.selected_avatar_id = "byte_bot"
	player.purchased_items.clear()
	player.avatar_changed.emit()
	var legacy: TextureRect = TextureRect.new()
	root.add_child(legacy)
	root.get_node("AssetManager").bind_texture(legacy, "ui_pfp")
	check(legacy.get("displayed_id") == "byte_bot", "Legacy header binding uses uniform avatar")
	var preview: TextureRect = portraits.new()
	preview.call("show_avatar", "byte_bot")
	root.add_child(preview)
	var original_texture: Texture2D = assets.get_texture("ui_avatar_byte_bot")
	assets._textures["ui_avatar_byte_bot"] = null
	assets.sync_finished.emit(false)
	check(legacy.texture == null and preview.texture == null and preview.material == null, "Empty cache uses native avatar placeholder without a missing resource")
	check(player.current_avatar_id() == "byte_bot", "Missing art preserves selected avatar")
	var fixture_image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	fixture_image.fill(Color.CYAN)
	var downloaded_texture: ImageTexture = ImageTexture.create_from_image(fixture_image)
	assets._textures["ui_avatar_byte_bot"] = downloaded_texture
	assets.sync_finished.emit(false)
	check(legacy.texture == downloaded_texture and preview.texture == downloaded_texture, "Partial asset sync refreshes headers and picker/store-style previews")
	check(player.current_avatar_id() == "byte_bot", "Asset refresh never changes equipped ID")
	assets._textures["ui_avatar_byte_bot"] = original_texture
	assets.sync_finished.emit(true)
	preview.free()
	assets.sync_finished.emit(false)
	var picker: Control = screen._avatar_picker
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		(screen._identity.get_parent() as ScrollContainer).scroll_vertical = 0
		await settle()
		await tap(screen._avatar_button)
		check(picker.visible and picker._buttons.size() == 10, "Native profile-picture tap opens ten options")
		for button: Button in picker._buttons:
			check(root.get_visible_rect().encloses(button.get_global_rect()), "Landscape avatar cell fits")
		check(root.get_visible_rect().encloses(picker._action.get_global_rect()), "Landscape confirm fits")
		await capture("avatars_%dx%d" % [dimensions.x, dimensions.y])
		await tap(picker._buttons[1])
		check(picker.selected_id == "cyber_cat" and player.current_avatar_id() == "byte_bot", "Preview alone never equips")
		await tap(picker._cancel)
		check(not picker.visible and player.current_avatar_id() == "byte_bot", "Cancel preserves equipped avatar")
		await tap(screen._avatar_button)
		await tap(picker._buttons[2])
		check(picker._action.text == "VIEW IN STORE" and picker._state.text.contains("800 PVP TOKENS"), "Locked preview shows store price")
		await capture("avatars_locked_%dx%d" % [dimensions.x, dimensions.y])
		check(not screen.can_go_back() and not picker.visible, "Back dismisses chooser before leaving profile")
	# Existing selected avatar can be confirmed without a save; mutation is tested above on the off-tree probe.
	picker.present()
	await tap(picker._action)
	check(not picker.visible, "Confirm current selection closes modal")
	var store_requests: Array[String] = []
	picker.store_requested.disconnect(screen._avatar_store)
	var capture_store: Callable = func(id: String) -> void: store_requests.append(id)
	picker.store_requested.connect(capture_store)
	picker.present()
	await tap(picker._buttons[9])
	await tap(picker._action)
	check(store_requests == ["p8"] and player.current_avatar_id() == "byte_bot", "View in Store requests exact locked item without equipping")
	picker.dismiss()
	picker.store_requested.disconnect(capture_store)
	picker.store_requested.connect(screen._avatar_store)
	player.selected_avatar_id = "cyber_cat"
	player.avatar_changed.emit()
	check(legacy.get("displayed_id") == "cyber_cat", "Bound headers update immediately from selection signal")
	check(screen.find_child("AvatarImage", true, false).get("displayed_id") == "cyber_cat", "Profile portrait refreshes from same signal")
	picker.present()
	screen._session_changed(false)
	await settle()
	check(not picker.visible, "Account switch dismisses stale chooser")
	legacy.queue_free()
	await settle()
	player.selected_avatar_id = original_id
	player.purchased_items.assign(original_items)
	player.avatar_changed.emit()
	root.size = Vector2i(1280, 720)
	await settle()
