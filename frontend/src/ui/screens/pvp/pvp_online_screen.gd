class_name PvpOnlineScreen
extends PvpBattleScreen
## Capture the flag through a private room or matchmaking, using the shared CRT workspace.
## Owns exactly one PvpOnlineSession from lobby (or search) to final result and frees it only when the player leaves.
## Progress, winners and rating come from server events. Unsupported servers stay in the lobby.

const Session = preload("res://src/network/pvp_online_session.gd")
const MatchTerminal: GDScript = preload("res://src/ui/screens/dashboard/dashboard_pvp_hub.gd")
const FlagTerminal: GDScript = preload("res://src/ui/screens/pvp/pvp_flag_terminal.gd")
const CODE_MAX_LENGTH: int = 12

## () -> PvpOnlineSession. Tests inject a session wired to fake transports.
var session_factory: Callable = Callable()

var _session: Session
var _sessions_created: int = 0
var _sessions_freed: int = 0
var _action: String = "create"
var _leaving: bool = false
var _left: bool = false
var _recovery_tried: bool = false
var _in_match: bool = false
var _view: Dictionary = {}
var _round_number: int = 0
var _opponent_offline: bool = false
var _opponent_grace_ends_at: int = 0
var _ready_sent: bool = false
var _rating_http: HTTPRequest
var _rating_retry: Timer
var _rating_match: String = ""
var _rating_owner: String = ""
var _rating_attempts: int = 0
var _rating_applied: bool = false
var _rating_line: String = ""
var _rating_detail: String = ""
var _reward_tween: Tween

var _terminal: MatchTerminal
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
var _lobby_title: Label
var _lobby_subtitle: Label
var _code_panel: PanelContainer
var _search_box: VBoxContainer
var _search_title: Label
var _search_time: Label
var _cancel_search_button: Button
var _match_notice: Control
var _notice_timer: Tween
var _flag_screen: FlagTerminal
var _role_button: Button
var _preferred_role: String = ""


func battle_mode() -> Mode:
	return Mode.ONLINE


func on_enter(args: Dictionary) -> void:
	var requested: String = str(args.get("action", "create"))
	_action = requested if requested == "join" or requested == "find" else "create"
	if _action == "create":
		_create_room()
	elif _action == "find":
		_find_opponent()
	_render_online()


func on_exit() -> void:
	_close_match_notice()
	if _rating_http != null:
		_rating_http.cancel_request()
	if _rating_retry != null:
		_rating_retry.stop()
	if _reward_tween != null: _reward_tween.kill()
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
		if _session == null or not _session.has_pending_exit():
			_complete_leave()
		return
	if _session == null:
		return
	if _session.state == Session.State.SEARCHING:
		_update_search()
	if is_instance_valid(_flag_screen) and _flag_screen.visible:
		var end: int = _session.countdown_ends_at if _session.state == Session.State.COUNTDOWN else int(_session.flag.get("ends_at",0))
		_flag_screen.show_clock(0 if _session.state == Session.State.FINISHED else end-_session.server_now_ms())
		if _session.state == Session.State.FINISHED:
			_flag_screen.show_rating(_rating_line, _rating_detail)
		return


## Called by the shared _ready(). Online mode builds its lobby and session; it never creates a local battle.
func _start_match() -> void:
	_abandon_note.text = "Leaving forfeits an active match."
	_build_lobby()
	_ensure_session()
	_render_online()


func _on_leave() -> void:
	_leave_online()


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
	made.round_resolved.connect(_on_round_resolved)
	made.match_finished.connect(_on_match_finished)
	made.connection_changed.connect(_on_connection_changed)
	made.error_received.connect(_on_error_received)
	made.match_found.connect(_on_match_found)
	made.matchmaking_ended.connect(_on_matchmaking_ended)


func _drop_session() -> void:
	if _session == null:
		return
	var leaving: Session = _session
	_session = null
	_sessions_freed += 1
	if not _leaving:
		leaving.leave()
	if leaving.get_parent() == self:
		remove_child(leaving)
	leaving.queue_free()


