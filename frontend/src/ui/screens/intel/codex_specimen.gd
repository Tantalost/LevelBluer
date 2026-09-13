extends Control
## Asset-cache preview only: never spawns live combat nodes or downloads new art.
const Glyphs = preload("res://src/ui/screens/deploy/upgrade_glyphs.gd")
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
var tab: StringName = &"units"
var unit_id := "base"
var accent := UI.TEAL
var _base: Texture2D
var _head: Texture2D
var _frames: SpriteFrames
var _animation: StringName = &"walk_side"
var _time := 0.0
var _frame := 0

func _ready() -> void:
	custom_minimum_size = Vector2(180, 184)
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	AssetManager.sync_finished.connect(_refresh)
	_refresh(true)

func _refresh(_success: bool) -> void:
	if tab == &"units" and unit_id == "base":
		_base = AssetManager.get_texture("tower_basic_node_base")
		_head = AssetManager.get_texture("tower_basic_node_head")
	elif tab == &"enemies":
		_frames = AssetManager.get_character_sprite_frames(EnemyBase.character_for_wave(unit_id))
		if _frames != null and not _frames.has_animation(_animation):
			_animation = &"walk_top"
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _frames == null or not _frames.has_animation(_animation):
		return
	var count := _frames.get_frame_count(_animation)
	if count == 0:
		return
	_time += delta
	var next := int(_time * _frames.get_animation_speed(_animation)) % count
	if next != _frame:
		_frame = next
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1720"))
	var center := size * Vector2(0.5, 0.49)
	for radius in [0.31, 0.43]:
		draw_arc(center, minf(size.x, size.y) * radius, 0, TAU, 64, Color(accent, 0.16), 1.0, true)
	for corner in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(8, size.y - 8), size - Vector2(8, 8)]:
		var direction := Vector2(1 if corner.x < center.x else -1, 1 if corner.y < center.y else -1)
		draw_line(corner, corner + Vector2(14 * direction.x, 0), accent, 2)
		draw_line(corner, corner + Vector2(0, 14 * direction.y), accent, 2)
	var art_rect := Rect2(center - Vector2(65, 69), Vector2(130, 138))
	if tab == &"units" and _base != null:
		_fit(_base, art_rect)
		if _head != null:
			_fit(_head, art_rect)
	elif _frames != null and _frames.has_animation(_animation) and _frames.get_frame_count(_animation) > 0:
		_fit(_frames.get_frame_texture(_animation, _frame % _frames.get_frame_count(_animation)), art_rect)
	else:
		Glyphs.paint(self, center, 48, unit_id if tab == &"units" else "lock", accent)
	var caption := "LIVE SPECIMEN" if _frames != null else ("HARDWARE" if _base != null else "SCHEMATIC")
	draw_string(UI.FONT, Vector2(14, size.y - 15), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, accent)

func _fit(texture: Texture2D, rect: Rect2) -> void:
	if texture == null or texture.get_width() == 0 or texture.get_height() == 0:
		return
	var factor := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var fitted := texture.get_size() * factor
	draw_texture_rect(texture, Rect2(rect.get_center() - fitted * 0.5, fitted), false)
