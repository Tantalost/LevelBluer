extends "res://src/autoload/screen_router.gd"
## Real routing/stack logic with inert screens, avoiding account and network side effects.
func _instantiate(id: StringName) -> BaseScreen:
	if not SCREENS.has(id):
		return null
	var screen := BaseScreen.new()
	screen.screen_id = id
	return screen
