class_name StoreScreen
extends BaseScreen
## Cosmetic collection storefront. Only the isolated PvP wallet is displayed.
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Avatars = preload("res://src/ui/screens/profile/avatar_portrait.gd")
const NAVY: Color = Color("102040")
const CYAN: Color = Color("4FE0D4")
const CREAM: Color = Color("F3ECD6")
const CATEGORIES: Array[String] = ["FEATURED", "PROFILES", "BORDERS"]

class ItemArt extends Control:
	var design: String = "frame"
	var ink: Color = Color("4FE0D4")
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var unit: float = maxf(1, floorf(minf(size.x, size.y) / 24.0))
		draw_set_transform((size - Vector2.ONE * unit * 24.0) * 0.5, 0, Vector2.ONE * unit)
		for index: int in 6:
			draw_line(Vector2(0, index * 4), Vector2(24, index * 4), Color(ink, 0.08), 0.15)
		draw_circle(Vector2(12, 12), 10, Color(ink, 0.1))
		match design:
			"frame":
				draw_rect(Rect2(4, 4, 16, 16), Color("050B18"))
				draw_rect(Rect2(4, 4, 16, 16), ink, false, 1)
				draw_rect(Rect2(6, 6, 12, 12), Color(ink, 0.4), false, 0.5)
				for point: Vector2 in [Vector2(3, 3), Vector2(18, 3), Vector2(3, 18), Vector2(18, 18)]:
					draw_rect(Rect2(point, Vector2(3, 3)), ink)
				draw_rect(Rect2(10, 9, 4, 4), Color(ink, 0.5))
				draw_rect(Rect2(8, 14, 8, 3), Color(ink, 0.3))
			"drone":
				draw_line(Vector2(5, 8), Vector2(19, 16), ink, 1)
				draw_line(Vector2(5, 16), Vector2(19, 8), ink, 1)
				for point: Vector2 in [Vector2(5, 7), Vector2(19, 7), Vector2(5, 17), Vector2(19, 17)]:
					draw_rect(Rect2(point - Vector2(3, 1), Vector2(6, 2)), ink)
				draw_rect(Rect2(8, 9, 8, 6), Color("173058"))
				draw_rect(Rect2(8, 9, 8, 6), ink, false, 1)
				draw_rect(Rect2(11, 11, 2, 2), Color("F3ECD6"))
			"cloak":
				draw_colored_polygon(PackedVector2Array([Vector2(12, 3), Vector2(17, 7), Vector2(20, 21), Vector2(12, 18), Vector2(4, 21), Vector2(7, 7)]), Color(ink, 0.55))
				draw_rect(Rect2(8, 8, 8, 6), Color("050B18"))
				draw_rect(Rect2(9, 10, 2, 1), ink)
				draw_rect(Rect2(13, 10, 2, 1), ink)
			_:
				draw_rect(Rect2(7, 4, 10, 10), Color(ink, 0.55))
				draw_rect(Rect2(8, 8, 8, 3), Color("050B18"))
				draw_rect(Rect2(9, 9, 6, 1), ink)
				draw_rect(Rect2(5, 16, 14, 5), ink)
				draw_rect(Rect2(10, 15, 4, 6), Color("173058"))
		draw_set_transform(Vector2.ZERO)

var _wallet: Label
var _body: HBoxContainer
var _gallery: ScrollContainer
var _grid: GridContainer
var _detail_scroll: ScrollContainer
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
	var shell: Dictionary = UI.shell(self, "PVP EXCHANGE", _back_pressed)
	_back = shell.back
	var layout: VBoxContainer = shell.layout
	var wallet_row: HBoxContainer = HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 16)
	layout.add_child(wallet_row)
	var heading: Label = UI.label("COMPETE. COLLECT. STAND OUT.", 22, CYAN)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	wallet_row.add_child(heading)
	var wallet_panel: PanelContainer = UI.panel(wallet_row, Color("0E2A28"))
	_wallet = UI.label("", 24, CYAN)
	_wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_panel.add_child(_wallet)
	var categories: HBoxContainer = HBoxContainer.new()
	categories.add_theme_constant_override("separation", 12)
	layout.add_child(categories)
	for category: String in CATEGORIES:
		var tab: Button = UI.button(category, _select_category.bind(category))
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		categories.add_child(tab)
		_tabs.append(tab)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(_body)
	_gallery = _scroll(_body)
	_gallery.size_flags_stretch_ratio = 1.3
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
	panel.add_theme_stylebox_override("panel", UI.journal_box(NAVY, Color("305C76"), 22))
	_detail = UI.column(panel, 16)
	_status = UI.label("Earn tokens through PvP. Match rewards are not available yet.", 20, UI.MUTED)
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

func _art(item: Dictionary, height: float) -> Control:
	if str(item.art) == "avatar":
		var portrait: TextureRect = Avatars.new()
		portrait.show_avatar(str(item.id))
		portrait.custom_minimum_size = Vector2(0, height)
		portrait.set_meta("art_height", height)
		return portrait
	var art: ItemArt = ItemArt.new()
	art.design = str(item.art)
	art.ink = Color(str(item.color))
	art.custom_minimum_size = Vector2(0, height)
	art.set_meta("art_height", height)
	art.size_flags_horizontal = SIZE_EXPAND_FILL
	return art

