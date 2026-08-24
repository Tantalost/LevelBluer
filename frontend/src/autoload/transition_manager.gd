extends CanvasLayer
## Autoload overlay. Fades the whole viewport so screen swaps are not a hard cut.
## Lives on layer 100 so it composites above ScreenHost and gameplay.

@onready var _color_rect: ColorRect = $ColorRect

var _tween: Tween = null


func _ready() -> void:
	layer = 100
	_color_rect.color = Color.BLACK
	_color_rect.modulate.a = 0.0
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_to_black(duration: float = 0.5) -> void:
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_color_rect, "modulate:a", 1.0, duration)
	await _tween.finished


func fade_to_clear(duration: float = 0.5) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_color_rect, "modulate:a", 0.0, duration)
	await _tween.finished
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
