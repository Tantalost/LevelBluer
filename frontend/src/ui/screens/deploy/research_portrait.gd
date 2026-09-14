extends Control
## Shared hardware portrait for the armory and compact tower switcher.
const Glyphs = preload("res://src/ui/screens/deploy/upgrade_glyphs.gd")
var tower_id := "base"
var accent := Color("85d9c3")
var base_art: Texture2D
var head_art: Texture2D

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	AssetManager.sync_finished.connect(_refresh_art)
	_refresh_art(true)

func _refresh_art(_success: bool) -> void:
	base_art = AssetManager.get_texture("tower_basic_node_base")
	head_art = AssetManager.get_texture("tower_basic_node_head")
	queue_redraw()

func _draw() -> void:
	if size.x < 1 or size.y < 1:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.37
	for i in range(4, 0, -1):
		draw_circle(center, radius * (1 + i * 0.13), Color(accent, 0.025))
	draw_arc(center, radius * 1.2, -PI * 0.85, PI * 0.85, 60, Color(accent, 0.3), 2, true)
	if tower_id == "base" and base_art != null:
		_fit(base_art, center + Vector2(0, radius * 0.18), radius * 1.8)
		if head_art != null:
			_fit(head_art, center - Vector2(0, radius * 0.1), radius * 2)
	else:
		var points := PackedVector2Array([center + Vector2(0, radius), center + Vector2(radius, radius * 0.55), center + Vector2(0, 0.1 * radius), center + Vector2(-radius, radius * 0.55)])
		draw_colored_polygon(points, Color(accent, 0.1))
		points.append(points[0])
		draw_polyline(points, accent, 2, true)
		Glyphs.paint(self, center - Vector2(0, radius * 0.2), radius * 0.65, tower_id if tower_id != "base" else "root", accent)

func _fit(texture: Texture2D, center: Vector2, diameter: float) -> void:
	var extent := texture.get_size()
	extent *= diameter / maxf(extent.x, extent.y)
	draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false)
