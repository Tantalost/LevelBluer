extends BaseScreen
## Chapter 1 presentation and transitions. Phone reports intents, never saves.
const UI: GDScript = preload("res://src/ui/screens/intel/study_ui.gd")
const Chapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const Phone: GDScript = preload("res://src/gameplay/decision/survey_phone.gd")
const Practice: GDScript = preload("res://src/gameplay/decision/tutorial_phone.gd")
var state: Dictionary = {}
var replay: bool = false
var _active: bool = false
var _paused: bool = false
var _backgrounded: bool = false
var _suspended: bool = false
var _sending: bool = false
var _testing: bool = false
var _owner: String = ""
var _signed_owner: bool = false
var _bg: TextureRect
var _portrait: TextureRect
var _cast_stage: Control
var _cast: Dictionary[String, TextureRect] = {}
var _poses: Dictionary[String, int] = {"john":0, "eric":0, "jobert":0}
var _focus: Tween
var _chat_started: bool = false
var _chat_speaker: String = "john"
var _resume_chat: bool = false
var _chat_cue: float = -1.0
var _area: Control
var _header: HBoxContainer
var _heading: Label
var _phone: Control
var _journal: PanelContainer
var _journal_body: VBoxContainer
var _app_shortcuts: HBoxContainer
var _dialogue: PanelContainer
var _speaker: Label
var _line: RichTextLabel
var _advance_button: Button
var _menu: PanelContainer
var _seal: Practice.SealArt
var _typing: Tween
var _motion: Tween
var _seq: int = 0
var _sentences: PackedStringArray = []
var _sentence: int = 0
var _reveal: InvestigationReveal
var _reveal_tween: Tween
var _revealing: bool = false
var _resume_reveal: bool = false
var _results: ChapterCelebration
var _result_actions: HBoxContainer
var _result_secondary: HBoxContainer
var _result_tween: Tween
var _result_audio: AudioStreamPlayer
var _celebrate_pending: bool = false

## A vector-only title treatment: no downloaded artwork or extra scene manager.
class InvestigationReveal extends Control:
	const FONT: Font = preload("res://assets/fonts/DigitalDisco.ttf")
	var gentle: bool = false
	var elapsed: float = 0.0:
		set(value):
			elapsed = value
			queue_redraw()

	func _text(value: String, center: Vector2, pixels: int, color: Color) -> void:
		var width: float = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
		var origin: Vector2 = center + Vector2(-width * 0.5, FONT.get_ascent(pixels) * 0.36)
		draw_string_outline(FONT, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 6, Color("050B18", color.a))
		draw_string(FONT, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

	func _draw() -> void:
		var fade: float = smoothstep(0.0, 0.35, elapsed) * (1.0 - smoothstep(3.55, 4.0, elapsed))
		var unit: float = minf(size.x / 1280.0, size.y / 720.0)
		var center: Vector2 = size * 0.5
		var arrive: float = smoothstep(0.5, 1.02, elapsed)
		var depart: float = smoothstep(3.35, 3.95, elapsed)
		var offset: float = 0.0 if gentle else (1.0 - arrive + depart) * 160 * unit
		draw_rect(Rect2(Vector2.ZERO, size), Color("050B18", fade * 0.3))
		# Broken orbital traces and a layered glass dossier, not full-width bars.
		var radius: float = 218 * unit
		for ring: int in 3:
			var turn: float = 0.0 if gentle else elapsed * (0.10 if ring % 2 == 0 else -0.08)
			draw_arc(center, radius + ring * 16 * unit, turn + 0.15, turn + 2.5, 64, Color("4FE0D4", fade * 0.18), 2 * unit, true)
			draw_arc(center, radius + ring * 16 * unit, turn + PI, turn + 5.6, 64, Color("FFB648", fade * 0.14), unit, true)
		var box: Rect2 = Rect2(center - Vector2(520, 128) * unit + Vector2(offset, 0), Vector2(1040, 256) * unit)
		_plate(box.grow(16 * unit), Color("102040", fade * 0.32), Color("4FE0D4", fade * 0.16), 32 * unit)
		_plate(box, Color("050B18", fade * 0.84), Color("4FE0D4", fade * 0.62), 26 * unit)
		for row: int in 14:
			var y: float = box.position.y + 14 * unit + row * 17 * unit
			draw_line(Vector2(box.position.x + 28 * unit, y), Vector2(box.end.x - 28 * unit, y), Color("8FF0E6", fade * 0.035), unit)
		_brackets(box.grow(8 * unit), 24 * unit, Color("4FE0D4", fade), 3 * unit)
		for side: float in [-1.0, 1.0]:
			for tick: int in 5:
				var p: Vector2 = center + Vector2(side * (405 + tick * 12), 72) * unit
				draw_line(p, p + Vector2(8, -16) * unit, Color("FFB648", fade * 0.7), 3 * unit)
		var title_alpha: float = smoothstep(0.72, 1.02, elapsed) * fade
		var pop: float = 1.0 if gentle else lerpf(1.1, 1.0, arrive)
		var title_center: Vector2 = center + Vector2(-offset, -28 * unit)
		_text("INVESTIGATION", title_center + Vector2(0, 4 * unit), maxi(16, int(90 * unit * pop)), Color("2E6BFF", title_alpha * 0.45))
		_text("INVESTIGATION", title_center, maxi(16, int(90 * unit * pop)), Color("F3ECD6", title_alpha))
		_text("M O D E", center + Vector2(0, 57 * unit), maxi(14, int(37 * unit)), Color("4FE0D4", smoothstep(1.0, 1.3, elapsed) * fade))
		_text("[  CASE 01  /  THE SURVEY  ]", center + Vector2(0, -174 * unit), maxi(12, int(24 * unit)), Color("8FF0E6", fade))
		_text("Every message leaves a trace.", center + Vector2(0, 175 * unit), maxi(14, int(30 * unit)), Color("F3ECD6", smoothstep(1.35, 1.7, elapsed) * fade))
		var rail: Rect2 = Rect2(center + Vector2(-100, 214) * unit, Vector2(200, 3) * unit)
		draw_rect(rail, Color("173058", fade))
		rail.size.x *= smoothstep(0.5, 3.3, elapsed)
		draw_rect(rail, Color("4FE0D4", fade))
		if not gentle:
			var sweep: float = fmod(elapsed * 0.42, 1.0)
			var x: float = lerpf(box.position.x + 30 * unit, box.end.x - 30 * unit, sweep)
			draw_line(Vector2(x, box.position.y + 15 * unit), Vector2(x, box.end.y - 15 * unit), Color("8FF0E6", sin(sweep * PI) * fade * 0.18), 3 * unit)

	func _plate(rect: Rect2, fill: Color, edge: Color, cut: float) -> void:
		var points: PackedVector2Array = PackedVector2Array([rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y), rect.end - Vector2(0, cut), rect.end - Vector2(cut, 0), Vector2(rect.position.x, rect.end.y), rect.position + Vector2(0, cut)])
		draw_colored_polygon(points, fill)
		points.append(points[0])
		draw_polyline(points, edge, 1.5, true)

	func _brackets(rect: Rect2, length: float, color: Color, weight: float) -> void:
		for corner: Vector2 in [Vector2.ZERO, Vector2(1,0), Vector2.ONE, Vector2(0,1)]:
			var p: Vector2 = rect.position + rect.size * corner
			var direction: Vector2 = Vector2.ONE - corner * 2
			draw_polyline(PackedVector2Array([p + Vector2(direction.x * length, 0), p, p + Vector2(0, direction.y * length)]), color, weight, true)

