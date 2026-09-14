import logging
from datetime import UTC, datetime

from app.schemas.progress import ProgressSyncRequest, ProgressSyncResponse
from app.services.auth_service import _supabase_error, fetch_student_by_id
from app.services.bkt_service import MASTERY_COLUMNS, clamp_pl
from app.supabase_client import supabase

logger = logging.getLogger(__name__)

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

    _upsert_game_bkt(student_id, payload.mastery_matrix)
    blob = {k: v for k, v in dumped.items() if k != "student"}
    _upsert_save_blob(student_id, blob)
    return ProgressSyncResponse()


def fetch_student_progress(student_id: str) -> dict | None:
    """Return the stored Godot save blob, or None when no cloud row exists.

    Optional read: GET /api/progress/sync treats fetch failure the same as an
    empty cloud save so the client can keep using local JSON. This is not a
    required progress-sync write.
    """
    try:
        response = (
            supabase.table("player_saves")
            .select("payload")
            .eq("student_id", student_id)
            .limit(1)
            .execute()
        )
    except Exception:
        logger.exception("progress fetch failed student_id=%s", student_id)
        return None
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
        lambda: supabase.table("bkt_records").upsert(rows).execute(),
    )
    if not student_mastery:
        return
    _required_write(
        student_id,
        "students.mastery_update",
        lambda: supabase.table("students").update(student_mastery).eq("id", student_id).execute(),
    )


def _upsert_save_blob(student_id: str, payload: dict) -> None:
    blob = dict(payload)
    if "module_pretests" not in blob:
        # Optional read used only to preserve already-stored pretest flags.
        existing = fetch_student_progress(student_id) or {}
        if isinstance(existing.get("module_pretests"), (dict, list)):
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
