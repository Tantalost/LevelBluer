class_name PvpOnlineSession
extends Node
## Online PvP client session: rooms over HTTP, one authenticated WebSocket, ordered server events.
## The backend is authoritative. This layer never grades, times out, or resolves rounds; timers are display-only.

signal room_created(code: String)
signal room_joined(code: String)
signal room_updated(view: Dictionary)
signal opponent_connected
signal opponent_disconnected(grace_ends_at: int)
signal countdown_started(round_number: int, countdown_ends_at: int)
signal round_started(round_data: Dictionary)
signal local_answer_locked(round_number: int, option_index: int, correct: bool)
signal round_resolved(result: Dictionary)
signal match_finished(result: Dictionary)
signal connection_changed(next_state: int)
signal error_received(code: String, message: String)

enum State { IDLE, CREATING_ROOM, JOINING_ROOM, CONNECTING, WAITING, COUNTDOWN, ACTIVE, ROUND_RESULT, FINISHED, DISCONNECTED, RECONNECTING, ERROR }

const DEFAULT_API_BASE: String = "http://127.0.0.1:8000"
const REQUEST_TIMEOUT_SEC: float = 15.0
const RECONNECT_WINDOW_MS: int = 15000
const RECONNECT_BACKOFF_MS: Array[int] = [500, 1000, 2000, 3000]
const PING_INTERVAL_MS: int = 5000
const LEAVE_TIMEOUT_MS: int = 2000
const ROUND_KEYS: PackedStringArray = ["round", "question_id", "question", "options", "started_at", "ends_at"]
const CLOSE_UNAUTHORIZED: int = 4401
const CLOSE_FORBIDDEN: int = 4403
const CLOSE_NOT_FOUND: int = 4404
const CLOSE_REPLACED: int = 4409
const CLOSE_ROOM_GONE: int = 4410
const CLOSE_ERRORS: Dictionary = {
	4401: "auth_failed",
	4403: "forbidden",
	4404: "room_missing",
	4409: "replaced",
	4410: "room_closed",
}
const SAFE_MESSAGES: Dictionary = {
	"auth_failed": "Your sign-in expired. Please sign in again.",
	"forbidden": "You are not part of this match.",
	"room_missing": "That room no longer exists.",
	"room_not_found": "No room uses that code.",
	"replaced": "This match was opened on another device or tab.",
	"room_closed": "This match is closed.",
	"room_full": "That room already has two players.",
	"already_in_room": "You are already in that room.",
	"not_in_room": "You are not part of this match.",
	"bank_unavailable": "Online PvP is unavailable right now.",
	"reconnect_failed": "Connection lost. The match could not be resumed.",
	"network": "Could not reach the LevelBlue server.",
	"bad_response": "The server sent an unexpected reply.",
	"late": "Too late — the round had already ended.",
	"round_resolved": "That round was already decided.",
	"already_answered": "You already answered this round.",
	"wrong_round": "That round is not open.",
}

## Wraps WebSocketPeer so tests can substitute a fake transport.
class SocketTransport extends RefCounted:
	var _peer: WebSocketPeer = WebSocketPeer.new()

	func open(url: String, headers: PackedStringArray) -> Error:
		_peer = WebSocketPeer.new()
		_peer.handshake_headers = headers
		return _peer.connect_to_url(url)

	func poll() -> void:
		_peer.poll()

	func ready_state() -> WebSocketPeer.State:
		return _peer.get_ready_state()

	func close_code() -> int:
		return _peer.get_close_code()

	func next_text() -> String:
		if _peer.get_available_packet_count() <= 0:
			return ""
		return _peer.get_packet().get_string_from_utf8()

	func send_text(text: String) -> Error:
		return _peer.send_text(text)

	func close(code: int = 1000) -> void:
		_peer.close(code)


## (method: int, path: String, body: Dictionary) -> {"ok": bool, "status": int, "data": Dictionary}
var http_transport: Callable = Callable()
## () -> SocketTransport
var socket_factory: Callable = Callable()
## () -> String
var token_provider: Callable = Callable()
## () -> int (local monotonic ms)
var now_provider: Callable = Callable()
var api_base: String = ""

