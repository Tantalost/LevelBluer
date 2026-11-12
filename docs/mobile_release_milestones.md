# LEVELBLUE: three-week mobile completion plan

Planning date: 29 October 2026. Proposed implementation window: 30 October–19 November 2026 (21 calendar days).

All five modules now have five implemented chapters (6 November 2026). Mika's final hearing closes the school campaign. Module 5 uses five hosted environments, its paper-themed debate effects and Mika's counter artwork. The earlier whole-system audit below records the state before the finale. The 19 November target is a tested, deployable mobile application. Installed-device and deployment acceptance remain open.

## Release outcome

A student can sign in, complete the learning and story paths for all five modules, receive BKT-driven practice, inspect their progress and Codex, play an online match with another student, and use the supported profile/store features. Progress survives restart and reconnect and remains isolated between accounts. Authorized staff can access the agreed learning records through the existing staff system. The installed release works against the deployed services.

The paths are connected but not forced into one rigid sequence. Retain approved lesson/story prerequisites; PvP is an engagement and knowledge-application activity, not a required research test or the primary mastery measurement.

## Evidence available at planning time

- Module 1 has five authored chapters and local gameplay checks. Codex now reads their existing discovery saves and has a library UI. Physical-device acceptance is still outstanding.
- Lessons cover five modules and 30 topics. Recommended practice and account/BKT safeguards exist and have local regression coverage. Full device-to-hosted-service acceptance is outstanding.
- Progress and Profile consume shared progress data. Student progress screens are not proof that the staff dashboard meets its requirements.
- Online PvP already has room/join/matchmaking, authoritative server answers/results, disconnect handling and match-history/rating code. These must be verified with two installed mobile clients against the release backend.
- Store purchase code exists, but some items explicitly say equipping is unavailable. A complete release must implement their intended supported use or remove them from the purchasable catalog with scope approval.
- Module 2 has legacy scenario material; Module 3 has an existing call interaction. These are reusable material, not four completed story campaigns. Modules 4 and 5 need their story content agreed.
- The teacher/school-head web application is a separate dependency. This plan does not assume its authorization, analytics, deployments or source access are already verified.

Gate acceptance uses implemented, locally verified, device verified, blocked or deferred states with evidence. At the user's request, the 6 November audit also supplies approximate planning percentages. Those estimates do not replace gate acceptance or represent measured learning gains.

## Deadline controls

1. Reuse current screen controllers, dialogue, phone, call, investigation, evidence-command, save and account systems. Extract shared code only where an actual second use requires it. No general story-engine rewrite.
2. Freeze all four remaining story outlines early. Define characters, chronology, chapter count, learning purpose, evidence, resolution and cross-module continuity before coding the corresponding module.
3. Complete all four story arcs, while reusing investigation mechanics and short transitions. Do not promise four new Module-1-scale cinematic productions. Exact chapter counts are a Gate 3A decision, not silently reduced later.
4. Ship one reliable existing online duel format first. Additional PvP game types, new reward currencies, elaborate ranking effects, and new store categories are deferred unless all mandatory gates finish early and the user approves.
5. Keep the established mobile palette, type, touch sizes, safe areas and reduced-motion behavior. UI repairs are mandatory when they block use; another broad visual redesign is not in this release plan.
6. Protect 15–19 November for integrated acceptance and release. If estimates exceed capacity at Gate 3A, obtain an explicit scope/date decision immediately. Do not call a release complete while hiding missing mandatory modules or broken workflows.
7. Test each gate immediately. The final test window is for regression, deployment and realistic complete journeys, not the first time accounts, BKT or PvP are exercised.

## Milestone schedule

| Gate | Planning dates | Deliverable | Exit requirement |
| --- | --- | --- | --- |
| 3A | Oct 30–31 | Whole-app baseline, release scope and all story outlines | Agreed content and completion matrix; early device/backend checks; dependencies and estimates resolved |
| 3B | Nov 1–2 | Module 2: Smishing | Complete approved story, investigations, progression, Codex and phone acceptance |
| 3C | Nov 3–4 | Module 3: Vishing | Complete approved call-based story and interruption/resume checks |
| 3D | Nov 5–6 | Module 4: Pretexting | Complete approved identity-verification story and evidence chain |
| 3E | Nov 7–8 | Module 5: Baiting and campaign ending | Complete approved final module, cross-module closure and all-module progression |
| 4 | Nov 9–10 | Lessons, BKT and account integration | Demonstrated adaptive loop across five topics, persistent state and assessment separation |
| 5 | Nov 11–12 | Analytics, staff support and evaluation readiness | Student/staff records agree, role access works, independent assessment and feedback paths agreed/verified |
| 6 | Nov 13–14 | PvP, Store and Profile completion | Two-phone online journey and supported purchase/equip/persistence flows pass |
| 7 | Nov 15–17 | Whole-app mobile acceptance | Release candidate passes full user journeys; no blocking or serious defects |
| 8 | Nov 18–19 | Release build, deployment and contingency fixes | Installable signed build, deployed services, fresh-install/upgrade smoke checks and handover |

The eight story-authoring days are the highest schedule risk. They assume compact approved content, rapid reviews, substantial reuse and no new core gameplay system. Gate 3A must test this assumption against the actual chapter count and implementation capacity.

## Gate 3A — Freeze scope and prove the foundations

### Work

- Walk the current routes: account → Lessons → Story → practice → Progress/Codex → PvP → Store/Profile → restart. Record actual failures and distinguish them from unfinished content.
- Build/install the current Android baseline on the intended minimum-spec phone; confirm the actual target device/OS requirements. Do not infer iOS deliverability from Godot support alone.
- Verify login, token expiry/sign-out, save/reload and one offline/reconnect learning event against the deployed backend. Fix a foundation failure before building four modules on it.
- Run an early two-phone PvP connection/match smoke check. Check deployment WebSocket support, room ownership, service restart behavior and server instance/worker assumptions. Resolve hosting incompatibilities now.
- Confirm the teacher/head dashboard owner, source access, test roles, hosted API contract and deployment responsibility. Record missing access as a dependency with a deadline.
- Agree all four story outlines together: continuing/new characters, consequences of Module 1, how the existing four-light ending connects, location/time continuity and final campaign closure.
- For each planned chapter list its scenario, learner decision, knowledge component, evidence, safe action, feedback, reusable UI, save boundary and asset requirements.
- Set the release feature matrix: mandatory, deferred, current state, owner, acceptance evidence and unresolved dependency. Review day estimates and cut optional work before approving this baseline.

### Exit

Approved outlines and chapter counts; no invented research allocation; runnable baseline; no unowned deployment dependency; credible fit within the remaining time. Story mechanics reuse is demonstrated, not only assumed. Missing staff access or a nonworking online backend triggers a scope/date discussion here, not during release week.

## Gates 3B–3E — Deliver each complete story module

### Common implementation sequence for every module

1. Approve the final script and clue logic against its outline. Every suspicion must distinguish observed facts from assumptions, and the resolution must be supported by the story.
2. Implement dialogue and simulation using existing components; keep a useful tap alternative to precision dragging. Retain character appearance and chapter-to-chapter location/time continuity.
3. Implement investigations, correct/incorrect feedback, hints and the module conclusion. Ensure the learning objective is exercised, not merely described in dialogue.
4. Wire lesson prerequisites, chapter unlocks, original/replay saves, rewards and the return to the hub. Apply rewards once; preserve existing completed saves.
5. Add discovered Codex records and progress totals. Hide future clues/resolutions and make every intended record obtainable.
6. Map scored knowledge checks to existing BKT components and the current observation contract. Record assisted activity separately; do not convert story taps, culprit guesses or cinematic completion into knowledge evidence.
7. Review cached/hosted assets, touch layout, sound settings and reduced motion. Each module requires five new story-specific environment backgrounds plus distinct imagery and visual-effect treatment across its intro, chapter previews, investigations and hearing/counter presentation. Preserve recurring character likenesses and the shared UI theme. Reuse animation components with module-specific assets/parameters; do not duplicate managers. Track visual acceptance separately from gameplay completion.
8. Test normal play, wrong answers, hint-assisted play, replay, app background/resume and save/reload at an intermediate chapter. Verify the concluding transition and account ownership.

### Gate 3B — Module 2 / Smishing

- Learning focus: SMS sender claims, shortened links, requests for OTP/recovery codes, and independent verification through the official service.
- Reuse SMS/private-message views, destination reveal, link expansion and source comparison. Treat names, sender IDs and message threads as clues rather than proof of authenticity.
- Deliver the complete approved arc and its resolution, with safe actions that do not depend on clicking the suspicious link.
- Exit: every chapter starts, resumes and finishes; all evidence/records are obtainable; results connect to the correct smishing skill and later-module unlock rules.

### Gate 3C — Module 3 / Vishing

- Learning focus: authority/urgency during calls, sensitive information requests, ending the call and independently finding a trusted callback route.
- Reuse the call panel, dialogue timing, verification choices and existing audio settings. No dependency on speech recognition, microphone recording or a new voice-production system.
- Provide complete readable dialogue when audio is muted. Test interruption, application suspension, timed choices and resumption; no missed-call dead end or timer advancing while legitimately paused.
- Exit: complete playable arc, consistent caller/evidence logic, accessible call flow and correct vishing observations/progress.

### Gate 3D — Module 4 / Pretexting

- Learning focus: plausibility versus verified identity, claimed roles/permissions, story inconsistencies and independent confirmation.
- Reuse identity cards, message/history comparison, timeline ordering and evidence connection. Verification must rely on a known channel, not contact details supplied by the suspicious person.
- Keep the resolution coherent with earlier modules. Familiarity, job titles and urgency alone are not sufficient evidence of trust.
- Exit: full story and resolution, correct evidence relationships, justified safe responses and correct pretexting records.

### Gate 3E — Module 5 / Baiting and campaign closure

- Learning focus: attractive offers, unexpected files/devices, origin and file-type checks, safe reporting and avoiding execution of untrusted content.
- Reuse file/offer inspection, consequence feedback and evidence reconstruction. Simulations never execute unsafe files or solicit real credentials.
- Resolve the approved overarching story and remaining character threads. End with a clear completion state and routes to review and recommended practice.
- Exit: all five modules are reachable through legitimate progression, the final ending is playable, completion/replay totals agree across Deploy/Codex/Progress, and no mandatory story button leads to a placeholder.

## Gate 4 — Lessons, adaptive BKT and persistent accounts

### Work

- Verify all 30 existing lesson topics: content, answer keys, feedback, simulation completion, prerequisites and checkpoints. Review accuracy against the corresponding new stories.
- Audit actual knowledge-component mappings. Do not advertise fine-grained mastery when only broader threat-topic estimates exist; use accurate labels unless a separately approved change is needed.
- Demonstrate two learners with different response histories receiving different eligible practice selections. Confirm recommendations recompute after new eligible responses and never skip required story chronology.
- Test correct/incorrect updates, initial estimates, all-content-exhausted behavior, duplicate taps, retries/replays and delayed acknowledgements. One eligible new response must not generate multiple mastery updates.
- Confirm progress and recommendations survive restart/offline/reconnect and that account A's records never appear in account B, including delayed network replies and A→B→A switching.
- Keep mastery estimates, formative practice, checkpoint scores, assisted story activity and research assessments clearly separated. Perks cannot affect graded learning checks or research scores.
- Verify PvP ratings, cosmetics, story animation and hint-assisted retries do not silently become equivalent unassisted mastery observations. Keep PvP outside BKT updating for this release unless an explicit defensible observation policy is approved.

### Exit

A recorded device demonstration of answer → saved learning record → BKT update → changed eligible recommendation → consistent Progress display → persisted result after reconnect. Both accounts pass isolation checks. Configured BKT parameters are described accurately; no claim of trained parameters or proven learning gains.

## Gate 5 — Analytics, support and evaluation readiness

### Work

- Reconcile the student Progress screen with stored completion, practice, checkpoint and mastery records across all modules. Display pending/failed sync honestly.
- Verify existing staff dashboard/API integration with actual authorized test accounts. Teachers see assigned students/sections; school heads see their authorized scope. Unauthorized cross-section access must fail at the service, not merely be hidden in the UI.
- Staff must be able to find a learner, review topic mastery and activity, identify a difficulty supported by the records, and use the agreed existing support workflow. Agree the minimum support action during Gate 3A; do not quietly count a dashboard alone as a complete support workflow.
- Present mastery as an estimate; distinguish inactivity, missing data and low mastery. Check timestamps, account/section association and stale data behavior.
- Confirm the independent research pre/post-assessment delivery plan with the adviser. Existing lesson checkpoints/practice items are not automatically independent instruments. Reuse an approved external delivery method if selected; implement an in-app path only when explicitly included and content is ready.
- Verify the existing student feedback submission path and ratings against the receiving dashboard. Do not label the current form a validated instrument without review.
- Document the planned LEVELBLUE-versus-usual-instruction comparison accurately. Section allocation, sample size, instruments and statistical analysis remain adviser decisions; no student recruitment or analysis is part of this app-delivery window.

### Exit

An authorized staff user can complete the agreed monitoring/support tasks with the same records the student sees. Role boundaries and feedback persistence pass. The assessment-delivery decision is documented honestly; incomplete research instruments are not misrepresented as completed app functionality.

## Gate 6 — PvP, Store and Profile working together

### Capture the Flag proposal for review · 7 November 2026

The adviser's consultation changes the intended online duel from quiz damage to first capture. Proposed first playable match: a school event folder containing a simulated flag. Matchmaking, private rooms, Ready and the amber Access Granted handoff lead into the same match. The server assigns one attacker and one defender. Both see the same flag on the cyan network map. The attacker can retrieve it from the remote vault. The defender can secure it in quarantine. The first valid capture ends the match immediately.

| Step | Attacker console | Defender console |
| --- | --- | --- |
| Open a route | Inspect the event invitation and its expanded destination. Trace the link to the simulated sender relay on the map. | Compare the invitation with the club directory. Flag the mismatched sender and route the incident to the verified gateway. |
| Locate the flag | Inspect the relay's attachment manifest. Trace the event pack's delivery reference to the matching vault file. | Restore the original conversation behind the cropped endorsement. Pair the suspicious pack with its incident record to open quarantine. |
| Capture | Tap the verified file and **Retrieve flag**. | Tap the implicated file and **Secure flag**. |

The two routes use equivalent numbers of interactions and evidence of comparable reading length. An incorrect inspection highlights the relevant detail and leaves the current gate open for another attempt. Each role gets one optional interruption, unlocked after its first gate: inspect the opponent's active relay to delay their next transfer briefly. This is a bounded game action on the fictional map. For the first slice, implement and test the plain race first; add the interruption only after both roles can complete the baseline fairly. If time expires without a capture, record a draw. On a rematch the players should be able to try the opposite role.

The playing screen retains the CRT housing and VT323 typeface. A cyan map highlights selectable nodes and the target. A green file/terminal pane shows the evidence for the selected node. On compact landscape screens a tap switches between map and file detail while keeping the flag and rival progress visible. Red **Access Denied** feedback identifies the failed check. The result identifies who retrieved or secured the flag. Commands are touch controls on fictional records.

- The existing online screen hosts the map, evidence pane and result. A tap selects a node locally; a committed action sends the node, action and current state revision through the existing session socket.
- The room service validates role, prerequisites and revision, serializes capture attempts, and broadcasts authoritative progress and one result. Rejoining restores role and progress. A duplicate or late capture cannot award a second win.
- Acceptance: complete both roles through private room and matchmaking, test crossed captures, invalid shortcuts, retry, timeout and reconnect, then play on two phones and compare the routes for reading time and reachability. PvP measures match outcomes separately from BKT mastery and research scores. Bot parity, extra maps and additional minigames are outside this first online slice.

### Work

- Finish the existing duel mode: create/join, ready, match start, questions, answers, scoring, winner, result/history/rating and return to hub. Test matchmaking if exposed in the release UI.
- Use two physical phones on the deployed service. Test background/resume, interrupted network, reconnection grace, quit/forfeit, simultaneous answers, late/duplicate answers, invalid/full rooms, expired authentication and cancellation while searching.
- Keep grading and match results server-authoritative. Recoverable errors must offer a usable action; result retries cannot duplicate ratings or rewards.
- Trace actual PvP-point and store-currency contracts. Confirm intended rewards, balances and purchases agree with the backend and survive restart/sync. Do not invent a new currency bridge to hide a mismatch.
- Complete supported cosmetics from purchase → ownership → equip → Profile/PvP appearance → restart/account sync. Test insufficient balance, already owned items, repeated taps and account switching.
- Resolve collection-only items with the user: implement their intended use within the time box or remove them from sale. Do not sell an item promising functionality the build does not provide.
- Keep competitive results separate from research assessments and BKT mastery. Cosmetic equipment cannot alter graded learning outcomes.

### Exit

Two students complete multiple real online matches and see consistent outcomes. Connection loss has a defined result. Purchases/equipment and earned balances persist correctly; every visible Store action works. No extra game type is required to declare this existing mode complete.

## Gate 7 — Complete mobile acceptance and feature freeze

Freeze additions on 15 November. Work only on defects, clarity, performance and accessibility required for the agreed release.

### Required acceptance journeys

1. Fresh student: sign-in/onboarding → module baseline/lessons → Module 1 story → practice → progress/Codex → later modules → campaign ending.
2. Returning student: save mid-activity → background → terminate → reopen → resume without lost progress, repeated rewards or skipped required work.
3. Offline/reconnect: previously available lesson/story content remains usable as designed; cached assets have a clear fallback; pending learning sync completes once when connectivity returns. Online-only actions explain that connectivity is required.
4. Account change: A signs out and B signs in; screens, queued callbacks, rewards, mastery, drafts and cosmetics do not cross accounts.
5. Social journey: two signed-in phones join/match/play/end → rating/history → supported Store purchase/equip → another match/Profile.
6. Support journey: student learning reaches the staff system; an authorized staff user identifies the relevant difficulty and completes the agreed support action.
7. Accessibility/lifecycle: small landscape safe areas, Android Back, virtual keyboard, long text, sound off, reduced motion, pause/resume and slow network all leave navigation usable.

### Exit

- No reproducible crashes, lost/cross-account progress, incorrect grading/mastery writes, blocking chapter paths or inconsistent online outcomes.
- Every required journey passes on the agreed minimum device and a second target phone. Establish measurable performance targets at Gate 3A and record actual results here.
- Serious usability/accessibility defects are fixed. Only explicitly accepted minor cosmetic defects may remain in the release notes.
- Local tests, screenshots and logs support the acceptance record. Passing automated checks alone is not physical-device acceptance.

## Gate 8 — Release, deployment and handover

- Produce the signed release build for the confirmed distribution target; verify package/version identifiers and release configuration. Signing secrets stay outside source control.
- Verify hosted production service versions, required migrations, HTTPS/WebSockets and Cloudinary asset references. Migration/deployment changes follow the approved deployment process.
- Test a clean install and upgrade from the previous supported build, including saved accounts/progress and missing/slow asset downloads.
- Run release-build smoke journeys for login, one lesson/practice event, story resume, sync, two-device PvP, equipment and staff visibility.
- Deliver the install artifact, build/version information, short user/staff instructions, accepted limitations, test evidence and recovery/rollback procedure.
- Inspect explicit staged paths before any requested commit. Developer tests, verification scripts, UID sidecars for those scripts and generated artifacts remain local. Do not blanket-stage, delete tests to hide them or overwrite unrelated work.

### Exit

The release build installs and passes against the deployed environment; mandatory features are available; the recipient has the artifact and operating instructions. An editor demo alone does not satisfy this milestone. Public-store publication is a separate deliverable unless explicitly required and its external review timeline is accounted for.

## Review and escalation rules

- At each gate: report completed behavior, changes, local/device validation, remaining defects/dependencies and exact next gate; wait for user approval.
- If a mandatory dependency fails or a time box is exceeded, state the impact immediately and propose a concrete scope/date tradeoff. Do not silently spend the final test buffer.
- Cut optional polish, additional PvP modes and new asset variants first. Do not cut account isolation, correct BKT/scoring, mandatory story completion or usable mobile navigation to preserve cosmetic work.
- This is the delivery plan for the whole mobile system. Story completion is one major part of acceptance, not its substitute.

## Gate 3A working record — 30 October 2026

### Decisions confirmed

- The delivery target is the whole tested mobile application, including Story, Lessons, BKT and PvP, by 19 November; research fieldwork and analysis are outside this window.
- The governing campaign is the current school story. The user explicitly selected this over the old BlueTech campaign on 30 October. Legacy scenario mechanics remain reusable, but their corporate plot does not constrain the new story.
- The user approved the five-chapter-per-module structure and Amani/Liza/Sir Rham/Mika protagonist assignments on 30 October. The chapter breakdown below is the structural baseline for script development. Detailed dialogue, final attribution evidence and new character art still need review; this is not acceptance of the remaining technical Gate 3A checks or authorization to start Gate 3B code automatically.

### Baseline and release matrix

| Area | Evidence / current condition | Work required before release | Gate / owner |
| --- | --- | --- | --- |
| Module 1 | Five authored chapters; previous local chapter checks passed | Physical-phone journey and shared-component regression during later changes | 3A/7, development + user device testing |
| Modules 2–5 | Current chapter registry and story unlocks recognize only Module 1; other modules still route through legacy stages | Approved outlines, chapter routing, validated saves, progression and module endings | 3B–3E, development + user content review |
| Codex/Progress | Chapter lists and totals currently cover Module 1 only | Extend existing projections to every accepted module without counting unauthored chapters as available | With each story gate |
| Lessons/adaptation | Lesson journey local check reported zero failures on Oct 29 | All-topic and installed-device adaptive journey; preserve eligible first-response updates | 4, development |
| Offline BKT persistence | Initial sandbox run hit read-only SQLite/save errors; approved writable rerun completed with failures=0 | Real-device restart/reconnect test remains required; the writable fixture is local verification | 3A/4, development + device access |
| Backend services | Initial sandbox HTTP TestClient batch timed out; approved rerun outside sandbox passed 173 tests across auth, BKT, learning records, progress and PvP services/routes/history/rating | Installed-client/deployed-service acceptance remains required; no production fix was needed to pass this local suite | 3A, development |
| Hosted game API | Oct 29 GET /health returned status=ok and service=levelblue-mobile-backend | Authenticated login/save/reconnect and two-client match on deployed version; health alone verifies neither | 3A/6, deployment owner + development |
| Local development server | app.main:app starts and /health passed on 127.0.0.1:8081 on Oct 29 | Use correct command; Godot still points at hosted server, pending any explicit local-test selection | Development convenience, not release acceptance |
| PvP client | Session fixture and full online-screen fixture each reported zero failures | Two-device deployed match, disconnect/rejoin and result/rating persistence | 3A/6, development + device access |
| Android packaging | Oct 30: signed development APK exported with Godot 4.7.2, existing JDK 23 and Android build-tools 36.0.0; signature, APK alignment, native-library alignment and packaged data checks passed | Install and exercise on target devices; production package ID, signing ownership, launcher branding and distribution remain release decisions | 3A/8, development + release owner |
| Device access | ADB started successfully Oct 30 but listed no connected devices | User supplies/attaches target phone(s), confirms Android versions and permits test accounts; no passwords in chat | 3A/6/7, user |
| Store/Profile | Some items explicitly state collection-only / equipping unavailable | Every purchasable supported item has a working intended use; agree handling of unavailable categories | 6, development + user scope decision |
| Teacher/head analytics | Configured web API is a separate project; source/access not supplied here | Locate source/owner and test roles; prove authorized progress visibility and support action | Dependency due during 3A; implementation/acceptance in 5 |
| Research evaluation | Comparison direction agreed; instruments and allocation not finalized | Adviser confirms independent assessment delivery; app checkpoint scores must not be relabeled as independent research tests | 5, research adviser + project owner |

Earlier SDK inventory was incomplete: the platform and build-tool directories do exist. A development APK has now been built and inspected; physical-phone acceptance remains pending.

Local evidence is under ignored frontend/.godot/: gate3a_verify_lesson_journey.log, gate3a_verify_bkt_offline_sync.log (restricted failed run), gate3a_bkt_writable.log (passing rerun), gate3a_verify_pvp_online_session.log, gate3a_pvp_screen.log, gate3a_backend_core_review.log (timed-out restricted run) and gate3a_backend_verified.log (173 passing tests). Keep these and developer scripts out of commits. Do not reuse real student identities for automated fixtures.

### Android baseline build — 30 October 2026

- Preset: `frontend/export_presets.cfg`, **Android Development**. Output: ignored `builds/android/levelblue-dev.apk` (approximately 77 MiB). Development identity: `com.levelblue.mobile.dev`, launcher name **LEVELBLUE Dev**, version `0.1.0-dev` / code `1`. This separate package has its own local saves and does not migrate an installed production package's data.
- Installed only the Android debug/release templates and version marker from the official Godot 4.7.2 standard template archive after checking its SHA512 against the official checksum file. Templates, editor settings and debug signing key remain local. Existing JDK 23.0.1 successfully built and signed this APK; no Gradle project or additional Java installation was introduced.
- Enabled `textures/vram_compression/import_etc2_astc` in the existing Godot project, as required by the Android exporter. Added one shared export preset; no gameplay scripts or scene hierarchy changed.
- The APK includes ARM64 and x86_64 engine/SQLite libraries. ARM32 is disabled because the bundled SQLite extension does not supply it. Manifest floor is API 24 and target is API 36; these are packaging values, not a claim of tested minimum-device performance. The actual supported device baseline is still awaiting confirmation.
- Verified v2/v3 APK signatures, 16 KiB ZIP alignment and all native libraries' 16 KiB ELF LOAD alignment. Confirmed the launcher alias, landscape orientation, Internet-only permission and disabled account-data backup in the manifest. Confirmed bundled lesson, question, assessment and story JSON files; developer tests, verification scripts and diagnostic client are absent. Retained `src/tools/map_builder.gd`, which is a runtime scene dependency.
- Export log: `frontend/.godot/android-build/export-debug.log`. Android package inspection emits an optional themed-icon resource warning from the template; launcher branding/themed-icon verification remains part of device/release acceptance. The export itself completed without script errors.
- Godot still uses the configured hosted APIs and Cloudinary. First-use remote assets and authenticated flows require connectivity; a valid APK does not establish that those services or login work on a phone.
- `/builds/`, keystores and JKS files are ignored by the root `.gitignore`; export credentials were already ignored. No generated APK, signing material or developer test is intended for a commit.

Rebuild from the repository root after configuring Godot's local Java/Android SDK paths and installing matching Android templates:

```powershell
New-Item -ItemType Directory -Force -Path builds/android | Out-Null
& '<path-to-Godot-4.7.2-console.exe>' --headless --path frontend --export-debug 'Android Development' '../builds/android/levelblue-dev.apk'
```

For the installed-client check, connect an authorized test phone with USB debugging enabled, verify it with `adb devices -l`, then install with `adb install -r builds/android/levelblue-dev.apk`. Check cold launch and touch navigation; test-account login; lesson completion and account progress; one eligible BKT response; background/resume and process restart; offline activity followed by reconnect/sync without double counting. A second authorized client is required for deployed PvP acceptance. Do not use a real student's account for fixtures or report these checks as passed before observing them.

### Shared implementation boundary for the new stories

- Extend the existing chapter selection, module routing and PlayerManager chapter definition/validation methods. Preserve all existing original/replay keys; adapt Progress and Codex through those same definitions. Do not create another save manager or replace the old campaign saves wholesale.
- Use a chapter screen with the current dialogue/portrait region, story phone or call panel, existing investigation widgets and existing results/evidence transition. Signals remain owned by the active screen; completion calls the existing validated save/reward APIs. Generalize a component only when its second actual use requires it.
- Route eligible independent answers through the existing learning-record/BKT path. Keep tutorial assistance, retries, dramatic culprit choices and scene completion separate. Read-only Codex browsing and PvP ratings create no mastery observation.

These are the proposed integration boundaries for Gate 3B, not a new engine implementation in Gate 3A. The current hard-coded Module 1 registry is a known integration task, so copying chapter files alone will not complete the new modules.

### Approved campaign structure / detailed script brief

Approved size: five compact chapters per remaining module, twenty new chapters total. Each chapter has one main dramatic development and a small investigation; module finales reuse the current evidence challenge/reconstruction format. Aim for roughly 12–20 minutes per new module at normal reading speed, to be measured with a real playthrough rather than enforced by a timer. Accessibility reading time remains unrestricted.

The count, protagonists and broad final-module role are approved. Detailed ending dialogue and attribution evidence are not yet a final script. If the first implemented chapter shows this production scope cannot fit the eight story-development days, revise the schedule/scope openly before producing the rest.

#### Continuity proposal

- Keep John's Module 1 outcome intact. Jobert remains removed from the club; he cannot casually resume being John's trusted helper in later chapters.
- Use the approved five viewpoints: John (Module 1), Amani (Module 2), Liza (Module 3), Sir Rham (Module 4) and Mika (Module 5). Amani and Liza already appear by name in the opening's cast; Sir Rham/Mika fill its currently unnamed staff/classmate roles. Check the montage artwork before assigning those figures or updating its captions; the approved role mapping does not establish that the existing illustration already matches their appearances.
- John becomes a supporting peer who asks verification questions instead of supplying every answer. Sir Rham coordinates legitimate help. Dan and Eric may contribute information; their earlier jokes/financial worries do not automatically make them suspects again.
- Four lights represent four active attacker connections, not five module counters. The proposed operators are Jobert, a text operator, a voice operator and The Collector. Module 1 closes Jobert's connection; Modules 2 and 3 close the text and voice operations; Modules 4 and 5 expose and contain the Collector's identity/deployment workflow. Module 4 does not extinguish an invented fifth light.
- The next chapters must introduce evidence of that coordination before asserting it. A similar phrase, timing coincidence, alias or familiar profile picture is not sufficient attribution. Account/service records supplied by an independently verified source, corroborated communications and the eventual admission explain the operation.
- Proposed motive: steal wallet/account access and use the school's trusted contacts to reach more students. The final prize/file is a way to extend that access. No hidden technical superpower or unintroduced mastermind appears only in the last scene.

#### Module 2 — Text Tricks: "The Message That Knew"

Viewpoint: Amani. John is trying to help without becoming another person Amani follows blindly. The humor comes from everyday school expenses and Amani's impatience; the threat is the believable mixture of real notifications and malicious instructions. Existing BKT component: smishing.

| Chapter | Story development | Reused interaction / evidence | Learner decision and resolution |
| --- | --- | --- | --- |
| 1. The Missing Delivery | Amani is waiting for materials for the club event. A delivery SMS asks for a small redelivery payment. Dan jokes that even the parcel wants allowance. | Phone messages; hold-to-reveal and destination comparison; real order status accessed independently | Identify the payment request and mismatched destination; verify in the known service instead of following the text |
| 2. A Code I Didn't Request | A real login/recovery code arrives immediately after the suspicious message. Another text claims that returning the code will cancel an attacker. | Compare actual notification text with the claimant's instructions; annotate what the code authorizes | Recognize that a genuine code does not authenticate the person requesting it; withhold it and secure the account through a known route |
| 3. The Familiar Name | A message appears under a familiar service label and mentions the club delivery. Amani thinks the details settle it; John asks how the sender could have learned them. | Compare request, recipient, visible context and independently obtained service information | Separate known facts from a claim of identity; do not treat a sender label or accurate detail as proof |
| 4. Last Chance | The claimant switches from delivery help to a mobile-account problem and demands an urgent recovery action. Amani nearly follows a reply containing a fake "official" number. | Timeline/order puzzle; select the independently obtained contact channel; preserve message context | Break the attacker-controlled chain; verify the genuine account event without sharing codes or using the supplied contact |
| 5. Keep the Code | Full Chapter 5 debate in the Module 1 format: challenge the fee, genuine-code, familiar-detail and recovery-route claims. A legitimate support response confirms the unauthorized attempt was blocked. | Shared preparation, cinematic entry, terminal evidence commands, credibility/hints, counter effects and closing reconstruction/animatic; new support record introduced before use | Amani keeps control of the account. The suspicious text account is reported; the text operator disconnects in an audience-only cutaway. Coordination remains a developing question, not a guess presented as fact |

Lesson mapping: suspicious SMS/link inspection, code secrecy, familiar sender claims, real-event versus fraudulent instructions, independent verification. Candidate evidence: delivery/status mismatch, real code purpose, copied public detail, attacker-supplied contact, verified support outcome. Red herring: Dan knew the delivery schedule; that access does not identify its sender.

#### Module 3 — Phone Tricks: "Stay on the Line"

Viewpoint: Liza. She knows about the text incident and is determined not to be fooled, making a reassuring caller more persuasive than another obvious threatening message. John helps her review what was actually verified. Existing BKT component: vishing.

| Chapter | Story development | Reused interaction / evidence | Learner decision and resolution |
| --- | --- | --- | --- |
| 1. The Helpful Caller | A supposed account-security worker calls Liza about the recent school scam and sounds patient and professional. | Existing call panel, transcript and claimed-identity card | Identify the claim without treating caller ID, a calm voice or knowledge of the incident as authentication |
| 2. They Know My Name | The caller mentions details that were genuinely available in a club post. Liza's confidence rises. | Compare caller statements with the original source; evidence selection | Distinguish knowledge of a person from permission to access their account |
| 3. Don't Hang Up | A genuine security alert appears during the call. The caller says the code is needed to stop a pending transaction and insists Liza stay connected. | Call/message switching, request inspection, optional pause; accessible choices | Refuse secret sharing and end the caller-controlled interaction; no real call or wallet transaction occurs |
| 4. Call Back, Safely | A second supposed supervisor offers a callback number. Liza instead finds a trusted contact through a known official channel. | Choose independent contact; compare callback transcript and caller's story | Reject confirmation supplied by the same suspicious chain; authorized support contradicts the request |
| 5. The Voice Loses Control | Liza reconstructs the attempted takeover. Sir Rham supplies a verified incident acknowledgement before the evidence challenge. | Shared Chapter 5 preparation, cinematic entry, four evidence-command rounds, credibility/hints, counter effects, final contradiction and closing reconstruction; transcript accessible with sound off | Liza secures the account and preserves the call details. The voice operator leaves the masked meeting; the final connection remains |

Lesson mapping: caller-ID limitations, authority and emotional pressure, codes/secrets, ending a call, independent callback verification. Candidate evidence: asserted identity, public information source, actual security-alert purpose, fabricated callback channel, official contradiction. Red herring: Eric called Liza earlier about club expenses; proximity in a call log is not authorship.

#### Module 4 — Fake Stories: "The Perfect Credential"

Viewpoint: Sir Rham. The attacker changes strategy because students are checking messages: impersonate someone authorized to help the whole school. This gives the teacher a believable reason to need verification rather than making him inexplicably careless. Existing BKT component: pretexting.

| Chapter | Story development | Reused interaction / evidence | Learner decision and resolution |
| --- | --- | --- | --- |
| 1. Here to Help | A supposed incident-response coordinator contacts Sir Rham with a convincing appointment and school branding. | Identity/request card; compare appointment with trusted internal schedule | Separate a well-prepared story from independently confirmed authority |
| 2. A Consistent Story | The profile, email and meeting invitation all agree. The coordinator requests a student contact list for urgent protection. | Match claims across records; mark which sources are independently controlled | Recognize that several attacker-controlled sources can repeat the same false identity |
| 3. The Exception | The coordinator claims an urgent exception authorizes roster access and tries to move the discussion to a private chat. | Permission/request comparison; choose a documented independent approval route | Protect student data and refuse an unverified exception; apparent helpfulness does not replace authorization |
| 4. Ask the Real Office | Sir Rham contacts the actual office through an existing directory. The office confirms the claimed person was not assigned and preserves the fraudulent request. | Timeline and verified-response comparison | Identify the unsupported identity and request using evidence the player has actually seen |
| 5. The Mask Holds | An evidence review defeats the claim that consistent branding proves authority. The operator changes tactics instead of obtaining the roster. | Full shared Chapter 5 preparation, cinematic entry, four evidence-command rounds, credibility/hints, counter effects, final comparison and closing reconstruction/animatic | The school restricts access and shares verified guidance. The Collector's connection remains active; the plot carries into the final delivery attempt |

Lesson mapping: pretext plausibility, independent sources, authorization, minimum necessary information, escalation. Candidate evidence: unconfirmed appointment, shared source behind matching documents, data request, missing authorization, real-office denial. Red herring: a real staff member's scheduling error; it does not establish involvement. The player is not asked to identify a real person's guilt from branding or a signature alone.

#### Module 5 — Tempting Offers: "The Last Gift"

Viewpoint: Mika, preparing the club event. The last operator offers something the club actually wants: a ready-made event asset pack after the earlier disruptions. John, Amani, Liza and Sir Rham now bring different verification skills to the same case. Existing BKT component: baiting; the finale also reviews previously introduced topics without creating new mastery categories.

| Chapter | Story development | Reused interaction / evidence | Learner decision and resolution |
| --- | --- | --- | --- |
| 1. A Gift for the Club | Mika finds an attractive offer for event materials. It invokes the school's recovery effort to make accepting feel helpful. | Offer/source inspection; compare claims with the approved supplier or sender | Evaluate provenance before accepting an attractive file or device |
| 2. Just Open It | A preview and friendly note say to run an attached helper to unlock the pack. The file details do not match the promised content. | Existing file metadata and hotspot inspection; no real file execution | Refuse the unexpected execution/permission step; appearance alone is not a safety guarantee |
| 3. Everyone Already Has It | A copied endorsement suggests classmates have used the pack. Mika asks them through their established chat and gets a different answer. | Compare endorsement with independent replies; evidence matching | Recognize manufactured social proof and avoid forwarding an unverified offer |
| 4. Four Connections | The group assembles records already earned. A verified incident report and preserved communications, introduced here, supply the missing link between the accounts and the final delivery. | Existing timeline/case-note reconstruction; deliberately include unsupported shortcuts as distractors | Explain what the campaign tried to gain and what the records can actually establish; the report names its limits |
| 5. Close the Connection | The final evidence challenge confronts the Collector's claims. The story supplies a recorded admission/corroborated record before attributing operation control, then shows containment and support for affected students. | Reused terminal evidence commands and closing comic/animatic; four-light asset reused for final shutdown | The malicious delivery is contained, compromised access is revoked through legitimate support, evidence is retained and reports are made. The last light goes out. End on campaign completion and a clear route to review/practice |

Lesson mapping: reward/curiosity bait, source and file-type checks, unexpected execution/permissions, social proof, reporting and containment. Red herring: Mika's enthusiasm for the event; wanting the gift is not wrongdoing. No student is blamed for being deceived, and no ending promises that one click automatically compromises every device.

### Content and asset budget to review

- Five compact chapters per module, at most three short scored knowledge checks/investigation steps per ordinary chapter; one short reused evidence challenge at each module end. Exact question mapping and answer rationale are authored with the script before code.
- One location/time card and a brief module transition; reuse existing school/room backgrounds, phone views, portraits, call UI, sound library and hearing effects. Do not budget four new long opening movies or new combat systems.
- Amani and Liza may need approved portrait references or consistent existing art. Sir Rham and Mika need an asset-availability check before committing to portraits in every scene. Text/phone presentation can carry early scenes; final required assets must be settled before a module is accepted.
- Reuse the four-light scene only after reviewing the artwork's actual composition. Make the masked cutaways visibly separate from what the protagonists know; an audience reveal does not automatically unlock student evidence.
- New final source portraits/covers can use the existing Cloudinary workflow when needed. No generated PNG dumps or unused variants are included in commits.

### Gate 3A completion blockers and next decisions

