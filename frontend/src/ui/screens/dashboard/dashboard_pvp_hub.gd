extends Control
## UI-only PvP destination. No simulated opponents, queue, ranks or network calls.
signal switch_requested
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const RED: Color = Color("#FF5C5C")
var _header: Label
var _identity: Label
var _title: Label
var _subtitle: Label
var _status: VBoxContainer
var _switch: Button
var _queue: Button
var _copy: Label
var _backdrop: TextureRect

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var fallback: ColorRect = ColorRect.new()
	fallback.color = Color("#170A12")
	fallback.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fallback)
	fallback.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_refresh_art()
	AssetManager.sync_finished.connect(_refresh_art)
	var tint: ColorRect = ColorRect.new()
	tint.color = Color(0.02, 0.01, 0.02, 0.16)
	tint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tint)
	tint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_header = UI.label("LEVEL BLUE  /  RED OS", 24, RED, true)
	add_child(_header)
	_identity = UI.label("", 24, Color("#F3ECD6"))
	_identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_identity)
	_title = UI.label("RIVAL\nNETWORK", 52, Color("#F3ECD6"), true)
	add_child(_title)
	_subtitle = UI.label("PVP COMMAND CENTER", 24, RED)
	add_child(_subtitle)
	_status = VBoxContainer.new()
	_status.add_theme_constant_override("separation", 14)
	add_child(_status)
	_status.add_child(UI.label("ARENA / NOT CONNECTED", 24, RED))
	_copy = UI.label("Your competitive workspace is ready.\nMatchmaking and battles are not available yet.", 24, Color("#B8A6AE"))
	_status.add_child(_copy)
	_queue = UI.button("FIND OPPONENT  /  UNAVAILABLE", Callable())
	_queue.disabled = true
	_queue.tooltip_text = "This milestone adds the PvP interface. Multiplayer battles are not connected yet."
	_queue.add_theme_stylebox_override("disabled", UI.box(Color("#170C14"), Color("#69343D"), 18))
	_queue.add_theme_color_override("font_disabled_color", Color("#BDA4AC"))
	_status.add_child(_queue)
	_switch = UI.button("SWITCH OS", func() -> void: switch_requested.emit())
	_switch.name = "SwitchOS"
	_switch.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_switch.add_theme_stylebox_override("normal", UI.box(Color("#24101A"), RED, 14))
	add_child(_switch)
	var icon: IntelPixelIcon = IntelPixelIcon.new()
	icon.kind = IntelPixelIcon.Kind.SWAP
	icon.ink_override = RED
	icon.position = Vector2(14, 12)
	icon.size = Vector2(36, 36)
	_switch.add_child(icon)
	resized.connect(_layout)
	refresh_identity()
	_layout.call_deferred()

func refresh_identity() -> void:
	_identity.text = AuthService.display_name().to_upper()
	_refresh_art()

func _refresh_art(_success: bool = true) -> void:
	# Keep the calm, static workspace separate from the dramatic selector art.
	_backdrop.texture = AssetManager.get_texture("ui_dashboard_pvp_workspace")

func _layout() -> void:
	if not is_inside_tree() or _switch == null:
		return
	var physical: float = maxf(0.4, float(get_window().size.y) / get_viewport_rect().size.y)
	var readable: int = maxi(24, ceili(16.0 / physical))
	var inset: float = size.x * 0.055
	_header.position = Vector2(inset, size.y * 0.065)
	_header.size = Vector2(size.x * 0.62, 48)
	_identity.position = Vector2(size.x * 0.69, size.y * 0.065)
	_identity.size = Vector2(size.x * 0.255, 48)
	_identity.clip_text = true
	_identity.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.position = Vector2(inset, size.y * 0.23)
	_title.size = Vector2(size.x * 0.53, size.y * 0.2)
	_subtitle.position = Vector2(inset, size.y * 0.44)
	_subtitle.size = Vector2(size.x * 0.55, 44)
	_status.position = Vector2(inset, size.y * 0.53)
	_status.size = Vector2(size.x * 0.52, 0)
	for label: Label in [_identity, _subtitle, _copy, _status.get_child(0) as Label]:
		label.add_theme_font_size_override("font_size", readable)
	_queue.add_theme_font_size_override("font_size", readable)
	_queue.custom_minimum_size.y = maxf(60, 44.0 / physical)
	_switch.add_theme_font_size_override("font_size", readable)
	_switch.position = Vector2(inset, size.y * 0.86)
	_switch.size = Vector2(maxf(245, 180.0 / physical), maxf(60, 44.0 / physical))
