extends Control
## Shared geometric combat/presentation. The default scene remains disposable;
## live story play extends explicit hooks without giving the preview save access.
const HUD = preload("res://src/gameplay/preview/preview_hud.gd")
const Board = preload("res://src/gameplay/preview/preview_board.gd")
const Quiz = preload("res://src/gameplay/quiz_content.gd")
const TOWER = preload("res://src/gameplay/tower_base.tscn")
const ENEMY = preload("res://src/gameplay/enemy_base.tscn")
const TYPES := ["base", "scanner", "sandbox"]
const MOVE_COST := 1
var match_context: MatchContext
var config: Dictionary
var phase := "Briefing"
var intro_elapsed := 0.0
var gold := 2
var health := 5
var wave := 0
var waves_completed := 0
var answered := 0
var correct_answers := 0
var question_index := 0
var question: Dictionary
var question_pool: Array = []
var selected_answers: Array = []
var resolved := false
var time_left := 20.0
var time_limit := 20.0
var paused := false
var speed := 1.0
var occupied: Dictionary = {}
var pending_cell := Vector2i(-1, -1)
var pending_type := ""
var selected_tower: TowerBase
var move_origin := Vector2i(-1, -1)
var active_enemies := 0
var spawned := 0
var defeated := 0
var match_kills := 0
var spawn_clock := 0.0
var defend_clock := 0.0
var intermission := 0.0
var incident_due := false
var incident_active := false
var incident_left := 0.0
var incident: Dictionary = {}
var global_patch := false
var hud: Control

func _ready() -> void:
	# Fail closed: each scene validates its explicit context before any setup.
	if not _valid_context():
		push_error("Gameplay scene requires its matching context before initialization.")
		set_process(false)
		return
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_configure_match()
	hud = HUD.new()
	add_child(hud)
	hud.action.connect(_intent)
	hud.battle.cell_tapped.connect(select_cell)
	Engine.time_scale = 1.0
	hud.show_intro(str(config.get("name", "Diagnostic Protocol")), intro_elapsed)
	_update_hud()

func _valid_context() -> bool:
	return match_context != null and match_context.preview and not match_context.persistent

func _configure_match() -> void:
	config = ContentDB.get_stage("1").duplicate(true)
	gold = int(config.get("starting_gold", 2))
	question_pool = ContentDB.get_stage_question_pool(1).duplicate(true)
	question_pool.shuffle()

func _capacity(kind: String) -> int:
	return ContentDB.default_capacity(kind)

func _access_reason(_kind: String) -> String:
	return ""

func _research_bonus(_kind: String) -> Dictionary:
	return {}

func _enemy_health_scale() -> float:
	return 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	if hud == null or paused:
		return
	if phase == "Briefing":
		advance_briefing(delta)
		return
	if phase == "Trace" and not resolved:
		time_left = maxf(0, time_left - delta)
		hud.quiz_timer.value = time_left
		hud.quiz_time.text = "%.1fs" % time_left
		if time_left <= 0:
			resolve_answer(true)
	elif phase == "Defend":
		defend_clock += delta
		if incident_due and defend_clock >= 3.0:
			incident_due = false
			_open_incident()
		if incident_active:
			incident_left -= delta
			if incident_left <= 0:
				resolve_incident(false)
		var data: Dictionary = config.waves[wave]
		spawn_clock -= delta
		if spawned < int(data.enemy_count) and spawn_clock <= 0:
			_spawn_enemy()
			spawn_clock += float(data.spawn_delay)
		if spawned >= int(data.enemy_count) and active_enemies == 0 and not incident_active:
			intermission += delta
			if intermission >= 2.0:
				_wave_cleared()
	_update_hud()
	if is_instance_valid(selected_tower) and hud.side.visible:
		hud.update_tower_details(_tower_details(selected_tower))

