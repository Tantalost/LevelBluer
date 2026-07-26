@tool
class_name SafeAreaContainer
extends MarginContainer
## Keeps its children clear of camera cutouts and the gesture bar.
##
## This matters more for Level Blue than for a portrait game. In landscape the
## notch sits on the LEFT or RIGHT edge, which is exactly where your header
## back arrow and your currency pills live. On a notched device those controls
## end up under the cutout and become untappable.
##
## Wrap the root of every screen in one of these. The device rotating, or the
## player flipping the phone 180 degrees, moves the notch to the other side —
## which is why this recalculates on resize rather than reading once at ready.

## Extra padding applied on top of the system safe area, so screens don't have
## to fight the container for breathing room.
@export var extra_margin: int = 16:
	set(value):
		extra_margin = value
		_apply()


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return

	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return

	var safe := DisplayServer.get_display_safe_area()
	var visible_size := get_viewport().get_visible_rect().size

	# The safe area comes back in real device pixels, but our margins are in
	# stretched viewport units. Convert between the two or the insets will be
	# wrong by exactly the stretch factor.
	var scale_x := visible_size.x / float(window_size.x)
	var scale_y := visible_size.y / float(window_size.y)

	# Clamp to zero. On desktop the "safe area" is the whole monitor, which is
	# larger than the game window and yields negative insets; on Android the
	# values are real. Clamping gives correct behaviour on both without
	# branching on platform.
	var left := maxi(0, int(safe.position.x * scale_x)) + extra_margin
	var top := maxi(0, int(safe.position.y * scale_y)) + extra_margin
	var right := maxi(0, int((window_size.x - safe.end.x) * scale_x)) + extra_margin
	var bottom := maxi(0, int((window_size.y - safe.end.y) * scale_y)) + extra_margin
	
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
