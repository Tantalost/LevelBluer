extends SceneTree
## Online PvP session layer against fake HTTP/WebSocket transports. No backend, no UI.
const Session = preload("res://src/network/pvp_online_session.gd")

const HOST_ID: String = "stu-host"
const GUEST_ID: String = "stu-guest"
const OUTSIDER_ID: String = "stu-outsider"
const POLL_STEP_MS: int = 100

var failures: int = 0
var clock_ms: int = 1000
var http_calls: Array[Dictionary] = []
var http_replies: Array[Dictionary] = []
var sockets: Array[FakeSocket] = []
var socket_plan: Array[int] = []


class FakeSocket extends "res://src/network/pvp_online_session.gd".SocketTransport:
	var url: String = ""
	var headers: PackedStringArray = PackedStringArray()
	var state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
	var code: int = -1
	var inbound: Array[String] = []
	var sent: Array[String] = []
	var closed_by_client: bool = false
	var opens: bool = true

	func open(target: String, handshake: PackedStringArray) -> Error:
		url = target
		headers = handshake
		state = WebSocketPeer.STATE_OPEN if opens else WebSocketPeer.STATE_CLOSED
		return OK

	func poll() -> void:
		pass

	func ready_state() -> WebSocketPeer.State:
		return state

	func close_code() -> int:
		return code

	func next_text() -> String:
		if inbound.is_empty():
			return ""
		return inbound.pop_front()

	func send_text(text: String) -> Error:
		if state != WebSocketPeer.STATE_OPEN:
			return ERR_UNAVAILABLE
		sent.append(text)
		return OK

	func close(close_with: int = 1000) -> void:
		closed_by_client = true
		code = close_with
		state = WebSocketPeer.STATE_CLOSED

	func push(message: Dictionary) -> void:
		inbound.append(JSON.stringify(message))

	func drop(close_with: int) -> void:
		code = close_with
		state = WebSocketPeer.STATE_CLOSED

	func sent_messages() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for text: String in sent:
			out.append(JSON.parse_string(text) as Dictionary)
		return out


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func jwt(user_id: String) -> String:
	var payload: String = Marshalls.utf8_to_base64(JSON.stringify({"id": user_id, "role": "student"})).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	return "eyJhbGciOiJIUzI1NiJ9.%s.signature" % payload


func fake_http(method: int, path: String, body: Dictionary) -> Dictionary:
	http_calls.append({"method": method, "path": path, "body": body})
	if http_replies.is_empty():
		return {"ok": false, "status": 0, "data": {}}
	return http_replies.pop_front()


func make_socket() -> Session.SocketTransport:
	var socket: FakeSocket = FakeSocket.new()
	if not socket_plan.is_empty():
		socket.opens = socket_plan.pop_front() == 1
	sockets.append(socket)
	return socket


func now() -> int:
	return clock_ms


func session_for(user_id: String) -> Session:
	clock_ms = 1000
	http_calls.clear()
	http_replies.clear()
	sockets.clear()
	socket_plan.clear()
	var session: Session = Session.new()
	session.http_transport = fake_http
	session.socket_factory = make_socket
	session.now_provider = now
	session.token_provider = func() -> String: return jwt(user_id)
	session.api_base = "https://api.levelblue.test/"
	return session


func view(code: String, server_state: String, revision: int, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"code": code,
		"state": server_state,
		"host_id": HOST_ID,
		"guest_id": GUEST_ID,
		"ready": {HOST_ID: false, GUEST_ID: false},
		"connected": {HOST_ID: true, GUEST_ID: true},
		"hp": {HOST_ID: 100, GUEST_ID: 100},
		"round_number": 0,
		"countdown_ends_at": null,
		"round": null,
		"result": null,
		"winner_id": null,
		"retired_by": null,
		"finish_reason": null,
		"revision": revision,
		"server_now": 50000,
	}
	out.merge(extra, true)
	return out


