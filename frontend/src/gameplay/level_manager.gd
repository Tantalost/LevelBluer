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
const GLOBAL_PATCH_CHANCE: float = 0.4
const LOSS_CREDIT_PAYOUT: int = 10
const QUESTION_TIME_SEC: float = 20.0
const MULTI_SELECT_TIME_SEC: float = 30.0
const OPTION_KEYS: PackedStringArray = ["A", "B", "C", "D", "E", "F"]

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
var _exam_deck: Array[Dictionary] = []
var _exam_deck_index: int = 0
var _wave_questions_asked: int = 0
var _quiz_time_left: float = 0.0
var _quiz_time_limit: float = QUESTION_TIME_SEC
var _quiz_timer_running: bool = false
var _bkt_frozen: bool = false
var _wave_token: int = 0
var _wave_finished_spawning: bool = true
var _wave_kills: int = 0
var _wave_total_enemies: int = 0
var _is_wave_intermission: bool = false

@onready var _map_mount: Node2D = %MapMount
var _track: Path2D
var _map_endpoint_visuals: Node2D
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
@onready var _quiz_timer_row: HBoxContainer = %QuizTimerRow
@onready var _quiz_timer_label: Label = %QuizTimerLabel
@onready var _quiz_timer_bar: ProgressBar = %QuizTimerBar
@onready var _quiz_timer_value: Label = %QuizTimerValue
@onready var _scenario_scroll: ScrollContainer = %ScenarioScroll
@onready var _scenario_label: Label = %ScenarioLabel
@onready var _question_label: Label = %QuestionLabel
@onready var _quiz_reward_hint: Label = %QuizRewardHint
@onready var _quiz_tap_hint: Label = %QuizTapHint
@onready var _answer_list: GridContainer = %AnswerList
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
@onready var _shop_row: HBoxContainer = %ShopRow
@onready var _tower_card: TowerDeployCard = %TowerCard
@onready var _scanner_card: TowerDeployCard = %ScannerCard
@onready var _sandbox_card: TowerDeployCard = %SandboxCard
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
var _wave_intel_hidden: bool = false
var _global_patch_active: bool = false
var _defeat_started := false
var _match_kills := 0
var _defeat_overlay: CanvasLayer

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
	_tower_card.pressed.connect(_on_shop_card_pressed.bind(_tower_card))
	_scanner_card.pressed.connect(_on_shop_card_pressed.bind(_scanner_card))
	_sandbox_card.pressed.connect(_on_shop_card_pressed.bind(_sandbox_card))
	var basic_node_portrait: Texture2D = AssetManager.get_texture("tower_basic_node_base")
	if basic_node_portrait != null:
		_tower_card.portrait = basic_node_portrait
	_configure_shop_card(_tower_card, "base")
	_configure_shop_card(_scanner_card, "scanner")
	_configure_shop_card(_sandbox_card, "sandbox")
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
	await _mount_map()
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
		_tower_placer.move_cost = 1
	current_gold = maxi(current_gold, 6)
	_refresh_shop_cards()
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.start_build_coach()
	update_hud()
	change_phase(GamePhase.PHASE_2_BUILD)


func _on_tower_placed(tower: TowerBase) -> void:
	if _global_patch_active and tower != null and is_instance_valid(tower):
		tower.apply_global_patch()
	_refresh_shop_cards()
	_on_tutorial_tower_placed(tower)


func _on_tutorial_tower_placed(_tower: TowerBase) -> void:
	if not Router.is_tutorial or _tower_placer == null:
		return
	var placed: int = _tower_placer.placed_count()
	if placed == 1:
		PlayerManager.grant_tutorial_capacity_rank()
		_refresh_shop_cards()
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
	PlayerManager.grant_tutorial_capacity_rank()
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
	if not _quiz_timer_running or _quiz_locked:
		return
	_quiz_time_left = maxf(0.0, _quiz_time_left - delta)
	_update_quiz_timer_visual()
	if _quiz_time_left <= 0.0:
		_on_quiz_time_expired()


func change_phase(new_phase: GamePhase) -> void:
	# Terminal events can arrive together from a leak, collider, or wave callback.
	if _defeat_started or current_phase == GamePhase.VICTORY:
		return
	if new_phase != GamePhase.PHASE_3_DEFEND:
		_hide_incident()
	if new_phase != GamePhase.PHASE_1_QUIZ:
		_stop_question_timer()
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
			_wave_questions_asked = 0
			_wave_intel_hidden = false
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
			_defeat_started = true
			current_phase = GamePhase.GAME_OVER
			_wave_token += 1
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
				tip = "Exam score %d%%. Review the missed topics in Lessons, then retry." % accuracy_pct
			elif not weak_skill.is_empty():
				tip = "Critical weakness: %s. Train it in Lessons before you deploy again." % weak_skill.capitalize()
			print("[LevelManager] Entering GAME_OVER. Match lost.")
			_award_loss_credits()
			if base_health <= 0:
				_present_base_defeat(tip)
			else:
				# A failed exam is not a destroyed base; retain its advisory result.
				Router.open_defeat(tip, weak_skill, LOSS_CREDIT_PAYOUT)
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
			_present_stage_clear(accuracy, credit_payout)
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


func _award_loss_credits() -> void:
	PlayerManager.add_credits(LOSS_CREDIT_PAYOUT)


