from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.routes.auth import router as auth_router
from app.routes.bkt import router as bkt_router
from app.routes.pretest import router as pretest_router
from app.routes.progress import router as progress_router

app = FastAPI(
    title="LevelBlue Mobile API",
    description="Python backend for the Godot mobile game — student auth, pre-test, BKT, and save sync.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(pretest_router)
app.include_router(bkt_router)
app.include_router(progress_router)


@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException) -> JSONResponse:
    message = exc.detail if isinstance(exc.detail, str) else "Request failed"
    return JSONResponse(status_code=exc.status_code, content={"error": message})


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "levelblue-mobile-backend"}
