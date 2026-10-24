"""Validated evidence from the authenticated mobile learner; no legacy backfill."""
from datetime import UTC, datetime, timedelta
from hashlib import sha256
import json
import logging
from typing import Annotated, Literal
from uuid import UUID

from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, StrictBool, model_validator
from app.data.pretest_questions import questions_for_module
from app.schemas.pretest import PretestAnswerPayload
from app.services.pretest_grading import is_correct
from app.supabase_client import supabase

MODULES = {"mod_01": "Phishing", "mod_02": "Smishing", "mod_03": "Vishing", "mod_04": "Pretexting", "mod_05": "Baiting"}
logger = logging.getLogger(__name__)

def _log_operational_failure(exc: Exception) -> None:
    """Store a sanitized sync failure. Never include payloads, tokens, or student answers."""
    cause = exc.__cause__ or exc
    text = " ".join(str(part) for part in getattr(cause, "args", (cause,))).lower()
    if "already used with different content" in text or "duplicate key" in text:
        category, message = "duplicate-event", "A learning event id was already stored with different content."
    elif "invalid learning batch" in text:
        category, message = "invalid-event", "A learning event batch was rejected."
    else:
        category, message = "sync-failure", "Learning records could not be saved."
    try:
        supabase.rpc("levelblue_log_operational_event", {"p_category": category, "p_message": message, "p_code": category, "p_route": "/api/progress/sync", "p_status": 503}).execute()
    except Exception:
        logger.warning("Operational monitoring event was not stored")


