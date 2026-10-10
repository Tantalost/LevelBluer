# Geometric gameplay rollout: Module 1 / Stage 1

## Targeted review rollout (2026-10-10)

Approved scope: **all stages in Modules 1 and 2**, implemented and verified one
stage at a time. Current enabled checkpoints: **Module 1 Stages 1 and 2**.
Stages 3–9 need their own authored decision-to-lesson mappings and practice;
both Stage 10 assessments require separate integration preserving graded scores.
Module 2 stages are not yet enabled for this recovery system. Rewards, buffs,
and voiced scenes are not part of this implementation checkpoint.

The existing live controller emits the result; its result overlay emits
`remediation`; Router tears down gameplay and opens the existing lesson player
in targeted-review mode. A shared `StageRemediation` policy owns evidence and
review state; PlayerManager persists it in the normal per-account save.
No extra scene tree or parallel BKT implementation is introduced.

### Stage 1 acceptance contract

- Failure with recorded unsafe-decision/timeout evidence → acknowledge summary
  with **Review Lesson** → matched refresher → 2–3 new practice questions →
  explicit **Review Complete** → restart Stage 1 from its opening with 3 HP.
- Incident 1 (urgent lookalike sign-in) → Lesson 3, Almost the real website.
  Incident 2 (familiar sender asks for a secret) → Lesson 2, The name on the left
  can lie. Incident 3 (independently verified reminder) → Lesson 5, Inbox under
  the clock. Critical errors receive priority over risky responses; equal
  weights prefer the most recently recorded topic.
- Below the existing 0.40 at-risk boundary, provide guided support and three
  questions; otherwise use a focused refresher and two. BKT remains a broad
  **phishing-domain** estimate, not a probability for these individual concepts.
- Only a previously unseen item's first submitted answer is scored. Reopened
  incidents, repeat practice, corrections, and reading never regrade that item.
  Timeouts identify support needs but do not fabricate incorrect BKT answers.
  Cleared-stage replay stays ungraded. Original story HP rules are unchanged.
- Battle-only failure without unsafe evidence provides tactical guidance, with
  no additional knowledge penalty. Legacy checkpoints without observations
  cannot be used to infer a knowledge weakness retroactively.
- Closing/reopening keeps the review and its first answers. All gameplay entry
  paths share the pending-review check. Retry clears the incident checkpoint
  before consuming the review; completed lessons/stages and currencies remain.
- Save evidence includes decision IDs/outcomes, scored flags, before/after
  mastery, selected topic/lesson, support level, practice first answers and
  corrections, timestamps, and links between successive attempt sessions.
  It travels in the existing save blob. **No new teacher-dashboard report or
  server-side remediation analytics endpoint is implemented here.**

### Stage 2 acceptance contract — They Know Our Project

- Notes for Our Poster → Lesson 3, Almost the real website. The targeted review
  addresses public project details, a new sign-in destination, and the risk of
  forwarding the unverified link to a teammate.
- The Fair Registration → Lesson 2, The name on the left can lie. Review the
  copied teacher identity and branding, deadline pressure, and why replying to
  the suspicious sender is not an independent identity check.
- Who Gets Our Folder? → Lesson 2, with a requester-identity and permissions
  refresher. A genuine sharing site does not authenticate an unknown requester.
  Viewer access can expose private data; verify the exact account first, then
  share only the necessary file and permission. This extends the identity
  lesson in the review; it does not invent a separate permissions lesson.
- Nine newly authored questions (three per topic), with distinct `m1s2_*` IDs.
  Existing `m1s1_*` IDs remain unchanged so past evidence survives the update.
  The same 0.40 threshold selects two focused or three guided questions.
- Preserve the stage's 45-second decision clocks and phone investigation gates.
  A critical choice costs one HP; the fourth failure ends the attempt and opens
  review. Risky choices keep HP and enter containment; a containment loss
  requires review, while successful containment lets the story continue.
- Retrying after review starts **Stage 2**, Incident 1, with 3 HP—not Stage 1 and
  not the incident where the player failed. Stage 1 completion and normal lesson
  progression remain untouched. A successful clear retains existing rewards.
- Save validation rejects cross-stage threat/topic assignments. Both stages'
  review records coexist without overwriting each other.

### Verification

