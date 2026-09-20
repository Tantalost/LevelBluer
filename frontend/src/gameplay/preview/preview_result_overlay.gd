extends "res://src/ui/screens/victory/base_defeat_overlay.gd"
## Reuses the original full reveal, tint, impact, typography and button animation.
## Only the copy and allowed actions differ; this screen has no account effects.
const BODY_FONT = preload("res://assets/fonts/DigitalDisco.ttf")

func configure(data: Dictionary) -> void:
	super.configure(data)
	_stage.text = "STAGE 01 / GAMEPLAY PREVIEW"
	_reward_title.text = "NOTHING SAVED"
	_credits.text = "BASE INTEGRITY  %d / 5" % int(data.get("health", 0))
	_wave.text = "WAVES COMPLETED  %d / %d" % [data.get("completed", 0), data.get("waves", 3)]
	_kills.text = "ANSWERS CORRECT  %d / %d" % [data.get("correct", 0), data.get("answered", 0)]
	_advisory.text = "Mastery, credits and progression are unchanged."
	_buttons[0].text = "RETRY PREVIEW"
	_buttons[1].text = "RETURN TO STAGE SELECT"
	_buttons[2].hide()
	_buttons[3].hide()
	_button_actions = [&"restart", &"back"]
	_layout()

func _layout() -> void:
	super._layout()
	var scale_y := maxf(0.1, get_viewport().get_final_transform().get_scale().y)
	var readable := maxf(26, ceilf(16 / scale_y))
	for label in [_stage, _reward_title, _credits, _wave, _kills, _advisory]:
		label.add_theme_font_override("font", BODY_FONT)
		label.add_theme_font_size_override("font_size", int(readable))
		label.size.y = maxf(label.size.y, readable * 1.4)
	var area := _root.size
	var height := maxf(64, ceilf(48 / scale_y))
	for i in 2:
		_buttons[i].add_theme_font_override("font", BODY_FONT)
		_buttons[i].add_theme_font_size_override("font_size", int(readable))
		_buttons[i].size = Vector2(minf(area.x * 0.38, 440), height)
		_buttons[i].position = Vector2(area.x * 0.5 + (12 if i == 1 else -12 - _buttons[i].size.x), area.y - height - 32)
	_skip.size = Vector2(150, height)
	_skip.position = Vector2(area.x - 170, 12)
	_skip.add_theme_font_override("font", BODY_FONT)
	_skip.add_theme_font_size_override("font_size", int(readable))
