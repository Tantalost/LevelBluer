class_name LevelManager
extends Node
## Match controller: quiz → build → defend, economy, base HP, end-game modal.

enum GamePhase {
	PRE_MATCH,
	PHASE_1_QUIZ,
	PHASE_2_BUILD,
	PHASE_3_DEFEND,
	GAME_OVER,
	VICTORY,
}

@export var enemy_scene: PackedScene

const QUESTION_BANK: Dictionary = {
	"ports": [
		{"text": "Which port is used for HTTPS?", "correct": "443", "wrong": "80"},
		{"text": "Which port handles SSH traffic?", "correct": "22", "wrong": "21"},
	],
	"firewalls": [
		{"text": "Which rule blocks all incoming traffic by default?", "correct": "Implicit Deny", "wrong": "Port Forwarding"},
		{"text": "A firewall operates primarily at which OSI layer?", "correct": "Network (Layer 3)", "wrong": "Application (Layer 7)"},
	],
	"crypto": [
		{"text": "Which algorithm is asymmetric?", "correct": "RSA", "wrong": "AES"},
		{"text": "What is the primary purpose of a hash?", "correct": "Integrity", "wrong": "Encryption"},
	],
}

var current_phase: GamePhase = GamePhase.PRE_MATCH
var current_gold: int = 5
var base_health: int = 5
var active_enemies: int = 0
var current_question: Dictionary = {}
var current_wave_index: int = 0
var current_stage_config: Dictionary = {}
var exam_questions_asked: int = 0
var exam_questions_correct: int = 0
var exam_history: Array[String] = []
var _wave_token: int = 0
var _wave_finished_spawning: bool = true
var _wave_kills: int = 0
var _is_wave_intermission: bool = false

@onready var _track: Path2D = %EnemyTrack
@onready var _player_base: Area2D = %PlayerBase
@onready var _phase_label: Label = %PhaseLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _base_health_label: Label = %BaseHealthLabel
@onready var _start_wave_button: Button = %StartWaveButton
@onready var _start_hint_label: Label = %StartHintLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _map_label: Label = %MapLabel
@onready var _heart_label: Label = %HeartLabel
@onready var _quiz_modal: ColorRect = %QuizModal
@onready var _exam_progress_label: Label = %ExamProgressLabel
@onready var _question_label: Label = %QuestionLabel
@onready var _btn_correct: Button = %BtnCorrect
@onready var _btn_wrong: Button = %BtnWrong
@onready var _end_game_modal: ColorRect = %EndGameModal
@onready var _modal_title_label: Label = %TitleLabel
@onready var _items_label: Label = %ItemsLabel
@onready var _gold_acquired_label: Label = %GoldAcquiredLabel
@onready var _tips_label: Label = %TipsLabel
@onready var _codex_button: Button = %CodexButton
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _restart_button: Button = %RestartButton
@onready var _tower_placer: TowerPlacer = %GridMap
@onready var _upgrade_panel: PanelContainer = %TowerUpgradePanel
@onready var _stats_label: Label = %StatsLabel
@onready var _upgrade_options: HBoxContainer = %UpgradeOptionsContainer
@onready var _btn_close: Button = %BtnClose
@onready var _level_background: ColorRect = %Background

var _selected_tower: TowerBase = null


func _ready() -> void:
	_player_base.area_entered.connect(_on_player_base_area_entered)
	_codex_button.pressed.connect(_on_codex_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_result_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_btn_correct.pressed.connect(_on_quiz_correct_pressed)
	_btn_wrong.pressed.connect(_on_quiz_wrong_pressed)
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	_tower_placer.tower_selected.connect(_on_tower_selected)
	_btn_close.pressed.connect(_on_upgrade_close_pressed)
	_upgrade_panel.visible = false
	_end_game_modal.visible = false
	_quiz_modal.visible = false
	_set_start_controls_visible(false)
	_level_background.color = Palette.GAMEPLAY_BG
	_level_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_fit_level_background)
	_fit_level_background()
	_phase_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_gold_label.add_theme_color_override("font_color", Palette.GOLD)
	_base_health_label.add_theme_color_override("font_color", Palette.HEART)
	_wave_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_map_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_heart_label.add_theme_color_override("font_color", Palette.HEART)
	_start_hint_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_style_start_button()
	_exam_progress_label.add_theme_color_override("font_color", Palette.GOLD)
	_question_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_modal_title_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_items_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_gold_acquired_label.add_theme_color_override("font_color", Palette.GOLD)
	_tips_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_style_result_buttons()
	_stats_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_load_stage_config()
	update_hud()
	print("[LevelManager] Initializing Level for Stage Index: ", Router.active_stage_index)
	change_phase(GamePhase.PHASE_1_QUIZ)


