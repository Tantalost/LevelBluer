class_name PvpBattleScreen
extends BaseScreen
## Presentation for a local bot duel. Rules live in PvpBattle.
const Battle = preload("res://src/gameplay/pvp/pvp_battle.gd")
const UI = preload("res://src/ui/screens/intel/study_ui.gd")
const Quiz = preload("res://src/gameplay/quiz_content.gd")
const ARENA_TEX = preload("res://assets/gameplay/pvp/arena/network_core_arena_v1.png")
const DEFENDER_TEX = preload("res://assets/gameplay/pvp/characters/cyber_defender_pixel_v1.png")
const RIVAL_TEX = preload("res://assets/gameplay/pvp/characters/rival_cyber_duelist_left_v1.png")
const PULSE_TEX = preload("res://assets/gameplay/pvp/vfx/blue_cyber_pulse_v1.png")
const ARENA_FOCUS := Vector2(0.502, 0.47)
const FIGHTER_FOOT := 0.96

class HpBar extends Control:
	var value: int = 100
	var fill: Color = Color("#4FE0D4")

	func _ready() -> void:
		custom_minimum_size.y = 12
		resized.connect(queue_redraw)

	func set_hp(next_hp: int) -> void:
		value = clampi(next_hp, 0, 100)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.NAVY_700)
		var width: float = size.x * float(value) / 100.0
		if width > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(width, size.y)), fill)

var _battle: Battle
var _layout: VBoxContainer
var _body: VBoxContainer
var _status: Label
var _timer: Label
var _round_label: Label
var _player_name: Label
var _bot_name: Label
var _player_hp: Label
var _bot_hp: Label
var _player_bar: HpBar
var _bot_bar: HpBar
var _footer: HBoxContainer
var _abandon: Control
var _choices: Array[Dictionary] = []
var _answer_buttons: Array[Button] = []
var _display_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pause_started: int = -1
var _paused_total: int = 0
var _quiz: PanelContainer
var _quiz_column: VBoxContainer
var _countdown: Control
var _countdown_round: Label
var _countdown_value: Label
var _result_host: CenterContainer
var _result_title: Label
var _result_note: Label
var _end_host: CenterContainer
var _end_title: Label
var _end_you_hp: Label
var _end_rival_hp: Label
var _end_you_correct: Label
var _end_rival_correct: Label
var _end_rounds: Label
var _end_you_avg: Label
var _end_rival_avg: Label
var _arena: Control
var _background: TextureRect
var _player_slot: Control
var _rival_slot: Control
var _player_shake: Control
var _pulse: TextureRect
var _hit_flash: ColorRect
var _fx: Tween
var _fx_round: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shell: Dictionary = UI.shell(self, "", func() -> void: Router.request_back())
	_layout = shell["layout"] as VBoxContainer
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 8)
	var back: Button = shell["back"] as Button
	back.name = "BackButton"
	var title: Label = shell["title"] as Label
	title.visible = false
	_build_hud()
	_build_arena()
	_build_quiz()
	_build_result_card()
	_build_end_card()
	_build_abandon()
	_display_rng.randomize()
	resized.connect(_fit_arena)
	_fit_arena()
	_start_match()


func _process(_delta: float) -> void:
	if _battle == null:
		return
	var now: int = _clock_now()
	_battle.tick(now)
	_update_hud(now)


func _exit_tree() -> void:
	_unbind_battle()


func on_exit() -> void:
	_unbind_battle()


func consume_back() -> bool:
	if _battle == null or _battle.phase == Battle.Phase.FINISHED:
		return false
	if _abandon.visible:
		_abandon.hide()
		return true
	_abandon.show()
	return true


func _start_match() -> void:
	_abandon.hide()
	_pause_started = -1
	_paused_total = 0
	_footer.hide()
	var deck_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	deck_rng.randomize()
	var bot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	bot_rng.randomize()
	var deck: Array[Dictionary] = Battle.build_deck(_pool(), 0, deck_rng)
	var next: Battle = Battle.new()
	_bind_battle(next)
	var now: int = _clock_now()
	if not _battle.start(deck, now, bot_rng):
		_unbind_battle()
		_render_unavailable()
		return
	_battle.tick(now)


