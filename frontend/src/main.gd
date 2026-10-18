extends Control
## Root of Main.tscn. The only scene ever loaded directly by the engine —
## everything after this is pushed by the Router into ScreenHost.

@onready var _screen_host: Control = %ScreenHost
@onready var _quit_dialog: Control = %QuitDialog
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
var _tutorial_bar: PanelContainer
var _tutorial_actions: HBoxContainer
var _pending_action: StringName = &""
var _was_paused: bool = false
var _confirming: bool = false
var _confirm_card: PanelContainer
var _confirm_title: Label
var _confirm_body: Label
var _confirm_ok: Button
var _confirm_cancel: Button


func _ready() -> void:
	_setup_navigation()
	AssetManager.sync_catalog()
	Router.replace_all(&"intro")


func _setup_navigation() -> void:
	Router.register_host(_screen_host)
	Router.quit_requested.connect(_on_quit_requested)
	Router.tutorial_leave_requested.connect(_on_tutorial_leave_requested)
	Router.tutorial_state_changed.connect(_refresh_tutorial_controls)
	Router.screen_changed.connect(_on_screen_changed)
	Router.navigation_cancel_requested.connect(_cancel_confirmation)
	_build_confirmation()
	get_tree().auto_accept_quit = false
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TutorialNavigation"
	layer.layer = 50
	add_child(layer)
	_tutorial_bar = PanelContainer.new()
	_tutorial_bar.name = "TutorialControls"
	_tutorial_bar.add_theme_stylebox_override("panel", UI.box(Color("#0A1730"), Color("#173058"), 8))
	layer.add_child(_tutorial_bar)
	_tutorial_actions = HBoxContainer.new()
	_tutorial_actions.add_theme_constant_override("separation", 12)
	_tutorial_bar.add_child(_tutorial_actions)
	var label: Label = UI.label("TUTORIAL / PRACTICE", 24, Color("#8FF0E6"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_actions.add_child(label)
	var skip: Button = UI.button("SKIP TUTORIAL", func() -> void: _show_confirmation(&"skip"))
	skip.name = "SkipTutorialButton"
	_tutorial_actions.add_child(skip)
	var dashboard: Button = UI.button("DASHBOARD", _on_tutorial_leave_requested)
	dashboard.name = "TutorialDashboardButton"
	_tutorial_actions.add_child(dashboard)
	var exit_button: Button = UI.button("EXIT GAME", _on_quit_requested)
	exit_button.name = "TutorialExitButton"
	_tutorial_actions.add_child(exit_button)
	resized.connect(_refresh_tutorial_controls)
	_refresh_tutorial_controls()


func _on_screen_changed(_id: StringName) -> void:
	_refresh_tutorial_controls()


func _build_confirmation() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.9)
	_quit_dialog.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	_quit_dialog.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_card = UI.panel(center)
	_confirm_card.add_theme_stylebox_override("panel", UI.box(Color("#0A1730"), Color("#4FE0D4"), 24))
	var column: VBoxContainer = UI.column(_confirm_card, 24)
	_confirm_title = UI.label("", 32, Color("#8FF0E6"))
	column.add_child(_confirm_title)
	_confirm_body = UI.label("", 28, Color("#F3ECD6"))
	column.add_child(_confirm_body)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	_confirm_cancel = UI.button("", _cancel_confirmation, true)
	_confirm_ok = UI.button("", _on_quit_confirmed)
	for button: Button in [_confirm_cancel, _confirm_ok]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	_confirm_cancel.focus_neighbor_left = _confirm_ok.get_path()
	_confirm_cancel.focus_neighbor_right = _confirm_ok.get_path()
	_confirm_ok.focus_neighbor_left = _confirm_cancel.get_path()
	_confirm_ok.focus_neighbor_right = _confirm_cancel.get_path()
	_confirm_cancel.focus_next = _confirm_ok.get_path()
	_confirm_cancel.focus_previous = _confirm_ok.get_path()
	_confirm_ok.focus_next = _confirm_cancel.get_path()
	_confirm_ok.focus_previous = _confirm_cancel.get_path()


func _refresh_tutorial_controls() -> void:
	if _tutorial_bar == null:
		return
	if _confirm_card != null:
		_confirm_card.custom_minimum_size.x = minf(1050.0, size.x - 48.0)
		UI.fit_touch(_quit_dialog)
	var active: bool = Router.is_tutorial or (Router.current_screen_id() == &"dashboard" and PlayerManager.needs_tutorial())
	_tutorial_bar.visible = active
	var content: Control = $ContentRoot
	if not active:
		content.offset_top = 0.0
		return
	UI.fit_touch(_tutorial_bar)
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var height: float = maxf(72.0, 64.0 / physical)
	_tutorial_bar.position = Vector2.ZERO
	_tutorial_bar.size = Vector2(size.x, height)
	content.offset_top = height


func _on_tutorial_leave_requested() -> void:
	_show_confirmation(&"dashboard")


func _show_confirmation(action: StringName) -> void:
	if _quit_dialog.visible or _confirming or Router.is_busy():
		return
	_pending_action = action
	Router.navigation_confirmation_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_confirm_title.text = "EXIT LEVELBLUE?" if action == &"exit" else "LEAVE TUTORIAL?"
	_confirm_body.text = "Completed progress is saved locally. Unfinished activities will not be completed.\nAn online match may count as a forfeit. You will remain signed in." if action == &"exit" else "Return to the dashboard without completing the tutorial.\nNo mastery or assessment credit is awarded.\nRestart this practice anytime from Settings > Replay tutorial."
	_confirm_ok.text = "EXIT GAME" if action == &"exit" else ("SKIP TUTORIAL" if action == &"skip" else "DASHBOARD")
	_confirm_cancel.text = "KEEP PLAYING" if action == &"exit" else "CONTINUE TUTORIAL"
	_quit_dialog.show()
	_refresh_tutorial_controls()
	_confirm_cancel.grab_focus()


func _cancel_confirmation() -> void:
	get_tree().paused = _was_paused
	_pending_action = &""
	Router.navigation_confirmation_open = false
	_quit_dialog.hide()


func _on_quit_requested() -> void:
	_show_confirmation(&"exit")


func _on_quit_confirmed() -> void:
	if _confirming or _pending_action == &"":
		return
	_confirming = true
	var action: StringName = _pending_action
	_cancel_confirmation()
	if action == &"exit":
		# Ensure the local write; do not wait indefinitely for cloud sync.
		await SaveService.flush()
		get_tree().quit()
	else:
		await Router.leave_tutorial()
	_confirming = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_quit_requested()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		Router.request_back()
		get_viewport().set_input_as_handled()
