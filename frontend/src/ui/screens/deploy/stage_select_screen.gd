extends BaseScreen
## Combined stage-select dock + pan/zoom skill tree. Data/save wiring is out of scope.

## Mirrors SkillNodeData until Godot .NET can compile the C# resource.
## Keys match SkillId. Swap this dict for SkillTreeDB.tres in a later milestone.
const MOCK_SKILL_DB: Dictionary = {
	"firewall_1": {
		"name": "Basic Firewall",
		"graph_pos": Vector2(0, 0),
		"prereqs": [],
		"unlock_cost": 1,
	},
	"firewall_2": {
		"name": "Advanced Filtering",
		"graph_pos": Vector2(0, -150),
		"prereqs": ["firewall_1"],
		"unlock_cost": 1,
	},
	"crypto_1": {
		"name": "Basic Encryption",
		"graph_pos": Vector2(150, 0),
		"prereqs": ["firewall_1"],
		"unlock_cost": 1,
	},
	"firewall_3": {
		"name": "Packet Inspection",
		"graph_pos": Vector2(0, -300),
		"prereqs": ["firewall_2"],
		"unlock_cost": 2,
	},
}

## Simulated save file. Replace with SaveService in a later milestone.
var mock_coins: int = 5
var mock_max_stage_cleared: int = 2
var current_selected_stage: int = 0

@export var stage_count: int = 10
@export var stage_node_scene: PackedScene
@export var skill_node_scene: PackedScene
@export var module_titles: PackedStringArray = PackedStringArray(["Tiny Forest"])

@onready var _safe: MarginContainer = %SafeArea
@onready var _pan_zoom: SkillTreePanZoom = %SkillTreePanZoom
@onready var _edge_layer: Control = %EdgeLayer
@onready var _node_layer: Control = %NodeLayer
@onready var _stage_row: HBoxContainer = %StageRow
@onready var _module_title: Label = %ModuleTitle

var _pixel_font: Font
var _module_index: int = 0
var _stage_nodes: Array[StageNodeUI] = []


func _ready() -> void:
	_load_font()
	get_viewport().size_changed.connect(_apply_scale)
	%PrevModuleButton.pressed.connect(func() -> void: _cycle_module(-1))
	%NextModuleButton.pressed.connect(func() -> void: _cycle_module(1))
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%BreachButton.pressed.connect(_on_breach_pressed)
	_generate_skill_tree()
	_refresh_coins_label()


func on_enter(_args: Dictionary) -> void:
	visible = true
	_set_canvas_layers_visible(true)
	_rebuild_stages()
	_refresh_module_title()
	_apply_scale()
	_pan_zoom.reset_view.call_deferred()


func on_resume() -> void:
	visible = true
	_set_canvas_layers_visible(true)
	_apply_scale()


func on_exit() -> void:
	# CanvasLayers paint in global space; parent.visible = false is not enough.
	visible = false
	_set_canvas_layers_visible(false)


func _set_canvas_layers_visible(active: bool) -> void:
	var background: CanvasLayer = get_node_or_null("BackgroundLayer") as CanvasLayer
	var tree: CanvasLayer = get_node_or_null("TreeLayer") as CanvasLayer
	var hud: CanvasLayer = get_node_or_null("HudLayer") as CanvasLayer
	if background != null:
		background.visible = active
	if tree != null:
		tree.visible = active
	if hud != null:
		hud.visible = active


func _clear_children(host: Node) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()


func _load_font() -> void:
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		var file := load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
		if file != null:
			_pixel_font = file


func _rebuild_stages() -> void:
	_clear_children(_stage_row)
	_stage_nodes.clear()

	if stage_node_scene == null:
		push_error("StageSelectScreen: stage_node_scene is not assigned")
		return

	var count := maxi(1, stage_count)
	current_selected_stage = clampi(current_selected_stage, 0, mini(count - 1, mock_max_stage_cleared))
	for i in count:
		var node := stage_node_scene.instantiate() as StageNodeUI
		if node == null:
			push_error("StageSelectScreen: stage_node_scene is not a StageNodeUI")
			return
		_stage_row.add_child(node)
		_stage_nodes.append(node)
		var kind := StageNodeUI.Kind.BOSS if i == count - 1 else StageNodeUI.Kind.NORMAL
		node.configure(i, kind, _pixel_font)
		node.stage_pressed.connect(_on_stage_pressed)
	_refresh_stage_visuals()


