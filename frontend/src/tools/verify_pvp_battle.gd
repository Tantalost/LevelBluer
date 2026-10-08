extends SceneTree
## Deterministic local-duel rules. No mastery writes, timers, or network.
const Battle = preload("res://src/gameplay/pvp/pvp_battle.gd")
const Quiz = preload("res://src/gameplay/quiz_content.gd")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for _index: int in 4:
		await process_frame


func _run() -> void:
	var player: Node = root.get_node("PlayerManager")
	var mastery_before: String = JSON.stringify(player.mastery_matrix)
	var tokens_before: int = player.pvp_tokens
	_check_hp_floor()
	_check_deck_identity()
	_check_guards()
	_check_hidden_bot()
	_check_damage_cases()
	_check_ko()
	_check_first_correct_race()
	_check_match_continues_until_ko()
	_check_live_bank()
	_check_short_and_empty_decks()
	_check_result_hold_and_retired_match()
	await _check_screen()
	await _check_screen_hardening()
	check(JSON.stringify(player.mastery_matrix) == mastery_before, "PvP leaves mastery unchanged")
	check(player.pvp_tokens == tokens_before, "PvP leaves the token wallet unchanged")
	var battle_source: String = FileAccess.get_file_as_string("res://src/gameplay/pvp/pvp_battle.gd")
	var screen_source: String = FileAccess.get_file_as_string("res://src/ui/screens/pvp/pvp_battle_screen.gd")
	check(not battle_source.contains("update_mastery") and not screen_source.contains("update_mastery"), "PvP source does not update mastery")
	check(not battle_source.contains("pvp_tokens") and not screen_source.contains("pvp_tokens"), "PvP source does not pay tokens")
	print("[PVP] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func question_row(id: String) -> Dictionary:
	return {
		"id": id,
		"question": "Pick yes",
		"options": ["no", "yes"],
		"answer_index": 1,
	}


func scripted(correct: bool, delay_ms: int) -> Callable:
	return _scripted.bind(correct, delay_ms)


func _scripted(_question: Dictionary, correct: bool, delay_ms: int) -> Dictionary:
	return {"correct": correct, "delay_ms": delay_ms}


func scripted_pick(pick: int, delay_ms: int) -> Callable:
	return _scripted_pick.bind(pick, delay_ms)


func _scripted_pick(_question: Dictionary, pick: int, delay_ms: int) -> Dictionary:
	return {"pick": pick, "delay_ms": delay_ms, "correct": true}


func fresh(policy: Callable) -> Battle:
	var battle: Battle = Battle.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var questions: Array = []
	for i: int in 8:
		questions.append(question_row("r%d" % (i + 1)))
	battle.set_bot_policy(policy)
	check(battle.start(questions, 0, rng), "match starts")
	battle.tick(0)
	check(battle.phase == Battle.Phase.COUNTDOWN, "match opens on the countdown")
	return battle


func open_question(battle: Battle) -> int:
	if battle.phase == Battle.Phase.PREPARING:
		battle.tick(0)
	if battle.phase == Battle.Phase.ROUND_RESULT:
		battle.tick(battle.result_ends_at)
	if battle.phase != Battle.Phase.COUNTDOWN:
		return -1
	battle.tick(battle.countdown_ends_at)
	if battle.phase != Battle.Phase.QUESTION:
		return -1
	return battle.question_started_at()


func play_round(battle: Battle, player_pick: Variant, player_offset: int, bot_correct: bool, bot_delay: int) -> void:
	battle.set_bot_policy(scripted(bot_correct, bot_delay))
	var opened: int = open_question(battle)
	check(opened >= 0, "question opened")
	if opened < 0:
		return
	var player_at: int = opened + player_offset
	var bot_at: int = opened + bot_delay
	if player_offset >= 0 and player_at <= bot_at:
		check(battle.submit_player(player_pick, player_at), "in-time answer accepted")
	if battle.phase == Battle.Phase.QUESTION and bot_at < battle.round_ends_at:
		battle.tick(bot_at)
	if player_offset >= 0 and player_at > bot_at and battle.phase == Battle.Phase.QUESTION:
		check(battle.submit_player(player_pick, player_at), "in-time answer accepted")
	if battle.phase == Battle.Phase.QUESTION:
		battle.tick(battle.round_ends_at)
	check(battle.phase == Battle.Phase.ROUND_RESULT, "round resolved")


func close_match(battle: Battle) -> void:
	check(battle.phase == Battle.Phase.ROUND_RESULT, "result is showing before the match advances")
	battle.tick(battle.result_ends_at)


func _check_hp_floor() -> void:
	check(Battle.apply_damage(100, 20) == 80, "20 damage from full HP")
	check(Battle.apply_damage(10, 20) == 0, "damage below zero clamps to 0")
	check(Battle.apply_damage(0, 20) == 0, "HP stays on the floor")
	check(Battle.apply_damage(100, 0) == 100, "no damage leaves HP at the cap")
	check(Battle.apply_damage(150, 0) == 100, "HP cannot rise above 100")
	check(Battle.apply_damage(95, -5) == 95, "negative damage is ignored")


func _check_deck_identity() -> void:
	var shared_a: Dictionary = question_row("alpha")
	shared_a["question"] = "shared wording"
	var shared_b: Dictionary = question_row("beta")
	shared_b["question"] = "shared wording"
	var text_only: Dictionary = {
		"question": "shared wording",
		"options": ["no", "yes"],
		"answer_index": 1,
	}
	var multi: Dictionary = question_row("multi")
	multi["delivery"] = "multi_select"
	multi["type_id"] = "tap_trap_lines"
	multi["correct_indices"] = [0]
	var pool: Array = [shared_a, question_row("alpha"), text_only, shared_b, multi, question_row("gamma")]
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 42
	var deck_a: Array[Dictionary] = Battle.build_deck(pool, 7, rng_a)
	var deck_b: Array[Dictionary] = Battle.build_deck(pool, 7, rng_b)
	var ids_a: PackedStringArray = PackedStringArray()
	var ids_b: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for row: Dictionary in deck_a:
		var qid: String = str(row.get("id", ""))
		ids_a.append(qid)
		check(not seen.has(qid), "deck ids are unique")
		seen[qid] = true
		check(not Quiz.is_multi(row), "multi-select questions stay out of the timed duel")
	for row: Dictionary in deck_b:
		ids_b.append(str(row.get("id", "")))
	check(seen.size() == 3 and seen.has("alpha") and seen.has("beta") and seen.has("gamma"), "identity is the question id, not the prompt text")
	check(",".join(ids_a) == ",".join(ids_b), "the same deck seed is stable")
	var battle: Battle = Battle.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var state: int = rng.state
	check(battle.start([question_row("a"), question_row("a"), text_only, question_row("b")], 0, rng), "partial deck still starts")
	check(battle.question_ids() == ["a", "b"], "start keeps the first id and drops text-only rows")
	check(rng.state == state, "building a scripted match does not roll the bot")


func _check_guards() -> void:
	var battle: Battle = fresh(scripted(false, 2000))
	check(not battle.submit_player(1, 0), "countdown rejects an answer")
	var opened: int = open_question(battle)
	check(battle.submit_player(0, opened + 100), "first answer locks")
	check(not battle.submit_player(0, opened + 200), "second answer is rejected")
	check(battle.phase == Battle.Phase.QUESTION, "a wrong answer leaves the round open")
	check(battle.player_response_ms() == 100, "the first response time is kept")
	check(not battle.side_correct(false) and battle.bot_response_ms() == -1, "bot result stays hidden before resolution")
	var late: Battle = fresh(scripted(true, 20000))
	var late_opened: int = open_question(late)
	check(not late.submit_player(1, late.round_ends_at), "the deadline itself is late")
	check(not late.player_locked(), "a late answer does not lock")
	check(late.submit_player(1, late.round_ends_at - 1), "the last open millisecond is accepted")
	check(late.player_response_ms() == late.round_ends_at - 1 - late_opened, "late-boundary response time is kept")
	var phases: Array[int] = []
	var once: Battle = fresh(scripted(false, 1000))
	once.phase_changed.connect(func(next_phase: int) -> void: phases.append(next_phase))
	var start: int = open_question(once)
	var hp_before: int = once.bot_hp
	check(once.submit_player(1, start + 500), "player answers before the bot")
	check(once.phase == Battle.Phase.ROUND_RESULT, "the first correct answer resolves immediately")
	check(once.bot_hp == hp_before - Battle.DAMAGE_HIT, "correct versus wrong deals 20 once")
	check(once.player_hp == Battle.MAX_HP, "the correct player takes no damage")
	check(once.rounds_played == 1, "the round counts once")
	check(_count(phases, Battle.Phase.RESOLVING) == 1, "resolve emits once")
	check(not once.submit_player(0, start + 600), "a submission after resolution is rejected")
	once.tick(start + 1000)
	check(once.phase == Battle.Phase.ROUND_RESULT and once.bot_hp == hp_before - Battle.DAMAGE_HIT, "a delayed bot answer is ignored after the player wins")
	once.tick(once.result_ends_at - 1)
	check(once.bot_hp == hp_before - Battle.DAMAGE_HIT, "a second tick does not resolve again")
	check(once.rounds_played == 1, "a second tick does not count another round")
	check(_count(phases, Battle.Phase.RESOLVING) == 1, "resolve cannot run twice")
	var played: int = once.rounds_played
	once.tick(once.result_ends_at)
	check(once.phase == Battle.Phase.COUNTDOWN, "the next round waits on its countdown")
	check(_count(phases, Battle.Phase.NEXT_ROUND) == 1, "advance emits once")
	once.tick(once.result_ends_at)
	check(once.phase == Battle.Phase.COUNTDOWN, "a second advance does not skip the countdown")
	check(once.rounds_played == played, "a second advance does not consume another round")
	check(_count(phases, Battle.Phase.NEXT_ROUND) == 1, "advance cannot run twice")


func _check_hidden_bot() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var battle: Battle = Battle.new()
	var questions: Array = []
	for i: int in 2:
		questions.append(question_row("h%d" % (i + 1)))
	battle.set_bot_policy(scripted_pick(0, 4321))
	check(battle.start(questions, 0, rng), "scripted bot match starts")
	var state: int = rng.state
	battle.tick(0)
	var opened: int = open_question(battle)
	battle.tick(opened + 4321)
	check(battle.phase == Battle.Phase.QUESTION, "the bot can answer while the question is still open")
	check(not battle.side_correct(false), "injected bot accuracy stays hidden")
	check(battle.bot_response_ms() == -1, "bot timing stays hidden until resolution")
	check(battle.submit_player(1, opened + 4500), "player can still answer after the bot")
	battle.tick(opened + 4500)
	check(battle.phase == Battle.Phase.ROUND_RESULT, "both answers resolve")
	check(not battle.side_correct(false), "an injected wrong choice grades wrong even if the policy claims correct")
	check(battle.side_correct(true), "player choice still grades on its own")
	check(battle.bot_response_ms() == 4321, "injected bot delay is the response time")
	check(battle.damage_to(false) == Battle.DAMAGE_HIT, "the wrong bot takes 20")
	check(rng.state == state, "an injected bot does not consume the random generator")


func _check_damage_cases() -> void:
	var correct_wrong: Battle = fresh(scripted(false, 2000))
	play_round(correct_wrong, 1, 1000, false, 2000)
	check(correct_wrong.player_hp == 100 and correct_wrong.bot_hp == 80, "correct versus wrong deals 20 to the bot")
	check(correct_wrong.average_correct_ms(true) == 1000.0, "average uses the correct answer only")
	check(correct_wrong.average_correct_ms(false) == -1.0, "a wrong answer has no average")

	var correct_timeout: Battle = fresh(scripted(false, 20000))
	play_round(correct_timeout, 1, 1000, false, 20000)
	check(correct_timeout.bot_hp == 80 and correct_timeout.player_hp == 100, "the first correct answer deals 20 before a late bot")
	check(not correct_timeout.side_timed_out(false) and not correct_timeout.side_timed_out(true), "a won round does not time the opponent out")

	var wrong_correct: Battle = fresh(scripted(true, 2000))
	var wrong_opened: int = open_question(wrong_correct)
	check(wrong_correct.submit_player(0, wrong_opened + 1000), "a wrong answer is accepted")
	check(wrong_correct.phase == Battle.Phase.QUESTION, "the rival can still answer after a wrong lock")
	check(not wrong_correct.submit_player(1, wrong_opened + 1200), "the wrong player cannot answer twice")
	wrong_correct.tick(wrong_opened + 2000)
	check(wrong_correct.phase == Battle.Phase.ROUND_RESULT, "the rival's correct answer resolves the round")
	check(wrong_correct.player_hp == 80 and wrong_correct.bot_hp == 100, "the first correct rival deals 20")

	var timeout_correct: Battle = fresh(scripted(true, 2000))
	play_round(timeout_correct, null, -1, true, 2000)
	check(timeout_correct.player_hp == 80 and timeout_correct.bot_hp == 100, "a correct bot wins before the deadline")
	check(not timeout_correct.side_timed_out(true), "the player is locked out by the rival's correct answer")
	check(timeout_correct.player_correct == 0 and timeout_correct.average_correct_ms(true) < 0.0, "an unanswered player has no correct-answer time")
	check(timeout_correct.bot_correct == 1 and timeout_correct.average_correct_ms(false) == 2000.0, "the bot average is its correct response")

	var player_first: Battle = fresh(scripted(true, 3000))
	play_round(player_first, 1, 1000, true, 3000)
	check(player_first.player_hp == 100 and player_first.bot_hp == 80, "the first correct player deals 20")
	check(not player_first.side_correct(false), "the later bot answer is not recorded")

	var bot_first: Battle = fresh(scripted(true, 1500))
	var bot_opened: int = open_question(bot_first)
	bot_first.tick(bot_opened + 1500)
	check(bot_first.phase == Battle.Phase.ROUND_RESULT, "the bot's correct answer resolves immediately")
	check(not bot_first.submit_player(1, bot_opened + 4000), "the player cannot answer after the rival wins")
	check(bot_first.player_hp == 80 and bot_first.bot_hp == 100, "the first correct bot deals 20")

	var both_wrong: Battle = fresh(scripted(false, 2000))
	play_round(both_wrong, 0, 1000, false, 2000)
	check(both_wrong.player_hp == 100 and both_wrong.bot_hp == 100, "both wrong deals no damage")
	check(both_wrong.player_correct_ms == 0 and both_wrong.bot_correct_ms == 0, "wrong answers add no time")

	var wrong_timeout: Battle = fresh(scripted(false, 20000))
	play_round(wrong_timeout, 0, 1000, false, 20000)
	check(wrong_timeout.player_hp == 100 and wrong_timeout.bot_hp == 100, "wrong versus timeout deals no damage")
	check(wrong_timeout.side_timed_out(false), "the late bot times out")


func _check_ko() -> void:
	var battle: Battle = fresh(scripted(true, 2000))
	for _round: int in 5:
		play_round(battle, 0, 1000, true, 2000)
	check(battle.player_hp == 0 and battle.bot_hp == 100, "five hits put the player on the floor")
	check(battle.rounds_played == 5, "KO stops at the fifth round")
	close_match(battle)
	check(battle.phase == Battle.Phase.FINISHED, "KO finishes the match")
	check(battle.winner() == Battle.Outcome.BOT_WIN, "the standing rival wins")
	check(battle.question_ids().size() > battle.rounds_played, "the KO fixture still had rounds left")
	check(battle.rounds_played == 5, "KO reports the rounds actually played")
	battle.tick(battle.result_ends_at + 100000)
	check(battle.player_hp == 0 and battle.rounds_played == 5 and battle.phase == Battle.Phase.FINISHED, "a finished KO cannot resolve again")


func _check_first_correct_race() -> void:
	var player_win: Battle = fresh(scripted(true, 3000))
	var opened: int = open_question(player_win)
	var before: int = player_win.bot_hp
	check(player_win.submit_player(1, opened + 400), "the player's correct answer is accepted")
	check(player_win.phase == Battle.Phase.ROUND_RESULT, "player correct first resolves immediately")
	check(player_win.damage_to(false) == Battle.DAMAGE_HIT and player_win.bot_hp == before - Battle.DAMAGE_HIT, "the round winner deals 20")
	check(not player_win.side_correct(false), "the opponent's answer is not revealed after the player wins")
	check(not player_win.submit_player(0, opened + 500), "late submission rejected after correct answer resolved round")
	player_win.tick(opened + 3000)
	check(player_win.rounds_played == 1 and player_win.bot_hp == before - Battle.DAMAGE_HIT, "delayed bot answer ignored after player wins")
	var rival_win: Battle = fresh(scripted(true, 1200))
	var rival_opened: int = open_question(rival_win)
	rival_win.tick(rival_opened + 1200)
	check(rival_win.phase == Battle.Phase.ROUND_RESULT and rival_win.player_hp == 80, "bot correct first resolves immediately")
	check(not rival_win.submit_player(1, rival_opened + 1300), "player input is rejected after the rival answers first")
	var missed: Battle = fresh(scripted(true, 2500))
	var missed_opened: int = open_question(missed)
	check(missed.submit_player(0, missed_opened + 300), "a wrong answer locks that player")
	check(missed.phase == Battle.Phase.QUESTION and missed.player_hp == 100 and missed.bot_hp == 100, "wrong answer does not resolve round")
	check(not missed.side_correct(true) and missed.bot_response_ms() == -1, "a wrong lock does not reveal the rival")
	check(not missed.submit_player(1, missed_opened + 400), "wrong player cannot answer twice")
	check(missed.phase == Battle.Phase.QUESTION, "opponent can still answer after other player is wrong")
	missed.tick(missed_opened + 2500)
	check(missed.phase == Battle.Phase.ROUND_RESULT and missed.player_hp == 80, "the other player can still win after a wrong lock")
	var quiet: Battle = fresh(scripted(false, 20000))
	var quiet_opened: int = open_question(quiet)
	quiet.tick(quiet.round_ends_at)
	check(quiet.phase == Battle.Phase.ROUND_RESULT, "a deadline with no correct answer resolves")
	check(quiet.player_hp == 100 and quiet.bot_hp == 100 and quiet.damage_to(true) == 0 and quiet.damage_to(false) == 0, "timeout with no correct answer = no damage")
	check(quiet.side_timed_out(true) and quiet.side_timed_out(false), "both unanswered sides time out")
	check(quiet_opened >= 0, "the timeout fixture opened a question")


func _check_match_continues_until_ko() -> void:
	var battle: Battle = fresh(scripted(false, 2000))
	for _round: int in 7:
		play_round(battle, 0, 1000, false, 2000)
	check(battle.rounds_played == 7, "seven rounds are played without a round cap")
	check(battle.player_hp == 100 and battle.bot_hp == 100, "seven wrong rounds leave both at full HP")
	check(battle.phase == Battle.Phase.ROUND_RESULT, "round 7 does not finish the match")
	check(battle.winner() == Battle.Outcome.ONGOING, "alive players have no winner after round 7")
	close_match(battle)
	check(battle.phase == Battle.Phase.COUNTDOWN and battle.round_number == 8, "the match reaches round 8")
	check(battle.winner() == Battle.Outcome.ONGOING, "round 8 starts with both players alive")
	play_round(battle, 0, 1000, false, 2000)
	check(battle.rounds_played == 8 and battle.phase == Battle.Phase.ROUND_RESULT, "round 8 resolves without ending the match")
	check(battle.average_correct_ms(true) < 0.0 and battle.average_correct_ms(false) < 0.0, "no correct answers means no average")
	var knocked: Battle = fresh(scripted(true, 2000))
	for _round: int in 5:
		play_round(knocked, 0, 1000, true, 2000)
	check(knocked.player_hp == 0 and knocked.rounds_played == 5, "five hits knock the player out")
	close_match(knocked)
	check(knocked.phase == Battle.Phase.FINISHED and knocked.winner() == Battle.Outcome.BOT_WIN, "a match ends only when HP reaches 0")
	check(knocked.rounds_played == 5, "KO reports the rounds actually played")


func _check_live_bank() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var pool: Array = []
	var bank: Dictionary = root.get_node("ContentDB").get_questions()
	for skill: Variant in bank.keys():
		var rows: Variant = bank[skill]
		if typeof(rows) != TYPE_ARRAY:
			continue
		var list: Array = rows as Array
		for row: Variant in list:
			pool.append(row)
	var eligible: Dictionary = {}
	for row: Variant in pool:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var question: Dictionary = row as Dictionary
		if Quiz.is_multi(question):
			continue
		var qid: String = Battle.question_id(question)
		if qid.is_empty() or Quiz.options(question).is_empty() or eligible.has(qid):
			continue
		eligible[qid] = true
	var deck: Array[Dictionary] = Battle.build_deck(pool, 0, rng)
	check(deck.size() == eligible.size() and deck.size() > 7, "the live bank keeps every eligible question")
	var seen: Dictionary = {}
	for row: Dictionary in deck:
		var qid: String = Battle.question_id(row)
		check(not qid.is_empty() and not seen.has(qid), "live deck ids are present and unique")
		seen[qid] = true
		check(not Quiz.is_multi(row), "live deck skips multi-select")


func _check_screen() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://src/ui/screens/pvp/pvp_battle_screen.tscn")
	var screen: BaseScreen = packed.instantiate() as BaseScreen
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var status: Label = screen.find_child("BattleStatus", true, false) as Label
	check(status != null and status.text == "GET READY", "the duel screen opens on the countdown")
	check(screen.consume_back(), "back during a match asks before leaving")
	var confirm: Control = screen.find_child("AbandonConfirm", true, false) as Control
	check(confirm != null and confirm.visible, "abandon confirmation is shown")
	check(screen.is_inside_tree(), "the match stays mounted")
	screen.consume_back()
	check(confirm != null and not confirm.visible, "a second back cancels the confirmation")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		var back: Control = screen.find_child("BackButton", true, false) as Control
		check(back != null and root.get_visible_rect().encloses(back.get_global_rect()), "back stays on screen at %s" % dimensions)
		screen.consume_back()
		var stay: Control = screen.find_child("StayButton", true, false) as Control
		var leave: Control = screen.find_child("AbandonLeaveButton", true, false) as Control
		check(stay != null and root.get_visible_rect().encloses(stay.get_global_rect()), "stay stays on screen at %s" % dimensions)
		check(leave != null and root.get_visible_rect().encloses(leave.get_global_rect()), "leave stays on screen at %s" % dimensions)
		screen.consume_back()
	screen.queue_free()
	await settle()


func _count_bot(_question: Dictionary, calls: Array) -> Dictionary:
	calls[0] = int(calls[0]) + 1
	return {"correct": false, "delay_ms": 1000}


func _check_short_and_empty_decks() -> void:
	var calls: Array = [0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	var text_only: Dictionary = {"question": "text only", "options": ["no", "yes"], "answer_index": 1}
	var multi: Dictionary = question_row("multi")
	multi["delivery"] = "multi_select"
	multi["type_id"] = "tap_trap_lines"
	var ineligible: Array = [text_only, multi, {"id": "   ", "options": ["no", "yes"], "answer_index": 0}]
	check(Battle.build_deck(ineligible, 0, rng).is_empty(), "ineligible rows do not fill a deck")
	var empty: Battle = Battle.new()
	empty.set_bot_policy(_count_bot.bind(calls))
	check(not empty.start(ineligible, 0, rng), "zero eligible questions does not start")
	empty.tick(1000000)
	check(empty.phase == Battle.Phase.PREPARING, "an empty match never leaves preparing")
	check(empty.winner() == Battle.Outcome.ONGOING, "an empty match has no winner")
	check(empty.rounds_played == 0 and empty.player_hp == 100, "an empty match deals no damage")
	check(int(calls[0]) == 0, "an empty match never schedules a bot")
	var deck: Array = [question_row("s1"), question_row("s2"), question_row("s3")]
	deck.append_array(ineligible)
	var built: Array[Dictionary] = Battle.build_deck(deck, 0, rng)
	check(built.size() == 3, "a short bank stays short")
	var short: Battle = Battle.new()
	short.set_bot_policy(_count_bot.bind(calls))
	check(short.start(built, 0, rng), "a three-question match starts")
	short.tick(0)
	var seen_ids: PackedStringArray = PackedStringArray()
	var last_id: String = ""
	for _round: int in 3:
		var opened: int = open_question(short)
		check(opened >= 0, "short-deck question opened")
		last_id = Battle.question_id(short.current_question())
		check(not seen_ids.has(last_id), "a deck does not repeat a question before it is exhausted")
		seen_ids.append(last_id)
		check(short.submit_player(0, opened + 500), "short-deck answer accepted")
		short.tick(short.round_ends_at)
		check(short.phase == Battle.Phase.ROUND_RESULT, "short-deck round resolved")
	check(short.rounds_played == 3 and short.player_hp == 100 and short.bot_hp == 100, "an exhausted deck does not end a live match")
	close_match(short)
	check(short.phase == Battle.Phase.COUNTDOWN and short.round_number == 4, "a new deck continues the match")
	check(short.winner() == Battle.Outcome.ONGOING, "refreshing the deck does not pick a winner")
	var refreshed: PackedStringArray = PackedStringArray(short.question_ids())
	check(refreshed.size() == 3 and refreshed.has("s1") and refreshed.has("s2") and refreshed.has("s3"), "the new deck reuses the eligible questions")
	var next_opened: int = open_question(short)
	check(next_opened >= 0, "the refreshed deck opens a question")
	var next_id: String = Battle.question_id(short.current_question())
	check(next_id != last_id, "a new deck avoids repeating the previous question")
	check(int(calls[0]) == 4, "the bot is scheduled once per opened round")
	var pair: Battle = Battle.new()
	var pair_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pair_rng.seed = 9
	pair.set_bot_policy(scripted(false, 1000))
	check(pair.start([question_row("left"), question_row("right")], 0, pair_rng), "a two-question match starts")
	pair.tick(0)
	var first_opened: int = open_question(pair)
	var first_id: String = Battle.question_id(pair.current_question())
	check(pair.submit_player(0, first_opened + 100), "the first pair answer locks")
	pair.tick(pair.round_ends_at)
	play_round(pair, 0, 100, false, 1000)
	var second_id: String = Battle.question_id(pair.current_question())
	close_match(pair)
	var third_opened: int = open_question(pair)
	check(third_opened >= 0 and pair.round_number == 3, "two questions still continue into round 3")
	check(Battle.question_id(pair.current_question()) == first_id and first_id != second_id, "a refreshed deck does not repeat the question just played")


func _check_result_hold_and_retired_match() -> void:
	var battle: Battle = fresh(scripted(false, 1000))
	var opened: int = open_question(battle)
	check(battle.submit_player(1, opened + 400), "early answer locks")
	battle.tick(battle.bot_answers_at)
	check(battle.phase == Battle.Phase.ROUND_RESULT, "early answers resolve before the question deadline")
	check(battle.result_ends_at < battle.round_ends_at, "the result hold ends before the old question deadline")
	var rounds: int = battle.rounds_played
	var hp: int = battle.bot_hp
	battle.tick(battle.result_ends_at - 1)
	check(battle.phase == Battle.Phase.ROUND_RESULT and battle.rounds_played == rounds and battle.bot_hp == hp, "the question timer does not resolve during the result hold")
	battle.retire()
	battle.tick(battle.round_ends_at + 100000)
	check(not battle.submit_player(0, battle.round_ends_at), "a retired match rejects input")
	check(battle.phase == Battle.Phase.ROUND_RESULT and battle.rounds_played == rounds and battle.bot_hp == hp, "a delayed tick cannot advance a retired match")


func _check_screen_hardening() -> void:
	root.size = Vector2i(1280, 720)
	var screen: Control = (load("res://src/ui/screens/pvp/pvp_battle_screen.tscn") as PackedScene).instantiate() as Control
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var battle: Battle = screen.get("_battle") as Battle
	var deadline: int = battle.countdown_ends_at
	(screen.get("_abandon") as Control).show()
	var frozen: int = int(screen.call("_clock_now"))
	await create_timer(0.08).timeout
	var still: int = int(screen.call("_clock_now"))
	check(still == frozen, "the leave dialog freezes the battle clock")
	check(battle.countdown_ends_at == deadline, "the leave dialog does not move absolute deadlines")
	check(battle.phase == Battle.Phase.COUNTDOWN, "a frozen clock does not start the question")
	(screen.get("_abandon") as Control).hide()
	var resumed: int = int(screen.call("_clock_now"))
	check(resumed == frozen, "closing the dialog resumes at the frozen timestamp")
	check(deadline - resumed == deadline - frozen, "remaining time is unchanged by the dialog")
	var replaced: Battle = screen.get("_battle") as Battle
	var replaced_hp: int = replaced.player_hp
	var bar: Control = screen.get("_player_bar") as Control
	var bar_links: int = bar.resized.get_connections().size()
	var rematch: Button = screen.find_child("RematchButton", true, false) as Button
	rematch.pressed.emit()
	var current: Battle = screen.get("_battle") as Battle
	check(current != replaced, "rematch installs a new battle")
	check(current.player_hp == 100 and current.bot_hp == 100, "rematch restores both HP totals")
	check(current.rounds_played == 0 and current.player_correct == 0 and current.bot_correct == 0, "rematch clears round totals")
	check(current.winner() == Battle.Outcome.ONGOING, "rematch has no inherited winner")
	check(int(screen.get("_paused_total")) == 0 and int(screen.get("_pause_started")) < 0, "rematch clears the pause clock")
	check(replaced.phase_changed.get_connections().size() == 0, "rematch disconnects the old battle")
	check(current.phase_changed.get_connections().size() == 1, "rematch listens to the new battle once")
	check(bar.resized.get_connections().size() == bar_links, "rematch does not stack bar callbacks")
	replaced.tick(100000000)
	check(not replaced.submit_player(1, 100000000), "a replaced match rejects input")
	current = screen.get("_battle") as Battle
	check(replaced.player_hp == replaced_hp and current.player_hp == 100 and current.rounds_played == 0, "a delayed tick cannot reach the new match")
	_check_displayed_choices(screen)
	var active: Battle = screen.get("_battle") as Battle
	screen.call("on_exit")
	check(screen.get("_battle") == null, "leave drops the battle")
	check(active.phase_changed.get_connections().size() == 0, "leave disconnects the battle")
	var left_hp: int = active.player_hp
	var left_rounds: int = active.rounds_played
	screen.call("_process", 0.1)
	active.tick(100000000)
	check(active.player_hp == left_hp and active.rounds_played == left_rounds, "leave ignores a delayed bot tick")
	screen.queue_free()
	await settle()


func _check_displayed_choices(screen: Control) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8
	var now: int = Time.get_ticks_msec()
	var battle: Battle = Battle.new()
	battle.set_bot_policy(scripted(false, 8000))
	var questions: Array = [_choice_question(), _binary_question(), _false_question()]
	check(battle.start(questions, now, rng), "choice fixture starts")
	battle.tick(now)
	battle.tick(now + Battle.COUNTDOWN_MS)
	screen.call("_bind_battle", battle)
	screen.call("_render_phase")
	_assert_pressed_choice(screen, battle, false)
	battle.tick(battle.result_ends_at)
	battle.tick(battle.countdown_ends_at)
	_assert_pressed_choice(screen, battle, true)
	battle.tick(battle.result_ends_at)
	battle.tick(battle.countdown_ends_at)
	_assert_pressed_choice(screen, battle, true)


func _assert_pressed_choice(screen: Control, battle: Battle, want_correct: bool) -> void:
	check(battle.phase == Battle.Phase.QUESTION, "choice fixture is on a question")
	var buttons: Array = screen.get("_answer_buttons") as Array
	var choices: Array = screen.get("_choices") as Array
	check(buttons.size() == choices.size() and choices.size() >= 2, "every graded option has a button")
	var selected: int = -1
	for index: int in choices.size():
		var choice: Dictionary = choices[index] as Dictionary
		var label: String = str(choice.get("text", ""))
		if label == "Phishing":
			label = "Suspicious / attack"
		check((buttons[index] as Button).text == label, "button text stays paired with its graded value")
		var graded: bool = Quiz.grade(battle.current_question(), choice.get("value"))
		if selected < 0 and graded == want_correct:
			selected = index
	check(selected >= 0, "the fixture has the requested grade")
	var picked: Variant = (choices[selected] as Dictionary).get("value")
	(buttons[selected] as Button).pressed.emit()
	if not want_correct:
		var waiting: Label = screen.find_child("BattleStatus", true, false) as Label
		check(waiting != null and waiting.text == "INCORRECT — WAITING FOR RIVAL", "a wrong press waits without revealing the answer")
		check((buttons[selected] as Button).disabled, "a wrong press locks the answer buttons")
	if battle.phase == Battle.Phase.QUESTION:
		battle.tick(mini(battle.bot_answers_at, battle.round_ends_at))
		if battle.phase == Battle.Phase.QUESTION:
			battle.tick(battle.round_ends_at)
	check(battle.phase == Battle.Phase.ROUND_RESULT, "the pressed option resolves when the race ends")
	if want_correct:
		var headline: Label = screen.get("_result_title") as Label
		check(headline != null and headline.text == "CORRECT — ATTACK!", "the first correct press attacks immediately")
	check(battle.player_pick() == picked, "the pressed button submits its own graded value")
	check(battle.side_correct(true) == Quiz.grade(battle.current_question(), picked), "the submitted value matches Quiz.grade")
	check(battle.side_correct(true) == want_correct, "the pressed option has the expected grade")


func _choice_question() -> Dictionary:
	return {
		"id": "grade_mc",
		"delivery": "multiple_choice_4",
		"question": "Which sign is strongest?",
		"options": ["All caps", "A swapped character", "Morning send", "The word enrollment"],
		"answer_index": 1.0,
	}


func _binary_question() -> Dictionary:
	return {
		"id": "grade_bin",
		"delivery": "binary_ab",
		"type_id": "trust_verdict",
		"question": "Phishing or legitimate?",
		"correct_answer": "phishing",
	}


func _false_question() -> Dictionary:
	return {
		"id": "grade_tf",
		"delivery": "true_false",
		"type_id": "safety_rule_tf",
		"text": "A matching display name proves the message is safe.",
		"answer": false,
	}


func _count(phases: Array[int], phase: int) -> int:
	var total: int = 0
	for item: int in phases:
		if item == phase:
			total += 1
	return total
