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
var _cosmetics: Control

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
	show_cosmetics(player.current_cosmetic_id("frame"), player.current_cosmetic_id("badge"))


## Draws a collectible at 32 by 24 design units in the caller's transform.
static func draw_cosmetic(canvas: CanvasItem, design: String, ink: Color) -> void:
	var dark: Color = Color("#091322")
	var shade: Color = ink.darkened(0.62)
	var bright: Color = ink.lightened(0.55)
	match design:
		"frame":
			canvas.draw_rect(Rect2(5, 2, 23, 22), shade)
			canvas.draw_rect(Rect2(5, 1, 22, 22), ink)
			canvas.draw_rect(Rect2(8, 4, 16, 16), dark)
			canvas.draw_rect(Rect2(10, 6, 12, 12), shade, false, 1)
			canvas.draw_rect(Rect2(13, 8, 6, 5), ink.darkened(0.2))
			canvas.draw_rect(Rect2(14, 9, 5, 2), dark)
			canvas.draw_rect(Rect2(16, 9, 2, 1), bright)
			canvas.draw_rect(Rect2(12, 14, 8, 3), shade)
			canvas.draw_rect(Rect2(14, 14, 4, 1), ink)
			for stripe: int in 4:
				canvas.draw_rect(Rect2(5, 7 + stripe * 3, 2, 1), shade)
				canvas.draw_rect(Rect2(25, 7 + stripe * 3, 2, 1), shade)
			for pos: Vector2 in [Vector2(4, 0), Vector2(23, 0), Vector2(4, 21), Vector2(23, 21)]:
				canvas.draw_rect(Rect2(pos, Vector2(5, 3)), bright)
				canvas.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(1, 1)), shade)
		"drone":
			for rotor: Vector2 in [Vector2(5, 4), Vector2(26, 4), Vector2(5, 18), Vector2(26, 18)]:
				canvas.draw_line(Vector2(16, 11), rotor, shade, 3)
				canvas.draw_rect(Rect2(rotor - Vector2(3, 2), Vector2(7, 6)), shade)
				canvas.draw_rect(Rect2(rotor - Vector2(4, 1), Vector2(9, 3)), ink)
				canvas.draw_rect(Rect2(rotor - Vector2(5, 2), Vector2(5, 1)), bright)
				canvas.draw_rect(Rect2(rotor + Vector2(1, -3), Vector2(5, 1)), bright)
				canvas.draw_rect(Rect2(rotor - Vector2(1, 2), Vector2(3, 2)), dark)
			canvas.draw_rect(Rect2(10, 7, 12, 8), shade)
			canvas.draw_rect(Rect2(12, 5, 8, 11), ink)
			canvas.draw_rect(Rect2(13, 5, 6, 1), bright)
			canvas.draw_rect(Rect2(14, 7, 4, 1), shade)
			canvas.draw_rect(Rect2(11, 11, 10, 4), dark)
			canvas.draw_rect(Rect2(12, 12, 3, 1), bright)
			canvas.draw_rect(Rect2(17, 12, 2, 1), ink)
			canvas.draw_rect(Rect2(13, 16, 6, 2), shade)
		"cloak":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(9, 5), Vector2(16, 0), Vector2(23, 5), Vector2(26, 15), Vector2(30, 23), Vector2(19, 20), Vector2(16, 23), Vector2(3, 22), Vector2(7, 14)]), shade)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(9, 5), Vector2(16, 0), Vector2(23, 5), Vector2(18, 4), Vector2(12, 7), Vector2(9, 14), Vector2(5, 21)]), ink)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(16, 5), Vector2(21, 7), Vector2(20, 12), Vector2(17, 15), Vector2(12, 12), Vector2(11, 9)]), dark)
			canvas.draw_rect(Rect2(13, 10, 3, 1), bright)
			canvas.draw_rect(Rect2(18, 10, 2, 1), bright)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(8, 14), Vector2(15, 17), Vector2(9, 21), Vector2(4, 22)]), ink.darkened(0.26))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(21, 13), Vector2(25, 16), Vector2(28, 22), Vector2(19, 19)]), ink.darkened(0.38))
			canvas.draw_line(Vector2(11, 14), Vector2(17, 17), ink, 1)
			canvas.draw_rect(Rect2(16, 16, 2, 2), bright)


func show_cosmetics(frame_id: String, badge_id: String) -> void:
	if not is_instance_valid(_cosmetics):
		_cosmetics = Control.new()
		_cosmetics.name = "PortraitCosmetics"
		_cosmetics.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_cosmetics)
		_cosmetics.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_cosmetics.resized.connect(_cosmetics.queue_redraw)
		_cosmetics.draw.connect(_draw_cosmetics)
	_cosmetics.set_meta("frame_id", frame_id)
	_cosmetics.set_meta("badge_id", badge_id)
	_cosmetics.queue_redraw()


func _draw_cosmetics() -> void:
	var player: Node = get_node("/root/PlayerManager")
	var frame: Dictionary = player.store_item(str(_cosmetics.get_meta("frame_id", "")))
	var badge: Dictionary = player.store_item(str(_cosmetics.get_meta("badge_id", "")))
	var side: float = floorf(minf(_cosmetics.size.x, _cosmetics.size.y))
	if side < 4:
		return
	var origin: Vector2 = ((_cosmetics.size - Vector2.ONE * side) * 0.5).floor()
	if not frame.is_empty() and str(frame.get("slot", "")) == "frame":
		var ink: Color = Color(str(frame.color))
		var stroke: float = maxf(1, floorf(side / 32.0))
		var rect: Rect2 = Rect2(origin + Vector2.ONE * stroke, Vector2.ONE * (side - stroke * 2))
		_cosmetics.draw_rect(rect, ink.darkened(0.6), false, stroke * 2)
		_cosmetics.draw_rect(rect.grow(-stroke * 2), ink, false, stroke)
		var corner: float = maxf(3, floorf(side * 0.18))
		for point: Vector2 in [rect.position, rect.position + Vector2(rect.size.x - corner, 0), rect.end - Vector2(corner, corner), rect.position + Vector2(0, rect.size.y - corner)]:
			_cosmetics.draw_rect(Rect2(point, Vector2(corner, stroke * 2)), ink.lightened(0.35))
			_cosmetics.draw_rect(Rect2(point, Vector2(stroke * 2, corner)), ink)
		if str(frame.id) == "b2":
			_cosmetics.draw_line(rect.position + Vector2(0, side * 0.3), rect.position + Vector2(side * 0.2, side * 0.3), ink, stroke * 2)
	if not badge.is_empty() and str(badge.get("slot", "")) == "badge":
		var unit: float = side * 0.44 / 32.0
		var anchor: Vector2 = origin + Vector2(side - unit * 32.0, side - unit * 24.0)
		_cosmetics.draw_rect(Rect2(anchor - Vector2.ONE * 2, Vector2(32, 24) * unit + Vector2.ONE * 4), Color("#050B18"))
		_cosmetics.draw_set_transform(anchor, 0, Vector2.ONE * unit)
		draw_cosmetic(_cosmetics, str(badge.art), Color(str(badge.color)))
		_cosmetics.draw_set_transform(Vector2.ZERO)
