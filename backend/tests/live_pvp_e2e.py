"""Live private-room PvP check: one uvicorn worker (no reload) + two headless Godot clients.

Development only; not part of unittest discovery. Run from backend/:
    .venv\\Scripts\\python.exe tests\\live_pvp_e2e.py [scenario ...]
Set GODOT to the Godot 4 binary if it is not at the default path.
Use --isolated for synthetic students, a disposable signing key and no database access.
Tokens are minted with the server's own signer for two distinct student ids and are only
written to the per-run temp directory; they are never printed.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
from pathlib import Path
from typing import Any
from contextlib import asynccontextmanager
from unittest.mock import patch

BACKEND = Path(__file__).resolve().parents[1]
FRONTEND = BACKEND.parent / "frontend"
PORT = 8765
API = f"http://127.0.0.1:{PORT}"
DEAD_API = "http://127.0.0.1:9"
GODOT = os.environ.get("GODOT", r"C:\Users\beron\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe")
SCENARIOS = ["full", "reconnect", "forfeit", "lobby_leave", "match_leave", "replace", "restart", "offline"]
MM_SCENARIOS = ["mm_full", "mm_cancel", "mm_simultaneous", "mm_cancel_race", "mm_abrupt", "mm_expiry", "mm_noshow", "mm_conflict"]
HOST_ONLY = {"offline", "mm_expiry", "mm_noshow", "mm_conflict"}
RACE_OFFSETS_MS = [-600, -520, -500, -490, -480, -460, -300, 0]
QUEUE_TTL_S = 90
MATCH_GRACE_S = 60
CLIENT_TIMEOUT_S = 300

sys.path.insert(0, str(BACKEND))
os.chdir(BACKEND)
ISOLATED = "--isolated" in sys.argv or "--serve-isolated" in sys.argv
if "--isolated" in sys.argv:
    # Child processes inherit these test-only settings; never edit .env or the
    # production app's authentication, and never use real account ids here.
    os.environ["SUPABASE_URL"] = "http://127.0.0.1:9"
    os.environ["SUPABASE_SERVICE_KEY"] = "isolated-pvp-no-database"
    os.environ["JWT_SECRET"] = uuid.uuid4().hex + uuid.uuid4().hex
    os.environ.pop("PVP_E2E_HOST_ID", None)
    os.environ.pop("PVP_E2E_GUEST_ID", None)
from app.services.auth_service import _create_token  # noqa: E402


def serve_isolated() -> None:
    """Real transports and server rules; only student storage is substituted."""
    import uvicorn
    from fastapi import FastAPI, HTTPException
    from app.routes.pvp import router
    from app.services.pvp_hub import PvpHub
    from app.services.pvp_service import PvpService

    def student_lookup(student_id: str) -> dict[str, Any]:
        if not student_id.startswith(("e2e-a-", "e2e-b-")):
            raise HTTPException(status_code=404, detail="Synthetic student not found")
        return {"id": student_id, "session_version": 0}

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        hub = PvpHub(PvpService()) # No recorder: persistence is tested with FakeDb separately.
        app.state.pvp_hub = hub
        with patch("app.services.auth_service.fetch_student_by_id", side_effect=student_lookup):
            async with hub.running():
                yield

    app = FastAPI(lifespan=lifespan)
    app.include_router(router)
    uvicorn.run(app, host="127.0.0.1", port=PORT, workers=1)


class Run:
    def __init__(self) -> None:
        self.checks: list[tuple[str, bool, str]] = []
        self.outcomes: list[str] = []

    def check(self, scenario: str, ok: bool, message: str) -> None:
        self.checks.append((scenario, bool(ok), message))
        print(f"  [{'PASS' if ok else 'FAIL'}] {message}")


def start_server(log_path: Path) -> subprocess.Popen[bytes]:
    log = open(log_path, "ab")
    command = [sys.executable, str(Path(__file__).resolve()), "--serve-isolated"] if ISOLATED else [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(PORT), "--workers", "1"]
    proc = subprocess.Popen(
        command,
        cwd=BACKEND, stdout=log, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )
    deadline = time.time() + 40
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"{API}/openapi.json", timeout=1) as response:
                if response.status == 200:
                    return proc
        except Exception:
            time.sleep(0.3)
    proc.kill()
    raise RuntimeError("backend did not start")


def client(work: Path, role: str, scenario: str, api: str) -> subprocess.Popen[bytes]:
    out = open(work / f"{role}.out", "wb")
    return subprocess.Popen(
        [GODOT, "--headless", "--path", str(FRONTEND), "--script", "res://src/tools/live_pvp_client.gd", "--",
         f"role={role}", f"scenario={scenario}", f"dir={work.as_posix()}", f"api={api}"],
        stdout=out, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )


def api(method: str, path: str, token: str) -> tuple[int, dict[str, Any]]:
    data = b"" if method == "POST" else None
    request = urllib.request.Request(API + path, data=data, method=method, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read() or b"{}")


def now_ms() -> int:
    return int(time.time() * 1000)


def save(work: Path, name: str, payload: dict[str, Any]) -> None:
    (work / f"{name}.json").write_text(json.dumps(payload), encoding="utf-8")


def load(work: Path, name: str) -> dict[str, Any]:
    path = work / f"{name}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def events(work: Path, role: str) -> list[dict[str, Any]]:
    path = work / f"{role}.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def first(items: list[dict[str, Any]], event: str, **match: Any) -> dict[str, Any] | None:
    for item in items:
        if item["event"] == event and all(item.get(key) == value for key, value in match.items()):
            return item
    return None


def every(items: list[dict[str, Any]], event: str) -> list[dict[str, Any]]:
    return [item for item in items if item["event"] == event]


def run_scenario(scenario: str, server: list[subprocess.Popen[bytes]], server_log: Path, run: Run, race_offset_ms: int = 0) -> Path:
    work = Path(tempfile.mkdtemp(prefix=f"pvp_{scenario}_"))
    suffix = uuid.uuid4().hex[:6]
    # PVP_E2E_HOST_ID / PVP_E2E_GUEST_ID: real student UUIDs, so match history is written for real accounts.
    host_id = os.environ.get("PVP_E2E_HOST_ID") or f"e2e-a-{suffix}"
    guest_id = os.environ.get("PVP_E2E_GUEST_ID") or f"e2e-b-{suffix}"
    host_token, guest_token = _create_token(host_id), _create_token(guest_id)
    (work / "host.token").write_text(host_token, encoding="utf-8")
    (work / "guest.token").write_text(guest_token, encoding="utf-8")
    print(f"\n=== {scenario}{f' offset={race_offset_ms}ms' if scenario == 'mm_cancel_race' else ''}  ({work})")
    if scenario == "offline":
        host = client(work, "host", scenario, DEAD_API)
        host.wait(timeout=CLIENT_TIMEOUT_S)
        return work
    if scenario == "mm_conflict":
        status, view = api("POST", "/api/pvp/rooms", host_token)
        save(work, "driver", {"private_status": status, "private_code": view.get("code", "")})
    host = client(work, "host", scenario, API)
    guest = client(work, "guest", scenario, API) if scenario not in HOST_ONLY else None
    if scenario == "mm_simultaneous":
        moment = now_ms() + 12_000
        (work / "go_at").write_text(f"{moment},{moment}")
    started = time.time()
    killed_guest = killed_server = killed_host = went = False
    while time.time() - started < CLIENT_TIMEOUT_S:
        if not went and (work / "host_queued").exists():
            went = True
            if scenario == "mm_cancel_race":
                moment = now_ms() + 1500
                (work / "go_at").write_text(f"{moment},{moment + race_offset_ms}")
            elif scenario == "mm_noshow":
                status, ticket = api("POST", "/api/pvp/matchmaking/join", guest_token)
                save(work, "driver", {"join_status": status, "ticket": ticket, "matched_at": now_ms()})
        if not killed_host and (work / "kill_host").exists():
            killed_host = True
            host.kill()
            host.wait()
            killed_at = now_ms()
            (work / "host_killed").write_text(str(killed_at))
            if scenario == "mm_expiry":
                _probe_expiry(work, host_token, guest_token, killed_at)
        if guest is None and host.poll() is not None:
            break
        if not killed_guest and (work / "kill_guest").exists():
            killed_guest = True
            guest.kill()
            (work / "guest_killed_at").write_text(str(int(time.time() * 1000)))
        if not killed_server and (work / "kill_server").exists():
            killed_server = True
            server[0].kill()
            server[0].wait()
            time.sleep(3)
            server[0] = start_server(server_log)
        if guest is not None and host.poll() is not None and guest.poll() is not None:
            break
        time.sleep(0.1)
    for proc in (host, guest):
        if proc is not None and proc.poll() is None:
            proc.kill()
    if scenario == "mm_noshow":
        info = load(work, "driver")
        info["guest_status_after"] = api("GET", "/api/pvp/matchmaking/status", guest_token)[1]
        save(work, "driver", info)
    return work


def _probe_expiry(work: Path, host_token: str, guest_token: str, killed_at: int) -> None:
    """Just past the TTL, the dead client's entry must be gone: a new player waits instead of matching a ghost."""
    time.sleep(max(0.0, (killed_at + (QUEUE_TTL_S + 2) * 1000 - now_ms()) / 1000))
    status, ticket = api("POST", "/api/pvp/matchmaking/join", guest_token)
    guest_status = api("GET", "/api/pvp/matchmaking/status", guest_token)[1]
    cancel = api("POST", "/api/pvp/matchmaking/cancel", guest_token)[1]
    dead_status = api("GET", "/api/pvp/matchmaking/status", host_token)[1]
    save(work, "driver", {"killed_at": killed_at, "probe_at": now_ms(), "join_status": status, "ticket": ticket, "guest_status": guest_status, "cancel": cancel, "dead_status": dead_status})


