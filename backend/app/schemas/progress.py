from pydantic import BaseModel, ConfigDict, Field


class ProgressSyncRequest(BaseModel):
    """Godot `PlayerManager.get_save_data()` snapshot. Extra keys are stored, not rejected."""

    model_config = ConfigDict(extra="allow")

    mock_max_stage_cleared: int = 1
    mastery_matrix: dict[str, float] = Field(default_factory=dict)
    locked_stages: dict = Field(default_factory=dict)
    completed_lessons: list[str] = Field(default_factory=list)
    credits: int = 0
    unlocked_towers: list[str] = Field(default_factory=list)
    unlocked_skills: list[str] = Field(default_factory=list)
    lesson_progress: dict = Field(default_factory=dict)
    purchased_items: list[str] = Field(default_factory=list)


class ProgressSyncResponse(BaseModel):
    ok: bool = True
