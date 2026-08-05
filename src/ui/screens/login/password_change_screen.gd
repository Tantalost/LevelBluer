extends BaseScreen
## Full-screen wrapper for the forced password change modal.
##
## Login shows the same modal as an overlay; this screen exists so the router
## can still navigate here directly if needed.

@onready var _modal: PasswordChangeModal = %PasswordChangeModal


func _ready() -> void:
	_modal.completed.connect(_on_password_changed)


func on_enter(_args: Dictionary) -> void:
	_modal.open()


func on_exit() -> void:
	_modal.close()


func can_go_back() -> bool:
	return false


func _on_password_changed() -> void:
	Router.replace_all(&"dashboard")
