# Operator dossier

The existing Profile route now shares the readable dark/teal study-screen shell and permanent subtle CRT treatment, with an operator-ID presentation distinct from the Progress screen.

## Reasons to visit

- Identity card: existing avatar, reusable rank insignia, rank points and the next rank target.
- Next assignment: a suggestion from actual stage access and lesson progress, opening the existing Deploy, Lessons, Codex or Progress route. It never launches a locked stage or bypasses a pre-test.
- Field Record and Tower Armory shortcuts: exact authored-stage/lesson totals and current credits.
- Personal intelligence: highest and lowest assessed BKT estimates, including awaiting-sync labels. Absent mastery is not presented as zero.
- Four service milestones derived from recorded lesson and stage completion. They award no new rewards.
- Expandable personal record: name, section, email, reported status, sessions, threat points, reported system levels and available test information.

The full graph and journey remain in Progress. Profile is a concise personal briefing, not a second overall-score screen.

Cached data appears immediately. The existing authenticated profile refresh is retained in the background; UI updates are guarded against exit/account changes. Empty account fields and unconfirmed tests are labeled explicitly. No database, reward, scoring or unlock changes, and no new bitmap assets.

## Verification

Godot: `--headless --path frontend --script res://src/tools/verify_profile_screen.gd`.

For visual QA, run with a graphical renderer and append `-- --render`. Screenshots are saved only under ignored `frontend/.godot/`.

Fixtures cover fresh/partial/completed players, Commander, recommendations, absent and pending mastery, earned milestones, long identity fields, account switches, read-only inspection and 1280×720, 960×600 and 844×390 layouts with simulated safe-area insets. No real account requests, purchases or saves are performed by the test.
