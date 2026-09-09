extends BaseScreen
## Research dossiers and a state-aware, branching tech constellation.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const OrbitNode = preload("res://src/ui/screens/deploy/tech_orbit_node.gd")
const ResearchCard = preload("res://src/ui/screens/deploy/tower_research_card.gd")
const TRACK_COLORS := {"skill": Color("67bbff"), "stats": Color("51e7ab"), "capacity": Color("f5d45b"), "evolution": Color("f37893")}
const TRACK_ORDER: Array[String] = ["skill", "stats", "capacity", "evolution"]
const TOWER_ORDER: Array[String] = ["base", "scanner", "sandbox"]

@onready var _safe: MarginContainer = %SafeArea
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _coins_value: Label = %CoinsValue
@onready var _selection_screen: MarginContainer = %SelectionScreen
@onready var _selection_row: HBoxContainer = %SelectionRow
@onready var _tree_screen: Control = %TreeScreen
@onready var _tree_canvas: Control = %TreeCanvas
@onready var _trace_layer: Control = %TraceLayer
@onready var _node_layer: Control = %NodeLayer
@onready var _empty_hint: Label = %EmptyHint

var _pixel_font: Font
var _tutorial_overlay: TutorialOverlay = null
var _active_tower: String = ""
var _capacity_rank1_button: Button = null
var _root_button: Button = null
var _track_nodes: Dictionary = {}
var _select_cards: Dictionary = {}
var _selected_track := ""
var _selected_rank := 0
var _detail_title: Label
var _detail_body: Label
var _detail_state: Label
var _purchase_button: Button
var _intro: Label
var _selection_footer: Label


func _ready() -> void:
	_load_font()
	get_viewport().size_changed.connect(_on_resized)
	_back_button.pressed.connect(_on_back_pressed)
	_tree_canvas.resized.connect(func() -> void:
		if _tree_screen.visible:
			_rebuild_tree.call_deferred()
	)
	_build_research_chrome()
	_build_selection_cards()
	_show_selection()
	_apply_scale()


func on_enter(_args: Dictionary) -> void:
	visible = true
	_set_canvas_layers_visible(true)
	_refresh_coins_label()
	_refresh_selection_cards()
	_apply_scale()
	_apply_tutorial_coach()


func on_resume() -> void:
	visible = true
	_set_canvas_layers_visible(true)
	_refresh_coins_label()
	_refresh_selection_cards()
	if not _active_tower.is_empty() and _tree_screen.visible:
		_rebuild_tree()
	_apply_scale()
	_apply_tutorial_coach()


func on_exit() -> void:
	visible = false
	_set_canvas_layers_visible(false)


func can_go_back() -> bool:
	if Router.is_tutorial:
		return false
	if _tree_screen.visible:
		_show_selection()
		return false
	return true


func _set_canvas_layers_visible(active: bool) -> void:
	var background: CanvasLayer = get_node_or_null("BackgroundLayer") as CanvasLayer
	var hud: CanvasLayer = get_node_or_null("HudLayer") as CanvasLayer
	if background != null:
		background.visible = active
	if hud != null:
		hud.visible = active


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file


func _on_resized() -> void:
	_apply_scale()
	if _tree_screen.visible:
		_rebuild_tree()
	else:
		_refresh_selection_cards()


func _on_back_pressed() -> void:
	if Router.is_tutorial:
		return
	if _tree_screen.visible:
		_show_selection()
		return
	Router.request_back()


func _show_selection() -> void:
	_active_tower = ""
	_selection_screen.visible = true
	_tree_screen.visible = false
	_title_label.text = "NODE ARMORY"
	_back_button.text = tr("SETT_BACK")
	_refresh_selection_cards()
	_refresh_coins_label()


func _open_tower(tower_id: String) -> void:
	if not _is_tower_selectable(tower_id):
		return
	_active_tower = tower_id
	_selected_track = ""
	_selected_rank = 0
	_selection_screen.visible = false
	_tree_screen.visible = true
	_title_label.text = TowerBase.display_name_for(tower_id).to_upper()
	_back_button.text = "< NODES"
	_refresh_coins_label()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_rebuild_tree()


func _is_tower_selectable(tower_id: String) -> bool:
	if tower_id == "base":
		return true
	if tower_id == "scanner":
		return PlayerManager.tech_rank("base", "evolution") >= 1 or PlayerManager.is_tower_unlocked("scanner")
	if tower_id == "sandbox":
		return PlayerManager.tech_rank("base", "evolution") >= 2 or PlayerManager.is_tower_unlocked("sandbox")
	return false


