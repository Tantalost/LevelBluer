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

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

@export var enemy_scene: PackedScene

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
var _wave_total_enemies: int = 0
var _is_wave_intermission: bool = false

@onready var _map_mount: Node2D = %MapMount
var _track: Path2D
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
@onready var _quiz_window: PanelContainer = %QuizWindow
@onready var _quiz_title_bar: PanelContainer = %QuizTitleBar
@onready var _quiz_file_label: Label = %QuizFileLabel
@onready var _quiz_event_label: Label = %QuizEventLabel
@onready var _quiz_led: ColorRect = %QuizLed
@onready var _quiz_well: PanelContainer = %QuizWell
@onready var _exam_progress_label: Label = %ExamProgressLabel
@onready var _question_label: Label = %QuestionLabel
@onready var _quiz_reward_hint: Label = %QuizRewardHint
@onready var _quiz_tap_hint: Label = %QuizTapHint
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
var _tower_placer: TowerPlacer
@onready var _upgrade_panel: PanelContainer = %TowerUpgradePanel
@onready var _stats_label: Label = %StatsLabel
@onready var _upgrade_options: HBoxContainer = %UpgradeOptionsContainer
@onready var _btn_close: Button = %BtnClose
@onready var _level_background: ColorRect = %Background
@onready var _btn_speed_1x: HudGeoButton = %BtnSpeed1x
@onready var _btn_speed_2x: HudGeoButton = %BtnSpeed2x
@onready var _btn_pause: HudGeoButton = %BtnPause
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _tower_card: HudGeoButton = %TowerCard
@onready var _incident_modal: PanelContainer = %IncidentModal
@onready var _incident_text: Label = %IncidentText
@onready var _btn_incident_a: Button = %BtnIncidentA
@onready var _btn_incident_b: Button = %BtnIncidentB

var _selected_tower: TowerBase = null
var _current_incident_correct_btn: Button = null
var _incident_timeout_timer: SceneTreeTimer = null
var _pixel_font: Font
var _quiz_correct_text: String = ""
var _quiz_led_t: float = 0.0
var _speed_mult: float = 1.0
var _shake_intensity: float = 0.0

@onready var _camera: Camera2D = %Camera2D