func change_phase(new_phase: GamePhase) -> void:
	match new_phase:
		GamePhase.PRE_MATCH:
			_quiz_modal.visible = false
			_set_start_controls_visible(false)
			_end_game_modal.visible = false
			_hide_upgrade_ui()
			print("[LevelManager] Entering PRE_MATCH. Waiting for briefing...")
		GamePhase.PHASE_1_QUIZ:
			_end_game_modal.visible = false
			_set_start_controls_visible(false)
			_hide_upgrade_ui()
			if current_wave_index == 0:
				exam_questions_asked = 0
				exam_questions_correct = 0
				exam_history.clear()
			_btn_correct.disabled = false
			_btn_wrong.disabled = false
			_load_next_question()
			_quiz_modal.visible = true
			print("[LevelManager] Entering Phase 1: QUIZ. Loading mock questions...")
		GamePhase.PHASE_2_BUILD:
			_quiz_modal.visible = false
			_end_game_modal.visible = false
			_set_start_controls_visible(true)
			print("[LevelManager] Entering Phase 2: BUILD. Generating mock gold...")
		GamePhase.PHASE_3_DEFEND:
			_quiz_modal.visible = false
			_set_start_controls_visible(false)
			_end_game_modal.visible = false
			_hide_upgrade_ui()
			print("[LevelManager] Entering Phase 3: DEFEND. Spawning wave " + str(current_wave_index + 1) + "...")
		GamePhase.GAME_OVER:
			_quiz_modal.visible = false
			_set_start_controls_visible(false)
			_hide_upgrade_ui()
			var weak_skill: String = PlayerManager.get_weakest_skill()
			var tip := "Open Intel, then Codex, and train the weak skill before you deploy again."
			if _is_summative():
				var exam_count: int = _exam_question_count()
				var accuracy: float = 0.0
				if exam_count > 0:
					accuracy = float(exam_questions_correct) / float(exam_count)
				var accuracy_pct: int = int(round(accuracy * 100.0))
				tip = "Exam score %d%%. Review the missed topics in Codex, then retry." % accuracy_pct
			elif not weak_skill.is_empty():
				tip = "Critical weakness: %s. Train it in Codex before you deploy again." % weak_skill.capitalize()
			print("[LevelManager] Entering GAME_OVER. Match lost.")
			Router.open_defeat(tip, weak_skill)
		GamePhase.VICTORY:
			_quiz_modal.visible = false
			_set_start_controls_visible(false)
			_hide_upgrade_ui()
			var stage_id: int = Router.active_stage_index + 1
			PlayerManager.mark_stage_cleared(stage_id)
			print("[Victory] Stage ", stage_id, " cleared. Max stage is now ", PlayerManager.mock_max_stage_cleared)
			var accuracy: float = 1.0
			if _is_summative():
				var exam_count: int = _exam_question_count()
				if exam_count > 0:
					accuracy = float(exam_questions_correct) / float(exam_count)
			Router.open_victory(accuracy, current_gold)
			print("[LevelManager] Entering VICTORY. Match won.")
	current_phase = new_phase
	update_hud()
	if new_phase == GamePhase.PHASE_3_DEFEND:
		_begin_wave()
	else:
		_wave_token += 1


func update_hud() -> void:
	_phase_label.text = _phase_display_name()
	_gold_label.text = "GOLD  " + str(current_gold)
	_base_health_label.text = "BASE  " + str(base_health)
	_heart_label.text = str(base_health)
	_wave_label.text = str(_wave_kills) + "/" + str(_current_wave_enemy_count())
	_map_label.text = "MAP A" + str(Router.active_stage_index + 1)


func _fit_level_background() -> void:
	var vr: Rect2 = get_viewport().get_visible_rect()
	_level_background.position = Vector2.ZERO
	_level_background.size = vr.size


