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


def checkpoint_response(correct: bool, index: int) -> dict:
    return {"question_id": f"q{index}", "prompt": "Which response is safer?", "options": ["Report it", "Send the code"],
            "selected_answer": "Report it" if correct else "Send the code", "correct_answer": "Report it", "correct": correct}


def checkpoint_event(correct: int, **overrides):
    responses = [checkpoint_response(index < correct, index) for index in range(25)]
    payload = dict(event(), kind="posttest", instrument="lesson-checkpoint-v1", attempt_id=str(uuid4()),
                   correct=correct, answered=25, total=25, assessment_role="formative", passed=correct >= 20, responses=responses)
    payload.update(overrides)
    return payload


class CheckpointClassificationTests(unittest.TestCase):
    def test_failed_full_attempt_is_formative_and_not_passed(self):
        row = LearningEvent(**checkpoint_event(10)).record()
        self.assertEqual(row["kind"], "posttest")
        self.assertEqual(row["data"]["instrument"], "lesson-checkpoint-v1")
        self.assertTrue(row["data"]["completed"])
        self.assertFalse(row["data"]["passed"])
        self.assertEqual(row["data"]["assessment_role"], "formative")
        self.assertIsNone(row["data"]["comparison_key"])
        self.assertEqual(row["data"]["correct"], 10)
        self.assertEqual(row["data"]["score"], 40)
        self.assertNotIn("mastery", row["data"])

    def test_pass_threshold_and_perfect_score(self):
        passed = LearningEvent(**checkpoint_event(20)).record()["data"]
        perfect = LearningEvent(**checkpoint_event(25)).record()["data"]
        self.assertTrue(passed["completed"] and passed["passed"] and passed["assessment_role"] == "formative")
        self.assertEqual(passed["score"], 80)
        self.assertTrue(perfect["completed"] and perfect["passed"])
        self.assertEqual(perfect["correct"], 25)

    def test_repeated_attempts_keep_separate_identifiers(self):
        first = LearningEvent(**checkpoint_event(10)).record()
        second = LearningEvent(**checkpoint_event(10)).record()
        self.assertNotEqual(first["event_id"], second["event_id"])
        self.assertNotEqual(first["data"]["attempt_id"], second["data"]["attempt_id"])
        self.assertFalse(first["data"]["passed"] or second["data"]["passed"])
        self.assertEqual(first["data"]["assessment_role"], second["data"]["assessment_role"])

    def test_metadata_survives_ingestion_without_changing_answers(self):
        payload = checkpoint_event(10)
        sent = [dict(item) for item in payload["responses"]]
        parsed = ProgressSyncRequest(learning_events=[payload]).learning_events[0]
        stored = parsed.record()["data"]["responses"]
        self.assertEqual(stored, sent)
        self.assertEqual(parsed.record()["data"]["assessment_role"], "formative")
        self.assertFalse(parsed.record()["data"]["passed"])
        self.assertEqual(parsed.record()["module_id"], payload["module_id"])
        self.assertEqual(parsed.record()["occurred_at"], payload["occurred_at"])

    def test_checkpoint_snapshot_does_not_invoke_bkt(self):
        store = Mock()
        store.rpc.return_value.execute.return_value = types.SimpleNamespace(error=None)
        payload = checkpoint_event(10)
        with patch("app.services.learning_records.supabase", store):
            record_learning_events("learner", [LearningEvent(**payload)])
        self.assertEqual(store.rpc.call_args.args[0], "levelblue_record_learning")
        stored = store.rpc.call_args.args[1]["p_events"][0]["data"]
        self.assertEqual(stored["assessment_role"], "formative")
        self.assertFalse(stored["passed"])
        self.assertTrue(stored["completed"])
        self.assertNotIn("mastery", stored)

    def test_false_pass_and_non_checkpoint_role_are_rejected(self):
        for payload in [checkpoint_event(10, passed=True), checkpoint_event(20, passed=False), checkpoint_event(20, assessment_role=None),
                        dict(event(), kind="posttest", instrument="stage-exam-v1", correct=15, answered=15, total=15, attempt_id=str(uuid4()), assessment_role="formative", passed=True),
                        dict(event(), assessment_role="formative", passed=True)]:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                LearningEvent(**payload)

    def test_legacy_checkpoint_without_metadata_keeps_its_stored_shape(self):
        payload = checkpoint_event(10)
        del payload["assessment_role"]
        del payload["passed"]
        data = LearningEvent(**payload).record()["data"]
        self.assertNotIn("assessment_role", data)
        self.assertNotIn("passed", data)
        self.assertTrue(data["completed"])
        self.assertEqual(data["instrument"], "lesson-checkpoint-v1")

    def test_pretest_and_mastery_classification_are_unchanged(self):
        mastery = LearningEvent(**event()).record()
        self.assertEqual(mastery["kind"], "mastery")
        self.assertEqual(set(mastery["data"]), {"topic", "source", "mastery"})
        bank = questions_for_module("mod_01")
        pretest = LearningEvent(**dict(event(), kind="pretest", answers=[{"id": q["id"], "answer": -1} for q in bank])).record()
        self.assertEqual(pretest["kind"], "pretest")
        self.assertEqual(pretest["data"]["source"], "server-graded")
        self.assertIsNone(pretest["data"]["comparison_key"])
        self.assertNotIn("assessment_role", pretest["data"])
        self.assertNotIn("passed", pretest["data"])
        stage = LearningEvent(**dict(event(), kind="posttest", instrument="stage-exam-v1", correct=0, answered=15, total=15, attempt_id=str(uuid4()))).record()
        self.assertNotIn("assessment_role", stage["data"])
        self.assertNotIn("passed", stage["data"])
        self.assertTrue(stage["data"]["completed"])
        self.assertIsNone(stage["data"]["comparison_key"])

    def test_sync_persists_checkpoint_metadata_inside_event_data(self):
        app = FastAPI()
        app.include_router(router)
        client = TestClient(app)
        store = Mock()
        store.rpc.return_value.execute.return_value = types.SimpleNamespace(error=None)
        payload = checkpoint_event(20)
        with patch("app.routes.progress.verify_token", return_value={"id": "owner", "role": "student"}), patch("app.services.progress_service.fetch_student_by_id", return_value={"id": "owner"}), patch("app.services.progress_service.supabase", FakeSupabase()), patch("app.services.learning_records.supabase", store):
            response = client.post("/api/progress/sync", headers={"Authorization": "Bearer test"}, json={"learning_events": [payload]})
        self.assertEqual(response.status_code, 200, response.text)
        stored = store.rpc.call_args.args[1]["p_events"][0]
        self.assertEqual(stored["kind"], "posttest")
        self.assertEqual(stored["module_id"], "mod_01")
        self.assertEqual(stored["data"]["assessment_role"], "formative")
        self.assertTrue(stored["data"]["passed"])
        self.assertTrue(stored["data"]["completed"])
        self.assertIsNone(stored["data"]["comparison_key"])
        self.assertEqual(len(stored["data"]["responses"]), 25)
        self.assertEqual(response.json()["acknowledged_events"], [payload["event_id"]])