func _leave_online() -> void:
	if _leaving or _left:
		return
	_leaving = true
	_close_match_notice()
	if _rating_http != null:
		_rating_http.cancel_request()
	if _rating_retry != null:
		_rating_retry.stop()
	_abandon.hide()
	_lobby_status.text = "Leaving…"
	if _session != null:
		_session.leave()
	_render_online()
	if _session == null or not _session.has_pending_exit():
		_complete_leave()


func _complete_leave() -> void:
	if _left:
		return
	_left = true
	_drop_session()
	_pop_when_router_free()


## Router.pop() is silently dropped mid-transition; keep retrying until this screen is popped.
func _pop_when_router_free() -> void:
	while is_inside_tree() and Router.is_top(self):
		if Router.is_busy():
			await get_tree().process_frame
			continue
		await Router.pop()


func _create_room() -> void:
	if _session == null or _leaving:
		return
	_lobby_error.text = ""
	_session.create_room()


func _find_opponent() -> void:
	if _session == null or _leaving:
		return
	_lobby_error.text = ""
	_session.join_matchmaking()


func _retry() -> void:
	if _action == "find":
		_find_opponent()
	else:
		_create_room()
	_render_online()


func _cancel_search() -> void:
	if _session == null or _leaving or _session.state != Session.State.SEARCHING:
		return
	_cancel_search_button.disabled = true
	_cancel_search_button.text = "CANCELLING…"
	_session.cancel_matchmaking()


func _submit_code() -> void:
	if _session == null or _leaving:
		return
	var code: String = normalize_code(_code_input.text)
	_code_input.text = code
	if code.is_empty():
		_lobby_error.text = "Enter the room code your classmate shared."
		_render_online()
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


func _on_match_found(_code: String) -> void:
	if _leaving or _action != "find" or is_instance_valid(_match_notice):
		return
	_lobby_error.text = ""
	var terminal: MatchTerminal = MatchTerminal.new()
	terminal.match_confirmed = true
	terminal.name = "MatchConfirmed"
	_match_notice = terminal
	add_child(terminal)
	terminal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice_timer = create_tween()
	_notice_timer.tween_interval(2.0)
	_notice_timer.tween_callback(_close_match_notice)
	_render_online()


func _close_match_notice() -> void:
	if _notice_timer != null:
		_notice_timer.kill()
		_notice_timer = null
	if is_instance_valid(_match_notice):
		_match_notice.hide()
		_match_notice.queue_free()
		_match_notice = null


func _on_matchmaking_ended(_reason: String) -> void:
	_leave_online()


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


func _on_round_resolved(_result: Dictionary) -> void:
	_render_online()


func _on_match_finished(_result: Dictionary) -> void:
	_render_online()


func _on_connection_changed(_next_state: int) -> void:
	if _next_state in [Session.State.COUNTDOWN, Session.State.ACTIVE, Session.State.FINISHED, Session.State.RECONNECTING, Session.State.DISCONNECTED, Session.State.ERROR]:
		_close_match_notice()
	_render_online()


func _on_error_received(code: String, message: String) -> void:
	if _session == null:
		return
	if code == "reconnect_failed" and _session.flag.is_empty() and not _recovery_tried and not _session.room_code.is_empty():
		# Grace is over; ask the server once for the authoritative final result.
		_recovery_tried = true
		_recover_room.call_deferred(_session.room_code)
	if not _session.flag.is_empty() and _session.state == Session.State.ACTIVE:
		_render_flag()
		return
	_lobby_error.text = message
	_render_online()


# ---- rendering (server state only) ----------------------------------------------------

