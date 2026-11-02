# Pre-test completion column (`students.module_pretests`)

Status: prepared and verified locally only. Not applied to any Supabase project.

## Why

Without the column, the mobile API stores pre-test completion flags in `player_saves.payload`. That needs separate writes (flag, then mastery) and rewrites the whole save, so a concurrent progress upload can overwrite the flag or be overwritten by it. With the column, `submit_pretest` stores completion, mastery, status and the Module 1 `pre` score in **one** conditional `students` update. Other saved fields are not affected.

## Files

- Migration (authoritative shared schema): `web-LevelBlue/backend/migrations/20261031_student_module_pretests.sql`
- API: `backend/app/services/pretest_service.py`. On the column path, the update only matches while the module is not yet marked complete (`not module_pretests @> {"mod_xx": true}`). If no row matches, the API returns `400 Pre-test already completed`, the response the client already treats as done.
- Tests (local only): `LegacyPretestFallbackTest` and `ColumnPretestTest` in `backend/tests/test_progress_sync.py`.

## What the migration does

1. Adds `module_pretests jsonb not null default '{}'`, checked to be an object. If a hand-made `jsonb` column already exists, it fills nulls with `{}` and sets the default and `not null`; if any value is not an object (for example an array of flags), it stops without changes so those flags can be converted manually. Any other existing type stops the migration without changes.
2. Backfills flags from `player_saves.payload.module_pretests` in both stored shapes, `{"mod_01": true}` and `["mod_01"]`. It merges into existing column flags, copies only `mod_01`–`mod_05`, and is idempotent.
3. Reloads the PostgREST schema cache. All of this runs in one transaction.

It does not modify mastery columns, `bkt_records`, lessons, wallets or any `player_saves` payload.

## Compatibility

- **Before the migration:** the API detects the missing column and uses the legacy fallback: read the save, write the flag, write mastery, and roll the flag back if the mastery write fails.
- **After the migration, without the backfill or for unparsed string flags:** a student with `{}` in the column still has flags read from `player_saves`, and the next completion writes the merged set into the column.
- **Deploy order:** either order works. The older API also writes the column once it exists, though without the conditional update.

## Deployment-owner procedure

1. Back up the database, or confirm point-in-time recovery is enabled.
2. Run the migration against a staging copy first, in the Supabase SQL editor.
3. Check the result with counts only (no student details):
   ```sql
   select data_type, is_nullable, column_default from information_schema.columns
    where table_schema='public' and table_name='students' and column_name='module_pretests';
   select count(*) filter (where module_pretests <> '{}') as with_flags, count(*) as students from public.students;
   select count(*) as legacy_string_flags from public.player_saves
    where jsonb_typeof(payload->'module_pretests') = 'string';
   ```
   If `legacy_string_flags` is non-zero, those students keep working through the fallback; tell the mobile team before the fallback is ever removed.
4. Apply to production during low activity, then submit one test pre-test on a test account and confirm a second submission returns "Pre-test already completed".
5. Keep the API's legacy fallback until every environment has the column. Remove it later in a separate, reviewed change.

## Rollback

- **Do not drop the column.** Completions recorded after the migration exist only there; dropping it would let students retake pre-tests and lose their completion state.
- **Reverting the API code** needs no schema change.
- **If the column truly must be removed**, first copy its flags back into the saves, with progress sync paused because it rewrites payloads:
  ```sql
  update public.player_saves ps set payload = jsonb_set(ps.payload, '{module_pretests}',
         coalesce(case when jsonb_typeof(ps.payload->'module_pretests')='object' then ps.payload->'module_pretests' end,'{}'::jsonb) || s.module_pretests)
    from public.students s where s.id = ps.student_id and s.module_pretests <> '{}';
  ```
  Students with flags but no `player_saves` row would also need a row created. Only then drop the constraint and column, and reload the schema.

## Remaining risks

- `bkt_records` is still updated separately on a best-effort basis; the `students` mastery columns stay the source of truth.
- The progress upload may still overwrite `students.mastery_*` with the client's local value, as it does today. The pre-test flag itself can no longer be overwritten.
- Cross-device whole-snapshot overwrites in `player_saves` progress sync are a separate issue that this migration does not address.
