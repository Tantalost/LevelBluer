# Dashboard World access guidance

World now displays a live status and short instruction instead of static Continue copy and a hard-coded unread count. Gold ! indicates a lock; GO indicates an available next stage; OK indicates completion of the current authored stage set.

Tapping World opens a scrollable access briefing. It explains the next stage/module requirement, lists all five module-access states and ten authored stage states, and provides a Lessons, Deploy or Progress shortcut. Missions remains available from the briefing. Close/system Back dismisses the briefing without leaving Dashboard.

The presentation reads existing tutorial, lesson and stage gates. It never changes completion, credits or locks. Refreshes run on dashboard entry/resume, account/progress signals and resize. Future modules explicitly say their stages are coming soon even when lesson-based module access is unlocked.

Known gameplay limitation: no current review flow calls PlayerManager.unlock_stage. Exam-lock guidance therefore does not promise that reviewing a lesson automatically unlocks a stage. That mechanic is unchanged.

Verification: `--headless --path frontend --script res://src/tools/verify_world_access.gd`. With a graphical renderer, append `-- --render` for ignored QA screenshots in `frontend/.godot/`.

The focused test covers tutorial, pre-test, lesson progress, ready stages, sequential gates, exam locks, completion, account changes, read-only state, modal Back, desktop and phone layouts. The older dashboard smoke test separately reports its existing companion/pre-test assertion (it enables the companion in a fixture then expects _apply_lock_state, which only hides PreTestLock, to disable it). Companion behavior was not changed by this feature.
