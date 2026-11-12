import logging
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status

from app.data.pretest_questions import parse_module_pretests
from app.schemas.progress import ProgressSyncRequest, ProgressSyncResponse
from app.services.auth_service import _supabase_error, ensure_student_access, fetch_student_by_id
from app.services.bkt_service import MASTERY_COLUMNS, P_L0, clamp_pl
from app.services.database_diagnostics import is_lock_timeout, log_operational_event
from app.supabase_client import supabase

from app.services.learning_records import record_learning_events

logger = logging.getLogger(__name__)


class ProgressReadError(RuntimeError):
    """The cloud save could not be read. This is not an empty row."""

# Gameplay P(L) is calculated in Godot and stored as a snapshot on sync.
# Pre-test still writes official P(L) through its own diagnostic (P(T)=0) path.
GAME_TOPIC_MAP = {
    "phishing": "Phishing",
    "smishing": "Smishing",
    "vishing": "Vishing",
    "pretexting": "Pretexting",
    "baiting": "Baiting",
}
STUDENT_SYNC_KEYS = (
    "threat_points",
    "upgrade_materials",
    "points",
    "sessions",
    "tower_level",
    "glade_level",
    "forge_level",
    "pre",
    "post",
)
# Same future skew already accepted on a learning-event occurred_at.
_ACTIVITY_FUTURE_SKEW = timedelta(minutes=10)


def _as_utc(moment: datetime) -> datetime:
    if moment.tzinfo is None:
        return moment.replace(tzinfo=UTC)
    return moment.astimezone(UTC)


def _plausible_learning_time(moment: datetime, now: datetime) -> bool:
    """A real learning clock time. Naive, ancient, and far-future values are not."""
    if moment.tzinfo is None:
        return False
    current = _as_utc(moment)
    if current.year < 2020:
        return False
    return current <= now + _ACTIVITY_FUTURE_SKEW


def _parse_stored_activity(value: object, now: datetime) -> datetime | None:
    if isinstance(value, datetime):
        moment = value
    elif value is None:
        return None
    else:
        text = str(value).strip()
        if not text or text.lower() == "just now":
            return None
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            moment = datetime.fromisoformat(text)
        except ValueError:
            return None
    if not _plausible_learning_time(moment, now):
        return None
    return _as_utc(moment)


def _evidence_activity(value: object, now: datetime) -> datetime | None:
    number = _finite_number(value)
    if number is None or number <= 0:
        return None
    try:
        moment = datetime.fromtimestamp(number, UTC)
    except (OverflowError, OSError, ValueError):
        return None
    if not _plausible_learning_time(moment, now):
        return None
    return moment


def _latest_learning_activity(
    payload: ProgressSyncRequest,
    dumped: dict,
    now: datetime,
) -> datetime | None:
    """Latest validated learning time in this upload. The request clock is not one."""
    latest: datetime | None = None
    for event in payload.learning_events:
        if not _plausible_learning_time(event.occurred_at, now):
            continue
        moment = _as_utc(event.occurred_at)
        if latest is None or moment > latest:
            latest = moment
    evidence = dumped.get("learning_evidence")
    if isinstance(evidence, dict):
        moment = _evidence_activity(evidence.get("last_at"), now)
        if moment is not None and (latest is None or moment > latest):
            latest = moment
    return latest


def _last_active_update(student: dict, activity: datetime | None, now: datetime) -> str | None:
    """ISO activity time when this upload is newer. None leaves the stored value alone."""
    if activity is None:
        return None
    stored = _parse_stored_activity(student.get("last_active"), now)
    if stored is not None and stored >= activity:
        return None
    return _as_utc(activity).isoformat()


