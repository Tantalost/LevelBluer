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
    merged_matrix = _merge_uploaded_mastery(
        dumped.get("mastery_matrix") or {},
        stored_progress.get("mastery_matrix") or {},
        dumped,
    )
    dumped["mastery_matrix"] = merged_matrix
    _upsert_game_bkt(student_id, merged_matrix)
    blob = {k: v for k, v in dumped.items() if k not in ("student", "learning_events")}
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


def _merge_uploaded_mastery(incoming: dict, existing: dict, payload: dict) -> dict[str, float]:
    """Keep cloud skills the upload did not assess, including a real 0.10."""
    merged: dict[str, float] = {}
    if isinstance(existing, dict):
        for skill, value in existing.items():
            try:
                merged[str(skill).strip().lower()] = clamp_pl(float(value))
            except (TypeError, ValueError):
                continue
    assessed = _assessed_skills(payload if isinstance(payload, dict) else {})
    if not isinstance(incoming, dict):
        return merged
    for skill, value in incoming.items():
        try:
            number = clamp_pl(float(value))
        except (TypeError, ValueError):
            continue
        skill_id = str(skill).strip().lower()
        if _is_unassessed_prior(skill_id, number, assessed):
            continue
        merged[skill_id] = number
    return merged


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
