class_name PvpOnlineScreen
extends PvpBattleScreen
## Private-room online duel. Reuses the duel presentation in ONLINE mode.
## Owns exactly one PvpOnlineSession from lobby to final result and frees it only when the player leaves.
## Questions, options, answer verdicts, HP, and winners come from server events; nothing is graded or scored here.

const Session = preload("res://src/network/pvp_online_session.gd")
const CODE_MAX_LENGTH: int = 12
const ROUND_ERRORS: PackedStringArray = ["late", "round_resolved", "already_answered", "wrong_round"]

## () -> PvpOnlineSession. Tests inject a session wired to fake transports.
var session_factory: Callable = Callable()

var _session: Session
var _sessions_created: int = 0
var _action: String = "create"
var _leaving: bool = false
var _left: bool = false
var _recovery_tried: bool = false
var _in_match: bool = false
var _view: Dictionary = {}
var _round_number: int = 0
var _shown_round: int = 0
var _lock_note: String = ""
var _opponent_offline: bool = false
var _opponent_grace_ends_at: int = 0
var _ready_sent: bool = false

var _lobby_host: ScrollContainer
var _entry: VBoxContainer
var _code_input: LineEdit
var _join_button: Button
var _retry_button: Button
var _room_box: VBoxContainer
var _code_label: Label
var _share_label: Label
var _copy_button: Button
var _opponent_label: Label
var _ready_label: Label
var _you_card: PanelContainer
var _rival_card: PanelContainer
var _rival_name: Label
var _ready_button: Button
var _lobby_status: Label
var _lobby_error: Label
var _leave_room_button: Button
var _banner: Label


func battle_mode() -> Mode:
	return Mode.ONLINE


func on_enter(args: Dictionary) -> void:
	_action = "join" if str(args.get("action", "create")) == "join" else "create"
	if _action == "create":
		_create_room()
	_render_online()


func on_exit() -> void:
	super()
	_drop_session()


func _exit_tree() -> void:
	super()
	# The child session already closed its socket on its own exit; only drop the reference.
	_session = null


func consume_back() -> bool:
	if _leaving:
		return true
	if not _match_live():
		_leave_online()
		return true
	_abandon.visible = not _abandon.visible
	return true


func _process(_delta: float) -> void:
	if _leaving:
		if _session == null or not _session.is_socket_open():
			_complete_leave()
		return
	if _session == null:
		return
	_update_online_hud()
	_update_banner()


## Called by the shared _ready(). Online mode builds its lobby and session; it never creates a local battle.
func _start_match() -> void:
	_bot_name.text = "RIVAL"
	_abandon_note.text = "Leaving forfeits an active match."
	var rematch: Node = _footer.get_node_or_null("RematchButton")
	if rematch is Control:
		(rematch as Control).hide()
	_build_banner()
	_build_lobby()
	_ensure_session()
	_render_online()


func _on_leave() -> void:
	_leave_online()


func _on_rematch() -> void:
	pass


# ---- session ownership ---------------------------------------------------------------

func _ensure_session() -> void:
	if _session != null:
		return
	var made: Session = null
	if session_factory.is_valid():
		made = session_factory.call() as Session
	if made == null:
		made = Session.new()
	made.name = "OnlineSession"
	_session = made
	_sessions_created += 1
	add_child(made)
	made.room_created.connect(_on_room_entered)
	made.room_joined.connect(_on_room_entered)
	made.room_updated.connect(_on_room_updated)
	made.opponent_connected.connect(_on_opponent_connected)
	made.opponent_disconnected.connect(_on_opponent_disconnected)
	made.countdown_started.connect(_on_countdown_started)
	made.round_started.connect(_on_round_started)
	made.local_answer_locked.connect(_on_local_answer_locked)
	made.round_resolved.connect(_on_round_resolved)
	made.match_finished.connect(_on_match_finished)
	made.connection_changed.connect(_on_connection_changed)
	made.error_received.connect(_on_error_received)


func _drop_session() -> void:
	if _session == null:
		return
	var leaving: Session = _session
	_session = null
	if not _leaving:
		leaving.leave()
	if leaving.get_parent() == self:
		remove_child(leaving)
	leaving.queue_free()


func _leave_online() -> void:
	if _leaving or _left:
		return
	_leaving = true
	_abandon.hide()
	_lobby_status.text = "Leaving…"
	if _session != null:
		_session.leave()
	_render_online()
	if _session == null or not _session.is_socket_open():
		_complete_leave()


