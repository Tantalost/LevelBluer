class_name PvpBattle
extends RefCounted
## Local duel rules only. No nodes, sockets, rewards, or BKT/mastery writes.
const Quiz = preload("res://src/gameplay/quiz_content.gd")

signal phase_changed(next_phase: int)

enum Phase { PREPARING, COUNTDOWN, QUESTION, RESOLVING, ROUND_RESULT, NEXT_ROUND, FINISHED }
enum Outcome { ONGOING, PLAYER_WIN, BOT_WIN, DRAW }

const MAX_HP: int = 100
const ROUND_MS: int = 10000
const COUNTDOWN_MS: int = 3000
const RESULT_MS: int = 2500
const DAMAGE_HIT: int = 20
const BOT_ACCURACY: float = 0.65
const BOT_DELAY_MIN_MS: int = 1500
const BOT_DELAY_MAX_MS: int = 8000
const BOT_NAME: String = "RIVAL NODE"

class Answer:
	var locked: bool = false
	var timed_out: bool = false
	var correct: bool = false
	var response_ms: int = -1
	var pick: Variant = null

class RoundState:
	var question_id: String = ""
	var question: Dictionary = {}
	var started_at: int = 0
	var ends_at: int = 0
	var resolved: bool = false
	var advanced: bool = false
	var damage_to_player: int = 0
	var damage_to_bot: int = 0
	var player: Answer
	var bot: Answer

	func _init() -> void:
		player = Answer.new()
		bot = Answer.new()

var phase: Phase = Phase.PREPARING
var player_hp: int = MAX_HP
var bot_hp: int = MAX_HP
var round_number: int = 0
var rounds_played: int = 0
var countdown_ends_at: int = 0
var round_ends_at: int = 0
var result_ends_at: int = 0
var bot_answers_at: int = 0
var player_correct: int = 0
var bot_correct: int = 0
var player_correct_ms: int = 0
var bot_correct_ms: int = 0
var match_result: Outcome = Outcome.ONGOING

var _deck: Array[Dictionary] = []
var _source: Array[Dictionary] = []
var _round_cursor: int = 0
var _last_question_id: String = ""
var _deck_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current: RoundState
var _running: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bot_policy: Callable = Callable()
var _bot_delay_ms: int = 0
var _scheduled_pick: Variant = null


static func question_id(question: Dictionary) -> String:
	return str(question.get("id", "")).strip_edges()


static func apply_damage(hp: int, damage: int) -> int:
	return clampi(hp - maxi(damage, 0), 0, MAX_HP)


