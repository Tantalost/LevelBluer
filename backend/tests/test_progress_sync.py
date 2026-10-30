import sys
import types
import unittest
from unittest.mock import patch

if "postgrest.exceptions" not in sys.modules:
    _postgrest = types.ModuleType("postgrest")
    _postgrest_exceptions = types.ModuleType("postgrest.exceptions")

    class _APIError(Exception):
        pass

    _postgrest_exceptions.APIError = _APIError
    _postgrest.exceptions = _postgrest_exceptions
    sys.modules["postgrest"] = _postgrest
    sys.modules["postgrest.exceptions"] = _postgrest_exceptions

if "app.supabase_client" not in sys.modules:
    _supabase_stub = types.ModuleType("app.supabase_client")
    _supabase_stub.supabase = object()
    sys.modules["app.supabase_client"] = _supabase_stub

from fastapi import HTTPException, status

from app.schemas.progress import ProgressSyncRequest
from app.services.progress_service import sync_student_progress


class _Result:
    def __init__(self, data=None, error=None):
        self.data = data or []
        self.error = error


class FakeQuery:
    def __init__(self, store, table):
        self._store = store
        self._table = table
        self._pending_upsert = None
        self._on_conflict = ""

    def update(self, payload):
        self._store.updates.setdefault(self._table, []).append(payload)
        return self

    def upsert(self, payload, *, on_conflict=""):
        self._pending_upsert = payload
        self._on_conflict = on_conflict
        self._store.upserts.setdefault(self._table, []).append(payload)
        return self

    def eq(self, *_args, **_kwargs):
        return self

    def select(self, *_args, **_kwargs):
        return self

    def limit(self, *_args, **_kwargs):
        return self

    def execute(self):
        self._store.executes.append(self._table)
        n = self._store.executes.count(self._table)
        if self._table in self._store.fail:
            raise RuntimeError(f"supabase {self._table} failed: secret-token")
        if (self._table, n) in self._store.fail_nth:
            raise RuntimeError(f"supabase {self._table} #{n} failed: secret-token")
        if self._table == "player_saves" and self._pending_upsert is None:
            return _Result(data=self._store.save_rows)
        if self._table == "bkt_records" and self._pending_upsert is not None:
            rows = self._pending_upsert
            if isinstance(rows, dict):
                rows = [rows]
            for row in rows:
                key = (row["student_id"], row["topic"])
                if key in self._store.bkt_rows and self._on_conflict != "student_id,topic":
                    raise RuntimeError("duplicate student/topic; default primary key is id")
                self._store.bkt_rows[key] = dict(row)
        return _Result(data=[{"payload": {}}])


class FakeSupabase:
    def __init__(self, fail=None, fail_nth=None):
        self.fail = set(fail or ())
        self.fail_nth = set(fail_nth or ())
        self.bkt_rows = {}
        self.executes: list[str] = []
        self.updates: dict[str, list] = {}
        self.upserts: dict[str, list] = {}
        self.save_rows = [{"payload": {}}]

    def table(self, name: str) -> FakeQuery:
        return FakeQuery(self, name)


def _payload() -> ProgressSyncRequest:
    return ProgressSyncRequest(
        mock_max_stage_cleared=2,
        mastery_matrix={"phishing": 0.42, "smishing": 0.55},
    )


