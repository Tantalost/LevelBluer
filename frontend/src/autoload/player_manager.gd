extends Node
signal avatar_changed
signal progress_changed
const Avatars = preload("res://src/ui/screens/profile/avatar_portrait.gd")
const Remediation: GDScript = preload("res://src/gameplay/decision/stage_remediation.gd")
var remediation_state: Dictionary = {"sessions": []}
var selected_avatar_id: String = "byte_bot"
## Autoload singleton, registered as "PlayerManager".
## Lesson progress is persisted per signed-in participant.

const P_GUESS: float = 0.2
const P_SLIP: float = 0.1
const P_TRANSIT: float = 0.1
const DEFAULT_MASTERY: float = 0.10
const MIN_MASTERY: float = 0.01
const MAX_MASTERY: float = 0.99
const MAX_WRONG_DROP: float = 0.10
const AT_RISK_MASTERY: float = 0.40
const PROFICIENT_MASTERY: float = 0.70
const ALL_MODULES_LESSON := "mod1_all"
const _OFFICIAL_SKILLS: PackedStringArray = [
	"phishing",
	"smishing",
	"vishing",
	"pretexting",
	"baiting",
]

var mastery_matrix: Dictionary = {
	"phishing": DEFAULT_MASTERY,
}
var unlocked_skills: Array[String] = []
## Both keyed by the canonical "module_id:stage_id" string (see
## stage_progress_key()) — e.g. "mod_01:1" and "mod_02:1" never collide.
## Never key either of these by raw stage number alone.
var locked_stages: Dictionary = {}
var cleared_stages: Dictionary = {}
var completed_lessons: Array[String] = []
var lesson_progress: Dictionary = {}
var lesson_post_quiz_scores: Dictionary = {}
var lesson_quiz_responses: Dictionary = {}
## One first-response audit per practice-bank item; bounded by the authored bank.
var practice_responses: Dictionary = {}
var mission_progress: Dictionary = {}
var pretest_baselines: Dictionary = {}
var purchased_items: Array[String] = []
var unlocked_towers: Array[String] = ["base"]
var tech_ranks: Dictionary = {}
var has_stateful_inspection: bool = false
## Per-module progression ceiling: max_stage_cleared_by_module["mod_01"] is
## the highest stage cleared in Module 1, independent of every other module.
## Absent means "no clears recorded yet" — see max_stage_cleared().
var max_stage_cleared_by_module: Dictionary = {}
var credits: int = 0
## Separate cosmetic wallet. No Solo reward or OS-switch path may credit it.
## PvP settlement is not implemented yet; do not grant local participation rewards.
var pvp_tokens: int = 0

const STORE_ITEMS: Array[Dictionary] = [
	{"id": "t1", "name": "Assault Frame", "price": 500, "category": "FEATURED", "art": "frame", "color": "4FE0D4", "description": "An angular cyan frame for your collection."},
	{"id": "t2", "name": "Recon Drone", "price": 350, "category": "FEATURED", "art": "drone", "color": "4F8CFF", "description": "A compact surveillance-drone collectible."},
	{"id": "t3", "name": "Ghost Cloak", "price": 1200, "category": "FEATURED", "art": "cloak", "color": "B09AFF", "description": "A shadow operative emblem with violet accents."},
	{"id": "b1", "name": "Gold Frame", "price": 300, "category": "BORDERS", "art": "frame", "color": "FFB648", "description": "A gold border with pixel-cut corners."},
	{"id": "b2", "name": "Shadow Border", "price": 600, "category": "BORDERS", "art": "frame", "color": "B09AFF", "description": "A dark border edged with violet light."},
]
var module_1_complete: bool = false
var seen_module_intros: Array[String] = []
var tutorial_complete: bool = false
var tutorial_skipped: bool = false
## Presentation-only, per-account onboarding snapshot. Never learning evidence.
var onboarding_state: Dictionary = {}
## Story chapters are separate from legacy stages, onboarding and graded BKT.
var chapter_progress: Dictionary = {}
const SurveyChapter: GDScript = preload("res://src/gameplay/decision/survey_chapter.gd")
const AdvisorChapter: GDScript = preload("res://src/gameplay/decision/advisor_chapter.gd")
const PayoutChapter: GDScript = preload("res://src/gameplay/decision/payout_chapter.gd")
const PrizeChapter: GDScript = preload("res://src/gameplay/decision/prize_chapter.gd")
const ConfrontationChapter: GDScript = preload("res://src/gameplay/decision/confrontation_chapter.gd")
const DeliveryChapter: GDScript = preload("res://src/gameplay/decision/delivery_chapter.gd")
var chapter_replays: Dictionary = {}

func story_definition(id: String) -> GDScript:
	if id == DeliveryChapter.ID: return DeliveryChapter
	return {"mod_01_ch_01":SurveyChapter, "mod_01_ch_02":AdvisorChapter, "mod_01_ch_03":PayoutChapter, "mod_01_ch_04":PrizeChapter, "mod_01_ch_05":ConfrontationChapter}.get(id)

func authored_story_ids() -> PackedStringArray:
	return [SurveyChapter.ID, AdvisorChapter.ID, PayoutChapter.ID, PrizeChapter.ID, ConfrontationChapter.ID, DeliveryChapter.ID]

func story_unlocked(id: String) -> bool:
	if id == DeliveryChapter.ID:
		return is_module_deploy_unlocked("mod_02") and chapter_progress.get(ConfrontationChapter.ID, {}).get("completed", false)
	if not is_module_deploy_unlocked("mod_01"): return false
	if id == SurveyChapter.ID: return true
	if id == AdvisorChapter.ID: return chapter_progress.get(SurveyChapter.ID, {}).get("completed", false)
	if id == PayoutChapter.ID: return chapter_progress.get(AdvisorChapter.ID, {}).get("completed", false) and chapter_progress.get(SurveyChapter.ID, {}).get("completed", false)
	if id == PrizeChapter.ID: return story_unlocked(PayoutChapter.ID) and chapter_progress.get(PayoutChapter.ID, {}).get("completed", false)
	if id == ConfrontationChapter.ID: return story_unlocked(PrizeChapter.ID) and chapter_progress.get(PrizeChapter.ID, {}).get("completed", false)
	return false

func story_checkpoint(id: String, is_replay: bool) -> Dictionary:
	return (chapter_replay_progress if id == SurveyChapter.ID else chapter_replays.get(id, {})) if is_replay else chapter_progress.get(id, {})
const StoryPerks: GDScript = preload("res://src/gameplay/decision/story_perks.gd")
var owned_perks: Array[String] = ["recap"]
var perk_loadout: Array[String] = []
var perk_attempts: Array[Dictionary] = []
var chapter_replay_progress: Dictionary = {}

func purchase_perk(id: String, persist: bool = true) -> bool:
	if id not in StoryPerks.IDS or id in owned_perks: return false
	var price: int = int(StoryPerks.DATA[id].cost)
	if credits < price: return false
	credits -= price
	owned_perks.append(id)
	if persist: SaveService.save_game()
	return true

func equip_perk(id: String, persist: bool = true) -> bool:
	if id not in owned_perks: return false
	if id in perk_loadout: perk_loadout.erase(id)
	elif perk_loadout.size() < 2: perk_loadout.append(id)
	else: return false
	if persist: SaveService.save_game()
	return true

func begin_survey_attempt(is_replay: bool, persist: bool = true) -> Dictionary:
	return begin_story_attempt(SurveyChapter.ID, is_replay, persist)

func begin_story_attempt(chapter_id: String, is_replay: bool, persist: bool = true) -> Dictionary:
	var definition: GDScript = story_definition(chapter_id)
	if definition == null or (chapter_id != SurveyChapter.ID and not story_unlocked(chapter_id)): return {}
	var raw: Dictionary = story_checkpoint(chapter_id, is_replay)
	if is_replay and raw.get("completed", false): raw = {}
	var snapshot: Dictionary = definition.clean(raw)
	if (snapshot.get("perk_run", {}) as Dictionary).is_empty() and not snapshot.get("completed", false):
		var starting_loadout: Array[String] = []
		if raw.is_empty(): starting_loadout.assign(perk_loadout)
		snapshot["perk_run"] = StoryPerks.new_run(learning_id(), starting_loadout, is_replay, raw.is_empty(), chapter_id)
	save_story_attempt(snapshot, is_replay, persist, chapter_id)
	return snapshot

func save_story_attempt(snapshot: Dictionary, is_replay: bool, persist: bool = true, chapter_id: String = "mod_01_ch_01") -> void:
	var definition: GDScript = story_definition(chapter_id)
	if definition == null or (chapter_id != SurveyChapter.ID and not story_unlocked(chapter_id)): return
	var valid: Dictionary = definition.clean(snapshot)
	var run: Dictionary = valid.get("perk_run", {})
	if not run.is_empty():
		# Preserve pre-perk hint evidence across migration and ledger reloads.
		if valid.hint_used: run["builtin_hints"] = maxi(1, int(run.get("builtin_hints", 0)))
		run["completed"] = bool(valid.completed)
		if run.completed and float(run.finished_at) == 0.0: run.finished_at = Time.get_unix_time_from_system()
		run["assist_status"] = StoryPerks.status(run, valid.hint_used)
		run["mistakes"] = valid.mistakes
		run["coins_awarded"] = int(valid.reward) if valid.completed and not is_replay else 0
		var found: bool = false
		for index: int in perk_attempts.size():
			if perk_attempts[index].id == run.id:
				if not perk_attempts[index].get("completed", false): perk_attempts[index] = run.duplicate(true)
				found = true
				break
		if not found: perk_attempts.append(run.duplicate(true))
	if is_replay:
		if chapter_id == SurveyChapter.ID: chapter_replay_progress = valid
		else: chapter_replays[chapter_id] = valid
		if persist: SaveService.save_game()
	else: save_chapter(valid, chapter_id, persist)

func save_survey_chapter(snapshot: Dictionary, persist: bool = true) -> void:
	save_chapter(snapshot, SurveyChapter.ID, persist)

func save_chapter(snapshot: Dictionary, chapter_id: String, persist: bool = true) -> void:
	var definition: GDScript = story_definition(chapter_id)
	if definition == null or (chapter_id != SurveyChapter.ID and not story_unlocked(chapter_id)): return
	var previous: Dictionary = chapter_progress.get(chapter_id, {})
	if bool(previous.get("completed", false)):
		return # Replays never replace the original exhibit or award twice.
	var valid: Dictionary = definition.clean(snapshot)
	chapter_progress[chapter_id] = valid
	if bool(valid["completed"]):
		credits += int(valid["reward"])
	if persist:
		SaveService.save_game(true, not bool(valid["completed"]))
var has_intel_bonus: bool = false
var intel_bonus_module: String = ""
var _session_hydrated: bool = false
var _hydrated_participant: String = ""
## An existing local file, or a save made after hydration, may be uploaded.
## Guest data, reset defaults, and a cloud download that only fills a missing
## file are not local progress.
var _local_upload_ready: bool = false
## "" legacy local file, "unconfirmed" after a failed read, "empty" when the
## server confirmed there is no row, "known" after a real cloud snapshot.
var _cloud_baseline: String = ""
## Answers played while the cloud snapshot was unknown. Replayed onto the
## cloud prior after a later successful read so neither history is replaced.
var _unconfirmed_bkt_log: Array[Dictionary] = []
var _bkt_step_seq: int = 0
## True when this file recorded an explicit upload decision. A downloaded
## snapshot stays false until the player changes it.
var _cloud_upload_pinned: bool = false
## Local edits that must be merged with a verified cloud read before POST.
var _pending_cloud_merge: bool = false
## Set only for the save that stores a merge or a confirmed-empty upload.
var _verified_upload: bool = false
## Wallet at the last verified cloud snapshot. Unknown for a legacy file,
## so reconciliation cannot add that balance on top of itself.
var _wallet_basis_known: bool = false
var _wallet_basis_credits: int = 0
var _wallet_basis_tokens: int = 0
## Evidence counts at the last verified cloud snapshot. Unknown for a legacy
## file, so reconciliation cannot add that history on top of itself.
var _evidence_basis_known: bool = false
var _evidence_basis_responses: int = 0
var _evidence_basis_sessions: int = 0
var _evidence_basis_topics: Dictionary = {}
## Durable evidence summary, separate from the acknowledged outbound event queue.
var learning_evidence: Dictionary = {}
const SUPPORT_GRACE_SECONDS: int = 72 * 60 * 60
const LEARNING_SESSION_IDLE_SECONDS: int = 30 * 60
const TRACE_MODULE_IDS: PackedStringArray = ["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"]
var trace_seen_by_module: Dictionary = {}
var trace_missed_by_module: Dictionary = {}
## Resume checkpoints for decision-based stages, keyed "mod_01:1".
## Only in-progress stages are stored; a cleared stage erases its entry.
var decision_stage_state: Dictionary = {}
## Lightweight, permanent story memory for reactive dialogue (see
## DecisionScenarios.condition_met / choice_memory) — a flat, free-form
## key -> scalar (bool/String/int/float) dictionary, authored explicitly per
## choice, never auto-derived from SAFE/RISKY/CRITICAL. Deliberately separate
## from mastery_matrix/decision_stage_state/cleared_stages/credits: this is
## narrative continuity only, never BKT, mastery, stage progression, the
## Case Board, or TD balance. Keys are free-form authored strings (e.g.
## "mod03_s1_bank_verification"), not scoped by code to any one module or
## stage, so a later module/stage can read an earlier one's memory with no
## special wiring — see get_story_memory_snapshot().
var story_memory: Dictionary = {}


