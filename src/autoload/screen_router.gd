extends Node
## Autoload singleton, registered as "Router".
##
## Owns every screen transition in Level Blue. Screens never call
## change_scene_to_file() and never add each other as children — they call
## Router.push() / Router.pop(). Keeping navigation in one place is what makes
## the header back arrows and Android's system back gesture behave identically
## without duplicated logic in nine different screens.
##
## REQUIRED project setting:
##   Application > Config > Quit On Go Back = OFF
## Without it Godot quits the app on the Android back gesture before this
## script ever sees the notification.

signal screen_changed(screen_id: StringName)

const SCREENS: Dictionary = {
	&"splash":       "res://src/ui/screens/intro/splash_screen.tscn",
	&"intro":        "res://src/ui/screens/intro/intro_screen.tscn",
	&"login":        "res://src/ui/screens/login/login_screen.tscn",
	&"dashboard":    "res://src/ui/screens/dashboard/dashboard_screen.tscn",
	&"store":        "res://src/ui/screens/store/store_screen.tscn",
	&"intel_hub":    "res://src/ui/screens/intel/intel_hub_screen.tscn",
	&"lessons":      "res://src/ui/screens/intel/lessons_screen.tscn",
	&"codex":        "res://src/ui/screens/intel/codex_screen.tscn",
	&"progress":     "res://src/ui/screens/progress/progress_screen.tscn",
	&"upgrades":     "res://src/ui/screens/deploy/upgrade_screen.tscn",
	&"stage_select": "res://src/ui/screens/deploy/stage_select_screen.tscn",
	&"password_change": "res://src/ui/screens/login/password_change_screen.tscn",
	&"settings":     "res://src/ui/screens/settings/settings_screen.tscn",
}

## Emitted when the player tries to back out of the root screen. The main
## scene listens for this and shows a "Quit Level Blue?" confirmation, rather
## than dropping a student out of the app mid-session.
signal quit_requested

var _host: Control = null
var _stack: Array[BaseScreen] = []
var _busy: bool = false


## Called once by the main scene, passing the Control that screens live inside.
func register_host(host: Control) -> void:
	_host = host


func push(screen_id: StringName, args: Dictionary = {}) -> void:
	var screen := _instantiate(screen_id)
	if screen == null:
		return

	if not _stack.is_empty():
		_stack.back().on_exit()

	_host.add_child(screen)
	_stack.push_back(screen)
	screen.on_enter(args)

	_busy = false
	screen_changed.emit(screen_id)


## Clears the whole stack and starts fresh. Use this for login -> dashboard,
## where backing up into the login form would be wrong.
func replace_all(screen_id: StringName, args: Dictionary = {}) -> void:
	var screen := _instantiate(screen_id)
	if screen == null:
		return

	for existing in _stack:
		existing.on_exit()
		existing.queue_free()
	_stack.clear()

	_host.add_child(screen)
	_stack.push_back(screen)
	screen.on_enter(args)

	_busy = false
	screen_changed.emit(screen_id)


func pop() -> void:
	if _busy or _stack.size() <= 1:
		return
	_busy = true

	var leaving: BaseScreen = _stack.pop_back()
	leaving.on_exit()
	leaving.queue_free()

	var arriving: BaseScreen = _stack.back()
	arriving.on_resume()

	_busy = false
	screen_changed.emit(arriving.screen_id)


## Single entry point for "the player wants to go back" — wire your header
## back arrows to this, not to pop(), so screens that must not be dismissed
## (the forced password change) can refuse in one place.
func request_back() -> void:
	if _busy or _stack.is_empty():
		return

	var current: BaseScreen = _stack.back()
	if not current.can_go_back():
		return

	if _stack.size() == 1:
		quit_requested.emit()
		return

	pop()


func current_screen_id() -> StringName:
	return _stack.back().screen_id if not _stack.is_empty() else &""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		request_back()


func _instantiate(screen_id: StringName) -> BaseScreen:
	if _busy or _host == null:
		return null
	if not SCREENS.has(screen_id):
		push_error("Router: unknown screen id '%s'" % screen_id)
		return null

	_busy = true
	var path: String = SCREENS[screen_id]
	if not ResourceLoader.exists(path):
		push_error("Router: scene missing for '%s' at %s" % [screen_id, path])
		_busy = false
		return null
	var packed: PackedScene = load(path)
	var screen: BaseScreen = packed.instantiate()
	screen.screen_id = screen_id
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen
