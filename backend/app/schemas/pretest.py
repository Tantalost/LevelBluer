from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, StringConstraints, field_validator

from app.schemas.auth import MasteryPayload


class PretestQuestionPayload(BaseModel):
    id: int
    topic: str
    type: str
    text: str
    options: list[str] | None = None


class PretestQuestionsResponse(BaseModel):
    model_config = ConfigDict(serialize_by_alias=True)

    questions: list[PretestQuestionPayload]
    alreadyCompleted: bool = False
    moduleId: str
    completedModuleIds: list[str] = Field(default_factory=list)


class PretestAnswerPayload(BaseModel):
    id: int
    answer: StrictBool | StrictInt | Annotated[str, StringConstraints(max_length=96)]

    @field_validator("answer", mode="before")
    @classmethod
    def restore_json_choice_index(cls, value):
        # Godot may round-trip an integer choice index as 2.0 in its offline queue.
        if type(value) is float and value.is_integer():
            return int(value)
        return value


class PretestSubmitRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    module_id: str = Field(min_length=1, alias="moduleId")
    answers: list[PretestAnswerPayload] = Field(min_length=1)


class PretestSubmitResponse(BaseModel):
    model_config = ConfigDict(serialize_by_alias=True)

    success: bool = True
    pre: int
    correctCount: int
    totalQuestions: int
    averagePl: float
    mastery: MasteryPayload
    preTestCompleted: bool = True
    moduleId: str
    completedModuleIds: list[str] = Field(default_factory=list)