func _present_stage_clear(accuracy: float, credits: int) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_pause_menu.hide()
	if _tower_placer != null:
		_tower_placer.clear_selection()
		_tower_placer.set_build_preview(false)
	# Match the defeat presentation: preserve the completed map, freeze actors,
	# hide gameplay chrome, then reveal results over the battlefield.
	get_parent().get_node("Environment").process_mode = Node.PROCESS_MODE_DISABLED
	get_parent().get_node("GameplayCanvas").visible = false
	_player_base.set_deferred("monitoring", false)
	_defeat_overlay = preload("res://src/ui/screens/victory/base_defeat_overlay.gd").new()
	_defeat_overlay.name = "StageClearOverlay"
	get_parent().add_child(_defeat_overlay)
	_defeat_overlay.configure({
		"won": true,
		"stage": Router.active_stage_index + 1,
		"credits": credits,
		"kills": _match_kills,
		"accuracy": accuracy,
		"final_stage": _is_module_final(),
	})
	_defeat_overlay.action_requested.connect(_on_defeat_action)


func _present_base_defeat(tip: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_pause_menu.hide()
	if _tower_placer != null:
		_tower_placer.clear_selection()
		_tower_placer.set_build_preview(false)
	# Freeze actors and deployment while the map remains mounted behind results.
	get_parent().get_node("Environment").process_mode = Node.PROCESS_MODE_DISABLED
	get_parent().get_node("GameplayCanvas").visible = false
	_player_base.set_deferred("monitoring", false)
	if is_instance_valid(_map_endpoint_visuals):
		_map_endpoint_visuals.call("play_home_destruction")
	add_camera_shake(20)
	AudioManager.play_sfx("explosion")
	_defeat_overlay = preload("res://src/ui/screens/victory/base_defeat_overlay.gd").new()
	_defeat_overlay.name = "BaseDefeatOverlay"
	get_parent().add_child(_defeat_overlay)
	_defeat_overlay.configure({
		"stage": Router.active_stage_index + 1,
		"credits": LOSS_CREDIT_PAYOUT,
		"wave": current_wave_index + 1,
		"waves": maxi(1, _wave_count()),
		"kills": _match_kills,
		"tip": tip,
	})
	_defeat_overlay.action_requested.connect(_on_defeat_action)


func _on_defeat_action(action: StringName) -> void:
	match action:
		&"upgrade": Router.open_defeat_upgrades()
		&"restart": Router.restart_level()
		&"next": Router.advance_level()
		&"certificate": Router.open_certificate_screen()
		&"lessons": Router.open_lessons()
		&"back": Router.return_to_stage_select()


func update_hud() -> void:
	_phase_label.text = _phase_display_name()
	if current_phase == GamePhase.PHASE_1_QUIZ:
		_phase_label.add_theme_color_override("font_color", Palette.GOLD)
	else:
		_phase_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_gold_label.text = "GOLD  " + str(current_gold)
	_refresh_shop_cards()
	_wave_label.text = str(_wave_kills) + "/" + str(_wave_total_enemies)
	if Router.is_tutorial:
		_map_label.text = "TRAINING"
		return
	var wave_n: int = current_wave_index + 1
	var waves: int = maxi(1, _wave_count())
	var types: String = _wave_intel_text()
	if str(_current_wave_data().get("enemy_type", "")) == "boss":
		_map_label.text = "MAP A%d  BOSS  %s" % [Router.active_stage_index + 1, types]
	else:
		_map_label.text = "MAP A%d  W%d/%d  %s" % [Router.active_stage_index + 1, wave_n, waves, types]


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
	_sync_base_visual()


func _sync_base_visual() -> void:
	if _map_endpoint_visuals == null or not is_instance_valid(_map_endpoint_visuals):
		return
	var max_health: int = _heart_icons.size() if not _heart_icons.is_empty() else 5
	_map_endpoint_visuals.call("set_health", base_health, max_health)


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
		_wave_questions_asked = 0
		exam_history.clear()
		_asked_question_ids.clear()
		_exam_deck.clear()
		_exam_deck_index = 0
		current_gold = 0
		_wave_total_enemies = _current_wave_enemy_count()
		_wave_intel_hidden = false
		_global_patch_active = false
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
	_wave_questions_asked = 0
	exam_history.clear()
	_asked_question_ids.clear()
	_exam_deck.clear()
	_exam_deck_index = 0
	var gold_stored: Variant = current_stage_config.get("starting_gold", 5)
	current_gold = _apply_intel_bonus_gold(int(gold_stored))
	_wave_intel_hidden = false
	_global_patch_active = false
	_bkt_frozen = PlayerManager.has_cleared_stage(stage_id)
	if _bkt_frozen:
		print("[BKT] Stage ", stage_id, " already cleared. P(L) frozen for this replay.")
	if _is_summative():
		_exam_deck = _build_exam_deck()
		_exam_deck_index = 0
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
	# LevelManager readies before Environment in this scene. Wait for the map
	# builder before reading its endpoints and presentation flags.
	if not map_root.is_node_ready():
		await map_root.ready
	var fallback_world := get_parent().get_node_or_null("Environment/LevelWorld") as CanvasItem
	if fallback_world != null:
		fallback_world.visible = not bool(map_root.get_meta("authored_environment", false))
	_track = _resolve_track()
	_tower_placer = _find_tower_placer(map_root)
	if _tower_placer != null:
		_tower_placer.bind_level_manager(self)
		if not _tower_placer.tower_selected.is_connected(_on_tower_selected):
			_tower_placer.tower_selected.connect(_on_tower_selected)
		if not _tower_placer.tower_placed.is_connected(_on_tower_placed):
			_tower_placer.tower_placed.connect(_on_tower_placed)
	var builder := map_root as MapBuilder
	if builder != null:
		var end_pos: Vector2 = builder.get_end_global_position()
		if end_pos != Vector2.ZERO:
			_player_base.global_position = end_pos
	_player_base.scale = map_root.call("get_gameplay_scale") if map_root.has_method("get_gameplay_scale") else Vector2.ONE
	_map_endpoint_visuals = map_root.get_node_or_null("MapEndpointVisuals") as Node2D
	_sync_base_visual()


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


func _questions_per_wave() -> int:
	var fallback: int = 3
	if _is_summative():
		fallback = maxi(1, int(ceil(float(_exam_question_count()) / float(maxi(1, _wave_count())))))
	var stored: Variant = current_stage_config.get("questions_per_wave", fallback)
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
	else:
		current_question = _pick_adaptive_question()
	if current_question.is_empty():
		push_error("LevelManager: failed to load a question")
		return
	_present_current_question()
	_refresh_quiz_copy()
	_start_question_timer()


func _start_question_timer() -> void:
	if Router.is_tutorial:
		_quiz_timer_row.hide()
		_quiz_timer_running = false
		return
	_quiz_timer_row.show()
	var configured: float = float(current_stage_config.get("question_time_sec", QUESTION_TIME_SEC))
	_quiz_time_limit = MULTI_SELECT_TIME_SEC if _quiz_multi_select else maxf(5.0, configured)
	_quiz_time_left = _quiz_time_limit
	_quiz_timer_bar.max_value = _quiz_time_limit
	_quiz_timer_running = true
	_update_quiz_timer_visual()


func _stop_question_timer() -> void:
	_quiz_timer_running = false


func _update_quiz_timer_visual() -> void:
	_quiz_timer_bar.value = _quiz_time_left
	_quiz_timer_value.text = "%.1f" % _quiz_time_left
	var urgent: bool = _quiz_time_left <= 5.0
	_quiz_timer_bar.modulate = Palette.DANGER if urgent else Color.WHITE
	_quiz_timer_value.add_theme_color_override("font_color", Palette.DANGER if urgent else Palette.CYAN_300)
	_quiz_timer_label.text = "HURRY" if urgent else "TRACE"


func _on_quiz_time_expired() -> void:
	if current_phase != GamePhase.PHASE_1_QUIZ or _quiz_locked:
		return
	_quiz_timer_running = false
	_quiz_feedback.text = "TRACE EXPIRED — COUNTED AS A MISS"
	_quiz_feedback.visible = true
	_apply_quiz_label(_quiz_feedback, Palette.DANGER, 10)
	_finish_quiz_answer(false)


func _pick_adaptive_question() -> Dictionary:
	var module_id: String = _current_module_id()
	var skill_id: String = _current_module_skill()
	if skill_id.is_empty():
		push_error("LevelManager: no BKT skill for module %s" % module_id)
		return {}
	var pool: Array[Dictionary] = _module_question_pool()
	if pool.is_empty():
		push_error("LevelManager: TRACE bank unavailable for %s" % module_id)
		return {}
	var seen: Array[String] = PlayerManager.get_trace_seen(module_id)
	var missed: Array[String] = PlayerManager.get_trace_missed(module_id)
	var preferred: String = PlayerManager.preferred_difficulty(skill_id)
	var unseen: Array[Dictionary] = _questions_not_in(pool, seen)
	var working: Array[Dictionary] = unseen
	var reason_prefix: String = "preferred_difficulty+least_used_type"
	if working.is_empty():
		var review: Array[Dictionary] = _questions_with_ids(pool, missed)
		review = _questions_not_in(review, _asked_question_ids)
		if review.is_empty():
			working = _questions_not_in(pool, _asked_question_ids)
			reason_prefix = "review_seen"
		else:
			working = review
			reason_prefix = "review_missed"
		if working.is_empty():
			working = pool.duplicate()
	var usage_seen: Array[String] = seen.duplicate()
	for i in _asked_question_ids.size():
		var asked_id: String = _asked_question_ids[i]
		if not usage_seen.has(asked_id):
			usage_seen.append(asked_id)
	var selected: Dictionary = {}
	var ranked: PackedStringArray = _ranked_difficulties(preferred, working, pool, usage_seen)
	var selected_reason: String = reason_prefix
	for i in ranked.size():
		var difficulty: String = ranked[i]
		var matched: Array[Dictionary] = _questions_with_difficulty(working, difficulty)
		if matched.is_empty():
			continue
		selected = _pick_type_balanced(matched, usage_seen, pool)
		if selected.is_empty():
			continue
		if difficulty != preferred:
			selected_reason = "no_unseen_%s" % preferred
			if reason_prefix.begins_with("review"):
				selected_reason = "%s+%s" % [reason_prefix, selected_reason]
		elif reason_prefix.begins_with("review"):
			selected_reason = reason_prefix
		break
	if selected.is_empty() and not working.is_empty():
		selected = _pick_type_balanced(working, usage_seen, pool)
		selected_reason = "no_unseen_%s" % preferred
	if selected.is_empty():
		return {}
	selected["skill_id"] = str(selected.get("skill_id", skill_id))
	_remember_question(selected, _asked_question_ids)
	var unseen_remaining: int = _questions_not_in(pool, seen).size()
	if not seen.has(_question_key(selected)):
		unseen_remaining = maxi(0, unseen_remaining - 1)
	print("[TRACE SELECT]")
	print("module=%s" % module_id)
	print("skill=%s" % skill_id)
	print("stage=%d" % _current_stage_id())
	print("P(L)=%.2f" % PlayerManager.get_mastery(skill_id))
	print("preferred=%s" % preferred)
	print("selected=%s" % _question_key(selected))
	print("type=%s" % _question_type_id(selected))
	print("difficulty=%s" % _question_difficulty(selected))
	print("unseen_remaining=%d" % unseen_remaining)
	print("reason=%s" % selected_reason)
	if _question_difficulty(selected) != preferred:
		print("selected_difficulty=%s" % _question_difficulty(selected))
	return selected


func _current_stage_id() -> int:
	return Router.active_stage_index + 1


func _current_stage_question_pool() -> Array[Dictionary]:
	var module_id: String = _current_module_id()
	var raw: Array = ContentDB.get_stage_question_pool(_current_stage_id(), module_id)
	var pool: Array[Dictionary] = []
	for i in raw.size():
		var row: Variant = raw[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = (row as Dictionary).duplicate(true)
		if str(item.get("module_id", module_id)) != module_id:
			continue
		pool.append(item)
	if not pool.is_empty():
		return pool
	var skill_id: String = _current_module_skill()
	if skill_id.is_empty():
		return []
	var fallback: Array[Dictionary] = _skill_question_pool(ContentDB.get_questions(), skill_id)
	var scoped: Array[Dictionary] = []
	for i in fallback.size():
		var item: Dictionary = fallback[i]
		if str(item.get("module_id", module_id)) != module_id:
			continue
		scoped.append(item)
	return scoped


func _module_question_pool() -> Array[Dictionary]:
	var module_id: String = _current_module_id()
	var skill_id: String = _current_module_skill()
	if skill_id.is_empty():
		return []
	var raw: Array = ContentDB.get_module_questions(module_id)
	var pool: Array[Dictionary] = []
	for i in raw.size():
		var row: Variant = raw[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = (row as Dictionary).duplicate(true)
		if str(item.get("module_id", module_id)).strip_edges() != module_id:
			continue
		if str(item.get("skill_id", "")).strip_edges().is_empty():
			item["skill_id"] = skill_id
		if str(item.get("skill_id", "")).strip_edges().to_lower() != skill_id:
			continue
		pool.append(item)
	return pool


func _current_module_id() -> String:
	var module_id: String = str(Router.active_module_id).strip_edges()
	if module_id.is_empty():
		return "mod_01"
	return module_id


func _current_module_skill() -> String:
	var skill_id: String = ContentDB.skill_for_module(_current_module_id())
	if not skill_id.is_empty():
		return skill_id
	match _current_module_id():
		"mod_01":
			return "phishing"
		"mod_02":
			return "smishing"
		"mod_03":
			return "vishing"
		"mod_04":
			return "pretexting"
		"mod_05":
			return "baiting"
		_:
			return ""


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


func _questions_not_in(pool: Array[Dictionary], seen: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in pool.size():
		if seen.has(_question_key(pool[i])):
			continue
		result.append(pool[i])
	return result


func _questions_with_ids(pool: Array[Dictionary], wanted_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if wanted_ids.is_empty():
		return result
	for i in pool.size():
		if wanted_ids.has(_question_key(pool[i])):
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


func _question_type_id(q: Dictionary) -> String:
	var type_id: String = str(q.get("type_id", "")).strip_edges()
	if type_id.is_empty():
		return "other"
	return type_id


func _type_usage_counts(pool: Array[Dictionary], seen: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for i in pool.size():
		if not seen.has(_question_key(pool[i])):
			continue
		var type_id: String = _question_type_id(pool[i])
		counts[type_id] = int(counts.get(type_id, 0)) + 1
	return counts


func _pick_type_balanced(candidates: Array[Dictionary], usage_seen: Array[String], pool: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}
	var counts: Dictionary = _type_usage_counts(pool, usage_seen)
	var min_count: int = 999999
	for i in candidates.size():
		var type_id: String = _question_type_id(candidates[i])
		var used: int = int(counts.get(type_id, 0))
		if used < min_count:
			min_count = used
	var best: Array[Dictionary] = []
	for i in candidates.size():
		var type_id: String = _question_type_id(candidates[i])
		if int(counts.get(type_id, 0)) == min_count:
			best.append(candidates[i])
	if best.is_empty():
		return candidates[randi() % candidates.size()]
	return best[randi() % best.size()]


func _balanced_candidate_count(candidates: Array[Dictionary], usage_seen: Array[String], pool: Array[Dictionary]) -> int:
	if candidates.is_empty():
		return 0
	var counts: Dictionary = _type_usage_counts(pool, usage_seen)
	var min_count: int = 999999
	for i in candidates.size():
		var used: int = int(counts.get(_question_type_id(candidates[i]), 0))
		if used < min_count:
			min_count = used
	var total: int = 0
	for i in candidates.size():
		if int(counts.get(_question_type_id(candidates[i]), 0)) == min_count:
			total += 1
	return total


func _ranked_difficulties(preferred: String, working: Array[Dictionary], pool: Array[Dictionary], usage_seen: Array[String]) -> PackedStringArray:
	match preferred:
		"easy":
			return PackedStringArray(["easy", "medium", "hard"])
		"hard":
			return PackedStringArray(["hard", "medium", "easy"])
		"medium":
			if not _questions_with_difficulty(working, "medium").is_empty():
				return PackedStringArray(["medium", "easy", "hard"])
			var easy_best: int = _balanced_candidate_count(_questions_with_difficulty(working, "easy"), usage_seen, pool)
			var hard_best: int = _balanced_candidate_count(_questions_with_difficulty(working, "hard"), usage_seen, pool)
			if hard_best > easy_best:
				return PackedStringArray(["hard", "easy"])
			if easy_best > hard_best:
				return PackedStringArray(["easy", "hard"])
			if randf() < 0.5:
				return PackedStringArray(["easy", "hard"])
			return PackedStringArray(["hard", "easy"])
		_:
			return PackedStringArray(["easy", "medium", "hard"])


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


func _take_balanced_count(candidates: Array[Dictionary], needed: int, type_counts: Dictionary) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = candidates.duplicate()
	remaining.shuffle()
	var picked: Array[Dictionary] = []
	while picked.size() < needed and not remaining.is_empty():
		var min_count: int = 999999
		for i in remaining.size():
			var used: int = int(type_counts.get(_question_type_id(remaining[i]), 0))
			if used < min_count:
				min_count = used
		var chosen_index: int = -1
		for i in remaining.size():
			if int(type_counts.get(_question_type_id(remaining[i]), 0)) == min_count:
				chosen_index = i
				break
		if chosen_index < 0:
			break
		var chosen: Dictionary = remaining[chosen_index]
		picked.append(chosen)
		remaining.remove_at(chosen_index)
		var type_id: String = _question_type_id(chosen)
		type_counts[type_id] = int(type_counts.get(type_id, 0)) + 1
	return picked


func _build_exam_deck() -> Array[Dictionary]:
	var module_id: String = _current_module_id()
	var pool: Array[Dictionary] = _module_question_pool()
	if pool.is_empty():
		push_error("LevelManager: TRACE exam bank unavailable for %s" % module_id)
		return []
	var type_counts: Dictionary = {}
	var picked: Array[Dictionary] = []
	var picked_ids: Dictionary = {}
	var quotas: Array = [["easy", 4], ["medium", 7], ["hard", 4]]
	for q in quotas.size():
		var difficulty: String = str(quotas[q][0])
		var needed: int = int(quotas[q][1])
		var available: Array[Dictionary] = []
		var matched: Array[Dictionary] = _questions_with_difficulty(pool, difficulty)
		for i in matched.size():
			var qid: String = _question_key(matched[i])
			if picked_ids.has(qid):
				continue
			available.append(matched[i])
		var taken: Array[Dictionary] = _take_balanced_count(available, needed, type_counts)
		for i in taken.size():
			var item: Dictionary = taken[i]
			picked.append(item)
			picked_ids[_question_key(item)] = true
	if picked.size() < 15:
		var leftover: Array[Dictionary] = []
		for i in pool.size():
			var qid: String = _question_key(pool[i])
			if picked_ids.has(qid):
				continue
			leftover.append(pool[i])
		var filler: Array[Dictionary] = _take_balanced_count(leftover, 15 - picked.size(), type_counts)
		for i in filler.size():
			picked.append(filler[i])
			picked_ids[_question_key(filler[i])] = true
	picked.shuffle()
	var easy_n: int = 0
	var medium_n: int = 0
	var hard_n: int = 0
	var unique_ids: Dictionary = {}
	for i in picked.size():
		unique_ids[_question_key(picked[i])] = true
		match _question_difficulty(picked[i]):
			"easy":
				easy_n += 1
			"hard":
				hard_n += 1
			_:
				medium_n += 1
	print("[TRACE EXAM]")
	print("module=%s" % module_id)
	print("questions=%d" % picked.size())
	print("easy=%d" % easy_n)
	print("medium=%d" % medium_n)
	print("hard=%d" % hard_n)
	print("unique=%d" % unique_ids.size())
	return picked


func _pick_summative_question() -> Dictionary:
	if _exam_deck.is_empty():
		_exam_deck = _build_exam_deck()
		_exam_deck_index = 0
	if _exam_deck_index >= _exam_deck.size():
		push_error("LevelManager: TRACE exam deck exhausted")
		return {}
	var selected_q: Dictionary = _exam_deck[_exam_deck_index]
	_exam_deck_index += 1
	var skill_id: String = _current_module_skill()
	if not skill_id.is_empty():
		selected_q["skill_id"] = str(selected_q.get("skill_id", skill_id))
	exam_history.append(_question_key(selected_q))
	_remember_question(selected_q, _asked_question_ids)
	return selected_q


func _question_key(q: Dictionary) -> String:
	var qid: String = str(q.get("id", "")).strip_edges()
	if not qid.is_empty():
		return qid
	return str(q.get("text", q.get("question", "")))


func _current_skill_id() -> String:
	var skill_id: String = str(current_question.get("skill_id", "")).strip_edges()
	if skill_id.is_empty():
		skill_id = _current_module_skill()
	if not skill_id.is_empty():
		return skill_id
	return "phishing"


func _malicious_verdict_label(q: Dictionary) -> String:
	var module_id: String = str(q.get("module_id", _current_module_id())).strip_edges().to_lower()
	var skill_id: String = str(q.get("skill_id", "")).strip_edges().to_lower()
	if module_id == "mod_05" or skill_id == "baiting":
		return "BAITING"
	if module_id == "mod_04" or skill_id == "pretexting":
		return "PRETEXTING"
	if module_id == "mod_03" or skill_id == "vishing":
		return "VISHING"
	if module_id == "mod_02" or skill_id == "smishing":
		return "SMISHING"
	return "PHISHING"


func _display_type_label(q: Dictionary) -> String:
	var type_id: String = str(q.get("type_id", "")).strip_edges()
	var type_label: String = str(q.get("type_label", "")).strip_edges()
	var module_id: String = str(q.get("module_id", _current_module_id())).strip_edges().to_lower()
	var skill_id: String = str(q.get("skill_id", "")).strip_edges().to_lower()
	if module_id == "mod_05" or skill_id == "baiting":
		match type_id:
			"sender_audit":
				return "Source Audit"
			"url_spoof":
				return "Source & Action Check"
			"tap_trap_lines":
				return "Tap the Bait Lines"
			"inbox_triage":
				return "Offer Triage"
			"consequence_choice":
				return "Before You Plug or Download"
	if module_id == "mod_04" or skill_id == "pretexting":
		match type_id:
			"sender_audit":
				return "Role Audit"
			"url_spoof":
				return "Verification Check"
			"tap_trap_lines":
				return "Tap the Story Lines"
			"inbox_triage":
				return "Situation Triage"
			"consequence_choice":
				return "Before You Help"
	if module_id == "mod_03" or skill_id == "vishing":
		match type_id:
			"sender_audit":
				return "Caller Audit"
			"url_spoof":
				return "Callback Check"
			"inbox_triage":
				return "Call Triage"
			"consequence_choice":
				return "Before You Speak"
	if not type_label.is_empty():
		return type_label
	return type_id


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
		_add_quiz_option(_malicious_verdict_label(current_question), "phishing", false)
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
	return preload("res://src/gameplay/quiz_content.gd")._format_scenario(q)


func _first_text(candidates: Array) -> String:
	for i in candidates.size():
		var value: String = str(candidates[i]).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _format_prompt(q: Dictionary) -> String:
	return preload("res://src/gameplay/quiz_content.gd")._format_prompt(q)


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
	var button: Button = Button.new()
	var option_index: int = _quiz_option_buttons.size()
	var option_key: String = OPTION_KEYS[option_index] if option_index < OPTION_KEYS.size() else str(option_index + 1)
	button.text = "%s   %s" % [option_key, label]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_quiz_choice(button)
	button.custom_minimum_size = Vector2(0, 74)
	button.add_theme_font_size_override("font_size", 12)
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
		Palette.PRIMARY_BLUE if selected else Palette.NAVY_900,
		Palette.CYAN_300 if selected else Palette.CYAN_400,
		0,
		2
	)
	box.border_width_left = 6
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Palette.CREAM)


func _is_quiz_correct(picked: Variant) -> bool:
	return preload("res://src/gameplay/quiz_content.gd").grade(current_question, picked, _quiz_correct_text)


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
	_stop_question_timer()
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
	_wave_questions_asked += 1
	if is_correct:
		exam_questions_correct += 1
	_record_bkt(_current_skill_id(), is_correct, PlayerManager.bkt_params_from(current_question))
	if not Router.is_tutorial:
		PlayerManager.record_trace_result(_current_module_id(), _question_key(current_question), is_correct)
	if is_inside_tree():
		await get_tree().create_timer(1.05).timeout
	if current_phase != GamePhase.PHASE_1_QUIZ:
		return
	if Router.is_tutorial:
		_resolve_tutorial_quiz(reward, is_correct)
		return
	if is_correct:
		_try_grant_global_patch()
	else:
		_wave_intel_hidden = true
	if not _is_summative():
		current_gold += reward
		print("[Economy] Quiz reward +" + str(reward) + " Gold. Current Gold: " + str(current_gold))
	update_hud()
	var exam_count: int = _exam_question_count()
	var more_in_wave: bool = _wave_questions_asked < _questions_per_wave()
	var more_in_exam: bool = not _is_summative() or exam_questions_asked < exam_count
	if more_in_wave and more_in_exam:
		_set_quiz_locked(false)
		_load_next_question()
		update_hud()
		return
	_quiz_modal.visible = false
	if _is_summative() and exam_questions_asked >= exam_count:
		var accuracy: float = float(exam_questions_correct) / float(exam_count)
		if accuracy < _exam_required_score():
			print("[Exam] Score below target. Final result follows wave 3: " + str(accuracy))
		else:
			print("[Exam] Passing score secured: " + str(accuracy))
	change_phase(GamePhase.PHASE_2_BUILD)


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
	_shop_row.visible = building
	_refresh_shop_cards()
	_btn_speed.visible = live and not Router.is_tutorial
	if Router.is_tutorial:
		_btn_pause.visible = false
	_apply_speed()


func _refresh_quiz_copy() -> void:
	var exam: bool = _is_summative()
	_quiz_file_label.text = "EXAM.DAT" if exam else "QTE.DAT"
	var type_label: String = _display_type_label(current_question)
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
	_quiz_tap_hint.text = "TAKE YOUR TIME — FOLLOW THE HANDLER" if Router.is_tutorial else "SELECT BEFORE THE TRACE EXPIRES"
	if Router.is_tutorial:
		_exam_progress_label.text = "TRACE  %d / 5" % (exam_questions_asked + 1)
	elif exam:
		_exam_progress_label.text = "EXAM  %d / %d     WAVE  %d / %d" % [
			exam_questions_asked + 1,
			_exam_question_count(),
			current_wave_index + 1,
			_wave_count(),
		]
	else:
		_exam_progress_label.text = "WAVE  %d / %d     TRACE  %d / %d" % [
			current_wave_index + 1,
			_wave_count(),
			_wave_questions_asked + 1,
			_questions_per_wave(),
		]
	_exam_progress_label.visible = true


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
	print("[Incident] Ignored! Auto-failing with System Lag.")
	_record_bkt("phishing", false)
	_apply_system_lag()
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
		print("[Incident] Wrong! Applying System Lag.")
		_apply_system_lag()
	_current_incident_correct_btn = null
	_check_wave_cleared()


func _apply_intel_bonus_gold(base_gold: int) -> int:
	var module_id: String = PlayerManager.intel_module_for_stage(Router.active_stage_index + 1)
	return PlayerManager.consume_intel_bonus_gold(base_gold, module_id)


func _try_grant_global_patch() -> void:
	if _global_patch_active:
		return
	if randf() > GLOBAL_PATCH_CHANCE:
		return
	_global_patch_active = true
	get_tree().call_group("towers", "apply_global_patch")
	if _quiz_feedback.visible:
		_quiz_feedback.text = str(_quiz_feedback.text) + "  GLOBAL PATCH"
	print("[Patch] Global Patch applied for this match.")


func _apply_system_lag() -> void:
	get_tree().call_group("towers", "apply_incident_lag")


func _wave_intel_text() -> String:
	if _wave_intel_hidden:
		return "? ? ?"
	var wave: Dictionary = _current_wave_data()
	var tokens: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	var mix_stored: Variant = wave.get("enemy_mix", [])
	if typeof(mix_stored) == TYPE_ARRAY:
		var mix: Array = mix_stored as Array
		for i in mix.size():
			var token: String = str(mix[i]).strip_edges().to_upper()
			if token.is_empty() or seen.has(token):
				continue
			seen[token] = true
			tokens.append(token)
	if tokens.size() == 0:
		var enemy_type: String = str(wave.get("enemy_type", "basic")).strip_edges().to_upper()
		if enemy_type.is_empty():
			enemy_type = "BASIC"
		tokens.append(enemy_type)
	return " ".join(tokens)


func _style_quiz_ui() -> void:
	var window: StyleBoxFlat = _pixel_box(Palette.NAVY_900, Palette.CYAN_400, 0, 3)
	window.shadow_color = Color(Palette.DEEP_SPACE, 0.82)
	window.shadow_size = 5
	window.shadow_offset = Vector2(8, 8)
	_quiz_window.add_theme_stylebox_override("panel", window)
	_quiz_title_bar.add_theme_stylebox_override("panel", _pixel_box(Palette.PRIMARY_BLUE, Palette.CYAN_300, 0, 0))
	_quiz_well.add_theme_stylebox_override("panel", _pixel_box(Color(Palette.NAVY_800, 0.98), Palette.NAVY_700, 0, 0))
	_quiz_led.color = Palette.GOLD
	_apply_quiz_label(_quiz_file_label, Palette.CREAM, 11)
	_apply_quiz_label(_quiz_event_label, Palette.CREAM, 11)
	_apply_quiz_label(_exam_progress_label, Palette.CYAN_300, 10)
	_apply_quiz_label(_quiz_timer_label, Palette.CYAN_300, 9)
	_apply_quiz_label(_quiz_timer_value, Palette.CYAN_300, 10)
	_apply_quiz_label(_scenario_label, Palette.CYAN_300, 11)
	_apply_quiz_label(_question_label, Palette.CREAM, 14)
	_apply_quiz_label(_quiz_reward_hint, Palette.SUCCESS, 9)
	_apply_quiz_label(_quiz_tap_hint, Palette.CYAN_300, 8)
	_apply_quiz_label(_quiz_feedback, Palette.CYAN_400, 10)
	var timer_bg: StyleBoxFlat = _pixel_box(Palette.DEEP_SPACE, Palette.NAVY_700, 0, 1)
	var timer_fill: StyleBoxFlat = _pixel_box(Palette.CYAN_400, Palette.CYAN_300, 0, 0)
	_quiz_timer_bar.add_theme_stylebox_override("background", timer_bg)
	_quiz_timer_bar.add_theme_stylebox_override("fill", timer_fill)
	_style_quiz_choice(_btn_correct)
	_style_quiz_choice(_btn_wrong)
	_style_quiz_submit(_quiz_confirm)
	var wave_frame: PanelContainer = _wave_label.get_parent() as PanelContainer
	if wave_frame != null:
		var chip: StyleBoxFlat = _pixel_box(Color(Palette.BG_HEADER, 0.9), Palette.CYAN_DIM, 0, 2)
		chip.content_margin_left = 12.0
		chip.content_margin_right = 12.0
		chip.content_margin_top = 8.0
		chip.content_margin_bottom = 8.0
		wave_frame.add_theme_stylebox_override("panel", chip)


## Submit action, not an answer card. Solid gold and half width so players do not
## read it as one more tappable email line.
func _style_quiz_submit(button: Button) -> void:
	var normal: StyleBoxFlat = _pixel_box(Palette.GOLD, Palette.TEXT_ON_GOLD, 0, 2)
	var hover: StyleBoxFlat = _pixel_box(Palette.CYAN, Palette.TEXT_ON_GOLD, 0, 2)
	var disabled: StyleBoxFlat = _pixel_box(Color(Palette.BG_PANEL_ALT, 0.85), Palette.TEXT_MUTED, 0, 2)
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
	button.add_theme_font_size_override("font_size", 12)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(360, 56)


func _style_quiz_choice(button: Button) -> void:
	var normal: StyleBoxFlat = _pixel_box(Palette.NAVY_900, Palette.CYAN_400, 0, 2)
	normal.border_width_left = 6
	normal.content_margin_left = 20.0
	normal.content_margin_right = 20.0
	normal.content_margin_top = 18.0
	normal.content_margin_bottom = 18.0
	var hover: StyleBoxFlat = _pixel_box(Palette.PRIMARY_BLUE, Palette.CYAN_300, 0, 3)
	hover.border_width_left = 8
	hover.content_margin_left = 20.0
	hover.content_margin_right = 20.0
	hover.content_margin_top = 18.0
	hover.content_margin_bottom = 18.0
	var disabled: StyleBoxFlat = _pixel_box(Color(Palette.NAVY_900, 0.68), Palette.NAVY_700, 0, 2)
	disabled.content_margin_left = 20.0
	disabled.content_margin_right = 20.0
	disabled.content_margin_top = 18.0
	disabled.content_margin_bottom = 18.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Palette.CREAM)
	button.add_theme_color_override("font_pressed_color", Palette.CREAM)
	button.add_theme_color_override("font_disabled_color", Palette.NAVY_700)
	button.add_theme_font_size_override("font_size", 12)
	if _pixel_font != null:
		button.add_theme_font_override("font", _pixel_font)
	button.custom_minimum_size = Vector2(0, 74)


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
	if _defeat_started or current_phase == GamePhase.VICTORY:
		return
	_match_kills += 1
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
	if _defeat_started or current_phase == GamePhase.VICTORY or base_health <= 0:
		return
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
	if _is_summative():
		var exam_count: int = _exam_question_count()
		var accuracy: float = float(exam_questions_correct) / float(exam_count)
		if accuracy < _exam_required_score():
			var stage_id: int = Router.active_stage_index + 1
			PlayerManager.lock_stage(stage_id)
			print("[Exam] Failed after final defense. Locking Stage ", stage_id, " for remediation.")
			change_phase(GamePhase.GAME_OVER)
			return
	change_phase(GamePhase.VICTORY)


func _on_shop_card_pressed(card: TowerDeployCard) -> void:
	if _tower_placer == null or card == null:
		return
	_tower_placer.begin_place_drag_for(card.tower_id)


func _configure_shop_card(card: TowerDeployCard, type_id: String) -> void:
	if card == null:
		return
	card.configure(
		type_id,
		TowerBase.display_name_for(type_id).to_upper(),
		TowerBase.role_for(type_id),
		TowerBase.cost_for(type_id),
		card.portrait,
		TowerBase.accent_for(type_id),
	)


func _refresh_shop_cards() -> void:
	if _shop_row == null:
		return
	var building: bool = current_phase == GamePhase.PHASE_2_BUILD
	_refresh_one_shop_card(_tower_card, "base", building)
	_refresh_one_shop_card(_scanner_card, "scanner", building)
	_refresh_one_shop_card(_sandbox_card, "sandbox", building)


func _refresh_one_shop_card(card: TowerDeployCard, type_id: String, building: bool) -> void:
	if card == null:
		return
	var unlocked: bool = PlayerManager.is_tower_unlocked(type_id)
	if Router.is_tutorial:
		unlocked = type_id == "base"
	card.visible = building and unlocked
	card.cost = TowerBase.cost_for(type_id)
	var cap_max: int = 0
	var remaining: int = 0
	if _tower_placer != null:
		cap_max = _tower_placer.type_capacity(type_id)
		remaining = maxi(0, cap_max - _tower_placer.placed_count_of(type_id))
	card.slots_max = cap_max
	card.slots_remaining = remaining
	var at_cap: bool = remaining <= 0
	card.cap_reached = at_cap
	card.available = building and unlocked and not at_cap and current_gold >= card.cost


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
	if tower_node.current_type == "sandbox":
		var note := Label.new()
		note.text = "ZONE SLOW  x0.6"
		_apply_panel_font(note, 10)
		_upgrade_options.add_child(note)
		return
	_upgrade_options.add_child(_make_power_upgrade_button(tower_node))


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