def sync_student_progress(student_id: str, payload: ProgressSyncRequest) -> ProgressSyncResponse:
    student = fetch_student_by_id(student_id)
    ensure_student_access(student)
    acknowledged = record_learning_events(student_id, payload.learning_events)
    current_stage = int(student.get("highest_unlocked_stage") or 1)
    incoming_stage = max(1, int(payload.mock_max_stage_cleared))
    dumped = payload.model_dump()
    now = datetime.now(UTC)
    update = {
        "highest_unlocked_stage": max(current_stage, incoming_stage),
    }
    # last_active is the latest real learning time, not the moment this request arrived.
    last_active = _last_active_update(
        student,
        _latest_learning_activity(payload, dumped, now),
        now,
    )
    if last_active is not None:
        update["last_active"] = last_active
    completed_at_start = _official_module_ids(student)
    student_patch = dumped.get("student")
    if isinstance(student_patch, dict):
        for key in STUDENT_SYNC_KEYS:
            if key not in student_patch or student_patch[key] is None:
                continue
            # On the current schema the graded pretest endpoint owns students.pre.
            # A phone snapshot must not publish that percent early or replace it later.
            if key == "pre" and "module_pretests" in student:
                continue
            value = student_patch[key]
            if key in ("pre", "post", "highest_unlocked_stage"):
                update[key] = max(int(student.get(key) or 0), int(value))
            elif key.startswith("mastery_"):
                update[key] = float(value)
            else:
                update[key] = int(value)

    _required_write(
        student_id,
        "students.update",
        lambda: supabase.table("students").update(update).eq("id", student_id).execute(),
    )

    try:
        stored_progress = fetch_student_progress(student_id) or {}
    except ProgressReadError as exc:
        raise _supabase_error(exc) from exc
    if not isinstance(stored_progress, dict):
        stored_progress = {}
    incoming_matrix = dumped.get("mastery_matrix") or {}
    incoming_assessed = _assessed_skills(dumped)
    merged_matrix = _merge_uploaded_mastery(
        incoming_matrix,
        stored_progress.get("mastery_matrix") or {},
        dumped,
        stored_progress,
    )
    # The graded pretest may commit while this snapshot is in flight. That
    # column is the one diagnostic result. This snapshot must not replace it
    # with the phone's earlier posterior or become the next diagnostic prior.
    fresh_student = fetch_student_by_id(student_id)
    gained = _official_module_ids(fresh_student) - completed_at_start
    merged_matrix = _retain_official_pretest_mastery(merged_matrix, fresh_student, gained)
    # The read above can still go stale before the write. A conditional update
    # has to notice that, and the BKT row has to use the same pre-image.
    merged_matrix, fresh_student = _upsert_game_bkt(student_id, merged_matrix, fresh_student)
    dumped["mastery_matrix"] = merged_matrix
    blob = {k: v for k, v in dumped.items() if k not in ("student", "learning_events")}
    # Educational history is merged before the retention copy. A new posterior
    # must not decide whether stored answers survive, and schema defaults must
    # not look like a request to clear lesson completion.
    _merge_educational_history(blob, stored_progress, set(payload.model_fields_set))
    _preserve_assessment_provenance(
        blob,
        stored_progress,
        _skills_retained_from_store(merged_matrix, incoming_matrix, incoming_assessed),
    )
    _upsert_save_blob(student_id, blob, stored_progress, fresh_student)
    return ProgressSyncResponse(acknowledged_events=acknowledged)


def fetch_student_progress(student_id: str) -> dict | None:
    """Return the stored Godot save blob, or None when no cloud row exists.

    A storage failure raises ProgressReadError. Callers must not treat that
    as confirmation that the student has no cloud progress.
    """
    try:
        response = (
            supabase.table("player_saves")
            .select("payload")
            .eq("student_id", student_id)
            .limit(1)
            .execute()
        )
    except Exception as exc:
        logger.exception("progress fetch failed student_id=%s", student_id)
        raise ProgressReadError("Cloud progress could not be read") from exc
    rows = response.data or []
    if not rows:
        return None
    payload = rows[0].get("payload")
    return payload if isinstance(payload, dict) else None


def _required_write(student_id: str, operation: str, execute) -> object:
    """Run a required Supabase write. Failures must fail the sync request."""
    try:
        response = execute()
    except Exception as exc:
        logger.exception("progress sync: %s failed student_id=%s", operation, student_id)
        raise _supabase_error(exc) from exc
    if getattr(response, "error", None):
        logger.error(
            "progress sync: %s returned error student_id=%s error=%s",
            operation,
            student_id,
            response.error,
        )
        raise _supabase_error(RuntimeError(operation))
    return response


SYNC_CONFLICT_DETAIL = "Progress changed during sync. Your progress is still saved on this device and will retry."
SYNC_BUSY_DETAIL = "Progress sync is busy. Your progress is still saved on this device and will retry."