func _pool() -> Array:
	var pool: Array = []
	var bank: Dictionary = ContentDB.get_questions()
	for skill: Variant in bank.keys():
		var rows: Variant = bank[skill]
		if typeof(rows) != TYPE_ARRAY:
			continue
		var list: Array = rows as Array
		for row: Variant in list:
			pool.append(row)
	return pool


func _on_phase_changed(_next_phase: int) -> void:
	_render_phase()


func _render_phase() -> void:
	if _battle == null:
		return
	_answer_buttons.clear()
	_choices.clear()
	UI.clear(_body)
	_footer.hide()
	_apply_chrome(_battle.phase)
	var now: int = _clock_now()
	_update_hud(now)
	match _battle.phase:
		Battle.Phase.COUNTDOWN:
			_status.text = "GET READY"
			_clear_fx()
		Battle.Phase.QUESTION:
			_status.text = "CHOOSE AN ANSWER"
			_render_question()
			_clear_fx()
		Battle.Phase.RESOLVING:
			_render_result()
			_clear_fx()
		Battle.Phase.ROUND_RESULT:
			_render_result()
			_present_round_fx()
		Battle.Phase.FINISHED:
			_render_end()
			_clear_fx()
		_:
			_status.text = "LINKING"
			_clear_fx()
	_fit_arena()
	UI.fit_touch(self)
	_fit_answer_text.call_deferred()


func _apply_chrome(phase: Battle.Phase) -> void:
	var questioning: bool = phase == Battle.Phase.QUESTION
	var counting: bool = phase == Battle.Phase.COUNTDOWN or phase == Battle.Phase.PREPARING
	var resulting: bool = phase == Battle.Phase.RESOLVING or phase == Battle.Phase.ROUND_RESULT
	var finished: bool = phase == Battle.Phase.FINISHED
	_quiz.visible = questioning
	_countdown.visible = counting
	_result_host.visible = resulting
	_end_host.visible = finished
	if counting:
		_attach(_status, _countdown_value.get_parent())
	elif questioning:
		_attach(_status, _quiz_column, 0)


func _render_question() -> void:
	var question: Dictionary = _battle.current_question()
	var scenario: String = Quiz._format_scenario(question)
	if not scenario.is_empty():
		var evidence: PanelContainer = UI.panel(_body, Palette.NAVY_800)
		evidence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		evidence.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_800, Palette.NAVY_700, 8))
		var evidence_label: Label = UI.label(scenario, 16, Palette.CREAM)
		evidence_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		evidence.add_child(evidence_label)
	var prompt: Label = UI.label(Quiz._format_prompt(question), 18, Palette.CREAM)
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(prompt)
	_choices = Quiz.options(question)
	_shuffle_choices(_choices)
	var grid: GridContainer = GridContainer.new()
	grid.name = "AnswerGrid"
	grid.columns = 2 if _choices.size() > 1 else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	var button_height: float = 52.0 if size.y >= 520.0 else 44.0
	for index: int in _choices.size():
		var label: String = str(_choices[index].get("text", ""))
		if label == "Phishing":
			label = "Suspicious / attack"
		var button: Button = UI.button(label, _pick.bind(index))
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(0, button_height)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_answer_buttons.append(button)
		grid.add_child(button)


func _render_result() -> void:
	var headline: String = _result_headline()
	_status.text = headline
	_result_title.text = headline
	var note: String = Quiz.explanation(_battle.current_question(), _battle.side_correct(true), _battle.player_pick())
	_result_note.text = note
	_result_note.visible = not note.is_empty()


func _render_end() -> void:
	var title: String = "DRAW"
	var color: Color = Palette.WARNING
	match _battle.winner():
		Battle.Outcome.PLAYER_WIN:
			title = "VICTORY"
			color = Palette.SUCCESS
		Battle.Outcome.BOT_WIN:
			title = "DEFEAT"
			color = Palette.DANGER
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_end_you_hp.text = "YOU  %d" % _battle.player_hp
	_end_rival_hp.text = "RIVAL  %d" % _battle.bot_hp
	_end_you_correct.text = "CORRECT  %d" % _battle.player_correct
	_end_rival_correct.text = "CORRECT  %d" % _battle.bot_correct
	_end_rounds.text = "ROUNDS  %d" % _battle.rounds_played
	_end_you_avg.text = "AVG  %s" % _format_average(_battle.average_correct_ms(true))
	_end_rival_avg.text = "AVG  %s" % _format_average(_battle.average_correct_ms(false))
	_footer.show()