class ChapterCelebration extends InvestigationReveal:
	var award: int = 0
	var balance: int = 0
	var replaying: bool = false
	var action_space: float = 130.0
	var shown_award: int = 0
	var shown_balance: int = 0

	func _readable(pixels: float, minimum: float = 14.0) -> int:
		var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
		return ceili(maxf(pixels, minimum / physical))

	func _draw() -> void:
		var unit: float = minf(size.x / 1000.0, (size.y - action_space) / 355.0)
		var center: Vector2 = Vector2(size.x * 0.5, 0)
		var ink: StyleBoxFlat = StyleBoxFlat.new()
		ink.bg_color = Color("050B18", 0.94)
		ink.border_color = Color("4FE0D4", 0.65)
		ink.set_border_width_all(2)
		ink.set_corner_radius_all(24)
		ink.shadow_color = Color("050B18", 0.65)
		ink.shadow_size = 18
		draw_style_box(ink, Rect2(Vector2.ZERO, size))
		_brackets(Rect2(Vector2(10,10), size - Vector2(20,20)), 25 * unit, Color("FFB648", 0.7), 2)
		var alpha: float = smoothstep(0.0, 0.55, elapsed)
		var lift: float = 0.0 if gentle else (1.0 - smoothstep(0.0, 0.65, elapsed)) * 18 * unit
		_text("CASE 01  /  THE SURVEY", center + Vector2(0, 36 * unit), _readable(20 * unit, 12), Color("8FF0E6", alpha))
		_text("CHAPTER COMPLETE", center + Vector2(0, 92 * unit + lift), _readable(64 * unit, 30), Color("F3ECD6", alpha))
		var seal_center: Vector2 = center + Vector2(0, 153 * unit)
		draw_circle(seal_center - Vector2(110 * unit, 0), 16 * unit, Color("153B37"))
		draw_polyline(PackedVector2Array([seal_center + Vector2(-118,-1) * unit, seal_center + Vector2(-112,5) * unit, seal_center + Vector2(-102,-7) * unit]), Color("4FE0D4"), 3 * unit, true)
		_text("EXHIBIT SEALED", seal_center + Vector2(18 * unit,0), _readable(28 * unit), Color("4FE0D4", alpha))
		var progress: float = 1.0 if gentle else smoothstep(0.75, 2.8, elapsed)
		shown_award = roundi(award * progress)
		shown_balance = balance - award + shown_award
		var reward: Rect2 = Rect2(center + Vector2(-190, 193) * unit, Vector2(380, 104) * unit)
		_plate(reward, Color("153B37", 0.8), Color("FFB648", 0.45), 12 * unit)
		_text("+%d" % shown_award, center + Vector2(0, 236 * unit), _readable(65 * unit, 34), Color("FFB648"))
		_text("CREDITS EARNED" if not replaying else "REPLAY / NO REWARD", center + Vector2(0, 278 * unit), _readable(19 * unit, 12), Color("F3ECD6"))
		_text("03", center + Vector2(-330, 225) * unit, _readable(46 * unit, 24), Color("8FF0E6"))
		_text("EVIDENCE BUNDLES", center + Vector2(-330, 265) * unit, _readable(17 * unit, 12), Color("F3ECD6"))
		_text(str(shown_balance), center + Vector2(330, 225) * unit, _readable(46 * unit, 24), Color("FFB648"))
		_text("WALLET BALANCE", center + Vector2(330, 265) * unit, _readable(17 * unit, 12), Color("F3ECD6"))
		var detail: String = "Replay complete. Your original rewards are unchanged." if replaying else "%d completion  +  %d clean-work bonus" % [Chapter.BASE_REWARD, maxi(0, award - Chapter.BASE_REWARD)]
		_text(detail, center + Vector2(0, 331 * unit), _readable(22 * unit), Color("8FF0E6"))
		if not gentle and not replaying:
			for coin: int in 5:
				var flight: float = (elapsed - 0.8 - coin * 0.22) / 0.85
				if flight > 0.0 and flight < 1.0:
					var point: Vector2 = center + Vector2(lerpf(130, 330, flight), 205 - sin(flight * PI) * 54) * unit
					draw_circle(point, 9 * unit, Color("FFB648"))
					draw_circle(point, 5 * unit, Color("F3ECD6"), false, 1.5 * unit)
		if not gentle and elapsed < 5.5:
			for i: int in 40:
				var time: float = maxf(0.0, elapsed - 0.3 - (i % 5) * 0.06)
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var origin: Vector2 = Vector2(size.x * 0.5 + side * (size.x * 0.34 + time * (20 + i % 7 * 11)), 25 + time * (22 + i % 9 * 8) + time * time * 8)
				var tint: Color = Color("FFB648") if i % 3 == 0 else Color("4FE0D4")
				tint.a = (1.0 - smoothstep(3.8, 5.5, elapsed)) * 0.8
				if Rect2(Vector2(8,8), size - Vector2(16,16)).has_point(origin):
					draw_set_transform(origin, time * side + i)
					draw_rect(Rect2(Vector2.ZERO, Vector2(5, 10) * maxf(unit, 0.7)), tint)
			draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var fallback: ColorRect = ColorRect.new()
	fallback.color = Color("173058")
	fallback.mouse_filter = MOUSE_FILTER_IGNORE
	fallback.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fallback)
	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_bg)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	safe.extra_margin = 14
	add_child(safe)
	_area = Control.new()
	safe.add_child(_area)
	_cast_stage = Control.new()
	_cast_stage.mouse_filter = MOUSE_FILTER_IGNORE
	_cast_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_area.add_child(_cast_stage)
	for person: String in ["john", "eric", "jobert"]:
		var actor: TextureRect = TextureRect.new()
		actor.name = person.capitalize()
		actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		actor.mouse_filter = MOUSE_FILTER_IGNORE
		_cast_stage.add_child(actor)
		_cast[person] = actor
	_portrait = _cast["john"]
	_phone = Phone.new()
	_area.add_child(_phone)
	_phone.evidence_changed.connect(_evidence_changed)
	_phone.thought_requested.connect(_thought)
	_phone.phase_finished.connect(_phase_finished)
	_phone.chat_speaker_changed.connect(_chat_focus)
	_phone.view_changed.connect(_refresh_app_shortcuts)
	_journal = UI.panel(_area, Color("0A1730", 0.92))
	var journal_style: StyleBoxFlat = UI.box(Color("0A1730", 0.90), Color("173058"), 20)
	journal_style.set_corner_radius_all(18)
	journal_style.border_width_left = 4
	journal_style.border_color = Color("4FE0D4", 0.65)
	_journal.add_theme_stylebox_override("panel", journal_style)
	_journal_body = UI.scroll_column(_journal)
	_app_shortcuts = HBoxContainer.new()
	_app_shortcuts.add_theme_constant_override("separation", 12)
	_area.add_child(_app_shortcuts)
	_app_shortcuts.add_child(_button("MAIL", func() -> void: _phone._open_mail()))
	_app_shortcuts.add_child(_button("NOTEPAD", func() -> void: _phone._open_notes()))
	_app_shortcuts.add_child(_button("CAPTURE", func() -> void: _phone.take_photo()))
	_app_shortcuts.add_child(_button("INBOX", func() -> void: _phone._inbox()))
	_dialogue = UI.panel(_area, Color("050B18", 0.82))
	var box: StyleBoxFlat = UI.box(Color("050B18", 0.86), Color("173058"), 24)
	box.set_corner_radius_all(22)
	_dialogue.add_theme_stylebox_override("panel", box)
	var dialogue_body: VBoxContainer = UI.column(_dialogue, 10)
	_speaker = UI.label("John", 24, Color("4FE0D4"))
	_speaker.add_theme_color_override("font_color", Color("101623"))
	var speaker_style: StyleBoxFlat = UI.box(Color("4FE0D4"), Color("4FE0D4"), 8)
	speaker_style.set_corner_radius_all(10)
	_speaker.add_theme_stylebox_override("normal", speaker_style)
	_speaker.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_speaker.autowrap_mode = TextServer.AUTOWRAP_OFF
	dialogue_body.add_child(_speaker)
	var row: HBoxContainer = HBoxContainer.new()
	dialogue_body.add_child(row)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	_line = RichTextLabel.new()
	_line.add_theme_font_override("normal_font", UI.FONT)
	_line.add_theme_color_override("default_color", Color("F3ECD6"))
	_line.size_flags_horizontal = SIZE_EXPAND_FILL
	_line.size_flags_vertical = SIZE_EXPAND_FILL
	_line.add_theme_constant_override("line_separation", 6)
	row.add_child(_line)
	_advance_button = _button("›", _advance)
	_advance_button.size_flags_vertical = SIZE_SHRINK_END
	_advance_button.tooltip_text = "Reveal this sentence / next sentence"
	_advance_button.accessibility_name = "Continue dialogue"
	row.add_child(_advance_button)
	_header = HBoxContainer.new()
	_results = ChapterCelebration.new()
	_results.name = "ChapterCelebration"
	_results.mouse_filter = MOUSE_FILTER_IGNORE
	_results.hide()
	_area.add_child(_results)
	_result_actions = HBoxContainer.new()
	_result_actions.add_theme_constant_override("separation", 16)
	_results.add_child(_result_actions)
	var next_chapter: Button = _button("NEXT CHAPTER\nComing soon", func() -> void: pass)
	next_chapter.name = "NextChapter"
	next_chapter.disabled = true
	next_chapter.tooltip_text = "Chapter 2 access earned. Its story is not available yet."
	next_chapter.add_theme_color_override("font_disabled_color", Color("F3ECD6", 0.65))
	var unavailable: StyleBoxFlat = UI.box(Color("173058", 0.7), Color("173058"), 10)
	unavailable.set_corner_radius_all(16)
	next_chapter.add_theme_stylebox_override("disabled", unavailable)
	_result_actions.add_child(next_chapter)
	var upgrades: Button = _button("UPGRADES", _open_upgrades)
	upgrades.name = "Upgrades"
	var primary: StyleBoxFlat = UI.box(Color("2E6BFF"), Color("8FF0E6"), 10)
	primary.set_corner_radius_all(16)
	upgrades.add_theme_stylebox_override("normal", primary)
	_result_actions.add_child(upgrades)
	_result_secondary = HBoxContainer.new()
	_result_secondary.add_theme_constant_override("separation", 12)
	_results.add_child(_result_secondary)
	_result_secondary.add_child(_button("MODULES", _leave))
	_result_secondary.add_child(_button("REPLAY", _replay))
	_result_audio = AudioStreamPlayer.new()
	_result_audio.bus = &"Master"
	_result_audio.stream = load("res://assets/audio/bgm/chapter_complete.wav") as AudioStreamWAV
	add_child(_result_audio)
	_result_audio.finished.connect(func() -> void: AudioManager.set_story_duck(self, 1.0))
	_reveal = InvestigationReveal.new()
	_reveal.name = "InvestigationReveal"
	_reveal.mouse_filter = MOUSE_FILTER_IGNORE
	_reveal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_reveal.hide()
	_area.add_child(_reveal)
	_header.add_theme_constant_override("separation", 14)
	_area.add_child(_header)
	_header.add_child(_button("BACK", _leave))
	_heading = UI.label("CHAPTER 1 / THE SURVEY", 22, Color("F3ECD6"))
	_heading.add_theme_color_override("font_outline_color", Color("050B18"))
	_heading.add_theme_constant_override("outline_size", 4)
	_heading.size_flags_horizontal = SIZE_EXPAND_FILL
	_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_heading)
	_header.add_child(_button("MENU", _toggle_menu))
	_menu = UI.panel(_area, Color("0A1730"))
	var menu_body: VBoxContainer = UI.column(_menu)
	menu_body.add_child(UI.label("CHAPTER PAUSED", 26, Color("4FE0D4")))
	menu_body.add_child(_button("RESUME", _toggle_menu))
	menu_body.add_child(_button("SETTINGS", _settings))
	menu_body.add_child(_button("SAVE & RETURN TO MODULES", _leave))
	_menu.hide()
	_area.resized.connect(_layout)
	AssetManager.sync_finished.connect(_art_ready)
	SettingsService.settings_changed.connect(_settings_changed)
	AuthService.session_changed.connect(_session_changed)