func _complete_leave() -> void:
	if _left:
		return
	_left = true
	_drop_session()
	Router.pop()


func _create_room() -> void:
	if _session == null or _leaving:
		return
	_lobby_error.text = ""
	_session.create_room()


func _submit_code() -> void:
	if _session == null or _leaving:
		return
	var code: String = normalize_code(_code_input.text)
	_code_input.text = code
	if code.is_empty():
		_lobby_error.text = "Enter the room code your classmate shared."
		return
	_lobby_error.text = ""
	_session.join_room(code)


func _recover_room(code: String) -> void:
	if _session == null or _leaving or code.is_empty():
		return
	_session.recover_room(code)


static func normalize_code(raw: String) -> String:
	return raw.strip_edges().replace(" ", "").to_upper()


# ---- session events ------------------------------------------------------------------

func _on_room_entered(_code: String) -> void:
	_render_online()


func _on_room_updated(next_view: Dictionary) -> void:
	_view = next_view
	var number: int = int(next_view.get("round_number", 0))
	if number > 0:
		_round_number = number
	var opponent: String = _session.opponent_id() if _session != null else ""
	if not opponent.is_empty():
		_opponent_offline = not _flag("connected", opponent)
		if not _opponent_offline:
			_opponent_grace_ends_at = 0
	_render_online()


func _on_opponent_connected() -> void:
	_opponent_offline = false
	_opponent_grace_ends_at = 0
	_render_online()


func _on_opponent_disconnected(grace_ends_at: int) -> void:
	_opponent_offline = true
	_opponent_grace_ends_at = grace_ends_at
	_render_online()


func _on_countdown_started(round_number: int, _countdown_ends_at: int) -> void:
	_round_number = round_number
	_render_online()


func _on_round_started(round_data: Dictionary) -> void:
	_round_number = int(round_data.get("round", _round_number))
	_render_online()


func _on_local_answer_locked(round_number: int, _option_index: int, correct: bool) -> void:
	if _session == null or round_number != int(_session.current_round.get("round", 0)):
		return
	_lock_note = "CORRECT — WAITING FOR SERVER" if correct else "INCORRECT — WAITING FOR RIVAL"
	if _session.state == Session.State.ACTIVE:
		_apply_answer_lock()


func _on_round_resolved(result: Dictionary) -> void:
	_render_online()
	_play_result_fx(result)


func _on_match_finished(_result: Dictionary) -> void:
	_render_online()


func _on_connection_changed(_next_state: int) -> void:
	_render_online()


func _on_error_received(code: String, message: String) -> void:
	if _session == null:
		return
	if code == "reconnect_failed" and not _recovery_tried and not _session.room_code.is_empty():
		# Grace is over; ask the server once for the authoritative final result.
		_recovery_tried = true
		_recover_room.call_deferred(_session.room_code)
	if _session.state == Session.State.ACTIVE and ROUND_ERRORS.has(code):
		_lock_note = message.to_upper()
		_apply_answer_lock()
		return
	_lobby_error.text = message
	_render_online()


# ---- rendering (server state only) ----------------------------------------------------

func _render_online() -> void:
	if _session == null or _lobby_host == null:
		return
	var state: Session.State = _session.state
	if state == Session.State.COUNTDOWN or state == Session.State.ACTIVE or state == Session.State.ROUND_RESULT or state == Session.State.FINISHED:
		_in_match = true
	match state:
		Session.State.COUNTDOWN:
			_render_countdown()
		Session.State.ACTIVE:
			_render_round()
		Session.State.ROUND_RESULT:
			_render_round_result()
		Session.State.FINISHED:
			_render_finish()
		Session.State.RECONNECTING:
			if not _in_match:
				_render_lobby()
		Session.State.DISCONNECTED, Session.State.ERROR:
			if _in_match:
				_render_lost()
			else:
				_render_lobby()
		_:
			_render_lobby()
	_update_online_hud()
	_update_banner()


func _show_arena(on: bool) -> void:
	_lobby_host.visible = not on
	_hud.visible = on
	_arena.visible = on
	if not on:
		_show_panels(false, false, false, false)
	_fit_arena()