func _render_online() -> void:
	if _session == null or _lobby_host == null or _leaving:
		return
	var state: Session.State = _session.state
	if state in [Session.State.COUNTDOWN, Session.State.ACTIVE, Session.State.ROUND_RESULT]:
		_in_match = true
	if state == Session.State.FINISHED:
		_render_finish()
	elif not _session.flag.is_empty():
		_render_flag()
	elif _in_match and state in [Session.State.DISCONNECTED, Session.State.ERROR, Session.State.RECONNECTING]:
		_render_lost()
	else:
		_render_lobby()
		if state in [Session.State.COUNTDOWN, Session.State.ACTIVE, Session.State.ROUND_RESULT]:
			_lobby_status.text = "This room uses an older game version. Leave and update the server for Capture the Flag."
			_lobby_status.show()
			_ready_button.disabled = true


func _open_workspace() -> void:
	if not is_instance_valid(_flag_screen):
		_flag_screen = FlagTerminal.new()
		add_child(_flag_screen)
		_flag_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_flag_screen.command.connect(_send_flag_action)
		_flag_screen.leave_requested.connect(consume_back)
		_flag_screen.retry_requested.connect(_session.retry_connection)
		move_child(_abandon,-1)
	_flag_screen.show()
	_terminal.hide()
	_lobby_host.hide()

func _workspace_data() -> Dictionary:
	if not _session.flag.is_empty(): return _session.flag
	return {"role":"session","step":0,"rival_step":0,"inspected":false,"revision":0,"node":"SESSION.LOG","inspect_label":"","summary":"","detail":"","targets":{},"feedback":""}

func _render_flag() -> void:
	_open_workspace()
	var data: Dictionary = _workspace_data()
	var attacking: bool = data.role == "attacker"
	match _session.state:
		Session.State.COUNTDOWN:
			var mission: String = "Trace the event invitation to the vault and retrieve EVENT.FLAG." if attacking else "Verify the invitation and secure EVENT.FLAG in quarantine."
			_flag_screen.present(data,"briefing", mission + " The first capture wins.")
		Session.State.ACTIVE:
			_flag_screen.present(data,"active")
		Session.State.DISCONNECTED, Session.State.ERROR:
			_flag_screen.present(data,"lost", "Connection lost. Reconnect to check the server result.")
		_:
			_flag_screen.present(data,"offline", "Connection interrupted. Restoring your flag route…")


func _send_flag_action(action: String, target: String) -> void:
	if not _session.send_flag_action(action,target):
		_flag_screen.present(_session.flag,"offline","Waiting for the room connection…")


func _show_lobby() -> void:
	_terminal.show()
	_lobby_host.show()
	if is_instance_valid(_flag_screen): _flag_screen.hide()


