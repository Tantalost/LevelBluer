from pydantic import BaseModel, Field


class BktStateResponse(BaseModel):
    ok: bool = True
    mastery: dict[str, float] = Field(default_factory=dict)
    gameplay: dict[str, float] = Field(default_factory=dict)
