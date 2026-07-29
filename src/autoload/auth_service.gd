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

var _participant_code: String = ""
var _token: String = ""
var _signed_in: bool = false
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)


func is_signed_in() -> bool:
	return _signed_in


func auth_token() -> String:
	return _token


## The anonymised identifier that goes into every telemetry row. Never a name,
## never an email — see the ethics note in the study design doc.
func participant_code() -> String:
	return _participant_code


func restore_session() -> bool:
	await get_tree().process_frame

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

	if _signed_in and not _token.is_empty() and not _participant_code.is_empty():
		session_changed.emit(true)
		return true

	return false


func sign_in(email: String, password: String) -> Result:
	if email.is_empty() or password.is_empty():
		return Result.INVALID_CREDENTIALS

	var body := {"email": email.strip_edges(), "password": password}
	var parsed: Variant = await _post_json("/api/auth/login", body)
	if parsed == null:
		return Result.NETWORK_ERROR

	if typeof(parsed) != TYPE_DICTIONARY:
		return Result.UNKNOWN

	if parsed.has("error") or parsed.has("detail"):
		return Result.INVALID_CREDENTIALS

	_token = str(parsed.get("token", ""))
	var user: Dictionary = parsed.get("user", {})
	_participant_code = str(user.get("_id", user.get("id", "")))

	if _token.is_empty() or _participant_code.is_empty():
		push_warning("AuthService login response missing token or user id: %s" % JSON.stringify(parsed))
		return Result.UNKNOWN

	if bool(parsed.get("mustChangePassword", false)):
		_signed_in = false
		_persist(false, true)
		return Result.MUST_CHANGE_PASSWORD

	_signed_in = true
	_persist(true, false)
	session_changed.emit(true)
	return Result.OK


func change_password(new_password: String) -> Result:
	if _token.is_empty():
		return Result.UNKNOWN

	var body := {"newPassword": new_password}
	var parsed: Variant = await _post_json(
		"/api/auth/change-password",
		body,
		true,
	)
	if parsed == null:
		return Result.NETWORK_ERROR

	if typeof(parsed) != TYPE_DICTIONARY:
		return Result.UNKNOWN

	if parsed.has("error"):
		return Result.UNKNOWN

	_signed_in = true
	_persist(true, false)
	session_changed.emit(true)
	return Result.OK


func sign_out() -> void:
	_signed_in = false
	_token = ""
	_participant_code = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	session_changed.emit(false)


func _api_base() -> String:
	return str(ProjectSettings.get_setting("levelblue/api_base_url", DEFAULT_API_BASE))


func _post_json(path: String, body: Dictionary, authorized: bool = false) -> Variant:
	var url := "%s%s" % [_api_base().trim_suffix("/"), path]
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authorized and not _token.is_empty():
		headers.append("Authorization: Bearer %s" % _token)

	var json_body := JSON.stringify(body)
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		push_warning("AuthService request failed to start: %s" % err)
		return null

	var completed: Array = await _http.request_completed
	var result_code: int = completed[0]
	var response_code: int = completed[1]
	var response_body: PackedByteArray = completed[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		push_warning("AuthService network error: HTTPRequest result %s" % result_code)
		return null

	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}

	if response_code == 401 and not authorized:
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {"error": "Unauthorized"}

	if response_code < 200 or response_code >= 300:
		push_warning("AuthService HTTP %s: %s" % [response_code, text])
		return parsed if typeof(parsed) == TYPE_DICTIONARY else null

	return parsed


func _persist(signed_in: bool, pending_password_change: bool) -> void:
	var payload := {
		"token": _token,
		"participant_code": _participant_code,
		"signed_in": signed_in,
		"pending_password_change": pending_password_change,
	}
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not persist session.")
		return
	file.store_string(JSON.stringify(payload))
	file.close()
