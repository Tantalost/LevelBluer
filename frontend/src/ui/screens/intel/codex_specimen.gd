extends Control
## Same draw-only geometry as TowerBase/EnemyBase in the current campaign.
const Glyphs = preload("res://src/gameplay/preview/unit_glyphs.gd")
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var tab: StringName = &"units"
var unit_id: String = "base"
var accent: Color = Color("#4FE0D4")
var compact: bool = false
var angle: float = -PI / 4.0

func _ready() -> void:
	custom_minimum_size = Vector2(72, 72) if compact else Vector2(180, 164)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func rotate_view() -> void:
	angle += PI / 4.0
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	if not compact:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#050B18"))
		for radius: float in [0.31, 0.44]:
			draw_arc(center, minf(size.x, size.y) * radius, 0, TAU, 48, Color(accent, 0.18), 1.0)
		for corner: Vector2 in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(8, size.y - 8), size - Vector2(8, 8)]:
			var direction: Vector2 = Vector2(1 if corner.x < center.x else -1, 1 if corner.y < center.y else -1)
			draw_line(corner, corner + Vector2(14 * direction.x, 0), accent, 2)
			draw_line(corner, corner + Vector2(0, 14 * direction.y), accent, 2)
	var factor: float = minf(size.x, size.y) / (92.0 if tab == &"units" else 76.0)
	var body_angle: float = angle if (tab == &"enemies" or unit_id == "sandbox") and not compact else 0.0
	draw_set_transform(center, body_angle, Vector2.ONE * factor)
	if tab == &"units":
		Glyphs.tower(self, unit_id, angle, 0.0, 37.0)
	else:
		var stats: Dictionary = ContentDB.get_enemy(unit_id)
		var color: Color = stats.get("color", Palette.RED)
		Glyphs.enemy(self, unit_id, angle if compact else 0.0, color)
	draw_set_transform(Vector2.ZERO)
