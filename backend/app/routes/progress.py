from fastapi import APIRouter, Header, HTTPException, status
from fastapi.responses import JSONResponse

from app.schemas.progress import ProgressSyncRequest, ProgressSyncResponse
from app.services.auth_service import verify_token
from app.services.progress_service import fetch_student_progress, sync_student_progress

router = APIRouter(prefix="/api/progress", tags=["progress"])


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


@router.post("/sync", response_model=ProgressSyncResponse)
def sync_progress(
    payload: ProgressSyncRequest,
    authorization: str | None = Header(default=None),
) -> ProgressSyncResponse:
    return sync_student_progress(_student_id(authorization), payload)


@router.get("/sync")
def get_progress(authorization: str | None = Header(default=None)) -> JSONResponse:
    payload = fetch_student_progress(_student_id(authorization))
    if payload is None:
        return JSONResponse(content=None)
    return JSONResponse(content=payload)
