extends CanvasLayer
## Live-map result presentation. It only reports data and emits the selected action.
signal action_requested(action: StringName)
const ActionButton = preload("res://src/ui/screens/victory/defeat_action_button.gd")
const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const REVEAL_COMPLETE := 3.6
var elapsed := 0.0
var results_ready := false
var _leaving := false
var _won := false
var _root: Control
var _grade: ShaderMaterial
var _title: Label
var _stage: Label
var _reward_title: Label
var _credits: Label
var _wave: Label
var _kills: Label
var _advisory: Label
var _buttons: Array[Button] = []
var _button_actions: Array[StringName] = [&"upgrade", &"restart", &"lessons", &"back"]
var _skip: Button

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade = ShaderMaterial.new()
	_grade.shader = preload("res://src/ui/screens/victory/defeat_tint.gdshader")
	tint.material = _grade
	_root.add_child(tint)
	_stage = _label(Color("cda2b7"))
	_title = _label(Color("ff648a"))
	_title.text = "BASE DESTROYED"
	_reward_title = _label(Color("d7c6de"))
	_reward_title.text = "CREDITS ACQUIRED"
	_credits = _label(Color("ffe1ac"))
	_wave = _label(Color("e3d3e4"))
	_kills = _label(Color("e3d3e4"))
	_advisory = _label(Color("c5aabb"))
	for caption: String in ["UPGRADE", "RESTART", "LESSONS", "BACK"]:
		var button := ActionButton.new()
		button.text = caption
		button.primary = _buttons.is_empty()
		button.disabled = true
		button.pressed.connect(_choose_button.bind(_buttons.size()))
		_root.add_child(button)
		_buttons.append(button)
	_skip = Button.new()
	_skip.text = "SKIP >"
	_skip.flat = true
	_skip.add_theme_font_override("font", FONT)
	_skip.add_theme_font_size_override("font_size", 10)
	_skip.pressed.connect(finish_reveal)
	_root.add_child(_skip)
	_root.resized.connect(_layout)
	_layout()
	_update_reveal()

func configure(data: Dictionary) -> void:
	_won = bool(data.get("won", false))
	if _won:
		_configure_clear(data)
	else:
		_configure_defeat(data)
	for i in _buttons.size():
		var action_button: Button = _buttons[i]
		action_button.set("success", _won)
		action_button.set("primary", i == 0)
		action_button.queue_redraw()
	_layout()
	_update_reveal()


func _configure_clear(data: Dictionary) -> void:
	var stage: int = int(data.get("stage", 1))
	var final_stage: bool = bool(data.get("final_stage", stage >= 10))
	_stage.text = str(data.get("subtitle", "MAP A%d  /  DEFENSE SECURED" % stage))
	_title.text = str(data.get("title", "STAGE CLEARED"))
	_reward_title.text = "CREDITS ACQUIRED"
	_credits.text = "+%d CR" % int(data.get("credits", 0))
	_wave.text = "%s   %d" % [str(data.get("kills_label", "THREATS CLEARED")), int(data.get("kills", 0))]
	_kills.text = "ACCURACY   %d%%" % int(round(float(data.get("accuracy", 1.0)) * 100.0))
	_advisory.text = str(data.get("advisory", "MODULE COMPLETE" if final_stage else "NEXT STAGE UNLOCKED"))
	_buttons[0].text = "CERTIFICATE" if final_stage else "NEXT STAGE"
	_buttons[1].text = "REPLAY"
	_buttons[2].text = "UPGRADES"
	_buttons[3].text = "BACK"
	var primary_action: StringName = &"certificate" if final_stage else &"next"
	_button_actions = [primary_action, &"restart", &"upgrade", &"back"]
	_set_label_color(_stage, Palette.CYAN_300)
	_set_label_color(_title, Palette.SUCCESS)
	_set_label_color(_reward_title, Palette.CREAM)
	_set_label_color(_credits, Palette.WARNING)
	_set_label_color(_wave, Palette.CREAM)
	_set_label_color(_kills, Palette.CREAM)
	_set_label_color(_advisory, Palette.CYAN_300)
	_grade.set_shader_parameter("grade_color", _rgb(Palette.SUCCESS))
	_grade.set_shader_parameter("edge_color", _rgb(Palette.TEAL_900))
	_grade.set_shader_parameter("impact_color", _rgb(Palette.CYAN_400))