1. Complete: school continuity, five chapters per module and protagonist mapping are approved. Detailed scripts and the precise final attribution/connection-resolution scene remain review work inside their story gates.
2. Confirm target Android devices/versions and two student test accounts; attach a phone for install/lifecycle checks. Never request passwords in chat.
3. Confirm the teacher/head project location and deployment owner, including a legitimate staff test role and the minimum support action.
4. Android baseline export and package inspection are complete. Finish the authenticated physical-device checks. Writable/offline sync and the backend suite pass locally; these do not replace an installed-client check.
5. Reassess the two-day-per-module estimate after the first complete reusable chapter. A deadline-driven content reduction needs explicit approval.

Gate 3A acceptance remains open. On 30 October the user deferred phone testing and explicitly requested the next milestone; Gate 3B can therefore proceed. Device/deployed-account/PvP checks and staff access remain release dependencies. Module 2 Chapters 1–5 are now implemented and locally verified; device/deployment acceptance remains open, so Gate 3B is not fully accepted.

## Gate 3B — Module 2 script and integration review

Status: approved for implementation on 30 October, including new character and background generation. This section records the five-chapter script brief; only Chapter 1 is currently playable.

### Continuity and presentation

Module title: **The Message That Knew**. Viewpoint: Amani. Opens after John's hearing, during preparations for the club event. John is supportive but does not become a replacement authority who knows every answer. Jobert is not restored to the club. Reuse the school hallway and clubroom; do not present John's bedroom artwork as Amani's room.

The current opening explicitly says Amani has no signal while friends receive messages that appear to be hers. Chapter 3 must show that incident. The proposed explanation is a copied public identity using a different contact, established by comparing the messages. Do not silently change this into a confirmed SIM swap or successful takeover. The interrupted signal is visible context, not proof that the sender controls her phone; Wi-Fi lets her review the evidence. The later support record confirms the particular wallet attempt was blocked, not that every account is universally safe.

The user authorized a new Amani expression sheet and event-room background. Both are generated and integrated for Chapter 1; see the asset record below. Their final visual acceptance remains open. Do not substitute John's portrait for Amani; use available John/Dan/Sir Rham portraits only for those speakers. Keep the established navy/cyan/cream theme, touch controls and readable dialogue. No new cinematic system is required.

### Chapter 1 — The Missing Delivery

**Location:** clubroom, lunchtime. Amani is tracking event materials she genuinely ordered. The order was paid already. A public club post mentions that the materials are arriving today, but does not publish her private order number.

**Script beats:**

1. Amani: "Twenty name tags. Zero tape. Somehow I'm managing a club event and a national supply crisis."
2. Dan: "Did you try tracking the tape?"
3. Amani: "I am tracking the tape. The tape is apparently having a better lunch break than us."
4. Phone notification: "Parcel update: delivery failed. Pay ₱18 to reschedule today. Track delivery: https://go-parcel.example/r/8K2."
5. Amani: "Eighteen pesos? Fine. That's cheaper than walking to the depot."
6. John: "Maybe. What does the order you already have say?"
7. Amani: "You're asking me to check my delivery in two places?"
8. John: "Start with the place you used before this message arrived."
9. The player opens the saved order through the simulated app's own icon. It says "Paid. Out for delivery. No redelivery fee requested." The SMS carries no matching order reference.
10. Amani: "My parcel isn't asking for eighteen pesos. Someone else is."

**Investigation:** hold the link, with an equally available **Inspect address** tap; expand the shortened destination locally; compare with the independently opened order. The simulated destination is `https://parcel-redelivery.example/pay`, while the known service is `https://parcel.example`. Correct selections receive green highlighting and an explanation. A shortened link or HTTPS alone does not decide safety; the conflicting request and independent order context matter.

**Evidence:** unexplained redelivery payment; hidden destination; independent order status. **Exit:** Amani preserves the message and does not pay. Chapter 2 starts when a genuine security code arrives. No player is required to open a real URL or enter personal information.

### Chapter 2 — A Code I Didn't Request

**Location:** same clubroom, minutes later. The code belongs to a fictional wallet's device authorization, not to the parcel. The attacker tries to turn a real alert into a cancellation instruction.

**Script beats:**

1. Wallet alert: "Use this code to authorize a new device. Do not share it. If this was not you, open the wallet app directly."
2. New SMS: "The delivery payment triggered a verification error. Reply with the code to cancel it. Do not open another app while cancellation is pending."
3. Amani: "I didn't even pay. Why is my wallet involved?"
4. John: "What does the wallet say the code will do?"
5. Amani: "Authorize a new device."
6. John: "And what does this person say it will do?"
7. Amani: "Cancel one. That's the opposite instruction wearing a customer-service voice."
8. Amani closes the SMS reply and opens the known wallet app. The suspicious device attempt is visible there; she selects the legitimate reject/report action.
9. Amani: "The code can stay on my phone. It didn't ask for a field trip."

**Investigation:** match the genuine code's stated purpose to the action it authorizes; mark the contradiction in the cancellation request; choose the wallet app independently. The display uses a fixed fictional code, and the player never types a real one. Incorrect choices explain that receiving a real alert does not authenticate a separate sender. Hints teach the distinction without becoming graded responses.

**Evidence:** new-device authorization text; opposite cancellation instruction; independently rejected attempt. **Exit:** she does not share the code. The immediate attempt is stopped, but the origin of the messages is unresolved.

### Chapter 3 — The Familiar Name

**Location:** hallway outside the clubroom, later that afternoon. This is the opening montage's Amani incident. Her cellular signal drops. She connects to school Wi-Fi; John shows a message Dan received under Amani's name and copied profile picture.

**Script beats:**

1. John: "Did you tell Dan the parcel needs another payment?"
2. Amani: "I told Dan to find tape. That's the only transaction I've authorized."
3. John shows the forwarded message: "It's Amani. New number for today. Club parcel is stuck—pay the small fee here and I'll return it."
4. Amani: "That's my photo. And my phone has no signal. Did they get into it?"
5. John: "Let's check what we actually know before we decide that."
6. The player compares the sender with their established conversation. It is a different contact; Amani's usual chat remains accessible over Wi-Fi. The profile image and delivery detail also appear in the public event post.
7. Dan: "I knew the delivery was today too. I posted the reminder."
8. Amani: "So knowing the delivery day isn't exactly a secret handshake."
9. John: "And a copied name doesn't tell us who is behind the account."
10. Amani warns the club through its established chat: "That new-number payment message isn't mine. Check with me here before sending anything."

**Investigation:** match copied details to the public post; compare the unfamiliar contact with the established one; separate observed facts from assumptions. Preserve the no-signal observation without teaching that it proves a SIM swap or device compromise.

**Evidence:** impersonating contact; public source of the copied details; denial through Amani's established account. **Red herring:** Dan knew the schedule. Knowledge of the schedule alone does not identify the sender. **Exit:** classmates are warned; no unsupported culprit accusation is made.

### Chapter 4 — Last Chance

**Location:** clubroom, after classes. Another SMS claims to fix the phone problem. It supplies its own support number and demands the authorization code before a short deadline.

**Script beats:**

1. SMS: "Your mobile account is at risk. Call our recovery desk now and give the verification code to restore access. Three minutes remaining."
2. Amani: "They've gone from delivering tape to repairing my entire life."
3. John: "Which service issued that code?"
4. Amani: "The wallet. Not my mobile provider."
5. Sir Rham: "Use the contact details you already trust. Don't let the message choose who confirms its own story."
6. The player reaches help through the wallet's existing app and checks the carrier through an independently opened service channel. No real call is placed.
7. Wallet support: "Do not read the device authorization code to a caller. Your rejected device request is under review. Keep the case reference in this app."
8. Amani: "So calling the number in the warning would still leave me inside their instructions."
9. John: "Exactly."

**Investigation:** order delivery request → genuine code → impersonating message → recovery pressure; choose the independently obtained contact rather than the supplied number. A fabricated countdown may appear inside the SMS, but it never expires the student's decision or penalizes reading time.

**Evidence:** cross-service pretext; attacker-supplied verification route; independent support response. **Exit:** preserved messages are attached to the simulated support case. Signal loss remains insufficient evidence of takeover; the story does not invent a technical diagnosis without records.

### Chapter 5 — Keep the Code

**Location:** clubroom, next morning. The genuine parcel arrives. Amani opens the reply inside the support case she created—not a new unsolicited text claiming to be support.

**Script beats:**

1. Dan arrives holding the parcel: "Your tape has completed its character development."
2. Amani: "Mine cost eighteen pesos less than expected."
3. Verified case response: "The rejected new-device request did not authorize access. We have recorded the messages you supplied. Review your signed-in devices and report anything unfamiliar."
4. Sir Rham: "Walk us through the requests. What made them unsafe?"
5. Claim one: "The fee was small, so paying was harmless." Rebut with the independent paid-order status and unexplained payment destination.
6. Claim two: "The code was genuine, so the person asking for it was genuine." Rebut with its new-device purpose and the contradictory cancellation instruction.
7. Claim three: "They knew Amani's delivery, so they must be someone she trusted." Rebut with the public post and copied identity; do not accuse Dan.
8. Claim four: "Their recovery number can verify their warning." Rebut with the independently opened wallet/carrier routes. Final match: the sender says cancel, the alert says authorize, and support confirms the rejected attempt did not grant access. Amani reconstructs six panels (fee → code → copied identity → recovery pressure → independent support → hearing), then narrates the closing argument. Red-herring panels cannot complete the reconstruction.
9. Amani: "The message knew something about me. That didn't mean it was speaking for me."
10. John: "And you checked without handing the check back to the person who sent it."
11. Amani: "Great. Now let's investigate who ordered twenty name tags for a nineteen-person activity."
12. Audience-only masked cutaway: the text operator says, "No code. They've reported the contact." That operator's connection closes; Jobert's light stays dark, leaving two active connections. The Collector: "Then stop texting." This foreshadows Module 3 without making the cutaway evidence available to the students.

**Resolution limits:** support confirms this attempt was blocked; the player has not established the text operator's real identity. Amani is a target of impersonation and an attempted takeover, not blamed for the attacker using her public details. The ending does not clear every possible account or promise that codes alone provide complete protection.

**End actions:** Continue to the appropriate module route when its requirements/content are available; Review evidence; Practice smishing through the existing Lessons flow. Until Module 3 is authored, show its honest availability state rather than opening a placeholder story. Retain any legacy Module 3 progress without silently deleting or rewriting it.

### Approved implementation boundary

1. **Existing chapter screen and phone:** retain `SurveyChapterScreen` and its phone/dialogue/overlay hierarchy. Make protagonist, phone behavior and next-chapter routing come from the chapter definition instead of `John`, chapter number and hard-coded `mod_01` strings. Preserve phone signals (`evidence_changed`, `thought_requested`, `phase_finished`, `chat_speaker_changed`) into the current screen controller; only that controller requests persistence. Extend the current phone components for the SMS comparisons; add chapter-specific content/validation definitions rather than duplicate screen scenes. For Chapter 5, reuse the existing confrontation screen and widgets with per-module content, cast, final contradiction and resolution. The user confirmed on 31 October that **every module's Chapter 5 uses Module 1's full debate format**, rather than a compact phone review. Keep the same controller-owned timing, pause/input guards, evidence signals, credibility rules and save paths. Amani's case challenges requests without inventing an unsupported identity or confession.
2. **Existing account and archive paths:** expand `PlayerManager.story_definition`, unlock/sanitization paths, the existing Deploy selector and Codex projections to the five Module 2 chapter IDs. Keep Module 1 IDs, completed snapshots, legacy stage saves and replay behavior intact. Continue using `SaveService` and `progress_changed`; no second save store or global story manager. Award completion once, keep replays separate and unlock only authored content through the actual module requirements.
3. **Existing learning path:** narrative choices, evidence taps and coached/hinted corrections stay in the story activity/assist record. Any scored transfer checks use fresh existing smishing-bank items through the current practice/first-response contract, without story perks or hints; answer eligibility and duplicate protection must be verified before enabling a mastery update. The results lead to the existing adaptive Lessons flow. No BKT increase merely for clearing a chapter, no new knowledge-component taxonomy and no research assessment change.

### Gate 3B verification and review order

The user approved this script/clue logic and the three integration points. Chapter 1 is the first working slice, including its save/replay/return path. Review the shared integration cost against the remaining schedule before authoring later chapters in code. Continue within Gate 3B after that check; it is not a new milestone or a reason to silently shrink content.

Required local checks: unchanged Module 1 saves and routes; correct protagonist/sender names; no accidental advisor/payout phone selected merely because a Module 2 chapter has the same number; all five investigations reachable; completion/rewards once; account switch isolation; assistance/replay exclusion from mastery; first-response deduplication; partial-chapter reload; Codex discovery boundaries and totals; touch targets and readable layout; background/pause/exit cancellation. Keep developer verification files local and out of commits. Phone acceptance remains deferred by the user, not waived for release.

### Chapter 1 implementation review — 30 October

- Playable: nine opening beats, SMS notification, timed hold/tap inspection, local link expansion with a tap alternative, independent order comparison, persistent green findings, evidence summary and security-code epilogue.
- Reuse: the existing chapter screen, phone shell/signals, account save/replay paths, perk activity record, Deploy selector, Codex and Progress. Chapter definitions select the protagonist, phone and background. Legacy missions remain reachable. Chapters 2–5 are visibly in development and cannot be launched.
- Learning boundary: Chapter 1 is coached story activity. Clearing it, correcting an answer or using a hint does not update BKT. A Module 2-specific graded transfer/practice handoff is still pending; do not describe this slice as completed adaptive-learning integration.
- Local validation passed: story progression, pause/exit timer cancellation, tap alternatives, correction feedback, corrupted-save guards, partial progress, save/reload, isolated replay, once-only rewards, unchanged mastery, discovery-gated Codex evidence, authored chapter totals, legacy-route availability and locked unauthored chapters. Render checks passed at 844×390 and 720×360, including a 48-pixel Continue target. Existing Survey, Advisor, Payout, module-selector and Codex checks passed.
- Remaining acceptance: real phone/safe-area behavior, deployed-account synchronization/isolation for the new chapter, full Module 1 end-to-end regression, refreshed APK and asset-download/offline behavior. The earlier Android APK predates this implementation. Local checks do not close these release gates.
- Schedule review: the first slice required shared routing, portrait cropping, archive discovery and progress-total work as well as content. Those changes can support the remaining chapters, but one chapter is not evidence that the original two-day Module 2 time box is achievable. Keep the five approved chapters; reuse this flow for Chapter 2 next and measure remaining content/verification effort before promising the subsequent module dates. No additional global manager or cinematic framework was added.

### Module 2 generated asset record

Generated with the built-in image-generation tool. Project copies are kept locally under `output/module2-art/` and excluded from Git. Production asset entries use Cloudinary URLs. The transparent portrait sheet uses six equal cells in three columns and two rows; existing character crops remain unchanged.

| Asset | Local output | Hosted production image |
| --- | --- | --- |
| Amani expressions | `output/module2-art/amani_poses_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793339789/levelblue_mod2_amani_poses_v1.png |
| Event room, daytime (revised 31 October) | `output/module2-art/event_workroom_day_v2.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793410992/levelblue_mod2_art_20261031_event_workroom_day_v2.png |

Original prompt set (first artwork pass; revised environments and title prompts are recorded below):

- **Amani:** Fictional Filipino senior-high-school student, 17–18, warm brown skin, brown almond eyes, black low ponytail with loose side strands and a teal hairclip. White short-sleeve uniform blouse, dark green pocket accent, navy waist/lanyard. Six waist-up expressions in an equal 3×2 grid, 1536×1024, genuinely transparent background: neutral, laughing, worried, surprised, thinking with phone, confident with arms folded. Crisp anime visual-novel illustration, warm cel shading and subtle painted texture. Consistent face, clothing and scale; no labels, borders or background.
- **Event room:** Wide 16:9 school club event-preparation room at lunchtime. Cream walls, teal window frames, tropical campus and sunlight to the left, tiled floor, corkboard with blank notes and event layout, kraft paper, name tags, twine, navy/teal bunting, sealed carton on the right table, shelves and a standing fan. Clear center for character overlays and quiet lower area for dialogue. Anime painted background with crisp detail and subtle pixel texture; cream/navy/teal palette and warm daylight. No people, UI or logos.

### Required module introductions — user direction, 30 October

Every module must have its own story introduction, consistent with Module 1's prologue presentation. An authored intro, title reveal, Skip and Replay Intro are part of module acceptance; chapter dialogue alone does not satisfy this requirement. Use the existing navy/cyan/cream design, touch controls, text-speed/reduced-motion settings and pause/exit behavior. Intro playback must not award evidence, credits, chapter completion or BKT mastery. Implement each intro within its module's milestone; do not implement Modules 3–5 ahead of their approved gates.

Before implementation, `module_intro_screen.gd` supported only Module 1 and sent other modules directly to selection. Deploy first-entry routing checked only Module 1. Module 2's secondary action opened legacy missions instead of an intro.

**Module 2 approved prologue — implemented 30 October:**

1. Hallway, later that afternoon. Amani's phone has no cellular signal. A forwarded message is displayed as a simulated card: “It's Amani. New number for today. Club parcel is stuck.” This is a preview of Chapter 3, not new evidence awarded to the player.
2. Amani: “My name. My photo. But I didn't send those messages.”
3. Amani: “My phone had no signal. Everyone else was hearing from someone who looked like me.”
4. Amani: “Before that, I was just waiting for a parcel.”
5. Caption: “Earlier that day…” Transition to the event-preparation room.
6. Caption: “One delivery update.”
7. Caption: “One small fee.”
8. Amani: “I thought the only thing missing was the tape.”
9. Existing-style title reveal: “MODULE 2 / TEXT TRICKS”, with the story subtitle “The Message That Knew”. Continue opens Module 2 chapter selection.

Keep the signal loss and copied identity as observations. Neither the narration nor the title reveal should imply a confirmed SIM swap, account takeover, or culprit identity. Chapter 1 begins at lunchtime after John's hearing; Chapter 3 revisits the hallway incident in full.

**Implementation, using existing nodes and signals:**

- Extend `ModuleIntroScreen`'s existing artwork, message card, narration, caption and title controls with module-specific beat/presentation data. Retain the current advance buttons, tween ownership, notification sound, pause and reduced-motion handling; no new scene manager.
- Route Module 2's first entry through the same intro screen and use `PlayerManager.seen_module_intros` for the viewing flag. Existing chapter saves continue directly to selection and retain an explicit Replay Intro action. Continue returns to the correct module's chapter selector; Back must not mark the intro seen.
- Keep legacy missions as a separate selector action. Verify Module 1 regression, Module 2 first-entry/skip/replay/back, saved seen flags, no learning/reward mutations, touch layout and cancellation on exit before accepting the intro.

Local checks passed for Module 1's existing intro/selector and Module 2's first-entry route, existing-save bypass, serialized viewing flag, approved beats, Skip/Replay, Back without marking seen, Continue returning to Module 2, no rewards/mastery mutations from playback and tween cancellation on exit. The new intro renders at 844×390 and 720×360 with Amani, the hallway, event room, message card and title/subtitle. Replay Intro and legacy access use separate buttons, with wrapping on narrow screens. The navigation fixture preloads the seen flag to avoid writing the user's real guest save; a real-device first-time saved flag and cloud round trip remain release acceptance checks. Modules 3–5 intros remain part of their later module gates.

### Artwork revision — 31 October

The user requested a mysterious final intro image and at least five distinct environments. Generated and hosted six 1672×941 images: Amani mystery title, event workroom, afternoon club corridor, rainy covered courtyard, library research corner and faculty consultation room. The title replaces the room-and-sprite ending; no duplicate portrait overlays the illustration. The intro and Chapter 1 use the revised workroom, and the intro uses the new corridor. The other three environments are available assets; approved chapter locations have not been silently changed to use them.

All six Cloudinary delivery URLs were downloaded, decoded and cached through AssetManager. Intro checks passed with the new artwork at 844×390 and 720×360. PNGs remain ignored, with no new animation manager or local-image dependency in production. The [asset inventory and final prompt set](../output/module2-art/README.md) records local filenames, asset IDs, hosted URLs and intended use. Real-phone acceptance remains pending.