func _render_unavailable() -> void:
	_quiz.visible = true
	_countdown.visible = false
	_result_host.visible = false
	_end_host.visible = false
	_attach(_status, _quiz_column, 0)
	_status.text = "QUESTION BANK UNAVAILABLE"
	UI.clear(_body)
	var note: Label = UI.label("No duel questions could be loaded. Nothing was saved.", 22, Palette.WARNING)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(note)
	_footer.hide()


func _attach(node: Control, parent: Node, index: int = -1) -> void:
	if node == null or parent == null:
		return
	var old_parent: Node = node.get_parent()
	if old_parent == parent:
		if index >= 0:
			parent.move_child(node, mini(index, parent.get_child_count() - 1))
		return
	if old_parent != null:
		old_parent.remove_child(node)
	parent.add_child(node)
	if index >= 0:
		parent.move_child(node, mini(index, parent.get_child_count() - 1))


func _result_headline() -> String:
	if _battle.side_timed_out(true) and _battle.side_timed_out(false):
		return "BOTH TIMED OUT"
	var dealt: int = _battle.damage_to(false)
	var taken: int = _battle.damage_to(true)
	if _battle.side_correct(true) and _battle.side_correct(false):
		if dealt > 0:
			return "BOTH CORRECT · FASTER!"
		if taken > 0:
			return "RIVAL FASTER · -%d HP" % taken
		return "BOTH CORRECT · EVEN"
	if dealt > 0:
		return "CORRECT · %d DAMAGE" % dealt
	if taken > 0:
		if _battle.side_timed_out(true):
			return "TIMED OUT · -%d HP" % taken
		return "YOU MISSED · -%d HP" % taken
	return "NO DAMAGE"


func _pick(index: int) -> void:
	if _battle == null or index < 0 or index >= _choices.size():
		return
	if _battle.submit_player(_choices[index].get("value"), _clock_now()):
		_show_locked()


func _show_locked() -> void:
	_status.text = "ANSWER LOCKED / WAITING FOR OPPONENT"
	for button: Button in _answer_buttons:
		button.disabled = true


func _on_rematch() -> void:
	_start_match()


func _on_leave() -> void:
	Router.pop()


func _on_stay() -> void:
	_abandon.hide()


func _build_hud() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_layout.add_child(row)
	var player_box: VBoxContainer = _fighter_column()
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size.x = 156
	center.add_theme_constant_override("separation", 0)
	var bot_box: VBoxContainer = _fighter_column()
	row.add_child(player_box)
	row.add_child(center)
	row.add_child(bot_box)
	var player_label: String = AuthService.display_name().strip_edges()
	if player_label.is_empty():
		player_label = "OPERATOR"
	_player_name = UI.label(player_label.to_upper(), 14, Palette.CYAN_300, true)
	_player_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_player_hp = UI.label("100", 16, Palette.CREAM, true)
	_player_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	_player_hp.custom_minimum_size.x = 36
	_player_bar = HpBar.new()
	_player_bar.fill = Palette.CYAN_400
	_player_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_box.add_child(_player_name)
	player_box.add_child(_hp_line(_player_hp, _player_bar, true))
	_round_label = UI.label("ROUND 1", 14, Palette.CREAM, true)
	_round_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer = UI.label("", 18, Palette.WARNING, true)
	_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_round_label)
	center.add_child(_timer)
	_bot_name = UI.label(Battle.BOT_NAME, 14, Palette.DANGER, true)
	_bot_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bot_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bot_hp = UI.label("100", 16, Palette.CREAM, true)
	_bot_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bot_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bot_hp.custom_minimum_size.x = 36
	_bot_bar = HpBar.new()
	_bot_bar.fill = Palette.DANGER
	_bot_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bot_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot_box.add_child(_bot_name)
	bot_box.add_child(_hp_line(_bot_hp, _bot_bar, false))


func _hp_line(number: Label, bar: HpBar, number_first: bool) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	if number_first:
		line.add_child(number)
		line.add_child(bar)
	else:
		line.add_child(bar)
		line.add_child(number)
	return line


func _fighter_column() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	return box