func _wave_cleared() -> void:
	waves_completed = wave + 1
	if waves_completed >= config.waves.size():
		_finish(true)
	else:
		wave += 1
		question_index = 0
		_set_phase("Trace")
		_next_question()

func advance_briefing(delta: float) -> void:
	if phase != "Briefing" or paused:
		return
	intro_elapsed = minf(4, intro_elapsed + delta)
	hud.show_intro(str(config.get("name", "Diagnostic Protocol")), intro_elapsed)
	if intro_elapsed >= 4:
		hud.hide_intro()
		_set_phase("Trace")
		_next_question()

func _update_hud() -> void:
	hud.status.text = "STAGE 01 / WAVE %d/%d" % [wave + 1, config.waves.size()]
	hud.update_resources(gold, health)
	hud.set_phase(phase)
	hud.start_button.visible = phase == "Build" and not paused
	hud.speed_button.disabled = phase not in ["Build", "Defend"] or paused
	hud.speed_button.text = "%dx" % int(speed)
	hud.wave_progress.set_progress(defeated if phase == "Defend" else 0, int(config.waves[wave].enemy_count), phase != "Defend")
	hud.battle.board.health = health
	hud.battle.board.queue_redraw()

func _set_phase(next: String) -> void:
	phase = next
	cancel_selection()
	Engine.time_scale = 1.0 if phase == "Trace" or phase == "Results" else speed
	hud.hide_quiz()
	if phase == "Trace" or phase == "Results":
		hud.battle.enabled = false
	_update_hud()

func _next_question() -> void:
	if question_pool.is_empty():
		hud.show_modal("Question content unavailable", "Return to Stage Select and try again. Nothing has been saved.", [{"text": "Return to Stage Select", "id": "exit"}])
		resolved = true
		return
	question = question_pool[answered % question_pool.size()].duplicate(true)
	selected_answers.clear()
	resolved = false
	time_limit = 30.0 if Quiz.is_multi(question) else maxf(5, float(config.get("question_time_sec", 20)))
	time_left = time_limit
	hud.show_question(question, question_index + 1, int(config.get("questions_per_wave", 3)))
	hud.quiz_timer.max_value = time_limit

func choose_answer(value: Variant) -> void:
	if phase != "Trace" or resolved or paused:
		return
	if Quiz.is_multi(question):
		if selected_answers.has(value):
			selected_answers.erase(value)
		else:
			selected_answers.append(value)
	else:
		selected_answers = [value]
	var indices: Array = []
	var options: Array = Quiz.options(question)
	for i in options.size():
		if selected_answers.has(options[i].value):
			indices.append(i)
	hud.paint_selection(indices)

func resolve_answer(expired: bool = false) -> void:
	if phase != "Trace" or resolved or paused:
		return
	if not expired and selected_answers.is_empty():
		return
	# The deadline wins even if a queued Submit arrives on the timeout frame.
	expired = expired or time_left <= 0
	var picked: Variant = selected_answers.duplicate() if Quiz.is_multi(question) else (selected_answers[0] if not selected_answers.is_empty() else null)
	if expired:
		selected_answers.clear()
		picked = null
	resolved = true
	var correct: bool = not expired and Quiz.grade(question, picked)
	answered += 1
	question_index += 1
	correct_answers += int(correct)
	gold += 5 if correct else 2
	if correct and not global_patch and randf() <= LevelManager.GLOBAL_PATCH_CHANCE:
		global_patch = true
		for tower: TowerBase in occupied.values():
			tower.apply_global_patch()
	hud.show_feedback(correct, expired, Quiz.explanation(question, correct, picked))
	_update_hud()

func continue_question() -> void:
	if phase != "Trace" or not resolved or paused:
		return
	if question_index >= int(config.get("questions_per_wave", 3)):
		_set_phase("Build")
	else:
		_next_question()

