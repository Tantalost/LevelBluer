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
var _asked_question_ids: Array[String] = []
var _bkt_frozen: bool = false
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
@onready var _heart_hud: HBoxContainer = %HeartHud
@onready var _start_wave_button: Button = %StartWaveButton
@onready var _start_hint_label: Label = %StartHintLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _map_label: Label = %MapLabel
@onready var _quiz_modal: ColorRect = %QuizModal
@onready var _quiz_window: PanelContainer = %QuizWindow
@onready var _quiz_title_bar: PanelContainer = %QuizTitleBar
@onready var _quiz_file_label: Label = %QuizFileLabel
@onready var _quiz_event_label: Label = %QuizEventLabel
@onready var _quiz_led: ColorRect = %QuizLed
@onready var _quiz_well: PanelContainer = %QuizWell
@onready var _exam_progress_label: Label = %ExamProgressLabel
@onready var _scenario_scroll: ScrollContainer = %ScenarioScroll
@onready var _scenario_label: Label = %ScenarioLabel
@onready var _question_label: Label = %QuestionLabel
@onready var _quiz_reward_hint: Label = %QuizRewardHint
@onready var _quiz_tap_hint: Label = %QuizTapHint
@onready var _answer_list: VBoxContainer = %AnswerList
@onready var _btn_correct: Button = %BtnCorrect
@onready var _btn_wrong: Button = %BtnWrong
@onready var _quiz_confirm: Button = %QuizConfirmButton
@onready var _quiz_feedback: Label = %QuizFeedbackLabel
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
@onready var _upgrade_options: VBoxContainer = %UpgradeOptionsContainer
@onready var _btn_close: Button = %BtnClose
@onready var _level_background: ColorRect = %Background
@onready var _btn_speed: HudGeoButton = %BtnSpeed
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
var _quiz_locked: bool = false
var _quiz_multi_select: bool = false
var _quiz_selected: Dictionary = {}
var _quiz_option_buttons: Array[Button] = []
var _quiz_led_t: float = 0.0
var _speed_mult: float = 1.0
var _shake_intensity: float = 0.0
var _heart_icons: Array[TextureRect] = []
var _tex_heart_full: Texture2D
var _tex_heart_half: Texture2D
var _tex_heart_empty: Texture2D
var _heart_tween: Tween
var _tutorial_overlay: TutorialOverlay = null
var _tutorial_defend_done: bool = false

@onready var _camera: Camera2D = %Camera2D


