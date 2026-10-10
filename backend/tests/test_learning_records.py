import sys
import types
import unittest
from datetime import UTC, datetime, timedelta
from uuid import uuid4
from unittest.mock import Mock, patch

if "app.supabase_client" not in sys.modules:
    stub = types.ModuleType("app.supabase_client")
    stub.supabase = object()
    sys.modules["app.supabase_client"] = stub

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from app.services.learning_records import LearningEvent, record_learning_events
from app.schemas.progress import ProgressSyncRequest
from app.routes.progress import router
from app.data.pretest_questions import questions_for_module
from tests.test_progress_sync import FakeSupabase


def event(**overrides):
    return dict(event_id=str(uuid4()), kind="mastery", module_id="mod_01", occurred_at=datetime.now(UTC).isoformat(), mastery=0, **overrides)


class LearningRecordsTests(unittest.TestCase):
    def test_zero_and_timestamp_preserved(self):
        payload = event()
        parsed = LearningEvent(**payload)
        self.assertEqual(parsed.record()["data"]["mastery"], 0)
        self.assertEqual(parsed.record()["occurred_at"], payload["occurred_at"])

    def test_reject_missing_future_or_invalid_evidence(self):
        invalid = [dict(event(), occurred_at="2000-01-01"), dict(event(), occurred_at=(datetime.now(UTC)+timedelta(days=1)).isoformat()), dict(event(), mastery=1.1), dict(event(), student_id="another"), dict(event(), comparison_key="forged"), dict(event(), kind="stage"), dict(event(), kind="posttest", instrument="stage-exam-v1", correct=0, answered=14, total=15, attempt_id=str(uuid4()))]
        for payload in invalid:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                LearningEvent(**payload)
        with self.assertRaises(ValidationError):
            ProgressSyncRequest(learning_events=[event() for _ in range(101)])

    def test_full_zero_posttest_is_completed_but_has_no_automatic_gain(self):
        row = LearningEvent(**dict(event(), kind="posttest", instrument="stage-exam-v1", correct=0, answered=15, total=15, attempt_id=str(uuid4()))).record()
        self.assertEqual(row["data"]["score"], 0)
        self.assertTrue(row["data"]["completed"])
        self.assertIsNone(row["data"]["comparison_key"])
        self.assertEqual(row["data"]["source"], "mobile-reported")

    def test_pretest_is_graded_from_answers_not_claimed_score(self):
        bank = questions_for_module("mod_01")
        answers = [{"id":q["id"], "answer":-1} for q in bank]
        payload = dict(event(), kind="pretest", answers=answers, correct=25)
        row = LearningEvent(**payload).record()
        self.assertEqual(row["data"]["correct"], 0)
        self.assertEqual(row["data"]["source"], "server-graded")
        for wrong in [answers[:-1], answers[:-1]+[answers[0]]]:
            with self.assertRaises(ValidationError):
                LearningEvent(**dict(payload,answers=wrong))

    def test_rpc_failure_does_not_acknowledge_events(self):
        store=Mock();store.rpc.return_value.execute.side_effect=RuntimeError("private-key")
        with patch("app.services.learning_records.supabase",store),self.assertRaises(HTTPException) as caught:
            record_learning_events("learner",[LearningEvent(**event())])
        self.assertEqual(caught.exception.status_code,503)
        self.assertNotIn("private-key",caught.exception.detail)

    def test_authenticated_sync_binds_events_to_claim_and_acks_after_save(self):
        app=FastAPI();app.include_router(router);client=TestClient(app)
        store=Mock();store.rpc.return_value.execute.return_value=types.SimpleNamespace(error=None)
        payload=event()
        with patch("app.routes.progress.verify_token",return_value={"id":"owner","role":"student"}),patch("app.services.progress_service.fetch_student_by_id",return_value={"id":"owner"}),patch("app.services.progress_service.supabase",FakeSupabase()),patch("app.services.learning_records.supabase",store):
            response=client.post("/api/progress/sync?student_id=another",headers={"Authorization":"Bearer test"},json={"learning_events":[payload]})
            self.assertEqual(response.status_code,200,response.text)
            self.assertEqual(response.json()["acknowledged_events"],[payload["event_id"]])
            self.assertEqual(store.rpc.call_args.args[1]["p_student"],"owner")
        for role in ["admin","super"]:
            with patch("app.routes.progress.verify_token",return_value={"id":"staff","role":role}):
                self.assertEqual(client.post("/api/progress/sync",headers={"Authorization":"Bearer test"},json={"learning_events":[payload]}).status_code,403)
        self.assertEqual(client.post("/api/progress/sync",json={"learning_events":[payload]}).status_code,401)

    def test_evidence_failure_prevents_false_success_or_partial_snapshot(self):
        fake=FakeSupabase()
        from app.services.progress_service import sync_student_progress
        with patch("app.services.progress_service.fetch_student_by_id",return_value={"id":"owner"}),patch("app.services.progress_service.supabase",fake),patch("app.services.progress_service.record_learning_events",side_effect=HTTPException(status_code=503)):
            with self.assertRaises(HTTPException):
                sync_student_progress("owner",ProgressSyncRequest(learning_events=[event()]))
        self.assertFalse(fake.updates)
