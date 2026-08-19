extends BaseScreen
## Module carousel. Unlocked packs open the per-module stage list.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const CARD_W := 276.0
const CARD_H := 418.0
const CARD_GAP := 32.0
const CARD_SELECTED_EXTRA := 16.0
const UPGRADES_W := 152.0
const UPGRADES_H := 392.0

@onready var _safe: MarginContainer = %SafeArea
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _player_name: Label = %PlayerName
@onready var _threat_value: Label = %ThreatValue
@onready var _materials_value: Label = %MaterialsValue
@onready var _settings_button: HudGeoButton = %SettingsButton
@onready var _upgrades_card: Button = %UpgradesCard
@onready var _tab_fill: ColorRect = %TabFill
@onready var _modules_tab_label: Label = %ModulesTabLabel
@onready var _card_scroll: ScrollContainer = %CardScroll
@onready var _card_row: HBoxContainer = %CardRow
@onready var _main_menu: HudGeoButton = %MainMenuButton
@onready var _breach_button: HudGeoButton = %BreachButton

var _pixel_font: Font
var _modules: Array[Dictionary] = []
var _selected: int = 0
var _cards: Array[Button] = []
var current_selected_stage: int = 0


func _ready() -> void:
	_load_font()
	_modules = LessonCatalog.modules()
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_main_menu.pressed.connect(func() -> void: Router.request_back())
	_settings_button.pressed.connect(func() -> void: Router.push(&"settings"))
	_upgrades_card.pressed.connect(func() -> void: Router.push(&"upgrades"))
	_breach_button.pressed.connect(_on_breach_pressed)
	%ProfileButton.pressed.connect(func() -> void: Router.push(&"profile"))
	_style_upgrades_card()
	_style_back()
	_apply_spacing()
	_rebuild_cards()


func on_enter(_args: Dictionary) -> void:
	visible = true
	_modules = LessonCatalog.modules()
	_selected = _first_unlocked()
	current_selected_stage = _td_index_for(_selected)
	_refresh_header()
	_rebuild_cards()
	_refresh_breach()


func on_resume() -> void:
	visible = true
	_refresh_header()
	_rebuild_cards()
	_refresh_breach()


func on_exit() -> void:
	visible = false


func _refresh_header() -> void:
	_title_label.text = "SELECT A MODULE"
	_player_name.text = "<%s>" % AuthService.display_name().to_upper()
	var threat: int = AuthService.wallet_threat_points()
	var mats: int = AuthService.materials()
	_threat_value.text = str(threat if threat >= 0 else 0)
	_materials_value.text = str(mats if mats >= 0 else 0)
	_tab_fill.color = Palette.GOLD
	_modules_tab_label.text = "M\nO\nD\nU\nL\nE\nS"
	_apply_label(_title_label, Palette.TEXT_PRIMARY, 14)
	_apply_label(_player_name, Palette.TEXT_PRIMARY, 11)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_materials_value, Palette.TEXT_PRIMARY, 12)
	_apply_label(_modules_tab_label, Palette.BG_DEEP, 10)
	_apply_label(%UpgradesTitle, Palette.TEXT_PRIMARY, 12)
	_apply_label(%UpgradesSub, Palette.CYAN, 9)
	_style_back()
	_style_upgrades_card()
	%AvatarBox.add_theme_stylebox_override("panel", _pixel_box(Palette.FOREST_NIGHT, Palette.CYAN, 0, 2))
	_apply_spacing()


func _style_back() -> void:
	_back_button.text = tr("SETT_BACK")
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 14)
	_back_button.add_theme_color_override("font_color", Palette.FIELD_PLACEHOLDER)
	_back_button.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)


func _apply_spacing() -> void:
	_safe.add_theme_constant_override("margin_left", 22)
	_safe.add_theme_constant_override("margin_top", 16)
	_safe.add_theme_constant_override("margin_right", 22)
	_safe.add_theme_constant_override("margin_bottom", 14)
	var layout: VBoxContainer = _safe.get_node_or_null("ScreenLayout") as VBoxContainer
	if layout != null:
		layout.add_theme_constant_override("separation", 20)
	var carousel: HBoxContainer = null
	if layout != null:
		carousel = layout.get_node_or_null("CarouselRow") as HBoxContainer
	if carousel != null:
		carousel.add_theme_constant_override("separation", 22)
		carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	_upgrades_card.custom_minimum_size = Vector2(UPGRADES_W, UPGRADES_H)
	_upgrades_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if carousel != null:
		var tab: Control = carousel.get_node_or_null("ModulesTab") as Control
		if tab != null:
			tab.custom_minimum_size = Vector2(32, UPGRADES_H - 24.0)
			tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_row.add_theme_constant_override("separation", int(CARD_GAP))
	_card_row.custom_minimum_size = Vector2(0, CARD_H)
	_card_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _style_upgrades_card() -> void:
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.GOLD, 0, 3)
	_upgrades_card.add_theme_stylebox_override("normal", box)
	_upgrades_card.add_theme_stylebox_override("hover", _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.TEXT_PRIMARY, 0, 3))
	_upgrades_card.add_theme_stylebox_override("pressed", box)
	%UpgradesWell.add_theme_stylebox_override("panel", _pixel_box(Palette.GOLD_DIM, Color(Palette.TEXT_PRIMARY, 0.16), 0, 2))


