class_name StoreScreen
extends BaseScreen
## Cosmetic collection storefront. Only the isolated PvP wallet is displayed.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Avatars: GDScript = preload("res://src/ui/screens/profile/avatar_portrait.gd")
const NAVY: Color = Color("#0A1730")
const CYAN: Color = Color("#4FE0D4")
const CREAM: Color = Color("#F3ECD6")
const MUTED: Color = Color("#A4B6C8")
const EDGE: Color = Color("#29405C")
const CATEGORIES: Array[String] = ["FEATURED", "PROFILES", "BORDERS"]

## Each display case draws its own lighting, perspective floor and pixel collectible.
## Avatars use the same portrait renderer as the player's profile.
class ItemArt extends Control:
	var design: String
	var ink: Color
	var displayed_id: String
	var portrait: TextureRect
	var preview: bool = false

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if design == "avatar" or preview:
			portrait = Avatars.new()
			portrait.show_avatar(displayed_id if design == "avatar" else PlayerManager.current_avatar_id())
			add_child(portrait)
			if preview:
				var item: Dictionary = PlayerManager.store_item(displayed_id)
				var frame: String = displayed_id if str(item.slot) == "frame" else PlayerManager.current_cosmetic_id("frame")
				var badge: String = displayed_id if str(item.slot) == "badge" else PlayerManager.current_cosmetic_id("badge")
				portrait.show_cosmetics(frame, badge)
		resized.connect(_fit)
		_fit()

	func _fit() -> void:
		if portrait != null:
			var side: float = floorf(minf(size.x * 0.80, size.y * 0.78))
			portrait.size = Vector2.ONE * side
			portrait.position = ((size - portrait.size) * 0.5).floor()
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if minf(w, h) < 4.0:
			return
		var lit: Color = Color("#0B1829").lerp(ink, 0.24)
		var dark: Color = Color("#091322")
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), size, Vector2(0, h)]), PackedColorArray([lit, dark, dark, lit.darkened(0.55)]))
		var horizon: float = floorf(h * 0.74)
		var grid: Color = Color(ink, 0.13)
		for n: int in range(-5, 6):
			var dx: float = n * w / 6.0
			draw_line(Vector2(w * 0.5 + dx * 0.38, horizon), Vector2(w * 0.5 + dx, h), grid)
		for ratio: float in [0.0, 0.22, 0.55, 1.0]:
			var y: float = lerpf(horizon, h - 1, ratio)
			draw_line(Vector2(0, y), Vector2(w, y), grid)
		for x: float in [12.0, w - 12.0]:
			draw_line(Vector2(x - 4, 13), Vector2(x + 4, 13), Color(ink, 0.60))
			draw_line(Vector2(x, 9), Vector2(x, 17), Color(ink, 0.60))
		if portrait != null:
			return
		var unit: float = maxf(1, floorf(minf(w / 39.0, h / 31.0)))
		draw_set_transform((size * 0.5 - Vector2(16, 12) * unit).floor(), 0, Vector2.ONE * unit)
		Avatars.draw_cosmetic(self, design, ink)
		draw_set_transform(Vector2.ZERO)

var _wallet: Label
var _body: HBoxContainer
var _gallery: ScrollContainer
var _grid: GridContainer
var _detail_scroll: ScrollContainer
var _info: VBoxContainer
var _preview: BoxContainer
var _count: Label
var _detail: VBoxContainer
var _back: Button
var _tabs: Array[Button] = []
var _cards: Array[Button] = []
var _buy: Button
var _modal: ColorRect
var _modal_card: PanelContainer
var _modal_text: Label
var _confirm: Button
var _cancel: Button
var _status: Label
var _category: String = "FEATURED"
var _selected: String = "t1"
var _pending: String = ""
var _compact: bool = false
var _details_open: bool = false
var _return_focus: Control

func _ready() -> void:
	var shell: Dictionary = UI.shell(self, "STORE", _back_pressed)
	_back = shell.back
	var layout: VBoxContainer = shell.layout
	layout.add_theme_constant_override("separation", 14)
	var header: HBoxContainer = _back.get_parent() as HBoxContainer
	var wallet_panel: PanelContainer = UI.panel(header, NAVY)
	wallet_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	wallet_panel.add_theme_stylebox_override("panel", _surface(Color("#102B30"), Color("#326067"), 12))
	_wallet = UI.label("", 24, Color("#8FF0E6"))
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_panel.add_child(_wallet)
	var categories: HBoxContainer = HBoxContainer.new()
	categories.add_theme_constant_override("separation", 8)
	layout.add_child(categories)
	for category: String in CATEGORIES:
		var tab: Button = UI.button(category.capitalize(), _select_category.bind(category))
		tab.custom_minimum_size.x = 155
		categories.add_child(tab)
		_tabs.append(tab)
	_count = UI.label("", 22, MUTED)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.size_flags_horizontal = SIZE_EXPAND_FILL
	categories.add_child(_count)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(_body)
	_gallery = _scroll(_body)
	_gallery.size_flags_stretch_ratio = 1.55
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_grid.size_flags_vertical = SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_gallery.add_child(_grid)
	_detail_scroll = _scroll(_body)
	var panel: PanelContainer = UI.panel(_detail_scroll, NAVY)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _surface(NAVY, EDGE, 18))
	_preview = BoxContainer.new()
	_preview.add_theme_constant_override("separation", 20)
	panel.add_child(_preview)
	_detail = UI.column(_preview, 8)
	_detail.size_flags_horizontal = SIZE_EXPAND_FILL
	_info = UI.column(_preview, 12)
	_info.size_flags_horizontal = SIZE_EXPAND_FILL
	_status = UI.label("", 20, UI.MUTED)
	_status.hide()
	layout.add_child(_status)
	_build_modal()
	resized.connect(_layout)
	_refresh()
	_layout.call_deferred()