func _configure_defeat(data: Dictionary) -> void:
	_stage.text = str(data.get("subtitle", "MAP A%d  /  DEFENSE FAILED" % int(data.get("stage", 1))))
	_title.text = str(data.get("title", "BASE DESTROYED"))
	if bool(data.get("is_decision", false)):
		# Decision-stage defeat: 2 buttons, body text, no credits/wave/kills rows.
		_reward_title.text = ""
		_credits.text = ""
		_wave.text = ""
		_kills.text = ""
		_advisory.text = str(data.get("body", ""))
		_buttons[0].text = str(data.get("retry_label", "RETRY"))
		_buttons[1].text = str(data.get("exit_label", "EXIT MISSION"))
		_buttons[2].text = ""
		_buttons[3].text = ""
		_button_actions = [&"restart", &"back", &"", &""]
		# Primary is RETRY; EXIT MISSION is secondary.
		_buttons[0].set("primary", true)
		_buttons[1].set("primary", false)
		_buttons[2].visible = false
		_buttons[3].visible = false
		_set_label_color(_title, Color("ff648a"))
	else:
		_reward_title.text = "CREDITS ACQUIRED"
		_credits.text = "+%d CR" % int(data.get("credits", 0))
		_wave.text = "%s   %d / %d" % [str(data.get("wave_label", "WAVE REACHED")), data.get("wave", 1), data.get("waves", 1)]
		_kills.text = "THREATS CLEARED   %d" % int(data.get("kills", 0))
		_advisory.text = str(data.get("tip", "Upgrade your nodes, then redeploy."))
		_buttons[0].text = "UPGRADE"
		_buttons[1].text = str(data.get("retry_label", "RESTART"))
		_buttons[2].text = "LESSONS"
		_buttons[3].text = "BACK"
		_buttons[2].visible = true
		_buttons[3].visible = true
		_button_actions = [&"upgrade", &"restart", &"lessons", &"back"]


func _set_label_color(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)

func _label(ink: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_shadow_color", Color("140d20"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	_root.add_child(label)
	return label

func _layout() -> void:
	var area := _root.size
	var factor := minf(area.x / 1280.0, area.y / 720.0)
	_place(_stage, 0.055, 0.035, 0.8, 10 * factor)
	_place(_title, 0.14, 0.10, 0.94, 36 * factor)
	_place(_reward_title, 0.30, 0.04, 0.65, 13 * factor)
	_place(_credits, 0.355, 0.065, 0.65, 25 * factor)
	_place(_wave, 0.44, 0.04, 0.65, 12 * factor)
	_place(_kills, 0.495, 0.04, 0.65, 12 * factor)
	_place(_advisory, 0.575, 0.085, 0.66, 10 * factor)
	_advisory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in _buttons.size():
		var button := _buttons[i]
		var w := 240.0 if i == 0 else 164.0
		button.size = Vector2(w, 52 if i == 0 else 42) * factor
		button.position = Vector2((area.x - button.size.x) * 0.5, area.y * (0.74 if i == 0 else 0.85))
		button.add_theme_font_size_override("font_size", maxi(9, int((15 if i == 0 else 11) * factor)))
	_buttons[2].position = Vector2(26, area.y - _buttons[2].size.y - 24)
	_buttons[3].position = Vector2(area.x - _buttons[3].size.x - 26, area.y - _buttons[3].size.y - 24)
	_skip.position = Vector2(area.x - 110, 22)
	_skip.size = Vector2(90, 32)

func _place(label: Label, y: float, height: float, width: float, font_size: float) -> void:
	label.size = _root.size * Vector2(width, height)
	label.position = Vector2((_root.size.x - label.size.x) * 0.5, _root.size.y * y)
	label.pivot_offset = label.size * 0.5
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))

func _process(delta: float) -> void:
	elapsed += delta
	_update_reveal()

func _update_reveal() -> void:
	_grade.set_shader_parameter("amount", clampf(elapsed / 0.45, 0, 1))
	_grade.set_shader_parameter("impact", maxf(0, 1 - elapsed / 0.28) * 0.7)
	_stage.modulate.a = _fade(0.3)
	_title.modulate.a = _fade(0.25)
	_title.scale = Vector2.ONE * (1.0 + 0.14 * (1.0 - _fade(0.25)))
	_reward_title.modulate.a = _fade(1.65)
	_credits.modulate.a = _fade(1.95)
	_wave.modulate.a = _fade(2.2)
	_kills.modulate.a = _fade(2.45)
	_advisory.modulate.a = _fade(2.7)
	for i in _buttons.size():
		_buttons[i].modulate.a = _fade(3.0 + minf(i, 1) * 0.22)
	_skip.visible = elapsed < REVEAL_COMPLETE
	if elapsed >= REVEAL_COMPLETE and not results_ready:
		results_ready = true
		for button in _buttons:
			button.disabled = false
		_buttons[0].grab_focus()
		set_process(false)

func _fade(start: float) -> float:
	return smoothstep(0, 1, clampf((elapsed - start) / 0.32, 0, 1))

func finish_reveal() -> void:
	elapsed = maxf(elapsed, REVEAL_COMPLETE)
	_update_reveal()

func _choose_button(index: int) -> void:
	if index < 0 or index >= _button_actions.size():
		return
	_choose(_button_actions[index])

func _choose(action: StringName) -> void:
	if action.is_empty() or not results_ready or _leaving:
		return
	_leaving = true
	for button in _buttons:
		button.disabled = true
	action_requested.emit(action)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		if not results_ready:
			finish_reveal()
		elif event.is_action_pressed("ui_cancel"):
			_choose(&"back")
		get_viewport().set_input_as_handled()