`verify_stage_remediation.gd` uses isolated accounts, including the real
PlayerManager BKT/save serialization, real lesson UI, live stage controller,
and result action. It checks authored mappings, duplicate submissions,
corrections, timeouts, tactical-only failures, malformed/legacy saves, account
isolation, resumed reviews, cleared-stage replay, and opening-state retry.
Stage 2 tests inspect the actual phone evidence and choose the displayed
outcomes through the live UI: fourth failure at each incident, timeouts,
failed/successful containment, and all-safe completion. They exercise all three
review topics, guided/focused practice, reload during correction, distinct
question IDs, stage-specific routing, and Stage 1 progress preservation.
Containment completion/loss is injected at the controller boundary in these
recovery tests; this is not a new combat-balance certification.
Stage 1 screens were inspected at 1280×720 and 844×390; Stage 2 review/practice
screens were inspected at 844×390 landscape. Screenshot artifacts remain under
ignored `.godot/`.

The broad live-stage regression run exposed a Module 2 Stage 7 loadout/balance
assertion (1 remaining HP, expected at least 3); this checkpoint does not adjust
that stage's balance. Outdated test expectations for the dedicated tutorial
and simulation briefing were updated to follow the current authored flow.

## Module interaction identities and authoring contract

Future decision-story scenes share the controller, live workspace, investigation,
BKT, checkpoints, and breach systems. Their signature interactions are:

- Module 1 / phishing: email/message inspection (sender, domain, links,
  attachments, wording and context). Inspect before trusting.
- Module 2 / smishing: SMS and mobile account-event inspection (OTP/recovery,
  carrier/eSIM events and conflicting notifications). Separate the real event
  from the malicious message.
- Module 3 / vishing: the existing live call panel, emotion, duration, timed
  pressure and optional investigation. Break out of the caller-controlled
  channel. Calls stay in their dedicated panel.
- Module 4 / pretexting: identity and story-consistency inspection (claimed
  name, organization, role, history, credentials and timeline contradictions).
  Check what is verified rather than merely plausible. No new content yet.
- Module 5 / baiting: object/file/offer inspection (source, type, description,
  isolation and evidence handling). Something attractive can still be the
  attack. No new content yet.

Optional `display` may appear on a threat for passive inspection before its
existing evidence/choices, or inside its `investigation` config above the
existing evidence-analysis items. Both use the same metadata renderer:

```json
"display": {
  "presentation": "email",
  "metadata": [
    {"label": "FROM", "value": "security@example.test"},
    {"label": "SUBJECT", "value": "Account notice"}
  ]
}
```

Modes are `generic`, `email`, `mobile`, `identity`, and `artifact`. Missing or
unknown mode falls back to generic. Labels/values must be non-empty strings;
malformed rows are skipped. Authored order is preserved, text wraps and scrolls,
and values are literal text rather than interpreted markup. No icon, animation,
or color is required to read them. Modes supply a heading only; they never
read or infer evidence validity, outcomes, BKT or progression. Never author
metadata that labels an item valid or names a SAFE/RISKY/CRITICAL answer.

Each future stage does **not** need every mechanic. Use the signature mechanic
only when it improves the scene. Mix dialogue → decision, dialogue → investigation
→ decision, call → timed decision, inspection → story reveal, and dialogue →
consequence. Do not repeat inspection → decision → TD for every incident.
Adding passive display metadata does not introduce a new required interaction
or change any existing timer/reduced-motion setting.

Current demos: Module 1 Stage 1 Account Suspension Notice (email headers/link),
and Module 2 Stage 2 Delivery Delayed (SMS versus delivery-app status). The
original dialogue, choices, evidence and outcomes remain authored as before.
Module 3 Stage 1 retains its existing call/investigation demo; no Stage 2 or
Case Board is added here.

Normal Stage 1 now launches `src/gameplay/decision/stage_one_live.tscn`.
The dedicated, non-saving preview still launches `preview/stage_one_preview.tscn`.
Stage 2–10, other modules and the tutorial continue to use `level_base.tscn`.

## Preserved story rules

