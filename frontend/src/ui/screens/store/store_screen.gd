class_name StoreScreen
extends BaseScreen
## Cosmetic shop. Matches StoreScreen.tsx: categories, confirm buy, threat spend.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const CATS: PackedStringArray = ["TRENDING", "PROFILES", "BORDERS"]

@onready var _os_bar: PanelContainer = %OsBar
@onready var _os_led: ColorRect = %OsLed
@onready var _os_cursor: Label = %OsCursor
@onready var _back_button: Button = %BackButton
@onready var _header_title: Label = %HeaderTitle
@onready var _threat_box: PanelContainer = %ThreatBox
@onready var _threat_value: Label = %ThreatValue
@onready var _cat_row: HBoxContainer = %CategoryRow
@onready var _item_grid: GridContainer = %ItemGrid
@onready var _modal: ColorRect = %PurchaseModal
@onready var _modal_card: PanelContainer = %ModalCard
@onready var _modal_title: Label = %ModalTitle
@onready var _modal_text: Label = %ModalText
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _ground: ColorRect = %Ground

var _pixel_font: Font
var _category: String = "TRENDING"
var _pending: Dictionary = {}
var _blink_t: float = 0.0
var _toast_left: float = 0.0
var _cat_buttons: Array[Button] = []


func _ready() -> void:
	_load_font()
	_ground.color = Palette.FOREST_FLOOR
	_style_os_bar()
	_style_close_button()
	_style_threat_pill()
	_style_modal()
	_apply_label(_header_title, Palette.TEXT_PRIMARY, 12)
	_apply_label(_os_cursor, Palette.GREEN, 12)
	_apply_label(_threat_value, Palette.TEXT_PRIMARY, 10)
	_apply_label(_modal_title, Palette.TEXT_PRIMARY, 14)
	_apply_label(_modal_text, Palette.GOLD, 11)
	_apply_label(_toast_label, Palette.TEXT_PRIMARY, 11)
	_header_title.text = "STORE.DAT"
	_back_button.pressed.connect(func() -> void: Router.request_back())
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_hide_modal)
	_modal.gui_input.connect(_on_modal_gui)
	_modal.visible = false
	_toast.visible = false
	_build_categories()


func _process(delta: float) -> void:
	_blink_t += delta
	var on := fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false


func on_enter(_args: Dictionary) -> void:
	set_process(true)
	_category = "TRENDING"
	_hide_modal()
	_refresh_wallet()
	_refresh_categories()
	_rebuild_items()


func on_resume() -> void:
	set_process(true)
	_refresh_wallet()
	_rebuild_items()


func on_exit() -> void:
	set_process(false)


func can_go_back() -> bool:
	if _modal.visible:
		_hide_modal()
		return false
	return true


func _build_categories() -> void:
	var existing: Array = _cat_row.get_children()
	for i in existing.size():
		existing[i].queue_free()
	_cat_buttons.clear()
	for i in CATS.size():
		var cat := str(CATS[i])
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = cat
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 40)
		if _pixel_font != null:
			button.add_theme_font_override("font", _pixel_font)
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_select_category.bind(cat))
		_cat_row.add_child(button)
		_cat_buttons.append(button)


func _select_category(cat: String) -> void:
	_category = cat
	_refresh_categories()
	_rebuild_items()


func _refresh_categories() -> void:
	for i in _cat_buttons.size():
		var button := _cat_buttons[i]
		var active := button.text == _category
		var box := _pixel_box(Color(Palette.BG_DEEP, 0.35), Palette.GOLD if active else Palette.CYAN_DIM, 0, 2)
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		button.add_theme_stylebox_override("normal", box)
		button.add_theme_stylebox_override("hover", box)
		button.add_theme_stylebox_override("pressed", box)
		button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)


func _catalog_for(cat: String) -> Array:
	match cat:
		"PROFILES":
			return [
				{"id": "p1", "name": "Commander Avatar", "price": 800},
				{"id": "p2", "name": "Operative Icon", "price": 450},
			]
		"BORDERS":
			return [
				{"id": "b1", "name": "Gold Frame", "price": 300},
				{"id": "b2", "name": "Shadow Border", "price": 600},
			]
		_:
			return [
				{"id": "t1", "name": "Assault Frame", "price": 500},
				{"id": "t2", "name": "Recon Drone", "price": 350},
				{"id": "t3", "name": "Ghost Cloak", "price": 1200},
			]


func _rebuild_items() -> void:
	var kids: Array = _item_grid.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child != null:
			_item_grid.remove_child(child)
			child.queue_free()
	var list: Array = _catalog_for(_category)
	for i in list.size():
		var item: Dictionary = list[i]
		_item_grid.add_child(_make_card(item))


