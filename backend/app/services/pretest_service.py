import logging

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
from app.services.auth_service import _supabase_error, ensure_student_access
from app.services.bkt_service import (
    MASTERY_COLUMNS,
    average_pl,
    gameplay_skill,
    initial_pl,
    update_pl_diagnostic,
)
from app.services.database_diagnostics import is_lock_timeout, log_operational_event, safe_database_error
from app.supabase_client import supabase
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

PRETEST_RETRY_DETAIL = "Pre-test results could not be saved right now. Your answers are kept; try again."


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


def _save_payload(student_id: str, strict: bool = False) -> dict:
    """Legacy-schema pre-test flags live in player_saves.payload.

    strict: a failed read raises instead of looking like an empty save, so it can
    neither allow a second pre-test nor be written back over existing progress.
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
        if strict:
            raise _supabase_error(exc, "player_saves.read") from exc
        return {}
    if strict and getattr(response, "error", None):
        raise _supabase_error(RuntimeError("player_saves.read"), "player_saves.read")
    rows = response.data or []
    if not rows:
        return {}
    payload = rows[0].get("payload")
    if isinstance(payload, dict):
        return payload
    if strict and payload is not None:
        raise _supabase_error(RuntimeError("player_saves.payload is not an object"), "player_saves.read")
    return {}


def module_pretests_map(row: dict, student_id: str | None = None, strict: bool = False) -> dict[str, bool]:
    """Official flags. An empty column is authoritative; the save is only for a missing column."""
    if "module_pretests" in row:
        return parse_module_pretests(row.get("module_pretests"))
    sid = student_id or str(row.get("id") or "")
    if not sid:
        return {}
    return parse_module_pretests(_save_payload(sid, strict).get("module_pretests"))


def has_completed_module_pretest(row: dict, module_id: str, student_id: str | None = None) -> bool:
    return bool(module_pretests_map(row, student_id).get(module_id))


def completed_ids_for_student(row: dict, student_id: str | None = None) -> list[str]:
    return completed_module_ids(module_pretests_map(row, student_id))


def list_pretest_questions(student_id: str, module_id: str) -> PretestQuestionsResponse:
    bank = questions_for_module(module_id)
    if not bank:
        raise _unknown_module()
    student = _fetch_student(student_id)
    ensure_student_access(student)
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


def _finite_probability(value: object) -> float | None:
    """A usable posterior. Zero, missing, and non-numeric values are not evidence."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    number = float(value)
    if number != number or number <= 0.0 or number > 1.0:
        return None
    return number