func _rebuild_cards() -> void:
	var kids: Array = _card_row.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child != null:
			_card_row.remove_child(child)
			child.queue_free()
	_cards.clear()
	for i in _modules.size():
		var card := _make_module_card(i)
		_card_row.add_child(card)
		_cards.append(card)
	_center_selected_card.call_deferred()


func _make_module_card(index: int) -> Button:
	var entry: Dictionary = _modules[index]
	var locked: bool = not _is_unlocked(index)
	var selected: bool = index == _selected
	var accent: Color = _accent_of(str(entry.get("accent", "cyan")))
	if locked:
		accent = Palette.TEXT_MUTED
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_W + (CARD_SELECTED_EXTRA if selected else 0.0), CARD_H)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var border: Color = Palette.GOLD if selected else accent
	var box := _pixel_box(Color(Palette.BG_HEADER, 0.94), border, 0, 3 if selected else 2)
	card.add_theme_stylebox_override("normal", box)
	card.add_theme_stylebox_override("hover", _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.TEXT_PRIMARY, 0, 3))
	card.add_theme_stylebox_override("pressed", box)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 16)
	card.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 12)
	pad.add_child(body)
	body.add_child(_card_label("MODULE %d" % (index + 1), Palette.TEXT_PRIMARY, 15, true))
	body.add_child(_card_label(str(entry.get("title", "")).to_upper(), Palette.CYAN if not locked else Palette.TEXT_MUTED, 10, true))
	var total: int = maxi(1, LessonCatalog.lesson_count(str(entry.get("id", ""))))
	var done: int = 0 if locked else mini(PlayerManager.get_lesson_progress(str(entry.get("id", ""))), total)
	if _is_complete(index):
		done = total
	body.add_child(_card_label("CLR %d    ALL %d" % [done, total], Palette.TEXT_PRIMARY, 9, true))
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_theme_stylebox_override("panel", _pixel_box(Color(accent, 0.42 if not locked else 0.18), Color(Palette.TEXT_PRIMARY, 0.12), 0, 2))
	body.add_child(well)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_child(center)
	var glyph := IntelPixelIcon.new()
	glyph.kind = IntelPixelIcon.Kind.LOCK if locked else _glyph_for(index)
	glyph.monochrome = true
	glyph.custom_minimum_size = Vector2(108, 108)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(glyph)
	if locked:
		body.add_child(_card_label("LOCKED", Palette.TEXT_MUTED, 11, true))
	elif _td_index_for(index) < 0:
		body.add_child(_card_label("SOON", Palette.GOLD, 11, true))
	var captured: int = index
	card.pressed.connect(func() -> void: _select_module(captured))
	return card


func _select_module(index: int) -> void:
	if index < 0 or index >= _modules.size():
		return
	_selected = index
	current_selected_stage = maxi(0, _td_index_for(index))
	_rebuild_cards()
	_refresh_breach()
	if _is_unlocked(index):
		_open_module(index)


func _center_selected_card() -> void:
	if _selected < 0 or _selected >= _cards.size():
		return
	var card: Button = _cards[_selected]
	var view_w := _card_scroll.size.x
	if view_w <= 1.0:
		return
	var target := int(card.position.x - (view_w - card.size.x) * 0.5)
	_card_scroll.scroll_horizontal = maxi(0, target)


func _first_unlocked() -> int:
	for i in _modules.size():
		if _is_unlocked(i):
			return i
	return 0


func _is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	return _is_complete(index - 1)


func _is_complete(index: int) -> bool:
	if index < 0 or index >= _modules.size():
		return false
	var module_id := str(_modules[index].get("id", ""))
	return PlayerManager.get_lesson_progress(module_id) >= LessonCatalog.lesson_count(module_id)


func _td_index_for(module_index: int) -> int:
	# STAGE_DB currently has ids 1 and 2 (plus exam 10). Do not invent stages.
	if module_index == 0 or module_index == 1:
		return module_index
	return -1


func _can_open() -> bool:
	return not _modules.is_empty() and _is_unlocked(_selected)


func _refresh_breach() -> void:
	if _can_open():
		_breach_button.title = "OPEN  >"
		_breach_button.fill_key = "gold"
		_breach_button.border_key = "gold"
	else:
		_breach_button.title = "LOCKED"
		_breach_button.fill_key = "header"
		_breach_button.border_key = "muted"
	_breach_button.queue_redraw()


func _on_breach_pressed() -> void:
	if not _can_open():
		return
	_open_module(_selected)


func _open_module(index: int) -> void:
	if not _is_unlocked(index):
		return
	Router.push(&"module_stages", {"module_index": index})


func _glyph_for(index: int) -> IntelPixelIcon.Kind:
	match index:
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