func _make_card(item: Dictionary) -> PanelContainer:
	var owned := PlayerManager.owns_store_item(str(item.get("id", "")))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_box := _pixel_box(Color(Palette.FOREST_NIGHT, 0.92), Palette.CYAN_DIM, 0, 2)
	card_box.content_margin_left = 12.0
	card_box.content_margin_right = 12.0
	card_box.content_margin_top = 12.0
	card_box.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_box)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "")).to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label(name_label, Palette.TEXT_PRIMARY, 11)
	var price_label := Label.new()
	price_label.text = "%d TP" % int(item.get("price", 0))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label(price_label, Palette.GOLD, 10)
	var buy := Button.new()
	buy.focus_mode = Control.FOCUS_NONE
	buy.custom_minimum_size = Vector2(0, 36)
	buy.text = "OWNED" if owned else "BUY"
	buy.disabled = owned
	if _pixel_font != null:
		buy.add_theme_font_override("font", _pixel_font)
	buy.add_theme_font_size_override("font_size", 11)
	_style_buy(buy, owned)
	if not owned:
		buy.pressed.connect(_open_modal.bind(item))
	col.add_child(name_label)
	col.add_child(price_label)
	col.add_child(buy)
	card.add_child(col)
	return card


func _open_modal(item: Dictionary) -> void:
	_pending = item.duplicate()
	_modal_title.text = str(item.get("name", "")).to_upper()
	_modal_text.text = "PRICE: %d TP" % int(item.get("price", 0))
	_modal.visible = true


func _hide_modal() -> void:
	_pending = {}
	_modal.visible = false


func _on_modal_gui(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _modal_card.get_global_rect().has_point(mouse.global_position):
		_hide_modal()


func _on_confirm() -> void:
	if _pending.is_empty():
		_hide_modal()
		return
	var item_id := str(_pending.get("id", ""))
	var price := int(_pending.get("price", 0))
	var message := "Insufficient threat points"
	if PlayerManager.owns_store_item(item_id):
		message = "Already owned"
	elif PlayerManager.purchase_store_item(item_id, price):
		message = "Purchase successful"
	_hide_modal()
	_refresh_wallet()
	_rebuild_items()
	_show_toast(message)


func _show_toast(text: String) -> void:
	_toast_label.text = text.to_upper()
	_toast.visible = true
	_toast_left = 2.0


func _refresh_wallet() -> void:
	_threat_value.text = str(AuthService.wallet_threat_points())


func _style_buy(button: Button, owned: bool) -> void:
	var fill := Color(Palette.PINE, 0.85) if owned else Palette.CYAN_DIM
	var border := Palette.GREEN if owned else Palette.CYAN
	var box := _pixel_box(fill, border, 0, 2)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_color_override("font_color", Palette.GREEN if owned else Palette.TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", Palette.GREEN)


func _style_os_bar() -> void:
	var style := _pixel_box(Color(Palette.BG_HEADER, 0.92), Palette.GOLD_DIM, 0, 2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_os_bar.add_theme_stylebox_override("panel", style)


func _style_threat_pill() -> void:
	var style := _pixel_box(Color(Palette.GOLD, 0.12), Palette.GOLD, 0, 1)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_threat_box.add_theme_stylebox_override("panel", style)


func _style_close_button() -> void:
	_back_button.custom_minimum_size = Vector2(44, 32)
	var normal := _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	var hover := _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2)
	_back_button.add_theme_stylebox_override("normal", normal)
	_back_button.add_theme_stylebox_override("hover", hover)
	_back_button.add_theme_stylebox_override("pressed", hover)
	_back_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 12)


func _style_modal() -> void:
	var card := _pixel_box(Palette.BG_PANEL_ALT, Palette.GOLD, 0, 2)
	card.content_margin_left = 20.0
	card.content_margin_right = 20.0
	card.content_margin_top = 18.0
	card.content_margin_bottom = 18.0
	_modal_card.add_theme_stylebox_override("panel", card)
	var confirm := _pixel_box(Palette.GOLD, Palette.GOLD_DIM, 0, 2)
	confirm.content_margin_left = 16.0
	confirm.content_margin_right = 16.0
	confirm.content_margin_top = 10.0
	confirm.content_margin_bottom = 10.0
	_confirm_button.add_theme_stylebox_override("normal", confirm)
	_confirm_button.add_theme_stylebox_override("hover", confirm)
	_confirm_button.add_theme_stylebox_override("pressed", confirm)
	_confirm_button.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD)
	var cancel := _pixel_box(Color(Palette.BG_DEEP, 0.4), Palette.TEXT_MUTED, 0, 2)
	cancel.content_margin_left = 16.0
	cancel.content_margin_right = 16.0
	cancel.content_margin_top = 10.0
	cancel.content_margin_bottom = 10.0
	_cancel_button.add_theme_stylebox_override("normal", cancel)
	_cancel_button.add_theme_stylebox_override("hover", cancel)
	_cancel_button.add_theme_stylebox_override("pressed", cancel)
	_cancel_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_confirm_button.add_theme_font_override("font", _pixel_font)
		_cancel_button.add_theme_font_override("font", _pixel_font)
	_confirm_button.add_theme_font_size_override("font_size", 11)
	_cancel_button.add_theme_font_size_override("font_size", 11)
	var toast := _pixel_box(Color(Palette.BG_DEEP, 0.92), Palette.CYAN_DIM, 0, 2)
	toast.content_margin_left = 16.0
	toast.content_margin_right = 16.0
	toast.content_margin_top = 8.0
	toast.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("panel", toast)


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
