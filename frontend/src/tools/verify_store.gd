extends SceneTree
## In-memory fixtures only. Off-tree wallet probe overrides the persistence hook.
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for index: int in 6:
		await process_frame

func capture(name: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func _run() -> void:
	await settle()
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "Game remains locked to either landscape direction")
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = "extends \"res://src/autoload/player_manager.gd\"\nvar writes: int = 0\nfunc _save_progress() -> void:\n\twrites += 1\n"
	check(probe_script.reload() == OK, "Wallet probe compiles")
	var probe: Node = probe_script.new()
	probe.credits = 9876
	probe.pvp_tokens = 0
	check(not probe.purchase_store_item("t1"), "Solo balance cannot fund store")
	probe.pvp_tokens = 1000
	check(not probe.purchase_store_item("unknown", 1), "Unknown item rejected")
	check(not probe.purchase_store_item("t1", 1), "Forged price rejected")
	check(not probe.purchase_store_item("t1", 0), "Zero price rejected")
	check(probe.purchase_store_item("t1"), "Canonical purchase succeeds")
	check(probe.pvp_tokens == 500 and probe.credits == 9876, "Only PvP wallet debited")
	check(probe.writes == 1 and probe.owns_store_item("t1"), "Ownership and debit saved once")
	check(not probe.purchase_store_item("t1"), "Duplicate cannot charge twice")
	check(not probe.purchase_store_item("t3"), "Insufficient PvP balance rejected")
	var snapshot: Dictionary = probe.get_save_data()
	probe.pvp_tokens = 99
	probe.apply_save_data(snapshot)
	check(probe.pvp_tokens == 500 and probe.owns_store_item("t1"), "Wallet and ownership round trip")
	snapshot.erase("pvp_tokens")
	probe.apply_save_data(snapshot)
	check(probe.pvp_tokens == 0 and probe.credits == 9876 and probe.owns_store_item("t1"), "Legacy save preserves Solo and ownership with zero tokens")
	for invalid: Variant in [-3, "900", true, {}, INF, NAN]:
		snapshot["pvp_tokens"] = invalid
		probe.apply_save_data(snapshot)
		check(probe.pvp_tokens == 0, "Invalid wallet normalizes to zero")
	probe.pvp_tokens = 50
	probe.reset_to_defaults()
	check(probe.pvp_tokens == 0, "Account reset clears token wallet")
	probe.free()
	var player: Node = root.get_node("PlayerManager")
	var original_tokens: int = player.pvp_tokens
	var original_credits: int = player.credits
	var original_items: Array = player.purchased_items.duplicate()
	player.pvp_tokens = 0
	player.credits = 9876
	player.purchased_items.clear()
	root.size = Vector2i(1280, 720)
	var screen: Control = load("res://src/ui/screens/store/store_screen.tscn").instantiate()
	root.add_child(screen)
	await settle()
	check(screen._wallet.text == "0 PVP TOKENS", "Header only displays PvP wallet")
	for label: Node in screen.find_children("*", "Label", true, false):
		check(not label.text.contains("9876") and not label.text.contains(" CR"), "No Solo balance or CR prices appear in store")
	check(screen._buy.disabled, "Purchase unavailable without tokens")
	check(screen._cards.size() == 3, "Featured gallery has three entries")
	check(screen._gallery.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Scrollbar hidden")
	await capture("store_desktop")
	await tap(screen._cards[1])
	check(screen._selected == "t2", "Native card selects preview")
	await tap(screen._tabs[1])
	check(screen._cards.size() == 8 and screen._selected == "p1", "All eight paid profiles are selectable")
	screen.on_enter({"item_id": "p8"})
	await settle()
	check(screen._category == "PROFILES" and screen._selected == "p8", "Avatar picker deep link selects the exact store item")
	check(screen._detail.get_child(1).get("displayed_id") == "p8", "Store preview uses the matching avatar portrait")
	await capture("store_avatar")
	await tap(screen._tabs[2])
	check(screen._cards.size() == 2 and screen._selected == "b1", "Borders category selectable")
	player.pvp_tokens = 1000
	screen.on_resume()
	await settle()
	check(not screen._buy.disabled, "Funded fixture enables confirmation")
	await tap(screen._buy)
	check(screen._modal.visible and screen._pending == "b1", "Native Buy opens confirmation")
	check(screen._modal_text.text.contains("300 PVP TOKENS"), "Quote uses PvP only")
	check(root.gui_get_focus_owner() == screen._cancel, "Cancel gets safe initial focus")
	check(screen._cancel.get_node(screen._cancel.focus_next) == screen._confirm, "Modal focus cycles within dialog")
	await capture("store_confirm")
	await tap(screen._cancel)
	check(not screen._modal.visible and player.pvp_tokens == 1000, "Cancel does not charge")
	player.purchased_items.append("b1")
	screen.on_resume()
	await settle()
	check(screen._buy.disabled and screen._buy.text == "OWNED", "Owned item cannot repurchase")
	player.pvp_tokens = 0
	for dimensions: Vector2i in [Vector2i(844, 390), Vector2i(960, 540)]:
		root.size = dimensions
		screen._select_category("FEATURED")
		await settle()
		screen._layout()
		await settle()
		check(screen._gallery.visible and not screen._detail_scroll.visible, "Mobile gallery is separate")
		check(root.get_visible_rect().encloses(screen._wallet.get_global_rect()), "Mobile wallet fits")
		for tab: Button in screen._tabs:
			check(root.get_visible_rect().encloses(tab.get_global_rect()), "Mobile tab fits")
		await capture("store_gallery_%dx%d" % [dimensions.x, dimensions.y])
		await tap(screen._cards[0])
		check(not screen._gallery.visible and screen._detail_scroll.visible, "Mobile selection opens detail page")
		check(root.get_visible_rect().encloses(screen._detail_scroll.get_global_rect()), "Mobile detail viewport fits")
		await capture("store_detail_%dx%d" % [dimensions.x, dimensions.y])
		check(not screen.can_go_back() and screen._gallery.visible, "Mobile Back returns to items first")
		player.pvp_tokens = 1000
		screen._select_item("t1")
		await settle()
		screen._open_modal()
		await settle()
		check(root.get_visible_rect().encloses(screen._modal_card.get_global_rect()), "Mobile confirmation fits viewport")
		await capture("store_confirm_%dx%d" % [dimensions.x, dimensions.y])
		player.pvp_tokens = 0
		screen._on_confirm()
		await settle()
		check(not player.owns_store_item("t1") and screen._buy.disabled, "Stale confirmation cannot overspend")
	check(player.credits == 9876, "Browsing never changes Solo wallet")
	screen.queue_free()
	await settle()
	player.pvp_tokens = original_tokens
	player.credits = original_credits
	player.purchased_items.assign(original_items)
	print("[STORE] failures=%d" % failures)
	quit(0 if failures == 0 else 1)
