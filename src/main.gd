extends Control
## Root of Main.tscn. The only scene ever loaded directly by the engine —
## everything after this is pushed by the Router into ScreenHost.

@onready var _screen_host: Control = %ScreenHost
@onready var _quit_dialog: ConfirmationDialog = %QuitDialog


func _ready() -> void:
	Router.register_host(_screen_host)
	Router.quit_requested.connect(_on_quit_requested)
	_quit_dialog.confirmed.connect(_on_quit_confirmed)

	Router.replace_all(&"splash")


func _on_quit_requested() -> void:
	# Reached when the player presses back on the root screen. Confirming
	# matters here: students are mid-session on a shared classroom device, and
	# an accidental back gesture that silently kills the app loses their
	# unsynced attempt log.
	_quit_dialog.dialog_text = tr("QUIT_CONFIRM_BODY")
	_quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	# Flush anything still buffered before the process goes away.
	await SaveService.flush()
	get_tree().quit()
