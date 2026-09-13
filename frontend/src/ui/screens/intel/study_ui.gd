extends RefCounted
## Shared readable CRT chrome. No textures, flashing, or screen distortion.
const FONT = preload("res://assets/fonts/DigitalDisco.ttf")
const TITLE = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BG := Color("0b141c")
const PANEL := Color("152630")
const TEXT := Color("e3eee5")
const MUTED := Color("a0b7bb")
const TEAL := Color("85d9c3")
const GOLD := Color("e5c88a")

static func box(fill: Color = PANEL, border: Color = Color("3b626a"), padding: int = 18) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(1)
	b.border_width_top = 2
	b.set_content_margin_all(padding)
	b.shadow_color = Color(0, 0, 0, 0.25)
	b.shadow_size = 4
	b.shadow_offset = Vector2(3, 4)
	return b

static func label(text: String, font_size: int = 24, color: Color = TEXT, heading: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TITLE if heading else FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 48)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", BG if primary else TEXT)
	b.add_theme_color_override("font_hover_color", BG)
	b.add_theme_color_override("font_pressed_color", BG)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_stylebox_override("normal", box(TEAL if primary else PANEL, TEAL if primary else Color("3b626a"), 10))
	b.add_theme_stylebox_override("hover", box(TEAL, TEXT, 10))
	b.add_theme_stylebox_override("pressed", box(GOLD, TEXT, 10))
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, GOLD, 0))
	b.add_theme_stylebox_override("disabled", box(BG, Color("29424b"), 10))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

static func column(parent: Node, spacing: int = 14) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", spacing)
	parent.add_child(c)
	return c

static func lock_topic(button: Button, reason: String) -> void:
	button.disabled = true
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.tooltip_text = reason
	button.text = "LOCKED / " + button.text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var style := box(Color("1b2027"), Color("48505a"), 10)
	style.content_margin_left = 48
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_color_override("font_disabled_color", Color("aeb5bd"))
	var icon := IntelPixelIcon.new()
	icon.name = "LockIcon"
	icon.kind = IntelPixelIcon.Kind.LOCK
	icon.ink_override = Color("aeb5bd")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = 10
	icon.offset_right = 38
	icon.offset_top = -14
	icon.offset_bottom = 14
	button.add_child(icon)

static func panel(parent: Node, fill: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(fill))
	parent.add_child(p)
	return p

static func scroll_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content := column(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func shell(host: Control, title: String, back: Callable) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	var margin := SafeAreaContainer.new()
	margin.extra_margin = 24
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	host.add_child(margin)
	var layout := column(margin, 20)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	layout.add_child(header)
	var back_button := button("< BACK", back)
	back_button.custom_minimum_size.x = 110
	header.add_child(back_button)
	var name_label := label(title, 20, TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)
	var crt := ColorRect.new()
	crt.name = "CRTOverlay"
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float line = step(0.68, fract(FRAGCOORD.y / 3.0)); vec2 p = UV * 2.0 - 1.0; float edge = pow(max(abs(p.x), abs(p.y)), 5.0); COLOR = vec4(0.01,0.04,0.04, line * 0.045 + edge * 0.16); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	crt.material = mat
	crt.visible = true
	host.add_child(crt)
	return {"layout": layout, "back": back_button, "title": name_label, "crt": crt}
