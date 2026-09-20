extends BaseScreen
## Armory -> tower selector / connected research network / upgrade inspector.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const OrbitNode = preload("res://src/ui/screens/deploy/tech_orbit_node.gd")
const ResearchCard = preload("res://src/ui/screens/deploy/tower_research_card.gd")
const Portrait = preload("res://src/ui/screens/deploy/research_portrait.gd")
const TRACK_COLORS := {"skill": Color("8dbfda"), "stats": Color("85d9c3"), "capacity": Color("e5c88a"), "evolution": Color("c5afd7")}
const TRACK_ORDER: Array[String] = ["skill", "stats", "capacity", "evolution"]
const TOWER_ORDER: Array[String] = ["base", "scanner", "sandbox"]
const TITLES := {"skill": "INSPECTION", "stats": "OUTPUT", "capacity": "DEPLOY", "evolution": "EVOLUTION"}

var _back_button: Button
var _title_label: Label
var _coins_value: Label
var _selection_screen: ScrollContainer
var _selection_row: HBoxContainer
var _tree_screen: HBoxContainer
var _tree_canvas: Control
var _node_layer: Control
var _trace_layer: Control
var _empty_hint: Label
var _switcher: VBoxContainer
var _inspector: VBoxContainer
var _detail_title: Label
var _detail_body: Label
var _detail_state: Label
var _detail_cost: Label
var _detail_icon: Control
var _purchase_button: Button
var _tutorial_overlay: TutorialOverlay
var _active_tower := ""
var _selected_track := ""
var _selected_rank := 0
var _capacity_rank1_button: Button
var _root_button: Button
var _track_nodes: Dictionary = {}
var _select_cards: Dictionary = {}
var _font := 28
var _touch := 64.0
var _refresh_queued := false

func _ready() -> void:
	var shell := UI.shell(self, "NODE ARMORY", _on_back_pressed)
	_back_button = shell.back
	_title_label = shell.title
	_coins_value = UI.label("", 28, UI.GOLD)
	_coins_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.get_parent().add_child(_coins_value)
	_selection_screen = ScrollContainer.new()
	_selection_screen.size_flags_vertical = SIZE_EXPAND_FILL
	_selection_screen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.layout.add_child(_selection_screen)
	var intro := UI.column(_selection_screen, 20)
	intro.size_flags_horizontal = SIZE_EXPAND_FILL
	intro.add_child(UI.label("RESEARCH DIVISION / Select a tower to develop its abilities.", 28, UI.MUTED))
	_selection_row = HBoxContainer.new()
	_selection_row.add_theme_constant_override("separation", 20)
	intro.add_child(_selection_row)
	intro.add_child(UI.label("EVOLUTION PATH   /   BASIC NODE  >  SCANNER  >  SANDBOX", 26, UI.TEAL))
	_tree_screen = HBoxContainer.new()
	_tree_screen.add_theme_constant_override("separation", 16)
	_tree_screen.size_flags_vertical = SIZE_EXPAND_FILL
	shell.layout.add_child(_tree_screen)
	_build_tree_shell()
	get_viewport().size_changed.connect(_on_resized)
	AuthService.session_changed.connect(_session_changed)
	_show_selection()
	_apply_scale()