# ---- verdicts ----------------------------------------------------------------------------

def judge_full(work: Path, run: Run) -> None:
    s = "full"
    host, guest = events(work, "host"), events(work, "guest")
    run.check(s, first(host, "room_code") is not None, "host created a room over real HTTP")
    run.check(s, first(guest, "room_state", state="waiting") is not None, "guest joined the same room over real HTTP and the JWT WebSocket")
    judge_match(s, host, guest, run)


def judge_match(s: str, host: list[dict[str, Any]], guest: list[dict[str, Any]], run: Run) -> None:
    host_id = (first(host, "result") or {}).get("me", "")
    guest_id = (first(guest, "result") or {}).get("me", "")
    h_rounds = {e["round"]: e for e in reversed(every(host, "round"))}
    g_rounds = {e["round"]: e for e in reversed(every(guest, "round"))}
    run.check(s, h_rounds.keys() == g_rounds.keys() and len(h_rounds) >= 1, f"both clients saw the same rounds {sorted(h_rounds)}")
    same = all(h_rounds[n]["question_id"] == g_rounds[n]["question_id"] and h_rounds[n]["options"] == g_rounds[n]["options"] for n in h_rounds if n in g_rounds)
    run.check(s, same, "every round had the same question and option order on both clients")
    arrivals = [abs(h_rounds[n]["wall"] - g_rounds[n]["wall"]) for n in h_rounds if n in g_rounds]
    run.check(s, arrivals and max(arrivals) < 250, f"round_started reached both clients within {max(arrivals) if arrivals else '?'}ms")
    zeros = []
    for n in h_rounds:
        hz, gz = first(host, "countdown_zero", round=n), first(guest, "countdown_zero", round=n)
        if hz and gz:
            zeros.append(abs(hz["wall"] - gz["wall"]))
    run.check(s, not zeros or max(zeros) < 250, f"countdowns hit zero within {max(zeros) if zeros else 'n/a'}ms (server deadlines)")
    h_results = {e["round"]: e for e in every(host, "result")}
    g_results = {e["round"]: e for e in every(guest, "result")}
    expected = {1: host_id, 2: host_id, 3: "", 4: "", 5: guest_id, 6: guest_id, 7: host_id, 8: guest_id, 9: host_id, 10: host_id}
    for number, winner in expected.items():
        hr, gr = h_results.get(number), g_results.get(number)
        ok = hr is not None and gr is not None and hr["winner"] == gr["winner"] == winner and hr["hp"] == gr["hp"]
        run.check(s, ok, f"round {number}: winner={'host' if winner == host_id else 'guest' if winner == guest_id else 'none'} reason={hr and hr['reason']} hp={hr and hr['hp']} identical on both")
    run.check(s, h_results.get(3, {}).get("reason") == "timeout" and h_results.get(4, {}).get("reason") == "both_wrong", "timeout and both-wrong rounds dealt no damage")
    run.check(s, h_results.get(5, {}).get("winner") == guest_id, "round 5 race: the faster correct player (guest) won although both were correct")
    wrong = first(guest, "locked", round=2)
    host_answer = first(host, "answered", round=2)
    run.check(s, wrong is not None and wrong["correct"] is False and wrong["state"] == "ACTIVE", "a wrong answer locked only the guest; the round stayed open")
    run.check(s, wrong is not None and host_answer is not None and host_answer["wall"] > wrong["wall"] and h_results.get(2, {}).get("winner") == host_id, "the host could still answer after the guest's wrong answer and won")
    hp6 = h_results.get(6, {}).get("hp", {}).get(guest_id)
    hp7 = h_results.get(7, {}).get("hp", {}).get(guest_id)
    run.check(s, first(host, "raw_duplicate_sent", round=7) is not None and hp6 is not None and hp7 is not None and hp6 - hp7 == 20, f"a raw duplicate answer dealt one hit only ({hp6} -> {hp7})")
    dup_errors = [e for e in host if e["event"] == "error" and e["code"] in ("already_answered", "round_resolved")]
    run.check(s, len(dup_errors) == 1, f"the server rejected exactly one duplicate answer ({[e['code'] for e in dup_errors]})")
    ui_dups = [e for e in host + guest if e["event"] == "error" and e["code"] in ("already_answered", "round_resolved") and e is not (dup_errors[0] if dup_errors else None)]
    run.check(s, not ui_dups, "UI double clicks never reached the server")
    losers_locked = all(e["locked_after_result"] for e in every(host, "result") + every(guest, "result") if e["winner"] and e["winner"] != e["me"])
    run.check(s, losers_locked, "the losing client's answers were locked as soon as the server result arrived")
    run.check(s, max(h_results or {0: 0}) >= 8, f"the match continued past round 7 ({max(h_results or {0: 0})} rounds)")
    hf, gf = first(host, "final"), first(guest, "final")
    run.check(s, hf is not None and gf is not None and hf["reason"] == gf["reason"] == "ko", "the match ended only by KO")
    run.check(s, hf is not None and gf is not None and hf["winner"] == gf["winner"] == host_id and hf["hp"] == gf["hp"], f"both clients agree on the winner and final HP {hf and hf['hp']}")
    run.check(s, hf is not None and gf is not None and hf["title"] == "VICTORY" and gf["title"] == "DEFEAT", "host shows VICTORY and guest shows DEFEAT")
    for name, items in (("host", host), ("guest", guest)):
        cleanup = first(items, "cleanup") or {}
        run.check(s, cleanup.get("sessions_created") == 1 and cleanup.get("sessions_freed") == 1, f"{name} used one session for the whole match and freed it once")