### Chapter 2 implementation review — 31 October

- Playable: **A Code I Didn't Request**, in the same clubroom minutes after Chapter 1. A wallet alert precedes the false cancellation SMS. Amani and John compare the opposing instructions, then the player identifies the code's purpose, marks the contradiction and independently opens the simulated wallet to reject/report the device request. The code is fixed and fictional; no credential input or external submission exists.
- Reuse: existing chapter screen, phone containers/signals, account save and replay records, perks, Codex and Progress. Two chapter-specific scripts hold the authored content and phone activity. Shared Module 2 phone spacing and green success panels now live in the existing base phone. No new manager or save format.
- Routing: Chapter 1's next action opens Module 2 Chapter 2, not Module 1 Chapter 2. Shared evidence handlers use exact chapter IDs for Module 1's custom fields. Chapter 2 returns to Module 2 selection; Chapters 3–5 remain in development. Legacy missions and existing chapter saves remain intact.
- Learning boundary: code-purpose and contradiction choices are coached story activity. Hints/perks remain recorded as assistance; completion/replay does not update mastery or create graded learning events. The planned Module 2 transfer/practice handoff remains pending.
- Local checks: prerequisite gating, notification/message order, all dialogue and investigation phases, wrong-answer correction, paused input, partial save/resume, malformed-save guards, stale-account event rejection, discovered-only Codex records, once-only rewards, isolated replay, unchanged saved mastery and learning events. Mobile render checks use 844×390 and 720×360 with 48-pixel controls and persistent green success feedback. Survey, Advisor, Delivery, chapter-selector and Codex regression checks pass.
- Remaining acceptance: real phone/safe areas, deployed-account synchronization, offline asset behavior and an updated APK. Gate 3B remains active; the next content slice is Chapter 3, **The Familiar Name**.


### Chapter 3 implementation review — 31 October

- Implemented **The Familiar Name** in the afternoon club corridor, reconnecting with Amani's intro. John shows the forwarded new-number payment request; Amani reconnects through school Wi-Fi, compares the copied details and warns classmates through the established club chat. Dan's public reminder is context, not proof of authorship. Signal loss does not establish a SIM swap or device compromise.
- Three activities: match the photo and delivery schedule to the public post; independently inspect the established contact; distinguish observations from assumptions and send the prepared warning through the established club chat. Uses the existing portrait, Cloudinary corridor art, mobile phone controls, success feedback, chapter controller and save/replay paths. Partial matches persist; no external message is sent.
- Chapter 2 now unlocks Chapter 3. Codex records and Progress include the new chapter; Chapter 4 remains unavailable. Shared paired-choice buttons moved into the existing base phone instead of duplicating layout code.
- Local checks passed for full story/activity completion, paused input, partial match restoration, correction without false completion, prerequisite guards, Codex discovery and chapter selection, completion reload, isolated replay, once-only rewards and unchanged saved mastery/learning events. Rendered at 844×390 and 720×360 with 48-pixel choice targets. Chapters 1–2 regression checks passed. Developer verification files and rendered artifacts remain ignored.
- Real-phone, deployed-account sync and updated-APK acceptance remain pending. Gate 3B remains active; next content slice: Chapter 4, **Last Chance**. The graded transfer/practice handoff is still pending; this coached story does not itself update BKT.


### Chapter 4 implementation review — 31 October

- Implemented **Last Chance**, back in the clubroom after classes. The new SMS claims a mobile-account emergency and demands the wallet authorization code through its own recovery contact. Sir Rham advises independent verification. The message's three-minute claim is static story content; reading time never expires the activity or costs rewards.
- Activities: tap events into chronological order, choose support through existing service apps, retain both wallet and carrier responses, and attach the saved messages to simulated wallet case LB-204. The wallet request remains under review; the carrier response establishes no cause for the signal issue. No real call, code entry or external support submission occurs.
- Reuses the existing chapter/phone architecture, paired touch choices, account saves, replay, perk assistance records, Codex, Progress and Cloudinary clubroom art. Chapter 3 unlocks Chapter 4; Chapter 5 remains unavailable. Coached choices do not create graded learning events or update BKT.
- Local checks: full story and activity progression; paused input; wrong-order correction; partial timeline and support-response retention; both-response attachment prerequisite; malformed-save guards; Codex discovery and chapter selection; completion reload; replay separation; once-only credits; unchanged saved mastery/events. Rendered at 844×390 and 720×360 with 48-pixel controls. Chapters 1–3 regressions passed; the Chapter 3 fixture now waits for the seal's actual state rather than a fixed delay. Verification files and artifacts remain ignored.
- Gate 3B remains active. Next: Chapter 5, **Keep the Code**, followed by the still-pending Module 2 transfer/practice handoff and acceptance review. Real-phone, deployed-account sync, offline assets and refreshed APK acceptance remain open.

### Chapter 5 debate implementation review — 31 October

- **Keep the Code** now runs through Module 1's hearing screen: preparation and new exhibits, a four-lead theory choice, the joining cinematic, four moving discussions with orange weak points, terminal-command evidence loading/firing, credibility penalties and hints, Amani's counter cut-in, a final contradiction and six-panel closing argument with narrated text. Optional music, reduced motion, pause and touch controls share the existing implementation.
- The cast is Amani, John, Dan and Sir Rham. The theory asks which request hides the trap; it does not ask students to identify a culprit without attribution evidence. The final match compares cancellation with device authorization. The audience-only ending leaves Jobert and the text operator disconnected, with two connections active. It is not student-accessible evidence.
- Chapter 4 and chapter selection route to the correct hearing definition. Original/replay account records remain separate. Earlier compact-review records are retained, labeled as an earlier review, and can be replayed through the full debate without duplicate credits. The unused compact phone implementation was removed.
- Results offer chapter selection, the existing smishing practice flow, and the correct Codex chapter. Fresh practice responses use the existing BKT first-response policy; repeats do not update it again. Practice does not modify pre-test/checkpoint results, rewards or unlocks. Story completion, corrected attempts, hints and replays do not update mastery.
- Local checks passed for Module 1's existing hearing and Module 2's complete hearing, including save reload, invalid completion, wrong choices, two-error hint, zero-credibility retry, command/counter timing, pause/background/exit, comic placement, rewards and replay. Focused-practice checks passed. Mobile renders checked at 720×360, 844×390 and 932×430; developer checks/screenshots remain excluded from commits.
- Gate 3B is **not device-accepted**. Remaining acceptance: real phone/safe areas, deployed-account synchronization, offline asset behavior and refreshed APK. Modules 3–5 remain later content gates; the shared finale format is recorded, but no future module implementation is included here.

## Gate 3C — Module 3 script and integration review (31 October)

Status: the user approved the detailed script, Liza art brief and intro + Chapter 1 implementation slice. The intro and subsequently authorized Chapters 1–5 are implemented and locally checked. The Chapter 5 implementation review below records the final slice. The five dedicated Module 3 environment backgrounds are now integrated; see the environment review below. Approval of the detailed script does not automatically open later implementation slices. Module 2's outstanding device checks remain release requirements.

### Continuity and learning boundary

Title: **Stay on the Line**. Viewpoint: **Liza**, after Amani's hearing. The school is preparing the same club event. Liza has heard the warning about suspicious texts; the new caller uses that warning to sound protective. The setting moves from the event-briefing classroom to a covered walkway, library corner, rainy courtyard and quiet study room, using five dedicated Module 3 environments. The intro flash-forward and Chapter 3 share the same courtyard. John offers support without taking over Liza's decisions. Eric's earlier call about club expenses is a red herring, never attribution evidence.

The caller claims to work for the fictional wallet's security team. They know Liza's name and event role from a public club post. A genuine **password-reset** code is misrepresented as a way to stop a payment. This distinguishes the call's request from Module 2's new-device authorization. No real credential, phone number, code submission, call recording, microphone access or external call is needed. Caller identity and incident knowledge are claims until independently verified. A calm voice is neither proof of legitimacy nor proof of fraud.

### Module-specific intro

Cold open in the covered courtyard: Liza has one hand over her phone, staring at a security alert. An unidentified caller says, "Stay on the line. If you leave, I can't stop it."

Liza's narration: "I knew what a suspicious message looked like. I wasn't ready for someone who sounded like they were helping."

Cut to a readable phone insert: **PASSWORD RESET REQUESTED**. Do not reveal a real or usable code. Liza: "The voice said stop a payment. The screen said reset my password."

Blackout captions: "A familiar name." / "A patient voice." / "One instruction too far." Then **MODULE 03 / STAY ON THE LINE**, returning to the courtyard earlier that afternoon. This is the same location used when Chapter 3 reaches that moment. No new introductory save flag; reuse the existing per-module seen-intro record.

### Chapter 1 — The Helpful Caller

1. Covered courtyard, after the event briefing. Eric calls about reimbursements. "Keep the receipts. This time, 'trust me' is not an accounting method."
2. Liza: "I have receipts. What I don't have is a stapler that believes in teamwork."
3. After that call ends, another incoming call appears with the displayed label **Account Security**. The label is explicitly unverified.
4. Caller: "Liza? I'm following up on the scam reported by your school. Before anything else, please don't open another message from them."
5. Liza: "That's the first useful thing anyone's told me today. Which service are you with?"
6. Caller claims the wallet security team and offers an incident reference. John notices her pause; he doesn't claim he can identify a caller from their voice.
7. Liza: "They sound prepared. I still need something I can check outside this call."

Investigation: review the received call excerpt; sort **claimed identity / observed fact / independently verified fact**; inspect the displayed caller label and self-supplied reference; choose an independently opened service route as the next check. Correct selections stay green and explain the distinction. Evidence: claimed security role, borrowed incident context, no independent identity confirmation. Eric's earlier call stays contextual, not scored as proof.

### Chapter 2 — They Know My Name

1. A caller excerpt mentions Liza's club role and the event date: "We're protecting the account used for your event expenses."
2. Liza: "They knew the event. I didn't tell them that."
3. John: "Who else could have seen it?"
4. In the library corner, Liza opens the already-published club announcement: her name, role and date are all there.
5. Liza: "So they did their homework. That doesn't make them the teacher."

Investigation: match each caller detail to the public post; separate **knowledge about Liza** from **permission to access her account**; preserve the source comparison. Evidence: publicly available details, caller's unsupported authorization claim, independent source of that information. Do not infer the poster is the caller.

### Chapter 3 — Don't Hang Up

Return to the courtyard moment from the intro. A genuine alert says a password reset was requested. The caller says, "Read me the code and I'll stop the payment. Don't hang up—we'll lose the protection session."

Liza: "You said a payment. This says password reset." Caller: "That's the security procedure. We need to act before the window closes."

Investigation: switch between the saved call statement and alert; highlight **reset password** versus **stop payment**; refuse code sharing and end the call. The end-call action must remain available and must never be penalized. Ending early preserves only received material and the alert; missing explanations are supplied as clearly labeled review guidance, not invented call history. A static caller deadline creates narrative pressure; there is no reading-speed penalty or expiring decision.

Liza: "If hanging up breaks their protection, I'm going to check who that protection belongs to." No code is entered or transmitted. Evidence: alert's actual purpose, contradictory instruction, pressure to prevent independent checking.

### Chapter 4 — Call Back, Safely

A follow-up message claims to be from the caller's supervisor and supplies a callback number. Liza almost treats the second name as a second source.

John: "Where did that number come from?" Liza: "The same conversation I'm trying to verify. Right."

Investigation: choose contact details from the independently opened wallet app; compare the trusted support response with the caller's claim; attach the saved call details and alert to a local simulated incident record. Trusted support states it did not request that call or ask her to share the reset code. It confirms the reset request was not completed and recommends reviewing account activity. The supervisor's name and supplied number remain unverified; no claim that two matching attacker-controlled sources are independent.

### Chapter 5 — The Voice Loses Control

Use the full shared Module 1/2 debate flow. Sir Rham chairs the review with Liza, John and Eric. Preparation introduces the verified incident acknowledgement from the service case, before it can be used as evidence. The opening theory identifies the unsafe request rather than inventing an unsupported real-world culprit.

- Round 1: "A security label and professional voice verify the caller." Counter with the unverified identity claim and independent service response.
- Round 2: "Only someone authorized could know Liza's role." Counter with the public club post.
- Round 3: "The reset code was needed to stop a payment." Counter with the alert's stated purpose and the conflicting call instruction.
- Round 4: "The supervisor's number provides an independent check." Counter with its source in the same suspicious conversation and the separately obtained service contact.
- Final contradiction: freeze the saved phrase "Don't hang up—we'll lose the protection session." Match it against the independently obtained incident response: Liza ended the call without sharing the code, and the reset was not completed. Hanging up did not authorize that reset.
- Closing argument: six panels—helpful call, public details, reset alert, refusal/end call, independent callback, evidence review—with red-herring frames that cannot complete the sequence. Play the reconstructed account through the existing narrated-text animatic.

Credibility, hints, terminal commands, counter timing, pause, assistance records and replay follow the existing shared hearing rules. Eric's expense call is always context rather than a culprit clue. Resolution: the attempted reset was not completed; preserve/report the contact and review unfamiliar activity. Do not claim every account is safe.

Audience-only cutaway: the voice operator says, "She hung up. Used the service's own contact." That connection closes. Jobert and the text operator remain disconnected; one operator remains active. The Collector: "Then give them someone they expect to trust." This leads into Module 4's false coordinator without exposing the cutaway to the student's evidence archive.

Results: chapter selection, discovered evidence, and existing vishing practice. Future story content is honestly labeled unavailable until authored. Coached story responses never update BKT; fresh eligible practice responses use the existing first-response policy and stay separate from research assessments.

### Approved implementation boundary and first slice

1. **Scene reuse:** extend `ModuleIntroScreen` with Liza's beats; use `SurveyChapterScreen` with module-specific definitions and the existing phone/dialogue hierarchy for Chapters 1–4. Embed the existing `DecisionCallPanel` where a live call is needed. First slice: intro plus Chapter 1, with later chapters visibly in development.
2. **Signals and lifecycle:** the call panel emits `end_call_requested`; the current chapter/phone owner saves the received transcript and ended state through existing signals and `PlayerManager`. Only the screen owns progression and timing. Pause, backgrounding, account changes and leaving the screen stop owned cues; ended calls do not restart on rebuild. Resize reuses state rather than resetting the call. No new scene manager or save store.
3. **Shared finale and records:** Chapter 5 supplies Liza's data to `ConfrontationScreen`; extend the existing registry, unlock chain, Codex and Progress projections per completed slice. Keep module IDs, original/replay progress and legacy missions intact. Use the existing focused practice route for `mod_03`.

### Art brief and local acceptance

Liza currently has a placeholder illustration, not an approved production expression sheet. Proposed design: a student with straight shoulder-length dark hair and round glasses, in the established school uniform, distinct from Amani's side-parted hair/teal clip. Match the existing illustrated game style; six readable expressions, plus a mysterious phone-call title image. Use the already approved courtyard/library/clubroom environments where their chronology fits. Final artwork needs review and Cloudinary hosting; generated source PNGs stay out of commits.

First-slice checks: intro skip/replay once; legitimate unlock after Module 2 plus the existing vishing lesson requirement; readable transcript with sound off; no missed-call dead end; early end retained; back/menu/background/resume; 48-pixel touch controls and safe-area layout; partial saves and account isolation; evidence discovery; once-only credits and replay; unchanged mastery/assessment records. Subsequent slices add the code/callback comparisons and the full hearing. Physical-phone/deployed-sync acceptance remains pending until actually performed.


### Gate 3C first-slice review — 1 November 2026

- Implemented **Stay on the Line** intro and **The Helpful Caller**, using the existing intro/chapter screens, phone shell, call panel, save/replay owner and assistance ledger. Only two new production scripts separate the chapter data from its phone interactions; no new save or scene manager.
- Liza's six poses and the mystery title image use Cloudinary. AssetManager download/cache checks passed; local PNGs and developer verification files remain ignored. [Asset inventory and generation prompts](../output/module3-art/README.md).
- Chapter 1: receive or decline an unexpected call, end at any received excerpt, classify claim/observation/unverified identity, and select an independently opened wallet Support route. Ending or declining is never a mistake. Saved notes contain only received statements. No microphone, external phone call or real code entry is used.
- Call end and excerpt signals persist through the existing chapter owner. Reload, resize and asset refresh do not restart an ended call. Phone Continue advances one dialogue page without dropping unread thoughts.
- Deploy exposes the intro and Chapter 1 after Module 2 completion plus the first Phone Tricks lesson. Chapters 2–5 cannot launch; legacy Module 3 missions remain accessible. Codex reveals three observations from earned findings; Progress counts eleven authored chapters across Modules 1–3.
- Coached choices and hints remain outside mastery updates and independent assessments. Hint use is recorded; original completion grants credits once and replays grant none. This slice does not claim a completed Module 3 adaptive-practice handoff.
- Local checks: Godot import; call decline, full listen and early end; pause guards; partial save/reload; account-owner rejection; evidence discovery; once-only reward and replay; unchanged mastery/events; intro skip/replay/navigation; 48-pixel touch controls; 720×360 and 844×390 render inspection. Shared call-panel and Module 1/2 hearing assertions passed. The older hearing harnesses still emit resource-in-use warnings at shutdown; those warnings are not a clean lifecycle acceptance result.
- Physical-phone/safe-area, updated APK, hosted account-sync and offline-first installation acceptance remain open. Local viewport checks do not substitute for device testing.
- Next proposed slice, awaiting the user's go-ahead: **Chapter 2 — They Know My Name**, matching caller details to the public club post while preserving the caller's unknown identity.


### Gate 3C Chapter 2 review — 1 November 2026

The user authorized the next slice after the Chapter 1 review. **They Know My Name** now follows the completed first chapter through the existing Next Chapter route and Deploy selector. The existing library research corner gives the comparison a different setting without another asset or manager.

Continuity: the excerpt is a **new voicemail after the earlier call ended**, not retroactively added dialogue. This works whether the player declined Chapter 1's call, ended early or heard everything. Chapter 1's saved received-statement count remains unchanged. Liza independently opens the public club page she already follows; the post existed before the call.

The three activities are:
1. Tap a caller detail, then the matching public-post field (name, event expense role and 6 November date). Correct pairs stay green, are disabled against duplicate input, and survive partial save/reload. Tapping a destination before selecting a detail gives guidance without a penalty.
2. Distinguish public knowledge from a verified security role or permission to access the wallet.
3. Preserve the voicemail and post with the supported conclusion: the details **could** be copied from a public source. The comparison neither identifies the caller nor proves which source they used; it does not implicate the post's author.

Integration reuses the current chapter/save/replay, perk-assistance, phone, Codex and Progress paths. The two new scripts contain chapter data and phone-specific presentation; no new persistence or learning infrastructure. Chapter 3 stays unavailable until implemented. Progress now counts twelve authored chapters. Guided corrections/hints/replay do not create mastery updates or research scores, and completion grants credits only once.

Validation: partial-match saves, malformed prerequisites, pause, account-owner guards, no rewriting prior call notes, discovery-gated Codex records, once-only rewards and replay passed. Render checks at 844×390 and 720×360 covered 48-pixel touch choices, readable source comparison and visible green confirmation. A shared phone resize callback was found to run after removal from the scene tree; `_metrics()` now returns immediately when detached. Chapter 1, Module 3 intro/navigation and shared advisor-phone regression checks were run. Developer checks remain local/ignored, with no staging or commits performed by the agent.

Physical-device, installed-APK, hosted-sync and offline-first acceptance remain outstanding. Next proposed slice, awaiting confirmation: **Chapter 3 — Don't Hang Up**, returning to the courtyard moment from the intro.


### Gate 3C Chapter 3 review — 1 November 2026

The user authorized continuation after Chapter 2. **Don't Hang Up** returns Liza to the covered courtyard from the intro. This is a new incoming call after the voicemail/public-post comparison, so earlier decline/end choices are preserved. The wallet alert explicitly describes a password reset, while the caller claims the code will stop a payment.

