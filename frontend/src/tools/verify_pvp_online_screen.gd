extends SceneTree
## Online PvP screen (lobby -> battle -> result) against a fake session transport. No backend.
## Screens reference autoloads, so they are loaded at runtime rather than preloaded by this entry script.
const Session = preload("res://src/network/pvp_online_session.gd")
const MODE_BOT: int = 0
const MODE_ONLINE: int = 1
const SECTIONS: int = 6
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


func capture(filename: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")


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
		"supports_flag": true,
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
	await _check_flag_screen()
	await _check_rating_presentation()
	await _check_leave_cleanup()
	await _check_leave_while_router_busy()
	_check_source_guards()
	check(JSON.stringify(player.mastery_matrix) == mastery_before, "online PvP never touches mastery")
	check(int(player.pvp_tokens) == tokens_before, "online PvP never pays tokens")
	check(sections_done == SECTIONS, "every screen section ran to completion (%d/%d)" % [sections_done, SECTIONS])
	# Router transitions deliberately play audio. Let the audio server release
	# playback handles before ending this short-lived test process.
	var audio: Node = root.get_node("AudioManager")
	audio._kill_bgm_tween()
	audio._stop_music()
	audio._stop_effects()
	await create_timer(0.1).timeout
	print("[PVP ONLINE SCREEN] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _check_hub_and_routes() -> void:
	var hub: Control = (load("res://src/ui/screens/dashboard/dashboard_pvp_hub.gd") as GDScript).new() as Control
	root.add_child(hub)
	await settle()
	check(str(hub.get("_queue").text) == "PRACTICE VS BOT", "the hub offers bot practice")
	check(str(hub.get("_create").text) == "CREATE ROOM" and str(hub.get("_join").text) == "JOIN A ROOM", "the hub offers create and join commands")
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
	check(bot.get("_practice_panel") != null and bot.get("_practice") == null, "BOT mode opens local CTF Home before starting")
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
	check(screen._flag_screen == null, "the battle stays hidden in the lobby")
	var socket: FakeSocket = sockets[0]
	socket.push(view("waiting", 1, {"type": "room_state", "guest_id": null, "hp": {HOST_ID: 100}}))
	pump(screen)
	check(screen._opponent_label.text.begins_with("Waiting for an opponent"), "the lobby waits for an opponent")
	socket.push(view("waiting", 2, {"type": "room_state"}))
	pump(screen)
	check(screen._rival_name.text == "CONNECTED" and screen._opponent_label.text == "NOT READY", "the lobby shows the opponent connection and ready state")
	await capture("pvp_lobby_1280x720")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(720, 360), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		var lobby: Rect2 = screen._lobby_host.get_global_rect()
		for control: Control in [screen._code_label, screen._copy_button, screen._ready_button, screen._you_card, screen._rival_card]:
			check(lobby.grow(1.0).encloses(control.get_global_rect()), "%s fits the lobby without scrolling at %s" % [control.name, dimensions])
			check(root.get_visible_rect().size.x >= control.get_global_rect().end.x, "%s stays on screen horizontally at %s" % [control.name, dimensions])
		check(screen._copy_button.autowrap_mode == TextServer.AUTOWRAP_OFF and screen._ready_button.autowrap_mode == TextServer.AUTOWRAP_OFF, "lobby buttons never wrap")
	await capture("pvp_lobby_844x390")
	root.size = Vector2i(1280, 720)
	await settle()
	screen._ready_button.pressed.emit()
	screen._ready_button.pressed.emit()
	check(socket.sent_of("ready").size() == 1 and socket.sent_of("ready")[0].get("mode") == "event_flag_v1", "READY sends one ready message")
	check(screen._ready_button.disabled, "READY locks after sending")
	socket.push(view("waiting", 3, {"type": "room_state", "ready": {HOST_ID: true, GUEST_ID: true}}))
	pump(screen)
	check(screen._lobby_host.visible and screen._ready_label.text == "READY" and screen._opponent_label.text == "READY", "both ready flags come from the server")
	check(session.state == Session.State.WAITING and screen._flag_screen == null, "Ready waits for countdown")
	socket.push(view("abandoned",4,{"type":"room_state","retired_by":GUEST_ID,"finish_reason":"retired"}))
	pump(screen)
	check(screen._flag_screen._files_caption.text.contains("ROOM CLOSED"), "Room closed before play gets neutral CRT report")
	await close_screen(screen)
	sections_done += 1


func _check_join_flow() -> void:
	reset_fakes()
	var screen: Control = await open_screen(GUEST_ID, "join")
	check(screen._entry.visible and not screen._room_box.visible and http_calls.is_empty(), "Join Room asks for a code before any request")
	root.size = Vector2i(720,360)
	await settle()
	await capture("pvp_terminal_join_720")
	screen._code_input.text = "   "
	screen._join_button.pressed.emit()
	check(http_calls.is_empty() and screen._lobby_error.is_visible_in_tree() and screen._lobby_error.text.begins_with("Enter the room code"), "an empty code gets visible local feedback")
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
	check(screen._rival_name.text == "CONNECTED" and factory_calls == 1, "the guest sees the host and still has one session")
	await close_screen(screen)
	sections_done += 1


func _check_rating_presentation() -> void:
	var screen: Control = await active_screen()
	var socket: FakeSocket = sockets.back()
	socket.push(event("round_result", 4, {"round": 1, "winner_id": HOST_ID, "damage": {GUEST_ID: 20}, "hp": {HOST_ID: 100, GUEST_ID: 80}, "charge": {HOST_ID: 3, GUEST_ID: 0}}))
	pump(screen)
	socket.push(event("match_finished", 5, {"winner_id": HOST_ID, "origin": "private", "match_id": "fixture", "reason": "ko", "stats": {HOST_ID: {"correct": 5}, GUEST_ID: {"correct": 2}}}))
	pump(screen)
	check(screen._rating_line.contains("NO RATING CHANGE") and screen._rating_http == null, "private matches never fetch or invent rewards")
	var auth: Node = root.get_node("AuthService")
	var original: String = str(auth.get("_token"))
	auth.set("_token", jwt(HOST_ID))
	screen._rating_match = "fixture"
	screen._rating_owner = HOST_ID
	screen._rating_attempts = 5
	screen._rating_line = "RATING UPDATE PENDING"
	screen._rating_received(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), "{}".to_utf8_buffer())
	check(not screen._rating_applied and screen._rating_line == "RATING UPDATE PENDING", "outage does not invent a points change")
	var record: Dictionary = {"status": "applied", "match_id": "fixture", "points_before": 1190, "points_after": 1206, "points_delta": 16, "rank_before": "Silver", "rank_after": "Gold", "current_threshold": 1200, "next_threshold": 1600}
	var malformed: Dictionary = record.duplicate()
	malformed["points_delta"] = 99
	check(not screen._valid_rating(malformed), "inconsistent ledger is rejected")
	var settings: Node = root.get_node("SettingsService")
	var prior: bool = bool(settings.get("reduced_motion"))
	settings.set("reduced_motion", false)
	screen._rating_received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(record).to_utf8_buffer())
	var animation: Tween = screen._reward_tween
	screen._rating_received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(record).to_utf8_buffer())
	check(screen._reward_tween == animation, "duplicate confirmation does not restart reward animation")
	await create_timer(1.4).timeout
	check(screen._rating_line == "1206 PVP POINTS" and screen._rating_detail.begins_with("RANK UP"), "animation settles at confirmed rating and rank")
	auth.set("_token", jwt(GUEST_ID))
	record["points_after"] = 1220
	record["points_delta"] = 30
	screen._rating_received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(record).to_utf8_buffer())
	check(screen._rating_line == "1206 PVP POINTS", "account-switched response is ignored")
	auth.set("_token", original)
	settings.set("reduced_motion", prior)
	await close_screen(screen)


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


