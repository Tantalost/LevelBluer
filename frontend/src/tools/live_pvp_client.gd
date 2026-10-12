extends SceneTree
## Live PvP client harness (development only). One real online client per Godot process,
## driven through the real PvpOnlineScreen + PvpOnlineSession against a running backend.
## Usage: godot --headless --path frontend --script res://src/tools/live_pvp_client.gd -- role=host scenario=full dir=<abs dir> api=http://127.0.0.1:8765
## The token is read from <dir>/<role>.token and never printed. The harness reads the local bank only to
## decide which button to press; the screen itself never grades.
const SCENE: String = "res://src/ui/screens/pvp/pvp_online_screen.tscn"
const Session = preload("res://src/network/pvp_online_session.gd")
const SCENARIO_TIMEOUT_MS: int = 240000
const BLACKHOLE_API: String = "http://127.0.0.1:9"

## round -> [action, delay_ms]; action is correct | wrong | none | dup (correct + raw duplicate send)
const PLANS: Dictionary = {
	"full": {
		"host": {1: ["correct", 600], 2: ["correct", 2500], 3: ["none", 0], 4: ["wrong", 500], 5: ["correct", 1800], 6: ["none", 0], 7: ["dup", 700], 8: ["none", 0], 9: ["correct", 600], 10: ["correct", 600]},
		"guest": {1: ["none", 0], 2: ["wrong", 800], 3: ["none", 0], 4: ["wrong", 700], 5: ["correct", 600], 6: ["correct", 600], 7: ["none", 0], 8: ["correct", 600], 9: ["wrong", 300], 10: ["none", 0]},
	},
}

var role: String = "host"
var scenario: String = "full"
var dir_path: String = ""
var api: String = ""
var screen: Control
var log_file: FileAccess
var answers: Dictionary = {}
var started_ms: int = 0
var answered: Dictionary = {}
var countdown_zero_logged: Dictionary = {}
var ready_pressed: bool = false
var done: bool = false
var exit_code: int = 0
var marks: Dictionary = {}
var second: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for raw: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.split("=", true, 1)
		if parts.size() == 2:
			match parts[0]:
				"role": role = parts[1]
				"scenario": scenario = parts[1]
				"dir": dir_path = parts[1]
				"api": api = parts[1]
	log_file = FileAccess.open(dir_path.path_join(role + ".jsonl"), FileAccess.WRITE)
	var token: String = FileAccess.get_file_as_string(dir_path.path_join(role + ".token")).strip_edges()
	var auth: Node = root.get_node("AuthService")
	auth.set("_token", token)
	auth.set("_display_name", role.to_upper())
	ProjectSettings.set_setting("levelblue/api_base_url", api)
	for row: Dictionary in root.get_node("ContentDB").call("get_pvp_questions"):
		answers[str(row["id"])] = str((row["options"] as Array)[int(row["answer_index"])])
	started_ms = Time.get_ticks_msec()
	note("start", {"scenario": scenario})
	if scenario == "offline":
		await _offline()
	elif scenario.begins_with("mm_"):
		await _play_matchmaking()
	else:
		await _play()
	note("exit", {"code": exit_code})
	log_file.flush()
	quit(exit_code)


# ---- evidence -----------------------------------------------------------------------

func note(event: String, data: Dictionary = {}) -> void:
	var line: Dictionary = {"event": event, "wall": int(Time.get_unix_time_from_system() * 1000.0), "role": role}
	var session: Session = current_session()
	if session != null and session.has_clock_sample:
		line["server"] = session.server_now_ms()
	line.merge(data, true)
	log_file.store_line(JSON.stringify(line))
	log_file.flush()


func current_session() -> Session:
	if screen == null or not is_instance_valid(screen):
		return null
	return screen.get("_session") as Session


func mark_file(name: String) -> void:
	FileAccess.open(dir_path.path_join(name), FileAccess.WRITE).store_string("1")


func buttons_disabled() -> bool:
	for button: Button in screen.get("_answer_buttons") as Array:
		if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
			return false
	return true


# ---- client ---------------------------------------------------------------------------