func _scroll(parent: Node) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	parent.add_child(scroll)
	return scroll

static func _surface(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(padding)
	return style

func _art(item: Dictionary, height: float, preview: bool = false) -> ItemArt:
	var art: ItemArt = ItemArt.new()
	art.design = str(item.art)
	art.preview = preview
	art.ink = Color(str(item.color))
	art.displayed_id = str(item.id)
	art.custom_minimum_size.y = height
	art.size_flags_horizontal = SIZE_EXPAND_FILL
	art.size_flags_vertical = SIZE_EXPAND_FILL
	return art

func _refresh() -> void:
	_wallet.text = "%d THREAT" % PlayerManager.pvp_tokens
	UI.clear(_grid)
	_cards.clear()
	for item: Dictionary in PlayerManager.store_items():
		if str(item.category) != _category:
			continue
		var id: String = str(item.id)
		var card: Button = UI.button("", _select_item.bind(id))
		card.set_meta("item_id", id)
		card.accessibility_name = str(item.name)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		_grid.add_child(card)
		_cards.append(card)
		var column: VBoxContainer = UI.column(card, 8)
		column.mouse_filter = MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		column.offset_left = 12
		column.offset_right = -12
		column.offset_top = 12
		column.offset_bottom = -12
		column.add_child(_art(item, 70))
		var title: Label = UI.label(str(item.name), 29, CREAM)
		column.add_child(title)
		var owned: bool = PlayerManager.owns_store_item(id)
		var equipped: bool = PlayerManager.is_store_item_equipped(id)
		var price: Label = UI.label("Equipped" if equipped else "Owned" if owned else "%d Threat" % int(item.price), 23, Color("#74E6A1") if owned else Color("#8FF0E6"))
		column.add_child(price)
		card.accessibility_name += ", " + price.text
	_count.text = "%d items" % _cards.size()
	for i: int in _tabs.size():
		var tab: Button = _tabs[i]
		var active: bool = CATEGORIES[i] == _category
		tab.add_theme_stylebox_override("normal", _surface(Color("#153B37") if active else NAVY, CYAN if active else EDGE, 9))
		tab.add_theme_color_override("font_color", Color("#8FF0E6") if active else MUTED)
	_style_cards()
	_show_detail()
	_layout.call_deferred()

func _style_cards() -> void:
	for card: Button in _cards:
		var selected: bool = str(card.get_meta("item_id")) == _selected
		var style: StyleBoxFlat = _surface(Color("#122A39") if selected else NAVY, CYAN if selected else EDGE, 0)
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", _surface(Color("#153347"), CYAN, 0))
		card.add_theme_stylebox_override("pressed", _surface(Color("#153B37"), CYAN, 0))

func _show_detail() -> void:
	UI.clear(_detail)
	UI.clear(_info)
	var item: Dictionary = PlayerManager.store_item(_selected)
	var type_name: String = "Profile " + str(item.slot)
	_detail.add_child(UI.label(type_name.to_upper(), 19, Color(str(item.color)).lightened(0.25)))
	_detail.add_child(_art(item, 158, true))
	_info.add_child(UI.label(str(item.name), 32, CREAM))
	_info.add_child(UI.label(str(item.description), 23, MUTED))
	var owned: bool = PlayerManager.owns_store_item(_selected)
	var affordable: bool = PlayerManager.pvp_tokens >= int(item.price)
	var equipped: bool = PlayerManager.is_store_item_equipped(_selected)
	_info.add_child(UI.label("Equipped" if equipped else "Ready to equip" if owned else "%d Threat" % int(item.price), 26, Color("#74E6A1") if owned else CYAN))
	var caption: String = "BUY ITEM" if affordable else "NOT ENOUGH THREAT"
	if owned:
		caption = ("EQUIPPED" if str(item.slot) == "avatar" else "REMOVE") if equipped else "EQUIP"
	_buy = UI.button(caption, _use_selected if owned else _open_modal, true)
	_buy.disabled = (equipped and str(item.slot) == "avatar") or (not owned and not affordable)
	_info.add_child(_buy)
	if not owned and not affordable:
		_info.add_child(UI.label("%d more Threat needed." % (int(item.price) - PlayerManager.pvp_tokens), 20, MUTED))
	_detail_scroll.scroll_vertical = 0

func _use_selected() -> void:
	if _modal.visible:
		return
	var item: Dictionary = PlayerManager.store_item(_selected)
	var removing: bool = PlayerManager.is_store_item_equipped(_selected)
	var success: bool = PlayerManager.remove_store_item(_selected) if removing else PlayerManager.equip_store_item(_selected)
	_refresh()
	_status.text = "Item unavailable. Check your collection."
	if success:
		_status.text = ("%s removed." if removing else "%s equipped.") % str(item.name)
	_status.show()


func _select_category(category: String) -> void:
	if _modal.visible:
		return
	_status.hide()
	_category = category
	_details_open = false
	for item: Dictionary in PlayerManager.store_items():
		if str(item.category) == category:
			_selected = str(item.id)
			break
	_gallery.scroll_vertical = 0
	_refresh()

func _select_item(id: String) -> void:
	if _modal.visible:
		return
	_status.hide()
	_selected = id
	_details_open = true
	_style_cards()
	_show_detail()
	_layout()
	if _compact:
		_back.grab_focus()

func _build_modal() -> void:
	_modal = ColorRect.new()
	_modal.color = Color(0.01, 0.02, 0.05, 0.9)
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_modal_card = UI.panel(center, NAVY)
	_modal_card.add_theme_stylebox_override("panel", _surface(NAVY, CYAN, 22))
	var column: VBoxContainer = UI.column(_modal_card, 14)
	column.add_child(UI.label("CONFIRM PURCHASE", 20, CREAM, true))
	_modal_text = UI.label("", 24)
	column.add_child(_modal_text)
	var choices: HBoxContainer = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	column.add_child(choices)
	_confirm = UI.button("Buy item", _on_confirm, true)
	_cancel = UI.button("CANCEL", _hide_modal)
	_confirm.size_flags_horizontal = SIZE_EXPAND_FILL
	_cancel.size_flags_horizontal = SIZE_EXPAND_FILL
	choices.add_child(_cancel)
	choices.add_child(_confirm)
	_confirm.focus_next = _confirm.get_path_to(_cancel)
	_confirm.focus_previous = _confirm.get_path_to(_cancel)
	_cancel.focus_next = _cancel.get_path_to(_confirm)
	_cancel.focus_previous = _cancel.get_path_to(_confirm)
	for direction: String in ["left", "right", "top", "bottom"]:
		_confirm.set("focus_neighbor_" + direction, _confirm.get_path_to(_cancel))
		_cancel.set("focus_neighbor_" + direction, _cancel.get_path_to(_confirm))
	_modal.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hide_modal())
	_modal.hide()

