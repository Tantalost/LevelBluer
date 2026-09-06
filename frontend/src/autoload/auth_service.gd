extends Node
## Autoload singleton, registered as "AuthService".
##
## Talks to the Python mobile backend for student login and password changes.
## Student accounts are provisioned by teachers via the web admin console.

signal session_changed(signed_in: bool)

enum Result {
	OK,
	INVALID_CREDENTIALS,
	NETWORK_ERROR,
	MUST_CHANGE_PASSWORD,
	UNKNOWN,
}

const DEFAULT_API_BASE := "http://127.0.0.1:8000"
const SESSION_PATH := "user://session.dat"
const REQUEST_TIMEOUT_SEC := 25.0
const RANK_STEP := 500
const RANKS: PackedStringArray = ["RECRUIT I", "RECRUIT II", "OPERATIVE I", "OPERATIVE II", "SPECIALIST", "ELITE I", "ELITE II", "COMMANDER"]

var _participant_code: String = ""
var _token: String = ""
var _signed_in: bool = false
var _display_name: String = "COMMANDER_X"
var _materials: int = -1
var _threat_points: int = -1
var _current_stage: int = 1
var _mastery: Dictionary = {}
var _pre_test_completed: bool = false
var _http: HTTPRequest
var _bkt_http: HTTPRequest
var _request_seq: int = 0
var _bkt_queue: Array[Dictionary] = []
var _bkt_busy: bool = false
var _user: Dictionary = {}
var _points: int = 0
var _section: String = ""
var _email: String = ""
var _full_name: String = ""
var _status: String = "Needs Review"
var _last_active: String = ""
var _sessions: int = 0
var _pre_score: int = 0
var _post_score: int = 0
var _tower_level: int = 1
var _glade_level: int = 1
var _forge_level: int = 1


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT_SEC
	_http.use_threads = true
	add_child(_http)
	_bkt_http = HTTPRequest.new()
	_bkt_http.timeout = REQUEST_TIMEOUT_SEC
	_bkt_http.use_threads = true
	add_child(_bkt_http)


func is_signed_in() -> bool:
	return _signed_in


func start_background_refresh() -> void:
	if StudentDatabase.has_pending_sync(_participant_code):
		SaveService.push_pending_sync()
		return
	_run_background_refresh()


func _run_background_refresh() -> void:
	await refresh_profile()


func auth_token() -> String:
	return _token


## The anonymised identifier that goes into every telemetry row. Never a name,
## never an email — see the ethics note in the study design doc.
func participant_code() -> String:
	return _participant_code


func display_name() -> String:
	return _display_name


func materials() -> int:
	return _materials


func threat_points() -> int:
	return _threat_points


func wallet_threat_points() -> int:
	return _threat_points if _threat_points >= 0 else 1000


func spend_threat_points(amount: int) -> bool:
	if amount < 0:
		return false
	var current := wallet_threat_points()
	if current < amount:
		return false
	_threat_points = current - amount
	if _signed_in:
		_persist(_signed_in, false)
	return true


func current_stage() -> int:
	return _current_stage


func points() -> int:
	return _points


func section() -> String:
	return _section


func email() -> String:
	return _email


func full_name() -> String:
	return _full_name if not _full_name.is_empty() else _display_name


func status_label() -> String:
	return _status


func last_active() -> String:
	return _last_active


func sessions() -> int:
	return _sessions


func pre_score() -> int:
	return _pre_score


func post_score() -> int:
	return _post_score


func tower_level() -> int:
	return _tower_level


func glade_level() -> int:
	return _glade_level


func forge_level() -> int:
	return _forge_level


func mastery() -> Dictionary:
	return _mastery.duplicate()


func _rank_index() -> int:
	return clampi(int(_points / RANK_STEP), 0, RANKS.size() - 1)


func rank_title() -> String:
	return RANKS[_rank_index()]


func next_rank_points() -> int:
	var index := _rank_index()
	if index >= RANKS.size() - 1:
		return maxi(_points, RANK_STEP * (RANKS.size() - 1))
	return (index + 1) * RANK_STEP


