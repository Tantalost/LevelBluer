import copy
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
        self._update = None
        self._insert = None
        self._eqs: dict = {}
        self._isnull: list = []
        self._contains_all: list = []
        self._negate = False

    def update(self, payload):
        self._update = payload
        self._store.updates.setdefault(self._table, []).append(payload)
        return self

    def insert(self, payload):
        self._insert = payload
        if not hasattr(self._store, "inserts"):
            self._store.inserts = {}
        self._store.inserts.setdefault(self._table, []).append(payload)
        return self

    def upsert(self, payload, *, on_conflict=""):
        self._pending_upsert = payload
        self._on_conflict = on_conflict
        self._store.upserts.setdefault(self._table, []).append(payload)
        return self

    def eq(self, column, value, *_args, **_kwargs):
        self._eqs[column] = value
        return self

    def is_(self, column, value, *_args, **_kwargs):
        if value is None or value == "null":
            self._isnull.append(column)
        return self

    @property
    def not_(self):
        self._negate = True
        return self

    def contains(self, column, value):
        self._contains = (column, value, self._negate)
        self._contains_all.append(self._contains)
        self._negate = False
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
        if self._table == "bkt_records" and self._insert is not None:
            return self._insert_bkt_row()
        if self._table == "bkt_records" and self._update is not None:
            return self._update_bkt_row()
        if self._table == "bkt_records":
            return self._select_bkt_rows()
        return _Result(data=[{"payload": {}}])

    def _insert_bkt_row(self):
        row = dict(self._insert)
        key = (row["student_id"], row["topic"])
        if key in self._store.bkt_rows:
            raise RuntimeError("duplicate key value violates unique constraint 23505")
        self._store.bkt_rows[key] = row
        return _Result(data=[dict(row)])

    def _update_bkt_row(self):
        key = (self._eqs.get("student_id"), self._eqs.get("topic"))
        current = self._store.bkt_rows.get(key)
        seen = self._eqs.get("probability_known")
        if current is None or seen is None or abs(float(current.get("probability_known")) - float(seen)) > 1e-6:
            return _Result(data=[])
        updated = dict(current)
        updated.update(self._update)
        self._store.bkt_rows[key] = updated
        return _Result(data=[dict(updated)])

    def _select_bkt_rows(self):
        student_id = self._eqs.get("student_id")
        topic = self._eqs.get("topic")
        rows = []
        for (sid, stored_topic), row in self._store.bkt_rows.items():
            if student_id is not None and sid != student_id:
                continue
            if topic is not None and stored_topic != topic:
                continue
            rows.append(dict(row))
        return _Result(data=rows)


_COLUMN_TOPICS = {
    "mastery_phishing": "Phishing",
    "mastery_smishing": "Smishing",
    "mastery_vishing": "Vishing",
    "mastery_pretexting": "Pretexting",
    "mastery_baiting": "Baiting",
}
_MODULE_COLUMNS = {
    "mod_01": "mastery_phishing",
    "mod_02": "mastery_smishing",
    "mod_03": "mastery_vishing",
    "mod_04": "mastery_pretexting",
    "mod_05": "mastery_baiting",
}


def _flag_done(value) -> bool:
    """The migration's falsy set: false, null, 0, "", {}, []."""
    return value not in (False, None, 0, "", {}, [])


def _same_number(stored, expected) -> bool:
    """SQL `is not distinct from` on numerics: exact, and null only equals null."""
    if stored is None or expected is None:
        return stored is None and expected is None
    return float(stored) == float(expected)


def _restricted(row: dict) -> bool:
    return str(row.get("status") or "").strip().lower() in ("inactive", "archived")


def _write_bkt_rows(store, student_id: str, values: dict[str, float]) -> None:
    rows = []
    for topic, value in values.items():
        row = {"student_id": student_id, "topic": topic, "probability_known": value}
        store.bkt_rows[(student_id, topic)] = dict(row)
        rows.append(row)
    store.upserts.setdefault("bkt_records", []).append(rows)


def _emulate_write_mastery(store, params: dict) -> dict:
    """levelblue_write_mastery after its row lock. A fake without a student row always matches."""
    mastery = params["p_mastery"]
    expected = params["p_expected"]
    if set(mastery) != set(expected) or not mastery or not set(mastery) <= set(_COLUMN_TOPICS):
        raise RuntimeError("22023 Invalid mastery keys")
    if any(not 0 <= float(value) <= 1 for value in mastery.values()):
        raise RuntimeError("22023 Mastery value out of range")
    row = getattr(store, "student_row", None)
    if row is not None:
        if _restricted(row):
            return {"status": "restricted"}
        flags = row.get("module_pretests") if isinstance(row.get("module_pretests"), dict) else {}
        if any(_flag_done(flags.get(module_id)) for module_id in params["p_incomplete_modules"] if module_id in flags):
            return {"status": "conflict", "reason": "pretest_completed"}
        for column, seen in expected.items():
            if not _same_number(row.get(column), seen):
                return {"status": "conflict", "reason": "mastery_changed"}
        row.update(mastery)
    _write_bkt_rows(store, params["p_student"], {_COLUMN_TOPICS[c]: v for c, v in mastery.items()})
    return {"status": "ok"}


def _emulate_record_pretest(store, params: dict) -> dict:
    module_id = params["p_module"]
    column = _MODULE_COLUMNS.get(module_id)
    probability = params["p_mastery"]
    pre = params["p_pre"]
    if (
        column is None
        or probability is None
        or not 0 <= probability <= 1
        or (module_id == "mod_01") != (pre is not None)
        or (pre is not None and not 0 <= pre <= 100)
    ):
        raise RuntimeError("22023 Invalid pretest result")
    if getattr(store, "student_row", None) is None:
        store.student_row = {"id": params["p_student"], "module_pretests": {}}
    row = store.student_row
    if _restricted(row):
        return {"status": "restricted"}
    flags = row.get("module_pretests") if isinstance(row.get("module_pretests"), dict) else {}
    if module_id in flags and _flag_done(flags[module_id]):
        return {"status": "already_completed"}
    if not _same_number(row.get(column), params["p_expected_prior"]):
        return {"status": "prior_changed"}
    flags = dict(flags, **{module_id: True})
    row["module_pretests"] = flags
    row[column] = probability
    if module_id == "mod_01":
        row["pre"] = pre
    _write_bkt_rows(store, params["p_student"], {_COLUMN_TOPICS[column]: probability})
    return {"status": "ok", "completed_modules": sorted(k for k, v in flags.items() if _flag_done(v))}


class FakeRpc:
    def __init__(self, store, name: str, params: dict):
        self._store = store
        self._name = name
        self._params = params

    def execute(self):
        store = self._store
        label = f"rpc:{self._name}"
        store.executes.append(label)
        store.rpcs.append((self._name, copy.deepcopy(self._params)))
        if label in store.fail:
            raise RuntimeError(f"supabase {label} failed: secret-token")
        if (label, store.executes.count(label)) in store.fail_nth:
            raise RuntimeError(f"supabase {label} #{store.executes.count(label)} failed: secret-token")
        hook = getattr(store, "before_rpc", None)
        if hook is not None:
            hook(self._name)
        if self._name == "levelblue_write_mastery":
            hook = getattr(store, "before_mastery_update", None)
            if hook is not None:
                hook()
            return _Result(data=_emulate_write_mastery(store, self._params))
        if self._name == "levelblue_record_pretest_result":
            return _Result(data=_emulate_record_pretest(store, self._params))
        return _Result(data=None)


class FakeSupabase:
    def __init__(self, fail=None, fail_nth=None):
        self.fail = set(fail or ())
        self.fail_nth = set(fail_nth or ())
        self.bkt_rows = {}
        self.executes: list[str] = []
        self.updates: dict[str, list] = {}
        self.upserts: dict[str, list] = {}
        self.rpcs: list[tuple[str, dict]] = []
        self.save_rows = [{"payload": {}}]

    def table(self, name: str) -> FakeQuery:
        return FakeQuery(self, name)

    def rpc(self, name: str, params: dict) -> FakeRpc:
        return FakeRpc(self, name, params)


def _mastery_writes(fake) -> list[dict]:
    return [params["p_mastery"] for name, params in fake.rpcs if name == "levelblue_write_mastery"]


class StatefulSaveQuery(FakeQuery):
    """A successful player_saves upsert is what the next progress read returns."""

    def execute(self):
        result = super().execute()
        if self._table == "player_saves" and isinstance(self._pending_upsert, dict):
            self._store.save_rows = [{"payload": copy.deepcopy(self._pending_upsert["payload"])}]
        return result


class StatefulSupabase(FakeSupabase):
    def table(self, name: str) -> StatefulSaveQuery:
        return StatefulSaveQuery(self, name)


class ConcurrencyQuery(StatefulSaveQuery):
    """Student mastery writes succeed only when the guarded values still match."""

    def execute(self):
        if (
            self._table == "students"
            and isinstance(self._update, dict)
            and any(str(key).startswith("mastery_") for key in self._update)
        ):
            hook = getattr(self._store, "before_mastery_update", None)
            if hook is not None:
                hook()
            self._store.executes.append(self._table)
            if not self._student_filters_match():
                return _Result(data=[])
            self._store.student_row.update(self._update)
            return _Result(data=[dict(self._store.student_row)])
        if self._table == "bkt_records" and self._pending_upsert is None and (
            self._update is not None or self._insert is not None
        ):
            hook = getattr(self._store, "before_bkt_write", None)
            if hook is not None:
                hook()
        return super().execute()

    def _student_filters_match(self) -> bool:
        row = self._store.student_row
        for column, expected in self._eqs.items():
            actual = row.get(column)
            if column == "id":
                if actual != expected:
                    return False
                continue
            try:
                if actual is None or abs(float(actual) - float(expected)) > 1e-6:
                    return False
            except (TypeError, ValueError):
                return False
        for column in self._isnull:
            if row.get(column) is not None:
                return False
        for column, wanted, negate in self._contains_all:
            current = row.get(column) or {}
            if not isinstance(current, dict):
                current = {}
            contained = all(current.get(key) == value for key, value in wanted.items())
            if negate and contained:
                return False
            if not negate and not contained:
                return False
        return True


class ConcurrencySupabase(StatefulSupabase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.student_row: dict = {}
        self.before_mastery_update = None
        self.before_bkt_write = None
        self.inserts: dict = {}

    def table(self, name: str) -> ConcurrencyQuery:
        return ConcurrencyQuery(self, name)


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

    def test_mastery_is_one_atomic_call_with_the_read_as_expected(self):
        fake = FakeSupabase()
        self.assertTrue(self._run(fake).ok)
        self.assertEqual(fake.rpcs, [("levelblue_write_mastery", {
            "p_student": "stu-1",
            "p_mastery": {"mastery_phishing": 0.42, "mastery_smishing": 0.55},
            "p_expected": {"mastery_phishing": None, "mastery_smishing": None},
            "p_incomplete_modules": ["mod_01", "mod_02", "mod_03", "mod_04", "mod_05"],
        })])
        self.assertNotIn("bkt_records", fake.executes)
        self.assertEqual(len(fake.updates.get("students", [])), 1)
        self.assertFalse(any(k.startswith("mastery_") for k in fake.updates["students"][0]))

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

    def test_mastery_write_failure_raises_non_2xx_before_the_save_blob(self):
        fake = FakeSupabase(fail={"rpc:levelblue_write_mastery"})
        with self.assertRaises(HTTPException) as ctx:
            self._run(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")
        self.assertNotIn("secret-token", str(ctx.exception.detail))
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.bkt_rows, {})

    def test_lock_timeout_returns_503_and_keeps_the_upload_pending(self):
        fake = FakeSupabase()

        def busy(name):
            if name == "levelblue_write_mastery":
                raise RuntimeError("canceling statement due to lock timeout 55P03")

        fake.before_rpc = busy
        with patch("app.services.database_diagnostics._last_event_at", {}), \
                patch("app.services.database_diagnostics.supabase", fake):
            with self.assertRaises(HTTPException) as ctx:
                self._run(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(ctx.exception.detail, "Progress sync is busy. Your progress is still saved on this device and will retry.")
        self.assertNotIn("player_saves", fake.upserts)
        events = [params for name, params in fake.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual([event["p_code"] for event in events], ["mastery-lock-timeout"])
        self.assertNotIn("stu-1", str(events))

    def test_restricted_or_missing_student_at_write_time_is_not_a_conflict(self):
        for outcome, code in (("restricted", status.HTTP_403_FORBIDDEN), ("not_found", status.HTTP_404_NOT_FOUND)):
            with self.subTest(outcome=outcome):
        fake = FakeSupabase()
                with patch(f"{__name__}._emulate_write_mastery", return_value={"status": outcome}):
                    with self.assertRaises(HTTPException) as ctx:
        self._run(fake)
                self.assertEqual(ctx.exception.status_code, code)
                self.assertEqual(len(_mastery_writes(fake)), 1)
                self.assertNotIn("player_saves", fake.upserts)

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

    def _sync(self, fake: FakeSupabase, payload: ProgressSyncRequest):
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", payload)

    def test_new_student_without_evidence_creates_no_bkt_rows(self):
        fake = FakeSupabase()
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertNotIn("bkt_records", fake.upserts)
        stored = fake.upserts["player_saves"][0]["payload"]["mastery_matrix"]
        self.assertEqual(stored, {})
        mastery_updates = [row for row in fake.updates.get("students", []) if any(key.startswith("mastery_") for key in row)]
        self.assertEqual(mastery_updates, [])

    def test_one_assessed_topic_does_not_record_other_priors(self):
        fake = FakeSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {
                    "phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10,
                },
            }
        }]
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.61, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10},
            learning_evidence={"topics": {"phishing": 4}, "responses": 4},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        matrix = fake.upserts["player_saves"][0]["payload"]["mastery_matrix"]
        self.assertEqual(set(matrix), {"phishing"})
        self.assertAlmostEqual(matrix["phishing"], 0.61)
        self.assertEqual({topic for _sid, topic in fake.bkt_rows}, {"Phishing"})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.61)
        self.assertNotIn(("stu-1", "Smishing"), fake.bkt_rows)

    def test_legacy_default_priors_are_not_recorded_as_evidence(self):
        fake = FakeSupabase()
        fake.bkt_rows[("stu-1", "Vishing")] = {
            "student_id": "stu-1", "topic": "Vishing", "probability_known": 0.10,
        }
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {
                    "phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10,
                },
            }
        }]
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertNotIn("bkt_records", fake.upserts)
        self.assertEqual(fake.upserts["player_saves"][0]["payload"]["mastery_matrix"], {})
        # The historical row is intentionally left for a separate review.
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Vishing")]["probability_known"], 0.10)

    def test_stored_evidence_keeps_assessed_prior(self):
        fake = FakeSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {"phishing": 0.50, "pretexting": 0.10},
                "learning_evidence": {"topics": {"pretexting": 2}, "responses": 2},
            }
        }]
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.55})
        self.assertTrue(self._sync(fake, payload).ok)
        matrix = fake.upserts["player_saves"][0]["payload"]["mastery_matrix"]
        self.assertAlmostEqual(matrix["phishing"], 0.55)
        self.assertAlmostEqual(matrix["pretexting"], 0.10)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Pretexting")]["probability_known"], 0.10)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.55)

    def test_repeated_sync_does_not_refresh_unassessed_priors(self):
        fake = FakeSupabase()
        legacy = {
            "phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10,
        }
        fake.save_rows = [{"payload": {"mastery_matrix": dict(legacy)}}]
        payload = ProgressSyncRequest(
            mastery_matrix=dict(legacy, phishing=0.42),
            learning_evidence={"topics": {"phishing": 3}, "responses": 3},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertEqual(_mastery_writes(fake), [{"mastery_phishing": 0.42}, {"mastery_phishing": 0.42}])
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)

    def test_offline_log_keeps_reconciled_topic_and_drops_other_priors(self):
        fake = FakeSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {
                    "phishing": 0.10, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10,
                },
            }
        }]
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.42, "smishing": 0.10, "vishing": 0.10, "pretexting": 0.10, "baiting": 0.10},
            learning_evidence={"topics": {"phishing": 1}, "responses": 1},
            unconfirmed_bkt_log=[{
                "skill": "smishing", "op": "update", "correct": False, "prior": 0.20, "posterior": 0.10,
            }],
        )
        self.assertTrue(self._sync(fake, payload).ok)
        matrix = fake.upserts["player_saves"][0]["payload"]["mastery_matrix"]
        self.assertEqual(set(matrix), {"phishing", "smishing"})
        self.assertAlmostEqual(matrix["smishing"], 0.10)
        self.assertEqual({topic for _sid, topic in fake.bkt_rows}, {"Phishing", "Smishing"})
        self.assertEqual(fake.upserts["player_saves"][0]["payload"]["unconfirmed_bkt_log"][0]["skill"], "smishing")

    def test_incoming_default_does_not_overwrite_assessed_cloud_mastery(self):
        fake = StatefulSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {"phishing": 0.80},
                "learning_evidence": {
                    "topics": {"phishing": 2},
                    "responses": 2,
                    "sessions": 1,
                    "first_at": 1700000000,
                    "last_at": 1700000100,
                },
                "credits": 40,
                "unconfirmed_bkt_log": [{
                    "id": "already-acked", "skill": "phishing", "op": "update", "posterior": 0.80,
                }],
            }
        }]
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.10}, credits=40)
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertAlmostEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["phishing"], 0.80)
        self.assertTrue(self._sync(fake, payload).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.80)
        self.assertEqual(stored["learning_evidence"], {
            "topics": {"phishing": 2},
            "responses": 2,
            "sessions": 1,
            "first_at": 1700000000,
            "last_at": 1700000100,
        })
        self.assertEqual(stored["credits"], 40)
        self.assertNotIn("unconfirmed_bkt_log", stored)
        self.assertNotIn("learning_events", stored)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.80)

    def test_repeated_sync_preserves_assessment_provenance(self):
        fake = StatefulSupabase()
        acknowledged = [{
            "id": "event-1", "skill": "pretexting", "op": "update", "posterior": 0.10,
        }]
        first = ProgressSyncRequest(
            mastery_matrix={"pretexting": 0.10},
            learning_evidence={
                "topics": {"pretexting": 2},
                "responses": 2,
                "sessions": 1,
                "first_at": 1700000000,
                "last_at": 1700000100,
            },
            pretest_baselines={"mod_04": {"correct": 1, "total": 4}},
            practice_responses={"prac-1": {"module_id": "mod_04", "skill": "pretexting", "correct": False}},
            credits=7,
            unconfirmed_bkt_log=acknowledged,
        )
        self.assertTrue(self._sync(fake, first).ok)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Pretexting")]["probability_known"], 0.10)
        second = ProgressSyncRequest(
            mastery_matrix={"pretexting": 0.10, "phishing": 0.44},
            credits=9,
        )
        self.assertTrue(self._sync(fake, second).ok)
        third = ProgressSyncRequest(mastery_matrix={"pretexting": 0.10, "phishing": 0.44}, credits=9)
        self.assertTrue(self._sync(fake, third).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(stored["mastery_matrix"]["pretexting"], 0.10)
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.44)
        self.assertEqual(stored["learning_evidence"], {
            "topics": {"pretexting": 2},
            "responses": 2,
            "sessions": 1,
            "first_at": 1700000000,
            "last_at": 1700000100,
        })
        self.assertEqual(stored["pretest_baselines"], {"mod_04": {"correct": 1, "total": 4}})
        self.assertEqual(stored["practice_responses"], {
            "prac-1": {"module_id": "mod_04", "skill": "pretexting", "correct": False},
        })
        self.assertNotIn("unconfirmed_bkt_log", stored)
        self.assertNotIn("learning_events", stored)
        self.assertEqual(stored["credits"], 9)
        self.assertEqual(len(fake.bkt_rows), 2)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Pretexting")]["probability_known"], 0.10)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.44)

    def test_merged_timestamps_stay_ordered(self):
        fake = StatefulSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {"pretexting": 0.10},
                "learning_evidence": {
                    "topics": {"pretexting": 2},
                    "responses": 2,
                    "sessions": 1,
                    "first_at": 1700000000,
                    "last_at": 1700000100,
                },
            }
        }]
        payload = ProgressSyncRequest(
            mastery_matrix={"pretexting": 0.10, "phishing": 0.40},
            learning_evidence={
                "topics": {"phishing": 4},
                "responses": 4,
                "sessions": 1,
                "first_at": 1700000200,
            },
        )
        self.assertTrue(self._sync(fake, payload).ok)
        evidence = fake.save_rows[0]["payload"]["learning_evidence"]
        self.assertEqual(evidence["first_at"], 1700000000)
        self.assertEqual(evidence["last_at"], 1700000100)
        self.assertLessEqual(evidence["first_at"], evidence["last_at"])
        self.assertNotIn("unconfirmed_bkt_log", fake.save_rows[0]["payload"])
        self.assertNotIn("learning_events", fake.save_rows[0]["payload"])

    def test_merged_response_total_matches_topic_counts(self):
        fake = StatefulSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {"pretexting": 0.10},
                "learning_evidence": {
                    "topics": {"pretexting": 2},
                    "responses": 2,
                    "sessions": 1,
                    "first_at": 1700000000,
                    "last_at": 1700000100,
                },
            }
        }]
        payload = ProgressSyncRequest(
            mastery_matrix={"pretexting": 0.10, "phishing": 0.40},
            learning_evidence={
                "topics": {"phishing": 4},
                "responses": 4,
                "sessions": 1,
                "first_at": 1700000200,
                "last_at": 1700000300,
            },
        )
        self.assertTrue(self._sync(fake, payload).ok)
        evidence = fake.save_rows[0]["payload"]["learning_evidence"]
        self.assertEqual(evidence["topics"], {"phishing": 4, "pretexting": 2})
        self.assertEqual(evidence["responses"], 6)

    def test_preserved_evidence_does_not_replace_newer_metadata(self):
        fake = StatefulSupabase()
        fake.save_rows = [{
            "payload": {
                "mastery_matrix": {"pretexting": 0.10, "phishing": 0.40},
                "learning_evidence": {
                    "topics": {"pretexting": 2, "phishing": 1},
                    "responses": 3,
                    "sessions": 1,
                    "first_at": 1700000000,
                    "last_at": 1700000100,
                },
            }
        }]
        payload = ProgressSyncRequest(
            mastery_matrix={"pretexting": 0.10, "phishing": 0.52},
            learning_evidence={
                "topics": {"phishing": 4},
                "responses": 4,
                "sessions": 2,
                "first_at": 1780000000,
                "last_at": 1780000500,
            },
        )
        self.assertTrue(self._sync(fake, payload).ok)
        evidence = fake.save_rows[0]["payload"]["learning_evidence"]
        self.assertEqual(evidence["topics"], {"phishing": 4, "pretexting": 2})
        self.assertEqual(evidence["first_at"], 1700000000)
        self.assertEqual(evidence["last_at"], 1780000500)
        self.assertEqual(evidence["sessions"], 2)
        self.assertEqual(evidence["responses"], 6)
        self.assertAlmostEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["pretexting"], 0.10)
        self.assertAlmostEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["phishing"], 0.52)


class LegacySchemaQuery(FakeQuery):
    """students has no module_pretests column, as in the legacy schema."""

    def __init__(self, store, table):
        super().__init__(store, table)
        self._update = None

    def update(self, payload):
        self._update = payload
        return super().update(payload)

    def delete(self):
        self._store.deletes.append(self._table)
        return self

    def execute(self):
        if self._table == "students" and isinstance(self._update, dict) and "module_pretests" in self._update:
            self._store.executes.append(self._table)
            raise RuntimeError('column "module_pretests" of relation "students" does not exist')
        result = super().execute()
        if self._table == "students" and isinstance(self._update, dict):
            self._store.student_row.update(self._update)
        if self._table == "player_saves" and isinstance(self._pending_upsert, dict):
            self._store.save_rows = [{"payload": self._pending_upsert["payload"]}]
        return result


