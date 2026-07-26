extends BaseScreen
## Login screen.
##
## The interesting problem here is not the form, it is the Android virtual
## keyboard. In landscape it covers roughly half the screen height, and this
## form is vertically centred — without the handling below, the password field
## sits behind the keyboard and the player cannot see what they are typing.

@onready var _form: Control = %FormRoot
@onready var _email: LineEdit = %EmailField
@onready var _password: LineEdit = %PasswordField
@onready var _submit: Button = %LoginButton
@onready var _error: Label = %ErrorLabel

var _form_home_y: float = 0.0
var _busy: bool = false


func _ready() -> void:
	# Configure the fields in code so the settings live next to the reasoning.
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.caret_blink = true
	_password.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD

	_email.text_submitted.connect(func(_t): _password.grab_focus())
	_password.text_submitted.connect(func(_t): _attempt_login())
	_submit.pressed.connect(_attempt_login)

	for field in [_email, _password]:
		field.focus_entered.connect(func(): set_process(true))
		field.focus_exited.connect(_on_field_focus_exited)

	set_process(false)


func on_enter(_args: Dictionary) -> void:
	_form_home_y = _form.position.y
	_error.text = ""
	_error.visible = false
	_email.grab_focus()


func on_exit() -> void:
	# Never leave credentials sitting in memory on a shared classroom device.
	_password.text = ""


func _process(_delta: float) -> void:
	_track_keyboard()


func _on_field_focus_exited() -> void:
	# Give focus a frame to land on the other field before deciding the
	# keyboard is gone, or tabbing between fields causes the form to bounce.
	await get_tree().process_frame
	if _email.has_focus() or _password.has_focus():
		return
	set_process(false)
	_slide_form(_form_home_y)


func _track_keyboard() -> void:
	var keyboard_px := DisplayServer.virtual_keyboard_get_height()
	if keyboard_px <= 0:
		_slide_form(_form_home_y)
		return

	# The keyboard height comes back in device pixels; our layout is in
	# stretched viewport units. Convert, or the shift is wrong by exactly the
	# stretch factor.
	var window_height := DisplayServer.window_get_size().y
	if window_height <= 0:
		return
	var scale := get_viewport().get_visible_rect().size.y / float(window_height)
	var keyboard_units := keyboard_px * scale

	# Lift by half the keyboard height rather than all of it — enough to clear
	# the fields without shoving the logo off the top of the screen.
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
			# replace_all, not push — backing out of the dashboard into a login
			# form still holding a typed password would be wrong twice over.
			Router.replace_all(&"dashboard")
		AuthService.Result.MUST_CHANGE_PASSWORD:
			Router.replace_all(&"password_change")
		AuthService.Result.INVALID_CREDENTIALS:
			_show_error("LOGIN_ERR_INVALID")
		AuthService.Result.NETWORK_ERROR:
			_show_error("LOGIN_ERR_NETWORK")
		_:
			_show_error("LOGIN_ERR_UNKNOWN")


func _set_busy(busy: bool) -> void:
	_busy = busy
	_submit.disabled = busy
	_email.editable = not busy
	_password.editable = not busy
	_submit.text = tr("LOGIN_BUSY") if busy else tr("LOGIN_SUBMIT")


func _show_error(key: String) -> void:
	# Deliberately generic on invalid credentials: never reveal whether it was
	# the address or the password that was wrong. Given what this app teaches,
	# getting that detail right is worth the two seconds it costs.
	_error.text = tr(key)
	_error.visible = true
	_password.text = ""
	_password.grab_focus()