func exp_into_rank() -> int:
	if _rank_index() >= RANKS.size() - 1:
		return RANK_STEP
	return _points % RANK_STEP


func exp_rank_span() -> int:
	return RANK_STEP


func has_pre_test_completed() -> bool:
	return _pre_test_completed


func average_mastery() -> float:
	if _mastery.is_empty():
		return -1.0
	var total := 0.0
	for value in _mastery.values():
		total += float(value)
	return total / float(_mastery.size())


func weak_mastery_topics(threshold: float = 0.40) -> PackedStringArray:
	var topics: PackedStringArray = []
	for topic in _mastery.keys():
		if float(_mastery[topic]) < threshold:
			topics.append(str(topic))
	return topics


func restore_session() -> bool:
	await get_tree().process_frame

	var sqlite_row: Dictionary = StudentDatabase.load_signed_in_student()
	if not sqlite_row.is_empty():
		_apply_student_row(sqlite_row)
		_signed_in = true
		_persist(true, false, int(sqlite_row.get("needs_cloud_sync", 0)) == 1)
		session_changed.emit(true)
		return true

	if not FileAccess.file_exists(SESSION_PATH):
		return false

	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return false

	var raw := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return false

	_token = str(data.get("token", ""))
	_participant_code = str(data.get("participant_code", ""))
	_signed_in = bool(data.get("signed_in", false))
	_display_name = str(data.get("display_name", "COMMANDER_X"))
	_materials = int(data.get("materials", -1))
	_threat_points = int(data.get("threat_points", -1))
	_current_stage = int(data.get("current_stage", 1))
	var mastery_data: Variant = data.get("mastery", {})
	_mastery = mastery_data if typeof(mastery_data) == TYPE_DICTIONARY else {}
	_pre_test_completed = bool(data.get("pre_test_completed", false))
	var user_data: Variant = data.get("user", {})
	if typeof(user_data) == TYPE_DICTIONARY and not user_data.is_empty():
		_apply_user_profile(user_data, false)
	else:
		_points = int(data.get("points", 0))
		_section = str(data.get("section", ""))
		_email = str(data.get("email", ""))
		_full_name = str(data.get("full_name", _display_name))
		_status = str(data.get("status", "Needs Review"))
		_last_active = str(data.get("last_active", ""))
		_sessions = int(data.get("sessions", 0))
		_pre_score = int(data.get("pre", 0))
		_post_score = int(data.get("post", 0))
		_tower_level = int(data.get("tower_level", 1))
		_glade_level = int(data.get("glade_level", 1))
		_forge_level = int(data.get("forge_level", 1))

	if _signed_in and not _token.is_empty() and not _participant_code.is_empty():
		_persist(true, false, true)
		session_changed.emit(true)
		return true

	return false


func sign_in(email: String, password: String) -> Result:
	if email.is_empty() or password.is_empty():
		return Result.INVALID_CREDENTIALS

	_abort_http()
	await get_tree().process_frame
	var body := {"email": email.strip_edges().to_lower(), "password": password}
	var parsed: Variant = await _request_json("/api/auth/login", HTTPClient.METHOD_POST, body)
	if parsed == null:
		return Result.NETWORK_ERROR

	if typeof(parsed) != TYPE_DICTIONARY:
		return Result.UNKNOWN

	if parsed.has("error") or parsed.has("detail"):
		return Result.INVALID_CREDENTIALS

	_token = str(parsed.get("token", ""))
	var user: Dictionary = parsed.get("user", {})
	_participant_code = str(user.get("_id", user.get("id", "")))
	_apply_user_profile(user)

	if _token.is_empty() or _participant_code.is_empty():
		push_warning("AuthService login response missing token or user id: %s" % JSON.stringify(parsed))
		return Result.UNKNOWN

	if bool(parsed.get("mustChangePassword", false)):
		_signed_in = false
		_persist(false, true, false)
		return Result.MUST_CHANGE_PASSWORD

	_signed_in = true
	_persist(true, false, false)
	session_changed.emit(true)
	return Result.OK


