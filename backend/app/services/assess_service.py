from app.schemas.bkt import BktStateResponse
from app.services.auth_service import ensure_student_access, fetch_student_by_id
from app.services.bkt_service import (
    MASTERY_COLUMNS,
    TOPICS,
    gameplay_skill,
    initial_pl,
)
from app.supabase_client import supabase


def fetch_bkt_state(student_id: str) -> BktStateResponse:
    """Stored mastery at full precision, so a value just under 0.40 or 0.70 keeps its band."""
    mastery: dict[str, float] = {}
    student = fetch_student_by_id(student_id)
    ensure_student_access(student)
    for topic, column in MASTERY_COLUMNS.items():
        mastery[topic] = initial_pl(float(student.get(column) or 0))
    records = _fetch_bkt_rows(student_id)
    for topic, value in records.items():
        mastery[topic] = initial_pl(value)
    gameplay = {gameplay_skill(topic): value for topic, value in mastery.items()}
    return BktStateResponse(mastery=mastery, gameplay=gameplay)


def _fetch_bkt_rows(student_id: str) -> dict[str, float]:
    """The five official topics only; any other stored topic is ignored."""
    try:
        response = (
            supabase.table("bkt_records")
            .select("topic, probability_known")
            .eq("student_id", student_id)
            .execute()
        )
    except Exception:
        return {}
    found: dict[str, float] = {}
    for row in response.data or []:
        topic = str(row.get("topic") or "")
        if topic not in TOPICS:
            continue
        found[topic] = float(row.get("probability_known") or 0)
    return found