def judge_reconnect(work: Path, run: Run) -> None:
    s = "reconnect"
    host, guest = events(work, "host"), events(work, "guest")
    drop = first(guest, "network_drop")
    restore = first(guest, "network_restore")
    run.check(s, drop is not None and restore is not None, "guest dropped its socket during round 1 and its network came back ~3.5s later")
    seen = first(host, "opponent_disconnected")
    run.check(s, seen is not None and seen["banner"].startswith("RIVAL DISCONNECTED"), f"host showed the grace banner: {seen and seen['banner']!r}")
    run.check(s, seen is not None and 14000 <= seen["grace_ends_at"] - seen.get("server", 0) <= 15500, "the grace deadline came from the server (~15s)")
    run.check(s, first(guest, "state", state="RECONNECTING") is not None, "guest entered RECONNECTING")
    round1 = first(guest, "round", round=1)
    restored = [e for e in guest if e["event"] == "room_state" and restore and e["wall"] > restore["wall"]]
    back = restored[0] if restored else None
    run.check(s, back is not None and round1 is not None and back["round"] == 1 and back["question_id"] == round1["question_id"], f"guest restored the same round 1 question from the server ({back and back['state']})")
    hp_host_view = [e for e in host if e["event"] in ("room_state", "result") and back and e["wall"] <= back["wall"]]
    run.check(s, back is not None and bool(hp_host_view) and back["hp"] == hp_host_view[-1]["hp"], f"restored HP {back and back['hp']} matches the host's HP at that moment")
    back_conn = first(host, "opponent_connected")
    run.check(s, back_conn is not None and back_conn["banner"] == "", "host cleared the warning when the guest returned")
    hf, gf = first(host, "final"), first(guest, "final")
    run.check(s, hf is not None and gf is not None and hf["reason"] == gf["reason"] == "ko" and hf["winner"] == gf["winner"], "the resumed match finished by KO with the same result on both clients")


