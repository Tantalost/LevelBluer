extends SceneTree
## FIND OPPONENT: matchmaking client in PvpOnlineSession + the search flow in PvpOnlineScreen. Fake transports, no backend.
## Screens reference autoloads, so they are loaded at runtime rather than preloaded by this entry script.
const Session = preload("res://src/network/pvp_online_session.gd")
const SECTIONS: int = 7
const ONLINE_SCENE: String = "res://src/ui/screens/pvp/pvp_online_screen.tscn"
const BOT_SCENE: String = "res://src/ui/screens/pvp/pvp_battle_screen.tscn"
const ME: String = "stu-me"
const RIVAL: String = "stu-rival"
const JOIN_PATH: String = "/api/pvp/matchmaking/join"
const CANCEL_PATH: String = "/api/pvp/matchmaking/cancel"
const STATUS_PATH: String = "/api/pvp/matchmaking/status"

signal release_http

var failures: int = 0
var sections_done: int = 0
var clock_ms: int = 1000
var http_calls: Array[Dictionary] = []
var http_replies: Array[Dictionary] = []
var sockets: Array[FakeSocket] = []
var hold_http: bool = false
var factory_calls: int = 0


class FakeSocket extends "res://src/network/pvp_online_session.gd".SocketTransport:
	var url: String = ""
	var state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
	var code: int = -1
	var inbound: Array[String] = []
	var sent: Array[String] = []

	func open(target: String, _handshake: PackedStringArray) -> Error:
		url = target
		state = WebSocketPeer.STATE_OPEN
		return OK

	func poll() -> void:
		pass

	func ready_state() -> WebSocketPeer.State:
		return state

	func close_code() -> int:
		return code

	func next_text() -> String:
		return "" if inbound.is_empty() else inbound.pop_front()

	func send_text(text: String) -> Error:
		if state != WebSocketPeer.STATE_OPEN:
			return ERR_UNAVAILABLE
		sent.append(text)
		return OK

	func close(close_with: int = 1000) -> void:
		code = close_with
		state = WebSocketPeer.STATE_CLOSED

	func push(message: Dictionary) -> void:
		inbound.append(JSON.stringify(message))

	func drop(close_with: int) -> void:
		code = close_with
		state = WebSocketPeer.STATE_CLOSED


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for _index: int in 4:
		await process_frame


func jwt(user_id: String) -> String:
	var payload: String = Marshalls.utf8_to_base64(JSON.stringify({"id": user_id, "role": "student"})).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	return "eyJhbGciOiJIUzI1NiJ9.%s.signature" % payload


func fake_http(method: int, path: String, body: Dictionary) -> Dictionary:
	http_calls.append({"method": method, "path": path, "body": body})
	if hold_http:
		await release_http
	if http_replies.is_empty():
		return {"ok": false, "status": 0, "data": {}}
	return http_replies.pop_front()


func make_socket() -> Session.SocketTransport:
	var socket: FakeSocket = FakeSocket.new()
	sockets.append(socket)
	return socket


func now() -> int:
	return clock_ms


func new_session() -> Session:
	factory_calls += 1
	var session: Session = Session.new()
	session.http_transport = fake_http
	session.socket_factory = make_socket
	session.now_provider = now
	session.token_provider = func() -> String: return jwt(ME)
	session.api_base = "https://api.levelblue.test"
	return session


func reset_fakes() -> void:
	clock_ms = 1000
	http_calls.clear()
	http_replies.clear()
	sockets.clear()
	hold_http = false
	factory_calls = 0


func reply(data: Dictionary, status: int = 200) -> void:
	http_replies.append({"ok": status >= 200 and status < 300, "status": status, "data": data})


func queued() -> void:
	reply({"status": "queued", "queued_at": 1000, "expires_at": 91000})


func matched(code: String) -> void:
	reply({"status": "matched", "room_code": code})


