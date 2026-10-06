extends Control
## Presentation-only chooser. Profile handles confirmation and store navigation.
signal confirmed(id: String)
signal store_requested(id: String)
signal dismissed
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Portrait = preload("res://src/ui/screens/profile/avatar_portrait.gd")
var selected_id: String = "byte_bot"
var _panel: Panel
var _title: Label
var _preview: TextureRect
var _name: Label
var _state: Label
var _hint: Label
var _cancel: Button
var _action: Button
var _buttons: Array[Button] = []
var _rings: Array[Panel] = []
var _portraits: Array[TextureRect] = []
var _badges: Array[Label] = []
var _return_focus: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.9)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismiss())
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UI.journal_box(Color("0A1730"), Color("4FE0D4"), 0))
	add_child(_panel)
	_title = UI.label("PROFILE PICTURE", 22, UI.TEXT, true)
	_panel.add_child(_title)
	_preview = Portrait.new()
	_panel.add_child(_preview)
	_name = UI.label("", 28, UI.TEXT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_name)
	_state = UI.label("", 22, UI.TEAL)
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_state)
	_hint = UI.label("2 FREE / 8 STORE UNLOCKS", 20, UI.MUTED)
	_panel.add_child(_hint)
	for avatar: Dictionary in Portrait.ENTRIES:
		var button: Button = UI.button("", choose.bind(str(avatar.id)))
		button.tooltip_text = str(avatar.name)
		button.accessibility_name = str(avatar.name)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_panel.add_child(button)
		var ring: Panel = Panel.new()
		ring.mouse_filter = MOUSE_FILTER_IGNORE
		button.add_child(ring)
		var portrait: TextureRect = Portrait.new()
		portrait.show_avatar(str(avatar.id))
		button.add_child(portrait)
		var badge: Label = UI.label("", 20, UI.MUTED)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_child(badge)
		_buttons.append(button)
		_rings.append(ring)
		_portraits.append(portrait)
		_badges.append(badge)
		button.focus_entered.connect(_refresh_focus)
		button.focus_exited.connect(_refresh_focus)
	_cancel = UI.button("CANCEL", dismiss)
	_action = UI.button("CONFIRM", _activate, true)
	_panel.add_child(_cancel)
	_panel.add_child(_action)
	resized.connect(_layout)
	hide()

func present() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	show()
	choose(PlayerManager.current_avatar_id())
	_layout()
	_buttons[_index(selected_id)].grab_focus()

func _index(id: String) -> int:
	for index: int in Portrait.ENTRIES.size():
		if str(Portrait.ENTRIES[index].id) == id:
			return index
	return 0

func choose(id: String) -> void:
	var avatar: Dictionary = Portrait.entry(id)
	if avatar.is_empty():
		return
	selected_id = id
	_preview.show_avatar(id)
	_name.text = str(avatar.name)
	var available: bool = PlayerManager.can_use_avatar(id)
	_state.text = ("EQUIPPED" if id == PlayerManager.current_avatar_id() else ("FREE" if int(avatar.price) == 0 else "OWNED")) if available else "LOCKED / %d PVP TOKENS" % int(avatar.price)
	_action.text = "CONFIRM" if available else "VIEW IN STORE"
	for index: int in _buttons.size():
		var item: Dictionary = Portrait.ENTRIES[index]
		var owned: bool = PlayerManager.can_use_avatar(str(item.id))
		var equipped: bool = str(item.id) == PlayerManager.current_avatar_id()
		_badges[index].text = "EQUIPPED" if equipped else (("FREE" if int(item.price) == 0 else "OWNED") if owned else "%d PT / LOCK" % int(item.price))
		_buttons[index].accessibility_name = "%s, %s" % [item.name, _badges[index].text]
		_portraits[index].modulate = Color.WHITE if owned else Color(0.62, 0.67, 0.73)
		var style: StyleBoxFlat = UI.box(Color("102040"), UI.GOLD if str(item.id) == id else (UI.TEXT if _buttons[index].has_focus() else (Color("33D17A") if equipped else Color("173058"))), 0)
		style.set_corner_radius_all(1000)
		style.set_border_width_all(3 if str(item.id) == id else 2)
		_rings[index].add_theme_stylebox_override("panel", style)
	_layout()

