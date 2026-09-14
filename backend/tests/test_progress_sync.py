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

    def update(self, payload):
        self._store.updates.setdefault(self._table, []).append(payload)
        return self

    def upsert(self, payload):
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
        return _Result(data=[{"payload": {}}])


class FakeSupabase:
    def __init__(self, fail=None, fail_nth=None):
        self.fail = set(fail or ())
        self.fail_nth = set(fail_nth or ())
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
