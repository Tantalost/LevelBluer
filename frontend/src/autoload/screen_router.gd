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

var is_tutorial: bool = false
var tutorial_beat: StringName = &""
var active_stage_index: int = 0
var active_module_id: String = "mod_01"

const SCREENS: Dictionary = {
	&"splash":       "res://src/ui/screens/intro/splash_screen.tscn",
	&"asset_loading": "res://src/ui/screens/intro/splash_screen.tscn",
	&"intro":        "res://src/ui/screens/intro/intro_screen.tscn",
	&"login":        "res://src/ui/screens/login/login_screen.tscn",
	&"dashboard":    "res://src/ui/screens/dashboard/dashboard_screen.tscn",
	&"store":        "res://src/ui/screens/store/store_screen.tscn",
	&"lessons":      "res://src/ui/screens/intel/lessons_screen.tscn",
	&"lesson_player": "res://src/ui/screens/intel/lesson_player_screen.tscn",
	&"codex":        "res://src/ui/screens/intel/codex_screen.tscn",
	&"progress":     "res://src/ui/screens/progress/progress_screen.tscn",
	&"upgrades":     "res://src/ui/screens/deploy/upgrade_screen.tscn",
	&"missions":     "res://src/ui/screens/deploy/missions_screen.tscn",
	&"stage_select": "res://src/ui/screens/deploy/stage_select_screen.tscn",
	&"module_intro": "res://src/ui/screens/deploy/module_intro_screen.tscn",
	&"module_stages": "res://src/ui/screens/deploy/module_stage_screen.tscn",
	&"password_change": "res://src/ui/screens/login/password_change_screen.tscn",
	&"settings":     "res://src/ui/screens/settings/settings_screen.tscn",
	&"profile":      "res://src/ui/screens/profile/profile_screen.tscn",
	&"pretest":      "res://src/ui/screens/pretest/pretest_screen.tscn",
	&"victory":      "res://src/ui/screens/victory/victory_screen.tscn",
	&"certificate":  "res://src/ui/screens/intel/certificate_screen.tscn",
}

## Emitted when the player tries to back out of the root screen. The main
## scene listens for this and shows a "Quit Level Blue?" confirmation, rather
## than dropping a student out of the app mid-session.
signal quit_requested

const LEVEL_SCENE := "res://src/gameplay/level_base.tscn"
const PREVIEW_SCENE := "res://src/gameplay/preview/stage_one_preview.tscn"
var active_match_context: MatchContext = MatchContext.new()

var _host: Control = null
var _stack: Array[BaseScreen] = []
var _busy: bool = false
var _gameplay: Node = null


## Called once by the main scene, passing the Control that screens live inside.
func register_host(host: Control) -> void:
	_host = host


## Hands off to the TD scene without change_scene_to_file(). Swapping the tree
## root would destroy Main.tscn (ScreenHost, quit dialog, the UI stack).
func start_level(stage_index: int, module_id: String = "") -> void:
	if _busy or _host == null:
		push_error("Router: cannot start level (host not registered or busy)")
		return
	if _gameplay != null and is_instance_valid(_gameplay):
		push_warning("Router: a level is already running")
		return
	if not ResourceLoader.exists(LEVEL_SCENE):
		push_error("Router: level scene missing at %s" % LEVEL_SCENE)
		return
	if not module_id.strip_edges().is_empty():
		active_module_id = module_id.strip_edges()
	elif active_module_id.strip_edges().is_empty():
		active_module_id = "mod_01"
	await _navigate(true, func() -> void: _begin_gameplay(stage_index))


func start_gameplay_preview() -> void:
	if _busy or _host == null or is_tutorial or is_instance_valid(_gameplay):
		return
	if not StageManager.access_reason(1, "mod_01").is_empty():
		return
	await _navigate(true, func() -> void: _begin_gameplay(0, MatchContext.stage_one_preview()))


func start_tutorial() -> void:
	if not PlayerManager.needs_tutorial():
		open_module_select_screen()
		return
	is_tutorial = true
	tutorial_beat = &"match"
	active_module_id = "mod_01"
	await start_level(0)
	if _gameplay == null or not is_instance_valid(_gameplay):
		is_tutorial = false
		tutorial_beat = &""


func enter_gameplay(stage_index: int) -> void:
	if _host == null:
		push_error("Router: cannot enter gameplay (host not registered)")
		return
	var tree: SceneTree = get_tree()
	while _busy:
		if tree == null:
			return
		await tree.process_frame
	if not AssetManager.has_required_gameplay_assets():
		push_error("Router: required gameplay assets are not available locally")
		return
	if _gameplay != null and is_instance_valid(_gameplay):
		push_warning("Router: a level is already running")
		return
	await _navigate(true, func() -> void:
		if current_screen_id() == &"asset_loading":
			_pop_now()
		_begin_gameplay(stage_index)
	)


func return_to_stage_select() -> void:
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		if _host == null:
			return
		_set_ui_stack_active(true)
		if not _stack.is_empty():
			_stack.back().on_resume()
		screen_changed.emit(current_screen_id())
	, true)


