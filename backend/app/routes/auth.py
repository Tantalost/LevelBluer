from fastapi import APIRouter, Depends, Header, HTTPException, status

from app.schemas.auth import (
    ChangePasswordRequest,
    ChangePasswordResponse,
    LoginRequest,
    LoginResponse,
)
from app.services.auth_service import change_student_password, login_student, verify_token

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization token required",
        )
    return authorization.split(" ", 1)[1].strip()


@router.post("/login", response_model=LoginResponse, response_model_by_alias=True)
def login(payload: LoginRequest) -> LoginResponse:
    return login_student(payload.email, payload.password)


@router.post("/change-password", response_model=ChangePasswordResponse, response_model_by_alias=True)
def change_password(
    payload: ChangePasswordRequest,
    authorization: str | None = Header(default=None),
) -> ChangePasswordResponse:
    token = _extract_bearer_token(authorization)
    claims = verify_token(token)

    if claims.get("role") != "student":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only student accounts can use this endpoint",
        )

    change_student_password(str(claims["id"]), payload.newPassword)
    return ChangePasswordResponse()