func _build_research_chrome() -> void:
	var chrome := Control.new()
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_screen.add_child(chrome)
	_intro = Label.new()
	_intro.text = "RESEARCH DIVISION  /  TOWER SYSTEMS\nChoose a node to inspect its upgrade network."
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_intro.offset_top = 15
	_intro.offset_bottom = 66
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(_intro)
	_selection_footer = Label.new()
	_selection_footer.text = "EVOLUTION PATH     BASIC NODE  >  SCANNER  >  SANDBOX"
	_selection_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_selection_footer.offset_top = -32
	_selection_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(_selection_footer)
	_tree_canvas.offset_bottom = -122
	var panel := PanelContainer.new()
	panel.name = "ResearchInspector"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -112
	panel.offset_bottom = -4
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b29")
	style.border_color = Color("304358")
	style.set_border_width_all(1)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_tree_screen.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 9)
	row.add_child(copy)
	_detail_title = Label.new()
	_detail_body = Label.new()
	_detail_state = Label.new()
	for label in [_detail_title, _detail_body, _detail_state]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(label)
	_purchase_button = Button.new()
	_purchase_button.custom_minimum_size = Vector2(240, 48)
	_purchase_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_purchase_button.pressed.connect(_purchase_selected)
	row.add_child(_purchase_button)


func _build_selection_cards() -> void:
	_clear_children(_selection_row)
	_select_cards.clear()
	for tower_id in TOWER_ORDER:
		var card := ResearchCard.new()
		card.tower_id = tower_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_open_tower.bind(tower_id))
		_selection_row.add_child(card)
		_select_cards[tower_id] = card
	_refresh_selection_cards()


func _refresh_selection_cards() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf((view.x - 100.0) / 944.0, (view.y - 225.0) / 430.0)
	fit = maxf(0.45, fit)
	_selection_row.add_theme_constant_override("separation", int(22 * fit))
	var colors := {"base": Color("5ee5c0"), "scanner": Color("68baff"), "sandbox": Color("b394f6")}
	for tower_id in TOWER_ORDER:
		if not _select_cards.has(tower_id):
			continue
		var card = _select_cards[tower_id]
		var data: Dictionary = ContentDB.get_tower(tower_id)
		var bonus: Dictionary = PlayerManager.stats_bonus_for(tower_id)
		card.custom_minimum_size = Vector2(300, 430) * fit
		card.accent = colors[tower_id]
		card.unlocked = _is_tower_selectable(tower_id)
		card.heading = TowerBase.display_name_for(tower_id).to_upper()
		card.role = TowerBase.role_for(tower_id)
		card.cost = TowerBase.cost_for(tower_id)
		card.damage = int(data.get("damage", 0)) + int(bonus.get("damage", 0))
		card.rate = float(data.get("fire_rate", 0)) + float(bonus.get("fire_rate", 0))
		card.slots = PlayerManager.tower_capacity(tower_id)
		card.requirement = "REQUIRES BASIC " + _lock_reason(tower_id)
		card.ranks = 0
		card.total_ranks = 0
		for track in TRACK_ORDER:
			card.ranks += PlayerManager.tech_rank(tower_id, track)
			card.total_ranks += ContentDB.tech_max_rank(tower_id, track)
		# Locked cards remain focusable so the unlock requirement is discoverable.
		card.tooltip_text = "Open research" if card.unlocked else "Unlock through Basic Node > Evolution. " + _lock_reason(tower_id)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if card.unlocked else Control.CURSOR_HELP
		card.queue_redraw()


func _lock_reason(tower_id: String) -> String:
	if tower_id == "scanner":
		return "EVO RANK 1"
	if tower_id == "sandbox":
		return "EVO RANK 2"
	return "LOCKED"


func _rebuild_tree() -> void:
	_capacity_rank1_button = null
	_root_button = null
	_track_nodes.clear()
	_clear_children(_trace_layer)
	_clear_children(_node_layer)
	if _active_tower.is_empty():
		return
	var tracks: Array[String] = ContentDB.tech_track_ids(_active_tower)
	_empty_hint.visible = tracks.is_empty()
	if tracks.is_empty():
		_empty_hint.text = "UPGRADE TRACKS COMING LATER"
	_layout_tree(tracks)
	_refresh_inspector()