func has_skill(skill_id: String) -> bool:
	return unlocked_skills.has(skill_id)


func unlock_skill(skill_id: String) -> void:
	if skill_id.is_empty() or unlocked_skills.has(skill_id):
		return
	unlocked_skills.append(skill_id)
	SaveService.save_game()


func unlock_tower(tower_id: String) -> void:
	if tower_id.is_empty() or unlocked_towers.has(tower_id):
		return
	unlocked_towers.append(tower_id)
	SaveService.save_game()


func is_tower_unlocked(tower_id: String) -> bool:
	if tower_id.is_empty():
		return false
	return unlocked_towers.has(tower_id)


func tech_rank(tower_id: String, track_id: String) -> int:
	if tower_id.is_empty() or track_id.is_empty():
		return 0
	if not tech_ranks.has(tower_id):
		return 0
	var stored: Variant = tech_ranks[tower_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return 0
	var tracks: Dictionary = stored as Dictionary
	return maxi(0, int(tracks.get(track_id, 0)))


func tower_capacity(tower_id: String) -> int:
	var base_cap: int = ContentDB.default_capacity(tower_id)
	var ranks: int = tech_rank(tower_id, "capacity")
	# Rank 1 is the default allotment (Basic starts at 2). Later ranks add slots.
	var extra: int = maxi(0, ranks - 1)
	return maxi(0, base_cap + extra)


func stats_bonus_for(tower_id: String) -> Dictionary:
	return ContentDB.tech_stats_bonus(tower_id, tech_rank(tower_id, "stats"))


func grant_tutorial_inspection() -> void:
	if tech_rank("base", "skill") >= 1 and has_stateful_inspection:
		return
	_set_tech_rank("base", "skill", 1)
	has_stateful_inspection = true
	SaveService.save_game()


func purchase_tech_rank(tower_id: String, track_id: String) -> bool:
	var next_rank: int = tech_rank(tower_id, track_id) + 1
	var max_rank: int = ContentDB.tech_max_rank(tower_id, track_id)
	if next_rank <= 0 or next_rank > max_rank:
		return false
	var cost: int = ContentDB.tech_rank_cost(tower_id, track_id, next_rank)
	if cost < 0:
		return false
	if not spend_credits(cost):
		return false
	_set_tech_rank(tower_id, track_id, next_rank)
	_apply_rank_effects(tower_id, track_id, next_rank)
	SaveService.save_game()
	return true


func _set_tech_rank(tower_id: String, track_id: String, rank: int) -> void:
	if tower_id.is_empty() or track_id.is_empty():
		return
	var tracks: Dictionary = {}
	if tech_ranks.has(tower_id) and typeof(tech_ranks[tower_id]) == TYPE_DICTIONARY:
		tracks = (tech_ranks[tower_id] as Dictionary).duplicate(true)
	tracks[track_id] = maxi(0, rank)
	tech_ranks[tower_id] = tracks


func _apply_rank_effects(tower_id: String, track_id: String, rank: int) -> void:
	var entry: Dictionary = ContentDB.tech_rank_entry(tower_id, track_id, rank)
	if entry.is_empty():
		return
	var flag: String = str(entry.get("flag", ""))
	if flag == "has_stateful_inspection":
		has_stateful_inspection = true
	var unlock_id: String = str(entry.get("unlock_tower", ""))
	if not unlock_id.is_empty():
		unlock_tower(unlock_id)


func _ready() -> void:
	reset_to_defaults()
	AuthService.session_changed.connect(_on_session_changed)
	if AuthService.is_signed_in():
		_hydrate_signed_in_session()


func _on_session_changed(signed_in: bool) -> void:
	if not signed_in:
		_session_hydrated = false
		_hydrated_participant = ""
		_local_upload_ready = false
		reset_to_defaults()
		return
	if _session_hydrated and _hydrated_participant == AuthService.participant_code():
		return
	await _hydrate_signed_in_session()


func _hydrate_signed_in_session() -> void:
	_session_hydrated = false
	_local_upload_ready = false
	reset_to_defaults()
	_hydrated_participant = AuthService.participant_code()
	if not SaveService.load_game():
		_cloud_baseline = "unconfirmed"
		_local_upload_ready = false
	_session_hydrated = true
	SaveService.fetch_cloud_save()


func has_hydrated_account() -> bool:
	return AuthService.is_signed_in() and _session_hydrated and _hydrated_participant == AuthService.participant_code()


func can_upload_progress() -> bool:
	return has_hydrated_account() and _local_upload_ready


func cloud_baseline() -> String:
	return _cloud_baseline


func cloud_baseline_unconfirmed() -> bool:
	return _cloud_baseline == "unconfirmed"


## Offline play that must be merged with a later cloud snapshot. A mastery
## mirror from the official BKT pull is not local progress.
func needs_cloud_reconcile() -> bool:
	return has_unconfirmed_local_writes() or _pending_cloud_merge


func has_unconfirmed_local_writes() -> bool:
	if _cloud_baseline != "unconfirmed":
		return false
	if not _unconfirmed_bkt_log.is_empty() or credits != 0 or pvp_tokens != 0:
		return true
	if not lesson_progress.is_empty() or not completed_lessons.is_empty() or not learning_events.is_empty():
		return true
	if not pretest_baselines.is_empty() or not practice_responses.is_empty() or not lesson_quiz_responses.is_empty():
		return true
	if not lesson_post_quiz_scores.is_empty() or not cleared_stages.is_empty() or not mission_progress.is_empty():
		return true
	return false


func note_cloud_fetch_failed() -> void:
	if not has_hydrated_account():
		return
	# A failed read applies to legacy files too. Keep the local snapshot,
	# but do not POST it over cloud progress this device has not seen.
	_local_upload_ready = false
	_verified_upload = false
	_cloud_baseline = "unconfirmed"
	_cloud_upload_pinned = true


func confirm_cloud_empty(upload_local: bool) -> void:
	_cloud_baseline = "empty"
	_unconfirmed_bkt_log.clear()
	_pending_cloud_merge = false
	_cloud_upload_pinned = false
	_verified_upload = false
	_local_upload_ready = upload_local and has_hydrated_account()
	_note_evidence_basis()


func note_downloaded_cloud_baseline() -> void:
	_cloud_baseline = "known"
	_unconfirmed_bkt_log.clear()
	_local_upload_ready = false
	_verified_upload = false
	_pending_cloud_merge = false
	_wallet_basis_known = true
	_wallet_basis_credits = credits
	_wallet_basis_tokens = pvp_tokens
	_note_evidence_basis()
	_cloud_upload_pinned = true


func note_existing_local_save() -> void:
	if not AuthService.is_signed_in() or _hydrated_participant != AuthService.participant_code():
		return
	# No local file is uploadable until a cloud read in this session verifies it.
	_local_upload_ready = false
	if _cloud_baseline == "":
		_cloud_baseline = "unconfirmed"


func accept_local_progress_write() -> void:
	if not _session_hydrated or _hydrated_participant != AuthService.participant_code():
		return
	if _verified_upload:
		_verified_upload = false
		_local_upload_ready = true
		_pending_cloud_merge = false
		_cloud_baseline = "known"
		_cloud_upload_pinned = false
		return
	_local_upload_ready = false
	_pending_cloud_merge = true
	_cloud_upload_pinned = true
	if _cloud_baseline == "known" or _cloud_baseline == "empty":
		_cloud_baseline = "unconfirmed"


func record_pretest_baseline(module_id: String, answers: Array) -> void:
	if Router.is_tutorial or pretest_baselines.has(module_id):
		return
	var grade: Dictionary = PretestBank.grade(module_id, answers, 0.0)
	if not bool(grade.get("ok", false)):
		return
	pretest_baselines[module_id] = {"correct": int(grade.correct_count), "total": int(grade.total)}
	_save_progress()


func pretest_baseline(module_id: String) -> Dictionary:
	return (pretest_baselines.get(module_id, {}) as Dictionary).duplicate(true)


func get_lesson_progress(module_id: String) -> int:
	if module_id.is_empty() or not lesson_progress.has(module_id):
		return 0
	return int(lesson_progress[module_id])


func has_lesson_post_quiz(module_id: String) -> bool:
	return int(lesson_post_quiz_scores.get(module_id, 0)) >= 20


func record_lesson_quiz_answer(module_id: String, lesson_index: int, question_id: String, correct: bool, params: Dictionary = {}) -> bool:
	if Router.is_tutorial or module_id not in LessonCatalog.module_ids() or question_id.is_empty():
		return false
	if lesson_index < 0 or lesson_index >= LessonCatalog.lesson_count(module_id) or lesson_index != get_lesson_progress(module_id) or not can_access_lesson_module(module_id):
		return false
	var responses: Dictionary = lesson_quiz_responses.get(module_id, {})
	if responses.has(question_id):
		return false
	responses[question_id] = correct
	lesson_quiz_responses[module_id] = responses
	var skill: String = str(LessonCatalog.module_by_id(module_id).domain)
	# Persist the first-response marker and its one local BKT update together.
	# No official-BKT submission: that would grade the same response twice.
	update_mastery(skill, correct, params, false)
	_save_progress()
	return true


func can_access_lesson_module(module_id: String) -> bool:
	var ids: Array[String] = LessonCatalog.module_ids()
	var index: int = ids.find(module_id)
	# Keep previously-started archives accessible without inventing quiz passes.
	return index >= 0 and (index == 0 or get_lesson_progress(module_id) > 0 or has_lesson_post_quiz(ids[index - 1]))

func record_practice_answer(question: Dictionary, correct: bool, selection: Dictionary) -> bool:
	var id: String = str(question.get("id", ""))
	var module_id: String = str(question.get("module_id", ""))
	if Router.is_tutorial or id.is_empty() or practice_responses.has(id) or not can_access_lesson_module(module_id): return false
	var authored: bool = false
	for item: Dictionary in ContentDB.get_module_questions(module_id):
		if str(item.get("id", "")) == id:
			question = item
			authored = true
			break
	if not authored: return false
	var skill: String = str(LessonCatalog.module_by_id(module_id).get("domain", ""))
	if skill.is_empty(): return false
	var before: float = get_mastery(skill)
	update_mastery(skill,correct,bkt_params_from(question),false)
	practice_responses[id] = {"module_id":module_id, "skill":skill, "correct":correct,
		"mastery_before":before, "mastery_after":get_mastery(skill),
		"reason":str(selection.get("reason", "")), "policy":"bkt-practice-v1",
		"eligible_mastery":(selection.get("eligible_mastery",{}) as Dictionary).duplicate(true),
		"bkt_params":bkt_params_from(question).duplicate(true), "model":"bkt-capped-drop-v1",
		"preferred_difficulty":preferred_difficulty_for_probability(before),
		"difficulty":str(question.get("difficulty", "")), "assisted":false,
		"occurred_at":int(Time.get_unix_time_from_system())}
	_save_progress()
	return true


func record_lesson_post_quiz(module_id: String, score: int, answered: int, responses: Array[Dictionary] = []) -> bool:
	if module_id not in LessonCatalog.module_ids() or answered != 25 or score < 0 or score > answered:
		return false
	if get_lesson_progress(module_id) < LessonCatalog.lesson_count(module_id):
		return false
	var evidence: Dictionary = {"attempt_id":learning_id(), "instrument":"lesson-checkpoint-v1", "correct":score, "answered":answered, "total":25}
	if not responses.is_empty():
		evidence["responses"] = responses.duplicate(true)
	record_learning_event("posttest", module_id, evidence)
	if score > int(lesson_post_quiz_scores.get(module_id, 0)):
		lesson_post_quiz_scores[module_id] = score
		_save_progress()
	return has_lesson_post_quiz(module_id)


func complete_lesson_unit(module_id: String, total: int, all_module_ids: Array[String]) -> void:
	if module_id.is_empty():
		return
	var clamped_total: int = maxi(1, total)
	var done: int = get_lesson_progress(module_id)
	if done >= clamped_total:
		return
	done += 1
	lesson_progress[module_id] = done
	grant_intel_bonus(module_id)
	if done >= clamped_total:
		complete_lesson(module_id)
		if _all_modules_complete(all_module_ids):
			complete_lesson(ALL_MODULES_LESSON)
	_save_progress()


func complete_module(module_id: String, total: int, all_module_ids: Array[String]) -> void:
	if module_id.is_empty():
		return
	var clamped_total: int = maxi(1, total)
	lesson_progress[module_id] = clamped_total
	complete_lesson(module_id)
	if _all_modules_complete(all_module_ids):
		complete_lesson(ALL_MODULES_LESSON)
	_save_progress()


func _all_modules_complete(all_module_ids: Array[String]) -> bool:
	if all_module_ids.is_empty():
		return false
	for i in all_module_ids.size():
		if not has_completed_lesson(all_module_ids[i]):
			return false
	return true


func reset_to_defaults() -> void:
	mission_progress.clear()
	pretest_baselines.clear()
	remediation_state = {"sessions": []}
	learning_events.clear()
	learning_evidence.clear()
	max_stage_cleared_by_module.clear()
	credits = 0
	pvp_tokens = 0
	selected_avatar_id = Avatars.DEFAULT_ID
	avatar_changed.emit()
	locked_stages.clear()
	cleared_stages.clear()
	completed_lessons.clear()
	lesson_progress.clear()
	lesson_post_quiz_scores.clear()
	lesson_quiz_responses.clear()
	practice_responses.clear()
	purchased_items.clear()
	unlocked_skills.clear()
	unlocked_towers = ["base"]
	tech_ranks.clear()
	_ensure_default_capacity_rank()
	_set_tech_rank("base", "skill", 1)
	has_stateful_inspection = true
	module_1_complete = false
	seen_module_intros.clear()
	tutorial_complete = false
	tutorial_skipped = false
	onboarding_state = {}
	chapter_progress = {}
	owned_perks = ["recap"]
	perk_loadout = []
	perk_attempts = []
	chapter_replay_progress = {}
	chapter_replays = {}
	has_intel_bonus = false
	intel_bonus_module = ""
	trace_seen_by_module = _empty_trace_history()
	trace_missed_by_module = _empty_trace_history()
	decision_stage_state = {}
	story_memory = {}
	mastery_matrix = {
		"phishing": DEFAULT_MASTERY,
	}
	_cloud_baseline = ""
	_unconfirmed_bkt_log.clear()
	_cloud_upload_pinned = false
	_local_upload_ready = false
	_pending_cloud_merge = false
	_verified_upload = false
	_wallet_basis_known = true
	_wallet_basis_credits = 0
	_wallet_basis_tokens = 0
	_evidence_basis_known = true
	_evidence_basis_responses = 0
	_evidence_basis_sessions = 0
	_evidence_basis_topics = {}
	progress_changed.emit()


func get_decision_stage_state(stage_key: String) -> Dictionary:
	var key: String = stage_key.strip_edges()
	if key.is_empty() or not decision_stage_state.has(key):
		return {}
	var stored: Variant = decision_stage_state[key]
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return (stored as Dictionary).duplicate(true)


func set_decision_stage_state(stage_key: String, state: Dictionary) -> void:
	var key: String = stage_key.strip_edges()
	if key.is_empty():
		return
	decision_stage_state[key] = state.duplicate(true)
	SaveService.save_game()


func clear_decision_stage_state(stage_key: String) -> void:
	var key: String = stage_key.strip_edges()
	if key.is_empty() or not decision_stage_state.has(key):
		return
	decision_stage_state.erase(key)
	SaveService.save_game()


## Read-only snapshot for reactive dialogue's condition checks (see
## DecisionScenarios.condition_met/dialogue_lines) — a duplicate, so callers
## can never mutate story memory by editing what this returns.
func get_story_memory_snapshot() -> Dictionary:
	return story_memory.duplicate(true)


func get_story_memory(key: String) -> Variant:
	return story_memory.get(key.strip_edges(), null)


## Commits one choice's whole authored "memory" block (see
## DecisionScenarios.choice_memory) in a single save, never one write per
## key — this is the one and only place story memory is ever persisted, so
## every commit path (SAFE's immediate resolution, RISKY's TD-win) reaches
## exactly this same, exactly-once write.
func set_story_memories(entries: Dictionary) -> void:
	if entries.is_empty():
		return
	for key in entries.keys():
		var trimmed: String = str(key).strip_edges()
		if trimmed.is_empty():
			continue
		story_memory[trimmed] = entries[key]
	SaveService.save_game()


func _normalize_decision_state(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var stored: Dictionary = raw as Dictionary
	for key in stored.keys():
		var entry: Variant = stored[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry as Dictionary
		var retry_cp: Dictionary = {}
		if typeof(row.get("retry_checkpoint")) == TYPE_DICTIONARY:
			retry_cp = (row["retry_checkpoint"] as Dictionary).duplicate(true)
		result[str(key)] = {
			"threat_index": int(row.get("threat_index", 0)),
			"resolved_threats": int(row.get("resolved_threats", 0)),
			"flow_state": str(row.get("flow_state", "")),
			"in_breach": bool(row.get("in_breach", false)),
			"security_state": str(row.get("security_state", "NOMINAL")),
			"safe_count": int(row.get("safe_count", 0)),
			"retry_checkpoint": retry_cp,
		}
		# Optional live Stage 1 review marker; older checkpoints remain unchanged.
		var reviewed_index := int(row.get("reviewed_breach_index", -1))
		if reviewed_index >= 0 and reviewed_index == int(row.get("threat_index", 0)):
			result[str(key)]["reviewed_breach_index"] = reviewed_index
		if row.has("story_hp"):
			result[str(key)]["story_hp"] = clampi(int(row["story_hp"]), -1, 3)
		if row.has("timer_seconds_left") and str(row.get("flow_state", "")) == "THREAT":
			var seconds: float = float(row["timer_seconds_left"])
			if is_finite(seconds):
				result[str(key)]["timer_seconds_left"] = maxf(0.0, seconds)
	return result


## Older saves have no "story_memory" key at all; they simply start with no
## memory, exactly the same as a fresh account. Only scalar values
## (bool/String/int/float) are trusted from a save file — anything else
## (an array, a nested dictionary) is dropped rather than risking a
## condition_met() comparison against an unexpected type.
func _normalize_story_memory(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var stored: Dictionary = raw as Dictionary
	for key in stored.keys():
		var trimmed: String = str(key).strip_edges()
		if trimmed.is_empty():
			continue
		var value: Variant = stored[key]
		var value_type: int = typeof(value)
		if value_type == TYPE_BOOL or value_type == TYPE_STRING or value_type == TYPE_STRING_NAME or value_type == TYPE_INT or value_type == TYPE_FLOAT:
			result[trimmed] = value
	return result


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	SaveService.save_game()


func grant_intel_bonus(module_id: String) -> void:
	if module_id.is_empty():
		return
	has_intel_bonus = true
	intel_bonus_module = module_id
	SaveService.save_game()


func consume_intel_bonus_gold(base_gold: int, module_id: String) -> int:
	var gold: int = maxi(0, base_gold)
	if not has_intel_bonus:
		return gold
	if not intel_bonus_module.is_empty() and intel_bonus_module != module_id:
		return gold
	has_intel_bonus = false
	intel_bonus_module = ""
	SaveService.save_game()
	var boosted: int = int(ceil(float(gold) * 1.15))
	print("[Intel] Threat Intel Bonus +15%% gold. %d -> %d" % [gold, boosted])
	return boosted


func intel_module_for_stage(stage_id: int) -> String:
	var active: String = str(Router.active_module_id).strip_edges()
	if not active.is_empty():
		return active
	if stage_id >= 1 and stage_id <= 10:
		return "mod_01"
	return ""


func spend_credits(amount: int) -> bool:
	if amount <= 0 or credits < amount:
		return false
	credits -= amount
	SaveService.save_game()
	return true


func _save_progress() -> void:
	SaveService.save_game()
	progress_changed.emit()


## Canonical identity for stage-progression state (cleared/locked/ceiling).
## Use this everywhere instead of rebuilding the string manually, and never
## represent a stage's completion/lock state by raw stage number alone —
## mod_01:1 and mod_02:1 must never collide.
static func stage_progress_key(module_id: String, stage_id: int) -> String:
	return "%s:%d" % [module_id.strip_edges(), stage_id]


## Highest stage cleared within module_id, independent of every other
## module. Defaults to 1 (no clears yet) — the same baseline every module
## has always started from, now scoped per module instead of shared.
func max_stage_cleared(module_id: String) -> int:
	var mid: String = module_id.strip_edges()
	if mid.is_empty() or not max_stage_cleared_by_module.has(mid):
		return 1
	return int(max_stage_cleared_by_module[mid])


func lock_stage(module_id: String, stage_id: int) -> void:
	if stage_id <= 0 or module_id.strip_edges().is_empty():
		return
	locked_stages[stage_progress_key(module_id, stage_id)] = true
	SaveService.save_game()


func unlock_stage(module_id: String, stage_id: int) -> void:
	locked_stages.erase(stage_progress_key(module_id, stage_id))
	SaveService.save_game()


func is_stage_locked(module_id: String, stage_id: int) -> bool:
	return locked_stages.has(stage_progress_key(module_id, stage_id))


func owns_store_item(item_id: String) -> bool:
	return not item_id.is_empty() and purchased_items.has(item_id)


func store_item(item_id: String) -> Dictionary:
	for item: Dictionary in store_items():
		if str(item.id) == item_id:
			return item.duplicate(true)
	return {}


func store_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = STORE_ITEMS.duplicate(true)
	for avatar: Dictionary in Avatars.ENTRIES:
		if int(avatar.price) == 0:
			continue
		items.append({"id": avatar.id, "name": avatar.name, "price": avatar.price,
			"category": "PROFILES", "art": "avatar", "color": "4FE0D4",
			"description": "Unlock this profile picture. Choose it from your profile after purchase."})
	return items


func can_use_avatar(id: String) -> bool:
	var avatar: Dictionary = Avatars.entry(id)
	return not avatar.is_empty() and (int(avatar.price) == 0 or owns_store_item(id))


func current_avatar_id() -> String:
	return selected_avatar_id if can_use_avatar(selected_avatar_id) else Avatars.DEFAULT_ID


func select_avatar(id: String) -> bool:
	if not can_use_avatar(id):
		return false
	if selected_avatar_id == id:
		return true
	selected_avatar_id = id
	_save_progress()
	avatar_changed.emit()
	return true


func purchase_store_item(item_id: String, price: int = -1) -> bool:
	if item_id.is_empty() or owns_store_item(item_id):
		return false
	var item: Dictionary = store_item(item_id)
	if item.is_empty():
		return false
	var cost: int = int(item.price)
	# Never trust a price supplied by a UI caller; retain the optional argument
	# for compatibility and reject stale or forged quotes.
	if (price != -1 and price != cost) or cost <= 0 or pvp_tokens < cost:
		return false
	pvp_tokens -= cost
	purchased_items.append(item_id)
	# Ownership and wallet are persisted together, not in two separate writes.
	_save_progress()
	return true


func complete_lesson(lesson_id: String) -> void:
	if lesson_id.is_empty() or completed_lessons.has(lesson_id):
		return
	completed_lessons.append(lesson_id)
	if lesson_id != ALL_MODULES_LESSON:
		_try_grant_module_unlock()
	SaveService.save_game()


func _try_grant_module_unlock() -> void:
	for i in ContentDB.CORE_LESSON_IDS.size():
		var core_id: String = String(ContentDB.CORE_LESSON_IDS[i])
		if not has_completed_lesson(core_id):
			return
	if has_completed_lesson(ALL_MODULES_LESSON):
		return
	completed_lessons.append(ALL_MODULES_LESSON)


func has_completed_lesson(lesson_id: String) -> bool:
	return completed_lessons.has(lesson_id)


func is_module_deploy_unlocked(module_id: String) -> bool:
	return deployment_lesson_count(module_id) >= 1


func deployment_lesson_count(module_id: String) -> int:
	if module_id not in LessonCatalog.module_ids():
		return 0
	var total: int = LessonCatalog.lesson_count(module_id)
	# Older complete-module saves may have no per-lesson counter.
	if has_completed_lesson(module_id):
		return total
	return clampi(get_lesson_progress(module_id), 0, total)


func has_seen_module_intro(module_id: String) -> bool:
	return not module_id.is_empty() and seen_module_intros.has(module_id)


func mark_module_intro_seen(module_id: String) -> void:
	if module_id.is_empty() or seen_module_intros.has(module_id):
		return
	seen_module_intros.append(module_id)
	SaveService.save_game()


func needs_tutorial() -> bool:
	return not tutorial_complete and not tutorial_skipped


func needs_opening() -> bool:
	# Existing accounts retain their onboarding choice; no forced migration.
	return needs_tutorial() and str(onboarding_state.get("tutorial_status", "")) not in ["completed", "skipped"]


func save_onboarding(state: Dictionary, outcome: String = "") -> void:
	onboarding_state = state.duplicate(true)
	if outcome == "completed":
		tutorial_complete = true
		tutorial_skipped = false
	elif outcome == "skipped":
		tutorial_skipped = true
	# Same local-first snapshot/retry mechanism as existing presentation progress.
	_save_progress()


func skip_tutorial() -> void:
	if tutorial_complete or tutorial_skipped:
		return
	tutorial_skipped = true
	_save_progress()


func mark_tutorial_complete() -> void:
	if tutorial_complete:
		return
	tutorial_complete = true
	tutorial_skipped = false
	_save_progress()


func mark_stage_cleared(module_id: String, stage_id: int) -> void:
	var mid: String = module_id.strip_edges()
	if stage_id <= 0 or mid.is_empty():
		return
	max_stage_cleared_by_module[mid] = maxi(max_stage_cleared(mid), stage_id)
	cleared_stages[stage_progress_key(mid, stage_id)] = true
	SaveService.save_game()
	progress_changed.emit()


func has_cleared_stage(module_id: String, stage_id: int) -> bool:
	if stage_id <= 0:
		return false
	return cleared_stages.has(stage_progress_key(module_id, stage_id))


func get_weakest_skill() -> String:
	if mastery_matrix.is_empty():
		return "phishing"
	var weakest_skill: String = ""
	var lowest_score: float = 1.0
	var skill_ids: Array = mastery_matrix.keys()
	for i in skill_ids.size():
		var skill_id: String = str(skill_ids[i])
		var stored: Variant = mastery_matrix[skill_id]
		var score: float = float(stored)
		if score < lowest_score:
			lowest_score = score
			weakest_skill = skill_id
	if weakest_skill.is_empty():
		return "phishing"
	return weakest_skill


func get_mastery(skill_id: String = "phishing") -> float:
	var key: String = skill_id if not skill_id.is_empty() else "phishing"
	return clampf(_mastery_of(key), 0.0, 1.0)


func preferred_difficulty(skill_id: String = "phishing") -> String:
	return preferred_difficulty_for_probability(get_mastery(skill_id))

func preferred_difficulty_for_probability(p_learned: float) -> String:
	if p_learned < AT_RISK_MASTERY:
		return "easy"
	if p_learned < PROFICIENT_MASTERY:
		return "medium"
	return "hard"


func get_trace_seen(module_id: String) -> Array[String]:
	return _trace_id_list(trace_seen_by_module, module_id)


func get_trace_missed(module_id: String) -> Array[String]:
	return _trace_id_list(trace_missed_by_module, module_id)


func record_trace_result(module_id: String, question_id: String, is_correct: bool) -> void:
	var mid: String = module_id.strip_edges()
	var qid: String = question_id.strip_edges()
	if mid.is_empty() or qid.is_empty():
		return
	_ensure_trace_history()
	var seen: Array[String] = get_trace_seen(mid)
	if not seen.has(qid):
		seen.append(qid)
	trace_seen_by_module[mid] = seen
	var missed: Array[String] = get_trace_missed(mid)
	if is_correct:
		var missed_index: int = missed.find(qid)
		if missed_index >= 0:
			missed.remove_at(missed_index)
	elif not missed.has(qid):
		missed.append(qid)
	trace_missed_by_module[mid] = missed
	SaveService.save_game()


func _empty_trace_history() -> Dictionary:
	var history: Dictionary = {}
	for i in TRACE_MODULE_IDS.size():
		history[str(TRACE_MODULE_IDS[i])] = []
	return history


func _ensure_trace_history() -> void:
	if trace_seen_by_module.is_empty():
		trace_seen_by_module = _empty_trace_history()
	if trace_missed_by_module.is_empty():
		trace_missed_by_module = _empty_trace_history()
	for i in TRACE_MODULE_IDS.size():
		var module_id: String = str(TRACE_MODULE_IDS[i])
		if not trace_seen_by_module.has(module_id) or typeof(trace_seen_by_module[module_id]) != TYPE_ARRAY:
			trace_seen_by_module[module_id] = []
		if not trace_missed_by_module.has(module_id) or typeof(trace_missed_by_module[module_id]) != TYPE_ARRAY:
			trace_missed_by_module[module_id] = []


func _trace_id_list(store: Dictionary, module_id: String) -> Array[String]:
	_ensure_trace_history()
	var result: Array[String] = []
	var mid: String = module_id.strip_edges()
	if mid.is_empty() or not store.has(mid):
		return result
	var stored: Variant = store[mid]
	if typeof(stored) != TYPE_ARRAY:
		return result
	var rows: Array = stored as Array
	for i in rows.size():
		var qid: String = str(rows[i]).strip_edges()
		if qid.is_empty() or result.has(qid):
			continue
		result.append(qid)
	return result


func _normalize_trace_history(raw: Variant) -> Dictionary:
	var history: Dictionary = _empty_trace_history()
	if typeof(raw) != TYPE_DICTIONARY:
		return history
	var saved: Dictionary = raw as Dictionary
	for i in TRACE_MODULE_IDS.size():
		var module_id: String = str(TRACE_MODULE_IDS[i])
		if not saved.has(module_id) or typeof(saved[module_id]) != TYPE_ARRAY:
			continue
		var ids: Array[String] = []
		var rows: Array = saved[module_id] as Array
		for j in rows.size():
			var qid: String = str(rows[j]).strip_edges()
			if qid.is_empty() or ids.has(qid):
				continue
			ids.append(qid)
		history[module_id] = ids
	return history


func quiz_gold_reward(is_correct: bool, skill_id: String = "phishing") -> int:
	var base_gold: int = 5 if is_correct else 2
	var p_learned: float = get_mastery(skill_id)
	var mult: float = 1.0
	if p_learned >= PROFICIENT_MASTERY:
		mult = 1.5
	elif p_learned >= AT_RISK_MASTERY:
		mult = 1.25
	return maxi(1, int(ceil(float(base_gold) * mult)))


func bkt_params_from(question: Dictionary) -> Dictionary:
	var stored: Variant = question.get("bkt", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored as Dictionary


func _apply_mastery_step(skill_id: String, is_correct: bool, p_guess: float, p_slip: float, p_transit: float) -> float:
	var p_learned: float = _mastery_of(skill_id)
	var p_post: float = _posterior(p_learned, is_correct, p_guess, p_slip)
	var new_mastery: float = clampf(p_post + ((1.0 - p_post) * p_transit), MIN_MASTERY, MAX_MASTERY)
	if not is_correct:
		new_mastery = clampf(maxf(new_mastery, p_learned - MAX_WRONG_DROP), MIN_MASTERY, MAX_MASTERY)
	mastery_matrix[skill_id] = new_mastery
	return p_learned


func update_mastery(skill_id: String, is_correct: bool, params: Dictionary = {}, persist: bool = true) -> void:
	# Practice in the onboarding sandbox is never a graded learning response.
	if Router.is_tutorial:
		return
	var key: String = skill_id if not skill_id.is_empty() else "phishing"
	var p_guess: float = _bkt_param(params, ["p_g", "p_guess"], P_GUESS)
	var p_slip: float = _bkt_param(params, ["p_s", "p_slip"], P_SLIP)
	var p_transit: float = _bkt_param(params, ["p_t", "p_transit"], P_TRANSIT)
	var p_learned: float = _apply_mastery_step(key, is_correct, p_guess, p_slip, p_transit)
	# A verified upload already contains its replay. Every other answer must be
	# logged: the baseline is still "known" until the save marks it pending,
	# and without the log reconciliation keeps the older cloud mastery.
	if not _verified_upload:
		_unconfirmed_bkt_log.append({
			"op": "update",
			"id": _next_bkt_step_id(key),
			"skill": key,
			"correct": is_correct,
			"p_g": p_guess,
			"p_s": p_slip,
			"p_t": p_transit,
			"prior": p_learned,
			"posterior": float(mastery_matrix[key]),
		})
	var new_mastery: float = float(mastery_matrix[key])
	_record_graded_response(key, int(Time.get_unix_time_from_system()))
	record_learning_event("mastery", str(LEARNING_MODULES.get(key, "")), {"mastery":new_mastery}, false)
	print(
		"[BKT] local %s %s  P(L) %.3f -> %.3f  (G=%.2f S=%.2f T=%.2f)"
		% [key, "hit" if is_correct else "miss", p_learned, new_mastery, p_guess, p_slip, p_transit]
	)
	# Exactly one BKT calculation path: this local update, persisted here and
	# uploaded as-is by the existing cloud progress sync. Never also submit
	# this same answer to AuthService's official-BKT queue/endpoint — that
	# would be a second, server-side BKT calculation for one gameplay event.
	if persist:
		SaveService.save_game()


func save_remediation(state: Dictionary) -> void:
	remediation_state = Remediation.restore(state)
	# Save evidence and its mastery update together, never re-submit to official BKT.
	_save_progress()


## True only when this account has local changes SaveService hasn't
## confirmed as synced yet (StudentDatabase.needs_cloud_sync — the same
## signal SaveService.fetch_cloud_save() already checks before it will
## overwrite anything). While true, local mastery_matrix is authoritative:
## no cached or remote BKT value may replace it, network-unavailable or not.
func _has_pending_local_sync() -> bool:
	return AuthService.is_signed_in() and StudentDatabase.has_pending_sync(AuthService.participant_code())


func apply_official_mastery(skill_id: String, probability_known: float) -> void:
	var key: String = skill_id if not skill_id.is_empty() else "phishing"
	mastery_matrix[key] = clampf(probability_known, MIN_MASTERY, MAX_MASTERY)


## Seeds mastery_matrix from AuthService's cached/official values. Callable
## even while a local sync is pending — an intentional local seed (e.g. a
## just-computed pretest diagnostic handed to AuthService, then read back
## here) is not "stale cached data clobbering newer gameplay"; only
## pull_official_bkt()'s unsolicited remote/cached refresh needs to defer to
## pending local state (see its own guard).
func seed_from_official_mastery(only_skill: String = "", record_unconfirmed: bool = false) -> void:
	var official: Dictionary = AuthService.mastery()
	var changed := false
	for i in _OFFICIAL_SKILLS.size():
		var skill_id: String = _OFFICIAL_SKILLS[i]
		if not only_skill.is_empty() and skill_id != only_skill:
			continue
		var titled: String = skill_id.capitalize()
		var value: float = float(official.get(titled, official.get(skill_id, 0.0)))
		if value <= 0.0:
			continue
		apply_official_mastery(skill_id, value)
		if record_unconfirmed and _cloud_baseline == "unconfirmed":
			var seeded: float = float(mastery_matrix[skill_id])
			_unconfirmed_bkt_log.append({
				"op": "seed",
				"id": _next_bkt_step_id(skill_id),
				"skill": skill_id,
				"value": seeded,
				"posterior": seeded,
			})
		changed = true
		print("[BKT] seeded %s from official P(L)=%.3f" % [skill_id, value])
	if changed:
		SaveService.save_game()


func pull_official_bkt() -> void:
	if _has_pending_local_sync():
		print("[BKT] pending local sync — keeping local mastery_matrix, skipping official BKT pull")
		return
	if not AuthService.is_signed_in():
		seed_from_official_mastery()
		return
	var request_owner: String = AuthService.participant_code()
	var before_fetch: Dictionary = mastery_matrix.duplicate(true)
	var gameplay: Dictionary = await AuthService.fetch_bkt_state()
	if not AuthService.is_signed_in() or request_owner != AuthService.participant_code() or _has_pending_local_sync() or mastery_matrix != before_fetch:
		return
	if gameplay.is_empty():
		seed_from_official_mastery()
		return
	var keys: Array = gameplay.keys()
	for i in keys.size():
		var skill_id: String = str(keys[i]).strip_edges().to_lower()
		if skill_id.is_empty():
			continue
		apply_official_mastery(skill_id, float(gameplay[keys[i]]))
	print("[BKT] pulled official gameplay matrix ", gameplay)
	SaveService.save_game()


func _mastery_of(skill_id: String) -> float:
	if not mastery_matrix.has(skill_id):
		return DEFAULT_MASTERY
	return float(mastery_matrix[skill_id])


func _bkt_param(params: Dictionary, keys: Array, fallback: float) -> float:
	for i in keys.size():
		var key: String = str(keys[i])
		if not params.has(key):
			continue
		var stored: Variant = params[key]
		if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
			return clampf(float(stored), 0.01, 0.5)
	return fallback


func _posterior(p_learned: float, is_correct: bool, p_guess: float = P_GUESS, p_slip: float = P_SLIP) -> float:
	if is_correct:
		var numer: float = p_learned * (1.0 - p_slip)
		var denom: float = numer + ((1.0 - p_learned) * p_guess)
		if denom <= 0.0:
			return p_learned
		return numer / denom
	var numer_wrong: float = p_learned * p_slip
	var denom_wrong: float = numer_wrong + ((1.0 - p_learned) * (1.0 - p_guess))
	if denom_wrong <= 0.0:
		return p_learned
	return numer_wrong / denom_wrong


func get_save_data() -> Dictionary:
	return {
		"mission_progress": mission_progress.duplicate(true),
		"pretest_baselines": pretest_baselines.duplicate(true),
		"learning_evidence": learning_evidence.duplicate(true),
		"learning_events": learning_events.duplicate(true),
		"max_stage_cleared_by_module": max_stage_cleared_by_module.duplicate(true),
		# Legacy field kept for older clients/detection only (see
		# SaveService._looks_like_save()); it mirrors Module 1's own ceiling,
		# since Module 1 was the sole module with real stage content when
		# this field was the single source of truth.
		"mock_max_stage_cleared": max_stage_cleared("mod_01"),
		"mastery_matrix": _export_mastery_matrix(),
		"locked_stages": locked_stages.duplicate(true),
		"cleared_stages": cleared_stages.keys(),
		"completed_lessons": completed_lessons.duplicate(),
		"credits": credits,
		"pvp_tokens": pvp_tokens,
		"selected_avatar_id": current_avatar_id(),
		"unlocked_towers": unlocked_towers.duplicate(),
		"unlocked_skills": unlocked_skills.duplicate(),
		"tech_ranks": tech_ranks.duplicate(true),
		"has_stateful_inspection": has_stateful_inspection,
		"lesson_progress": lesson_progress.duplicate(true),
		"lesson_post_quiz_scores": lesson_post_quiz_scores.duplicate(true),
		"lesson_quiz_responses": lesson_quiz_responses.duplicate(true),
		"practice_responses": practice_responses.duplicate(true),
		"purchased_items": purchased_items.duplicate(),
		"module_1_complete": module_1_complete,
		"seen_module_intros": seen_module_intros.duplicate(),
		"tutorial_complete": tutorial_complete,
		"tutorial_skipped": tutorial_skipped,
		"onboarding_state": onboarding_state.duplicate(true),
		"chapter_progress": chapter_progress.duplicate(true),
		"owned_perks": owned_perks.duplicate(),
		"perk_loadout": perk_loadout.duplicate(),
		"perk_attempts": perk_attempts.duplicate(true),
		"chapter_replay_progress": chapter_replay_progress.duplicate(true),
		"chapter_replays": chapter_replays.duplicate(true),
		"has_intel_bonus": has_intel_bonus,
		"intel_bonus_module": intel_bonus_module,
		"cloud_baseline": _cloud_baseline,
		"cloud_upload_ready": _pending_cloud_merge or _local_upload_ready,
		"wallet_basis_known": _wallet_basis_known,
		"wallet_basis_credits": _wallet_basis_credits,
		"wallet_basis_tokens": _wallet_basis_tokens,
		"evidence_basis_known": _evidence_basis_known,
		"evidence_basis_responses": _evidence_basis_responses,
		"evidence_basis_sessions": _evidence_basis_sessions,
		"evidence_basis_topics": _evidence_basis_topics.duplicate(true),
		"unconfirmed_bkt_log": _copy_bkt_log(),
		"trace_seen_by_module": trace_seen_by_module.duplicate(true),
		"trace_missed_by_module": trace_missed_by_module.duplicate(true),
		"decision_stage_state": decision_stage_state.duplicate(true),
		"story_memory": story_memory.duplicate(true),
		"remediation_state": remediation_state.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	# A snapshot replaces account state; absent legacy keys must not retain it.
	reset_to_defaults()
	var saved_missions: Variant = data.get("mission_progress", {})
	if saved_missions is Dictionary:
		mission_progress = saved_missions.duplicate(true)
	var baselines: Variant = data.get("pretest_baselines", {})
	if baselines is Dictionary:
		for module_id: String in LessonCatalog.module_ids():
			var baseline: Variant = baselines.get(module_id, {})
			if not baseline is Dictionary:
				continue
			var correct: Variant = baseline.get("correct")
			var total: Variant = baseline.get("total")
			if (correct is int or correct is float) and (total is int or total is float):
				if is_finite(float(correct)) and is_finite(float(total)) and float(total) > 0 and float(total) <= 100 and float(correct) >= 0 and float(correct) <= float(total) and float(correct) == floorf(float(correct)) and float(total) == floorf(float(total)):
					pretest_baselines[module_id] = {"correct": int(correct), "total": int(total)}
	_restore_learning_evidence(data.get("learning_evidence", {}))
	var practice: Variant = data.get("practice_responses", {})
	if practice is Dictionary:
		for module_id: String in LessonCatalog.module_ids():
			for question: Dictionary in ContentDB.get_module_questions(module_id):
				var id: String = str(question.get("id", ""))
				var record: Variant = practice.get(id)
				if record is Dictionary and record.get("module_id", "") == module_id and record.get("correct") is bool:
					practice_responses[id] = record.duplicate(true)
	remediation_state = Remediation.restore(data.get("remediation_state", {}))
	learning_events.clear()
	var events: Variant = data.get("learning_events", [])
	if events is Array:
		for event: Variant in events:
			if event is Dictionary:
				learning_events.append(event.duplicate(true))
	# Missing/malformed legacy wallet always means zero, never Solo conversion.
	pvp_tokens = 0
	var tokens_raw: Variant = data.get("pvp_tokens", 0)
	if typeof(tokens_raw) == TYPE_INT or typeof(tokens_raw) == TYPE_FLOAT:
		var tokens_number: float = float(tokens_raw)
		if is_finite(tokens_number) and tokens_number >= 0.0:
			pvp_tokens = int(minf(tokens_number, 2147483647.0))
	lesson_post_quiz_scores.clear()
	var checkpoints: Variant = data.get("lesson_post_quiz_scores", {})
	if checkpoints is Dictionary:
		for module_id: String in LessonCatalog.module_ids():
			var score: Variant = checkpoints.get(module_id, 0)
			if score is int or score is float:
				lesson_post_quiz_scores[module_id] = clampi(int(score), 0, 25)
	var mini_responses: Variant = data.get("lesson_quiz_responses", {})
	if mini_responses is Dictionary:
		for module_id: String in LessonCatalog.module_ids():
			var responses: Variant = mini_responses.get(module_id, {})
			if responses is Dictionary:
				var valid: Dictionary = {}
				for question_id: Variant in responses:
					if question_id is String and not question_id.is_empty() and responses[question_id] is bool:
						valid[question_id] = responses[question_id]
				if not valid.is_empty():
					lesson_quiz_responses[module_id] = valid
	max_stage_cleared_by_module.clear()
	if data.has("max_stage_cleared_by_module") and typeof(data["max_stage_cleared_by_module"]) == TYPE_DICTIONARY:
		var saved_ceilings: Dictionary = data["max_stage_cleared_by_module"] as Dictionary
		var ceiling_keys: Array = saved_ceilings.keys()
		for i in ceiling_keys.size():
			var mid: String = str(ceiling_keys[i]).strip_edges()
			if not mid.is_empty():
				max_stage_cleared_by_module[mid] = maxi(1, int(saved_ceilings[ceiling_keys[i]]))
	elif data.has("mock_max_stage_cleared"):
		# Legacy global counter only ever tracked Module 1 — the sole module
		# with real stage content before Module 2 existed — so it migrates
		# there rather than being guessed at for any other module.
		max_stage_cleared_by_module["mod_01"] = maxi(1, int(data["mock_max_stage_cleared"]))

	if data.has("mastery_matrix") and typeof(data["mastery_matrix"]) == TYPE_DICTIONARY:
		var saved_matrix: Dictionary = data["mastery_matrix"] as Dictionary
		var matrix_keys: Array = saved_matrix.keys()
		for i in matrix_keys.size():
			var skill_id: String = str(matrix_keys[i])
			if skill_id.is_empty():
				continue
			mastery_matrix[skill_id] = float(saved_matrix[matrix_keys[i]])

	locked_stages.clear()
	if data.has("locked_stages"):
		_ingest_stage_progress_set(data["locked_stages"], locked_stages)

	cleared_stages.clear()
	if data.has("cleared_stages"):
		_ingest_stage_progress_set(data["cleared_stages"], cleared_stages)
	elif max_stage_cleared("mod_01") > 1:
		for stage_n in range(1, max_stage_cleared("mod_01") + 1):
			cleared_stages[stage_progress_key("mod_01", stage_n)] = true

	if data.has("completed_lessons") and typeof(data["completed_lessons"]) == TYPE_ARRAY:
		var saved_lessons: Array = data["completed_lessons"] as Array
		completed_lessons.clear()
		for i in saved_lessons.size():
			var lesson_id: String = str(saved_lessons[i])
			if not lesson_id.is_empty() and not completed_lessons.has(lesson_id):
				completed_lessons.append(lesson_id)

	if data.has("lesson_progress") and typeof(data["lesson_progress"]) == TYPE_DICTIONARY:
		var saved_progress: Dictionary = data["lesson_progress"] as Dictionary
		lesson_progress.clear()
		var progress_keys: Array = saved_progress.keys()
		for i in progress_keys.size():
			var module_id: String = str(progress_keys[i])
			if module_id.is_empty():
				continue
			lesson_progress[module_id] = int(saved_progress[progress_keys[i]])

	if data.has("credits"):
		var credits_raw: Variant = data["credits"]
		var credits_type: int = typeof(credits_raw)
		if credits_type == TYPE_INT or credits_type == TYPE_FLOAT:
			credits = maxi(0, int(credits_raw))

	purchased_items.clear()
	if data.has("purchased_items") and typeof(data["purchased_items"]) == TYPE_ARRAY:
		var saved_items: Array = data["purchased_items"] as Array
		for i in saved_items.size():
			var item_id: String = str(saved_items[i])
			if not item_id.is_empty() and not purchased_items.has(item_id):
				purchased_items.append(item_id)

	var avatar_raw: Variant = data.get("selected_avatar_id", Avatars.DEFAULT_ID)
	selected_avatar_id = str(avatar_raw) if typeof(avatar_raw) == TYPE_STRING else Avatars.DEFAULT_ID
	selected_avatar_id = current_avatar_id()
	avatar_changed.emit()

	if data.has("unlocked_towers") and typeof(data["unlocked_towers"]) == TYPE_ARRAY:
		var saved_towers: Array = data["unlocked_towers"] as Array
		unlocked_towers.clear()
		unlocked_towers.append("base")
		for i in saved_towers.size():
			var tower_id: String = str(saved_towers[i])
			if tower_id.is_empty() or tower_id == "network" or tower_id == "crypto":
				continue
			if not unlocked_towers.has(tower_id):
				unlocked_towers.append(tower_id)

	if data.has("tech_ranks") and typeof(data["tech_ranks"]) == TYPE_DICTIONARY:
		tech_ranks = (data["tech_ranks"] as Dictionary).duplicate(true)
	else:
		tech_ranks.clear()
	_sanitize_tech_ranks()
	_ensure_default_capacity_rank()

	# Inspection is now standard starter equipment, including for legacy saves.
	_set_tech_rank("base", "skill", 1)
	has_stateful_inspection = true
	_sync_evolution_unlocks()

	if data.has("unlocked_skills") and typeof(data["unlocked_skills"]) == TYPE_ARRAY:
		var saved_skills: Array = data["unlocked_skills"] as Array
		unlocked_skills.clear()
		for i in saved_skills.size():
			var skill_id: String = str(saved_skills[i])
			if not skill_id.is_empty() and not unlocked_skills.has(skill_id):
				unlocked_skills.append(skill_id)

	if data.has("module_1_complete"):
		var complete_raw: Variant = data["module_1_complete"]
		var complete_type: int = typeof(complete_raw)
		if complete_type == TYPE_BOOL:
			module_1_complete = complete_raw
		elif complete_type == TYPE_INT or complete_type == TYPE_FLOAT:
			module_1_complete = int(complete_raw) != 0

	if data.has("seen_module_intros") and typeof(data["seen_module_intros"]) == TYPE_ARRAY:
		var saved_intros: Array = data["seen_module_intros"] as Array
		seen_module_intros.clear()
		for i in saved_intros.size():
			var intro_id: String = str(saved_intros[i])
			if not intro_id.is_empty() and not seen_module_intros.has(intro_id):
				seen_module_intros.append(intro_id)

	tutorial_skipped = data.get("tutorial_skipped", false) == true
	var saved_onboarding: Variant = data.get("onboarding_state", {})
	onboarding_state = (saved_onboarding as Dictionary).duplicate(true) if saved_onboarding is Dictionary else {}
	var saved_chapters: Variant = data.get("chapter_progress", {})
	owned_perks = StoryPerks.ids(data.get("owned_perks", []))
	if "recap" not in owned_perks: owned_perks.append("recap")
	for id: String in StoryPerks.ids(data.get("perk_loadout", []), 2):
		if id in owned_perks: perk_loadout.append(id)
	var attempts: Variant = data.get("perk_attempts", [])
	if attempts is Array:
		var seen_attempts: Array[String] = []
		for raw: Variant in attempts:
			var run: Dictionary = StoryPerks.clean_run(raw)
			if run.is_empty() or run.id in seen_attempts: continue
			seen_attempts.append(run.id)
			run["assist_status"] = StoryPerks.status(run)
			for field: String in ["mistakes", "coins_awarded"]:
				var value: Variant = raw.get(field, 0)
				if (value is int or value is float) and is_finite(float(value)): run[field] = maxi(0, int(value))
			perk_attempts.append(run)
	var replay_data: Variant = data.get("chapter_replay_progress", {})
	if replay_data is Dictionary and not replay_data.is_empty(): chapter_replay_progress = SurveyChapter.clean(replay_data)
	if saved_chapters is Dictionary and saved_chapters.get(SurveyChapter.ID) is Dictionary:
		chapter_progress[SurveyChapter.ID] = SurveyChapter.clean(saved_chapters[SurveyChapter.ID])
	if saved_chapters is Dictionary and saved_chapters.get(AdvisorChapter.ID) is Dictionary:
		chapter_progress[AdvisorChapter.ID] = AdvisorChapter.clean(saved_chapters[AdvisorChapter.ID])
	var replays: Variant = data.get("chapter_replays", {})
	if replays is Dictionary and replays.get(AdvisorChapter.ID) is Dictionary:
		chapter_replays[AdvisorChapter.ID] = AdvisorChapter.clean(replays[AdvisorChapter.ID])
	if saved_chapters is Dictionary and saved_chapters.get(PayoutChapter.ID) is Dictionary:
		chapter_progress[PayoutChapter.ID] = PayoutChapter.clean(saved_chapters[PayoutChapter.ID])
	if replays is Dictionary and replays.get(PayoutChapter.ID) is Dictionary:
		chapter_replays[PayoutChapter.ID] = PayoutChapter.clean(replays[PayoutChapter.ID])
	if saved_chapters is Dictionary and saved_chapters.get(PrizeChapter.ID) is Dictionary:
		chapter_progress[PrizeChapter.ID] = PrizeChapter.clean(saved_chapters[PrizeChapter.ID])
	if replays is Dictionary and replays.get(PrizeChapter.ID) is Dictionary:
		chapter_replays[PrizeChapter.ID] = PrizeChapter.clean(replays[PrizeChapter.ID])
	if saved_chapters is Dictionary and saved_chapters.get(ConfrontationChapter.ID) is Dictionary:
		chapter_progress[ConfrontationChapter.ID] = ConfrontationChapter.clean(saved_chapters[ConfrontationChapter.ID])
	if replays is Dictionary and replays.get(ConfrontationChapter.ID) is Dictionary:
		chapter_replays[ConfrontationChapter.ID] = ConfrontationChapter.clean(replays[ConfrontationChapter.ID])
	if saved_chapters is Dictionary and saved_chapters.get(DeliveryChapter.ID) is Dictionary:
		chapter_progress[DeliveryChapter.ID] = DeliveryChapter.clean(saved_chapters[DeliveryChapter.ID])
	if replays is Dictionary and replays.get(DeliveryChapter.ID) is Dictionary:
		chapter_replays[DeliveryChapter.ID] = DeliveryChapter.clean(replays[DeliveryChapter.ID])
	if data.has("tutorial_complete"):
		var tutorial_raw: Variant = data["tutorial_complete"]
		var tutorial_type: int = typeof(tutorial_raw)
		if tutorial_type == TYPE_BOOL:
			tutorial_complete = tutorial_raw
		elif tutorial_type == TYPE_INT or tutorial_type == TYPE_FLOAT:
			tutorial_complete = int(tutorial_raw) != 0

	if data.has("has_intel_bonus"):
		var bonus_raw: Variant = data["has_intel_bonus"]
		var bonus_type: int = typeof(bonus_raw)
		if bonus_type == TYPE_BOOL:
			has_intel_bonus = bonus_raw
		elif bonus_type == TYPE_INT or bonus_type == TYPE_FLOAT:
			has_intel_bonus = int(bonus_raw) != 0
	if data.has("intel_bonus_module"):
		intel_bonus_module = str(data["intel_bonus_module"])

	if data.has("trace_seen_by_module"):
		trace_seen_by_module = _normalize_trace_history(data["trace_seen_by_module"])
	else:
		trace_seen_by_module = _empty_trace_history()
	if data.has("trace_missed_by_module"):
		trace_missed_by_module = _normalize_trace_history(data["trace_missed_by_module"])
	else:
		trace_missed_by_module = _empty_trace_history()
	# Older saves have no decision checkpoints; they simply start Stage 1 fresh.
	decision_stage_state = _normalize_decision_state(data.get("decision_stage_state", {}))
	story_memory = _normalize_story_memory(data.get("story_memory", {}))

	if module_1_complete:
		cleared_stages[stage_progress_key("mod_01", 10)] = true
	_restore_cloud_reconcile_state(data)
	_normalize_mastery_keys()
	progress_changed.emit()


func _restore_cloud_reconcile_state(data: Dictionary) -> void:
	_cloud_baseline = ""
	_unconfirmed_bkt_log.clear()
	_cloud_upload_pinned = false
	_local_upload_ready = false
	_verified_upload = false
	_pending_cloud_merge = false
	_wallet_basis_known = false
	_wallet_basis_credits = 0
	_wallet_basis_tokens = 0
	_evidence_basis_known = false
	_evidence_basis_responses = 0
	_evidence_basis_sessions = 0
	_evidence_basis_topics = {}
	var baseline_raw: Variant = data.get("cloud_baseline", "")
	var baseline: String = str(baseline_raw) if baseline_raw is String else ""
	if baseline == "unconfirmed" or baseline == "empty" or baseline == "known":
		_cloud_baseline = baseline
	var log_raw: Variant = data.get("unconfirmed_bkt_log", [])
	if log_raw is Array:
		for step: Variant in log_raw:
			if step is Dictionary:
				_unconfirmed_bkt_log.append((step as Dictionary).duplicate(true))
	if data.has("cloud_upload_ready"):
		_cloud_upload_pinned = true
		_pending_cloud_merge = bool(data["cloud_upload_ready"])
	if data.has("wallet_basis_known"):
		_wallet_basis_known = bool(data["wallet_basis_known"])
		_wallet_basis_credits = _variant_int(data.get("wallet_basis_credits", 0))
		_wallet_basis_tokens = _variant_int(data.get("wallet_basis_tokens", 0))
	if data.has("evidence_basis_known"):
		_evidence_basis_known = bool(data["evidence_basis_known"])
		_evidence_basis_responses = _variant_int(data.get("evidence_basis_responses", 0))
		_evidence_basis_sessions = _variant_int(data.get("evidence_basis_sessions", 0))
		_evidence_basis_topics = {}
		var basis_topics: Variant = data.get("evidence_basis_topics", {})
		if basis_topics is Dictionary:
			for topic_id: Variant in basis_topics.keys():
				_evidence_basis_topics[str(topic_id)] = _variant_int(basis_topics[topic_id])


func _copy_bkt_log() -> Array:
	var copy: Array = []
	for step: Dictionary in _unconfirmed_bkt_log:
		copy.append(step.duplicate(true))
	return copy


## Cloud history stays in place. Offline answers are applied on top of it,
## and every other field keeps both sides when they touched different data.
func reconcile_cloud_snapshot(cloud: Dictionary) -> void:
	var local: Dictionary = get_save_data()
	var log: Array[Dictionary] = []
	for step: Dictionary in _unconfirmed_bkt_log:
		log.append(step.duplicate(true))
	var basis_known: bool = _wallet_basis_known
	var basis_credits: int = _wallet_basis_credits
	var basis_tokens: int = _wallet_basis_tokens
	var evidence_basis_known: bool = _evidence_basis_known
	var evidence_basis_responses: int = _evidence_basis_responses
	var evidence_basis_sessions: int = _evidence_basis_sessions
	var evidence_basis_topics: Dictionary = _evidence_basis_topics.duplicate(true)
	var merged: Dictionary = _merge_unconfirmed_progress(cloud, local, basis_known, basis_credits, basis_tokens, evidence_basis_known, evidence_basis_responses, evidence_basis_sessions, evidence_basis_topics)
	# Keep the log through a failed POST and through a stale GET. Replay starts
	# from the cloud prior, and steps already visible in that snapshot are skipped.
	var persisted_log: Array = []
	for step: Dictionary in log:
		persisted_log.append(step.duplicate(true))
	merged["unconfirmed_bkt_log"] = persisted_log
	apply_save_data(merged)
	_replay_bkt_log(log, cloud.get("pretest_baselines", {}))
	_cloud_baseline = "known"
	_pending_cloud_merge = false
	_wallet_basis_known = true
	_wallet_basis_credits = credits
	_wallet_basis_tokens = pvp_tokens
	_note_evidence_basis()
	_verified_upload = true
	_local_upload_ready = true
	_cloud_upload_pinned = false
	progress_changed.emit()


func _merge_unconfirmed_progress(cloud: Dictionary, local: Dictionary, basis_known: bool, basis_credits: int, basis_tokens: int, evidence_basis_known: bool, evidence_basis_responses: int, evidence_basis_sessions: int, evidence_basis_topics: Dictionary) -> Dictionary:
	var merged: Dictionary = cloud.duplicate(true)
	merged["lesson_progress"] = _max_int_dict(cloud.get("lesson_progress", {}), local.get("lesson_progress", {}))
	merged["lesson_post_quiz_scores"] = _max_int_dict(cloud.get("lesson_post_quiz_scores", {}), local.get("lesson_post_quiz_scores", {}))
	merged["max_stage_cleared_by_module"] = _max_int_dict(cloud.get("max_stage_cleared_by_module", {}), local.get("max_stage_cleared_by_module", {}))
	merged["mock_max_stage_cleared"] = maxi(_variant_int(cloud.get("mock_max_stage_cleared", 0)), _variant_int(local.get("mock_max_stage_cleared", 0)))
	var merged_credits: int = _combine_wallet(_variant_int(cloud.get("credits", 0)), _variant_int(local.get("credits", 0)), basis_known, basis_credits)
	var merged_tokens: int = _combine_wallet(_variant_int(cloud.get("pvp_tokens", 0)), _variant_int(local.get("pvp_tokens", 0)), basis_known, basis_tokens)
	merged["credits"] = merged_credits
	merged["pvp_tokens"] = merged_tokens
	merged["wallet_basis_known"] = true
	merged["wallet_basis_credits"] = merged_credits
	merged["wallet_basis_tokens"] = merged_tokens
	merged["completed_lessons"] = _union_strings(cloud.get("completed_lessons", []), local.get("completed_lessons", []))
	merged["cleared_stages"] = _union_strings(cloud.get("cleared_stages", []), local.get("cleared_stages", []))
	merged["unlocked_towers"] = _union_strings(cloud.get("unlocked_towers", []), local.get("unlocked_towers", []), ["base"])
	merged["unlocked_skills"] = _union_strings(cloud.get("unlocked_skills", []), local.get("unlocked_skills", []))
	merged["purchased_items"] = _union_strings(cloud.get("purchased_items", []), local.get("purchased_items", []))
	merged["owned_perks"] = _union_strings(cloud.get("owned_perks", []), local.get("owned_perks", []), ["recap"])
	merged["seen_module_intros"] = _union_strings(cloud.get("seen_module_intros", []), local.get("seen_module_intros", []))
	merged["locked_stages"] = _union_dict_keys(cloud.get("locked_stages", {}), local.get("locked_stages", {}))
	merged["pretest_baselines"] = _union_missing_keys(cloud.get("pretest_baselines", {}), local.get("pretest_baselines", {}))
	merged["practice_responses"] = _union_missing_keys(cloud.get("practice_responses", {}), local.get("practice_responses", {}))
	merged["lesson_quiz_responses"] = _union_quiz_responses(cloud.get("lesson_quiz_responses", {}), local.get("lesson_quiz_responses", {}))
	merged["mission_progress"] = _union_missing_keys(cloud.get("mission_progress", {}), local.get("mission_progress", {}))
	merged["chapter_progress"] = _union_missing_keys(cloud.get("chapter_progress", {}), local.get("chapter_progress", {}))
	merged["learning_events"] = _union_events(cloud.get("learning_events", []), local.get("learning_events", []))
	var merged_evidence: Dictionary = _merge_evidence(cloud.get("learning_evidence", {}), local.get("learning_evidence", {}), evidence_basis_known, evidence_basis_responses, evidence_basis_sessions, evidence_basis_topics)
	merged["learning_evidence"] = merged_evidence
	merged["evidence_basis_known"] = true
	merged["evidence_basis_responses"] = _variant_int(merged_evidence.get("responses", 0))
	merged["evidence_basis_sessions"] = _variant_int(merged_evidence.get("sessions", 0))
	var merged_topics: Dictionary = {}
	var merged_topic_raw: Variant = merged_evidence.get("topics", {})
	if merged_topic_raw is Dictionary:
		for topic_id: Variant in merged_topic_raw.keys():
			merged_topics[str(topic_id)] = _variant_int(merged_topic_raw[topic_id])
	merged["evidence_basis_topics"] = merged_topics
	merged["mastery_matrix"] = _merge_mastery(cloud.get("mastery_matrix", {}), local.get("mastery_matrix", {}), cloud.get("lesson_progress", {}), local.get("lesson_progress", {}))
	merged["tutorial_complete"] = bool(cloud.get("tutorial_complete", false)) or bool(local.get("tutorial_complete", false))
	merged["tutorial_skipped"] = bool(cloud.get("tutorial_skipped", false)) or bool(local.get("tutorial_skipped", false))
	merged["module_1_complete"] = bool(cloud.get("module_1_complete", false)) or bool(local.get("module_1_complete", false))
	merged["has_intel_bonus"] = bool(cloud.get("has_intel_bonus", false)) or bool(local.get("has_intel_bonus", false))
	merged["cloud_baseline"] = "known"
	merged["cloud_upload_ready"] = true
	return merged


func _note_evidence_basis() -> void:
	_evidence_basis_known = true
	_evidence_basis_responses = _variant_int(learning_evidence.get("responses", 0))
	_evidence_basis_sessions = _variant_int(learning_evidence.get("sessions", 0))
	_evidence_basis_topics = {}
	var topics: Variant = learning_evidence.get("topics", {})
	if topics is Dictionary:
		for topic_id: Variant in topics.keys():
			_evidence_basis_topics[str(topic_id)] = _variant_int(topics[topic_id])


func _combine_wallet(cloud_value: int, local_value: int, basis_known: bool, basis: int) -> int:
	if not basis_known:
		return maxi(cloud_value, local_value)
	# Earnings on each side since the verified balance are applied once.
	# A lower cloud value is an older snapshot, not a second copy of the balance.
	var cloud_gain: int = maxi(0, cloud_value - basis)
	return maxi(0, local_value + cloud_gain)


func _merge_mastery(cloud_raw: Variant, local_raw: Variant, cloud_lessons_raw: Variant, local_lessons_raw: Variant) -> Dictionary:
	var merged: Dictionary = {}
	if cloud_raw is Dictionary:
		merged = (cloud_raw as Dictionary).duplicate(true)
	if not local_raw is Dictionary:
		return merged
	var logged: Dictionary = {}
	for step: Dictionary in _unconfirmed_bkt_log:
		var logged_skill: String = str(step.get("skill", "")).strip_edges()
		if not logged_skill.is_empty():
			logged[logged_skill] = true
	var cloud_lessons: Dictionary = cloud_lessons_raw if cloud_lessons_raw is Dictionary else {}
	var local_lessons: Dictionary = local_lessons_raw if local_lessons_raw is Dictionary else {}
	var local: Dictionary = local_raw
	for key: Variant in local.keys():
		var skill: String = str(key)
		if logged.has(skill):
			continue
		var local_value: float = float(local[key])
		# A stored 0.10 with no answer, pretest, or checkpoint is the prior.
		# Copying it would wipe a cloud skill the player has not assessed.
		if _is_unassessed_prior(skill, local_value):
			continue
		var module_id: String = str(LEARNING_MODULES.get(skill, ""))
		var cloud_lesson: int = _variant_int(cloud_lessons.get(module_id, 0))
		var local_lesson: int = _variant_int(local_lessons.get(module_id, 0))
		if not merged.has(skill) or local_lesson > cloud_lesson:
			merged[skill] = local_value
	return merged


func _next_bkt_step_id(skill_id: String) -> String:
	_bkt_step_seq += 1
	return "%s-%d-%d" % [skill_id, _bkt_step_seq, Time.get_ticks_usec()]


func _replay_bkt_log(log: Array[Dictionary], cloud_baselines: Variant) -> void:
	var baselines: Dictionary = cloud_baselines if cloud_baselines is Dictionary else {}
	var skip_counts: Dictionary = _reflected_bkt_prefix(log)
	_drop_reflected_bkt_steps(skip_counts)
	var seen_updates: Dictionary = {}
	for step: Dictionary in log:
		var skill: String = str(step.get("skill", "")).strip_edges()
		if skill.is_empty():
			continue
		if str(step.get("op", "")) == "seed":
			if int(skip_counts.get(skill, 0)) > 0:
				continue
			var module_id: String = str(LEARNING_MODULES.get(skill, ""))
			if not module_id.is_empty() and baselines.has(module_id):
				continue
			apply_official_mastery(skill, float(step.get("value", DEFAULT_MASTERY)))
			continue
		var seen: int = int(seen_updates.get(skill, 0))
		seen_updates[skill] = seen + 1
		if seen < int(skip_counts.get(skill, 0)):
			continue
		_apply_mastery_step(
			skill,
			bool(step.get("correct", false)),
			float(step.get("p_g", P_GUESS)),
			float(step.get("p_s", P_SLIP)),
			float(step.get("p_t", P_TRANSIT)),
		)


func _drop_reflected_bkt_steps(skip_counts: Dictionary) -> void:
	var seen_updates: Dictionary = {}
	var remaining: Array[Dictionary] = []
	for step: Dictionary in _unconfirmed_bkt_log:
		var skill: String = str(step.get("skill", "")).strip_edges()
		var reflected: int = int(skip_counts.get(skill, 0))
		if str(step.get("op", "")) == "seed":
			if reflected > 0:
				continue
			remaining.append(step)
			continue
		var seen: int = int(seen_updates.get(skill, 0))
		seen_updates[skill] = seen + 1
		if seen < reflected:
			continue
		remaining.append(step)
	_unconfirmed_bkt_log = remaining


## How many leading answers for each skill are already present in the cloud
## mastery this replay is about to update. A later retry then applies only the tail.
func _reflected_bkt_prefix(log: Array[Dictionary]) -> Dictionary:
	var grouped: Dictionary = {}
	for step: Dictionary in log:
		if str(step.get("op", "")) == "seed":
			continue
		var skill: String = str(step.get("skill", "")).strip_edges()
		if skill.is_empty():
			continue
		if not grouped.has(skill):
			grouped[skill] = []
		var bucket: Array = grouped[skill]
		bucket.append(step)
		grouped[skill] = bucket
	var skip_counts: Dictionary = {}
	for skill_id: Variant in grouped.keys():
		var skill: String = str(skill_id)
		var steps: Array = grouped[skill]
		var current: float = _mastery_of(skill)
		var skip: int = 0
		var previous_posterior: float = 0.0
		var have_previous: bool = false
		for index: int in steps.size():
			var raw_step: Variant = steps[index]
			if not raw_step is Dictionary:
				break
			var step: Dictionary = raw_step
			if not step.has("posterior"):
				break
			var posterior: float = float(step["posterior"])
			if have_previous:
				if not step.has("prior") or not is_equal_approx(float(step["prior"]), previous_posterior):
					break
			if is_equal_approx(current, posterior):
				skip = index + 1
			previous_posterior = posterior
			have_previous = true
		skip_counts[skill] = skip
	return skip_counts


func _variant_int(raw: Variant) -> int:
	if raw is int or raw is float:
		return int(raw)
	return 0


func _max_int_dict(cloud_raw: Variant, local_raw: Variant) -> Dictionary:
	var merged: Dictionary = {}
	if cloud_raw is Dictionary:
		var cloud: Dictionary = cloud_raw
		for key: Variant in cloud.keys():
			merged[str(key)] = _variant_int(cloud[key])
	if local_raw is Dictionary:
		var local: Dictionary = local_raw
		for key: Variant in local.keys():
			var id: String = str(key)
			merged[id] = maxi(_variant_int(merged.get(id, 0)), _variant_int(local[key]))
	return merged


func _union_strings(cloud_raw: Variant, local_raw: Variant, defaults: Array = []) -> Array:
	var merged: Array = []
	var seen: Dictionary = {}
	var sources: Array = [cloud_raw, local_raw]
	for source: Variant in sources:
		if not source is Array:
			continue
		for entry: Variant in source:
			var text: String = str(entry).strip_edges()
			if text.is_empty() or seen.has(text) or defaults.has(text):
				continue
			seen[text] = true
			merged.append(text)
	return merged


func _union_dict_keys(cloud_raw: Variant, local_raw: Variant) -> Dictionary:
	var merged: Dictionary = {}
	var sources: Array = [cloud_raw, local_raw]
	for source: Variant in sources:
		if not source is Dictionary:
			continue
		var data: Dictionary = source
		for key: Variant in data.keys():
			merged[str(key)] = true
	return merged


func _union_missing_keys(cloud_raw: Variant, local_raw: Variant) -> Dictionary:
	var merged: Dictionary = {}
	if cloud_raw is Dictionary:
		merged = (cloud_raw as Dictionary).duplicate(true)
	if local_raw is Dictionary:
		var local: Dictionary = local_raw
		for key: Variant in local.keys():
			if not merged.has(key):
				merged[key] = local[key]
	return merged


func _union_quiz_responses(cloud_raw: Variant, local_raw: Variant) -> Dictionary:
	var merged: Dictionary = {}
	if cloud_raw is Dictionary:
		merged = (cloud_raw as Dictionary).duplicate(true)
	if not local_raw is Dictionary:
		return merged
	var local: Dictionary = local_raw
	for module_id: Variant in local.keys():
		if typeof(local[module_id]) != TYPE_DICTIONARY:
			continue
		var local_module: Dictionary = local[module_id]
		var combined: Dictionary = {}
		if merged.get(module_id) is Dictionary:
			combined = (merged[module_id] as Dictionary).duplicate(true)
		for question_id: Variant in local_module.keys():
			if not combined.has(question_id):
				combined[question_id] = local_module[question_id]
		merged[module_id] = combined
	return merged


func _union_events(cloud_raw: Variant, local_raw: Variant) -> Array:
	var merged: Array = []
	var seen: Dictionary = {}
	var sources: Array = [cloud_raw, local_raw]
	for source: Variant in sources:
		if not source is Array:
			continue
		for entry: Variant in source:
			if not entry is Dictionary:
				continue
			var event: Dictionary = entry
			var event_id: String = str(event.get("event_id", "")).strip_edges()
			if event_id.is_empty() or seen.has(event_id):
				continue
			seen[event_id] = true
			merged.append(event.duplicate(true))
	return merged


func _merge_evidence(cloud_raw: Variant, local_raw: Variant, basis_known: bool, basis_responses: int, basis_sessions: int, basis_topics: Dictionary) -> Dictionary:
	var cloud: Dictionary = cloud_raw if cloud_raw is Dictionary else {}
	var local: Dictionary = local_raw if local_raw is Dictionary else {}
	var topics: Dictionary = {}
	var cloud_topics: Dictionary = cloud.get("topics", {}) if cloud.get("topics", {}) is Dictionary else {}
	var local_topics: Dictionary = local.get("topics", {}) if local.get("topics", {}) is Dictionary else {}
	var topic_ids: Dictionary = {}
	for source: Dictionary in [cloud_topics, local_topics, basis_topics]:
		for key: Variant in source.keys():
			topic_ids[str(key)] = true
	for key: Variant in topic_ids.keys():
		var id: String = str(key)
		topics[id] = _combine_wallet(_variant_int(cloud_topics.get(id, 0)), _variant_int(local_topics.get(id, 0)), basis_known, _variant_int(basis_topics.get(id, 0)))
	var responses: int = _combine_wallet(_variant_int(cloud.get("responses", 0)), _variant_int(local.get("responses", 0)), basis_known, basis_responses)
	if responses <= 0:
		return {}
	var sessions: int = _combine_wallet(_variant_int(cloud.get("sessions", 0)), _variant_int(local.get("sessions", 0)), basis_known, basis_sessions)
	var cloud_first: int = _variant_int(cloud.get("first_at", 0))
	var local_first: int = _variant_int(local.get("first_at", 0))
	var first_at: int = 0
	if cloud_first > 0 and local_first > 0:
		first_at = mini(cloud_first, local_first)
	elif cloud_first > 0:
		first_at = cloud_first
	else:
		first_at = local_first
	return {
		"topics": topics,
		"responses": responses,
		"sessions": maxi(1, sessions),
		"first_at": first_at,
		"last_at": maxi(_variant_int(cloud.get("last_at", 0)), _variant_int(local.get("last_at", 0))),
	}


## Normalizes either representation of a stage-progress set (cleared_stages
## or locked_stages) into module-scoped keys. Accepts already-canonical
## "module_id:stage_id" strings unchanged (idempotent — re-ingesting a
## normalized save reproduces the identical set, no duplicates) and migrates
## legacy raw stage numbers (int, float, or a bare numeric string) into
## Module 1, the only module with real stage content before Module 2 existed.
func _ingest_stage_progress_set(raw: Variant, target: Dictionary) -> void:
	var entries: Array = []
	if typeof(raw) == TYPE_ARRAY:
		entries = raw as Array
	elif typeof(raw) == TYPE_DICTIONARY:
		entries = (raw as Dictionary).keys()
	else:
		return
	for i in entries.size():
		var key: String = _normalize_stage_progress_key(entries[i])
		if not key.is_empty():
			target[key] = true


func _normalize_stage_progress_key(entry: Variant) -> String:
	if typeof(entry) == TYPE_INT or typeof(entry) == TYPE_FLOAT:
		var stage_id: int = int(entry)
		return stage_progress_key("mod_01", stage_id) if stage_id > 0 else ""
	if typeof(entry) != TYPE_STRING and typeof(entry) != TYPE_STRING_NAME:
		return ""
	var text: String = str(entry).strip_edges()
	if text.is_empty():
		return ""
	var colon: int = text.find(":")
	if colon > 0:
		var module_part: String = text.substr(0, colon).strip_edges()
		var stage_part: String = text.substr(colon + 1).strip_edges()
		if not module_part.is_empty() and stage_part.is_valid_int() and int(stage_part) > 0:
			return stage_progress_key(module_part, int(stage_part))
		return ""
	if text.is_valid_int():
		var legacy_id: int = int(text)
		return stage_progress_key("mod_01", legacy_id) if legacy_id > 0 else ""
	return ""


## Memory keeps the 0.10 prior so recommendations and the threat matrix
## stay unchanged. Saves and uploads omit that prior unless an assessment
## actually produced it.
func _is_unassessed_prior(skill_id: String, value: float) -> bool:
	return is_equal_approx(value, DEFAULT_MASTERY) and not _skill_has_assessment(skill_id)


func _skill_has_assessment(skill_id: String) -> bool:
	var skill: String = skill_id.strip_edges().to_lower()
	if skill.is_empty():
		return false
	if has_graded_evidence(skill):
		return true
	var module_id: String = str(LEARNING_MODULES.get(skill, ""))
	if not module_id.is_empty() and pretest_baselines.has(module_id):
		return true
	if not module_id.is_empty() and int(lesson_post_quiz_scores.get(module_id, 0)) > 0:
		return true
	if not module_id.is_empty():
		var quizzes: Variant = lesson_quiz_responses.get(module_id, {})
		if quizzes is Dictionary and not (quizzes as Dictionary).is_empty():
			return true
	for question_id: Variant in practice_responses.keys():
		var record: Variant = practice_responses[question_id]
		if not record is Dictionary:
			continue
		if str(record.get("skill", "")) == skill:
			return true
		if not module_id.is_empty() and str(record.get("module_id", "")) == module_id:
			return true
	for step: Dictionary in _unconfirmed_bkt_log:
		if str(step.get("skill", "")).strip_edges().to_lower() == skill:
			return true
	return false


func _export_mastery_matrix() -> Dictionary:
	var exported: Dictionary = {}
	var keys: Array = mastery_matrix.keys()
	for i in keys.size():
		var skill_id: String = str(keys[i])
		var value: float = float(mastery_matrix[keys[i]])
		if _is_unassessed_prior(skill_id, value):
			continue
		exported[skill_id] = value
	return exported


func _normalize_mastery_keys() -> void:
	var next: Dictionary = {}
	for i in _OFFICIAL_SKILLS.size():
		var skill_id: String = _OFFICIAL_SKILLS[i]
		var value: float = DEFAULT_MASTERY
		if mastery_matrix.has(skill_id):
			value = float(mastery_matrix[skill_id])
		next[skill_id] = value
	mastery_matrix = next


func _ensure_default_capacity_rank() -> void:
	if tech_rank("base", "capacity") >= 1:
		return
	_set_tech_rank("base", "capacity", 1)


func has_graded_evidence(skill_id: String) -> bool:
	var topics: Dictionary = learning_evidence.get("topics", {})
	return int(topics.get(skill_id.to_lower(), 0)) > 0


func _record_graded_response(skill_id: String, now: int) -> void:
	if not AuthService.is_signed_in() or Router.is_tutorial or skill_id not in _OFFICIAL_SKILLS:
		return
	var previous: int = int(learning_evidence.get("last_at", 0))
	if previous <= 0:
		learning_evidence["first_at"] = now
	if previous <= 0 or now - previous >= LEARNING_SESSION_IDLE_SECONDS:
		learning_evidence["sessions"] = int(learning_evidence.get("sessions", 0)) + 1
	learning_evidence["last_at"] = maxi(now, previous)
	learning_evidence["responses"] = int(learning_evidence.get("responses", 0)) + 1
	var topics: Dictionary = learning_evidence.get("topics", {})
	topics[skill_id] = int(topics.get(skill_id, 0)) + 1
	learning_evidence["topics"] = topics


func learning_support_eligible(now: int = -1) -> bool:
	if not AuthService.is_signed_in() or needs_tutorial() or Router.is_tutorial:
		return false
	var first: int = int(learning_evidence.get("first_at", 0))
	var clock: int = int(Time.get_unix_time_from_system()) if now < 0 else now
	return first > 0 and clock - first >= SUPPORT_GRACE_SECONDS \
		and int(learning_evidence.get("responses", 0)) >= 10 \
		and int(learning_evidence.get("sessions", 0)) >= 2


func _restore_learning_evidence(raw: Variant) -> void:
	learning_evidence = {}
	if not raw is Dictionary:
		return
	var topics: Variant = raw.get("topics", {})
	if not topics is Dictionary:
		return
	var clean_topics: Dictionary = {}
	var responses: int = 0
	for skill: String in _OFFICIAL_SKILLS:
		var count: Variant = topics.get(skill, 0)
		if (count is int or count is float) and is_finite(float(count)):
			var safe_count: int = clampi(int(count), 0, 1000000)
			if safe_count > 0:
				clean_topics[skill] = safe_count
				responses += safe_count
	for key: String in ["first_at", "last_at", "sessions"]:
		var value: Variant = raw.get(key, 0)
		if not (value is int or value is float) or not is_finite(float(value)):
			return
	if responses <= 0 or int(raw.get("first_at", 0)) <= 0:
		return
	learning_evidence = {"topics": clean_topics, "responses": responses,
		"first_at": int(raw.first_at), "last_at": maxi(int(raw.first_at), int(raw.get("last_at", 0))),
		"sessions": clampi(int(raw.get("sessions", 0)), 1, responses)}


func _sanitize_tech_ranks() -> void:
	var clean: Dictionary = {}
	var tower_keys: Array = tech_ranks.keys()
	for i in tower_keys.size():
		var tower_id: String = str(tower_keys[i])
		if tower_id.is_empty() or typeof(tech_ranks[tower_keys[i]]) != TYPE_DICTIONARY:
			continue
		var tracks: Dictionary = tech_ranks[tower_keys[i]] as Dictionary
		var next_tracks: Dictionary = {}
		var track_keys: Array = tracks.keys()
		for j in track_keys.size():
			var track_id: String = str(track_keys[j])
			if track_id.is_empty():
				continue
			next_tracks[track_id] = maxi(0, int(tracks[track_keys[j]]))
		clean[tower_id] = next_tracks
	tech_ranks = clean


func _sync_evolution_unlocks() -> void:
	var evo: int = tech_rank("base", "evolution")
	if evo >= 1 and not unlocked_towers.has("scanner"):
		unlocked_towers.append("scanner")
	if evo >= 2 and not unlocked_towers.has("sandbox"):
		unlocked_towers.append("sandbox")


# Learning evidence is account-scoped and travels with the existing offline save.
var learning_events: Array[Dictionary] = []
const LEARNING_MODULES: Dictionary = {"phishing":"mod_01", "smishing":"mod_02", "vishing":"mod_03", "pretexting":"mod_04", "baiting":"mod_05"}

func learning_id() -> String:
	var value: String = Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-4%s-a%s-%s" % [value.substr(0,8), value.substr(8,4), value.substr(13,3), value.substr(17,3), value.substr(20,12)]

func record_learning_event(kind: String, module_id: String, fields: Dictionary, persist: bool = true) -> void:
	if not AuthService.is_signed_in() or module_id not in LEARNING_MODULES.values():
		return
	var event: Dictionary = fields.duplicate(true)
	var now: float = Time.get_unix_time_from_system()
	var stamp: String = Time.get_datetime_string_from_unix_time(int(now)) + ".%06dZ" % int(fmod(now, 1.0) * 1000000.0)
	event.merge({"event_id":learning_id(), "kind":kind, "module_id":module_id, "occurred_at":stamp}, true)
	learning_events.append(event)
	if persist:
		_save_progress()

func begin_learning_attempt(module_id: String, stage_id: int) -> String:
	if not AuthService.is_signed_in():
		return ""
	var attempt: String = learning_id()
	record_learning_event("stage", module_id, {"attempt_id":attempt, "stage":stage_id, "outcome":"started"})
	return attempt

func finish_learning_attempt(attempt: String, module_id: String, stage_id: int, outcome: String, details: Dictionary = {}) -> void:
	if not attempt.is_empty():
		var fields: Dictionary = {"attempt_id":attempt, "stage":stage_id, "outcome":outcome}
		if not details.is_empty():
			fields["details"] = details.duplicate(true)
		record_learning_event("stage", module_id, fields)

func acknowledge_learning_events(ids: Array) -> void:
	var remaining: Array[Dictionary] = []
	for event: Dictionary in learning_events:
		if event.get("event_id", "") not in ids:
			remaining.append(event)
	learning_events = remaining
