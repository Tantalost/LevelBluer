extends Button
## Reusable research dossier. Art comes from the existing asset cache.

const Glyphs = preload("res://src/ui/screens/deploy/upgrade_glyphs.gd")
const FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
var tower_id := "base"
var unlocked := true
var accent := Color("5ee5c0")
var heading := "BASIC NODE"
var role := "DPS"
var cost := 2
var damage := 1
var rate := 0.55
var slots := 2
var ranks := 0
var total_ranks := 9
var requirement := ""
var base_art: Texture2D
var head_art: Texture2D

func _ready() -> void:
	flat = true
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for sig in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		sig.connect(queue_redraw)
	_refresh_art()
	AssetManager.sync_finished.connect(_on_assets_ready)

func _on_assets_ready(_success: bool) -> void:
	_refresh_art()

func _refresh_art() -> void:
	if tower_id == "base":
		base_art = AssetManager.get_texture("tower_basic_node_base")
		head_art = AssetManager.get_texture("tower_basic_node_head")
	queue_redraw()

func _draw() -> void:
	var factor := size / Vector2(300, 430)
	draw_set_transform(Vector2.ZERO, 0, factor)
	var hover := is_hovered() or has_focus()
	var edge := accent if hover else Color(accent, 0.4)
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(276, 0), Vector2(300, 24), Vector2(300, 430), Vector2(18, 430), Vector2(0, 412), Vector2(0, 0)])
	draw_colored_polygon(outline, Color("101c2b") if hover else Color("0c1623"))
	draw_polyline(outline, edge, 1.5, true)
	draw_line(Vector2(18, 0), Vector2(100, 0), accent, 3)
	_copy("0%d / %s" % [["base", "scanner", "sandbox"].find(tower_id) + 1, role], Vector2(20, 29), 9, accent)
	_copy("ONLINE" if unlocked else "LOCKED", Vector2(212, 29), 8, accent if unlocked else Color("8794a8"))
	# A quiet blueprint well gives the hardware a focal point and sense of scale.
	var well := Rect2(16, 44, 268, 188)
	draw_rect(well, Color("09121e"))
	for x in range(24, 281, 22):
		draw_line(Vector2(x, 45), Vector2(x, 231), Color(accent, 0.035))
	for y in range(55, 232, 22):
		draw_line(Vector2(17, y), Vector2(283, y), Color(accent, 0.035))
	var center := Vector2(150, 133)
	for r in [60, 82]:
		draw_arc(center, r, 0, TAU, 64, Color(accent, 0.14), 1.0, true)
	if tower_id == "base" and base_art != null:
		_fit_art(base_art, Rect2(75, 71, 150, 150))
		if head_art != null:
			_fit_art(head_art, Rect2(64, 51, 172, 172))
	else:
		_draw_schematic(center)
	_copy("HARDWARE PREVIEW" if tower_id == "base" and base_art != null else "SYSTEM SCHEMATIC", Vector2(20, 220), 7, Color("708297"))
	_copy(heading, Vector2(20, 261), 15, Color("e6edee"))
	var descriptors := {"base": "PRECISION / DIRECT FIRE", "scanner": "DETECTION / RAPID FIRE", "sandbox": "CONTROL / SLOW FIELD"}
	_copy(str(descriptors[tower_id]), Vector2(20, 281), 8, accent)
	draw_line(Vector2(20, 298), Vector2(280, 298), Color("263447"))
	var stat_labels := ["DAMAGE", "RATE / S", "SLOTS"]
	var stat_values := [str(damage), "%.2f" % rate, str(slots)]
	if tower_id == "sandbox":
		stat_labels[0] = "SLOW"
		stat_values[0] = "%d%%" % roundi((1.0 - float(ContentDB.get_tower(tower_id).get("zone_slow", 1))) * 100)
	for i in 3:
		_copy(stat_labels[i], Vector2(20 + i * 92, 317), 7, Color("8191a5"))
		_copy(stat_values[i], Vector2(20 + i * 92, 340), 13, Color("d7e2ec"))
	_copy("DEPLOY %dG" % cost, Vector2(20, 365), 8, accent)
	_copy("%d/%d TECH" % [ranks, total_ranks] if total_ranks > 0 else "NO UPGRADES YET", Vector2(152, 365), 7, Color("8d9caf"))
	var action := Rect2(16, 385, 268, 29)
	draw_rect(action, Color(accent, 0.14) if unlocked else Color("172131"))
	_copy("OPEN RESEARCH  >" if unlocked else requirement, Vector2(28, 404), 9, accent if unlocked else Color("96a4b7"))
	if not unlocked:
		Glyphs.paint(self, Vector2(260, 63), 9, "lock", Color("91a1b5"))
	draw_set_transform(Vector2.ZERO)

func _copy(value: String, pos: Vector2, px: int, ink: Color) -> void:
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)

func _fit_art(texture: Texture2D, rect: Rect2) -> void:
	var ratio := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var fitted := texture.get_size() * ratio
	draw_texture_rect(texture, Rect2(rect.get_center() - fitted * 0.5, fitted), false)

func _draw_schematic(center: Vector2) -> void:
	var ink := Color(accent, 0.8)
	var footprint := PackedVector2Array([center + Vector2(0, 57), center + Vector2(65, 30), center + Vector2(0, 3), center + Vector2(-65, 30), center + Vector2(0, 57)])
	draw_colored_polygon(footprint, Color(accent, 0.06))
	draw_polyline(footprint, ink, 1.5, true)
	if tower_id == "scanner":
		draw_rect(Rect2(center + Vector2(-18, -5), Vector2(36, 38)), Color("203644"))
		draw_line(center + Vector2(0, 23), center + Vector2(0, -30), ink, 4, true)
		Glyphs.paint(self, center + Vector2(0, -23), 34, "scanner", ink)
	else:
		Glyphs.paint(self, center + Vector2(0, -15), 43, "sandbox" if tower_id == "sandbox" else "root", ink)
		for i in [-1, 1]:
			draw_line(center + Vector2(i * 47, 22), center + Vector2(i * 47, -31), ink, 3, true)