def _upsert_game_bkt(
    student_id: str,
    matrix: dict[str, float],
    guarded_student: dict,
) -> tuple[dict[str, float], dict]:
    """Write gameplay mastery without replacing a pretest that landed after the read.

    levelblue_write_mastery updates students.mastery_* and bkt_records in one
    transaction under the student row lock, only while the columns still hold
    this attempt's read and no module this attempt saw as incomplete has been
    graded. The retry keeps a newly graded column and does not apply that
    topic's phone snapshot. A second conflict raises 409 with nothing written,
    so the phone keeps its upload pending.
    """
    current = dict(matrix)
    baseline = guarded_student if isinstance(guarded_student, dict) else {}
    for attempt in range(2):
        payload = _student_mastery_payload(current)
        if not payload:
            return current, baseline
        if _write_mastery(student_id, payload, baseline):
            return current, baseline
        if attempt == 1:
            break
        previous = baseline
        baseline = fetch_student_by_id(student_id)
        current = _preserve_graded_mastery(current, previous, baseline)
    logger.warning("progress sync: mastery conflict unresolved student_id=%s", student_id)
    log_operational_event(
        "sync-failure",
        "Progress sync mastery changed twice during one upload; the phone keeps it pending.",
        "mastery-conflict",
        "/api/progress/sync",
        status.HTTP_409_CONFLICT,
    )
    raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=SYNC_CONFLICT_DETAIL)


def _student_mastery_payload(matrix: dict[str, float]) -> dict[str, float]:
    payload: dict[str, float] = {}
    for skill_id, topic in GAME_TOPIC_MAP.items():
        if skill_id not in matrix:
            continue
        column = MASTERY_COLUMNS.get(topic)
        if not column:
            continue
        try:
            payload[column] = clamp_pl(float(matrix[skill_id]))
        except (TypeError, ValueError):
            continue
    return payload


def _seen_mastery(student: dict, column: str) -> float | None:
    if not isinstance(student, dict) or column not in student or student.get(column) is None:
        return None
    try:
        return float(student[column])
    except (TypeError, ValueError):
        return None


def _write_mastery(student_id: str, payload: dict[str, float], student: dict) -> bool:
    """True when written; False on a conflict. Every other outcome raises.

    expected is this attempt's read of each column, compared exactly in SQL.
    PostgREST returns numeric columns as JSON numbers, and a float written by
    this API round-trips through that read unchanged.
    """
    completed = _official_module_ids(student)
    params = {
        "p_student": student_id,
        "p_mastery": payload,
        "p_expected": {column: _seen_mastery(student, column) for column in payload},
        "p_incomplete_modules": [module_id for module_id in SKILL_MODULES.values() if module_id not in completed],
    }
    try:
        response = supabase.rpc("levelblue_write_mastery", params).execute()
    except Exception as exc:
        if is_lock_timeout(exc):
            logger.warning("progress sync: mastery write lock timeout student_id=%s", student_id)
            log_operational_event(
                "sync-failure",
                "Progress sync waited too long for the student record; the phone keeps it pending.",
                "mastery-lock-timeout",
                "/api/progress/sync",
                status.HTTP_503_SERVICE_UNAVAILABLE,
            )
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=SYNC_BUSY_DETAIL) from exc
        logger.error("progress sync: mastery write failed student_id=%s", student_id)
        raise _supabase_error(exc, "levelblue_write_mastery") from exc
    outcome = _rpc_status(response)
    if outcome == "ok":
        return True
    if outcome == "conflict":
        return False
    if outcome == "restricted":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This student account is inactive")
    if outcome == "not_found":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    raise _supabase_error(RuntimeError("levelblue_write_mastery returned an unexpected result"), "levelblue_write_mastery")


def _rpc_status(response: object) -> str:
    data = getattr(response, "data", None)
    if isinstance(data, list) and len(data) == 1:
        data = data[0]
    if isinstance(data, dict):
        return str(data.get("status") or "")
    return ""

def _preserve_graded_mastery(matrix: dict[str, float], baseline: dict, fresh: dict) -> dict[str, float]:
    """Keep the column written by a pretest that completed after this attempt's read."""
    gained = _official_module_ids(fresh) - _official_module_ids(baseline)
    return _retain_official_pretest_mastery(matrix, fresh, gained)


