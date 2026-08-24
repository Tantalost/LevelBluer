class_name DashboardModeModal
extends Control
## SELECT GAME MODE overlay. Sheet layout matches MissionsScreen; chrome matches Dashboard.

signal mode_confirmed(mode: StringName)
signal cancelled

enum Mode { SOLO, PVP }

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _dimmer: ColorRect = %Dimmer
@onready var _modal_card: PanelContainer = %ModalCard
@onready var _title: Label = %ModalTitle
@onready var _subtitle: Label = %ModalSubtitle
@onready var _body_panel: PanelContainer = %BodyPanel
@onready var _solo_card: PanelContainer = %SoloCard
@onready var _pvp_card: PanelContainer = %PvpCard
@onready var _solo_header: PanelContainer = %SoloHeader
@onready var _pvp_header: PanelContainer = %PvpHeader
@onready var _solo_header_label: Label = %SoloHeaderLabel
@onready var _pvp_header_label: Label = %PvpHeaderLabel
@onready var _solo_title: Label = %SoloTitle
@onready var _pvp_title: Label = %PvpTitle
@onready var _solo_sub: Label = %SoloSub
@onready var _pvp_sub: Label = %PvpSub
@onready var _solo_badge: PanelContainer = %SoloBadge
@onready var _pvp_badge: PanelContainer = %PvpBadge
@onready var _solo_badge_label: Label = %SoloBadgeLabel
@onready var _pvp_badge_label: Label = %PvpBadgeLabel
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton

var selected_mode: Mode = Mode.SOLO
var _pixel_font: Font
var _view_width: float = 1280.0
var _chrome: Color = Palette.FOREST_NIGHT


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_load_font()
	_chrome = Palette.FOREST_NIGHT.lerp(Palette.PINE, 0.42)
	_dimmer.color = Color(Palette.BG_DEEP, 0.62)
	_solo_card.gui_input.connect(func(e: InputEvent) -> void: _on_card_input(e, Mode.SOLO))
	_pvp_card.gui_input.connect(func(e: InputEvent) -> void: _on_card_input(e, Mode.PVP))
	_confirm.pressed.connect(_confirm_selection)
	_cancel.pressed.connect(_close)
	_dimmer.gui_input.connect(_on_dimmer_gui)


func open(initial_mode: Mode = Mode.SOLO, viewport_width: float = 1280.0) -> void:
	_view_width = viewport_width
	selected_mode = initial_mode
	visible = true
	_apply_copy()
	_apply_scale()
	_style_sheet()
	_refresh_selection()
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func close() -> void:
	if not visible:
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.15)
	await fade.finished
	visible = false
	cancelled.emit()


func get_mode_name() -> StringName:
	return &"SOLO" if selected_mode == Mode.SOLO else &"PVP"


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file


func _apply_copy() -> void:
	_title.text = tr("DASH_MODE_TITLE")
	_subtitle.text = tr("DASH_MODE_SUBTITLE")
	_cancel.text = tr("DASH_MODE_CANCEL")
	_confirm.text = tr("DASH_MODE_CONFIRM")


func _apply_scale() -> void:
	var title_size: int = UiScale.n(16.0, _view_width)
	var sub_size: int = UiScale.n(8.0, _view_width)
	var card_title: int = UiScale.n(20.0, _view_width)
	var confirm_size: int = UiScale.n(12.0, _view_width)
	_apply_label(_title, Palette.TEXT_PRIMARY, title_size)
	_apply_label(_subtitle, Palette.CYAN, sub_size)
	_apply_label(_solo_header_label, Palette.CYAN, sub_size)
	_apply_label(_pvp_header_label, Palette.RED, sub_size)
	_apply_label(_solo_title, Palette.FIELD_TEXT, card_title)
	_apply_label(_pvp_title, Palette.FIELD_TEXT, card_title)
	_apply_label(_solo_sub, Color(Palette.FIELD_TEXT, 0.55), sub_size)
	_apply_label(_pvp_sub, Color(Palette.FIELD_TEXT, 0.55), sub_size)
	_apply_label(_solo_badge_label, Palette.BG_DEEP, sub_size)
	_apply_label(_pvp_badge_label, Palette.TEXT_PRIMARY, sub_size)
	if _pixel_font != null:
		_confirm.add_theme_font_override("font", _pixel_font)
		_cancel.add_theme_font_override("font", _pixel_font)
	_confirm.add_theme_font_size_override("font_size", confirm_size)
	_cancel.add_theme_font_size_override("font_size", sub_size)
	_solo_card.custom_minimum_size = Vector2(UiScale.n(248.0, _view_width), UiScale.n(220.0, _view_width))
	_pvp_card.custom_minimum_size = Vector2(UiScale.n(248.0, _view_width), UiScale.n(220.0, _view_width))


