extends SafeAreaContainer
## Shared presentation only: auth requests and validation stay in their screens.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
@onready var _card: PanelContainer = %AuthCard
@onready var _scroll: ScrollContainer = %AuthScroll
var _keyboard_height: int = -1
var _entrance: Tween

func _ready() -> void:
	super._ready()
	theme = Theme.new()
	theme.default_font = UI.FONT
	theme.set_color("font_color", "Label", Color("f3ecd6"))
	theme.set_stylebox("panel", "PanelContainer", UI.box(Color("0a1730"), Color("4fe0d4"), 24))
	theme.set_type_variation("AuthInset", "PanelContainer")
	theme.set_stylebox("panel", "AuthInset", UI.box(Color("0e2a28"), Color("173058"), 24))
	theme.set_type_variation("AuthError", "PanelContainer")
	theme.set_stylebox("panel", "AuthError", UI.box(Color("301d2b"), Color("ff5c5c"), 12))
	theme.set_type_variation("AuthTitle", "Label")
	theme.set_color("font_color", "AuthTitle", Color("8ff0e6"))
	theme.set_type_variation("AuthHero", "PanelContainer")
	var hero_style: StyleBoxEmpty = StyleBoxEmpty.new()
	hero_style.set_content_margin_all(16)
	theme.set_stylebox("panel", "AuthHero", hero_style)
	theme.set_type_variation("AuthComposition", "PanelContainer")
	theme.set_stylebox("panel", "AuthComposition", StyleBoxEmpty.new())
	theme.set_type_variation("AuthMuted", "Label")
	theme.set_color("font_color", "AuthMuted", Color("a0b7bb"))
	theme.set_type_variation("AuthHeading", "Label")
	theme.set_color("font_color", "AuthHeading", Color("f3ecd6"))
	var terminal_style: StyleBoxFlat = UI.box(Color("0a1730f5"), Color("173058"), 28)
	terminal_style.set_corner_radius_all(16)
	terminal_style.corner_detail = 1
	terminal_style.border_width_bottom = 6
	terminal_style.shadow_size = 12
	terminal_style.shadow_color = Color("050b1890")
	theme.set_type_variation("AuthTerminal", "PanelContainer")
	theme.set_stylebox("panel", "AuthTerminal", terminal_style)
	theme.set_stylebox("panel", "AuthInset", UI.box(Color("10204080"), Color("173058"), 20))
	for state: String in ["normal", "read_only"]:
		var input_style: StyleBoxFlat = UI.box(Color("050b18"), Color("173058"), 14)
		input_style.border_width_bottom = 3
		theme.set_stylebox(state, "LineEdit", input_style)
	theme.set_stylebox("focus", "LineEdit", UI.box(Color.TRANSPARENT, Color("4fe0d4"), 0))
	theme.set_color("font_color", "LineEdit", Color("f3ecd6"))
	theme.set_color("caret_color", "LineEdit", Color("4fe0d4"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("a0b7bb"))
	theme.set_type_variation("AuthPrimary", "Button")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = Color("102040")
		var primary: Color = Color("2e6bff")
		if state == "hover":
			fill = Color("173058")
			primary = Color("4f8cff")
		elif state == "pressed":
			primary = Color("173058")
		elif state == "disabled":
			primary = Color("102040")
		theme.set_stylebox(state, "Button", UI.box(fill, Color("173058"), 10))
		var action: StyleBoxFlat = UI.box(primary, Color("4f8cff"), 10)
		action.border_width_top = 2
		action.border_width_bottom = 5 if state != "pressed" else 1
		action.set_corner_radius_all(8)
		action.corner_detail = 1
		theme.set_stylebox(state, "AuthPrimary", action)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(state, "Button", Color("f3ecd6"))
	theme.set_stylebox("focus", "Button", UI.box(Color.TRANSPARENT, Color("ffb648"), 0))
	theme.set_stylebox("background", "ProgressBar", UI.box(Color("050b18"), Color("173058"), 0))
	theme.set_stylebox("fill", "ProgressBar", UI.box(Color("4fe0d4"), Color("4fe0d4"), 0))
	get_viewport().size_changed.connect(_layout)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	_decorate(_card)
	visibility_changed.connect(_reveal)
	_reveal()
	_layout.call_deferred()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var height: int = DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if height != _keyboard_height:
		_keyboard_height = height
		_layout()

func _layout() -> void:
	if not is_node_ready():
		return
	# Reset keyboard clearance even when no native window/safe-area is available.
	add_theme_constant_override("margin_bottom", extra_margin)
	super._apply()
	var scale_y: float = maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var font_size: int = maxi(24, ceili(16.0 / scale_y))
	theme.default_font_size = font_size
	theme.set_font_size("font_size", "AuthTitle", font_size + 8)
	theme.set_font_size("font_size", "AuthHeading", font_size + 16)
	var bottom: int = maxi(get_theme_constant("margin_bottom"), ceili(maxi(0, _keyboard_height) / scale_y) + extra_margin)
	add_theme_constant_override("margin_bottom", bottom)
	_card.custom_minimum_size.x = minf(1200, maxf(0, size.x - get_theme_constant("margin_left") - get_theme_constant("margin_right")))
	_size_inputs(_card, maxf(56, ceilf(48.0 / scale_y)))
	_focus_changed.call_deferred(get_viewport().gui_get_focus_owner())

func _size_inputs(node: Node, height: float) -> void:
	if node is LineEdit or node is Button or node is ProgressBar:
		(node as Control).custom_minimum_size.y = height
	for child: Node in node.get_children():
		_size_inputs(child, height)

func _focus_changed(control: Control) -> void:
	if is_instance_valid(control) and _scroll.is_ancestor_of(control):
		_scroll.ensure_control_visible.call_deferred(control)

func _reveal() -> void:
	if not is_visible_in_tree():
		return
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	_card.modulate.a = 0.0
	_entrance = create_tween()
	_entrance.tween_property(_card, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

func _decorate(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.theme_type_variation == &"AuthTerminal":
			control.draw.connect(_draw_terminal.bind(control))
			control.resized.connect(control.queue_redraw)
		elif control.name in [&"HeroGraphic", &"ShieldGraphic", &"MailIcon", &"LockIcon"]:
			control.draw.connect(_draw_symbol.bind(control))
			control.resized.connect(control.queue_redraw)
	for child: Node in node.get_children():
		_decorate(child)

func _draw_terminal(control: Control) -> void:
	var w: float = control.size.x
	var h: float = control.size.y
	var cyan: Color = Color("4fe0d4")
	# Stepped corners and a short illuminated rail, not a full neon rectangle.
	for origin: Vector2 in [Vector2.ZERO, Vector2(w, h)]:
		var sign_value: float = 1.0 if origin == Vector2.ZERO else -1.0
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in [Vector2(0, 56), Vector2(0, 16), Vector2(8, 16), Vector2(8, 8), Vector2(16, 8), Vector2(16, 0), Vector2(84, 0)]:
			points.append(origin + point * sign_value)
		control.draw_polyline(points, Color("4fe0d421"), 8)
		control.draw_polyline(points, cyan, 2)
	for index: int in 3:
		control.draw_rect(Rect2(w - 54 + index * 10, 14, 5, 5), cyan if index == 0 else Color("173058"))

func _draw_symbol(control: Control) -> void:
	var center: Vector2 = (control.size * 0.5).floor()
	var cyan: Color = Color("8ff0e6")
	if control.name == &"HeroGraphic":
		for radius: int in [78, 106]:
			var points: PackedVector2Array = PackedVector2Array()
			for index: int in 9:
				var angle: float = TAU * index / 8.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			control.draw_polyline(points, Color("4fe0d430"), 2)
		control.draw_line(Vector2(0, center.y), Vector2(center.x - 125, center.y), Color("4fe0d450"), 2)
		control.draw_line(Vector2(center.x + 125, center.y), Vector2(control.size.x, center.y), Color("4fe0d450"), 2)
		for offset: float in [-1.0, 1.0]:
			control.draw_rect(Rect2(center + Vector2(offset * 120 - 3, -3), Vector2(6, 6)), cyan)
	elif control.name == &"ShieldGraphic":
		var points: PackedVector2Array = PackedVector2Array([Vector2(-36, -34), Vector2(36, -34), Vector2(36, 10), Vector2(24, 10), Vector2(24, 22), Vector2(12, 22), Vector2(12, 34), Vector2(0, 42), Vector2(-12, 34), Vector2(-12, 22), Vector2(-24, 22), Vector2(-24, 10), Vector2(-36, 10), Vector2(-36, -34)])
		for index: int in points.size():
			points[index] += center
		control.draw_colored_polygon(points, Color("153b37"))
		control.draw_polyline(points, cyan, 3)
		control.draw_rect(Rect2(center + Vector2(-12, -5), Vector2(24, 21)), cyan)
		control.draw_rect(Rect2(center + Vector2(-7, -17), Vector2(14, 14)), cyan, false, 3)
		control.draw_rect(Rect2(center + Vector2(-2, 1), Vector2(4, 8)), Color("0a1730"))
	elif control.name == &"MailIcon":
		control.draw_rect(Rect2(center - Vector2(13, 9), Vector2(26, 18)), cyan, false, 2)
		control.draw_polyline(PackedVector2Array([center + Vector2(-12, -7), center + Vector2(0, 3), center + Vector2(12, -7)]), cyan, 2)
	else:
		control.draw_rect(Rect2(center + Vector2(-10, -2), Vector2(20, 16)), cyan, false, 2)
		control.draw_rect(Rect2(center + Vector2(-6, -12), Vector2(12, 10)), cyan, false, 2)