func _ready() -> void:
	_player_base.area_entered.connect(_on_player_base_area_entered)
	_codex_button.pressed.connect(_on_codex_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_result_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_btn_correct.pressed.connect(_on_quiz_correct_pressed)
	_btn_wrong.pressed.connect(_on_quiz_wrong_pressed)
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	_btn_close.pressed.connect(_on_upgrade_close_pressed)
	_btn_speed_1x.pressed.connect(_on_speed_1x_pressed)
	_btn_speed_2x.pressed.connect(_on_speed_2x_pressed)
	_btn_pause.pressed.connect(toggle_pause)
	_btn_incident_a.pressed.connect(_on_incident_button_pressed.bind(_btn_incident_a))
	_btn_incident_b.pressed.connect(_on_incident_button_pressed.bind(_btn_incident_b))
	_upgrade_panel.visible = false
	_end_game_modal.visible = false
	_quiz_modal.visible = false
	_hide_incident()
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
	_load_pixel_font()
	_style_quiz_ui()
	_style_incident_ui()
	_modal_title_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_items_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_gold_acquired_label.add_theme_color_override("font_color", Palette.GOLD)
	_tips_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_style_result_buttons()
	_stats_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_load_stage_config()
	_mount_map()
	update_hud()
	print("[LevelManager] Initializing Level for Stage Index: ", Router.active_stage_index)
	change_phase(GamePhase.PHASE_1_QUIZ)


func _process(delta: float) -> void:
	_update_camera_shake(delta)
	if not _quiz_modal.visible:
		return
	_quiz_led_t += delta
	_quiz_led.color = Palette.GOLD if fmod(_quiz_led_t, 0.85) < 0.48 else Palette.CYAN


func change_phase(new_phase: GamePhase) -> void:
	if new_phase != GamePhase.PHASE_3_DEFEND:
		_hide_incident()
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
			_hide_incident()
			print("[LevelManager] Entering Phase 3: DEFEND. Spawning wave " + str(current_wave_index + 1) + "...")
		GamePhase.GAME_OVER:
			Engine.time_scale = 1.0
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
			Engine.time_scale = 1.0
			_quiz_modal.visible = false
			_set_start_controls_visible(false)
			_hide_upgrade_ui()
			var stage_id: int = Router.active_stage_index + 1
			PlayerManager.mark_stage_cleared(stage_id)
			TaskManager.record_stage_cleared()
			print("[Victory] Stage ", stage_id, " cleared. Max stage is now ", PlayerManager.mock_max_stage_cleared)
			var accuracy: float = 1.0
			if _is_summative():
				var exam_count: int = _exam_question_count()
				if exam_count > 0:
					accuracy = float(exam_questions_correct) / float(exam_count)
			var credit_payout: int = 50 + maxi(0, current_gold)
			PlayerManager.add_credits(credit_payout)
			print("[Economy] Victory payout +" + str(credit_payout) + " credits. Wallet: " + str(PlayerManager.credits))
			if _is_module_final():
				PlayerManager.module_1_complete = true
				SaveService.save_game()
				Router.open_certificate_screen()
			else:
				Router.open_victory(accuracy, credit_payout)
			print("[LevelManager] Entering VICTORY. Match won.")
	current_phase = new_phase
	_sync_phase_chrome()
	update_hud()
	if new_phase == GamePhase.PHASE_3_DEFEND:
		_begin_wave()
		_schedule_incident()
	else:
		_hide_incident()
		_wave_token += 1


func update_hud() -> void:
	_phase_label.text = _phase_display_name()
	if current_phase == GamePhase.PHASE_1_QUIZ:
		_phase_label.add_theme_color_override("font_color", Palette.GOLD)
	else:
		_phase_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_gold_label.text = "GOLD  " + str(current_gold)
	_base_health_label.text = "HP  " + str(base_health)
	_heart_label.text = str(base_health)
	_wave_label.text = str(_wave_kills) + "/" + str(_wave_total_enemies)
	_map_label.text = "MAP A" + str(Router.active_stage_index + 1)


func _fit_level_background() -> void:
	var vr: Rect2 = get_viewport().get_visible_rect()
	_level_background.position = Vector2.ZERO
	_level_background.size = vr.size


func _load_stage_config() -> void:
	# Stage select is 0-based. ContentDB stage keys are 1-based string IDs.
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


func _mount_map() -> void:
	const FALLBACK_MAP := "res://src/gameplay/maps/map_basic.tscn"
	var stored: Variant = current_stage_config.get("map_scene", FALLBACK_MAP)
	var scene_path: String = str(stored)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("LevelManager: map_scene missing or invalid, using basic")
		scene_path = FALLBACK_MAP
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("LevelManager: failed to load map " + scene_path)
		return
	var stale: Array[Node] = []
	for child in _map_mount.get_children():
		stale.append(child)
	for i in stale.size():
		_map_mount.remove_child(stale[i])
		stale[i].queue_free()
	var map_root: Node = packed.instantiate()
	_map_mount.add_child(map_root)
	_track = _resolve_track()
	_tower_placer = _find_tower_placer(map_root)
	if _tower_placer != null:
		_tower_placer.bind_level_manager(self)
		if not _tower_placer.tower_selected.is_connected(_on_tower_selected):
			_tower_placer.tower_selected.connect(_on_tower_selected)
	var builder := map_root as MapBuilder
	if builder != null:
		var end_pos: Vector2 = builder.get_end_global_position()
		if end_pos != Vector2.ZERO:
			_player_base.global_position = end_pos


func _resolve_track() -> Path2D:
	var found: Node = get_tree().get_first_node_in_group("level_path")
	return found as Path2D


func _find_tower_placer(root: Node) -> TowerPlacer:
	var placer := root as TowerPlacer
	if placer != null:
		return placer
	for child in root.get_children():
		var nested: TowerPlacer = _find_tower_placer(child)
		if nested != null:
			return nested
	return null


func _spawn_enemy(type_id: String, hp_mult: float) -> void:
	if enemy_scene == null:
		push_error("LevelManager: enemy_scene is not assigned")
		return
	var track: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	_track = track
	if track == null:
		push_error("LevelManager: no Path2D in group 'level_path'")
		return
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	if enemy == null:
		push_error("LevelManager: enemy_scene is not an EnemyBase")
		return
	enemy.initialize_stats(type_id, hp_mult)
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	active_enemies += 1
	track.add_child(enemy)


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


func _is_module_final() -> bool:
	# Router.active_stage_index is 0-based. Stage 10 is index 9.
	var stage_id: int = Router.active_stage_index + 1
	return _is_summative() and stage_id == 10


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
			return "TRACE"
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
	_resolve_quiz_choice(_btn_correct.text)


func _on_quiz_wrong_pressed() -> void:
	_resolve_quiz_choice(_btn_wrong.text)


func _resolve_quiz_choice(picked: String) -> void:
	var is_correct: bool = picked == _quiz_correct_text
	_resolve_quiz(5 if is_correct else 2, is_correct)


func _load_next_question() -> void:
	var question_bank: Dictionary = ContentDB.get_questions()
	if question_bank.is_empty():
		push_error("LevelManager: question bank is empty")
		return
	var type_stored: Variant = current_stage_config.get("type", "")
	var is_formative: bool = str(type_stored) == "formative"
	if not is_formative:
		current_question = _pick_summative_question()
	else:
		var target_skill: String = ""
		var all_skills: Array = question_bank.keys()
		if all_skills.is_empty():
			push_error("LevelManager: question bank has no skills")
			return
		if randf() <= 0.8:
			target_skill = PlayerManager.get_weakest_skill()
		else:
			target_skill = str(all_skills[randi() % all_skills.size()])
		if not question_bank.has(target_skill):
			target_skill = "ports"
		var bank_stored: Variant = question_bank[target_skill]
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
	_quiz_correct_text = str(current_question.get("correct", ""))
	var wrong_text: String = str(current_question.get("wrong", ""))
	if randi() % 2 == 0:
		_btn_correct.text = _quiz_correct_text
		_btn_wrong.text = wrong_text
	else:
		_btn_correct.text = wrong_text
		_btn_wrong.text = _quiz_correct_text
	_refresh_quiz_copy()


func _pick_summative_question() -> Dictionary:
	var question_bank: Dictionary = ContentDB.get_questions()
	var all_questions: Array[Dictionary] = []
	var skill_ids: Array = question_bank.keys()
	for i in skill_ids.size():
		var skill_id: String = str(skill_ids[i])
		var list_stored: Variant = question_bank[skill_id]
		var q_list: Array = list_stored as Array
		for j in q_list.size():
			var q_stored: Variant = q_list[j]
			var q_dict: Dictionary = (q_stored as Dictionary).duplicate()
			q_dict["skill_id"] = skill_id
			all_questions.append(q_dict)
	if all_questions.is_empty():
		push_error("LevelManager: question bank has no questions")
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
	_start_wave_button.custom_minimum_size = Vector2(180, 52)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	_hide_incident()


func _on_speed_1x_pressed() -> void:
	_speed_mult = 1.0
	_apply_speed()


func _on_speed_2x_pressed() -> void:
	_speed_mult = 2.0
	_apply_speed()


func _apply_speed() -> void:
	var quiz_open: bool = _quiz_modal.visible or current_phase == GamePhase.PHASE_1_QUIZ
	Engine.time_scale = 1.0 if quiz_open else _speed_mult
	_btn_speed_1x.fill_key = "gold" if _speed_mult <= 1.5 else "header"
	_btn_speed_2x.fill_key = "gold" if _speed_mult > 1.5 else "header"
	_btn_speed_1x.queue_redraw()
	_btn_speed_2x.queue_redraw()


func _sync_phase_chrome() -> void:
	var building: bool = current_phase == GamePhase.PHASE_2_BUILD
	var live: bool = building or current_phase == GamePhase.PHASE_3_DEFEND
	if _tower_placer != null:
		_tower_placer.set_build_preview(building)
	_tower_card.visible = building
	_btn_speed_1x.visible = live
	_btn_speed_2x.visible = live
	_apply_speed()


func _refresh_quiz_copy() -> void:
	var exam := _is_summative()
	_quiz_file_label.text = "EXAM.DAT" if exam else "QTE.DAT"
	_quiz_event_label.text = "EXAM TRACE" if exam else "QUICK TRACE"
	_quiz_reward_hint.visible = not exam
	_quiz_tap_hint.text = "TAP TO PASS" if exam else "TAP FAST"
	if exam:
		var current_q: int = exam_questions_asked + 1
		var total_q: int = _exam_question_count()
		_exam_progress_label.text = "TRACE  " + str(current_q) + " / " + str(total_q)
		_exam_progress_label.visible = true
	else:
		_exam_progress_label.visible = false


func _load_pixel_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var file: FontFile = load(FONT_PATH) as FontFile
	if file != null:
		_pixel_font = file


func _style_incident_ui() -> void:
	var panel := _pixel_box(Color(Palette.BG_HEADER, 0.94), Palette.GOLD, 0, 2)
	panel.shadow_color = Color(Palette.BG_DEEP, 0.72)
	panel.shadow_size = 2
	panel.shadow_offset = Vector2(4, 4)
	_incident_modal.add_theme_stylebox_override("panel", panel)
	var header: Label = _incident_modal.find_child("IncidentHeader", true, false) as Label
	if header != null:
		_apply_quiz_label(header, Palette.GOLD, 9)
	_apply_quiz_label(_incident_text, Palette.TEXT_PRIMARY, 10)
	_style_quiz_choice(_btn_incident_a)
	_style_quiz_choice(_btn_incident_b)
	_btn_incident_a.custom_minimum_size = Vector2(0, 44)
	_btn_incident_b.custom_minimum_size = Vector2(0, 44)
	_btn_incident_a.add_theme_font_size_override("font_size", 9)
	_btn_incident_b.add_theme_font_size_override("font_size", 9)


func _hide_incident() -> void:
	_cancel_incident_timeout()
	_incident_modal.visible = false
	_current_incident_correct_btn = null


func _wave_type_mix(mix_stored: Variant, fallback_type: String) -> PackedStringArray:
	var mix: PackedStringArray = PackedStringArray()
	if typeof(mix_stored) != TYPE_ARRAY:
		return mix
	var raw: Array = mix_stored as Array
	for i in raw.size():
		var spawn_type: String = str(raw[i]).strip_edges()
		if spawn_type.is_empty():
			spawn_type = fallback_type
		mix.append(spawn_type)
	return mix


func _incident_chance() -> float:
	var stored: Variant = current_stage_config.get("incident_chance", 0.5)
	if typeof(stored) != TYPE_INT and typeof(stored) != TYPE_FLOAT:
		return 0.5
	return clampf(float(stored), 0.0, 1.0)


func _schedule_incident() -> void:
	if randf() > _incident_chance():
		return
	if not is_inside_tree():
		return
	var token: int = _wave_token
	var timer: SceneTreeTimer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_incident_delay_elapsed.bind(token))


