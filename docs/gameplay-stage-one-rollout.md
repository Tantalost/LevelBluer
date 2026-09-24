# Geometric gameplay rollout: Module 1 / Stage 1

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