class StageEvidenceTests(unittest.TestCase):
    def test_stage_details_bounded_and_optional_for_legacy_clients(self):
        payload = dict(event(), kind="stage", attempt_id=str(uuid4()), stage=1, outcome="failed")
        self.assertNotIn("details", LearningEvent(**payload).record()["data"])
        details = dict(phase="Trace", health=0, answered=3, correct=0, waves_completed=0, waves_total=3, timed_out=True, missed_question_ids=["q1"])
        self.assertEqual(LearningEvent(**dict(payload,details=details)).record()["data"]["details"]["correct"],0)
        for invalid in [dict(details,correct=4),dict(details,missed_question_ids=["x"]*51),dict(details,waves_completed=4),dict(details,student_id="forged")]:
            with self.assertRaises(ValidationError):
                LearningEvent(**dict(payload,details=invalid))
        with self.assertRaises(ValidationError):
            LearningEvent(**dict(payload,outcome="started",details=details))

    def test_old_mobile_snapshots_cannot_write_enrollment(self):
        from app.services.progress_service import sync_student_progress
        fake=FakeSupabase()
        payload=ProgressSyncRequest(student={"section":"Old","section_id":"old","grade_level":"Grade 11","enrollment_status":"active","academic_year":"2026-2027","enrollment_version":0}, section="Old")
        with patch("app.services.progress_service.fetch_student_by_id",return_value={"id":"owner","section":"New","grade_level":"Grade 12","enrollment_status":"graduated"}),patch("app.services.progress_service.supabase",fake):
            sync_student_progress("owner",payload)
        for update in fake.updates.get("students",[]):
            self.assertFalse(set(update)&{"section","section_id","grade_level","enrollment_status","academic_year","enrollment_version"})
