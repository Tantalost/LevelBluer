-- Phase 4B: PvP Points (Elo-style, K=32, start 1000, floor 0) for automatic matchmaking only.
-- Apply once in the Supabase SQL editor after pvp_match_history.sql, then: notify pgrst, 'reload schema';
-- Server-only (service role). Separate from BKT/mastery/tokens: nothing here touches those tables.
--
-- Rated = origin 'matchmaking' AND started_at not null AND finish_reason in (ko, forfeit_leave,
-- forfeit_disconnect) AND finished_at >= rated_from. Anything else is unrated until a future migration
-- says otherwise. rated_from is fixed when this migration first runs, so earlier matches (including the
-- Phase 4A E2E rows) can never be rated by any path.
--
-- Ratings are applied per player in chronological (finished_at, match_id) order: a match waits while
-- either participant has an older rated-eligible match without rating events.

create table if not exists public.pvp_rating_config (
    id             boolean     primary key default true check (id),
    rated_from     timestamptz not null default now(),
    initial_points integer     not null default 1000 check (initial_points >= 0),
    k_factor       integer     not null default 32 check (k_factor > 0)
);
insert into public.pvp_rating_config (id) values (true) on conflict (id) do nothing;

create table if not exists public.pvp_ratings (
    student_id    uuid        primary key references public.students (id) on delete cascade,
    points        integer     not null default 1000 check (points >= 0),
    rated_matches integer     not null default 0 check (rated_matches >= 0),
    wins          integer     not null default 0 check (wins >= 0),
    losses        integer     not null default 0 check (losses >= 0),
    draws         integer     not null default 0 check (draws >= 0),
    peak_points   integer     not null default 1000,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    constraint pvp_ratings_tally check (wins + losses + draws = rated_matches),
    constraint pvp_ratings_peak  check (peak_points >= points)
);

create table if not exists public.pvp_rating_events (
    match_id               uuid        not null references public.pvp_matches (match_id) on delete cascade,
    student_id             uuid        not null references public.students (id) on delete cascade,
    opponent_id            uuid        not null references public.students (id) on delete cascade,
    result                 text        not null check (result in ('win', 'loss', 'draw')),
    points_before          integer     not null check (points_before >= 0),
    points_after           integer     not null check (points_after >= 0),
    points_delta           integer     not null,
    opponent_points_before integer     not null check (opponent_points_before >= 0),
    k_factor               smallint    not null check (k_factor > 0),
    created_at             timestamptz not null default now(),
    primary key (match_id, student_id),
    -- points_delta is the change actually applied (after the 0 floor), so the ledger always reconciles.
    constraint pvp_rating_events_delta    check (points_after = points_before + points_delta),
    constraint pvp_rating_events_distinct check (student_id <> opponent_id)
);
create index if not exists pvp_rating_events_student_recent on public.pvp_rating_events (student_id, created_at desc);

-- Immutable audit: no UPDATE ever; DELETE only as a cascade from deleting a student/match.
create or replace function public.pvp_rating_events_immutable() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
    if tg_op = 'DELETE' and pg_trigger_depth() > 1 then
        return old;
    end if;
    raise exception 'pvp_rating_events is an immutable audit log' using errcode = '42501';
end $$;
drop trigger if exists pvp_rating_events_no_change on public.pvp_rating_events;
create trigger pvp_rating_events_no_change before update or delete on public.pvp_rating_events
    for each row execute function public.pvp_rating_events_immutable();

-- Checked at COMMIT: a rated match always has exactly two ledger rows, never one.
create or replace function public.pvp_rating_events_pair_check() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
    if (select count(*) from public.pvp_rating_events where match_id = new.match_id) <> 2 then
        raise exception 'pvp_rating_events must hold exactly two rows for match %', new.match_id using errcode = '23514';
    end if;
    return null;
end $$;
drop trigger if exists pvp_rating_events_pair on public.pvp_rating_events;
create constraint trigger pvp_rating_events_pair after insert on public.pvp_rating_events
    deferrable initially deferred for each row execute function public.pvp_rating_events_pair_check();

