extends BaseScreen
## Student access terminal. AuthPanel owns responsive presentation and keyboard clearance.

@onready var _email: LineEdit = %EmailField
@onready var _password: LineEdit = %PasswordField
@onready var _submit: Button = %LoginButton
@onready var _busy_spinner: ProgressBar = %BusySpinner
@onready var _error_panel: PanelContainer = %ErrorPanel
@onready var _error: Label = %ErrorLabel
@onready var _tagline: Label = %TaglineLabel
@onready var _email_label: Label = %EmailLabel
@onready var _password_label: Label = %PasswordLabel
@onready var _password_modal: PasswordChangeModal = %PasswordChangeModal
@onready var _toggle_password: Button = %TogglePassword
@onready var _assistance: Button = %AssistanceButton
@onready var _heading: Label = %Heading
@onready var _intro: Label = %Intro
@onready var _help: Label = %Help
@onready var _recovery_request: HTTPRequest = $RecoveryRequest

var _busy: bool = false
var _recovery_mode: bool = false
var _recovery_sent: bool = false
var _recovery_cooldown_until: int = 0


func _ready() -> void:
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.caret_blink = true
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD

	_email.text_submitted.connect(func(_text: String) -> void:
		if _recovery_mode:
			_attempt_login()
		else:
			_password.grab_focus()
	)
	_password.text_submitted.connect(func(_text: String) -> void: _attempt_login())
	_toggle_password.pressed.connect(_toggle_visibility)
	_submit.pressed.connect(_attempt_login)
	_assistance.pressed.connect(_toggle_recovery)
	_recovery_request.request_completed.connect(_on_assistance_response)
	_password_modal.completed.connect(_on_password_changed)
	AssetManager.bind_texture(get_node_or_null("Background") as CanvasItem, "ui_background")
	AssetManager.bind_texture(find_child("Logo", true, false) as CanvasItem, "ui_logo")

	_apply_copy()


func on_enter(_args: Dictionary) -> void:
	await get_tree().process_frame
	_recovery_mode = false
	_recovery_sent = false
	_hide_error()
	_apply_copy()
	_password.secret = true
	_toggle_password.text = tr("AUTH_SHOW")
	for control: Control in [_email, _password, _submit, _toggle_password]:
		control.focus_mode = Control.FOCUS_ALL
	# Do not open a mobile keyboard before the player chooses a field.
	_submit.grab_focus()


func on_exit() -> void:
	_recovery_request.cancel_request()
	_set_busy(false)
	_password.text = ""
	_password_modal.close()
	_password.secret = true
	_toggle_password.text = tr("AUTH_SHOW")


func can_go_back() -> bool:
	return not _busy and not _password_modal.visible


func _apply_copy() -> void:
	_tagline.text = tr("LOGIN_TAGLINE").replace("\\n", "\n").to_upper()
	_email_label.text = tr("LOGIN_EMAIL_LABEL").to_upper()
	_password_label.text = tr("LOGIN_PASSWORD_LABEL").to_upper()
	_password_label.visible = not _recovery_mode
	(_password.get_parent() as Control).visible = not _recovery_mode
	_heading.text = tr("RECOVERY_TITLE" if _recovery_mode else "LOGIN_WELCOME")
	_intro.text = tr("RECOVERY_INTRO" if _recovery_mode else "LOGIN_INTRO")
	_help.text = tr("RECOVERY_RECEIPT" if _recovery_sent else ("RECOVERY_HELP" if _recovery_mode else "LOGIN_HELP"))
	_help.visible = _recovery_mode
	_email_label.visible = not _recovery_sent
	(_email.get_parent() as Control).visible = not _recovery_sent
	_assistance.text = tr("RECOVERY_BACK" if _recovery_mode else "RECOVERY_FORGOT")
	_refresh_submit_label()


func _toggle_visibility() -> void:
	_password.secret = not _password.secret
	_toggle_password.text = tr("AUTH_SHOW") if _password.secret else tr("AUTH_HIDE")


