extends BaseScreen
## The "Security Alert" forced password change, shown once on first login.
##
## The rule rows are generated from PasswordRules.RULE_ORDER rather than laid
## out by hand in the scene. Adding a sixth rule then means one line in
## PasswordRules and nothing here.

@onready var _rule_list: VBoxContainer = %RuleList
@onready var _password: LineEdit = %NewPasswordField
@onready var _confirm: LineEdit = %ConfirmPasswordField
@onready var _confirm_hint: Label = %ConfirmHint
@onready var _submit: Button = %SubmitButton

var _rule_rows: Dictionary = {}   # StringName -> Label
var _busy: bool = false


func _ready() -> void:
	_password.secret = true
	_confirm.secret = true
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_confirm.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD

	_build_rule_rows()

	_password.text_changed.connect(func(_t): _refresh())
	_confirm.text_changed.connect(func(_t): _refresh())
	_submit.pressed.connect(_attempt_change)


func on_enter(_args: Dictionary) -> void:
	_refresh()
	_password.grab_focus()


func can_go_back() -> bool:
	# This is a forced step. Returning false blocks the header arrow and the
	# Android back gesture together, so there is no way around it — which is
	# the entire point of a forced password change.
	return false


func _build_rule_rows() -> void:
	for child in _rule_list.get_children():
		child.queue_free()

	for rule in PasswordRules.RULE_ORDER:
		var row := Label.new()
		row.theme_type_variation = &"BodyText"
		_rule_list.add_child(row)
		_rule_rows[rule] = row


func _refresh() -> void:
	var password := _password.text
	var results := PasswordRules.evaluate(password)

	for rule in PasswordRules.RULE_ORDER:
		var row: Label = _rule_rows[rule]
		var passed: bool = results[rule]
		# The marker is text, not an icon, so it survives translation and needs
		# no extra art. Colour alone would fail for colour-blind students.
		var marker := "✓ " if passed else "○ "
		row.text = marker + tr(PasswordRules.RULE_KEYS[rule])
		row.add_theme_color_override(
			"font_color",
			Palette.GREEN if passed else Palette.TEXT_SECONDARY
		)

	var matches := PasswordRules.confirmation_matches(password, _confirm.text)
	# Only complain about a mismatch once they have started typing the
	# confirmation — flagging an empty field as wrong is just noise.
	_confirm_hint.visible = not _confirm.text.is_empty() and not matches
	_confirm_hint.text = tr("PWD_ERR_MISMATCH")

	_submit.disabled = _busy or not PasswordRules.is_acceptable(password, _confirm.text)


func _attempt_change() -> void:
	if _busy:
		return

	_busy = true
	_submit.disabled = true
	_submit.text = tr("PWD_BUSY")

	var result: AuthService.Result = await AuthService.change_password(_password.text)

	_busy = false
	_submit.text = tr("PWD_SUBMIT")

	if result == AuthService.Result.OK:
		_password.text = ""
		_confirm.text = ""
		Router.replace_all(&"dashboard")
	else:
		_confirm_hint.visible = true
		_confirm_hint.text = tr("PWD_ERR_SERVER")
		_refresh()
