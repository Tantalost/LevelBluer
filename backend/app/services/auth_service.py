from datetime import UTC, datetime, timedelta

import re

import bcrypt
import httpx
import jwt
from fastapi import HTTPException, status

from app.config import settings
from app.schemas.auth import (
    BuildingLevelsPayload,
    LoginResponse,
    MasteryPayload,
    StudentUserPayload,
)
from app.supabase_client import supabase

JWT_ALGORITHM = "HS256"
JWT_EXPIRY_DAYS = 365


def _supabase_error(exc: Exception) -> HTTPException:
    if isinstance(exc, httpx.ConnectError):
        return HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to reach database. Check your network connection.",
        )
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Database request failed",
    )


def _map_student(row: dict) -> StudentUserPayload:
    name = row.get("name") or " ".join(
        part for part in [row.get("first_name"), row.get("last_name")] if part
    ).strip()

    return StudentUserPayload(
        id=str(row["id"]),
        name=name or row.get("email", "Student"),
        email=row["email"],
        section=row.get("section"),
        status=row.get("status") or "Needs Review",
        technical=bool(row.get("technical")),
        pre=int(row.get("pre") or 0),
        post=int(row.get("post") or 0),
        sessions=int(row.get("sessions") or 0),
        points=int(row.get("points") or 0),
        threatPoints=int(row.get("threat_points") or 0),
        materials=int(row.get("upgrade_materials") or 0),
        highestUnlockedStage=int(row.get("highest_unlocked_stage") or 1),
        buildingLevels=BuildingLevelsPayload(
            tower=int(row.get("tower_level") or 1),
            glade=int(row.get("glade_level") or 1),
            forge=int(row.get("forge_level") or 1),
        ),
        interventionStatus=row.get("intervention_status") or "NORMAL",
        mastery=MasteryPayload(
            Phishing=float(row.get("mastery_phishing") or 0),
            Smishing=float(row.get("mastery_smishing") or 0),
            Vishing=float(row.get("mastery_vishing") or 0),
            Pretexting=float(row.get("mastery_pretexting") or 0),
            Baiting=float(row.get("mastery_baiting") or 0),
        ),
        preTestCompleted=int(row.get("sessions") or 0) > 0,
    )


def _create_token(student_id: str) -> str:
    payload = {
        "id": student_id,
        "role": "student",
        "exp": datetime.now(UTC) + timedelta(days=JWT_EXPIRY_DAYS),
        "iat": datetime.now(UTC),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def verify_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc


def _fetch_student_by_email(email: str) -> dict | None:
    normalized = email.strip().lower()
    try:
        response = supabase.table("students").select("*").eq("email", normalized).execute()
    except Exception as exc:
        raise _supabase_error(exc) from exc
    rows = response.data or []
    return rows[0] if rows else None


def _verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password:
        return False
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except ValueError:
        return False


def login_student(email: str, password: str) -> LoginResponse:
    student = _fetch_student_by_email(email)
    if not student:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not _verify_password(password, student.get("password", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    token = _create_token(str(student["id"]))
    if isinstance(token, bytes):
        token = token.decode("utf-8")

    # DB default is true; null means first-login (legacy rows).
    raw_flag = student.get("requires_password_change")
    must_change = True if raw_flag is None else bool(raw_flag)

    return LoginResponse(
        token=token,
        mustChangePassword=must_change,
        user=_map_student(student),
    )


def _validate_password_strength(password: str) -> None:
    if len(password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters",
        )
    if not re.search(r"[A-Z]", password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain an uppercase letter",
        )
    if not re.search(r"[a-z]", password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain a lowercase letter",
        )
    if not re.search(r"[0-9]", password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain a number",
        )
    if not re.search(r"[^A-Za-z0-9]", password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain a special character",
        )


def change_student_password(student_id: str, new_password: str) -> None:
    _validate_password_strength(new_password)
    hashed = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt(rounds=10))
    try:
        response = (
            supabase.table("students")
            .update(
                {
                    "password": hashed.decode("utf-8"),
                    "requires_password_change": False,
                }
            )
            .eq("id", student_id)
            .execute()
        )
    except Exception as exc:
        raise _supabase_error(exc) from exc

    if getattr(response, "error", None):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update password",
        )
