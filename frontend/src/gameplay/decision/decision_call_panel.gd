extends HBoxContainer
## Reusable "phone call in progress" presentation for decision-story scenes
## (see DecisionScenarios.has_call). Purely data-driven — any module/stage
## can enable it via an authored "call" block on a threat; no per-stage
## branching lives here or in the caller. Mute/speaker are local, cosmetic
## toggles with no gameplay effect at all, so they need no signal out. Ending
## the call is the one interaction that affects the surrounding scene, so it
## is the only one exposed as a signal.
signal end_call_requested

const UI = preload("res://src/ui/screens/intel/study_ui.gd")

var _caller_label: Label
var _number_label: Label
var _status_label: Label
var _duration_label: Label
var _mute_button: Button
var _speaker_button: Button
var _end_button: Button
var _muted := false
var _speaker_on := false
var _ended := false
var _show_duration := true


func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_SHRINK_BEGIN
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.box(Color("152630"), Color("3b626a"), 8))
	add_child(card)
	var info := UI.column(card, 2)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	info.add_child(title_row)
	_caller_label = UI.label("", 20, UI.TEAL)
	_caller_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_caller_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_caller_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caller_label.clip_text = true
	title_row.add_child(_caller_label)
	_duration_label = UI.label("00:00", 20, UI.GOLD)
	_duration_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(_duration_label)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 10)
	info.add_child(detail_row)
	_number_label = UI.label("", 18, UI.MUTED)
	_number_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_row.add_child(_number_label)
	_status_label = UI.label("", 18, UI.MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_row.add_child(_status_label)
	var controls := HFlowContainer.new()
	controls.alignment = FlowContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("h_separation", 10)
	controls.add_theme_constant_override("v_separation", 6)
	info.add_child(controls)
	_mute_button = UI.button("MUTE", _toggle_mute)
	_mute_button.add_theme_font_size_override("font_size", 18)
	_mute_button.custom_minimum_size = Vector2(88, 40)
	_mute_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_mute_button.size_flags_vertical = SIZE_SHRINK_CENTER
	controls.add_child(_mute_button)
	_speaker_button = UI.button("SPEAKER", _toggle_speaker)
	_speaker_button.add_theme_font_size_override("font_size", 18)
	_speaker_button.custom_minimum_size = Vector2(120, 40)
	_speaker_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speaker_button.size_flags_vertical = SIZE_SHRINK_CENTER
	controls.add_child(_speaker_button)
	_end_button = UI.button("END CALL", _request_end_call)
	_end_button.add_theme_font_size_override("font_size", 18)
	_end_button.custom_minimum_size = Vector2(110, 40)
	_end_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_end_button.size_flags_vertical = SIZE_SHRINK_CENTER
	controls.add_child(_end_button)


## Resets every bit of local, presentation-only state (mute/speaker/ended/
## duration) — every threat with an enabled call starts a brand-new one,
## never carrying over a previous incident's muted/ended state.
func configure(call_data: Dictionary) -> void:
	_muted = false
	_speaker_on = false
	_ended = false
	_show_duration = bool(call_data.get("show_duration", true))
	_caller_label.text = str(call_data.get("caller", "UNKNOWN CALLER")).strip_edges().to_upper()
	var number: String = str(call_data.get("number", "")).strip_edges()
	_number_label.text = number if not number.is_empty() else "UNKNOWN NUMBER"
	var status: String = str(call_data.get("status", "")).strip_edges().to_upper()
	_status_label.text = status if not status.is_empty() else "CONNECTED"
	_duration_label.visible = _show_duration
	_duration_label.text = "00:00"
	_update_mute_button()
	_update_speaker_button()
	_end_button.visible = bool(call_data.get("allow_end_call", false))
	_end_button.disabled = false


## Presentation only — a separate clock from the decision countdown (see
## stage_one_live.gd's call_duration_elapsed vs. decision_seconds_left).
## Counts up, never down, and never affects any outcome.
func update_duration(elapsed_seconds: float) -> void:
	if _ended or not _show_duration:
		return
	var whole: int = maxi(0, floori(elapsed_seconds))
	_duration_label.text = "%02d:%02d" % [whole / 60, whole % 60]


## Ending a call and deciding what to do next are separate concepts — this
## only stops the presentation's own clock and marks it ENDED in text; it
## never grades anything or picks a choice.
func set_ended() -> void:
	_ended = true
	_status_label.text = "ENDED"
	_end_button.disabled = true


func is_muted() -> bool:
	return _muted


func is_speaker_on() -> bool:
	return _speaker_on


func _toggle_mute() -> void:
	_muted = not _muted
	_update_mute_button()


func _toggle_speaker() -> void:
	_speaker_on = not _speaker_on
	_update_speaker_button()


func _update_mute_button() -> void:
	_mute_button.text = "MUTE: ON" if _muted else "MUTE: OFF"


func _update_speaker_button() -> void:
	_speaker_button.text = "SPEAKER: ON" if _speaker_on else "SPEAKER: OFF"


func _request_end_call() -> void:
	if _ended or _end_button.disabled:
		return
	end_call_requested.emit()
