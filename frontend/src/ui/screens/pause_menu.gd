class_name PauseMenu
extends Control
## Match pause overlay. Root is PROCESS_MODE_ALWAYS so Resume still receives clicks.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %TitleLabel
@onready var _btn_resume: Button = %BtnResume
@onready var _btn_settings: Button = %BtnSettings
@onready var _btn_retreat: Button = %BtnRetreat


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.color = Color(Palette.BG_DEEP, 0.78)
	_style_panel()
	_style_label(_title, Palette.TEXT_PRIMARY, 16)
	_title.text = "SYSTEM PAUSED"
	_style_button(_btn_resume, Palette.CYAN, "RESUME")
	_style_button(_btn_settings, Palette.GOLD, "SETTINGS")
	_style_button(_btn_retreat, Palette.RED, "RETREAT")
	_btn_resume.pressed.connect(_on_resume_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_retreat.pressed.connect(_on_retreat_pressed)


func pause_game() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	tree.paused = true
	show()


func resume_game() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	resume_game()


func _on_settings_pressed() -> void:
	resume_game()
	Engine.time_scale = 1.0
	Router.open_settings()


func _on_retreat_pressed() -> void:
	resume_game()
	Engine.time_scale = 1.0
	Router.open_dashboard()


func _style_panel() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.BG_PANEL
	box.border_color = Palette.CYAN
	box.set_border_width_all(2)
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 22.0
	box.content_margin_bottom = 22.0
	_panel.add_theme_stylebox_override("panel", box)


func _style_label(label: Label, color: Color, size_px: int) -> void:
	if ResourceLoader.exists(FONT_PATH):
		var font: FontFile = load(FONT_PATH) as FontFile
		if font != null:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)


func _style_button(button: Button, accent: Color, caption: String) -> void:
	button.text = caption
	button.custom_minimum_size = Vector2(280, 48)
	if ResourceLoader.exists(FONT_PATH):
		var font: FontFile = load(FONT_PATH) as FontFile
		if font != null:
			button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.16)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent, 0.32)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
