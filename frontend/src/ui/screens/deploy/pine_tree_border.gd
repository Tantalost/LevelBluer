extends Control
## Procedural U-shaped pine frame around the stage dock. Art swap later:
## assign a TextureRect over this node; this draw is the layout placeholder.

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return

	var tree_w := maxf(14.0, size.x / 42.0)
	var bottom_h := size.y * 0.42
	var side_h := size.y * 0.92

	var x := tree_w * 0.5
	while x < size.x:
		var h := bottom_h * (0.75 + 0.25 * sin(x * 0.21))
		_draw_tree(Vector2(x, size.y - 2.0), h, tree_w)
		x += tree_w * 0.72

	var y := size.y - 4.0
	while y > size.y * 0.12:
		var h := side_h * 0.38
		_draw_tree(Vector2(tree_w * 0.55, y), h, tree_w)
		_draw_tree(Vector2(size.x - tree_w * 0.55, y), h, tree_w)
		y -= tree_w * 0.85


func _draw_tree(base: Vector2, height: float, tree_w: float) -> void:
	var half := tree_w * 0.55
	var top := base + Vector2(0.0, -height)
	var left := base + Vector2(-half, 0.0)
	var right := base + Vector2(half, 0.0)
	draw_colored_polygon(PackedVector2Array([top, left, right]), Palette.PINE)
	var mid := base + Vector2(0.0, -height * 0.38)
	draw_colored_polygon(
		PackedVector2Array([
			top + Vector2(0.0, height * 0.08),
			mid + Vector2(-half * 0.55, 0.0),
			mid + Vector2(half * 0.55, 0.0),
		]),
		Palette.PINE_LIT,
	)
