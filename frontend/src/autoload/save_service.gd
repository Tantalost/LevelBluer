extends Node
## Autoload singleton, registered as "SaveService".
## Local JSON is the session source of truth while offline.
## Offline mutations are queued and pushed to the cloud when a request succeeds.

signal cloud_fetch_completed(success: bool)
signal cloud_sync_completed(success: bool)

const DEFAULT_API_BASE := "http://127.0.0.1:8000"
const SYNC_PATH := "/api/progress/sync"
const SYNC_TIMEOUT_SEC := 10.0
const RETRY_SEC := 20.0

var _http_request: HTTPRequest
var _http_fetch: HTTPRequest
var _sync_in_flight: bool = false
var _resync_queued: bool = false
var _fetch_in_flight: bool = false
var _last_fetch_ok: bool = false
var _retry_left: float = 0.0


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = SYNC_TIMEOUT_SEC
	_http_request.use_threads = true
	add_child(_http_request)
	_http_request.request_completed.connect(_on_sync_completed)

	_http_fetch = HTTPRequest.new()
	_http_fetch.timeout = SYNC_TIMEOUT_SEC
	_http_fetch.use_threads = true
	add_child(_http_fetch)
	_http_fetch.request_completed.connect(_on_fetch_completed)
	set_process(true)


func _process(delta: float) -> void:
	if not AuthService.is_signed_in():
		return
	if not StudentDatabase.has_pending_sync(AuthService.participant_code()):
		return
	_retry_left -= delta
	if _retry_left > 0.0:
		return
	_retry_left = RETRY_SEC
	push_pending_sync()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		push_pending_sync()


func load_local() -> void:
	load_game()
	await get_tree().process_frame


func flush() -> void:
	save_game()
	await get_tree().process_frame


func save_game() -> void:
	var data: Dictionary = PlayerManager.get_save_data()
	var json_string: String = JSON.stringify(data)
	var path: String = _resolve_save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveService] Failed to open save file for writing: " + path)
		return
	file.store_string(json_string)
	file.close()
	print("[SaveService] Game saved successfully. path=", path)
	_sync_to_cloud()


func load_game() -> void:
	var path: String = _resolve_save_path()
	if not FileAccess.file_exists(path):
		print("[SaveService] No save file found. Starting fresh. path=", path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveService] Failed to open save file for reading: " + path)
		return
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("[SaveService] JSON Parse Error in save file: " + path)
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[SaveService] Save root is not a Dictionary: " + path)
		return
	var parsed: Dictionary = data as Dictionary
	if not _looks_like_save(parsed):
		push_error("[SaveService] Save file is not a player snapshot: " + path)
		return
	PlayerManager.apply_save_data(parsed)
	print("[SaveService] Save loaded successfully. path=", path)


func fetch_cloud_save() -> void:
	if StudentDatabase.has_pending_sync(AuthService.participant_code()):
		push_pending_sync()
		_finish_fetch(false)
		return
	if _fetch_in_flight:
		return
	if not AuthService.is_signed_in():
		_finish_fetch(false)
		return
	var token: String = AuthService.auth_token()
	if token.is_empty() or _http_fetch == null:
		_finish_fetch(false)
		return

	var url: String = _api_base() + SYNC_PATH
	var headers: PackedStringArray = [
		"Authorization: Bearer " + token,
	]
	_fetch_in_flight = true
	var error: Error = _http_fetch.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_warning("[SaveService] Failed to initiate cloud fetch. error=" + str(error))
		_finish_fetch(false)


func wait_for_cloud_fetch() -> bool:
	if _fetch_in_flight:
		return await cloud_fetch_completed
	return _last_fetch_ok


func _on_fetch_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("[SaveService] Cloud fetch failed or offline. response_code=" + str(response_code))
		_finish_fetch(false)
		return

	var json_string: String = body.get_string_from_utf8()
	if json_string.strip_edges().is_empty() or json_string.strip_edges() == "null":
		print("[SaveService] No cloud save exists yet. Loading local fallback.")
		load_game()
		_finish_fetch(true)
		return

	var save_dict: Dictionary = _extract_save_dict(json_string)
	if save_dict.is_empty():
		print("[SaveService] Cloud returned no player snapshot. Loading local fallback.")
		load_game()
		_finish_fetch(true)
		return

	var path: String = _resolve_save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveService] Cloud save parsed but local write failed. Applying in memory.")
		PlayerManager.apply_save_data(save_dict)
		_finish_fetch(true)
		return
	file.store_string(JSON.stringify(save_dict))
	file.close()
	print("[SaveService] Cloud save downloaded and written to disk.")
	load_game()
	_finish_fetch(true)


func _extract_save_dict(json_string: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var parsed: Dictionary = data as Dictionary
	var payload: Variant = parsed.get("payload", parsed)
	if typeof(payload) != TYPE_DICTIONARY:
		return {}
	var save_dict: Dictionary = payload as Dictionary
	if not _looks_like_save(save_dict):
		return {}
	return save_dict


func _looks_like_save(data: Dictionary) -> bool:
	return data.has("mastery_matrix") or data.has("mock_max_stage_cleared")


func _finish_fetch(success: bool) -> void:
	_fetch_in_flight = false
	_last_fetch_ok = success
	cloud_fetch_completed.emit(success)


func push_pending_sync() -> void:
	AuthService.flush_pending_pretests()
	_sync_to_cloud()


func _sync_to_cloud() -> void:
	if not AuthService.is_signed_in():
		return
	var token: String = AuthService.auth_token()
	if token.is_empty():
		return
	if _http_request == null:
		return
	if _sync_in_flight:
		_resync_queued = true
		return

	var data: Dictionary = PlayerManager.get_save_data()
	data["student"] = AuthService.cloud_sync_payload()
	data["module_pretests"] = AuthService.completed_module_pretest_ids()
	var json_string: String = JSON.stringify(data)
	var url: String = _api_base() + SYNC_PATH
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	]

	_sync_in_flight = true
	var error: Error = _http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		_sync_in_flight = false
		_retry_left = RETRY_SEC
		push_warning("[SaveService] Failed to initiate cloud sync. error=" + str(error))


func _on_sync_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
) -> void:
	_sync_in_flight = false
	var ok: bool = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("[SaveService] Cloud sync skipped (offline or network error). result=" + str(result))
		_retry_left = RETRY_SEC
	elif ok:
		print("[SaveService] Cloud sync successful.")
		StudentDatabase.mark_synced(AuthService.participant_code())
		_retry_left = RETRY_SEC
	else:
		push_warning("[SaveService] Cloud sync failed. Code: " + str(response_code))
		_retry_left = RETRY_SEC
	cloud_sync_completed.emit(ok)

	if _resync_queued:
		_resync_queued = false
		_sync_to_cloud()


func _api_base() -> String:
	return str(ProjectSettings.get_setting("levelblue/api_base_url", DEFAULT_API_BASE)).trim_suffix("/")


func _resolve_save_path() -> String:
	var user_id: String = "guest"
	if AuthService.is_signed_in():
		var raw_id: String = AuthService.participant_code().strip_edges()
		var safe_id: String = raw_id.validate_filename()
		if not safe_id.is_empty():
			user_id = safe_id
	return "user://player_save_" + user_id + ".json"