func _ready() -> void:
	_player_base.area_entered.connect(_on_player_base_area_entered)
	_codex_button.pressed.connect(_on_codex_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_result_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_btn_correct.pressed.connect(_on_quiz_correct_pressed)
	_btn_wrong.pressed.connect(_on_quiz_wrong_pressed)
	_quiz_confirm.pressed.connect(_on_quiz_confirm_pressed)
	_start_wave_button.pressed.connect(_on_start_wave_pressed)
	_btn_close.pressed.connect(_on_upgrade_close_pressed)
	_btn_speed.pressed.connect(_on_speed_pressed)
	_btn_pause.pressed.connect(toggle_pause)
	_btn_incident_a.pressed.connect(_on_incident_button_pressed.bind(_btn_incident_a))
	_btn_incident_b.pressed.connect(_on_incident_button_pressed.bind(_btn_incident_b))
	_tower_card.pressed.connect(_on_tower_card_pressed)
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
	_wave_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_map_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_start_hint_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_style_start_button()
	_load_pixel_font()
	_bind_heart_hud()
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
	if Router.is_tutorial:
		_begin_tutorial_shell()
	else:
		change_phase(GamePhase.PHASE_1_QUIZ)
	AudioManager.play_bgm(AudioManager.level_track)


func _begin_tutorial_shell() -> void:
	change_phase(GamePhase.PRE_MATCH)
	_btn_pause.visible = false
	_btn_speed.visible = false
	_quiz_modal.visible = false
	_set_start_controls_visible(false)
	update_hud()
	var packed: PackedScene = load("res://src/gameplay/tutorial/tutorial_overlay.tscn") as PackedScene
	if packed == null:
		push_error("LevelManager: tutorial overlay missing")
		return
	var overlay: TutorialOverlay = packed.instantiate() as TutorialOverlay
	if overlay == null:
		return
	var canvas: Node = get_parent().get_node_or_null("GameplayCanvas")
	if canvas == null:
		overlay.queue_free()
		return
	canvas.add_child(overlay)
	_tutorial_overlay = overlay
	if not overlay.quiz_requested.is_connected(_on_tutorial_quiz_requested):
		overlay.quiz_requested.connect(_on_tutorial_quiz_requested)
	if not overlay.build_requested.is_connected(_on_tutorial_build_requested):
		overlay.build_requested.connect(_on_tutorial_build_requested)
	if not overlay.defend_requested.is_connected(_on_tutorial_defend_requested):
		overlay.defend_requested.connect(_on_tutorial_defend_requested)
	if not overlay.upgrades_requested.is_connected(_on_tutorial_upgrades_requested):
		overlay.upgrades_requested.connect(_on_tutorial_upgrades_requested)
	overlay.setup_match()


func _on_tutorial_quiz_requested() -> void:
	if not Router.is_tutorial:
		return
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.visible = false
		_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_phase(GamePhase.PHASE_1_QUIZ)


func _tutorial_gate_copy(is_correct: bool) -> String:
	if exam_questions_asked == 0 and not is_correct:
		return tr("TUTORIAL_Q1_RETRY")
	if exam_questions_asked == 1 and is_correct:
		return tr("TUTORIAL_Q2_FORCE_MISS")
	return ""


func _resolve_tutorial_quiz(reward: int, is_correct: bool) -> void:
	current_gold += reward
	if not is_correct:
		_tutorial_add_miss_enemies(2)
	update_hud()
	if exam_questions_asked < 5:
		_set_quiz_locked(false)
		_load_next_question()
		return
	_quiz_modal.visible = false
	change_phase(GamePhase.PRE_MATCH)
	_show_tutorial_post_quiz()


func _tutorial_add_miss_enemies(count: int) -> void:
	var waves_stored: Variant = current_stage_config.get("waves", [])
	if typeof(waves_stored) != TYPE_ARRAY:
		return
	var waves: Array = waves_stored as Array
	if waves.is_empty():
		return
	var row: Variant = waves[0]
	if typeof(row) != TYPE_DICTIONARY:
		return
	var wave: Dictionary = row as Dictionary
	var next_count: int = int(wave.get("enemy_count", 0)) + maxi(0, count)
	wave["enemy_count"] = next_count
	waves[0] = wave
	current_stage_config["waves"] = waves
	_wave_total_enemies = next_count


func _show_tutorial_post_quiz() -> void:
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_overlay.show_post_quiz()


func _on_tutorial_build_requested() -> void:
	if not Router.is_tutorial:
		return
	if _tower_placer != null:
		_tower_placer.tower_cost = 3
		_tower_placer.move_cost = 1
		_tower_placer.max_towers = 2
	current_gold = maxi(current_gold, 7)
	if _tower_card != null:
		_tower_card.subtitle = "3G"
		_tower_card.queue_redraw()
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.start_build_coach()
	update_hud()
	change_phase(GamePhase.PHASE_2_BUILD)


func _on_tutorial_tower_placed(_tower: TowerBase) -> void:
	if not Router.is_tutorial or _tower_placer == null:
		return
	var placed: int = _tower_placer.placed_count()
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	if placed < 2:
		_tutorial_overlay.coach_build_progress(placed)
		return
	_tutorial_overlay.show_post_build()


func _on_tutorial_defend_requested() -> void:
	if not Router.is_tutorial:
		return
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.visible = false
		_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_defend_done = false
	change_phase(GamePhase.PHASE_3_DEFEND)


func _on_tutorial_upgrades_requested() -> void:
	if not Router.is_tutorial:
		return
	PlayerManager.ensure_tutorial_upgrade_funds()
	Router.open_tutorial_upgrades()


func _finish_tutorial_defend() -> void:
	if _tutorial_defend_done:
		return
	_tutorial_defend_done = true
	_wave_token += 1
	_clear_track_enemies()
	if current_phase != GamePhase.PRE_MATCH:
		change_phase(GamePhase.PRE_MATCH)
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_overlay.show_post_defend()


func _clear_track_enemies() -> void:
	if _track == null or not is_instance_valid(_track):
		return
	var kids: Array = _track.get_children()
	for i in kids.size():
		var enemy: EnemyBase = kids[i] as EnemyBase
		if enemy == null:
			continue
		if enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.disconnect(_on_enemy_died)
		if enemy.reached_base.is_connected(_on_enemy_reached_base):
			enemy.reached_base.disconnect(_on_enemy_reached_base)
		_track.remove_child(enemy)
		enemy.queue_free()
	active_enemies = 0
	_wave_finished_spawning = true


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
			_set_quiz_locked(false)
			_load_next_question()
			_quiz_modal.visible = true
			print("[LevelManager] Entering Phase 1: QUIZ. Loading mock questions...")
		GamePhase.PHASE_2_BUILD:
			_quiz_modal.visible = false
			_end_game_modal.visible = false
			_set_start_controls_visible(not Router.is_tutorial)
			print("[LevelManager] Entering Phase 2: BUILD. Generating mock gold...")
		GamePhase.PHASE_3_DEFEND:
			_quiz_modal.visible = false
			_set_start_controls_visible(false)
			_end_game_modal.visible = false
			_hide_upgrade_ui()
			_hide_incident()
			print("[LevelManager] Entering Phase 3: DEFEND. Spawning wave " + str(current_wave_index + 1) + "...")
		GamePhase.GAME_OVER:
			if Router.is_tutorial:
				_finish_tutorial_defend()
				return
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
			if Router.is_tutorial:
				_finish_tutorial_defend()
				return
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
	_wave_label.text = str(_wave_kills) + "/" + str(_wave_total_enemies)
	if Router.is_tutorial:
		_map_label.text = "TRAINING"
		return
	var wave_n: int = current_wave_index + 1
	var waves: int = maxi(1, _wave_count())
	if str(_current_wave_data().get("enemy_type", "")) == "boss":
		_map_label.text = "MAP A%d  BOSS" % (Router.active_stage_index + 1)
	else:
		_map_label.text = "MAP A%d  W%d/%d" % [Router.active_stage_index + 1, wave_n, waves]


func _bind_heart_hud() -> void:
	_tex_heart_full = AssetManager.get_texture("ui_heart_full")
	_tex_heart_half = AssetManager.get_texture("ui_heart_half")
	_tex_heart_empty = AssetManager.get_texture("ui_heart_empty")
	AssetManager.bind_texture(_btn_speed.get_node_or_null("Icon") as CanvasItem, "ui_speedup")
	AssetManager.bind_texture(_btn_pause.get_node_or_null("Icon") as CanvasItem, "ui_pause")
	_heart_icons.clear()
	var kids: Array = _heart_hud.get_children()
	for i in kids.size():
		var icon: TextureRect = kids[i] as TextureRect
		if icon == null:
			continue
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.pivot_offset = icon.custom_minimum_size * 0.5
		_heart_icons.append(icon)
	_sync_hearts()


func _sync_hearts() -> void:
	for i in _heart_icons.size():
		var icon: TextureRect = _heart_icons[i]
		icon.texture = _tex_heart_full if base_health > i else _tex_heart_empty
		icon.scale = Vector2.ONE
		icon.modulate = Color.WHITE


func _play_heart_hit() -> void:
	var lost_index: int = base_health
	if _heart_tween != null and _heart_tween.is_valid():
		_heart_tween.kill()
	_sync_hearts()
	if lost_index < 0 or lost_index >= _heart_icons.size():
		return
	var icon: TextureRect = _heart_icons[lost_index]
	icon.texture = _tex_heart_half
	icon.pivot_offset = icon.size * 0.5 if icon.size.x > 1.0 else icon.custom_minimum_size * 0.5
	icon.scale = Vector2(1.45, 1.45)
	icon.modulate = Palette.CREAM
	_heart_tween = create_tween()
	_heart_tween.tween_property(icon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_heart_tween.parallel().tween_property(icon, "modulate", Color.WHITE, 0.28)
	_heart_tween.chain().tween_callback(_finish_heart_hit.bind(icon))


func _finish_heart_hit(icon: TextureRect) -> void:
	if icon == null or not is_instance_valid(icon):
		return
	icon.texture = _tex_heart_empty
	icon.scale = Vector2.ONE
	icon.modulate = Color.WHITE


func _fit_level_background() -> void:
	var vr: Rect2 = get_viewport().get_visible_rect()
	_level_background.position = Vector2.ZERO
	_level_background.size = vr.size


func _load_stage_config() -> void:
	if Router.is_tutorial:
		current_stage_config = {
			"name": "Handler Briefing",
			"type": "tutorial",
			"map_scene": "res://src/gameplay/maps/map_tutorial.tscn",
			"starting_gold": 0,
			"incident_chance": 0.0,
			"waves": [
				{"enemy_count": 3, "spawn_delay": 1.4, "health_multiplier": 1.0, "enemy_type": "basic"},
			],
		}
		current_wave_index = 0
		exam_questions_asked = 0
		exam_questions_correct = 0
		exam_history.clear()
		_asked_question_ids.clear()
		current_gold = 0
		_wave_total_enemies = _current_wave_enemy_count()
		_bkt_frozen = true
		print("[Stage] Loaded tutorial briefing map")
		return
	# Stage select is 0-based. ContentDB stage keys are 1-based string IDs.
	var stage_id: int = Router.active_stage_index + 1
	current_stage_config = StageManager.get_stage_config(stage_id)
	if current_stage_config.is_empty():
		current_stage_config = StageManager.get_stage_config(1)
	current_wave_index = 0
	exam_questions_asked = 0
	exam_questions_correct = 0
	exam_history.clear()
	_asked_question_ids.clear()
	if _is_summative():
		# Pass reward only. Granting this here would double-pay on exam success.
		current_gold = 0
	else:
		var gold_stored: Variant = current_stage_config.get("starting_gold", 5)
		current_gold = int(gold_stored)
	_bkt_frozen = PlayerManager.has_cleared_stage(stage_id)
	if _bkt_frozen:
		print("[BKT] Stage ", stage_id, " already cleared. P(L) frozen for this replay.")
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
		if not _tower_placer.tower_placed.is_connected(_on_tutorial_tower_placed):
			_tower_placer.tower_placed.connect(_on_tutorial_tower_placed)
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
	if not AssetManager.has_required_gameplay_assets():
		push_error("LevelManager: no cached enemy sprites; spawn skipped")
		return
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


func _is_diagnostic() -> bool:
	var type_stored: Variant = current_stage_config.get("type", "")
	return str(type_stored) == "diagnostic"


func _is_formative() -> bool:
	var type_stored: Variant = current_stage_config.get("type", "")
	return str(type_stored) == "formative"


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
			return "BRIEFING" if Router.is_tutorial else "PRE-MATCH"
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
	_submit_quiz_choice(_btn_correct.text)


func _on_quiz_wrong_pressed() -> void:
	_submit_quiz_choice(_btn_wrong.text)


func _submit_quiz_choice(picked: Variant) -> void:
	if _quiz_locked:
		return
	var is_correct: bool = _is_quiz_correct(picked)
	if Router.is_tutorial:
		var gate: String = _tutorial_gate_copy(is_correct)
		if not gate.is_empty():
			_quiz_feedback.text = gate
			_quiz_feedback.visible = true
			_apply_quiz_label(_quiz_feedback, Palette.GOLD, 9)
			return
	_show_quiz_feedback(is_correct, picked)
	_finish_quiz_answer(is_correct)


func _load_next_question() -> void:
	var question_bank: Dictionary = ContentDB.get_questions()
	if question_bank.is_empty():
		push_error("LevelManager: question bank is empty")
		return
	if _is_summative() and exam_questions_asked < _exam_question_count():
		current_question = _pick_summative_question()
	elif _is_formative():
		current_question = _pick_adaptive_question(true)
	else:
		current_question = _pick_adaptive_question(false)
	if current_question.is_empty():
		push_error("LevelManager: failed to load a question")
		return
	_present_current_question()
	_refresh_quiz_copy()


func _pick_adaptive_question(chase_weak: bool) -> Dictionary:
	var pool: Array[Dictionary] = _current_stage_question_pool()
	if pool.is_empty():
		push_error("LevelManager: stage question pool is empty")
		return {}
	var target_skill: String = str(pool[0].get("skill_id", "phishing"))
	if chase_weak:
		target_skill = PlayerManager.get_weakest_skill()
	var preferred: String = PlayerManager.preferred_difficulty(target_skill)
	if not chase_weak and randf() > 0.5:
		preferred = ""
	var selected: Dictionary = _select_from_pool(pool, preferred, _asked_question_ids)
	if selected.is_empty():
		return {}
	selected["skill_id"] = str(selected.get("skill_id", target_skill))
	_remember_question(selected, _asked_question_ids)
	print(
		"[BKT] TRACE stage=%d id=%s type=%s diff=%s P(L)=%.2f"
		% [
			_current_stage_id(),
			_question_key(selected),
			str(selected.get("type_id", "?")),
			str(selected.get("difficulty", "?")),
			PlayerManager.get_mastery(str(selected["skill_id"])),
		]
	)
	return selected


func _current_stage_id() -> int:
	return Router.active_stage_index + 1


func _current_stage_question_pool() -> Array[Dictionary]:
	var raw: Array = ContentDB.get_stage_question_pool(_current_stage_id())
	var pool: Array[Dictionary] = []
	for i in raw.size():
		var row: Variant = raw[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		pool.append((row as Dictionary).duplicate(true))
	if not pool.is_empty():
		return pool
	return _skill_question_pool(ContentDB.get_questions(), "phishing")


func _skill_question_pool(question_bank: Dictionary, skill_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	if not question_bank.has(skill_id):
		return pool
	var list_stored: Variant = question_bank[skill_id]
	if typeof(list_stored) != TYPE_ARRAY:
		return pool
	var q_list: Array = list_stored as Array
	for i in q_list.size():
		var q_stored: Variant = q_list[i]
		if typeof(q_stored) != TYPE_DICTIONARY:
			continue
		var q_dict: Dictionary = (q_stored as Dictionary).duplicate(true)
		if str(q_dict.get("skill_id", "")).is_empty():
			q_dict["skill_id"] = skill_id
		pool.append(q_dict)
	return pool


func _select_from_pool(pool: Array[Dictionary], preferred: String, seen: Array[String]) -> Dictionary:
	var unseen: Array[Dictionary] = _questions_not_in(pool, seen)
	var working: Array[Dictionary] = unseen if not unseen.is_empty() else pool
	if working.is_empty():
		return {}
	var ranked: PackedStringArray = PackedStringArray()
	if not preferred.is_empty():
		ranked.append(preferred)
		ranked.append_array(_adjacent_difficulties(preferred))
	for i in ranked.size():
		var matched: Array[Dictionary] = _questions_with_difficulty(working, ranked[i])
		if not matched.is_empty():
			return matched[randi() % matched.size()]
	return working[randi() % working.size()]


func _questions_not_in(pool: Array[Dictionary], seen: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in pool.size():
		if seen.has(_question_key(pool[i])):
			continue
		result.append(pool[i])
	return result


func _questions_with_difficulty(pool: Array[Dictionary], difficulty: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in pool.size():
		if _question_difficulty(pool[i]) == difficulty:
			result.append(pool[i])
	return result


func _question_difficulty(q: Dictionary) -> String:
	var value: String = str(q.get("difficulty", "")).strip_edges().to_lower()
	if value == "easy" or value == "medium" or value == "hard":
		return value
	return ""


func _adjacent_difficulties(preferred: String) -> PackedStringArray:
	match preferred:
		"easy":
			return PackedStringArray(["medium", "hard"])
		"hard":
			return PackedStringArray(["medium", "easy"])
		"medium":
			return PackedStringArray(["easy", "hard"])
		_:
			return PackedStringArray(["easy", "medium", "hard"])


func _remember_question(q: Dictionary, history: Array[String]) -> void:
	var key: String = _question_key(q)
	if key.is_empty() or history.has(key):
		return
	history.append(key)


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
			if typeof(q_stored) != TYPE_DICTIONARY:
				continue
			var q_dict: Dictionary = (q_stored as Dictionary).duplicate(true)
			if str(q_dict.get("skill_id", "")).is_empty():
				q_dict["skill_id"] = skill_id
			all_questions.append(q_dict)
	if all_questions.is_empty():
		push_error("LevelManager: question bank has no questions")
		return {}
	var valid_questions: Array[Dictionary] = []
	for i in all_questions.size():
		var q: Dictionary = all_questions[i]
		var qid: String = _question_key(q)
		if not exam_history.has(qid):
			valid_questions.append(q)
	if valid_questions.is_empty():
		exam_history.clear()
		valid_questions = all_questions
	var selected_q: Dictionary = valid_questions[randi() % valid_questions.size()]
	exam_history.append(_question_key(selected_q))
	_remember_question(selected_q, _asked_question_ids)
	return selected_q


func _question_key(q: Dictionary) -> String:
	var qid: String = str(q.get("id", "")).strip_edges()
	if not qid.is_empty():
		return qid
	return str(q.get("text", q.get("question", "")))


func _current_skill_id() -> String:
	var skill_id: String = str(current_question.get("skill_id", "phishing")).strip_edges()
	if skill_id.is_empty():
		return "phishing"
	return skill_id


func _record_bkt(skill_id: String, is_correct: bool, params: Dictionary = {}) -> void:
	if _bkt_frozen:
		print("[BKT] Replay — P(L) not updated.")
		return
	PlayerManager.update_mastery(skill_id, is_correct, params)


func _present_current_question() -> void:
	_quiz_selected.clear()
	_quiz_option_buttons.clear()
	_quiz_multi_select = false
	_set_quiz_locked(false)
	_quiz_feedback.visible = false
	_quiz_feedback.text = ""
	_clear_answer_list()
	var delivery: String = str(current_question.get("delivery", ""))
	var type_id: String = str(current_question.get("type_id", ""))
	var scenario_text: String = _format_scenario(current_question)
	_scenario_label.text = scenario_text
	_scenario_scroll.visible = not scenario_text.is_empty()
	_question_label.text = _format_prompt(current_question)
	if delivery == "multi_select" or type_id == "tap_trap_lines":
		_quiz_multi_select = true
		var lines_stored: Variant = current_question.get("email_lines", [])
		if typeof(lines_stored) == TYPE_ARRAY:
			var lines: Array = lines_stored as Array
			for i in lines.size():
				_add_quiz_option(str(lines[i]), i, true)
		_quiz_confirm.visible = true
		_refresh_confirm_state()
		return
	_quiz_confirm.visible = false
	if delivery == "binary_ab" or type_id == "trust_verdict":
		_add_quiz_option("PHISHING", "phishing", false)
		_add_quiz_option("LEGITIMATE", "legitimate", false)
		return
	if delivery == "true_false" or type_id == "safety_rule_tf":
		_add_quiz_option("TRUE", true, false)
		_add_quiz_option("FALSE", false, false)
		return
	var options_stored: Variant = current_question.get("options", [])
	if typeof(options_stored) == TYPE_ARRAY:
		var options: Array = options_stored as Array
		for i in options.size():
			_add_quiz_option(str(options[i]), i, false)
		return
	push_error("LevelManager: unsupported question delivery '%s'" % delivery)


func _format_scenario(q: Dictionary) -> String:
	var scene: Dictionary = {}
	var scene_stored: Variant = q.get("scenario", {})
	if typeof(scene_stored) == TYPE_DICTIONARY:
		scene = scene_stored as Dictionary
	# Sender Audit ships the address inside "scenario", triage ships it top level.
	var from_line: String = _first_text([q.get("from_line", ""), scene.get("from_line", "")])
	if not from_line.is_empty():
		return "FROM  %s" % from_line
	var preview: String = _first_text([q.get("preview", ""), scene.get("preview", "")])
	var content: String = _first_text([q.get("content", ""), scene.get("content", "")])
	if not preview.is_empty() or not content.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		if not preview.is_empty():
			parts.append(preview.to_upper())
		if not content.is_empty():
			parts.append(content)
		return "\n".join(parts)
	var lines: PackedStringArray = PackedStringArray()
	var sender: String = str(scene.get("from", "")).strip_edges()
	var subject: String = str(scene.get("subject", "")).strip_edges()
	var body: String = str(scene.get("body", "")).strip_edges()
	if not sender.is_empty():
		lines.append("FROM  %s" % sender)
	if not subject.is_empty():
		lines.append("SUBJ  %s" % subject)
	if not body.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append(body)
	return "\n".join(lines)


func _first_text(candidates: Array) -> String:
	for i in candidates.size():
		var value: String = str(candidates[i]).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _format_prompt(q: Dictionary) -> String:
	var prompt: String = str(q.get("question", "")).strip_edges()
	if not prompt.is_empty():
		return prompt
	var delivery: String = str(q.get("delivery", ""))
	if delivery == "binary_ab":
		return "Phishing or legitimate?"
	if delivery == "true_false":
		return str(q.get("text", "")).strip_edges()
	return str(q.get("prompt", q.get("text", ""))).strip_edges()


func _clear_answer_list() -> void:
	if _answer_list == null:
		return
	var kids: Array = _answer_list.get_children()
	for i in kids.size():
		var child: Node = kids[i] as Node
		if child == null:
			continue
		_answer_list.remove_child(child)
		child.queue_free()


func _add_quiz_option(label: String, value: Variant, toggle: bool) -> void:
	var button := Button.new()
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_quiz_choice(button)
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 10)
	if toggle:
		button.pressed.connect(_on_quiz_toggle_pressed.bind(button, value))
	else:
		button.pressed.connect(_on_quiz_option_pressed.bind(value))
	_answer_list.add_child(button)
	_quiz_option_buttons.append(button)


func _on_quiz_option_pressed(value: Variant) -> void:
	_submit_quiz_choice(value)


func _on_quiz_toggle_pressed(button: Button, value: Variant) -> void:
	if _quiz_locked:
		return
	var key: String = str(value)
	if _quiz_selected.has(key):
		_quiz_selected.erase(key)
	else:
		_quiz_selected[key] = value
	_paint_toggle_button(button, _quiz_selected.has(key))
	_refresh_confirm_state()


func _refresh_confirm_state() -> void:
	if not _quiz_multi_select:
		return
	var picked: int = _quiz_selected.size()
	if picked <= 0:
		_quiz_confirm.text = "TAP THE TRAP LINES FIRST"
		_quiz_confirm.disabled = true
		return
	_quiz_confirm.text = "SUBMIT  %d SELECTED" % picked
	_quiz_confirm.disabled = _quiz_locked


func _on_quiz_confirm_pressed() -> void:
	if _quiz_locked or not _quiz_multi_select:
		return
	var picked: Array = []
	var keys: Array = _quiz_selected.keys()
	for i in keys.size():
		picked.append(_quiz_selected[keys[i]])
	_submit_quiz_choice(picked)


func _paint_toggle_button(button: Button, selected: bool) -> void:
	var box: StyleBoxFlat = _pixel_box(
		Palette.GOLD if selected else Color(Palette.BG_PANEL_ALT, 0.96),
		Palette.TEXT_PRIMARY if selected else Palette.CYAN,
		0,
		2
	)
	box.border_width_left = 4
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD if selected else Palette.TEXT_PRIMARY)


func _is_quiz_correct(picked: Variant) -> bool:
	var delivery: String = str(current_question.get("delivery", ""))
	var type_id: String = str(current_question.get("type_id", ""))
	if delivery == "multi_select" or type_id == "tap_trap_lines":
		var expected: Array[int] = _int_list(current_question.get("correct_indices", []))
		var got: Array[int] = []
		if typeof(picked) == TYPE_ARRAY:
			got = _int_list(picked)
		expected.sort()
		got.sort()
		if expected.size() != got.size():
			return false
		for i in expected.size():
			if expected[i] != got[i]:
				return false
		return true
	if delivery == "binary_ab" or type_id == "trust_verdict":
		return str(picked).to_lower() == str(current_question.get("correct_answer", "")).to_lower()
	if delivery == "true_false" or type_id == "safety_rule_tf":
		return bool(picked) == bool(current_question.get("answer", false))
	if current_question.has("answer_index"):
		return int(picked) == int(current_question.get("answer_index", -1))
	return str(picked) == _quiz_correct_text


func _int_list(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	var rows: Array = raw as Array
	for i in rows.size():
		out.append(int(rows[i]))
	return out


func _show_quiz_feedback(is_correct: bool, picked: Variant) -> void:
	var note: String = ""
	if is_correct:
		note = str(current_question.get("correct_feedback", "")).strip_edges()
	else:
		note = str(current_question.get("incorrect_feedback", "")).strip_edges()
		var type_id: String = str(current_question.get("type_id", ""))
		if type_id == "consequence_choice" and typeof(picked) == TYPE_INT:
			if int(picked) == 0:
				note = str(current_question.get("click_debrief", note)).strip_edges()
			elif int(picked) == 1:
				note = str(current_question.get("ignore_debrief", note)).strip_edges()
	if note.is_empty():
		note = str(current_question.get("explanation", "")).strip_edges()
	if note.is_empty():
		note = "SECURE" if is_correct else "MISS"
	_quiz_feedback.text = note
	_quiz_feedback.visible = true
	_apply_quiz_label(_quiz_feedback, Palette.GREEN if is_correct else Palette.HEART, 9)


func _finish_quiz_answer(is_correct: bool) -> void:
	_set_quiz_locked(true)
	var skill_id: String = _current_skill_id()
	_resolve_quiz(PlayerManager.quiz_gold_reward(is_correct, skill_id), is_correct)


func _set_quiz_locked(locked: bool) -> void:
	_quiz_locked = locked
	_btn_correct.disabled = locked
	_btn_wrong.disabled = locked
	_quiz_confirm.disabled = locked
	for i in _quiz_option_buttons.size():
		var button: Button = _quiz_option_buttons[i]
		if button != null and is_instance_valid(button):
			button.disabled = locked
	if not locked:
		_refresh_confirm_state()


func _resolve_quiz(reward: int, is_correct: bool) -> void:
	if current_phase != GamePhase.PHASE_1_QUIZ:
		return
	_set_quiz_locked(true)
	exam_questions_asked += 1
	if is_correct:
		exam_questions_correct += 1
	_record_bkt(_current_skill_id(), is_correct, PlayerManager.bkt_params_from(current_question))
	if is_inside_tree():
		await get_tree().create_timer(1.05).timeout
	if current_phase != GamePhase.PHASE_1_QUIZ:
		return
	if Router.is_tutorial:
		_resolve_tutorial_quiz(reward, is_correct)
		return
	if not _is_summative():
		current_gold += reward
		print("[Economy] Quiz reward +" + str(reward) + " Gold. Current Gold: " + str(current_gold))
		_quiz_modal.visible = false
		update_hud()
		change_phase(GamePhase.PHASE_2_BUILD)
		return
	var exam_count: int = _exam_question_count()
	if exam_questions_asked < exam_count:
		_set_quiz_locked(false)
		_load_next_question()
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
	if Router.is_tutorial:
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


func _on_speed_pressed() -> void:
	_speed_mult = 2.0 if _speed_mult <= 1.5 else 1.0
	_apply_speed()


func _apply_speed() -> void:
	var quiz_open: bool = _quiz_modal.visible or current_phase == GamePhase.PHASE_1_QUIZ
	Engine.time_scale = 1.0 if quiz_open else _speed_mult
	var fast: bool = _speed_mult > 1.5
	_btn_speed.fill_key = "gold" if fast else "header"
	_btn_speed.border_key = "gold" if fast else "cyan"
	_btn_speed.queue_redraw()
	var icon := _btn_speed.get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.modulate = Palette.CYAN_400 if fast else Palette.CREAM


func _sync_phase_chrome() -> void:
	var building: bool = current_phase == GamePhase.PHASE_2_BUILD
	var live: bool = building or current_phase == GamePhase.PHASE_3_DEFEND
	if _tower_placer != null:
		_tower_placer.set_build_preview(building)
	_tower_card.visible = building
	_btn_speed.visible = live and not Router.is_tutorial
	if Router.is_tutorial:
		_btn_pause.visible = false
	_apply_speed()


func _refresh_quiz_copy() -> void:
	var exam := _is_summative()
	_quiz_file_label.text = "EXAM.DAT" if exam else "QTE.DAT"
	var type_label: String = str(current_question.get("type_label", "")).strip_edges()
	if type_label.is_empty():
		_quiz_event_label.text = "EXAM TRACE" if exam else "QUICK TRACE"
	else:
		_quiz_event_label.text = type_label.to_upper()
	_quiz_reward_hint.visible = not exam
	if not exam:
		var skill_id: String = _current_skill_id()
		var hit_gold: int = PlayerManager.quiz_gold_reward(true, skill_id)
		var miss_gold: int = PlayerManager.quiz_gold_reward(false, skill_id)
		var mastery_pct: int = clampi(int(round(PlayerManager.get_mastery(skill_id) * 100.0)), 0, 100)
		if _bkt_frozen:
			_quiz_reward_hint.text = "SECURE +%dG     MISS +%dG     P(L) %d%% LOCKED" % [hit_gold, miss_gold, mastery_pct]
		else:
			_quiz_reward_hint.text = "SECURE +%dG     MISS +%dG     P(L) %d%%" % [hit_gold, miss_gold, mastery_pct]
	_quiz_tap_hint.text = "TAP TO PASS" if exam else "TAP FAST"
	if exam or Router.is_tutorial:
		var current_q: int = exam_questions_asked + 1
		var total_q: int = 5 if Router.is_tutorial else _exam_question_count()
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
	_record_bkt("phishing", false)
	_spawn_penalty_enemies(3, "fast")
	_check_wave_cleared()


func _on_incident_button_pressed(btn: Button) -> void:
	if not _incident_modal.visible:
		return
	_cancel_incident_timeout()
	_incident_modal.visible = false
	var incident_hit: bool = btn == _current_incident_correct_btn
	_record_bkt("phishing", incident_hit)
	if incident_hit:
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
	_apply_quiz_label(_scenario_label, Palette.TEXT_SECONDARY, 10)
	_apply_quiz_label(_question_label, Palette.TEXT_PRIMARY, 12)
	_apply_quiz_label(_quiz_reward_hint, Palette.CYAN, 8)
	_apply_quiz_label(_quiz_tap_hint, Palette.TEXT_MUTED, 8)
	_apply_quiz_label(_quiz_feedback, Palette.CYAN, 9)
	_style_quiz_choice(_btn_correct)
	_style_quiz_choice(_btn_wrong)
	_style_quiz_submit(_quiz_confirm)
	var wave_frame := _wave_label.get_parent() as PanelContainer
	if wave_frame != null:
		var chip := _pixel_box(Color(Palette.BG_HEADER, 0.9), Palette.CYAN_DIM, 0, 2)
		chip.content_margin_left = 12.0
		chip.content_margin_right = 12.0
		chip.content_margin_top = 8.0
		chip.content_margin_bottom = 8.0
		wave_frame.add_theme_stylebox_override("panel", chip)


## Submit action, not an answer card. Solid gold and half width so players do not
## read it as one more tappable email line.
func _style_quiz_submit(button: Button) -> void:
	var normal := _pixel_box(Palette.GOLD, Palette.TEXT_ON_GOLD, 0, 2)
	var hover := _pixel_box(Palette.CYAN, Palette.TEXT_ON_GOLD, 0, 2)
	var disabled := _pixel_box(Color(Palette.BG_PANEL_ALT, 0.85), Palette.TEXT_MUTED, 0, 2)
	for box in [normal, hover, disabled]:
		box.content_margin_left = 22.0
		box.content_margin_right = 22.0
		box.content_margin_top = 10.0
		box.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_hover_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_pressed_color", Palette.TEXT_ON_GOLD)
	button.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	button.add_theme_font_size_override("font_size", 10)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(300, 44)


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
	_play_heart_hit()
	update_hud()
	if base_health <= 0:
		if Router.is_tutorial:
			base_health = 0
			update_hud()
			_finish_tutorial_defend()
			return
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
	if Router.is_tutorial:
		if base_health <= 0:
			_finish_tutorial_defend()
			return
		if active_enemies != 0 or not _wave_finished_spawning:
			return
		_finish_tutorial_defend()
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


func _on_tower_card_pressed() -> void:
	if _tower_placer == null:
		return
	_tower_placer.begin_place_drag()


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
	var move_gold: int = _tower_placer.move_cost if _tower_placer != null else 1
	var level: int = _selected_tower.upgrade_level
	_stats_label.text = (
		TowerBase.display_name_for(_selected_tower.current_type)
		+ "  LV %d/%d" % [level, TowerBase.MAX_UPGRADE_LEVEL]
		+ " | DMG " + str(_selected_tower.base_damage)
		+ " | MOVE " + str(move_gold) + "G"
	)
	_rebuild_upgrade_buttons(_selected_tower)


func _rebuild_upgrade_buttons(tower_node: TowerBase) -> void:
	_clear_upgrade_options()
	_upgrade_options.add_child(_make_power_upgrade_button(tower_node))
	var paths: Array[String] = TowerBase.paths_for(tower_node.current_type)
	if paths.is_empty():
		return
	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 12)
	path_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		path_row.add_child(btn)
	_upgrade_options.add_child(path_row)


func _make_power_upgrade_button(tower_node: TowerBase) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 40)
	_apply_panel_font(btn, 10)
	if not tower_node.can_upgrade():
		btn.text = "MAX LV %d" % TowerBase.MAX_UPGRADE_LEVEL
		btn.disabled = true
		return btn
	var cost: int = tower_node.next_upgrade_cost()
	var next_dmg: int = TowerBase.damage_at(tower_node.current_type, tower_node.upgrade_level + 1)
	btn.text = "UPGRADE LV %d  %dG  DMG %d>%d" % [
		tower_node.upgrade_level + 1,
		cost,
		tower_node.base_damage,
		next_dmg,
	]
	btn.pressed.connect(_on_power_upgrade_pressed.bind(tower_node))
	return btn


func _on_power_upgrade_pressed(tower_node: TowerBase) -> void:
	if tower_node == null or not is_instance_valid(tower_node):
		_hide_upgrade_ui()
		return
	if not tower_node.can_upgrade():
		print("[Upgrade] Tower is already at max level.")
		return
	var cost: int = tower_node.next_upgrade_cost()
	if current_gold < cost:
		print("[Economy] Insufficient gold. Need: " + str(cost))
		return
	current_gold -= cost
	tower_node.apply_power_upgrade()
	print(
		"[Economy] Tower LV %d. Damage %d. Remaining Gold: %d"
		% [tower_node.upgrade_level, tower_node.base_damage, current_gold]
	)
	update_hud()
	_on_tower_selected(tower_node)


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
			if Router.is_tutorial:
				get_viewport().set_input_as_handled()
				return
			_on_start_wave_pressed()
			get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if Router.is_tutorial:
		return
	if current_phase == GamePhase.GAME_OVER or current_phase == GamePhase.VICTORY:
		return
	if _pause_menu.visible:
		_pause_menu.resume_game()
	else:
		_pause_menu.pause_game()
