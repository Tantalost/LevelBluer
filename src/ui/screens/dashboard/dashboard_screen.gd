extends BaseScreen
## Temporary placeholder dashboard until the full command centre is built.

@onready var _logout: Button = %LogoutButton
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_logout.pressed.connect(_on_logout_pressed)


func on_enter(_args: Dictionary) -> void:
	_status.text = tr("DASHBOARD_PLACEHOLDER")
	_logout.text = tr("LOGOUT")


func _on_logout_pressed() -> void:
	AuthService.sign_out()
	await SaveService.flush()
	Router.replace_all(&"login")
