@tool
extends Control
## Reusable, non-modal handler. Existing Cloudinary expressions; no new portrait files.
const PIXEL_FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/DigitalDisco.ttf")
const INK := Color("18252b")
const PAPER := Color("e8e8da")
const ACCENT := Color("8dc9bd")
const IDLE_EXPR := "npc_calm"
const TALK_EXPR := "npc_talk"
const LINES: Array[String] = [
	"Good to see you, Commander. The outpost is quiet. Ready for your next deployment?",
	"A little preparation goes a long way. Visit Lessons before tackling a new threat.",
	"Keep your towers close enough to support each other. A clear firing lane makes all the difference.",
	"The Codex keeps your intel in one place. Knowing the enemy is half the defense.",
	"Don't get comfortable just because the graph looks green. Quiet networks still get probed.",
	"One phisherman looks harmless. Give it a minute and you have a swarm on the lane.",
	"Yes. People still click mystery links on a locked-down terminal. Every shift.",
	"I'm not convinced we have closed every hole. Double-check the Codex before you deploy.",
	"Ransomware on the core would freeze this whole outpost. That thought still gets to me.",
	"Watching a leak and not being able to stop it... I do not enjoy that part of the job.",
	"We lose good operators who skip the basics. I wish that were not still true.",
	"I still replay the last breach we missed. Do not make me write that report again.",
	"I, uh, misread a ping last week. We are not discussing that one.",
	"...You did not hear that from me. Anyway. Back to the mission.",
	"Ha. Remember the 'harmless' attachment that took down a lab? Funny. Until it isn't.",
	"Social engineering still works because people want to help. That never sits right.",
	"If they are coming for this network, we hit first. Place your nodes. Hold the line.",
	"Commander—ransomware on the core is not a drill. Contain it. Now.",
	"Even a good commander needs a breather. I'll keep watch while you take a moment.",
]
const LINE_EXPR: Array[String] = [
	"npc_smile",
	"npc_thoughtfulness",
	"npc_calm",
	"npc_talk",
	"npc_skepticism",
	"npc_astonishment",
	"npc_eye_rolling",
	"npc_doubt",
	"npc_fear",
	"npc_discomfort",
	"npc_sadness",
	"npc_cry",
	"npc_embarrassment",
	"npc_awkwardness",
	"npc_laughter",
	"npc_disgust",
	"npc_aggression",
	"npc_scream",
	"npc_smile",
]

var _portrait_button: Button
var _portrait: TextureRect
var _dialogue: PanelContainer
var _body: Label
var _hint: Label
var _next: Button
var _line := -1
var _elapsed := 0.0
var _typing := false
var _enabled := true
var _expression := ""
var _idle_time := 0.0
var _portrait_home := Vector2.ZERO
var _unheard: Array[int] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()
	if LINES.size() != LINE_EXPR.size():
		push_error("Handler LINES and LINE_EXPR must stay the same length.")
	if not Engine.is_editor_hint():
		AssetManager.sync_finished.connect(_on_assets_ready)
		_refresh_portrait(IDLE_EXPR)
	set_process(not Engine.is_editor_hint())

func _build() -> void:
	_portrait_button = Button.new()
	_portrait_button.name = "TalkToHandler"
	_portrait_button.flat = true
	_portrait_button.tooltip_text = "Talk to your handler"
	_portrait_button.accessibility_name = "Talk to handler"
	_portrait_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		_portrait_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_portrait_button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, ACCENT))
	add_child(_portrait_button)
	_portrait_button.pressed.connect(talk)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = MOUSE_FILTER_IGNORE
	# Keep the original alpha and expression art, tinting the guide as a teal hologram.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 p = texture(TEXTURE, UV); float l = dot(p.rgb, vec3(0.299,0.587,0.114)); COLOR = vec4(mix(vec3(0.12,0.28,0.30), vec3(0.66,0.88,0.81), l), p.a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	_portrait.material = material
	_portrait_button.add_child(_portrait)
	_hint = _label("HANDLER  /  TAP TO TALK", 9, ACCENT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_dialogue = PanelContainer.new()
	_dialogue.name = "SmallDialogue"
	_dialogue.add_theme_stylebox_override("panel", _box(Color("152329f2"), Color("698c87")))
	add_child(_dialogue)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_dialogue.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var name_label := _label("HANDLER", 10, ACCENT)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_label)
	var close := _small_button("X", "Close dialogue")
	row.add_child(close)
	close.pressed.connect(close_dialogue)
	_body = _label("", 18, PAPER)
	_body.add_theme_font_override("font", BODY_FONT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.y = 72
	column.add_child(_body)
	_next = _small_button("NEXT  >", "Next dialogue")
	_next.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_next)
	_next.pressed.connect(talk)
	_dialogue.hide()

