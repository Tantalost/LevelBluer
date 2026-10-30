# LEVELBLUE: three-week mobile completion plan

Planning date: 29 October 2026. Proposed implementation window: 30 October–19 November 2026 (21 calendar days).

Status: Gate 3B active. The user approved the Module 2 script/integration boundary and requested new character/background art. Chapter 1 is implemented and locally checked; Chapters 2–5 remain to be implemented. On 30 October the user explicitly deferred phone testing. Gate 3A device/deployment checks remain open; this is a sequencing exception, not a passing result. Later gates still require their completion review and user approval. The deadline is a tested, deployable mobile application, not completion of student recruitment, research data collection or analysis. Dates are time boxes and a feasibility target, not a promise of completion regardless of scope or defects.

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

No percentages are used. Each item is implemented, locally verified, device verified, blocked, or deferred—with evidence attached.

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
7. Review cached/hosted assets, touch layout, sound settings and reduced motion. Final essential art must be integrated before accepting the module; reuse backgrounds/portraits where appropriate.
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
| 5. Keep the Code | Short evidence challenge: explain why the genuine code and accurate details did not make the workflow safe. A legitimate support response confirms the unauthorized attempt was blocked. | Existing rebuttal/evidence cards and reconstruction; new support record introduced before use | Amani keeps control of the account. The suspicious text account is reported; the text operator disconnects in an audience-only cutaway. Coordination remains a developing question, not a guess presented as fact |

Lesson mapping: suspicious SMS/link inspection, code secrecy, familiar sender claims, real-event versus fraudulent instructions, independent verification. Candidate evidence: delivery/status mismatch, real code purpose, copied public detail, attacker-supplied contact, verified support outcome. Red herring: Dan knew the delivery schedule; that access does not identify its sender.

#### Module 3 — Phone Tricks: "Stay on the Line"

Viewpoint: Liza. She knows about the text incident and is determined not to be fooled, making a reassuring caller more persuasive than another obvious threatening message. John helps her review what was actually verified. Existing BKT component: vishing.

| Chapter | Story development | Reused interaction / evidence | Learner decision and resolution |
| --- | --- | --- | --- |
| 1. The Helpful Caller | A supposed account-security worker calls Liza about the recent school scam and sounds patient and professional. | Existing call panel, transcript and claimed-identity card | Identify the claim without treating caller ID, a calm voice or knowledge of the incident as authentication |
| 2. They Know My Name | The caller mentions details that were genuinely available in a club post. Liza's confidence rises. | Compare caller statements with the original source; evidence selection | Distinguish knowledge of a person from permission to access their account |
| 3. Don't Hang Up | A genuine security alert appears during the call. The caller says the code is needed to stop a pending transaction and insists Liza stay connected. | Call/message switching, request inspection, optional pause; accessible choices | Refuse secret sharing and end the caller-controlled interaction; no real call or wallet transaction occurs |
| 4. Call Back, Safely | A second supposed supervisor offers a callback number. Liza instead finds a trusted contact through a known official channel. | Choose independent contact; compare callback transcript and caller's story | Reject confirmation supplied by the same suspicious chain; authorized support contradicts the request |
| 5. The Voice Loses Control | Liza reconstructs the attempted takeover. Sir Rham supplies a verified incident acknowledgement before the evidence challenge. | Evidence-command rebuttal and short timeline; transcript accessible with sound off | Liza secures the account and preserves the call details. The voice operator leaves the masked meeting; the final connection remains |

Lesson mapping: caller-ID limitations, authority and emotional pressure, codes/secrets, ending a call, independent callback verification. Candidate evidence: asserted identity, public information source, actual security-alert purpose, fabricated callback channel, official contradiction. Red herring: Eric called Liza earlier about club expenses; proximity in a call log is not authorship.

#### Module 4 — Fake Stories: "The Perfect Credential"

Viewpoint: Sir Rham. The attacker changes strategy because students are checking messages: impersonate someone authorized to help the whole school. This gives the teacher a believable reason to need verification rather than making him inexplicably careless. Existing BKT component: pretexting.

| Chapter | Story development | Reused interaction / evidence | Learner decision and resolution |
| --- | --- | --- | --- |
| 1. Here to Help | A supposed incident-response coordinator contacts Sir Rham with a convincing appointment and school branding. | Identity/request card; compare appointment with trusted internal schedule | Separate a well-prepared story from independently confirmed authority |
| 2. A Consistent Story | The profile, email and meeting invitation all agree. The coordinator requests a student contact list for urgent protection. | Match claims across records; mark which sources are independently controlled | Recognize that several attacker-controlled sources can repeat the same false identity |
| 3. The Exception | The coordinator claims an urgent exception authorizes roster access and tries to move the discussion to a private chat. | Permission/request comparison; choose a documented independent approval route | Protect student data and refuse an unverified exception; apparent helpfulness does not replace authorization |
| 4. Ask the Real Office | Sir Rham contacts the actual office through an existing directory. The office confirms the claimed person was not assigned and preserves the fraudulent request. | Timeline and verified-response comparison | Identify the unsupported identity and request using evidence the player has actually seen |
| 5. The Mask Holds | An evidence review defeats the claim that consistent branding proves authority. The operator changes tactics instead of obtaining the roster. | Existing hearing layout with a shorter claim set; revised participant dialogue | The school restricts access and shares verified guidance. The Collector's connection remains active; the plot carries into the final delivery attempt |

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

Gate 3A acceptance remains open. On 30 October the user deferred phone testing and explicitly requested the next milestone; Gate 3B can therefore proceed. Device/deployed-account/PvP checks and staff access remain release dependencies. Module 2 Chapter 1 is now implemented; neither Gate 3B nor any later milestone is complete.

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
8. Amani reconstructs the sequence using the existing evidence cards. Correct responses explain the request and verification route, not just award points.
9. Amani: "The message knew something about me. That didn't mean it was speaking for me."
10. John: "And you checked without handing the check back to the person who sent it."
11. Amani: "Great. Now let's investigate who ordered twenty name tags for a nineteen-person activity."
12. Audience-only masked cutaway: the text operator says, "No code. They've reported the contact." That operator's connection closes; Jobert's light stays dark, leaving two active connections. The Collector: "Then stop texting." This foreshadows Module 3 without making the cutaway evidence available to the students.

**Resolution limits:** support confirms this attempt was blocked; the player has not established the text operator's real identity. Amani is a target of impersonation and an attempted takeover, not blamed for the attacker using her public details. The ending does not clear every possible account or promise that codes alone provide complete protection.

**End actions:** Continue to the appropriate module route when its requirements/content are available; Review evidence; Practice smishing through the existing Lessons flow. Until Module 3 is authored, show its honest availability state rather than opening a placeholder story. Retain any legacy Module 3 progress without silently deleting or rewriting it.

### Approved implementation boundary

1. **Existing chapter screen and phone:** retain `SurveyChapterScreen` and its phone/dialogue/overlay hierarchy. Make protagonist, phone behavior and next-chapter routing come from the chapter definition instead of `John`, chapter number and hard-coded `mod_01` strings. Preserve phone signals (`evidence_changed`, `thought_requested`, `phase_finished`, `chat_speaker_changed`) into the current screen controller; only that controller requests persistence. Extend the current phone components for the SMS comparisons; add chapter-specific content/validation definitions rather than duplicate screen scenes. Reuse the confrontation presentation components for the compact evidence review, with Amani's content and no Jobert-specific accusation/admission flow.
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
| Event room, daytime | `output/module2-art/event_room_day_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793339808/levelblue_mod2_event_room_day_v1.png |

Final prompt set (production specification):

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