class StageDetails(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    phase: str = Field(max_length=40)
    health: int = Field(ge=0, le=100000)
    answered: int | None = Field(default=None, ge=0, le=10000)
    correct: int | None = Field(default=None, ge=0, le=10000)
    waves_completed: int | None = Field(default=None, ge=0, le=1000)
    waves_total: int | None = Field(default=None, ge=0, le=1000)
    timed_out: bool = False
    missed_question_ids: list[Annotated[str, StringConstraints(min_length=1, max_length=96)]] = Field(default_factory=list, max_length=50)

    @model_validator(mode="after")
    def consistent_counts(self):
        if self.correct is not None and (self.answered is None or self.correct > self.answered):
            raise ValueError("Correct count cannot exceed answered count")
        if self.waves_completed is not None and (self.waves_total is None or self.waves_completed > self.waves_total):
            raise ValueError("Completed waves cannot exceed total waves")
        return self


class AssessmentResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    question_id: str = Field(min_length=1, max_length=512)
    prompt: str = Field(max_length=8000)
    options: list[Annotated[str, StringConstraints(max_length=2000)]] = Field(default_factory=list, max_length=50)
    selected_answer: str = Field(max_length=8000)
    correct_answer: str = Field(max_length=8000)
    correct: StrictBool


def pretest_response(question: dict, answer: bool | int | str) -> dict:
    options = question.get("options") or (["True", "False"] if question.get("type") == "true_false" else [])
    def label(value):
        if type(value) is bool:
            return "True" if value else "False"
        if type(value) is int and 0 <= value < len(options):
            return options[value]
        return str(value)
    return {"question_id": str(question["id"]), "prompt": question["text"], "options": options,
            "selected_answer": label(answer), "correct_answer": label(question["answer"]),
            "correct": is_correct(question, answer)}


class LearningEvent(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    event_id: UUID
    kind: Literal["pretest", "posttest", "stage", "mastery"]
    module_id: Literal["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"]
    occurred_at: datetime
    attempt_id: UUID | None = None
    stage: int | None = Field(default=None, ge=1, le=10)
    outcome: Literal["started", "cleared", "failed", "abandoned"] | None = None
    instrument: Literal["lesson-checkpoint-v1", "stage-exam-v1"] | None = None
    correct: int | None = Field(default=None, ge=0, le=100)
    answered: int | None = Field(default=None, ge=0, le=100)
    total: int | None = Field(default=None, ge=1, le=100)
    mastery: float | None = Field(default=None, ge=0, le=1)
    answers: list[PretestAnswerPayload] | None = Field(default=None, max_length=100)
    responses: list[AssessmentResponse] | None = Field(default=None, max_length=100)
    details: StageDetails | None = None

    @model_validator(mode="after")
    def validate_evidence(self):
        if self.occurred_at.tzinfo is None or self.occurred_at > datetime.now(UTC) + timedelta(minutes=10):
            raise ValueError("A timezone-aware event time, not in the future, is required")
        if self.occurred_at.year < 2020:
            raise ValueError("Invalid event time")
        if self.kind == "stage" and (self.attempt_id is None or self.stage is None or self.outcome is None):
            raise ValueError("Stage events need an attempt, stage, and outcome")
        if self.details is not None and (self.kind != "stage" or self.outcome == "started"):
            raise ValueError("Stage details require a terminal stage outcome")
        if self.kind == "mastery" and self.mastery is None:
            raise ValueError("Mastery observation is required")
        if self.responses is not None and self.kind != "posttest":
            raise ValueError("Response snapshots are only accepted for post-tests; pre-tests are server graded")
        if self.kind == "posttest":
            expected = 25 if self.instrument == "lesson-checkpoint-v1" else 15
            if self.instrument is None or self.attempt_id is None or self.total != expected or self.answered != expected or self.correct is None or self.correct > expected:
                raise ValueError("Only fully answered assessments can record a score")
            if self.responses is not None:
                if len(self.responses) != expected or sum(r.correct for r in self.responses) != self.correct:
                    raise ValueError("Response count and results must match the assessment score")
        if self.kind == "pretest":
            bank = questions_for_module(self.module_id)
            if not self.answers or len(self.answers) != len(bank) or {a.id for a in self.answers} != {q["id"] for q in bank}:
                raise ValueError("Every pre-test question must be answered exactly once")
        return self

    def record(self):
        data = {"topic": MODULES[self.module_id], "source": "mobile-reported"}
        if self.kind == "mastery":
            data["mastery"] = self.mastery
        elif self.kind == "stage":
            data.update(attempt_id=str(self.attempt_id), stage=self.stage, outcome=self.outcome)
            if self.details is not None:
                data["details"] = self.details.model_dump(exclude_none=True)
        elif self.kind == "pretest":
            bank = questions_for_module(self.module_id)
            answers = {a.id: a.answer for a in self.answers}
            correct = sum(is_correct(q, answers[q["id"]]) for q in bank)
            version = sha256(json.dumps(bank, sort_keys=True).encode()).hexdigest()[:16]
            data.update(response_version=1, responses=[pretest_response(q, answers[q["id"]]) for q in bank])
            data.update(source="server-graded", instrument="pretest-" + version, correct=correct, total=len(bank), score=100 * correct / len(bank), scale="percent", completed=True, comparison_key=None)
        else:
            # Equal percentages alone do not make different instruments comparable.
            data.update(attempt_id=str(self.attempt_id), instrument=self.instrument, correct=self.correct, total=self.total, score=100 * self.correct / self.total, scale="percent", completed=True, comparison_key=None)
            if self.responses is not None:
                data.update(response_version=1, responses=[r.model_dump() for r in self.responses])
        return {"event_id": str(self.event_id), "kind": self.kind, "module_id": self.module_id, "occurred_at": self.occurred_at.isoformat(), "data": data}


def record_learning_events(student_id: str, events: list[LearningEvent]) -> list[str]:
    if not events:
        return []
    try:
        response = supabase.rpc("levelblue_record_learning", {"p_student": student_id, "p_events": [event.record() for event in events]}).execute()
        if getattr(response, "error", None):
            raise RuntimeError("Learning records write failed")
    except Exception as exc:
        _log_operational_failure(exc)
        raise HTTPException(status_code=503, detail="Learning records could not be saved. Apply the learning-records migration and retry; queued results remain on this device.") from exc
    return [str(event.event_id) for event in events]
