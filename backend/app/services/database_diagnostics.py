"""Bounded diagnostic metadata only; never serialize database error payloads."""
import httpx
from postgrest.exceptions import APIError


def safe_database_error(exc: Exception) -> str:
    # Explicit allowlists avoid logging arbitrary code/message fields from a proxy.
    hints: dict[str, str] = {
        "401": "check_service_key_and_project",
        "403": "check_database_permissions",
        "42501": "check_database_permissions",
        "42P01": "check_table_migrations",
        "42703": "check_column_migrations",
        "42883": "check_function_migrations",
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