func cell_reason(cell: Vector2i, kind: String = "") -> String:
	if phase != "Build" or paused:
		return "Construction is only available during Build."
	var reason: String = hud.battle.board.cell_reason(cell)
	if not reason.is_empty():
		return reason
	if occupied.has(cell):
		return "This tile already holds a tower."
	if not kind.is_empty():
		if not TYPES.has(kind):
			return "Choose a tower from the loadout."
		if not _access_reason(kind).is_empty():
			return _access_reason(kind)
		if _count(kind) >= _capacity(kind):
			return "Capacity reached for this tower."
		if gold < TowerBase.cost_for(kind):
			return "Not enough gold."
	return ""

func _count(kind: String) -> int:
	var count := 0
	for tower: TowerBase in occupied.values():
		count += int(tower.current_type == kind)
	return count

func select_cell(cell: Vector2i) -> void:
	if paused or not ["Build", "Defend"].has(phase):
		return
	if move_origin.x >= 0:
		var reason := cell_reason(cell)
		if not reason.is_empty():
			_notice(reason)
			return
		pending_cell = cell
		hud.battle.board.selected = cell
		hud.battle.board.ghost = selected_tower.current_type
		hud.open_side("Move tower", "Confirm this destination for %d gold. The original tile stays occupied until you confirm." % MOVE_COST, [], [{"text": "Confirm move / 1 gold", "id": "confirm_move", "primary": true}, {"text": "Cancel", "id": "cancel"}])
		return
	if occupied.has(cell):
		pending_cell = cell
		pending_type = ""
		selected_tower = occupied[cell]
		hud.battle.board.selected = cell
		hud.battle.board.ghost = ""
		hud.battle.board.show_range = true
		hud.battle.board.range_radius = selected_tower._range_radius()
		_inspect()
		return
	var reason := cell_reason(cell)
	if not reason.is_empty():
		cancel_selection()
		_notice(reason)
		return
	pending_cell = cell
	pending_type = ""
	selected_tower = null
	hud.battle.board.selected = cell
	hud.battle.board.ghost = ""
	hud.show_build_picker(_loadout_choices(), cell)

func _loadout_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for kind in TYPES:
		choices.append({"name": TowerBase.display_name_for(kind), "id": "pick_tower", "value": kind,
			"cost": TowerBase.cost_for(kind), "affordable": gold >= TowerBase.cost_for(kind),
			"locked": not _access_reason(kind).is_empty(),
			"remaining": maxi(0, _capacity(kind) - _count(kind))})
	return choices

func pick_tower(kind: String) -> void:
	if phase != "Build" or pending_cell.x < 0 or not TYPES.has(kind) or paused:
		return
	pending_type = kind
	hud.battle.board.ghost = kind
	var reason := cell_reason(pending_cell, kind)
	# Read the real baseline footprint/range from an unmounted actor, without
	# running ready, account bonus hooks or spawning a preview combat unit.
	var template := TOWER.instantiate() as TowerBase
	template.match_context = match_context
	var radius := template._range_radius()
	template.free()
	hud.battle.board.range_radius = radius
	var stats: Array[Dictionary] = [{"kind": "range", "caption": "Range", "display": "%.2f tiles" % (radius / Board.CELL), "value": radius / Board.CELL, "maximum": 3.0}]
	if kind == "sandbox":
		stats.append({"kind": "slow", "caption": "Slow", "display": "20–60%", "value": 60, "maximum": 100})
	else:
		var entry := TowerBase.entry_for(kind)
		var max_damage := 1.0
		var max_rate := 1.0
		for type in TYPES:
			max_damage = maxf(max_damage, TowerBase.damage_at(type, 0))
			max_rate = maxf(max_rate, float(TowerBase.entry_for(type).get("fire_rate", 1.0)))
		var damage := TowerBase.damage_at(kind, 0) + int(_research_bonus(kind).get("damage", 0))
		var rate := float(entry.get("fire_rate", 1.0)) + float(_research_bonus(kind).get("fire_rate", 0))
		stats.append({"kind": "damage", "caption": "Damage", "display": str(damage) + (" +15%" if global_patch else ""), "value": damage, "maximum": maxf(max_damage, damage)})
		stats.append({"kind": "rate", "caption": "Rate", "display": "%.2f/s" % rate, "value": rate, "maximum": maxf(max_rate, rate)})
	var matchups: Array[Dictionary] = [
		{"kind": "heavy", "name": "Heavy", "value": "×1.5", "strong": true},
		{"kind": "swarm", "name": "Swarm", "value": "×0.5", "strong": false}]
	if kind == "scanner":
		matchups = [{"kind": "swarm", "name": "Swarm", "value": "×1.5", "strong": true}, {"kind": "heavy", "name": "Heavy", "value": "×0.5", "strong": false}]
	elif kind == "sandbox":
		matchups = [{"kind": "stealth", "name": "Stealth", "value": "−60%", "strong": true}, {"kind": "heavy", "name": "Heavy / swarm", "value": "−20%", "strong": false}]
	hud.show_build_picker(_loadout_choices(), pending_cell, kind, {
		"name": TowerBase.display_name_for(kind), "stats": stats, "matchups": matchups, "patch": global_patch and kind != "sandbox",
		"cost": TowerBase.cost_for(kind), "remaining": maxi(0, _capacity(kind) - _count(kind)),
		"capacity": _capacity(kind), "reason": reason,
	})