func _build_tree_shell() -> void:
	_switcher = UI.scroll_column(_tree_screen)
	_switcher.get_parent().size_flags_horizontal = SIZE_FILL
	_switcher.get_parent().custom_minimum_size.x = 146
	var center := UI.column(_tree_screen, 8)
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.62
	center.add_child(UI.label("SKILL NETWORK", 26, UI.TEAL))
	var scroll := ScrollContainer.new()
	scroll.name = "NetworkScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	_tree_canvas = Control.new()
	_tree_canvas.custom_minimum_size = Vector2(500, 650)
	_tree_canvas.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_tree_canvas)
	_trace_layer = Control.new()
	_trace_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_trace_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tree_canvas.add_child(_trace_layer)
	_node_layer = Control.new()
	_node_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_node_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tree_canvas.add_child(_node_layer)
	_empty_hint = UI.label("This tower is online.\nUpgrade tracks are coming soon.", 30, UI.MUTED)
	_empty_hint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tree_canvas.add_child(_empty_hint)
	center.add_child(UI.label("HALO: AVAILABLE   /   FILLED: OWNED   /   LOCK: PREREQUISITE", 22, UI.MUTED))
	var panel := UI.panel(_tree_screen, Color("14252c"))
	panel.custom_minimum_size.x = 340
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.38
	var layout := UI.column(panel, 14)
	_inspector = UI.scroll_column(layout)
	var emblem := OrbitNode.new()
	emblem.is_root = true
	emblem.caption = ""
	emblem.state = "BUY"
	emblem.custom_minimum_size = Vector2(112, 116)
	emblem.size_flags_horizontal = SIZE_SHRINK_CENTER
	emblem.mouse_filter = MOUSE_FILTER_IGNORE
	emblem.focus_mode = FOCUS_NONE
	_inspector.add_child(emblem)
	_detail_icon = emblem
	_detail_title = UI.label("", 36)
	_inspector.add_child(_detail_title)
	_detail_body = UI.label("", 28, UI.TEXT)
	_inspector.add_child(_detail_body)
	_detail_state = UI.label("", 28, UI.TEAL)
	_inspector.add_child(_detail_state)
	_detail_cost = UI.label("", 30, UI.GOLD)
	layout.add_child(_detail_cost)
	_purchase_button = UI.button("SELECT AN UPGRADE", _purchase_selected, true)
	layout.add_child(_purchase_button)
	_tree_canvas.resized.connect(_queue_tree_refresh)

func _session_changed(_signed_in: bool) -> void:
	_show_selection()

func _on_resized() -> void:
	_apply_scale()
	_queue_tree_refresh()

func _queue_tree_refresh() -> void:
	if _refresh_queued or not _tree_screen.visible:
		return
	_refresh_queued = true
	_rebuild_tree.call_deferred()

func _apply_scale() -> void:
	var ratio := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	_font = maxi(28, ceili(16 / ratio))
	_touch = maxf(64, ceilf(48 / ratio))
	for button in [_back_button, _purchase_button]:
		button.add_theme_font_size_override("font_size", _font)
		button.custom_minimum_size.y = _touch
	_back_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_back_button.custom_minimum_size.x = _font * 5.5
	_coins_value.add_theme_font_size_override("font_size", _font)
	_detail_title.add_theme_font_size_override("font_size", _font + 8)
	_detail_body.add_theme_font_size_override("font_size", _font)
	_detail_state.add_theme_font_size_override("font_size", _font)
	_refresh_selection_cards()
	if not _active_tower.is_empty():
		_build_switcher()

func on_enter(_args: Dictionary) -> void:
	visible = true
	_refresh_coins_label()
	_refresh_selection_cards()
	_apply_tutorial_coach()

func on_resume() -> void:
	visible = true
	_refresh_coins_label()
	_refresh_selection_cards()
	if not _active_tower.is_empty():
		if not _is_tower_selectable(_active_tower):
			_show_selection()
		else:
			_rebuild_tree()
	_apply_tutorial_coach()

func on_exit() -> void:
	visible = false

func can_go_back() -> bool:
	if Router.is_tutorial:
		return false
	if _tree_screen.visible:
		_show_selection()
		return false
	return true

func _on_back_pressed() -> void:
	if Router.is_tutorial:
		return
	if _tree_screen.visible:
		_show_selection()
	else:
		Router.request_back()

func _show_selection() -> void:
	_active_tower = ""
	_selection_screen.visible = true
	_tree_screen.visible = false
	_title_label.text = "NODE ARMORY"
	_back_button.text = "< BACK"
	_refresh_selection_cards()
	_refresh_coins_label()

func _open_tower(tower_id: String) -> void:
	if not _is_tower_selectable(tower_id) or (Router.is_tutorial and tower_id != "base"):
		return
	_active_tower = tower_id
	_selected_track = ""
	_selected_rank = 0
	_selection_screen.visible = false
	_tree_screen.visible = true
	_title_label.text = TowerBase.display_name_for(tower_id).to_upper() + " / UPGRADES"
	_back_button.text = "< NODES"
	_refresh_coins_label()
	_build_switcher()
	await get_tree().process_frame
	if is_inside_tree():
		_rebuild_tree()

