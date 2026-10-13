# Mobile student feedback

Settings → Send Feedback and stage results → Give feedback share one modal (`student_feedback.gd`). Results support both clears and failures; tutorial and non-persistent gameplay previews do not offer the shortcut. The form does not grade answers, award currency, or write learning records.

## Contract and setup

The game posts directly to the existing **web** API, not the Python mobile API:

- Project setting: `levelblue/feedback_api_base_url` in `frontend/project.godot`.
- Configured web server: `https://web-llevelblue.onrender.com` (provided by the project owner).
- For local development only, override with `http://127.0.0.1:5000`. On a phone, loopback refers to that phone, not the developer's PC. Insecure HTTP is accepted only for explicit loopback development URLs; redirects are disabled to protect bearer tokens.
- Route: `POST /api/usability-feedback`, with the current student's bearer token. The web and Python servers must share the JWT signing configuration and student database. Never embed signing keys or database credentials in Godot.
- The existing web feedback migration and required section migrations must be applied by the deployment owner. No hosted schema or records were changed by this implementation.

The five questions and required integer ratings (1–5) match the web contract exactly. Nothing is preselected. `feedbackType` is `comment` or `bug`; bugs require the student's own message. Student comments are limited to 4,500 characters, leaving space under the server's 5,000-character maximum for context. Module IDs map to the web's Phishing/Smishing/Vishing/Pretexting/Baiting names. General feedback omits `module`.

The existing API has no separate stage field. A visible `[Mobile / <module> / Stage <number> / <outcome>]` prefix goes into `comments`; general submissions say `General app experience`. All attached context is shown before Send. The server—not the client—derives student identity, section and composite rating. The form explicitly explains that staff can read the response and it is not anonymous.

## Lifecycle and failure behavior

- A single modal owns its HTTPRequest; it does not share/cancel AuthService's login or save requests.
- Success requires HTTP 201 and the server-returned record `_id`. Only then is the draft removed and a confirmation shown.
- Requests time out after 25 seconds. Send/Back/Close are locked in flight. Duplicate taps cannot create parallel submissions.
- No background queue or automatic retry. An uncertain response warns that a manual retry could duplicate a response already received by the server. The web endpoint currently has no idempotency-key support.
- Account-scoped drafts survive modal close/reopen in this running app, including failed sends. They are memory-only: app termination loses them. No comments are written into save sync, telemetry, or log files. An account change while the form is open cancels the request and clears drafts.
- Scene teardown cancels its request; tree-owned signal connections clean up automatically. Cancellation cannot recall a request the server has already accepted.
- The modal captures Back and keyboard Tab focus, retains scrollable content and a fixed footer in landscape, and adjusts for the mobile virtual keyboard. Real-device keyboard behavior still needs device QA.

## Verification

`verify_student_feedback.gd` uses a loopback fake HTTP server and in-memory test credentials. It never posts to the real dashboard or changes account saves. Coverage includes required ratings, comment limits, bug validation, payload/identity boundaries, duplicate-send protection, 400/401/403/429/500/503 responses, malformed success, timeout, draft restoration, account switching, both result outcomes, Settings entry, and 1280×720 / 844×390 layouts. Add `-- --render` for ignored `.godot/feedback_*.png` previews.

On 2026-10-12 the project owner confirmed a successful mobile submission and supplied a screenshot of the received response in the teacher web dashboard, including student identity, section, general-app context, comment and a 3.6 average matching the submitted ratings. This confirms that live submission path for the tested account; real-device keyboard behavior and other roles still require device/access QA.
