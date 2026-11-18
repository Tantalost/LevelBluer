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

### Milestone 1: learning, BKT, and account reliability

Recommended practice uses current BKT estimates to prioritize the weakest eligible topic (four questions), with one question from another eligible topic. New first responses update mastery; repeated submissions and guided corrections do not add another practice update. Practice records remain separate from checkpoint scores and research assessments. The configured BKT parameters have not been fitted to student data, and mastery estimates are not evidence of learning gains.

Lesson and checkpoint screens bind to the account that opened them. An account change expires the activity, including switching away and back; the learner must reopen it. Godot disconnects their session signals when the screen nodes are freed. A module pre-test seeds only its own topic. Delayed diagnostic acknowledgements preserve newer learning and locally completed pre-tests. BKT fetches reject responses if the account, mastery, or pending-save state changed while awaiting the network.

Local regression coverage includes personalized question selection, duplicate submission protection, save reloads, expired activities, topic-specific pre-test updates, delayed-response protection, and compact landscape touch layouts. Backend checks cover single BKT updates, progress sync, authentication, and learning-record ownership/acknowledgement. Developer verification scripts and their artifacts are local validation material and must not be staged in release commits.

The technical checks do not replace physical-device acceptance. Before closing the milestone, verify a signed-in learner completing practice on a phone, restarting offline, reconnecting to the deployed backend, and switching to another account. Confirm the first learner's progress survives and the second learner does not inherit it. The user authorized Milestone 2 on 2026-10-29; this physical-device acceptance remains outstanding.

Run Godot with `--headless --path frontend --script res://src/tools/verify_lessons_workspace.gd`. This exercises all 30 topics, correct/wrong quiz responses, phase gates, unsafe/safe simulated actions, module locking and compact layout. It does not invoke the save operation. Add `-- --render` in a graphical test process to capture the picker, definition, quiz and simulation to ignored `.godot/` screenshots.

## Lesson presentation update — 16 November 2026

Lessons and lesson reading now use the original Focused Learning instrumental; simulations switch to Terminal Investigation through the existing two-deck AudioManager. Both tracks are delivered from Cloudinary and cached with the existing hosted-audio loader. Crossfades take 1.5 seconds, the new tracks use restrained gain, and existing video ducking, music settings and application suspension remain in force. If hosted audio is unavailable, the existing study/decision music remains usable without blocking learning. Assessment music is unchanged.

- Focused Learning: https://res.cloudinary.com/nfd5bhkz/video/upload/v1794816696/levelblue/audio/lessons/focused_learning_v1.mp3
- Terminal Investigation: https://res.cloudinary.com/nfd5bhkz/video/upload/v1794816708/levelblue/audio/lessons/terminal_investigation_v1.mp3

A failed mini quiz pins Review Lesson above Retry Mini Quiz. Review reopens the current lesson's teaching pages and returns to the existing result; it does not clear answers, rotate questions or award BKT credit. Only Retry starts the next attempt through the existing rotation policy. Passing remains 3/5.

The existing lesson_desktop_sim component owns a presentation-only sequence: SIMULATION slides in, BEGIN follows, the title closes, and the mission briefing types into view. Let's Investigate is hidden and disabled until the briefing finishes. Its original evidence gates and completion signal remain authoritative. All 30 lessons use this entry sequence; Module 1 keeps its six authored operation briefs, while other lessons use their current scenario and verification instructions. Reduced Motion uses stationary titles and immediate briefing text. Hidden screens and application suspension pause the sequence. No new animation manager or bundled media was added.

Recording scripts for Module 1 Lessons 1–6 are in module1_lesson_voiceover_script.md. Preserve the existing seven Lesson 1 video voiceovers. The new script is ready for recording; new lesson narration has not yet been supplied or installed.

Validation: 182 focused checks passed, including all 30 simulation entry/completion flows, failed-quiz review preservation, hosted playback, music mute/resume, and small mobile layouts. Existing game-audio regression passed. Physical-phone acceptance and an APK rebuild were not performed in this change. Developer checks and generated working files remain excluded from commits.