func _load_stage_config() -> void:
	# Stage select is 0-based. STAGE_DB keys are 1-based diagnostic/formative IDs.
	var stage_id: int = Router.active_stage_index + 1
	current_stage_config = StageManager.get_stage_config(stage_id)
	if current_stage_config.is_empty():
		current_stage_config = StageManager.get_stage_config(1)
	current_wave_index = 0
	exam_questions_asked = 0
	exam_questions_correct = 0
	if _is_summative():
		# Pass reward only. Granting this here would double-pay on exam success.
		current_gold = 0
	else:
		var gold_stored: Variant = current_stage_config.get("starting_gold", 5)
		current_gold = int(gold_stored)
	print("[Stage] Loaded " + str(current_stage_config.get("name", "Unknown")) + " (id " + str(stage_id) + ")")


func _current_wave_data() -> Dictionary:
	var stored: Variant = current_stage_config.get("waves", [])
	var waves: Array = stored as Array
	if current_wave_index < 0 or current_wave_index >= waves.size():
		return {}
	var wave_stored: Variant = waves[current_wave_index]
	return wave_stored as Dictionary


func _wave_count() -> int:
	var stored: Variant = current_stage_config.get("waves", [])
	var waves: Array = stored as Array
	return waves.size()


func _current_wave_enemy_count() -> int:
	var wave_data: Dictionary = _current_wave_data()
	var count_stored: Variant = wave_data.get("enemy_count", 0)
	return maxi(0, int(count_stored))


func _is_summative() -> bool:
	var type_stored: Variant = current_stage_config.get("type", "")
	return str(type_stored) == "summative"


func _exam_question_count() -> int:
	var stored: Variant = current_stage_config.get("exam_question_count", 5)
	return maxi(1, int(stored))


func _exam_required_score() -> float:
	var stored: Variant = current_stage_config.get("exam_required_score", 0.75)
	return float(stored)


func _phase_display_name() -> String:
	match current_phase:
		GamePhase.PRE_MATCH:
			return "PRE-MATCH"
		GamePhase.PHASE_1_QUIZ:
			return "QUIZ"
		GamePhase.PHASE_2_BUILD:
			return "BUILD"
		GamePhase.PHASE_3_DEFEND:
			return "DEFEND"
		GamePhase.GAME_OVER:
			return "DEFEAT"
		GamePhase.VICTORY:
			return "VICTORY"
	return "UNKNOWN"


func _on_quiz_correct_pressed() -> void:
	_resolve_quiz(5, true)


func _on_quiz_wrong_pressed() -> void:
	_resolve_quiz(2, false)


func _load_next_question() -> void:
	if QUESTION_BANK.is_empty():
		push_error("LevelManager: QUESTION_BANK is empty")
		return
	var type_stored: Variant = current_stage_config.get("type", "")
	var is_formative: bool = str(type_stored) == "formative"
	if not is_formative:
		current_question = _pick_summative_question()
	else:
		var target_skill: String = ""
		var all_skills: Array = QUESTION_BANK.keys()
		if all_skills.is_empty():
			push_error("LevelManager: QUESTION_BANK has no skills")
			return
		if randf() <= 0.8:
			target_skill = PlayerManager.get_weakest_skill()
		else:
			target_skill = str(all_skills[randi() % all_skills.size()])
		if not QUESTION_BANK.has(target_skill):
			target_skill = "ports"
		var bank_stored: Variant = QUESTION_BANK[target_skill]
		var skill_questions: Array = bank_stored as Array
		if skill_questions.is_empty():
			push_error("LevelManager: no questions for skill " + target_skill)
			return
		var q_stored: Variant = skill_questions[randi() % skill_questions.size()]
		var selected_q: Dictionary = q_stored as Dictionary
		current_question = selected_q.duplicate()
		current_question["skill_id"] = target_skill
	if current_question.is_empty():
		push_error("LevelManager: failed to load a question")
		return
	_question_label.text = str(current_question.get("text", ""))
	if _is_summative():
		var current_q: int = exam_questions_asked + 1
		var total_q: int = _exam_question_count()
		_exam_progress_label.text = "Question " + str(current_q) + " of " + str(total_q)
		_exam_progress_label.visible = true
	else:
		_exam_progress_label.visible = false
	_btn_correct.text = str(current_question.get("correct", ""))
	_btn_wrong.text = str(current_question.get("wrong", ""))


