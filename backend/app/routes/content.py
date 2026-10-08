"""Authenticated, read-only school curriculum. Never serves draft or review data."""
from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import JSONResponse, Response
from app.services.auth_service import verify_token, fetch_student_by_id
from app.supabase_client import supabase

router = APIRouter(prefix="/api/content", tags=["school content"])

@router.get("")
def published_content(authorization: str | None = Header(default=None), if_none_match: str | None = Header(default=None)) -> Response:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Student sign-in required")
    claims = verify_token(authorization.split(" ", 1)[1].strip())
    if claims.get("role") != "student" or not claims.get("id"):
        raise HTTPException(status_code=403, detail="Student access required")
    student = fetch_student_by_id(str(claims["id"]))
    if str(student.get("status", "")).lower() in {"inactive", "archived", "suspended"}:
        raise HTTPException(status_code=403, detail="Student access is inactive")
    try:
        catalog = supabase.rpc("levelblue_published_catalog", {}).execute().data
        if not isinstance(catalog, dict) or catalog.get("schemaVersion") != 1 or not isinstance(catalog.get("items"), list):
            raise ValueError("Invalid catalog")
    except Exception as exc:
        raise HTTPException(status_code=503, detail="School content is unavailable. Please try again later.") from exc
    headers = {"ETag": f'"levelblue-content-v1-{catalog["releaseVersion"]}"', "Cache-Control": "private, no-cache", "Vary": "Authorization"}
    if if_none_match == headers["ETag"]:
        return Response(status_code=304, headers=headers)
    return JSONResponse(content=catalog, headers=headers)