func _layout_tree(tracks: Array[String]) -> void:
	var area := _tree_canvas.size
	if area.x < 8 or area.y < 8:
		return
	var root := OrbitNode.new()
	root.is_root = true
	root.state = "OWNED"
	root.accent = Color("b2cadb")
	root.caption = "CORE"
	root.size = Vector2(110, 90)
	root.position = Vector2(area.x * 0.5 - 55, area.y - 94)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.focus_mode = Control.FOCUS_NONE
	_node_layer.add_child(root)
	_root_button = root
	# Four independent prerequisite chains, not invented cross-track dependencies.
	var positions := {
		"skill": [Vector2(0.12, 0.46)],
		"stats": [Vector2(0.35, 0.66), Vector2(0.27, 0.40), Vector2(0.20, 0.14)],
		"capacity": [Vector2(0.60, 0.66), Vector2(0.64, 0.40), Vector2(0.60, 0.14)],
		"evolution": [Vector2(0.79, 0.58), Vector2(0.86, 0.20)]
	}
	for track_id in TRACK_ORDER:
		if not tracks.has(track_id):
			continue
		var count := ContentDB.tech_max_rank(_active_tower, track_id)
		var nodes: Array[Button] = []
		var owned := PlayerManager.tech_rank(_active_tower, track_id)
		var accent: Color = TRACK_COLORS[track_id]
		for rank in range(1, count + 1):
			var normalized: Vector2 = positions[track_id][mini(rank - 1, positions[track_id].size() - 1)]
			var center := Vector2(normalized.x * area.x, normalized.y * (area.y - 50) + 18)
			var btn := _make_rank_node(track_id, rank, count, center)
			nodes.append(btn)
			if track_id == "capacity" and rank == 1:
				_capacity_rank1_button = btn
		_track_nodes[track_id] = nodes
		var top: Button = nodes.back()
		_add_track_label(track_id, top.position.x + top.size.x * 0.5, top.position.y - 30 if track_id == "skill" else 10, accent, owned, count)
	_draw_traces()


func _make_rank_node(track_id: String, rank: int, max_rank: int, center: Vector2) -> Button:
	var btn := OrbitNode.new()
	btn.track_id = track_id
	btn.rank = rank
	btn.max_rank = max_rank
	btn.state = _rank_state(track_id, rank)
	btn.accent = TRACK_COLORS[track_id]
	var names := {"skill": "INSPECTION", "stats": "OUTPUT", "capacity": "DEPLOY", "evolution": "SCANNER" if rank == 1 else "SANDBOX"}
	btn.caption = str(names[track_id]) + (" %s" % ["I", "II", "III"][rank - 1] if track_id in ["stats", "capacity"] else "")
	btn.size = Vector2(clampf(_tree_canvas.size.x * 0.115, 100, 145), clampf(_tree_canvas.size.y * 0.21, 76, 103))
	btn.position = center - Vector2(btn.size.x * 0.5, (btn.size.y - 25) * 0.5)
	btn.selected = track_id == _selected_track and rank == _selected_rank
	var entry := ContentDB.tech_rank_entry(_active_tower, track_id, rank)
	btn.tooltip_text = "%s\n%d CR / %s" % [entry.get("label", ""), entry.get("cost", 0), btn.state]
	btn.pressed.connect(_inspect_rank.bind(track_id, rank))
	if Router.is_tutorial and not (track_id == "capacity" and rank == 1):
		btn.disabled = true
	_node_layer.add_child(btn)
	return btn