func restart_level() -> void:
	var stage: int = active_stage_index
	var context: MatchContext = active_match_context
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_begin_gameplay(stage, context)
	)


func advance_level() -> void:
	# Stage indices are zero-based; index 9 is the final stage.
	if active_stage_index >= 9:
		return
	var next_stage: int = active_stage_index + 1
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_begin_gameplay(next_stage)
	)


func open_defeat_upgrades() -> void:
	if _host == null:
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"upgrades")
	)


func open_dashboard() -> void:
	if _host == null:
		push_error("Router: cannot open Dashboard (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
	)


func open_settings() -> void:
	if _host == null:
		push_error("Router: cannot open Settings (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"settings")
	)


func open_lessons() -> void:
	if _host == null:
		push_error("Router: cannot open Lessons (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		# Lessons returns directly to Dashboard, including after a failed stage.
		_push_now(&"lessons")
	)


func open_tutorial_upgrades() -> void:
	if _host == null:
		push_error("Router: cannot open tutorial upgrades (host not registered)")
		return
	is_tutorial = true
	tutorial_beat = &"upgrade"
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"upgrades")
	)


func open_tutorial_lesson() -> void:
	if _host == null:
		push_error("Router: cannot open tutorial lesson (host not registered)")
		return
	is_tutorial = true
	tutorial_beat = &"lesson"
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"lesson_player", {"module_id": "mod_01", "tutorial": true})
	)


func open_tutorial_dashboard() -> void:
	if _host == null:
		push_error("Router: cannot open tutorial dashboard (host not registered)")
		return
	is_tutorial = true
	tutorial_beat = &"dash"
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
	)


func finish_tutorial() -> void:
	PlayerManager.mark_tutorial_complete()
	is_tutorial = false
	tutorial_beat = &""


func open_codex(skill_id: String) -> void:
	if _host == null:
		push_error("Router: cannot open Codex (host not registered)")
		return
	var topic: String = skill_id if not skill_id.is_empty() else "phishing"
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"codex", {"skill_id": topic})
	)


func open_splash_screen() -> void:
	if _host == null:
		push_error("Router: cannot open Splash (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"splash")
	)


func open_login_screen() -> void:
	if _host == null:
		push_error("Router: cannot open Login (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"login")
	)


func open_certificate_screen() -> void:
	if _host == null:
		push_error("Router: cannot open Certificate (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"certificate")
	)


func open_missions_screen() -> void:
	if _host == null:
		push_error("Router: cannot open Missions (host not registered)")
		return
	if _gameplay != null and is_instance_valid(_gameplay):
		await _navigate(true, func() -> void:
			_teardown_gameplay()
			_set_ui_stack_active(true)
			_replace_all_now(&"dashboard")
			_push_now(&"missions")
		)
		return
	_push_now(&"missions")


func open_module_select_screen() -> void:
	if _host == null:
		push_error("Router: cannot open Module Select (host not registered)")
		return
	await _navigate(true, func() -> void:
		_dismiss_missions_if_open()
		_push_now(&"stage_select")
	)


func open_stage_select_screen() -> void:
	open_module_select_screen()


func _dismiss_missions_if_open() -> void:
	if current_screen_id() != &"missions":
		return
	if _stack.size() <= 1:
		return
	_pop_now()


func open_victory(accuracy: float, gold: int) -> void:
	var payout: int = maxi(0, gold)
	open_results({
		"won": true,
		"credits": payout,
		"materials": payout,
		"accuracy": accuracy,
	})


func open_defeat(tip: String, weak_skill: String, credits: int = 0) -> void:
	var payout: int = maxi(0, credits)
	open_results({
		"won": false,
		"credits": payout,
		"materials": payout,
		"tip": tip,
		"weak_skill": weak_skill,
	})


func open_results(args: Dictionary) -> void:
	if _host == null:
		push_error("Router: cannot open results (host not registered)")
		return
	await _navigate(true, func() -> void:
		_teardown_gameplay()
		_set_ui_stack_active(true)
		_replace_all_now(&"dashboard")
		_push_now(&"victory", args)
	)


func retry_level() -> void:
	if not _stack.is_empty() and _stack.back().screen_id == &"victory":
		_pop_now()
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
	active_match_context = MatchContext.new()
	if not PlayerManager.needs_tutorial():
		is_tutorial = false
		tutorial_beat = &""
	Engine.time_scale = 1.0
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false


func push(screen_id: StringName, args: Dictionary = {}) -> void:
	await _navigate(not _is_overlay(screen_id), func() -> void: _push_now(screen_id, args))


## Clears the whole stack and starts fresh. Use this for login -> dashboard,
## where backing up into the login form would be wrong.
func replace_all(screen_id: StringName, args: Dictionary = {}) -> void:
	await _navigate(not _is_overlay(screen_id), func() -> void: _replace_all_now(screen_id, args))


## Drops the current screen and opens `screen_id` in its place. Back then
## returns to whatever was under the current screen, not to this one.
func replace(screen_id: StringName, args: Dictionary = {}) -> void:
	await _navigate(not _is_overlay(screen_id), func() -> void: _replace_now(screen_id, args))


