extends Control
## Original pixel vignette on a fixed 320x104 canvas. No textures or particle nodes.
const INK := Color("060b10")
const FAR := Color("192a32")
const CONCRETE := Color("344851")
const TEAL := Color("85d9c3")
const GOLD := Color("d5b67a")
const ALERT := Color("df826d")
var timeline := 0.0:
	set(value):
		timeline = clampf(value, 0, 1.8)
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 1 or size.y < 1:
		return
	var factor := maxf(1, floorf(minf(size.x / 320, size.y / 104)))
	var origin := ((size - Vector2(320, 104) * factor) * 0.5).floor()
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	draw_rect(Rect2(0, 0, 320, 104), INK)
	var awake := clampf((timeline - 0.85) / 0.65, 0, 1)
	# Static, deterministic skyline: muted gold becomes teal when the defense wakes.
	for i in 15:
		var x := 5 + i * 21
		var height := 18 + posmod(i * 13, 33)
		draw_rect(Rect2(x, 72 - height, 18, height), FAR)
		for floor_index in int(height / 8):
			for column in 2:
				var lit := (x < 160 + awake * 160 and x > 160 - awake * 160)
				var color := TEAL if lit else Color(GOLD, 0.4)
				draw_rect(Rect2(x + 4 + column * 7, 76 - height + floor_index * 8, 2, 3), color)
	draw_rect(Rect2(0, 72, 320, 32), Color("122029"))
	for i in 8:
		draw_rect(Rect2(4 + i * 40, 89, 24, 1), Color("3b4a4e"))
	# Cable runs converge on the player-held outpost.
	for direction in [-1, 1]:
		draw_line(Vector2(160 + direction * 22, 84), Vector2(160 + direction * 150, 84), Color("46605f"), 1)
		if awake > 0:
			draw_line(Vector2(160 + direction * 22, 84), Vector2(160 + direction * (22 + awake * 128), 84), TEAL, 2)
	# Miniature server outpost with a broad, stable silhouette.
	draw_rect(Rect2(137, 62, 48, 26), Color("091219"))
	draw_rect(Rect2(140, 45, 40, 38), CONCRETE)
	draw_rect(Rect2(136, 41, 48, 5), Color("687d7c"))
	draw_rect(Rect2(144, 49, 14, 30), INK)
	draw_rect(Rect2(162, 49, 14, 30), INK)
	for row in 4:
		for column in 2:
			var x := 147 + column * 18
			draw_rect(Rect2(x, 53 + row * 6, 8, 2), TEAL if awake > 0 else Color("68705a"))
			draw_rect(Rect2(x + 9, 53 + row * 6, 1, 2), GOLD)
	draw_rect(Rect2(153, 29, 14, 10), Color("657c80"))
	draw_rect(Rect2(157, 25, 6, 6), TEAL if timeline >= 0.8 else GOLD)
	# One hostile envelope, not a barrage or strobe.
	if timeline > 0.18 and timeline < 0.82:
		var travel := clampf((timeline - 0.18) / 0.64, 0, 1)
		var packet := Vector2(roundf(lerpf(20, 119, travel)), 48)
		draw_rect(Rect2(packet + Vector2(-12, 2), Vector2(7, 1)), Color(ALERT, 0.35))
		draw_rect(Rect2(packet, Vector2(11, 8)), ALERT)
		draw_polyline(PackedVector2Array([packet + Vector2(1, 1), packet + Vector2(5, 5), packet + Vector2(10, 1)]), INK, 1)
	if timeline >= 0.60:
		var shield := PackedVector2Array([Vector2(160, 15), Vector2(195, 27), Vector2(192, 57), Vector2(180, 76), Vector2(160, 88), Vector2(140, 76), Vector2(128, 57), Vector2(125, 27)])
		draw_colored_polygon(shield, Color(TEAL, 0.04))
		shield.append(shield[0])
		draw_polyline(shield, Color(TEAL, clampf((timeline - 0.6) / 0.2, 0, 1)), 2)
	# A single expanding pixel ring marks impact; confined to the vignette.
	if timeline >= 0.82 and timeline < 1.24:
		var burst := (timeline - 0.82) / 0.42
		for i in 8:
			var point := Vector2(126, 48) + Vector2.from_angle(i * TAU / 8) * (4 + burst * 18)
			draw_rect(Rect2(point.round(), Vector2(2, 2)), Color(TEAL, 1 - burst))
	draw_rect(Rect2(1, 1, 318, 102), Color("4d6666"), false, 1)
	for x in [0, 310]:
		draw_rect(Rect2(x, 0, 10, 2), TEAL)
		draw_rect(Rect2(x, 102, 10, 2), TEAL)
	draw_set_transform(Vector2.ZERO)
