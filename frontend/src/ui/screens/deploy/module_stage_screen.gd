extends BaseScreen
## Per-module stage list. Same chrome for every module; backdrop tint and stage data change.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const BG_CITY := "res://assets/ui/dashboard.png"
const BG_ALT := "res://assets/ui/background.png"
const STAGE_COUNT := 10
const ROW_H := 64.0
const ROW_GAP := 18.0
const ROW_W := 560.0
const ROW_SELECTED_EXTRA := 36.0

@onready var _safe: MarginContainer = %SafeArea
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _player_name: Label = %PlayerName
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _settings_button: HudGeoButton = %SettingsButton
@onready var _hero_art: TextureRect = %HeroArt
@onready var _type_chip: HudGeoButton = %TypeChip
@onready var _waves_chip: HudGeoButton = %WavesChip
@onready var _gold_chip: HudGeoButton = %GoldChip
@onready var _score_label: Label = %ScoreLabel
@onready var _stage_title: Label = %StageTitle
@onready var _stage_sub: Label = %StageSub
@onready var _art_well: PanelContainer = %ArtWell
@onready var _art_glyph: IntelPixelIcon = %ArtGlyph
@onready var _pack_label: Label = %PackLabel
@onready var _pack_title: Label = %PackTitle
@onready var _pack_stats: Label = %PackStats
@onready var _stage_list: VBoxContainer = %StageList
@onready var _main_menu: HudGeoButton = %MainMenuButton
@onready var _breach_button: HudGeoButton = %BreachButton

var _pixel_font: Font
var _modules: Array[Dictionary] = []
var _module_index: int = 0
var _selected: int = 0
var current_selected_stage: int = 0


func _ready() -> void:
	_load_font()
	_modules = LessonCatalog.modules()
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_main_menu.pressed.connect(func() -> void: Router.request_back())
	_settings_button.pressed.connect(func() -> void: Router.push(&"settings"))
	_breach_button.pressed.connect(_on_breach_pressed)
	%ProfileButton.pressed.connect(func() -> void: Router.push(&"profile"))
	%PackBanner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waves_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_back()


func on_enter(args: Dictionary) -> void:
	visible = true
	_modules = LessonCatalog.modules()
	_module_index = clampi(int(args.get("module_index", 0)), 0, maxi(0, _modules.size() - 1))
	_selected = _first_playable()
	current_selected_stage = _launch_index(_selected)
	_refresh_all()


func on_resume() -> void:
	visible = true
	_refresh_all()


func on_exit() -> void:
	visible = false


func _refresh_all() -> void:
	_refresh_header()
	_apply_backdrop()
	_rebuild_rows()
	_refresh_detail()
	_refresh_breach()


func _refresh_header() -> void:
	_title_label.text = "SELECT A STAGE"
	_player_name.text = "<%s>" % AuthService.display_name().to_upper()
	var threat: int = AuthService.wallet_threat_points()
	var mats: int = AuthService.materials()
	_threat_value.text = str(threat if threat >= 0 else 0)
	_materials_value.text = str(mats if mats >= 0 else 0)
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 14)
	_apply_label(_player_name, Palette.TEXT_PRIMARY, 11)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_style_back()
	%AvatarBox.add_theme_stylebox_override("panel", _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2))
	_apply_spacing()
	var entry: Dictionary = _module_entry()
	var module_id := str(entry.get("id", ""))
	var total: int = maxi(1, LessonCatalog.lesson_count(module_id))
	var done: int = mini(PlayerManager.get_lesson_progress(module_id), total)
	_pack_label.text = "MODULE %d/%d" % [_module_index + 1, maxi(1, _modules.size())]
	_pack_title.text = str(entry.get("title", "")).to_upper()
	_pack_stats.text = "CLR %d   ALL %d" % [done, total]
	_apply_label(_pack_label, Palette.CYAN, 10)
	_apply_label(_pack_title, Palette.TEXT_PRIMARY, 16)
	_apply_label(_pack_stats, Palette.TEXT_PRIMARY, 10)


func _apply_spacing() -> void:
	_safe.add_theme_constant_override("margin_left", 24)
	_safe.add_theme_constant_override("margin_top", 14)
	_safe.add_theme_constant_override("margin_right", 20)
	_safe.add_theme_constant_override("margin_bottom", 12)
	var layout: VBoxContainer = _safe.get_node_or_null("ScreenLayout") as VBoxContainer
	if layout != null:
		layout.add_theme_constant_override("separation", 18)
	var main_row: HBoxContainer = null
	if layout != null:
		main_row = layout.get_node_or_null("MainRow") as HBoxContainer
	if main_row != null:
		main_row.add_theme_constant_override("separation", 48)
	var left: VBoxContainer = null
	var right: VBoxContainer = null
	if main_row != null:
		left = main_row.get_node_or_null("LeftCol") as VBoxContainer
		right = main_row.get_node_or_null("RightCol") as VBoxContainer
	if left != null:
		left.add_theme_constant_override("separation", 16)
		left.size_flags_stretch_ratio = 0.38
	if right != null:
		right.add_theme_constant_override("separation", 16)
		right.size_flags_stretch_ratio = 0.62
	_stage_list.add_theme_constant_override("separation", int(ROW_GAP))