func _pick_summative_question() -> Dictionary:
	var all_questions: Array[Dictionary] = []
	var skill_ids: Array = QUESTION_BANK.keys()
	for i in skill_ids.size():
		var skill_id: String = str(skill_ids[i])
		var list_stored: Variant = QUESTION_BANK[skill_id]
		var q_list: Array = list_stored as Array
		for j in q_list.size():
			var q_stored: Variant = q_list[j]
			var q_dict: Dictionary = (q_stored as Dictionary).duplicate()
			q_dict["skill_id"] = skill_id
			all_questions.append(q_dict)
	if all_questions.is_empty():
		push_error("LevelManager: QUESTION_BANK has no questions")
		return {}
	var valid_questions: Array[Dictionary] = []
	for i in all_questions.size():
		var q: Dictionary = all_questions[i]
		var text: String = str(q.get("text", ""))
		if not exam_history.has(text):
			valid_questions.append(q)
	if valid_questions.is_empty():
		exam_history.clear()
		valid_questions = all_questions
	var selected_q: Dictionary = valid_questions[randi() % valid_questions.size()]
	exam_history.append(str(selected_q.get("text", "")))
	return selected_q


func _resolve_quiz(reward: int, is_correct: bool) -> void:
	if current_phase != GamePhase.PHASE_1_QUIZ:
		return
	_btn_correct.disabled = true
	_btn_wrong.disabled = true
	exam_questions_asked += 1
	if is_correct:
		exam_questions_correct += 1
	var skill_id: String = str(current_question.get("skill_id", ""))
	PlayerManager.update_mastery(skill_id, is_correct)
	if not _is_summative():
		current_gold += reward
		print("[Economy] Quiz reward +" + str(reward) + " Gold. Current Gold: " + str(current_gold))
		_quiz_modal.visible = false
		update_hud()
		change_phase(GamePhase.PHASE_2_BUILD)
		return
	var exam_count: int = _exam_question_count()
	if exam_questions_asked < exam_count:
		_load_next_question()
		_btn_correct.disabled = false
		_btn_wrong.disabled = false
		update_hud()
		return
	var accuracy: float = float(exam_questions_correct) / float(exam_count)
	_quiz_modal.visible = false
	if accuracy >= _exam_required_score():
		print("[Exam] Passed with accuracy: " + str(accuracy))
		var gold_stored: Variant = current_stage_config.get("starting_gold", 20)
		current_gold = int(gold_stored)
		update_hud()
		change_phase(GamePhase.PHASE_2_BUILD)
		return
	print("[Exam] Failed with accuracy: " + str(accuracy))
	var stage_id: int = Router.active_stage_index + 1
	PlayerManager.lock_stage(stage_id)
	print("[Exam] Failed. Locking Stage ", stage_id, " for remediation.")
	change_phase(GamePhase.GAME_OVER)


func _on_start_wave_pressed() -> void:
	if current_phase != GamePhase.PHASE_2_BUILD:
		return
	_set_start_controls_visible(false)
	change_phase(GamePhase.PHASE_3_DEFEND)


func _set_start_controls_visible(active: bool) -> void:
	_start_wave_button.visible = active
	_start_hint_label.visible = active


func _style_start_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Palette.TEXT_PRIMARY, 0.08)
	normal.border_color = Palette.TEXT_PRIMARY
	normal.set_border_width_all(2)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	_start_wave_button.add_theme_stylebox_override("normal", normal)
	_start_wave_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)


func _style_result_buttons() -> void:
	var upgrade_box := StyleBoxFlat.new()
	upgrade_box.bg_color = Color(Palette.BG_PANEL, 0.92)
	upgrade_box.border_color = Palette.TEXT_PRIMARY
	upgrade_box.set_border_width_all(2)
	upgrade_box.content_margin_left = 20.0
	upgrade_box.content_margin_right = 20.0
	upgrade_box.content_margin_top = 12.0
	upgrade_box.content_margin_bottom = 12.0
	_upgrade_button.add_theme_stylebox_override("normal", upgrade_box)
	_upgrade_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	var restart_box := StyleBoxFlat.new()
	restart_box.bg_color = Color(Palette.CASTLE_SHADOW, 0.9)
	restart_box.border_color = Palette.TEXT_MUTED
	restart_box.set_border_width_all(2)
	restart_box.content_margin_left = 16.0
	restart_box.content_margin_right = 16.0
	restart_box.content_margin_top = 8.0
	restart_box.content_margin_bottom = 8.0
	_restart_button.add_theme_stylebox_override("normal", restart_box)
	_restart_button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	var codex_box := StyleBoxFlat.new()
	codex_box.bg_color = Palette.GOLD
	codex_box.border_color = Palette.TEXT_ON_GOLD
	codex_box.set_border_width_all(2)
	codex_box.content_margin_left = 20.0
	codex_box.content_margin_right = 20.0
	codex_box.content_margin_top = 12.0
	codex_box.content_margin_bottom = 12.0
	_codex_button.add_theme_stylebox_override("normal", codex_box)
	_codex_button.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD)


