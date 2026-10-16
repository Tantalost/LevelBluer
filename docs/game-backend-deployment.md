# Shared game backend deployment

The root `render.yaml` provisions a separate Python/FastAPI service from `backend/`.
It does not replace the existing Node web backend or the Vercel frontend.
The Blueprint defaults to Free; review the plan before creating the service.
No paid service, deployment, commit, or push is performed by adding this file.

## Render setup

1. Push the current game code and `render.yaml` to the intended GitHub branch.
2. In Render, choose **New > Blueprint**, connect `Tantalost/LevelBluer`, and select
   that branch. Use the root `render.yaml`. Check that `levelblue-game-api` is a
   new service name, not an existing unrelated service.
3. Enter `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, and `JWT_SECRET` privately in Render.
   Use the existing database/project and the **same JWT_SECRET as the web backend**
   so mobile authentication and web feedback remain compatible. The service key
   must be server-side only; never paste secrets into chat or the Godot client.
4. Deploy. The Blueprint selects Python 3.12.14 (the local test runtime), installs
   `requirements.txt`, and starts:

   ```sh
   python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 1
   ```

5. Open the assigned HTTPS URL with `/health`. Expect
   `{"status":"ok","service":"levelblue-mobile-backend"}`.
   This confirms startup, not database permissions or a working PvP match.
6. Confirm `backend/migrations/pvp_match_history.sql` has been applied to the
   existing Supabase project before testing saved match history. Do not recreate
   the database or reset students. Existing game tables/migrations must also be
   present, as for local play.

Keep **one instance, one worker, no reload, no autoscaling**. Automatic deploys
are disabled in the Blueprint; use a manual deploy outside demo/match sessions.
Rooms, reconnect state, matchmaking queues, and not-yet-saved history retries
are memory-only. Restarts, deploys, or instance replacement discard that state;
even overlapping deploy instances cannot share a room. Start a fresh room after
the deployment finishes.

## Connect both game clients

After verifying the assigned URL, change only `levelblue/api_base_url` in
`frontend/project.godot` to that HTTPS origin (no `/api` suffix). Re-export or
restart both clients from the updated project. PvP derives its secure WebSocket
URL from this same setting automatically. This URL also serves login, BKT,
pretests, content and save sync, so test those before accepting the deployment.

Leave these on the existing Node web backend:

- `feedback_api_base_url=https://web-llevelblue.onrender.com`
- `recovery_api_base_url=https://web-llevelblue.onrender.com`

`STUDENT_RECOVERY_URL` and Brevo credentials stay on the Node backend. They are
not needed by this Python service. Sign out and back in on both test clients
after changing servers; use two different student accounts.

## Two-laptop acceptance

1. Log in on each laptop and confirm the correct student/profile is loaded.
2. Host chooses Create Room and remains in the lobby.
3. Guest chooses Join Room and enters the host's exact room code.
4. Confirm both names are present; both select Ready.
5. Confirm synchronized countdown/questions, answers, HP and final result.
6. Verify match history after completion and check normal lesson/progress access.
7. Test mobile feedback separately to catch a mismatched JWT secret.

Do not claim live acceptance based only on local automated tests or `/health`.
Godot native clients are the supported rehearsal path, not a browser export.

## PvP presentation and Overclock update

Deploy the updated Python backend before rebuilding both Godot clients. This
update uses the existing PvP rating ledger; no new database migration is needed
if the current rating migrations are already installed.

- Three consecutive round wins charge Overclock. The next winning hit deals
  25 damage instead of 20 and consumes the charge. Losing or tying a round
  resets an incomplete streak; a fully charged buff remains until used.
- Online damage and charge are server-authoritative. Bot practice follows the
  same rules locally. Reconnect snapshots include charge and final statistics.
- Ranked results read `GET /api/pvp/me/matches/{match_id}/rating`, authenticated
  and scoped to the current student. Only an applied ledger entry animates the
  before/after rating. Pending or unavailable rewards are retried up to five
  times, then display a check-later message; the client never grants points.
- Private rooms and bot practice remain unrated. PvP rating is not the Threat
  store wallet. Reduced-motion mode skips the reward count-up and screen fade.

Rehearse a ranked result, private-room result, charged hit, reconnect, and
leaving during reward sync on two updated clients. Local regression tests do
not replace this hosted acceptance check.

## Defense fallback

Free Render services can spin down after inactivity. Before rehearsal/demo,
open `/health` and wait for a successful response before signing in. The client
request timeout can expire during cold startup; retry after health is ready.
Free service hours/availability are not guaranteed. A paid plan is an optional
owner decision, not part of this configuration.

For LAN fallback, run the same backend on one laptop using the start command
above with `--port 8000` instead of `$PORT`. Use the host's private Wi-Fi IPv4
address from `ipconfig` as `http://<host-ip>:8000` on BOTH game clients. Allow only
the necessary Python/port inbound traffic on the trusted private network; do
not disable the firewall or expose the port through the router. Guest Wi-Fi
client isolation can prevent LAN access. HTTP LAN testing is for trusted test
accounts only; use HTTPS hosting for normal use. Authentication and Supabase
operations still require internet: this is not a fully offline mode.

## References

- https://render.com/docs/deploy-fastapi
- https://render.com/docs/blueprint-spec
- https://render.com/docs/python-version
- https://render.com/docs/websocket
- https://render.com/docs/free
