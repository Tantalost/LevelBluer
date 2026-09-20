extends Control
## Same beveled silhouettes as the battlefield; no sprite/Cloudinary dependency.
const Glyphs = preload("res://src/gameplay/preview/unit_glyphs.gd")
var tower_id := "base"
var accent := Color("85d9c3")
var unlocked := true

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	modulate = Color.WHITE if unlocked else Color("82929a")

func _draw() -> void:
	if size.x < 1 or size.y < 1:
		return
	var zoom := minf(size.x, size.y) / 96.0
	draw_set_transform(size * 0.5, 0, Vector2.ONE * zoom)
	Glyphs.bevel(self, PackedVector2Array([Vector2(-38,-38), Vector2(38,-38), Vector2(38,38), Vector2(-38,38)]), Color("303b40"))
	Glyphs.tower(self, tower_id, -PI / 2, 0, 30)
	draw_set_transform(Vector2.ZERO)