- Existing chapter screen, phone shell and call panel are reused. Two production scripts separate chapter data from phone-specific interactions; there is no new manager, save store, timer or external calling integration.
- The player can answer, decline, switch to the wallet alert, challenge the purpose mismatch, or end immediately. End/Decline stays in the fixed phone footer even while scrolling the alert. Safe exits carry no mistake or speed penalty. The caller's deadline is dialogue only. No actual code is displayed, entered or transmitted.
- The live call ends before the coached review. This leaves no connected call hidden behind dialogue. Activities identify the reset purpose, highlight the conflicting actions across two sources, and choose to keep the code private and verify through the existing wallet app. Correct findings receive the shared green confirmation.
- Save/reload retains alert reading, ended state and the exact received-statement count. Declined calls have no transcript. Missing statements appear only as explicitly labeled review guidance, including in Codex; they are never presented as received evidence. Post-call dialogue also works after a decline.
- The existing registry, Chapter 2 Next action, Deploy labels, save/replay cleaner, assistance policy, Codex and Progress now include Chapter 3. Thirteen chapters are authored across Modules 1–3. Chapters 4–5 of Module 3 remain in development. Legacy missions and prior chapter saves remain intact.
- Guided corrections and hints do not submit mastery observations or research scores. Assistance remains recorded, original completion awards credits once, and replay awards none. The service's independent response and reset outcome belong to Chapter 4; this chapter does not invent them.

Local checks cover decline, early end, full optional exchange, pause, fixed exit during scrolling, partial save/reload, prerequisite cleaning, account-owner guards, source-aware Codex discovery, once-only credits, replay restoration and unchanged mastery/learning events. Mobile viewport checks use 844×390 and 720×360 with 48-pixel touch controls. Chapter 2 regression includes the new Chapter 3 unlock. Module 3 intro/selector assertions also pass, including keeping Chapter 4 unavailable; that older harness still reports four ObjectDB instances and two resources in use at shutdown, so it is not a clean lifecycle acceptance result. Its local harness now waits for the seal animation's completion state instead of relying on a short wall-clock delay. Developer checks and render artifacts stay local/ignored; no files were staged or committed.

Physical-device safe areas, installed APK, hosted sync and offline-first acceptance remain open. Next slice, awaiting the user's go-ahead: **Chapter 4 — Call Back, Safely**, independently verifying the supplied supervisor contact and attaching the preserved alert/call details to the service case.


### Visual completion requirement — confirmed 1 November 2026

Every module needs **at least five distinct, newly created environment backgrounds tied to its story**, in the established visual style. Reused environments may support continuity but do not count toward the module's five new backgrounds. Portrait sheets, chapter thumbnails, title cards and evidence interfaces do not count as environment backgrounds. Preserve spatial/time continuity, especially the Module 3 intro's courtyard moment revisited in Chapter 3. Asset hosting/caching follows the existing Cloudinary pipeline; source PNGs and generated validation artifacts stay out of commits.

Module 3 now has five dedicated environment backgrounds, separate from its portrait sheet and mystery title. All five are hosted and used in the intro/Chapters 1–4; this closes the background inventory requirement, not the unfinished Chapter 5 or physical-device acceptance. Audit the existing Module 1/2 inventories against this requirement without automatically replacing suitable authored art; carry the same requirement into Modules 4/5 when those gates open.

### Gate 3C Chapter 4 gameplay review — 1 November 2026

The user authorized **Call Back, Safely** after Chapter 3. A follow-up message claims to come from a supervisor and supplies its own callback contact. John asks where the contact came from; Liza recognizes that two names in the same suspicious conversation do not make two independent sources.

The existing chapter screen, phone shell, saves/replays, assistance ledger, Codex and Progress are reused. Two production scripts separate the authored chapter from its phone interactions; no additional scene manager, persistence system, real calling or reporting service was introduced.

1. **Independent contact:** choose the existing wallet app, navigate to Support / Contact us, then select that independently obtained contact. The supplied message number gives correction instead of triggering a real call.
2. **Support comparison:** read the service response before interpreting it. Support says it did not request the call or ask for the reset code; this reset was not completed, and account activity should be reviewed. Neither the supervisor's identity nor the safety of every account is established.
3. **Incident record:** review and attach the original Chapter 3 alert and received call notes. Declined calls remain transcript-free; early hang-up includes only the first received statement. Later alternate replays cannot rewrite the original incident. Partial attachments survive save/reload, turn green and remain reviewable. No code is attached or transmitted; the report stays inside the game.

Chapter 3's Next action and Deploy unlock Chapter 4. Codex discoveries remain gated by completed activities, Progress counts fourteen authored chapters, and Chapter 5 remains visibly unavailable. Guided corrections/hints stay separate from BKT mastery updates and research assessment scores. Hint use is recorded; original completion awards credits once and replays award none.

Validation passed: notification/story progression, independent-route prerequisites, response-reading gate, corrected interpretations, partial report recovery, account-owner rejection, pause guards, source-faithful attachments for declined/short/full calls, replay isolation, once-only credits, unchanged mastery/events and Chapter 4/5 selector availability. Godot previews at 844×390 and 720×360 verified readable text, green attachment feedback, visible Continue and 48-pixel touch controls. Chapter 3 regression passed with the new Chapter 4 unlock. Local tests/artifacts remain ignored; nothing was staged or committed.

At the Chapter 4 gameplay review, backgrounds and physical-device acceptance were open. The environment pass below closes the five-background inventory requirement; physical-device safe areas, installed APK, hosted account sync and offline-first acceptance remain open. This review closes the Chapter 4 gameplay slice, not the whole Module 3 gate. The next gameplay slice is **Chapter 5 — The Voice Loses Control**, using the full shared debate format. Its briefing and final comparison must respect declined/shortened call histories: an unheard phrase cannot be presented as a saved quote. No Chapter 5 implementation has begun.


### Gate 3C environment integration review — 3 November 2026

Five newly generated Module 3 environments are hosted and integrated: event-briefing classroom, covered walkway, library research corner, rainy courtyard and quiet study room. Scene captions establish the moves between locations. The intro flash-forward and Chapter 3 use the same courtyard; Chapter 4 starts there before moving indoors for independent Support verification. Chapter selection previews use the corresponding environments. Existing screens, phone panels and AssetManager caching are reused; no additional scene manager or save system was added.

All five hosted images downloaded and decoded successfully through AssetManager. Local verification passed for every Chapter 1–4 story background assignment and the intro location sequence. Godot previews at 844×390 and 720×360 were visually inspected with character/dialogue/phone overlays. Exact generation prompts, local file names, hosted URLs and placements are recorded in `output/module3-art/README.md`. PNGs and developer checks remain excluded from commits.

This closes the five-background inventory/integration requirement. Chapter 5, physical-device safe areas, installed release, hosted account sync and offline-first acceptance remain open. The next gameplay slice is Chapter 5 — The Voice Loses Control, using the shared debate format and source-faithful evidence.


### Gate 3C Chapter 5 implementation review — 3 November 2026

The user approved **The Voice Loses Control** after the environment pass. This completes Module 3's local story implementation, not physical-device/deployment acceptance.

- Reuses the shared hearing scene and widgets: preparation/new exhibits, theory selection, joining cinematic, four claim/evidence-command rounds, credibility and hints, Liza counter effects, final comparison, six-panel closing reconstruction, narrated-text animatic, aftermath and four-connection cutaway. One chapter-definition script supplies the module content; no new scene manager or persistence system.
- Sir Rham chairs with Liza, John and Eric. Claims concern caller identity, public details, reset purpose and independent contact. They are explanatory arguments, not accusations against classmates. Eric's expense call stays a red herring. The independently obtained incident acknowledgement is introduced in preparation before it can be used.
- Original Chapter 3 call history determines transcript content. A declined call has no received statements; the final pressure phrase and payment comparison are clearly marked review examples. An early hang-up includes only the received first statement. Alternate replay histories cannot rewrite original evidence. The evidence drawer, briefing and final comparison use the same read-only context.
- Chapter 4's Next action and Deploy unlock the hearing. Saves keep original and replay attempts separate; malformed completion is rejected; credits are awarded once. Codex exposes five findings only after their corresponding rebuttals/final match and excludes the audience-only cutaway. Progress now counts fifteen authored chapters. The result offers Chapter Select, Review Evidence and the existing vishing practice route. Module 4 remains labeled in development.
- The voice operator disconnects in the audience-only ending. Jobert and the text operator remain disconnected, leaving one connection. This does not expose a real-world culprit identity to Liza's evidence archive.

Validation passed: complete hearing, wrong theory/no bonus, correct theory bonus, wrong evidence penalties, two-error hint, zero-credibility round retry, duplicate input protection, terminal state timings, counter pause, background/exit cancellation, account-owner rejection, reconstruction save/reload, replay isolation, once-only rewards, source-faithful declined/short/full call records, and hidden/unlocked Codex findings. Mobile renders inspected at 720×360, 844×390 and 932×430; compact theory labels keep all four touch choices visible. Module 1 and Module 2 hearing regressions passed. The older Module 2 verification needed to stop/drain audio before process exit; after local harness cleanup it passed without shutdown warnings. Chapter 4-to-5 handoff and fifteen-chapter Progress checks passed.

Vishing-focused practice verification passed: fresh eligible answers change BKT mastery, duplicate answers do not update it twice, and assessment scores, lesson unlocks and coins remain unchanged. Coached hearing choices, hints, perks and replay do not emit graded BKT observations. No fitting or learning-gain claim is made by these checks.

Developer checks, UID sidecars and screenshots remain ignored; nothing was staged or committed. Physical phones, installed APK, hosted account synchronization and offline-first acceptance remain open. Next scope for approval: Gate 3D / Module 4 detailed script and first slice; do not begin it automatically.


### Per-module visual variety requirement — 3 November 2026

The user confirmed that each module must have new images and distinct effect treatment, not merely different dialogue over the same presentation. The UI palette, controls and shared debate mechanics remain consistent. Existing animation states and widgets should deliver story-specific visual motifs, transitions and counter treatments; no separate effects system is required.

Module 3 has five dedicated backgrounds, Liza artwork and a dedicated mystery title. Its distinct signal-wave hearing treatment is implemented in the review below. Final visual acceptance and physical-device checks remain open despite completed local gameplay checks; do not silently begin Module 4 art or code. Later modules must include their imagery/effect plan in their approved implementation slices.

### Gate 3C signal-wave presentation review — 3 November 2026

The user approved Module 3 effects in the existing hearing widgets/controller. Liza now has a newly generated, lettered COUNTER! illustration hosted on Cloudinary, referenced through AssetManager and fitted fully inside mobile viewports. The joining sequence shows a cyan audio signal, the title reveals THE VOICE / LOSES CONTROL, the terminal identifies Liza and verifies voice evidence, and the rebuttal collapses the signal before revealing her artwork. Navy/cyan/cream colors and the touch controls remain consistent.

The shared controller still owns timing, audio cues, pause/resume and teardown. Existing command duration/easing/sound parameters remain in use. No effects manager, save system or gameplay scoring changes were added. Module 1/2 use their existing presentation by default. Missing cached art retains the existing character-based counter fallback; first acquisition still requires network access.

Module 3's complete hearing and hosted download/cache decode passed. Mobile renders were checked at 720×360, 844×390 and 932×430, including the terminal and uncropped counter lettering. Reduced-motion title/counter frames remained identical within their states. Command cue sequencing, pause/backgrounding, exit cancellation, once-only credit awards, original/replay evidence separation and unchanged BKT observations passed. Source PNGs, developer checks and captures remain ignored, and nothing is staged or committed.

Module 1 and Module 2 hearing regressions also passed after the effects changes. Module 1's local harness now stops and drains audio before shutdown, matching the existing Module 2 cleanup; the rerun exited without resource warnings. This is local verification maintenance, not a new production audio system. That older harness is already tracked, so its edit must be explicitly excluded from any future staging; ignore rules alone cannot protect it. Nothing is staged.

This closes the approved local effect implementation. Final user visual review, physical-device performance/safe areas, installed APK, account synchronization and offline-first release acceptance remain pending. Module 4 has not started. Asset paths, exact prompt and hosted URL are recorded in `output/module3-art/README.md`.

### Gate 3D detailed script and first-slice proposal — 3 November 2026

The user approved moving to Module 4's detailed script and first implementation slice, then explicitly approved the script, art brief and first slice below on 3 November 2026. The implementation review follows this specification. Earlier Module 3 physical-device/release checks remain open.

**Learning purpose:** identify a plausible pretext, separate claimed identity from verified authority, and verify the request through an independently chosen school contact. Use the existing `pretexting` component and practice bank. Coached story corrections and perks stay in the assistance ledger, never research assessment scores or graded BKT observations.

**Continuity:** the next school day after Liza's hearing. Sir Rham is helping the club recover from the earlier incidents. The adversary offers institutional help rather than another student reward. All gameplay remains on a phone; a scene containing office furniture does not introduce a desktop computer interface. The coordinator uses the displayed role **Incident Response Coordinator**, with no invented real person's name or portrait. The final active connection belongs to the Collector only in the audience's cutaway; the school cannot infer the operator's real identity from this alone.

#### Intro — The Perfect Credential

Flash-forward: late afternoon in the small faculty consultation room. Sir Rham's phone shows an unfulfilled request: “Send the club contact list here. Emergency clearance is already approved.” No names, numbers or real student records are displayed.

1. Sir Rham: “They said the list would keep my students safe.”
2. Sir Rham: “The logo was familiar. The appointment looked official.”
3. Sir Rham: “But who had actually approved this?”
4. Caption: “Earlier that morning…”
5. Caption: “One appointment. One helpful stranger.”
6. Sir Rham: “I was ready to help. I still needed to know who I was helping.”
7. Title: **FAKE STORIES / THE PERFECT CREDENTIAL**.

The consultation room, late-afternoon lighting and request wording return in Chapter 3. Viewing/skipping/replaying the intro uses existing intro-seen state and grants no chapter progress.

#### Chapter 1 — Here to Help: implementation script

Location: faculty workroom, morning. Sir Rham has his phone beside a cold cup of coffee and club folders. John appears briefly at the doorway; he does not authenticate the coordinator or make the decision for Sir Rham.

1. Sir Rham, tired smile: “I finally made coffee. Naturally, the paperwork arrived first.”
2. John, relaxed: “At least nobody promised to pay you for drinking it.”
3. Sir Rham, amused: “Progress. We're learning.”
4. Phone notification: **NEW APPOINTMENT / School incident follow-up**. Reuse the notification cue; tap opens the message before the dialogue continues.
5. Message: “Good morning, Sir Rham. I am the incident-response coordinator assigned to your club's case. Your 10:30 consultation has been approved. Please acknowledge so I can prepare the protective follow-up.” Its attached appointment card repeats the role, school branding, 10:30 time and “Appointment confirmed.”
6. Sir Rham, interested: “They know about the club incidents. A follow-up would make sense.”
7. John, thoughtful: “Did the office arrange it, or does the message say the office arranged it?”
8. Sir Rham, focused: “Fair question. I'll check the schedule I already use.”
9. Existing school schedule, opened through a separately labeled trusted school shortcut: **TODAY / 10:30 — Club event logistics / internal staff only. No external coordinator recorded.**
10. Sir Rham, cautious: “Same time. Different purpose. This could be an update I haven't received. It still isn't confirmation.”
11. John: “So the appointment is a claim to check.”
12. Sir Rham, resolved: “Exactly. Helpful is a description. Authorized is something we verify.”

Investigation inside the shared cream phone panel, with fixed visible Continue controls and scrollable evidence:

1. **Claim or observation:** tap each card and classify it. “A coordinator contacted me” becomes “Someone claiming that role contacted me”; “The message displays school branding” is observable; “The school approved this coordinator” remains unverified. Wrong answers explain the distinction and remain retryable. No countdown or reaction penalty.
2. **Compare the appointment:** inspect both the supplied appointment and independently opened schedule. Tap the purpose/visitor mismatch. The matching time is not a contradiction. Saving the finding requires reading both sources and identifying the actual mismatch, with green highlighting and a short explanation.
3. **Choose the next check:** choose the office contact from the existing school directory. Distractors: use the sender's “verification” contact, or confirm from the logo alone. This chapter records the independent route; it does not invent an office response before Chapter 4.

Chapter 1 evidence: displayed role/branding are unverified claims; the independently opened schedule does not confirm the proposed external appointment; the existing directory supplies a verification route. Close: “I haven't confirmed the appointment. I haven't shared a list. First, I need to understand exactly what they're asking for.” Award once through existing completion logic; replay awards none. Until Chapter 2 is implemented, return to Chapter Select with Chapter 2 visibly in development rather than a broken Next button.

#### Chapter 2 — A Consistent Story: scripted evidence chain

Location: bright administration reception alcove, late morning, waiting to ask the office about the schedule. The coordinator sends a profile card, email and meeting invitation; all were supplied in the same unverified conversation. The request expands to the club's student names, sections and contact numbers “to contact everyone safely.”

- Sir Rham: “Three matching documents. That looks reassuring.”
- John: “Three documents—or one person telling the same story three times?”
- Sir Rham: “Consistency is useful. Independence is the missing part.”
- A real office scheduling update clarifies that the original internal meeting moved to 11:00. This explains a mundane schedule change; it does not appoint the unknown coordinator or make the staff member a suspect.

Interactions: compare repeated claims, group records by who supplied them, distinguish consistency from independent confirmation, preserve the actual data request. Do not imply that common branding proves forgery. Evidence: all three supplied records share an unverified source; the data request exceeds a simple appointment acknowledgement; scheduling confusion is not culprit evidence.

#### Chapter 3 — The Exception: scripted evidence chain

Location/time: the same faculty consultation room and late-afternoon lighting as the intro. The coordinator pressures Sir Rham to send the contact list by private message, claiming an emergency exception. The roster is represented by a sealed generic card, never real student data.

- Coordinator: “Send the club contact list here. Emergency clearance is already approved.”
- Sir Rham: “Approved by whom, and for which information?”
- Coordinator: “Please don't delay protection with routine paperwork.”
- Sir Rham: “An urgent reason to help isn't permission to disclose.”

Interactions: compare the requested fields/channel with the fictional school's in-game authorization notice; identify the missing documented approval; choose the established office route instead of sending a partial list or switching to the supplied private contact. The notice is school-story evidence, not a claim about universal school policy or legal requirements. Evidence: roster request, unverified exception claim, missing independent authorization. No student list is sent on either a correct or corrected learning path.

#### Chapter 4 — Ask the Real Office: scripted evidence chain

Location: records-office consultation counter, late afternoon. Sir Rham uses the previously selected school directory route. The real office confirms: “We have not assigned an external coordinator to this club case. We did not approve this request for student contacts. Keep the original messages for review.”

- Sir Rham: “Please confirm both the appointment and the request. A real role would still need the right permission.”
- Verified response: no assignment and no approval for this request; the internal event meeting was separate.
- Sir Rham: “Now I have an independent answer. I'll preserve what arrived and keep the list restricted.”

Interactions: verify the response's independent route, match each conclusion to its supporting statement, assemble a report containing the supplied appointment/request and verified denial. Preserve provenance and original/replay separation. The office denial confirms the false assignment in this case, not a real-world culprit identity or the safety of every school system.

#### Chapter 5 — The Mask Holds: full shared hearing specification

Location: school briefing room at early evening, with the hearing attended on phones. Cast: Sir Rham, John, Liza and Mika. Sir Rham presents his incident; peers voice plausible explanations so the player can challenge claims without accusing them of participating in the scam.