func pop() -> void:
	if _stack.size() <= 1:
		return
	await _navigate(not _is_overlay(current_screen_id()), func() -> void: _pop_now(), true)


## Single entry point for "the player wants to go back" — wire your header
## back arrows to this, not to pop(), so screens that must not be dismissed
## (the forced password change) can refuse in one place.
func request_back() -> void:
	if is_tutorial:
		return
	if _gameplay != null and is_instance_valid(_gameplay):
		if active_match_context.preview and _gameplay.has_method("toggle_pause"):
			_gameplay.toggle_pause()
			return
		var manager: Node = _gameplay.get_node_or_null("LevelManager")
		if manager is LevelManager:
			(manager as LevelManager).toggle_pause()
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


func _navigate(use_fx: bool, action: Callable, backwards: bool = false) -> void:
	if _busy or _host == null:
		return
	_busy = true
	var play_fx: bool = use_fx and not _stack.is_empty()
	if play_fx:
		await TransitionManager.cover(backwards)
	action.call()
	if play_fx:
		var tree: SceneTree = get_tree()
		if tree != null:
			await tree.process_frame
		await TransitionManager.reveal(backwards)
	_busy = false


func _is_overlay(screen_id: StringName) -> bool:
	return screen_id == &"missions"


func _push_now(screen_id: StringName, args: Dictionary = {}) -> void:
	var screen: BaseScreen = _instantiate(screen_id)
	if screen == null:
		return
	if not _stack.is_empty():
		_stack.back().on_exit()
	_host.add_child(screen)
	_stack.push_back(screen)
	screen.on_enter(args)
	screen_changed.emit(screen_id)


func _replace_now(screen_id: StringName, args: Dictionary = {}) -> void:
	var screen: BaseScreen = _instantiate(screen_id)
	if screen == null:
		return
	if not _stack.is_empty():
		var leaving: BaseScreen = _stack.pop_back()
		leaving.on_exit()
		if leaving.get_parent() == _host:
			_host.remove_child(leaving)
		leaving.queue_free()
	_host.add_child(screen)
	_stack.push_back(screen)
	screen.on_enter(args)
	screen_changed.emit(screen_id)


func _replace_all_now(screen_id: StringName, args: Dictionary = {}) -> void:
	var screen: BaseScreen = _instantiate(screen_id)
	if screen == null:
		return
	for existing in _stack:
		existing.on_exit()
		existing.queue_free()
	_stack.clear()
	_host.add_child(screen)
	_stack.push_back(screen)
	screen.on_enter(args)
	screen_changed.emit(screen_id)


func _pop_now() -> void:
	if _stack.size() <= 1:
		return
	var leaving: BaseScreen = _stack.pop_back()
	leaving.on_exit()
	if leaving.get_parent() == _host:
		_host.remove_child(leaving)
	leaving.queue_free()
	if _stack.is_empty():
		return
	var arriving: BaseScreen = _stack.back()
	arriving.on_resume()
	screen_changed.emit(arriving.screen_id)


func _begin_gameplay(stage_index: int, context: MatchContext = null) -> void:
	if context == null:
		context = MatchContext.new()
	context.stage_id = stage_index + 1
	if not context.preview and not AssetManager.has_required_gameplay_assets():
		push_error("Router: required gameplay assets are not available locally")
		_set_ui_stack_active(true)
		return
	active_stage_index = stage_index
	if _gameplay != null and is_instance_valid(_gameplay):
		push_warning("Router: a level is already running")
		return
	var scene_path: String = PREVIEW_SCENE if context.preview else LEVEL_SCENE
	if not ResourceLoader.exists(scene_path):
		push_error("Router: level scene missing at %s" % LEVEL_SCENE)
		return
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Router: failed to load %s" % LEVEL_SCENE)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("Router: failed to instantiate level")
		return
	# Configure before entering the tree; no preview side effects can run first.
	active_match_context = context
	if context.preview:
		instance.set("match_context", context)
	if not _stack.is_empty():
		_stack.back().on_exit()
	_set_ui_stack_active(false)
	_gameplay = instance
	var parent: Node = _host.get_parent()
	if parent == null:
		_gameplay = null
		instance.queue_free()
		_set_ui_stack_active(true)
		push_error("Router: ScreenHost has no parent")
		return
	parent.add_child(_gameplay)
	screen_changed.emit(&"gameplay")


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
	if _host == null:
		return null
	if not SCREENS.has(screen_id):
		push_error("Router: unknown screen id '%s'" % screen_id)
		return null

	var path: String = SCREENS[screen_id]
	if not ResourceLoader.exists(path):
		push_error("Router: scene missing for '%s' at %s" % [screen_id, path])
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Router: failed to load '%s' at %s" % [screen_id, path])
		return null

	var instance: Node = packed.instantiate()
	if instance == null or not (instance is BaseScreen):
		push_error("Router: invalid scene for '%s' at %s" % [screen_id, path])
		if instance != null:
			instance.queue_free()
		return null

	var screen: BaseScreen = instance
	screen.screen_id = screen_id
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen
