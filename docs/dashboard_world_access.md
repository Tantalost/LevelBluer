# Worlds mission journal

World now displays a live status and short instruction instead of static Continue copy and a hard-coded unread count. Gold ! indicates a lock; GO indicates an available next stage; OK indicates completion of the current authored stage set.

Tapping World opens a navy-and-cream pixel journal with beveled page borders and cyan selection accents. The left page contains five icon-based world cards and All / Completed tabs. The right page shows the selected world's description, a short next objective, lesson preparation and stage checkboxes. The sticky footer offers the existing Lessons, Deploy or Progress route, plus Missions. No fictional rewards or new progression gates are introduced.

Below 1,000 physical pixels wide, the list and details become separate full-width pages. Back returns from details to the list, then dismisses the journal. X always closes it. Touch targets remain at least 48 physical pixels tall. Both scroll views retain scrolling but hide their bars. Tab focus is confined to visible journal buttons, and closing restores the prior focus. Opening uses a short fade, disabled with Reduced Motion; the tween is cancelled on close and teardown.

`world_journal.gd` owns only presentation and emits navigation signals to the dashboard. This separates the new UI from the already-large dashboard controller. `world_access.gd` remains a read-only snapshot; it now also exposes module IDs, names, descriptions and concise objective hints. Selecting a future world only offers Lessons; it does not promise an unauthored deployment map. Completed means all lessons and authored stages are cleared; future worlds are not counted as completed. Cleared stages with replay locks keep their lock reason visible.

The presentation reads existing tutorial, lesson and stage gates. It never changes completion, credits or locks. Refreshes run on dashboard entry/resume, account/progress signals and resize. Future modules explicitly say their stages are coming soon even when lesson-based module access is unlocked.

Known gameplay limitation: no current review flow calls PlayerManager.unlock_stage. Exam-lock guidance therefore does not promise that reviewing a lesson automatically unlocks a stage. That mechanic is unchanged.

Verification: `--headless --path frontend --script res://src/tools/verify_world_access.gd`. With a graphical renderer, append `-- --render` for ignored QA screenshots in `frontend/.godot/`.

The focused test covers tutorial, pre-test, lesson progress, ready stages, sequential gates, exam locks, completion, account changes and read-only state. Journal checks include native card activation, All / Completed filtering and its empty state, selection routes, keyboard focus, hidden-but-functional scrolling, mobile two-step Back, 1280x720 desktop, 844x390 landscape phone with safe-area insets, and 960x540 landscape layout. Screenshots are ignored QA outputs under `frontend/.godot/`. The separate dashboard smoke test checks that mode switching and the existing dashboard remain intact.

## Matching Missions journal

The existing `missions_screen.gd` and scene now use the same navy-and-cream two-page layout. Shared `StudyUI.journal_box` and `journal_check` helpers keep beveled borders and completion marks consistent without coupling either screen's data model. Daily / Main / Event are direct tabs. Mission cards expose live counts and progress bars; selecting one shows its objective and real credit reward. Main, Event, and an empty Daily category have explicit empty states.

On mobile, a mission opens a separate full-width details page. Back returns to the list first; X closes through Router. Hidden scrollbars, focus confinement, touch-sized buttons, and the reduced-motion-aware fade match Worlds. The screen reuses TaskManager snapshots on entry/resume and never issues a payout. Existing rewards are still automatically credited by TaskManager on completion. Existing session-only task storage is unchanged; this redesign does not introduce persistence or a daily reset schedule.

`verify_world_access.gd` also tests Missions: native tab/card activation, progress values, single-line count layout, completion checkmarks, all empty states, mobile Back, keyboard focus, reduced motion, interrupted animation, desktop and landscape-phone layouts, and unchanged credits/task state. Synthetic progress exists only in memory during the test and is restored afterward.
