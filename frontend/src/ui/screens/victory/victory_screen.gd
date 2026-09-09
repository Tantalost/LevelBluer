class_name VictoryScreen
extends BaseScreen
## Stage results. Win shows materials gained; fail types an advisory log.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const BG_CITY := "res://assets/ui/dashboard.png"
const CHAR_SEC := 0.032
const PUNCT_SEC := 0.18
const LINE_SEC := 0.12
const WRAP_COLS := 34

@onready var _hero_art: TextureRect = %HeroArt
@onready var _result_label: Label = %ResultLabel
@onready var _player_name: Label = %PlayerName
@onready var _materials_value: Label = %MaterialsValue
@onready var _materials_delta: Label = %MaterialsDelta
@onready var _stage_name: Label = %StageName
@onready var _status_label: Label = %StatusLabel
@onready var _type_chip: HudGeoButton = %TypeChip
@onready var _art_well: PanelContainer = %ArtWell
@onready var _art_glyph: IntelPixelIcon = %ArtGlyph
@onready var _materials_banner: HudGeoButton = %MaterialsBanner
@onready var _grade_chip: HudGeoButton = %GradeChip
@onready var _win_block: Control = %WinBlock
@onready var _fail_block: Control = %FailBlock
@onready var _tips_body: Label = %TipsBody
@onready var _back_button: HudGeoButton = %BackButton
@onready var _retry_button: HudGeoButton = %RetryButton
@onready var _codex_button: HudGeoButton = %CodexButton

var _pixel_font: Font
var _won: bool = true
var _materials_gained: int = 0
var _weak_skill: String = ""
var _tip_full: String = ""
var _tip_index: int = 0
var _type_acc: float = 0.0


func _ready() -> void:
	_load_font()
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_retry_button.pressed.connect(func() -> void: Router.retry_level())
	_codex_button.pressed.connect(_on_lessons_pressed)
	%ProfileButton.pressed.connect(func() -> void: Router.push(&"profile"))
	_type_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_materials_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func on_enter(args: Dictionary) -> void:
	_won = bool(args.get("won", true))
	_materials_gained = maxi(0, int(args.get("credits", args.get("materials", args.get("gold", 0)))))
	_weak_skill = str(args.get("weak_skill", ""))
	var tip := str(args.get("tip", ""))
	_refresh(tip)


func on_exit() -> void:
	_stop_typewriter()


func _refresh(tip: String) -> void:
	_style_header()
	_apply_backdrop()
	var config: Dictionary = StageManager.get_stage_config(Router.active_stage_index + 1)
	var stage_title := str(config.get("name", "STAGE")).to_upper()
	var stage_type := str(config.get("type", "STAGE")).to_upper()
	_stage_name.text = stage_title
	_status_label.text = "STAGE COMPLETE" if _won else "STAGE FAILED"
	_type_chip.title = stage_type if not stage_type.is_empty() else "STAGE"
	_apply_label(_stage_name, Palette.TEXT_PRIMARY, 13)
	_apply_label(_status_label, Palette.GOLD if _won else Palette.HEART, 16)
	_stage_name.add_theme_constant_override("line_spacing", 8)
	_tips_body.add_theme_constant_override("line_spacing", 10)
	_stage_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tips_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_win_block.visible = _won
	_fail_block.visible = not _won
	_codex_button.visible = not _won
	if _won:
		_stop_typewriter()
		_materials_banner.title = "+%d" % _materials_gained
		_materials_banner.subtitle = "CREDITS EARNED"
		_materials_banner.fill_key = "gold"
		_materials_banner.border_key = "gold"
		_grade_chip.title = "CLR"
		_grade_chip.fill_key = "gold"
		_grade_chip.border_key = "gold"
		_art_glyph.kind = IntelPixelIcon.Kind.TERMINAL
		_art_glyph.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_art_well.add_theme_stylebox_override("panel", _pixel_box(Color(Palette.GOLD, 0.35), Palette.GOLD, 0, 2))
	else:
		_apply_label(%TipsTitle, Palette.CYAN, 10)
		_apply_label(_tips_body, Palette.GREEN, 11)
		_art_glyph.kind = IntelPixelIcon.Kind.LOCK
		_art_glyph.modulate = Palette.TEXT_MUTED
		_art_well.add_theme_stylebox_override("panel", _pixel_box(Color(Palette.RED_DEEP, 0.55), Palette.RED, 0, 2))
		_start_typewriter(_terminal_copy(tip))
	_type_chip.queue_redraw()
	_materials_banner.queue_redraw()
	_grade_chip.queue_redraw()
	_art_glyph.queue_redraw()


