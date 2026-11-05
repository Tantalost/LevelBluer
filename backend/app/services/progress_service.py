import logging
from datetime import UTC, datetime

from app.schemas.progress import ProgressSyncRequest, ProgressSyncResponse
from app.services.auth_service import _supabase_error, fetch_student_by_id
from app.services.bkt_service import MASTERY_COLUMNS, P_L0, clamp_pl
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


def sync_student_progress(student_id: str, payload: ProgressSyncRequest) -> ProgressSyncResponse:
    student = fetch_student_by_id(student_id)
    if str(student.get("status", "")).lower() in ("inactive", "archived"):
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="This student account is inactive")
    acknowledged = record_learning_events(student_id, payload.learning_events)
    current_stage = int(student.get("highest_unlocked_stage") or 1)
    incoming_stage = max(1, int(payload.mock_max_stage_cleared))
    dumped = payload.model_dump()
    update = {
        "last_active": datetime.now(UTC).isoformat(),
        "highest_unlocked_stage": max(current_stage, incoming_stage),
    }
    student_patch = dumped.get("student")
    if isinstance(student_patch, dict):
        for key in STUDENT_SYNC_KEYS:
            if key not in student_patch or student_patch[key] is None:
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
    dumped["mastery_matrix"] = merged_matrix
    _upsert_game_bkt(student_id, merged_matrix)
    blob = {k: v for k, v in dumped.items() if k not in ("student", "learning_events")}
    _preserve_assessment_provenance(
        blob,
        stored_progress,
        _skills_retained_from_store(merged_matrix, incoming_matrix, incoming_assessed),
    )
    _upsert_save_blob(student_id, blob, stored_progress)
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


def _upsert_game_bkt(student_id: str, matrix: dict[str, float]) -> None:
    rows = []
    student_mastery: dict[str, float] = {}
    for skill_id, topic in GAME_TOPIC_MAP.items():
        if skill_id not in matrix:
            continue
        probability_known = clamp_pl(float(matrix[skill_id]))
        rows.append(
            {
                "student_id": student_id,
                "topic": topic,
                "probability_known": probability_known,
            }
        )
        column = MASTERY_COLUMNS.get(topic)
        if column:
            student_mastery[column] = probability_known
    if not rows:
        return
    _required_write(
        student_id,
        "bkt_records.upsert",
        lambda: supabase.table("bkt_records").upsert(rows, on_conflict="student_id,topic").execute(),
    )
    if not student_mastery:
        return
    _required_write(
        student_id,
        "students.mastery_update",
        lambda: supabase.table("students").update(student_mastery).eq("id", student_id).execute(),
    )


SKILL_MODULES = {
    "phishing": "mod_01",
    "smishing": "mod_02",
    "vishing": "mod_03",
    "pretexting": "mod_04",
    "baiting": "mod_05",
}


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
            if isinstance(baseline, dict) and baseline:
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


def _preserve_assessment_provenance(blob: dict, stored: dict | None, retained: set[str]) -> None:
    """Copy stored evidence for cloud mastery this upload did not reassess.

    Only evidence already stored is copied, and only into keys the upload
    omitted. Acknowledged BKT steps are not copied back into the save, so a
    later reconcile cannot apply them again.
    """
    if not retained or not isinstance(stored, dict):
        return
    _copy_topic_counts(blob, stored, retained)
    _copy_module_evidence(blob, stored, "pretest_baselines", retained)
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
    if field in ("first_at", "responses"):
        return number > 0
    return number >= 0


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
    """Match Godot's loader: earliest start, latest end, responses summed once."""
    first_values: list[int] = []
    last_values: list[int] = []
    for source in (evidence, stored_evidence):
        if not isinstance(source, dict):
            continue
        first = _evidence_int(source.get("first_at"))
        if first is not None and first > 0:
            first_values.append(first)
        if "last_at" in source:
            last = _evidence_int(source.get("last_at"))
            if last is not None and last >= 0:
                last_values.append(last)
    first_at = min(first_values) if first_values else None
    if first_at is not None:
        evidence["first_at"] = first_at
    if last_values or first_at is not None:
        last_at = max(last_values) if last_values else first_at
        if first_at is not None and last_at is not None and last_at < first_at:
            last_at = first_at
        if last_at is not None:
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


def _upsert_save_blob(student_id: str, payload: dict, existing: dict | None = None) -> None:
    blob = dict(payload)
    if "module_pretests" not in blob:
        # Optional read used only to preserve already-stored pretest flags.
        if existing is None:
            try:
                existing = fetch_student_progress(student_id) or {}
            except ProgressReadError as exc:
                # Do not replace the stored blob when its pretest flags could not be read.
                raise _supabase_error(exc) from exc
        if isinstance(existing, dict) and isinstance(existing.get("module_pretests"), (dict, list)):
            blob["module_pretests"] = existing["module_pretests"]
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
