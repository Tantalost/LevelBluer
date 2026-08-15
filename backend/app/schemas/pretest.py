from pydantic import BaseModel, ConfigDict, Field

from app.schemas.auth import MasteryPayload


class PretestQuestionPayload(BaseModel):
    id: int
    topic: str
    type: str
    text: str
    options: list[str] | None = None


class PretestQuestionsResponse(BaseModel):
    questions: list[PretestQuestionPayload]
    alreadyCompleted: bool = False


class PretestAnswerPayload(BaseModel):
    id: int
    answer: bool | int


class PretestSubmitRequest(BaseModel):
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