- Preparation: review already collected records, introduce the office's incident acknowledgement, equip existing permitted story perks, then choose which assumption made the request look trustworthy. Correct theory: “Matching records prove authority.” Keep the shared bonus/three-mistake rules.
- Cinematic: existing joining states, participant arrival and title reveal with Module 4's document/verification motif. No new scene manager.
- Round 1: “It matched the school's schedule.” Rebuttal: supplied appointment versus independent schedule and the clarified internal meeting. Same time does not confirm the external coordinator.
- Round 2: “The profile, email and invite all agree.” Rebuttal: source map showing the same unverified supplier. Repetition is not independent corroboration.
- Round 3: “An emergency exception authorized the list.” Rebuttal: actual private-channel request versus the school's displayed approval notice. The request has no independently confirmed authorization.
- Round 4: “You never proved the school hadn't assigned them.” Rebuttal: the independently contacted office's explicit denial. The schedule discrepancy alone would have been insufficient.
- Each round keeps the shared correct/incorrect credibility changes, hints, restart protection and evidence-command targeting. At least one irrelevant exhibit remains in each evidence pile, including the harmless scheduling correction where appropriate.
- Final comparison: “Already approved” against the verified “No assignment / no approval” response. No typo or branding-only attribution shortcut.
- Closing reconstruction: contact → claimed appointment → matching supplied documents → expanded private roster request → independent office check → preserve/report without disclosure. Include decoy frames, tap placement and the existing narrated-text animatic.
- Outcome: the school restricts the fraudulent contact and shares verified guidance. The acknowledgement says the request was reported and no roster was disclosed; it does not promise a completed investigation.
- Audience-only cutaway: three inactive connections and the Collector still active. “They won't give us the list. Then let them ask for the file.” Mika receives an event-asset offer leading to Module 5. No new light goes out, and this cutaway is excluded from the learner's case evidence.

#### Art and effect acceptance plan

Preserve Sir Rham's user-provided reference: dark cap, round glasses, dark hair extending near the nape, warm complexion, broad smile, tan textured shirt and black wristwatch. Produce a six-expression sheet with readable neutral/amused/concerned/skeptical/checking/resolved poses; expressions must match dialogue. Do not invent a face for the unverified coordinator.

Five distinct new environments are required across this module:

| New environment | Story use | First slice? |
| --- | --- | --- |
| Faculty workroom, morning | Chapter 1, earlier-morning intro beat and preview | Yes |
| Administration reception alcove, late morning | Chapter 2 comparisons and preview | Later Chapter 2 slice |
| Small faculty consultation room, late afternoon | Intro flash-forward and Chapter 3 private-channel pressure | Yes, for intro continuity |
| Records-office consultation counter, late afternoon | Chapter 4 independent office verification | Later Chapter 4 slice |
| School briefing room, early evening | Chapter 5 preparation/hearing/reconstruction | Later Chapter 5 slice |

First-slice art also includes a dedicated mystery title image: a faceless, backlit figure beyond frosted office glass, an unreadable credential shape and layered paperwork; restrained cyan/navy with warm cream light. Render title lettering in the existing UI, not baked into evidence art. No real logo, personal data or legible invented credentials. Later slices include their own investigation compositions/previews and Sir Rham's counter illustration. Merely using five backgrounds does not close visual acceptance.

Effect motif: document alignment, separated source layers and verified-source borders. Reuse current reveal/phone/highlight states; no flashing strobes, color-theme replacement or new effects manager. First slice uses a restrained title alignment reveal, notification cue and green evidence confirmation; reduced motion presents static frames. Full hearing effects are implemented only with Chapter 5.

#### First implementation slice: nodes, signals and exit checks

1. Extend existing ModuleIntroScreen and ModuleStageScreen for index 3; route to the existing SurveyChapterScreen. Add only a Chapter 1 definition and its phone activity subclass to separate authored state from interaction rendering. Preserve earlier intro routing, legacy stage access and saved progress.
2. The phone subclass emits existing evidence_changed / thought_requested / phase_finished signals. SurveyChapterScreen owns progression, pause and saves; PlayerManager owns unlocks and original/replay records. Add Sir Rham to the existing portrait path with one consistent speaker key; do not create a separate actor manager.
3. Reuse AssetManager/Cloudinary for new art and current Codex discovery/progress refreshes. Chapter 1 unlock requires Module 3's hearing and the existing Module 4 lesson gate. Chapter 2–5 remain unavailable until their slices are implemented. Extend the existing mobile layout only as needed for touch readability.

Acceptance for the first slice: intro replay/skip/pause/exit; notification → open message → all three activities → completion; wrong-answer correction; source prerequisites; green success feedback; malformed-save repair; partial save/resume; original/replay and account-owner isolation; once-only rewards; no graded mastery events from coaching; sixteen authored chapters reflected in Progress; Codex findings revealed only after discovery; hosted asset cache decode and missing-asset fallback; visible actions at 720×360, 844×390 and 932×430. Keep developer tests/source PNGs out of commits. Physical phone and deployment checks remain separate release requirements.

### Gate 3D first-slice implementation review — 3 November 2026

**Locally implemented and verified:** Module 4's dedicated intro and Chapter 1, **Here to Help**. Chapters 2–5 remain visibly in development. The detailed five-chapter script above is approved, but this review does not authorize implementing every remaining chapter at once.

- Reuses the intro/chapter/phone screens, AssetManager, PlayerManager, assistance ledger, Codex and Progress. Only the Chapter 1 definition and phone interaction subclass were added as production scripts. Sir Rham's display name and portrait key remain consistent; earlier protagonists retain their existing paths.
- Intro flashes forward to the late-afternoon consultation room, then returns to the morning workroom. The credential-themed title uses the existing reveal tween with restrained source-line alignment. Normal-motion timing, reduced motion, pause/resume, skip and teardown use existing owners.
- Chapter 1 begins with a notification before opening the supplied appointment. Activities distinguish claims from observations, require both source records before saving the purpose/visitor mismatch, and require opening the existing school directory before choosing its office contact. Correct findings turn green and remain reviewable. The schedule mismatch alone is not called proof of fraud; no office response or roster disclosure is invented.
- Unlock requires the completed Module 3 hearing and the existing Module 4 lesson prerequisite. Explicit `mod_04_ch_02` routing prevents the older shared default from pointing back to Module 1. With Chapter 2 unavailable, completion offers Chapter Select. Legacy missions/saved progress remain accessible. Progress now counts sixteen authored chapters, and Codex reveals three findings as they are earned.
- Four new images are hosted and integrated: Sir Rham's six-expression sheet based on the user's reference, faculty workroom, consultation room and mystery title. The portrait's transparency and all four hosted cache decodes passed. See `output/module4-art/README.md` for exact prompts, local paths and versioned URLs. **Only two of the five required environment backgrounds are complete.** Later investigation/preview/counter artwork and hearing effects remain tracked in the art plan.

Validation passed: full story → notification → investigation → seal → epilogue → results, source-read gates, wrong-answer correction, partial source save/load, malformed-save repair, account-owner rejection, paused input, once-only original rewards and reward-free replay, unchanged BKT mastery/events, hidden/unlocked Codex findings, and Chapter 2 unavailability. Godot previews were inspected at 720×360, 844×390 and 932×430; success feedback was moved above comparison review buttons so it remains visible on the smallest tested layout. Module 4 intro normal-motion pause/resume, skip cancellation and owned-tween cleanup passed.

Shared regressions passed for Module Select, Module 3 intro and Module 3's public-source comparison chapter. Two local assertions were stale: Module 3 Chapter 5 was still expected to be unimplemented, and Progress was still expected to contain fourteen chapters. Those expectations were updated to the implemented hearing/prerequisite gate and sixteen chapters. The intro test now drains audio before shutdown. These are developer checks, not product assessment changes, and remain excluded from staging.

Repository note: commits were made externally during implementation, including the four generated PNGs. Only those four hosted source images were explicitly removed from the current index; local copies remain and the root `.gitignore` now covers Module 4 PNGs. Prior commit history was preserved. Do not claim historical copies were removed. No commit was created by this implementation run.

Remaining acceptance: user visual review, physical phone safe areas/performance, installed build, hosted account sync and first-download/offline behavior. Missing cached artwork does not add a new dependency or save system; the existing AssetManager acquisition/fallback behavior remains a device-release check. Next implementation slice, after explicit confirmation: **Module 4 Chapter 2 — A Consistent Story**, including its new administration-reception environment and source-comparison presentation. No Module 5 implementation has been started by this slice.

### Gate 3D Chapter 2 implementation review — 4 November 2026

The user's continuation advances the approved script to **A Consistent Story**. Chapter 2 is locally implemented and verified; Chapters 3–5 remain in development. The preceding first-slice review is historical: Chapter 1 now offers Next Chapter, and Progress counts seventeen authored chapters.

- Reuses the chapter screen, phone containers, progression owner, assistance ledger, AssetManager and Codex. Adds only the chapter definition and its phone activity subclass; no new save or effects manager.
- Late-morning reception story follows the directory choice in Chapter 1. The new notification must be opened before the attached records can be preserved. Players open and classify each supplied profile/email/invitation, inspect the request for names/sections/contact numbers, and independently open the usual school notice before preserving its limited significance. Correct findings turn green. The notice corrects an internal meeting to 11:00; it does not authenticate the coordinator, authorize disclosure or implicate its staff author. No student contacts are transmitted and no office denial is invented ahead of Chapter 4.
- Prerequisites, partial reads/classifications, corrected answers, completed saves, separate replay, once-only rewards and three discovery-gated Codex entries use existing state owners. Coached activities do not update BKT mastery or research assessment events. Corrected the Chapter 1 perk phase policy, which accidentally included it in the finale-only phase override; both ordinary chapters now permit their own story phases and deny assessment contexts.
- Generated and hosted a dedicated reception environment, used for the story, investigation and chapter preview. Module 4 now has **3/5 required environments**. Exact prompt and versioned URL are recorded in `output/module4-art/README.md`. The new PNG and developer checks remain ignored; the four earlier staged PNG removals are preserved. No commit was made.

Validation passed: full story → notification → source classification → request → independent notice → seal → epilogue → results; incorrect-answer correction; prerequisite gates; pause and stale-account guards; partial and completed save/load; malformed-save repair; original reward once and reward-free replay; discovery gating; unchanged mastery/events. Chapter 1's full regression, intro lifecycle checks and handoff to Chapter 2 also passed. Godot renders were inspected at 720×360, 844×390 and 932×430. On the smallest layout the source choices are reachable by scrolling, retain at least 44-pixel height, and Continue stays inside the phone. The new selector preview was inspected at 720×360.

Physical-device safe areas/performance, installed-build behavior, hosted account synchronization and first-download/offline acceptance remain open. Next implementation slice, after explicit confirmation: **Chapter 3 — The Exception**, returning to the same consultation room and late-afternoon lighting shown in the intro. No later chapter was implemented in this slice.

### Gate 3D Chapter 3 implementation review — 4 November 2026

The user approved the next slice: **The Exception** is now locally implemented and verified. It returns to the consultation room in the intro at late afternoon and repeats the emergency-clearance wording shown there. Chapter 2 now offers Next Chapter. Chapters 4–5 remain in development; Progress counts eighteen authored chapters.

- Uses the existing chapter screen, phone controls, signals, account/save ownership and replay handling. Two production scripts separate authored chapter state from its phone interaction, following the existing chapter architecture. No new manager, network contact or student-data collection form was added.
- After the notification and preserved request, players review both the actual request and the independently opened school authorization notice. They identify student contact fields and the unconfirmed private channel, distinguish claimed clearance from independently confirmed documented approval, then select the established School Office through the existing directory. The fictional notice is explicitly scoped to this school scenario. The office response is pending; no denial or culprit identity is invented before Chapter 4.
- The restricted roster is a generic navy/cyan UI card, with no actual student data. Choosing a partial list or the sender's alternate private contact yields correction without sending anything or opening a contact. Correct findings use existing green confirmation. The small-screen final confirmation explicitly keeps LIST RESTRICTED / NOTHING SENT visible with Continue.
- Saves retain partial document reads, field/channel matches, claim review and directory review. The cleaner requires their ordered prerequisites; wrong answers, hint/perk status and completion rewards retain existing semantics. Three source-grounded Codex discoveries unlock from evidence. Coached story activity does not change mastery or research assessment records; perks remain denied outside story context.
- Chapter 3's story, investigation and preview reuse the Module 4 consultation environment created for the intro, preserving its room and lighting. This is intentional continuity, not another environment counted toward the requirement. **Environment inventory remains 3/5.** Records-office and briefing-room backgrounds, later previews, counter art and full hearing effects remain open for their approved slices.

Validation passed: complete story/notification/investigation/seal/epilogue flow; prerequisite unlocks; two-document and ordered comparison gates; partial read and completed save/load; malformed-save repair; corrected unsafe proposals; pause and stale-account guards; once-only reward, assisted bonus removal and reward-free replay; Codex hidden/unlocked findings; unchanged BKT mastery/events. Chapter 2's regression and new handoff also passed. Godot renders were inspected at 720×360, 844×390 and 932×430; comparison and approval choices remain reachable through scrolling with at least 44-pixel button heights, and the smallest success panel and Continue fit visibly. Tests and generated validation images remain local and ignored. No files were newly staged and no commit was made; the earlier PNG removals remain staged.

Remaining acceptance: physical phone safe areas/performance, installed build, hosted account synchronization and offline/first-download behavior. Next slice, after explicit confirmation: **Chapter 4 — Ask the Real Office**, including the new records-office background and independently sourced office response. Chapter 5 remains the approved full shared debate, not a simplified quiz.

### Gate 3D Chapter 4 implementation review — 4 November 2026

The user approved **Ask the Real Office**. It is locally implemented and verified, with a new hosted records-office environment. Chapter 3 now offers Next Chapter; Chapter 5 remains in development. Progress counts nineteen authored chapters.

- Reuses the shared chapter/phone screens, source-labelled records, progression signals, account ownership, saves and replay. The two new scripts separate the chapter definition from its interactions. No new manager or save system was added.
- The response is reached through the existing school directory and established School Office entry. Players trace that route in order, match the assignment and authorization denials to their conclusions, and identify the limit: false claims in this case, not an operator identity or a guarantee of system-wide safety. The internal event meeting remains separate.
- Players review and include the supplied appointment, actual private request and office response before saving their case record. Each retains its source. Roster inclusion and unsupported accusations give corrective feedback without adding either to the record. No student data is collected or transmitted. Green highlights persist on reviewed route steps, included records and correct matches; final success and Continue fit the small-screen panel.
- Partial route, match and report progress survive cleaning/save/load. Existing perk and hint tracking, corrected-work rewards, replay isolation and three discovery-gated Codex entries apply. Coaching remains separate from BKT mastery and research assessment events.
- Generated `records_office_v1.png`, 1672×941, using the built-in imagegen tool; integrated its versioned Cloudinary URL into the story, investigation and chapter preview. **Module 4 environment inventory is 4/5.** The school briefing room, Chapter 5 imagery/counter and document-themed hearing effects remain outstanding. Exact generation prompt and URL are in `output/module4-art/README.md`.

Validation passed: hosted asset acquisition/cache decode; full story → notification → route tracing → statement matching → record assembly → seal → epilogue; prerequisite and ordered-step guards; correction feedback; partial and completed save/load; malformed-save repair; pause and stale-account protection; once-only credits, assisted bonus removal and reward-free replay; Codex discovery gating; unchanged mastery/events. Chapter 3's regression and new handoff passed. Godot renders were inspected at 720×360, 844×390 and 932×430; route choices remain reachable by scrolling with at least 44-pixel button heights, and final success and Continue remain visible. The chapter preview uses the new room.

Tests, render captures and source PNG remain ignored and unstaged. Existing staged removals of the four earlier hosted source images were preserved; no commit was made. Physical-device safe areas/performance, installed build, hosted account sync and offline/first-download acceptance remain open.

Next slice after explicit confirmation: **Chapter 5 — The Mask Holds**, using the approved full shared hearing format, its school briefing-room environment and Sir Rham's module-specific presentation. Do not begin Module 5 automatically.

### Gate 3D Chapter 5 implementation review — 5 November 2026

**All five chapters of Module 4 are playable locally.** Completing *Ask the Real Office* unlocks *The Mask Holds* through Next Chapter and Chapter Select. Progress now counts twenty authored chapters.

Sir Rham, John, Liza and Mika test four explanations using the original appointment, its document sources, the private roster request and the independent office response. The supplied appointment stays at 10:30. The school's correction moves only its internal meeting to 11:00. Players compare the claimed approval with the office denial and reconstruct six events. The school acknowledges the report, and the roster stays private. The Collector remains the sole active connection throughout the audience cutaway. Mika's unopened event-file offer leads into the next module.

The shared hearing handles preparation, joining, credibility, hints, pixel evidence commands, replay and reconstruction. Its existing clock drives Module 4's document layers and reduced-motion treatment. New hosted briefing-room and Sir Rham counter illustrations complete the finale art. The module now has five distinct environments. Five Codex findings unlock through the debate, and the results screen offers pretexting practice. Mika uses the existing camera-off presentation in this hearing.

Local Godot checks passed for the Chapter 4 handoff, Module 3 hearing regression, and Module 4 hearing through completion and replay. Checks covered the theory bonus, wrong evidence, zero-credibility recovery, pause and resume, source comparison, case reconstruction, save restoration, once-only rewards and Codex discovery. Story assistance stays in the story ledger and the checks confirmed separation from graded BKT and assessment events. The mobile previews covered 720×360, 844×390 and 932×430. The two hosted illustrations downloaded and decoded in the local cache. Developer checks, screenshots and new PNGs remain local.

**Release acceptance still open:** installed build on a physical phone, safe areas and performance, hosted account synchronization, and first-download/offline behavior. The next story milestone is review of Mika's detailed Module 5 script and art brief.

### Gate 3E script and art brief for review — 5 November 2026

**The Last Gift** follows Mika, who has to get a school event ready after four exhausting incidents. Her deadline is real. A free pack of finished posters, signs and editable layouts would give the club a night of work back. The player’s job is to help her finish the event while checking who supplied the offer and what accepting it would actually do. The approved five chapter titles stay in order. The proposed dialogue, identity evidence and art direction below are for review.

#### Intro and Chapter 1 · A Gift for the Club

Start on the same evening and the **same unread notification** that ended Sir Rham’s hearing. Mika stands in the auditorium wings. Beyond the curtain someone holds up a hand-painted arrow to ask which way it goes. Mika turns it the other way. Her phone lights up. *Event Recovery Desk · Your event materials are ready.* Mika says, “Posters, arrows, room signs. If this has table numbers too, I might cry.” She pockets the phone to help carry a sign. Title reveal over a closed, brightly tabbed asset folder. End the intro there. On replay or skip, Chapter 1 still starts that evening with the single unread offer.

1. **Open the message.** Back in the wings, tap the notification. “You’ve had enough disruptions. Here’s a complete event pack, including table numbers. Our desk prepared it for your club.” John asks, “Did we order table numbers?” Mika replies, “I wished for them quite loudly. I don’t think that counts.” Inspect the promised items and the displayed sender. Record the offer as received and the supplier role as claimed.
2. **Check the booking.** Mika opens the existing club event chat and its pinned materials plan herself. The plan assigns poster files to the student design desk through the established club folder. The offer came in a separate conversation and supplies its own contact for confirmation. Match each record to its source. A missing supplier name prompts a check and leaves the origin unresolved.
3. **Choose the safe next step.** Save the message and ask the design desk through the pinned club contact. A reply to the offer’s own “verification desk” gives the player a chance to reconsider. The confirmation should read *Offer preserved · pack unopened*. Mika texts John, “Keep the crooked arrow. It’s the only sign whose maker I can personally identify.”

The original save records the message, independent plan and chosen contact route. The reply arrives in Chapter 2. A complete Chapter 1 save can never reveal that later reply.

#### Chapters 2–4 · What the player discovers

| Chapter and scene | Dialogue and touch sequence | Finding the player can keep |
| --- | --- | --- |
| **2. Just Open It** · Next morning, school print and design studio | The design desk replies in the established chat, “Our signs are in the club folder. We didn’t send a helper.” The offer sends an image preview and a new instruction to install a “preview helper.” Mika says, “I asked to see a poster. Why am I being asked to install anything?” Inspect three labelled areas of an inert phone mock-up: the poster preview, the actual attachment type (*Android app package*), and the request to allow installation from this source. Tap **Keep closed and preserve details**. | The attractive preview describes the promise. The package type and installation step describe the requested action. The independent desk denies sending that helper. Viewing the in-game record never downloads, installs, or opens a real package. |
| **3. Everyone Already Has It** · Late morning, campus sign-painting shelter | A cropped endorsement reads, “Tried it. Looks great! — Amani.” Amani answers in the established club chat, “That was about Mika’s hand-painted banner. Look one message up.” Compare the sender’s crop with the original reply and its banner thumbnail. Liza asks, “Can you warn us without sending us the thing?” Choose the warning that names the offer and points to the pinned club folder. | The quoted words were real. The crop changed what “it” referred to. The player preserves both messages and warns classmates without forwarding the package. Mika’s enthusiasm and Amani’s praise are distractors, not attribution evidence. |
| **4. Four Connections** · Afternoon, student services incident desk | Sir Rham opens the school support case through its established directory entry. He reads a sanitized service report aloud. The report supplies delivery references for the coordinator request and the pack offer. Students pair each reference with its preserved original. The directing account field is withheld pending verification. Mika closes the case note with a question for the hearing: “Who directed the switch?” | This is the first student-accessible evidence connecting the two deliveries. The references link the deliveries. The directing account is revealed in Chapter 5. The person’s real-world identity remains unknown. Separate earlier case cards preserve John’s Jobert outcome, Amani’s rejected device request and Liza’s independent wallet-support check. Their similarities alone cannot establish a shared sender. |

#### Chapter 5 · Close the Connection

At dusk in the event production booth, Mika hosts the hearing on her phone. John, Amani, Liza and Sir Rham join. They reconstruct the Collector’s claims from preserved records. The Collector does not receive a live invitation. The opening’s five affected people have a voice, and the four masked connections retain their existing count.

Preparation opens the original case record and one **new containment receipt** from the independently opened support case. It says the reported delivery was removed, compromised posting access was revoked, and affected students can contact support through the school directory. Mika kept the pack closed. Her own device has no recorded installation in this story.

Theory prompt: **Which assumption made the offer persuasive?** The correct choice is *A useful gift must be safe.* Other choices are *Read what it installs*, *Ask the actual design desk*, and *Warn the club without the file*. Use the shared three hints, 35/20 starting credibility, joining cinematic, terminal command loading, orange claim targets, +15/−10 scoring and round recovery.

| Round | Claim to challenge | Correct exhibit and rebuttal | Plausible wrong picks |
| --- | --- | --- | --- |
| 1 · The right gift | “It had exactly what the club needed, so **the school must have sent it**.” | Pinned materials plan plus design-desk reply. Mika says, “They knew we needed signs. The people making our signs say this didn’t come from them.” | Attractive preview, banner praise |
| 2 · Only a preview | “The thumbnail was a poster. **All you had to do was view it.**” | Package details plus installation request. Liza says, “Read the action on the prompt. It asks to install an app.” | Sender display name, schedule correction |
| 3 · Everyone trusts it | “Amani tried the pack and **endorsed this download**.” | Cropped endorsement beside original banner thread. Amani says, “That’s my sentence. Put the picture it belongs to back above it.” | Poster preview, Mika’s excitement |
| 4 · Separate deliveries | “The coordinator failed. **There’s nothing connecting that request to this offer.**” | Independently obtained service report paired with the preserved records. Sir Rham says, “These two delivery references match our originals. The contact changed its pitch. These records link the deliveries.” | Shared branding, similar timing, the internal schedule correction |

**Final comparison and mastermind reveal (approved).** Once the four rebuttals are sealed, reveal the authenticated case addendum. It identifies **the Collector** as the mastermind. The addendum pairs preserved instructions to the survey, text and call operators with service-verified case references, then records the Collector directing the pivot from the failed roster request to the pack. This evidence supports campaign coordination as well as the two deliveries. Students obtain it through the established support case. Keep the identifying addendum out of previews, preparation, hints, recap and early Codex entries. Match the recorded admission about switching from roster to pack against both corroborated delivery references. Mika’s line: “I can tell you which account sent both. I can show you how we know.” The match awards the shared final bonus, capped at 100. No student has to guess a legal name.

**Closing reconstruction.** Place six frames: roster withheld → gift offered → helper requests installation → endorsement restored to its original context → support corroborates the two deliveries → delivery contained and club warned. Decoys: *Mika installs the helper* and *Amani recommends the pack*. The narrated comic uses story locations and repeats the source of the final finding. After the hearing, the club puts up its own signs. John holds the crooked arrow. Mika says, “Leave that one. Everyone found us.” The verified support receipt and help route close the learner’s case. Only then cut to the audience view: three lights are already dark and the fourth goes out. Offer **Review evidence** and **Practice baiting** through the existing Codex and lesson routes. Campaign completion comes from the final chapter’s saved completion.

#### Module 5 visual direction and first-slice boundary

| New environment | Art and continuity cue |
| --- | --- |
| Auditorium wings, evening | Painted arrows, rolled canvas and warm spill from the stage. Same framing and unread offer across intro and Chapter 1. |
| Print and design studio, morning | Paper offcuts, drying prints, broad worktable and window light. Leave the actual file details to live phone UI. |
| Covered sign-painting shelter, late morning | Open-sided canopy, half-painted banner and campus walkway. The banner gives Amani’s original reply a concrete referent. |
| Student services incident desk, afternoon | Accessible visitor-side seats, frosted privacy divider and a tray for case folders. Keep names, student data and screens out of the artwork. |
| Event production booth, dusk | View through glass toward the school event, cue sheets and finished handmade signs. Frame Mika and her phone clearly during the finale. |

**Portrait proposal.** Mika wears the established school uniform, dark hair in a low ponytail with a small teal tie, and a paint-marked event lanyard. Six expressions: delighted, busy, puzzled, checking, concerned, and resolved. Her earlier off-screen line and camera-off hearing establish her role and voice. Review the proposed likeness against any preferred reference and the opening montage before generating it. Reuse the approved portraits for the returning cast.

**Presentation motif.** The title starts as a beautifully wrapped folder. A paper tab peels back to expose a second label. The later counter uses two separated layers, *preview* and *requested action*, with Mika’s own lettered counter illustration. Render evidentiary words as live UI with the existing navy/cyan/cream palette. Use a stationary pair of labels in reduced motion. Budget a new mystery title, five environments with chapter-specific previews, Mika’s portrait and final counter. Track investigation and hearing presentation separately from the environment count. Host approved assets through the existing catalog and keep source PNGs and developer checks local.

**Proposed first implementation slice for sign-off**

- Extend the current module intro and chapter selector for Module 5. Route **A Gift for the Club** to the shared chapter screen after Module 4’s completed hearing and the existing Module 5 lesson gate. Keep legacy stages and saves accessible.
- Supply Chapter 1 content and touch interactions through the existing chapter definition and phone-panel pattern. The phone emits the existing evidence, thought and phase signals. The chapter screen and PlayerManager retain pause, account ownership, original/replay state and rewards.
- Produce only the first-slice artwork: Mika’s approved portrait, evening auditorium wings and mystery title. Register Chapter 1 discoveries in Codex and Progress. Check notification → source comparison → safe response → seal, resume and replay, reduced motion, mobile touch layout and isolation from graded BKT and assessment records. Later chapters and the remaining four environments have their own implementation gates.

### Gate 3E first implementation review — 5 November 2026

The user approved Mika's design, the first slice and the Collector evidence. **Chapter 5 is the campaign ending and reveals the mastermind.** The revised Chapter 4 script gives the students delivery references to investigate. The identifying admission and corroborated directions become available at the final comparison in Chapter 5. These later scenes are approved story direction and await implementation.

Mika's dedicated intro and **Chapter 1, A Gift for the Club**, are playable after completing Module 4's hearing and the first Tempting Offers lesson. Both scenes take place in the auditorium wings on the evening of the hearing and follow the same unread message. Players inspect the promise, match the offer and pinned plan to their sources, and send a simulated inquiry through the established design-desk contact. The saved finding ends with the pack unopened and a reply pending. Three discoveries appear in Codex as earned. Progress now counts 21 authored chapters. The results screen returns to Chapter Select, where later chapters are marked in development.

The first three images are hosted and integrated. Mika has six poses, the auditorium wings are the first of five planned environments, and the dedicated folder title uses the existing reveal animation with a paper-tab accent. Asset paths, hosted links and exact prompts are in `output/module5-art/README.md`.

The new chapter, Module 4 hearing and Module Select checks passed in Godot 4.7.2. Coverage included lesson and story prerequisites, first visit and returning-player routes, comparison prerequisites, feedback, partial save restoration, original/replay rewards, assistance separation from mastery, intro pause/replay/skip and artwork cache decoding. Godot previews were inspected at 720×360, 844×390 and 932×430. Physical-device and installed-build acceptance remain open.

Next story slice: **Chapter 2, Just Open It**, including the design-desk reply, the preview-helper inspection and the new morning print studio.

### Gate 3E Chapter 2 implementation review — 5 November 2026

**Just Open It** continues Mika's inquiry the next morning in the new print and design studio. The pinned design desk denies sending a helper. Players compare that reply with the separate offer, inspect its poster thumbnail, Android package details and installation request, then preserve the evidence with the package closed. The file type alone is explicitly insufficient to establish malware. All interactions use inert records within the game.

The existing chapter screen, phone signals, PlayerManager saves and perk rules own the flow. Chapter 1 now hands off to Chapter 2. Progress counts 22 authored chapters, and Codex reveals the three findings as earned. Partial inspection, original/replay saves, reward protection, pause and account ownership use the existing mechanisms. Story coaching remains separate from graded mastery and learning events.

The studio image is hosted through Cloudinary and used in the chapter preview, story and investigation. Module 5 now has **2 of 5 new environments**. Three later environments, finale art and module-specific hearing effects remain open. The art record and exact prompt are in `output/module5-art/README.md`.

The Chapter 2 Godot verification and Chapter 1 handoff regression both passed with zero failures, including touch targets, source and inspection prerequisites, corrective feedback, save restoration, pause/account guards, reward/replay behavior and unchanged mastery records. Mobile previews were reviewed at 720×360, 844×390 and 932×430. Developer checks and source PNGs remain ignored and were not staged. Physical-device and installed-build acceptance remain open.

Next implementation gate: **Chapter 3, Everyone Already Has It**, including Amani's cropped endorsement, its original banner context and the new sign-painting shelter. Chapter 3 remains unavailable in this slice. The mastermind reveal stays reserved for Chapter 5.

### Gate 3E Chapter 3 implementation review — 5 November 2026

**Everyone Already Has It** is playable after Chapter 2. Mika receives a cropped endorsement in the offer conversation, checks the original through the existing club chat, restores the missing banner photo and question, and reads Amani's clarification. Players identify that the praise concerns the hand-painted banner before choosing a warning that names the offer and installation request, points to the pinned club folder and excludes the package. Forwarding the package and accusing Amani receive distinct corrective feedback. The game sends no external message or attachment.

The chapter uses the existing screen, phone base, evidence signals, save owner, rewards and perk rules. Three earned Codex findings preserve the sources and do not reveal later attribution. Progress counts **23 authored chapters**. Chapter 2's result offers Chapter 3, while Chapter 4 remains in development. The mastermind reveal remains reserved for Chapter 5.

The new late-morning shelter background is hosted through Cloudinary. Its banner also supplies the original-message thumbnail, with a caption identifying the photo as taken before hanging. The chapter keeps the established navy/cyan/cream interfaces and green success feedback. Module 5 now has **3 of 5 new environments**. The student services incident desk, production booth and finale-specific imagery/effects remain open. The exact generation prompt and asset URL are recorded in `output/module5-art/README.md`.

Chapter 3 verification, the Chapter 2 handoff regression and the Chapter 1 opening/selector regression all passed with zero failures in Godot 4.7.2. Checks covered prerequisites, mandatory source inspection, partial save/load, corrective feedback, pause/account guards, reward-once behavior, replay preservation, Codex discovery and unchanged graded mastery/learning events. The comparison card, safe warning and selector were reviewed in rendered mobile previews at 720×360, 844×390 and 932×430. These previews do not close physical-device or installed-build acceptance. Developer checks, artifacts and source PNGs remain local and ignored, with no new files staged.

Next implementation gate: **Chapter 4, Four Connections**. Use the independently reached support case and corroborated delivery references in the new afternoon incident-desk setting. Keep the directing-account field withheld until the Chapter 5 final comparison.

## Whole-system completion audit — 6 November 2026

The user paused feature work during Chapter 4 review and requested a whole-system completion estimate. No further gameplay implementation was performed during this audit. The assessment uses the current working tree, existing implementation reviews and fresh local checks. It does not establish the state of a deployed version or an installed phone. The separate staff web application's source and authorized roles are not available in this workspace.

**Planning estimate: approximately 70% complete toward the tested, deployable whole-system target, with a ±5 percentage-point uncertainty.** This is an engineering estimate against the agreed release scope, not a count of files, a test pass percentage or a prediction of elapsed work remaining. Release integration receives substantial weight because it is mandatory. The missing finale is more work than an average chapter, so 24/25 authored definitions does not mean the story is 96% finished.

| Area | Estimated completion | Weight in overall estimate | Evidence and remaining work |
| --- | --- | --- | --- |
| Story / Deploy | 90% | 20% | Modules 1–4 have five chapters each. Module 5 has four implemented chapters; Chapter 4's review is paused after a passing flow check. Final hearing, mastermind reveal, reconstruction, campaign closure and final environment/presentation remain. Device acceptance remains open. |
| Lessons | 85% | 10% | Five modules and 30 topics; fresh workspace check passes all 30. Finish content/answer-key review and installed-device acceptance. |
| BKT and adaptive practice | 80% | 15% | Actual posterior/learning updates, weaker-eligible-topic practice selection and difficulty selection exist. Fresh offline-sync checks pass. Estimates cover five broad threat topics; parameters are configured, not fitted to student data. The wrong-answer decrease cap is a deliberate modification to classic BKT. Device-to-hosted persistence and adaptive demonstrations remain open. |
| Codex | 85% | 5% | Searchable field guide and discovery-gated chapter records cover 24 authored chapters. Final records and full-campaign presentation acceptance remain. |
| Student Progress | 80% | 5% | Uses live mastery, lesson/checkpoint data and dynamic authored chapter totals with sync labels. Later-module locked guidance needs correction: `progress_data.gd` explicitly handles Modules 2–3 but can fall back to “Complete Chapter 0 first” for a locked first chapter in Modules 4–5. Two local assertions still assume five total chapters. |
| PvP | 70% | 10% | Room/join, matchmaking, authoritative duel logic, reconnect handling, history and ratings are implemented. Mock session check passes. Two installed phones, hosted interruptions/results and Store-currency integration remain. Extra game types are outside the agreed minimum release. |
| Store | 50% | 6% | Purchase/ownership checks and avatar selection exist; local Store fixtures pass. Non-avatar items explicitly say equipping is unavailable. `pvp_tokens`/Threat settlement from matches is not implemented; PvP rating is a separate value. The earn → buy → equip → Profile/PvP loop is incomplete. |
| Profile | 75% | 4% | Shared progress snapshot and selectable owned avatars exist. Complete supported cosmetic integration and reconcile the outdated full-completion/asset assertions before final acceptance. |
| Account/backend integration | 80% | 5% | Auth, local/cloud save ownership, progress/BKT services and configured hosted origins exist, with substantial local coverage. Installed-client login, expiry, reconnect, account switching and live database contracts need acceptance. |
| Staff monitoring/support integration | Unverified | 5% reserved | Mobile records and feedback integration exist. An earlier live feedback receipt is documented, but teacher/head authorization, progress reconciliation and support actions cannot be counted as accepted from this mobile repository. No completion credit is assigned for this reserved dependency; this does not mean the separate web app is unimplemented. |
| Mobile release and deployment acceptance | 30% | 15% | Android development preset and a signed development APK exist. The APK is dated 30 October and predates recent story additions. Release signing/identity, updated build, target-phone journeys, current hosted deployment and handover remain open. |

The weighted value is approximately 68%, rounded to about 70% at this level of uncertainty. Features being present is distinct from their release gates passing. The amount of remaining work is not proportional to the number of remaining story chapters.

### Fresh validation evidence

- Python discovery ran **369 tests: 357 passed, 11 failed and 1 errored**. The failing scenario checks reference legacy titles/structures such as “The First Warning” while current content says “Before the Bell”; one expects a `threats` key. The TRACE source assertion expects a `[TRACE EXAM]` marker absent from current code. These require reconciliation with the intended legacy support boundary; they were not deleted, rewritten or declared harmless.
- Godot Lessons workspace: **30 topics, zero failures**.
- Godot BKT offline sync: **zero failures**, including topic-specific diagnostics, newer-learning preservation and delayed-account-response guards.
- Godot Store fixtures: **zero failures** for implemented behavior. This does not supply missing equipping or match-earned currency.
- Godot online PvP session fixtures: **zero failures**, using fake HTTP/WebSocket transports. No two-phone live acceptance was performed.
- Godot Progress: **2 failed assertions**, both expecting five authored chapters despite the current 24.
- Godot Profile: **13 failed assertions**. Ten require avatars to be remote-only; three treat Module 1 completion as whole-campaign completion/expected routing. These are validation-contract discrepancies to resolve, not proof of thirteen distinct runtime faults.
- Immediately before the pause, Chapter 4's rendered flow verification passed with zero failures. Its small-screen pairing view and case-note scrolling still need final review; the Chapter 3 → 4 handoff regression has not yet been run in this slice.

Audit logs are retained locally under `frontend/.godot/system_audit_*.log`. Developer tests and generated logs remain ignored. No production service or student record was changed, no deployment was performed, and no files were staged for this audit.

### Recommended remaining order

1. Resume and close Chapter 4 review, then finish Module 5's shared-format Chapter 5, campaign ending and final art.
2. Reconcile the stale validation contracts and confirmed later-module guidance defect; demonstrate the complete Lessons → BKT → Progress → account-sync path.
3. Finish the agreed PvP → Threat → supported Store item → Profile/PvP use flow, with two-device acceptance.
4. Verify the separate teacher/head monitoring and support workflow. Confirm independent research assessment delivery separately from gameplay scores.
5. Rebuild the Android app, run full journeys on target phones against the deployed services, fix blocking defects and close release handover.

The existing 19 November deadline leaves about two weeks. Prioritize these integration and acceptance gates over new game modes or broad visual redesigns. Story progress alone cannot close the whole-system target.

### Gate 3E · Delivery review and campaign ending · 6 November 2026

In **Four Connections**, Mika and Sir Rham match the school support report to both original deliveries. Finishing the chapter opens **Close the Connection** in the shared hearing. After four rebuttals, Mika uses the authenticated addendum to identify Collector. It links the roster request and the pack offer to the directing account and corroborates the earlier operators' instructions. John's case retains Jobert's admission.

The player assembles the six-panel reconstruction. The club then puts up its handmade signs in the evening auditorium wings, returning to the setting where Mika first received the offer. The final masked cutaway closes the fourth connection. Completing it saves the chapter, records the first-clear reward, and offers evidence review and baiting practice. Godot checks covered the Chapter 3–5 progression, discovery order, save and replay behavior, and isolation of story decisions from graded mastery. A full installed-phone playthrough is still required for release acceptance.

### PvP Capture the Flag · approved first online slice · 7 November 2026

The approved **Event Pack** race replaces quiz combat for two updated online clients. The attacker expands an invitation, traces its delivery manifest and retrieves EVENT.FLAG. The defender checks the pinned directory, restores the original endorsement thread and secures the same flag in quarantine. Each path requires inspecting the evidence before routing. Incorrect routes provide feedback. The first server-accepted capture ends the match; the two-minute deadline produces a draw if neither captures. This is a simulated social-engineering investigation, with no real file execution or network attack.

The existing terminal lobby, room/session owner, matchmaking, ready and reconnect signals remain in use. Players can choose a preferred role; matching preferences are assigned randomly. The new terminal presentation provides a cyan network map and green file pane, with tap navigation between them on smaller phones. The backend retains each player's evidence step and command revision, rejects stale or premature commands and serializes simultaneous captures under the existing room lock. One final match record feeds the existing rating pipeline. Private matches are unrated. PvP does not update BKT mastery, assessment scores or the store wallet.