def judge_forfeit(work: Path, run: Run) -> None:
    s = "forfeit"
    host = events(work, "host")
    killed_at = int((work / "guest_killed_at").read_text()) if (work / "guest_killed_at").exists() else 0
    run.check(s, killed_at > 0, "guest process was killed mid-round (no leave message)")
    seen = first(host, "opponent_disconnected")
    run.check(s, seen is not None and seen["banner"].startswith("RIVAL DISCONNECTED"), f"host showed the grace banner: {seen and seen['banner']!r}")
    final = first(host, "final")
    run.check(s, final is not None and final["reason"] == "forfeit" and final["winner"] == final["me"], "host received an authoritative forfeit victory")
    run.check(s, final is not None and final["title"] == "VICTORY" and final["line"] == "RIVAL FORFEITED — CONNECTION LOST", f"host UI: {final and (final['title'], final['line'])}")
    if final and killed_at:
        waited = final["wall"] - killed_at
        run.check(s, 14000 <= waited <= 18000, f"forfeit landed after the grace window ({waited}ms after the kill)")


def judge_lobby_leave(work: Path, run: Run) -> None:
    s = "lobby_leave"
    host, guest = events(work, "host"), events(work, "guest")
    left = first(guest, "cleanup")
    run.check(s, left is not None and left["left"] and left["sessions_freed"] == 1, "guest left the lobby and freed its session once")
    final = first(host, "final")
    run.check(s, final is not None and final["reason"] == "retired" and final["title"] == "ROOM CLOSED", f"host was told the room closed: {final and (final['reason'], final['title'])}")