func place_tower() -> bool:
	if pending_type.is_empty() or not cell_reason(pending_cell, pending_type).is_empty():
		return false
	var tower := TOWER.instantiate() as TowerBase
	tower.match_context = match_context
	tower.starting_type = pending_type
	tower.position = Board.center(pending_cell)
	occupied[pending_cell] = tower
	gold -= TowerBase.cost_for(pending_type)
	hud.battle.world.add_child(tower)
	if global_patch:
		tower.apply_global_patch()
	cancel_selection()
	_update_hud()
	return true

func _inspect() -> void:
	if not is_instance_valid(selected_tower):
		cancel_selection()
		return
	var tower := selected_tower
	var choices: Array[Dictionary] = []
	if phase == "Build":
		choices.append({"text": "Upgrade / %d gold" % tower.next_upgrade_cost() if tower.can_upgrade() else "Maximum upgrade", "id": "upgrade", "primary": true, "disabled": not tower.can_upgrade() or gold < tower.next_upgrade_cost()})
		choices.append({"text": "Move / %d gold" % MOVE_COST, "id": "move", "disabled": gold < MOVE_COST})
	choices.append({"text": "Close", "id": "cancel"})
	hud.show_tower_details(_tower_details(tower), choices)

func _tower_details(tower: TowerBase) -> Dictionary:
	var field := tower.current_type == "sandbox"
	var effect := "Heavy ×1.5 damage / Swarm ×0.5 damage"
	if tower.current_type == "scanner":
		effect = "Swarm ×1.5 damage / Heavy ×0.5 damage"
	elif field:
		effect = "Slow field: −60% speed against stealth; −20% against swarm and heavy."
	if tower._match_damage_scale > 1 and not field:
		effect += "\nGlobal patch: +15% damage."
	if tower._buff_time_left > 0 and not field:
		effect += "\n%s / %.1fs" % ["System lag: reduced attack speed" if tower._buff_is_lag else "Incident boost: faster attacks", tower._buff_time_left]
	return {
		"kind": tower.current_type,
		"title": "%s / L%d" % [TowerBase.display_name_for(tower.current_type).to_upper(), tower.upgrade_level + 1],
		"level": tower.upgrade_level, "max_level": TowerBase.MAX_UPGRADE_LEVEL,
		"upgrades": "UPGRADES %d / %d" % [tower.upgrade_level, TowerBase.MAX_UPGRADE_LEVEL],
		"totals": "DAMAGE %d   /   KILLS %d" % [tower.preview_damage_dealt, tower.preview_kills],
		"tile": "No tile effects / One-cell footprint",
		"range": "Range\n%.2f tiles" % (tower._range_radius() / Board.CELL),
		"damage": "Damage\n%s" % ("—" if field else str(tower.base_damage)),
		"rate": "Attack speed\n%s" % ("Passive" if field else "%.2f/s" % (tower.fire_rate * tower._buff_fire_scale)),
		"rotation": "Aim response\n%s" % ("—" if field else "%.1f/s" % TowerBase.AIM_TURN_SPEED),
		"projectile": "Bolt speed\n%s" % ("—" if field else "%.0f u/s" % ProjectileBase.DEFAULT_SPEED),
		"multiplier": "Damage boost\n%s" % ("—" if field else "×%.2f" % tower._match_damage_scale),
		"effects": effect,
		"next": ("Next: damage %d → %d" % [tower.base_damage, TowerBase.damage_at(tower.current_type, tower.upgrade_level + 1) + int(_research_bonus(tower.current_type).get("damage", 0))] if not field else "Power upgrades do not increase this slow field.") if tower.can_upgrade() else "Maximum upgrade reached.",
	}