func round_event(revision: int, number: int, server_now: int = 60000) -> Dictionary:
	return {
		"type": "round_started",
		"revision": revision,
		"code": "ABC234",
		"server_now": server_now,
		"round": number,
		"question_id": "pvp_easy_01_0%d" % number,
		"question": "What is phishing?",
		"options": ["A trick", "Antivirus", "Charger", "Wi-Fi"],
		"started_at": server_now,
		"ends_at": server_now + 10000,
	}


## A session that created room ABC234 and has an open socket in the waiting state.
func open_host() -> Session:
	var session: Session = session_for(HOST_ID)
	http_replies.append({"ok": true, "status": 201, "data": view("ABC234", "waiting", 0, {"guest_id": null, "hp": {HOST_ID: 100}})})
	session.create_room()
	session.poll()
	var socket: FakeSocket = sockets.back()
	socket.push(view("ABC234", "waiting", 1, {"type": "room_state"}))
	session.poll()
	return session


func active_host() -> Session:
	var session: Session = open_host()
	var socket: FakeSocket = sockets.back()
	socket.push({"type": "countdown_started", "revision": 2, "server_now": 57000, "round": 1, "countdown_ends_at": 60000})
	socket.push(round_event(3, 1))
	session.poll()
	return session


func _run() -> void:
	var player: Node = root.get_node("PlayerManager")
	var mastery_before: String = JSON.stringify(player.mastery_matrix)
	_check_create_room()
	_check_join_room()
	_check_http_failures()
	_check_revision_ordering()
	_check_round_started()
	_check_answer_payload()
	_check_clock_offset()
	_check_disconnect_reconnects()
	_check_reconnect_gives_up()
	_check_intentional_leave()
	_check_close_codes()
	_check_match_finished_stops_reconnect()
	_check_new_room_resets()
	_check_source_guards()
	check(JSON.stringify(player.mastery_matrix) == mastery_before, "online PvP session never touches mastery")
	print("[PVP ONLINE] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _check_create_room() -> void:
	var session: Session = session_for(HOST_ID)
	var created: Array[String] = []
	session.room_created.connect(func(code: String) -> void: created.append(code))
	http_replies.append({"ok": true, "status": 201, "data": view("abc234", "waiting", 0, {"guest_id": null, "hp": {HOST_ID: 100}})})
	session.create_room()
	check(http_calls.size() == 1 and int(http_calls[0]["method"]) == HTTPClient.METHOD_POST and str(http_calls[0]["path"]) == "/api/pvp/rooms", "create posts to /api/pvp/rooms")
	check((http_calls[0]["body"] as Dictionary).is_empty(), "create sends no player id or other body fields")
	check(created == ["ABC234"] and session.room_code == "ABC234", "create parses and normalizes the room code")
	check(session.self_id == HOST_ID and session.host_id == HOST_ID and session.guest_id.is_empty(), "create reads identity from the JWT and the server view")
	check(session.state == Session.State.CONNECTING and sockets.size() == 1, "create opens one WebSocket")
	var socket: FakeSocket = sockets[0]
	check(socket.url == "wss://api.levelblue.test/api/pvp/rooms/ABC234/ws", "the socket URL is derived from the API base (https -> wss)")
	check(socket.headers == PackedStringArray(["Authorization: Bearer " + jwt(HOST_ID)]), "the handshake carries only the bearer JWT")
	session.poll()
	socket.push(view("ABC234", "waiting", 1, {"type": "room_state"}))
	session.poll()
	check(session.state == Session.State.WAITING and session.last_revision == 1, "room_state moves the session to waiting")
	check(session.send_ready() and socket.sent_messages().back() == {"type": "ready"}, "ready sends only the ready type")
	session.free()


func _check_join_room() -> void:
	var session: Session = session_for(GUEST_ID)
	var joined: Array[String] = []
	session.room_joined.connect(func(code: String) -> void: joined.append(code))
	http_replies.append({"ok": true, "status": 200, "data": view("ABC234", "waiting", 2)})
	session.join_room(" abc234 ")
	check(str(http_calls[0]["path"]) == "/api/pvp/rooms/ABC234/join" and (http_calls[0]["body"] as Dictionary).is_empty(), "join posts to the room code with no body")
	check(joined == ["ABC234"] and session.self_id == GUEST_ID and session.opponent_id() == HOST_ID, "join parses the room and identifies the opponent")
	check(session.last_revision == 2 and session.my_hp() == 100 and session.opponent_hp() == 100, "join applies HP and the HTTP revision")
	check(sockets.size() == 1 and sockets[0].url.ends_with("/api/pvp/rooms/ABC234/ws"), "join opens the room socket")
	session.free()


func _check_http_failures() -> void:
	var session: Session = session_for(OUTSIDER_ID)
	var errors: Array[String] = []
	session.error_received.connect(func(code: String, _message: String) -> void: errors.append(code))
	http_replies.append({"ok": false, "status": 409, "data": {"error": "This room already has two players", "code": "room_full"}})
	check(not await session.join_room("ABC234"), "a full room fails to join")
	check(session.state == Session.State.ERROR and errors == ["room_full"] and sockets.is_empty(), "a rejected join surfaces the server code and opens no socket")
	check(Session.safe_message("room_full") == "That room already has two players.", "server codes map to user-safe text")
	http_replies.append({"ok": false, "status": 401, "data": {"error": "Invalid or expired token"}})
	session.create_room()
	check(errors.back() == "auth_failed", "a 401 without a code becomes auth_failed")
	http_replies.append({"ok": false, "status": 0, "data": {}})
	session.create_room()
	check(errors.back() == "network", "a transport failure becomes network")
	session.free()


## Parsed JSON numbers are floats; compare integer payloads explicitly.
func same_ints(message: Dictionary, expected: Dictionary) -> bool:
	if message.keys().size() != expected.keys().size():
		return false
	for key: Variant in expected:
		if not message.has(key):
			return false
		var want: Variant = expected[key]
		if typeof(want) == TYPE_INT:
			if typeof(message[key]) != TYPE_FLOAT and typeof(message[key]) != TYPE_INT:
				return false
			if int(message[key]) != int(want):
				return false
		elif str(message[key]) != str(want):
			return false
	return true


func _check_revision_ordering() -> void:
	var session: Session = open_host()
	var socket: FakeSocket = sockets.back()
	var updates: Array[int] = []
	session.room_updated.connect(func(_view: Dictionary) -> void: updates.append(session.last_revision))
	socket.push(view("ABC234", "waiting", 5, {"type": "room_state"}))
	socket.push(view("ABC234", "waiting", 5, {"type": "room_state", "ready": {HOST_ID: true, GUEST_ID: true}}))
	socket.push(view("ABC234", "waiting", 4, {"type": "room_state"}))
	socket.push(view("ABC234", "waiting", 9, {"type": "room_state"}))
	session.poll()
	check(updates == [5, 9], "only revisions above the last applied one are applied")
	check(session.ignored_events == 2, "duplicate and stale revisions are ignored")
	check(session.last_revision == 9, "gaps between revisions are allowed")
	var states: Array[int] = []
	session.connection_changed.connect(func(next_state: int) -> void: states.append(next_state))
	socket.push({"type": "pong", "revision": 50, "server_now": 70000})
	socket.push({"type": "error", "code": "not_waiting", "message": "x", "revision": 60, "server_now": 70000})
	session.poll()
	check(session.last_revision == 9 and states.is_empty() and session.state == Session.State.WAITING, "pong and error never change revision or state")
	check(session.last_error_code == "not_waiting", "server errors are surfaced")
	session.free()


func _check_round_started() -> void:
	var session: Session = open_host()
	var socket: FakeSocket = sockets.back()
	var started: Array[Dictionary] = []
	var counted: Array[int] = []
	session.round_started.connect(func(round_data: Dictionary) -> void: started.append(round_data))
	session.countdown_started.connect(func(number: int, _ends_at: int) -> void: counted.append(number))
	socket.push({"type": "countdown_started", "revision": 2, "server_now": 57000, "round": 1, "countdown_ends_at": 60000})
	session.poll()
	check(session.state == Session.State.COUNTDOWN and counted == [1] and session.countdown_ends_at == 60000, "countdown_started is parsed")
	var leaky: Dictionary = round_event(3, 1)
	leaky["answer_index"] = 2
	leaky["bkt"] = {"p_g": 0.25}
	leaky["correct_option"] = 0
	socket.push(leaky)
	session.poll()
	check(session.state == Session.State.ACTIVE and started.size() == 1, "round_started activates the round")
	var stored: Dictionary = session.current_round
	check(stored.keys().size() == 6 and stored.has("question_id") and not stored.has("answer_index") and not stored.has("bkt") and not stored.has("correct_option"), "only public round fields are stored")
	check(stored["round"] == 1 and stored["question_id"] == "pvp_easy_01_01" and stored["ends_at"] == 70000, "round fields keep their values")
	check(JSON.stringify(stored["options"]) == JSON.stringify(["A trick", "Antivirus", "Charger", "Wi-Fi"]), "option order is kept exactly as sent")
	check(typeof(stored["round"]) == TYPE_INT and typeof(stored["started_at"]) == TYPE_INT, "round numbers and deadlines are ints")
	session.free()


func _check_answer_payload() -> void:
	var session: Session = active_host()
	var socket: FakeSocket = sockets.back()
	var locks: Array[bool] = []
	session.local_answer_locked.connect(func(_round: int, _option: int, correct: bool) -> void: locks.append(correct))
	check(not session.submit_answer(4) and not session.submit_answer(-1), "out-of-range options are not sent")
	check(session.submit_answer(1), "the first answer is sent")
	var answer: Dictionary = socket.sent_messages().back()
	check(same_ints(answer, {"type": "answer", "round": 1, "option_index": 1}), "the answer payload is only type, round, and option_index")
	check(not socket.sent.back().contains("."), "round and option_index serialize as integers")
	check(not session.submit_answer(2) and socket.sent.size() == 1, "a second answer for the same round is blocked locally")
	check(session.has_answered_current_round(), "the session remembers the local lock")
	socket.push({"type": "answer_locked", "revision": 4, "server_now": 61000, "round": 1, "option_index": 1, "correct": false})
	socket.push({"type": "error", "code": "late", "message": "x", "revision": 4, "server_now": 61000})
	session.poll()
	check(locks == [false] and session.last_error_code == "late", "server lock and rejection are surfaced")
	socket.push({"type": "round_result", "revision": 6, "server_now": 62000, "round": 1, "winner_id": GUEST_ID, "reason": "correct", "damage": {HOST_ID: 20}, "hp": {HOST_ID: 80, GUEST_ID: 100}, "correct_option": 2, "result_ends_at": 64500})
	session.poll()
	check(session.state == Session.State.ROUND_RESULT and session.my_hp() == 80 and session.last_result["correct_option"] == 2, "round_result applies server HP and result")
	check(not session.submit_answer(0), "answers are not sent during the result")
	socket.push(round_event(8, 2, 67000))
	session.poll()
	check(not session.has_answered_current_round() and session.submit_answer(0), "a new round unlocks one new answer")
	session.free()


func _check_clock_offset() -> void:
	var session: Session = active_host()
	clock_ms = 2000
	sockets.back().push({"type": "pong", "revision": 3, "server_now": 61500})
	session.poll()
	check(session.has_clock_sample and session.clock_offset_ms == 59500, "the offset is server_now minus local time")
	clock_ms = 2500
	check(session.server_now_ms() == 62000, "server time advances with the local clock")
	check(session.round_remaining_ms() == 8000, "round time is the server deadline minus estimated server time")
	clock_ms = 20000
	check(session.round_remaining_ms() == 0, "the display timer floors at zero")
	check(session.state == Session.State.ACTIVE, "the client never ends a round locally")
	session.free()


func _check_disconnect_reconnects() -> void:
	var session: Session = active_host()
	var first: FakeSocket = sockets.back()
	check(session.submit_answer(3), "an answer is sent before the drop")
	first.drop(1006)
	session.poll()
	check(session.state == Session.State.RECONNECTING, "an unexpected drop enters reconnecting")
	check(sockets.size() == 1, "the first retry waits for the backoff")
	clock_ms += Session.backoff_ms(0) - 1
	session.poll()
	check(sockets.size() == 1, "no retry before 0.5s")
	clock_ms += 1
	session.poll()
	check(sockets.size() == 2 and session.reconnect_attempts == 1, "the first retry opens a new socket")
	var second: FakeSocket = sockets.back()
	check(second.url == first.url and second.headers == first.headers, "reconnect reuses the room code and JWT")
	check(http_calls.size() == 1, "reconnect never creates or joins a room again")
	second.push(view("ABC234", "active", 7, {"type": "room_state", "round_number": 1, "round": {"round": 1, "question_id": "pvp_easy_01_01", "question": "What is phishing?", "options": ["A trick", "Antivirus", "Charger", "Wi-Fi"], "started_at": 60000, "ends_at": 70000}, "you_answered": true}))
	session.poll()
	check(session.state == Session.State.ACTIVE and session.current_round["question_id"] == "pvp_easy_01_01", "reconnect restores the authoritative round")
	check(session.has_answered_current_round() and not session.submit_answer(0), "a restored round keeps the server's answered lock")
	session.free()


func _check_reconnect_gives_up() -> void:
	var session: Session = active_host()
	var errors: Array[String] = []
	session.error_received.connect(func(code: String, _message: String) -> void: errors.append(code))
	for _i: int in 20:
		socket_plan.append(0)
	sockets.back().drop(1006)
	session.poll()
	var dropped_at: int = clock_ms
	var opens: Array[int] = []
	while clock_ms <= dropped_at + Session.RECONNECT_WINDOW_MS + 4000:
		clock_ms += POLL_STEP_MS
		var before: int = sockets.size()
		session.poll()
		if sockets.size() > before:
			opens.append(clock_ms - dropped_at)
	check(opens.size() >= 4 and opens[0] == 500, "retries start after 0.5s")
	var gaps_ok: bool = true
	for index: int in range(1, opens.size()):
		gaps_ok = gaps_ok and opens[index] - opens[index - 1] <= 3000 + POLL_STEP_MS
	check(gaps_ok, "the backoff is bounded at 3s")
	check(opens.back() < Session.RECONNECT_WINDOW_MS, "no retry starts after the 15s grace")
	check(session.state == Session.State.DISCONNECTED and errors == ["reconnect_failed"], "reconnecting gives up after the grace")
	var settled: int = sockets.size()
	clock_ms += 30000
	session.poll()
	check(sockets.size() == settled, "a given-up session stays disconnected")
	session.free()


func _check_intentional_leave() -> void:
	var session: Session = active_host()
	var socket: FakeSocket = sockets.back()
	session.leave()
	check(socket.sent_messages().back() == {"type": "leave"}, "leave sends the leave message")
	socket.push({"type": "match_finished", "revision": 9, "server_now": 61000, "state": "abandoned", "reason": "retired", "winner_id": GUEST_ID, "retired_by": HOST_ID, "hp": {HOST_ID: 100, GUEST_ID: 100}})
	socket.drop(1000)
	session.poll()
	clock_ms += 20000
	session.poll()
	check(sockets.size() == 1, "intentional leave never reconnects")
	check(session.state == Session.State.FINISHED and session.finish_result["reason"] == "retired", "leave ends in the server's finished result")
	var quiet: Session = active_host()
	quiet.leave()
	clock_ms += Session.LEAVE_TIMEOUT_MS
	quiet.poll()
	clock_ms += 20000
	quiet.poll()
	check(sockets.size() == 1 and quiet.state == Session.State.IDLE and sockets[0].closed_by_client, "a leave the server never confirms closes locally without reconnecting")
	session.free()
	quiet.free()


func _check_close_codes() -> void:
	var expected: Dictionary = {
		4401: ["auth_failed", Session.State.ERROR],
		4403: ["forbidden", Session.State.ERROR],
		4404: ["room_missing", Session.State.ERROR],
		4409: ["replaced", Session.State.DISCONNECTED],
		4410: ["room_closed", Session.State.DISCONNECTED],
	}
	for close_code: int in expected:
		var session: Session = active_host()
		var errors: Array[String] = []
		session.error_received.connect(func(code: String, _message: String) -> void: errors.append(code))
		sockets.back().drop(close_code)
		session.poll()
		clock_ms += 20000
		session.poll()
		var want: Array = expected[close_code]
		check(errors == [str(want[0])] and session.state == int(want[1]), "close %d becomes %s" % [close_code, want[0]])
		check(sockets.size() == 1, "close %d never reconnects" % close_code)
		session.free()


func _check_match_finished_stops_reconnect() -> void:
	var session: Session = active_host()
	var socket: FakeSocket = sockets.back()
	var finished: Array[Dictionary] = []
	session.match_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	socket.push({"type": "round_result", "revision": 4, "server_now": 61000, "round": 1, "winner_id": HOST_ID, "reason": "correct", "damage": {GUEST_ID: 20}, "hp": {HOST_ID: 100, GUEST_ID: 0}, "correct_option": 1, "result_ends_at": 63500})
	socket.push({"type": "match_finished", "revision": 5, "server_now": 61000, "state": "finished", "reason": "ko", "winner_id": HOST_ID, "retired_by": null, "hp": {HOST_ID: 100, GUEST_ID: 0}})
	session.poll()
	check(finished.size() == 1 and finished[0]["winner_id"] == HOST_ID and finished[0]["reason"] == "ko", "match_finished reports the server winner")
	socket.drop(1006)
	session.poll()
	clock_ms += 20000
	session.poll()
	check(sockets.size() == 1 and session.state == Session.State.FINISHED, "a finished match never reconnects")
	session.free()


func _check_new_room_resets() -> void:
	var session: Session = active_host()
	var old: FakeSocket = sockets.back()
	check(session.last_revision == 3 and not session.current_round.is_empty(), "the first room has state")
	http_replies.append({"ok": true, "status": 201, "data": view("XYZ789", "waiting", 0, {"guest_id": null, "hp": {HOST_ID: 100}})})
	session.create_room()
	check(old.closed_by_client, "starting a new room closes the old socket")
	check(session.room_code == "XYZ789" and session.last_revision == 0 and session.current_round.is_empty() and session.last_result.is_empty(), "a new room resets revision and round state")
	var fresh: FakeSocket = sockets.back()
	session.poll()
	fresh.push(view("XYZ789", "waiting", 1, {"type": "room_state"}))
	session.poll()
	check(session.last_revision == 1 and session.state == Session.State.WAITING, "revision 1 is accepted in the new room")
	old.push(view("ABC234", "active", 99, {"type": "room_state"}))
	session.poll()
	check(session.room_code == "XYZ789" and session.last_revision == 1, "the old socket can no longer affect the new session")
	session.free()


func _check_source_guards() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/network/pvp_online_session.gd")
	check(not source.contains("answer_index") and not source.contains("Quiz.grade"), "online mode never reads answer_index or grades locally")
	check(not source.contains("PvpBattle") and not source.contains("update_mastery") and not source.contains("pvp_tokens"), "the session is separate from bot PvP, mastery, and tokens")
	check(not source.contains("\"user_id\"") and not source.contains("\"student_id\""), "the session never sends a player id")
