extends Node
## Autoload singleton, registered as "AuthService".
##
## STUB. The signatures here are final; the bodies are fake. Build every screen
## against this interface now, then replace the bodies with HTTPRequest calls to
## Supabase later without touching a single screen script.
##
## Doing it in this order is deliberate: UI work and backend work can proceed in
## parallel, and you can demo the full navigation flow before the server exists.

signal session_changed(signed_in: bool)

## Result codes returned by sign_in(). Screens match on these rather than
## parsing error strings, so the messages can be translated freely.
enum Result {
	OK,
	INVALID_CREDENTIALS,
	NETWORK_ERROR,
	MUST_CHANGE_PASSWORD,
	UNKNOWN,
}

var _participant_code: String = ""
var _signed_in: bool = false

const SESSION_PATH := "user://session.dat"


func is_signed_in() -> bool:
	return _signed_in


## The anonymised identifier that goes into every telemetry row. Never a name,
## never an email — see the ethics note in the study design doc.
func participant_code() -> String:
	return _participant_code


## Attempts to restore a saved session on boot. Returns true if the player can
## skip the login screen.
func restore_session() -> bool:
	await get_tree().process_frame

	if not FileAccess.file_exists(SESSION_PATH):
		return false

	# STUB: real version validates the stored refresh token against Supabase
	# and signs out if it has been revoked.
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return false
	_participant_code = file.get_line()
	file.close()

	_signed_in = not _participant_code.is_empty()
	if _signed_in:
		session_changed.emit(true)
	return _signed_in


func sign_in(email: String, password: String) -> Result:
	await get_tree().create_timer(0.6).timeout  # STUB: pretend network latency

	if email.is_empty() or password.is_empty():
		return Result.INVALID_CREDENTIALS

	# STUB: any non-empty credentials succeed. A password of "temp" simulates a
	# freshly provisioned account so you can exercise the forced-change flow.
	if password == "temp":
		_participant_code = "lb-stub"
		return Result.MUST_CHANGE_PASSWORD

	_participant_code = "lb-stub"
	_signed_in = true
	_persist()
	session_changed.emit(true)
	return Result.OK


func change_password(_new_password: String) -> Result:
	await get_tree().create_timer(0.6).timeout  # STUB

	_signed_in = true
	_persist()
	session_changed.emit(true)
	return Result.OK


func sign_out() -> void:
	_signed_in = false
	_participant_code = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	session_changed.emit(false)


func _persist() -> void:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not persist session.")
		return
	file.store_line(_participant_code)
	file.close()