func _apply_backdrop() -> void:
	var path := BG_CITY if _module_index == 0 else BG_ALT
	if ResourceLoader.exists(path):
		_hero_art.texture = load(path) as Texture2D
	var accent: Color = _module_accent()
	_hero_art.modulate = Color(accent.lightened(0.35), 0.72)
	%MapDim.color = Color(Palette.BG_DEEP, 0.48)


func _rebuild_rows() -> void:
	var kids: Array = _stage_list.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child != null:
			_stage_list.remove_child(child)
			child.queue_free()
	_stage_list.add_theme_constant_override("separation", int(ROW_GAP))
	for i in STAGE_COUNT:
		_stage_list.add_child(_make_row(i))


func _make_row(index: int) -> HudGeoButton:
	var selected: bool = index == _selected
	var playable: bool = _can_play(index)
	var locked: bool = not _is_unlocked(index)
	var row := HudGeoButton.new()
	row.geo = HudGeoButton.Geo.CHIP
	row.shear = 28.0
	row.title_size = 12
	row.custom_minimum_size = Vector2(ROW_W + (ROW_SELECTED_EXTRA if selected else 0.0), ROW_H)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	if locked:
		row.fill_key = "header"
		row.border_key = "muted"
	elif selected and playable:
		row.fill_key = "gold"
		row.border_key = "gold"
	elif selected:
		row.fill_key = "cyan"
		row.border_key = "cyan"
	else:
		row.fill_key = "panel"
		row.border_key = "cyan"
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	row.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 16)
	pad.add_child(body)
	var num_color: Color = Palette.TEXT_ON_GOLD if selected and playable else Palette.TEXT_PRIMARY
	if locked:
		num_color = Palette.TEXT_MUTED
	var num := _card_label("%02d" % (index + 1), num_color, 16, false)
	num.custom_minimum_size = Vector2(40, 0)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(num)
	var name_color: Color = num_color
	if selected and playable:
		name_color = Palette.TEXT_ON_GOLD
	elif not locked:
		name_color = Palette.TEXT_PRIMARY
	var name_label := _card_label(_stage_name(index), name_color, 11, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	body.add_child(name_label)
	if selected and playable:
		var start_lbl := _card_label("START", Palette.TEXT_ON_GOLD, 12, false)
		start_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.add_child(start_lbl)
	if locked:
		var overlay := CenterContainer.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glyph := IntelPixelIcon.new()
		glyph.kind = IntelPixelIcon.Kind.LOCK
		glyph.monochrome = true
		glyph.custom_minimum_size = Vector2(44, 44)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.modulate = Palette.TEXT_MUTED
		overlay.add_child(glyph)
	var captured: int = index
	row.pressed.connect(func() -> void: _select_stage(captured))
	return row


func _select_stage(index: int) -> void:
	if index < 0 or index >= STAGE_COUNT:
		return
	_selected = index
	current_selected_stage = maxi(0, _launch_index(index))
	_rebuild_rows()
	_refresh_detail()
	_refresh_breach()


func _refresh_detail() -> void:
	var config: Dictionary = _stage_config(_selected)
	var locked: bool = not _is_unlocked(_selected)
	var playable: bool = _can_play(_selected)
	_stage_title.text = _stage_name(_selected)
	var entry: Dictionary = _module_entry()
	_stage_sub.text = "MODULE %d  ·  %s" % [_module_index + 1, str(entry.get("title", "")).to_upper()]
	_score_label.text = "BEST  --"
	_apply_label(_score_label, Palette.TEXT_PRIMARY, 18)
	_apply_label(_stage_title, Palette.TEXT_PRIMARY, 16)
	_apply_label(_stage_sub, Palette.CYAN, 10)
	var type_text := "LOCKED"
	var waves_text := "WAVES --"
	var gold_text := "GOLD --"
	if not config.is_empty():
		type_text = str(config.get("type", "stage")).to_upper()
		var waves: Array = config.get("waves", [])
		waves_text = "WAVES %d" % waves.size()
		gold_text = "GOLD %d" % int(config.get("starting_gold", 0))
	elif locked:
		type_text = "LOCKED"
	else:
		type_text = "SOON"
	_type_chip.title = type_text
	_waves_chip.title = waves_text
	_gold_chip.title = gold_text
	_type_chip.fill_key = "gold" if playable else "header"
	_type_chip.border_key = "gold" if playable else "muted"
	_waves_chip.fill_key = "panel"
	_waves_chip.border_key = "cyan" if not locked else "muted"
	_gold_chip.fill_key = "panel"
	_gold_chip.border_key = "cyan" if not locked else "muted"
	_type_chip.queue_redraw()
	_waves_chip.queue_redraw()
	_gold_chip.queue_redraw()
	var accent: Color = _module_accent()
	if locked:
		accent = Palette.TEXT_MUTED
	_art_well.add_theme_stylebox_override("panel", _pixel_box(Color(accent, 0.42), Color(Palette.TEXT_PRIMARY, 0.16), 0, 2))
	_art_glyph.kind = IntelPixelIcon.Kind.LOCK if locked else _glyph_for_stage(_selected)
	_art_glyph.modulate = Palette.TEXT_MUTED if locked else Color(1.0, 1.0, 1.0, 1.0)
	_art_glyph.queue_redraw()


func _refresh_breach() -> void:
	if _can_play(_selected):
		_breach_button.title = "BREACH  >"
		_breach_button.fill_key = "gold"
		_breach_button.border_key = "gold"
	elif _stage_id(_selected) < 0 or _stage_config(_selected).is_empty():
		_breach_button.title = "SOON"
		_breach_button.fill_key = "header"
		_breach_button.border_key = "muted"
	else:
		_breach_button.title = "LOCKED"
		_breach_button.fill_key = "header"
		_breach_button.border_key = "muted"
	_breach_button.queue_redraw()


func _on_breach_pressed() -> void:
	if not _can_play(_selected):
		return
	var launch: int = _launch_index(_selected)
	if launch < 0:
		return
	current_selected_stage = launch
	Router.start_level(launch)


func _first_playable() -> int:
	for i in STAGE_COUNT:
		if _can_play(i):
			return i
	return 0


func _is_unlocked(index: int) -> bool:
	var stage_id: int = _stage_id(index)
	if stage_id <= 0:
		return false
	var config: Dictionary = StageManager.get_stage_config(stage_id)
	if config.is_empty():
		return false
	if index > 0:
		var prev_clear: int = _previous_playable_id(index)
		if prev_clear > 0 and PlayerManager.mock_max_stage_cleared < prev_clear:
			return false
	var req := str(config.get("req_lesson", ""))
	if not req.is_empty() and not PlayerManager.has_completed_lesson(req):
		return false
	if PlayerManager.is_stage_locked(stage_id):
		return false
	return true


func _can_play(index: int) -> bool:
	return _is_unlocked(index) and not _stage_config(index).is_empty()


func _previous_playable_id(index: int) -> int:
	var i: int = index - 1
	while i >= 0:
		var stage_id: int = _stage_id(i)
		if stage_id > 0 and not StageManager.get_stage_config(stage_id).is_empty():
			return stage_id
		i -= 1
	return 0


func _stage_id(index: int) -> int:
	# Only module 1 maps onto STAGE_DB ids 1, 2, and 10. Other modules have no TD data yet.
	if _module_index != 0:
		return -1
	return index + 1


func _launch_index(index: int) -> int:
	var stage_id: int = _stage_id(index)
	if stage_id <= 0:
		return -1
	return stage_id - 1


func _stage_config(index: int) -> Dictionary:
	var stage_id: int = _stage_id(index)
	if stage_id <= 0:
		return {}
	return StageManager.get_stage_config(stage_id)


func _stage_name(index: int) -> String:
	var config: Dictionary = _stage_config(index)
	if not config.is_empty():
		return str(config.get("name", "STAGE %d" % (index + 1))).to_upper()
	return "STAGE %d" % (index + 1)


func _module_entry() -> Dictionary:
	if _module_index < 0 or _module_index >= _modules.size():
		return {}
	return _modules[_module_index]


func _module_accent() -> Color:
	return _accent_of(str(_module_entry().get("accent", "cyan")))


func _glyph_for_stage(index: int) -> IntelPixelIcon.Kind:
	var config: Dictionary = _stage_config(index)
	var kind := str(config.get("type", ""))
	match kind:
		"diagnostic":
			return IntelPixelIcon.Kind.TERMINAL
		"formative":
			return IntelPixelIcon.Kind.BADGE
		"summative":
			return IntelPixelIcon.Kind.SKULL
		_:
			return _module_glyph()


func _module_glyph() -> IntelPixelIcon.Kind:
	match _module_index:
		0:
			return IntelPixelIcon.Kind.ENVELOPE
		1:
			return IntelPixelIcon.Kind.PHONE
		2:
			return IntelPixelIcon.Kind.PHONE
		3:
			return IntelPixelIcon.Kind.BADGE
		_:
			return IntelPixelIcon.Kind.SKULL


func _style_back() -> void:
	_back_button.text = tr("SETT_BACK")
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 14)
	_back_button.add_theme_color_override("font_color", Palette.FIELD_PLACEHOLDER)
	_back_button.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)


func _accent_of(name: String) -> Color:
	match name:
		"green":
			return Palette.GREEN
		"magenta":
			return Palette.MAGENTA
		"gold":
			return Palette.GOLD
		"muted":
			return Palette.TEXT_MUTED
		_:
			return Palette.CYAN


func _card_label(text: String, color: Color, font_size: int, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	_apply_label(label, color, font_size)
	return label


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