func change_password(new_password: String) -> Result:
	if _token.is_empty():
		return Result.UNKNOWN

	var body := {"newPassword": new_password}
	var parsed: Variant = await _request_json(
		"/api/auth/change-password",
		HTTPClient.METHOD_POST,
		body,
		true,
	)
	if parsed == null:
		return Result.NETWORK_ERROR

	if typeof(parsed) != TYPE_DICTIONARY:
		return Result.UNKNOWN

	if parsed.has("error") or parsed.has("detail"):
		return Result.UNKNOWN

	_signed_in = true
	_persist(true, false, false)
	session_changed.emit(true)
	return Result.OK


func sign_out() -> void:
	_abort_http()
	_signed_in = false
	_token = ""
	_participant_code = ""
	_display_name = "COMMANDER_X"
	_materials = -1
	_threat_points = -1
	_current_stage = 1
	_mastery = {}
	_pre_test_completed = false
	_user = {}
	_points = 0
	_section = ""
	_email = ""
	_full_name = ""
	_status = "Needs Review"
	_last_active = ""
	_sessions = 0
	_pre_score = 0
	_post_score = 0
	_tower_level = 1
	_glade_level = 1
	_forge_level = 1
	StudentDatabase.clear_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	session_changed.emit(false)


func fetch_pretest_questions() -> Variant:
	return await _request_json("/api/pretest/questions", HTTPClient.METHOD_GET, {}, true)


func submit_pretest(answers: Array) -> Result:
	var parsed: Variant = await _request_json(
		"/api/pretest/submit",
		HTTPClient.METHOD_POST,
		{"answers": answers},
		true,
	)
	if parsed == null:
		return Result.NETWORK_ERROR
	if typeof(parsed) != TYPE_DICTIONARY:
		return Result.UNKNOWN
	if parsed.has("error") or parsed.has("detail"):
		return Result.UNKNOWN

	var mastery_data: Variant = parsed.get("mastery", {})
	if typeof(mastery_data) == TYPE_DICTIONARY:
		_mastery = mastery_data
	_pre_test_completed = bool(parsed.get("preTestCompleted", true))
	_persist(_signed_in, false, true)
	session_changed.emit(_signed_in)
	PlayerManager.seed_from_official_mastery()
	return Result.OK


func refresh_profile() -> bool:
	if _token.is_empty():
		return _signed_in and not _participant_code.is_empty()
	var parsed: Variant = await _request_json("/api/auth/me", HTTPClient.METHOD_GET, {}, true)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _signed_in and not _participant_code.is_empty()
	if parsed.has("error") or parsed.has("detail"):
		return _signed_in and not _participant_code.is_empty()
	if str(parsed.get("_id", parsed.get("id", ""))).is_empty():
		return _signed_in and not _participant_code.is_empty()
	_apply_user_profile(parsed)
	_persist(_signed_in, false, false)
	return true


func enqueue_bkt_assess(skill_id: String, is_correct: bool, params: Dictionary = {}) -> void:
	if not _signed_in or _token.is_empty():
		return
	var job := {
		"skill_id": skill_id if not skill_id.is_empty() else "phishing",
		"is_correct": is_correct,
	}
	for key in ["p_g", "p_s", "p_t"]:
		if not params.has(key):
			continue
		var stored: Variant = params[key]
		if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
			job[key] = float(stored)
	_bkt_queue.append(job)
	if not _bkt_busy:
		_pump_bkt_queue()


func fetch_bkt_state() -> Dictionary:
	if _token.is_empty():
		return {}
	var parsed: Variant = await _request_json("/api/bkt/state", HTTPClient.METHOD_GET, {}, true)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed as Dictionary
	if payload.has("error") or payload.has("detail"):
		return {}
	var mastery_data: Variant = payload.get("mastery", {})
	if typeof(mastery_data) == TYPE_DICTIONARY:
		var incoming: Dictionary = mastery_data as Dictionary
		var keys: Array = incoming.keys()
		for i in keys.size():
			_mastery[str(keys[i])] = float(incoming[keys[i]])
		_persist(_signed_in, false, false)
	var gameplay_data: Variant = payload.get("gameplay", {})
	if typeof(gameplay_data) != TYPE_DICTIONARY:
		return {}
	return gameplay_data as Dictionary


