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
	&"lesson_player": "res://src/ui/screens/intel/lesson_player_screen.tscn",
	&"codex":        "res://src/ui/screens/intel/codex_screen.tscn",
	&"progress":     "res://src/ui/screens/progress/progress_screen.tscn",
	&"upgrades":     "res://src/ui/screens/deploy/upgrade_screen.tscn",
	&"stage_select": "res://src/ui/screens/deploy/stage_select_screen.tscn",
	&"module_stages": "res://src/ui/screens/deploy/module_stage_screen.tscn",
	&"password_change": "res://src/ui/screens/login/password_change_screen.tscn",
	&"settings":     "res://src/ui/screens/settings/settings_screen.tscn",
	&"profile":      "res://src/ui/screens/profile/profile_screen.tscn",
	&"pretest":      "res://src/ui/screens/pretest/pretest_screen.tscn",
	&"victory":      "res://src/ui/screens/victory/victory_screen.tscn",
}

## Emitted when the player tries to back out of the root screen. The main
## scene listens for this and shows a "Quit Level Blue?" confirmation, rather
## than dropping a student out of the app mid-session.
signal quit_requested

const LEVEL_SCENE := "res://src/gameplay/level_base.tscn"

var active_stage_index: int = 0
var _host: Control = null
var _stack: Array[BaseScreen] = []
var _busy: bool = false
var _gameplay: Node = null


## Called once by the main scene, passing the Control that screens live inside.
func register_host(host: Control) -> void:
	_host = host


## Hands off to the TD scene without change_scene_to_file(). Swapping the tree
## root would destroy Main.tscn (ScreenHost, quit dialog, the UI stack).
func start_level(stage_index: int) -> void:
	active_stage_index = stage_index
	if _busy or _host == null:
		push_error("Router: cannot start level (host not registered or busy)")
		return
	if _gameplay != null and is_instance_valid(_gameplay):
		push_warning("Router: a level is already running")
		return
	if not ResourceLoader.exists(LEVEL_SCENE):
		push_error("Router: level scene missing at %s" % LEVEL_SCENE)
		return

	_busy = true
	var packed: PackedScene = load(LEVEL_SCENE) as PackedScene
	if packed == null:
		_busy = false
		push_error("Router: failed to load %s" % LEVEL_SCENE)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_busy = false
		push_error("Router: failed to instantiate level")
		return

	if not _stack.is_empty():
		_stack.back().on_exit()
	_set_ui_stack_active(false)
	_gameplay = instance
	var parent: Node = _host.get_parent()
	if parent == null:
		_busy = false
		_gameplay = null
		instance.queue_free()
		_set_ui_stack_active(true)
		push_error("Router: ScreenHost has no parent")
		return
	parent.add_child(_gameplay)
	_busy = false
	screen_changed.emit(&"gameplay")


func return_to_stage_select() -> void:
	_teardown_gameplay()
	if _host == null:
		return
	_set_ui_stack_active(true)
	if not _stack.is_empty():
		_stack.back().on_resume()
	screen_changed.emit(current_screen_id())


func restart_level() -> void:
	var stage: int = active_stage_index
	_teardown_gameplay()
	start_level(stage)


func open_lessons() -> void:
	if _host == null:
		push_error("Router: cannot open Lessons (host not registered)")
		return
	_teardown_gameplay()
	_set_ui_stack_active(true)
	replace_all(&"dashboard")
	push(&"intel_hub")
	push(&"lessons")


func open_codex(skill_id: String) -> void:
	if _host == null:
		push_error("Router: cannot open Codex (host not registered)")
		return
	var topic: String = skill_id if not skill_id.is_empty() else "ports"
	_teardown_gameplay()
	_set_ui_stack_active(true)
	replace_all(&"dashboard")
	push(&"intel_hub")
	push(&"codex", {"skill_id": topic})


func open_victory(accuracy: float, gold: int) -> void:
	open_results({
		"won": true,
		"materials": maxi(0, gold),
		"accuracy": accuracy,
	})


func open_defeat(tip: String, weak_skill: String) -> void:
	open_results({
		"won": false,
		"materials": 0,
		"tip": tip,
		"weak_skill": weak_skill,
	})


func open_results(args: Dictionary) -> void:
	if _host == null:
		push_error("Router: cannot open results (host not registered)")
		return
	_teardown_gameplay()
	_set_ui_stack_active(true)
	replace_all(&"dashboard")
	push(&"victory", args)


func retry_level() -> void:
	if not _stack.is_empty() and _stack.back().screen_id == &"victory":
		var leaving: BaseScreen = _stack.pop_back()
		leaving.on_exit()
		leaving.queue_free()
	start_level(active_stage_index)


func _teardown_gameplay() -> void:
	if _gameplay == null:
		return
	if is_instance_valid(_gameplay):
		var parent: Node = _gameplay.get_parent()
		if parent != null:
			parent.remove_child(_gameplay)
		_gameplay.queue_free()
	_gameplay = null


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
	if _gameplay != null and is_instance_valid(_gameplay):
		return_to_stage_select()
		return
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


func _set_ui_stack_active(active: bool) -> void:
	if _host == null:
		return
	_host.visible = active
	_host.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_canvas_layers_visible(_host, active)


func _set_canvas_layers_visible(node: Node, active: bool) -> void:
	# CanvasLayer is not a CanvasItem. Hiding a parent Control does not stop it
	# from compositing, which is why BREACH left Tiny Forest under the quiz.
	var kids: Array = node.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child == null:
			continue
		var layer: CanvasLayer = child as CanvasLayer
		if layer != null:
			layer.visible = active
		_set_canvas_layers_visible(child, active)


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
	if packed == null:
		push_error("Router: failed to load '%s' at %s" % [screen_id, path])
		_busy = false
		return null

	var instance: Node = packed.instantiate()
	if instance == null or not (instance is BaseScreen):
		push_error("Router: invalid scene for '%s' at %s" % [screen_id, path])
		_busy = false
		if instance != null:
			instance.queue_free()
		return null

	var screen: BaseScreen = instance
	screen.screen_id = screen_id
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen
