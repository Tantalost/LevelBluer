"""Realtime delivery and timing for PvpService.

Single-worker, in-memory: every connection and room lives in this process. Production
must run ONE backend worker until room state and locking move to a shared store.

All hub methods run on the asyncio event loop thread. Each socket has one ordered
outbound queue and one writer task, so events never interleave or reorder.
"""
from __future__ import annotations

import asyncio
import contextlib
import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

from fastapi import WebSocket

from app.services.pvp_service import PvpError, PvpService

if TYPE_CHECKING:
    from app.services.pvp_history import MatchRecorder

logger = logging.getLogger(__name__)

TICK_SECONDS = 0.1
CLEANUP_SECONDS = 5.0
RECORD_SECONDS = 1.0
CLOSE_REPLACED = 4409
CLOSE_ROOM_GONE = 4410


@dataclass(eq=False)
class Connection:
    code: str
    user_id: str
    websocket: WebSocket
    queue: asyncio.Queue[dict[str, Any] | int] = field(default_factory=asyncio.Queue)
    writer: asyncio.Task[None] | None = None
    closed: bool = False


class PvpHub:
    def __init__(self, service: PvpService, tick_seconds: float = TICK_SECONDS, cleanup_seconds: float = CLEANUP_SECONDS, recorder: MatchRecorder | None = None, record_seconds: float = RECORD_SECONDS) -> None:
        self.service = service
        self.tick_seconds = tick_seconds
        self.cleanup_seconds = cleanup_seconds
        self.recorder = recorder
        self.record_seconds = record_seconds
        self._connections: dict[tuple[str, str], Connection] = {}
        self._last_cleanup = 0.0

    # ---- connections --------------------------------------------------------

    async def attach(self, code: str, user_id: str, websocket: WebSocket) -> Connection:
        code = code.strip().upper()
        connection = Connection(code=code, user_id=user_id, websocket=websocket)
        connection.writer = asyncio.create_task(self._write(connection))
        previous = self._connections.get((code, user_id))
        self._connections[(code, user_id)] = connection
        if previous is not None:
            self._close(previous, CLOSE_REPLACED)
        self.service.connect(code, user_id)
        self.flush(code)
        return connection

    def is_current(self, connection: Connection) -> bool:
        return not connection.closed and self._connections.get((connection.code, connection.user_id)) is connection

    async def detach(self, connection: Connection) -> None:
        if self.is_current(connection):
            del self._connections[(connection.code, connection.user_id)]
            with contextlib.suppress(PvpError):
                self.service.disconnect(connection.code, connection.user_id)
            self.flush(connection.code)
        self._close(connection, None)
        if connection.writer is not None:
            with contextlib.suppress(asyncio.CancelledError, Exception):
                await connection.writer

    def release(self, connection: Connection) -> None:
        """Close after already-queued events are delivered, without starting a disconnect grace."""
        if self.is_current(connection):
            del self._connections[(connection.code, connection.user_id)]
        self._close(connection, 1000)

    def send(self, connection: Connection, message: dict[str, Any]) -> None:
        if not connection.closed:
            connection.queue.put_nowait(message)

    def error(self, connection: Connection, code: str, message: str) -> None:
        try:
            revision = self.service.revision(connection.code)
        except PvpError:
            revision = 0
        self.send(connection, {"type": "error", "code": code, "message": message, "revision": revision, "server_now": self.service.now()})

    def flush(self, code: str) -> None:
        try:
            events = self.service.drain_events(code)
        except PvpError:
            return
        for event in events:
            for (room_code, user_id), connection in list(self._connections.items()):
                if room_code == code and (event.to is None or event.to == user_id):
                    self.send(connection, event.payload)

    def _close(self, connection: Connection, close_code: int | None) -> None:
        if connection.closed:
            return
        connection.closed = True
        connection.queue.put_nowait(close_code if close_code is not None else 1000)

    async def _write(self, connection: Connection) -> None:
        while True:
            message = await connection.queue.get()
            if isinstance(message, int):
                with contextlib.suppress(Exception):
                    await connection.websocket.close(code=message)
                return
            try:
                await connection.websocket.send_json(message)
            except Exception:
                connection.closed = True
                return

    # ---- server-driven time --------------------------------------------------

    def tick(self) -> None:
        for code in self.service.room_codes():
            try:
                self.service.tick(code)
            except PvpError:
                continue
            self.flush(code)

    def cleanup(self) -> list[str]:
        removed = self.service.cleanup()
        for code in self.service.room_codes():
            self.flush(code)
        for code in removed:
            for key, connection in list(self._connections.items()):
                if key[0] == code:
                    del self._connections[key]
                    self._close(connection, CLOSE_ROOM_GONE)
        return removed

    async def run(self) -> None:
        loop = asyncio.get_running_loop()
        while True:
            try:
                self.tick()
                if loop.time() - self._last_cleanup >= self.cleanup_seconds:
                    self._last_cleanup = loop.time()
                    self.cleanup()
            except Exception:
                logger.exception("PvP ticker step failed")
            await asyncio.sleep(self.tick_seconds)

    async def persist(self) -> int:
        """Hand finished matches to the recorder and write them off the event loop."""
        records = self.service.drain_records()
        if self.recorder is None:
            return 0
        self.recorder.add(records)
        if not self.recorder.pending:
            return 0
        return await asyncio.to_thread(self.recorder.flush)

    async def _record_loop(self, stop: asyncio.Event) -> None:
        # Separate from the ticker so a slow database never delays round deadlines.
        # Never cancelled mid-write: it finishes the current flush, then does one last pass.
        while True:
            try:
                await self.persist()
            except Exception:
                logger.exception("PvP history step failed")
            if stop.is_set():
                return
            with contextlib.suppress(TimeoutError):
                await asyncio.wait_for(stop.wait(), self.record_seconds)

    @contextlib.asynccontextmanager
    async def running(self) -> AsyncIterator[PvpHub]:
        task = asyncio.create_task(self.run())
        stop = asyncio.Event()
        recorder_task = asyncio.create_task(self._record_loop(stop))
        try:
            yield self
        finally:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
            stop.set()
            with contextlib.suppress(Exception):
                await recorder_task
            for connection in list(self._connections.values()):
                self._close(connection, 1001)
            self._connections.clear()
