from datetime import UTC, datetime

from app.schemas.progress import ProgressSyncRequest, ProgressSyncResponse
from app.services.auth_service import _supabase_error, fetch_student_by_id
from app.supabase_client import supabase

# Official P(L) is written by pretest + /api/bkt/assess, not by the Godot save blob.
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

    try:
        supabase.table("students").update(update).eq("id", student_id).execute()
    except Exception as exc:
        raise _supabase_error(exc) from exc

    _upsert_game_bkt(student_id, payload.mastery_matrix)
    blob = {k: v for k, v in dumped.items() if k != "student"}
    _upsert_save_blob(student_id, blob)
    return ProgressSyncResponse()


def fetch_student_progress(student_id: str) -> dict | None:
    """Return the stored Godot save blob, or None when no cloud row exists."""
    try:
        response = (
            supabase.table("player_saves")
            .select("payload")
            .eq("student_id", student_id)
            .limit(1)
            .execute()
        )
    except Exception:
        return None
    rows = response.data or []
    if not rows:
        return None
    payload = rows[0].get("payload")
    return payload if isinstance(payload, dict) else None


def _upsert_game_bkt(student_id: str, matrix: dict[str, float]) -> None:
    rows = []
    for skill_id, topic in GAME_TOPIC_MAP.items():
        if skill_id not in matrix:
            continue
        rows.append(
            {
                "student_id": student_id,
                "topic": topic,
                "probability_known": float(matrix[skill_id]),
            }
        )
    if not rows:
        return
    try:
        supabase.table("bkt_records").upsert(rows).execute()
    except Exception:
        pass


def _upsert_save_blob(student_id: str, payload: dict) -> None:
    blob = dict(payload)
    if "module_pretests" not in blob:
        existing = fetch_student_progress(student_id) or {}
        if isinstance(existing.get("module_pretests"), (dict, list)):
            blob["module_pretests"] = existing["module_pretests"]
    try:
        supabase.table("player_saves").upsert(
            {
                "student_id": student_id,
                "payload": blob,
                "updated_at": datetime.now(UTC).isoformat(),
            }
        ).execute()
    except Exception:
        pass