func _render_lobby() -> void:
	_show_arena(false)
	var state: Session.State = _session.state
	var room: String = _session.room_code
	var idle: bool = state == Session.State.IDLE or state == Session.State.ERROR or state == Session.State.DISCONNECTED
	_entry.visible = room.is_empty() and _action == "join"
	_join_button.disabled = _leaving or state == Session.State.JOINING_ROOM
	_retry_button.visible = room.is_empty() and _action == "create" and idle and not _leaving
	_room_box.visible = not room.is_empty()
	_code_label.text = room
	_share_label.text = "Your classmate opens PvP › JOIN ROOM and enters %s" % room
	var opponent: String = _session.opponent_id()
	if opponent.is_empty():
		_rival_name.text = "OPEN SLOT"
		_rival_name.add_theme_color_override("font_color", Palette.CYAN_300)
		_opponent_label.text = "Waiting for an opponent to join…"
		_opponent_label.add_theme_color_override("font_color", Palette.CYAN_300)
		_rival_card.add_theme_stylebox_override("panel", _slot_style(Palette.NAVY_700))
	else:
		var rival_ready: bool = _flag("ready", opponent)
		_rival_name.text = "OFFLINE" if _opponent_offline else "CONNECTED"
		_rival_name.add_theme_color_override("font_color", Palette.DANGER if _opponent_offline else Palette.CREAM)
		_opponent_label.text = "READY" if rival_ready else "NOT READY"
		_opponent_label.add_theme_color_override("font_color", _status_color(rival_ready, _opponent_offline))
		_rival_card.add_theme_stylebox_override("panel", _slot_style(Palette.SUCCESS if rival_ready else Palette.DANGER))
	var me_ready: bool = _flag("ready", _session.self_id)
	_ready_label.text = "READY" if me_ready else "NOT READY"
	_ready_label.add_theme_color_override("font_color", _status_color(me_ready, false))
	_you_card.add_theme_stylebox_override("panel", _slot_style(Palette.SUCCESS if me_ready else Palette.CYAN_400))
	_ready_button.disabled = _leaving or state != Session.State.WAITING or me_ready or _ready_sent
	_ready_button.text = "I'M READY" if not (me_ready or _ready_sent) else "READY — WAITING FOR RIVAL"
	_leave_room_button.disabled = _leaving
	if not _leaving:
		_lobby_status.text = _lobby_line(state)
	_lobby_status.visible = not _lobby_status.text.is_empty()
	_lobby_error.visible = not _lobby_error.text.is_empty()


func _lobby_line(state: Session.State) -> String:
	match state:
		Session.State.CREATING_ROOM:
			return "Creating room…"
		Session.State.JOINING_ROOM:
			return "Joining room…"
		Session.State.CONNECTING:
			return "Connecting…"
		Session.State.RECONNECTING:
			return "Connection lost — reconnecting…"
	return ""


func _render_countdown() -> void:
	_show_arena(true)
	_show_panels(false, true, false, false)
	_status.text = "GET READY"
	_clear_fx()


func _render_round() -> void:
	_show_arena(true)
	_show_panels(true, false, false, false)
	var round_data: Dictionary = _session.current_round
	var number: int = int(round_data.get("round", 0))
	if number != _shown_round:
		_build_question(round_data)
		_lock_note = ""
	_apply_answer_lock()


func _build_question(round_data: Dictionary) -> void:
	_shown_round = int(round_data.get("round", 0))
	_answer_buttons.clear()
	_choices.clear()
	UI.clear(_body)
	var prompt: Label = UI.label(str(round_data.get("question", "")), 18, Palette.CREAM)
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(prompt)
	var options: Array = round_data.get("options", []) as Array
	var grid: GridContainer = GridContainer.new()
	grid.name = "AnswerGrid"
	grid.columns = 2 if options.size() > 1 else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	var button_height: float = 52.0 if size.y >= 520.0 else 44.0
	for index: int in options.size():
		var button: Button = UI.button(str(options[index]), _online_pick.bind(index))
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(0, button_height)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_answer_buttons.append(button)
		grid.add_child(button)
	UI.fit_touch(self)
	_fit_answer_text.call_deferred()


func _apply_answer_lock() -> void:
	var answered: bool = _session.has_answered_current_round()
	var open: bool = _session.state == Session.State.ACTIVE and not answered and not _leaving
	for button: Button in _answer_buttons:
		button.disabled = not open
	if answered:
		_status.text = _lock_note if not _lock_note.is_empty() else "ANSWER LOCKED — WAITING"
	else:
		_status.text = "CHOOSE AN ANSWER"


