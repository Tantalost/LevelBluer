from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.routes.auth import router as auth_router
from app.routes.bkt import router as bkt_router
from app.routes.pretest import router as pretest_router
from app.routes.progress import router as progress_router
from app.routes.content import router as content_router
from app.routes.pvp import router as pvp_router
from app.services.pvp_history import MatchRecorder
from app.services.pvp_hub import PvpHub
from app.services.pvp_service import PvpService


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # Online PvP rooms are in-memory: run exactly one worker (no --workers N).
    hub = PvpHub(PvpService(
        active_grace_ms=settings.pvp_active_grace_seconds * 1000,
        waiting_grace_ms=settings.pvp_waiting_grace_seconds * 1000,
        closed_ttl_ms=settings.pvp_closed_ttl_seconds * 1000,
        stale_waiting_ms=settings.pvp_stale_waiting_seconds * 1000,
        queue_ttl_ms=settings.pvp_queue_ttl_seconds * 1000,
    ), recorder=MatchRecorder())
    app.state.pvp_hub = hub
    async with hub.running():
        yield


app = FastAPI(
    title="LevelBlue Mobile API",
    description="Python backend for the Godot mobile game — student auth, pre-test, BKT, and save sync.",
    version="1.0.0",
    lifespan=lifespan,
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
app.include_router(content_router)
app.include_router(pvp_router)


@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException) -> JSONResponse:
    message = exc.detail if isinstance(exc.detail, str) else "Request failed"
    return JSONResponse(status_code=exc.status_code, content={"error": message})


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "levelblue-mobile-backend"}