create or replace function public.levelblue_pvp_is_rated(m public.pvp_matches, cutoff timestamptz) returns boolean
language sql stable set search_path = public, pg_temp as $$
    select m.origin = 'matchmaking'
       and m.started_at is not null
       and m.finish_reason in ('ko', 'forfeit_leave', 'forfeit_disconnect')
       and m.finished_at >= cutoff
$$;

-- Applies one rated match atomically from the stored authoritative pvp_matches row.
-- Returns {status: applied | already_applied | unrated | not_recorded | waiting_for_prior_match | conflict}.
create or replace function public.levelblue_apply_pvp_rating(p_match_id uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
    cfg        public.pvp_rating_config%rowtype;
    m          public.pvp_matches%rowtype;
    ra         public.pvp_ratings%rowtype;
    rb         public.pvp_ratings%rowtype;
    low_id     uuid;
    high_id    uuid;
    result_a   text;
    result_b   text;
    existing   integer;
    mismatched integer;
    prior      uuid;
    score_a    numeric;
    expected_a numeric;
    delta_a    integer;
    new_a      integer;
    new_b      integer;
begin
    select * into cfg from public.pvp_rating_config where id;
    select * into m from public.pvp_matches where match_id = p_match_id;
    if not found then
        return jsonb_build_object('status', 'not_recorded', 'match_id', p_match_id);
    end if;
    if not public.levelblue_pvp_is_rated(m, cfg.rated_from) then
        return jsonb_build_object('status', 'unrated', 'match_id', p_match_id,
            'reason', case when m.finished_at < cfg.rated_from then 'before_cutoff' else 'not_ranked' end);
    end if;

    result_a := case when m.winner_id is null then 'draw' when m.winner_id = m.player1_id then 'win' else 'loss' end;
    result_b := case result_a when 'win' then 'loss' when 'loss' then 'win' else 'draw' end;

    -- Deterministic student-id order for both row creation and locking: no deadlocks.
    low_id := least(m.player1_id, m.player2_id);
    high_id := greatest(m.player1_id, m.player2_id);
    insert into public.pvp_ratings (student_id, points, peak_points) values (low_id, cfg.initial_points, cfg.initial_points) on conflict (student_id) do nothing;
    insert into public.pvp_ratings (student_id, points, peak_points) values (high_id, cfg.initial_points, cfg.initial_points) on conflict (student_id) do nothing;
    perform 1 from public.pvp_ratings where student_id = low_id for update;
    perform 1 from public.pvp_ratings where student_id = high_id for update;

    -- Idempotency, evaluated under the locks so a concurrent duplicate sees the committed events.
    select count(*),
           count(*) filter (where not (
               (student_id = m.player1_id and opponent_id = m.player2_id and result = result_a) or
               (student_id = m.player2_id and opponent_id = m.player1_id and result = result_b)))
      into existing, mismatched
      from public.pvp_rating_events where match_id = p_match_id;
    if existing > 0 then
        if existing <> 2 or mismatched > 0 then
            return jsonb_build_object('status', 'conflict', 'match_id', p_match_id);
        end if;
        return jsonb_build_object('status', 'already_applied', 'match_id', p_match_id, 'events',
            (select jsonb_agg(jsonb_build_object('student_id', student_id, 'result', result, 'points_before', points_before,
                     'points_after', points_after, 'points_delta', points_delta) order by student_id)
               from public.pvp_rating_events where match_id = p_match_id));
    end if;

    -- Chronological order per player: never rate past an older unrated match of either participant.
    select pm.match_id into prior
      from public.pvp_matches pm
     where pm.match_id <> m.match_id
       and (pm.player1_id in (m.player1_id, m.player2_id) or pm.player2_id in (m.player1_id, m.player2_id))
       and public.levelblue_pvp_is_rated(pm, cfg.rated_from)
       and (pm.finished_at, pm.match_id) < (m.finished_at, m.match_id)
       and not exists (select 1 from public.pvp_rating_events e where e.match_id = pm.match_id)
     order by pm.finished_at, pm.match_id
     limit 1;
    if prior is not null then
        return jsonb_build_object('status', 'waiting_for_prior_match', 'match_id', p_match_id, 'prior_match_id', prior);
    end if;

    -- Both changes come from the same pre-match values read under the locks.
    select * into ra from public.pvp_ratings where student_id = m.player1_id;
    select * into rb from public.pvp_ratings where student_id = m.player2_id;
    score_a := case result_a when 'win' then 1 when 'loss' then 0 else 0.5 end;
    expected_a := 1 / (1 + power(10::numeric, (rb.points - ra.points)::numeric / 400));
    delta_a := round(cfg.k_factor * (score_a - expected_a));  -- numeric round: halves away from zero
    new_a := greatest(0, ra.points + delta_a);
    new_b := greatest(0, rb.points - delta_a);

    update public.pvp_ratings
       set points = new_a, peak_points = greatest(peak_points, new_a), rated_matches = rated_matches + 1,
           wins = wins + (result_a = 'win')::int, losses = losses + (result_a = 'loss')::int,
           draws = draws + (result_a = 'draw')::int, updated_at = now()
     where student_id = m.player1_id;
    update public.pvp_ratings
       set points = new_b, peak_points = greatest(peak_points, new_b), rated_matches = rated_matches + 1,
           wins = wins + (result_b = 'win')::int, losses = losses + (result_b = 'loss')::int,
           draws = draws + (result_b = 'draw')::int, updated_at = now()
     where student_id = m.player2_id;
    insert into public.pvp_rating_events
        (match_id, student_id, opponent_id, result, points_before, points_after, points_delta, opponent_points_before, k_factor)
    values
        (m.match_id, m.player1_id, m.player2_id, result_a, ra.points, new_a, new_a - ra.points, rb.points, cfg.k_factor),
        (m.match_id, m.player2_id, m.player1_id, result_b, rb.points, new_b, new_b - rb.points, ra.points, cfg.k_factor);

    return jsonb_build_object('status', 'applied', 'match_id', p_match_id, 'events', jsonb_build_array(
        jsonb_build_object('student_id', m.player1_id, 'result', result_a, 'points_before', ra.points, 'points_after', new_a, 'points_delta', new_a - ra.points),
        jsonb_build_object('student_id', m.player2_id, 'result', result_b, 'points_before', rb.points, 'points_after', new_b, 'points_delta', new_b - rb.points)));
end $$;

-- Recovery after a restart: rated-eligible matches with no rating events, oldest first (keyset paging).
create or replace function public.levelblue_pvp_unrated_matches(
    p_after_finished timestamptz default null, p_after_id uuid default null, p_limit integer default 200
) returns table (match_id uuid, player1_id uuid, player2_id uuid, finished_at timestamptz)
language sql stable security definer set search_path = public, pg_temp as $$
    select pm.match_id, pm.player1_id, pm.player2_id, pm.finished_at
      from public.pvp_matches pm
      join public.pvp_rating_config cfg on cfg.id
     where public.levelblue_pvp_is_rated(pm, cfg.rated_from)
       and not exists (select 1 from public.pvp_rating_events e where e.match_id = pm.match_id)
       and (p_after_finished is null or (pm.finished_at, pm.match_id) > (p_after_finished, p_after_id))
     order by pm.finished_at, pm.match_id
     limit least(greatest(p_limit, 1), 1000)
$$;

-- No client access at all: RLS on with no policies, table privileges revoked, functions service-role only.
alter table public.pvp_rating_config enable row level security;
alter table public.pvp_ratings enable row level security;
alter table public.pvp_rating_events enable row level security;
revoke all on table public.pvp_rating_config, public.pvp_ratings, public.pvp_rating_events from anon, authenticated;
revoke all on function public.levelblue_apply_pvp_rating(uuid) from public, anon, authenticated;
revoke all on function public.levelblue_pvp_unrated_matches(timestamptz, uuid, integer) from public, anon, authenticated;
revoke all on function public.levelblue_pvp_is_rated(public.pvp_matches, timestamptz) from public, anon, authenticated;
revoke all on function public.pvp_rating_events_immutable() from public, anon, authenticated;
revoke all on function public.pvp_rating_events_pair_check() from public, anon, authenticated;
grant execute on function public.levelblue_apply_pvp_rating(uuid) to service_role;
grant execute on function public.levelblue_pvp_unrated_matches(timestamptz, uuid, integer) to service_role;
grant execute on function public.levelblue_pvp_is_rated(public.pvp_matches, timestamptz) to service_role;