func _style_header() -> void:
	_result_label.text = "RESULT"
	_player_name.text = "<%s>" % AuthService.display_name().to_upper()
	_materials_value.text = str(PlayerManager.credits)
	_materials_delta.visible = _materials_gained > 0
	_materials_delta.text = "+%d" % _materials_gained if _materials_delta.visible else ""
	_apply_label(_result_label, Palette.CYAN, 13)
	_apply_label(_player_name, Palette.TEXT_PRIMARY, 11)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_delta, Palette.GOLD, 9)
	%AvatarBox.add_theme_stylebox_override("panel", _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2))
	%TipsBox.add_theme_stylebox_override("panel", _pixel_box(Color(Palette.BG_HEADER, 0.92), Palette.RED, 0, 2))


func _apply_backdrop() -> void:
	AssetManager.bind_texture(%CityArt, "ui_dashboard")
	if %CityArt.texture == null and ResourceLoader.exists(BG_CITY):
		%CityArt.texture = load(BG_CITY) as Texture2D
	AssetManager.bind_texture(find_child("AvatarImage", true, false) as CanvasItem, "ui_pfp")
	_hero_art.modulate = Color(0.82, 0.92, 1.0, 0.92) if _won else Color(1.0, 0.72, 0.72, 0.88)


func _terminal_copy(tip: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("> status: FAILED")
	if not _weak_skill.is_empty():
		lines.append("> skill: " + _weak_skill)
	lines.append(">")
	var body := tip.strip_edges()
	if body.is_empty():
		body = "Review Codex, then retry the stage."
	var chunks: PackedStringArray = body.split(". ")
	var i := 0
	while i < chunks.size():
		var sentence := chunks[i].strip_edges()
		i += 1
		if sentence.is_empty():
			continue
		if not sentence.ends_with(".") and not sentence.ends_with("%"):
			sentence += "."
		_append_wrapped(lines, sentence)
	return "\n".join(lines)


func _append_wrapped(lines: PackedStringArray, sentence: String) -> void:
	var words: PackedStringArray = sentence.split(" ")
	var row := ""
	var i := 0
	while i < words.size():
		var word := words[i]
		i += 1
		if word.is_empty():
			continue
		if row.is_empty():
			row = word
			continue
		if row.length() + 1 + word.length() <= WRAP_COLS:
			row += " " + word
			continue
		lines.append(row)
		row = word
	if not row.is_empty():
		lines.append(row)


func _start_typewriter(full: String) -> void:
	_tip_full = full
	_tip_index = 0
	_type_acc = 0.0
	_tips_body.text = "_"
	set_process(not full.is_empty())
	if full.is_empty():
		_tips_body.text = "> no advisory"


func _stop_typewriter() -> void:
	set_process(false)
	_tip_full = ""
	_tip_index = 0
	_type_acc = 0.0


func _process(delta: float) -> void:
	if _tip_full.is_empty():
		set_process(false)
		return
	if _tip_index >= _tip_full.length():
		_tips_body.text = _tip_full
		set_process(false)
		return
	var next := _tip_full.substr(_tip_index, 1)
	var wait := CHAR_SEC
	if next == "." or next == ":":
		wait = PUNCT_SEC
	elif next == "\n":
		wait = LINE_SEC
	_type_acc += delta
	if _type_acc < wait:
		return
	_type_acc = 0.0
	_tip_index += 1
	_tips_body.text = _tip_full.substr(0, _tip_index) + "_"


func _on_lessons_pressed() -> void:
	Router.open_lessons()


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _apply_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