class LegacySchemaSupabase(FakeSupabase):
    """Stateful: later reads see every write that succeeded."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.student_row = {"id": "stu-1"}
        self.deletes: list[str] = []

    def table(self, name: str) -> FakeQuery:
        return LegacySchemaQuery(self, name)


class _ColumnPretestCases:
    EXISTING = {"mastery_matrix": {"phishing": 0.8}, "lesson_progress": {"mod_01": 7}, "credits": 50}

    def _submit(self, fake, stale_row: dict | None = None, reads: list[dict] | None = None):
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload
        from app.services.pretest_service import submit_pretest

        bank = questions_for_module("mod_01")
        # Every third answer wrong: 0.9202 once, 0.99 if re-applied. Patterns that hit the
        # 0.01/0.99 clamp mid-sequence erase the prior and would hide a second application.
        answers = [
            PretestAnswerPayload(id=q["id"], answer=q["answer"] if i % 3 else (int(q["answer"]) + 1) % len(q["options"]))
            for i, q in enumerate(bank)
        ]
        queued = [dict(row) for row in reads] if reads is not None else None

        def fetch(_sid):
            if queued:
                return queued.pop(0)
            return dict(stale_row if stale_row is not None else fake.student_row)

        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", side_effect=fetch),
        ):
            return submit_pretest("stu-1", "mod_01", answers)

    def _fake(self, **kwargs):
        fake = ColumnSchemaSupabase(**kwargs)
        fake.save_rows = [{"payload": dict(self.EXISTING)}]
        return fake

    def _expected_mod_01(self, prior: float = 0) -> float:
        from app.data.pretest_questions import questions_for_module
        from app.services.bkt_service import initial_pl, update_pl_diagnostic

        expected = initial_pl(prior)
        for i, question in enumerate(questions_for_module("mod_01")):
            if question["topic"] == "Phishing":
                expected = round(update_pl_diagnostic(expected, bool(i % 3)), 4)
        return expected

    def test_failed_save_read_aborts_before_any_write(self):
        fake = self._fake(fail={"player_saves"})
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(fake.rpcs, [])
        self.assertNotIn("students", fake.updates)
        self.assertEqual(fake.bkt_rows, {})

    def test_failed_result_write_is_reported_without_details_and_logged(self):
        fake = self._fake(fail={"rpc:levelblue_record_pretest_result"})
        with patch("app.services.database_diagnostics._last_event_at", {}), \
                patch("app.services.database_diagnostics.supabase", fake):
            with self.assertRaises(HTTPException) as ctx:
                self._submit(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")
        self.assertNotIn("secret-token", str(ctx.exception.detail))
        self.assertEqual(fake.student_row, {"id": "stu-1", "module_pretests": {}})
        self.assertEqual(fake.bkt_rows, {})
        events = [params for name, params in fake.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual([(e["p_code"], e["p_status"]) for e in events], [("pretest-write-failed", 500)])
        self.assertNotIn("stu-1", str(events))


class ColumnSchemaQuery(LegacySchemaQuery):
    """students.module_pretests exists (migration 20261031 applied): one conditional update."""

    def execute(self):
        if self._table != "students" or not isinstance(self._update, dict):
            return FakeQuery.execute(self)
        self._store.executes.append(self._table)
        if ("students", self._store.executes.count("students")) in self._store.fail_nth:
            raise RuntimeError("supabase students failed: secret-token")
        row = self._store.student_row
        condition = getattr(self, "_contains", None)
        if condition is not None:
            column, wanted, negate = condition
            current = row.get(column, {})
            contained = all(current.get(key) == value for key, value in wanted.items())
            if contained == negate:
                return _Result(data=[])
        row.update(self._update)
        return _Result(data=[dict(row)])


class ColumnSchemaSupabase(LegacySchemaSupabase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.student_row = {"id": "stu-1", "module_pretests": {}}

    def table(self, name: str) -> FakeQuery:
        return ColumnSchemaQuery(self, name)


class ColumnPretestTest(_ColumnPretestCases, unittest.TestCase):
    """students.module_pretests exists: the result is one atomic database call."""

    def test_submit_is_one_atomic_write_and_leaves_the_save_alone(self):
        fake = self._fake()
        result = self._submit(fake)
        expected = self._expected_mod_01()
        self.assertEqual(fake.rpcs, [("levelblue_record_pretest_result", {
            "p_student": "stu-1",
            "p_module": "mod_01",
            "p_mastery": expected,
            "p_pre": result.pre,
            "p_expected_prior": None,
        })])
        self.assertNotIn("students", fake.executes)
        self.assertNotIn("bkt_records", fake.executes)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(fake.student_row["mastery_phishing"], expected)
        self.assertEqual(fake.student_row["pre"], result.pre)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], expected)
        self.assertEqual(result.completedModuleIds, ["mod_01"])
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.save_rows[0]["payload"], self.EXISTING)
        self.assertNotIn("status", fake.student_row)

    def test_retry_after_success_is_rejected_without_reapplying(self):
        fake = self._fake()
        self._submit(fake)
        first = dict(fake.student_row)
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row, first)

    def test_simultaneous_submissions_apply_once(self):
        fake = self._fake()
        before = dict(fake.student_row)
        self._submit(fake, stale_row=before)
        winner = dict(fake.student_row)
        # The second request read the row before the first one committed.
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake, stale_row=before)
        self.assertEqual(ctx.exception.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row, winner)
        self.assertEqual(len(fake.upserts.get("bkt_records", [])), 1)

    def test_failed_write_leaves_row_unchanged_and_retry_applies_once(self):
        expected_fake = self._fake()
        self._submit(expected_fake)
        fake = self._fake(fail_nth={("rpc:levelblue_record_pretest_result", 1)})
        with self.assertRaises(HTTPException):
            self._submit(fake)
        self.assertEqual(fake.student_row, {"id": "stu-1", "module_pretests": {}})
        self._submit(fake)
        self.assertEqual(fake.student_row, expected_fake.student_row)

    def test_empty_column_does_not_adopt_blob_only_flags(self):
        fake = self._fake()
        fake.save_rows = [{"payload": dict(self.EXISTING, module_pretests=["mod_02"])}]
        self._submit(fake)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertNotIn("player_saves", fake.upserts)

    def test_column_flag_blocks_resubmission_without_reading_the_save(self):
        fake = self._fake(fail={"player_saves"})
        fake.student_row["module_pretests"] = {"mod_01": True}
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")

    def test_login_reads_completion_from_the_column(self):
        from app.services import auth_service

        fake = self._fake(fail={"player_saves"})
        with patch.object(auth_service, "supabase", fake):
            ids = auth_service._completed_module_ids({"id": "stu-1", "module_pretests": {"mod_01": True, "mod_03": True}})
        self.assertEqual(ids, ["mod_01", "mod_03"])
        self.assertNotIn("player_saves", fake.executes)

    def test_practice_committed_after_the_read_is_regraded_once_from_that_prior(self):
        fake = self._fake()
        stale = dict(fake.student_row)
        fake.student_row["mastery_phishing"] = 0.55
        result = self._submit(fake, reads=[stale, dict(fake.student_row)])
        expected = self._expected_mod_01(prior=0.55)
        writes = [params for name, params in fake.rpcs if name == "levelblue_record_pretest_result"]
        self.assertEqual([w["p_expected_prior"] for w in writes], [None, 0.55])
        self.assertEqual(writes[1]["p_mastery"], expected)
        self.assertEqual(fake.student_row["mastery_phishing"], expected)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], expected)
        self.assertEqual(result.mastery.Phishing, expected)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})

    def test_prior_changing_twice_returns_503_and_writes_nothing(self):
        fake = self._fake()
        stale = dict(fake.student_row)
        fake.student_row["mastery_phishing"] = 0.55
        before = dict(fake.student_row)
        with patch("app.services.database_diagnostics._last_event_at", {}), \
                patch("app.services.database_diagnostics.supabase", fake):
            with self.assertRaises(HTTPException) as ctx:
                self._submit(fake, reads=[stale, stale])
        self.assertEqual(ctx.exception.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertNotEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row, before)
        self.assertEqual(fake.bkt_rows, {})
        events = [params for name, params in fake.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual([(e["p_code"], e["p_status"]) for e in events], [("pretest-write-failed", 503)])

    def test_lock_timeout_returns_503_and_the_retry_applies_once(self):
        fake = self._fake()

        def busy(name):
            if name == "levelblue_record_pretest_result":
                fake.before_rpc = None
                raise RuntimeError("canceling statement due to lock timeout 55P03")

        fake.before_rpc = busy
        with patch("app.services.database_diagnostics._last_event_at", {}), \
                patch("app.services.database_diagnostics.supabase", fake):
            with self.assertRaises(HTTPException) as ctx:
                self._submit(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(fake.student_row, {"id": "stu-1", "module_pretests": {}})
        events = [params for name, params in fake.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual([e["p_code"] for e in events], ["mastery-lock-timeout"])
        self._submit(fake)
        self.assertEqual(fake.student_row["mastery_phishing"], self._expected_mod_01())
        self.assertEqual(len(fake.upserts["bkt_records"]), 1)


class AssessedTopicPretestStatusTest(unittest.TestCase):
    """Evidenced posteriors still classify At Risk and On Track. That label is not stored."""

    def _submit(self, row: dict, *, correct: bool = True, pattern: list[bool] | None = None, save_payload: dict | None = None):
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload
        from app.services.bkt_service import MASTERY_COLUMNS, average_pl, initial_pl, update_pl_diagnostic
        from app.services.pretest_service import submit_pretest

        fake = ColumnSchemaSupabase()
        fake.student_row = {"id": "stu-1", "module_pretests": {}}
        fake.student_row.update(row)
        fake.save_rows = [{"payload": dict(save_payload or {})}]
        bank = questions_for_module("mod_01")
        if pattern is not None:
            self.assertEqual(len(pattern), len(bank))
        answers: list[PretestAnswerPayload] = []
        expected = initial_pl(float(fake.student_row.get("mastery_phishing") or 0))
        correct_count = 0
        for index, question in enumerate(bank):
            is_correct = pattern[index] if pattern is not None else correct
            answer = question["answer"] if is_correct else (int(question["answer"]) + 1) % len(question["options"])
            answers.append(PretestAnswerPayload(id=question["id"], answer=answer))
            if is_correct:
                correct_count += 1
            expected = round(update_pl_diagnostic(expected, is_correct), 4)
        before = dict(fake.student_row)
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student",
                  side_effect=lambda _sid, snapshot=before: dict(snapshot)),
        ):
            result = submit_pretest("stu-1", "mod_01", answers)
        filled = {
            name: initial_pl(float(before.get(column) or 0))
            for name, column in MASTERY_COLUMNS.items()
        }
        filled["Phishing"] = expected
        return fake, result, expected, correct_count, len(bank), round(average_pl(filled), 4)

    def _assert_preserved_result(self, fake, result, expected: float, correct_count: int, total: int, prior_average: float) -> None:
        self.assertEqual(result.pre, int(round((correct_count / total) * 100)))
        self.assertEqual(fake.student_row["pre"], result.pre)
        self.assertTrue(result.preTestCompleted)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(result.completedModuleIds, ["mod_01"])
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], expected)
        self.assertAlmostEqual(result.mastery.Phishing, expected)
        self.assertEqual(result.averagePl, prior_average)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], expected)
        for column in ("mastery_smishing", "mastery_vishing", "mastery_pretexting", "mastery_baiting"):
            self.assertNotIn(column, fake.student_row)

    def test_one_assessed_topic_above_threshold_ignores_unassessed_priors(self):
        from app.services.pretest_service import assessed_topic_status

        fake, result, expected, correct_count, total, prior_average = self._submit({})
        self.assertGreater(expected, 0.40)
        self.assertNotIn("status", fake.student_row)
        self.assertEqual(assessed_topic_status({}, "Phishing", expected), "On Track")
        self._assert_preserved_result(fake, result, expected, correct_count, total, prior_average)

    def test_one_assessed_topic_below_threshold_is_at_risk(self):
        from app.services.pretest_service import assessed_topic_status

        fake, result, expected, correct_count, total, prior_average = self._submit({}, correct=False)
        self.assertLess(expected, 0.40)
        self.assertNotIn("status", fake.student_row)
        self.assertEqual(assessed_topic_status({}, "Phishing", expected), "At Risk")
        self._assert_preserved_result(fake, result, expected, correct_count, total, prior_average)

    def test_unevidenced_historical_priors_do_not_lower_an_assessed_topic(self):
        from app.services.pretest_service import assessed_topic_status

        priors = {
            "mastery_phishing": 0.10,
            "mastery_smishing": 0.10,
            "mastery_vishing": 0.10,
            "mastery_pretexting": 0.10,
            "mastery_baiting": 0.10,
        }
        self.assertEqual(assessed_topic_status(priors, "Phishing", 0.80), "On Track")
        self.assertEqual(assessed_topic_status({"mastery_smishing": 0.80}, "Phishing", 0.10), "At Risk")
        fake, result, expected, _correct_count, _total, prior_average = self._submit({
            "mastery_smishing": 0.10,
            "mastery_vishing": 0.10,
            "mastery_pretexting": 0.10,
            "mastery_baiting": 0.10,
        })
        self.assertGreater(expected, 0.40)
        self.assertNotIn("status", fake.student_row)
        self.assertEqual(assessed_topic_status(fake.student_row, "Phishing", expected), "On Track")
        self.assertEqual(result.averagePl, prior_average)
        self.assertEqual(fake.student_row["mastery_smishing"], 0.10)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertNotIn(("stu-1", "Smishing"), fake.bkt_rows)

    def test_genuine_assessed_0_10_counts_and_a_current_pretest_needs_no_saved_evidence(self):
        from app.services.pretest_service import assessed_topic_status

        evidenced = {"practice_responses": {"q1": {"skill": "phishing", "module_id": "mod_01", "correct": False}}}
        self.assertEqual(assessed_topic_status({}, "Phishing", 0.10), "At Risk")
        self.assertEqual(assessed_topic_status({"mastery_phishing": 0.10}, "Smishing", 0.50), "On Track")
        self.assertEqual(
            assessed_topic_status({"mastery_phishing": 0.10}, "Smishing", 0.50, evidenced),
            "At Risk",
        )
        self.assertEqual(
            assessed_topic_status({"mastery_phishing": 0.10}, "Smishing", 0.90, evidenced),
            "On Track",
        )
        # This answer pattern lands between 0.40 and 0.70, so one evidenced 0.10 changes the label.
        pattern = [bool((5823 >> index) & 1) for index in range(15)]
        save = {"learning_evidence": {"topics": {"smishing": 1}, "responses": 1, "sessions": 1, "first_at": 1, "last_at": 1}}
        fake, _result, expected, _correct_count, _total, prior_average = self._submit(
            {
                "mastery_smishing": 0.10,
                "mastery_vishing": 0.10,
                "mastery_pretexting": 0.10,
                "mastery_baiting": 0.10,
            },
            pattern=pattern,
            save_payload=save,
        )
        alone = "At Risk" if expected < 0.40 else "On Track"
        with_evidence = "At Risk" if (expected + 0.10) / 2 < 0.40 else "On Track"
        self.assertNotEqual(alone, with_evidence)
        self.assertEqual(assessed_topic_status(fake.student_row, "Phishing", expected, save), with_evidence)
        self.assertEqual(assessed_topic_status(fake.student_row, "Phishing", expected, save), "At Risk")
        self.assertNotIn("status", fake.student_row)
        self.assertEqual(_result.averagePl, prior_average)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})

    def test_threshold_boundary_uses_existing_0_40_cut(self):
        from app.services.pretest_service import assessed_topic_status

        self.assertEqual(assessed_topic_status({}, "Phishing", 0.40), "On Track")
        self.assertEqual(assessed_topic_status({}, "Phishing", 0.3999), "At Risk")

    def test_no_valid_assessed_topic_does_not_invent_status(self):
        from app.services.pretest_service import assessed_topic_status

        evidenced = {"learning_evidence": {"topics": {"smishing": 2}, "responses": 2}}
        self.assertIsNone(assessed_topic_status({}, "Phishing", 0))
        self.assertIsNone(assessed_topic_status({"mastery_smishing": 0, "status": "Needs Review"}, "Phishing", float("nan")))
        self.assertIsNone(assessed_topic_status({
            "mastery_smishing": "bad",
            "mastery_vishing": float("inf"),
            "mastery_pretexting": True,
            "mastery_baiting": -0.2,
        }, "Phishing", None, evidenced))
        self.assertEqual(
            assessed_topic_status({"mastery_smishing": "bad"}, "Phishing", 0.50, evidenced),
            "On Track",
        )

    def test_sparse_sync_keeps_topic_evidence_used_by_status(self):
        from app.services.pretest_service import assessed_topic_status

        fake = StatefulSupabase()
        first = ProgressSyncRequest(
            mastery_matrix={"pretexting": 0.10},
            learning_evidence={
                "topics": {"pretexting": 2},
                "responses": 2,
                "sessions": 1,
                "first_at": 1700000000,
                "last_at": 1700000100,
            },
            pretest_baselines={"mod_04": {"correct": 1, "total": 4}},
            practice_responses={"prac-1": {"module_id": "mod_04", "skill": "pretexting", "correct": False}},
        )
        sparse = ProgressSyncRequest(mastery_matrix={"phishing": 0.10}, credits=1)
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", first).ok)
            self.assertTrue(sync_student_progress("stu-1", sparse).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertEqual(stored["learning_evidence"]["topics"], {"pretexting": 2})
        self.assertEqual(stored["pretest_baselines"], {"mod_04": {"correct": 1, "total": 4}})
        self.assertIn("prac-1", stored["practice_responses"])
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Pretexting")]["probability_known"], 0.10)
        columns = {
            "mastery_phishing": 0.10,
            "mastery_smishing": 0.10,
            "mastery_vishing": 0.10,
            "mastery_pretexting": 0.10,
            "mastery_baiting": 0.10,
        }
        self.assertEqual(assessed_topic_status(columns, "Phishing", 0.50, stored), "At Risk")
        self.assertEqual(assessed_topic_status(columns, "Phishing", 0.50), "On Track")

    def _answers(self):
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload

        bank = questions_for_module("mod_01")
        return [
            PretestAnswerPayload(id=question["id"], answer=question["answer"])
            for question in bank
        ]

    def _column_student(self, save_payload: dict, *, fail=None) -> ColumnSchemaSupabase:
        fake = ColumnSchemaSupabase(fail=fail)
        fake.student_row = {
            "id": "stu-1",
            "module_pretests": {"mod_02": True},
            "mastery_smishing": 0.10,
        }
        fake.save_rows = [{"payload": dict(save_payload)}]
        return fake

    def _submit_column(self, fake: ColumnSchemaSupabase, posterior: float = 0.50):
        from app.services.pretest_service import submit_pretest

        before = dict(fake.student_row)
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student",
                  side_effect=lambda _sid, snapshot=before: dict(snapshot)),
            patch("app.services.pretest_service.update_pl_diagnostic", return_value=posterior),
        ):
            return submit_pretest("stu-1", "mod_01", self._answers())

    def test_other_module_evidence_read_includes_assessed_0_10(self):
        evidence = {"pretest_baselines": {"mod_02": {"correct": 1, "total": 4}}}
        fake = self._column_student(evidence)
        from app.services.pretest_service import assessed_topic_status

        result = self._submit_column(fake, 0.50)
        self.assertNotIn("status", fake.student_row)
        self.assertEqual(
            assessed_topic_status({"mastery_smishing": 0.10}, "Phishing", 0.50, evidence),
            "At Risk",
        )
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.50)
        self.assertEqual(fake.student_row["mastery_smishing"], 0.10)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True, "mod_02": True})
        self.assertEqual(result.averagePl, 0.18)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.50)

    def test_evidence_read_failure_does_not_persist_status(self):
        evidence = {"pretest_baselines": {"mod_02": {"correct": 1, "total": 4}}}
        fake = self._column_student(evidence, fail={"player_saves"})
        before = dict(fake.student_row)
        with self.assertRaises(HTTPException) as ctx:
            self._submit_column(fake, 0.50)
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")
        self.assertNotIn("secret-token", str(ctx.exception.detail))
        self.assertEqual(fake.student_row, before)
        self.assertNotIn("status", fake.student_row)
        self.assertNotIn("mastery_phishing", fake.student_row)
        self.assertNotIn("students", fake.updates)
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.bkt_rows, {})
        self.assertEqual(fake.executes, ["player_saves"])

    def test_successful_empty_evidence_read_is_not_a_database_error(self):
        fake = self._column_student({})
        from app.services.pretest_service import assessed_topic_status

        result = self._submit_column(fake, 0.50)
        self.assertTrue(result.preTestCompleted)
        self.assertNotIn("status", fake.student_row)
        self.assertEqual(assessed_topic_status({"mastery_smishing": 0.10}, "Phishing", 0.50, {}), "On Track")
        self.assertEqual(fake.student_row["mastery_smishing"], 0.10)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.50)
        self.assertEqual(result.averagePl, 0.18)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})

    def test_completed_module_retry_rejects_before_evidence_read(self):
        fake = ColumnSchemaSupabase(fail={"player_saves"})
        fake.student_row = {
            "id": "stu-1",
            "module_pretests": {"mod_01": True},
            "mastery_phishing": 0.50,
            "status": "On Track",
        }
        before = dict(fake.student_row)
        from app.services.pretest_service import submit_pretest

        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student",
                  side_effect=lambda _sid: dict(before)),
        ):
        with self.assertRaises(HTTPException) as ctx:
                submit_pretest("stu-1", "mod_01", self._answers())
        self.assertEqual(ctx.exception.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row, before)
        self.assertEqual(fake.executes, [])
        self.assertEqual(fake.updates, {})
        self.assertEqual(fake.upserts, {})
        self.assertEqual(fake.bkt_rows, {})

    def test_retry_after_success_does_not_reapply_the_diagnostic(self):
        fake, _result, expected, _correct_count, _total, _prior_average = self._submit({})
        first = dict(fake.student_row)
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload
        from app.services.pretest_service import submit_pretest

        bank = questions_for_module("mod_01")
        answers = [
            PretestAnswerPayload(id=q["id"], answer=(int(q["answer"]) + 1) % len(q["options"]))
            for q in bank
        ]
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", side_effect=lambda _sid: dict(fake.student_row)),
        ):
            with self.assertRaises(HTTPException) as ctx:
                submit_pretest("stu-1", "mod_01", answers)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row, first)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], expected)
        self.assertEqual(len(fake.bkt_rows), 1)


class SparseLearningRecordSyncTest(unittest.TestCase):
    """Sparse uploads keep lesson history. Empty collections are not a reset."""

    HISTORY = {
        "mastery_matrix": {"phishing": 0.42},
        "lesson_progress": {"mod_01": 6},
        "completed_lessons": ["mod_01"],
        "lesson_quiz_responses": {"mod_01": {"mod01_q1": True}},
        "lesson_post_quiz_scores": {"mod_01": 22},
        "practice_responses": {
            "prac-1": {"module_id": "mod_01", "skill": "phishing", "correct": True},
        },
        "learning_evidence": {
            "topics": {"phishing": 6},
            "responses": 6,
            "sessions": 1,
            "first_at": 1700000000,
            "last_at": 1700000100,
        },
    }

    def _sync(self, fake: FakeSupabase, payload: ProgressSyncRequest):
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", payload)

    def _stored(self, fake: FakeSupabase) -> dict:
        return fake.save_rows[0]["payload"]

    def _assert_history(self, stored: dict, posterior: float) -> None:
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], posterior)
        self.assertEqual(stored["lesson_progress"], {"mod_01": 6})
        self.assertEqual(stored["completed_lessons"], ["mod_01"])
        self.assertEqual(stored["lesson_quiz_responses"], {"mod_01": {"mod01_q1": True}})
        self.assertEqual(stored["lesson_post_quiz_scores"], {"mod_01": 22})
        self.assertEqual(stored["practice_responses"], self.HISTORY["practice_responses"])
        self.assertEqual(stored["learning_evidence"], self.HISTORY["learning_evidence"])

    def test_a_full_snapshot_persists_educational_records(self):
        fake = StatefulSupabase()
        self.assertTrue(self._sync(fake, ProgressSyncRequest(**self.HISTORY)).ok)
        self._assert_history(self._stored(fake), 0.42)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)

    def test_b_unevidenced_prior_keeps_stored_history(self):
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": copy.deepcopy(self.HISTORY)}]
        omitted = ProgressSyncRequest(mastery_matrix={"phishing": 0.10})
        self.assertNotIn("lesson_progress", omitted.model_fields_set)
        self.assertNotIn("completed_lessons", omitted.model_fields_set)
        self.assertNotIn("lesson_quiz_responses", omitted.model_fields_set)
        self.assertTrue(self._sync(fake, omitted).ok)
        self._assert_history(self._stored(fake), 0.42)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)

    def test_c_new_posterior_keeps_omitted_answer_records(self):
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": copy.deepcopy(self.HISTORY)}]
        self.assertTrue(self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.62})).ok)
        self._assert_history(self._stored(fake), 0.62)
        self.assertEqual(self._stored(fake)["learning_evidence"]["topics"], {"phishing": 6})
        self.assertEqual(self._stored(fake)["learning_evidence"]["responses"], 6)
        self.assertEqual(len(self._stored(fake)["practice_responses"]), 1)
        self.assertEqual(len(fake.bkt_rows), 1)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.62)

    def test_d_repeated_snapshot_and_sparse_sync_do_not_duplicate(self):
        fake = StatefulSupabase()
        full = ProgressSyncRequest(**self.HISTORY)
        sparse = ProgressSyncRequest(mastery_matrix={"phishing": 0.62})
        self.assertTrue(self._sync(fake, full).ok)
        self.assertTrue(self._sync(fake, full).ok)
        self._assert_history(self._stored(fake), 0.42)
        self.assertTrue(self._sync(fake, sparse).ok)
        self.assertTrue(self._sync(fake, sparse).ok)
        self._assert_history(self._stored(fake), 0.62)
        self.assertEqual(len(fake.bkt_rows), 1)
        self.assertEqual(len(self._stored(fake)["completed_lessons"]), 1)
        self.assertEqual(len(self._stored(fake)["lesson_quiz_responses"]["mod_01"]), 1)
        self.assertEqual(len(self._stored(fake)["practice_responses"]), 1)

    def test_e_one_topic_update_preserves_the_other_four(self):
        skills = ("phishing", "smishing", "vishing", "pretexting", "baiting")
        modules = ("mod_01", "mod_02", "mod_03", "mod_04", "mod_05")
        history = {
            "mastery_matrix": {skill: 0.20 + (index / 10) for index, skill in enumerate(skills)},
            "lesson_progress": {module: index + 1 for index, module in enumerate(modules)},
            "completed_lessons": ["mod_01"],
            "lesson_quiz_responses": {module: {module + "_q1": index % 2 == 0} for index, module in enumerate(modules)},
            "lesson_post_quiz_scores": {module: 16 + index for index, module in enumerate(modules)},
            "practice_responses": {
                "prac-" + module: {"module_id": module, "skill": skills[index], "correct": index % 2 == 0}
                for index, module in enumerate(modules)
            },
            "learning_evidence": {
                "topics": {skill: index + 2 for index, skill in enumerate(skills)},
                "responses": 20,
                "sessions": 2,
                "first_at": 1700000000,
                "last_at": 1700000900,
            },
        }
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": copy.deepcopy(history)}]
        self.assertTrue(self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.70})).ok)
        stored = self._stored(fake)
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.70)
        for index, skill in enumerate(skills[1:], start=1):
            self.assertAlmostEqual(stored["mastery_matrix"][skill], history["mastery_matrix"][skill])
            module = modules[index]
            self.assertEqual(stored["lesson_progress"][module], history["lesson_progress"][module])
            self.assertEqual(stored["lesson_quiz_responses"][module], history["lesson_quiz_responses"][module])
            self.assertEqual(stored["lesson_post_quiz_scores"][module], history["lesson_post_quiz_scores"][module])
            self.assertEqual(stored["practice_responses"]["prac-" + module], history["practice_responses"]["prac-" + module])
            self.assertEqual(stored["learning_evidence"]["topics"][skill], history["learning_evidence"]["topics"][skill])
        self.assertEqual(stored["lesson_progress"]["mod_01"], 1)
        self.assertEqual(stored["lesson_quiz_responses"]["mod_01"], {"mod_01_q1": True})
        self.assertEqual(stored["lesson_post_quiz_scores"]["mod_01"], 16)
        self.assertEqual(stored["learning_evidence"]["topics"]["phishing"], 2)
        self.assertEqual(stored["learning_evidence"]["responses"], 20)
        self.assertEqual(stored["completed_lessons"], ["mod_01"])
        self.assertEqual(len(fake.bkt_rows), 5)

    def test_f_explicit_empty_matches_omitted_and_does_not_wipe(self):
        omitted = ProgressSyncRequest(mastery_matrix={"phishing": 0.10})
        explicit = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.10},
            lesson_progress={},
            completed_lessons=[],
            lesson_quiz_responses={"mod_01": {}},
            lesson_post_quiz_scores={},
            practice_responses={},
            learning_evidence={},
        )
        self.assertNotIn("lesson_progress", omitted.model_fields_set)
        self.assertIn("lesson_progress", explicit.model_fields_set)
        self.assertNotIn("learning_evidence", omitted.model_fields_set)
        self.assertIn("learning_evidence", explicit.model_fields_set)
        results = []
        for payload in (omitted, explicit):
            fake = StatefulSupabase()
            fake.save_rows = [{"payload": copy.deepcopy(self.HISTORY)}]
            self.assertTrue(self._sync(fake, payload).ok)
            results.append(self._stored(fake))
        for stored in results:
            self._assert_history(stored, 0.42)
        self.assertEqual(results[0]["lesson_progress"], results[1]["lesson_progress"])
        self.assertEqual(results[0]["completed_lessons"], results[1]["completed_lessons"])
        self.assertEqual(results[0]["lesson_quiz_responses"], results[1]["lesson_quiz_responses"])
        self.assertEqual(results[0]["lesson_post_quiz_scores"], results[1]["lesson_post_quiz_scores"])
        self.assertEqual(results[0]["practice_responses"], results[1]["practice_responses"])
        self.assertEqual(results[0]["learning_evidence"], results[1]["learning_evidence"])

    def test_forward_merge_keeps_best_and_adds_new_answers_once(self):
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": copy.deepcopy(self.HISTORY)}]
        incoming = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.50},
            lesson_progress={"mod_01": 2, "mod_02": 1},
            completed_lessons=["mod_01", "mod_02"],
            lesson_quiz_responses={"mod_01": {"mod01_q1": False, "mod01_q2": True}},
            lesson_post_quiz_scores={"mod_01": 10},
            practice_responses={
                "prac-1": {"module_id": "mod_01", "skill": "phishing", "correct": False},
                "prac-2": {"module_id": "mod_01", "skill": "phishing", "correct": True},
            },
            learning_evidence={
                "topics": {"phishing": 4},
                "responses": 4,
                "sessions": 1,
                "first_at": 1700000000,
                "last_at": 1700000100,
            },
        )
        self.assertTrue(self._sync(fake, incoming).ok)
        self.assertTrue(self._sync(fake, incoming).ok)
        stored = self._stored(fake)
        self.assertEqual(stored["lesson_progress"], {"mod_01": 6, "mod_02": 1})
        self.assertEqual(stored["completed_lessons"], ["mod_01", "mod_02"])
        self.assertEqual(stored["lesson_quiz_responses"], {"mod_01": {"mod01_q1": True, "mod01_q2": True}})
        self.assertEqual(stored["lesson_post_quiz_scores"], {"mod_01": 22})
        self.assertTrue(stored["practice_responses"]["prac-1"]["correct"])
        self.assertTrue(stored["practice_responses"]["prac-2"]["correct"])
        self.assertEqual(len(stored["practice_responses"]), 2)
        self.assertEqual(stored["learning_evidence"]["topics"], {"phishing": 6})
        self.assertEqual(stored["learning_evidence"]["responses"], 6)
        raised = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.50},
            lesson_progress={"mod_01": 6},
            lesson_post_quiz_scores={"mod_01": 24},
            learning_evidence={
                "topics": {"phishing": 7},
                "responses": 7,
                "sessions": 2,
                "first_at": 1780000000,
                "last_at": 1780000500,
            },
        )
        self.assertTrue(self._sync(fake, raised).ok)
        stored = self._stored(fake)
        self.assertEqual(stored["lesson_progress"], {"mod_01": 6, "mod_02": 1})
        self.assertEqual(stored["completed_lessons"], ["mod_01", "mod_02"])
        self.assertEqual(stored["lesson_post_quiz_scores"]["mod_01"], 24)
        self.assertEqual(stored["learning_evidence"]["topics"], {"phishing": 7})
        self.assertEqual(stored["learning_evidence"]["responses"], 7)
        self.assertEqual(stored["learning_evidence"]["sessions"], 2)
        self.assertEqual(stored["learning_evidence"]["first_at"], 1700000000)
        self.assertEqual(stored["learning_evidence"]["last_at"], 1780000500)
        self.assertEqual(len(stored["lesson_quiz_responses"]["mod_01"]), 2)
        self.assertEqual(len(stored["practice_responses"]), 2)

    def test_g_acknowledged_bkt_log_is_not_restored_or_replayed(self):
        fake = StatefulSupabase()
        first = dict(self.HISTORY)
        first["unconfirmed_bkt_log"] = [{
            "id": "acked-step", "skill": "phishing", "op": "update", "posterior": 0.42,
        }]
        self.assertTrue(self._sync(fake, ProgressSyncRequest(**first)).ok)
        self.assertEqual(self._stored(fake)["unconfirmed_bkt_log"][0]["id"], "acked-step")
        self.assertTrue(self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.62})).ok)
        stored = self._stored(fake)
        self.assertNotIn("unconfirmed_bkt_log", stored)
        self.assertNotIn("learning_events", stored)
        self._assert_history(stored, 0.62)
        self.assertEqual(len(fake.bkt_rows), 1)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.62)


class PretestBaselineSparseSyncTest(unittest.TestCase):
    """A new posterior keeps every stored pretest baseline."""

    STORED = {
        "mastery_matrix": {"phishing": 0.42, "pretexting": 0.55},
        "pretest_baselines": {
            "mod_01": {"correct": 3, "total": 4},
            "mod_04": {"correct": 1, "total": 4},
        },
        "lesson_progress": {"mod_01": 6},
        "completed_lessons": ["mod_01"],
        "lesson_quiz_responses": {"mod_01": {"mod01_q1": True}},
        "lesson_post_quiz_scores": {"mod_01": 22},
        "practice_responses": {
            "prac-1": {"module_id": "mod_01", "skill": "phishing", "correct": True},
        },
        "learning_evidence": {
            "topics": {"phishing": 6, "pretexting": 2},
            "responses": 8,
            "sessions": 1,
            "first_at": 1700000000,
            "last_at": 1700000100,
        },
    }
    BASELINES = {
        "mod_01": {"correct": 3, "total": 4},
        "mod_04": {"correct": 1, "total": 4},
    }

    def _sync(self, fake: FakeSupabase, payload: ProgressSyncRequest):
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", payload)

    def _with_history(self) -> StatefulSupabase:
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": copy.deepcopy(self.STORED)}]
        return fake

    def _assert_lesson_history(self, stored: dict) -> None:
        self.assertEqual(stored["lesson_progress"], {"mod_01": 6})
        self.assertEqual(stored["completed_lessons"], ["mod_01"])
        self.assertEqual(stored["lesson_quiz_responses"], {"mod_01": {"mod01_q1": True}})
        self.assertEqual(stored["lesson_post_quiz_scores"], {"mod_01": 22})
        self.assertEqual(stored["practice_responses"], self.STORED["practice_responses"])
        self.assertEqual(stored["learning_evidence"]["topics"], {"phishing": 6, "pretexting": 2})
        self.assertEqual(stored["learning_evidence"]["responses"], 8)

    def test_a_new_posterior_keeps_every_stored_baseline(self):
        fake = self._with_history()
        self.assertTrue(self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.62})).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertEqual(stored["pretest_baselines"], self.BASELINES)
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.62)
        self.assertAlmostEqual(stored["mastery_matrix"]["pretexting"], 0.55)
        self._assert_lesson_history(stored)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.62)

    def test_b_explicit_empty_baseline_map_keeps_stored_baselines(self):
        fake = self._with_history()
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.62}, pretest_baselines={})
        self.assertIn("pretest_baselines", payload.model_fields_set)
        self.assertTrue(self._sync(fake, payload).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertEqual(stored["pretest_baselines"], self.BASELINES)
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.62)

    def test_c_new_module_baseline_is_added_once(self):
        fake = self._with_history()
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.62},
            pretest_baselines={"mod_02": {"correct": 2, "total": 4}},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertTrue(self._sync(fake, payload).ok)
        baselines = fake.save_rows[0]["payload"]["pretest_baselines"]
        self.assertEqual(baselines["mod_01"], {"correct": 3, "total": 4})
        self.assertEqual(baselines["mod_04"], {"correct": 1, "total": 4})
        self.assertEqual(baselines["mod_02"], {"correct": 2, "total": 4})
        self.assertEqual(list(baselines), ["mod_01", "mod_04", "mod_02"])

    def test_d_existing_module_baseline_is_not_replaced(self):
        fake = self._with_history()
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.62},
            pretest_baselines={"mod_01": {"correct": 0, "total": 4}},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        baselines = fake.save_rows[0]["payload"]["pretest_baselines"]
        self.assertEqual(baselines, self.BASELINES)
        self.assertEqual(len(baselines), 2)

    def test_e_repeated_sparse_sync_does_not_duplicate_baselines_or_bkt_rows(self):
        fake = self._with_history()
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.62})
        self.assertTrue(self._sync(fake, payload).ok)
        self.assertTrue(self._sync(fake, payload).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertEqual(stored["pretest_baselines"], self.BASELINES)
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.62)
        self.assertAlmostEqual(stored["mastery_matrix"]["pretexting"], 0.55)
        self._assert_lesson_history(stored)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing"), ("stu-1", "Pretexting")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.62)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Pretexting")]["probability_known"], 0.55)


class MalformedPretestBaselineEvidenceTest(unittest.TestCase):
    """Only a valid correct/total pair can make a 0.10 prior assessed."""

    def _sync(self, fake: FakeSupabase, payload: ProgressSyncRequest, stored: dict | None = None):
        if stored is not None:
            fake.save_rows = [{"payload": copy.deepcopy(stored)}]
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", payload)

    def test_a_malformed_baseline_cannot_replace_assessed_posterior(self):
        fake = StatefulSupabase()
        stored = {
            "mastery_matrix": {"phishing": 0.42},
            "pretest_baselines": {"mod_01": {"correct": 3, "total": 4}},
        }
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.10},
            pretest_baselines={"mod_01": {"foo": 1}},
        )
        self.assertTrue(self._sync(fake, payload, stored).ok)
        saved = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(saved["mastery_matrix"]["phishing"], 0.42)
        self.assertEqual(saved["pretest_baselines"], {"mod_01": {"correct": 3, "total": 4}})
        self.assertNotIn("foo", str(saved["pretest_baselines"]))
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})

    def test_b_malformed_baseline_does_not_assess_an_unseen_topic(self):
        fake = StatefulSupabase()
        payload = ProgressSyncRequest(
            mastery_matrix={"smishing": 0.10},
            pretest_baselines={"mod_02": {"foo": 1}},
        )
        self.assertTrue(self._sync(fake, payload, {"mastery_matrix": {}}).ok)
        saved = fake.save_rows[0]["payload"]
        self.assertNotIn("smishing", saved["mastery_matrix"])
        self.assertNotIn("mod_02", saved.get("pretest_baselines", {}))
        self.assertNotIn(("stu-1", "Smishing"), fake.bkt_rows)
        self.assertNotIn("bkt_records", fake.upserts)

    def test_c_valid_baseline_marks_the_topic_assessed(self):
        fake = StatefulSupabase()
        payload = ProgressSyncRequest(
            mastery_matrix={"smishing": 0.10},
            pretest_baselines={"mod_02": {"correct": 2, "total": 4}},
        )
        self.assertTrue(self._sync(fake, payload, {"mastery_matrix": {}}).ok)
        saved = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(saved["mastery_matrix"]["smishing"], 0.10)
        self.assertEqual(saved["pretest_baselines"], {"mod_02": {"correct": 2, "total": 4}})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.10)

    def test_d_genuine_assessed_0_10_remains_valid(self):
        fake = StatefulSupabase()
        stored = {
            "mastery_matrix": {"phishing": 0.42, "smishing": 0.10},
            "pretest_baselines": {
                "mod_01": {"correct": 3, "total": 4},
                "mod_02": {"correct": 1, "total": 4},
            },
        }
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.62})
        self.assertTrue(self._sync(fake, payload, stored).ok)
        saved = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(saved["mastery_matrix"]["phishing"], 0.62)
        self.assertAlmostEqual(saved["mastery_matrix"]["smishing"], 0.10)
        self.assertEqual(saved["pretest_baselines"]["mod_01"], {"correct": 3, "total": 4})
        self.assertEqual(saved["pretest_baselines"]["mod_02"], {"correct": 1, "total": 4})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.10)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.62)

    def test_e_invalid_baseline_shapes_do_not_create_evidence(self):
        stored = {
            "mastery_matrix": {"phishing": 0.42},
            "pretest_baselines": {"mod_01": {"correct": 3, "total": 4}},
        }
        invalid_maps = [
            {"mod_02": "nope"},
            {"mod_02": ["correct", 1]},
            {"mod_02": {"correct": True, "total": 4}},
            {"mod_02": {"correct": 1, "total": 0}},
            {"mod_02": {"correct": 1, "total": 101}},
            {"mod_02": {"correct": 5, "total": 4}},
            {"mod_02": {"correct": -1, "total": 4}},
            {"mod_02": {"correct": 1.5, "total": 4}},
            {"mod_99": {"correct": 1, "total": 4}},
        ]
        for baselines in invalid_maps:
            fake = StatefulSupabase()
            payload = ProgressSyncRequest(
                mastery_matrix={"phishing": 0.10, "smishing": 0.10},
                pretest_baselines=baselines,
            )
            self.assertTrue(self._sync(fake, payload, stored).ok, baselines)
            saved = fake.save_rows[0]["payload"]
            self.assertAlmostEqual(saved["mastery_matrix"]["phishing"], 0.42, msg=baselines)
            self.assertNotIn("smishing", saved["mastery_matrix"], baselines)
            self.assertEqual(saved["pretest_baselines"], {"mod_01": {"correct": 3, "total": 4}}, baselines)
            self.assertNotIn(("stu-1", "Smishing"), fake.bkt_rows, baselines)
            self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42, msg=baselines)


class OfficialPretestAuthorityTest(unittest.TestCase):
    """The student column is the completion record. A client upload cannot grant or revoke it."""

    MODULES = (
        ("mod_01", "Phishing", "mastery_phishing"),
        ("mod_02", "Smishing", "mastery_smishing"),
        ("mod_03", "Vishing", "mastery_vishing"),
        ("mod_04", "Pretexting", "mastery_pretexting"),
        ("mod_05", "Baiting", "mastery_baiting"),
    )

    def _answers(self, module_id: str, *, correct: bool = True) -> list:
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload

        bank = questions_for_module(module_id)
        self.assertIsNotNone(bank)
        rows = []
        for question in bank:
            answer = question["answer"] if correct else (int(question["answer"]) + 1) % len(question["options"])
            rows.append(PretestAnswerPayload(id=question["id"], answer=answer))
        return rows

    def _column_fake(self, flags: dict, save: dict | None = None) -> ColumnSchemaSupabase:
        fake = ColumnSchemaSupabase()
        fake.student_row = {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": dict(flags)}
        fake.save_rows = [{"payload": copy.deepcopy(save or {})}]
        return fake

    def _submit(self, fake: ColumnSchemaSupabase, module_id: str, rows: list | None = None):
        from app.services.pretest_service import submit_pretest

        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student",
                  side_effect=lambda _sid: dict(fake.student_row)),
        ):
            return submit_pretest("stu-1", module_id, self._answers(module_id) if rows is None else rows)

    def _sync(self, student: dict, stored: dict, **fields):
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": copy.deepcopy(stored)}]
        payload = ProgressSyncRequest(**fields)
        with (
            patch("app.services.progress_service.fetch_student_by_id", return_value=dict(student)),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
        for update in fake.updates.get("students", []):
            self.assertNotIn("module_pretests", update)
        return fake, fake.save_rows[0]["payload"]

    def test_empty_column_ignores_client_flag_and_accepts_first_submission(self):
        fake = self._column_fake({}, {"module_pretests": ["mod_01"], "credits": 12})
        before_bkt = dict(fake.bkt_rows)
        result = self._submit(fake, "mod_01")
        self.assertTrue(result.preTestCompleted)
        self.assertEqual(result.completedModuleIds, ["mod_01"])
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertNotEqual(fake.bkt_rows, before_bkt)
        self.assertEqual(fake.save_rows[0]["payload"]["credits"], 12)
        self.assertNotIn("player_saves", fake.upserts)

    def test_column_completion_rejects_repeat_without_another_bkt_write(self):
        fake = self._column_fake({"mod_01": True}, {"module_pretests": []})
        fake.student_row["mastery_phishing"] = 0.42
        before = dict(fake.student_row)
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake, "mod_01")
        self.assertEqual(ctx.exception.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row, before)
        self.assertEqual(fake.bkt_rows, {})
        self.assertEqual(fake.updates, {})
        self.assertEqual(fake.upserts, {})
        self.assertEqual(fake.executes, [])

    def test_incoming_empty_list_cannot_clear_official_completion(self):
        _fake, saved = self._sync(
            {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": {"mod_01": True, "mod_02": True}},
            {
                "module_pretests": ["mod_01", "mod_02"],
                "pretest_baselines": {"mod_01": {"correct": 3, "total": 4}},
                "lesson_progress": {"mod_01": 6},
            },
            mastery_matrix={"phishing": 0.62},
            module_pretests=[],
        )
        self.assertEqual(saved["module_pretests"], {"mod_01": True, "mod_02": True})
        self.assertEqual(saved["pretest_baselines"], {"mod_01": {"correct": 3, "total": 4}})
        self.assertEqual(saved["lesson_progress"], {"mod_01": 6})
        self.assertAlmostEqual(saved["mastery_matrix"]["phishing"], 0.62)

    def test_incoming_module_five_without_grading_is_not_completed(self):
        _fake, saved = self._sync(
            {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": {}},
            {"mastery_matrix": {}},
            mastery_matrix={"baiting": 0.10},
            module_pretests=["mod_05"],
        )
        self.assertEqual(saved["module_pretests"], {})
        self.assertNotIn("baiting", saved["mastery_matrix"])
        from app.services.auth_service import _completed_module_ids

        self.assertEqual(
            _completed_module_ids({"id": "stu-1", "module_pretests": {}}),
            [],
        )

    def test_sync_before_graded_post_still_accepts_the_first_submission(self):
        student = {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": {}}
        _sync_fake, saved = self._sync(
            student,
            {
                "module_pretests": ["mod_01"],
                "lesson_progress": {"mod_01": 6},
                "pretest_baselines": {"mod_04": {"correct": 1, "total": 4}},
            },
            module_pretests=["mod_01"],
            mastery_matrix={"phishing": 0.10},
        )
        self.assertEqual(saved["module_pretests"], {})
        self.assertEqual(saved["lesson_progress"], {"mod_01": 6})
        self.assertEqual(saved["pretest_baselines"], {"mod_04": {"correct": 1, "total": 4}})
        fake = self._column_fake({}, saved)
        result = self._submit(fake, "mod_01")
        self.assertEqual(result.completedModuleIds, ["mod_01"])
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertEqual(len(fake.upserts.get("bkt_records", [])), 1)

    def test_sync_after_graded_post_keeps_official_completion(self):
        fake = self._column_fake({})
        self._submit(fake, "mod_01")
        official = dict(fake.student_row["module_pretests"])
        phishing = fake.student_row["mastery_phishing"]
        _sync_fake, saved = self._sync(
            {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": official, "mastery_phishing": phishing},
            {"module_pretests": ["mod_01"], "mastery_matrix": {"phishing": phishing}},
            module_pretests=[],
            mastery_matrix={"phishing": phishing},
        )
        self.assertEqual(saved["module_pretests"], {"mod_01": True})
        _again, replaced = self._sync(
            {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": official},
            saved,
            module_pretests=["mod_05"],
            mastery_matrix={"phishing": phishing},
        )
        self.assertEqual(replaced["module_pretests"], {"mod_01": True})
        self.assertNotIn("mod_05", replaced["module_pretests"])
        repeat = self._column_fake(official, replaced)
        repeat.student_row["mastery_phishing"] = phishing
        before = dict(repeat.student_row)
        with self.assertRaises(HTTPException) as ctx:
            self._submit(repeat, "mod_01")
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(repeat.student_row, before)
        self.assertEqual(repeat.bkt_rows, {})

    def test_five_modules_complete_independently_and_update_only_their_topic(self):
        fake = self._column_fake({})
        seen_topics: list[str] = []
        phishing_after_first = None
        for module_id, topic, column in self.MODULES:
            before = {key: fake.student_row.get(key) for _mid, _topic, key in self.MODULES}
            result = self._submit(fake, module_id)
            seen_topics.append(topic)
            self.assertEqual(result.completedModuleIds, [item[0] for item in self.MODULES[:len(seen_topics)]])
            self.assertEqual(
                fake.student_row["module_pretests"],
                {item[0]: True for item in self.MODULES[:len(seen_topics)]},
            )
            self.assertEqual(set(fake.bkt_rows), {("stu-1", name) for name in seen_topics})
            self.assertIn(column, fake.student_row)
            if phishing_after_first is None:
                phishing_after_first = fake.student_row["mastery_phishing"]
            else:
                self.assertEqual(fake.student_row["mastery_phishing"], phishing_after_first)
            for other_module, other_topic, other_column in self.MODULES:
                if other_module == module_id:
                    continue
                self.assertEqual(fake.student_row.get(other_column), before[other_column])
                if other_topic not in seen_topics:
                    self.assertNotIn(("stu-1", other_topic), fake.bkt_rows)
        self.assertEqual(len(fake.upserts["bkt_records"]), 5)
        self.assertEqual(fake.student_row["pre"], 100)

    def test_incomplete_answers_and_unknown_module_write_nothing(self):
        fake = self._column_fake({}, {"credits": 4})
        short = self._answers("mod_01")[:-1]
        with self.assertRaises(HTTPException) as incomplete:
            self._submit(fake, "mod_01", short)
        self.assertEqual(incomplete.exception.detail, "Submit an answer for every pre-test question")
        with self.assertRaises(HTTPException) as unknown:
            self._submit(fake, "mod_99", self._answers("mod_01"))
        self.assertEqual(unknown.exception.detail, "Unknown module_id")
        self.assertEqual(fake.student_row["module_pretests"], {})
        self.assertEqual(fake.bkt_rows, {})
        self.assertEqual(fake.updates, {})
        self.assertEqual(fake.upserts, {})
        self.assertEqual(fake.save_rows[0]["payload"]["credits"], 4)

    def test_sync_preserves_baselines_and_educational_records(self):
        stored = dict(SparseLearningRecordSyncTest.HISTORY)
        stored["pretest_baselines"] = {
            "mod_01": {"correct": 3, "total": 4},
            "mod_04": {"correct": 1, "total": 4},
        }
        stored["module_pretests"] = ["mod_05"]
        _fake, saved = self._sync(
            {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": {"mod_01": True}},
            stored,
            mastery_matrix={"phishing": 0.62},
            module_pretests=[],
            lesson_progress={},
            completed_lessons=[],
        )
        self.assertEqual(saved["module_pretests"], {"mod_01": True})
        self.assertEqual(saved["pretest_baselines"], stored["pretest_baselines"])
        self.assertEqual(saved["lesson_progress"], {"mod_01": 6})
        self.assertEqual(saved["completed_lessons"], ["mod_01"])
        self.assertEqual(saved["lesson_quiz_responses"], stored["lesson_quiz_responses"])
        self.assertEqual(saved["lesson_post_quiz_scores"], stored["lesson_post_quiz_scores"])
        self.assertIn("prac-1", saved["practice_responses"])
        self.assertEqual(saved["learning_evidence"]["topics"], {"phishing": 6})
        self.assertAlmostEqual(saved["mastery_matrix"]["phishing"], 0.62)

    def test_legacy_row_without_the_column_keeps_stored_flags_only(self):
        legacy_student = {"id": "stu-1", "highest_unlocked_stage": 1}
        stored = {
            "module_pretests": ["mod_01", "mod_02"],
            "pretest_baselines": {"mod_01": {"correct": 3, "total": 4}},
            "lesson_progress": {"mod_01": 6},
        }
        _cleared, cleared = self._sync(legacy_student, stored, module_pretests=[], mastery_matrix={"phishing": 0.42})
        self.assertEqual(cleared["module_pretests"], ["mod_01", "mod_02"])
        self.assertEqual(cleared["pretest_baselines"], stored["pretest_baselines"])
        _replaced, replaced = self._sync(
            legacy_student,
            stored,
            module_pretests=["mod_05"],
            mastery_matrix={"phishing": 0.42},
        )
        self.assertEqual(replaced["module_pretests"], ["mod_01", "mod_02"])
        _invented, invented = self._sync(
            legacy_student,
            {"lesson_progress": {"mod_01": 2}},
            module_pretests=["mod_05"],
            mastery_matrix={"phishing": 0.10},
        )
        self.assertNotIn("module_pretests", invented)
        self.assertEqual(invented["lesson_progress"], {"mod_01": 2})

        from app.services.auth_service import _completed_module_ids

        reader = FakeSupabase()
        reader.save_rows = [{"payload": {"module_pretests": ["mod_01", "mod_02"]}}]
        with patch("app.services.auth_service.supabase", reader):
            self.assertEqual(_completed_module_ids({"id": "stu-1"}), ["mod_01", "mod_02"])
        with patch("app.services.auth_service.supabase", reader):
            self.assertEqual(
                _completed_module_ids({"id": "stu-1", "module_pretests": {}}),
                [],
            )
        self.assertEqual(reader.executes, ["player_saves"])

        # A submission is always recorded by the database function, never in the save blob,
        # and the function's own completion check rejects the repeat.
        submitter = LegacySchemaSupabase()
        submitter.save_rows = [{"payload": dict(invented)}]
        result = self._submit(submitter, "mod_01")
        self.assertEqual(result.completedModuleIds, ["mod_01"])
        self.assertNotIn("player_saves", submitter.upserts)
        self.assertEqual(submitter.save_rows[0]["payload"], invented)
        self.assertIn(("stu-1", "Phishing"), submitter.bkt_rows)
        with self.assertRaises(HTTPException) as ctx:
            self._submit(submitter, "mod_01")
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(len(submitter.upserts.get("bkt_records", [])), 1)


class OfflinePretestDoubleApplicationTest(unittest.TestCase):
    """A progress snapshot must not publish or stack an official pretest diagnostic."""

    def _fetch_then_grade(self, official: dict):
        calls = {"n": 0}
        before = {
            "id": "stu-1",
            "highest_unlocked_stage": 1,
            "module_pretests": {},
            "mastery_phishing": 0.20,
            "mastery_smishing": 0.20,
            "pre": 0,
        }

        def fetch(_student_id: str) -> dict:
            calls["n"] += 1
            if calls["n"] == 1:
                return dict(before)
            graded = dict(before)
            graded.update(official)
            return graded

        return fetch

    def test_a_in_flight_snapshot_keeps_the_graded_posterior(self):
        from app.services.bkt_service import update_pl_diagnostic

        phone_diagnostic = 0.77
        official = 0.42
        doubled = update_pl_diagnostic(phone_diagnostic, True)
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": {"lesson_quiz_responses": {"mod_03": {"q1": True}}}}]
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": phone_diagnostic, "smishing": 0.66, "vishing": 0.51},
            student={"pre": 95, "points": 4},
            lesson_quiz_responses={"mod_03": {"q2": False}},
            practice_responses={"prac-9": {"module_id": "mod_04", "skill": "pretexting", "correct": True}},
            lesson_progress={"mod_03": 2},
            lesson_post_quiz_scores={"mod_05": 21},
        )
        with patch(
            "app.services.progress_service.fetch_student_by_id",
            side_effect=self._fetch_then_grade({
                "module_pretests": {"mod_01": True},
                "mastery_phishing": official,
                "pre": 40,
            }),
        ), patch("app.services.progress_service.supabase", fake):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], official)
        self.assertNotAlmostEqual(stored["mastery_matrix"]["phishing"], phone_diagnostic)
        self.assertNotAlmostEqual(stored["mastery_matrix"]["phishing"], doubled)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], official)
        self.assertAlmostEqual(stored["mastery_matrix"]["smishing"], 0.66)
        self.assertAlmostEqual(stored["mastery_matrix"]["vishing"], 0.51)
        self.assertEqual(stored["module_pretests"], {"mod_01": True})
        self.assertEqual(stored["lesson_quiz_responses"]["mod_03"], {"q1": True, "q2": False})
        self.assertIn("prac-9", stored["practice_responses"])
        self.assertEqual(stored["lesson_progress"], {"mod_03": 2})
        self.assertEqual(stored["lesson_post_quiz_scores"], {"mod_05": 21})
        for update in fake.updates.get("students", []):
            self.assertNotIn("pre", update)

    def _mixed_answers(self, module_id: str):
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload

        bank = questions_for_module(module_id)
        return [
            PretestAnswerPayload(
                id=question["id"],
                answer=question["answer"] if index % 3 else (int(question["answer"]) + 1) % len(question["options"]),
            )
            for index, question in enumerate(bank)
        ]

    def test_b_graded_pretest_is_one_diagnostic_and_later_learning_can_sync(self):
        from app.services.bkt_service import update_pl_diagnostic
        from app.services.pretest_service import submit_pretest

        fake = ColumnSchemaSupabase()
        fake.student_row = {
            "id": "stu-1",
            "highest_unlocked_stage": 1,
            "module_pretests": {},
            "mastery_phishing": 0.20,
            "pre": 0,
        }
        answers = self._mixed_answers("mod_01")
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", side_effect=lambda _sid: dict(fake.student_row)),
        ):
            result = submit_pretest("stu-1", "mod_01", answers)
        official = fake.student_row["mastery_phishing"]
        self.assertAlmostEqual(official, result.mastery.Phishing)
        self.assertNotAlmostEqual(official, update_pl_diagnostic(official, True))
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(len(fake.upserts["bkt_records"]), 1)
        self.assertEqual(fake.student_row["pre"], result.pre)

        later = 0.61 if abs(official - 0.61) > 0.02 else 0.73
        sync_fake = StatefulSupabase()
        sync_fake.save_rows = [{"payload": {"module_pretests": {"mod_01": True}}}]
        student = {
            "id": "stu-1",
            "highest_unlocked_stage": 1,
            "module_pretests": {"mod_01": True},
            "mastery_phishing": official,
            "pre": result.pre,
        }
        with (
            patch("app.services.progress_service.fetch_student_by_id", return_value=dict(student)),
            patch("app.services.progress_service.supabase", sync_fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", ProgressSyncRequest(
                mastery_matrix={"phishing": later},
                student={"pre": 100},
                lesson_quiz_responses={"mod_03": {"after": True}},
            )).ok)
        self.assertAlmostEqual(sync_fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], later)
        self.assertNotAlmostEqual(sync_fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], update_pl_diagnostic(official, True))
        self.assertEqual(sync_fake.save_rows[0]["payload"]["lesson_quiz_responses"], {"mod_03": {"after": True}})
        for update in sync_fake.updates.get("students", []):
            self.assertNotIn("pre", update)

    def test_e_repeat_submission_does_not_apply_another_diagnostic(self):
        from app.services.pretest_service import submit_pretest

        fake = ColumnSchemaSupabase()
        fake.student_row = {"id": "stu-1", "highest_unlocked_stage": 1, "module_pretests": {}, "mastery_vishing": 0.25}
        answers = self._mixed_answers("mod_03")
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", side_effect=lambda _sid: dict(fake.student_row)),
        ):
            submit_pretest("stu-1", "mod_03", answers)
            official = fake.student_row["mastery_vishing"]
            writes = len(fake.upserts["bkt_records"])
            with self.assertRaises(HTTPException) as ctx:
                submit_pretest("stu-1", "mod_03", answers)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertEqual(fake.student_row["mastery_vishing"], official)
        self.assertEqual(len(fake.upserts["bkt_records"]), writes)

    def test_h_one_pending_module_does_not_freeze_another_topics_snapshot(self):
        fake = StatefulSupabase()
        fetch = self._fetch_then_grade({
            "module_pretests": {"mod_02": True},
            "mastery_smishing": 0.37,
        })
        payload = ProgressSyncRequest(
            mastery_matrix={"smishing": 0.81, "vishing": 0.58, "phishing": 0.44},
            lesson_quiz_responses={"mod_01": {"kept": True}},
        )
        with (
            patch("app.services.progress_service.fetch_student_by_id", side_effect=fetch),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
        stored = fake.save_rows[0]["payload"]
        self.assertAlmostEqual(stored["mastery_matrix"]["smishing"], 0.37)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.37)
        self.assertAlmostEqual(stored["mastery_matrix"]["vishing"], 0.58)
        self.assertAlmostEqual(stored["mastery_matrix"]["phishing"], 0.44)
        self.assertEqual(stored["lesson_quiz_responses"], {"mod_01": {"kept": True}})
        self.assertEqual(stored["module_pretests"], {"mod_02": True})

    def test_i_progress_sync_does_not_write_module_one_pre_on_the_current_schema(self):
        fake = StatefulSupabase()
        student = {
            "id": "stu-1",
            "highest_unlocked_stage": 1,
            "module_pretests": {},
            "pre": 0,
        }
        with (
            patch("app.services.progress_service.fetch_student_by_id", return_value=dict(student)),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", ProgressSyncRequest(
                student={"pre": 88, "points": 2},
                mastery_matrix={"phishing": 0.63},
            )).ok)
        for update in fake.updates.get("students", []):
            self.assertNotIn("pre", update)
        self.assertIn("points", fake.updates["students"][0])

        legacy = StatefulSupabase()
        with (
            patch("app.services.progress_service.fetch_student_by_id", return_value={
                "id": "stu-1",
                "highest_unlocked_stage": 1,
                "pre": 10,
            }),
            patch("app.services.progress_service.supabase", legacy),
        ):
            self.assertTrue(sync_student_progress("stu-1", ProgressSyncRequest(student={"pre": 25})).ok)
        self.assertEqual(legacy.updates["students"][0]["pre"], 25)


class PretestProgressConcurrencyTest(unittest.TestCase):
    """A stale progress sync cannot replace a pretest that commits during the write."""

    def _student(self, **overrides) -> dict:
        row = {
            "id": "stu-1",
            "highest_unlocked_stage": 1,
            "module_pretests": {},
            "mastery_phishing": 0.20,
            "mastery_smishing": 0.20,
            "mastery_vishing": 0.20,
        }
        row.update(overrides)
        return row

    def _bkt(self, fake: ConcurrencySupabase, topic: str, probability: float) -> None:
        fake.bkt_rows[("stu-1", topic)] = {
            "student_id": "stu-1",
            "topic": topic,
            "probability_known": probability,
        }

    def _sync(self, fake: ConcurrencySupabase, payload: ProgressSyncRequest, fetch):
        with (
            patch("app.services.progress_service.fetch_student_by_id", side_effect=fetch),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", payload)

    def _live_fetch(self, fake: ConcurrencySupabase):
        def fetch(_student_id: str) -> dict:
            return copy.deepcopy(fake.student_row)

        return fetch

    def test_a_grade_before_conditional_update_keeps_official_mastery(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student(module_pretests={"mod_01": True}, mastery_phishing=0.42)
        self._bkt(fake, "Phishing", 0.42)
        stale = self._student()
        calls = {"n": 0}

        def fetch(_student_id: str) -> dict:
            calls["n"] += 1
            if calls["n"] <= 2:
                return dict(stale)
            return copy.deepcopy(fake.student_row)

        result = self._sync(fake, ProgressSyncRequest(
            mastery_matrix={"phishing": 0.77, "smishing": 0.66},
        ), fetch)
        self.assertTrue(result.ok)
        self.assertGreaterEqual(calls["n"], 3)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.42)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)
        self.assertAlmostEqual(fake.student_row["mastery_smishing"], 0.66)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        stored = fake.save_rows[0]["payload"]["mastery_matrix"]
        self.assertAlmostEqual(stored["phishing"], 0.42)
        self.assertNotAlmostEqual(stored["phishing"], 0.77)

    def test_b_grade_between_read_and_update_is_a_conflict(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student(mastery_phishing=0.42)
        self._bkt(fake, "Phishing", 0.42)

        def grade() -> None:
            fake.student_row["module_pretests"] = {"mod_01": True}

        fake.before_mastery_update = grade
        result = self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.77}), self._live_fetch(fake))
        self.assertTrue(result.ok)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.42)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.42)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertAlmostEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["phishing"], 0.42)

    def test_c_a_failed_write_changes_neither_table(self):
        fake = ConcurrencySupabase(fail={"rpc:levelblue_write_mastery"})
        fake.student_row = self._student()
        self._bkt(fake, "Phishing", 0.20)
        before_row = copy.deepcopy(fake.student_row)
        before_bkt = copy.deepcopy(fake.bkt_rows)
        with self.assertRaises(HTTPException) as ctx:
            self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.77, "smishing": 0.66}), self._live_fetch(fake))
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(fake.student_row, before_row)
        self.assertEqual(fake.bkt_rows, before_bkt)
        self.assertNotIn("player_saves", fake.upserts)

    def test_d_sync_without_concurrent_grading_writes_mastery(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        result = self._sync(fake, ProgressSyncRequest(
            mastery_matrix={"phishing": 0.63, "smishing": 0.48},
        ), self._live_fetch(fake))
        self.assertTrue(result.ok)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.63)
        self.assertAlmostEqual(fake.student_row["mastery_smishing"], 0.48)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.63)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.48)
        self.assertEqual(fake.student_row["module_pretests"], {})

    def test_e_practice_after_official_grading_can_sync(self):
        from app.services.bkt_service import update_pl_diagnostic

        fake = ConcurrencySupabase()
        fake.student_row = self._student(module_pretests={"mod_01": True}, mastery_phishing=0.42)
        self._bkt(fake, "Phishing", 0.42)
        result = self._sync(fake, ProgressSyncRequest(
            mastery_matrix={"phishing": 0.55},
            student={"pre": 100},
        ), self._live_fetch(fake))
        self.assertTrue(result.ok)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.55)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.55)
        self.assertNotAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], update_pl_diagnostic(0.42, True))
        self.assertNotAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], update_pl_diagnostic(0.55, True))
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        for update in fake.updates.get("students", []):
            self.assertNotIn("pre", update)
            self.assertNotIn("module_pretests", update)

    def test_f_one_module_grade_does_not_overwrite_another(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        self._bkt(fake, "Smishing", 0.20)

        def grade() -> None:
            fake.student_row["mastery_smishing"] = 0.37
            fake.student_row["module_pretests"] = {"mod_02": True}
            self._bkt(fake, "Smishing", 0.37)

        fake.before_mastery_update = grade
        result = self._sync(fake, ProgressSyncRequest(
            mastery_matrix={"phishing": 0.44, "smishing": 0.81, "vishing": 0.58},
            lesson_quiz_responses={"mod_01": {"kept": True}},
        ), self._live_fetch(fake))
        self.assertTrue(result.ok)
        self.assertAlmostEqual(fake.student_row["mastery_smishing"], 0.37)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.37)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.44)
        self.assertAlmostEqual(fake.student_row["mastery_vishing"], 0.58)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.44)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Vishing")]["probability_known"], 0.58)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_02": True})
        self.assertEqual(fake.save_rows[0]["payload"]["lesson_quiz_responses"], {"mod_01": {"kept": True}})

    def test_g_repeated_sync_does_not_reapply_a_bkt_step(self):
        from app.services.bkt_service import update_pl_diagnostic

        fake = ConcurrencySupabase()
        fake.student_row = self._student(module_pretests={"mod_01": True}, mastery_phishing=0.42)
        self._bkt(fake, "Phishing", 0.42)
        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.55})
        self.assertTrue(self._sync(fake, payload, self._live_fetch(fake)).ok)
        self.assertTrue(self._sync(fake, payload, self._live_fetch(fake)).ok)
        self.assertEqual(set(fake.bkt_rows), {("stu-1", "Phishing")})
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], 0.55)
        self.assertNotAlmostEqual(
            fake.bkt_rows[("stu-1", "Phishing")]["probability_known"],
            update_pl_diagnostic(0.55, True),
        )
        # The second upload restates the same posterior from the new read; it is not another step.
        writes = [params for name, params in fake.rpcs if name == "levelblue_write_mastery"]
        self.assertEqual([w["p_mastery"] for w in writes], [{"mastery_phishing": 0.55}] * 2)
        self.assertEqual([w["p_expected"] for w in writes], [{"mastery_phishing": 0.42}, {"mastery_phishing": 0.55}])
        self.assertEqual(writes[0]["p_incomplete_modules"], ["mod_02", "mod_03", "mod_04", "mod_05"])


class UnresolvedSyncConflictTest(unittest.TestCase):
    """Two missed guarded writes are not acknowledged as a finished sync."""

    _student = PretestProgressConcurrencyTest._student
    _bkt = PretestProgressConcurrencyTest._bkt
    _sync = PretestProgressConcurrencyTest._sync
    _live_fetch = PretestProgressConcurrencyTest._live_fetch

    def _other_device_writes(self, fake: ConcurrencySupabase, times: int, column: str = "mastery_smishing"):
        calls = {"n": 0}

        def write() -> None:
            calls["n"] += 1
            if calls["n"] <= times:
                fake.student_row[column] = round(0.30 + calls["n"] / 100, 4)

        return write

    def test_a_two_student_conflicts_return_409_before_the_save_blob(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        fake.save_rows = [{"payload": {"lesson_progress": {"mod_01": 3}}}]
        before_save = copy.deepcopy(fake.save_rows)
        fake.before_mastery_update = self._other_device_writes(fake, 2)
        with self.assertRaises(HTTPException) as ctx:
            self._sync(fake, ProgressSyncRequest(
                mastery_matrix={"phishing": 0.63, "smishing": 0.48},
                lesson_progress={"mod_01": 4},
            ), self._live_fetch(fake))
        self.assertEqual(ctx.exception.status_code, status.HTTP_409_CONFLICT)
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.save_rows, before_save)
        self.assertAlmostEqual(fake.student_row["mastery_smishing"], 0.32)
        self.assertNotIn("secret-token", str(ctx.exception.detail))

    def test_b_one_conflict_then_success_still_returns_ok(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        fake.before_mastery_update = self._other_device_writes(fake, 1)
        result = self._sync(fake, ProgressSyncRequest(
            mastery_matrix={"phishing": 0.63, "smishing": 0.48},
        ), self._live_fetch(fake))
        self.assertTrue(result.ok)
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.63)
        self.assertAlmostEqual(fake.student_row["mastery_smishing"], 0.48)
        self.assertAlmostEqual(fake.bkt_rows[("stu-1", "Smishing")]["probability_known"], 0.48)
        self.assertIn("player_saves", fake.upserts)

    def test_c_an_unresolved_conflict_writes_no_topic_and_is_logged_once(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        self._bkt(fake, "Phishing", 0.20)
        fake.before_mastery_update = self._other_device_writes(fake, 2)
        with patch("app.services.database_diagnostics._last_event_at", {}), \
                patch("app.services.database_diagnostics.supabase", fake):
            with self.assertRaises(HTTPException) as ctx:
                self._sync(fake, ProgressSyncRequest(mastery_matrix={"phishing": 0.63, "smishing": 0.48}), self._live_fetch(fake))
        self.assertEqual(ctx.exception.status_code, status.HTTP_409_CONFLICT)
        self.assertNotIn("player_saves", fake.upserts)
        # Phishing matched both times; the smishing conflict still leaves it unwritten in both tables.
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.20)
        self.assertEqual(fake.bkt_rows, {("stu-1", "Phishing"): {"student_id": "stu-1", "topic": "Phishing", "probability_known": 0.20}})
        events = [params for name, params in fake.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual([(e["p_code"], e["p_status"]) for e in events], [("mastery-conflict", 409)])
        self.assertNotIn("stu-1", str(events))

    def test_e_conflict_events_are_throttled_per_code(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        with patch("app.services.database_diagnostics._last_event_at", {}), \
                patch("app.services.database_diagnostics.supabase", fake):
            for _ in range(3):
                fake.before_mastery_update = self._other_device_writes(fake, 2)
                with self.assertRaises(HTTPException):
                    self._sync(fake, ProgressSyncRequest(mastery_matrix={"smishing": 0.48}), self._live_fetch(fake))
        events = [params for name, params in fake.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual(len(events), 1)

    def test_d_events_recorded_before_409_are_acknowledged_once_on_retry(self):
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        fake.before_mastery_update = self._other_device_writes(fake, 2, "mastery_phishing")
        stored_events: dict[str, int] = {}

        def record(_student_id: str, _events) -> list[str]:
            stored_events["evt-1"] = stored_events.get("evt-1", 0) or 1
            return ["evt-1"]

        payload = ProgressSyncRequest(mastery_matrix={"phishing": 0.63})
        with patch("app.services.progress_service.record_learning_events", side_effect=record) as recorder:
            with self.assertRaises(HTTPException):
                self._sync(fake, payload, self._live_fetch(fake))
            result = self._sync(fake, payload, self._live_fetch(fake))
        self.assertEqual(result.acknowledged_events, ["evt-1"])
        self.assertEqual(recorder.call_count, 2)
        self.assertEqual(stored_events, {"evt-1": 1})
        self.assertAlmostEqual(fake.student_row["mastery_phishing"], 0.63)
        self.assertIn("player_saves", fake.upserts)


class AtomicMasteryOrderingTest(unittest.TestCase):
    """Pretest and practice writes serialize on the student row, so both tables always agree."""

    _student = PretestProgressConcurrencyTest._student
    _bkt = PretestProgressConcurrencyTest._bkt
    _live_fetch = PretestProgressConcurrencyTest._live_fetch
    _answers = OfficialPretestAuthorityTest._answers

    def _fake(self) -> ConcurrencySupabase:
        fake = ConcurrencySupabase()
        fake.student_row = self._student()
        self._bkt(fake, "Phishing", 0.20)
        return fake

    def _submit_pretest(self, fake: ConcurrencySupabase):
        from app.services.pretest_service import submit_pretest

        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", side_effect=self._live_fetch(fake)),
        ):
            return submit_pretest("stu-1", "mod_01", self._answers("mod_01"))

    def _sync(self, fake: ConcurrencySupabase, posterior: float = 0.55):
        with (
            patch("app.services.progress_service.fetch_student_by_id", side_effect=self._live_fetch(fake)),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", ProgressSyncRequest(mastery_matrix={"phishing": posterior}))

    def _diagnostic(self, prior: float) -> float:
        from app.data.pretest_questions import questions_for_module
        from app.services.bkt_service import initial_pl, update_pl_diagnostic

        value = initial_pl(prior)
        for question in questions_for_module("mod_01"):
            if question["topic"] == "Phishing":
                value = round(update_pl_diagnostic(value, True), 4)
        return value

    def _assert_tables_agree(self, fake: ConcurrencySupabase, value: float) -> None:
        self.assertEqual(fake.student_row["mastery_phishing"], value)
        self.assertEqual(fake.bkt_rows[("stu-1", "Phishing")]["probability_known"], value)

    def test_a_pretest_committing_inside_a_practice_sync_keeps_the_official_result(self):
        fake = self._fake()
        graded = {}

        def grade() -> None:
            fake.before_mastery_update = None
            graded["result"] = self._submit_pretest(fake)

        fake.before_mastery_update = grade
        self.assertTrue(self._sync(fake).ok)
        official = self._diagnostic(0.20)
        self.assertEqual(graded["result"].mastery.Phishing, official)
        self._assert_tables_agree(fake, official)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["phishing"], official)

    def test_b_practice_committing_before_the_pretest_write_becomes_its_prior(self):
        fake = self._fake()

        def practice(name: str) -> None:
            if name == "levelblue_record_pretest_result":
                fake.before_rpc = None
                self.assertTrue(self._sync(fake).ok)

        fake.before_rpc = practice
        result = self._submit_pretest(fake)
        official = self._diagnostic(0.55)
        self.assertEqual(result.mastery.Phishing, official)
        self._assert_tables_agree(fake, official)
        writes = [p for n, p in fake.rpcs if n == "levelblue_record_pretest_result"]
        self.assertEqual([w["p_expected_prior"] for w in writes], [0.20, 0.55])

    def test_c_practice_after_the_pretest_replaces_it_in_both_tables(self):
        fake = self._fake()
        self._submit_pretest(fake)
        self.assertTrue(self._sync(fake, 0.61).ok)
        self._assert_tables_agree(fake, 0.61)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})


class AccountAndActivityClassificationTest(unittest.TestCase):
    """Administrative status, mastery labels, and learning time stay separate."""

    def _answers(self):
        from app.data.pretest_questions import questions_for_module
        from app.schemas.pretest import PretestAnswerPayload

        bank = questions_for_module("mod_01")
        return [PretestAnswerPayload(id=question["id"], answer=question["answer"]) for question in bank]

    def test_inactive_pretest_cannot_become_on_track(self):
        from app.services.pretest_service import submit_pretest

        fake = ColumnSchemaSupabase()
        fake.student_row = {"id": "stu-1", "status": "Inactive", "module_pretests": {}}
        before = dict(fake.student_row)
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", return_value=dict(before)),
        ):
            with self.assertRaises(HTTPException) as ctx:
                submit_pretest("stu-1", "mod_01", self._answers())
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertEqual(ctx.exception.detail, "This student account is inactive")
        self.assertEqual(fake.student_row, before)
        self.assertNotIn("students", fake.updates)
        self.assertEqual(fake.bkt_rows, {})

    def test_archived_pretest_cannot_become_at_risk(self):
        from app.services.pretest_service import submit_pretest

        fake = ColumnSchemaSupabase()
        fake.student_row = {"id": "stu-1", "status": "Archived", "module_pretests": {}}
        before = dict(fake.student_row)
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student", return_value=dict(before)),
        ):
            with self.assertRaises(HTTPException) as ctx:
                submit_pretest("stu-1", "mod_01", [])
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertNotIn("archived", ctx.exception.detail.lower())
        self.assertEqual(fake.student_row["status"], "Archived")
        self.assertNotIn("mastery_phishing", fake.student_row)
        self.assertNotIn("students", fake.updates)

    def test_restricted_accounts_cannot_use_pretest_questions_bkt_or_progress(self):
        from app.routes.progress import get_progress
        from app.services.assess_service import fetch_bkt_state
        from app.services.pretest_service import list_pretest_questions

        for label in ("Inactive", "archived"):
            with self.subTest(endpoint="questions", status=label):
                with (
                    patch("app.services.pretest_service._fetch_student", return_value={"id": "stu-1", "status": label}),
                    self.assertRaises(HTTPException) as ctx,
                ):
                    list_pretest_questions("stu-1", "mod_01")
                self.assertEqual(ctx.exception.status_code, 403)
            with self.subTest(endpoint="bkt-state", status=label):
                with (
                    patch("app.services.assess_service.fetch_student_by_id", return_value={"id": "stu-1", "status": label}),
                    patch("app.services.assess_service.supabase") as database,
                    self.assertRaises(HTTPException) as ctx,
                ):
                    fetch_bkt_state("stu-1")
                self.assertEqual(ctx.exception.status_code, 403)
                database.table.assert_not_called()
            with self.subTest(endpoint="progress-sync", status=label):
                database = FakeSupabase()
                with (
                    patch("app.services.progress_service.fetch_student_by_id", return_value={"id": "stu-1", "status": label}),
                    patch("app.services.progress_service.supabase", database),
                    self.assertRaises(HTTPException) as ctx,
                ):
                    sync_student_progress("stu-1", ProgressSyncRequest(credits=1))
                self.assertEqual(ctx.exception.status_code, 403)
                self.assertEqual(database.updates, {})
            with self.subTest(endpoint="progress-read", status=label):
                with (
                    patch("app.routes.progress.verify_token", return_value={"id": "stu-1", "role": "student"}),
                    patch("app.routes.progress.fetch_student_by_id", return_value={"id": "stu-1", "status": label}),
                    patch("app.routes.progress.fetch_student_progress") as reader,
                    self.assertRaises(HTTPException) as ctx,
                ):
                    get_progress("Bearer token")
                self.assertEqual(ctx.exception.status_code, 403)
                reader.assert_not_called()

    def test_new_student_and_unevidenced_prior_are_not_low_mastery(self):
        from app.services.pretest_service import assessed_topic_status

        self.assertIsNone(assessed_topic_status(
            {"status": "Needs Review", "mastery_phishing": 0.10},
            "Phishing",
            None,
            {},
        ))
        self.assertEqual(assessed_topic_status({"mastery_phishing": 0.10}, "Smishing", 0.80), "On Track")
        self.assertEqual(assessed_topic_status({}, "Phishing", 0.20), "At Risk")
        fake = FakeSupabase()
        with (
            patch("app.services.progress_service.fetch_student_by_id", return_value={
                "id": "stu-1",
                "status": "Needs Review",
                "highest_unlocked_stage": 1,
                "mastery_phishing": 0.10,
            }),
            patch("app.services.progress_service.supabase", fake),
        ):
            self.assertTrue(sync_student_progress("stu-1", ProgressSyncRequest(
                mastery_matrix={"phishing": 0.10},
            )).ok)
        for update in fake.updates.get("students", []):
            self.assertNotIn("status", update)
            self.assertNotIn("last_active", update)

    def _activity(self, student: dict, payload: ProgressSyncRequest) -> dict:
        fake = FakeSupabase()
        with (
            patch("app.services.progress_service.fetch_student_by_id", return_value=dict(student)),
            patch("app.services.progress_service.supabase", fake),
            patch("app.services.progress_service.record_learning_events", return_value=[]),
        ):
            self.assertTrue(sync_student_progress("stu-1", payload).ok)
        self.assertTrue(fake.updates.get("students"))
        return fake.updates["students"][0]

    def test_learning_activity_uses_event_time_and_does_not_invent_any(self):
        from datetime import UTC, datetime, timedelta
        from uuid import uuid4
        from app.services.learning_records import LearningEvent

        now = datetime.now(UTC)
        week = now - timedelta(days=7)
        older = now - timedelta(days=14)
        newer = now - timedelta(days=1)
        student = {"id": "stu-1", "status": "Needs Review", "highest_unlocked_stage": 1}
        evidence = {
            "topics": {"phishing": 1},
            "responses": 1,
            "sessions": 1,
            "first_at": int(older.timestamp()),
            "last_at": week.timestamp(),
        }
        event = LearningEvent(
            event_id=uuid4(),
            kind="mastery",
            module_id="mod_01",
            occurred_at=older,
            mastery=0.2,
        )
        stamped = self._activity(student, ProgressSyncRequest(
            learning_events=[event],
            learning_evidence=evidence,
            mastery_matrix={"phishing": 0.42},
        ))
        actual = datetime.fromisoformat(stamped["last_active"])
        self.assertLess(abs((actual - week).total_seconds()), 1)
        self.assertGreater((now - actual).total_seconds(), 6 * 24 * 3600)
        self.assertNotIn("just now", stamped["last_active"].lower())

        untouched = self._activity(
            {**student, "updated_at": now.isoformat(), "last_active": None},
            ProgressSyncRequest(credits=2),
        )
        self.assertNotIn("last_active", untouched)

        moved = self._activity(
            {**student, "last_active": older.isoformat()},
            ProgressSyncRequest(learning_evidence={
                "topics": {"phishing": 2},
                "responses": 2,
                "sessions": 2,
                "first_at": int(older.timestamp()),
                "last_at": newer.timestamp(),
            }),
        )
        self.assertLess(abs((datetime.fromisoformat(moved["last_active"]) - newer).total_seconds()), 1)

        kept = self._activity(
            {**student, "last_active": newer.isoformat()},
            ProgressSyncRequest(learning_evidence={
                "topics": {"phishing": 1},
                "responses": 1,
                "sessions": 1,
                "first_at": int(older.timestamp()),
                "last_at": older.timestamp(),
            }),
        )
        self.assertNotIn("last_active", kept)

        future = self._activity(student, ProgressSyncRequest(learning_evidence={
            "topics": {"phishing": 1},
            "responses": 1,
            "sessions": 1,
            "first_at": 1,
            "last_at": (now + timedelta(days=2)).timestamp(),
        }))
        self.assertNotIn("last_active", future)
        malformed = self._activity(
            {**student, "last_active": "Just now"},
            ProgressSyncRequest(learning_evidence={
                "topics": {"phishing": 1},
                "responses": 1,
                "sessions": 1,
                "first_at": "yesterday",
                "last_at": "tomorrow",
            }),
        )
        self.assertNotIn("last_active", malformed)


class BktStateAndRetiredAssessTest(unittest.TestCase):
    def _state(self, student: dict, rows: list[dict]):
        from app.services.assess_service import fetch_bkt_state

        database = FakeSupabase()
        for row in rows:
            database.bkt_rows[("stu-1", row["topic"])] = dict(row, student_id="stu-1")
        with (
            patch("app.services.assess_service.fetch_student_by_id", return_value=dict(student, id="stu-1")),
            patch("app.services.assess_service.supabase", database),
        ):
            return fetch_bkt_state("stu-1")

    def test_state_keeps_full_precision_at_the_mastery_bands(self):
        # Four-decimal rounding turned each of these into 0.4000, 0.7000 or 0.9000 and changed its band.
        state = self._state({}, [
            {"topic": "Phishing", "probability_known": 0.39996},
            {"topic": "Smishing", "probability_known": 0.69996},
            {"topic": "Vishing", "probability_known": 0.899996},
        ])
        self.assertEqual(state.mastery["Phishing"], 0.39996)
        self.assertEqual(state.gameplay["phishing"], 0.39996)
        self.assertLess(state.mastery["Phishing"], 0.40)
        self.assertLess(state.mastery["Smishing"], 0.70)
        self.assertLess(state.mastery["Vishing"], 0.90)

    def test_state_ignores_nonstandard_topics(self):
        state = self._state({"mastery_phishing": 0.52}, [
            {"topic": "Phishing", "probability_known": 0.61},
            {"topic": "ports", "probability_known": 0.95},
            {"topic": "phishing", "probability_known": 0.11},
        ])
        self.assertEqual(set(state.mastery), {"Phishing", "Smishing", "Vishing", "Pretexting", "Baiting"})
        self.assertEqual(set(state.gameplay), {"phishing", "smishing", "vishing", "pretexting", "baiting"})
        self.assertEqual(state.mastery["Phishing"], 0.61)

    def test_retired_assess_returns_410_writes_nothing_and_logs_without_details(self):
        from app.routes import bkt

        database = FakeSupabase()
        with (
            patch("app.services.database_diagnostics._last_event_at", {}),
            patch("app.services.database_diagnostics.supabase", database),
        ):
            for _ in range(2):
                with self.assertRaises(HTTPException) as ctx:
                    bkt.assess()
                self.assertEqual(ctx.exception.status_code, status.HTTP_410_GONE)
        self.assertEqual(database.updates, {})
        self.assertEqual(database.upserts, {})
        self.assertEqual(database.bkt_rows, {})
        events = [params for name, params in database.rpcs if name == "levelblue_log_operational_event"]
        self.assertEqual(events, [{
            "p_category": "api-error",
            "p_message": "A client called the retired /api/bkt/assess endpoint.",
            "p_code": "bkt-assess-retired",
            "p_route": "/api/bkt/assess",
            "p_status": 410,
        }])

    def test_retired_assess_route_accepts_any_body_without_validation(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient

        from app.routes import bkt

        app = FastAPI()
        app.include_router(bkt.router)
        with patch("app.routes.bkt.log_operational_event"):
            response = TestClient(app).post("/api/bkt/assess", json={"skill_id": "phishing", "is_correct": True})
        self.assertEqual(response.status_code, 410)


class EvidenceTimestampValidationTest(unittest.TestCase):
    """first_at / last_at follow the R7 learning-time rule: 2020 or later, at most 10 minutes ahead."""

    def setUp(self):
        from datetime import UTC, datetime

        self.now = int(datetime.now(UTC).timestamp())
        self.week_ago = self.now - 7 * 86400

    def _sync(self, fake: FakeSupabase, payload: ProgressSyncRequest):
        with (
            patch("app.services.progress_service.fetch_student_by_id",
                  return_value={"id": "stu-1", "highest_unlocked_stage": 1}),
            patch("app.services.progress_service.supabase", fake),
        ):
            return sync_student_progress("stu-1", payload)

    def _stored_evidence(self, fake: StatefulSupabase) -> dict:
        return fake.save_rows[0]["payload"]["learning_evidence"]

    def _upload(self, first_at: object, last_at: object) -> ProgressSyncRequest:
        return ProgressSyncRequest(
            mastery_matrix={"phishing": 0.30},
            learning_evidence={
                "topics": {"phishing": 10},
                "responses": 10,
                "sessions": 2,
                "first_at": first_at,
                "last_at": last_at,
            },
        )

    def test_pre_2020_first_at_is_ignored_and_evidence_kept(self):
        for ancient in (1, 1500000000):
            fake = StatefulSupabase()
            self.assertTrue(self._sync(fake, self._upload(ancient, self.now)).ok)
            evidence = self._stored_evidence(fake)
            self.assertNotIn("first_at", evidence, ancient)
            self.assertEqual(evidence["topics"], {"phishing": 10})
            self.assertEqual(evidence["responses"], 10)
            self.assertEqual(evidence["sessions"], 2)
            self.assertEqual(evidence["last_at"], self.now)

    def test_far_future_timestamps_are_ignored(self):
        future = self.now + 365 * 86400
        fake = StatefulSupabase()
        self.assertTrue(self._sync(fake, self._upload(future, future)).ok)
        evidence = self._stored_evidence(fake)
        self.assertNotIn("first_at", evidence)
        self.assertNotIn("last_at", evidence)
        self.assertEqual(evidence["topics"], {"phishing": 10})
        self.assertEqual(evidence["responses"], 10)
        valid_first = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.30},
            learning_evidence={"topics": {"phishing": 11}, "sessions": 3,
                               "first_at": self.week_ago, "last_at": self.now},
        )
        self.assertTrue(self._sync(fake, valid_first).ok)
        evidence = self._stored_evidence(fake)
        self.assertEqual(evidence["first_at"], self.week_ago)
        self.assertEqual(evidence["last_at"], self.now)

    def test_ten_minute_skew_is_still_plausible(self):
        fake = StatefulSupabase()
        ahead = self.now + 5 * 60
        self.assertTrue(self._sync(fake, self._upload(self.week_ago, ahead)).ok)
        self.assertEqual(self._stored_evidence(fake)["last_at"], ahead)

    def test_stored_invalid_first_at_yields_to_a_valid_upload(self):
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": {
            "mastery_matrix": {"phishing": 0.30},
            "learning_evidence": {"topics": {"phishing": 4}, "responses": 4, "sessions": 1,
                                  "first_at": 1, "last_at": 1},
        }}]
        self.assertTrue(self._sync(fake, self._upload(self.week_ago, self.now)).ok)
        evidence = self._stored_evidence(fake)
        self.assertEqual(evidence["first_at"], self.week_ago)
        self.assertEqual(evidence["last_at"], self.now)
        sparse = ProgressSyncRequest(mastery_matrix={"phishing": 0.30}, credits=3)
        self.assertTrue(self._sync(fake, sparse).ok)
        evidence = self._stored_evidence(fake)
        self.assertEqual(evidence["first_at"], self.week_ago)
        self.assertEqual(evidence["topics"], {"phishing": 10})

    def test_sparse_sync_does_not_copy_an_invalid_stored_first_at(self):
        fake = StatefulSupabase()
        fake.save_rows = [{"payload": {
            "mastery_matrix": {"phishing": 0.30},
            "learning_evidence": {"topics": {"phishing": 4}, "responses": 4, "sessions": 1,
                                  "first_at": 1, "last_at": self.now + 365 * 86400},
        }}]
        payload = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.30},
            learning_evidence={"topics": {"phishing": 5}, "sessions": 2},
        )
        self.assertTrue(self._sync(fake, payload).ok)
        evidence = self._stored_evidence(fake)
        self.assertNotIn("first_at", evidence)
        self.assertNotIn("last_at", evidence)
        self.assertEqual(evidence["topics"], {"phishing": 5})
        self.assertEqual(evidence["responses"], 5)

    def test_offline_upload_merges_chronologically_without_duplicating(self):
        fake = StatefulSupabase()
        earlier = self.now - 10 * 86400
        fake.save_rows = [{"payload": {
            "mastery_matrix": {"phishing": 0.30},
            "learning_evidence": {"topics": {"phishing": 6}, "responses": 6, "sessions": 2,
                                  "first_at": earlier, "last_at": earlier + 3600},
        }}]
        offline = ProgressSyncRequest(
            mastery_matrix={"phishing": 0.35, "smishing": 0.30},
            learning_evidence={"topics": {"phishing": 6, "smishing": 4}, "responses": 10,
                               "sessions": 3, "first_at": self.week_ago, "last_at": self.now},
        )
        self.assertTrue(self._sync(fake, offline).ok)
        self.assertTrue(self._sync(fake, offline).ok)
        evidence = self._stored_evidence(fake)
        self.assertEqual(evidence["first_at"], earlier)
        self.assertEqual(evidence["last_at"], self.now)
        self.assertEqual(evidence["topics"], {"phishing": 6, "smishing": 4})
        self.assertEqual(evidence["responses"], 10)
        self.assertEqual(evidence["sessions"], 3)


if __name__ == "__main__":
    unittest.main()
