from fastapi import APIRouter, Header, HTTPException, status

from app.schemas.pretest import (
    PretestQuestionsResponse,
    PretestSubmitRequest,
    PretestSubmitResponse,
)
from app.services.auth_service import verify_token
from app.services.pretest_service import list_pretest_questions, submit_pretest

router = APIRouter(prefix="/api/pretest", tags=["pretest"])


def _student_id(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization token required",
        )
    claims = verify_token(authorization.split(" ", 1)[1].strip())
    if claims.get("role") != "student":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only student accounts can use this endpoint",
        )
    return str(claims["id"])


@router.get("/questions", response_model=PretestQuestionsResponse)
def get_questions(authorization: str | None = Header(default=None)) -> PretestQuestionsResponse:
    return list_pretest_questions(_student_id(authorization))


@router.post("/submit", response_model=PretestSubmitResponse, response_model_by_alias=True)
def submit(
    payload: PretestSubmitRequest,
    authorization: str | None = Header(default=None),
) -> PretestSubmitResponse:
    return submit_pretest(_student_id(authorization), payload.answers)
