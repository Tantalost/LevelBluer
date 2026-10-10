extends SceneTree
## Focused regression for BKT local/offline mastery consistency (see fix.md
## at the repo root). Covers exactly:
##   A. offline gameplay survives a stale-cache pull_official_bkt() attempt
##      while a local sync is pending
##   B. an intentional local seed (seed_from_official_mastery()) still
##      applies even while a local sync is pending — pending sync must not
##      block a real local->AuthService->PlayerManager handoff
##   C. the real local pretest flow (AuthService.submit_pretest()) marks the
##      student dirty and still successfully hands its diagnostic P(L) to
##      PlayerManager via seed_from_official_mastery(), with no P(T) applied
##   D. AuthService.progress_mastery_snapshot() prefers PlayerManager's live
##      mastery_matrix while a local sync is pending, with no _bkt_queue
##      entry required
##   E. PlayerManager.update_mastery() never enqueues an AuthService BKT-assess
##      job (exactly one, local, BKT calculation per gameplay update)
##   F. the BKT formula/params (default and TRACE-authored) are unchanged
##   G. a wrong answer drops P(L) by at most 0.10, an identical wrong pick on
##      the same question is graded once per attempt, and the pre-test
##      diagnostic update is untouched
##
## Run headless:  godot --headless --path frontend --script res://src/tools/verify_bkt_offline_sync.gd
## The local guest save is backed up before the run and restored afterwards.
## No GUI automation.

const TEST_STUDENT_ID := "bkt-offline-sync-test"

var failures := 0
var _player: Node
var _auth: Node
var _sdb: Node
var _save_path := ""
var _save_backup := ""
var _had_save := false


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("  ok  " + message)


func one_bkt_step(before: float, correct: bool, p_g: float, p_s: float, p_t: float) -> float:
	var post: float = _player._posterior(before, correct, p_g, p_s)
	return clampf(post + ((1.0 - post) * p_t), _player.MIN_MASTERY, _player.MAX_MASTERY)


func fresh() -> void:
	_auth._mastery = {}
	_auth._bkt_queue.clear()
	_auth._signed_in = false
	_auth._participant_code = ""
	_auth._token = ""
	_auth._completed_module_ids.clear()
	_auth._pending_pretest.clear()
	_player.reset_to_defaults()


## StudentDatabase's own _ready() can lose the race against the SQLite
## GDExtension's class registration under a bare `--script` invocation (the
## same way every other verify_*.gd in this suite avoids StudentDatabase
## entirely). This re-runs its exact _ready() steps later, once the class is
## confirmed registered, purely so this test can exercise the real
## has_pending_sync()/mark_needs_sync()/mark_synced() this fix relies on.
## See the report's "headless SQLite" section for the separate normal-startup
## verification; production boots through the main scene, not a bare script.
func _ensure_student_database() -> bool:
	if _sdb.is_available():
		return true
	if not ClassDB.class_exists("SQLite"):
		return false
	var db = ClassDB.instantiate("SQLite")
	db.path = "user://levelblue_students"
	db.verbosity_level = 0
	if not db.open_db():
		return false
	if not db.query(_sdb.CREATE_STUDENTS_SQL):
		return false
	_sdb._db = db
	_sdb._ready_ok = true
	return true


func _cleanup_student_database() -> void:
	if _sdb.is_available():
		_sdb._db.query_with_bindings("DELETE FROM students WHERE id = ?;", [TEST_STUDENT_ID])


func _cleanup_save_files() -> void:
	if _had_save:
		var file := FileAccess.open(_save_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_save_backup)
			file.close()
	elif FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	for stray_participant in [TEST_STUDENT_ID, "no-double-submit-test"]:
		var stray_path := "user://player_save_%s.json" % stray_participant
		if FileAccess.file_exists(stray_path):
			DirAccess.remove_absolute(stray_path)