func _on_incident_delay_elapsed(token: int) -> void:
	if not is_inside_tree():
		return
	if token != _wave_token:
		return
	if current_phase != GamePhase.PHASE_3_DEFEND:
		return
	if _is_wave_intermission:
		return
	_trigger_incident()


func _trigger_incident() -> void:
	var incident_bank: Array = ContentDB.get_incidents()
	if incident_bank.is_empty():
		return
	if current_phase != GamePhase.PHASE_3_DEFEND:
		return
	var bank_size: int = incident_bank.size()
	var event_stored: Variant = incident_bank[randi() % bank_size]
	if typeof(event_stored) != TYPE_DICTIONARY:
		return
	var event: Dictionary = event_stored as Dictionary
	_incident_text.text = str(event.get("text", ""))
	var correct_text: String = str(event.get("correct", ""))
	var wrong_text: String = str(event.get("wrong", ""))
	if randf() > 0.5:
		_btn_incident_a.text = correct_text
		_btn_incident_b.text = wrong_text
		_current_incident_correct_btn = _btn_incident_a
	else:
		_btn_incident_a.text = wrong_text
		_btn_incident_b.text = correct_text
		_current_incident_correct_btn = _btn_incident_b
	_incident_modal.visible = true
	_cancel_incident_timeout()
	if not is_inside_tree():
		return
	_incident_timeout_timer = get_tree().create_timer(6.0)
	_incident_timeout_timer.timeout.connect(_on_incident_timeout)