func _attempt_login() -> void:
	if _busy:
		return
	if _recovery_mode:
		_request_assistance()
		return

	var email: String = _email.text.strip_edges()
	var password: String = _password.text

	if email.is_empty() or password.is_empty():
		_show_error("LOGIN_ERR_EMPTY")
		return

	_hide_error()
	_email.release_focus()
	_password.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_set_busy(true)
	var result: AuthService.Result = await AuthService.sign_in(email, password)
	if result == AuthService.Result.OK:
		SaveService.fetch_cloud_save()
		await SaveService.wait_for_cloud_fetch()
		await PlayerManager.pull_official_bkt()
	_set_busy(false)

	match result:
		AuthService.Result.OK:
			Router.replace_all(&"dashboard")
		AuthService.Result.MUST_CHANGE_PASSWORD:
			_password.text = ""
			for control: Control in [_email, _password, _submit, _toggle_password]:
				control.focus_mode = Control.FOCUS_NONE
			_password_modal.open()
		AuthService.Result.INVALID_CREDENTIALS:
			_show_error("LOGIN_ERR_INVALID")
		AuthService.Result.NETWORK_ERROR:
			_show_error("LOGIN_ERR_NETWORK")
		_:
			_show_error("LOGIN_ERR_UNKNOWN")


func _set_busy(busy: bool) -> void:
	_busy = busy
	_submit.visible = not busy
	_busy_spinner.visible = busy
	_email.editable = not busy
	_password.editable = not busy
	_toggle_password.disabled = busy
	_assistance.disabled = busy
	if not busy:
		_refresh_submit_label()


func _refresh_submit_label() -> void:
	if _busy:
		return
	_submit.text = tr("RECOVERY_SEND" if _recovery_mode else "LOGIN_SUBMIT").to_upper()
	_submit.visible = not _recovery_sent


func _show_error(key: String) -> void:
	_error.text = tr(key)
	_error_panel.visible = true
	_password.text = ""
	if _recovery_mode:
		_email.grab_focus()
	else:
		_password.grab_focus()


func _hide_error() -> void:
	_error.text = ""
	_error_panel.visible = false


func _on_password_changed() -> void:
	await SaveService.wait_for_cloud_fetch()
	Router.replace_all(&"dashboard")


func _toggle_recovery() -> void:
	if _busy:
		return
	_recovery_mode = not _recovery_mode
	_recovery_sent = false
	_password.text = ""
	_hide_error()
	_apply_copy()
	_assistance.grab_focus()


func _request_assistance() -> void:
	if _recovery_sent or _busy:
		return
	if Time.get_ticks_msec() < _recovery_cooldown_until:
		_show_error("RECOVERY_WAIT")
		return
	var email: String = _email.text.strip_edges().to_lower()
	var validator: RegEx = RegEx.new()
	validator.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	if email.length() > 254 or validator.search(email) == null:
		_show_error("RECOVERY_EMAIL_ERROR")
		return
	var base_url: String = str(ProjectSettings.get_setting("levelblue/recovery_api_base_url", "")).trim_suffix("/")
	if not base_url.begins_with("https://"):
		_show_error("RECOVERY_UNAVAILABLE")
		return
	_hide_error()
	_email.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_set_busy(true)
	var start_error: Error = _recovery_request.request(base_url + "/api/student-recovery/request", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"email": email}))
	if start_error != OK:
		_set_busy(false)
		_show_error("LOGIN_ERR_NETWORK")
		return


func _on_assistance_response(result_code: int, status_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _recovery_mode or not _busy:
		return
	_set_busy(false)
	if result_code != HTTPRequest.RESULT_SUCCESS:
		_show_error("RECOVERY_NETWORK_ERROR")
	elif status_code == 202:
		_recovery_sent = true
		_recovery_cooldown_until = Time.get_ticks_msec() + 60000
		_apply_copy()
		_assistance.grab_focus()
	elif status_code == 429:
		_recovery_cooldown_until = Time.get_ticks_msec() + 900000
		_show_error("RECOVERY_RATE_LIMIT")
	else:
		_show_error("RECOVERY_UNAVAILABLE")