func _online_pick(index: int) -> void:
	if _session == null or _leaving:
		return
	if not _session.submit_answer(index):
		return
	_lock_note = "ANSWER SENT — WAITING"
	_apply_answer_lock()


func _render_round_result() -> void:
	_show_arena(true)
	_show_panels(false, false, true, false)
	var result: Dictionary = _session.last_result
	var headline: String = _result_headline_for(result)
	_status.text = headline
	_result_title.text = headline
	var note: String = _answer_note(result)
	_result_note.text = note
	_result_note.visible = not note.is_empty()


func _result_headline_for(result: Dictionary) -> String:
	var winner: String = str(result.get("winner_id", ""))
	if winner.is_empty():
		match str(result.get("reason", "")):
			"both_wrong":
				return "BOTH MISSED — NO DAMAGE"
			"timeout":
				return "TIME UP — NO DAMAGE"
		return "NO DAMAGE"
	if winner == _session.self_id:
		return "CORRECT — ATTACK!"
	return "RIVAL ANSWERED FIRST"


func _answer_note(result: Dictionary) -> String:
	var options: Array = _session.current_round.get("options", []) as Array
	var position: int = int(result.get("correct_option", -1))
	if int(result.get("round", 0)) != int(_session.current_round.get("round", -1)):
		return ""
	if position < 0 or position >= options.size():
		return ""
	return "Answer: %s" % str(options[position])


func _render_finish() -> void:
	_show_arena(true)
	_show_panels(false, false, false, true)
	var finish: Dictionary = _session.finish_result
	var winner: String = str(finish.get("winner_id", ""))
	var title: String = "DRAW"
	var color: Color = Palette.WARNING
	if winner.is_empty() and str(finish.get("state", "")) == "abandoned":
		title = "ROOM CLOSED"
	elif winner == _session.self_id:
		title = "VICTORY"
		color = Palette.SUCCESS
	elif not winner.is_empty():
		title = "DEFEAT"
		color = Palette.DANGER
	_fill_end_card(title, color, _finish_line(finish))


func _finish_line(finish: Dictionary) -> String:
	var mine: bool = str(finish.get("retired_by", "")) == _session.self_id
	match str(finish.get("reason", "")):
		"ko":
			return "KNOCKOUT"
		"forfeit":
			return "YOU FORFEITED — CONNECTION LOST" if mine else "RIVAL FORFEITED — CONNECTION LOST"
		"retired":
			return "YOU LEFT THE MATCH" if mine else "RIVAL LEFT THE MATCH"
		"stale":
			return "ROOM EXPIRED"
	return "MATCH OVER"


func _render_lost() -> void:
	_show_arena(true)
	_show_panels(false, false, false, true)
	_fill_end_card("DISCONNECTED", Palette.WARNING, Session.safe_message(_session.last_error_code))


func _fill_end_card(title: String, color: Color, line: String) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_end_you_hp.text = "YOU  %d" % _session.my_hp()
	_end_rival_hp.text = "RIVAL  %d" % _session.opponent_hp()
	(_end_you_correct.get_parent() as Control).hide()
	(_end_you_avg.get_parent() as Control).hide()
	_end_rounds.text = line
	_end_rounds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.show()


func _play_result_fx(result: Dictionary) -> void:
	var number: int = int(result.get("round", 0))
	if _session == null or number <= _fx_round or not is_inside_tree():
		return
	_fx_round = number
	_clear_fx()
	if _arena == null or _arena.size.x < 2.0:
		return
	var winner: String = str(result.get("winner_id", ""))
	if winner.is_empty():
		return
	if winner == _session.self_id:
		_play_defender_attack()
	else:
		_play_rival_pulse()


func _update_online_hud() -> void:
	var mine: int = _session.my_hp()
	var theirs: int = _session.opponent_hp()
	_player_hp.text = str(mine)
	_bot_hp.text = str(theirs)
	_player_bar.set_hp(mine)
	_bot_bar.set_hp(theirs)
	_round_label.text = "ROUND %d" % maxi(_round_number, 1)
	_countdown_round.text = _round_label.text
	match _session.state:
		Session.State.ACTIVE:
			_timer.text = "%.1fs" % (float(_session.round_remaining_ms()) / 1000.0)
		Session.State.COUNTDOWN:
			_timer.text = "%d" % int(ceil(float(_session.countdown_remaining_ms()) / 1000.0))
			_countdown_value.text = _timer.text
		_:
			_timer.text = ""
	_timer.visible = not _timer.text.is_empty()


