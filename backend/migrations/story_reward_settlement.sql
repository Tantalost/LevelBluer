-- Deploy before the corresponding API. Existing save table; no second wallet.
-- All API save writers use this CAS, including requests from older clients.
create or replace function public.levelblue_compare_save(
    p_student_id uuid, p_expected jsonb, p_payload jsonb
) returns boolean
language plpgsql security definer set search_path = public
as $$
declare current_payload jsonb;
begin
    -- Serializes the absent-row case as well as existing rows.
    perform pg_advisory_xact_lock(hashtextextended(p_student_id::text, 77103));
    select payload into current_payload from public.player_saves
        where student_id = p_student_id for update;
    if current_payload is distinct from p_expected then return false; end if;
    insert into public.player_saves(student_id, payload, updated_at)
        values(p_student_id, p_payload, now())
        on conflict(student_id) do update set payload = excluded.payload, updated_at = excluded.updated_at;
    return true;
end;
$$;
revoke all on function public.levelblue_compare_save(uuid, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.levelblue_compare_save(uuid, jsonb, jsonb) to service_role;
