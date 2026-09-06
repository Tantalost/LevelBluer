from app.schemas.bkt import BktAssessRequest, BktAssessResponse, BktStateResponse
from app.services.auth_service import _supabase_error, fetch_student_by_id
from app.services.bkt_service import (
    MASTERY_COLUMNS,
    P_G,
    P_S,
    P_T,
    TOPICS,
    gameplay_skill,
    initial_pl,
    official_topic,
    update_pl,
)
from app.supabase_client import supabase


def assess_answer(student_id: str, payload: BktAssessRequest) -> BktAssessResponse:
    topic = official_topic(payload.skill_id)
    previous = _load_topic_pl(student_id, topic)
    next_pl = update_pl(
        previous,
        payload.is_correct,
        p_t=payload.p_t if payload.p_t is not None else P_T,
        p_g=payload.p_g if payload.p_g is not None else P_G,
        p_s=payload.p_s if payload.p_s is not None else P_S,
    )
    _persist_topic_pl(student_id, topic, next_pl)
    return BktAssessResponse(
        skill_id=gameplay_skill(topic),
        topic=topic,
        previous=round(previous, 4),
        probability_known=round(next_pl, 4),
    )


def fetch_bkt_state(student_id: str) -> BktStateResponse:
    mastery: dict[str, float] = {}
    student = fetch_student_by_id(student_id)
    for topic, column in MASTERY_COLUMNS.items():
        mastery[topic] = round(initial_pl(float(student.get(column) or 0)), 4)
    records = _fetch_bkt_rows(student_id)
    for topic, value in records.items():
        mastery[topic] = round(initial_pl(value), 4)
    gameplay = {gameplay_skill(topic): value for topic, value in mastery.items()}
    return BktStateResponse(mastery=mastery, gameplay=gameplay)


def _load_topic_pl(student_id: str, topic: str) -> float:
    records = _fetch_bkt_rows(student_id)
    if topic in records:
        return initial_pl(records[topic])
    student = fetch_student_by_id(student_id)
    column = MASTERY_COLUMNS.get(topic)
    if column:
        return initial_pl(float(student.get(column) or 0))
    return initial_pl(0.0)


def _fetch_bkt_rows(student_id: str) -> dict[str, float]:
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
        if not topic:
            continue
        found[topic] = float(row.get("probability_known") or 0)
    return found


def _persist_topic_pl(student_id: str, topic: str, probability_known: float) -> None:
    try:
        supabase.table("bkt_records").upsert(
            {
                "student_id": student_id,
                "topic": topic,
                "probability_known": probability_known,
            }
        ).execute()
    except Exception as exc:
        raise _supabase_error(exc) from exc
    column = MASTERY_COLUMNS.get(topic)
    if column is None or topic not in TOPICS:
        return
    try:
        supabase.table("students").update({column: probability_known}).eq("id", student_id).execute()
    except Exception as exc:
        raise _supabase_error(exc) from exc
