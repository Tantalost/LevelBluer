# Student Progress

The dashboard Progress route uses the existing Overview, Mastery and Journey tabs, lessons/Codex theme, and CRT overlay. Milestone 2 extends these screens and their shared presentation snapshot; it adds no scenes, assets, dependencies, backend endpoints, or save schema. Reading progress remains read-only. Learning starts only after an explicit tap on an action.

## Data and behavior

- Rank uses AuthService's existing title, points and rank-span helpers; Commander shows a full bar and maximum-rank message.
- Story counts the five authored Module 1 chapter records. Legacy ten-stage clears and replays cannot inflate this count. Future story modules are Coming soon and excluded from the denominator. Chapter titles come from existing definitions and access comes from PlayerManager.story_unlocked. Original completion details show assisted, unassisted, or unknown assistance without treating story activity as a graded assessment.
- Lessons count the thirty LessonCatalog entries against clamped saved lesson progress. Access uses PlayerManager.can_access_lesson_module, including checkpoint prerequisites and existing access to previously started modules. Six completed lessons alone cannot unlock the next module.
- Checkpoints are a separate five-module pass count, using the existing 20/25 threshold. The detail shows a positive best saved score when available. Historical saves cannot distinguish an unattempted checkpoint from a zero score; these show "No passing result recorded", never an invented attempt or pass. Existing checkpoint review does not award another result. Scores remain separate from BKT estimates and independent research assessments.
- Overview recommends the lowest eligible topic below the existing proficiency threshold through LessonCatalog.practice_recommendation. Otherwise it offers the next accessible unfinished lesson/checkpoint, or practice review after completion. The CTA re-evaluates the recommendation at tap time and routes into the existing lesson_player flow, which retains its pre-test and access guards.
- AuthService.progress_mastery_snapshot normalizes five topic keys and reads cached mastery. The gameplay default prior is not presented as an assessment. Missing, invalid and fresh zero values remain Not assessed. Only assessed topics contribute to the average.
- Current graded local evidence takes precedence over cached mastery. Existing pending-save and account-owned legacy queue checks label estimates awaiting sync. Overview identifies the account and uses the existing pending-save flag plus unacknowledged learning events for "Changes waiting to sync". A clean queue says "No pending changes", not an unverified claim of cloud connectivity. Guests see "On this device only".
- AuthService.progress_changed, PlayerManager.progress_changed, and SaveService cloud-fetch/cloud-sync completion signals refresh visible Progress UI. Refreshes coalesce through a deferred call; hidden screens refresh on resume. Session changes clear the previous display, and stale account actions cannot navigate. Node destruction automatically removes signal connections. Reading or entering Progress performs no persistence or network request.
- Profile consumes the same snapshot. Its field-record totals and story milestone descriptions also use chapters, preserving compatibility and consistency without changing rewards.

## Presentation

The reusable mastery radar draws five percentage rings, a translucent polygon only when all axes are assessed, and isolated valid segments otherwise. Topic labels and plotted vertices select the matching details. The topic list scrolls independently; main views scroll vertically when space is tight. Values below 40% are Needs practice, below 70% Developing, and 70% or higher Proficient, using existing gameplay thresholds.

Touch targets account for the viewport scale to remain at least 48 rendered pixels high, including on 844×390 landscape screens. SafeAreaContainer supplies notch and gesture insets. The radar keeps a minimum 360 logical-pixel width and height. The screen does not change device orientation or the BKT model.

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_progress_screen.gd`. Local fixtures cover chapter/replay separation, lesson/checkpoint gates, mastery thresholds and missing data, recommendations changing with mastery, tap-time routing, pending-sync acknowledgement, account isolation, in-memory account-save reloads, read-only browsing, and mobile bounds. Also run `verify_profile_screen.gd` for the shared snapshot consumer. Tests and artifacts remain local and are excluded from commit scope.

With a rendering-enabled Godot run and `-- --render`, the same test writes ignored screenshots to `frontend/.godot/progress_*.png` at mobile landscape viewport sizes, including simulated safe-area insets. These are QA artifacts, not shipped assets. Physical-device touch, offline restart/reconnect, and deployed-account acceptance remain outstanding; automated fixtures do not establish those results. Milestone 3 requires explicit approval.
