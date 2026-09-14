from datetime import UTC, datetime

from app.data.pretest_questions import (
    MODULE_1_ID,
    completed_module_ids,
    parse_module_pretests,
    public_question,
    questions_for_module,
    topic_for_module,
)
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
    update_pl_diagnostic,
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


def _unknown_module() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Unknown module_id",
    )


def _is_missing_column(exc: Exception, column: str) -> bool:
    text = str(exc).lower()
    return column.lower() in text and (
        "column" in text or "schema cache" in text or "pgrst204" in text
    )


def _save_payload(student_id: str) -> dict:
    try:
        response = (
            supabase.table("player_saves")
            .select("payload")
            .eq("student_id", student_id)
            .limit(1)
            .execute()
        )
    except Exception:
        return {}
    rows = response.data or []
    if not rows:
        return {}
    payload = rows[0].get("payload")
    return payload if isinstance(payload, dict) else {}


def module_pretests_map(row: dict, student_id: str | None = None) -> dict[str, bool]:
    completed = parse_module_pretests(row.get("module_pretests"))
    if completed:
        return completed
    sid = student_id or str(row.get("id") or "")
    if not sid:
        return {}
    return parse_module_pretests(_save_payload(sid).get("module_pretests"))


def has_completed_module_pretest(row: dict, module_id: str, student_id: str | None = None) -> bool:
    return bool(module_pretests_map(row, student_id).get(module_id))


def completed_ids_for_student(row: dict, student_id: str | None = None) -> list[str]:
    return completed_module_ids(module_pretests_map(row, student_id))


def _write_save_module_pretests(student_id: str, completed: dict[str, bool]) -> None:
    payload = _save_payload(student_id)
    payload["module_pretests"] = completed
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


def list_pretest_questions(student_id: str, module_id: str) -> PretestQuestionsResponse:
    bank = questions_for_module(module_id)
    if not bank:
        raise _unknown_module()
    student = _fetch_student(student_id)
    completed = completed_ids_for_student(student, student_id)
    return PretestQuestionsResponse(
        alreadyCompleted=module_id in completed,
        moduleId=module_id,
        completedModuleIds=completed,
        questions=[PretestQuestionPayload(**public_question(q)) for q in bank],
    )


def _is_correct(question: dict, submitted: bool | int | str) -> bool:
    from app.services.pretest_grading import is_correct
    return is_correct(question, submitted)


def submit_pretest(
    student_id: str,
    module_id: str,
    answers: list[PretestAnswerPayload],
) -> PretestSubmitResponse:
    bank = questions_for_module(module_id)
    topic = topic_for_module(module_id)
    if not bank or not topic:
        raise _unknown_module()

    student = _fetch_student(student_id)
    completed = module_pretests_map(student, student_id)
    if completed.get(module_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Pre-test already completed",
        )

    by_id = {q["id"]: q for q in bank}
    submitted_ids = {item.id for item in answers}
    required_ids = set(by_id)
    if submitted_ids != required_ids or len(answers) != len(bank):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Submit an answer for every pre-test question",
        )

    mastery = {
        name: initial_pl(float(student.get(column) or 0))
        for name, column in MASTERY_COLUMNS.items()
    }

    correct_count = 0
    for item in answers:
        question = by_id[item.id]
        is_correct = _is_correct(question, item.answer)
        if is_correct:
            correct_count += 1
        item_topic = question["topic"]
        if item_topic == topic:
            mastery[topic] = round(update_pl_diagnostic(mastery[topic], is_correct), 4)

    total = len(bank)
    pre_score = int(round((correct_count / total) * 100)) if total else 0
    avg = average_pl(mastery)

    completed[module_id] = True
    completed_ids = completed_module_ids(completed)

    update_payload: dict = {
        "status": "At Risk" if avg < 0.40 else "On Track",
        MASTERY_COLUMNS[topic]: mastery[topic],
        "module_pretests": completed,
    }
    if module_id == MODULE_1_ID:
        update_payload["pre"] = pre_score

    wrote_column = True
    try:
        response = (
            supabase.table("students")
            .update(update_payload)
            .eq("id", student_id)
            .execute()
        )
    except Exception as exc:
        if not _is_missing_column(exc, "module_pretests"):
            raise _supabase_error(exc) from exc
        wrote_column = False
        fallback = {k: v for k, v in update_payload.items() if k != "module_pretests"}
        try:
            response = (
                supabase.table("students")
                .update(fallback)
                .eq("id", student_id)
                .execute()
            )
        except Exception as retry_exc:
            raise _supabase_error(retry_exc) from retry_exc

    if getattr(response, "error", None):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save pre-test results",
        )

    if not wrote_column:
        _write_save_module_pretests(student_id, completed)

    _upsert_bkt_records(student_id, {topic: mastery[topic]})

    stored_pre = pre_score if module_id == MODULE_1_ID else int(student.get("pre") or 0)
    return PretestSubmitResponse(
        pre=stored_pre,
        correctCount=correct_count,
        totalQuestions=total,
        averagePl=round(avg, 4),
        mastery=MasteryPayload(**mastery),
        preTestCompleted=True,
        moduleId=module_id,
        completedModuleIds=completed_ids,
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
    if not rows:
        return
    try:
        supabase.table("bkt_records").upsert(rows).execute()
    except Exception:
        # Table/constraint may not exist in every environment; student columns are source of truth.
        pass