func _render_lobby() -> void:
	_show_lobby()
	var state: Session.State = _session.state
	var room: String = _session.room_code
	var idle: bool = state == Session.State.IDLE or state == Session.State.ERROR or state == Session.State.DISCONNECTED
	var searching: bool = state == Session.State.SEARCHING
	var matchmade: bool = _action == "find"
	if matchmade:
		_lobby_title.text = "MATCH FOUND" if not room.is_empty() else "FIND A MATCH"
	elif room.is_empty():
		_lobby_title.text = "JOIN A ROOM" if _action == "join" else "CREATE ROOM"
	else:
		_lobby_title.text = "PRIVATE ROOM"
	_lobby_subtitle.text = "Both players must be ready to begin."
	_lobby_subtitle.visible = matchmade and not room.is_empty()
	_entry.visible = room.is_empty() and _action == "join"
	_join_button.disabled = _leaving or state == Session.State.JOINING_ROOM
	_retry_button.visible = room.is_empty() and _action != "join" and idle and not _leaving
	_search_box.visible = searching
	_cancel_search_button.disabled = _leaving or not searching
	if searching:
		_update_search()
	else:
		_cancel_search_button.text = "CANCEL"
	_room_box.visible = not room.is_empty()
	_code_panel.visible = not matchmade
	_share_label.visible = not matchmade
	_code_label.text = room
	_share_label.text = "Invite a classmate with code %s." % room
	var opponent: String = _session.opponent_id()
	if opponent.is_empty():
		_rival_name.text = "OPEN SLOT"
		_rival_name.add_theme_color_override("font_color", MatchTerminal.AMBER)
		_opponent_label.text = "Waiting for an opponent to join…"
		_opponent_label.add_theme_color_override("font_color", MatchTerminal.AMBER)
		_rival_card.add_theme_stylebox_override("panel", _slot_style(MatchTerminal.EDGE))
	else:
		var rival_ready: bool = _flag("ready", opponent)
		_rival_name.text = "OFFLINE" if _opponent_offline else "CONNECTED"
		_rival_name.add_theme_color_override("font_color", Palette.DANGER if _opponent_offline else Color("#ffe192"))
		_opponent_label.text = "READY" if rival_ready else "NOT READY"
		_opponent_label.add_theme_color_override("font_color", _status_color(rival_ready, _opponent_offline))
		_rival_card.add_theme_stylebox_override("panel", _slot_style(MatchTerminal.AMBER if rival_ready else MatchTerminal.EDGE))
	var me_ready: bool = _flag("ready", _session.self_id)
	_role_button.visible = _session.supports_flag and not room.is_empty()
	_role_button.disabled = _ready_sent or me_ready
	if _preferred_role.is_empty() and not room.is_empty():
		_preferred_role = "attacker" if _session.self_id == _session.host_id else "defender"
	if _role_button.visible:
		_lobby_title.text = "CAPTURE THE FLAG"
		_lobby_subtitle.hide()
		_share_label.hide()
	_role_button.text = "ROLE: " + _preferred_role.to_upper()
	_ready_label.text = "READY" if me_ready else "NOT READY"
	_ready_label.add_theme_color_override("font_color", _status_color(me_ready, false))
	_you_card.add_theme_stylebox_override("panel", _slot_style(MatchTerminal.AMBER if me_ready else MatchTerminal.EDGE))
	_ready_button.disabled = _leaving or state != Session.State.WAITING or me_ready or _ready_sent or not _session.supports_flag
	_ready_button.text = "I'M READY" if not (me_ready or _ready_sent) else "READY — WAITING FOR RIVAL"
	if _role_button.visible and (me_ready or _ready_sent): _ready_button.text = "READY"
	_leave_room_button.disabled = _leaving
	_leave_room_button.visible = not searching
	_ready_button.visible = not room.is_empty()
	_leave_room_button.text = "BACK" if room.is_empty() else "LEAVE ROOM"
	if not _leaving:
		_lobby_status.text = _lobby_line(state)
		if _role_button.visible and state == Session.State.WAITING:
			_lobby_status.text = "Waiting for rival…" if me_ready or _ready_sent else "Tap role to switch. Ties are assigned."
	if state == Session.State.WAITING and not _session.supports_flag:
		_lobby_status.text = "Capture the Flag requires an updated server. You can leave this room and use offline practice."
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


## Per-frame while queued: elapsed time and a dot indicator. Polling itself lives in the session.
func _update_search() -> void:
	var seconds: int = int(_session.search_elapsed_ms() / 1000.0)
	_search_time.text = "%d:%02d" % [int(seconds / 60.0), seconds % 60]
	_search_title.text = "SEARCHING FOR OPPONENT" + ("" if SettingsService.reduced_motion else ".".repeat(seconds % 4))


func _render_finish() -> void:
	_open_workspace()
	var finish: Dictionary = _session.finish_result
	var winner: String = str(finish.get("winner_id", ""))
	var title: String = "DRAW"
	if winner.is_empty() and str(finish.get("state", "")) == "abandoned": title = "ROOM CLOSED"
	elif winner == _session.self_id: title = "VICTORY"
	elif not winner.is_empty(): title = "DEFEAT"
	_set_result_rating(finish,winner)
	_flag_screen.present(_workspace_data(),"done",title + "\n" + _finish_line(finish))
	_flag_screen.show_rating(_rating_line,_rating_detail)