func _update_banner() -> void:
	var text: String = ""
	var state: Session.State = _session.state
	if state == Session.State.RECONNECTING:
		text = "CONNECTION LOST — RECONNECTING…"
	elif _in_match and _opponent_offline and state != Session.State.FINISHED:
		text = "RIVAL DISCONNECTED — WAITING FOR THEM TO RETURN"
		if _opponent_grace_ends_at > 0:
			var remain: int = maxi(0, _opponent_grace_ends_at - _session.server_now_ms())
			text = "RIVAL DISCONNECTED — WAITING %ds" % int(ceil(float(remain) / 1000.0))
	_banner.text = text
	_banner.visible = not text.is_empty()


func _match_live() -> bool:
	if _session == null or not _in_match:
		return false
	var state: Session.State = _session.state
	return state == Session.State.COUNTDOWN or state == Session.State.ACTIVE or state == Session.State.ROUND_RESULT or state == Session.State.RECONNECTING


func _flag(key: String, user_id: String) -> bool:
	var raw: Variant = _view.get(key, {})
	if typeof(raw) != TYPE_DICTIONARY or user_id.is_empty():
		return false
	return bool((raw as Dictionary).get(user_id, false))


func _on_ready_pressed() -> void:
	if _session == null or _leaving or _ready_sent:
		return
	if _session.send_ready():
		_ready_sent = true
	_render_online()


func _copy_code() -> void:
	if _session == null or _session.room_code.is_empty():
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(_session.room_code)
	_copy_button.text = "COPIED"


# ---- construction ----------------------------------------------------------------

func _build_banner() -> void:
	_banner = UI.label("", 16, Palette.WARNING, true)
	_banner.name = "ConnectionBanner"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.hide()
	_layout.add_child(_banner)
	_layout.move_child(_banner, mini(1, _layout.get_child_count() - 1))


func _build_lobby() -> void:
	_lobby_host = ScrollContainer.new()
	_lobby_host.name = "OnlineLobby"
	_lobby_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_host.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layout.add_child(_lobby_host)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_host.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size.x = 560
	card.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_900, Palette.NAVY_700, 22))
	center.add_child(card)
	var column: VBoxContainer = UI.column(card, 10)
	var title: Label = UI.label("PRIVATE ROOM", 24, Palette.CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle: Label = UI.label("Share the code. The duel starts when both players are ready.", 18, Palette.CYAN_300)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_entry = VBoxContainer.new()
	_entry.name = "JoinEntry"
	_entry.add_theme_constant_override("separation", 6)
	column.add_child(_entry)
	_entry.add_child(UI.label("Enter the room code your classmate shared.", 18, Palette.CYAN_300))
	var entry_row: HBoxContainer = HBoxContainer.new()
	entry_row.add_theme_constant_override("separation", 10)
	_entry.add_child(entry_row)
	_code_input = LineEdit.new()
	_code_input.name = "RoomCodeInput"
	_code_input.placeholder_text = "ROOM CODE"
	_code_input.max_length = CODE_MAX_LENGTH
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.custom_minimum_size.y = 48
	_code_input.add_theme_font_size_override("font_size", 24)
	_code_input.text_submitted.connect(func(_text: String) -> void: _submit_code())
	entry_row.add_child(_code_input)
	_join_button = UI.button("JOIN", _submit_code, true)
	_join_button.name = "JoinButton"
	entry_row.add_child(_join_button)
	_retry_button = UI.button("TRY AGAIN", _create_room, true)
	_retry_button.name = "RetryCreateButton"
	_retry_button.hide()
	column.add_child(_retry_button)
	_room_box = VBoxContainer.new()
	_room_box.name = "RoomBox"
	_room_box.add_theme_constant_override("separation", 12)
	column.add_child(_room_box)
	_build_code_panel()
	_build_player_slots()
	_ready_button = _lobby_button("I'M READY", _on_ready_pressed, Palette.PRIMARY_BLUE, Palette.BLUE_400, Palette.CREAM)
	_ready_button.name = "ReadyButton"
	_ready_button.custom_minimum_size.y = 56
	_ready_button.add_theme_stylebox_override("disabled", UI.box(Palette.NAVY_800, Palette.SUCCESS, 12))
	_ready_button.add_theme_color_override("font_disabled_color", Palette.SUCCESS)
	_room_box.add_child(_ready_button)
	_lobby_status = UI.label("", 16, Palette.CYAN_300)
	_lobby_status.name = "LobbyStatus"
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_status)
	_lobby_error = UI.label("", 16, Palette.DANGER)
	_lobby_error.name = "LobbyError"
	_lobby_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_error)
	_leave_room_button = _lobby_button("LEAVE ROOM", _leave_online, Palette.NAVY_900, Palette.NAVY_800, Palette.DANGER)
	_leave_room_button.name = "LeaveRoomButton"
	_leave_room_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave_room_button.add_theme_stylebox_override("normal", UI.box(Palette.NAVY_900, Palette.DANGER, 10))
	column.add_child(_leave_room_button)


