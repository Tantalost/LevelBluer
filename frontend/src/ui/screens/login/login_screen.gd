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

var _busy: bool = false


func _ready() -> void:
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.caret_blink = true
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD

	_email.text_submitted.connect(func(_text: String) -> void: _password.grab_focus())
	_password.text_submitted.connect(func(_text: String) -> void: _attempt_login())
	_toggle_password.pressed.connect(_toggle_visibility)
	_submit.pressed.connect(_attempt_login)
	_password_modal.completed.connect(_on_password_changed)
	AssetManager.bind_texture(get_node_or_null("Background") as CanvasItem, "ui_background")
	AssetManager.bind_texture(find_child("Logo", true, false) as CanvasItem, "ui_logo")

	_apply_copy()


func on_enter(_args: Dictionary) -> void:
	await get_tree().process_frame
	_hide_error()
	_apply_copy()
	_password.secret = true
	_toggle_password.text = tr("AUTH_SHOW")
	for control: Control in [_email, _password, _submit, _toggle_password]:
		control.focus_mode = Control.FOCUS_ALL
	# Do not open a mobile keyboard before the player chooses a field.
	_submit.grab_focus()


func on_exit() -> void:
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
	_refresh_submit_label()


func _toggle_visibility() -> void:
	_password.secret = not _password.secret
	_toggle_password.text = tr("AUTH_SHOW") if _password.secret else tr("AUTH_HIDE")


func _attempt_login() -> void:
	if _busy:
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
	if not busy:
		_refresh_submit_label()


func _refresh_submit_label() -> void:
	if _busy:
		return
	_submit.text = tr("LOGIN_SUBMIT").to_upper()


func _show_error(key: String) -> void:
	_error.text = tr(key)
	_error_panel.visible = true
	_password.text = ""
	_password.grab_focus()


func _hide_error() -> void:
	_error.text = ""
	_error_panel.visible = false


func _on_password_changed() -> void:
	await SaveService.wait_for_cloud_fetch()
	Router.replace_all(&"dashboard")
