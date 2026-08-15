@tool
extends EditorScript
## Generates res://assets/ui/level_blue_theme.tres.
##
## Run with File > Run in the script editor (Ctrl+Shift+X) while this file is
## open. Re-run any time you change the palette or add a variation.
##
## Why generate instead of clicking through the theme editor: eight variations
## built by hand is a few hundred inspector clicks, it drifts out of sync the
## moment two people edit it, and a .tres diff is unreadable in review. This is
## the source of truth; the .tres is a build artifact.

const OUTPUT_PATH := "res://assets/ui/level_blue_theme.tres"

# Point these at your actual font files once you have them.
const DISPLAY_FONT_PATH := "res://assets/fonts/display_pixel.ttf"
const BODY_FONT_PATH := "res://assets/fonts/body_sans.ttf"


func _run() -> void:
	var theme := Theme.new()

	var display_font := _load_font(DISPLAY_FONT_PATH)
	var body_font := _load_font(BODY_FONT_PATH)

	theme.default_font = body_font
	theme.default_font_size = 18

	_build_labels(theme, display_font, body_font)
	_build_buttons(theme, display_font)
	_build_panels(theme)
	_build_inputs(theme, body_font)
	_build_progress(theme)

	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	if err == OK:
		print("Theme written to ", OUTPUT_PATH)
	else:
		push_error("Failed to write theme: %d" % err)


func _build_labels(theme: Theme, display_font: Font, body_font: Font) -> void:
	# Base Label
	theme.set_color("font_color", "Label", Palette.TEXT_PRIMARY)
	theme.set_font("font", "Label", body_font)
	theme.set_font_size("font_size", "Label", 18)

	# DisplayTitle — "Security Alert", "Module 1: The Basics"
	_variation(theme, "DisplayTitle", "Label")
	theme.set_font("font", "DisplayTitle", display_font)
	theme.set_font_size("font_size", "DisplayTitle", 48)
	theme.set_color("font_color", "DisplayTitle", Palette.TEXT_PRIMARY)

	# ScreenTitle — "INTELLIGENCE", "PROGRESS"
	_variation(theme, "ScreenTitle", "Label")
	theme.set_font("font", "ScreenTitle", display_font)
	theme.set_font_size("font_size", "ScreenTitle", 32)
	theme.set_color("font_color", "ScreenTitle", Palette.TEXT_PRIMARY)

	# BodyText — lesson descriptions, rule checklists
	_variation(theme, "BodyText", "Label")
	theme.set_font("font", "BodyText", body_font)
	theme.set_font_size("font_size", "BodyText", 18)
	theme.set_color("font_color", "BodyText", Palette.TEXT_SECONDARY)

	# FieldLabel — the small spaced "EMAIL" / "PASSWORD" captions
	_variation(theme, "FieldLabel", "Label")
	theme.set_font("font", "FieldLabel", body_font)
	theme.set_font_size("font_size", "FieldLabel", 14)
	theme.set_color("font_color", "FieldLabel", Palette.CYAN)

	# ErrorText
	_variation(theme, "ErrorText", "Label")
	theme.set_font_size("font_size", "ErrorText", 16)
	theme.set_color("font_color", "ErrorText", Palette.RED)