static func build_deck(pool: Array, round_count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var unique: Dictionary = {}
	var ids: Array[String] = []
	for row: Variant in pool:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var question: Dictionary = row as Dictionary
		if not _is_duel_question(question):
			continue
		var qid: String = question_id(question)
		if unique.has(qid):
			continue
		unique[qid] = question.duplicate(true)
		ids.append(qid)
	_shuffle_ids(ids, rng)
	var deck: Array[Dictionary] = []
	var limit: int = ids.size()
	if round_count > 0 and round_count < limit:
		limit = round_count
	for i: int in limit:
		deck.append(unique[ids[i]] as Dictionary)
	return deck


func set_bot_policy(policy: Callable) -> void:
	_bot_policy = policy


func question_ids() -> Array[String]:
	var ids: Array[String] = []
	for question: Dictionary in _deck:
		ids.append(question_id(question))
	return ids


func start(questions: Array, now_ms: int, rng: RandomNumberGenerator) -> bool:
	_reset()
	_rng = rng
	var seen: Dictionary = {}
	for row: Variant in questions:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var question: Dictionary = row as Dictionary
		if not _is_duel_question(question):
			continue
		var qid: String = question_id(question)
		if seen.has(qid):
			continue
		seen[qid] = true
		_deck.append(question.duplicate(true))
	if _deck.is_empty():
		return false
	_source = _deck.duplicate(true)
	_deck_rng = RandomNumberGenerator.new()
	_deck_rng.seed = rng.seed
	_running = true
	phase = Phase.PREPARING
	return true


func tick(now_ms: int) -> void:
	if not _running or phase == Phase.FINISHED:
		return
	if phase == Phase.PREPARING:
		_begin_countdown(now_ms)
		return
	if phase == Phase.COUNTDOWN:
		if now_ms >= countdown_ends_at:
			_begin_question(now_ms)
			_tick_question(now_ms)
		return
	if phase == Phase.QUESTION:
		_tick_question(now_ms)
		return
	if phase == Phase.RESOLVING:
		_set_phase(Phase.ROUND_RESULT)
		return
	if phase == Phase.ROUND_RESULT:
		if now_ms >= result_ends_at:
			_advance(now_ms)
		return
	if phase == Phase.NEXT_ROUND:
		_advance(now_ms)


func retire() -> void:
	_running = false


func submit_player(pick: Variant, now_ms: int) -> bool:
	if not _running or phase != Phase.QUESTION or _current == null or _current.resolved:
		return false
	if _current.player.locked:
		return false
	if now_ms >= round_ends_at:
		return false
	if not _current.bot.locked and _bot_due(now_ms):
		_lock_bot(bot_answers_at)
		if _current.resolved or phase != Phase.QUESTION:
			return false
	_current.player.locked = true
	_current.player.timed_out = false
	_current.player.pick = pick
	_current.player.response_ms = now_ms - _current.started_at
	_current.player.correct = Quiz.grade(_current.question, pick)
	if _current.player.correct or _current.bot.locked:
		_resolve(now_ms)
	return true


func current_question() -> Dictionary:
	if _current == null:
		return {}
	return _current.question


func question_started_at() -> int:
	if _current == null:
		return 0
	return _current.started_at


func remaining_ms(now_ms: int) -> int:
	if phase != Phase.QUESTION:
		return 0
	return maxi(0, round_ends_at - now_ms)


func player_locked() -> bool:
	return phase == Phase.QUESTION and _current != null and _current.player.locked and not _current.resolved


func player_response_ms() -> int:
	if _current == null or not _current.player.locked:
		return -1
	return _current.player.response_ms


func player_pick() -> Variant:
	if _current == null or not _current.resolved:
		return null
	return _current.player.pick


func bot_response_ms() -> int:
	if _current == null or not _current.resolved:
		return -1
	return _current.bot.response_ms


func side_correct(player_side: bool) -> bool:
	if _current == null or not _current.resolved:
		return false
	return _current.player.correct if player_side else _current.bot.correct


func side_timed_out(player_side: bool) -> bool:
	if _current == null or not _current.resolved:
		return false
	return _current.player.timed_out if player_side else _current.bot.timed_out


func damage_to(player_side: bool) -> int:
	if _current == null or not _current.resolved:
		return 0
	return _current.damage_to_player if player_side else _current.damage_to_bot


func average_correct_ms(player_side: bool) -> float:
	var count: int = player_correct if player_side else bot_correct
	if count <= 0:
		return -1.0
	var total: int = player_correct_ms if player_side else bot_correct_ms
	return float(total) / float(count)


func winner() -> Outcome:
	return match_result


func _reset() -> void:
	phase = Phase.PREPARING
	player_hp = MAX_HP
	bot_hp = MAX_HP
	round_number = 0
	rounds_played = 0
	countdown_ends_at = 0
	round_ends_at = 0
	result_ends_at = 0
	bot_answers_at = 0
	player_correct = 0
	bot_correct = 0
	player_correct_ms = 0
	bot_correct_ms = 0
	match_result = Outcome.ONGOING
	_deck.clear()
	_source.clear()
	_round_cursor = 0
	_last_question_id = ""
	_current = null
	_running = false
	_bot_delay_ms = 0
	_scheduled_pick = null


func _begin_countdown(now_ms: int) -> void:
	round_number = rounds_played + 1
	countdown_ends_at = now_ms + COUNTDOWN_MS
	_set_phase(Phase.COUNTDOWN)


func _begin_question(now_ms: int) -> void:
	if _round_cursor >= _deck.size() and not _refill_deck():
		return
	var question: Dictionary = _deck[_round_cursor]
	_round_cursor += 1
	round_number = rounds_played + 1
	_last_question_id = question_id(question)
	_current = RoundState.new()
	_current.question = question
	_current.question_id = question_id(question)
	_current.started_at = now_ms
	_current.ends_at = now_ms + ROUND_MS
	round_ends_at = _current.ends_at
	var decision: Dictionary = _choose_bot(question)
	_bot_delay_ms = BOT_DELAY_MIN_MS
	if decision.has("delay_ms"):
		_bot_delay_ms = int(decision["delay_ms"])
	if _bot_delay_ms < 0:
		_bot_delay_ms = 0
	if decision.has("pick"):
		_scheduled_pick = decision["pick"]
	else:
		_scheduled_pick = _option_for(question, bool(decision.get("correct", false)))
	bot_answers_at = now_ms + _bot_delay_ms
	_set_phase(Phase.QUESTION)


func _tick_question(now_ms: int) -> void:
	if phase != Phase.QUESTION or _current == null or _current.resolved:
		return
	if not _current.bot.locked and _bot_due(now_ms):
		_lock_bot(now_ms)
	if _current == null or _current.resolved or phase != Phase.QUESTION:
		return
	if now_ms >= round_ends_at:
		_timeout_unlocked()
		_resolve(round_ends_at)


func _bot_due(now_ms: int) -> bool:
	return bot_answers_at < round_ends_at and now_ms >= bot_answers_at


func _lock_bot(now_ms: int) -> void:
	if _current == null or _current.resolved or _current.bot.locked:
		return
	_current.bot.locked = true
	_current.bot.timed_out = false
	_current.bot.pick = _scheduled_pick
	_current.bot.response_ms = _bot_delay_ms
	_current.bot.correct = Quiz.grade(_current.question, _scheduled_pick)
	if _current.bot.correct or _current.player.locked:
		_resolve(now_ms)


func _timeout_unlocked() -> void:
	if _current == null:
		return
	if not _current.player.locked:
		_current.player.locked = true
		_current.player.timed_out = true
		_current.player.correct = false
		_current.player.response_ms = -1
		_current.player.pick = null
	if not _current.bot.locked:
		_current.bot.locked = true
		_current.bot.timed_out = true
		_current.bot.correct = false
		_current.bot.response_ms = -1
		_current.bot.pick = null


func _resolve(now_ms: int) -> void:
	if phase != Phase.QUESTION or _current == null or _current.resolved:
		return
	_current.resolved = true
	var hit: Vector2i = _damage_for(_current)
	_current.damage_to_player = hit.x
	_current.damage_to_bot = hit.y
	player_hp = apply_damage(player_hp, hit.x)
	bot_hp = apply_damage(bot_hp, hit.y)
	if _current.player.correct and _current.player.response_ms >= 0:
		player_correct += 1
		player_correct_ms += _current.player.response_ms
	if _current.bot.correct and _current.bot.response_ms >= 0:
		bot_correct += 1
		bot_correct_ms += _current.bot.response_ms
	rounds_played += 1
	result_ends_at = now_ms + RESULT_MS
	_set_phase(Phase.RESOLVING)
	_set_phase(Phase.ROUND_RESULT)


func _advance(now_ms: int) -> void:
	if phase != Phase.ROUND_RESULT:
		return
	if _current != null and _current.advanced:
		return
	if _current != null:
		_current.advanced = true
	_set_phase(Phase.NEXT_ROUND)
	if player_hp <= 0 or bot_hp <= 0:
		_finish()
		return
	if _round_cursor >= _deck.size() and not _refill_deck():
		return
	_begin_countdown(now_ms)


func _finish() -> void:
	match_result = _decide()
	_running = false
	_set_phase(Phase.FINISHED)


func _decide() -> Outcome:
	if player_hp <= 0 and bot_hp <= 0:
		return Outcome.DRAW
	if player_hp <= 0:
		return Outcome.BOT_WIN
	if bot_hp <= 0:
		return Outcome.PLAYER_WIN
	return Outcome.ONGOING


func _refill_deck() -> bool:
	if _source.is_empty():
		return false
	var ids: Array[String] = []
	var by_id: Dictionary = {}
	for question: Dictionary in _source:
		var qid: String = question_id(question)
		if by_id.has(qid):
			continue
		by_id[qid] = question
		ids.append(qid)
	if ids.is_empty():
		return false
	_shuffle_ids(ids, _deck_rng)
	if ids.size() > 1 and ids[0] == _last_question_id:
		var held: String = ids[0]
		ids[0] = ids[1]
		ids[1] = held
	_deck.clear()
	for qid: String in ids:
		_deck.append((by_id[qid] as Dictionary).duplicate(true))
	_round_cursor = 0
	return true


func _damage_for(round_state: RoundState) -> Vector2i:
	if round_state.player.correct:
		return Vector2i(0, DAMAGE_HIT)
	if round_state.bot.correct:
		return Vector2i(DAMAGE_HIT, 0)
	return Vector2i.ZERO


func _choose_bot(question: Dictionary) -> Dictionary:
	if _bot_policy.is_valid():
		var decided: Variant = _bot_policy.call(question)
		if typeof(decided) == TYPE_DICTIONARY:
			return decided as Dictionary
	var correct: bool = _rng.randf() < BOT_ACCURACY
	var delay_ms: int = _rng.randi_range(BOT_DELAY_MIN_MS, BOT_DELAY_MAX_MS)
	return {"correct": correct, "delay_ms": delay_ms}


func _option_for(question: Dictionary, want_correct: bool) -> Variant:
	var choices: Array[Dictionary] = Quiz.options(question)
	var fallback: Variant = null
	for choice: Dictionary in choices:
		var value: Variant = choice.get("value", null)
		if fallback == null:
			fallback = value
		if Quiz.grade(question, value) == want_correct:
			return value
	return fallback


func _set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(int(phase))


static func _is_duel_question(question: Dictionary) -> bool:
	if question_id(question).is_empty():
		return false
	if Quiz.is_multi(question):
		return false
	return not Quiz.options(question).is_empty()


static func _shuffle_ids(ids: Array[String], rng: RandomNumberGenerator) -> void:
	for i: int in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: String = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