func _add_track_label(track_id: String, x: float, y: float, accent: Color, owned: int, count: int) -> void:
	var label := Label.new()
	label.text = "%s  %d/%d" % [track_id.to_upper(), owned, count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(x - 100, y)
	label.size = Vector2(200, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(label, clampi(int(_tree_canvas.size.x / 130), 7, 10), accent)
	_node_layer.add_child(label)


func _node_center(btn: Button) -> Vector2:
	var radius := minf(btn.size.x * 0.32, (btn.size.y - 25) * 0.5)
	return btn.position + Vector2(btn.size.x * 0.5, radius + 4)


func _draw_traces() -> void:
	for track_id in TRACK_ORDER:
		if not _track_nodes.has(track_id):
			continue
		var previous := _node_center(_root_button)
		var nodes: Array = _track_nodes[track_id]
		for i in nodes.size():
			var current: Button = nodes[i]
			var end := _node_center(current)
			var active := i <= PlayerManager.tech_rank(_active_tower, track_id)
			var ink: Color = TRACK_COLORS[track_id] if active else Color("303c50")
			_add_trace(previous, end, ink, active, track_id == "skill")
			previous = end


func _add_trace(from_pt: Vector2, to_pt: Vector2, ink: Color, active: bool, outer_branch: bool = false) -> void:
	var points := PackedVector2Array()
	var distance := absf(from_pt.y - to_pt.y)
	var control_a := from_pt + Vector2(0, -distance * 0.62)
	var control_b := to_pt + Vector2(0, distance * 0.58)
	if outer_branch:
		control_a = from_pt + Vector2(-150, -20)
		control_b = Vector2(to_pt.x, from_pt.y)
	for i in 41:
		points.append(from_pt.bezier_interpolate(control_a, control_b, to_pt, i / 40.0))
	for glow in [true, false]:
		var line := Line2D.new()
		line.points = points
		line.width = (11.0 if active else 5.0) if glow else (4.5 if active else 1.5)
		line.default_color = Color(ink, 0.065) if glow else ink
		line.antialiased = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_trace_layer.add_child(line)


func _inspect_rank(track_id: String, rank: int) -> void:
	if Router.is_tutorial:
		_on_rank_pressed(track_id, rank)
		return
	_selected_track = track_id
	_selected_rank = rank
	for key in _track_nodes:
		for node in _track_nodes[key]:
			node.selected = key == track_id and node.rank == rank
			node.queue_redraw()
	_refresh_inspector()


func _refresh_inspector() -> void:
	if _selected_track.is_empty():
		_detail_title.text = "RESEARCH NETWORK"
		_detail_body.text = "Select a circular node to inspect its effect and credit cost."
		_detail_state.text = "FILLED: OWNED    OUTLINED: NEXT RANK    PADLOCK: PREREQUISITE"
		_purchase_button.text = "SELECT AN UPGRADE"
		_purchase_button.disabled = true
		if ContentDB.tech_track_ids(_active_tower).is_empty():
			_detail_body.text = "This tower is unlocked. Upgrade tracks are not available yet."
			_detail_state.text = "Return to Nodes to research another tower."
		return
	var entry := ContentDB.tech_rank_entry(_active_tower, _selected_track, _selected_rank)
	var state := _rank_state(_selected_track, _selected_rank)
	var cost := int(entry.get("cost", 0))
	_detail_title.text = "%s / RANK %d" % [_selected_track.to_upper(), _selected_rank]
	_detail_title.add_theme_color_override("font_color", TRACK_COLORS[_selected_track])
	_detail_body.text = str(entry.get("label", ""))
	_purchase_button.disabled = state != "BUY" or PlayerManager.credits < cost
	match state:
		"OWNED":
			_detail_state.text = "Installed. This upgrade is active."
			_purchase_button.text = "OWNED"
		"LOCKED":
			_detail_state.text = "Requires %s rank %d first." % [_selected_track.to_upper(), _selected_rank - 1]
			_purchase_button.text = "LOCKED / %d CR" % cost
		_:
			_detail_state.text = "Ready to research." if PlayerManager.credits >= cost else "Need %d more credits." % (cost - PlayerManager.credits)
			_purchase_button.text = "RESEARCH / %d CR" % cost


func _purchase_selected() -> void:
	if not _selected_track.is_empty():
		_on_rank_pressed(_selected_track, _selected_rank)


func _rank_state(track_id: String, rank: int) -> String:
	var owned: int = PlayerManager.tech_rank(_active_tower, track_id)
	if owned >= rank:
		return "OWNED"
	if rank == owned + 1:
		return "BUY"
	return "LOCKED"


func _on_rank_pressed(track_id: String, rank: int) -> void:
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


func _refresh_coins_label() -> void:
	_coins_value.text = "%d CR" % PlayerManager.credits


func _apply_scale() -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	var scaled := func(value: float) -> int: return UiScale.n(value, view_w)
	_safe.add_theme_constant_override("margin_left", scaled.call(16))
	_safe.add_theme_constant_override("margin_top", scaled.call(12))
	_safe.add_theme_constant_override("margin_right", scaled.call(16))
	_safe.add_theme_constant_override("margin_bottom", scaled.call(8))
	_apply_font_button(_back_button, scaled.call(14))
	_back_button.add_theme_color_override("font_color", Palette.FIELD_PLACEHOLDER)
	_back_button.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)
	_apply_font(_title_label, scaled.call(16), Palette.TEXT_PRIMARY)
	_apply_font(_coins_value, scaled.call(12), Palette.TEXT_PRIMARY)
	_apply_font(_empty_hint, scaled.call(10), Palette.CYAN_300)
	_apply_font(_intro, maxi(8, scaled.call(8)), Color("869aaf"))
	_apply_font(_selection_footer, maxi(7, scaled.call(7)), Color("728ba2"))
	_apply_font(_detail_title, maxi(9, scaled.call(9)), Color("b9d7e6"))
	_apply_font(_detail_body, maxi(8, scaled.call(8)), Color("e0e8ed"))
	_apply_font(_detail_state, maxi(7, scaled.call(7)), Color("91a2b7"))
	_apply_font_button(_purchase_button, maxi(8, scaled.call(8)))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("16332f")
	button_style.border_color = Color("54bba1")
	button_style.set_border_width_all(1)
	_purchase_button.add_theme_stylebox_override("normal", button_style)
	var hover_style := button_style.duplicate()
	hover_style.bg_color = Color("215148")
	_purchase_button.add_theme_stylebox_override("hover", hover_style)
	_purchase_button.add_theme_stylebox_override("focus", hover_style)
	_purchase_button.custom_minimum_size.x = clampf(view_w * 0.23, 200, 320)
	_refresh_selection_cards()


func _clear_children(host: Node) -> void:
	var kids: Array = host.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child == null:
			continue
		host.remove_child(child)
		child.queue_free()


func _apply_font(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _apply_font_button(button: Button, font_size: int) -> void:
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", font_size)