func open_screen(action: String) -> void:
	screen = (load(SCENE) as PackedScene).instantiate() as Control
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.call("on_enter", {"action": action})
	var session: Session = current_session()
	session.round_started.connect(_on_round_started)
	session.round_resolved.connect(_on_round_resolved)
	session.match_finished.connect(_on_match_finished)
	session.countdown_started.connect(func(round_number: int, ends_at: int) -> void: note("countdown", {"round": round_number, "ends_at": ends_at}))
	session.local_answer_locked.connect(func(round_number: int, option_index: int, correct: bool) -> void: note("locked", {"round": round_number, "option": option_index, "correct": correct, "state": Session.State.keys()[current_session().state]}))
	session.connection_changed.connect(func(next_state: int) -> void: note("state", {"state": Session.State.keys()[next_state]}))
	session.error_received.connect(func(code: String, message: String) -> void: note("error", {"code": code, "message": message}))
	session.opponent_disconnected.connect(func(grace_ends_at: int) -> void: _note_banner.call_deferred("opponent_disconnected", grace_ends_at))
	session.opponent_connected.connect(func() -> void: _note_banner.call_deferred("opponent_connected", 0))
	session.match_found.connect(func(code: String) -> void: note("match_found", {"code": code, "status_requests": current_session().status_requests, "sessions_created": int(screen.get("_sessions_created"))}))
	session.room_updated.connect(func(view: Dictionary) -> void: note("room_state", {"state": str(view.get("state", "")), "round": int(view.get("round_number", 0)), "hp": view.get("hp", {}), "question_id": str(current_session().current_round.get("question_id", "")), "answered": current_session().has_answered_current_round()}))


func _note_banner(event: String, grace_ends_at: int) -> void:
	screen.call("_process", 0.0)
	var banner: Label = screen.get("_banner") as Label
	note(event, {"grace_ends_at": grace_ends_at, "banner": banner.text if banner.visible else ""})


func _on_round_started(data: Dictionary) -> void:
	note("round", {"round": int(data["round"]), "question_id": str(data["question_id"]), "options": data["options"], "started_at": int(data["started_at"]), "ends_at": int(data["ends_at"])})


func _on_round_resolved(result: Dictionary) -> void:
	var session: Session = current_session()
	note("result", {"round": int(result["round"]), "winner": str(result["winner_id"]), "reason": str(result["reason"]), "hp": session.hp, "me": session.self_id, "locked_after_result": buttons_disabled(), "headline": str((screen.get("_result_title") as Label).text)})


func _on_match_finished(result: Dictionary) -> void:
	_note_final.call_deferred(result)


func _note_final(result: Dictionary) -> void:
	note("final", {"reason": str(result["reason"]), "winner": str(result["winner_id"]), "hp": result["hp"], "me": current_session().self_id if current_session() != null else "", "title": (screen.get("_end_title") as Label).text, "line": (screen.get("_end_rounds") as Label).text})


func _play() -> void:
	open_screen("create" if role == "host" else "join")
	if role == "guest":
		var code: String = await wait_for_room_code()
		if code.is_empty():
			exit_code = 1
			return
		(screen.get("_code_input") as LineEdit).text = "  %s " % code.to_lower()
		(screen.get("_join_button") as Button).pressed.emit()
	await _loop()
	await leave_and_free()


func _loop() -> void:
	while not done:
		await process_frame
		if Time.get_ticks_msec() - started_ms > SCENARIO_TIMEOUT_MS:
			note("timeout")
			exit_code = 1
			break
		step()


func wait_for_room_code() -> String:
	var path: String = dir_path.path_join("room.txt")
	while Time.get_ticks_msec() - started_ms < 30000:
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_string(path).strip_edges()
		await process_frame
	note("no_room_code")
	return ""


func step() -> void:
	var session: Session = current_session()
	if session == null:
		done = true
		return
	if scenario.begins_with("mm_") and session.state == Session.State.WAITING and not session.opponent_id().is_empty() and not marks.has("lobby"):
		marks["lobby"] = true
		note("lobby", {"code": session.room_code, "title": (screen.get("_lobby_title") as Label).text, "rival": (screen.get("_rival_name") as Label).text, "sessions_created": int(screen.get("_sessions_created")), "status_requests": session.status_requests})
	if role == "host" and not scenario.begins_with("mm_") and not session.room_code.is_empty() and not marks.has("room"):
		marks["room"] = true
		note("room_code", {"code": session.room_code})
		FileAccess.open(dir_path.path_join("room.txt"), FileAccess.WRITE).store_string(session.room_code)
	var state: Session.State = session.state
	if state == Session.State.WAITING and not session.opponent_id().is_empty() and not ready_pressed and scenario != "lobby_leave":
		ready_pressed = true
		(screen.get("_ready_button") as Button).pressed.emit()
		note("ready_pressed")
	if state == Session.State.COUNTDOWN:
		var number: int = int(screen.get("_round_number"))
		if session.countdown_remaining_ms() <= 0 and not countdown_zero_logged.has(number):
			countdown_zero_logged[number] = true
			note("countdown_zero", {"round": number})
	if state == Session.State.ACTIVE:
		_answer_step(session)
	_scenario_step(session)