func _is_tower_selectable(tower_id: String) -> bool:
	if tower_id == "base":
		return true
	if tower_id == "scanner":
		return PlayerManager.tech_rank("base", "evolution") >= 1 or PlayerManager.is_tower_unlocked(tower_id)
	if tower_id == "sandbox":
		return PlayerManager.tech_rank("base", "evolution") >= 2 or PlayerManager.is_tower_unlocked(tower_id)
	return false

func _lock_reason(tower_id: String) -> String:
	return "LOCKED / BASIC NODE\nEVOLUTION RANK %d" % (1 if tower_id == "scanner" else 2)

func _refresh_selection_cards() -> void:
	if _selection_row == null:
		return
	UI.clear(_selection_row)
	_select_cards.clear()
	for id in TOWER_ORDER:
		var data := ContentDB.get_tower(id)
		var card := ResearchCard.new()
		card.tower_id = id
		card.unlocked = _is_tower_selectable(id)
		card.accent = _tower_color(id)
		card.heading = TowerBase.display_name_for(id).to_upper()
		card.role = str(data.get("role", "DPS"))
		card.cost = int(data.get("cost", 0))
		var bonus := PlayerManager.stats_bonus_for(id)
		card.damage = int(data.get("damage", 0)) + int(bonus.get("damage", 0))
		card.rate = float(data.get("fire_rate", 0)) + float(bonus.get("fire_rate", 0))
		card.slots = PlayerManager.tower_capacity(id)
		card.total_ranks = 0
		for track in ContentDB.tech_track_ids(id):
			card.total_ranks += ContentDB.tech_max_rank(id, track)
			card.ranks += PlayerManager.tech_rank(id, track)
		card.requirement = _lock_reason(id)
		card.body_font = _font
		card.custom_minimum_size = Vector2(0, 480 + (_font - 28) * 8)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.pressed.connect(_open_tower.bind(id))
		_selection_row.add_child(card)
		_select_cards[id] = card

func _tower_color(id: String) -> Color:
	return {"base": UI.TEAL, "scanner": Color("72b8ed"), "sandbox": Color("b997e8")}.get(id, UI.TEAL)

func _build_switcher() -> void:
	UI.clear(_switcher)
	_switcher.add_child(UI.label("TOWERS", 24, UI.MUTED))
	for id in TOWER_ORDER:
		var button := UI.button("", _open_tower.bind(id))
		button.custom_minimum_size = Vector2(138, maxf(132, _touch))
		button.disabled = Router.is_tutorial or not _is_tower_selectable(id)
		button.add_theme_stylebox_override("normal", UI.box(Color("233e41") if id == _active_tower else UI.PANEL, _tower_color(id), 0))
		var portrait := Portrait.new()
		portrait.tower_id = id
		portrait.unlocked = _is_tower_selectable(id)
		portrait.accent = _tower_color(id) if _is_tower_selectable(id) else UI.MUTED
		portrait.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		portrait.offset_bottom = -36
		button.add_child(portrait)
		var name_label := UI.label("BASIC" if id == "base" else id.to_upper(), 23, UI.TEXT)
		name_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		name_label.offset_top = -34
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(name_label)
		if not _is_tower_selectable(id):
			var lock := IntelPixelIcon.new()
			lock.kind = IntelPixelIcon.Kind.LOCK
			lock.ink_override = UI.MUTED
			lock.position = Vector2(8, 8)
			lock.size = Vector2(24, 24)
			button.add_child(lock)
			button.tooltip_text = _lock_reason(id)
		_switcher.add_child(button)