func _check_leave_while_router_busy() -> void:
	reset_fakes()
	http_replies.append({"ok": true, "status": 201, "data": view("waiting", 0, {"guest_id": null, "hp": {HOST_ID: 100}})})
	var router: Node = root.get_node("Router")
	var stack: Array = router.get("_stack") as Array
	var saved_stack: Array = stack.duplicate()
	var saved_host: Variant = router.get("_host")
	var host: Control = Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var below: Control = (load("res://src/ui/base_screen.gd") as GDScript).new() as Control
	host.add_child(below)
	var screen: Control = (load(ONLINE_SCENE) as PackedScene).instantiate() as Control
	screen.session_factory = new_session.bind(HOST_ID)
	host.add_child(screen)
	screen.on_enter({"action": "create"})
	await settle()
	router.set("_host", host)
	stack.clear()
	stack.append(below)
	stack.append(screen)
	var session: Session = screen._session
	var socket: FakeSocket = sockets.back()
	pump(screen)
	router.set("_busy", true)
	screen._leave_room_button.pressed.emit()
	socket.drop(1000)
	pump(screen)
	check(screen._left and screen._sessions_freed == 1 and session.is_queued_for_deletion(), "leaving during a router transition still frees the session once")
	for _i: int in 10:
		await process_frame
	check(is_instance_valid(screen) and bool(router.call("is_top", screen)), "a busy router keeps the screen mounted instead of dropping the pop")
	check(screen._sessions_freed == 1, "waiting for the router never frees the session twice")
	router.set("_busy", false)
	var waited: int = Time.get_ticks_msec()
	while stack.size() > 1 and Time.get_ticks_msec() - waited < 5000:
		await process_frame
	check(stack.size() == 1 and stack.back() == below, "the screen pops once the router is free")
	check(not is_instance_valid(screen) or screen._sessions_freed == 1, "the delayed pop does not free the session again")
	stack.clear()
	stack.append_array(saved_stack)
	router.set("_host", saved_host)
	host.queue_free()
	await settle()
	sections_done += 1