func _cancel_incident_timeout() -> void:
	if _incident_timeout_timer != null and _incident_timeout_timer.timeout.is_connected(_on_incident_timeout):
		_incident_timeout_timer.timeout.disconnect(_on_incident_timeout)
	_incident_timeout_timer = null


func _on_incident_timeout() -> void:
	_incident_timeout_timer = null
	if not is_inside_tree():
		return
	if not _incident_modal.visible:
		return
	if current_phase != GamePhase.PHASE_3_DEFEND:
		_hide_incident()
		return
	_incident_modal.visible = false
	_current_incident_correct_btn = null
	print("[Incident] Ignored! Auto-failing and spawning penalties.")
	_spawn_penalty_enemies(3, "fast")
	_check_wave_cleared()


func _on_incident_button_pressed(btn: Button) -> void:
	if not _incident_modal.visible:
		return
	_cancel_incident_timeout()
	_incident_modal.visible = false
	if btn == _current_incident_correct_btn:
		print("[Incident] Correct! Buffing towers.")
		get_tree().call_group("towers", "apply_incident_buff")
	else:
		print("[Incident] Wrong! Spawning penalty enemies.")
		_spawn_penalty_enemies(3, "fast")
	_current_incident_correct_btn = null
	_check_wave_cleared()


func _spawn_penalty_enemies(count: int, type_id: String) -> void:
	if current_phase != GamePhase.PHASE_3_DEFEND or not is_inside_tree():
		return
	_is_wave_intermission = false
	var wave_data: Dictionary = _current_wave_data()
	var hp_mult: float = float(wave_data.get("health_multiplier", 1.0))
	var resolved_type: String = type_id if not type_id.is_empty() else "fast"
	var spawn_count: int = maxi(0, count)
	_wave_total_enemies += spawn_count
	update_hud()
	for i in spawn_count:
		_spawn_enemy(resolved_type, hp_mult)