SKILL_MODULES = {
    "phishing": "mod_01",
    "smishing": "mod_02",
    "vishing": "mod_03",
    "pretexting": "mod_04",
    "baiting": "mod_05",
}
MODULE_SKILLS = {module_id: skill_id for skill_id, module_id in SKILL_MODULES.items()}


def _official_module_ids(student: dict | None) -> set[str]:
    """Modules whose completion column is present and true.

    A legacy row with no column has no official flag for this guard to read.
    """
    if not isinstance(student, dict) or "module_pretests" not in student:
        return set()
    return set(parse_module_pretests(student.get("module_pretests")))


def _retain_official_pretest_mastery(
    matrix: dict[str, float],
    student: dict,
    gained: set[str],
) -> dict[str, float]:
    """Keep the graded posterior for a pretest that committed during this sync."""
    if not gained:
        return matrix
    retained = dict(matrix)
    for module_id in gained:
        skill_id = MODULE_SKILLS.get(module_id)
        if skill_id is None:
            continue
        topic = GAME_TOPIC_MAP.get(skill_id)
        column = MASTERY_COLUMNS.get(topic) if topic else None
        raw = student.get(column) if column else None
        try:
            number = float(raw)
        except (TypeError, ValueError):
            retained.pop(skill_id, None)
            continue
        if number <= 0:
            retained.pop(skill_id, None)
            continue
        retained[skill_id] = clamp_pl(number)
    return retained


def _assessed_skills(payload: dict) -> set[str]:
    """Skills with a pretest, lesson, practice, checkpoint, or graded answer."""
    assessed: set[str] = set()
    evidence = payload.get("learning_evidence") or {}
    topics = evidence.get("topics") if isinstance(evidence, dict) else {}
    if isinstance(topics, dict):
        for skill, count in topics.items():
            try:
                if int(count or 0) > 0:
                    assessed.add(str(skill).strip().lower())
            except (TypeError, ValueError):
                continue
    baselines = payload.get("pretest_baselines") or {}
    if isinstance(baselines, dict):
        for module_id, baseline in baselines.items():
            if _valid_pretest_baseline(baseline) is not None:
                assessed.update(_skills_for_module(str(module_id)))
    scores = payload.get("lesson_post_quiz_scores") or {}
    if isinstance(scores, dict):
        for module_id, score in scores.items():
            try:
                if int(score or 0) > 0:
                    assessed.update(_skills_for_module(str(module_id)))
            except (TypeError, ValueError):
                continue
    quizzes = payload.get("lesson_quiz_responses") or {}
    if isinstance(quizzes, dict):
        for module_id, responses in quizzes.items():
            if isinstance(responses, dict) and responses:
                assessed.update(_skills_for_module(str(module_id)))
    practice = payload.get("practice_responses") or {}
    if isinstance(practice, dict):
        for record in practice.values():
            if not isinstance(record, dict):
                continue
            skill = str(record.get("skill", "")).strip().lower()
            if skill:
                assessed.add(skill)
            assessed.update(_skills_for_module(str(record.get("module_id", ""))))
    logged = payload.get("unconfirmed_bkt_log") or []
    if isinstance(logged, list):
        for step in logged:
            if isinstance(step, dict):
                skill = str(step.get("skill", "")).strip().lower()
                if skill:
                    assessed.add(skill)
    return assessed


def _skills_for_module(module_id: str) -> set[str]:
    return {skill for skill, module in SKILL_MODULES.items() if module == module_id}


def _is_unassessed_prior(skill_id: str, value: float, assessed: set[str]) -> bool:
    return abs(value - P_L0) <= 1e-4 and skill_id not in assessed


