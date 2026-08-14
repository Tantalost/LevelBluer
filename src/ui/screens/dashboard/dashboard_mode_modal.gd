class_name DashboardModeModal
extends Control
## SELECT GAME MODE overlay — matches DashboardScreen.tsx mode modal.

signal mode_confirmed(mode: StringName)
signal cancelled

enum Mode { SOLO, PVP }

var SOLO_GRADIENT := PackedColorArray([
	Color("#0a2a4a"), Color("#0d3d6e"), Color("#1a5fa0"),
])
var PVP_GRADIENT := PackedColorArray([
	Color("#3a0a1a"), Color("#6e1030"), Color("#a01a45"),
])

@onready var _overlay: ColorRect = $Overlay
@onready var _title: Label = %ModalTitle
@onready var _subtitle: Label = %ModalSubtitle
@onready var _solo_card: Control = %SoloCard
@onready var _pvp_card: Control = %PvpCard
@onready var _solo_overlay: ColorRect = %SoloDarkOverlay
@onready var _pvp_overlay: ColorRect = %PvpDarkOverlay
@onready var _solo_bottom: PanelContainer = %SoloBottom
@onready var _pvp_bottom: PanelContainer = %PvpBottom
@onready var _solo_badge: PanelContainer = %SoloBadge
@onready var _pvp_badge: PanelContainer = %PvpBadge
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton

var selected_mode: Mode = Mode.SOLO
var _pixel_font: Font
var _view_width: float = 1280.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_load_font()
	_solo_card.gui_input.connect(func(e): _on_card_input(e, Mode.SOLO))
	_pvp_card.gui_input.connect(func(e): _on_card_input(e, Mode.PVP))
	_confirm.pressed.connect(_confirm_selection)
	_cancel.pressed.connect(_close)


func open(initial_mode: Mode = Mode.SOLO, viewport_width: float = 1280.0) -> void:
	_view_width = viewport_width
	selected_mode = initial_mode
	visible = true
	_apply_copy()
	_apply_scale()
	_refresh_selection(false)
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
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		var file := load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
		if file != null:
			_pixel_font = file


func _apply_copy() -> void:
	_title.text = tr("DASH_MODE_TITLE")
	_subtitle.text = tr("DASH_MODE_SUBTITLE")
	_cancel.text = tr("DASH_MODE_CANCEL")
	_refresh_confirm_label()


func _apply_scale() -> void:
	var scaled := func(value: float) -> int: return UiScale.n(value, _view_width)
	var border_width := func(value: float) -> int: return UiScale.bw(value, _view_width)

	for label in [_title, _subtitle]:
		if _pixel_font:
			label.add_theme_font_override("font", _pixel_font)
	_title.add_theme_font_size_override("font_size", scaled.call(20))
	_subtitle.add_theme_font_size_override("font_size", scaled.call(10))

	_solo_card.custom_minimum_size = Vector2(scaled.call(200), scaled.call(300))
	_pvp_card.custom_minimum_size = Vector2(scaled.call(200), scaled.call(300))
	_confirm.add_theme_font_size_override("font_size", scaled.call(14))
	_cancel.add_theme_font_size_override("font_size", scaled.call(9))
	if _pixel_font:
		_confirm.add_theme_font_override("font", _pixel_font)
		_cancel.add_theme_font_override("font", _pixel_font)

	var card_border: int = border_width.call(3)
	for card in [_solo_card, _pvp_card]:
		var panel: PanelContainer = card.get_node("CardPanel")
		var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_width_left = card_border
		style.border_width_top = card_border
		style.border_width_right = card_border
		style.border_width_bottom = card_border
		panel.add_theme_stylebox_override("panel", style)


func _on_card_input(event: InputEvent, mode: Mode) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_mode(mode)


func _select_mode(mode: Mode) -> void:
	if selected_mode == mode:
		return
	selected_mode = mode
	_refresh_selection(true)
	_refresh_confirm_label()


func _refresh_selection(animate: bool) -> void:
	var solo_active := selected_mode == Mode.SOLO
	var pvp_active := selected_mode == Mode.PVP

	_solo_overlay.visible = not solo_active
	_pvp_overlay.visible = not pvp_active
	_solo_badge.visible = solo_active
	_pvp_badge.visible = pvp_active

	_apply_card_border(_solo_card, solo_active, solo_active)
	_apply_card_border(_pvp_card, pvp_active, pvp_active)

	var solo_target := Vector2.ONE if solo_active else Vector2(0.88, 0.88)
	var pvp_target := Vector2.ONE if pvp_active else Vector2(0.88, 0.88)

	if animate:
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tween.tween_property(_solo_card, "scale", solo_target, 0.35)
		tween.tween_property(_pvp_card, "scale", pvp_target, 0.35)
	else:
		_solo_card.scale = solo_target
		_pvp_card.scale = pvp_target


func _apply_card_border(card: Control, active: bool, is_solo: bool) -> void:
	var panel: PanelContainer = card.get_node("CardPanel")
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if active:
		style.border_color = Color("#ffd23f") if is_solo else Color("#ffd23f")
		if not is_solo:
			style.border_color = Color("#ffd23f")
	else:
		style.border_color = Color("#1a252f")
	panel.add_theme_stylebox_override("panel", style)

	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(1, 1, 1, 0.18) if active else Color(0, 0, 0, 0.5)
	if active:
		bottom_style.border_width_top = UiScale.bw(2, _view_width)
		bottom_style.border_color = Color("#ffd23f") if is_solo else Color("#ff4466")
		bottom_style.bg_color = Color(1, 0.82, 0.25, 0.18) if is_solo else Color(1, 0.27, 0.4, 0.18)
	var bottom: PanelContainer = _solo_bottom if is_solo else _pvp_bottom
	bottom.add_theme_stylebox_override("panel", bottom_style)


func _refresh_confirm_label() -> void:
	var icon := "🛡️" if selected_mode == Mode.SOLO else "⚔️"
	_confirm.text = "%s  %s" % [tr("DASH_MODE_CONFIRM"), icon]
	var style := _confirm.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if selected_mode == Mode.PVP:
		style.bg_color = Color("#ff4466")
		style.border_color = Color("#ff8899")
	else:
		style.bg_color = Color("#ffd23f")
		style.border_color = Color("#fff8d0")
	_confirm.add_theme_stylebox_override("normal", style)
	_confirm.add_theme_stylebox_override("hover", style)
	_confirm.add_theme_stylebox_override("pressed", style)


func _confirm_selection() -> void:
	mode_confirmed.emit(get_mode_name())
	visible = false
	modulate.a = 1.0


func _close() -> void:
	close()
