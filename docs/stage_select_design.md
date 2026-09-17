# Stage Select / Mission briefing

The per-module stage screen uses the same dark panels, muted teal palette, readable fonts, and permanently enabled subtle CRT shell as Module Select, Lessons, and Progress. A single compact header combines navigation, avatar/name/rank, wallet, and settings. Profile hover stays dark so its child labels retain contrast; long names use ellipsis with the full identity available through Profile. No new raster assets or asset downloads were added.

The expanded left panel presents a short, distinct teaser and field note for each mission, status/lock reason, and known intel (wave count and starting gold). Enemy compositions and solutions are not revealed. Briefings in `stage_briefings.gd` are authored flavor copy, not new gameplay mechanics. Decorative radar/waveform art has been removed so the briefing uses the space directly. Selecting a mission uses a subtle 160ms opacity reveal with no click delay.

Details scroll vertically with Deploy/Replay pinned below. The right panel provides a numbered roster, explicit Completed/Available/Locked states, lock icons, and a cleared-stage progress bar. Selecting a locked mission is informational and never launches gameplay.

Completed cards have a persistent green fill and green status text, including during hover/press. A gold border identifies the selected card independently of completion. Completion comes only from cleared-stage records, not availability. Previously cleared stages with a new exam lock retain their completion tint and explicitly show review required with a lock icon; replay still follows the access rules.

Stage completion counts use explicit cleared-stage records and authored configs. Lesson preparation is labeled separately. Modules without authored stages show Coming soon instead of ten fictitious missions.

## Existing behavior

StageManager.access_reason remains the source of access rules. Stage IDs 1–10 still launch with zero-based indices 0–9 through Router.start_level. Back, profile, and settings retain their routes. No scores, rewards, saves, or unlock rules changed. Session/progress updates, resume, and a low-frequency read-only local-state check refresh the presentation.

## Verification

Run Godot with `--path frontend --script res://src/tools/verify_stage_select.gd`. Add `-- --render` to capture previews under ignored `frontend/.godot`.

The harness uses in-memory fixtures without saves or gameplay launches. It covers all ten selections and distinct short briefings, fresh/partial/full progress, lesson/sequential/exam locks, replay, exact stage totals, unauthored modules, account changes, lifecycle refresh, and unchanged player state from selection. Rendered layout checks cover 1280×720, 960×600, and 844×390 with simulated safe-area insets, a single header, and 48-pixel primary touch targets.
