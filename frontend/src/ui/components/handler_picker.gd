extends Control
## Shared companion-appearance picker; PlayerManager owns the preference.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const IDS: Array[String] = ["male", "female", "original"]
const NAMES: Array[String] = ["Male", "Female", "Prefer not to say"]
var account: Node
var onboarding: bool = false
var selected: String = "original"
var _owner: String = ""
var _cards: Array[Button] = []
var _portraits: Array[TextureRect] = []
var _labels: Array[Label] = []
var _grid: GridContainer
var _confirm: Button
var _cancel: Button
var _title: Label
var _note: Label
var _return_focus: Control

static func open(host: Node, first_choice: bool = false) -> Control:
	var existing: Control = host.get_node_or_null("HandlerPicker") as Control
	if is_instance_valid(existing):
		return existing
	var picker: Control = new()
	picker.name = "HandlerPicker"
	picker.onboarding = first_choice
	host.add_child(picker)
	return picker

func _ready() -> void:
	if account == null:
		account = PlayerManager
	_owner = AuthService.participant_code()
	_return_focus = get_viewport().gui_get_focus_owner()
	selected = account.handler_appearance
	z_index = 100
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color("050B18")
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	add_child(safe)
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(safe)
	var body: VBoxContainer = UI.column(panel, 10)
	_title = UI.label("CHOOSE YOUR HANDLER", 28, UI.TEAL, true)
	body.add_child(_title)
	_note = UI.label("Choose your companion's appearance. This is not a question about your gender. Change it anytime in Settings.", 22, UI.MUTED)
	body.add_child(_note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_grid.size_flags_vertical = SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	for index: int in IDS.size():
		var card: Button = UI.button("", _choose.bind(IDS[index]))
		card.name = IDS[index].capitalize() + "Handler"
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.size_flags_vertical = SIZE_EXPAND_FILL
		_grid.add_child(card)
		var inset: MarginContainer = MarginContainer.new()
		inset.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(inset)
		inset.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for side: String in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, 12)
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = MOUSE_FILTER_IGNORE
		inset.add_child(column)
		var portrait: TextureRect = TextureRect.new()
		portrait.mouse_filter = MOUSE_FILTER_IGNORE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_vertical = SIZE_EXPAND_FILL
		column.add_child(portrait)
		var label: Label = UI.label(NAMES[index], 24, UI.TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = MOUSE_FILTER_IGNORE
		column.add_child(label)
		_cards.append(card)
		_portraits.append(portrait)
		_labels.append(label)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	_cancel = UI.button("KEEP ORIGINAL" if onboarding else "CANCEL", _cancel_choice)
	_confirm = UI.button("USE THIS HANDLER", _confirm_choice, true)
	for button: Button in [_cancel, _confirm]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		footer.add_child(button)
	AssetManager.sync_finished.connect(_refresh_art)
	AuthService.session_changed.connect(_session_changed)
	account.handler_appearance_changed.connect(_account_changed)
	resized.connect(_layout)
	_refresh_art(false)
	_choose(selected)
	_layout()
	_cards[IDS.find(selected)].grab_focus()

func _refresh_art(_success: bool) -> void:
	for index: int in IDS.size():
		_portraits[index].texture = AssetManager.get_handler_texture("npc_smile", IDS[index])

func _choose(value: String) -> void:
	if value not in IDS:
		return
	selected = value
	for index: int in IDS.size():
		var active: bool = IDS[index] == selected
		_cards[index].add_theme_stylebox_override("normal", UI.box(UI.PANEL, UI.TEAL if active else Color("173058"), 12))
		_cards[index].accessibility_name = NAMES[index] + (", selected" if active else "")
		_labels[index].modulate = UI.TEAL if active else UI.TEXT

func _confirm_choice() -> void:
	if _owner == AuthService.participant_code():
		account.set_handler_appearance(selected)
	close()

func _cancel_choice() -> void:
	if onboarding:
		selected = "original"
		_confirm_choice()
	else:
		close()

func _session_changed(_signed_in: bool) -> void:
	close()

func _account_changed() -> void:
	# Cloud restoration must not leave an outdated selection open.
	if onboarding and not account.handler_choice_pending:
		close()
	elif not onboarding:
		_choose(account.handler_appearance)

func close() -> void:
	if is_queued_for_deletion():
		return
	hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	queue_free()

func _layout() -> void:
	if not is_instance_valid(_confirm):
		return
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().x)
	var small: bool = size.y * physical < 500
	_grid.columns = 1 if size.x * physical < 600 else 3
	_title.add_theme_font_size_override("font_size", ceili((17.0 if small else 22.0) / physical))
	_note.add_theme_font_size_override("font_size", ceili(16.0 / physical))
	for label: Label in _labels:
		label.add_theme_font_size_override("font_size", ceili(18.0 / physical))
	for card: Button in _cards:
		card.custom_minimum_size = Vector2(0, 150.0 / physical)
	for button: Button in [_cancel, _confirm]:
		button.custom_minimum_size.y = 48.0 / physical
		button.add_theme_font_size_override("font_size", ceili(17.0 / physical))