func _style_quiz_ui() -> void:
	var window := _pixel_box(Palette.BG_HEADER, Palette.CYAN, 0, 2)
	window.shadow_color = Color(Palette.BG_DEEP, 0.72)
	window.shadow_size = 2
	window.shadow_offset = Vector2(6, 6)
	_quiz_window.add_theme_stylebox_override("panel", window)
	_quiz_title_bar.add_theme_stylebox_override("panel", _pixel_box(Palette.GOLD, Palette.GOLD, 0, 0))
	_quiz_well.add_theme_stylebox_override("panel", _pixel_box(Color(Palette.BG_PANEL, 0.94), Palette.CYAN_DIM, 0, 0))
	_quiz_led.color = Palette.GOLD
	_apply_quiz_label(_quiz_file_label, Palette.TEXT_ON_GOLD, 10)
	_apply_quiz_label(_quiz_event_label, Palette.TEXT_ON_GOLD, 10)
	_apply_quiz_label(_exam_progress_label, Palette.GOLD, 9)
	_apply_quiz_label(_question_label, Palette.TEXT_PRIMARY, 13)
	_apply_quiz_label(_quiz_reward_hint, Palette.CYAN, 8)
	_apply_quiz_label(_quiz_tap_hint, Palette.TEXT_MUTED, 8)
	_style_quiz_choice(_btn_correct)
	_style_quiz_choice(_btn_wrong)
	var wave_frame := _wave_label.get_parent() as PanelContainer
	if wave_frame != null:
		var chip := _pixel_box(Color(Palette.BG_HEADER, 0.9), Palette.CYAN_DIM, 0, 2)
		chip.content_margin_left = 12.0
		chip.content_margin_right = 12.0
		chip.content_margin_top = 8.0
		chip.content_margin_bottom = 8.0
		wave_frame.add_theme_stylebox_override("panel", chip)


