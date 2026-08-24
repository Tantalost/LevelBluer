extends CanvasLayer
## Autoload overlay. Fade-through-navy for screen swaps — no shaders, no shatter.
## Lives on layer 100 so it composites above ScreenHost and gameplay.

const SWAP_COVER := 0.2
const SWAP_REVEAL := 0.26

@onready var _veil: ColorRect = $ColorRect

var _tween: Tween = null
var _cover_amount: float = 0.0


func _ready() -> void:
	layer = 100
	_veil.material = null
	_veil.color = Color(Palette.BG_DEEP, 0.0)
	_veil.visible = false
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_offsets()


func cover(_backwards: bool = false) -> void:
	await fade_to_black(SWAP_COVER)


func reveal(_backwards: bool = false) -> void:
	await fade_to_clear(SWAP_REVEAL)


func is_covered() -> bool:
	return _veil.visible and _cover_amount >= 0.999


func fade_to_black(duration: float = 0.55) -> void:
	_veil.visible = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_offsets()
	if is_covered():
		return
	_kill_tween()
	_set_cover(_cover_amount)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_cover, _cover_amount, 1.0, duration)
	await _tween.finished


func fade_to_clear(duration: float = 0.55) -> void:
	_veil.visible = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_offsets()
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_cover, _cover_amount, 0.0, duration)
	await _tween.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false


func _set_cover(value: float) -> void:
	_cover_amount = clampf(value, 0.0, 1.0)
	_veil.color = Color(Palette.BG_DEEP, _cover_amount)


func _reset_offsets() -> void:
	_veil.offset_left = 0.0
	_veil.offset_top = 0.0
	_veil.offset_right = 0.0
	_veil.offset_bottom = 0.0


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
