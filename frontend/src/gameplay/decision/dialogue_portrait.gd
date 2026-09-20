extends Control
## Temporary pixel busts. Set portrait_texture when final character art arrives.
var portrait_texture: Texture2D
var speaker := "Mia"
var speaking := false
var talking := false
var clock := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	clock += delta
	if talking:
		queue_redraw()

func configure(who: String, active: bool, animated: bool) -> void:
	speaker = who
	speaking = active
	talking = animated
	queue_redraw()

func _draw() -> void:
	var ink := Color("85d9c3") if speaking else Color("46606b")
	var frame := Rect2(Vector2.ZERO, size)
	draw_style_box(_frame(ink), frame)
	if portrait_texture != null:
		var fitted := portrait_texture.get_size()
		fitted *= minf((size.x - 12) / fitted.x, (size.y - 12) / fitted.y)
		draw_texture_rect(portrait_texture, Rect2((size - fitted) / 2, fitted), false, Color.WHITE if speaking else Color(0.5, 0.6, 0.6))
		return
	var scale_factor := minf((size.x - 12) / 48.0, (size.y - 8) / 48.0)
	var offset := Vector2((size.x - 48 * scale_factor) / 2, size.y - 48 * scale_factor - 4)
	draw_set_transform(offset, 0, Vector2.ONE * scale_factor)
	var skin := Color("d5ab87")
	var coat := Color("37677a")
	var hair := Color("293a47")
	if speaker.begins_with("Ramon"):
		skin = Color("b88b69")
		coat = Color("807452")
	elif speaker == "Mia":
		coat = Color("487e77")
		hair = Color("394153")
	if not speaking:
		skin = skin.darkened(0.4)
		coat = coat.darkened(0.4)
	draw_rect(Rect2(7, 32, 34, 16), coat.darkened(0.25))
	draw_rect(Rect2(11, 30, 26, 18), coat)
	draw_rect(Rect2(20, 25, 8, 10), skin.darkened(0.12))
	draw_rect(Rect2(13, 7, 22, 22), hair)
	draw_rect(Rect2(16, 13, 16, 16), skin)
	draw_rect(Rect2(14, 7, 19, 8), hair)
	draw_rect(Rect2(18, 19, 3, 2), Color("13202b"))
	draw_rect(Rect2(27, 19, 3, 2), Color("13202b"))
	var mouth_height := 3 if talking and int(clock * 9) % 2 == 0 else 1
	draw_rect(Rect2(22, 25, 5, mouth_height), Color("654c47"))
	draw_rect(Rect2(17, 34, 4, 12), coat.lightened(0.15))
	draw_rect(Rect2(28, 36, 5, 3), ink)
	if speaker == "Mia":
		draw_rect(Rect2(12, 16, 4, 18), hair)
	elif speaker.begins_with("Ramon"):
		draw_rect(Rect2(16, 17, 8, 6), ink, false, 1)
		draw_rect(Rect2(25, 17, 8, 6), ink, false, 1)
	else:
		draw_rect(Rect2(12, 17, 4, 9), ink)
		draw_line(Vector2(14, 25), Vector2(20, 28), ink, 2)
	draw_set_transform(Vector2.ZERO)

func _frame(ink: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172c35") if speaking else Color("101b24")
	style.border_color = ink
	style.set_border_width_all(2 if speaking else 1)
	return style
