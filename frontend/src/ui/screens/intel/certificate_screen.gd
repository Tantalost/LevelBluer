class_name CertificateScreen
extends BaseScreen
## Capstone award after Module 1 Stage 10. Shows final BKT bars. No completion action.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var _os_bar: PanelContainer = %OsBar
@onready var _os_cursor: Label = %OsCursor
@onready var _os_led: ColorRect = %OsLed
@onready var _ground: ColorRect = %Ground
@onready var _back_button: Button = %BackButton
@onready var _header_title: Label = %HeaderTitle
@onready var _status_line: Label = %StatusLine
@onready var _cert_card: PanelContainer = %CertCard
@onready var _cert_title_bar: PanelContainer = %CertTitleBar
@onready var _cert_well: PanelContainer = %CertWell
@onready var _cert_file: Label = %CertFile
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _threat_matrix: ThreatMatrixPanel = %ThreatMatrixPanel
@onready var _return_button: Button = %ReturnButton

var _pixel_font: Font
var _blink_t: float = 0.0


func _ready() -> void:
	_load_font()
	_ground.color = Palette.FOREST_FLOOR.lerp(Palette.GOLD, 0.18)
	_style_os_bar()
	_style_close_button()
	_style_window(_cert_card, Palette.GOLD)
	_style_title_bar(_cert_title_bar, Palette.ORANGE)
	_style_well(_cert_well, Palette.ORANGE)
	_style_return_button()
	_apply_label(_header_title, Palette.GOLD, 14)
	_apply_label(_os_cursor, Palette.GREEN, 14)
	_apply_label(_status_line, Palette.GOLD, 12)
	_apply_label(_cert_file, Palette.TEXT_PRIMARY, 11)
	_apply_label(_title_label, Palette.GOLD, 16)
	_apply_label(_subtitle_label, Palette.TEXT_PRIMARY, 12)
	_back_button.pressed.connect(func() -> void: Router.open_intel_hub())
	_return_button.pressed.connect(func() -> void: Router.open_intel_hub())


func _process(delta: float) -> void:
	_blink_t += delta
	var on: bool = fmod(_blink_t, 1.05) < 0.58
	_os_cursor.visible = on
	_os_led.color = Palette.GREEN if on else Color(Palette.GREEN, 0.28)


func on_enter(_args: Dictionary) -> void:
	set_process(true)
	var trainee: String = AuthService.display_name().strip_edges().to_upper()
	if trainee.is_empty():
		trainee = "OPERATIVE"
	_subtitle_label.text = "ISSUED TO  %s" % trainee
	_threat_matrix.refresh_matrix()


func on_resume() -> void:
	set_process(true)
	_threat_matrix.refresh_matrix()


func on_exit() -> void:
	set_process(false)


func _style_return_button() -> void:
	var box: StyleBoxFlat = _pixel_box(Palette.GOLD, Palette.BG_DEEP, 0, 0)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	_return_button.add_theme_stylebox_override("normal", box)
	_return_button.add_theme_stylebox_override("hover", box)
	_return_button.add_theme_stylebox_override("pressed", box)
	_return_button.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD)
	if _pixel_font != null:
		_return_button.add_theme_font_override("font", _pixel_font)
	_return_button.add_theme_font_size_override("font_size", 14)
	_return_button.custom_minimum_size = Vector2(0, 58)


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


func _style_os_bar() -> void:
	var style: StyleBoxFlat = _pixel_box(Color(Palette.BG_HEADER, 0.92), Palette.GOLD, 0, 2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_os_bar.add_theme_stylebox_override("panel", style)


func _style_close_button() -> void:
	_back_button.custom_minimum_size = Vector2(44, 32)
	var normal: StyleBoxFlat = _pixel_box(Palette.RED, Palette.RED_DEEP, 0, 2)
	var hover: StyleBoxFlat = _pixel_box(Palette.RED, Palette.TEXT_PRIMARY, 0, 2)
	_back_button.add_theme_stylebox_override("normal", normal)
	_back_button.add_theme_stylebox_override("hover", hover)
	_back_button.add_theme_stylebox_override("pressed", hover)
	_back_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	if _pixel_font != null:
		_back_button.add_theme_font_override("font", _pixel_font)
	_back_button.add_theme_font_size_override("font_size", 12)


func _style_window(card: PanelContainer, accent: Color) -> void:
	var box: StyleBoxFlat = _pixel_box(Palette.BG_HEADER, accent, 0, 3)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(Palette.BG_DEEP, 0.75)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	card.add_theme_stylebox_override("panel", box)


func _style_title_bar(bar: PanelContainer, fill: Color) -> void:
	var style: StyleBoxFlat = _pixel_box(fill, fill, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	bar.add_theme_stylebox_override("panel", style)


func _style_well(well: PanelContainer, fill: Color) -> void:
	var style: StyleBoxFlat = _pixel_box(fill, Color(Palette.TEXT_PRIMARY, 0.12), 0, 2)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	well.add_theme_stylebox_override("panel", style)


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