func _open_modal() -> void:
	var item: Dictionary = PlayerManager.store_item(_selected)
	if PlayerManager.owns_store_item(_selected) or PlayerManager.pvp_tokens < int(item.price):
		_refresh()
		return
	_pending = _selected
	_return_focus = get_viewport().gui_get_focus_owner()
	_modal_text.text = "%s\n%d THREAT\n\nRemaining balance: %d Threat" % [item.name, int(item.price), PlayerManager.pvp_tokens - int(item.price)]
	_modal.show()
	_cancel.grab_focus()

func _hide_modal() -> void:
	_pending = ""
	_modal.hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null

func _on_confirm() -> void:
	if _pending.is_empty():
		return
	var success: bool = PlayerManager.purchase_store_item(_pending)
	_hide_modal()
	_refresh()
	_status.text = "Added to your collection. Tap Equip to wear it." if success else "Purchase unavailable. Check your Threat balance or ownership."
	_status.show()
	_back.grab_focus()

func _layout() -> void:
	if not is_instance_valid(_grid):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	_compact = size.x * physical < 1000.0
	_gallery.visible = not _compact or not _details_open
	_detail_scroll.visible = not _compact or _details_open
	_preview.vertical = not _compact
	_grid.columns = 3 if _compact and size.x * physical >= 680 else 2
	_modal_card.custom_minimum_size.x = minf(size.x - 48, 500.0 / physical)
	UI.fit_touch(self)
	for card: Button in _cards:
		card.custom_minimum_size.y = clampf(_body.size.y * 0.89, 220.0, 390.0) if _compact else 230.0
	if _detail.get_child_count() > 1:
		var artwork: Control = _detail.get_child(1) as Control
		artwork.custom_minimum_size.y = clampf(_body.size.y * 0.6, 145, 320) if _compact else 158.0

func can_go_back() -> bool:
	if _modal.visible:
		_hide_modal()
		return false
	if _compact and _details_open:
		_details_open = false
		_layout()
		for card: Button in _cards:
			if str(card.get_meta("item_id")) == _selected:
				card.grab_focus()
				break
		return false
	return true

func _back_pressed() -> void:
	if can_go_back():
		Router.request_back()

func on_enter(args: Dictionary) -> void:
	_details_open = false
	_status.hide()
	_hide_modal()
	var requested: Dictionary = PlayerManager.store_item(str(args.get("item_id", "")))
	if not requested.is_empty():
		_category = str(requested.category)
		_selected = str(requested.id)
		_details_open = true
	_refresh()

func on_resume() -> void:
	_refresh()

func on_exit() -> void:
	_hide_modal()
