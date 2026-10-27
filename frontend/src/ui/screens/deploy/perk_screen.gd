extends BaseScreen
## Story collection and pre-deployment loadout. Legacy tower ranks are untouched.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Perks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
const Orbit: GDScript = preload("res://src/ui/screens/deploy/tech_orbit_node.gd")
var _layout_root: VBoxContainer
var _body: HBoxContainer
var _cards: HBoxContainer
var _network: HBoxContainer
var _inspector: VBoxContainer
var _slots: HBoxContainer
var _coins: Label
var _notice: Label
var _launch: Button
var _title: Label
var _selected: String = ""
var _deploy: bool = false
var _replay: bool = false
var _chapter_id: String = "mod_01_ch_01"
var _active: bool = false
var _testing: bool = false
var _owner: String = ""
var _signed: bool = false

class Links extends Control:
	func _draw() -> void:
		var center: Vector2 = size * Vector2(0.5, 0.5)
		for target: Vector2 in [Vector2(0.25,0.17), Vector2(0.75,0.17), Vector2(0.5,0.70)]:
			draw_line(center, size * target, Color("48635f"), 2.0)

func _ready() -> void:
	var shell: Dictionary = UI.shell(self, "PERK COLLECTION", _back)
	_layout_root = shell.layout
	_title = shell.title
	_coins = UI.label("", 28, UI.GOLD)
	_coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.get_parent().add_child(_coins)
	_notice = UI.label("", 24, UI.MUTED)
	_layout_root.add_child(_notice)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	_layout_root.add_child(_body)
	_cards = HBoxContainer.new()
	_cards.size_flags_horizontal = SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 18)
	_body.add_child(_cards)
	_network = HBoxContainer.new()
	_network.size_flags_horizontal = SIZE_EXPAND_FILL
	_network.add_theme_constant_override("separation", 20)
	_body.add_child(_network)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 14)
	_slots.size_flags_horizontal = SIZE_EXPAND_FILL
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	_layout_root.add_child(footer)
	footer.add_child(_slots)
	_launch = UI.button("", _deploy_chapter, true)
	footer.add_child(_launch)
	get_viewport().size_changed.connect(_refresh)
	AuthService.session_changed.connect(_account_changed)
	SaveService.cloud_fetch_completed.connect(_cloud_changed)

func on_enter(args: Dictionary) -> void:
	_deploy = bool(args.get("deploy", false))
	_replay = bool(args.get("replay", false))
	_chapter_id = str(args.get("chapter_id", "mod_01_ch_01"))
	_testing = bool(args.get("test", false))
	_owner = AuthService.participant_code()
	_signed = AuthService.is_signed_in()
	_active = true
	show()
	_refresh()

func _account_changed(_signed_in: bool) -> void:
	if _owner != AuthService.participant_code() or _signed != AuthService.is_signed_in():
		_active = false
		hide()

func _cloud_changed(_success: bool) -> void:
	_refresh()

func _checkpoint() -> Dictionary:
	if not _deploy: return {}
	var snapshot: Dictionary = PlayerManager.story_checkpoint(_chapter_id, _replay)
	return snapshot if not snapshot.get("completed", false) else {}