func _button(caption: String, callback: Callable) -> Button:
	var button: Button = UI.button(caption, callback)
	var style: StyleBoxFlat = UI.box(Color("0A1730",0.95), Color("4FE0D4"), 12)
	style.set_corner_radius_all(22)
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("153B37")
	var pressed: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("2E6BFF")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_hover_color", Color("F3ECD6"))
	button.add_theme_color_override("font_pressed_color", Color("F3ECD6"))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func on_enter(args: Dictionary) -> void:
	_resume_reveal = false
	_celebrate_pending = false
	_testing = bool(args.get("test", false))
	_owner = AuthService.participant_code()
	_signed_owner = AuthService.is_signed_in()
	replay = bool(args.get("replay", false))
	state = Chapter.fresh() if replay else Chapter.clean(PlayerManager.chapter_progress.get(Chapter.ID, {}))
	_active = true
	_paused = false
	_menu.hide()
	show()
	_render()

func _render() -> void:
	_seq += 1
	_stop_tweens()
	_results.hide()
	UI.clear(_journal_body)
	_seal = null
	_phone.stop()
	_phone.hide()
	_chat_started = false
	_chat_cue = -1.0
	_poses = {"john":0, "eric":0, "jobert":0}
	if state["phase"] == "day":
		for index: int in range(int(state["beat"]) + 1):
			var previous: Dictionary = Chapter.STORY[index]
			_poses[str(previous["who"]).to_lower()] = int(previous.get("face", 0))
	_journal.hide()
	_portrait.show()
	_dialogue.show()
	_sending = false
	_speaker.text = "John · Thinking"
	var phase: String = str(state["phase"])
	_app_shortcuts.visible = phase in ["notes", "capture"]
	for index: int in _app_shortcuts.get_child_count():
		(_app_shortcuts.get_child(index) as Control).visible = (index < 2 and phase == "notes") or (index >= 2 and phase == "capture")
	var night: bool = phase != "day" or Chapter.STORY[int(state["beat"])].get("time", "day") == "night"
	_heading.text = "CHAPTER 1 / " + ("NIGHT" if night else "DAY") + (" / REPLAY" if replay else "")
	if phase == "day":
		var beat: Dictionary = Chapter.STORY[int(state["beat"])]
		_speaker.text = str(beat["who"])
		_set_line(str(beat["line"]))
		if bool(beat.get("mail", false)):
			_phone.configure_chapter("read", state)
	elif phase in ["sort", "highlight", "notes", "capture"]:
		_portrait.hide()
		_journal.show()
		var titles: Dictionary = {"sort":"01 / Sort the inbox", "highlight":"02 / Read between the lines", "notes":"03 / Trace the senders", "capture":"04 / Keep the context"}
		var tips: Dictionary = {"sort":"Open a message, then drag or tap to sort.", "highlight":"Tap the request that feels wrong.", "notes":"Check Mail → record the domain in Notepad.", "capture":"Frame the sender, subject and request."}
		_journal.tooltip_text = str(tips[phase])
		var progress_row: HBoxContainer = HBoxContainer.new()
		_journal_body.add_child(progress_row)
		var task_text: VBoxContainer = UI.column(progress_row, 4)
		task_text.size_flags_horizontal = SIZE_EXPAND_FILL
		var task_title: Label = UI.label(str(titles[phase]), 24, Color("4FE0D4"))
		task_title.set_meta("task_title", true)
		task_text.add_child(task_title)
		var summary: Label = UI.label(_evidence_summary(), 22, Color("F3ECD6"))
		summary.name = "EvidenceSummary"
		summary.size_flags_horizontal = SIZE_EXPAND_FILL
		task_text.add_child(summary)
		var hint: Button = _button("Hint", _hint)
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		progress_row.add_child(hint)
		_phone.configure_chapter(phase, state)
		_set_line({"sort":"Six messages. Which ones deserve another look?", "highlight":"Something about these requests feels off.", "notes":"Alright, what else feels wrong? Who actually sent these?", "capture":"I'd better keep a copy. The sender, the subject, the whole request."}[phase])
	elif phase == "seal":
		_journal.show()
		_journal_body.add_child(UI.label("EXHIBIT 01 / THE SURVEY", 28, Color("4FE0D4")))
		_journal_body.add_child(UI.label("3 evidence bundles\n\n01 · Three message captures\n02 · Sender-domain notes\n03 · Payment, pressure and personal-data clues", 24))
		_journal_body.add_child(UI.label("A typo or free mailbox alone is not proof. Keep each clue connected to the request it came from.", 22))
		for id: String in Chapter.suspicious_ids():
			_journal_body.add_child(_button("REVIEW / " + str(Chapter.message(id)["subject"]), _review_capture.bind(id)))
		_seal = Practice.SealArt.new()
		_journal_body.add_child(_seal)
		_journal_body.add_child(_button("SEAL EXHIBIT", _seal_exhibit))
		_set_line("I still don't know who the client is. But now I have something more useful than a feeling.")
	elif phase == "sleep":
		_set_line("I put my phone down. Eric said he knew the client. Tomorrow, I'll ask him again.\n\nFor now, I need some sleep.")
	else:
		_show_results()
	_load_art()
	_layout()
	if not SettingsService.reduced_motion:
		_motion = create_tween().set_parallel(true)
		_motion.finished.connect(func() -> void: _motion = null)
		for control: Control in [_dialogue, _journal, _phone]:
			control.modulate.a = 0.0
			_motion.tween_property(control, "modulate:a", 1.0, 0.22)
	else:
		for control: Control in [_dialogue, _journal, _phone]: control.modulate.a = 1.0
	_apply_pause()

