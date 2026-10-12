-- Phase 4A: persistent online PvP match history.
-- Apply once in the Supabase SQL editor. Safe to re-run.
-- Written only by the backend (service role) from server-authoritative results.
-- Rooms that never had two players get no row. abandoned_before_start rows are kept for
-- audit but excluded from all stats.
-- Stats are derived from these rows; nothing here touches BKT/mastery tables.

create table if not exists public.pvp_matches (
    match_id          uuid        primary key,
    origin            text        not null check (origin in ('private', 'matchmaking')),
    player1_id        uuid        not null references public.students (id) on delete cascade,
    player2_id        uuid        not null references public.students (id) on delete cascade,
    winner_id         uuid,
    forfeited_by      uuid,
    finish_reason     text        not null check (finish_reason in ('ko', 'forfeit_disconnect', 'forfeit_leave', 'abandoned_before_start')),
    player1_hp        smallint    not null check (player1_hp between 0 and 100),
    player2_hp        smallint    not null check (player2_hp between 0 and 100),
    player1_correct   smallint    not null default 0 check (player1_correct >= 0),
    player2_correct   smallint    not null default 0 check (player2_correct >= 0),
    player1_wrong     smallint    not null default 0 check (player1_wrong >= 0),
    player2_wrong     smallint    not null default 0 check (player2_wrong >= 0),
    player1_timeouts  smallint    not null default 0 check (player1_timeouts >= 0),
    player2_timeouts  smallint    not null default 0 check (player2_timeouts >= 0),
    rounds_played     smallint    not null default 0 check (rounds_played >= 0),
    started_at        timestamptz,
    finished_at       timestamptz not null,
    recorded_at       timestamptz not null default now(),
    constraint pvp_matches_distinct_players check (player1_id <> player2_id),
    constraint pvp_matches_winner_is_player check (winner_id is null or winner_id in (player1_id, player2_id)),
    constraint pvp_matches_forfeit_is_player check (forfeited_by is null or forfeited_by in (player1_id, player2_id)),
    constraint pvp_matches_start_matches_reason check ((finish_reason = 'abandoned_before_start') = (started_at is null)),
    constraint pvp_matches_finish_after_start check (started_at is null or finished_at >= started_at),
    constraint pvp_matches_abandoned_has_no_rounds check (finish_reason <> 'abandoned_before_start' or rounds_played = 0),
    constraint pvp_matches_abandoned_has_no_winner check (finish_reason <> 'abandoned_before_start' or winner_id is null)
);

create index if not exists pvp_matches_player1_recent on public.pvp_matches (player1_id, finished_at desc);
create index if not exists pvp_matches_player2_recent on public.pvp_matches (player2_id, finished_at desc);

-- No policies: anon/authenticated clients get nothing. The backend reads/writes with the service role
-- and only ever returns the caller's own rows.
alter table public.pvp_matches enable row level security;
revoke all on table public.pvp_matches from anon, authenticated;