def _merge_uploaded_mastery(
    incoming: dict,
    existing: dict,
    payload: dict,
    stored: dict | None = None,
) -> dict[str, float]:
    """Keep assessed cloud posteriors, including a real 0.10.

    Incoming and stored evidence are judged separately. Stored evidence can
    keep a stored 0.10, but it cannot make an incoming 0.10 count as a new
    assessment. A 0.10 with no evidence on its own copy is only the initial
    prior: it is left out of the saved matrix and is not upserted. This does
    not delete a bkt_records row written earlier.
    """
    incoming_assessed = _assessed_skills(payload if isinstance(payload, dict) else {})
    stored_assessed = _assessed_skills(stored if isinstance(stored, dict) else {})
    merged: dict[str, float] = {}
    if isinstance(existing, dict):
        for skill, value in existing.items():
            try:
                number = clamp_pl(float(value))
            except (TypeError, ValueError):
                continue
            skill_id = str(skill).strip().lower()
            if _is_unassessed_prior(skill_id, number, stored_assessed):
                continue
            merged[skill_id] = number
    if not isinstance(incoming, dict):
        return merged
    for skill, value in incoming.items():
        try:
            number = clamp_pl(float(value))
        except (TypeError, ValueError):
            continue
        skill_id = str(skill).strip().lower()
        if _is_unassessed_prior(skill_id, number, incoming_assessed):
            continue
        merged[skill_id] = number
    return merged


def _skills_retained_from_store(
    merged: dict[str, float],
    incoming: dict,
    incoming_assessed: set[str],
) -> set[str]:
    """Skills whose saved posterior came from the cloud, not this upload."""
    retained: set[str] = set()
    incoming_values = incoming if isinstance(incoming, dict) else {}
    for skill in merged:
        if skill not in incoming_values:
            retained.add(skill)
            continue
        try:
            number = clamp_pl(float(incoming_values[skill]))
        except (TypeError, ValueError):
            retained.add(skill)
            continue
        if _is_unassessed_prior(skill, number, incoming_assessed):
            retained.add(skill)
    return retained


def _merge_educational_history(blob: dict, stored: dict | None, provided: set[str]) -> None:
    """Keep stored lesson history across a sparse or partial upload.

    ``lesson_progress`` and ``completed_lessons`` have empty schema defaults,
    so a dump cannot tell an omitted field from one the client set to empty.
    ``provided`` is the request's ``model_fields_set`` and records that
    difference. No sync field is a reset: an omitted collection and an
    explicit empty collection both contribute no new history.     A supplied
    value merges forward — higher lesson count, union of completed modules,
    best checkpoint, the stored answer when that id already exists, and the
    higher topic count. Pretest baselines follow the same once-only rule:
    the stored baseline for a module stays, and a new official module is
    added once. Counts are not added together. Acknowledged BKT steps are
    left untouched so a later reconcile cannot replay them.
    """
    saved = stored if isinstance(stored, dict) else {}
    _merge_lesson_progress(blob, saved, provided)
    _merge_completed_lessons(blob, saved, provided)
    _merge_quiz_responses(blob, saved, provided)
    _merge_checkpoint_scores(blob, saved, provided)
    _merge_practice_responses(blob, saved, provided)
    _merge_pretest_baselines(blob, saved, provided)
    _merge_learning_evidence(blob, saved, provided)


def _incoming_mapping(blob: dict, field: str, provided: set[str]) -> dict:
    """Return new records for a field. Omitted and empty both mean none."""
    if field not in provided:
        return {}
    value = blob.get(field)
    return value if isinstance(value, dict) else {}


def _incoming_strings(blob: dict, field: str, provided: set[str]) -> list:
    if field not in provided:
        return []
    value = blob.get(field)
    return value if isinstance(value, list) else []


def _merge_lesson_progress(blob: dict, stored: dict, provided: set[str]) -> None:
    merged: dict[str, int] = {}
    sources = (
        stored.get("lesson_progress") if isinstance(stored.get("lesson_progress"), dict) else {},
        _incoming_mapping(blob, "lesson_progress", provided),
    )
    for source in sources:
        for module_id, count in source.items():
            number = _evidence_int(count)
            module = str(module_id).strip()
            if number is None or number <= 0 or not module:
                continue
            merged[module] = max(merged.get(module, 0), min(number, 1000000))
    blob["lesson_progress"] = merged


def _merge_completed_lessons(blob: dict, stored: dict, provided: set[str]) -> None:
    merged: list[str] = []
    seen: set[str] = set()
    stored_lessons = stored.get("completed_lessons") if isinstance(stored.get("completed_lessons"), list) else []
    for source in (stored_lessons, _incoming_strings(blob, "completed_lessons", provided)):
        for item in source:
            lesson_id = str(item).strip()
            if not lesson_id or lesson_id in seen:
                continue
            seen.add(lesson_id)
            merged.append(lesson_id)
    blob["completed_lessons"] = merged


def _merge_quiz_responses(blob: dict, stored: dict, provided: set[str]) -> None:
    stored_quizzes = stored.get("lesson_quiz_responses") if isinstance(stored.get("lesson_quiz_responses"), dict) else {}
    incoming = _incoming_mapping(blob, "lesson_quiz_responses", provided)
    merged: dict[str, dict] = {}
    module_ids = [str(module) for module in stored_quizzes]
    for module in incoming:
        if str(module) not in module_ids:
            module_ids.append(str(module))
    for module in module_ids:
        if not module:
            continue
        combined: dict[str, bool] = {}
        for source in (stored_quizzes.get(module), incoming.get(module)):
            if not isinstance(source, dict):
                continue
            for question_id, correct in source.items():
                key = str(question_id).strip()
                if not key or key in combined or not isinstance(correct, bool):
                    continue
                combined[key] = correct
        if combined:
            merged[module] = combined
    if merged or "lesson_quiz_responses" in provided:
        blob["lesson_quiz_responses"] = merged


def _merge_checkpoint_scores(blob: dict, stored: dict, provided: set[str]) -> None:
    stored_scores = stored.get("lesson_post_quiz_scores") if isinstance(stored.get("lesson_post_quiz_scores"), dict) else {}
    incoming = _incoming_mapping(blob, "lesson_post_quiz_scores", provided)
    merged: dict[str, int] = {}
    for source in (stored_scores, incoming):
        for module_id, score in source.items():
            number = _evidence_int(score)
            module = str(module_id).strip()
            if number is None or number <= 0 or not module:
                continue
            merged[module] = max(merged.get(module, 0), number)
    if merged or "lesson_post_quiz_scores" in provided:
        blob["lesson_post_quiz_scores"] = merged


def _merge_practice_responses(blob: dict, stored: dict, provided: set[str]) -> None:
    stored_practice = stored.get("practice_responses") if isinstance(stored.get("practice_responses"), dict) else {}
    incoming = _incoming_mapping(blob, "practice_responses", provided)
    merged: dict[str, dict] = {}
    for question_id, record in stored_practice.items():
        key = str(question_id).strip()
        if key and isinstance(record, dict):
            merged[key] = dict(record)
    for question_id, record in incoming.items():
        key = str(question_id).strip()
        if not key or key in merged or not isinstance(record, dict):
            continue
        merged[key] = dict(record)
    if merged or "practice_responses" in provided:
        blob["practice_responses"] = merged


def _valid_pretest_baseline(value: object) -> dict | None:
    """Return the stored correct/total pair, or None when it is not a baseline."""
    if not isinstance(value, dict):
        return None
    correct_raw = _finite_number(value.get("correct"))
    total_raw = _finite_number(value.get("total"))
    correct = _evidence_int(value.get("correct"))
    total = _evidence_int(value.get("total"))
    if correct_raw is None or total_raw is None or correct is None or total is None:
        return None
    if correct_raw != correct or total_raw != total:
        return None
    if total <= 0 or total > 100 or correct < 0 or correct > total:
        return None
    return {"correct": correct, "total": total}


def _merge_pretest_baselines(blob: dict, stored: dict, provided: set[str]) -> None:
    """Keep one baseline per official module, whether or not its posterior changed."""
    stored_baselines = stored.get("pretest_baselines") if isinstance(stored.get("pretest_baselines"), dict) else {}
    incoming = _incoming_mapping(blob, "pretest_baselines", provided)
    merged: dict[str, dict] = {}
    official = set(SKILL_MODULES.values())
    for module_id, value in stored_baselines.items():
        module = str(module_id).strip()
        baseline = _valid_pretest_baseline(value)
        if module in official and baseline is not None:
            merged[module] = baseline
    for module_id, value in incoming.items():
        module = str(module_id).strip()
        if module not in official or module in merged:
            continue
        baseline = _valid_pretest_baseline(value)
        if baseline is not None:
            merged[module] = baseline
    if merged or "pretest_baselines" in provided:
        blob["pretest_baselines"] = merged