func apply_topic_mastery(topic: String, probability_known: float) -> void:
	var key: String = topic if not topic.is_empty() else "Phishing"
	_mastery[key] = clampf(probability_known, 0.01, 0.99)
	if _user.has("mastery") and typeof(_user["mastery"]) == TYPE_DICTIONARY:
		var user_mastery: Dictionary = _user["mastery"]
		user_mastery[key] = _mastery[key]
		_user["mastery"] = user_mastery
	_persist(_signed_in, false, false)


func _pump_bkt_queue() -> void:
	if _bkt_busy:
		return
	_bkt_busy = true
	while not _bkt_queue.is_empty():
		var job: Dictionary = _bkt_queue[0]
		var ok: bool = await _post_bkt_assess(job)
		if not ok:
			break
		_bkt_queue.pop_front()
	_bkt_busy = false


func _post_bkt_assess(job: Dictionary) -> bool:
	if _bkt_http == null or _token.is_empty():
		return false
	var body := {
		"skill_id": str(job.get("skill_id", "phishing")),
		"is_correct": bool(job.get("is_correct", false)),
	}
	for key in ["p_g", "p_s", "p_t"]:
		if job.has(key):
			body[key] = float(job[key])
	var url := "%s/api/bkt/assess" % _api_base().trim_suffix("/")
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer %s" % _token,
	])
	if _bkt_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_bkt_http.cancel_request()
		await get_tree().process_frame
	var err := _bkt_http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_warning("[BKT] assess request failed to start: %s" % err)
		return false
	var completed: Array = await _bkt_http.request_completed
	var result_code: int = int(completed[0])
	var response_code: int = int(completed[1])
	var response_body: PackedByteArray = completed[3]
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("[BKT] assess failed. result=%s http=%s" % [result_code, response_code])
		return false
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return true
	var payload: Dictionary = parsed as Dictionary
	var topic: String = str(payload.get("topic", "Phishing"))
	var pl: float = float(payload.get("probability_known", 0.0))
	if pl > 0.0:
		apply_topic_mastery(topic, pl)
		print("[BKT] official %s P(L)=%.3f" % [topic, pl])
	return true


func _api_base() -> String:
	return str(ProjectSettings.get_setting("levelblue/api_base_url", DEFAULT_API_BASE))


func _abort_http() -> void:
	_request_seq += 1
	if _http == null:
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()


func _request_json(
	path: String,
	method: int,
	body: Dictionary = {},
	authorized: bool = false,
) -> Variant:
	_request_seq += 1
	var seq := _request_seq
	var url := "%s%s" % [_api_base().trim_suffix("/"), path]
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if authorized and not _token.is_empty():
		headers.append("Authorization: Bearer %s" % _token)

	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
		await get_tree().process_frame
		if seq != _request_seq:
			return null

	var json_body := JSON.stringify(body) if method != HTTPClient.METHOD_GET else ""
	var err := _http.request(url, headers, method, json_body)
	if err == ERR_BUSY:
		_http.cancel_request()
		await get_tree().process_frame
		if seq != _request_seq:
			return null
		err = _http.request(url, headers, method, json_body)
	if err != OK:
		push_warning("AuthService request failed to start: %s" % err)
		return null

	var completed: Array = await _http.request_completed
	if seq != _request_seq:
		return null
	var result_code: int = completed[0]
	var response_code: int = completed[1]
	var response_body: PackedByteArray = completed[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		push_warning("AuthService network error: HTTPRequest result %s" % result_code)
		return null

	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}

	if response_code == 401:
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {"error": "Unauthorized"}

	if response_code < 200 or response_code >= 300:
		push_warning("AuthService HTTP %s: %s" % [response_code, text])
		if response_code >= 500:
			return null
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {"error": "Request failed"}

	return parsed