func _style_sheet() -> void:
	var card := _pixel_box(_chrome, _chrome, 18, 0)
	card.content_margin_left = 0.0
	card.content_margin_right = 0.0
	card.content_margin_top = 0.0
	card.content_margin_bottom = 0.0
	card.shadow_color = Color(Palette.BG_DEEP, 0.7)
	card.shadow_size = 12
	card.shadow_offset = Vector2(0, 6)
	_modal_card.add_theme_stylebox_override("panel", card)
	_modal_card.custom_minimum_size = Vector2(UiScale.n(640.0, _view_width), UiScale.n(420.0, _view_width))

	var body := _pixel_box(Palette.BG_PANEL, Palette.BG_PANEL, 0, 0)
	_body_panel.add_theme_stylebox_override("panel", body)

	_style_header(_solo_header, Palette.PINE)
	_style_header(_pvp_header, Palette.RED_DEEP)
	_style_confirm()
	_style_cancel()


func _style_header(header: PanelContainer, fill: Color) -> void:
	var box := _pixel_box(fill, fill, 0, 0)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	header.add_theme_stylebox_override("panel", box)


func _style_confirm() -> void:
	var accent: Color = Palette.CYAN if selected_mode == Mode.SOLO else Palette.RED
	var fill: Color = Palette.PINE if selected_mode == Mode.SOLO else Palette.RED_DEEP
	var box := _pixel_box(fill, accent, 8, 2)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	_confirm.add_theme_stylebox_override("normal", box)
	_confirm.add_theme_stylebox_override("hover", box)
	_confirm.add_theme_stylebox_override("pressed", box)
	_confirm.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)


func _style_cancel() -> void:
	var empty := StyleBoxEmpty.new()
	_cancel.add_theme_stylebox_override("normal", empty)
	_cancel.add_theme_stylebox_override("hover", empty)
	_cancel.add_theme_stylebox_override("pressed", empty)
	_cancel.add_theme_color_override("font_color", Palette.TEXT_MUTED)


func _on_dimmer_gui(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _modal_card.get_global_rect().has_point(mouse.global_position):
		return
	_close()


func _on_card_input(event: InputEvent, mode: Mode) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_select_mode(mode)


func _select_mode(mode: Mode) -> void:
	if selected_mode == mode:
		return
	selected_mode = mode
	_refresh_selection()
	_style_confirm()


func _refresh_selection() -> void:
	var solo_active: bool = selected_mode == Mode.SOLO
	var pvp_active: bool = selected_mode == Mode.PVP
	_solo_badge.visible = solo_active
	_pvp_badge.visible = pvp_active
	_style_mode_card(_solo_card, solo_active, true)
	_style_mode_card(_pvp_card, pvp_active, false)
	_style_badge(_solo_badge, Palette.CYAN)
	_style_badge(_pvp_badge, Palette.RED)
	_apply_label(_solo_title, Palette.FIELD_TEXT if solo_active else Palette.TEXT_PRIMARY, UiScale.n(20.0, _view_width))
	_apply_label(_pvp_title, Palette.FIELD_TEXT if pvp_active else Palette.TEXT_PRIMARY, UiScale.n(20.0, _view_width))
	_apply_label(_solo_sub, Color(Palette.FIELD_TEXT, 0.7) if solo_active else Palette.TEXT_SECONDARY, UiScale.n(8.0, _view_width))
	_apply_label(_pvp_sub, Color(Palette.FIELD_TEXT, 0.7) if pvp_active else Palette.TEXT_SECONDARY, UiScale.n(8.0, _view_width))
	_apply_label(_solo_header_label, Palette.CYAN if solo_active else Palette.CYAN_DIM, UiScale.n(8.0, _view_width))
	_apply_label(_pvp_header_label, Palette.RED if pvp_active else Color(Palette.RED, 0.55), UiScale.n(8.0, _view_width))


func _style_mode_card(card: PanelContainer, active: bool, is_solo: bool) -> void:
	var accent: Color = Palette.CYAN if is_solo else Palette.RED
	var fill: Color = Color(Palette.FIELD_BG, 1.0) if active else Color(Palette.BG_PANEL_ALT, 0.92)
	var border: Color = accent if active else Color(Palette.TEXT_MUTED, 0.35)
	var box := _pixel_box(fill, border, 10, 2 if active else 1)
	card.add_theme_stylebox_override("panel", box)


func _style_badge(badge: PanelContainer, fill: Color) -> void:
	var box := _pixel_box(fill, fill, 10, 0)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	badge.add_theme_stylebox_override("panel", box)


func _confirm_selection() -> void:
	mode_confirmed.emit(get_mode_name())
	visible = false
	modulate.a = 1.0


func _close() -> void:
	close()


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
