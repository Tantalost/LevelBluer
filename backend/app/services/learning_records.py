"""Validated evidence from the authenticated mobile learner; no legacy backfill."""
from datetime import UTC, datetime, timedelta
from hashlib import sha256
import json
from typing import Literal
from uuid import UUID

from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from app.data.pretest_questions import questions_for_module
from app.schemas.pretest import PretestAnswerPayload
from app.services.pretest_grading import is_correct
from app.supabase_client import supabase

MODULES = {"mod_01": "Phishing", "mod_02": "Smishing", "mod_03": "Vishing", "mod_04": "Pretexting", "mod_05": "Baiting"}

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

    @model_validator(mode="after")
    def validate_evidence(self):
        if self.occurred_at.tzinfo is None or self.occurred_at > datetime.now(UTC) + timedelta(minutes=10):
            raise ValueError("A timezone-aware event time, not in the future, is required")
        if self.occurred_at.year < 2020:
            raise ValueError("Invalid event time")
        if self.kind == "stage" and (self.attempt_id is None or self.stage is None or self.outcome is None):
            raise ValueError("Stage events need an attempt, stage, and outcome")
        if self.kind == "mastery" and self.mastery is None:
            raise ValueError("Mastery observation is required")
        if self.kind == "posttest":
            expected = 25 if self.instrument == "lesson-checkpoint-v1" else 15
            if self.instrument is None or self.attempt_id is None or self.total != expected or self.answered != expected or self.correct is None or self.correct > expected:
                raise ValueError("Only fully answered assessments can record a score")
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
        elif self.kind == "pretest":
            bank = questions_for_module(self.module_id)
            answers = {a.id: a.answer for a in self.answers}
            correct = sum(is_correct(q, answers[q["id"]]) for q in bank)
            version = sha256(json.dumps(bank, sort_keys=True).encode()).hexdigest()[:16]
            data.update(source="server-graded", instrument="pretest-" + version, correct=correct, total=len(bank), score=100 * correct / len(bank), scale="percent", completed=True, comparison_key=None)
        else:
            # Equal percentages alone do not make different instruments comparable.
            data.update(attempt_id=str(self.attempt_id), instrument=self.instrument, correct=self.correct, total=self.total, score=100 * self.correct / self.total, scale="percent", completed=True, comparison_key=None)
        return {"event_id": str(self.event_id), "kind": self.kind, "module_id": self.module_id, "occurred_at": self.occurred_at.isoformat(), "data": data}


def record_learning_events(student_id: str, events: list[LearningEvent]) -> list[str]:
    if not events:
        return []
    try:
        response = supabase.rpc("levelblue_record_learning", {"p_student": student_id, "p_events": [event.record() for event in events]}).execute()
        if getattr(response, "error", None):
            raise RuntimeError("Learning records write failed")
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Learning records could not be saved. Apply the learning-records migration and retry; queued results remain on this device.") from exc
    return [str(event.event_id) for event in events]