func _activate() -> void:
	if PlayerManager.can_use_avatar(selected_id):
		confirmed.emit(selected_id)
	else:
		store_requested.emit(selected_id)

func _refresh_focus() -> void:
	if visible and is_instance_valid(_action):
		choose(selected_id)

func dismiss() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	dismissed.emit()

func _layout() -> void:
	if not is_instance_valid(_action):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	var pad: float = 16.0 / physical
	_panel.position = Vector2(size.x * 0.04, size.y * 0.05)
	_panel.size = Vector2(size.x * 0.92, size.y * 0.9)
	var area: Vector2 = _panel.size
	var footer: float = 48.0 / physical
	var heading: float = 28.0 / physical
	_title.position = Vector2(pad, pad)
	_title.size = Vector2(area.x - pad * 2, heading)
	_title.add_theme_font_size_override("font_size", maxi(20, ceili(16.0 / physical)))
	var body_top: float = pad + heading + pad * 0.5
	var body_height: float = area.y - body_top - footer - pad * 2
	var left_width: float = area.x * 0.3
	var diameter: float = minf(left_width - pad * 2, body_height * 0.64)
	_preview.position = Vector2((left_width - diameter) / 2, body_top)
	_preview.size = Vector2.ONE * diameter
	_name.position = Vector2(pad, body_top + diameter + pad * 0.35)
	_name.size = Vector2(left_width - pad * 2, body_height * 0.2)
	_state.position = Vector2(pad, _name.position.y + body_height * 0.2)
	_state.size = Vector2(left_width - pad * 2, body_height * 0.17)
	for label: Label in [_name, _state, _hint]:
		label.add_theme_font_size_override("font_size", maxi(22, ceili(16.0 / physical)))
	_hint.position = Vector2(left_width + pad, pad)
	_hint.size = Vector2(area.x - left_width - pad * 2, heading)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var grid_width: float = area.x - left_width - pad * 2
	var cell: Vector2 = Vector2(grid_width / 5, body_height / 2)
	for index: int in _buttons.size():
		var button: Button = _buttons[index]
		button.custom_minimum_size = Vector2.ZERO
		button.position = Vector2(left_width + pad + (index % 5) * cell.x, body_top + floori(index / 5.0) * cell.y)
		button.size = cell
		var side: float = minf(cell.x - pad * 0.4, cell.y - 24.0 / physical)
		_rings[index].position = Vector2((cell.x - side) / 2, 0)
		_rings[index].size = Vector2.ONE * side
		_portraits[index].position = _rings[index].position + Vector2.ONE * 5
		_portraits[index].size = Vector2.ONE * (side - 10)
		_badges[index].position = Vector2(0, side)
		_badges[index].size = Vector2(cell.x, 22.0 / physical)
		_badges[index].add_theme_font_size_override("font_size", maxi(18, ceili(13.0 / physical)))
	_cancel.position = Vector2(pad, area.y - pad - footer)
	_action.position = Vector2(area.x * 0.5 + pad * 0.5, _cancel.position.y)
	for button: Button in [_cancel, _action]:
		button.custom_minimum_size = Vector2.ZERO
		button.size = Vector2(area.x * 0.5 - pad * 1.5, footer)
		button.add_theme_font_size_override("font_size", maxi(24, ceili(16.0 / physical)))
	var focus: Array[Button] = _buttons.duplicate()
	focus.append_array([_cancel, _action])
	for index: int in focus.size():
		var button: Button = focus[index]
		button.focus_next = button.get_path_to(focus[(index + 1) % focus.size()])
		button.focus_previous = button.get_path_to(focus[(index + focus.size() - 1) % focus.size()])
		button.focus_neighbor_left = button.focus_previous
		button.focus_neighbor_right = button.focus_next
		button.focus_neighbor_top = button.get_path_to(focus[(index + focus.size() - 5) % focus.size()])
		button.focus_neighbor_bottom = button.get_path_to(focus[(index + 5) % focus.size()])