def assessed_topic_status(
    student: dict,
    topic: str,
    posterior: object,
    evidence: dict | None = None,
) -> str | None:
    """Educational label for topics that have assessment evidence.

    Evidence is the same save-blob rule as progress sync: graded topic
    counts, pre-test baselines, lesson quizzes, checkpoint scores, practice,
    and offline BKT steps. A mastery column or bkt_records row is not proof.
    The pretest being submitted counts for its own topic before that evidence
    is written. A 0.10 with that evidence stays in the average. A 0.10
    without it is only the starting prior. The cut stays 0.40. No usable
    evidenced posterior means no label is invented. The result is returned to
    callers and is not written to students.status.
    """
    from app.services.progress_service import _assessed_skills

    payload = evidence if isinstance(evidence, dict) else {}
    evidenced = _assessed_skills(payload)
    assessed: dict[str, float] = {}
    current = _finite_probability(posterior)
    if current is not None:
        assessed[topic] = current
    for name, column in MASTERY_COLUMNS.items():
        if name == topic or gameplay_skill(name) not in evidenced:
            continue
        stored = _finite_probability(student.get(column))
        if stored is not None:
            assessed[name] = stored
    if not assessed:
        return None
    average = average_pl(assessed)
    return "At Risk" if average < 0.40 else "On Track"


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
    ensure_student_access(student)
    # The column is authoritative whenever the row includes it, including {}.
    # A save-blob flag cannot block or invent completion on that schema.
    # The blob is consulted only for a legacy row that has no column key.
    column_present = "module_pretests" in student
    stored_progress: dict = {}
    if column_present:
        completed = parse_module_pretests(student.get("module_pretests"))
    else:
        stored_progress = _save_payload(student_id, strict=True)
        completed = parse_module_pretests(stored_progress.get("module_pretests"))
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
    # Status needs the save after the retry check. A failed read aborts
    # before any write; it is not an empty evidence record. No rows still is.
    if column_present:
        stored_progress = _save_payload(student_id, strict=True)

    correct_count = 0
    for item in answers:
        if _is_correct(by_id[item.id], item.answer):
            correct_count += 1
    total = len(bank)
    pre_score = int(round((correct_count / total) * 100)) if total else 0

    # A practice sync can commit between the read above and the write. The write
    # then reports prior_changed, and the same answers are graded once more from
    # the committed prior. The diagnostic itself is unchanged.
    for attempt in range(2):
        mastery = _grade_diagnostic(student, topic, answers, by_id)
        outcome = _record_pretest_result(
            student_id,
            module_id,
            mastery[topic],
            pre_score if module_id == MODULE_1_ID else None,
            student.get(MASTERY_COLUMNS[topic]),
        )
        result = outcome.get("status")
        if result == "ok":
            break
        if result == "already_completed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Pre-test already completed",
            )
        if result != "prior_changed":
            raise _supabase_error(RuntimeError("levelblue_record_pretest_result returned an unexpected result"))
        if attempt == 1:
            logger.warning("pretest: prior changed twice student_id=%s module=%s", student_id, module_id)
            _log_pretest_write_failure(status.HTTP_503_SERVICE_UNAVAILABLE)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=PRETEST_RETRY_DETAIL,
            )
        student = _fetch_student(student_id)
        ensure_student_access(student)

    completed_ids = completed_module_ids({str(module): True for module in outcome.get("completed_modules") or []})
    # averagePl stays the five-topic response figure, including unassessed
    # priors used to start the diagnostic. At Risk / On Track stays a
    # calculated label. It is not stored in the administrative status column.
    avg = average_pl(mastery)
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



def _grade_diagnostic(student: dict, topic: str, answers: list[PretestAnswerPayload], by_id: dict) -> dict[str, float]:
    mastery = {
        name: initial_pl(float(student.get(column) or 0))
        for name, column in MASTERY_COLUMNS.items()
    }
    for item in answers:
        question = by_id[item.id]
        if question["topic"] == topic:
            mastery[topic] = round(update_pl_diagnostic(mastery[topic], _is_correct(question, item.answer)), 4)
    return mastery


def _record_pretest_result(
    student_id: str,
    module_id: str,
    probability: float,
    pre_score: int | None,
    expected_prior: object,
) -> dict:
    """Completion flag, mastery column, Module 1 score and BKT row in one transaction."""
    params = {
        "p_student": student_id,
        "p_module": module_id,
        "p_mastery": probability,
        "p_pre": pre_score,
        "p_expected_prior": expected_prior,
    }
    try:
        response = supabase.rpc("levelblue_record_pretest_result", params).execute()
    except Exception as exc:
        if is_lock_timeout(exc):
            logger.warning("pretest: result write lock timeout student_id=%s", student_id)
            log_operational_event(
                "sync-failure",
                "Pre-test result waited too long for the student record; the phone keeps the answers pending.",
                "mastery-lock-timeout",
                "/api/pretest/submit",
                status.HTTP_503_SERVICE_UNAVAILABLE,
            )
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=PRETEST_RETRY_DETAIL) from exc
        error = _supabase_error(exc, "levelblue_record_pretest_result")
        _log_pretest_write_failure(error.status_code)
        raise error from exc
    data = getattr(response, "data", None)
    if isinstance(data, list) and len(data) == 1:
        data = data[0]
    if not isinstance(data, dict):
        raise _supabase_error(RuntimeError("levelblue_record_pretest_result returned no result"))
    if data.get("status") == "restricted":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This student account is inactive")
    if data.get("status") == "not_found":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    return data


def _log_pretest_write_failure(http_status: int) -> None:
    log_operational_event(
        "sync-failure",
        "An official pre-test result was not saved; the phone keeps the answers pending.",
        "pretest-write-failed",
        "/api/pretest/submit",
        http_status,
    )