func _refresh() -> void:
	if not _active or not is_inside_tree(): return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var font: int = maxi(24, ceili(16 / physical))
	_launch.custom_minimum_size.x = 220 / physical
	var checkpoint: Dictionary = _checkpoint()
	var frozen: bool = not checkpoint.is_empty()
	var equipped: Array[String] = Perks.ids(checkpoint.get("perk_run", {}).get("loadout", []), 2) if frozen else PlayerManager.perk_loadout
	_coins.text = "%d CR" % PlayerManager.credits
	_title.text = "PERK COLLECTION" if _selected.is_empty() else "PERKS / LOADOUT NETWORK"
	_notice.text = "RESUMING / Your chapter loadout is locked. Purchases apply to future runs." if frozen else "STORY TOOLS / Equip up to two. Optional assists; never active in tests."
	_cards.visible = _selected.is_empty()
	_network.visible = not _selected.is_empty()
	UI.clear(_cards)
	UI.clear(_network)
	UI.clear(_slots)
	for id: String in Perks.IDS:
		var data: Dictionary = Perks.DATA[id]
		var owned: bool = id in PlayerManager.owned_perks
		var card: PanelContainer = UI.panel(_cards, UI.PANEL)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.box(UI.PANEL, Color(data.color), 18))
		var card_layout: VBoxContainer = UI.column(card, 8)
		var column: VBoxContainer = UI.scroll_column(card_layout)
		column.add_theme_constant_override("separation", 8)
		column.add_child(UI.label("EQUIPPED" if id in equipped else ("OWNED" if owned else "AVAILABLE / %d CR" % int(data.cost)), font, Color(data.color)))
		var node: Button = _orbit(id, equipped, physical)
		node.custom_minimum_size = Vector2(120,140) / physical
		column.add_child(node)
		column.add_child(UI.label(str(data.name).to_upper(), font + 6))
		column.add_child(UI.label(str(data.effect), font, UI.MUTED))
		column.add_child(UI.label(str(data.limit), font, Color(data.color)))
		card_layout.add_child(UI.button("VIEW PERK", _inspect.bind(id)))
	if not _selected.is_empty(): _build_network(equipped, frozen, physical, font)
	for index: int in 2:
		var slot_id: String = equipped[index] if index < equipped.size() else ""
		var slot: Button = UI.button("SLOT %d / %s" % [index + 1, "EMPTY" if slot_id.is_empty() else str(Perks.DATA[slot_id].name).to_upper()], _unequip.bind(slot_id))
		slot.size_flags_horizontal = SIZE_EXPAND_FILL
		slot.disabled = frozen or slot_id.is_empty()
		slot.tooltip_text = "Locked for this attempt" if frozen else "Remove perk from next loadout"
		_slots.add_child(slot)
	_launch.visible = _deploy
	_launch.text = "CONTINUE" if frozen else ("DEPLOY / NO PERKS" if equipped.is_empty() else "DEPLOY / %d PERKS" % equipped.size())
	_launch.disabled = not PlayerManager.story_unlocked(_chapter_id)
	for child: Node in find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.get_script() == Orbit: continue
		button.custom_minimum_size.y = maxf(64, 48 / physical)
		button.add_theme_font_size_override("font_size", font)
	_notice.add_theme_font_size_override("font_size", font)

func _orbit(id: String, equipped: Array[String], physical: float) -> Button:
	var node: Button = Orbit.new()
	var data: Dictionary = Perks.DATA[id]
	node.track_id = data.glyph
	node.accent = Color(data.color)
	node.caption = ""
	node.badge_override = "EQUIPPED" if id in equipped else ("OWNED" if id in PlayerManager.owned_perks else "%d CR" % int(data.cost))
	node.state = "OWNED" if id in PlayerManager.owned_perks else "BUY"
	node.selected = _selected == id
	node.font_size = ceili(16 / physical)
	node.accessibility_name = str(data.name) + ". " + node.badge_override
	node.pressed.connect(_inspect.bind(id))
	return node

