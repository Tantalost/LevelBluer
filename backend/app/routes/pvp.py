"""Authenticated online PvP transport. The player id always comes from the verified JWT.

WebSocket auth: send ``Authorization: Bearer <jwt>`` in the handshake (Godot 4:
``WebSocketPeer.handshake_headers``). Tokens are never read from the URL or messages.
"""
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Query, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from app.services import pvp_history
from app.services.auth_service import verify_token
from app.services.pvp_hub import PvpHub
from app.services.pvp_service import PvpError

router = APIRouter(prefix="/api/pvp", tags=["pvp"])

CLOSE_UNAUTHORIZED = 4401
CLOSE_FORBIDDEN = 4403
CLOSE_NOT_FOUND = 4404

_STATUS = {
    "room_not_found": 404,
    "not_in_room": 403,
    "already_in_room": 409,
    "already_in_match": 409,
    "room_full": 409,
    "room_closed": 409,
    "bank_unavailable": 503,
}


def _student_id(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Student sign-in required")
    claims = verify_token(authorization.split(" ", 1)[1].strip())
    if claims.get("role") != "student" or not claims.get("id"):
        raise HTTPException(status_code=403, detail="Student access required")
    return str(claims["id"])


def _hub(app: Any) -> PvpHub:
    return app.state.pvp_hub


def _failure(exc: PvpError) -> JSONResponse:
    return JSONResponse(status_code=_STATUS.get(exc.code, 400), content={"error": str(exc), "code": exc.code})


@router.post("/rooms")
async def create_room(request: Request, authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    try:
        return JSONResponse(status_code=201, content=_hub(request.app).service.create_room(user_id))
    except PvpError as exc:
        return _failure(exc)


@router.post("/rooms/{code}/join")
async def join_room(code: str, request: Request, authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    hub = _hub(request.app)
    try:
        if hub.service.member_of(code, user_id):
            raise PvpError("already_in_room", "You are already in this room")
        view = hub.service.join_room(code, user_id)
    except PvpError as exc:
        return _failure(exc)
    hub.flush(view["code"])
    return JSONResponse(content=view)


@router.get("/rooms/{code}")
async def room_state(code: str, request: Request, authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    hub = _hub(request.app)
    try:
        view = hub.service.state(code, user_id)
    except PvpError as exc:
        return _failure(exc)
    hub.flush(view["code"])
    return JSONResponse(content=view)


@router.post("/matchmaking/join")
async def join_matchmaking(request: Request, authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    try:
        return JSONResponse(content=_hub(request.app).service.join_queue(user_id))
    except PvpError as exc:
        return _failure(exc)


@router.post("/matchmaking/cancel")
async def cancel_matchmaking(request: Request, authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    return JSONResponse(content=_hub(request.app).service.cancel_queue(user_id))


@router.get("/matchmaking/status")
async def matchmaking_status(request: Request, authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    return JSONResponse(content=_hub(request.app).service.queue_status(user_id))


# History is read-only and always scoped to the JWT's own student; no route accepts a result.

@router.get("/me/summary")
def my_summary(authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    try:
        return JSONResponse(content=pvp_history.student_summary(user_id))
    except pvp_history.HistoryUnavailable:
        return JSONResponse(status_code=503, content={"error": "PvP history is unavailable right now", "code": "history_unavailable"})


@router.get("/me/matches")
def my_matches(limit: int = Query(default=10, ge=1, le=pvp_history.RECENT_LIMIT_MAX), authorization: str | None = Header(default=None)) -> JSONResponse:
    user_id = _student_id(authorization)
    try:
        return JSONResponse(content={"matches": pvp_history.recent_matches(user_id, limit)})
    except pvp_history.HistoryUnavailable:
        return JSONResponse(status_code=503, content={"error": "PvP history is unavailable right now", "code": "history_unavailable"})


@router.websocket("/rooms/{code}/ws")
async def room_socket(websocket: WebSocket, code: str) -> None:
    hub = _hub(websocket.app)
    try:
        user_id = _student_id(websocket.headers.get("authorization"))
    except HTTPException as exc:
        await websocket.close(code=CLOSE_UNAUTHORIZED if exc.status_code == 401 else CLOSE_FORBIDDEN)
        return
    try:
        member = hub.service.member_of(code, user_id)
    except PvpError:
        await websocket.close(code=CLOSE_NOT_FOUND)
        return
    if not member:
        await websocket.close(code=CLOSE_FORBIDDEN)
        return
    await websocket.accept()
    connection = await hub.attach(code, user_id, websocket)
    try:
        while True:
            try:
                message = await websocket.receive_json()
            except WebSocketDisconnect:
                break
            except (ValueError, KeyError):
                hub.error(connection, "bad_message", "Messages must be JSON objects")
                continue
            if not hub.is_current(connection):
                break
            _dispatch(hub, connection, message)
            if connection.closed:
                break
    except RuntimeError:
        pass
    finally:
        await hub.detach(connection)


def _dispatch(hub: PvpHub, connection: Any, message: Any) -> None:
    if not isinstance(message, dict):
        hub.error(connection, "bad_message", "Messages must be JSON objects")
        return
    kind = message.get("type")
    service = hub.service
    try:
        if kind == "ping":
            hub.send(connection, {"type": "pong", "revision": service.revision(connection.code), "server_now": service.now()})
            return
        if kind == "ready":
            service.set_ready(connection.code, connection.user_id, True)
        elif kind == "answer":
            round_number = message.get("round")
            option_index = message.get("option_index")
            if isinstance(round_number, bool) or not isinstance(round_number, int):
                raise PvpError("bad_message", "answer needs an integer round")
            service.submit_answer(connection.code, connection.user_id, round_number, option_index)
        elif kind == "leave":
            service.retire(connection.code, connection.user_id)
            hub.flush(connection.code)
            hub.release(connection)
            return
        else:
            raise PvpError("bad_message", "Unknown message type")
    except PvpError as exc:
        hub.flush(connection.code)
        hub.error(connection, exc.code, str(exc))
        return
    hub.flush(connection.code)