func _check_source_guards() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/ui/screens/pvp/pvp_online_screen.gd")
	for banned: String in ["Quiz.", "grade(", "answer_index", "update_mastery", "pvp_tokens", "_battle", "Battle.", "submit_player", "damage_to", "_bank"]:
		check(not source.contains(banned), "ONLINE mode source never uses %s" % banned)
	check(source.contains("_session.send_flag_action(action,target)"), "Online capture commands go through the authoritative session")

func _check_flag_screen() -> void:
	reset_fakes()
	http_replies.append({"ok":true,"status":201,"data":view("waiting",0,{"supports_flag":true})})
	var screen: Control = await open_screen(HOST_ID,"create")
	check(screen._role_button.visible,"CTF role choice available in the room")
	var socket: FakeSocket = sockets[0]
	socket.push(view("waiting",1,{"type":"room_state","supports_flag":true}))
	pump(screen)
	root.size = Vector2i(720,360)
	await settle()
	await capture("flag_lobby_720")
	screen._ready_button.pressed.emit()
	check(socket.sent_of("ready")[0].get("mode") == "event_flag_v1","Ready requests the flag race")
	var data: Dictionary = {"role":"attacker","step":0,"rival_step":0,"inspected":false,"revision":0,
		"ends_at":180000,"node":"INVITATION","inspect_label":"Expand destination","summary":"Club poster pack / View event artwork","detail":"","targets":{},"feedback":""}
	socket.push(view("active",3,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	root.size = Vector2i(844,390)
	await settle()
	var terminal: Control = screen._flag_screen
	check(terminal.visible and not screen._terminal.visible,"Flag terminal replaces duel")
	check(terminal._home.visible and not terminal._files.visible and not terminal._map.visible,"Attacker begins at computer Home")
	await capture("flag_home_844")
	terminal._shortcuts[0].pressed.emit()
	check(terminal._shell.visible,"Terminal shortcut opens the command log")
	await capture("flag_terminal_844")
	terminal._shell_action.pressed.emit()
	check(terminal._files.visible and socket.sent_of("flag_action").is_empty(),"Opening Files sends no gameplay command")
	terminal._action.pressed.emit()
	var actions: Array[Dictionary] = socket.sent_of("flag_action")
	check(actions.size() == 1 and actions[0].get("action") == "inspect","Evidence inspection goes to server")
	data.merge({"inspected":true,"revision":1,"targets":{"relay-a":"RELAY-A","relay-b":"RELAY-B"},"detail":"Displayed: design.school.example\nExpanded: relay-b.example/event-pack\nTrace the delivery to the host in the expanded address."},true)
	socket.push(view("active",4,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	await settle()
	await capture("flag_attacker_844")
	terminal._rail[0].pressed.emit()
	check(terminal._home.visible and int(terminal._data.revision)==1,"Home preserves inspected evidence")
	terminal._shortcuts[2].pressed.emit()
	check(terminal._map.visible,"Netmap opens through the Home shortcut")
	await capture("flag_netmap_844")
	check(not terminal._nodes[1].get_global_rect().intersects(terminal._nodes[2].get_global_rect()),"Map route targets do not overlap after deferred layout")
	terminal._nodes[2].pressed.emit()
	terminal._action.pressed.emit()
	actions = socket.sent_of("flag_action")
	check(actions.size() == 2 and actions[1].target == "relay-b" and int(actions[1].revision)==1,"Route uses selected host and personal revision")
	root.size = Vector2i(720,360)
	data.merge({"role":"defender","step":1,"revision":5,"node":"INCIDENT RECORD","targets":{"banner.chat":"banner.chat","poster.chat":"poster.chat"},"detail":"Original: Mika asked about the handmade banner. Amani praised the banner. Case DL-817 names banner.chat as the original thread. Attach it to the incident.","feedback":"Access denied. Check the source record and delivery reference."},true)
	socket.push(view("active",5,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	terminal._nodes[1].pressed.emit()
	await settle()
	check(terminal._files.visible and not terminal._map.visible,"Small phone shows one readable application window")
	check(root.get_visible_rect().encloses(terminal._action.get_global_rect()),"Flag action fits compact screen")
	await capture("flag_defender_720")
	screen._session._give_up()
	check(terminal._mode=="lost" and not terminal._action.disabled,"Exhausted reconnect exposes a touch retry")
	terminal._action.pressed.emit()
	check(screen._session.room_code=="ABC234" and not screen._session.flag.is_empty(),"Manual retry retains room identity and evidence")
	socket=sockets.back()
	socket.push(view("active",6,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	check(terminal._mode=="active","Manual retry restores the flag interface")
	socket.push(event("match_finished",7,{"winner_id":GUEST_ID,"reason":"flag_retrieved","flag":data}))
	pump(screen)
	check(terminal._mode=="done" and "DEFEAT" in terminal._files_caption.text,"Confirmed winner reaches the flag result")
	await settle()
	await capture("flag_result_720")
	check(terminal.visible and screen._session.state==Session.State.FINISHED,"Deferred legacy recovery cannot replace a confirmed flag result")
	await close_screen(screen)
	# A newly connected defender also starts at Home after the synchronized countdown.
	reset_fakes()
	http_replies.append({"ok":true,"status":201,"data":view("waiting",0,{"supports_flag":true})})
	screen = await open_screen(HOST_ID,"create")
	root.size = Vector2i(720,360)
	socket = sockets[0]
	data.merge({"role":"defender","step":0,"inspected":false,"revision":0,"node":"INVITATION","targets":{},"detail":"","feedback":""},true)
	socket.push(view("countdown",1,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	terminal = screen._flag_screen
	terminal._shortcuts[1].pressed.emit()
	terminal._action.pressed.emit()
	check(socket.sent_of("flag_action").is_empty(),"Countdown prevents early inspection")
	socket.push(view("active",2,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	await settle()
	check(terminal._home.visible,"Defender enters Home when countdown finishes")
	for button: Button in terminal._shortcuts:
		check(button.get_global_rect().size.y >= 44,"Home shortcuts have touch-sized targets")
	await capture("flag_home_defender_720")
	var settings: Node = root.get_node("SettingsService")
	var reduced_before: bool = bool(settings.get("reduced_motion"))
	settings.set("reduced_motion",true)
	terminal._rail[3].pressed.emit()
	terminal._nodes[3].pressed.emit()
	check(terminal._map.visible and socket.sent_of("flag_action").is_empty(),"Locked flag cannot skip evidence from Netmap")
	data.merge({"step":2,"revision":4,"node":"QUARANTINE","inspect_label":"Inspect flag file","summary":"Protected event folder / DL-817"},true)
	socket.push(view("active",3,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	terminal._action.pressed.emit()
	data.merge({"inspected":true,"revision":5,"detail":"DL-817 / EVENT.FLAG\nMove the verified flag into quarantine.","targets":{"flag":"Secure flag"}},true)
	socket.push(view("active",4,{"type":"room_state","supports_flag":true,"flag":data}))
	pump(screen)
	terminal._action.pressed.emit()
	terminal._nodes[3].pressed.emit()
	terminal._action.pressed.emit()
	actions = socket.sent_of("flag_action")
	check(actions.back().action=="route" and actions.back().target=="flag","Files and Netmap finish with a server capture command")
	data.merge({"step":3,"revision":6,"inspected":false,"targets":{}},true)
	socket.push(event("match_finished",5,{"winner_id":HOST_ID,"reason":"flag_secured","flag":data}))
	pump(screen)
	await settle()
	check(terminal._files.visible and terminal._mode=="done","Reduced motion preserves the result window")
	await capture("flag_victory_720")
	settings.set("reduced_motion",reduced_before)
	await close_screen(screen)
