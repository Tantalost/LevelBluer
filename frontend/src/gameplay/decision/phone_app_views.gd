extends RefCounted
## Shared app presentation only. Chapter controllers own content, read IDs and saves.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")

static func ordered_mail(entries: Array, read_ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for read_group: bool in [false, true]:
		for entry: Dictionary in entries:
			if read_ids.has(str(entry.get("id", ""))) == read_group:
				result.append(entry)
	return result

static func mail_row(parent: Control, entry: Dictionary, read: bool, action: Callable, number: int = 0) -> AppRow:
	var row: AppRow = AppRow.new()
	row.mail_number = number
	row.subject = str(entry.get("subject", "Message"))
	row.subtitle = str(entry.get("sender", "Unknown sender"))
	row.read = read
	row.set_meta("message_id", str(entry.get("id", "")))
	row.accessibility_name = ("Message %d. " % number if number > 0 else "") + ("Read. " if read else "Unread. ") + row.subject + ". " + row.subtitle
	row.pressed.connect(action)
	parent.add_child(row)
	return row

static func contact_row(parent: Control, data: Dictionary, action: Callable) -> AppRow:
	var row: AppRow = AppRow.new()
	row.contact = true
	row.subject = str(data.get("title", "Contact"))
	row.subtitle = str(data.get("subtitle", "View contact"))
	row.portrait = data.get("portrait") as Texture2D
	row.accessibility_name = row.subject + ". " + row.subtitle
	row.pressed.connect(action)
	parent.add_child(row)
	return row

static func contact_details(parent: Control, data: Dictionary) -> void:
	var physical: float = maxf(0.25, parent.get_viewport().get_final_transform().get_scale().y)
	var identity: PanelContainer = UI.panel(parent, Color("e1eeeb"))
	identity.add_theme_stylebox_override("panel", UI.box(Color("e1eeeb"),Color("85c5d5"),ceili(14/physical)))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",ceili(16/physical))
	identity.add_child(row)
	var portrait: Texture2D = data.get("portrait") as Texture2D
	if portrait != null:
		var image: TextureRect = TextureRect.new()
		image.texture = portrait
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(64,72)/physical
		row.add_child(image)
	var labels: VBoxContainer = UI.column(row,ceili(6/physical))
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(UI.label(str(data.get("title", "Contact")),ceili(24/physical),Color("101623")))
	labels.add_child(UI.label(str(data.get("subtitle", "Saved contact")),ceili(16/physical),Color("365b63")))
	var body: Label = UI.label(str(data.get("body", "No additional contact information saved.")),ceili(18/physical),Color("101623"))
	parent.add_child(body)

class AppRow extends Button:
	var mail_number: int = 0
	var number_label: Label
	var subject: String = ""
	var subtitle: String = ""
	var read: bool = false
	var contact: bool = false
	var portrait: Texture2D
	var heading: Label
	var detail: Label
	var physical: float = 1.0
	func _ready() -> void:
		size_flags_horizontal = SIZE_EXPAND_FILL
		clip_contents = true
		for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(style, StyleBoxEmpty.new())
		heading = UI.label(subject, 24, Color("101623"))
		detail = UI.label(subtitle, 20, Color("365b63"))
		heading.max_lines_visible = 2
		detail.max_lines_visible = 1
		for label: Label in [heading, detail]:
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			add_child(label)
		if mail_number > 0 and not contact:
			number_label = UI.label(str(mail_number), 16, Color("101623"))
			number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(number_label)
		resized.connect(refresh)
		get_viewport().size_changed.connect(refresh.call_deferred)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		refresh.call_deferred()
	func refresh() -> void:
		if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(heading): return
		physical = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		custom_minimum_size = Vector2(0, (76 if contact else 88) / physical)
		heading.add_theme_font_size_override("font_size", ceili(18 / physical))
		detail.add_theme_font_size_override("font_size", ceili(14 / physical))
		var left: float = 64 / physical
		heading.position = Vector2(left, (13 if contact else 10) / physical)
		heading.size = Vector2(maxf(1, size.x - left - (32 if contact else 12) / physical), (26 if contact else 42) / physical)
		detail.position = Vector2(left, (44 if contact else 60) / physical)
		detail.size = Vector2(heading.size.x, 20 / physical)
		if is_instance_valid(number_label):
			number_label.add_theme_font_size_override("font_size", ceili(16 / physical))
			number_label.position = Vector2(5, 7) / physical
			number_label.size = Vector2(50, 22) / physical
		queue_redraw()
	func _draw() -> void:
		var paper: StyleBoxFlat = UI.box(Color("d9dcdb") if read else Color("fff7ed"), Color("4FE0D4") if has_focus() or is_pressed() else Color("aababa") if read else Color("85c5d5"), 0)
		paper.set_corner_radius_all(8)
		paper.shadow_size = 2
		draw_style_box(paper, Rect2(Vector2.ZERO, size).grow(-2))
		var tile: Rect2 = Rect2(Vector2(5, 5) / physical, Vector2(50 / physical, size.y - 10 / physical))
		var accent: Color = Color("9aa9a7") if read else Color("4fc6ca")
		draw_rect(tile, accent)
		if contact:
			if portrait != null:
				var picture: Rect2 = Rect2(tile.position.x + 3 / physical, tile.get_center().y - 24 / physical, 44 / physical, 48 / physical)
				var extent: Vector2 = portrait.get_size() * minf(picture.size.x / portrait.get_width(), picture.size.y / portrait.get_height())
				draw_texture_rect(portrait, Rect2(picture.get_center()-extent*0.5,extent), false)
			else:
				draw_circle(tile.get_center() + Vector2(0, -10 / physical), 9 / physical, Color("fff7ed"))
				draw_rect(Rect2(tile.get_center() + Vector2(-15, 3) / physical, Vector2(30, 19) / physical), Color("fff7ed"))
			var arrow: Vector2 = Vector2(size.x-17/physical,size.y*0.5)
			draw_polyline(PackedVector2Array([arrow+Vector2(-4,-6)/physical,arrow+Vector2(2,0)/physical,arrow+Vector2(-4,6)/physical]),Color("365b63"),2/physical)
			return
		var center: Vector2 = tile.get_center() + Vector2(0, 12 / physical if mail_number > 0 else 0.0)
		var ink: Color = Color("365b63")
		if read:
			draw_colored_polygon(PackedVector2Array([center + Vector2(-18, -9) / physical, center + Vector2(0, -25) / physical, center + Vector2(18, -9) / physical]), ink)
			draw_rect(Rect2(center + Vector2(-13, -18) / physical, Vector2(26, 25) / physical), Color("fff7ed"))
		draw_rect(Rect2(center + Vector2(-18, -9) / physical, Vector2(36, 25) / physical), Color("fff7ed"))
		draw_rect(Rect2(center + Vector2(-18, -9) / physical, Vector2(36, 25) / physical), ink, false, 2 / physical)
		draw_polyline(PackedVector2Array([center + Vector2(-18, -9) / physical, center + Vector2(0, 5) / physical, center + Vector2(18, -9) / physical]), ink, 2 / physical)

class Notifications extends Control:
	signal activated(data: Dictionary)
	var phone: Control
	var shell: Control
	var queue: Array[Dictionary] = []
	var seen: Dictionary = {}
	var current: Dictionary = {}
	var scope: String = ""
	var elapsed: float = 0.0
	var banner: Button
	var glyph: IntelPixelIcon
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		z_index = 20
		banner = UI.button("", _activate)
		banner.name = "PhoneNotification"
		banner.alignment = HORIZONTAL_ALIGNMENT_LEFT
		banner.add_theme_color_override("font_color", Color("101623"))
		banner.add_theme_color_override("font_disabled_color", Color("365b63"))
		for style: String in ["normal", "hover", "pressed", "disabled"]:
			var paper: StyleBoxFlat = UI.box(Color("fff7ed"), Color("4FE0D4"), 12)
			paper.set_corner_radius_all(12)
			banner.add_theme_stylebox_override(style, paper)
		add_child(banner)
		glyph = IntelPixelIcon.new()
		glyph.ink_override = Color("365b63")
		banner.add_child(glyph)
		banner.hide()
	func set_scope(value: String) -> void:
		if value == scope: return
		clear()
		scope = value
	func clear() -> void:
		seen.clear()
		dismiss()
	func dismiss() -> void:
		queue.clear()
		current.clear()
		elapsed = 0.0
		if is_instance_valid(banner): banner.hide()
	func enqueue(data: Dictionary) -> void:
		var id: String = str(data.get("id", ""))
		if id.is_empty() or seen.has(id): return
		seen[id] = true
		queue.append(data.duplicate(true))
	func _process(delta: float) -> void:
		if not is_instance_valid(phone) or not is_instance_valid(shell): return
		var paused: bool = bool(phone.get("_locked")) or not phone.is_visible_in_tree()
		banner.disabled = paused
		if paused: return
		if current.is_empty():
			if queue.is_empty(): return
			current = queue.pop_front()
			elapsed = 0.0
			banner.text = str(current.get("app", "MAIL")).to_upper() + " · " + str(current.get("sender", "New notification")) + "\n" + str(current.get("preview", ""))
			banner.icon = current.get("icon") as Texture2D
			glyph.visible = banner.icon == null
			glyph.kind = IntelPixelIcon.Kind.CHAT if str(current.get("app", "")).to_lower() in ["chat", "messages", "messenger"] else IntelPixelIcon.Kind.ENVELOPE
			banner.accessibility_name = banner.text + ". Tap to open."
			banner.show()
			var audio: Node = get_node_or_null("/root/AudioManager")
			if audio != null: audio.play_sfx(str(current.get("sound", "ui_notification")))
		elapsed += delta
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		var reduced: bool = phone._reduced_motion()
		var enter: float = 1.0 if reduced else smoothstep(0.0, 0.28, elapsed)
		banner.add_theme_font_size_override("font_size", ceili(16 / physical))
		banner.size = Vector2(maxf(1, shell.size.x - 32 / physical), 82 / physical)
		glyph.position = Vector2(12 / physical, (banner.size.y - 26 / physical) * 0.5)
		glyph.size = Vector2.ONE * 26 / physical
		for style: String in ["normal", "hover", "pressed", "disabled"]:
			(banner.get_theme_stylebox(style) as StyleBoxFlat).content_margin_left = (48 if glyph.visible else 12) / physical
		banner.position = shell.position + Vector2(16, 38 - (1.0 - enter) * 18) / physical
		banner.modulate.a = enter
		var duration: float = maxf(0.8, float(current.get("duration", 2.4)))
		if not bool(current.get("sticky", false)) and elapsed >= duration:
			current.clear()
			banner.hide()
	func _activate() -> void:
		if current.is_empty() or bool(phone.get("_locked")) or not phone.is_visible_in_tree(): return
		var data: Dictionary = current.duplicate(true)
		current.clear()
		banner.hide()
		activated.emit(data)
