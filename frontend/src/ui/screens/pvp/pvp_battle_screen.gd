class_name PvpBattleScreen
extends BaseScreen
## Shared exit confirmation; local practice runs the same CRT workspace as online CTF.
enum Mode { BOT, ONLINE }
const Battle = preload("res://src/gameplay/pvp/pvp_battle.gd")
const PracticeWorkspace: GDScript = preload("res://src/ui/screens/pvp/pvp_flag_terminal.gd")
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var _practice: Battle.FlagPractice
var _practice_panel: PracticeWorkspace
var _abandon: Control
var _abandon_note: Label
var _pause_started: int = -1
var _paused_total: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if battle_mode() == Mode.BOT:
		_build_practice()
	else:
		_build_abandon()
		_style_practice_dialog(_abandon)
		_start_match()
		move_child(_abandon,-1)

func _start_match() -> void:
	pass

func battle_mode() -> Mode:
	return Mode.BOT


func _process(_delta: float) -> void:
	if _practice != null:
		var local_now: int = _clock_now()
		_practice.tick(local_now)
		var deadline: int = _practice.countdown_ends_at if _practice.state == Battle.FlagPractice.State.COUNTDOWN else _practice.ends_at
		_practice_panel.show_clock(0 if _practice.state == Battle.FlagPractice.State.FINISHED else deadline-local_now)
		return



func _exit_tree() -> void:
	_unbind_battle()


func on_exit() -> void:
	_unbind_battle()


func consume_back() -> bool:
	if _practice_panel != null:
		if _practice == null or _practice.state == Battle.FlagPractice.State.FINISHED: return false
		_abandon.visible = not _abandon.visible
		return true
	return false


func _build_practice() -> void:
	_practice_panel = PracticeWorkspace.new()
	_practice_panel.practice_mode = true
	add_child(_practice_panel)
	_practice_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_panel.practice_started.connect(_start_practice)
	_practice_panel.command.connect(_practice_command)
	_practice_panel.replay_requested.connect(_reset_practice)
	_practice_panel.leave_requested.connect(func() -> void: Router.request_back())
	_build_abandon()
	_abandon_note.text = "This local flag race will be discarded."
	_style_practice_dialog(_abandon)
	_practice_panel.prepare_practice()


func _style_practice_dialog(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		control.add_theme_font_override("font", PracticeWorkspace.Terminal.FONT)
		control.add_theme_color_override("font_color", PracticeWorkspace.GREEN)
		if node is PanelContainer: control.add_theme_stylebox_override("panel", PracticeWorkspace.Terminal.box(PracticeWorkspace.BLACK, PracticeWorkspace.GREEN, 2))
		if node is Button:
			for style: String in ["normal","hover","pressed","focus"]:
				control.add_theme_stylebox_override(style, PracticeWorkspace.Terminal.box(PracticeWorkspace.BLACK, PracticeWorkspace.GREEN, 1))
	for child: Node in node.get_children(): _style_practice_dialog(child)


func _reset_practice() -> void:
	if _practice != null:
		_practice.retire()
		_practice.changed.disconnect(_render_practice)
		_practice = null
	_abandon.hide()
	_pause_started = -1
	_paused_total = 0
	_practice_panel.prepare_practice()


func _start_practice(role: String) -> void:
	_reset_practice()
	_practice = Battle.FlagPractice.new()
	_practice.changed.connect(_render_practice)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	_practice.start(role,_clock_now(),random)


func _practice_command(action: String, target: String) -> void:
	if _practice == null or _abandon.visible: return
	var snapshot: Dictionary = _practice.view()
	_practice.act(int(snapshot.revision),str(snapshot.node),action,target,_clock_now())


func _render_practice() -> void:
	if _practice == null: return
	var mode: String = "active"
	var note: String = ""
	if _practice.state == Battle.FlagPractice.State.COUNTDOWN:
		mode = "briefing"
	elif _practice.state == Battle.FlagPractice.State.FINISHED:
		mode = "done"
		note = "DRAW\nTime expired with the flag still in the vault."
		if _practice.winner >= 0:
			var attacker_won: bool = (_practice.role == "attacker") == (_practice.winner == 0)
			note = ("VICTORY" if _practice.winner == 0 else "DEFEAT") + "\n" + ("The attacker retrieved EVENT.FLAG." if attacker_won else "The defender secured EVENT.FLAG in quarantine.")
	_practice_panel.present(_practice.view(),mode,note)
	if mode == "done": _practice_panel.show_rating("PRACTICE / NO RATING CHANGE", "Play again to try another route or role.")


func _on_leave() -> void:
	Router.pop()


func _on_stay() -> void:
	_abandon.hide()


func _build_abandon() -> void:
	_abandon = Control.new()
	_abandon.name = "AbandonConfirm"
	_abandon.mouse_filter = Control.MOUSE_FILTER_STOP
	_abandon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abandon.hide()
	add_child(_abandon)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abandon.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abandon.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_900, Palette.DANGER, 18))
	center.add_child(panel)
	var column: VBoxContainer = UI.column(panel, 14)
	column.add_child(UI.label("LEAVE MATCH?", 22, Palette.CREAM, true))
	_abandon_note = UI.label("This flag race will be discarded.", 20, Palette.CREAM)
	column.add_child(_abandon_note)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var stay: Button = UI.button("STAY", _on_stay, true)
	stay.name = "StayButton"
	var leave: Button = UI.button("LEAVE", _on_leave)
	leave.name = "AbandonLeaveButton"
	actions.add_child(stay)
	actions.add_child(leave)


func _clock_now() -> int:
	var now: int = Time.get_ticks_msec()
	if _abandon != null and _abandon.visible:
		if _pause_started < 0:
			_pause_started = now
		return _pause_started - _paused_total
	if _pause_started >= 0:
		_paused_total += now - _pause_started
		_pause_started = -1
	return now - _paused_total


func _unbind_battle() -> void:
	if _practice != null:
		_practice.retire()
		if _practice.changed.is_connected(_render_practice): _practice.changed.disconnect(_render_practice)
		_practice = null
