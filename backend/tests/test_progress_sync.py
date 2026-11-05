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

    @property
    def not_(self):
        self._negate = True
        return self

    def contains(self, column, value):
        self._contains = (column, value, getattr(self, "_negate", False))
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
        topics = {row["topic"] for row in fake.upserts["bkt_records"][0]}
        self.assertEqual(topics, {"Phishing"})
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
        self.assertEqual(len(fake.upserts["bkt_records"]), 2)
        for batch in fake.upserts["bkt_records"]:
            self.assertEqual({row["topic"] for row in batch}, {"Phishing"})
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
        topics = {row["topic"] for row in fake.upserts["bkt_records"][0]}
        self.assertEqual(topics, {"Phishing", "Smishing"})
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
                "first_at": 1800000000,
                "last_at": 1800000500,
            },
        )
        self.assertTrue(self._sync(fake, payload).ok)
        evidence = fake.save_rows[0]["payload"]["learning_evidence"]
        self.assertEqual(evidence["topics"], {"phishing": 4, "pretexting": 2})
        self.assertEqual(evidence["first_at"], 1700000000)
        self.assertEqual(evidence["last_at"], 1800000500)
        self.assertEqual(evidence["sessions"], 2)
        self.assertEqual(evidence["responses"], 6)
        self.assertAlmostEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["pretexting"], 0.10)
        self.assertAlmostEqual(fake.save_rows[0]["payload"]["mastery_matrix"]["phishing"], 0.52)

    def test_student_mastery_column_update_fails_raises_non_2xx(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run(FakeSupabase(fail_nth={("students", 2)}))
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(ctx.exception.detail, "Database request failed")


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


class LegacyPretestFallbackTest(unittest.TestCase):
    EXISTING = {"mastery_matrix": {"phishing": 0.8}, "lesson_progress": {"mod_01": 7}, "credits": 50}

    def _submit(self, fake, stale_row: dict | None = None):
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
        with (
            patch("app.services.pretest_service.supabase", fake),
            patch("app.services.pretest_service._fetch_student",
                  side_effect=lambda _sid: dict(stale_row if stale_row is not None else fake.student_row)),
        ):
            return submit_pretest("stu-1", "mod_01", answers)

    def _clean_row(self) -> dict:
        fake = self._fake()
        self._submit(fake)
        return dict(fake.student_row)

    def test_retry_after_failed_flag_write_applies_diagnostic_once(self):
        expected = self._clean_row()
        fake = self._fake(fail_nth={("player_saves", 3)})
        with self.assertRaises(HTTPException):
            self._submit(fake)
        self._submit(fake)
        self.assertEqual(fake.student_row, expected, "retry must not re-apply the diagnostic to updated mastery")
        self.assertEqual(fake.save_rows[0]["payload"]["module_pretests"], {"mod_01": True})

    def test_retry_after_failed_mastery_write_applies_diagnostic_once(self):
        expected = self._clean_row()
        fake = self._fake(fail_nth={("students", 2)})
        with self.assertRaises(HTTPException):
            self._submit(fake)
        self.assertNotIn("module_pretests", fake.save_rows[0]["payload"], "flag is rolled back so the retry is accepted")
        self.assertEqual(fake.save_rows[0]["payload"], self.EXISTING)
        self._submit(fake)
        self.assertEqual(fake.student_row, expected)
        self.assertEqual(fake.save_rows[0]["payload"]["module_pretests"], {"mod_01": True})

    def test_failed_rollback_rejects_retry_instead_of_reapplying(self):
        fake = self._fake(fail_nth={("students", 2), ("player_saves", 4)})
        with self.assertRaises(HTTPException):
            self._submit(fake)
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(ctx.exception.detail, "Pre-test already completed")
        self.assertNotIn("mastery_phishing", fake.student_row)

    def test_mastery_rollback_without_prior_save_removes_flag_row(self):
        fake = self._fake(fail_nth={("students", 2)})
        fake.save_rows = []
        with self.assertRaises(HTTPException):
            self._submit(fake)
        self.assertEqual(fake.deletes, ["player_saves"])

    def _fake(self, **kwargs):
        fake = LegacySchemaSupabase(**kwargs)
        fake.save_rows = [{"payload": dict(self.EXISTING)}]
        return fake

    def test_failed_flag_read_aborts_before_any_write(self):
        fake = self._fake(fail={"player_saves"})
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake)
        self.assertEqual(ctx.exception.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertNotIn("students", fake.updates)
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.bkt_rows, {})

    def test_failed_fallback_read_leaves_mastery_and_save_untouched(self):
        fake = self._fake(fail_nth={("player_saves", 2)})
        with self.assertRaises(HTTPException):
            self._submit(fake)
        self.assertEqual(len(fake.updates["students"]), 1, "only the rejected column write was attempted")
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.bkt_rows, {})

    def test_failed_flag_write_is_reported(self):
        fake = self._fake(fail_nth={("player_saves", 3)})
        with self.assertRaises(HTTPException) as ctx:
            self._submit(fake)
        self.assertEqual(ctx.exception.detail, "Database request failed")
        self.assertNotIn("secret-token", str(ctx.exception.detail))

    def test_flags_are_added_to_the_existing_save(self):
        fake = self._fake()
        result = self._submit(fake)
        self.assertTrue(result.preTestCompleted)
        stored = fake.upserts["player_saves"][0]["payload"]
        self.assertEqual(stored["module_pretests"], {"mod_01": True})
        for key, value in self.EXISTING.items():
            self.assertEqual(stored[key], value)


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