def _merge_learning_evidence(blob: dict, stored: dict, provided: set[str]) -> None:
    stored_evidence = stored.get("learning_evidence") if isinstance(stored.get("learning_evidence"), dict) else {}
    if "learning_evidence" not in provided:
        incoming: dict = {}
    else:
        raw = blob.get("learning_evidence")
        incoming = raw if isinstance(raw, dict) else {}
    topics: dict[str, int] = {}
    for source in (stored_evidence.get("topics"), incoming.get("topics")):
        if not isinstance(source, dict):
            continue
        for skill, count in source.items():
            number = _evidence_int(count)
            skill_id = str(skill).strip().lower()
            if number is None or number <= 0 or not skill_id:
                continue
            topics[skill_id] = max(topics.get(skill_id, 0), min(number, 1000000))
    if not topics:
        return
    merged: dict = {"topics": topics}
    for field in ("first_at", "last_at", "sessions"):
        if _valid_evidence_field(field, incoming.get(field)):
            merged[field] = incoming[field]
    _fill_evidence_metadata(merged, stored_evidence)
    _normalize_merged_evidence(merged, stored_evidence)
    blob["learning_evidence"] = merged


def _preserve_assessment_provenance(blob: dict, stored: dict | None, retained: set[str]) -> None:
    """Copy stored evidence for cloud mastery this upload did not reassess.

    Lesson answers, checkpoints, practice, topic counts, and pretest
    baselines are already merged for every skill. This copy fills any other
    retained record the merge left absent. It does not touch baselines, so a
    replaced posterior cannot drop one. Acknowledged BKT steps are not copied
    back into the save, so a later reconcile cannot apply them again.
    """
    if not retained or not isinstance(stored, dict):
        return
    _copy_topic_counts(blob, stored, retained)
    _copy_checkpoint_scores(blob, stored, retained)
    _copy_module_evidence(blob, stored, "lesson_quiz_responses", retained)
    _copy_practice_responses(blob, stored, retained)


_EVIDENCE_FIELDS = ("first_at", "last_at", "sessions", "responses")


def _finite_number(value: object) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    number = float(value)
    if number != number or number in (float("inf"), float("-inf")):
        return None
    return number


def _valid_evidence_field(field: str, value: object) -> bool:
    number = _finite_number(value)
    if number is None:
        return False
    if field in ("first_at", "last_at"):
        return _evidence_time(value, datetime.now(UTC)) is not None
    if field == "responses":
        return number > 0
    return number >= 0


def _evidence_time(value: object, now: datetime) -> int | None:
    """Epoch seconds of a plausible learning time; an implausible one is ignored, not repaired."""
    if _evidence_activity(value, now) is None:
        return None
    return _evidence_int(value)


def _fill_evidence_metadata(target: dict, stored_evidence: dict) -> None:
    """Fill loader fields the upload omitted. Never replace a valid value."""
    for field in _EVIDENCE_FIELDS:
        if _valid_evidence_field(field, target.get(field)):
            continue
        if _valid_evidence_field(field, stored_evidence.get(field)):
            target[field] = stored_evidence[field]


def _evidence_int(value: object) -> int | None:
    number = _finite_number(value)
    if number is None:
        return None
    return int(number)


def _normalize_merged_evidence(evidence: dict, stored_evidence: dict) -> None:
    """Match Godot's loader: earliest valid start, latest valid end, responses summed once."""
    now = datetime.now(UTC)
    first_values: list[int] = []
    last_values: list[int] = []
    for source in (evidence, stored_evidence):
        if not isinstance(source, dict):
            continue
        first = _evidence_time(source.get("first_at"), now)
        if first is not None:
            first_values.append(first)
        last = _evidence_time(source.get("last_at"), now)
        if last is not None:
            last_values.append(last)
    first_at = min(first_values) if first_values else None
    if first_at is None:
        evidence.pop("first_at", None)
    else:
        evidence["first_at"] = first_at
    last_at = max(last_values) if last_values else first_at
    if first_at is not None and last_at is not None and last_at < first_at:
        last_at = first_at
    if last_at is None:
        evidence.pop("last_at", None)
    else:
        evidence["last_at"] = last_at
    topics = evidence.get("topics")
    if not isinstance(topics, dict):
        return
    total = 0
    for skill in SKILL_MODULES:
        count = _evidence_int(topics.get(skill))
        if count is not None and count > 0:
            total += min(count, 1000000)
    if total <= 0:
        return
    evidence["responses"] = total
    sessions = _evidence_int(evidence.get("sessions"))
    if sessions is None or sessions < 1:
        sessions = 1
    evidence["sessions"] = min(sessions, total)