func _rebuild_tree() -> void:
	_refresh_queued = false
	if _active_tower.is_empty() or not is_inside_tree():
		return
	_build_switcher()
	UI.clear(_node_layer)
	UI.clear(_trace_layer)
	_track_nodes.clear()
	_capacity_rank1_button = null
	_root_button = null
	var tracks := ContentDB.tech_track_ids(_active_tower)
	_empty_hint.visible = tracks.is_empty()
	if tracks.is_empty():
		_selected_track = ""
		_refresh_inspector()
		return
	var width := _tree_canvas.size.x
	var root_center := Vector2(width * 0.5, 222)
	_root_button = _make_rank_node("stats", 0, 0, root_center)
	_root_button.is_root = true
	_root_button.state = "OWNED"
	_root_button.caption = "CORE"
	_root_button.disabled = true
	for track in TRACK_ORDER:
		if not tracks.has(track):
			continue
		var count := ContentDB.tech_max_rank(_active_tower, track)
		var nodes: Array[Button] = []
		var previous := root_center
		for rank in range(1, count + 1):
			var center: Vector2
			match track:
				"stats": center = Vector2(width * 0.19, 90 + (rank - 1) * 178)
				"capacity": center = Vector2(width * 0.81, 90 + (rank - 1) * 178)
				"skill": center = Vector2(width * 0.5, 68)
				_: center = Vector2(width * 0.5, 374 + (rank - 1) * 172)
			var button := _make_rank_node(track, rank, count, center)
			nodes.append(button)
			if track == "capacity" and rank == 1:
				_capacity_rank1_button = button
			var line := Line2D.new()
			line.points = PackedVector2Array([previous, center])
			line.width = 3 if _rank_state(track, rank) == "OWNED" else 2
			line.default_color = TRACK_COLORS[track] if _rank_state(track, rank) == "OWNED" else Color("465864")
			line.antialiased = true
			_trace_layer.add_child(line)
			previous = center
		_track_nodes[track] = nodes
	_refresh_inspector()

func _make_rank_node(track: String, rank: int, count: int, center: Vector2) -> Button:
	var node := OrbitNode.new()
	node.tower_id = _active_tower
	node.track_id = track
	node.rank = rank
	node.max_rank = count
	node.state = _rank_state(track, rank)
	node.accent = TRACK_COLORS[track]
	node.caption = str(TITLES[track])
	if track == "evolution":
		node.caption = "SCANNER" if rank == 1 else "SANDBOX"
	node.font_size = maxi(23, _font - 4)
	node.size = Vector2(140, 148)
	node.position = center - Vector2(70, 54)
	node.selected = track == _selected_track and rank == _selected_rank
	node.pressed.connect(_inspect_rank.bind(track, rank))
	if Router.is_tutorial and not (track == "capacity" and rank == 1):
		node.disabled = true
	_node_layer.add_child(node)
	return node

func _inspect_rank(track: String, rank: int) -> void:
	if Router.is_tutorial:
		_on_rank_pressed(track, rank)
		return
	if ContentDB.tech_rank_entry(_active_tower, track, rank).is_empty():
		return
	_selected_track = track
	_selected_rank = rank
	for key in _track_nodes:
		for node in _track_nodes[key]:
			node.selected = key == track and node.rank == rank
			node.queue_redraw()
	_refresh_inspector()

func _refresh_inspector() -> void:
	_purchase_button.disabled = true
	_detail_cost.text = ""
	_detail_icon.is_root = _selected_track.is_empty()
	_detail_icon.tower_id = _active_tower
	_detail_icon.track_id = "root" if _selected_track.is_empty() else _selected_track
	_detail_icon.caption = ""
	_detail_icon.accent = UI.TEAL if _selected_track.is_empty() else TRACK_COLORS[_selected_track]
	_detail_icon.rank = _selected_rank
	_detail_icon.max_rank = ContentDB.tech_max_rank(_active_tower, _selected_track)
	_detail_icon.state = "BUY" if _selected_track.is_empty() else _rank_state(_selected_track, _selected_rank)
	_detail_icon.queue_redraw()
	if _selected_track.is_empty():
		_detail_title.text = "RESEARCH NETWORK"
		_detail_body.text = "Select an ability node to see its effect, rank and upgrade cost."
		_detail_state.text = "Explore the network. Credits are spent only when you choose Level Up."
		if _track_nodes.is_empty():
			_detail_body.text = "This tower is unlocked. Upgrade tracks are not available yet."
			_detail_state.text = "Switch towers to continue your research."
		_purchase_button.text = "SELECT AN UPGRADE"
		return
	var entry := ContentDB.tech_rank_entry(_active_tower, _selected_track, _selected_rank)
	var state := _rank_state(_selected_track, _selected_rank)
	var cost := int(entry.get("cost", 0))
	_detail_title.text = "%s\nRANK %d / %d" % [TITLES[_selected_track], _selected_rank, ContentDB.tech_max_rank(_active_tower, _selected_track)]
	_detail_body.text = str(entry.get("label", ""))
	if _selected_track == "stats":
		_detail_body.text = "+%d damage\n+%.2f shots / second\n\nPermanent improvement to this tower's output." % [entry.get("damage", 0), entry.get("fire_rate", 0)]
	elif _selected_track == "capacity":
		_detail_body.text += "\n\nControls how many of this tower you can deploy at once."
	elif _selected_track == "evolution":
		_detail_body.text += "\n\nAdds a new tower to your deployment roster."
	elif _selected_track == "skill":
		_detail_body.text += "\n\nEnables the existing Stateful Inspection ability."
	_detail_cost.text = "COST  /  %d CREDITS" % cost
	_purchase_button.disabled = state != "BUY" or PlayerManager.credits < cost
	match state:
		"OWNED":
			_detail_state.text = "INSTALLED / This upgrade is active."
			_purchase_button.text = "ALREADY OWNED"
		"LOCKED":
			_detail_state.text = "LOCKED / Requires %s rank %d first." % [_selected_track.to_upper(), _selected_rank - 1]
			_purchase_button.text = "PREREQUISITE LOCKED"
		_:
			_detail_state.text = "READY / Available to install." if PlayerManager.credits >= cost else "Need %d more credits." % (cost - PlayerManager.credits)
			_purchase_button.text = "LEVEL UP"
	_detail_state.add_theme_color_override("font_color", UI.TEAL if state == "OWNED" or not _purchase_button.disabled else UI.GOLD)