class ProgressSyncFailureTest(unittest.TestCase):
    def _run(self, fake: FakeSupabase):
        with (
            patch(
                "app.services.progress_service.fetch_student_by_id",
                return_value={"id": "stu-1", "highest_unlocked_stage": 1},
            ),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", _payload())

    def test_success_returns_ok(self):
        result = self._run(FakeSupabase())
        self.assertTrue(result.ok)

    def test_story_perks_survive_save_blob_without_assessment_events(self):
        fake = FakeSupabase()
        tracking = {
            "owned_perks": ["recap", "perspective"],
            "perk_loadout": ["recap"],
            "perk_attempts": [{"id": "attempt-1", "assist_status": "assisted",
                               "uses": {"recap": 1}, "replay": False}],
            "chapter_replay_progress": {"perk_run": {"id": "replay-1"}},
        }
        payload = ProgressSyncRequest(**tracking)
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
            patch("app.services.progress_service.record_learning_events", return_value=[]) as record,
        ):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
            record.assert_called_once_with("stu-1", [])
        stored = fake.upserts["player_saves"][0]["payload"]
        for key, value in tracking.items():
            self.assertEqual(stored[key], value)
        self.assertNotIn("bkt_records", fake.upserts)

    def test_repeated_sync_updates_existing_mastery_without_duplicates(self):
        fake = FakeSupabase()
        self.assertTrue(self._run(fake).ok)
        fake.bkt_rows[("stu-1", "Phishing")]["probability_known"] = 0.1
        self.assertTrue(self._run(fake).ok)
        self.assertEqual(len(fake.bkt_rows), 2)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)

    def test_practice_audit_sync_preserves_snapshot_without_creating_posttest(self):
        fake = FakeSupabase()
        records = {"mod01_practice": {"module_id": "mod_01", "correct": False,
                    "reason": "weakest_assessed_topic", "policy": "bkt-practice-v1",
                    "mastery_before": 0.4, "mastery_after": 0.3, "assisted": False}}
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.3}, practice_responses=records)
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
            patch("app.services.progress_service.record_learning_events", return_value=[]) as record,
        ):
            sync_student_progress("stu-1", payload)
            record.assert_called_once_with("stu-1", [])
        self.assertEqual(fake.upserts["player_saves"][0]["payload"]["practice_responses"], records)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.3)

    def test_pretest_updates_mastery_previously_saved_by_gameplay(self):
        from app.services.pretest_service import _upsert_bkt_records

        fake = FakeSupabase()
        self._run(fake)
        with patch("app.services.pretest_service.supabase", fake):
            _upsert_bkt_records("stu-1", {"Phishing": 0.7})
        self.assertEqual(len(fake.bkt_rows), 2)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.7)

    def test_assessment_updates_mastery_previously_saved_by_gameplay(self):
        from app.services.assess_service import _persist_topic_pl

        fake = FakeSupabase()
        self._run(fake)
        with patch("app.services.assess_service.supabase", fake):
            _persist_topic_pl("stu-1", "Phishing", 0.8)
        self.assertEqual(len(fake.bkt_rows), 2)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.8)

    def test_failed_save_read_does_not_replace_pretest_flags(self):
        fake = FakeSupabase(fail_nth={("player_saves", 1)})
        fake.save_rows = [{"payload": {"module_pretests": ["mod_01"]}}]
        with self.assertRaises(HTTPException) as ctx:
            self._run(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertNotIn("player_saves", fake.upserts)

    def test_save_read_keeps_existing_pretest_flags(self):
        fake = FakeSupabase()
        fake.save_rows = [{"payload": {"module_pretests": ["mod_01", "mod_02"]}}]
        self.assertTrue(self._run(fake).ok)
        stored = fake.upserts["player_saves"][0]["payload"]
        self.assertEqual(stored["module_pretests"], ["mod_01", "mod_02"])

    def test_save_blob_write_fails_raises_non_2xx(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run(FakeSupabase(fail={"player_saves"}))
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")
        self.assertNotIn("secret-token", str(ctx.exception.detail))

    def test_bkt_records_write_fails_raises_non_2xx(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run(FakeSupabase(fail={"bkt_records"}))
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")

    def test_unassessed_prior_does_not_replace_cloud_mastery(self):
        fake = FakeSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {"phishing": 0.8, "vishing": 0.66, "baiting": 0.5},
                "module_pretests": ["mod_02"],
            }
        }]
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.10, "smishing": 0.44, "vishing": 0.10})
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
        stored = fake.upserts["player_saves"][0]["payload"]
        matrix = stored["mastery_matrix"]
        self.assertAlmostEqual(matrix["phishing"], 0.8)
        self.assertAlmostEqual(matrix["smishing"], 0.44)
        self.assertAlmostEqual(matrix["vishing"], 0.66)
        self.assertAlmostEqual(matrix["baiting"], 0.5)
        self.assertEqual(stored["module_pretests"], ["mod_02"])
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.8)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Vishing")]["probability_known"], 0.66)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.44)

    def test_assessed_prior_is_stored(self):
        fake = FakeSupabase()
        fake.save_rows = [{"payload": {"mastery_matrix": {"phishing": 0.8, "pretexting": 0.33}}}]
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10},
            learning_evidence={"topics": {"phishing": 1}, "responses": 1},
            pretest_baselines={"mod_02": {"correct": 1, "total": 4}},
            lesson_quiz_responses={"mod_03": {"q1": False}},
            practice_responses={"prac_1": {"module_id": "mod_04", "skill": "pretexting", "correct": False}},
            lesson_post_quiz_scores={"mod_05": 3},
        )
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
        matrix = fake.upserts["player_saves"][0]["payload"]["mastery_matrix"]
        self.assertAlmostEqual(matrix["phishing"], 0.10)
        self.assertAlmostEqual(matrix["smishing"], 0.10)
        self.assertAlmostEqual(matrix["vishing"], 0.10)
        self.assertAlmostEqual(matrix["pretexting"], 0.10)
        self.assertAlmostEqual(matrix["baiting"], 0.10)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.10)

    def test_student_mastery_column_update_fails_raises_non_2xx(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run(FakeSupabase(fail_nth={("students", 2)}))
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")


if __name__ == "__main__":
    unittest.main()