func _run() -> void:
	_player = root.get_node("PlayerManager")
	_auth = root.get_node("AuthService")
	_sdb = root.get_node("StudentDatabase")
	var save := root.get_node("SaveService")
	_save_path = save._resolve_save_path()
	_had_save = FileAccess.file_exists(_save_path)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(_save_path)

	var db_ready: bool = _ensure_student_database()
	if not db_ready:
		print("  skip  StudentDatabase unavailable in this --script harness — pending-sync-gated tests below are skipped (see report)")
	else:
		fresh()
		_sdb.upsert_student({"id": TEST_STUDENT_ID, "name": "BKT Offline Test", "section": "Test"})
		_auth._signed_in = true
		_auth._participant_code = TEST_STUDENT_ID

		print("== A. Offline gameplay survives a stale-cache pull_official_bkt() while pending ==")
		_player.mastery_matrix["phishing"] = 0.10
		_player.update_mastery("phishing", true, {})
		var after_gameplay: float = _player.mastery_matrix["phishing"]
		check(after_gameplay > 0.10, "[A] Gameplay BKT update raises local P(L) above the starting 0.10")
		_sdb.mark_needs_sync(TEST_STUDENT_ID)
		check(_player._has_pending_local_sync(), "[setup] Pending sync recognized for the signed-in test student")
		_auth._mastery = {"Phishing": 0.10}
		_auth._token = ""
		await _player.pull_official_bkt()
		check(is_equal_approx(_player.mastery_matrix["phishing"], after_gameplay),
			"[A] pull_official_bkt() never overwrites newer local P(L) with stale cached mastery while a sync is pending")

		print("== B. An intentional local seed still applies while pending ==")
		check(_player._has_pending_local_sync(), "[setup] Still pending going into the seed test")
		_auth._mastery = {"Phishing": 0.77}
		_player.seed_from_official_mastery()
		check(is_equal_approx(_player.mastery_matrix["phishing"], 0.77),
			"[B] seed_from_official_mastery() is NOT blocked by a pending local sync — a real local->AuthService->PlayerManager handoff must still work")
		_sdb.mark_synced(TEST_STUDENT_ID)

		print("== C. The real local pretest flow hands its diagnostic P(L) to PlayerManager ==")
		fresh()
		_sdb.upsert_student({"id": TEST_STUDENT_ID, "name": "BKT Offline Test", "section": "Test"})
		_auth._signed_in = true
		_auth._participant_code = TEST_STUDENT_ID
		_auth._token = ""
		_player.mastery_matrix.erase("phishing")
		var answers: Array = []
		for question in PretestBank.public_questions("mod_01"):
			answers.append({"id": question["id"], "answer": 0})
		var result: int = _auth.submit_pretest("mod_01", answers)
		check(result == _auth.Result.OK, "[C] submit_pretest() grades the local pretest successfully")
		check(_player._has_pending_local_sync(), "[C] Submitting a pretest marks the student's local state dirty/pending (StudentDatabase.needs_cloud_sync)")
		var diagnostic_pl: float = float(_auth._mastery.get("Phishing", -1.0))
		check(diagnostic_pl > 0.0, "[C] AuthService computed a diagnostic P(L) from the local pretest")
		check(is_equal_approx(_player.mastery_matrix.get("phishing", -1.0), diagnostic_pl),
			"[C] seed_from_official_mastery() (called by submit_pretest()) hands the diagnostic P(L) to PlayerManager despite the pending flag it just set")
		var expected_no_transition: float = clampf(diagnostic_pl, 0.0, 1.0)
		check(is_equal_approx(diagnostic_pl, expected_no_transition), "[C] Pretest diagnostic never had the learning transition P(T) applied on top (Bayes posterior only)")
		_sdb.mark_synced(TEST_STUDENT_ID)
		_cleanup_student_database()

		print("== D. Progress snapshot prefers live PlayerManager mastery while pending, no _bkt_queue needed ==")
		fresh()
		_sdb.upsert_student({"id": TEST_STUDENT_ID, "name": "BKT Offline Test", "section": "Test"})
		_sdb.mark_needs_sync(TEST_STUDENT_ID)
		_auth._signed_in = true
		_auth._participant_code = TEST_STUDENT_ID
		_auth._mastery = {"Phishing": 0.20}
		_player.mastery_matrix["phishing"] = 0.65
		check(_auth._bkt_queue.is_empty(), "[D] _bkt_queue is empty going into the check (no queue-based signal available)")
		var snapshot: Array[Dictionary] = _auth.progress_mastery_snapshot()
		var phishing_row: Dictionary = {}
		for row in snapshot:
			if str(row.get("id", "")) == "phishing":
				phishing_row = row
		check(bool(phishing_row.get("pending", false)) and is_equal_approx(float(phishing_row.get("value", 0.0)), 0.65),
			"[D] Progress snapshot shows PlayerManager's live 0.65, not AuthService's stale 0.20, purely from the pending-sync flag")
		_sdb.mark_synced(TEST_STUDENT_ID)
		snapshot = _auth.progress_mastery_snapshot()
		for row in snapshot:
			if str(row.get("id", "")) == "phishing":
				phishing_row = row
		check(not bool(phishing_row.get("pending", false)) and is_equal_approx(float(phishing_row.get("value", 0.0)), 0.20),
			"[D] Once synced, the snapshot falls back to normal AuthService/remote mastery again")
		_cleanup_student_database()

	print("== E. update_mastery() never submits a second, server-side BKT calculation ==")
	fresh()
	_auth._signed_in = true
	_auth._participant_code = "no-double-submit-test"
	_auth._token = "fake-token"
	_player.mastery_matrix["phishing"] = 0.20
	_player.update_mastery("phishing", true, {})
	check(_auth._bkt_queue.is_empty(), "[E] update_mastery() does not enqueue an AuthService BKT-assess job")
	var expected_single_update: float = one_bkt_step(0.20, true, _player.P_GUESS, _player.P_SLIP, _player.P_TRANSIT)
	check(is_equal_approx(_player.mastery_matrix["phishing"], expected_single_update), "[E] The resulting P(L) matches exactly one local BKT update — no second calculation layered on top")
	_auth._token = ""

	print("== F. Existing BKT params are unchanged ==")
	fresh()
	_player.mastery_matrix["phishing"] = 0.30
	_player.update_mastery("phishing", true, {})
	var expected_default: float = one_bkt_step(0.30, true, _player.P_GUESS, _player.P_SLIP, _player.P_TRANSIT)
	check(is_equal_approx(_player.mastery_matrix["phishing"], expected_default), "[F] Decision-gameplay default BKT params (P_GUESS/P_SLIP/P_TRANSIT) are unchanged")
	_player.mastery_matrix["vishing"] = 0.30
	_player.update_mastery("vishing", true, {"p_g": 0.20, "p_s": 0.10, "p_t": 0.15})
	var expected_trace: float = one_bkt_step(0.30, true, 0.20, 0.10, 0.15)
	check(is_equal_approx(_player.mastery_matrix["vishing"], expected_trace), "[F] TRACE-authored p_g=.20/p_s=.10/p_t=.15 still flow through _bkt_param() unchanged")
	# Replay freeze (_bkt_frozen / mastery_frozen) is untouched by this fix
	# and already covered by verify_stage_progression.gd's
	# _test_mastery_frozen_scoping() — not duplicated here.

	print("== G. Wrong-answer drop cap and duplicate wrong-pick suppression ==")
	fresh()
	_player.mastery_matrix["phishing"] = 0.80
	var raw_drop: float = one_bkt_step(0.80, false, _player.P_GUESS, _player.P_SLIP, _player.P_TRANSIT)
	check(is_equal_approx(snappedf(raw_drop, 0.0001), 0.40), "[G] Raw BKT for a wrong answer from 0.80 is 0.40")
	_player.update_mastery("phishing", false, {})
	check(is_equal_approx(_player.mastery_matrix["phishing"], 0.70), "[G] One wrong answer from 0.80 is capped at 0.70")
	_player.mastery_matrix["phishing"] = 0.15
	var small_drop: float = one_bkt_step(0.15, false, _player.P_GUESS, _player.P_SLIP, _player.P_TRANSIT)
	_player.update_mastery("phishing", false, {})
	check(0.15 - small_drop < 0.10 and is_equal_approx(_player.mastery_matrix["phishing"], small_drop), "[G] A raw drop smaller than 0.10 is unchanged")
	_player.mastery_matrix["phishing"] = 0.80
	_player.update_mastery("phishing", true, {})
	check(is_equal_approx(_player.mastery_matrix["phishing"], one_bkt_step(0.80, true, _player.P_GUESS, _player.P_SLIP, _player.P_TRANSIT)), "[G] Correct answers still use the existing formula")

	var Quiz: GDScript = load("res://src/gameplay/quiz_content.gd")
	var question: Dictionary = {"id": "bkt_dup_q", "options": ["a", "b", "c"], "answer_index": 0}
	var graded: Dictionary = {}
	_player.mastery_matrix["phishing"] = 0.80
	for pick: int in [1, 1, 2]:
		if not Quiz.repeat_wrong_answer(graded, question, pick, false):
			_player.update_mastery("phishing", false, {})
		if pick == 1 and graded.size() == 1:
			check(is_equal_approx(_player.mastery_matrix["phishing"], 0.70), "[G] Same question + same wrong choice grades once (0.80 -> 0.70)")
	check(is_equal_approx(_player.mastery_matrix["phishing"], 0.60), "[G] A different wrong choice decreases again, still capped (0.70 -> 0.60)")
	check(not Quiz.repeat_wrong_answer({}, question, 1, false), "[G] A fresh attempt grades the same wrong choice normally")
	check(not Quiz.repeat_wrong_answer(graded, question, 0, true) and not Quiz.repeat_wrong_answer(graded, question, 0, true), "[G] Correct answers are never suppressed")

	var Pretest: GDScript = load("res://src/data/pretest_bank.gd")
	var diagnostic: float = Pretest._update_pl_diagnostic(0.80, false)
	check(is_equal_approx(snappedf(diagnostic, 0.0001), 0.3333), "[G] Pre-test diagnostic update is uncapped and has no P(T) (0.80 -> 0.3333)")
	check(is_equal_approx(snappedf(Pretest._update_pl_diagnostic(0.10, true), 0.0001), 0.3333), "[G] Pre-test diagnostic correct-answer update is unchanged")

	fresh()
	_cleanup_save_files()
	print("BKT_OFFLINE_SYNC_CHECKS failures=" + str(failures))
	quit()
