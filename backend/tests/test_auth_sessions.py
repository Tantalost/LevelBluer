"""Offline recovery session revocation; no live accounts or network."""
import sys
import types
import unittest
from unittest.mock import patch

if "app.supabase_client" not in sys.modules:
    stub = types.ModuleType("app.supabase_client")
    stub.supabase = object()
    sys.modules["app.supabase_client"] = stub

from fastapi import HTTPException
from app.services import auth_service


class AuthSessionTests(unittest.TestCase):
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