var state: State = State.IDLE
var room_code: String = ""
var self_id: String = ""
var host_id: String = ""
var guest_id: String = ""
var last_revision: int = 0
var ignored_events: int = 0
var hp: Dictionary = {}
var current_round: Dictionary = {}
var countdown_ends_at: int = 0
var last_result: Dictionary = {}
var finish_result: Dictionary = {}
var clock_offset_ms: int = 0
var has_clock_sample: bool = false
var last_error_code: String = ""
var reconnect_attempts: int = 0

var _socket: SocketTransport = null
var _socket_open: bool = false
var _leaving: bool = false
var _leave_deadline: int = 0
var _answered_round: int = 0
var _op_seq: int = 0
var _reconnect_deadline: int = 0
var _next_retry_at: int = 0
var _next_ping_at: int = 0
var _http: HTTPRequest


func _ready() -> void:
	if not http_transport.is_valid():
		_http = HTTPRequest.new()
		_http.timeout = REQUEST_TIMEOUT_SEC
		add_child(_http)


func _process(_delta: float) -> void:
	poll()


func _exit_tree() -> void:
	_stop_reconnect()
	_close_socket()


# ---- room actions -------------------------------------------------------------

func create_room() -> bool:
	_begin_session()
	_set_state(State.CREATING_ROOM)
	var seq: int = _op_seq
	var reply: Dictionary = await _call_http(HTTPClient.METHOD_POST, "/api/pvp/rooms")
	if seq != _op_seq:
		return false
	if not _accept_room_reply(reply):
		return false
	room_created.emit(room_code)
	_open_socket()
	return true


func join_room(code: String) -> bool:
	var normalized: String = code.strip_edges().to_upper()
	_begin_session()
	if normalized.is_empty():
		_fail("room_not_found")
		return false
	_set_state(State.JOINING_ROOM)
	var seq: int = _op_seq
	var reply: Dictionary = await _call_http(HTTPClient.METHOD_POST, "/api/pvp/rooms/%s/join" % normalized.uri_encode())
	if seq != _op_seq:
		return false
	if not _accept_room_reply(reply):
		return false
	room_joined.emit(room_code)
	_open_socket()
	return true


## Resume a room this player already belongs to (e.g. after an app restart).
func recover_room(code: String) -> bool:
	var normalized: String = code.strip_edges().to_upper()
	_begin_session()
	_set_state(State.CONNECTING)
	var seq: int = _op_seq
	var reply: Dictionary = await _call_http(HTTPClient.METHOD_GET, "/api/pvp/rooms/%s" % normalized.uri_encode())
	if seq != _op_seq:
		return false
	if not _accept_room_reply(reply):
		return false
	if state == State.FINISHED:
		return true
	_open_socket()
	return true


func send_ready() -> bool:
	if state != State.WAITING:
		return false
	return _send({"type": "ready"})


func submit_answer(option_index: int) -> bool:
	if state != State.ACTIVE or current_round.is_empty():
		return false
	var round_number: int = int(current_round.get("round", 0))
	if round_number <= 0 or _answered_round == round_number:
		return false
	var options: Array = current_round.get("options", []) as Array
	if option_index < 0 or option_index >= options.size():
		return false
	if not _send({"type": "answer", "round": round_number, "option_index": option_index}):
		return false
	_answered_round = round_number
	return true


func has_answered_current_round() -> bool:
	return not current_round.is_empty() and _answered_round == int(current_round.get("round", 0))


func leave() -> void:
	_op_seq += 1
	_stop_reconnect()
	if _socket != null and _socket_open:
		_leaving = true
		_leave_deadline = _now() + LEAVE_TIMEOUT_MS
		_send({"type": "leave"})
		# Flush now: an owner that frees the session right after leave() still reaches the server.
		_socket.poll()
		return
	_close_socket()
	if state != State.FINISHED:
		_set_state(State.IDLE)


# ---- time (display only) -------------------------------------------------------

func server_now_ms() -> int:
	return _now() + clock_offset_ms


func round_remaining_ms() -> int:
	if state != State.ACTIVE or current_round.is_empty():
		return 0
	return maxi(0, int(current_round.get("ends_at", 0)) - server_now_ms())


func countdown_remaining_ms() -> int:
	if state != State.COUNTDOWN:
		return 0
	return maxi(0, countdown_ends_at - server_now_ms())


func my_hp() -> int:
	return int(hp.get(self_id, 0))


func opponent_id() -> String:
	if self_id == host_id:
		return guest_id
	return host_id