class ColumnPretestTest(LegacyPretestFallbackTest):
    """Same submission helper; the legacy-only cases are not inherited."""

    def _fake(self, **kwargs):
        fake = ColumnSchemaSupabase(**kwargs)
        fake.save_rows = [{"payload": dict(self.EXISTING)}]
        return fake

    def _legacy_row(self) -> dict:
        legacy = LegacySchemaSupabase()
        legacy.save_rows = [{"payload": dict(self.EXISTING)}]
        LegacyPretestFallbackTest._submit(self, legacy)
        return {k: v for k, v in legacy.student_row.items()}

    def test_submit_is_one_conditional_write_and_leaves_the_save_alone(self):
        fake = self._fake()
        self._submit(fake)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True})
        self.assertEqual(fake.executes.count("students"), 1)
        self.assertNotIn("player_saves", fake.upserts)
        self.assertEqual(fake.save_rows[0]["payload"], self.EXISTING)
        expected = self._legacy_row()
        for key in ("mastery_phishing", "pre", "status"):
            self.assertEqual(fake.student_row[key], expected[key], "same BKT result as the legacy path")

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
        fake = self._fake(fail_nth={("students", 1)})
        with self.assertRaises(HTTPException):
            self._submit(fake)
        self.assertEqual(fake.student_row, {"id": "stu-1", "module_pretests": {}})
        self._submit(fake)
        self.assertEqual(fake.student_row, expected_fake.student_row)

    def test_unbackfilled_legacy_flags_are_kept_in_the_column(self):
        fake = self._fake()
        fake.save_rows = [{"payload": dict(self.EXISTING, module_pretests=["mod_02"])}]
        self._submit(fake)
        self.assertEqual(fake.student_row["module_pretests"], {"mod_01": True, "mod_02": True})
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

    # Legacy-only scenarios do not apply once the column exists.
    test_failed_flag_read_aborts_before_any_write = None
    test_failed_fallback_read_leaves_mastery_and_save_untouched = None
    test_failed_flag_write_is_reported = None
    test_flags_are_added_to_the_existing_save = None
    test_retry_after_failed_flag_write_applies_diagnostic_once = None
    test_retry_after_failed_mastery_write_applies_diagnostic_once = None
    test_failed_rollback_rejects_retry_instead_of_reapplying = None
    test_mastery_rollback_without_prior_save_removes_flag_row = None


if __name__ == "__main__":
    unittest.main()
