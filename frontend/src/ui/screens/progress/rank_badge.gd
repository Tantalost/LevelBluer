extends Control
## Reusable eight-rank insignia with no bitmap dependency.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var rank_index := 0

func _ready() -> void:
	custom_minimum_size = Vector2(130, 150)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.43
	var shield := PackedVector2Array()
	for point in [Vector2(-0.8,-0.9), Vector2(0.8,-0.9), Vector2(0.8,0.4), Vector2(0,1), Vector2(-0.8,0.4), Vector2(-0.8,-0.9)]:
		shield.append(center + point * r)
	draw_colored_polygon(shield, Color("243c3d"))
	draw_polyline(shield, UI.GOLD, 3, true)
	for i in range(1 + clampi(rank_index, 0, 7) / 2):
		var y := center.y - r * 0.45 + i * r * 0.26
		draw_polyline(PackedVector2Array([Vector2(center.x-r*0.45,y), Vector2(center.x,y+r*0.2), Vector2(center.x+r*0.45,y)]), UI.TEAL, 4, true)
	if rank_index % 2 == 1:
		draw_circle(center + Vector2(0, -r * 0.72), 4, UI.GOLD)