func opponent_hp() -> int:
	return int(hp.get(opponent_id(), 0))


func is_socket_open() -> bool:
	return _socket != null and _socket_open


# ---- pump -------------------------------------------------------------------------

func poll() -> void:
	var now: int = _now()
	if _socket != null:
		_socket.poll()
		var ready_state: WebSocketPeer.State = _socket.ready_state()
		if ready_state == WebSocketPeer.STATE_OPEN and not _socket_open:
			_socket_open = true
			_next_ping_at = now + PING_INTERVAL_MS
		_drain_socket()
		if _socket != null:
			ready_state = _socket.ready_state()
			if ready_state == WebSocketPeer.STATE_CLOSED:
				var code: int = _socket.close_code()
				_socket = null
				_socket_open = false
				_on_socket_closed(code)
			elif ready_state == WebSocketPeer.STATE_OPEN:
				if _leaving and now >= _leave_deadline:
					_leaving = false
					_close_socket()
					if state != State.FINISHED:
						_set_state(State.IDLE)
				elif now >= _next_ping_at:
					_next_ping_at = now + PING_INTERVAL_MS
					_send({"type": "ping"})
	if state == State.RECONNECTING and _socket == null and now >= _next_retry_at:
		if now >= _reconnect_deadline:
			_give_up()
		else:
			reconnect_attempts += 1
			_open_socket()


func _drain_socket() -> void:
	while _socket != null:
		var text: String = _socket.next_text()
		if text.is_empty():
			return
		_handle_text(text)


