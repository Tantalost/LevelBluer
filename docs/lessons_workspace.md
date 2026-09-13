# CRT lesson workspace

The Lessons route now opens a horizontal, Deploy-style module carousel with no upgrade card. All five existing modules and their six topics remain in LessonCatalog. Module prerequisites and module pretests are retained; completed modules open in review.

Selecting a module opens a two-panel workspace:

- Left: topic name, threat category, safety rule, and topic navigation. Future topics remain locked until the current unit is complete.
- Right: definition and case example, an answer-checked mini quiz, then a local desktop simulation. Body type is DigitalDisco at 23–28 px instead of the old 10–12 px pixel text. Scrollable content keeps the completion button visible.

The CRT overlay is code-drawn, subtle and static (no flashing or distortion). It is always enabled across lesson selection, the study workspace, pre-tests and Codex; there is no header toggle. No new images or Cloudinary assets are needed.

## Content and simulations

`lesson_study_content.gd` adapts existing case examples and quiz answers into the uniform sequence. Spot, trust, multi-select, and triage questions retain catalog answers; narrative activities use a safe-response knowledge check. Answer positions are rotated per topic. A wrong answer cannot advance to simulation.

`lesson_desktop_sim.gd` provides Windows-style training windows for Mail, Messages, Calls, Service Desk, and Device Security. Each uses the current lesson's case and requires opening, inspecting, independently verifying, and safely reporting the request. Unsafe choices show consequences and allow retry. This is a local scripted exercise: no actual browser, shell, file execution, credentials, phone calls, or external services are used.

Only the final Finish Topic action calls the existing PlayerManager completion API, after both checks pass. Replaying an earlier topic does not increment progress for a future topic. Tutorial callbacks remain available, and pretest return resumes the intended lesson.

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_lessons_workspace.gd`. This exercises all 30 topics, correct/wrong quiz responses, phase gates, unsafe/safe simulated actions, module locking and compact layout. It does not invoke the save operation. Add `-- --render` in a graphical test process to capture the picker, definition, quiz and simulation to ignored `.godot/` screenshots.
