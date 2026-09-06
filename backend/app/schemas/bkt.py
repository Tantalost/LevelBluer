from pydantic import BaseModel, Field


class BktAssessRequest(BaseModel):
    skill_id: str = "phishing"
    is_correct: bool
    p_g: float | None = Field(default=None, ge=0.01, le=0.5)
    p_s: float | None = Field(default=None, ge=0.01, le=0.5)
    p_t: float | None = Field(default=None, ge=0.01, le=0.5)


class BktAssessResponse(BaseModel):
    ok: bool = True
    skill_id: str
    topic: str
    previous: float
    probability_known: float


class BktStateResponse(BaseModel):
    ok: bool = True
    mastery: dict[str, float] = Field(default_factory=dict)
    gameplay: dict[str, float] = Field(default_factory=dict)