func _purchase_selected() -> void:
	if not _selected_track.is_empty():
		_on_rank_pressed(_selected_track, _selected_rank)

func _refresh_coins_label() -> void:
	_coins_value.text = "%d CR" % PlayerManager.credits

func _rank_state(track_id: String, rank: int) -> String:
	var owned: int = PlayerManager.tech_rank(_active_tower, track_id)
	if owned >= rank:
		return "OWNED"
	if rank == owned + 1:
		return "BUY"
	return "LOCKED"


func _on_rank_pressed(track_id: String, rank: int) -> void:
	if not _is_tower_selectable(_active_tower) or ContentDB.tech_rank_entry(_active_tower, track_id, rank).is_empty():
		return
	if Router.is_tutorial:
		if track_id != "capacity" or rank != 1:
			return
		if PlayerManager.tech_rank("base", "capacity") >= 1:
			_on_tutorial_capacity_ack()
			return
	var state: String = _rank_state(track_id, rank)
	if state == "OWNED":
		print("[TechTree] Already owned: %s R%d" % [track_id, rank])
		return
	if state != "BUY":
		return
	if PlayerManager.purchase_tech_rank(_active_tower, track_id):
		print("[TechTree] Bought %s rank %d" % [track_id, rank])
		_refresh_coins_label()
		_rebuild_tree()
		_build_switcher()
		if _track_nodes.has(track_id):
			_track_nodes[track_id][rank - 1].celebrate()
		_detail_state.text = "UPGRADE INSTALLED / Ready for deployment."
		if Router.is_tutorial and track_id == "capacity" and rank == 1:
			_on_tutorial_capacity_ack()
	else:
		print("[TechTree] Insufficient credits for %s R%d" % [track_id, rank])


func _on_tutorial_capacity_ack() -> void:
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.show_upgrade_owned()


func _apply_tutorial_coach() -> void:
	var coaching: bool = Router.is_tutorial and Router.tutorial_beat == &"upgrade"
	if not coaching:
		_back_button.visible = true
		if _tutorial_overlay != null:
			_tutorial_overlay.visible = false
		if _active_tower.is_empty():
			_show_selection()
		return
	_back_button.visible = false
	PlayerManager.grant_tutorial_capacity_rank()
	_refresh_coins_label()
	await _open_tower("base")
	_tutorial_overlay = TutorialOverlay.mount_on(self, 20)
	if _tutorial_overlay == null:
		return
	if not _tutorial_overlay.lesson_requested.is_connected(_on_tutorial_lesson_requested):
		_tutorial_overlay.lesson_requested.connect(_on_tutorial_lesson_requested)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var glow := Rect2()
	if _capacity_rank1_button != null:
		glow = _capacity_rank1_button.get_global_rect()
	_tutorial_overlay.setup_upgrade(glow)


func _on_tutorial_lesson_requested() -> void:
	Router.open_tutorial_lesson()
