extends ProgressBar
## Presentation-only interpolation. Never drives quiz deadlines or wave state.
var accent := Color("85d9c3")
var animated := true
var _clock := 0.0
var _target := -1.0
var _tween: Tween

func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_progress(amount: float, maximum: float, snap: bool = false) -> void:
	var reset := not is_equal_approx(max_value, maximum)
	max_value = maxf(1, maximum)
	amount = clampf(amount, 0, max_value)
	if not reset and is_equal_approx(_target, amount):
		return
	_target = amount
	if _tween != null:
		_tween.kill()
	if snap or reset or not is_inside_tree():
		value = amount
	else:
		_tween = create_tween()
		_tween.tween_property(self, "value", amount, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if animated and is_visible_in_tree():
		_clock += delta
		queue_redraw()

func _draw() -> void:
	if not animated or max_value <= 0:
		return
	var width := size.x * clampf(value / max_value, 0, 1)
	if width < 1:
		return
	var beam := Rect2(fposmod(_clock * 90, size.x + 60) - 60, 0, 44, size.y)
	var fill := Rect2(0, 0, width, size.y)
	if fill.intersects(beam):
		draw_rect(fill.intersection(beam), Color(1, 1, 1, 0.16))
	draw_rect(Rect2(maxf(0, width - 2), 0, 2, size.y), Color(accent, 0.65))
