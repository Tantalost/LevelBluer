extends BaseScreen
## Login screen — matches the React Native prototype layout.
##
## The interesting problem here is not the form, it is the Android virtual
## keyboard. In landscape it covers roughly half the screen height, and this
## form is vertically centred — without the handling below, the password field
## sits behind the keyboard and the player cannot see what they are typing.

@onready var _form: Control = %FormRoot
@onready var _email: LineEdit = %EmailField
@onready var _password: LineEdit = %PasswordField
@onready var _submit: Button = %LoginButton
@onready var _busy_spinner: ProgressBar = %BusySpinner
@onready var _error_panel: PanelContainer = %ErrorPanel
@onready var _error: Label = %ErrorLabel
@onready var _tagline: Label = %TaglineLabel
@onready var _email_label: Label = %EmailLabel
@onready var _password_label: Label = %PasswordLabel
@onready var _password_modal = %PasswordChangeModal

var _form_home_y: float = 0.0
var _busy: bool = false
var _keyboard_lift_supported: bool = false


func _ready() -> void:
	_keyboard_lift_supported = DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)

	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.caret_blink = true
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD

	_email.text_submitted.connect(func(_t): _password.grab_focus())
	_password.text_submitted.connect(func(_t): _attempt_login())
	_submit.pressed.connect(_attempt_login)
	_password_modal.completed.connect(_on_password_changed)

	for field in [_email, _password]:
		field.focus_entered.connect(_on_field_focus_entered)
		field.focus_exited.connect(_on_field_focus_exited)

	set_process(false)


func on_enter(_args: Dictionary) -> void:
	await get_tree().process_frame
	_form_home_y = _form.position.y
	_hide_error()
	_apply_copy()
	_email.grab_focus()


func on_exit() -> void:
	_password.text = ""
	_password_modal.close()
	_slide_form(_form_home_y)


func can_go_back() -> bool:
	return not _password_modal.visible


func _apply_copy() -> void:
	_tagline.text = tr("LOGIN_TAGLINE").to_upper()
	_email_label.text = tr("LOGIN_EMAIL_LABEL").to_upper()
	_password_label.text = tr("LOGIN_PASSWORD_LABEL").to_upper()
	_refresh_submit_label()


func _process(_delta: float) -> void:
	_track_keyboard()


func _on_field_focus_entered() -> void:
	if _keyboard_lift_supported:
		set_process(true)


func _on_field_focus_exited() -> void:
	await get_tree().process_frame
	if _email.has_focus() or _password.has_focus():
		return
	set_process(false)
	_slide_form(_form_home_y)


func _track_keyboard() -> void:
	if not _keyboard_lift_supported:
		return

	var keyboard_px := DisplayServer.virtual_keyboard_get_height()
	if keyboard_px <= 0:
		_slide_form(_form_home_y)
		return

	var window_height := DisplayServer.window_get_size().y
	if window_height <= 0:
		return
	var viewport_scale := get_viewport().get_visible_rect().size.y / float(window_height)
	var keyboard_units := keyboard_px * viewport_scale
	_slide_form(_form_home_y - keyboard_units * 0.5)


func _slide_form(target_y: float) -> void:
	if is_equal_approx(_form.position.y, target_y):
		return
	var tween := create_tween()
	tween.tween_property(_form, "position:y", target_y, 0.18) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _attempt_login() -> void:
	if _busy:
		return

	var email := _email.text.strip_edges()
	var password := _password.text

	if email.is_empty() or password.is_empty():
		_show_error("LOGIN_ERR_EMPTY")
		return

	_set_busy(true)
	var result: AuthService.Result = await AuthService.sign_in(email, password)
	_set_busy(false)

	match result:
		AuthService.Result.OK:
			Router.replace_all(&"dashboard")
		AuthService.Result.MUST_CHANGE_PASSWORD:
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
	if not busy:
		_refresh_submit_label()


func _refresh_submit_label() -> void:
	if _busy:
		return
	_submit.text = "▶  %s" % tr("LOGIN_SUBMIT")


func _show_error(key: String) -> void:
	_error.text = "⚠  %s" % tr(key)
	_error_panel.visible = true
	_password.text = ""
	_password.grab_focus()


func _hide_error() -> void:
	_error.text = ""
	_error_panel.visible = false


func _on_password_changed() -> void:
	Router.replace_all(&"dashboard")