- Authored opening, incidents, evidence, choices, consequences and ending are unchanged.
- SAFE resolves an incident. RISKY waits for **Deploy Defenses**, then runs containment.
- CRITICAL ends the attempt. Losing containment retries the same incident.
- Each containment resets towers, health and gold to the authored breach budget.
- Existing first-wave configuration and Stage 1's 0.60 enemy-health multiplier remain.
- Decision BKT is committed once, with cleared-stage replay mastery frozen.
- Checkpoints, tower unlocks/research/capacity, enemy tasks and victory rewards use existing services.
- Decision losses do not grant the non-decision game's loss reward.

## New presentation

The shared geometric combat controller/HUD supplies the 13×7 orthogonal map,
one-cell placement, tower selection/inspection, movement, upgrades, camera
navigation, animated route markers and death effects. A responsive decision
workspace displays the existing narrative without the legacy oversized placeholders.
Original result overlays/animations remain in use, including the decision-specific
SYSTEM COMPROMISED and CONTAINMENT FAILED outcomes.

### Conversation presentation

Opening, incident and consequence dialogue advances one authored line at a time.
The first named speaker appears on the left and the second on the right, using a
temporary portrait beside a full-width speech box. The listener and all choices
are hidden while dialogue plays. Text reveals progressively with a subtle speaking
animation. Tap the text or **Show Text** to reveal immediately; **Next Line** then
advances. Pause freezes both.

**View Scenario / Start Decision** replaces the conversation with the unchanged
situation and evidence on the left and choices on the right. Both panels scroll
independently; the countdown remains above them. The match controller starts a
45-second timer only at this transition. Choosing stops it immediately. Expiry
commits one RISKY assessment, saves the breach, and shows an explicit timeout
explanation with **Deploy Defenses**. It never claims the player selected one of
the authored actions. The normal containment and saved-breach review rules apply.

**Dialogue Review** opens a scrollable transcript of fully revealed lines and
responses from the current session, without future dialogue or hidden outcomes.
Review pauses typing and the decision timer and blocks underlying actions. Closing
review resumes the same remaining time; it never resets the countdown. Normal
pause also freezes it. Tests cover every incident's timeout and answer/expiry races.

Temporary portraits are code-drawn in `decision/dialogue_portrait.gd`. Final artwork
can be supplied through `DecisionOverlay.portrait_textures`, keyed by exact authored
speaker names (`Mia`, `Security Assistant`, `Ramon (Finance)`). The portrait renderer
fits each texture without stretching; missing entries retain their temporary busts.

The new map is intentionally not claimed to be balance-equivalent to the isometric map.
Future stage migrations should explicitly choose their layouts and authored flows;
the router currently enables only Module 1, Stage 1.

## Testing

Stop and restart the project, then use **Deploy → Module 1 → Stage 1** (normal launch).
An existing checkpoint resumes its incident. A RISKY decision opens **Deploy Defenses**;
SAFE decisions can complete the investigation without combat, as before.

Saved breaches now reopen the current incident's original dialogue, evidence and
choices, not the old “Containment is still running” shortcut. Completed incidents
are preserved. Reconsidering that already-assessed breach does not grade mastery
again; a checkpoint marker survives exits and save normalization until the incident
is resolved. Fresh decisions and ordinary failed-attempt retries keep their existing
assessment rules. No player save reset is needed.

Automated checks (run with Godot from the repository root):

```
godot --headless --path frontend --script res://src/tools/verify_stage_one_live.gd
godot --headless --path frontend --script res://src/tools/verify_gameplay_preview.gd
```

The live harness uses in-memory account/task gateways, exercises outcome and
checkpoint rules, placement/upgrade/move restrictions, and fingerprints the actual
player state to ensure tests leave it unchanged. Its single test enemy is made
non-persistent before being defeated so it cannot update real daily tasks.
For offscreen screenshots, use the compatibility renderer and append `-- --render`.
Layouts checked: 1280×720, 960×600, 844×390.

`verify_decision_stage.gd` is the retained **legacy** decision-scene regression
harness. It writes/restores a guest save; use the new isolated harness for this rollout.

## Accessibility authoring

Essential story and incident information must be written in text. Strong motion
and emotion animation are optional emphasis, never the only way to understand a
scene. Timed decisions must remain usable with extended or disabled deadlines;
do not communicate a critical distinction by color alone. If audio is added
later, provide an equivalent text cue. Keep call identity/status, evidence,
reconstruction findings, and consequences readable without sound or motion.