func _review_capture(id: String) -> void:
	if not _can_act() or _sending or not state["captures"].has(id): return
	var panel: PanelContainer = _journal_body.get_node_or_null("CaptureReview") as PanelContainer
	if panel != null:
		_journal_body.remove_child(panel)
		panel.queue_free()
	panel = UI.panel(_journal_body, Color("F3ECD6"))
	panel.name = "CaptureReview"
	var contents: VBoxContainer = UI.column(panel, 8)
	var entry: Dictionary = Chapter.message(id)
	contents.add_child(UI.label("SAVED CAPTURE / " + str(entry["address"]), 24, Color("101623")))
	var texture: Texture2D = _phone._previews.get(id)
	if texture != null:
		var photo: TextureRect = TextureRect.new()
		photo.texture = texture
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size.y = 250
		contents.add_child(photo)
	else:
		contents.add_child(UI.label(str(entry["subject"]) + "\n\n" + str(entry["phrase"]), 24, Color("101623")))
	_layout()
	(_journal_body.get_parent() as ScrollContainer).ensure_control_visible.call_deferred(panel)

func _show_results() -> void:
	_journal.hide()
	_portrait.hide()
	_dialogue.hide()
	_heading.text = "CHAPTER 1 / COMPLETE"
	_results.award = 0 if replay else int(state["reward"])
	_results.balance = PlayerManager.credits
	_results.replaying = replay
	_results.gentle = SettingsService.reduced_motion
	_results.accessibility_name = "Chapter complete. Three evidence bundles sealed. %d credits earned. Wallet balance %d." % [_results.award, _results.balance]
	_results.show()
	_results.elapsed = 6.0
	if _celebrate_pending:
		_celebrate_pending = false
		_results.elapsed = 0.0
		_result_tween = create_tween()
		_result_tween.finished.connect(func() -> void: _result_tween = null)
		_result_tween.tween_property(_results, "elapsed", 6.0, 6.0)
		if SettingsService.music_enabled and SettingsService.music_volume > 0 and SettingsService.master_volume > 0:
			_result_audio.volume_linear = SettingsService.music_volume / 100.0 * 0.65
			AudioManager.set_story_duck(self, 0.22)
			_result_audio.play()

