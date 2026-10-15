"""Offline recovery session revocation; no live accounts or network."""
import sys
import types
import unittest
from unittest.mock import patch, MagicMock

if "app.supabase_client" not in sys.modules:
    stub = types.ModuleType("app.supabase_client")
    stub.supabase = object()
    sys.modules["app.supabase_client"] = stub

from fastapi import HTTPException
from app.services import auth_service
from app.services.database_diagnostics import safe_database_error
from postgrest.exceptions import APIError
import httpx


class AuthSessionTests(unittest.TestCase):
    def test_database_diagnostics_never_include_provider_payload(self) -> None:
        secret = "PRIVATE-password-token-email-service-key"
        for code in ("401", "42501", "42P01", "PGRST202", "PGRST205", secret):
            exc = APIError({"code": code, "message": secret, "details": secret, "hint": secret})
            with self.assertLogs("app.services.auth_service", level="WARNING") as logs:
                response = auth_service._supabase_error(exc, "login_student_lookup")
            output = " ".join(logs.output)
            self.assertNotIn(secret, output)
            self.assertIn("operation=login_student_lookup", output)
            self.assertIn("code=" + ("unknown" if code == secret else code), output)
            self.assertEqual(response.status_code, 500)
            self.assertEqual(response.detail, "Database request failed")

    def test_database_transport_diagnostics_hide_urls_and_keep_response_contract(self) -> None:
        secret = "PRIVATE-token"
        for exc in (httpx.ConnectError(secret), httpx.ReadTimeout(secret), RuntimeError(secret)):
            with self.assertLogs("app.services.auth_service", level="WARNING") as logs:
                response = auth_service._supabase_error(exc)
            self.assertNotIn(secret, " ".join(logs.output))
            self.assertEqual(response.status_code, 503 if isinstance(exc, httpx.ConnectError) else 500)
        request = httpx.Request("GET", "https://example.invalid/?token=" + secret)
        error = httpx.HTTPStatusError(secret, request=request, response=httpx.Response(403, request=request))
        self.assertEqual(safe_database_error(error), "type=HTTPStatusError code=403 hint=database_http_error")

    def test_login_lookup_logs_sanitized_failure_before_password_check(self) -> None:
        database = MagicMock()
        database.table.return_value.select.return_value.eq.return_value.execute.side_effect = APIError(
            {"code": "42501", "message": "PRIVATE record data"})
        with patch.object(auth_service, "supabase", database), patch.object(auth_service, "_verify_password") as verify:
            with self.assertLogs("app.services.auth_service", level="WARNING") as logs:
                with self.assertRaises(HTTPException) as failure:
                    auth_service.login_student("private@example.com", "PRIVATE-password")
            verify.assert_not_called()
        self.assertEqual(failure.exception.status_code, 500)
        self.assertIn("operation=login_student_lookup", " ".join(logs.output))
        self.assertNotIn("PRIVATE", " ".join(logs.output))
        self.assertNotIn("private@example.com", " ".join(logs.output))

    def test_rating_recovery_uses_same_sanitized_diagnostics(self) -> None:
        from app.services.pvp_rating import RatingQueue
        def unavailable(*_args):
            raise APIError({"code": "PGRST202", "message": "PRIVATE-key", "details": "PRIVATE-record"})
        queue = RatingQueue(unrated=unavailable)
        with self.assertLogs("app.services.pvp_rating", level="WARNING") as logs:
            self.assertFalse(queue.recover())
        output = " ".join(logs.output)
        self.assertIn("operation=pvp_rating_recovery type=APIError code=PGRST202", output)
        self.assertNotIn("PRIVATE", output)

    def test_session_version_and_legacy_compatibility(self) -> None:
        token = auth_service._create_token("student")
        with patch.object(auth_service, "fetch_student_by_id", return_value={"id": "student"}):
            self.assertEqual(auth_service.verify_token(token)["sessionVersion"], 0)
        with patch.object(auth_service, "fetch_student_by_id", return_value={"id": "student", "session_version": 1}):
            with self.assertRaises(HTTPException) as error:
                auth_service.verify_token(token)
            self.assertEqual(error.exception.status_code, 401)
            self.assertEqual(auth_service.verify_token(auth_service._create_token("student", 1))["id"], "student")

    def test_removed_account_and_database_failure_fail_closed(self) -> None:
        token = auth_service._create_token("student")
        for database_status, expected in [(404, 401), (503, 503)]:
            with patch.object(auth_service, "fetch_student_by_id", side_effect=HTTPException(status_code=database_status)):
                with self.assertRaises(HTTPException) as error:
                    auth_service.verify_token(token)
                self.assertEqual(error.exception.status_code, expected)

    def test_invalid_token_does_not_query_database(self) -> None:
        with patch.object(auth_service, "fetch_student_by_id") as lookup:
            with self.assertRaises(HTTPException):
                auth_service.verify_token("not-a-token")
            lookup.assert_not_called()