func _set_result_rating(finish: Dictionary, winner: String) -> void:
	if str(finish.get("origin", "private")) != "matchmaking":
		_rating_line = "PRIVATE MATCH / NO RATING CHANGE"
		_rating_detail = "Play Find Opponent to compete for rating."
	elif not str(finish.get("match_id", "")).is_empty() and (not winner.is_empty() or finish.get("reason") == "flag_timeout"):
		if _rating_match.is_empty():
			_rating_match = str(finish["match_id"])
			_rating_owner = _session.self_id
			_rating_line = "RATING UPDATE PENDING"
			_rating_detail = "Waiting for the server's match record."
			_fetch_rating()
	else:
		_rating_line = "NO RATING CHANGE"
		_rating_detail = "No rated result was recorded."


func _finish_line(finish: Dictionary) -> String:
	var mine: bool = str(finish.get("retired_by", "")) == _session.self_id
	match str(finish.get("reason", "")):
		"flag_retrieved": return "The attacker retrieved EVENT.FLAG."
		"flag_secured": return "The defender secured EVENT.FLAG in quarantine."
		"flag_timeout": return "Time expired with the flag still in the vault."
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
	_open_workspace()
	_flag_screen.present(_workspace_data(),"lost","Connection lost. Reconnect to check the server result.")


func _fetch_rating() -> void:
	if _leaving or not is_inside_tree() or _rating_applied or _rating_attempts >= 5:
		return
	var token: String = AuthService.auth_token()
	if Session.token_subject(token) != _rating_owner:
		return
	if _rating_http == null:
		_rating_http = HTTPRequest.new()
		_rating_http.timeout = 8.0
		_rating_http.max_redirects = 0
		add_child(_rating_http)
		_rating_http.request_completed.connect(_rating_received)
		_rating_retry = Timer.new()
		_rating_retry.one_shot = true
		_rating_retry.wait_time = 2.0
		add_child(_rating_retry)
		_rating_retry.timeout.connect(_fetch_rating)
	_rating_attempts += 1
	var base: String = str(ProjectSettings.get_setting("levelblue/api_base_url", Session.DEFAULT_API_BASE)).trim_suffix("/")
	var error: Error = _rating_http.request(base + "/api/pvp/me/matches/" + _rating_match.uri_encode() + "/rating", PackedStringArray(["Authorization: Bearer " + token, "Accept: application/json"]))
	if error != OK:
		if _rating_attempts < 5:
			_rating_retry.start()
		else:
			_rating_detail = "Still syncing. Check your PvP profile later."