func upgrade_tower() -> bool:
	if phase != "Build" or paused or not is_instance_valid(selected_tower) or not occupied.values().has(selected_tower):
		return false
	var cost := selected_tower.next_upgrade_cost()
	if not selected_tower.can_upgrade() or gold < cost:
		return false
	if not selected_tower.apply_power_upgrade():
		return false
	gold -= cost
	_inspect()
	return true

func begin_move() -> void:
	if phase != "Build" or paused or not is_instance_valid(selected_tower) or gold < MOVE_COST:
		return
	move_origin = pending_cell
	pending_cell = Vector2i(-1, -1)
	hud.open_side("Select destination", "Tap a free tile. Moving costs 1 gold only after confirmation.", [], [{"text": "Cancel move", "id": "cancel"}])

func confirm_move() -> bool:
	if move_origin.x < 0 or not occupied.has(move_origin) or occupied[move_origin] != selected_tower or not cell_reason(pending_cell).is_empty() or gold < MOVE_COST:
		return false
	occupied.erase(move_origin)
	occupied[pending_cell] = selected_tower
	selected_tower.position = Board.center(pending_cell)
	selected_tower.play_redeploy_animation()
	gold -= MOVE_COST
	cancel_selection()
	return true

func cancel_selection() -> void:
	pending_cell = Vector2i(-1, -1)
	pending_type = ""
	selected_tower = null
	move_origin = Vector2i(-1, -1)
	if hud != null:
		hud.close_side()
		hud.battle.board.selected = pending_cell
		hud.battle.board.ghost = ""
		hud.battle.board.show_range = false

func _notice(copy: String) -> void:
	hud.open_side("Tile unavailable", copy, [], [{"text": "Cancel", "id": "cancel"}])

func begin_defend() -> void:
	if phase != "Build" or paused:
		return
	spawned = 0
	defeated = 0
	active_enemies = 0
	spawn_clock = 0
	defend_clock = 0
	intermission = 0
	incident_due = randf() <= float(config.get("incident_chance", 0.25))
	_set_phase("Defend")

func _spawn_enemy() -> void:
	var data: Dictionary = config.waves[wave]
	var mix: Array = data.get("enemy_mix", [])
	var kind: String = str(mix[spawned % mix.size()]) if not mix.is_empty() else str(data.get("enemy_type", "basic"))
	var enemy := ENEMY.instantiate() as EnemyBase
	enemy.match_context = match_context
	enemy.initialize_stats(kind, float(data.get("health_multiplier", 1)) * _enemy_health_scale())
	enemy.enemy_died.connect(_enemy_died)
	enemy.reached_base.connect(_enemy_leaked)
	spawned += 1
	active_enemies += 1
	hud.battle.track.add_child(enemy)

func _enemy_died(bounty: int) -> void:
	if phase != "Defend":
		return
	gold += bounty
	match_kills += 1
	active_enemies = maxi(0, active_enemies - 1)
	defeated += 1