def judge_match_leave(work: Path, run: Run) -> None:
    s = "match_leave"
    host, guest = events(work, "host"), events(work, "guest")
    back = first(guest, "back_pressed")
    run.check(s, back is not None and back["confirm_shown"], "back during a match asked for confirmation")
    left = first(guest, "cleanup")
    run.check(s, left is not None and left["left"] and left["sessions_freed"] == 1, "guest left mid-match and freed its session once")
    final = first(host, "final")
    run.check(s, final is not None and final["reason"] == "retired" and final["winner"] == final["me"] and final["line"] == "RIVAL LEFT THE MATCH", f"host won by the rival leaving: {final and (final['title'], final['line'])}")


def judge_replace(work: Path, run: Run) -> None:
    s = "replace"
    host, guest = events(work, "host"), events(work, "guest")
    replaced = first(host, "first_replaced")
    run.check(s, replaced is not None and replaced["error"] == "replaced" and replaced["title"] == "DISCONNECTED", f"the first socket was replaced (4409): {replaced and (replaced['error'], replaced['line'])}")
    second = first(host, "second_state_before_leave")
    run.check(s, second is not None and second["state"] in ("ACTIVE", "ROUND_RESULT", "COUNTDOWN"), f"the second socket took over the live match ({second and second['state']})")
    reconnects = [e for e in host if e["event"] == "state" and e["state"] == "RECONNECTING" and replaced and e["wall"] > replaced["wall"]]
    run.check(s, not reconnects, "the replaced client did not fight back with reconnect attempts")
    final = first(guest, "final")
    run.check(s, final is not None and final["reason"] == "retired" and final["winner"] == final["me"], "the guest received the authoritative result after the replacement left")


