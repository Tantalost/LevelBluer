from fastapi import APIRouter, Header, HTTPException, status

from app.schemas.bkt import BktAssessRequest, BktAssessResponse, BktStateResponse
from app.services.assess_service import assess_answer, fetch_bkt_state
from app.services.auth_service import verify_token

router = APIRouter(prefix="/api/bkt", tags=["bkt"])


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


@router.post("/assess", response_model=BktAssessResponse)
def assess(
    payload: BktAssessRequest,
    authorization: str | None = Header(default=None),
) -> BktAssessResponse:
    return assess_answer(_student_id(authorization), payload)


@router.get("/state", response_model=BktStateResponse)
def state(authorization: str | None = Header(default=None)) -> BktStateResponse:
    return fetch_bkt_state(_student_id(authorization))