func _open_upgrades() -> void:
	if not _can_act() or state.get("phase") != "done": return
	await Router.push(&"upgrades")

func _evidence_summary() -> String:
	var field: String = {"sort":"sorted", "highlight":"flags", "notes":"domains", "capture":"captures"}.get(str(state["phase"]), "captures")
	return "%d / %d collected" % [state[field].size(), 6 if field == "sorted" else 3]

func _set_line(text: String) -> void:
	# Presentation pages leave authored beat IDs (and existing saves) unchanged.
	_sentences.clear()
	_sentence = 0
	var boundary: RegEx = RegEx.new()
	boundary.compile("(?<=[.!?…])\\s+|\\n+")
	var start: int = 0
	for match_result: RegExMatch in boundary.search_all(text):
		var sentence: String = text.substr(start, match_result.get_start() - start).strip_edges()
		if not sentence.is_empty(): _sentences.append(sentence)
		start = match_result.get_end()
	var tail: String = text.substr(start).strip_edges()
	if not tail.is_empty(): _sentences.append(tail)
	if _sentences.is_empty(): _sentences.append("")
	_show_sentence()

func _show_sentence() -> void:
	if _typing != null and _typing.is_valid(): _typing.kill()
	var text: String = _sentences[_sentence]
	_line.text = text
	_line.scroll_to_line(0)
	_line.visible_characters = -1
	if SettingsService.text_speed != "instant":
		_line.visible_characters = 0
		_typing = create_tween()
		_typing.tween_property(_line, "visible_characters", text.length(), text.length() / (32.0 * SettingsService.text_speed_multiplier()))
		_typing.finished.connect(func() -> void:
			_typing = null
			_update_advance())
	_update_advance()

func _update_advance() -> void:
	var typed: bool = _line.visible_characters < 0 or _line.visible_characters >= _line.text.length()
	var last: bool = _sentence >= _sentences.size() - 1
	_advance_button.text = "›" if typed else "…"
	_advance_button.disabled = not _can_act() or _sending
	if typed and last and state.get("phase") in ["sort", "highlight", "notes", "capture", "seal"]:
		_advance_button.visible = false
	else:
		_advance_button.visible = true
	if typed and last and state.get("phase") == "day" and int(state.get("beat", 0)) == 11:
		_advance_button.disabled = state["read"].size() < 6 or not _can_act()
	if typed and last and _is_chat_beat():
		_advance_button.disabled = true
		if not _chat_started and _chat_cue < 0.0 and _can_act():
			# Let the last sentence land, including with instant text enabled.
			_chat_cue = 0.85

func _process(delta: float) -> void:
	if _chat_cue < 0.0 or not _can_act(): return
	_chat_cue -= delta
	if _chat_cue <= 0.0:
		_chat_cue = -1.0
		_chat_started = true
		_open_chat(_seq)

func _is_chat_beat() -> bool:
	return state.get("phase") == "day" and bool(Chapter.STORY[int(state.get("beat", 0))].get("chat", false))

