import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.routes.content import published_content

class SchoolContentTest(unittest.TestCase):
    def setUp(self):
        self.claims = patch("app.routes.content.verify_token", return_value={"id":"student-1","role":"student"})
        self.student = patch("app.routes.content.fetch_student_by_id", return_value={"id":"student-1","status":"Active"})
        self.database = patch("app.routes.content.supabase", MagicMock())
        self.verify = self.claims.start()
        self.fetch = self.student.start()
        self.db = self.database.start()
        self.addCleanup(patch.stopall)
        self.catalog = {"schemaVersion":1,"releaseVersion":2,"items":[{"id":"lesson-1","kind":"lesson","title":"Check the sender","revision":2}]}
        self.db.rpc.return_value.execute.return_value = SimpleNamespace(data=self.catalog)

    def test_student_feed_and_conditional_request(self):
        response = published_content("Bearer token", None)
        self.assertEqual(json.loads(response.body), self.catalog)
        self.db.rpc.assert_called_once_with("levelblue_published_catalog", {})
        self.fetch.assert_called_once_with("student-1")
        response = published_content("Bearer token", response.headers["etag"])
        self.assertEqual(response.status_code, 304)
        self.assertEqual(response.headers["vary"], "Authorization")

    def test_missing_auth_teacher_and_inactive_student_rejected(self):
        with self.assertRaises(HTTPException) as error:
            published_content(None, None)
        self.assertEqual(error.exception.status_code, 401)
        self.verify.return_value = {"id":"teacher","role":"admin"}
        with self.assertRaises(HTTPException) as error:
            published_content("Bearer token", None)
        self.assertEqual(error.exception.status_code, 403)
        self.verify.return_value = {"id":"student-1","role":"student"}
        self.fetch.return_value = {"status":"Inactive"}
        with self.assertRaises(HTTPException) as error:
            published_content("Bearer token", None)
        self.assertEqual(error.exception.status_code, 403)
        self.db.rpc.assert_not_called()

    def test_database_failure_is_not_an_empty_catalog_or_secret_leak(self):
        self.db.rpc.side_effect = RuntimeError("private database detail")
        with self.assertRaises(HTTPException) as error:
            published_content("Bearer token", None)
        self.assertEqual(error.exception.status_code, 503)
        self.assertNotIn("private", error.exception.detail)

    def test_invalid_catalog_is_rejected(self):
        self.db.rpc.return_value.execute.return_value = SimpleNamespace(data=[])
        with self.assertRaises(HTTPException) as error:
            published_content("Bearer token", None)
        self.assertEqual(error.exception.status_code, 503)
