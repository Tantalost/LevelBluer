extends "res://src/gameplay/decision/story_phone.gd"
signal pause_requested
## Laptop presentation shares the established evidence gates, logs and input guards.
## This prop owns no assessment state, combat state or network connection.

func _ready() -> void:
	super._ready()
	_shell.name = "LaptopScreen"
	_guide_panel.name = "LaptopChecklist"
	_guide.accessibility_name = "Laptop investigation checklist"
	_close.accessibility_name = "Close laptop and return to story"
	var frame: StyleBoxEmpty = StyleBoxEmpty.new()
	frame.content_margin_left = 26
	frame.content_margin_right = 26
	frame.content_margin_top = 34
	frame.content_margin_bottom = 20
	_shell.add_theme_stylebox_override("panel", frame)
	var pause: Button = UI.button("PAUSE", func() -> void: pause_requested.emit())
	pause.size_flags_horizontal = SIZE_EXPAND_FILL
	pause.custom_minimum_size.x = 0
	_nav.add_child(pause)

func configure(data: Dictionary) -> void:
	var settings: Dictionary = data.duplicate(true)
	settings["device_name"] = "laptop"
	settings["message_app"] = "Messages"
	settings["contacts_origin"] = str(data.get("contacts_origin", "Campus directory saved during enrollment"))
	var titles: Dictionary = {"home": "DESKTOP", "mail": "MESSAGES / SMS SYNC", "contacts": "CAMPUS DIRECTORY", "pages": "CAMPUS PORTAL", "lock": "ALEX'S LAPTOP"}
	titles.merge(data.get("app_titles", {}) as Dictionary, true)
	settings["app_titles"] = titles
	super.configure(settings)
	_status.text = "CAMPUS WORKSPACE / OFFLINE STORY"

func _checklist_tasks() -> Array[Dictionary]:
	var tasks: Array[Dictionary] = super._checklist_tasks()
	for task: Dictionary in tasks:
		task["text"] = str(task.text).replace("phone", "laptop").replace("email", "message").replace("Mail", "Messages")
	return tasks

func _fit_shell() -> void:
	if not is_instance_valid(_shell) or not is_instance_valid(_nav):
		return
	var factor: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var nav_height: float = maxf(52.0, 48.0 / factor)
	# Containers can retain larger button metrics during a viewport transition.
	nav_height = maxf(nav_height, _nav.get_combined_minimum_size().y)
	var gap: float = 20.0
	var landscape: bool = size.x >= size.y
	var guide_width: float = minf(280.0 / factor, size.x * 0.27)
	var guide_height: float = size.y - 130.0 if landscape else size.y * 0.26
	var width: float = size.x - 40.0 - (guide_width + gap if landscape else 0.0)
	var height: float = size.y - nav_height - 102.0 - (0.0 if landscape else guide_height + gap)
	_shell.position = Vector2(20.0 + (guide_width + gap if landscape else 0.0), 16.0)
	_shell.size = Vector2(width, maxf(160.0, height))
	_nav.position = Vector2(_shell.position.x, _shell.position.y + _shell.size.y + 66.0)
	_nav.size = Vector2(width, nav_height)
	_guide_panel.position = Vector2(20.0, 106.0) if landscape else Vector2(20.0, _nav.position.y + nav_height + gap)
	_guide_panel.size = Vector2(guide_width if landscape else width, guide_height)
	_shell.queue_redraw()

func _draw_frame() -> void:
	if not is_instance_valid(_shell):
		return
	var width: float = _shell.size.x
	var height: float = _shell.size.y
	_shell.draw_style_box(UI.box(Color("173058"), Color("8FF0E6"), 0), Rect2(Vector2.ZERO, _shell.size))
	_shell.draw_rect(Rect2(Vector2(10, 22), _shell.size - Vector2(20, 32)), Color("0A1730"))
	_shell.draw_circle(Vector2(width * 0.5, 12), 3, Color("4FE0D4"))
	_shell.draw_colored_polygon(PackedVector2Array([Vector2(0, height + 2), Vector2(width, height + 2), Vector2(width + 8, height + 54), Vector2(-8, height + 54)]), Color("173058"))
	for row: int in 3:
		for key: int in 12:
			_shell.draw_rect(Rect2(Vector2(22 + key * (width - 44) / 12.0, height + 8 + row * 10), Vector2((width - 68) / 12.0, 6)), Color("8FF0E6", 0.45))
	_shell.draw_rect(Rect2(Vector2(width * 0.40, height + 41), Vector2(width * 0.20, 8)), Color("4F8CFF", 0.6))
