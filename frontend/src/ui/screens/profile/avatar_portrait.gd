extends TextureRect
## Shared avatar catalog and circular renderer; no reward or purchase logic.
const DEFAULT_ID: String = "byte_bot"
const ENTRIES: Array[Dictionary] = [
	{"id": "byte_bot", "name": "Byte Bot", "file": "byte_bot", "price": 0},
	{"id": "cyber_cat", "name": "Cyber Cat", "file": "cyber_cat", "price": 0},
	{"id": "p1", "name": "Commander Avatar", "file": "commander", "price": 800},
	{"id": "p2", "name": "Operative Icon", "file": "operative", "price": 450},
	{"id": "p3", "name": "Neon Fox", "file": "neon_fox", "price": 600},
	{"id": "p4", "name": "Circuit Owl", "file": "circuit_owl", "price": 500},
	{"id": "p5", "name": "Glitch Ghost", "file": "glitch_ghost", "price": 700},
	{"id": "p6", "name": "Pixel Bunny", "file": "pixel_bunny", "price": 400},
	{"id": "p7", "name": "Cyber Axolotl", "file": "cyber_axolotl", "price": 650},
	{"id": "p8", "name": "Masked Raccoon", "file": "masked_raccoon", "price": 550},
]
static var _mask: ShaderMaterial
var displayed_id: String = ""

static func entry(id: String) -> Dictionary:
	for item: Dictionary in ENTRIES:
		if str(item.id) == id:
			return item.duplicate()
	return {}

static func texture_for(id: String) -> Texture2D:
	var item: Dictionary = entry(id)
	if item.is_empty():
		item = entry(DEFAULT_ID)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var assets: Node = tree.root.get_node("AssetManager")
	return assets.get_texture("ui_avatar_" + str(item.file)) as Texture2D

func _ready() -> void:
	_watch_asset_sync()
	if not displayed_id.is_empty():
		_refresh_texture()

func _watch_asset_sync() -> void:
	var assets: Node = get_node("/root/AssetManager")
	if not assets.is_connected("sync_finished", _on_asset_sync):
		assets.connect("sync_finished", _on_asset_sync)

func _on_asset_sync(_success: bool) -> void:
	# Partial syncs can still include this portrait. Never change the selected ID here.
	if not displayed_id.is_empty():
		_refresh_texture()

func _refresh_texture() -> void:
	texture = texture_for(displayed_id)
	material = _mask if texture != null else null
	queue_redraw()

func _draw() -> void:
	if texture != null:
		return
	# Native placeholder for first launch offline; no bundled image is required.
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	if radius <= 0.0:
		return
	draw_circle(center, radius, Color("102040"))
	draw_arc(center, radius, 0.0, TAU, 32, Color("4FE0D4"), 2.0)
	draw_circle(center + Vector2(0.0, -radius * 0.24), radius * 0.24, Color("8FF0E6"))
	draw_rect(Rect2(center + Vector2(-radius * 0.42, radius * 0.12), Vector2(radius * 0.84, radius * 0.40)), Color("8FF0E6"))

func show_avatar(id: String) -> void:
	displayed_id = id if not entry(id).is_empty() else DEFAULT_ID
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_IGNORE
	if _mask == null:
		var shader: Shader = Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){ float d = length(UV - vec2(0.5)); COLOR.rgb = mix(COLOR.rgb, vec3(0.31,0.88,0.83), step(0.465,d)); COLOR.a *= step(d, 0.49); }"
		_mask = ShaderMaterial.new()
		_mask.shader = shader
	_refresh_texture()

func bind_current() -> void:
	# Legacy header TextureRects receive this script after entering the tree.
	_watch_asset_sync()
	var player: Node = get_node("/root/PlayerManager")
	if not player.is_connected("avatar_changed", refresh_current):
		player.connect("avatar_changed", refresh_current)
	refresh_current()

func refresh_current() -> void:
	var player: Node = get_node("/root/PlayerManager")
	show_avatar(player.current_avatar_id())