def _copy_topic_counts(blob: dict, stored: dict, retained: set[str]) -> None:
    stored_evidence = stored.get("learning_evidence")
    if not isinstance(stored_evidence, dict):
        return
    stored_topics = stored_evidence.get("topics")
    if not isinstance(stored_topics, dict):
        return
    kept: dict[str, int] = {}
    for skill, count in stored_topics.items():
        skill_id = str(skill).strip().lower()
        try:
            number = int(count or 0)
        except (TypeError, ValueError):
            continue
        if skill_id in retained and number > 0:
            kept[skill_id] = number
    if not kept:
        return
    current = blob.get("learning_evidence")
    if not isinstance(current, dict):
        current = {"topics": kept}
        _fill_evidence_metadata(current, stored_evidence)
        _normalize_merged_evidence(current, stored_evidence)
        blob["learning_evidence"] = current
        return
    topics = current.get("topics")
    if not isinstance(topics, dict):
        topics = {}
        current["topics"] = topics
    for skill_id, number in kept.items():
        topics.setdefault(skill_id, number)
    _fill_evidence_metadata(current, stored_evidence)
    _normalize_merged_evidence(current, stored_evidence)


def _copy_module_evidence(blob: dict, stored: dict, field: str, retained: set[str]) -> None:
    stored_values = stored.get(field)
    if not isinstance(stored_values, dict):
        return
    current = blob.get(field)
    if not isinstance(current, dict):
        current = {}
    for module_id, value in stored_values.items():
        module = str(module_id)
        if module in current or not isinstance(value, dict) or not value:
            continue
        if retained.intersection(_skills_for_module(module)):
            current[module] = value
    if current:
        blob[field] = current


def _copy_checkpoint_scores(blob: dict, stored: dict, retained: set[str]) -> None:
    stored_scores = stored.get("lesson_post_quiz_scores")
    if not isinstance(stored_scores, dict):
        return
    current = blob.get("lesson_post_quiz_scores")
    if not isinstance(current, dict):
        current = {}
    for module_id, score in stored_scores.items():
        module = str(module_id)
        if module in current:
            continue
        try:
            number = int(score or 0)
        except (TypeError, ValueError):
            continue
        if number > 0 and retained.intersection(_skills_for_module(module)):
            current[module] = number
    if current:
        blob["lesson_post_quiz_scores"] = current


def _copy_practice_responses(blob: dict, stored: dict, retained: set[str]) -> None:
    stored_practice = stored.get("practice_responses")
    if not isinstance(stored_practice, dict):
        return
    current = blob.get("practice_responses")
    if not isinstance(current, dict):
        current = {}
    for question_id, record in stored_practice.items():
        key = str(question_id)
        if key in current or not isinstance(record, dict):
            continue
        skill = str(record.get("skill", "")).strip().lower()
        module_skills = _skills_for_module(str(record.get("module_id", "")))
        if skill in retained or retained.intersection(module_skills):
            current[key] = record
    if current:
        blob["practice_responses"] = current


def _upsert_save_blob(
    student_id: str,
    payload: dict,
    existing: dict | None = None,
    student: dict | None = None,
) -> None:
    blob = dict(payload)
    # Client module_pretests cannot grant or revoke completion. A present
    # student column, including {}, is copied into the save. A legacy row
    # with no column key keeps the flags already stored in the save.
    if isinstance(student, dict) and "module_pretests" in student:
        blob["module_pretests"] = parse_module_pretests(student.get("module_pretests"))
    else:
        if existing is None:
            try:
                existing = fetch_student_progress(student_id) or {}
            except ProgressReadError as exc:
                raise _supabase_error(exc) from exc
        stored_flags = existing.get("module_pretests") if isinstance(existing, dict) else None
        if isinstance(stored_flags, (dict, list)):
            blob["module_pretests"] = stored_flags
        else:
            blob.pop("module_pretests", None)
    _required_write(
        student_id,
        "player_saves.upsert",
        lambda: supabase.table("player_saves")
        .upsert(
            {
                "student_id": student_id,
                "payload": blob,
                "updated_at": datetime.now(UTC).isoformat(),
            }
        )
        .execute(),
    )