def judge_restart(work: Path, run: Run) -> None:
    s = "restart"
    for role in ("host", "guest"):
        outcome = first(events(work, role), "restart_outcome")
        run.check(s, outcome is not None and outcome["end_visible"] and outcome["error"] in ("room_missing", "room_not_found", "reconnect_failed"), f"{role} ended safely after a server restart: {outcome and (outcome['error'], outcome['line'])}")


def judge_offline(work: Path, run: Run) -> None:
    s = "offline"
    host = events(work, "host")
    create, join = first(host, "offline_create"), first(host, "offline_join")
    run.check(s, create is not None and create["error"] == "Could not reach the LevelBlue server." and create["retry_visible"], f"create with the backend down: {create and create['error']!r}")
    run.check(s, join is not None and join["error"] == "Could not reach the LevelBlue server." and join["entry_visible"], f"join with the backend down: {join and join['error']!r}")


def judge_mm_full(work: Path, run: Run) -> None:
    s = "mm_full"
    host, guest = events(work, "host"), events(work, "guest")
    waiting = first(host, "queued_waiting")
    run.check(s, waiting is not None and waiting["state"] == "SEARCHING" and waiting["room_code"] == "" and waiting["status_requests"] >= 2, f"A queued and kept polling alone ({waiting and waiting['status_requests']} polls, no room)")
    h_match, g_match = first(host, "match_found"), first(guest, "match_found")
    run.check(s, h_match is not None and g_match is not None and h_match["code"] == g_match["code"], f"both clients were matched into the same room {h_match and h_match['code']}")
    run.check(s, g_match is not None and g_match["status_requests"] == 0, "B was matched directly by its join (A was waiting)")
    for name, items, found in (("A", host, h_match), ("B", guest, g_match)):
        lobby = first(items, "lobby")
        run.check(s, lobby is not None and found is not None and lobby["code"] == found["code"] and lobby["title"] == "MATCH FOUND", f"{name} entered the existing lobby for that room")
        run.check(s, first(items, "ready_pressed") is not None, f"{name} pressed READY")
        before = first(items, "pre_leave")
        cleanup = first(items, "cleanup") or {}
        run.check(s, found is not None and before is not None and before["status_requests"] == found["status_requests"], f"{name} sent no status polls after the match ({found and found['status_requests']} -> {before and before['status_requests']})")
        run.check(s, cleanup.get("sessions_created") == 1 and cleanup.get("sessions_freed") == 1, f"{name} used one session from search to KO")
        run.check(s, first(items, "countdown") is not None and first(items, "round") is not None, f"{name} ran the normal Phase 2 WebSocket room flow")
    judge_match(s, host, guest, run)


def judge_mm_cancel(work: Path, run: Run) -> None:
    s = "mm_cancel"
    host, guest = events(work, "host"), events(work, "guest")
    cancelled = first(host, "cancelled")
    run.check(s, cancelled is not None and cancelled["left"] and cancelled["state"] == "FREED", "A cancelled alone, returned to the hub, and freed its session")
    later = first(guest, "guest_after_wait")
    run.check(s, later is not None and later["state"] == "SEARCHING" and later["room_code"] == "", "B queued afterwards and was NOT matched with the cancelled A")
    run.check(s, first(host, "match_found") is None and first(guest, "match_found") is None, "no match was created")
    run.check(s, (first(guest, "cancelled") or {}).get("left") is True, "B also cancelled cleanly")