func _apply_user_profile(user: Dictionary, overwrite_name: bool = true) -> void:
	_user = user.duplicate(true)
	if overwrite_name or _display_name.is_empty() or _display_name == "COMMANDER_X":
		_display_name = _format_profile_name(str(user.get("name", _display_name)))
	_full_name = str(user.get("name", _full_name))
	_email = str(user.get("email", _email))
	_section = str(user.get("section", _section))
	_status = str(user.get("status", _status if not _status.is_empty() else "Needs Review"))
	_last_active = str(user.get("lastActive", user.get("last_active", _last_active)))
	_points = int(user.get("points", _points))
	_sessions = int(user.get("sessions", _sessions))
	_pre_score = int(user.get("pre", _pre_score))
	_post_score = int(user.get("post", _post_score))
	_materials = int(user.get("materials", _materials))
	_threat_points = int(user.get("threatPoints", user.get("threat_points", _threat_points)))
	_current_stage = int(user.get("highestUnlockedStage", user.get("highest_unlocked_stage", _current_stage)))

	var buildings: Variant = user.get("buildingLevels", user.get("building_levels", {}))
	if typeof(buildings) == TYPE_DICTIONARY:
		_tower_level = int(buildings.get("tower", _tower_level))
		_glade_level = int(buildings.get("glade", _glade_level))
		_forge_level = int(buildings.get("forge", _forge_level))
	else:
		_tower_level = int(user.get("tower_level", _tower_level))
		_glade_level = int(user.get("glade_level", _glade_level))
		_forge_level = int(user.get("forge_level", _forge_level))

	var mastery_data: Variant = user.get("mastery", {})
	if typeof(mastery_data) == TYPE_DICTIONARY:
		_mastery = mastery_data
	_pre_test_completed = bool(user.get("preTestCompleted", _pre_test_completed))


func _apply_student_row(row: Dictionary) -> void:
	_participant_code = str(row.get("id", ""))
	_token = str(row.get("auth_token", ""))
	_display_name = str(row.get("display_name", ""))
	_full_name = str(row.get("name", _full_name))
	if _display_name.is_empty():
		_display_name = _format_profile_name(_full_name)
	_email = str(row.get("email", ""))
	_section = str(row.get("section", ""))
	_status = str(row.get("status", "Needs Review"))
	_last_active = str(row.get("last_active", ""))
	_points = int(row.get("points", 0))
	_sessions = int(row.get("sessions", 0))
	_pre_score = int(row.get("pre", 0))
	_post_score = int(row.get("post", 0))
	_materials = int(row.get("upgrade_materials", 0))
	_threat_points = int(row.get("threat_points", 0))
	_current_stage = int(row.get("highest_unlocked_stage", 1))
	_tower_level = int(row.get("tower_level", 1))
	_glade_level = int(row.get("glade_level", 1))
	_forge_level = int(row.get("forge_level", 1))
	_pre_test_completed = int(row.get("pre_test_completed", 0)) == 1
	_mastery = {
		"Phishing": float(row.get("mastery_phishing", 0.0)),
		"Smishing": float(row.get("mastery_smishing", 0.0)),
		"Vishing": float(row.get("mastery_vishing", 0.0)),
		"Pretexting": float(row.get("mastery_pretexting", 0.0)),
		"Baiting": float(row.get("mastery_baiting", 0.0)),
	}
	_user = {
		"id": _participant_code,
		"name": _full_name,
		"email": _email,
		"firstName": str(row.get("first_name", "")),
		"lastName": str(row.get("last_name", "")),
		"section": _section,
		"status": _status,
		"lastActive": _last_active,
		"technical": int(row.get("technical", 0)) == 1,
		"pre": _pre_score,
		"post": _post_score,
		"sessions": _sessions,
		"points": _points,
		"threatPoints": _threat_points,
		"materials": _materials,
		"highestUnlockedStage": _current_stage,
		"buildingLevels": {
			"tower": _tower_level,
			"glade": _glade_level,
			"forge": _forge_level,
		},
		"interventionStatus": str(row.get("intervention_status", "NORMAL")),
		"mastery": _mastery.duplicate(),
		"preTestCompleted": _pre_test_completed,
	}


