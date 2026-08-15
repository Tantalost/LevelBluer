from app.data.pretest_questions import PRETEST_QUESTIONS, public_question
from app.schemas.auth import MasteryPayload
from app.schemas.pretest import (
    PretestAnswerPayload,
    PretestQuestionsResponse,
    PretestQuestionPayload,
    PretestSubmitResponse,
)
from app.services.auth_service import _supabase_error
from app.services.bkt_service import (
    MASTERY_COLUMNS,
    TOPICS,
    average_pl,
    initial_pl,
    update_pl,
)
from app.supabase_client import supabase
from fastapi import HTTPException, status


def _fetch_student(student_id: str) -> dict:
    try:
        response = supabase.table("students").select("*").eq("id", student_id).execute()
    except Exception as exc:
        raise _supabase_error(exc) from exc
    rows = response.data or []
    if not rows:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )
    return rows[0]


def has_completed_pretest(row: dict) -> bool:
    return int(row.get("sessions") or 0) > 0


def list_pretest_questions(student_id: str) -> PretestQuestionsResponse:
    student = _fetch_student(student_id)
    return PretestQuestionsResponse(
        alreadyCompleted=has_completed_pretest(student),
        questions=[PretestQuestionPayload(**public_question(q)) for q in PRETEST_QUESTIONS],
    )


def _is_correct(question: dict, submitted: bool | int) -> bool:
    expected = question["answer"]
    if question["type"] == "true_false":
        return bool(submitted) is bool(expected)
    try:
        return int(submitted) == int(expected)
    except (TypeError, ValueError):
        return False


def submit_pretest(student_id: str, answers: list[PretestAnswerPayload]) -> PretestSubmitResponse:
    student = _fetch_student(student_id)
    if has_completed_pretest(student):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Pre-test already completed",
        )

    by_id = {q["id"]: q for q in PRETEST_QUESTIONS}
    submitted_ids = {item.id for item in answers}
    required_ids = set(by_id)
    if submitted_ids != required_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Submit an answer for every pre-test question",
        )

    mastery = {
        topic: initial_pl(float(student.get(column) or 0))
        for topic, column in MASTERY_COLUMNS.items()
    }

    correct_count = 0
    for item in answers:
        question = by_id[item.id]
        is_correct = _is_correct(question, item.answer)
        if is_correct:
            correct_count += 1
        topic = question["topic"]
        if topic in mastery:
            mastery[topic] = round(update_pl(mastery[topic], is_correct), 4)

    total = len(PRETEST_QUESTIONS)
    pre_score = int(round((correct_count / total) * 100)) if total else 0
    avg = average_pl(mastery)

    update_payload = {
        "pre": pre_score,
        "sessions": max(int(student.get("sessions") or 0), 1),
        "status": "At Risk" if avg < 0.40 else "On Track",
        "mastery_phishing": mastery["Phishing"],
        "mastery_smishing": mastery["Smishing"],
        "mastery_vishing": mastery["Vishing"],
        "mastery_pretexting": mastery["Pretexting"],
        "mastery_baiting": mastery["Baiting"],
    }

    try:
        response = (
            supabase.table("students")
            .update(update_payload)
            .eq("id", student_id)
            .execute()
        )
    except Exception as exc:
        raise _supabase_error(exc) from exc

    if getattr(response, "error", None):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save pre-test results",
        )

    _upsert_bkt_records(student_id, mastery)

    return PretestSubmitResponse(
        pre=pre_score,
        correctCount=correct_count,
        totalQuestions=total,
        averagePl=round(avg, 4),
        mastery=MasteryPayload(**mastery),
        preTestCompleted=True,
    )


def _upsert_bkt_records(student_id: str, mastery: dict[str, float]) -> None:
    rows = [
        {
            "student_id": student_id,
            "topic": topic,
            "probability_known": p_l,
        }
        for topic, p_l in mastery.items()
        if topic in TOPICS
    ]
    try:
        supabase.table("bkt_records").upsert(rows).execute()
    except Exception:
        # Table/constraint may not exist in every environment; student columns are source of truth.
        pass