func _open_chat(generation: int) -> void:
	if generation != _seq or not _active or not _is_chat_beat(): return
	_phone.configure_chapter("chat", state)
	_dialogue.hide()
	_chat_focus("John", 0)
	_layout()
	_apply_pause()

func _chat_focus(person: String, pose: int) -> void:
	_chat_speaker = person.to_lower()
	_poses[_chat_speaker] = pose
	_load_art()

func _advance() -> void:
	if not _can_act() or _sending:
		return
	if _line.visible_characters >= 0 and _line.visible_characters < _line.text.length():
		if _typing != null and _typing.is_valid(): _typing.kill()
		_line.visible_characters = -1
		_update_advance()
		return
	if _sentence < _sentences.size() - 1:
		_sentence += 1
		_show_sentence()
		return
	if state["phase"] == "day":
		if _is_chat_beat() and (not _chat_started or not _phone.visible or not _phone.phase_ready()): return
		if int(state["beat"]) == 11 and state["read"].size() < 6: return
		if int(state["beat"]) < Chapter.STORY.size() - 1:
			state["beat"] = int(state["beat"]) + 1
		else:
			_start_investigation_reveal()
			return
	elif state["phase"] == "sleep":
		state["completed"] = true
		state = Chapter.clean(state)
		_celebrate_pending = true
	else:
		return
	_save()
	_render()

func _evidence_changed(snapshot: Dictionary) -> void:
	if not _can_act(): return
	for field: String in ["read", "sorted", "flags", "domains", "captures", "mistakes"]:
		state[field] = snapshot[field]
	var summary: Label = _journal_body.find_child("EvidenceSummary", true, false) as Label
	if summary != null: summary.text = _evidence_summary()
	_save()
	_update_advance()

func _thought(text: String) -> void:
	if not _can_act(): return
	_speaker.text = "John · Thinking"
	_set_line(text)

func _phase_finished() -> void:
	if not _can_act() or not _phone.phase_ready(): return
	if state["phase"] == "day":
		if _is_chat_beat():
			_advance()
			return
		# Reading mail must not silently discard John's remaining thoughts.
		_update_advance()
		return
	state["phase"] = {"sort":"highlight", "highlight":"notes", "notes":"capture", "capture":"seal"}.get(str(state["phase"]), "seal")
	_save()
	_render()

func _hint() -> void:
	if not _can_act(): return
	state["hint_used"] = true
	_save()
	if state["phase"] == "capture" and is_instance_valid(_phone._camera):
		_phone._camera.frame = Rect2(0.02,0.02,0.96,0.96)
		_phone._camera._commit()
	_thought({"sort":"The three survey messages deserve a closer look. Compare their demands with the school updates you were expecting.", "highlight":"Look for unspecified pay, pressure not to verify, and unexplained requests for personal details. A typo is only supporting context.", "notes":"Read the address after @. Two survey senders use gmail.com; the coordinator uses yahoo.com. That alone does not prove a scam.", "capture":"Include the entire sender, subject and request. Framing assistance is available when a message is open."}.get(str(state["phase"]), "Keep each clue connected to its context."))

func _seal_exhibit() -> void:
	if not _can_act() or _sending or state["phase"] != "seal" or not Chapter.complete_evidence(state): return
	_sending = true
	_phone.set_locked(true)
	if _motion != null and _motion.is_valid(): _motion.kill()
	var generation: int = _seq
	_motion = create_tween()
	_motion.tween_property(_seal, "progress", 1.0, 0.05 if SettingsService.reduced_motion else 1.4)
	_motion.tween_callback(func() -> void:
		if not _active or generation != _seq: return
		state["sealed"] = true
		state["phase"] = "sleep"
		_save()
		_render())
	_update_advance()

func _save() -> void:
	if not replay and _owner == AuthService.participant_code() and _signed_owner == AuthService.is_signed_in():
		PlayerManager.save_survey_chapter(state, not _testing)

func _replay() -> void:
	if not _can_act(): return
	replay = true
	_phone._previews.clear()
	state = Chapter.fresh()
	_render()

func _load_art() -> void:
	if state.is_empty(): return
	var phase: String = str(state["phase"])
	var beat: Dictionary = Chapter.STORY[int(state["beat"])]
	var location: String = str(beat["bg"]) if phase == "day" else "john_desk_night"
	_bg.texture = AssetManager.get_texture("story_bg_" + location)
	var person: String = str(beat["who"]).to_lower() if phase == "day" else "john"
	if _chat_started and _is_chat_beat():
		# Chat senders are remote, not physical actors in John's room.
		person = "john"
	else:
		_poses[person] = int(beat.get("face", 0)) if phase == "day" else 2
	var present: Array[String] = ["john"]
	if phase == "day" and location == "hallway_day": present = ["john", "eric"]
	if phase == "day" and location == "clubroom": present = ["john", "eric", "jobert"]
	# Includes the lead-in and phone home, not only the open chat app.
	if _is_chat_beat(): present = ["john"]
	# John is already seated in the night artwork; never overlay a second John.
	_cast_stage.visible = location != "john_desk_night" and phase in ["day", "seal", "sleep"]
	for id: String in _cast:
		_cast[id].visible = present.has(id)
		_cast[id].texture = _actor_texture(id, _poses[id])
	_portrait = _cast[person]
	_cast_stage.move_child(_portrait, _cast_stage.get_child_count() - 1)
	if _focus != null and _focus.is_valid(): _focus.kill()
	_focus = create_tween().set_parallel(true)
	_focus.finished.connect(func() -> void: _focus = null)
	for id: String in _cast:
		var light: Color = Color.WHITE if id == person else Color(0.42, 0.46, 0.52, 1.0)
		if SettingsService.reduced_motion:
			_cast[id].modulate = light
		else:
			_focus.tween_property(_cast[id], "modulate", light, 0.22)
	if SettingsService.reduced_motion: _focus.kill()
	_layout()

