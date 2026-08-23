from datetime import UTC, datetime

from app.schemas.progress import ProgressSyncRequest, ProgressSyncResponse
from app.services.auth_service import _supabase_error, fetch_student_by_id
from app.supabase_client import supabase

# Pretest BKT lives on students.mastery_phishing / etc. Never write game skills there.
GAME_BKT_TOPICS = ("ports", "firewalls", "crypto")


def sync_student_progress(student_id: str, payload: ProgressSyncRequest) -> ProgressSyncResponse:
    student = fetch_student_by_id(student_id)
    current_stage = int(student.get("highest_unlocked_stage") or 1)
    incoming_stage = max(1, int(payload.mock_max_stage_cleared))
    update = {
        "last_active": datetime.now(UTC).isoformat(),
        "highest_unlocked_stage": max(current_stage, incoming_stage),
    }
    try:
        supabase.table("students").update(update).eq("id", student_id).execute()
    except Exception as exc:
        raise _supabase_error(exc) from exc

    _upsert_game_bkt(student_id, payload.mastery_matrix)
    _upsert_save_blob(student_id, payload.model_dump())
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
    rows = [
        {
            "student_id": student_id,
            "topic": topic,
            "probability_known": float(matrix[topic]),
        }
        for topic in GAME_BKT_TOPICS
        if topic in matrix
    ]
    if not rows:
        return
    try:
        supabase.table("bkt_records").upsert(rows).execute()
    except Exception:
        pass


def _upsert_save_blob(student_id: str, payload: dict) -> None:
    try:
        supabase.table("player_saves").upsert(
            {
                "student_id": student_id,
                "payload": payload,
                "updated_at": datetime.now(UTC).isoformat(),
            }
        ).execute()
    except Exception:
        pass
