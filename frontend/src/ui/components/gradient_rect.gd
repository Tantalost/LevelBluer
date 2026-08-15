class_name GradientRect
extends TextureRect
## Fills a rect with a linear gradient — used for DEPLOY/DEFEND and mode cards.

@export var gradient_colors: PackedColorArray = PackedColorArray([Color.WHITE, Color.BLACK])
@export var vertical: bool = true


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	rebuild()


func set_colors(colors: PackedColorArray, is_vertical: bool = true) -> void:
	gradient_colors = colors
	vertical = is_vertical
	rebuild()


func rebuild() -> void:
	if gradient_colors.is_empty():
		return

	var grad := Gradient.new()
	for i in gradient_colors.size():
		var t := 0.0 if gradient_colors.size() <= 1 else float(i) / float(gradient_colors.size() - 1)
		grad.add_point(t, gradient_colors[i])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	texture = tex