func _rating_received(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _leaving or _rating_applied or Session.token_subject(AuthService.auth_token()) != _rating_owner:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result == HTTPRequest.RESULT_SUCCESS and status == 200 and parsed is Dictionary:
		var record: Dictionary = parsed as Dictionary
		if str(record.get("status", "")) == "applied" and str(record.get("match_id", "")) == _rating_match:
			if _valid_rating(record) and not _rating_applied:
				_rating_applied = true
				_animate_rating(record)
				return
	if status == 401 or status == 403:
		_rating_detail = "Sign in again to check your rating."
	elif _rating_attempts < 5:
		_rating_retry.start()
	else:
		_rating_detail = "Still syncing. Check your PvP profile later."


static func _valid_rating(record: Dictionary) -> bool:
	for key: String in ["points_before", "points_after", "points_delta"]:
		var value: Variant = record.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
			return false
	return int(record["points_before"]) >= 0 and int(record["points_after"]) >= 0 and int(record["points_after"]) - int(record["points_before"]) == int(record["points_delta"]) and record.get("rank_before") is String and record.get("rank_after") is String


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
	if not _session.supports_flag: return
	if _session.send_ready(_preferred_role):
		_ready_sent = true
	_render_online()


func _copy_code() -> void:
	if _session == null or _session.room_code.is_empty():
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(_session.room_code)
	_copy_button.text = "COPIED"


# ---- construction ----------------------------------------------------------------


func _build_lobby() -> void:
	_lobby_host = ScrollContainer.new()
	_lobby_host.name = "OnlineLobby"
	_lobby_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_host.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lobby_host.follow_focus = true
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	_lobby_host.add_child(column)
	_terminal = MatchTerminal.new()
	_terminal.lobby_panel = _lobby_host
	_lobby_title = _terminal_label("PRIVATE ROOM", 28)
	_lobby_title.name = "LobbyTitle"
	column.add_child(_lobby_title)
	_lobby_subtitle = _terminal_label("", 19)
	column.add_child(_lobby_subtitle)
	_build_search_box(column)
	_entry = VBoxContainer.new()
	_entry.name = "JoinEntry"
	_entry.add_theme_constant_override("separation", 6)
	column.add_child(_entry)
	_entry.add_child(_terminal_label("Enter the code your classmate shared.", 20))
	var entry_row: HBoxContainer = HBoxContainer.new()
	entry_row.add_theme_constant_override("separation", 10)
	_entry.add_child(entry_row)
	_code_input = LineEdit.new()
	_code_input.name = "RoomCodeInput"
	_code_input.placeholder_text = "ROOM CODE"
	_code_input.max_length = CODE_MAX_LENGTH
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.custom_minimum_size = Vector2(90, 44)
	_code_input.add_theme_font_override("font", MatchTerminal.FONT)
	_code_input.add_theme_color_override("font_color", MatchTerminal.AMBER)
	_code_input.add_theme_color_override("caret_color", MatchTerminal.AMBER)
	_code_input.add_theme_color_override("font_placeholder_color", Color("#b99858"))
	_code_input.add_theme_stylebox_override("normal", _slot_style(MatchTerminal.EDGE))
	_code_input.add_theme_stylebox_override("focus", _slot_style(MatchTerminal.AMBER))
	_code_input.add_theme_font_size_override("font_size", 24)
	_code_input.text_submitted.connect(func(_text: String) -> void: _submit_code())
	entry_row.add_child(_code_input)
	_join_button = _lobby_button("JOIN", _submit_code, true)
	_join_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_join_button.custom_minimum_size.x = 84
	_join_button.name = "JoinButton"
	entry_row.add_child(_join_button)
	_retry_button = _lobby_button("TRY AGAIN", _retry, true)
	_retry_button.name = "RetryCreateButton"
	_retry_button.hide()
	column.add_child(_retry_button)
	_room_box = VBoxContainer.new()
	_room_box.name = "RoomBox"
	_room_box.add_theme_constant_override("separation", 4)
	column.add_child(_room_box)
	_build_code_panel()
	_build_player_slots()
	_role_button = _lobby_button("PREFERRED ROLE", _swap_role)
	_lobby_status = _terminal_label("", 19)
	_lobby_status.name = "LobbyStatus"
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_status)
	_lobby_error = _terminal_label("", 20, Color("#ffab88"))
	_lobby_error.name = "LobbyError"
	_lobby_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_lobby_error)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	actions.add_child(_role_button)
	_ready_button = _lobby_button("I'M READY", _on_ready_pressed, true)
	_ready_button.name = "ReadyButton"
	actions.add_child(_ready_button)
	_leave_room_button = _lobby_button("LEAVE ROOM", _leave_online)
	_leave_room_button.name = "LeaveRoomButton"
	actions.add_child(_leave_room_button)
	add_child(_terminal)
	_terminal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _swap_role() -> void:
	_preferred_role = "defender" if _preferred_role == "attacker" else "attacker"
	_render_lobby()


func _build_search_box(column: VBoxContainer) -> void:
	_search_box = VBoxContainer.new()
	_search_box.name = "SearchBox"
	_search_box.add_theme_constant_override("separation", 10)
	_search_box.hide()
	column.add_child(_search_box)
	_search_title = _terminal_label("SEARCHING FOR OPPONENT", 22)
	_search_title.name = "SearchTitle"
	_search_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_box.add_child(_search_title)
	_search_time = _terminal_label("0:00", 40)
	_search_time.name = "SearchTime"
	_search_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_box.add_child(_search_time)
	_cancel_search_button = _lobby_button("CANCEL", _cancel_search)
	_cancel_search_button.name = "CancelSearchButton"
	_cancel_search_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel_search_button.custom_minimum_size.x = 200
	_search_box.add_child(_cancel_search_button)


