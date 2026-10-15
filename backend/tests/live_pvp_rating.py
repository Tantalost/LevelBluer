"""Phase 4B live Supabase verification of the real SQL rating function (two dedicated E2E accounts).

Requires migrations/pvp_ratings.sql applied plus `notify pgrst, 'reload schema';`. Creates real, permanent
rating rows for the two test-only students (the audit log is immutable by design). Prints ids, statuses and
points only, never tokens or personal data. From backend/:

    .venv\\Scripts\\python.exe tests\\live_pvp_rating.py
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dotenv import dotenv_values  # noqa: E402
from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from supabase import create_client  # noqa: E402

from app.config import settings  # noqa: E402
from app.routes.pvp import router  # noqa: E402
from app.services import pvp_history, pvp_rating  # noqa: E402
from app.services.auth_service import _create_token  # noqa: E402
from app.supabase_client import supabase  # noqa: E402

try:
    from tests.test_pvp_rating import reference_apply  # noqa: E402
except ModuleNotFoundError:
    from test_pvp_rating import reference_apply  # noqa: E402

A = "c4e7a659-62ea-4336-8285-d3e9187d9760"
B = "b67bdd08-8ed1-4fe0-ba3c-2ddc3073b6ff"
PHASE_4A_ROWS = ("58444e3b", "548d573c", "7ba22cff")
BACKEND = Path(__file__).resolve().parents[1]
results: list[tuple[bool, str]] = []
matches_made: list[str] = []


def check(ok: bool, message: str) -> None:
    results.append((bool(ok), message))
    print(f"  [{'PASS' if ok else 'FAIL'}] {message}")


def digest(rows: list[dict[str, Any]]) -> str:
    return hashlib.sha256(json.dumps(rows, sort_keys=True, default=str).encode()).hexdigest()[:16]


def protected_snapshot() -> dict[str, str]:
    shot = {}
    for who, sid in (("A", A), ("B", B)):
        shot[f"{who} students"] = digest(supabase.table("students").select("*").eq("id", sid).execute().data)
        shot[f"{who} bkt_records"] = digest(supabase.table("bkt_records").select("*").eq("student_id", sid).order("topic").execute().data)
        shot[f"{who} player_saves"] = digest(supabase.table("player_saves").select("*").eq("student_id", sid).execute().data)
    return shot


def points(student_id: str) -> int:
    rows = supabase.table("pvp_ratings").select("points").eq("student_id", student_id).execute().data
    return int(rows[0]["points"]) if rows else 1000


def rating_row(student_id: str) -> dict[str, Any] | None:
    rows = supabase.table("pvp_ratings").select("points,rated_matches,wins,losses,draws").eq("student_id", student_id).execute().data
    return rows[0] if rows else None


def events(match_id: str) -> list[dict[str, Any]]:
    return supabase.table("pvp_rating_events").select("*").eq("match_id", match_id).execute().data


def store(winner: str | None, finished: datetime, origin: str = "matchmaking", reason: str = "ko", p1: str = A, p2: str = B) -> str:
    match_id = str(uuid.uuid4())
    started = None if reason == "abandoned_before_start" else finished - timedelta(minutes=2)
    loser = None if winner is None else (p2 if winner == p1 else p1)
    pvp_history.insert_match({
        "match_id": match_id, "origin": origin, "player1_id": p1, "player2_id": p2, "winner_id": winner,
        "forfeited_by": loser if reason.startswith("forfeit") else None, "finish_reason": reason,
        "player1_hp": 100 if winner == p1 else 0, "player2_hp": 100 if winner == p2 else 0,
        "player1_correct": 0, "player2_correct": 0, "player1_wrong": 0, "player2_wrong": 0,
        "player1_timeouts": 0, "player2_timeouts": 0, "rounds_played": 0 if started is None else 5,
        "started_at": started.isoformat() if started else None, "finished_at": finished.isoformat(),
    } if reason != "abandoned_before_start" else {
        "match_id": match_id, "origin": origin, "player1_id": p1, "player2_id": p2, "winner_id": None, "forfeited_by": None,
        "finish_reason": reason, "player1_hp": 100, "player2_hp": 100, "player1_correct": 0, "player2_correct": 0,
        "player1_wrong": 0, "player2_wrong": 0, "player1_timeouts": 0, "player2_timeouts": 0, "rounds_played": 0,
        "started_at": None, "finished_at": finished.isoformat(),
    })
    matches_made.append(match_id)
    return match_id


def apply(match_id: str) -> dict[str, Any]:
    return pvp_rating.apply_rating(match_id)


def mine(outcome: dict[str, Any], student_id: str) -> dict[str, Any]:
    return next(e for e in outcome.get("events", []) if e["student_id"] == student_id)


class Clock:
    """Strictly increasing finished_at values just behind now, so later real matches sort after them."""

    def __init__(self) -> None:
        self.at = datetime.now(UTC) - timedelta(seconds=60)

    def next(self) -> datetime:
        self.at += timedelta(seconds=1)
        return self.at


def main() -> int:
    print("Phase 4B live verification against", settings.supabase_url.split("//")[-1].split(".")[0], "(project ref)")
    config = supabase.table("pvp_rating_config").select("rated_from,initial_points,k_factor").execute().data
    check(len(config) == 1 and config[0]["initial_points"] == 1000 and config[0]["k_factor"] == 32, "config row: start 1000, K=32")
    rated_from = pvp_rating._instant(config[0]["rated_from"])
    print("  rated_from =", rated_from.isoformat())
    before = protected_snapshot()
    clock = Clock()

    print("\n1. Access control")
    anon_key = dotenv_values(BACKEND / ".env").get("SUPABASE_ANON_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    if anon_key:
        anon = create_client(settings.supabase_url, anon_key)
        for name, call in (
            ("apply function", lambda: anon.rpc("levelblue_apply_pvp_rating", {"p_match_id": str(uuid.uuid4())}).execute()),
            ("recovery function", lambda: anon.rpc("levelblue_pvp_unrated_matches", {}).execute()),
        ):
            try:
                call()
                check(False, f"anon key can call the {name}")
            except Exception:
                check(True, f"anon key is denied the {name}")
        for table in ("pvp_ratings", "pvp_rating_events", "pvp_rating_config"):
            try:
                data = anon.table(table).select("*").limit(1).execute().data
                check(data == [], f"anon key reads nothing from {table}")
            except Exception:
                check(True, f"anon key is denied {table}")
    else:
        print("  (SUPABASE_ANON_KEY not set; skipped)")

    print("\n2. Phase 4A rows are never rated (before the cutoff)")
    old = supabase.table("pvp_matches").select("match_id").or_(f"player1_id.in.({A},{B}),player2_id.in.({A},{B})").lt("finished_at", rated_from.isoformat()).execute().data
    for row in old:
        outcome = apply(row["match_id"])
        check(outcome == {"status": "unrated", "match_id": row["match_id"], "reason": "before_cutoff"} and not events(row["match_id"]),
              f"{row['match_id'][:8]} -> unrated/before_cutoff, no events")
    check({r["match_id"][:8] for r in old} >= set(PHASE_4A_ROWS), "all three Phase 4A E2E rows checked")

    print("\n3. Equal / unequal ratings, pre-match values, zero-sum")
    start_a, start_b = points(A), points(B)
    m1 = store(A, clock.next())
    out = apply(m1)
    exp_a, exp_b = reference_apply(start_a, start_b, 1)
    check(out["status"] == "applied", f"m1 applied ({out['status']})")
    check((mine(out, A)["points_before"], mine(out, B)["points_before"]) == (start_a, start_b), "both sides use the pre-match values")
    check((mine(out, A)["points_after"], mine(out, B)["points_after"]) == (exp_a, exp_b), f"SQL matches reference: {start_a}/{start_b} -> {exp_a}/{exp_b}")
    if start_a == start_b:
        check(mine(out, A)["points_delta"] == 16 and mine(out, B)["points_delta"] == -16, "equal ratings move exactly +16/-16")
    if min(exp_a, exp_b) > 0:
        check(mine(out, A)["points_delta"] + mine(out, B)["points_delta"] == 0, "zero-sum away from the floor")
    a1, b1 = points(A), points(B)
    m2 = store(A, clock.next())
    out = apply(m2)
    check(a1 != b1, f"unequal ratings now ({a1} vs {b1})")
    check((mine(out, A)["points_after"], mine(out, B)["points_after"]) == reference_apply(a1, b1, 1), "unequal favourite win matches reference")
    a2, b2 = points(A), points(B)
    m3 = store(B, clock.next(), reason="forfeit_disconnect")
    out = apply(m3)
    check((mine(out, B)["points_after"], mine(out, A)["points_after"]) == reference_apply(b2, a2, 1), "underdog win (disconnect forfeit) matches reference")
    a3, b3 = points(A), points(B)
    m4 = store(A, clock.next(), reason="forfeit_leave", p1=B, p2=A)
    out = apply(m4)
    check((mine(out, B)["points_after"], mine(out, A)["points_after"]) == reference_apply(b3, a3, 0), "leave forfeit rated, player order respected")

    print("\n4. Idempotency")
    snapshot = (rating_row(A), rating_row(B))
    for attempt in range(3):
        check(apply(m4)["status"] == "already_applied", f"duplicate #{attempt + 1} -> already_applied")
    check((rating_row(A), rating_row(B)) == snapshot, "duplicates changed nothing")
    m5 = store(B, clock.next())
    with ThreadPoolExecutor(max_workers=20) as pool:
        statuses = list(pool.map(lambda _i: create_client(settings.supabase_url, settings.supabase_service_key).rpc("levelblue_apply_pvp_rating", {"p_match_id": m5}).execute().data["status"], range(20)))
    check(statuses.count("applied") == 1 and statuses.count("already_applied") == 19, f"20 concurrent duplicates -> applied once ({statuses.count('applied')} applied)")
    check(rating_row(A)["rated_matches"] == snapshot[0]["rated_matches"] + 1, "concurrent duplicates counted once")

    print("\n5. Chronological order (match 1 must apply before match 2)")
    first = store(A, clock.next())
    second = store(B, clock.next())
    out = apply(second)
    check(out["status"] == "waiting_for_prior_match" and out.get("prior_match_id") == first and not events(second), "match 2 first -> waiting_for_prior_match, nothing written")
    recovered = [r["match_id"] for r in pvp_rating.list_unrated(None, None, 1000) if r["match_id"] in (first, second)]
    check(recovered == [first, second], "recovery lists them oldest-first")
    out1 = apply(first)
    out2 = apply(second)
    check(out1["status"] == "applied" and out2["status"] == "applied", "match 1 then match 2 applied")
    check(mine(out2, A)["points_before"] == mine(out1, A)["points_after"] and mine(out2, B)["points_before"] == mine(out1, B)["points_after"],
          "match 2 used match 1's resulting points")

    print("\n6. Two different matches applied concurrently")
    c1, c2 = store(A, clock.next()), store(A, clock.next())

    def drive(match_id: str) -> str:
        client = create_client(settings.supabase_url, settings.supabase_service_key)
        for _ in range(30):
            status = client.rpc("levelblue_apply_pvp_rating", {"p_match_id": match_id}).execute().data["status"]
            if status != "waiting_for_prior_match":
                return status
            time.sleep(0.2)
        return "timeout"

    with ThreadPoolExecutor(max_workers=2) as pool:
        done = list(pool.map(drive, (c2, c1)))
    e1, e2 = events(c1), events(c2)
    check(set(done) <= {"applied", "already_applied"} and len(e1) == 2 and len(e2) == 2, f"both applied ({done})")
    by = {e["student_id"]: e for e in e2}
    check(all(by[e["student_id"]]["points_before"] == e["points_after"] for e in e1), "the later match chained from the earlier one")

    print("\n7. Ineligible matches stay unrated")
    private = store(A, clock.next(), origin="private")
    abandoned = store(None, clock.next(), reason="abandoned_before_start")
    for name, mid in (("private KO", private), ("abandoned before start", abandoned)):
        out = apply(mid)
        check(out.get("status") == "unrated" and out.get("reason") == "not_ranked" and not events(mid), f"{name} -> unrated/not_ranked")
    check(apply(str(uuid.uuid4()))["status"] == "not_recorded", "unknown match -> not_recorded")

    print("\n8. Audit-log protections (not weakened)")
    try:
        supabase.table("pvp_rating_events").insert({"match_id": private, "student_id": A, "opponent_id": B, "result": "win", "points_before": 1000,
                                                    "points_after": 1000, "points_delta": 0, "opponent_points_before": 1000, "k_factor": 32}).execute()
        check(False, "a lone ledger row was accepted")
    except Exception:
        check(True, "a lone ledger row is rejected at commit")
    check(events(private) == [], "no partial ledger left behind")
    try:
        supabase.table("pvp_rating_events").update({"points_delta": 999}).eq("match_id", m1).execute()
        check(False, "UPDATE on the ledger was accepted")
    except Exception:
        check(True, "UPDATE on the ledger is rejected")
    try:
        supabase.table("pvp_rating_events").delete().eq("match_id", m1).execute()
        check(False, "DELETE on the ledger was accepted")
    except Exception:
        check(True, "DELETE on the ledger is rejected")
    check(len(events(m1)) == 2, "ledger rows intact after the attempts")

    print("\n9. Real matchmaking match through the running backend")
    env = dict(os.environ, PVP_E2E_HOST_ID=A, PVP_E2E_GUEST_ID=B)
    run = subprocess.run([sys.executable, "tests/live_pvp_e2e.py", "mm_full"], cwd=BACKEND, env=env, capture_output=True, text=True, timeout=600)
    check(run.returncode == 0, f"Godot mm_full E2E passed (exit {run.returncode})")
    latest = supabase.table("pvp_matches").select("*").eq("origin", "matchmaking").or_(f"player1_id.eq.{A},player1_id.eq.{B}").order("finished_at", desc=True).limit(1).execute().data
    real = latest[0] if latest else {}
    real_events = events(real.get("match_id", str(uuid.uuid4())))
    check(bool(real) and real["match_id"] not in matches_made and len(real_events) == 2, "backend rated the real match automatically (two events)")
    if len(real_events) == 2:
        win = next(e for e in real_events if e["student_id"] == real["winner_id"])
        lose = next(e for e in real_events if e["student_id"] != real["winner_id"])
        check((win["points_after"], lose["points_after"]) == reference_apply(win["points_before"], lose["points_before"], 1), "real match points match reference")

    print("\n10. Ledger and /api/pvp/me/rank")
    for mid in [m for m in matches_made if m not in (private, abandoned)]:
        check(len(events(mid)) == 2, f"{mid[:8]} has exactly two ledger rows")
    app = FastAPI()
    app.include_router(router)
    client = TestClient(app)
    for who, sid in (("A", A), ("B", B)):
        body = client.get("/api/pvp/me/rank", headers={"Authorization": f"Bearer {_create_token(sid)}"}).json()
        row = rating_row(sid)
        check(body == pvp_rating.standing(row), f"{who}: /me/rank = {body['points']} {body['rank']} ({body['rated_matches']} rated, {body['wins']}W/{body['losses']}L)")
        ledger = supabase.table("pvp_rating_events").select("points_delta,result").eq("student_id", sid).execute().data
        check(1000 + sum(e["points_delta"] for e in ledger) == row["points"] and len(ledger) == row["rated_matches"], f"{who}: ledger reconciles with points and tally")

    print("\n11. BKT / saves / students untouched")
    after = protected_snapshot()
    for key in before:
        check(before[key] == after[key], f"{key} unchanged")

    failed = [m for ok, m in results if not ok]
    print(f"\nLIVE_RATING checks={len(results)} failures={len(failed)}")
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