func _enemy_leaked() -> void:
	if phase != "Defend":
		return
	health = maxi(0, health - 1)
	hud.battle.shake_hit()
	active_enemies = maxi(0, active_enemies - 1)
	defeated += 1
	if health == 0:
		_finish(false)

func _open_incident() -> void:
	var bank: Array = ContentDB.get_incidents()
	if bank.is_empty():
		return
	incident = bank.pick_random().duplicate(true)
	incident_active = true
	incident_left = 6.0
	cancel_selection()
	var actions: Array[Dictionary] = [{"text": str(incident.correct), "id": "incident", "value": true}, {"text": str(incident.wrong), "id": "incident", "value": false}]
	actions.shuffle()
	hud.show_modal("Live incident / respond in 6 seconds", str(incident.text), actions)
	hud.battle.enabled = false

func resolve_incident(correct: bool) -> void:
	if not incident_active or phase != "Defend" or paused:
		return
	incident_active = false
	hud.close_modal()
	hud.battle.enabled = true
	for tower: TowerBase in occupied.values():
		if correct:
			tower.apply_incident_buff()
		else:
			tower.apply_incident_lag()

func toggle_pause() -> void:
	if phase == "Results":
		return
	paused = not paused
	hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	hud.battle.enabled = not paused and phase in ["Build", "Defend"] and not incident_active
	if paused:
		hud.show_modal(_pause_title(), _pause_description(), [{"text": "Resume", "id": "pause", "primary": true}, {"text": "Return to Stage Select", "id": "exit"}])
	else:
		hud.close_modal()
		if incident_active:
			hud.show_modal("Live incident / %.1fs remaining" % incident_left, str(incident.text), [{"text": str(incident.correct), "id": "incident", "value": true}, {"text": str(incident.wrong), "id": "incident", "value": false}])
	_update_hud()

func _finish(won: bool) -> void:
	if phase == "Results":
		return
	_set_phase("Results")
	incident_active = false
	hud.battle.world.process_mode = Node.PROCESS_MODE_DISABLED
	# Combat freezes behind the result reveal, but temporary residue must still
	# finish fading instead of being left permanently suspended on the map.
	for effect in hud.battle.track.get_children():
		if effect.has_meta("preview_death_burst") or effect.has_meta("preview_death_stain"):
			effect.process_mode = Node.PROCESS_MODE_ALWAYS
	if not won and _destroy_home_on_loss():
		hud.battle.board.play_home_destruction()
		AudioManager.play_sfx("explosion")
	hud.show_results(_result_data(won))

func _pause_title() -> String:
	return "Preview paused"

func _pause_description() -> String:
	return "Your account is untouched. Resume, or return to Stage Select."

func _destroy_home_on_loss() -> bool:
	return true

func _result_data(won: bool) -> Dictionary:
	return {"won": won, "stage": 1, "completed": waves_completed,
		"waves": config.waves.size(), "correct": correct_answers, "answered": answered, "health": health}

func _intent(id: String, value: Variant) -> void:
	if paused and id not in ["pause", "exit"]:
		return
	match id:
		"answer": choose_answer(value)
		"submit":
			if resolved:
				continue_question()
			else:
				resolve_answer()
		"pick_tower": pick_tower(str(value))
		"repick": select_cell(pending_cell)
		"place": place_tower()
		"cancel": cancel_selection()
		"upgrade": upgrade_tower()
		"move": begin_move()
		"confirm_move": confirm_move()
		"defend": begin_defend()
		"recenter": hud.battle.recenter()
		"pause": toggle_pause()
		"incident": resolve_incident(bool(value))
		"speed":
			if phase in ["Build", "Defend"]:
				speed = 2.0 if speed == 1 else 1.0
				Engine.time_scale = speed
		"exit": Router.return_to_stage_select()
		"retry": Router.restart_level()
