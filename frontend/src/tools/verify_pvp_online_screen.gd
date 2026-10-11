extends SceneTree
## Online PvP screen (lobby -> battle -> result) against a fake session transport. No backend.
## Screens reference autoloads, so they are loaded at runtime rather than preloaded by this entry script.
const Session = preload("res://src/network/pvp_online_session.gd")
const MODE_BOT: int = 0
const MODE_ONLINE: int = 1
const SECTIONS: int = 10
const ONLINE_SCENE: String = "res://src/ui/screens/pvp/pvp_online_screen.tscn"
const BOT_SCENE: String = "res://src/ui/screens/pvp/pvp_battle_screen.tscn"
const HOST_ID: String = "stu-host"
const GUEST_ID: String = "stu-guest"
const OPTIONS: Array[String] = ["A trick", "Antivirus", "Charger", "Wi-Fi"]

var failures: int = 0
var clock_ms: int = 1000
var http_calls: Array[Dictionary] = []
var http_replies: Array[Dictionary] = []
var sockets: Array[FakeSocket] = []
var factory_calls: int = 0
var sections_done: int = 0


class FakeSocket extends "res://src/network/pvp_online_session.gd".SocketTransport:
	var url: String = ""
	var headers: PackedStringArray = PackedStringArray()
	var state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
	var code: int = -1
	var inbound: Array[String] = []
	var sent: Array[String] = []

	func open(target: String, handshake: PackedStringArray) -> Error:
		url = target
		headers = handshake
		state = WebSocketPeer.STATE_OPEN
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
		code = close_with
		state = WebSocketPeer.STATE_CLOSED

	func push(message: Dictionary) -> void:
		inbound.append(JSON.stringify(message))

	func drop(close_with: int) -> void:
		code = close_with
		state = WebSocketPeer.STATE_CLOSED

	func sent_of(kind: String) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for text: String in sent:
			var message: Dictionary = JSON.parse_string(text) as Dictionary
			if str(message.get("type", "")) == kind:
				out.append(message)
		return out


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
	if http_replies.is_empty():
		return {"ok": false, "status": 0, "data": {}}
	return http_replies.pop_front()


func make_socket() -> Session.SocketTransport:
	var socket: FakeSocket = FakeSocket.new()
	sockets.append(socket)
	return socket


func now() -> int:
	return clock_ms


func new_session(user_id: String) -> Session:
	factory_calls += 1
	var session: Session = Session.new()
	session.http_transport = fake_http
	session.socket_factory = make_socket
	session.now_provider = now
	session.token_provider = func() -> String: return jwt(user_id)
	session.api_base = "https://api.levelblue.test"
	return session


func reset_fakes() -> void:
	clock_ms = 1000
	http_calls.clear()
	http_replies.clear()
	sockets.clear()
	factory_calls = 0