func _build_network(equipped: Array[String], frozen: bool, physical: float, font: int) -> void:
	var compact: bool = get_viewport().get_visible_rect().size.y * physical < 500.0
	var rail: VBoxContainer = UI.scroll_column(_network)
	rail.get_parent().size_flags_stretch_ratio = 0.24
	rail.add_child(UI.label("PERKS", font, UI.MUTED))
	for id: String in Perks.IDS:
		rail.add_child(UI.button(str(Perks.DATA[id].name), _inspect.bind(id)))
	var middle: VBoxContainer = UI.scroll_column(_network)
	middle.get_parent().size_flags_stretch_ratio = 0.40
	middle.add_child(UI.label("LOADOUT NETWORK", font, UI.TEAL))
	var canvas: Links = Links.new()
	var diagram_scale: float = 0.65 if compact else 1.0
	canvas.custom_minimum_size = Vector2(270,300) * diagram_scale / physical
	canvas.size_flags_horizontal = SIZE_SHRINK_CENTER
	middle.add_child(canvas)
	var positions: Array[Vector2] = [Vector2(0.03,0.02),Vector2(0.53,0.02),Vector2(0.28,0.55)]
	for index: int in 3:
		var node: Button = _orbit(Perks.IDS[index], equipped, physical)
		canvas.add_child(node)
		node.position = positions[index] * canvas.custom_minimum_size
		node.size = Vector2(120,130) * diagram_scale / physical
	var center: Label = UI.label("2 SLOTS", font, UI.TEAL)
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(center)
	center.position = Vector2(0,145) * diagram_scale / physical
	center.size = Vector2(270,35) * diagram_scale / physical
	middle.add_child(UI.label("Connections show loadout options, not purchase prerequisites.", font, UI.MUTED))
	var panel: PanelContainer = UI.panel(_network)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.36
	var inspector_layout: VBoxContainer = UI.column(panel, 12)
	_inspector = UI.scroll_column(inspector_layout)
	var data: Dictionary = Perks.DATA[_selected]
	var icon: Button = _orbit(_selected, equipped, physical)
	icon.custom_minimum_size.y = 130 / physical
	_inspector.add_child(icon)
	icon.visible = not compact
	_inspector.add_child(UI.label(str(data.name).to_upper(), font + 4))
	_inspector.add_child(UI.label(str(data.effect), font))
	_inspector.add_child(UI.label(str(data.limit), font, Color(data.color)))
	_inspector.add_child(UI.label("Using this tool marks the attempt assisted. Base coins are unchanged; clean-work bonus is unavailable.", font, UI.MUTED))
	var owned: bool = _selected in PlayerManager.owned_perks
	var action: Button = UI.button(("UNEQUIP" if _selected in equipped else "EQUIP") if owned else "UNLOCK / %d CR" % int(data.cost), _action, true)
	action.name = "PerkAction"
	action.disabled = (frozen or (equipped.size() >= 2 and _selected not in equipped)) if owned else PlayerManager.credits < int(data.cost)
	inspector_layout.add_child(action)
	if action.disabled: _inspector.add_child(UI.label("Loadout locked" if frozen and owned else ("Remove a perk to free a slot" if owned else "Not enough credits"), font, UI.GOLD))

func _inspect(id: String) -> void:
	if not _active: return
	_selected = id
	_refresh()
	var action: Button = find_child("PerkAction", true, false) as Button
	if action != null and not action.disabled: action.grab_focus.call_deferred()

func _action() -> void:
	if not _active: return
	if _selected in PlayerManager.owned_perks:
		if not _checkpoint().is_empty(): return
		PlayerManager.equip_perk(_selected, not _testing)
	else: PlayerManager.purchase_perk(_selected, not _testing)
	_refresh()

func _unequip(id: String) -> void:
	if _active and _checkpoint().is_empty() and id in PlayerManager.perk_loadout:
		PlayerManager.equip_perk(id, not _testing)
		_refresh()

func _deploy_chapter() -> void:
	if _active and _deploy and PlayerManager.story_unlocked(_chapter_id):
		Router.push(&"confrontation" if _chapter_id == "mod_01_ch_05" else &"survey_chapter", {"replay":_replay, "chapter_id":_chapter_id})

func _back() -> void:
	if not _selected.is_empty():
		_selected = ""
		_refresh()
	else: Router.request_back()

func on_exit() -> void:
	_active = false
	hide()

func on_resume() -> void:
	if _owner != AuthService.participant_code() or _signed != AuthService.is_signed_in(): return
	_active = true
	show()
	_refresh()