func _actor_texture(person: String, face: int) -> Texture2D:
	var texture: Texture2D = AssetManager.get_texture("chapter1_" + person)
	if texture != null and texture.get_width() == 1536 and texture.get_height() == 1024:
		var split: int = {"john":512,"eric":524,"jobert":546}[person]
		# Whole-body acting sheets have wider lower-row gestures. Use authored
		# gutters instead of cutting a hand at an assumed 512px cell boundary.
		var columns: PackedInt32Array = PackedInt32Array([0,512,1024,1536])
		if face >= 3:
			columns = PackedInt32Array([0,528,992,1536]) if person == "john" else PackedInt32Array([0,560,992,1536])
		var column: int = face % 3
		var left: int = columns[column]
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(left, 0 if face < 3 else split, columns[column + 1] - left, split if face < 3 else 1024 - split)
		# Give every pose an identical logical canvas and horizontal anchor;
		# changing gesture must not make the character scale or jump sideways.
		atlas.margin = Rect2(Vector2(48 + left - column * 512, 0), Vector2(608,550) - atlas.region.size)
		atlas.filter_clip = true
		return atlas
	return null

func _art_ready(_success: bool) -> void:
	_load_art()

func _layout() -> void:
	if not is_instance_valid(_area): return
	var w: float = _area.size.x
	var h: float = _area.size.y
	var physical: float = maxf(0.25, get_viewport().get_final_transform().get_scale().y)
	var touch: float = maxf(48, 48 / physical)
	_header.position = Vector2.ZERO
	_header.size = Vector2(w,touch)
	var has_phone: bool = _phone.visible
	var phase: String = str(state.get("phase", "day"))
	var top: float = touch + 16
	var investigation: bool = phase in ["sort", "highlight", "notes", "capture"]
	var task_height: float = touch + 20 / physical
	var phone_top: float = top + (task_height + 10 if investigation else 0.0)
	_phone.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_phone.position = Vector2(w * 0.49, phone_top)
	_phone.size = Vector2(w * 0.51, h - phone_top)
	_phone._metrics()
	_app_shortcuts.position = Vector2(0, top)
	_app_shortcuts.size = Vector2(w * 0.46, touch)
	var actors: Array[TextureRect] = []
	# Iterate canonical names, not draw order: switching focus never moves a slot.
	for person: String in ["john", "eric", "jobert"]:
		if _cast[person].visible: actors.append(_cast[person])
	var stage_width: float = w * (0.49 if has_phone else 1.0)
	var actor_width: float = stage_width * (0.95 if actors.size() == 1 else (0.83 if has_phone else 0.68))
	var actor_height: float = minf(h - top, actor_width * 550.0 / 608.0)
	for index: int in actors.size():
		var center: float = stage_width * (float(index + 1) / float(actors.size() + 1))
		actors[index].position = Vector2(center - actor_width * 0.5, h - actor_height)
		actors[index].size = Vector2(actor_width, actor_height)
	var dialogue_height: float = maxf(h * (0.34 if has_phone else 0.27), (185.0 if has_phone else 130.0) / physical)
	_dialogue.position = Vector2(0,h - dialogue_height)
	_dialogue.size = Vector2(w * 0.47 if has_phone else w, dialogue_height)
	_journal.position = Vector2(0,top)
	_journal.size = Vector2(w * 0.44, minf(240 / physical, _dialogue.position.y - top - 16))
	var journal_style: StyleBoxFlat = _journal.get_theme_stylebox("panel") as StyleBoxFlat
	for edge: String in ["left", "right", "top", "bottom"]:
		journal_style.set("content_margin_" + edge, (10.0 / physical) if investigation else 20.0)
	if investigation:
		_journal.position = Vector2(w * 0.49, top)
		_journal.size = Vector2(w * 0.51, task_height)
	if phase in ["seal", "done"]:
		_journal.position = Vector2(w * 0.12,top)
		_journal.size = Vector2(w * 0.76,h - top - (dialogue_height + 16 if phase == "seal" else 6))
	_menu.position = Vector2(w * 0.2,h * 0.15)
	_menu.size = Vector2(w * 0.6,h * 0.70)
	for node: Node in _area.find_children("*", "Button", true, false):
		var button: Button = node as Button
		button.custom_minimum_size.y = touch
		button.add_theme_font_size_override("font_size", maxi(20, int(16 / physical)))
	for node: Node in _header.get_children():
		if node is Button:
			var button: Button = node as Button
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.custom_minimum_size.x = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + 32
	for node: Node in _app_shortcuts.get_children():
		var button: Button = node as Button
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + 32
	(_journal_body.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if investigation else ScrollContainer.SCROLL_MODE_AUTO
	for node: Node in _journal_body.find_children("*", "Label", true, false):
		(node as Label).add_theme_font_size_override("font_size", maxi(24, int(18 / physical)))
		if investigation:
			(node as Label).add_theme_font_size_override("font_size", ceili((18.0 if node.has_meta("task_title") else 14.0) / physical))
		if node.has_meta("compact_instruction"):
			(node as Label).visible = h * physical >= 500
	_line.add_theme_font_size_override("normal_font_size", maxi(32,int((24.0 if has_phone else 28.0) / physical)))
	_speaker.add_theme_font_size_override("font_size", maxi(24,int(18 / physical)))
	_heading.add_theme_font_size_override("font_size", maxi(20,int(14 / physical)))
	_advance_button.custom_minimum_size = Vector2.ONE * touch
	_advance_button.add_theme_font_size_override("font_size", ceili(28 / physical))
	_layout_results(w, h, top, physical)

func _layout_results(w: float, h: float, top: float, physical: float) -> void:
	_results.position = Vector2(w * 0.065, top + 8)
	_results.size = Vector2(w * 0.87, h - top - 16)
	var primary_height: float = 64.0 / physical
	var secondary_height: float = 44.0 / physical
	var gap: float = 10.0 / physical
	_results.action_space = primary_height + secondary_height + gap * 3
	var margin: float = 28.0 / physical
	_result_actions.position = Vector2(margin, _results.size.y - _results.action_space + gap)
	_result_actions.size = Vector2(_results.size.x - margin * 2, primary_height)
	_result_secondary.position = Vector2(_results.size.x * 0.23, _results.size.y - secondary_height - gap)
	_result_secondary.size = Vector2(_results.size.x * 0.54, secondary_height)
	for row: HBoxContainer in [_result_actions, _result_secondary]:
		for node: Node in row.get_children():
			var button: Button = node as Button
			button.size_flags_horizontal = SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.custom_minimum_size = Vector2(0, primary_height if row == _result_actions else secondary_height)
			button.add_theme_font_size_override("font_size", ceili((20.0 if row == _result_actions else 15.0) / physical))
	_results.queue_redraw()

func _can_act() -> bool:
	return not _revealing and _can_present()

func _can_present() -> bool:
	return _active and not _paused and not _backgrounded and not _suspended and _owner == AuthService.participant_code() and _signed_owner == AuthService.is_signed_in()

func _start_investigation_reveal() -> void:
	_stop_tweens()
	_revealing = true
	_reveal.gentle = SettingsService.reduced_motion
	_reveal.elapsed = 0.0
	_reveal.show()
	for control: Control in [_dialogue, _journal, _phone, _app_shortcuts]: control.hide()
	_phone.set_locked(true)
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_reveal, "elapsed", 0.55, 0.55)
	_reveal_tween.tween_callback(func() -> void: AudioManager.play_sfx("ui_transition"))
	_reveal_tween.tween_property(_reveal, "elapsed", 1.05, 0.5)
	_reveal_tween.tween_callback(func() -> void: AudioManager.play_sfx("loading_ready"))
	_reveal_tween.tween_property(_reveal, "elapsed", 4.0, 2.95)
	_reveal_tween.finished.connect(_finish_investigation_reveal)
	_apply_pause()

