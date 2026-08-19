extends BaseScreen
## Skill-tree upgrades. Extracted from stage select so deploy flow stays a module picker.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
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

@export var skill_node_scene: PackedScene

@onready var _safe: MarginContainer = %SafeArea
@onready var _pan_zoom: SkillTreePanZoom = %SkillTreePanZoom
@onready var _edge_layer: Control = %EdgeLayer
@onready var _node_layer: Control = %NodeLayer
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _coins_value: Label = %CoinsValue

var _pixel_font: Font
var mock_coins: int = 5


func _ready() -> void:
	_load_font()
	get_viewport().size_changed.connect(_apply_scale)
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_generate_skill_tree()
	_refresh_coins_label()
	_apply_scale()


func on_enter(_args: Dictionary) -> void:
	visible = true
	_set_canvas_layers_visible(true)
	_apply_scale()
	_pan_zoom.reset_view.call_deferred()


func on_resume() -> void:
	visible = true
	_set_canvas_layers_visible(true)
	_apply_scale()


func on_exit() -> void:
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
	var kids: Array = host.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child == null:
			continue
		host.remove_child(child)
		child.queue_free()


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file


func _generate_skill_tree() -> void:
	_clear_children(_edge_layer)
	_clear_children(_node_layer)
	if skill_node_scene == null:
		push_error("UpgradeScreen: skill_node_scene is not assigned")
		return
	var view_w := get_viewport().get_visible_rect().size.x
	var diamond_px := UiScale.n(56, view_w)
	var font_px := UiScale.n(10, view_w)
	var spawned_nodes: Dictionary = {}
	var keys: Array = MOCK_SKILL_DB.keys()
	for i in keys.size():
		var skill_id := str(keys[i])
		var data: Dictionary = MOCK_SKILL_DB[skill_id]
		var node := skill_node_scene.instantiate() as SkillNodeUI
		if node == null:
			push_error("UpgradeScreen: skill_node_scene is not a SkillNodeUI")
			return
		_node_layer.add_child(node)
		node.configure(skill_id, 0, 1, _pixel_font)
		node.set_skill_data(skill_id, String(data.get("name", skill_id)), _get_skill_state(skill_id))
		node.skill_pressed.connect(_on_skill_pressed)
		node.apply_scale(diamond_px, font_px)
		node.place_on_canvas(data["graph_pos"])
		spawned_nodes[skill_id] = node
	for i in keys.size():
		var skill_id := str(keys[i])
		var data: Dictionary = MOCK_SKILL_DB[skill_id]
		var to_node: SkillNodeUI = spawned_nodes.get(skill_id)
		if to_node == null:
			continue
		var target_state := _get_skill_state(skill_id)
		var prereqs: Array = data.get("prereqs", [])
		for p in prereqs.size():
			var prereq_id := str(prereqs[p])
			var from_node: SkillNodeUI = spawned_nodes.get(prereq_id)
			if from_node == null:
				push_warning("UpgradeScreen: missing prereq '%s' for '%s'" % [prereq_id, skill_id])
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
	for i in prereqs.size():
		if not PlayerManager.has_skill(str(prereqs[i])):
			return "LOCKED"
	return "PURCHASABLE"


func _edge_color(target_state: String) -> Color:
	if target_state == "LOCKED":
		return Color(Palette.CYAN_DIM, 0.4)
	return Palette.CYAN


func _skill_center(node: Control) -> Vector2:
	return node.position + node.size * 0.5


func _on_skill_pressed(skill_id: String) -> void:
	_attempt_purchase(skill_id)


func _attempt_purchase(skill_id: String) -> void:
	if not MOCK_SKILL_DB.has(skill_id):
		return
	var state := _get_skill_state(skill_id)
	if state != "PURCHASABLE":
		return
	var data: Dictionary = MOCK_SKILL_DB[skill_id]
	var cost := int(data.get("unlock_cost", 0))
	if mock_coins < cost:
		return
	mock_coins -= cost
	PlayerManager.unlock_skill(skill_id)
	_refresh_coins_label()
	_generate_skill_tree()


func _refresh_coins_label() -> void:
	_coins_value.text = str(mock_coins)


func _apply_scale() -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	var scaled := func(value: float) -> int: return UiScale.n(value, view_w)
	_safe.add_theme_constant_override("margin_left", scaled.call(16))
	_safe.add_theme_constant_override("margin_top", scaled.call(12))
	_safe.add_theme_constant_override("margin_right", scaled.call(16))
	_safe.add_theme_constant_override("margin_bottom", scaled.call(8))
	_apply_font_button(_back_button, scaled.call(14))
	_back_button.text = tr("SETT_BACK")
	_back_button.add_theme_color_override("font_color", Palette.FIELD_PLACEHOLDER)
	_back_button.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)
	_apply_font(_title_label, scaled.call(16), Palette.TEXT_PRIMARY)
	_apply_font(_coins_value, scaled.call(12), Palette.TEXT_PRIMARY)
	_apply_font(%PurchaseHint, scaled.call(8), Palette.TEXT_PRIMARY)
	_apply_font(%ZoomHint, scaled.call(8), Palette.TEXT_PRIMARY)
	_apply_font(%MoveHint, scaled.call(8), Palette.TEXT_PRIMARY)
	%PurchaseHint.text = tr("STAGE_HINT_PURCHASE")
	%ZoomHint.text = tr("STAGE_HINT_ZOOM")
	%MoveHint.text = tr("STAGE_HINT_MOVE")
	_title_label.text = "UPGRADES"
	var kids: Array = _node_layer.get_children()
	for i in kids.size():
		var skill := kids[i] as SkillNodeUI
		if skill == null:
			continue
		skill.apply_scale(scaled.call(56), scaled.call(10))
		var data: Dictionary = MOCK_SKILL_DB.get(skill.skill_id, {})
		skill.place_on_canvas(data.get("graph_pos", Vector2.ZERO))


func _apply_font(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _apply_font_button(button: Button, font_size: int) -> void:
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.add_theme_font_size_override("font_size", font_size)