func _build_quiz() -> void:
	_quiz = PanelContainer.new()
	_quiz.name = "QuizPanel"
	_quiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quiz.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_900, Palette.NAVY_700, 8))
	_layout.add_child(_quiz)
	_quiz_column = VBoxContainer.new()
	_quiz_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quiz_column.add_theme_constant_override("separation", 6)
	_quiz.add_child(_quiz_column)
	_status = UI.label("", 18, Palette.CYAN_300, true)
	_status.name = "BattleStatus"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiz_column.add_child(_status)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	_quiz_column.add_child(_body)


func _build_result_card() -> void:
	_result_host = CenterContainer.new()
	_result_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_host.visible = false
	_layout.add_child(_result_host)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size.x = 460
	card.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_900, Palette.CYAN_400, 14))
	_result_host.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	_result_title = UI.label("", 22, Palette.CREAM, true)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_note = UI.label("", 16, Palette.CREAM)
	_result_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_note.custom_minimum_size.x = 420
	column.add_child(_result_title)
	column.add_child(_result_note)


func _build_end_card() -> void:
	_end_host = CenterContainer.new()
	_end_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_end_host.visible = false
	_layout.add_child(_end_host)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size.x = 520
	card.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_900, Palette.NAVY_700, 12))
	_end_host.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	_end_title = UI.label("DRAW", 36, Palette.WARNING, true)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_you_hp = _end_stat("YOU  100")
	_end_rival_hp = _end_stat("RIVAL  100")
	_end_you_correct = _end_stat("CORRECT  0")
	_end_rival_correct = _end_stat("CORRECT  0")
	_end_rounds = UI.label("", 18, Palette.CYAN_300)
	_end_rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_rounds.autowrap_mode = TextServer.AUTOWRAP_OFF
	_end_you_avg = _end_stat("AVG  —")
	_end_rival_avg = _end_stat("AVG  —")
	column.add_child(_end_title)
	column.add_child(_end_pair(_end_you_hp, _end_rival_hp))
	column.add_child(_end_pair(_end_you_correct, _end_rival_correct))
	column.add_child(_end_rounds)
	column.add_child(_end_pair(_end_you_avg, _end_rival_avg))
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 12)
	_footer.hide()
	column.add_child(_footer)
	var rematch: Button = UI.button("REMATCH", _on_rematch, true)
	rematch.name = "RematchButton"
	var leave: Button = UI.button("LEAVE", _on_leave)
	leave.name = "LeaveButton"
	_footer.add_child(rematch)
	_footer.add_child(leave)


func _build_arena() -> void:
	_arena = Control.new()
	_arena.name = "BattleArena"
	_arena.clip_contents = true
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena.resized.connect(_layout_fighters)
	_layout.add_child(_arena)
	_background = _pixel_rect(ARENA_TEX, "ArenaBackground")
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_arena.add_child(_background)
	_player_shake = _fighter_sprite(DEFENDER_TEX, "CyberDefender", true)
	_fighter_sprite(RIVAL_TEX, "RivalDuelist", false)
	_pulse = _pixel_rect(PULSE_TEX, "PlayerPulse")
	_pulse.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pulse.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pulse.z_index = 2
	_pulse.hide()
	_arena.add_child(_pulse)
	_hit_flash = ColorRect.new()
	_hit_flash.name = "PlayerHitFlash"
	_hit_flash.color = Palette.DANGER
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit_flash.hide()
	_player_shake.add_child(_hit_flash)
	_countdown = Control.new()
	_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown.z_index = 4
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena.add_child(_countdown)
	var plate_center: CenterContainer = CenterContainer.new()
	plate_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown.add_child(plate_center)
	var plate: PanelContainer = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.05, 0.10, 0.78), Palette.CYAN_400, 18))
	plate_center.add_child(plate)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	plate.add_child(stack)
	_countdown_round = UI.label("ROUND 1", 18, Palette.CREAM, true)
	_countdown_round.autowrap_mode = TextServer.AUTOWRAP_OFF
	_countdown_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_value = UI.label("3", 52, Palette.WARNING, true)
	_countdown_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	_countdown_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.custom_minimum_size.x = 280
	stack.add_child(_countdown_round)
	stack.add_child(_countdown_value)