func view(server_state: String, revision: int, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"code": "ABC234",
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


func round_payload(number: int, question: String = "What is phishing?") -> Dictionary:
	return {
		"round": number,
		"question_id": "pvp_easy_%02d" % number,
		"question": question,
		"options": OPTIONS.duplicate(),
		"started_at": 60000,
		"ends_at": 70000,
	}


func round_event(revision: int, number: int, question: String = "What is phishing?") -> Dictionary:
	var event: Dictionary = round_payload(number, question)
	event.merge({"type": "round_started", "revision": revision, "code": "ABC234", "server_now": 60000}, true)
	return event


func event(kind: String, revision: int, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"type": kind, "revision": revision, "code": "ABC234", "server_now": 60000}
	out.merge(extra, true)
	return out


func pump(screen: Control) -> void:
	if screen._session != null:
		screen._session.poll()
	screen._process(0.0)


func open_screen(user_id: String, action: String) -> Control:
	root.size = Vector2i(1280, 720)
	var screen: Control = (load(ONLINE_SCENE) as PackedScene).instantiate() as Control
	screen.session_factory = new_session.bind(user_id)
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.on_enter({"action": action})
	await settle()
	return screen


## Host screen that created ABC234, has a guest, and is on round 1.
func active_screen() -> Control:
	reset_fakes()
	http_replies.append({"ok": true, "status": 201, "data": view("waiting", 0, {"guest_id": null, "hp": {HOST_ID: 100}})})
	var screen: Control = await open_screen(HOST_ID, "create")
	var socket: FakeSocket = sockets.back()
	socket.push(view("waiting", 1, {"type": "room_state"}))
	socket.push(event("countdown_started", 2, {"round": 1, "countdown_ends_at": 63000}))
	socket.push(round_event(3, 1))
	pump(screen)
	return screen


func close_screen(screen: Control) -> void:
	screen.on_exit()
	screen.queue_free()
	await settle()


func same_ints(message: Dictionary, expected: Dictionary) -> bool:
	if message.keys().size() != expected.keys().size():
		return false
	for key: Variant in expected:
		if not message.has(key):
			return false
		var want: Variant = expected[key]
		if typeof(want) == TYPE_INT:
			if int(message[key]) != int(want):
				return false
		elif str(message[key]) != str(want):
			return false
	return true


func button_texts(screen: Control) -> Array[String]:
	var out: Array[String] = []
	for button: Button in screen._answer_buttons:
		out.append(button.text)
	return out


func all_disabled(screen: Control) -> bool:
	if screen._answer_buttons.is_empty():
		return false
	for button: Button in screen._answer_buttons:
		if not button.disabled:
			return false
	return true


func _run() -> void:
	var player: Node = root.get_node("PlayerManager")
	var mastery_before: String = JSON.stringify(player.mastery_matrix)
	var tokens_before: int = int(player.pvp_tokens)
	await _check_hub_and_routes()
	await _check_bot_mode_unchanged()
	await _check_create_flow()
	await _check_join_flow()
	await _check_answer_flow()
	await _check_correct_and_timeout()
	await _check_reconnect_restores()
	await _check_opponent_disconnect()
	await _check_match_finished()
	await _check_leave_cleanup()
	_check_source_guards()
	check(JSON.stringify(player.mastery_matrix) == mastery_before, "online PvP never touches mastery")
	check(int(player.pvp_tokens) == tokens_before, "online PvP never pays tokens")
	check(sections_done == SECTIONS, "every screen section ran to completion (%d/%d)" % [sections_done, SECTIONS])
	print("[PVP ONLINE SCREEN] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _check_hub_and_routes() -> void:
	var hub: Control = (load("res://src/ui/screens/dashboard/dashboard_pvp_hub.gd") as GDScript).new() as Control
	root.add_child(hub)
	await settle()
	check(str(hub.get("_queue").text) == "CHALLENGE BOT", "the hub keeps CHALLENGE BOT")
	check(str(hub.get("_create").text) == "CREATE ROOM" and str(hub.get("_join").text) == "JOIN ROOM", "the hub offers CREATE ROOM and JOIN ROOM")
	var fired: Array[String] = []
	hub.connect("battle_requested", func() -> void: fired.append("bot"))
	hub.connect("create_room_requested", func() -> void: fired.append("create"))
	hub.connect("join_room_requested", func() -> void: fired.append("join"))
	(hub.get("_queue") as Button).pressed.emit()
	(hub.get("_create") as Button).pressed.emit()
	(hub.get("_join") as Button).pressed.emit()
	check(fired == ["bot", "create", "join"], "each hub button raises only its own request")
	hub.queue_free()
	var screens: Dictionary = (load("res://src/autoload/screen_router.gd") as GDScript).get_script_constant_map()["SCREENS"]
	check(str(screens.get(&"pvp_online", "")) == ONLINE_SCENE and str(screens.get(&"pvp_battle", "")) == BOT_SCENE, "the router keeps the bot screen and registers the online screen")
	var dashboard: String = FileAccess.get_file_as_string("res://src/ui/screens/dashboard/dashboard_screen.gd")
	check(dashboard.contains("Router.push(&\"pvp_battle\")"), "CHALLENGE BOT still opens the local bot duel")
	check(dashboard.contains("Router.push(&\"pvp_online\", {\"action\": \"create\"})") and dashboard.contains("Router.push(&\"pvp_online\", {\"action\": \"join\"})"), "online buttons open the online screen with their action")
	await settle()
	sections_done += 1


func _check_bot_mode_unchanged() -> void:
	root.size = Vector2i(1280, 720)
	var bot: Control = (load(BOT_SCENE) as PackedScene).instantiate() as Control
	root.add_child(bot)
	await settle()
	check(int(bot.call("battle_mode")) == MODE_BOT, "the bot screen runs in BOT mode")
	check(bot.get("_battle") != null, "BOT mode still runs the local PvpBattle")
	check(bot.find_child("OnlineSession", true, false) == null, "BOT mode never creates an online session")
	bot.on_exit()
	bot.queue_free()
	await settle()
	sections_done += 1


func _check_create_flow() -> void:
	reset_fakes()
	http_replies.append({"ok": true, "status": 201, "data": view("waiting", 0, {"code": "abc234", "guest_id": null, "hp": {HOST_ID: 100}})})
	var screen: Control = await open_screen(HOST_ID, "create")
	var session: Session = screen._session
	check(int(screen.call("battle_mode")) == MODE_ONLINE, "the online screen runs in ONLINE mode")
	check(factory_calls == 1 and screen._sessions_created == 1, "Create Room creates exactly one session")
	check(session != null and session.get_parent() == screen, "the screen owns the session as its child")
	check(http_calls.size() == 1 and str(http_calls[0]["path"]) == "/api/pvp/rooms", "Create Room posts once to /api/pvp/rooms")
	check(screen._lobby_host.visible and screen._room_box.visible and not screen._entry.visible, "Create Room shows the lobby, not the code entry")
	check(screen._code_label.text == "ABC234" and screen._share_label.text.contains("ABC234"), "the lobby shows a share-friendly room code")
	check(not screen._hud.visible and not screen._arena.visible, "the battle stays hidden in the lobby")
	var socket: FakeSocket = sockets[0]
	socket.push(view("waiting", 1, {"type": "room_state", "guest_id": null, "hp": {HOST_ID: 100}}))
	pump(screen)
	check(screen._opponent_label.text.begins_with("Waiting for an opponent"), "the lobby waits for an opponent")
	socket.push(view("waiting", 2, {"type": "room_state"}))
	pump(screen)
	check(screen._opponent_label.text.contains("CONNECTED") and screen._opponent_label.text.contains("NOT READY"), "the lobby shows the opponent connection and ready state")
	screen._ready_button.pressed.emit()
	screen._ready_button.pressed.emit()
	check(socket.sent_of("ready").size() == 1 and same_ints(socket.sent_of("ready")[0], {"type": "ready"}), "READY sends one ready message")
	check(screen._ready_button.disabled, "READY locks after sending")
	socket.push(view("waiting", 3, {"type": "room_state", "ready": {HOST_ID: true, GUEST_ID: true}}))
	pump(screen)
	check(screen._lobby_host.visible and screen._ready_label.text == "YOU: READY" and screen._opponent_label.text.contains("READY"), "both ready flags come from the server")
	check(session.state == Session.State.WAITING and not screen._countdown.visible, "the battle does not start until the server countdown")
	socket.push(event("countdown_started", 4, {"round": 1, "countdown_ends_at": 63000}))
	pump(screen)
	check(not screen._lobby_host.visible and screen._countdown.visible and screen._hud.visible, "the server countdown opens the battle")
	check(screen._status.text == "GET READY" and screen._round_label.text == "ROUND 1", "the countdown shows the server round")
	check(screen._countdown_value.text == "3", "the countdown digit uses the server deadline")
	socket.push(round_event(5, 1))
	pump(screen)
	check(screen._session == session and screen._sessions_created == 1 and factory_calls == 1, "the same session survives lobby -> countdown -> round")
	check(screen.get("_battle") == null, "ONLINE mode never creates a local PvpBattle")
	await close_screen(screen)
	sections_done += 1


func _check_join_flow() -> void:
	reset_fakes()
	var screen: Control = await open_screen(GUEST_ID, "join")
	check(screen._entry.visible and not screen._room_box.visible and http_calls.is_empty(), "Join Room asks for a code before any request")
	screen._code_input.text = "   "
	screen._join_button.pressed.emit()
	check(http_calls.is_empty() and screen._lobby_error.text.begins_with("Enter the room code"), "an empty code is rejected locally")
	http_replies.append({"ok": false, "status": 404, "data": {"error": "Room not found", "code": "room_not_found"}})
	screen._code_input.text = "  zz9 99 "
	screen._join_button.pressed.emit()
	await settle()
	check(http_calls.size() == 1 and str(http_calls[0]["path"]) == "/api/pvp/rooms/ZZ999/join", "the entered code is trimmed and upper-cased")
	check(screen._lobby_error.text == "No room uses that code.", "a missing room shows a useful server error")
	check(screen._entry.visible and not screen._join_button.disabled and sockets.is_empty(), "a failed join stays on the code entry")
	http_replies.append({"ok": true, "status": 200, "data": view("waiting", 2)})
	screen._code_input.text = " abc234"
	screen._join_button.pressed.emit()
	await settle()
	check(str(http_calls[1]["path"]) == "/api/pvp/rooms/ABC234/join" and (http_calls[1]["body"] as Dictionary).is_empty(), "Join Room uses the entered code with no player id")
	check(sockets.size() == 1 and sockets[0].url.ends_with("/api/pvp/rooms/ABC234/ws"), "Join Room connects to the joined room")
	check(not screen._entry.visible and screen._room_box.visible and screen._code_label.text == "ABC234", "a joined room shows the lobby")
	check(screen._opponent_label.text.contains("CONNECTED") and factory_calls == 1, "the guest sees the host and still has one session")
	await close_screen(screen)
	sections_done += 1


func _check_answer_flow() -> void:
	var screen: Control = await active_screen()
	var socket: FakeSocket = sockets.back()
	check(screen._quiz.visible and screen._status.text == "CHOOSE AN ANSWER", "round_started opens the question")
	var prompt: Label = screen._body.get_child(0) as Label
	check(prompt != null and prompt.text == "What is phishing?", "the question text comes from round_started")
	check(button_texts(screen) == OPTIONS, "options come from the server in server order")
	check(not all_disabled(screen), "answers unlock when the round starts")
	check(screen._timer.text == "10.0s", "the timer shows the server deadline")
	screen._answer_buttons[2].pressed.emit()
	screen._answer_buttons[1].pressed.emit()
	var answers: Array[Dictionary] = socket.sent_of("answer")
	check(answers.size() == 1, "a second click after the local lock sends nothing")
	check(answers.size() == 1 and same_ints(answers[0], {"type": "answer", "round": 1, "option_index": 2}), "an answer sends only type, round, and option_index")
	check(all_disabled(screen), "answer buttons lock after one submission")
	check(screen._session.my_hp() == 100 and screen._player_hp.text == "100" and screen._bot_hp.text == "100", "submitting never changes HP locally")
	socket.push(event("answer_locked", 4, {"round": 1, "option_index": 2, "correct": false}))
	pump(screen)
	check(screen._status.text == "INCORRECT — WAITING FOR RIVAL", "a wrong answer shows the waiting state")
	check(screen._session.state == Session.State.ACTIVE and screen._quiz.visible and not screen._result_host.visible, "a wrong answer does not end the round")
	check(all_disabled(screen), "a wrong answer keeps only the local buttons locked")
	socket.push(event("round_result", 5, {"round": 1, "winner_id": GUEST_ID, "reason": "correct", "damage": {HOST_ID: 25}, "hp": {HOST_ID: 75, GUEST_ID: 100}, "correct_option": 0, "result_ends_at": 64000}))
	pump(screen)
	check(screen._result_host.visible and screen._result_title.text == "RIVAL ANSWERED FIRST", "the round result comes from the server")
	check(screen._result_note.text == "Answer: A trick", "the revealed answer comes from the server result")
	check(screen._player_hp.text == "75" and screen._player_bar.value == 75 and screen._bot_hp.text == "100", "HP changes only from the server result")
	await close_screen(screen)
	sections_done += 1


func _check_correct_and_timeout() -> void:
	var screen: Control = await active_screen()
	var socket: FakeSocket = sockets.back()
	screen._answer_buttons[0].pressed.emit()
	socket.push(event("answer_locked", 4, {"round": 1, "option_index": 0, "correct": true}))
	pump(screen)
	check(screen._bot_hp.text == "100", "a correct lock alone deals no damage")
	socket.push(event("round_result", 5, {"round": 1, "winner_id": HOST_ID, "reason": "correct", "damage": {GUEST_ID: 25}, "hp": {HOST_ID: 100, GUEST_ID: 75}, "correct_option": 0}))
	pump(screen)
	check(screen._result_title.text == "CORRECT — ATTACK!" and screen._bot_hp.text == "75", "the server decides who answered first and the damage")
	check(screen._fx_round == 1, "the result animation plays once for the resolved round")
	socket.push(event("countdown_started", 6, {"round": 2, "countdown_ends_at": 66500}))
	socket.push(round_event(7, 2, "Which link is safe?"))
	pump(screen)
	check((screen._body.get_child(0) as Label).text == "Which link is safe?" and not all_disabled(screen), "the next round renders fresh, unlocked answers")
	check(screen._round_label.text == "ROUND 2", "the round label follows the server")
	socket.push(event("round_result", 8, {"round": 2, "winner_id": null, "reason": "timeout", "damage": {}, "hp": {HOST_ID: 100, GUEST_ID: 75}, "correct_option": 1}))
	pump(screen)
	check(screen._result_title.text == "TIME UP — NO DAMAGE" and screen._player_hp.text == "100" and screen._bot_hp.text == "75", "a timeout shows no damage")
	check(screen._session.state == Session.State.ROUND_RESULT and not screen._end_host.visible, "a timeout does not end the match")
	await close_screen(screen)
	sections_done += 1


func _check_reconnect_restores() -> void:
	var screen: Control = await active_screen()
	var socket: FakeSocket = sockets.back()
	screen._answer_buttons[1].pressed.emit()
	socket.drop(1006)
	pump(screen)
	check(screen._session.state == Session.State.RECONNECTING, "a dropped socket starts reconnecting")
	check(screen._banner.visible and screen._banner.text.contains("RECONNECTING"), "the screen shows the reconnecting status")
	check(screen._quiz.visible and not screen._lobby_host.visible, "the player stays on the online battle while reconnecting")
	clock_ms += 600
	pump(screen)
	check(sockets.size() == 2 and sockets[1].url == socket.url, "reconnect reuses the same room")
	check(sockets[1].headers == socket.headers, "reconnect reuses the same JWT")
	var fx_before: int = screen._fx_round
	sockets[1].push(view("active", 12, {"type": "room_state", "round_number": 2, "round": round_payload(2, "Restored question?"), "you_answered": true, "hp": {HOST_ID: 50, GUEST_ID: 75}}))
	pump(screen)
	check(screen._session.state == Session.State.ACTIVE and not screen._banner.visible, "recovered room_state clears the reconnect status")
	check((screen._body.get_child(0) as Label).text == "Restored question?" and button_texts(screen) == OPTIONS, "the recovered round comes from the server")
	check(all_disabled(screen) and screen._status.text == "ANSWER LOCKED — WAITING", "a recovered answered round stays locked")
	check(screen._player_hp.text == "50" and screen._bot_hp.text == "75" and screen._round_label.text == "ROUND 2", "HP and round are restored from the server")
	check(screen._fx_round == fx_before and not screen._result_host.visible, "recovery does not replay result animations")
	check(screen._sessions_created == 1 and factory_calls == 1, "reconnecting keeps the same session")
	await close_screen(screen)
	sections_done += 1


func _check_opponent_disconnect() -> void:
	var screen: Control = await active_screen()
	var socket: FakeSocket = sockets.back()
	socket.push(event("opponent_disconnected", 4, {"user_id": GUEST_ID, "grace_ends_at": 75000}))
	pump(screen)
	check(screen._banner.visible and screen._banner.text.begins_with("RIVAL DISCONNECTED"), "an opponent drop shows the grace status")
	check(screen._banner.text.contains("15s"), "the grace countdown uses the server deadline")
	check(screen._session.state == Session.State.ACTIVE and screen._quiz.visible and not screen._end_host.visible, "an opponent drop does not end the match locally")
	socket.push(event("opponent_connected", 5, {"user_id": GUEST_ID}))
	pump(screen)
	check(not screen._banner.visible, "the opponent returning clears the warning")
	await close_screen(screen)
	sections_done += 1


func _check_match_finished() -> void:
	var screen: Control = await active_screen()
	var socket: FakeSocket = sockets.back()
	socket.push(event("match_finished", 4, {"state": "abandoned", "reason": "forfeit", "winner_id": HOST_ID, "retired_by": GUEST_ID, "hp": {HOST_ID: 100, GUEST_ID: 100}}))
	pump(screen)
	check(screen._end_host.visible and not screen._quiz.visible, "match_finished ends the battle UI")
	check(screen._end_title.text == "VICTORY" and screen._end_rounds.text == "RIVAL FORFEITED — CONNECTION LOST", "the forfeit result comes from the server")
	var rematch: Control = screen._footer.get_node("RematchButton") as Control
	var leave: Control = screen._footer.get_node("LeaveButton") as Control
	check(not rematch.visible and leave.visible, "the online result offers leave, not a local rematch")
	socket.drop(1000)
	clock_ms += 5000
	pump(screen)
	check(sockets.size() == 1 and screen._session.state == Session.State.FINISHED and not screen._banner.visible, "a finished match never reconnects")
	await close_screen(screen)
	screen = await active_screen()
	socket = sockets.back()
	socket.push(event("round_result", 4, {"round": 1, "winner_id": GUEST_ID, "reason": "correct", "damage": {HOST_ID: 25}, "hp": {HOST_ID: 0, GUEST_ID: 100}, "correct_option": 0}))
	socket.push(event("match_finished", 5, {"state": "finished", "reason": "ko", "winner_id": GUEST_ID, "retired_by": null, "hp": {HOST_ID: 0, GUEST_ID: 100}}))
	pump(screen)
	check(screen._end_title.text == "DEFEAT" and screen._end_rounds.text == "KNOCKOUT" and screen._end_you_hp.text == "YOU  0", "a knockout defeat is shown from server HP")
	await close_screen(screen)
	sections_done += 1


func _check_leave_cleanup() -> void:
	reset_fakes()
	http_replies.append({"ok": true, "status": 201, "data": view("waiting", 0, {"guest_id": null, "hp": {HOST_ID: 100}})})
	var screen: Control = await open_screen(HOST_ID, "create")
	var session: Session = screen._session
	var socket: FakeSocket = sockets.back()
	pump(screen)
	screen._leave_room_button.pressed.emit()
	check(socket.sent_of("leave").size() == 1, "LEAVE ROOM sends leave")
	check(screen._leaving and screen._session == session, "the session stays alive until the server closes the socket")
	socket.drop(1000)
	pump(screen)
	check(screen._session == null and screen._left, "leaving frees the session")
	check(session.is_queued_for_deletion() and session.get_parent() == null, "the session is detached and queued for deletion")
	await settle()
	check(not is_instance_valid(session), "the session is freed")
	clock_ms += 20000
	screen._process(0.0)
	check(sockets.size() == 1, "leaving never reconnects")
	screen.queue_free()
	await settle()
	screen = await active_screen()
	session = screen._session
	socket = sockets.back()
	check(screen.consume_back() and screen._abandon.visible, "back during a live match asks before forfeiting")
	(screen.find_child("AbandonLeaveButton", true, false) as Button).pressed.emit()
	check(socket.sent_of("leave").size() == 1 and not screen._abandon.visible, "confirming leave sends leave once")
	clock_ms += 2100
	pump(screen)
	check(screen._session == null and session.is_queued_for_deletion(), "the leave fallback frees the session if the server never closes")
	clock_ms += 20000
	screen._process(0.0)
	check(sockets.size() == 1, "an intentional leave stops reconnect attempts")
	screen.queue_free()
	await settle()
	screen = await active_screen()
	session = screen._session
	socket = sockets.back()
	screen.on_exit()
	check(socket.sent_of("leave").size() == 1 and screen._session == null and session.is_queued_for_deletion(), "a forced exit still sends leave and frees the session")
	screen.queue_free()
	await settle()
	sections_done += 1


func _check_source_guards() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/ui/screens/pvp/pvp_online_screen.gd")
	for banned: String in ["Quiz.", "grade(", "answer_index", "update_mastery", "pvp_tokens", "_battle", "Battle.", "submit_player", "damage_to", "_bank"]:
		check(not source.contains(banned), "ONLINE mode source never uses %s" % banned)
	check(source.contains("submit_answer(index)"), "ONLINE answers go only through PvpOnlineSession.submit_answer")