func _answer_step(session: Session) -> void:
	var round_data: Dictionary = session.current_round
	var number: int = int(round_data.get("round", 0))
	if answered.has(number) or session.has_answered_current_round():
		return
	var plan: Array = _plan(number)
	var action: String = str(plan[0])
	if action == "none":
		return
	if session.server_now_ms() < int(round_data.get("started_at", 0)) + int(plan[1]):
		return
	answered[number] = true
	var options: Array = round_data.get("options", []) as Array
	var right: String = str(answers.get(str(round_data.get("question_id", "")), ""))
	var correct_index: int = options.find(right)
	if correct_index < 0:
		note("unknown_question", {"question_id": str(round_data.get("question_id", ""))})
		return
	var index: int = correct_index if action != "wrong" else (correct_index + 1) % options.size()
	var buttons: Array = screen.get("_answer_buttons") as Array
	(buttons[index] as Button).pressed.emit()
	note("answered", {"round": number, "action": action, "option": index, "locked_ui": buttons_disabled()})
	(buttons[(index + 1) % buttons.size()] as Button).pressed.emit()
	if action == "dup":
		session.call("_send", {"type": "answer", "round": number, "option_index": index})
		note("raw_duplicate_sent", {"round": number})


func _plan(number: int) -> Array:
	var by_scenario: Dictionary = PLANS.get("full" if scenario == "mm_full" else scenario, {}) as Dictionary
	var by_role: Dictionary = by_scenario.get(role, {}) as Dictionary
	if by_role.has(number):
		return by_role[number] as Array
	if scenario == "full" or scenario == "mm_full":
		return ["none", 0]
	# Other scenarios: rounds 1-2 stay unanswered (room for drops and grace), then the host wins quickly to KO.
	return ["correct", 500] if role == "host" and number > 2 else ["none", 0]


