# Student Progress

The existing dashboard Progress route opens a new read-only screen with Overview, Mastery and Journey tabs. It shares the lessons/Codex palette, fonts and always-enabled CRT overlay. No new images, downloads or backend endpoints are required.

## Data and behavior

- Rank uses AuthService's existing title, points and rank-span helpers; Commander shows a full bar and maximum-rank message.
- Stage completion counts explicit cleared-stage records among Module 1's authored stages. Future modules are marked Coming soon and excluded from totals. StageManager.access_reason is shared with deployment and preserves the previous gates.
- Lessons use LessonCatalog totals and clamped PlayerManager lesson counts. Module/topic statuses include completion, prerequisites and pre-test requirements. Journey is informational and never starts gameplay or unlocks anything.
- AuthService.progress_mastery_snapshot normalizes five topic keys and reads cached mastery. The gameplay default prior is not presented as an assessment. Missing, invalid and fresh zero values remain Not assessed. Only assessed topics contribute to the average.
- Pending gameplay assessments are tagged with their participant code. For the current participant, the snapshot uses the local estimate until the queue clears and marks it Awaiting sync. This tag is local only and is not sent to the BKT API.
- AuthService.progress_changed refreshes visible Progress UI on existing persistence/update paths and queue changes. Reading the snapshot or entering the screen performs no persistence or network operation. Session changes clear the previously selected display.

## Presentation

The reusable mastery radar draws five percentage rings, a translucent polygon only when all axes are assessed, and isolated valid segments otherwise. Topic labels and plotted vertices select the matching details. The topic list scrolls independently; main views scroll vertically when space is tight. Values below 40% are Needs practice, below 70% Developing, and 70% or higher Proficient, using existing gameplay thresholds.

Touch targets account for the viewport scale to remain at least 48 rendered pixels high, including on 844×390 landscape screens. SafeAreaContainer supplies notch and gesture insets. The radar keeps a minimum 360 logical-pixel width and height. The screen does not change device orientation or the BKT model.

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_progress_screen.gd`. Fixtures cover fresh/partial/full progress, noncontiguous clears, maximum rank, threshold boundaries, unknown/nonfinite values, pending-sync precedence, account changes, read-only navigation, and deployment-gate parity. The test does not submit answers, save state or invoke completion routines.

With a rendering-enabled Godot run and `-- --render`, the same test writes ignored screenshots to `frontend/.godot/progress_*.png` at desktop, compact and phone-landscape sizes, including simulated safe-area insets. These are QA artifacts, not shipped game assets. Physical-device touch testing is still recommended before release.
