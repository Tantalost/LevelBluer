import sys
import types
import unittest
from unittest.mock import patch

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

    def test_repeated_sync_updates_existing_mastery_without_duplicates(self):
        fake = FakeSupabase()
        self.assertTrue(self._run(fake).ok)
        fake.bkt_rows[("stu-1", "Phishing")]["probability_known"] = 0.1
        self.assertTrue(self._run(fake).ok)
        self.assertEqual(len(fake.bkt_rows), 2)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)

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

    def test_student_mastery_column_update_fails_raises_non_2xx(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run(FakeSupabase(fail_nth={("students", 2)}))
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")


if __name__ == "__main__":
    unittest.main()
