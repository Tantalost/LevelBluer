"""Bounded diagnostic metadata only; never serialize database error payloads."""
import logging
import threading
import time

import httpx
from postgrest.exceptions import APIError

from app.supabase_client import supabase

logger = logging.getLogger(__name__)

OPERATIONAL_EVENT_INTERVAL_SECONDS = 60.0
_event_lock = threading.Lock()
_last_event_at: dict[str, float] = {}


def log_operational_event(category: str, message: str, code: str, route: str, http_status: int) -> None:
    """Store at most one sanitized event per code per interval in this process.

    Callers pass fixed text only: no student id, answers, tokens, or database error text.
    """
    now = time.monotonic()
    with _event_lock:
        last = _last_event_at.get(code)
        if last is not None and now - last < OPERATIONAL_EVENT_INTERVAL_SECONDS:
            return
        _last_event_at[code] = now
    try:
        supabase.rpc("levelblue_log_operational_event", {
            "p_category": category,
            "p_message": message,
            "p_code": code,
            "p_route": route,
            "p_status": http_status,
        }).execute()
    except Exception:
        logger.warning("Operational monitoring event was not stored")


def is_lock_timeout(exc: Exception) -> bool:
    """PostgreSQL lock_not_available (55P03), raised when a function's lock_timeout expires."""
    code = str(getattr(exc, "code", "") or "")
    return code == "55P03" or "55P03" in str(exc) or "lock timeout" in str(exc).lower()


def safe_database_error(exc: Exception) -> str:
    # Explicit allowlists avoid logging arbitrary code/message fields from a proxy.
    hints: dict[str, str] = {
        "401": "check_service_key_and_project",
        "403": "check_database_permissions",
        "42501": "check_database_permissions",
        "42P01": "check_table_migrations",
        "42703": "check_column_migrations",
        "42883": "check_function_migrations",
        "22023": "invalid_function_argument",
        "55P03": "database_lock_timeout",
        "PGRST000": "database_connection_failed",
        "PGRST001": "database_connection_failed",
        "PGRST002": "schema_cache_unavailable",
        "PGRST003": "database_pool_timeout",
        "PGRST202": "check_function_and_schema_cache",
        "PGRST204": "check_column_and_schema_cache",
        "PGRST205": "check_table_and_schema_cache",
        "PGRST301": "check_service_key_and_project",
        "PGRST302": "database_authentication_required",
        "PGRST303": "check_service_key_and_project",
    }
    if isinstance(exc, APIError):
        raw_code: object = exc.code
        code: str = str(raw_code) if isinstance(raw_code, (str, int)) else "unknown"
        if code not in hints:
            code = "unknown"
        return f"type=APIError code={code} hint={hints.get(code, 'unclassified_database_error')}"
    if isinstance(exc, httpx.TimeoutException):
        return "type=TimeoutException code=none hint=database_request_timeout"
    if isinstance(exc, httpx.ConnectError):
        return "type=ConnectError code=none hint=check_database_connectivity"
    if isinstance(exc, httpx.HTTPStatusError):
        status: int = exc.response.status_code
        safe_status: str = str(status) if 400 <= status <= 599 else "unknown"
        return f"type=HTTPStatusError code={safe_status} hint=database_http_error"
    return "type=OtherException code=unknown hint=unclassified_database_error"