func _show_result_screen(is_breach: bool) -> void:
	_end_game_modal.visible = true
	var mat: ShaderMaterial = _end_game_modal.material as ShaderMaterial
	if is_breach:
		_modal_title_label.text = "SYSTEM BREACHED"
		_modal_title_label.add_theme_color_override("font_color", Palette.HEART)
		_items_label.visible = false
		_gold_acquired_label.visible = false
		_tips_label.visible = true
		_tips_label.text = "Tips: Open Intel, then Codex, and train the weak skill before you deploy again."
		if mat != null:
			mat.set_shader_parameter("edge_color", Palette.RED_DEEP)
			mat.set_shader_parameter("center_alpha", 0.18)
			mat.set_shader_parameter("edge_alpha", 0.94)
	else:
		_modal_title_label.text = "SYSTEM SECURED"
		_modal_title_label.add_theme_color_override("font_color", Palette.GREEN)
		_items_label.visible = true
		_gold_acquired_label.visible = true
		_gold_acquired_label.text = "GOLD  " + str(current_gold)
		_tips_label.visible = false
		_codex_button.visible = false
		_upgrade_button.visible = true
		if mat != null:
			mat.set_shader_parameter("edge_color", Palette.BG_DEEP)
			mat.set_shader_parameter("center_alpha", 0.28)
			mat.set_shader_parameter("edge_alpha", 0.88)


func _begin_wave() -> void:
	_wave_token += 1
	_wave_finished_spawning = false
	_wave_kills = 0
	update_hud()
	_spawn_wave(_wave_token)


func _spawn_wave(token: int) -> void:
	if enemy_scene == null:
		push_error("LevelManager: enemy_scene is not assigned")
		return
	if _track == null:
		push_error("LevelManager: EnemyTrack is missing")
		return

	var wave_data: Dictionary = _current_wave_data()
	var count_stored: Variant = wave_data.get("enemy_count", 0)
	var delay_stored: Variant = wave_data.get("spawn_delay", 1.0)
	var hp_stored: Variant = wave_data.get("health_multiplier", 1.0)
	var type_stored: Variant = wave_data.get("enemy_type", "basic")
	var count: int = maxi(0, int(count_stored))
	var delay: float = float(delay_stored)
	var hp_mult: float = float(hp_stored)
	var type_id: String = str(type_stored)
	if type_id.is_empty():
		type_id = "basic"
	for i in count:
		if token != _wave_token or current_phase != GamePhase.PHASE_3_DEFEND or not is_inside_tree():
			return
		var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
		if enemy == null:
			push_error("LevelManager: enemy_scene is not an EnemyBase")
			return
		enemy.initialize_stats(type_id, hp_mult)
		enemy.enemy_died.connect(_on_enemy_died)
		active_enemies += 1
		_track.add_child(enemy)
		if i < count - 1:
			await get_tree().create_timer(delay).timeout

	if token != _wave_token or current_phase != GamePhase.PHASE_3_DEFEND:
		return
	_wave_finished_spawning = true
	_check_wave_cleared()


func _on_enemy_died(bounty_amount: int) -> void:
	current_gold += bounty_amount
	active_enemies = maxi(0, active_enemies - 1)
	_wave_kills += 1
	print("[Economy] Enemy defeated! + " + str(bounty_amount) + " Gold. Current Gold: " + str(current_gold))
	update_hud()
	_check_wave_cleared()


func _on_player_base_area_entered(area: Area2D) -> void:
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if enemy == null or enemy.is_dead or enemy.is_queued_for_deletion():
		return
	enemy.is_dead = true
	base_health -= 1
	active_enemies = maxi(0, active_enemies - 1)
	enemy.queue_free()
	print("[Enemy] Base breached!")
	update_hud()
	if base_health <= 0:
		change_phase(GamePhase.GAME_OVER)
		return
	_check_wave_cleared()