Local verification covered both capture routes, simultaneous finishes, inspection prerequisites, wrong routes, stale retries, reconnect, role conflicts, malformed commands, matchmaking and rating eligibility. The full backend PvP suite passed **146 checks**. Godot rendered checks cover small landscape layouts, terminal navigation and online ownership; physical two-phone acceptance is still required. Developer checks and screenshots remain local and are excluded from commits.

Before deployment, apply the updated `pvp_match_history.sql` and `pvp_ratings.sql`, then deploy the backend and rebuild both mobile clients. These changes have not been applied to the hosted database. Match rooms still require one backend worker. Bot practice and older clients retain the legacy quiz flow. Active interference, more maps and bot conversion are outside this first slice. Do not mark whole-system or hosted PvP acceptance complete until the installed-phone capture/reconnect/history/rating journey passes.

### Capture the Flag computer workspace redesign — approved and implemented

Replace the split-pane match presentation with the supplied green CRT computer reference: a substantial beige monitor bezel, inset dark glass, restrained scanlines, green pixel type, a system menu strip, bordered application windows and a small hardware power indicator. This is a simulated computer inside the mobile game, not a separate desktop platform. Keep the amber matchmaking directory unchanged in this slice.

Both players enter the same **Home** workspace when the existing synchronized countdown ends. Home shows the assigned role, a short mission briefing and three large application shortcuts: **Terminal**, **Files**, and **Netmap**. Terminal shows the current operation/status; Files opens the current evidence and inspection action; Netmap opens the route targets. All three operate on the existing server-owned trail. A persistent Home control returns to the workspace without resetting progress or pausing the shared timer. Inspection and routing remain explicit touch actions. Home is an entry view, not another Ready gate.

- Node structure: retain `PvpFlagTerminal` under `PvpOnlineScreen`; build the CRT shell, system strip, Home shortcuts, one application-window host, and bottom status strip inside it. Reuse its current file scroll, map controls, labels and buttons. At phone sizes, the selected app fills the usable workspace; the design does not depend on tiny overlapping windows or draggable title bars.
- Signals: existing `command(action, target)` continues through `PvpOnlineSession` to the server; existing leave/retry signals retain their owners. Local app navigation changes only visibility and selected app. Server replies still own evidence progress, feedback, capture and result; there is no new manager or duplicate match state.
- Acceptance: both roles initially land at Home; Files inspection → Netmap selection → confirmed route → final capture remains playable; Home/app switching cannot reset or bypass a gate; timer/reconnect/winner behavior stays intact. Review 720×360 and 844×390 renders, readable text, 44-pixel touch targets, safe areas and reduced motion. Use red window treatment only for actual denial/disconnection and green feedback for accepted progress. Do not add pretend attack tools or nonfunctional icons from the reference.

The user approved this structure and supplied additional pixel-icon, window, palette and effect references. The existing `PvpFlagTerminal` now implements Home, Terminal, Files and Netmap as touch-operated app views. Pixel icons are drawn on an integer grid; green window strips, double borders, scanlines, selected controls and matching scrollbars replace the previous split-pane presentation. Actual connection/route warnings use the red treatment. There is no new asset file, effects manager or match-state owner. Backend rules, database schema, roles and match duration remain unchanged.

The Godot online-screen verification passed with zero failures. Rendered previews were reviewed at 720×360 and 844×390. Checks cover initial Home for both roles, countdown inspection blocking, navigation without network actions, preserved evidence on returning Home, route selection, locked-flag protection, final capture, manual reconnect and a reduced-motion result. Small-phone touch targets retain a minimum 44-pixel height after the workspace scale. Physical-device acceptance and the previous hosted database/deployment tasks remain open.

### Bot Capture the Flag practice — approved conversion · 7 November 2026

The user chose **Also convert bot to CTF**, replacing the proposed visual-only update. Practice now opens the shared green CRT Home with role selection and Start Practice. It uses the same Event Pack evidence, Files inspection, Netmap routing and capture actions as online play. The local bot follows the opposite role's trail, takes 8–14 seconds per action and has a 25% chance of choosing the wrong route when more than one route exists. Wrong choices must be retried on a later turn. Its schedule is independent of player answers and progress.

`PvpBattleScreen` remains the local owner and uses `PvpBattle.FlagPractice` in the existing gameplay file. The shared workspace emits the existing command and exit signals, with practice start/replay signals for the local owner. No fighter arena or quiz match is constructed on the bot route. Home does not start a hidden timer: Start Practice begins the countdown, followed by a two-minute race. The first capture wins; the deadline yields a draw if neither side captures. Scheduled bot actions are resolved before later player inputs. Exit confirmation pauses the local race for both sides, replay returns to role selection, and cleanup disconnects and retires the local model.

Local verification covers both roles, inspection gates, wrong/stale commands, bot capture, timeout, replay, exit pause and cleanup. All 12 role/side/stage evidence snapshots were compared with the Python online implementation. Phone renders at 720×360 and 844×390 show Home, evidence and the final result. The bot check and shared online-screen regression passed with zero failures. Developer checks remain local and excluded from commits. Practice remains offline, unranked and separate from BKT, research assessments and the store wallet. Installed-phone acceptance remains open.
# Adviser update gates — diagnostic learning routes (11 November 2026)

Approved sequence: (1) diagnostic routes and chapter access, (2) twenty-question lesson pools and retry rotation, (3) Handler appearance and expression artwork, (4) engagement and rewards. Each gate is verified before the next begins. Gates 1–3 are locally implemented. On 12 November the user requested revising Gate 4 around story completion, chapter objectives and three-star achievements; the detailed proposal below awaits sign-off. Installed-phone and live synchronization acceptance remain open.

## Gate 1 implementation and acceptance

- First 15-item module diagnostic: 15/15 clears academic prerequisites; 12–14/15 requires lessons mapped to missed items; 0–11/15 requires all six lessons. Targeted and full routes still need the 20/25 checkpoint. Perfect-score clearance awards neither lesson completion nor a fabricated checkpoint score, mastery value or currency.
- `PretestBank.LESSON_MAP` maps all 75 diagnostic items to zero-based lesson objectives; coverage validation requires all six objectives in each module. Multi-objective misses require all associated lessons. This is an authored curriculum mapping, not an empirically validated assessment instrument.
- Saved baselines now retain `missed_ids`, `route_version`, `route` and `required_lessons`. Access is recomputed from validated diagnostic evidence. First results are immutable. Legacy partial aggregates without item-level evidence keep their full route; a valid historical 15/15 can clear the module. Malformed/incomplete mappings fail closed.
- `lesson_completions` records individual actual completions as `module_id:index` keys. Legacy `lesson_progress` remains a contiguous prefix; the displayed completion count is the union of both. Existing module-complete markers remain recognized. Account restore clears previous-account state; offline/cloud reconciliation unions completion records without manufacturing intermediate completions.
- Chapter prerequisites: Lessons 1–4 for Chapters 1–4; Lessons 5–6 plus academic module clearance for Chapter 5. Diagnostic-cleared lessons satisfy academic prerequisites, but earlier story chapters and the previous module ending still matter. Started/saved chapters remain resumable.
- Lesson map, journey, Progress and chapter selection share access predicates. Perfect diagnostic results offer the next learning module or optional study. Failed checkpoints offer mapped lesson review; items without a curated lesson association explicitly recommend broader module review rather than claiming precise diagnosis.
- Existing analytics transport remains compatible: adaptive checkpoints retain the `posttest` transport kind and `lesson-checkpoint-v1` instrument with no research comparison key. They are presented as checkpoints, not independent research post-assessments. No server/schema migration is required; the existing progress payload retains additional save fields.

Validation: Godot 4.7.2 script import passed; isolated route suite passed 314 checks covering all five modules, 15/14/12/11 results, immutable baseline, noncontiguous completion, JSON restore, cloud merge, legacy progress, chapter order and optional checkpoint review. Existing lesson workspace suite passed all 30 topics. Rendered the lesson map at 1280×720 and 844×390; confirmed readable status labels and native scrolling. Physical-phone acceptance and live two-device synchronization remain release checks. Developer checks and rendered artifacts are local/ignored and must not be staged.

## Gate 2 implementation and acceptance — 12 November 2026

- All 30 lessons now have explicit twenty-item assignments: eight cue-recognition checks, eight verification checks and four safe-response decisions. These are 600 lesson-question placements using 294 existing canonical questions (59/58/58/60/59 by module), not 600 newly authored questions. Related lessons reuse transfer questions about the same threat and verification decisions. No duplicate question bank or additional quiz manager was created.
- Each attempt draws two recognition, two verification and one safe-response question. Unseen items take priority, followed by avoiding the previous attempt and matching the current BKT difficulty preference. Each complete rotation uses all twenty items before restarting; the next cycle avoids the immediately previous five. Choices shuffle with their answer mapping. Passing remains 3/5.
- The existing account save now retains one current attempt per lesson: canonical IDs, choice permutations, submitted choices, reading completion, review position and rotation history. Reopening resumes the attempt instead of rerolling it. Restore recomputes correctness from content. Missing content and invalid option permutations cannot produce a pass. Account switching clears the prior account's attempts.
- Cloud merge selects a whole attempt rather than mixing question orders; within the same attempt, a stale draft cannot replace more submitted answers. Draft-only offline activity is included in reconciliation. This local conflict policy does not promise simultaneous multi-device quiz play; live two-device acceptance is still required.
- Mini quizzes and adaptive practice share canonical-ID deduplication. An already-observed question cannot add mastery again through either mode; completed-lesson review also remains ineligible. Rotation can include previously observed questions for practice without generating new BKT credit. Diagnostic/checkpoint scores and the BKT model remain separate and unchanged.
- Explanations accompany correct answers. Corrected two misleading existing domain explanations in Module 1 and made the binary suspicious/legitimate wording usable across all five threat types. Checkpoint lesson recommendations consult the full assigned pool, not a random five-question sample.

Validation: 2,337 local pool/rotation/resume/sync/deduplication checks passed; the 844×390 rendered run adds a visible-submit check (2,338 total). The 314 diagnostic-route checks and all thirty lesson/quiz/simulation flows pass. Reviewed rendered quiz layouts at 1280×720 and 844×390. Physical-device suspension, safe-area behavior and live account synchronization remain release acceptance items. No developer test files, screenshots or working media were staged or committed. Handler artwork/selection and rewards were not started.

## Gate 3 implementation and acceptance — 12 November 2026

The user approved both male and female base designs before expression production. This gate supports engagement and ease of use; appearance does not change learning routes, mastery, scores, voice recordings, currency or owned cosmetics.

- A shared `handler_picker.gd` opens on the dashboard after the first completed or skipped tutorial, and from Settings → Handler appearance. Male, Female and Prefer not to say are companion appearance choices; the latter retains the original. Returning accounts without the new fields remain original and receive no forced prompt. Keeping the original records a completed choice.
- The existing PlayerManager save includes `handler_appearance`, its update timestamp, and a pending onboarding choice. Existing local/cloud reconciliation chooses the more recent appearance independently of purchased cosmetics. Account changes clear the previous preference; the picker closes on session change. Restore emits the appearance signal only after the complete snapshot is applied, avoiding a transient reset in visible portraits.
- Dashboard portraits and the existing tutorial coach use the shared AssetManager resolver. The current John phone tutorial has no Handler dialogue; its existing completion emblem is replaced with a companion portrait without adding another step or replacing John. Initial completion uses the original; tutorial replays use the chosen appearance. Dashboard Handler guidance now discusses evidence, school stories, verification and lesson simulations instead of the former tower-defense instructions.
- Each new appearance has all eighteen expression states. Six transparent 1536×1024 sheets contain six 512×512 cells each. Godot uses AtlasTexture regions through the current catalog/cache, preserving existing portrait nodes and animation timing. A missing or invalid variant sheet falls back to the matching original expression. The next successful asset synchronization refreshes visible portraits.
- No new voice files, effects manager, save service or gender field were introduced. The only new reusable UI script is the picker shared by onboarding and Settings. Cards scroll vertically on narrow phones; selection and confirmation remain tap-operated, with 48-pixel action targets at tested sizes.

Expression sheet mapping, left-to-right then top-to-bottom:

| Sheet | Expressions | Male Cloudinary asset | Female Cloudinary asset |
| --- | --- | --- | --- |
| A | calm, smile, talk, thoughtfulness, skepticism, doubt | [Male A](https://res.cloudinary.com/nfd5bhkz/image/upload/v1794447957/levelblue/handler/handler_male_a_v1.png) | [Female A](https://res.cloudinary.com/nfd5bhkz/image/upload/v1794447962/levelblue/handler/handler_female_a_v1.png) |
| B | fear, astonishment, discomfort, sadness, cry, embarrassment | [Male B](https://res.cloudinary.com/nfd5bhkz/image/upload/v1794447967/levelblue/handler/handler_male_b_v1.png) | [Female B](https://res.cloudinary.com/nfd5bhkz/image/upload/v1794447971/levelblue/handler/handler_female_b_v1.png) |
| C | awkwardness, laughter, disgust, eye rolling, aggression, scream | [Male C](https://res.cloudinary.com/nfd5bhkz/image/upload/v1794447976/levelblue/handler/handler_male_c_v1.png) | [Female C](https://res.cloudinary.com/nfd5bhkz/image/upload/v1794447980/levelblue/handler/handler_female_c_v1.png) |

Art production used image generation with the approved base references: retain the pale-blue pixel silhouette, facial language, proportions, hairstyle and framing; vary facial expression only; transparent background; no text; consistent six-cell grids. Final sheets were uploaded to Cloudinary and all six downloaded successfully through Godot's existing asset loader. Working PNGs and upload receipts remain local under ignored `.godot/handler_designs`; temporary signing credentials were removed. No new media is bundled in the export or staged for Git.

Validation: Godot import passed; **149 Handler checks passed**, including 36 expression regions, unavailable art, first completion/skip, pending-choice restart, legacy accounts, selection of the original, JSON restoration, cloud merge, account switching, visible companion refresh, shared Settings controls, tutorial replay and mobile touch targets. Rendered picker views were inspected at 1280×720, 844×390 and 390×844; the tutorial completion portrait was reviewed at 844×390. Existing dashboard and current tutorial-practice replay suites passed; diagnostic routing passed 314 checks and mini-quiz rotation passed 2,337 checks. These are local checks, not a claim of installed-phone or live two-device acceptance. No student progress was written during these checks. Gate 4 rewards and timed replay have not begun.

## Gate 4 revised proposal — story achievements and learning support

**Status: proposed, not implemented.** The user rejected the earlier control-strip/timed-replay layout and asked for incentives to finish the story, careful decisions, help after mistakes, and three stars with chapter-specific objectives. This proposal prioritizes the existing 25 chapters. Timed replay is deferred. The earlier lesson-credit and academic-badge proposals are not silently implemented or discarded; reconsider them after this story-focused gate rather than mixing both reward systems in one change.

### Player experience

1. Before a chapter, show three short, spoiler-free objectives inside the existing preparation screen. One star is for completing the chapter; a second is for a named investigation challenge; a third is for completing the chapter without an incorrect evaluated decision. Goals must describe what the player controls, never scripted mistakes made by John or other characters.
2. During play, retain the existing evidence, terminal, phone and hearing interactions. A mistaken submission explains the relevant clue and consequence, offers a free contextual hint, and allows another attempt. Browsing, opening evidence, replaying dialogue, taking time and asking for help are not mistakes. Do not award stars for speed.
3. At completion, the existing result screen reveals earned stars, names the achieved objectives, explains any unfinished objective, and shows first-clear credits separately from newly earned star bonuses. Give Continue the primary action; Replay to improve is secondary. Reduced motion displays the same results immediately.
4. Chapter selection shows the best star result and the next improvement target. Finishing a chapter is sufficient for its chronological requirement, subject to existing academic prerequisites. Three stars must never become a gate to the next chapter or ending.
5. Completing all five chapters earns a story-completion cosmetic badge for that module regardless of star total. Use existing badge ownership and Equip/Remove controls. This signifies story completion, not measured knowledge or BKT mastery.

### Proposed star rules and examples

| Star | Rule | Purpose |
| --- | --- | --- |
| 1 — Case closed | Finish the chapter's existing investigation/resolution | Recognize persistence and progress even after mistakes |
| 2 — Chapter challenge | Meet one chapter-specific quality objective shown before play | Encourage attention to the particular social-engineering skill |
| 3 — Careful decisions | Complete the chapter with no incorrect evaluated submissions in that run | Reward careful reading and checking rather than guessing |

Examples for review, not finalized content mappings:

- Module 1, Chapter 1: classify all six messages correctly on their first submissions for the chapter challenge. Capturing evidence and finishing still earns completion even if sorting needed correction.
- Module 1, Chapter 2: identify the deceptive sender-domain difference on the first submitted comparison. Do not reveal the actual differing character in the pre-chapter objective.
- Chapter 5 hearings: complete the closing reconstruction correctly on its first check for the chapter challenge. Evidence-command errors and reconstruction errors count toward the careful-decisions star; scripted dialogue and cinematics do not. Existing credibility recovery and hints stay available.

Author and verify the objective for every chapter against its actual interaction before enabling stars there. A required action that all finishers necessarily complete is not a meaningful additional challenge. Record objective-specific events where current aggregate mistake counters cannot establish first-submission accuracy. Never infer missing attempt history from a finished save.

### Help, recovery and rewards

- Free contextual hints, recaps and reference material remain available throughout story learning. Using them does not remove stars or credits. Preserve assisted/unassisted activity records independently. The existing story clean-work reward currently excludes assisted attempts; replace that rule as part of this gate and update its explanatory copy. Existing paid support ownership must be preserved when making support free.
- Keep each chapter's existing base first-clear reward. Proposed additional reward: 25 Solo credits for first earning the second star, and another 25 for first earning the third. This replaces the old clean-work bonus; it must not stack with it. Final values require sign-off.
- A later replay may improve the saved best result and grant only a newly earned bonus. A worse replay never removes previous stars. Save the best completed run, not a synthetic three-star result assembled from unrelated attempts. Replays never rewrite the original evidence or first-attempt research/activity records.
- Resume preserves mistakes and objective attempts. Closing the app must not reset a failed challenge. Completed legacy chapters keep completion and existing credits; detailed stars require sufficient recorded evidence or a fresh replay. Account restoration and reconciliation must merge reward claims without paying twice or subtracting legitimately spent credits.
- No currency loss, paid retry, energy limit, or forced restart after learning mistakes. Do not award BKT credit for chapter stars, repeated story play, hints, or cosmetic achievements. Graded quizzes, checkpoints and independent research assessments keep their own rules.

### Reused nodes and signal ownership

- Extend the current chapter preparation/result containers and chapter selection rows with objective and star displays. Chapter controllers report evaluated actions through their existing save path; shared hearing mechanics remain unchanged.
- PlayerManager's existing story attempts, chapter saves and wallet own best results and one-time reward claims. Extend the current cosmetic catalog and portrait badge display for earned module badges; do not introduce another rewards manager or save service.
- Reuse existing success sounds and reveal animations, with reduced-motion treatment. Keep support controls within the current story interface, with large touch targets and readable objective text.

### Implementation order and acceptance

1. Confirm star/reward/help policy and map objectives for all 25 chapters. Audit paid-support migration and old reward records first.
2. Implement save rules and a complete Module 1 Chapter 1 flow as the first visual/behavioral check: preparation → mistake/help/retry → results → replay improvement → chapter selection.
3. Extend the shared chapter interactions and all five hearings using chapter-specific objectives. Verify that progress, original evidence and story continuity survive.
4. Add module-completion badges and final result polish through existing cosmetic controls.
5. Verify clean runs, mistakes, assisted runs, partial/resumed attempts, replay improvement, legacy saves, account switching, duplicate/stale synchronization, reward spending, badge equipping, reduced motion and phone layouts. Keep developer checks local and out of commits. Physical-device and live synchronization acceptance remain explicit release gates.