func _scenario_step(session: Session) -> void:
	var state: Session.State = session.state
	var active_for: int = 0
	if state == Session.State.ACTIVE:
		active_for = session.server_now_ms() - int(session.current_round.get("started_at", 0))
	match scenario:
		"full", "mm_full", "mm_noshow", "mm_abrupt":
			if state == Session.State.FINISHED and not marks.has("finish_wait"):
				marks["finish_wait"] = Time.get_ticks_msec()
			if marks.has("finish_wait") and Time.get_ticks_msec() - int(marks["finish_wait"]) > 1500:
				done = true
		"reconnect":
			if role == "guest" and int(session.current_round.get("round", 0)) == 1 and active_for > 1000 and not marks.has("dropped"):
				marks["dropped"] = Time.get_ticks_msec()
				ProjectSettings.set_setting("levelblue/api_base_url", BLACKHOLE_API)
				note("network_drop", {"round": 1})
				(session.get("_socket") as Session.SocketTransport).close(1001)
			if marks.has("dropped") and not marks.has("restored") and Time.get_ticks_msec() - int(marks["dropped"]) > 3500:
				marks["restored"] = true
				ProjectSettings.set_setting("levelblue/api_base_url", api)
				note("network_restore")
			if state == Session.State.FINISHED:
				done = true
		"forfeit":
			if role == "guest" and state == Session.State.ACTIVE and active_for > 1000 and not marks.has("kill"):
				marks["kill"] = true
				note("ready_to_kill")
				mark_file("kill_guest")
			if role == "host" and state == Session.State.FINISHED:
				done = true
		"lobby_leave":
			if role == "guest" and state == Session.State.WAITING and not session.opponent_id().is_empty() and not marks.has("left"):
				marks["left"] = true
				note("lobby_leave_pressed")
				(screen.get("_leave_room_button") as Button).pressed.emit()
			if role == "guest" and bool(screen.get("_left")):
				note("left", {"sessions_freed": int(screen.get("_sessions_freed"))})
				done = true
			if role == "host" and state == Session.State.FINISHED:
				done = true
		"match_leave":
			if role == "guest" and state == Session.State.ACTIVE and active_for > 1000 and not marks.has("left"):
				marks["left"] = true
				var asked: bool = bool(screen.call("consume_back"))
				note("back_pressed", {"confirm_shown": asked and (screen.get("_abandon") as Control).visible})
				(screen.find_child("AbandonLeaveButton", true, false) as Button).pressed.emit()
			if role == "guest" and bool(screen.get("_left")):
				note("left", {"sessions_freed": int(screen.get("_sessions_freed"))})
				done = true
			if role == "host" and state == Session.State.FINISHED:
				done = true
		"replace":
			if role == "host" and state == Session.State.ACTIVE and active_for > 1000 and second == null:
				second = Session.new()
				second.name = "SecondDevice"
				root.add_child(second)
				(second as Session).connection_changed.connect(func(next_state: int) -> void: note("second_state", {"state": Session.State.keys()[next_state]}))
				note("second_socket_open")
				(second as Session).recover_room(session.room_code)
			if role == "host" and second != null and (state == Session.State.DISCONNECTED or state == Session.State.ERROR) and not marks.has("replaced"):
				marks["replaced"] = Time.get_ticks_msec()
				screen.call("_process", 0.0)
				note("first_replaced", {"error": session.last_error_code, "title": (screen.get("_end_title") as Label).text, "line": (screen.get("_end_rounds") as Label).text, "second": Session.State.keys()[(second as Session).state]})
			if marks.has("replaced") and Time.get_ticks_msec() - int(marks["replaced"]) > 1500 and not marks.has("second_left"):
				marks["second_left"] = true
				note("second_state_before_leave", {"state": Session.State.keys()[(second as Session).state], "round": int((second as Session).current_round.get("round", 0))})
				(second as Session).leave()
				done = true
			if role == "guest" and state == Session.State.FINISHED:
				done = true
		"restart":
			if role == "host" and state == Session.State.ACTIVE and active_for > 1000 and not marks.has("kill"):
				marks["kill"] = true
				note("ready_to_kill_server")
				mark_file("kill_server")
			if marks.has("kill") or role == "guest":
				if state == Session.State.ERROR or state == Session.State.DISCONNECTED:
					screen.call("_process", 0.0)
					note("restart_outcome", {"error": session.last_error_code, "title": (screen.get("_end_title") as Label).text, "line": (screen.get("_end_rounds") as Label).text, "end_visible": (screen.get("_end_host") as Control).visible})
					done = true


func leave_and_free() -> void:
	if screen == null or not is_instance_valid(screen):
		return
	var live: Session = current_session()
	if live != null:
		note("pre_leave", {"status_requests": live.status_requests, "state": Session.State.keys()[live.state], "room_code": live.room_code})
	if not bool(screen.get("_left")):
		screen.call("_leave_online")
		var waited: int = Time.get_ticks_msec()
		while not bool(screen.get("_left")) and Time.get_ticks_msec() - waited < 4000:
			await process_frame
	note("cleanup", {"left": bool(screen.get("_left")), "sessions_freed": int(screen.get("_sessions_freed")), "sessions_created": int(screen.get("_sessions_created"))})
	if second != null and is_instance_valid(second):
		await create_timer(0.5).timeout
		second.queue_free()
	screen.queue_free()
	await process_frame


# ---- matchmaking ---------------------------------------------------------------------

func wall_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func marker(name: String) -> bool:
	return FileAccess.file_exists(dir_path.path_join(name))


func wait_until(condition: Callable, timeout_ms: int) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		if bool(condition.call()):
			return true
		await process_frame
	return bool(condition.call())


func searching_polled(count: int) -> bool:
	var session: Session = current_session()
	return session != null and session.state == Session.State.SEARCHING and session.status_requests >= count


func in_room() -> bool:
	var session: Session = current_session()
	return session != null and not session.room_code.is_empty() and session.state == Session.State.WAITING


func screen_left() -> bool:
	return screen != null and is_instance_valid(screen) and bool(screen.get("_left"))


func describe() -> Dictionary:
	var session: Session = current_session()
	if session == null:
		return {"state": "FREED", "room_code": "", "status_requests": -1, "left": screen_left()}
	return {"state": Session.State.keys()[session.state], "room_code": session.room_code, "status_requests": session.status_requests, "left": screen_left(), "error": session.last_error_code}


## Driver writes "<host_wall_ms>,<guest_wall_ms>"; each role busy-waits to its own moment.
func wait_go() -> bool:
	if not await wait_until(func() -> bool: return marker("go_at"), 60000):
		note("no_go")
		return false
	var parts: PackedStringArray = FileAccess.get_file_as_string(dir_path.path_join("go_at")).strip_edges().split(",")
	var target: int = int(parts[0] if role == "host" else parts[1])
	while wall_ms() < target:
		await process_frame
	note("go", {"target": target})
	return true


