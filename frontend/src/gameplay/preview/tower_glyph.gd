extends Control
const Glyphs = preload("res://src/gameplay/preview/unit_glyphs.gd")
var kind := "base"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var zoom := minf(size.x, size.y) / 74.0
	draw_set_transform(size * 0.5, 0, Vector2.ONE * zoom)
	Glyphs.tower(self, kind, -PI / 2, 0, 29)
	draw_set_transform(Vector2.ZERO)