func _handle_text(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed as Dictionary
	var kind: String = str(message.get("type", ""))
	_sample_clock(message)
	if kind == "pong":
		return
	if kind == "error":
		var code: String = str(message.get("code", "error"))
		last_error_code = code
		error_received.emit(code, safe_message(code))
		return
	var revision: int = _int(message.get("revision", 0))
	if revision <= last_revision:
		ignored_events += 1
		return
	last_revision = revision
	match kind:
		"room_state":
			_apply_view(message)
		"opponent_connected":
			opponent_connected.emit()
		"opponent_disconnected":
			opponent_disconnected.emit(_int(message.get("grace_ends_at", 0)))
		"countdown_started":
			countdown_ends_at = _int(message.get("countdown_ends_at", 0))
			_set_state(State.COUNTDOWN)
			countdown_started.emit(_int(message.get("round", 0)), countdown_ends_at)
		"round_started":
			current_round = public_round(message)
			_set_state(State.ACTIVE)
			round_started.emit(current_round.duplicate(true))
		"answer_locked":
			local_answer_locked.emit(_int(message.get("round", 0)), _int(message.get("option_index", -1)), bool(message.get("correct", false)))
		"round_result":
			last_result = _result_from(message)
			_apply_hp(message.get("hp", null))
			_set_state(State.ROUND_RESULT)
			round_resolved.emit(last_result.duplicate(true))
		"match_finished":
			_finish(message)


# ---- socket lifecycle -------------------------------------------------------------

func _open_socket() -> void:
	var token: String = _token()
	if token.is_empty():
		_fail("auth_failed")
		return
	self_id = token_subject(token)
	_socket = _make_socket()
	_socket_open = false
	var err: Error = _socket.open(ws_url(room_code), PackedStringArray(["Authorization: Bearer " + token]))
	if err != OK:
		_socket = null
		_on_socket_closed(-1)
		return
	if state != State.RECONNECTING:
		_set_state(State.CONNECTING)


func _on_socket_closed(code: int) -> void:
	if _leaving:
		_leaving = false
		if state != State.FINISHED:
			_set_state(State.IDLE)
		return
	if CLOSE_ERRORS.has(code):
		_stop_reconnect()
		if state == State.FINISHED:
			return
		var reason: String = str(CLOSE_ERRORS[code])
		if code == CLOSE_REPLACED or code == CLOSE_ROOM_GONE:
			_report(reason)
			_set_state(State.DISCONNECTED)
		else:
			_fail(reason)
		return
	if state == State.FINISHED or state == State.IDLE or state == State.ERROR or state == State.DISCONNECTED:
		return
	var now: int = _now()
	if state != State.RECONNECTING:
		_reconnect_deadline = now + RECONNECT_WINDOW_MS
		reconnect_attempts = 0
		_set_state(State.RECONNECTING)
	_next_retry_at = now + backoff_ms(reconnect_attempts)


func _give_up() -> void:
	_stop_reconnect()
	_report("reconnect_failed")
	_set_state(State.DISCONNECTED)


func _stop_reconnect() -> void:
	_reconnect_deadline = 0
	_next_retry_at = 0


func _close_socket() -> void:
	if _socket != null:
		_socket.close(1000)
	_socket = null
	_socket_open = false


func _send(message: Dictionary) -> bool:
	if _socket == null or not _socket_open:
		return false
	return _socket.send_text(JSON.stringify(message)) == OK


func _begin_session() -> void:
	_op_seq += 1
	_leaving = false
	_close_socket()
	_stop_reconnect()
	room_code = ""
	self_id = ""
	host_id = ""
	guest_id = ""
	last_revision = 0
	ignored_events = 0
	hp = {}
	current_round = {}
	countdown_ends_at = 0
	last_result = {}
	finish_result = {}
	last_error_code = ""
	reconnect_attempts = 0
	_answered_round = 0


# ---- state application ------------------------------------------------------------

func _accept_room_reply(reply: Dictionary) -> bool:
	var data: Dictionary = reply.get("data", {}) as Dictionary
	if not bool(reply.get("ok", false)):
		_fail(_http_error_code(int(reply.get("status", 0)), data))
		return false
	var code: String = str(data.get("code", "")).strip_edges().to_upper()
	if code.is_empty():
		_fail("bad_response")
		return false
	room_code = code
	self_id = token_subject(_token())
	_sample_clock(data)
	last_revision = maxi(last_revision, _int(data.get("revision", 0)))
	_apply_view(data)
	return true


func _apply_view(view: Dictionary) -> void:
	host_id = str(view.get("host_id", ""))
	guest_id = "" if view.get("guest_id", null) == null else str(view.get("guest_id", ""))
	_apply_hp(view.get("hp", null))
	countdown_ends_at = _int(view.get("countdown_ends_at", 0))
	var raw_round: Variant = view.get("round", null)
	current_round = public_round(raw_round as Dictionary) if typeof(raw_round) == TYPE_DICTIONARY else {}
	if bool(view.get("you_answered", false)) and not current_round.is_empty():
		_answered_round = int(current_round.get("round", 0))
	var raw_result: Variant = view.get("result", null)
	if typeof(raw_result) == TYPE_DICTIONARY:
		last_result = _result_from(raw_result as Dictionary)
	var server_state: String = str(view.get("state", ""))
	if server_state == "finished" or server_state == "abandoned":
		_finish(view)
	else:
		_set_state(state_for(server_state))
	room_updated.emit(public_view(view))


func _finish(source: Dictionary) -> void:
	_stop_reconnect()
	_apply_hp(source.get("hp", null))
	var already: bool = state == State.FINISHED
	finish_result = {
		"state": str(source.get("state", "finished")),
		"reason": str(source.get("reason", source.get("finish_reason", ""))),
		"winner_id": "" if source.get("winner_id", null) == null else str(source.get("winner_id", "")),
		"retired_by": "" if source.get("retired_by", null) == null else str(source.get("retired_by", "")),
		"hp": hp.duplicate(),
	}
	_set_state(State.FINISHED)
	if not already:
		match_finished.emit(finish_result.duplicate(true))


func _apply_hp(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var next: Dictionary = {}
	for key: Variant in (raw as Dictionary).keys():
		next[str(key)] = _int((raw as Dictionary)[key])
	hp = next


func _result_from(source: Dictionary) -> Dictionary:
	var damage: Dictionary = {}
	var raw_damage: Variant = source.get("damage", {})
	if typeof(raw_damage) == TYPE_DICTIONARY:
		for key: Variant in (raw_damage as Dictionary).keys():
			damage[str(key)] = _int((raw_damage as Dictionary)[key])
	return {
		"round": _int(source.get("round", 0)),
		"winner_id": "" if source.get("winner_id", null) == null else str(source.get("winner_id", "")),
		"reason": str(source.get("reason", "")),
		"damage": damage,
		"correct_option": _int(source.get("correct_option", -1)),
	}


func _sample_clock(message: Dictionary) -> void:
	if not message.has("server_now"):
		return
	clock_offset_ms = _int(message.get("server_now", 0)) - _now()
	has_clock_sample = true


func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	connection_changed.emit(int(next))


func _fail(code: String) -> void:
	_report(code)
	_set_state(State.ERROR)


func _report(code: String) -> void:
	last_error_code = code
	error_received.emit(code, safe_message(code))


# ---- helpers -----------------------------------------------------------------------

static func public_round(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ROUND_KEYS:
		if not source.has(key):
			continue
		if key == "options":
			var options: Array[String] = []
			for option: Variant in source[key] as Array:
				options.append(str(option))
			out[key] = options
		elif key == "question_id" or key == "question":
			out[key] = str(source[key])
		else:
			out[key] = _int(source[key])
	return out


static func public_view(view: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ["code", "state", "host_id", "guest_id", "ready", "connected", "hp", "round_number", "countdown_ends_at", "winner_id", "retired_by", "finish_reason"]:
		if view.has(key):
			out[key] = view[key]
	return out


static func state_for(server_state: String) -> State:
	match server_state:
		"waiting":
			return State.WAITING
		"countdown":
			return State.COUNTDOWN
		"active":
			return State.ACTIVE
		"round_result":
			return State.ROUND_RESULT
		"finished", "abandoned":
			return State.FINISHED
	return State.ERROR


static func backoff_ms(attempt: int) -> int:
	return RECONNECT_BACKOFF_MS[clampi(attempt, 0, RECONNECT_BACKOFF_MS.size() - 1)]


static func safe_message(code: String) -> String:
	return str(SAFE_MESSAGES.get(code, "Something went wrong. Please try again."))


## Reads the JWT "id" claim locally so the UI knows which HP is ours. Never sent to the server.
static func token_subject(token: String) -> String:
	var parts: PackedStringArray = token.split(".")
	if parts.size() < 2:
		return ""
	var encoded: String = parts[1].replace("-", "+").replace("_", "/")
	while encoded.length() % 4 != 0:
		encoded += "="
	var parsed: Variant = JSON.parse_string(Marshalls.base64_to_raw(encoded).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	return str((parsed as Dictionary).get("id", ""))


func ws_url(code: String) -> String:
	var base: String = _base()
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	return "%s/api/pvp/rooms/%s/ws" % [base, code.uri_encode()]


func _base() -> String:
	var base: String = api_base
	if base.is_empty():
		base = str(ProjectSettings.get_setting("levelblue/api_base_url", DEFAULT_API_BASE))
	return base.strip_edges().trim_suffix("/")


func _token() -> String:
	if token_provider.is_valid():
		return str(token_provider.call())
	var auth: Node = get_node_or_null("/root/AuthService")
	if auth == null:
		return ""
	return str(auth.call("auth_token"))


func _now() -> int:
	if now_provider.is_valid():
		return int(now_provider.call())
	return Time.get_ticks_msec()


func _make_socket() -> SocketTransport:
	if socket_factory.is_valid():
		return socket_factory.call() as SocketTransport
	return SocketTransport.new()


func _http_error_code(status: int, data: Dictionary) -> String:
	var code: String = str(data.get("code", ""))
	if not code.is_empty():
		return code
	match status:
		0:
			return "network"
		401:
			return "auth_failed"
		403:
			return "forbidden"
		404:
			return "room_not_found"
	return "bad_response"


func _call_http(method: int, path: String, body: Dictionary = {}) -> Dictionary:
	if http_transport.is_valid():
		var injected: Variant = await http_transport.call(method, path, body)
		return injected as Dictionary if typeof(injected) == TYPE_DICTIONARY else {"ok": false, "status": 0, "data": {}}
	return await _default_http(method, path, body)


func _default_http(method: int, path: String, body: Dictionary) -> Dictionary:
	var token: String = _token()
	if token.is_empty():
		return {"ok": false, "status": 401, "data": {}}
	if _http == null:
		return {"ok": false, "status": 0, "data": {}}
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + token,
	])
	var payload: String = "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	if _http.request(_base() + path, headers, method, payload) != OK:
		return {"ok": false, "status": 0, "data": {}}
	var completed: Array = await _http.request_completed
	var result: int = int(completed[0])
	var status: int = int(completed[1])
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": {}}
	var text: String = (completed[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}
	var data: Dictionary = parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
	return {"ok": status >= 200 and status < 300, "status": status, "data": data}


static func _int(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and (value as String).is_valid_int():
		return int(value)
	return 0
