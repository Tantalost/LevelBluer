@tool
extends Node2D
## Ground occupancy is independent of the sprite's vertical extent.

@export var module_id: StringName
@export var occupied_cells: Array[Vector2i] = [Vector2i.ZERO]
@export var blocks_movement: bool = true
@export var show_footprint: bool = false:
	set(value):
		show_footprint = value
		queue_redraw()


func _draw() -> void:
	if not show_footprint or not Engine.is_editor_hint():
		return
	for cell in occupied_cells:
		var center := Vector2(64 * (cell.x - cell.y), 32 * (cell.x + cell.y))
		var points := PackedVector2Array([
			center + Vector2(0, -32), center + Vector2(64, 0),
			center + Vector2(0, 32), center + Vector2(-64, 0),
			center + Vector2(0, -32)])
		draw_polyline(points, Color(0.2, 0.85, 0.8, 0.85), 1.5)