func _check_wave_cleared() -> void:
	if current_phase != GamePhase.PHASE_3_DEFEND:
		return
	if _is_wave_intermission:
		return
	if base_health <= 0:
		change_phase(GamePhase.GAME_OVER)
		return
	if active_enemies != 0 or not _wave_finished_spawning:
		return
	if current_wave_index < _wave_count() - 1:
		_is_wave_intermission = true
		print("[Wave] Cleared! Pausing for 2 seconds...")
		if not is_inside_tree():
			_is_wave_intermission = false
			return
		await get_tree().create_timer(2.0).timeout
		_is_wave_intermission = false
		if not is_inside_tree():
			return
		if current_phase != GamePhase.PHASE_3_DEFEND:
			return
		current_wave_index += 1
		change_phase(GamePhase.PHASE_1_QUIZ)
		return
	change_phase(GamePhase.VICTORY)


func _on_tower_selected(tower_node: TowerBase) -> void:
	if tower_node == null or not is_instance_valid(tower_node):
		_selected_tower = null
		_upgrade_panel.visible = false
		return
	_selected_tower = tower_node
	_refresh_upgrade_panel()
	_upgrade_panel.visible = true


func _refresh_upgrade_panel() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		_upgrade_panel.visible = false
		return
	_stats_label.text = TowerBase.display_name_for(_selected_tower.current_type) + " | Dmg: " + str(_selected_tower.base_damage)
	_rebuild_upgrade_buttons(_selected_tower)


func _rebuild_upgrade_buttons(tower_node: TowerBase) -> void:
	_clear_upgrade_options()
	var paths: Array[String] = TowerBase.paths_for(tower_node.current_type)
	if paths.is_empty():
		var max_label := Label.new()
		max_label.text = "MAX LEVEL"
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		max_label.add_theme_color_override("font_color", Palette.GOLD)
		_apply_panel_font(max_label, 10)
		_upgrade_options.add_child(max_label)
		return
	for path_id: String in paths:
		var btn := Button.new()
		var req: String = TowerBase.req_skill_for(path_id)
		var is_unlocked: bool = req.is_empty() or PlayerManager.has_skill(req)
		if is_unlocked:
			btn.text = TowerBase.display_name_for(path_id) + " (" + str(TowerBase.cost_for(path_id)) + "G)"
		else:
			btn.disabled = true
			btn.text = "[LOCKED] " + TowerBase.display_name_for(path_id)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_panel_font(btn, 10)
		btn.pressed.connect(_on_upgrade_purchased.bind(tower_node, path_id))
		_upgrade_options.add_child(btn)


func _apply_panel_font(control: Control, size_px: int) -> void:
	var font: Font = _stats_label.get_theme_font("font")
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size_px)


func _clear_upgrade_options() -> void:
	var kids: Array = _upgrade_options.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child == null:
			continue
		_upgrade_options.remove_child(child)
		child.queue_free()


func _on_upgrade_purchased(tower_node: TowerBase, target_type: String) -> void:
	if tower_node == null or not is_instance_valid(tower_node):
		_hide_upgrade_ui()
		return
	var req: String = TowerBase.req_skill_for(target_type)
	if not req.is_empty() and not PlayerManager.has_skill(req):
		print("[Upgrade] Locked. Requires: " + req)
		return
	var cost: int = TowerBase.cost_for(target_type)
	if current_gold < cost:
		print("[Economy] Insufficient gold. Need: " + str(cost))
		return
	current_gold -= cost
	tower_node.apply_stats(target_type)
	print("[Economy] Upgraded to " + TowerBase.display_name_for(target_type) + ". Remaining Gold: " + str(current_gold))
	update_hud()
	_on_tower_selected(tower_node)


func _on_upgrade_close_pressed() -> void:
	_tower_placer.clear_selection()


func _hide_upgrade_ui() -> void:
	_selected_tower = null
	_upgrade_panel.visible = false
	if _tower_placer != null:
		_tower_placer.selected_tower = null


func _on_codex_pressed() -> void:
	Router.open_codex(PlayerManager.get_weakest_skill())


func _on_upgrade_result_pressed() -> void:
	Router.return_to_stage_select()


func _on_restart_pressed() -> void:
	Router.restart_level()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_SPACE and current_phase == GamePhase.PHASE_2_BUILD:
			_on_start_wave_pressed()
			get_viewport().set_input_as_handled()