func room_view(code: String, revision: int = 2) -> Dictionary:
	return {
		"code": code, "state": "waiting", "host_id": RIVAL, "guest_id": ME,
		"ready": {RIVAL: false, ME: false}, "connected": {RIVAL: false, ME: false},
		"hp": {RIVAL: 100, ME: 100}, "round_number": 0, "countdown_ends_at": null, "round": null,
		"result": null, "winner_id": null, "retired_by": null, "finish_reason": null,
		"origin": "matchmaking", "revision": revision, "server_now": 50000,
	}


func calls_to(path: String) -> int:
	var count: int = 0
	for call: Dictionary in http_calls:
		if str(call["path"]) == path:
			count += 1
	return count


func no_student_id_sent() -> bool:
	for call: Dictionary in http_calls:
		if not (call["body"] as Dictionary).is_empty() or str(call["path"]).contains(ME):
			return false
	return true


## Advance the fake clock in poll-sized steps, pumping the session each time.
func run_for(session: Session, ms: int) -> void:
	var target: int = clock_ms + ms
	while clock_ms < target:
		clock_ms = mini(target, clock_ms + 100)
		session.poll()


func _run() -> void:
	var player: Node = root.get_node("PlayerManager")
	var mastery_before: String = JSON.stringify(player.mastery_matrix)
	var tokens_before: int = int(player.pvp_tokens)
	await _check_queue_and_polling()
	await _check_match_found()
	await _check_cancel()
	await _check_errors()
	await _check_screen_search_flow()
	await _check_screen_cancel_exit_errors()
	await _check_hub_private_and_bot()
	check(JSON.stringify(player.mastery_matrix) == mastery_before, "matchmaking never touches mastery")
	check(int(player.pvp_tokens) == tokens_before, "matchmaking never pays tokens")
	check(sections_done == SECTIONS, "every matchmaking section ran to completion (%d/%d)" % [sections_done, SECTIONS])
	print("[PVP MATCHMAKING] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


# ---- session -----------------------------------------------------------------------------

func _check_queue_and_polling() -> void:
	reset_fakes()
	var session: Session = new_session()
	queued()
	await session.join_matchmaking()
	check(http_calls.size() == 1 and int(http_calls[0]["method"]) == HTTPClient.METHOD_POST and str(http_calls[0]["path"]) == JOIN_PATH, "FIND OPPONENT posts once to the join endpoint")
	check(session.state == Session.State.SEARCHING and session.is_polling_matchmaking(), "a queued reply starts searching and schedules polling")
	session.poll()
	check(calls_to(STATUS_PATH) == 0, "the first status poll waits about a second")
	clock_ms += Session.MATCHMAKING_POLL_MS - 1
	session.poll()
	check(calls_to(STATUS_PATH) == 0, "no poll before 1s")
	hold_http = true
	clock_ms += 1
	session.poll()
	check(calls_to(STATUS_PATH) == 1 and int(http_calls.back()["method"]) == HTTPClient.METHOD_GET, "the status poll fires at 1s")
	run_for(session, 5000)
	session.get_matchmaking_status()
	check(calls_to(STATUS_PATH) == 1, "a slow status reply never overlaps with another poll")
	queued()
	hold_http = false
	release_http.emit()
	check(session.state == Session.State.SEARCHING and session.is_polling_matchmaking(), "queued keeps searching")
	for _index: int in 3:
		queued()
	run_for(session, 3000)
	check(calls_to(STATUS_PATH) == 1 + 3 and session.state == Session.State.SEARCHING, "queued polls about once per second (%d polls, %s)" % [calls_to(STATUS_PATH), Session.State.keys()[session.state]])
	check(no_student_id_sent(), "matchmaking requests never carry a student id")
	session.free()
	sections_done += 1


func _check_match_found() -> void:
	reset_fakes()
	var session: Session = new_session()
	var found: Array[String] = []
	session.match_found.connect(func(code: String) -> void: found.append(code))
	queued()
	await session.join_matchmaking()
	matched("abc234")
	http_replies.append({"ok": true, "status": 200, "data": room_view("ABC234")})
	clock_ms += Session.MATCHMAKING_POLL_MS
	session.poll()
	check(found == ["ABC234"], "matched reports the server's room code once")
	check(calls_to("/api/pvp/rooms/ABC234") == 1, "the matched room is recovered through the existing room endpoint")
	check(sockets.size() == 1 and sockets[0].url.ends_with("/api/pvp/rooms/ABC234/ws"), "the same session opens the normal room socket")
	check(session.room_code == "ABC234" and session.state == Session.State.CONNECTING and not session.is_polling_matchmaking(), "matched stops polling and enters the room")
	var status_calls: int = calls_to(STATUS_PATH)
	run_for(session, 5000)
	check(calls_to(STATUS_PATH) == status_calls, "no status polls after a match")
	sockets[0].push(room_view("ABC234", 3).merged({"type": "room_state"}))
	session.poll()
	check(session.state == Session.State.WAITING and session.opponent_id() == RIVAL, "the matched room behaves like a normal waiting room")
	check(session.send_ready() and sockets[0].sent.size() == 1, "the existing manual READY step is kept")
	reset_fakes()
	session.free()
	session = new_session()
	matched("XYZ789")
	http_replies.append({"ok": true, "status": 200, "data": room_view("XYZ789")})
	await session.join_matchmaking()
	check(session.room_code == "XYZ789" and calls_to(STATUS_PATH) == 0, "an immediate match on join skips polling")
	session.free()
	sections_done += 1


func _check_cancel() -> void:
	reset_fakes()
	var session: Session = new_session()
	var ended: Array[String] = []
	session.matchmaking_ended.connect(func(reason: String) -> void: ended.append(reason))
	queued()
	await session.join_matchmaking()
	reply({"status": "cancelled"})
	await session.cancel_matchmaking()
	check(calls_to(CANCEL_PATH) == 1 and session.state == Session.State.IDLE and ended == ["cancelled"], "cancel before a match returns to idle")
	run_for(session, 5000)
	check(calls_to(STATUS_PATH) == 0, "cancel stops polling")

	reset_fakes()
	session.free()
	session = new_session()
	queued()
	await session.join_matchmaking()
	matched("RACE22")
	http_replies.append({"ok": true, "status": 200, "data": room_view("RACE22")})
	await session.cancel_matchmaking()
	check(session.room_code == "RACE22" and sockets.size() == 1 and session.state == Session.State.CONNECTING, "a cancel answered with matched continues into the room")
	check(calls_to("/api/pvp/rooms/RACE22") == 1, "the race keeps the server's room instead of discarding it")

	reset_fakes()
	session.free()
	session = new_session()
	ended.clear()
	session.matchmaking_ended.connect(func(reason: String) -> void: ended.append(reason))
	queued()
	await session.join_matchmaking()
	hold_http = true
	clock_ms += Session.MATCHMAKING_POLL_MS
	session.poll()
	check(calls_to(STATUS_PATH) == 1, "a status poll is in flight")
	session.cancel_matchmaking()
	matched("STALE1")
	reply({"status": "cancelled"})
	hold_http = false
	release_http.emit()
	await process_frame
	check(session.state == Session.State.IDLE and session.room_code.is_empty() and ended == ["cancelled"], "a status reply superseded by cancel is ignored")
	run_for(session, 5000)
	check(calls_to(STATUS_PATH) == 1, "no polling after a cancel that interrupted a poll")

	reset_fakes()
	session.free()
	session = new_session()
	queued()
	await session.join_matchmaking()
	hold_http = true
	session.leave()
	check(calls_to(CANCEL_PATH) == 1 and session.state == Session.State.IDLE and session.has_pending_exit(), "leaving a search sends cancel and waits briefly for it")
	clock_ms += Session.LEAVE_TIMEOUT_MS
	check(not session.has_pending_exit(), "a lost cancel reply never blocks leaving")
	run_for(session, 5000)
	check(calls_to(STATUS_PATH) == 0, "leaving a search stops polling")
	hold_http = false
	release_http.emit()
	await process_frame
	session.free()
	sections_done += 1


func _check_errors() -> void:
	var cases: Array[Array] = [
		[{"ok": false, "status": 0, "data": {}}, "network"],
		[{"ok": false, "status": 401, "data": {"detail": "Student sign-in required"}}, "auth_failed"],
		[{"ok": false, "status": 409, "data": {"error": "Finish or leave your current match first", "code": "already_in_match"}}, "already_in_match"],
		[{"ok": true, "status": 200, "data": {}}, "bad_response"],
		[{"ok": true, "status": 200, "data": {"status": "matched"}}, "bad_response"],
		[{"ok": true, "status": 200, "data": {"status": "idle"}}, "search_ended"],
	]
	for case: Array in cases:
		reset_fakes()
		var session: Session = new_session()
		http_replies.append(case[0] as Dictionary)
		await session.join_matchmaking()
		var expected: String = str(case[1])
		check(session.state == Session.State.ERROR and session.last_error_code == expected, "join failure maps to %s (got %s)" % [expected, session.last_error_code])
		check(Session.safe_message(expected) != Session.safe_message("unknown_code") or expected == "bad_response", "%s has user-safe text" % expected)
		run_for(session, 3000)
		check(calls_to(STATUS_PATH) == 0, "no polling after %s" % expected)
		session.free()
	reset_fakes()
	var expiring: Session = new_session()
	queued()
	await expiring.join_matchmaking()
	reply({"status": "idle"})
	clock_ms += Session.MATCHMAKING_POLL_MS
	expiring.poll()
	check(expiring.state == Session.State.ERROR and expiring.last_error_code == "search_ended", "idle while queued (expiry or private room) ends the search safely")
	run_for(expiring, 3000)
	check(calls_to(STATUS_PATH) == 1, "an ended search stops polling")
	expiring.free()
	sections_done += 1


# ---- screen --------------------------------------------------------------------------------

func open_screen(action: String) -> Control:
	root.size = Vector2i(1280, 720)
	var screen: Control = (load(ONLINE_SCENE) as PackedScene).instantiate() as Control
	screen.session_factory = new_session
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.on_enter({"action": action})
	await settle()
	return screen


func close_screen(screen: Control) -> void:
	if is_instance_valid(screen):
		screen.on_exit()
		screen.queue_free()
	await settle()


func online_sessions(screen: Control) -> int:
	var count: int = 0
	for child: Node in screen.get_children():
		if child is Session:
			count += 1
	return count


func _check_screen_search_flow() -> void:
	reset_fakes()
	queued()
	var screen: Control = await open_screen("find")
	var session: Session = screen._session
	check(calls_to(JOIN_PATH) == 1 and factory_calls == 1, "FIND OPPONENT joins the queue with one session")
	check(screen._search_box.visible and screen._search_title.text.begins_with("SEARCHING FOR OPPONENT") and screen._cancel_search_button.visible, "the search panel shows SEARCHING FOR OPPONENT and CANCEL")
	check(not screen._room_box.visible and not screen._entry.visible and not screen._leave_room_button.visible and not screen._hud.visible, "searching shows only the search panel")
	clock_ms += 7400
	queued()
	screen._process(0.0)
	check(screen._search_time.text == "0:07", "elapsed search time counts up (%s)" % screen._search_time.text)
	await settle()
	check(session.state == Session.State.SEARCHING and calls_to(STATUS_PATH) >= 1, "the screen keeps the session polling while queued")
	matched("MATCH1")
	http_replies.append({"ok": true, "status": 200, "data": room_view("MATCH1")})
	clock_ms += Session.MATCHMAKING_POLL_MS
	await settle()
	check(screen._session == session and session.room_code == "MATCH1" and factory_calls == 1 and online_sessions(screen) == 1, "the match is entered with the same single session")
	check(not screen._search_box.visible and screen._room_box.visible and screen._lobby_title.text == "MATCH FOUND", "the match opens the normal room lobby")
	check(not screen._code_panel.visible and not screen._share_label.visible, "a matched room does not ask to share a code")
	sockets[0].push(room_view("MATCH1", 3).merged({"type": "room_state", "connected": {RIVAL: true, ME: true}}, true))
	await settle()
	check(screen._rival_name.text == "CONNECTED" and not screen._ready_button.disabled, "the existing READY step is available")
	screen._ready_button.pressed.emit()
	check(sockets[0].sent.size() == 1 and JSON.parse_string(sockets[0].sent[0])["type"] == "ready", "READY uses the existing room socket")
	var polls: int = calls_to(STATUS_PATH)
	clock_ms += 5000
	await settle()
	check(calls_to(STATUS_PATH) == polls, "no status polls after the match")
	await close_screen(screen)
	sections_done += 1


func _check_screen_cancel_exit_errors() -> void:
	reset_fakes()
	queued()
	var screen: Control = await open_screen("find")
	var session: Session = screen._session
	reply({"status": "cancelled"})
	screen._cancel_search_button.pressed.emit()
	await settle()
	check(calls_to(CANCEL_PATH) == 1 and screen._left and screen._sessions_freed == 1 and not is_instance_valid(session), "CANCEL dequeues, frees the session, and returns to the hub")
	var calls: int = http_calls.size()
	clock_ms += 5000
	await settle()
	check(http_calls.size() == calls, "nothing polls after cancel")
	screen.queue_free()
	await settle()

	reset_fakes()
	queued()
	screen = await open_screen("find")
	matched("RACE77")
	http_replies.append({"ok": true, "status": 200, "data": room_view("RACE77")})
	screen._cancel_search_button.pressed.emit()
	await settle()
	check(not screen._left and screen._session != null and screen._session.room_code == "RACE77" and screen._room_box.visible, "cancel answered with matched continues into the room lobby")
	check(screen._cancel_search_button.text == "CANCEL" and online_sessions(screen) == 1, "the race leaves one session and a reset search panel")
	await close_screen(screen)

	reset_fakes()
	queued()
	screen = await open_screen("find")
	session = screen._session
	screen.on_exit()
	check(calls_to(CANCEL_PATH) == 1 and screen._session == null and session.is_queued_for_deletion(), "screen exit cancels the search and frees the session")
	clock_ms += 5000
	await settle()
	check(calls_to(STATUS_PATH) == 0, "nothing polls after screen exit")
	screen.queue_free()
	await settle()

	reset_fakes()
	queued()
	screen = await open_screen("find")
	reply({"status": "cancelled"})
	check(screen.consume_back(), "back is handled while searching")
	await settle()
	check(calls_to(CANCEL_PATH) == 1 and screen._left, "back while searching cancels and leaves")
	screen.queue_free()
	await settle()

	for case: Array in [
		[{"ok": false, "status": 0, "data": {}}, "Could not reach the LevelBlue server."],
		[{"ok": false, "status": 409, "data": {"code": "already_in_match"}}, "You are already in a match. Finish or leave it first."],
		[{"ok": false, "status": 401, "data": {}}, "Your sign-in expired. Please sign in again."],
	]:
		reset_fakes()
		http_replies.append(case[0] as Dictionary)
		screen = await open_screen("find")
		check(screen._lobby_error.visible and screen._lobby_error.text == str(case[1]), "join failure shows: %s" % str(case[1]))
		check(screen._retry_button.visible and screen._leave_room_button.visible and screen._leave_room_button.text == "BACK" and not screen._search_box.visible, "a failed search offers TRY AGAIN and BACK")
		queued()
		screen._retry_button.pressed.emit()
		await settle()
		check(calls_to(JOIN_PATH) == 2 and screen._session.state == Session.State.SEARCHING and factory_calls == 1, "TRY AGAIN re-queues with the same session")
		await close_screen(screen)

	reset_fakes()
	queued()
	screen = await open_screen("find")
	reply({"status": "idle"})
	clock_ms += Session.MATCHMAKING_POLL_MS
	await settle()
	check(screen._session.state == Session.State.ERROR and screen._lobby_error.text == "The search stopped. Try again." and screen._retry_button.visible, "an unexpected idle status ends the search with a retry")
	var after: int = calls_to(STATUS_PATH)
	clock_ms += 5000
	await settle()
	check(calls_to(STATUS_PATH) == after, "no polling after idle")
	screen._leave_room_button.pressed.emit()
	await settle()
	check(screen._left and screen._sessions_freed == 1, "BACK after a failed search leaves cleanly")
	screen.queue_free()
	await settle()
	sections_done += 1


func _check_hub_private_and_bot() -> void:
	var hub: Control = (load("res://src/ui/screens/dashboard/dashboard_pvp_hub.gd") as GDScript).new() as Control
	root.add_child(hub)
	await settle()
	check(str(hub.get("_find").text) == "FIND OPPONENT", "the hub offers FIND OPPONENT")
	var fired: Array[String] = []
	hub.connect("find_opponent_requested", func() -> void: fired.append("find"))
	hub.connect("battle_requested", func() -> void: fired.append("bot"))
	hub.connect("create_room_requested", func() -> void: fired.append("create"))
	hub.connect("join_room_requested", func() -> void: fired.append("join"))
	for key: String in ["_find", "_queue", "_create", "_join"]:
		(hub.get(key) as Button).pressed.emit()
	check(fired == ["find", "bot", "create", "join"], "each hub button raises only its own request")
	hub.queue_free()
	var dashboard: String = FileAccess.get_file_as_string("res://src/ui/screens/dashboard/dashboard_screen.gd")
	check(dashboard.contains("Router.push(&\"pvp_online\", {\"action\": \"find\"})"), "FIND OPPONENT opens the online screen in find mode")
	check(dashboard.contains("Router.push(&\"pvp_online\", {\"action\": \"create\"})") and dashboard.contains("Router.push(&\"pvp_online\", {\"action\": \"join\"})"), "CREATE ROOM and JOIN ROOM routes are unchanged")

	reset_fakes()
	http_replies.append({"ok": true, "status": 201, "data": room_view("PRIV01").merged({"host_id": ME, "guest_id": null, "origin": "private"}, true)})
	var screen: Control = await open_screen("create")
	check(str(http_calls[0]["path"]) == "/api/pvp/rooms" and calls_to(JOIN_PATH) == 0, "CREATE ROOM still creates a private room without queueing")
	check(screen._lobby_title.text == "PRIVATE ROOM" and screen._code_panel.visible and screen._share_label.visible and not screen._search_box.visible, "the private lobby still shares its code")
	await close_screen(screen)
	reset_fakes()
	screen = await open_screen("join")
	check(screen._entry.visible and http_calls.is_empty() and not screen._search_box.visible, "JOIN ROOM still asks for a code first")
	await close_screen(screen)

	var bot: Control = (load(BOT_SCENE) as PackedScene).instantiate() as Control
	root.add_child(bot)
	await settle()
	check(bot.get("_battle") != null and bot.find_child("OnlineSession", true, false) == null, "bot mode still runs the local duel with no online session")
	bot.on_exit()
	bot.queue_free()
	await settle()
	var source: String = FileAccess.get_file_as_string("res://src/network/pvp_online_session.gd")
	for banned: String in ["update_mastery", "mastery_matrix", "pvp_tokens", "mmr", "elo_rating"]:
		check(not source.contains(banned), "the session never references %s" % banned)
	sections_done += 1