func _pixel_rect(texture: Texture2D, node_name: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2.ZERO
	return rect


func _fighter_sprite(texture: Texture2D, node_name: String, player_side: bool) -> Control:
	var slot: Control = Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_arena.add_child(slot)
	if player_side:
		_player_slot = slot
	else:
		_rival_slot = slot
	var shake: Control = Control.new()
	shake.name = node_name
	shake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shake.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(shake)
	var sprite: TextureRect = _pixel_rect(texture, node_name + "Sprite")
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shake.add_child(sprite)
	return shake


func _fit_arena() -> void:
	if _arena == null:
		return
	var short: bool = size.y < 520.0
	var ratio: float = 0.36 if short else 0.43
	var next_height: float = clampf(size.y * ratio, 110.0, size.y * 0.45)
	var counting: bool = _countdown != null and _countdown.visible and (_quiz == null or not _quiz.visible)
	_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL if counting else Control.SIZE_FILL
	_arena.size_flags_stretch_ratio = 1.0
	if not is_equal_approx(_arena.custom_minimum_size.y, next_height):
		_arena.custom_minimum_size.y = next_height
	_layout_fighters()


func _layout_fighters() -> void:
	if _arena == null or _player_slot == null or _rival_slot == null:
		return
	if _arena.size.x < 2.0 or _arena.size.y < 2.0:
		return
	var gap: float = maxf(2.0, _arena.size.y * 0.01)
	var side: float = minf(_arena.size.y - gap - 2.0, minf(_arena.size.y * 0.92, _arena.size.x * 0.34))
	side = minf(side, 306.0)
	var top: float = _arena.size.y - side - gap
	var inset: float = _arena.size.x * 0.09
	_place_slot(_player_slot, inset, top, side)
	_place_slot(_rival_slot, _arena.size.x - side - inset, top, side)
	_ground_sprite(_player_slot, side)
	_ground_sprite(_rival_slot, side)
	if _countdown != null and _countdown.get_child_count() > 0:
		var plate_center: Control = _countdown.get_child(0) as Control
		var shift: float = top + side * 0.46 - _arena.size.y * 0.5
		plate_center.offset_top = shift
		plate_center.offset_bottom = shift
	_layout_background()


func _layout_background() -> void:
	if _background == null or _arena == null or ARENA_TEX == null:
		return
	var view: Vector2 = _arena.size
	var tex_size: Vector2 = ARENA_TEX.get_size()
	if view.x < 2.0 or view.y < 2.0 or tex_size.x < 1.0 or tex_size.y < 1.0:
		return
	var cover: float = maxf(view.x / tex_size.x, view.y / tex_size.y)
	var drawn: Vector2 = tex_size * cover
	var origin: Vector2 = view * 0.5 - Vector2(tex_size.x * ARENA_FOCUS.x, tex_size.y * ARENA_FOCUS.y) * cover
	origin.x = clampf(origin.x, view.x - drawn.x, 0.0)
	origin.y = clampf(origin.y, view.y - drawn.y, 0.0)
	_background.position = origin
	_background.size = drawn


func _fit_answer_text() -> void:
	_fit_stack()
	if _answer_buttons.is_empty():
		return
	var sample: Button = _answer_buttons[0]
	if not is_instance_valid(sample):
		return
	var cell_width: float = sample.size.x
	if cell_width < 32.0 and _body != null:
		cell_width = _body.size.x * (0.5 if _answer_buttons.size() > 1 else 1.0) - 12.0
	if cell_width < 32.0:
		return
	var shared_height: float = sample.custom_minimum_size.y
	if shared_height < 40.0:
		shared_height = 52.0 if size.y >= 520.0 else 44.0
	var shared_font: int = 99
	var arbitrary: bool = false
	for button: Button in _answer_buttons:
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size.y = shared_height
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var fitted: int = font_size
		while fitted > 13 and not _answer_fits(font, button.text, fitted, cell_width - 28.0, shared_height - 20.0):
			fitted -= 1
			button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			arbitrary = true
		shared_font = mini(shared_font, fitted)
	if shared_font == 99:
		return
	for button: Button in _answer_buttons:
		if not is_instance_valid(button):
			continue
		if arbitrary:
			button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.add_theme_font_size_override("font_size", shared_font)


func _fit_stack() -> void:
	var limit: float = get_global_rect().end.y - 8.0
	if _lowest_visible_bottom() <= limit:
		return
	for child: Node in find_children("*", "Control", true, false):
		var control: Control = child as Control
		if (control is Label or control is Button) and control.has_meta("touch_font"):
			control.add_theme_font_size_override("font_size", int(control.get_meta("touch_font")))
		if control is Button and control.has_meta("touch_size"):
			var designed: Vector2 = control.get_meta("touch_size")
			control.custom_minimum_size = designed


func _lowest_visible_bottom() -> float:
	var lowest: float = 0.0
	for child: Node in _layout.get_children():
		var control: Control = child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		lowest = maxf(lowest, control.get_global_rect().end.y)
	return lowest


func _answer_fits(font: Font, text: String, font_size: int, width: float, height: float) -> bool:
	if _widest_word(font, text, font_size) > width:
		return false
	var bounds: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	return bounds.y <= height


func _widest_word(font: Font, text: String, font_size: int) -> float:
	var widest: float = 0.0
	for word: String in text.split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest


func _end_stat(text: String) -> Label:
	var stat: Label = UI.label(text, 18, Palette.CREAM, true)
	stat.autowrap_mode = TextServer.AUTOWRAP_OFF
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.custom_minimum_size.x = 168
	return stat


func _end_pair(left: Label, right: Label) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.add_child(left)
	row.add_child(right)
	return row


func _ground_sprite(slot: Control, side: float) -> void:
	if slot.get_child_count() == 0:
		return
	var shake: Control = slot.get_child(0) as Control
	if shake == null:
		return
	var lift: float = side * (1.0 / FIGHTER_FOOT - 1.0)
	for child: Node in shake.get_children():
		var sprite: TextureRect = child as TextureRect
		if sprite == null:
			continue
		sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sprite.offset_left = 0.0
		sprite.offset_top = -lift
		sprite.offset_right = side
		sprite.offset_bottom = side


func _place_slot(slot: Control, x: float, y: float, side: float) -> void:
	slot.offset_left = x
	slot.offset_top = y
	slot.offset_right = x + side
	slot.offset_bottom = y + side


func _present_round_fx() -> void:
	if _battle == null or not is_inside_tree():
		return
	if _fx_round == _battle.rounds_played:
		return
	_fx_round = _battle.rounds_played
	_clear_fx()
	if _arena == null or _arena.size.x < 2.0:
		return
	if _battle.damage_to(false) > 0:
		_play_player_pulse()
	elif _battle.damage_to(true) > 0:
		_play_player_hit()


func _play_player_pulse() -> void:
	var height: float = clampf(_arena.size.y * 0.28, 24.0, 84.0)
	var aspect: float = 2.0
	if PULSE_TEX.get_height() > 0:
		aspect = float(PULSE_TEX.get_width()) / float(PULSE_TEX.get_height())
	var pulse_size: Vector2 = Vector2(height * aspect, height)
	var origin: Vector2 = _slot_point(_player_slot, 0.86, 0.42) - pulse_size * 0.5
	var target: Vector2 = _slot_point(_rival_slot, 0.14, 0.42) - pulse_size * 0.5
	_pulse.size = pulse_size
	_pulse.position = origin
	_pulse.modulate = Color.WHITE
	_pulse.show()
	_fx = create_tween()
	_fx.set_trans(Tween.TRANS_QUAD)
	_fx.set_ease(Tween.EASE_OUT)
	_fx.tween_property(_pulse, "position", target, 0.32)
	_fx.tween_property(_pulse, "modulate:a", 0.0, 0.08)
	_fx.tween_callback(_hide_pulse)


func _play_player_hit() -> void:
	_player_shake.position = Vector2.ZERO
	_hit_flash.modulate.a = 0.72
	_hit_flash.show()
	_fx = create_tween()
	_fx.set_parallel(true)
	_fx.tween_method(_shake_player, 0.0, 1.0, 0.26)
	_fx.tween_property(_hit_flash, "modulate:a", 0.0, 0.26)
	_fx.chain().tween_callback(_end_hit)


func _shake_player(weight: float) -> void:
	if _player_shake == null:
		return
	_player_shake.position.x = sin(weight * TAU * 3.0) * (1.0 - weight) * 8.0


func _slot_point(slot: Control, x_ratio: float, y_ratio: float) -> Vector2:
	var rect: Rect2 = slot.get_rect()
	return rect.position + Vector2(rect.size.x * x_ratio, rect.size.y * y_ratio)


func _hide_pulse() -> void:
	if _pulse == null:
		return
	_pulse.hide()
	_pulse.modulate = Color.WHITE


func _end_hit() -> void:
	if _player_shake != null:
		_player_shake.position = Vector2.ZERO
	if _hit_flash != null:
		_hit_flash.hide()


func _clear_fx() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.kill()
	_fx = null
	_hide_pulse()
	_end_hit()


func _build_abandon() -> void:
	_abandon = Control.new()
	_abandon.name = "AbandonConfirm"
	_abandon.mouse_filter = Control.MOUSE_FILTER_STOP
	_abandon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abandon.hide()
	add_child(_abandon)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abandon.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abandon.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", UI.box(Palette.NAVY_900, Palette.DANGER, 18))
	center.add_child(panel)
	var column: VBoxContainer = UI.column(panel, 14)
	column.add_child(UI.label("LEAVE MATCH?", 22, Palette.CREAM, true))
	column.add_child(UI.label("This local duel will be discarded.", 20, Palette.CREAM))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var stay: Button = UI.button("STAY", _on_stay, true)
	stay.name = "StayButton"
	var leave: Button = UI.button("LEAVE", _on_leave)
	leave.name = "AbandonLeaveButton"
	actions.add_child(stay)
	actions.add_child(leave)


func _update_hud(now: int) -> void:
	if _battle == null:
		return
	var shown_round: int = maxi(_battle.round_number, 1)
	_round_label.text = "ROUND %d" % shown_round
	if _countdown_round != null:
		_countdown_round.text = _round_label.text
	_player_hp.text = str(_battle.player_hp)
	_bot_hp.text = str(_battle.bot_hp)
	_player_bar.set_hp(_battle.player_hp)
	_bot_bar.set_hp(_battle.bot_hp)
	if _battle.phase == Battle.Phase.QUESTION:
		_timer.text = "%.1fs" % (float(_battle.remaining_ms(now)) / 1000.0)
		if _battle.player_locked():
			_status.text = "ANSWER LOCKED / WAITING FOR OPPONENT"
	elif _battle.phase == Battle.Phase.COUNTDOWN:
		var remain: int = maxi(0, _battle.countdown_ends_at - now)
		_timer.text = "%d" % int(ceil(float(remain) / 1000.0))
		if _countdown_value != null:
			_countdown_value.text = _timer.text
	else:
		_timer.text = ""
	_timer.visible = not _timer.text.is_empty()


func _side_line(player_side: bool) -> String:
	var who: String = "YOU" if player_side else "RIVAL"
	if _battle.side_timed_out(player_side):
		return "%s TIMED OUT" % who
	if _battle.side_correct(player_side):
		return "%s SECURE" % who
	return "%s MISSED" % who


func _damage_line() -> String:
	if _battle.damage_to(true) > 0:
		return "YOU TAKE %d" % _battle.damage_to(true)
	if _battle.damage_to(false) > 0:
		return "RIVAL TAKES %d" % _battle.damage_to(false)
	return "NO DAMAGE"


func _format_average(ms: float) -> String:
	if ms < 0.0:
		return "—"
	return "%.2fs" % (ms / 1000.0)


func _shuffle_choices(choices: Array[Dictionary]) -> void:
	for i: int in range(choices.size() - 1, 0, -1):
		var j: int = _display_rng.randi_range(0, i)
		var swap: Dictionary = choices[i]
		choices[i] = choices[j]
		choices[j] = swap


func _clock_now() -> int:
	var now: int = Time.get_ticks_msec()
	if _abandon != null and _abandon.visible:
		if _pause_started < 0:
			_pause_started = now
		return _pause_started - _paused_total
	if _pause_started >= 0:
		_paused_total += now - _pause_started
		_pause_started = -1
	return now - _paused_total


func _bind_battle(next: Battle) -> void:
	_unbind_battle()
	_battle = next
	_battle.phase_changed.connect(_on_phase_changed)


func _unbind_battle() -> void:
	_fx_round = -1
	_clear_fx()
	if _battle == null:
		return
	_battle.retire()
	if _battle.phase_changed.is_connected(_on_phase_changed):
		_battle.phase_changed.disconnect(_on_phase_changed)
	_battle = null
