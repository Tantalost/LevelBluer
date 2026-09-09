extends Node2D
## Reusable pixel collapse drawn from the actual base texture, not a video asset.
var texture: Texture2D
var extent := Vector2(132, 132)
var elapsed := 0.0
var _pieces: Array[Dictionary] = []

func configure(source: Texture2D, displayed_size: Vector2) -> void:
	texture = source
	extent = displayed_size
	var rng := RandomNumberGenerator.new()
	rng.seed = 8127
	_pieces.clear()
	for y in 6:
		for x in 6:
			_pieces.append({"cell": Vector2(x, y), "velocity": Vector2(rng.randf_range(-0.85, 0.85), rng.randf_range(-1.1, -0.25)), "spin": rng.randf_range(-1.5, 1.5), "delay": rng.randf_range(0.0, 0.24)})

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	var unit := extent.x
	var collapse := maxf(0, elapsed - 0.28)
	# A charred compressed remnant remains grounded after the fragments settle.
	if collapse > 0.3:
		var rubble := Rect2(Vector2(-extent.x * 0.5, extent.y * 0.24), Vector2(extent.x, extent.y * 0.24))
		draw_texture_rect(texture, rubble, false, Color(0.3, 0.22, 0.26, minf(1, collapse)))
	var source_step := texture.get_size() / 6.0
	var step := extent / 6.0
	if collapse < 2.1:
		for piece in _pieces:
			var t := maxf(0, collapse - float(piece.delay))
			var offset: Vector2 = piece.velocity * unit * t * 0.7
			offset.y += unit * t * t * 0.7
			offset.y = minf(offset.y, extent.y * 0.45)
			var center: Vector2 = (piece.cell + Vector2.ONE * 0.5) * step - extent * 0.5 + offset
			draw_set_transform(center.snapped(Vector2.ONE * 2), float(piece.spin) * t)
			var alpha := clampf(2.1 - collapse, 0, 1)
			draw_texture_rect_region(texture, Rect2(-step * 0.5, step), Rect2(piece.cell * source_step, source_step), Color(1, 0.75, 0.78, alpha))
		draw_set_transform(Vector2.ZERO)
	# Repeating white-hot pixel bursts and rising embers mirror the reference.
	for i in 34:
		var period := 1.1 + float(i % 5) * 0.19
		var t := fmod(elapsed + i * 0.073, period) / period
		var angle := float(i) * 2.39996
		var origin := Vector2(cos(angle) * unit * 0.32, extent.y * 0.30)
		var travel := Vector2(cos(angle) * unit * 0.22, -unit * (0.25 + float(i % 7) * 0.06)) * t
		var width := maxf(2, unit * 0.032 * (1.0 - t))
		var ink := Color("fff0ca") if t < 0.22 else Color("ff647f")
		ink.a = (1.0 - t) * (1.0 if elapsed < 2.5 else 0.55)
		draw_rect(Rect2((origin + travel).snapped(Vector2.ONE * 2), Vector2.ONE * width), ink)
	for i in 9:
		var t := fmod(elapsed * 0.38 + i * 0.113, 1.0)
		var p := Vector2(sin(i * 2.1) * unit * 0.24, extent.y * 0.25 - t * unit * 0.7)
		var width := unit * (0.08 + t * 0.16)
		draw_rect(Rect2(p.snapped(Vector2.ONE * 3) - Vector2.ONE * width * 0.5, Vector2.ONE * width), Color(0.12, 0.08, 0.14, (1.0 - t) * 0.35))
	# Chunky white cores over pink flame silhouettes remain readable at map scale.
	var pixel := maxf(4.0, unit * 0.035)
	for i in 7:
		var flicker := floori(elapsed * 9 + i * 1.7) % 4
		var origin := Vector2((i - 3) * pixel * 2.2, extent.y * 0.32)
		var height := 3 + flicker
		for j in height:
			var p := origin + Vector2(sin(i + j + floor(elapsed * 8)) * pixel, -j * pixel)
			draw_rect(Rect2(p.snapped(Vector2.ONE * 2), Vector2.ONE * pixel * 1.4), Color("ff4c79"))
			if j < height - 2:
				draw_rect(Rect2(p.snapped(Vector2.ONE * 2) + Vector2.ONE * pixel * 0.25, Vector2.ONE * pixel * 0.85), Color("fff3d2"))
	if elapsed < 0.5:
		var flash := sin(clampf(elapsed / 0.5, 0, 1) * PI)
		for i in 8:
			var p := Vector2.from_angle(i * TAU / 8) * unit * elapsed * 0.8
			draw_rect(Rect2(p - Vector2.ONE * unit * 0.07, Vector2.ONE * unit * 0.14), Color(1, 0.88, 0.85, flash))