func _finish_investigation_reveal() -> void:
	if not _revealing or not _can_present(): return
	_revealing = false
	_reveal.hide()
	AudioManager.set_story_duck(self, 1.0)
	state["phase"] = "sort"
	_save()
	_render()

func _cancel_investigation_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid(): _reveal_tween.kill()
	_reveal_tween = null
	_revealing = false
	if is_instance_valid(_reveal): _reveal.hide()
	AudioManager.set_story_duck(self, 1.0)

func _toggle_menu() -> void:
	if not _active: return
	_paused = not _paused
	_menu.visible = _paused
	_apply_pause()

func _apply_pause() -> void:
	var locked: bool = not _can_act()
	if _result_tween != null and _result_tween.is_valid():
		if locked: _result_tween.pause()
		else: _result_tween.play()
	if is_instance_valid(_result_audio):
		_result_audio.stream_paused = locked
		if _result_audio.playing: AudioManager.set_story_duck(self, 1.0 if locked else 0.22)
	for row: HBoxContainer in [_result_actions, _result_secondary]:
		for node: Node in row.get_children():
			(node as Button).disabled = locked or node.name == "NextChapter"
	if _revealing:
		AudioManager.set_story_duck(self, 0.3 if _can_present() else 1.0)
		if _reveal_tween != null and _reveal_tween.is_valid():
			if _can_present(): _reveal_tween.play()
			else: _reveal_tween.pause()
	_refresh_app_shortcuts()
	_phone.set_locked(locked or _sending)
	for tween: Tween in [_typing,_motion,_focus]:
		if tween != null and tween.is_valid():
			if locked: tween.pause()
			else: tween.play()
	_update_advance()

func _refresh_app_shortcuts() -> void:
	if not is_instance_valid(_app_shortcuts): return
	for node: Node in _app_shortcuts.get_children():
		(node as Button).disabled = not _can_act() or _sending or ((node as Button).text == "CAPTURE" and not is_instance_valid(_phone._camera))

func _settings_changed() -> void:
	if is_instance_valid(_results):
		_results.gentle = SettingsService.reduced_motion
		_results.queue_redraw()
	if is_instance_valid(_result_audio):
		_result_audio.volume_linear = SettingsService.music_volume / 100.0 * 0.65 if SettingsService.music_enabled else 0.0
		if not SettingsService.music_enabled or SettingsService.music_volume <= 0:
			_result_audio.stop()
			AudioManager.set_story_duck(self, 1.0)
	if is_instance_valid(_reveal):
		_reveal.gentle = SettingsService.reduced_motion
		_reveal.queue_redraw()
	if SettingsService.text_speed == "instant":
		if _typing != null and _typing.is_valid(): _typing.kill()
		_line.visible_characters = -1
	if SettingsService.reduced_motion and not _sending:
		if _motion != null and _motion.is_valid(): _motion.kill()
		for control: Control in [_dialogue, _journal, _phone]: control.modulate.a = 1.0
		_load_art()
	_apply_pause()

func _settings() -> void:
	await Router.push(&"settings")

func _leave() -> void:
	if not _active: return
	_save()
	await Router.replace(&"stage_select")

func consume_back() -> bool:
	if _paused:
		_toggle_menu()
	else:
		_leave()
	return true

func _session_changed(_signed_in: bool) -> void:
	if _owner != AuthService.participant_code() or _signed_owner != AuthService.is_signed_in():
		_active = false
		_stop_tweens()
		_phone.stop()
		hide()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _backgrounded = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _backgrounded = false
		NOTIFICATION_APPLICATION_PAUSED: _suspended = true
		NOTIFICATION_APPLICATION_RESUMED: _suspended = false
		_: return
	if is_node_ready(): _apply_pause()

func _stop_tweens() -> void:
	if _result_tween != null and _result_tween.is_valid(): _result_tween.kill()
	_result_tween = null
	if is_instance_valid(_result_audio): _result_audio.stop()
	_cancel_investigation_reveal()
	for tween: Tween in [_typing,_motion,_focus]:
		if tween != null and tween.is_valid(): tween.kill()
	_typing = null
	_motion = null

func on_exit() -> void:
	_resume_reveal = _revealing
	_resume_chat = _chat_started and _phone.visible and _is_chat_beat()
	_active = false
	_seq += 1
	_stop_tweens()
	_phone.stop()
	hide()

func on_resume() -> void:
	if _owner != AuthService.participant_code() or _signed_owner != AuthService.is_signed_in(): return
	_active = true
	_paused = false
	_menu.hide()
	show()
	if _resume_reveal:
		_resume_reveal = false
		_start_investigation_reveal()
		return
	if _resume_chat:
		_phone.show()
		_load_art()
		_layout()
		_apply_pause()
		return
	_render()

func _exit_tree() -> void:
	_stop_tweens()