func _layout() -> void:
	if _portrait_button == null:
		return
	var side := minf(size.x - 20.0, size.y - 220.0)
	_portrait_button.position = Vector2((size.x - side) * 0.5, 0)
	_portrait_button.size = Vector2(side, side)
	_portrait_home = _portrait_button.position
	_hint.position = Vector2(0, side + 10)
	_hint.size = Vector2(size.x, 24)
	_dialogue.position = Vector2(0, side + 40)
	_dialogue.size = Vector2(size.x, 168)
	queue_redraw()

func _draw() -> void:
	if _portrait_button == null:
		return
	var side := _portrait_button.size.x
	# A restrained projection plinth grounds the existing bust in the environment.
	var center := Vector2(size.x * 0.5, side - 3)
	draw_set_transform(center, 0, Vector2(1, 0.18))
	draw_circle(Vector2.ZERO, side * 0.47, Color("0d2029c0"))
	draw_arc(Vector2.ZERO, side * 0.44, 0, TAU, 64, Color(ACCENT, 0.5), 2, true)
	draw_set_transform(Vector2.ZERO)

func talk() -> void:
	if not _enabled or Engine.is_editor_hint():
		return
	if _typing:
		_finish_line()
		return
	_line = _draw_line()
	_body.text = LINES[_line]
	_body.visible_characters = 0
	_elapsed = 0
	_typing = true
	_dialogue.show()
	_hint.text = "HANDLER  /  LINK ACTIVE"
	_next.text = "REVEAL  >"
	_refresh_portrait(_spoken_expression())
	AudioManager.play_sfx("ui_click")

func close_dialogue() -> void:
	_typing = false
	_dialogue.hide()
	_hint.text = "HANDLER  /  TAP TO TALK"
	_refresh_portrait(IDLE_EXPR)

func set_interaction_enabled(enabled: bool) -> void:
	_enabled = enabled
	_portrait_button.disabled = not enabled
	_portrait_button.focus_mode = FOCUS_ALL if enabled else FOCUS_NONE
	if not enabled:
		close_dialogue()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_idle_time += delta
	_portrait_button.position.y = _portrait_home.y + sin(_idle_time * 1.5) * 2
	if not _typing:
		return
	_elapsed += delta
	var count := int(_elapsed / 0.028)
	_body.visible_characters = count
	_refresh_portrait(_typing_expression(count))
	if count >= _body.text.length():
		_finish_line()

func _finish_line() -> void:
	_typing = false
	_body.visible_characters = -1
	_next.text = "NEXT  >"
	_refresh_portrait(_spoken_expression())

func _unhandled_key_input(event: InputEvent) -> void:
	if _dialogue.visible and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()

func _on_assets_ready(_success: bool) -> void:
	_expression = ""
	if _typing:
		_refresh_portrait(_typing_expression(int(_elapsed / 0.028)))
	elif _dialogue.visible:
		_refresh_portrait(_spoken_expression())
	else:
		_refresh_portrait(IDLE_EXPR)

func _spoken_expression() -> String:
	if _line < 0 or _line >= LINE_EXPR.size():
		return IDLE_EXPR
	return LINE_EXPR[_line]


func _draw_line() -> int:
	if LINES.is_empty():
		return 0
	if _unheard.is_empty():
		for i in LINES.size():
			_unheard.append(i)
		_unheard.shuffle()
		if _unheard.size() > 1 and _unheard[_unheard.size() - 1] == _line:
			var swap_i: int = _unheard.size() - 1
			_unheard[swap_i] = _unheard[0]
			_unheard[0] = _line
	return _unheard.pop_back()


func _can_lip_sync(asset_id: String) -> bool:
	return asset_id in ["npc_smile", "npc_calm", "npc_thoughtfulness", "npc_talk", "npc_skepticism", "npc_doubt"]


func _typing_expression(char_count: int) -> String:
	var spoken: String = _spoken_expression()
	if not _can_lip_sync(spoken):
		return spoken
	if char_count % 10 < 5:
		return TALK_EXPR
	return spoken


func _refresh_portrait(asset_id: String) -> void:
	if Engine.is_editor_hint() or _expression == asset_id:
		return
	var texture: Texture2D = AssetManager.get_texture(asset_id)
	if texture == null and asset_id != IDLE_EXPR:
		texture = AssetManager.get_texture(IDLE_EXPR)
	if texture == null and asset_id != "npc_smile":
		texture = AssetManager.get_texture("npc_smile")
	if texture != null:
		_portrait.texture = texture
		_expression = asset_id
	# Even without a cached portrait, the handler remains reachable by its button.
	_portrait_button.text = "" if _portrait.texture != null else "[ HANDLER ]\nTAP TO TALK"

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _small_button(text: String, description: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = description
	button.accessibility_name = description
	button.custom_minimum_size.y = 28
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _box(Color("29413f"), ACCENT))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, ACCENT))
	return button

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