func _build_code_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	_code_panel = panel
	panel.name = "CodePanel"
	panel.add_theme_stylebox_override("panel", _slot_style(MatchTerminal.EDGE))
	_room_box.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	row.add_child(stack)
	stack.add_child(_terminal_label("ROOM CODE", 17))
	_code_label = _terminal_label("", 32)
	_code_label.name = "RoomCode"
	_code_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var spaced: FontVariation = FontVariation.new()
	spaced.base_font = _code_label.get_theme_font("font")
	spaced.spacing_glyph = 2
	_code_label.add_theme_font_override("font", spaced)
	stack.add_child(_code_label)
	_copy_button = _lobby_button("COPY", _copy_code)
	_copy_button.name = "CopyCodeButton"
	_copy_button.custom_minimum_size = Vector2(78, 44)
	_copy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_copy_button)
	_share_label = _terminal_label("", 18)
	_share_label.name = "ShareText"
	_share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_box.add_child(_share_label)


func _build_player_slots() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PlayerSlots"
	row.add_theme_constant_override("separation", 12)
	_room_box.add_child(row)
	var you_name: String = AuthService.display_name().strip_edges().to_upper()
	_you_card = _lobby_slot(row, "YOU", "OPERATOR" if you_name.is_empty() else you_name, MatchTerminal.AMBER)
	_ready_label = _you_card.get_meta("status") as Label
	_ready_label.name = "ReadyStatus"
	_rival_card = _lobby_slot(row, "RIVAL", "OPEN SLOT", MatchTerminal.EDGE.lightened(0.3))
	_rival_name = _rival_card.get_meta("title") as Label
	_rival_name.name = "RivalName"
	_opponent_label = _rival_card.get_meta("status") as Label
	_opponent_label.name = "OpponentStatus"


func _lobby_slot(row: HBoxContainer, role: String, title: String, accent: Color) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.add_theme_stylebox_override("panel", _slot_style(MatchTerminal.EDGE))
	row.add_child(card)
	var stack: VBoxContainer = UI.column(card, 2)
	stack.add_child(_terminal_label(role, 17, accent))
	var name_label: Label = _terminal_label(title, 21)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(name_label)
	var status: Label = _terminal_label("", 18)
	stack.add_child(status)
	card.set_meta("title", name_label)
	card.set_meta("status", status)
	return card


func _slot_style(border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = MatchTerminal._box(MatchTerminal.INK, border)
	style.set_content_margin_all(4)
	return style


func _status_color(ready: bool, offline: bool) -> Color:
	if offline:
		return Color("#ffab88")
	return Color("#ffe192") if ready else MatchTerminal.AMBER


func _terminal_label(caption: String, point_size: int, color: Color = MatchTerminal.AMBER) -> Label:
	var label: Label = UI.label(caption, point_size, color)
	label.add_theme_font_override("font", MatchTerminal.FONT)
	return label


func _lobby_button(caption: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = MatchTerminal.terminal_command(caption, callback, primary)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(62,44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _animate_rating(record: Dictionary) -> void:
	var before: int = int(record.points_before)
	var after: int = int(record.points_after)
	var change: int = int(record.points_delta)
	_rating_detail = "%s / %s%d PVP POINTS" % [str(record.rank_after).to_upper(), "+" if change >= 0 else "", change]
	if change > 0 and record.rank_before != record.rank_after:
		_rating_detail = "RANK UP / " + _rating_detail
		AudioManager.play_sfx("loading_ready")
	if _reward_tween != null: _reward_tween.kill()
	if SettingsService.reduced_motion:
		_rating_frame(float(after))
	else:
		_reward_tween = create_tween()
		_reward_tween.tween_method(_rating_frame,float(before),float(after),1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _rating_frame(value: float) -> void:
	_rating_line = "%d PVP POINTS" % roundi(value)