def judge_mm_simultaneous(work: Path, run: Run) -> None:
    s = "mm_simultaneous"
    host, guest = events(work, "host"), events(work, "guest")
    h_go, g_go = first(host, "go"), first(guest, "go")
    run.check(s, h_go is not None and g_go is not None and abs(h_go["wall"] - g_go["wall"]) < 50, f"both pressed FIND OPPONENT within {h_go and g_go and abs(h_go['wall'] - g_go['wall'])}ms")
    h, g = first(host, "lobby_reached"), first(guest, "lobby_reached")
    run.check(s, h is not None and g is not None and h["room_code"] != "" and h["room_code"] == g["room_code"], f"exactly one shared room {h and h['room_code']} / {g and g['room_code']}")
    run.check(s, h is not None and g is not None and h["state"] == g["state"] == "WAITING", "both landed in the waiting lobby")
    for name, items in (("A", host), ("B", guest)):
        run.check(s, len(every(items, "match_found")) == 1 and (first(items, "cleanup") or {}).get("sessions_created") == 1, f"{name} matched once with one session")


def judge_mm_cancel_race(work: Path, run: Run) -> None:
    s = "mm_cancel_race"
    host, guest = events(work, "host"), events(work, "guest")
    h, g = first(host, "race_outcome"), first(guest, "race_outcome")
    if h is None or g is None:
        run.check(s, False, "both clients reported a race outcome")
        return
    h_room, g_room = h["room_code"], g["room_code"]
    if h_room:
        outcome = "match won: A's cancel returned matched"
        ok = h_room == g_room and not h["left"]
    else:
        outcome = "cancel won: A left, B kept searching"
        ok = h["left"] and g_room == "" and g["state"] in ("SEARCHING", "FREED")
    run.check(s, ok, f"{outcome} (A={h['state']}/{h_room or '-'}, B={g['state']}/{g_room or '-'})")
    run.outcomes.append(outcome.split(":")[0])


def judge_mm_abrupt(work: Path, run: Run) -> None:
    s = "mm_abrupt"
    guest = events(work, "guest")
    killed_at = int((work / "host_killed").read_text()) if (work / "host_killed").exists() else 0
    found = first(guest, "match_found")
    run.check(s, killed_at > 0 and found is not None and found["wall"] - killed_at < 10_000, f"B was matched with A's dead queue entry {found and found['wall'] - killed_at}ms after the kill")
    lobby = first(guest, "lobby")
    run.check(s, lobby is not None and lobby["rival"] == "OFFLINE", f"B's lobby showed the rival as {lobby and lobby['rival']}")
    final = first(guest, "final")
    waited = final["wall"] - found["wall"] if final and found else -1
    run.check(s, final is not None and final["reason"] == "forfeit" and final["winner"] == "" and final["title"] == "ROOM CLOSED", f"the no-show room closed safely: {final and (final['title'], final['line'])}")
    run.check(s, (MATCH_GRACE_S - 1) * 1000 <= waited <= (MATCH_GRACE_S + 3) * 1000, f"it closed after the {MATCH_GRACE_S}s matched-room grace ({waited}ms)")


def judge_mm_expiry(work: Path, run: Run) -> None:
    s = "mm_expiry"
    info = load(work, "driver")
    run.check(s, bool(info), "the driver probed the queue after the TTL")
    if not info:
        return
    after = (info["probe_at"] - info["killed_at"]) / 1000
    run.check(s, info["join_status"] == 200 and info["ticket"].get("status") == "queued", f"{after:.0f}s after an abrupt exit, a new player waits instead of matching the dead entry ({info['ticket']})")
    run.check(s, info["dead_status"] == {"status": "idle"}, f"the dead player's entry expired ({info['dead_status']})")
    run.check(s, info["cancel"] == {"status": "cancelled"}, "the probe dequeued itself")