func _style_quiz_choice(button: Button) -> void:
	var normal := _pixel_box(Color(Palette.BG_PANEL_ALT, 0.96), Palette.CYAN, 0, 2)
	normal.border_width_left = 4
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 14.0
	normal.content_margin_bottom = 14.0
	var hover := _pixel_box(Palette.GOLD, Palette.TEXT_PRIMARY, 0, 2)
	hover.border_width_left = 4
	hover.content_margin_left = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_top = 14.0
	hover.content_margin_bottom = 14.0
	var disabled := _pixel_box(Color(Palette.BG_PANEL_ALT, 0.7), Palette.CYAN_DIM, 0, 2)
	disabled.content_margin_left = 12.0
	disabled.content_margin_right = 12.0
	disabled.content_margin_top = 14.0
	disabled.content_margin_bottom = 14.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_pressed_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	button.add_theme_font_size_override("font_size", 12)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.custom_minimum_size = Vector2(0, 56)


func _apply_quiz_label(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _pixel_font != null:
		label.add_theme_font_override("font", _pixel_font)


func _pixel_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box


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
	_wave_total_enemies = _current_wave_enemy_count()
	update_hud()
	_spawn_wave(_wave_token)


func _spawn_wave(token: int) -> void:
	var wave_data: Dictionary = _current_wave_data()
	var count_stored: Variant = wave_data.get("enemy_count", 0)
	var delay_stored: Variant = wave_data.get("spawn_delay", 1.0)
	var hp_stored: Variant = wave_data.get("health_multiplier", 1.0)
	var type_stored: Variant = wave_data.get("enemy_type", "basic")
	var mix_stored: Variant = wave_data.get("enemy_mix", [])
	var count: int = maxi(0, int(count_stored))
	var delay: float = float(delay_stored)
	var hp_mult: float = float(hp_stored)
	var type_id: String = str(type_stored)
	if type_id.is_empty():
		type_id = "basic"
	var mix: PackedStringArray = _wave_type_mix(mix_stored, type_id)
	for i in count:
		if token != _wave_token or current_phase != GamePhase.PHASE_3_DEFEND or not is_inside_tree():
			return
		var spawn_type: String = type_id
		if mix.size() > 0:
			spawn_type = mix[i % mix.size()]
		_spawn_enemy(spawn_type, hp_mult)
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


func _on_enemy_reached_base() -> void:
	_apply_base_breach()


func _on_player_base_area_entered(area: Area2D) -> void:
	var enemy: EnemyBase = _enemy_from_hitbox(area)
	if enemy == null:
		return
	if not enemy.mark_leaked():
		return
	enemy.queue_free()
	_apply_base_breach()


func _enemy_from_hitbox(area: Area2D) -> EnemyBase:
	var node: Node = area
	while node != null:
		var enemy: EnemyBase = node as EnemyBase
		if enemy != null:
			return enemy
		node = node.get_parent()
	return null


func _apply_base_breach() -> void:
	base_health -= 1
	active_enemies = maxi(0, active_enemies - 1)
	add_camera_shake(15.0)
	print("[Enemy] Base breached!")
	update_hud()
	if base_health <= 0:
		change_phase(GamePhase.GAME_OVER)
		return
	_check_wave_cleared()


func add_camera_shake(intensity: float = 10.0) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _update_camera_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake_intensity <= 0.0:
		return
	_shake_intensity = lerpf(_shake_intensity, 0.0, delta * 5.0)
	_camera.offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity)
	)
	if _shake_intensity < 0.5:
		_shake_intensity = 0.0
		_camera.offset = Vector2.ZERO


func _check_wave_cleared() -> void:
	if current_phase != GamePhase.PHASE_3_DEFEND:
		return
	if _incident_modal.visible:
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
		var is_unlocked: bool = PlayerManager.is_tower_unlocked(path_id)
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
	if not PlayerManager.is_tower_unlocked(target_type):
		print("[Upgrade] Locked. Unlock this node in the skill tree first: " + target_type)
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
	if _tower_placer != null:
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
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_SPACE and current_phase == GamePhase.PHASE_2_BUILD:
			_on_start_wave_pressed()
			get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if current_phase == GamePhase.GAME_OVER or current_phase == GamePhase.VICTORY:
		return
	if _pause_menu.visible:
		_pause_menu.resume_game()
	else:
		_pause_menu.pause_game()