func _refresh() -> void:
	_wallet.text = "%d PVP TOKENS" % PlayerManager.pvp_tokens
	UI.clear(_grid)
	_cards.clear()
	for item: Dictionary in PlayerManager.store_items():
		if str(item.category) != _category:
			continue
		var card: Button = UI.button("", _select_item.bind(str(item.id)))
		card.tooltip_text = str(item.name)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		var active: bool = str(item.id) == _selected
		var style: StyleBoxFlat = UI.journal_box(NAVY, CYAN if active else Color("173058"), 16)
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", UI.journal_box(Color("173058"), CYAN, 16))
		card.add_theme_stylebox_override("pressed", style)
		var column: VBoxContainer = UI.column(card, 10)
		column.mouse_filter = MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		column.offset_left = 16
		column.offset_right = -16
		column.offset_top = 16
		column.offset_bottom = -16
		column.add_child(_art(item, 105))
		var name_label: Label = UI.label(str(item.name), 24, CREAM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var owned: bool = PlayerManager.owns_store_item(str(item.id))
		var price: Label = UI.label("OWNED" if owned else "%d TOKENS" % int(item.price), 22, Color("33D17A") if owned else CYAN)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(price)
		_grid.add_child(card)
		_cards.append(card)
	for tab: Button in _tabs:
		tab.add_theme_stylebox_override("normal", UI.box(Color("153B37") if tab.text == _category else NAVY, CYAN if tab.text == _category else Color("173058"), 12))
	_show_detail()
	_layout.call_deferred()

func _show_detail() -> void:
	UI.clear(_detail)
	var item: Dictionary = PlayerManager.store_item(_selected)
	_detail.add_child(UI.label("COLLECTION / " + _category, 18, CYAN))
	_detail.add_child(_art(item, 125))
	_detail.add_child(UI.label(str(item.name).to_upper(), 20, CREAM, true))
	_detail.add_child(UI.label(str(item.description), 24, UI.TEXT))
	var owned: bool = PlayerManager.owns_store_item(_selected)
	var affordable: bool = PlayerManager.pvp_tokens >= int(item.price)
	_detail.add_child(UI.label("IN YOUR COLLECTION" if owned else "%d PVP TOKENS" % int(item.price), 26, Color("33D17A") if owned else CYAN))
	_buy = UI.button("OWNED" if owned else ("BUY ITEM" if affordable else "EARN TOKENS IN PVP"), _open_modal, true)
	_buy.disabled = owned or not affordable
	_detail.add_child(_buy)
	if not owned and not affordable:
		_detail.add_child(UI.label("%d more tokens needed." % (int(item.price) - PlayerManager.pvp_tokens), 22, UI.MUTED))
	_detail.add_child(UI.label("COSMETIC ONLY / No combat advantage\n" + ("Choose this avatar from your profile." if str(item.art) == "avatar" else "Collection only. Equipping is not available yet."), 20, UI.MUTED))
	_detail_scroll.scroll_vertical = 0

func _select_category(category: String) -> void:
	if _modal.visible:
		return
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
	_selected = id
	_details_open = true
	_refresh()
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
	var column: VBoxContainer = UI.column(_modal_card, 20)
	column.add_child(UI.label("CONFIRM PURCHASE", 20, CREAM, true))
	_modal_text = UI.label("", 24)
	column.add_child(_modal_text)
	_confirm = UI.button("BUY", _on_confirm, true)
	_cancel = UI.button("CANCEL", _hide_modal)
	column.add_child(_confirm)
	column.add_child(_cancel)
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
	_modal_text.text = "%s\n\n%d PVP TOKENS\nBalance after purchase: %d\n\nAdds this cosmetic to your collection." % [item.name, int(item.price), PlayerManager.pvp_tokens - int(item.price)]
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
	_status.text = "Added to your collection." if success else "Purchase unavailable. Check your token balance or ownership."
	_back.grab_focus()

func _layout() -> void:
	if not is_instance_valid(_grid):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	_compact = size.x * physical < 1000.0
	_gallery.visible = not _compact or not _details_open
	_detail_scroll.visible = not _compact or _details_open
	# Landscape-only gallery; compact landscape phones still use a detail page.
	_grid.columns = 2
	_back.text = "< ITEMS" if _compact and _details_open else "< BACK"
	_modal_card.custom_minimum_size.x = minf(size.x - 48, 480.0 / physical)
	UI.fit_touch(self)
	for card: Button in _cards:
		card.custom_minimum_size.y = maxf(220, 190.0 / physical)
	for art: Node in find_children("*", "Control", true, false):
		if art.has_meta("art_height"):
			art.custom_minimum_size.y = maxf(float(art.get_meta("art_height")), 90.0 / physical)

func can_go_back() -> bool:
	if _modal.visible:
		_hide_modal()
		return false
	if _compact and _details_open:
		_details_open = false
		_layout()
		if not _cards.is_empty():
			_cards[0].grab_focus()
		return false
	return true

func _back_pressed() -> void:
	if can_go_back():
		Router.request_back()

func on_enter(args: Dictionary) -> void:
	_details_open = false
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
