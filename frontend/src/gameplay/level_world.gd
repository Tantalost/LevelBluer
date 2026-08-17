extends Node2D
## Procedural forest clearing. Placeholder until authored tile art ships.

var _path: PackedVector2Array = PackedVector2Array([
	Vector2(80, 400),
	Vector2(640, 180),
	Vector2(1200, 400),
])


func _ready() -> void:
	z_index = -1
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var vr: Rect2 = get_viewport().get_visible_rect()
	draw_rect(vr, Palette.FOREST_NIGHT, true)
	_draw_clearing(vr)
	_draw_path()
	_draw_scatter()
	_draw_spawn_grove()
	_draw_chevrons()
	_draw_castle(Vector2(1200, 400))
	_draw_tree_frame(vr)


func _draw_clearing(vr: Rect2) -> void:
	var oval := PackedVector2Array()
	var cx: float = vr.size.x * 0.5
	var cy: float = vr.size.y * 0.52
	var rx: float = vr.size.x * 0.42
	var ry: float = vr.size.y * 0.32
	for i in 28:
		var t: float = TAU * float(i) / 28.0
		oval.append(Vector2(cx + cos(t) * rx, cy + sin(t) * ry))
	draw_colored_polygon(oval, Palette.FOREST_FLOOR)


func _draw_path() -> void:
	draw_polyline(_path, Palette.PATH_DIRT, 78.0, false)
	draw_polyline(_path, Palette.PATH_DIRT_LIT, 42.0, false)


func _draw_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 18:
		var p := Vector2(rng.randf_range(180.0, 1100.0), rng.randf_range(220.0, 560.0))
		if _near_path(p, 70.0):
			continue
		if rng.randf() < 0.45:
			_draw_rock(p, rng.randf_range(6.0, 12.0))
		else:
			_draw_mushroom(p, rng.randf() < 0.5)
		if rng.randf() < 0.4:
			_draw_pine(p + Vector2(rng.randf_range(-18.0, 18.0), 10.0), rng.randf_range(28.0, 48.0), false)


func _near_path(p: Vector2, radius: float) -> bool:
	for i in _path.size() - 1:
		if _dist_to_segment(p, _path[i], _path[i + 1]) < radius:
			return true
	return false


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0
	var denom: float = ab.length_squared()
	if denom > 0.0:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw_spawn_grove() -> void:
	var origin := Vector2(70, 410)
	var offsets: Array[Vector2] = [
		Vector2(-36, 8), Vector2(-8, -18), Vector2(22, 14), Vector2(-22, 28), Vector2(10, -4),
	]
	for o: Vector2 in offsets:
		_draw_pine(origin + o, 64.0, true)


func _draw_chevrons() -> void:
	var origin := Vector2(130, 400)
	for i in 3:
		var x: float = origin.x + float(i) * 28.0
		var col: Color = Color(Palette.GREEN, 0.85 - float(i) * 0.18)
		var pts := PackedVector2Array([
			Vector2(x, origin.y - 14.0),
			Vector2(x + 18.0, origin.y),
			Vector2(x, origin.y + 14.0),
			Vector2(x + 6.0, origin.y),
		])
		draw_colored_polygon(pts, col)


func _draw_castle(origin: Vector2) -> void:
	var shadow := Rect2(origin + Vector2(-52, -18), Vector2(108, 28))
	draw_rect(shadow, Color(Palette.BG_DEEP, 0.45), true)
	draw_rect(Rect2(origin + Vector2(-48, -70), Vector2(96, 78)), Palette.CASTLE_SHADOW, true)
	draw_rect(Rect2(origin + Vector2(-40, -62), Vector2(80, 70)), Palette.CASTLE_STONE, true)
	draw_rect(Rect2(origin + Vector2(-58, -88), Vector2(22, 96)), Palette.CASTLE_SHADOW, true)
	draw_rect(Rect2(origin + Vector2(36, -88), Vector2(22, 96)), Palette.CASTLE_SHADOW, true)
	draw_rect(Rect2(origin + Vector2(-54, -84), Vector2(14, 88)), Palette.CASTLE_STONE, true)
	draw_rect(Rect2(origin + Vector2(40, -84), Vector2(14, 88)), Palette.CASTLE_STONE, true)
	for i in 5:
		var merlon_x: float = origin.x - 38.0 + float(i) * 16.0
		draw_rect(Rect2(Vector2(merlon_x, origin.y - 78.0), Vector2(10, 10)), Palette.CASTLE_STONE, true)
	draw_rect(Rect2(origin + Vector2(-10, -18), Vector2(20, 26)), Palette.BG_DEEP, true)
	var flag_top := origin + Vector2(2, -108)
	draw_line(origin + Vector2(2, -88), flag_top, Palette.TEXT_PRIMARY, 2.0)
	draw_colored_polygon(PackedVector2Array([
		flag_top,
		flag_top + Vector2(22, 8),
		flag_top + Vector2(0, 16),
	]), Palette.GREEN)
	_draw_heart(origin + Vector2(0, -128), 10.0)


func _draw_heart(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(-r * 0.45, -r * 0.15), r * 0.55, Palette.HEART)
	draw_circle(c + Vector2(r * 0.45, -r * 0.15), r * 0.55, Palette.HEART)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.95, 0.0),
		c + Vector2(0.0, r * 1.15),
		c + Vector2(r * 0.95, 0.0),
	]), Palette.HEART)


func _draw_tree_frame(vr: Rect2) -> void:
	var tree_w: float = 36.0
	var x: float = 8.0
	while x < vr.size.x:
		var h: float = 90.0 + 40.0 * sin(x * 0.05)
		_draw_pine(Vector2(x, vr.size.y + 8.0), h, false)
		_draw_pine(Vector2(x, 18.0), h * 0.55, false)
		x += tree_w * 0.62
	var y: float = 24.0
	while y < vr.size.y:
		_draw_pine(Vector2(18.0, y), 110.0, false)
		_draw_pine(Vector2(vr.size.x - 18.0, y), 110.0, false)
		y += 32.0


func _draw_pine(base: Vector2, height: float, lit: bool) -> void:
	var half: float = clampf(height * 0.22, 10.0, 22.0)
	var fill: Color = Palette.PINE_LIT if lit else Palette.PINE
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0.0, -height),
		base + Vector2(-half, 0.0),
		base + Vector2(half, 0.0),
	]), fill)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0.0, -height * 0.72),
		base + Vector2(-half * 0.7, -height * 0.28),
		base + Vector2(half * 0.7, -height * 0.28),
	]), Palette.PINE_LIT if lit else Color(Palette.PINE_LIT, 0.55))
	if lit:
		draw_circle(base + Vector2(0.0, -height * 0.55), 5.0, Color(Palette.SKILL_AURA, 0.35))


func _draw_rock(p: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-r, 0.0),
		p + Vector2(-r * 0.3, -r * 0.7),
		p + Vector2(r * 0.6, -r * 0.5),
		p + Vector2(r, 0.2),
	]), Palette.CASTLE_SHADOW)


func _draw_mushroom(p: Vector2, pink: bool) -> void:
	var cap: Color = Palette.HEART if pink else Palette.TEXT_SECONDARY
	draw_rect(Rect2(p + Vector2(-2, -6), Vector2(4, 8)), Palette.TEXT_MUTED, true)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-8, -4),
		p + Vector2(0, -12),
		p + Vector2(8, -4),
	]), cap)