def judge_mm_noshow(work: Path, run: Run) -> None:
    s = "mm_noshow"
    host = events(work, "host")
    info = load(work, "driver")
    found = first(host, "match_found")
    run.check(s, info.get("join_status") == 200 and info.get("ticket", {}).get("status") == "matched" and found is not None and info["ticket"].get("room_code") == found["code"], "B (HTTP only) matched with A, then never connected")
    lobby = first(host, "lobby")
    run.check(s, lobby is not None and lobby["rival"] == "OFFLINE", f"A's lobby showed the rival as {lobby and lobby['rival']}")
    final = first(host, "final")
    waited = final["wall"] - info.get("matched_at", 0) if final else -1
    run.check(s, final is not None and final["reason"] == "forfeit" and final["winner"] == "" and final["title"] == "ROOM CLOSED", f"A's room closed with no winner: {final and (final['title'], final['line'])}")
    run.check(s, (MATCH_GRACE_S - 1) * 1000 <= waited <= (MATCH_GRACE_S + 3) * 1000, f"after the {MATCH_GRACE_S}s matched-room grace ({waited}ms)")
    run.check(s, info.get("guest_status_after") == {"status": "idle"}, f"the no-show is free to queue again ({info.get('guest_status_after')})")


def judge_mm_conflict(work: Path, run: Run) -> None:
    s = "mm_conflict"
    info = load(work, "driver")
    conflict = first(events(work, "host"), "conflict")
    run.check(s, info.get("private_status") == 201, "A already owns an active private room")
    run.check(s, conflict is not None and conflict["errored"] and conflict["error"] == "You are already in a match. Finish or leave it first.", f"FIND OPPONENT was refused safely: {conflict and conflict['error']!r}")
    run.check(s, conflict is not None and conflict["retry_visible"] and conflict["back_visible"] and conflict["back_text"] == "BACK" and not conflict["searching_visible"], "the screen offers TRY AGAIN and BACK, not a search")


JUDGES = {
    "full": judge_full, "reconnect": judge_reconnect, "forfeit": judge_forfeit, "lobby_leave": judge_lobby_leave,
    "match_leave": judge_match_leave, "replace": judge_replace, "restart": judge_restart, "offline": judge_offline,
    "mm_full": judge_mm_full, "mm_cancel": judge_mm_cancel, "mm_simultaneous": judge_mm_simultaneous,
    "mm_cancel_race": judge_mm_cancel_race, "mm_abrupt": judge_mm_abrupt, "mm_expiry": judge_mm_expiry,
    "mm_noshow": judge_mm_noshow, "mm_conflict": judge_mm_conflict,
}


def main() -> int:
    args = sys.argv[1:]
    chosen = [name for name in args if name in JUDGES]
    if "mm" in args:
        chosen += MM_SCENARIOS
    chosen = chosen or SCENARIOS
    run = Run()
    server_log = Path(tempfile.gettempdir()) / "pvp_e2e_server.log"
    server_log.write_text("")
    server = [start_server(server_log)]
    try:
        for scenario in chosen:
            for offset in RACE_OFFSETS_MS if scenario == "mm_cancel_race" else [0]:
                work = run_scenario(scenario, server, server_log, run, offset)
                if server[0].poll() is not None:
                    server[0] = start_server(server_log)
                JUDGES[scenario](work, run)
    finally:
        # kill() is a hard stop on Windows (no lifespan shutdown); give the 1 s history writer time to land.
        time.sleep(3)
        server[0].kill()
    failed = [c for c in run.checks if not c[1]]
    if run.outcomes:
        print(f"\n[PVP E2E] cancel-race outcomes: {run.outcomes}")
    print(f"\n[PVP E2E] checks={len(run.checks)} failures={len(failed)}  server log: {server_log}")
    return 1 if failed else 0


if __name__ == "__main__":
    if "--serve-isolated" in sys.argv:
        serve_isolated()
    else:
        sys.exit(main())