func _generate_skill_tree() -> void:
	_clear_children(_edge_layer)
	_clear_children(_node_layer)

	if skill_node_scene == null:
		push_error("StageSelectScreen: skill_node_scene is not assigned")
		return

	var view_w := get_viewport().get_visible_rect().size.x
	var diamond_px := UiScale.n(56, view_w)
	var font_px := UiScale.n(10, view_w)
	var spawned_nodes: Dictionary = {}

	# Pass 1: every node exists and has a canvas coordinate before any edge is drawn.
	for skill_id in MOCK_SKILL_DB:
		var data: Dictionary = MOCK_SKILL_DB[skill_id]
		var node := skill_node_scene.instantiate() as SkillNodeUI
		if node == null:
			push_error("StageSelectScreen: skill_node_scene is not a SkillNodeUI")
			return
		_node_layer.add_child(node)
		node.configure(skill_id, 0, 1, _pixel_font)
		node.set_skill_data(skill_id, String(data.get("name", skill_id)), _get_skill_state(skill_id))
		node.skill_pressed.connect(_on_skill_pressed)
		node.apply_scale(diamond_px, font_px)
		node.place_on_canvas(data["graph_pos"])
		spawned_nodes[skill_id] = node

	# Pass 2: Line2D can now read real Control positions from both endpoints.
	for skill_id in MOCK_SKILL_DB:
		var data: Dictionary = MOCK_SKILL_DB[skill_id]
		var to_node: SkillNodeUI = spawned_nodes.get(skill_id)
		if to_node == null:
			continue
		var target_state := _get_skill_state(skill_id)
		var prereqs: Array = data.get("prereqs", [])
		for prereq_id in prereqs:
			var from_node: SkillNodeUI = spawned_nodes.get(prereq_id)
			if from_node == null:
				push_warning("StageSelectScreen: missing prereq '%s' for '%s'" % [prereq_id, skill_id])
				continue
			var edge := Line2D.new()
			edge.width = 3.0
			edge.default_color = _edge_color(target_state)
			edge.antialiased = false
			edge.points = PackedVector2Array([
				_skill_center(from_node),
				_skill_center(to_node),
			])
			_edge_layer.add_child(edge)


func _get_skill_state(skill_id: String) -> String:
	if PlayerManager.has_skill(skill_id):
		return "UNLOCKED"
	var data: Dictionary = MOCK_SKILL_DB.get(skill_id, {})
	var prereqs: Array = data.get("prereqs", [])
	for prereq_id in prereqs:
		if not PlayerManager.has_skill(String(prereq_id)):
			return "LOCKED"
	return "PURCHASABLE"


func _edge_color(target_state: String) -> Color:
	if target_state == "LOCKED":
		return Color(Palette.CYAN_DIM, 0.4)
	return Palette.CYAN


func _skill_center(node: Control) -> Vector2:
	return node.position + node.size * 0.5


func _refresh_stage_visuals() -> void:
	for child in _stage_row.get_children():
		var node := child as StageNodeUI
		if node == null:
			continue
		var state := "LOCKED"
		if node.index == current_selected_stage:
			state = "SELECTED"
		elif node.index <= mock_max_stage_cleared:
			state = "UNLOCKED"
		node.apply_visual_state(state)


func _on_stage_pressed(index: int) -> void:
	if index > mock_max_stage_cleared:
		print("[Stage Select] Stage locked.")
		return
	current_selected_stage = index
	_refresh_stage_visuals()


func _on_breach_pressed() -> void:
	Router.start_level(current_selected_stage)


func _on_skill_pressed(skill_id: String) -> void:
	var data: Dictionary = MOCK_SKILL_DB.get(skill_id, {})
	var skill_name := String(data.get("name", skill_id))
	print("[Skill Tree] Clicked: %s - State: %s" % [skill_name, _get_skill_state(skill_id)])
	_attempt_purchase(skill_id)