func _build_code_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CodePanel"
	panel.add_theme_stylebox_override("panel", UI.box(Palette.TEAL_900, Palette.CYAN_400, 16))
	_room_box.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	row.add_child(stack)
	stack.add_child(UI.label("ROOM CODE", 14, Palette.CYAN_300, true))
	_code_label = UI.label("", 48, Palette.CYAN_400, true)
	_code_label.name = "RoomCode"
	_code_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var spaced: FontVariation = FontVariation.new()
	spaced.base_font = _code_label.get_theme_font("font")
	spaced.spacing_glyph = 8
	_code_label.add_theme_font_override("font", spaced)
	stack.add_child(_code_label)
	_copy_button = _lobby_button("COPY", _copy_code, Palette.TEAL_800, Palette.CYAN_400, Palette.CREAM)
	_copy_button.name = "CopyCodeButton"
	_copy_button.custom_minimum_size = Vector2(120, 52)
	_copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_copy_button)
	_share_label = UI.label("", 18, Palette.CYAN_300)
	_share_label.name = "ShareText"
	_share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_box.add_child(_share_label)


func _build_player_slots() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PlayerSlots"
	row.add_theme_constant_override("separation", 12)
	_room_box.add_child(row)
	var you_name: String = AuthService.display_name().strip_edges().to_upper()
	_you_card = _lobby_slot(row, "YOU", "OPERATOR" if you_name.is_empty() else you_name, Palette.CYAN_300)
	_ready_label = _you_card.get_meta("status") as Label
	_ready_label.name = "ReadyStatus"
	_rival_card = _lobby_slot(row, "RIVAL", "OPEN SLOT", Palette.DANGER)
	_rival_name = _rival_card.get_meta("title") as Label
	_rival_name.name = "RivalName"
	_opponent_label = _rival_card.get_meta("status") as Label
	_opponent_label.name = "OpponentStatus"


func _lobby_slot(row: HBoxContainer, role: String, title: String, accent: Color) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.add_theme_stylebox_override("panel", _slot_style(Palette.NAVY_700))
	row.add_child(card)
	var stack: VBoxContainer = UI.column(card, 2)
	stack.add_child(UI.label(role, 14, accent, true))
	var name_label: Label = UI.label(title, 18, Palette.CREAM, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(name_label)
	var status: Label = UI.label("", 16, Palette.WARNING, true)
	stack.add_child(status)
	card.set_meta("title", name_label)
	card.set_meta("status", status)
	return card


func _slot_style(border: Color) -> StyleBoxFlat:
	return UI.box(Palette.NAVY_800, border, 12)


func _status_color(ready: bool, offline: bool) -> Color:
	if offline:
		return Palette.DANGER
	return Palette.SUCCESS if ready else Palette.WARNING


func _lobby_button(text: String, callback: Callable, fill: Color, hover: Color, ink: Color) -> Button:
	var button: Button = UI.button(text, callback)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size.y = 48
	button.add_theme_stylebox_override("normal", UI.box(fill, hover, 12))
	button.add_theme_stylebox_override("hover", UI.box(hover, Palette.CREAM, 12))
	button.add_theme_stylebox_override("pressed", UI.box(Palette.CYAN_400, Palette.CREAM, 12))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", Palette.CREAM)
	button.add_theme_color_override("font_pressed_color", Palette.INK)
	return button
