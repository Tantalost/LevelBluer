class_name PasswordChangeModal
extends Control
## First-login account setup, using the same terminal chrome as student login.
##
## Shown on first login when the student still has a temporary password.
## Validation rules live in PasswordRules; this file only renders and submits.

signal completed

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _new_label: Label = %NewPasswordLabel
@onready var _confirm_label: Label = %ConfirmPasswordLabel
@onready var _new_password: LineEdit = %NewPasswordField
@onready var _confirm: LineEdit = %ConfirmPasswordField
@onready var _toggle_new: Button = %ToggleNewPassword
@onready var _toggle_confirm: Button = %ToggleConfirmPassword
@onready var _rule_list: VBoxContainer = %RuleList
@onready var _error_panel: PanelContainer = %ErrorPanel
@onready var _error: Label = %ErrorLabel
@onready var _submit: Button = %SubmitButton
@onready var _busy_spinner: ProgressBar = %BusySpinner
@onready var _match: Label = %MatchLabel

var _rule_rows: Dictionary = {}
var _rule_lights: Dictionary = {}
var _busy: bool = false
var _show_new: bool = false
var _show_confirm: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_new_password.secret = true
	_confirm.secret = true
	_new_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_confirm.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD

	_build_rule_rows()
	_apply_copy()

	_new_password.text_changed.connect(func(_text: String) -> void: _refresh())
	_confirm.text_changed.connect(func(_text: String) -> void: _refresh())
	_new_password.text_submitted.connect(func(_text: String) -> void: _confirm.grab_focus())
	_confirm.text_submitted.connect(func(_text: String) -> void: _attempt_change())
	_toggle_new.pressed.connect(_toggle_new_visibility)
	_toggle_confirm.pressed.connect(_toggle_confirm_visibility)
	_submit.pressed.connect(_attempt_change)


func open() -> void:
	visible = true
	_show_new = false
	_show_confirm = false
	_new_password.secret = true
	_confirm.secret = true
	_new_password.text = ""
	_confirm.text = ""
	_toggle_new.text = tr("AUTH_SHOW")
	_toggle_confirm.text = tr("AUTH_SHOW")
	_hide_error()
	_set_busy(false)
	_refresh()
	_toggle_new.grab_focus()


func close() -> void:
	visible = false
	_new_password.text = ""
	_confirm.text = ""
	_new_password.secret = true
	_confirm.secret = true
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func _apply_copy() -> void:
	_title.text = tr("PWD_TITLE").to_upper()
	_subtitle.text = tr("PWD_SUBTITLE").to_upper()
	_new_label.text = tr("PWD_NEW_LABEL").to_upper()
	_confirm_label.text = tr("PWD_CONFIRM_LABEL").to_upper()
	_new_password.placeholder_text = tr("PWD_NEW_PLACEHOLDER")
	_confirm.placeholder_text = tr("PWD_CONFIRM_PLACEHOLDER")
	_refresh_submit_label()


func _build_rule_rows() -> void:
	for child: Node in _rule_list.get_children():
		child.queue_free()

	for rule: StringName in PasswordRules.RULE_ORDER:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		_rule_list.add_child(line)
		var light: ColorRect = ColorRect.new()
		light.custom_minimum_size = Vector2(8, 8)
		light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(light)
		_rule_lights[rule] = light
		var row: Label = Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(row)
		_rule_rows[rule] = row


func _refresh() -> void:
	var password: String = _new_password.text
	var results: Dictionary = PasswordRules.evaluate(password)

	for rule: StringName in PasswordRules.RULE_ORDER:
		var row: Label = _rule_rows[rule]
		var passed: bool = results[rule]
		var light: ColorRect = _rule_lights[rule] as ColorRect
		light.color = Color("33d17a") if passed else Color("173058")
		var marker: String = "[OK] " if passed else "[  ] "
		row.text = marker + tr(PasswordRules.RULE_KEYS[rule])
		row.add_theme_color_override(
			"font_color",
			Color("33d17a") if passed else Color("a0b7bb")
		)
	var matches: bool = PasswordRules.confirmation_matches(password, _confirm.text)
	_match.text = tr("PWD_MATCH") if matches else tr("PWD_CONFIRM_HELP" if _confirm.text.is_empty() else "PWD_ERR_MISMATCH")
	_match.add_theme_color_override("font_color", Color("33d17a") if matches else Color("a0b7bb"))


func _toggle_new_visibility() -> void:
	_show_new = not _show_new
	_new_password.secret = not _show_new
	_toggle_new.text = tr("AUTH_HIDE") if _show_new else tr("AUTH_SHOW")


func _toggle_confirm_visibility() -> void:
	_show_confirm = not _show_confirm
	_confirm.secret = not _show_confirm
	_toggle_confirm.text = tr("AUTH_HIDE") if _show_confirm else tr("AUTH_SHOW")


func _attempt_change() -> void:
	if _busy:
		return

	var password: String = _new_password.text
	var confirmation: String = _confirm.text

	if password.is_empty() or confirmation.is_empty():
		_show_error("PWD_ERR_EMPTY")
		return
	if not PasswordRules.all_satisfied(PasswordRules.evaluate(password)):
		_show_error("PWD_ERR_WEAK")
		return
	if password != confirmation:
		_show_error("PWD_ERR_MISMATCH")
		return

	_hide_error()
	_new_password.release_focus()
	_confirm.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_set_busy(true)

	var result: AuthService.Result = await AuthService.change_password(password)

	_set_busy(false)

	if result == AuthService.Result.OK:
		close()
		completed.emit()
	else:
		_show_error("PWD_ERR_SERVER")


func _set_busy(busy: bool) -> void:
	_busy = busy
	_submit.visible = not busy
	_busy_spinner.visible = busy
	_new_password.editable = not busy
	_confirm.editable = not busy
	_toggle_new.disabled = busy
	_toggle_confirm.disabled = busy
	if not busy:
		_refresh_submit_label()


func _refresh_submit_label() -> void:
	if _busy:
		return
	_submit.text = tr("PWD_SECURE_SUBMIT").to_upper()


func _show_error(key: String) -> void:
	_error.text = tr(key)
	_error_panel.visible = true


func _hide_error() -> void:
	_error.text = ""
	_error_panel.visible = false