func _attempt_purchase(skill_id: String) -> void:
	if not MOCK_SKILL_DB.has(skill_id):
		push_warning("StageSelectScreen: unknown skill '%s'" % skill_id)
		return

	var state := _get_skill_state(skill_id)
	if state != "PURCHASABLE":
		print("[Skill Tree] Cannot purchase '%s' (state: %s)" % [skill_id, state])
		return

	var data: Dictionary = MOCK_SKILL_DB[skill_id]
	var cost := int(data.get("unlock_cost", 0))
	if mock_coins < cost:
		print("[Skill Tree] Insufficient coins for: " + skill_id)
		return

	mock_coins -= cost
	PlayerManager.unlock_skill(skill_id)
	_refresh_coins_label()
	# _generate_skill_tree already remove_child + queue_free on both layers.
	_generate_skill_tree()


func _refresh_coins_label() -> void:
	%CoinsValue.text = str(mock_coins)


func _on_settings_pressed() -> void:
	pass


func _cycle_module(delta: int) -> void:
	if module_titles.is_empty():
		return
	_module_index = wrapi(_module_index + delta, 0, module_titles.size())
	_refresh_module_title()


func _refresh_module_title() -> void:
	if module_titles.is_empty():
		_module_title.text = tr("STAGE_MODULE_FALLBACK")
		return
	_module_title.text = module_titles[_module_index]


func _apply_scale() -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	var scaled := func(value: float) -> int: return UiScale.n(value, view_w)

	_safe.add_theme_constant_override("margin_left", scaled.call(16))
	_safe.add_theme_constant_override("margin_top", scaled.call(12))
	_safe.add_theme_constant_override("margin_right", scaled.call(16))
	_safe.add_theme_constant_override("margin_bottom", scaled.call(8))

	_apply_font(%CoinsValue, scaled.call(12))
	_apply_font(%WoodValue, scaled.call(12))
	_apply_font(%GemsValue, scaled.call(12))
	_apply_font(%KeysValue, scaled.call(12))
	_apply_font(_module_title, scaled.call(14))
	_module_title.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_apply_font(%PurchaseHint, scaled.call(8))
	_apply_font(%ZoomHint, scaled.call(8))
	_apply_font(%MoveHint, scaled.call(8))
	_apply_font_button(%PrevModuleButton, scaled.call(12))
	_apply_font_button(%NextModuleButton, scaled.call(12))
	_apply_font_button(%SettingsButton, scaled.call(16))
	_apply_font_button(%BreachButton, scaled.call(14))

	%PurchaseHint.text = tr("STAGE_HINT_PURCHASE")
	%ZoomHint.text = tr("STAGE_HINT_ZOOM")
	%MoveHint.text = tr("STAGE_HINT_MOVE")

	_refresh_coins_label()
	%WoodValue.text = "0"
	%GemsValue.text = "0"
	%KeysValue.text = "0"

	%ResourceStack.add_theme_constant_override("separation", scaled.call(8))
	_stage_row.add_theme_constant_override("separation", scaled.call(8))
	%StageDock.custom_minimum_size = Vector2(0, scaled.call(108))
	%StageMargin.add_theme_constant_override("margin_left", scaled.call(36))
	%StageMargin.add_theme_constant_override("margin_right", scaled.call(36))
	%StageMargin.add_theme_constant_override("margin_top", scaled.call(22))
	%StageMargin.add_theme_constant_override("margin_bottom", scaled.call(14))
	%SettingsButton.custom_minimum_size = Vector2(scaled.call(40), scaled.call(40))
	%PrevModuleButton.custom_minimum_size = Vector2(scaled.call(28), scaled.call(28))
	%NextModuleButton.custom_minimum_size = Vector2(scaled.call(28), scaled.call(28))
	%BreachButton.custom_minimum_size = Vector2(scaled.call(160), scaled.call(36))

	var cell := UiScale.n(36, view_w)
	var cell_font := UiScale.n(12, view_w)
	for node in _stage_nodes:
		node.apply_scale(cell, cell_font)

	for child in _node_layer.get_children():
		var skill := child as SkillNodeUI
		if skill == null:
			continue
		skill.apply_scale(scaled.call(56), scaled.call(10))
		var data: Dictionary = MOCK_SKILL_DB.get(skill.skill_id, {})
		skill.place_on_canvas(data.get("graph_pos", Vector2.ZERO))


func _apply_font(label: Label, font_size: int) -> void:
	if _pixel_font:
		label.add_theme_font_override("font", _pixel_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)


func _apply_font_button(button: Button, font_size: int) -> void:
	if _pixel_font:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", font_size)
