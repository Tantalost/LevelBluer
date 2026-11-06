from fastapi import APIRouter, Header, HTTPException, status

from app.schemas.bkt import BktStateResponse
from app.services.assess_service import fetch_bkt_state
from app.services.auth_service import verify_token
from app.services.database_diagnostics import log_operational_event

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


@router.post("/assess", include_in_schema=False)
def assess() -> None:
    """Retired: it wrote mastery outside the student-row lock. Progress sync records mastery."""
    log_operational_event(
        "api-error",
        "A client called the retired /api/bkt/assess endpoint.",
        "bkt-assess-retired",
        "/api/bkt/assess",
        status.HTTP_410_GONE,
    )
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="This endpoint has been retired. Progress sync records mastery.",
    )


@router.get("/state", response_model=BktStateResponse)
def state(authorization: str | None = Header(default=None)) -> BktStateResponse:
    return fetch_bkt_state(_student_id(authorization))