static func _format_profile_name(name: String) -> String:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return "COMMANDER_X"

	var parts := trimmed.split(" ", false)
	if parts.is_empty():
		return "COMMANDER_X"
	if parts.size() == 1:
		return parts[0].replace(" ", "_").to_upper()

	return parts[parts.size() - 1].replace(" ", "_").to_upper()


func cloud_sync_payload() -> Dictionary:
	return {
		"threat_points": maxi(_threat_points, 0),
		"upgrade_materials": maxi(_materials, 0),
		"points": _points,
		"sessions": _sessions,
		"tower_level": _tower_level,
		"glade_level": _glade_level,
		"forge_level": _forge_level,
		"highest_unlocked_stage": _current_stage,
		"pre": _pre_score,
		"post": _post_score,
		"mastery_phishing": float(_mastery.get("Phishing", 0.0)),
		"mastery_smishing": float(_mastery.get("Smishing", 0.0)),
		"mastery_vishing": float(_mastery.get("Vishing", 0.0)),
		"mastery_pretexting": float(_mastery.get("Pretexting", 0.0)),
		"mastery_baiting": float(_mastery.get("Baiting", 0.0)),
	}


func _persist(signed_in: bool, pending_password_change: bool, mark_dirty: bool = true) -> void:
	var payload := {
		"token": _token,
		"participant_code": _participant_code,
		"signed_in": signed_in,
		"pending_password_change": pending_password_change,
		"display_name": _display_name,
		"materials": _materials,
		"threat_points": _threat_points,
		"current_stage": _current_stage,
		"mastery": _mastery,
		"pre_test_completed": _pre_test_completed,
		"user": _user,
		"points": _points,
		"section": _section,
		"email": _email,
		"full_name": _full_name,
		"status": _status,
		"last_active": _last_active,
		"sessions": _sessions,
		"pre": _pre_score,
		"post": _post_score,
		"tower_level": _tower_level,
		"glade_level": _glade_level,
		"forge_level": _forge_level,
	}
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not persist session file.")
	else:
		file.store_string(JSON.stringify(payload))
		file.close()
	if _participant_code.is_empty():
		return
	var sqlite_row := {
		"id": _participant_code,
		"name": _full_name if not _full_name.is_empty() else _display_name,
		"section": _section,
		"pre": _pre_score,
		"post": _post_score,
		"sessions": _sessions,
		"points": _points,
		"last_active": _last_active if not _last_active.is_empty() else "Just now",
		"technical": bool(_user.get("technical", false)),
		"status": _status,
		"mastery_phishing": float(_mastery.get("Phishing", 0.0)),
		"mastery_smishing": float(_mastery.get("Smishing", 0.0)),
		"mastery_vishing": float(_mastery.get("Vishing", 0.0)),
		"mastery_pretexting": float(_mastery.get("Pretexting", 0.0)),
		"mastery_baiting": float(_mastery.get("Baiting", 0.0)),
		"threat_points": maxi(_threat_points, 0),
		"upgrade_materials": maxi(_materials, 0),
		"highest_unlocked_stage": _current_stage,
		"tower_level": _tower_level,
		"glade_level": _glade_level,
		"forge_level": _forge_level,
		"intervention_status": str(_user.get("interventionStatus", _user.get("intervention_status", "NORMAL"))),
		"requires_password_change": pending_password_change,
		"email": _email,
		"first_name": str(_user.get("firstName", _user.get("first_name", ""))),
		"last_name": str(_user.get("lastName", _user.get("last_name", ""))),
		"middle_initial": str(_user.get("middleInitial", _user.get("middle_initial", ""))),
		"auth_token": _token,
		"signed_in": signed_in,
		"pre_test_completed": _pre_test_completed,
		"pending_password_change": pending_password_change,
		"display_name": _display_name,
		"needs_cloud_sync": mark_dirty,
	}
	StudentDatabase.upsert_student(sqlite_row)
	if signed_in and mark_dirty:
		SaveService.push_pending_sync()