func _build_buttons(theme: Theme, display_font: Font) -> void:
	# PrimaryButton — gold fill, dark text: "Log In", "DEPLOY", "CONTINUE"
	_variation(theme, "PrimaryButton", "Button")
	theme.set_font("font", "PrimaryButton", display_font)
	theme.set_font_size("font_size", "PrimaryButton", 28)
	theme.set_color("font_color", "PrimaryButton", Palette.TEXT_ON_GOLD)
	theme.set_color("font_hover_color", "PrimaryButton", Palette.TEXT_ON_GOLD)
	theme.set_color("font_pressed_color", "PrimaryButton", Palette.TEXT_ON_GOLD)
	theme.set_color("font_disabled_color", "PrimaryButton", Palette.TEXT_MUTED)
	theme.set_stylebox("normal", "PrimaryButton", _box(Palette.GOLD, Palette.GOLD, 0))
	theme.set_stylebox("hover", "PrimaryButton", _box(Palette.GOLD.lightened(0.1), Palette.GOLD, 0))
	theme.set_stylebox("pressed", "PrimaryButton", _box(Palette.GOLD.darkened(0.2), Palette.GOLD, 0))
	theme.set_stylebox("disabled", "PrimaryButton", _box(Palette.GOLD_DIM, Palette.GOLD_DIM, 0))

	# SecondaryButton — outlined cyan: "Store", "Intel", "Progress"
	_variation(theme, "SecondaryButton", "Button")
	theme.set_font("font", "SecondaryButton", display_font)
	theme.set_font_size("font_size", "SecondaryButton", 24)
	theme.set_color("font_color", "SecondaryButton", Palette.TEXT_PRIMARY)
	theme.set_stylebox("normal", "SecondaryButton", _box(Palette.BG_PANEL, Palette.CYAN_DIM, 2))
	theme.set_stylebox("hover", "SecondaryButton", _box(Palette.BG_PANEL, Palette.CYAN, 2))
	theme.set_stylebox("pressed", "SecondaryButton", _box(Palette.BG_PANEL_ALT, Palette.CYAN, 2))


func _build_panels(theme: Theme) -> void:
	# PanelCard — dark navy fill, cyan border
	_variation(theme, "PanelCard", "PanelContainer")
	theme.set_stylebox("panel", "PanelCard", _box(Palette.BG_PANEL, Palette.CYAN, 2))

	# PanelCardGold — codex card, currency pills
	_variation(theme, "PanelCardGold", "PanelContainer")
	theme.set_stylebox("panel", "PanelCardGold", _box(Palette.BG_PANEL_ALT, Palette.GOLD, 2))

	# PanelFlat — no border, for grouping
	_variation(theme, "PanelFlat", "PanelContainer")
	theme.set_stylebox("panel", "PanelFlat", _box(Palette.BG_PANEL, Palette.BG_PANEL, 0))

	# AlertHeader — the red "Security Alert" bar
	_variation(theme, "AlertHeader", "PanelContainer")
	var alert := _box(Palette.RED_DEEP, Palette.RED, 0)
	alert.border_width_bottom = 3
	alert.border_color = Palette.RED
	theme.set_stylebox("panel", "AlertHeader", alert)


func _build_inputs(theme: Theme, body_font: Font) -> void:
	theme.set_font("font", "LineEdit", body_font)
	theme.set_font_size("font_size", "LineEdit", 22)
	theme.set_color("font_color", "LineEdit", Palette.FIELD_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Palette.FIELD_PLACEHOLDER)
	theme.set_color("caret_color", "LineEdit", Palette.FIELD_TEXT)

	var field := _box(Palette.FIELD_BG, Palette.FIELD_BG, 0)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 12
	field.content_margin_bottom = 12
	theme.set_stylebox("normal", "LineEdit", field)

	var focused := field.duplicate()
	focused.border_width_bottom = 3
	focused.border_color = Palette.CYAN
	theme.set_stylebox("focus", "LineEdit", focused)


func _build_progress(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _box(Palette.BG_PANEL_ALT, Palette.BG_PANEL_ALT, 0, 4))
	theme.set_stylebox("fill", "ProgressBar", _box(Palette.GOLD, Palette.GOLD, 0, 4))

	_variation(theme, "CyanProgress", "ProgressBar")
	theme.set_stylebox("background", "CyanProgress", _box(Palette.BG_PANEL_ALT, Palette.BG_PANEL_ALT, 0, 4))
	theme.set_stylebox("fill", "CyanProgress", _box(Palette.CYAN, Palette.CYAN, 0, 4))


# --- helpers -----------------------------------------------------------------

func _variation(theme: Theme, name: String, base: String) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, base)


func _box(fill: Color, border: Color, border_width: int, radius: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Font missing at %s — falling back to the engine default." % path)
	return ThemeDB.fallback_font
