class_name VictoryScreen
extends BaseScreen
## Post-clear stat tally. Router owns add/remove; do not queue_free() this node.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = %TitleLabel
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _mastery_label: Label = %MasteryLabel
@onready var _btn_continue: Button = %BtnContinue

var _pixel_font: Font


func _ready() -> void:
	_load_font()
	_background.color = Color(Palette.GAMEPLAY_BG, 0.94)
	_apply_label(_title_label, Palette.GREEN, 22)
	_apply_label(_accuracy_label, Palette.TEXT_PRIMARY, 12)
	_apply_label(_gold_label, Palette.GOLD, 12)
	_apply_label(_mastery_label, Palette.TEXT_SECONDARY, 9)
	_style_continue_button()
	_btn_continue.pressed.connect(_on_continue_pressed)


func on_enter(args: Dictionary) -> void:
	var accuracy_stored: Variant = args.get("accuracy", 1.0)
	var gold_stored: Variant = args.get("gold", 0)
	setup_victory_stats(float(accuracy_stored), int(gold_stored))


func setup_victory_stats(accuracy: float, gold: int) -> void:
	var accuracy_pct: int = int(round(clampf(accuracy, 0.0, 1.0) * 100.0))
	_accuracy_label.text = "Exam Accuracy: " + str(accuracy_pct) + "%"
	_gold_label.text = "Credits Earned: +" + str(maxi(0, gold))


func _on_continue_pressed() -> void:
	# Router.pop() queue_free()s this screen. Do not free it here.
	Router.request_back()


func _style_continue_button() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.GOLD
	box.border_color = Palette.TEXT_ON_GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	_btn_continue.add_theme_stylebox_override("normal", box)
	_btn_continue.add_theme_stylebox_override("hover", box)
	_btn_continue.add_theme_stylebox_override("pressed", box)
	_btn_continue.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD)
	if _pixel_font != null:
		_btn_continue.add_theme_font_override("font", _pixel_font)
	_btn_continue.add_theme_font_size_override("font_size", 12)


func _apply_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _load_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file