func press_cancel() -> void:
	note("cancel_pressed", describe())
	(screen.get("_cancel_search_button") as Button).pressed.emit()


func _play_matchmaking() -> void:
	match scenario:
		"mm_full":
			if role == "guest" and not await wait_until(func() -> bool: return marker("host_queued"), 60000):
				note("no_host_queue")
				exit_code = 1
				return
			open_screen("find")
			if role == "host" and await wait_until(func() -> bool: return searching_polled(2), 15000):
				note("queued_waiting", describe())
				mark_file("host_queued")
			await _loop()
		"mm_simultaneous":
			if await wait_go():
				open_screen("find")
				await wait_until(in_room, 15000)
				note("lobby_reached", describe())
				await create_timer(1.5).timeout
		"mm_cancel":
			if role == "host":
				open_screen("find")
				await wait_until(func() -> bool: return searching_polled(2), 15000)
				note("queued_waiting", describe())
				press_cancel()
				await wait_until(screen_left, 5000)
				note("cancelled", describe())
				mark_file("host_cancelled")
			else:
				await wait_until(func() -> bool: return marker("host_cancelled"), 60000)
				open_screen("find")
				await create_timer(3.5).timeout
				note("guest_after_wait", describe())
				press_cancel()
				await wait_until(screen_left, 5000)
				note("cancelled", describe())
		"mm_cancel_race":
			if role == "host":
				open_screen("find")
				await wait_until(func() -> bool: return searching_polled(1), 15000)
				mark_file("host_queued")
				if await wait_go():
					press_cancel()
					await wait_until(func() -> bool: return screen_left() or in_room(), 8000)
			elif await wait_go():
				open_screen("find")
				await wait_until(func() -> bool: return in_room() or searching_polled(2), 8000)
			note("race_outcome", describe())
			if not screen_left() and current_session() != null and current_session().state == Session.State.SEARCHING:
				press_cancel()
				await wait_until(screen_left, 5000)
			await create_timer(1.0).timeout
		"mm_abrupt", "mm_expiry":
			if role == "host":
				open_screen("find")
				await wait_until(func() -> bool: return searching_polled(2), 15000)
				note("queued_waiting", describe())
				mark_file("kill_host")
				await create_timer(30.0).timeout
				note("not_killed")
			else:
				await wait_until(func() -> bool: return marker("host_killed"), 60000)
				open_screen("find")
				await _loop()
		"mm_noshow":
			open_screen("find")
			await wait_until(func() -> bool: return searching_polled(1), 15000)
			mark_file("host_queued")
			await _loop()
		"mm_conflict":
			open_screen("find")
			var errored: bool = await wait_until(func() -> bool: return current_session() != null and current_session().state == Session.State.ERROR, 10000)
			note("conflict", {"errored": errored, "error": (screen.get("_lobby_error") as Label).text, "retry_visible": (screen.get("_retry_button") as Button).visible, "back_visible": (screen.get("_leave_room_button") as Button).visible, "back_text": (screen.get("_leave_room_button") as Button).text, "searching_visible": (screen.get("_search_box") as Control).visible, "sessions_created": int(screen.get("_sessions_created")), "state": describe()})
	await leave_and_free()


# ---- backend unavailable -------------------------------------------------------------

func _offline() -> void:
	open_screen("create")
	var waited: int = Time.get_ticks_msec()
	while current_session().state != Session.State.ERROR and Time.get_ticks_msec() - waited < 20000:
		await process_frame
	note("offline_create", {"state": Session.State.keys()[current_session().state], "error": (screen.get("_lobby_error") as Label).text, "retry_visible": (screen.get("_retry_button") as Button).visible})
	await leave_and_free()
	open_screen("join")
	(screen.get("_code_input") as LineEdit).text = "abc234"
	(screen.get("_join_button") as Button).pressed.emit()
	waited = Time.get_ticks_msec()
	while current_session().state != Session.State.ERROR and Time.get_ticks_msec() - waited < 20000:
		await process_frame
	note("offline_join", {"state": Session.State.keys()[current_session().state], "error": (screen.get("_lobby_error") as Label).text, "entry_visible": (screen.get("_entry") as Control).visible})
	await leave_and_free()
