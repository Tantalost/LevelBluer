# Deployment module selector

The existing `stage_select` route now uses the shared study-screen shell: a charcoal/slate background, permanently enabled subtle CRT overlay, muted teal accents, and larger DigitalDisco text.

- Dashboard-style profile, rank, threat and credit band; profile and settings remain accessible.
- Compact Upgrades button preserves the skill-tree route.
- Five vertically scrollable operation cards, with explicit lock icons and text.
- A separate briefing panel shows themed, code-drawn signal artwork, lesson preparation, stage availability and prerequisites.
- Open Module stays visible while the briefing scrolls. Selecting an unlocked card retains the original one-tap navigation.
- Module 1 reports explicit clears out of its ten stages. Other modules say stages are coming soon, independently of lesson-based access.

Existing lesson-access checks remain unchanged. First-time Module 1 entry opens
its intro; the saved intro-seen flag or existing Chapter 1 progress sends returning
players to Chapter Select. Other modules retain their stage-list routes. This
screen never awards progression or rewards.

No new bitmap assets or Cloudinary uploads are required. The existing cached profile avatar is reused; module diagrams live in `module_signal_art.gd`.

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_module_select.gd`. Add `-- --render` under a graphical renderer to capture ignored QA screenshots in `frontend/.godot/`.

Checks cover fresh/partial accounts, five module selections, lock rules, navigation destinations, account switching, unchanged progress, touch target sizes and 1280×720, 960×600 and 844×390 layouts. The phone fixture includes simulated safe-area insets.

## Module 1 intro milestone

Module 1 uses John's story-only prologue instead of the old Alex comic.
Three dialogue lines revisit the prize email over the bright, unmodified bedroom
background, with compact cream email evidence on the left. The bottom narration
matches the opening's translucent panel and teal speaker strip.

“Before the morning…”, “A club conversation.”, “A survey invitation.” and
“An unanswered question.” fade individually at screen center, hiding narration.
John then says “I need to figure out what went wrong.” The centered caption
“5 days before the disaster” fades into the title. Captions advance automatically
after a readable hold; the circular button lets players advance sooner.
Chapter timelines and gameplay instructions have been removed.

The ending uses newly generated, dedicated Cloudinary art with John's supplied
facial reference and white school shirt with a green-and-black pocket stripe.
“MODULE 1” and “Email Tricks” remain runtime labels, not baked text.
No PNG is bundled. Skip remains available on first viewing and
leads to the title card. Replay is read-only. Continue opens `module_stages` in
Chapter Select mode for Module 1; other modules retain legacy stage selection.

Typing and title transitions pause on application focus loss/suspension and are
cancelled on exit. Reduced motion, instant text, audio mute and cached/offline art
fallback remain supported. Only Continue invokes the existing intro-seen save;
reading, replaying and skipping to the card do not award progress, evidence or coins.

The module-select verifier now also checks sequential caption fading, the prologue, title, replay, skip,
focus pause, resume, progress invariance and both desktop/landscape-phone layouts.
Cloudinary-environment verification covers late and missing cached intro art.
Use `-- --download-art` with the module-select verifier to fetch the two new
art assets into the normal Godot cache; combine with `--render` for screenshots.

## Module 1 / Chapter 1: The Survey (2026-10-21)

Playable route: Deploy → Module 1 → first-visit introduction/title → Chapter
Select → Chapter 1. Returning players bypass the intro; a Replay Module Intro
button remains available. The existing module_stages screen lists five chapters
in this mode: only The Survey is playable; Chapters 2–5 are clearly coming soon.
Legacy mission lists and assessment data are not repurposed or reset.

Chapter Select now uses an illustrated preview with the existing Cloudinary
night-desk artwork, a readability gradient, short synopsis and progress badge.
A mint Start/Continue/Replay Chapter action stays beneath the preview; Replay
Intro is a separate compact, single-line control. Numbered chapter cards use
muted teal selection borders, sealed/available labels and muted Coming Soon states.
The compact profile and credit header preserves Profile and Settings access.
No new image files, routes, rewards or chapter content were added.

The chapter screen follows Deploy's squared slate terminal theme, not a separate
rounded navy/blue theme. Existing `study_ui.gd` button styling is shared through
`style_button`, including hover, pressed, focus and disabled states. Chapter
numbers are plain type rather than rounded badges; larger card labels and
neutral credit text match the previous screen. The illustrated layout is retained.

Completed Chapter 1 cards retain a green surface even when another chapter is
selected, with a right-aligned COMPLETED badge and explicit accessible status.
The preview's exhibit seal and earned progress bar use the same completion green.
Keyboard focus retains its separate gold outline. These are presentation-only
indicators from the existing saved completion flag, not new reward or unlock logic.
Verification checks completed/unfinished states and badge containment/non-overlap
at desktop and landscape-phone sizes.

The chapter list scrolls independently on landscape phones. Selection fades
respect reduced motion; owned tweens stop on exit or rebuild. Deferred scroll
targets resolve against the latest cards so resize/progress refresh cannot
reference a removed node. Missing artwork leaves a readable navy preview;
late AssetManager synchronization refreshes only its texture. Verification
includes fresh, in-progress, completed, pending and missing-art states at
1280×720 and 844×390; physical-device touch testing is still recommended.

- Day: late arrival, Eric's offer, club group chat, Jobert's caution, Eric's
  evasive answer about his client, then six inbox messages. John responds to
  the three suspicious requests as an authored flashback, not a graded choice.
- Night: sort all six messages (drag/drop or bin buttons), mark the requests
  in the three suspicious emails, use the existing phone's Notepad application
  to record each sender domain, and frame three contextual captures.
- Review and seal three bundles: message captures, domains, and wording/request
  clues. A short envelope animation leads to John's bedtime reflection, then
  chapter completion. Free email domains and spelling errors are explicitly
  supporting context, never proof by themselves.
- Rewards: 100 existing credits, plus 25 for zero sorting mistakes and no hints.
  Completion and the reward are saved together, once per account. Replays
  cannot modify the original exhibit or award again. Chapter 2 access is
  recorded, but Chapters 2–5 and perks are not playable in this milestone.

### Structure and persistence

`survey_chapter.gd` holds authored content, validation and reward constants;
`survey_phone.gd` extends the existing cream phone and emits evidence/thought/
advance signals; `survey_chapter_screen.gd` owns presentation and transitions.
No new autoload or backend endpoint. The tutorial camera's immutable sheet text
is now configurable, with its original default preserved.

`PlayerManager.chapter_progress.mod_01_ch_01` is saved through the existing
account-scoped local/cloud snapshot. It stores the authored content version,
story checkpoint, message IDs, clues, canonical-domain completion, capture IDs,
hint/mistake counters, seal/completion and next-chapter access. Draft input and
real credentials are never saved. Captures render only the simulated message;
images stay in memory, while a resumed review reconstructs the saved message
from its ID and authored version. No camera permission, real email sending,
teacher submission or screenshot upload is involved. The existing backend
snapshot schema allows additional fields; hosted sync has not been live-tested
for this new field. Conflicting simultaneous devices use existing sync rules.

### Presentation and lifecycle

Chapter 1 opens with the anonymous caption “Five days before everything went
wrong.” centered on pure black. John, the location art, dialogue panel and day
heading are hidden for this sentence; Back/Menu remain available. The caption
fades gently and waits for Continue before John's arrival line begins. It uses
separate authored caption metadata, not John's speech, while keeping existing
beat IDs and sentence paging intact. The fade pauses with the menu/background,
stops on exit and has a reduced-motion duration. Late artwork cannot reveal the
cast over the title card. Desktop and landscape-phone checks cover this handoff.

Full-screen school/room art, translucent bottom dialogue, compact teal nameplate,
expression sprites and right-side phone reuse the opening's visual language.
John, Eric and Jobert sheets are Cloudinary/cache assets; uploaded PNG source
copies have been removed from the repository. Missing art leaves the chapter playable; late cache
arrival updates only artwork. No original face photographs were uploaded.

Eric's October 22 face-reference update is archived as
`eric_expressions_v2.png` on Cloudinary (version 1792675006).
The six expressions retain the school uniform; Eric used
512×512 atlas cells with an 8px side inset to exclude neighboring sleeve pixels,
while John and Jobert retain their original row splits.
The previous remote sprite remains available for recovery.

The subsequent body-language pass replaces all three current Chapter 1 cast
sheets with `{john,eric,jobert}_poses_v1.png` at the URLs listed below.
Six facial slots now select complete upper-body poses: listening/thinking,
friendly invitation, nervousness/caution, surprise, doubt, and determination.
Torso turns, shoulders and hand gestures vary; these are visual-novel pose
changes, not skeletal animation. Existing story expression indices still pick
the pose, so saves and dialogue ordering are unchanged. The runtime uses each
sheet's actual gutters and a shared 608×550 logical canvas to preserve hands
and prevent size jumps. Previous expression sheets are archived remotely, not
bundled or downloaded by the game.

Cloudinary source/recovery links (all eight uploads hash-verified against the
removed local originals on October 22, 2026):

| Asset | Role | Remote original |
| --- | --- | --- |
| John poses | Runtime | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675007/john_poses_v1.png) |
| Jobert poses | Runtime | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675007/jobert_poses_v1.png) |
| Eric poses | Runtime | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675005/eric_poses_v1.png) |
| John's night desk | Runtime | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675006/john_desk_night_v1.png) |
| John expressions | Archive | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675007/john_expressions_v1.png) |
| Jobert expressions | Archive | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675006/jobert_expressions_v1.png) |
| Eric expressions v1 | Archive | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675005/eric_expressions_v1.png) |
| Eric expressions v2 | Archive | [PNG](https://res.cloudinary.com/nfd5bhkz/image/upload/v1792675006/eric_expressions_v2.png) |

Prompts remain as lightweight source notes. `john_neutral_v1.png` is retained
because no replacement upload was supplied. Runtime downloads live in
`user://assets`, outside the Git repository, and remain available offline.

Back/Menu, pause, app suspension, reduced motion and text-speed settings are
supported. Input is locked during menus/capture/sealing; navigation cancels
tweens and capture callbacks. Account identity and sign-in state guard writes.
Chapter progress does not update BKT, lesson scores or tutorial completion.

The October 22 readability pass presents one sentence per tap, with larger
32px-base dialogue (minimum 24px physical beside the phone, 28px full width).
Tap during typing reveals the sentence; tap again advances it. Investigation
thoughts use the same paging without advancing the evidence phase. Authored
beat IDs stay unchanged, so old checkpoints remain valid; re-entering a beat
starts at its first sentence. Club messages use separate bubbles. The compact
evidence card shows only the current task/count, with extra instructions hidden
on short screens and hints still available. Sender addresses wrap before @ on
narrow phones to keep the domain readable as a unit.

The Chapter 1 face-to-face conversation pass keeps the cast in fixed stage slots. The current
speaker is fully lit; listeners retain their last body pose at a dimmer tint.
Lighting crossfades respect reduced motion and pause. School/club backgrounds
remain bright. The phone stays hidden until John's final "Can't hurt to ask"
sentence finishes, including a short readable hold with instant text enabled.
During the Club Chat beat, Eric and Jobert have stepped outside: only John is
visible and fully lit, including the lead-in, phone home and Settings return.
Remote senders remain inside chat bubbles/typing indicators rather than becoming
room sprites. Eric's next face-to-face line establishes their return.
Club Chat now types John's scripted drafts into a fixed composer and requires
Send. Eric and Jobert each have a staggered typing indicator before their reply;
bubbles accumulate in scrollable history. No real message is sent. Continue
unlocks only after John's final reply. Menu, backgrounding and phone home pause
the chat clock; returning from Settings preserves its in-memory place. Leaving
the chapter still resumes from the saved story beat, without altering beat IDs.

Chapter 1's final story beat now changes the displayed time to NIGHT before
investigation starts. `story_bg_john_desk_night` shows John seated at his desk,
lit by a warm lamp against a blue night window. This Cloudinary-backed artwork
continues through investigation, evidence sealing and the closing thoughts;
the standing cast layer is hidden because John is already in the composition.
The morning opening artwork remains unchanged. Story beat IDs and rewards are
unchanged. Generation prompt: `output/imagegen/chapter1/john_desk_night_v1.prompt.txt`.
The source PNG is available through the Cloudinary recovery link above.
The retained prompt documents the built-in image-generation references.

Investigation UI polish: the compact task/count/Hint bar sits above the phone
on the right. Mail/Notepad and Capture/Inbox controls live outside the phone.
Messages separate subject/sender metadata from the body. Trace Senders uses a
read-only selectable address plus Select Domain/Copy; Notepad has Paste and
keeps per-message drafts while switching apps. This is a simulation-local
clipboard, cleared on exit/reconfiguration; no OS clipboard is read or written.
BACK and INBOX labels no longer carry arrow prefixes.

Capture validation uses the actual wrapped text height, with a three-logical-
pixel tolerance, instead of demanding empty space below the text. Saved capture
previews use the same canvas size and font metrics as the visible frame, then
crop that region. The shared tutorial capture control receives the same fix.

### Investigation title handoff

After John's final nighttime sentence, a four-second vector overlay replaces the
dialogue and phone controls, retaining the night desk artwork. A layered glass
dossier, cyan corner brackets, orbital traces and scanning lines introduce the
snapping INVESTIGATION / MODE title. The case label and "Every message leaves a
trace." arrive in stages, with gold accents and a restrained progress rail.
Existing transition/ready sound cues respect SFX mute. A source-owned music
duck temporarily lowers the BGM bus without modifying saved volume settings.

The overlay lives inside the existing chapter screen, below the Back/Menu HUD.
Only its completion advances the saved phase from day to sort. Repeated taps
cannot skip it. Menu/background pauses its timeline; leaving cancels it and
restores music. Returning from Settings restarts an interrupted reveal. Reduced
motion replaces the slide, scan, impact and sweep with gentle fades. No new
gameplay phases, assets, scenes or managers are introduced.

### Chapter completion celebration

Completion now uses its own card in the existing screen: animated heading,
exhibit seal, three evidence bundles, earned-credit count-up and wallet total.
Gold coins travel toward the balance while cyan/gold confetti falls. Reduced
motion uses a gentle heading fade and final totals without moving particles.
All counts are display-only: the existing save path still awards credits once.
Replays show zero new credits. Reopening results shows settled totals silently.

Large Next Chapter (disabled, Coming soon) and Upgrades buttons sit above smaller
Modules/Replay actions. Upgrades uses the existing router destination; Chapter 2
content remains unavailable. The original six-second chapter_complete.wav is
baked via bake_game_audio.gd --chapter-complete-only; it honors music/master
volume, pauses with the scene and stops on exit or mute. The background score is
temporarily ducked, then restored. Returning from Upgrades/Settings cannot replay
the payout or the music. No new gameplay controller or reward logic was added.

### Verification

Results chrome has no duplicate header caption, clipped-corner reward shape or
decorative corner brackets. Primary/secondary buttons share a centered grid,
consistent corners and mobile touch spacing. The pause menu is a centered square
with text rows and a blue keyboard/hover selection highlight. Its full-screen
dim backdrop blocks interaction behind the modal; Resume restores HUD focus.

Run `--headless --path frontend --script res://src/tools/verify_survey_chapter.gd`.
Omit headless and add `-- --render` for screenshots in ignored `frontend/.godot/`;
add `--download-art` once to verify/cache the three sprites and night desk from
Cloudinary. Subsequent runs reuse `user://assets` offline; no deleted local PNG
fixtures are needed. A fresh cache without this flag fails with setup guidance.
Tests use in-memory account fixtures and never save chapter progress to disk.

Covers story/inbox gating, sort retries and drop signals, sequential evidence,
chat cue/draft/reply timing, duplicate Send, persistent speaker lighting,
chat pause/home/settings resume, compact composer and incoming-message scrolling,
domain normalization/lookalike rejection, frame touch movement, partial capture
rejection, sealing pause, resume/serialization, clean-work bonus, duplicate reward
protection, replay isolation, invalid saves, account switching, and 1280×720 /
844×390 layouts. Also run tutorial, module-select and cloud-story regressions.
Physical Android keyboard, scrolling/drag feel and background/resume still need
a device acceptance pass. This milestone does not implement Chapter 2.

### Story perks and pre-deployment loadout

The player-facing Upgrades destination is now Perk Collection. It reuses the
slate/mint rectangular cards, circular glowing nodes, selection rail and right
detail panel from the old armory. Chapter selection opens this screen with a
deployment action and two optional slots. Empty loadouts are supported. On small
landscape screens, details scroll and the purchase/equip action remains fixed.
The profile, module menu and chapter-completion shortcut use the Perks label.

Initial permanent unlocks (provisional balance):
- Case Recap: free; once per attempt, only already encountered dialogue.
- Fresh Perspective: 100 credits; one contextual Night investigation hint.
- Cross-Reference: 150 credits; compare already captured messages, reusable.

`story_perks.gd` is a pure policy/data helper, not an autoload. The existing
PlayerManager owns purchases, loadouts and attempt records; the chapter screen
owns the paused assist modal. The policy requires the explicit `story_chapter`
context and known Chapter 1 phases. Checks, checkpoints, research tests and other
contexts are denied. No assessment scoring, BKT updates or automatic evidence
completion is attached to perk activation. Readability/accessibility settings
remain free and outside the perk system. Connections are visual loadout options,
not upgrade prerequisites or ranks.

A chapter attempt snapshots its two-slot loadout. Resuming retains that snapshot
even if the global loadout changes. Activation is saved before help is displayed.
Merely equipping a perk does not mark assistance: actual use or a built-in hint
does. Assisted completion keeps the 100-credit base reward, but not the 25-credit
clean-work bonus. Original clears still award once; replays have separate progress
and records and never overwrite the original clear or award more credits.

Save fields are `owned_perks`, `perk_loadout`, `perk_attempts` and
`chapter_replay_progress`. Each attempt retains ID, chapter/content/perk versions,
equipped IDs, activation events/counts, built-in hint count, timestamps, replay and
completion flags, mistakes, coins awarded and assisted/unassisted/unknown status.
Old completed saves are not retroactively labeled unassisted. Legacy in-progress
runs resume with an empty loadout and unknown tracking, retaining known hint use.
Old tower purchases/ranks are preserved without automatic refunds; the old armory
remains routed separately for legacy tutorial/defeat flows.

The existing backend accepts and stores these fields in its generic player-save
payload; a mocked sync regression verifies retention without assessment events.
They are not yet a researcher dashboard/export dataset. Live hosted sync and
cross-device acceptance were not exercised for this milestone. Separating test
effects does not erase prior learning from hints; study analysis should still
account for assistance exposure and replay attempts.

Verification: `verify_story_perks.gd` checks purchases, limits, frozen loadouts,
save/reload, migration, isolated contexts, reward/replay behavior, account guards,
the three assist panels and 1280x720 / 844x390 layouts. Add `-- --render` to capture
ignored `.godot/perks_*.png` screenshots. Also run `verify_survey_chapter.gd`,
`verify_module_select.gd`, `verify_research_ui.gd` and backend
`tests.test_progress_sync`. These fixtures do not make live purchases or uploads.

### Chapter 2 — The Advisor Email

Chapter 2 is now authored and playable after Chapter 1 completion. Chapter 1's
Next Chapter action and the chapter-select card both open the chapter-specific
perk loadout. Chapter 3 still shows Coming soon, even after access is earned.

The existing `survey_chapter_screen.gd` is now shared presentation, configured by
chapter ID. Each case supplies story beats, task metadata, evidence descriptions,
phase transitions and validation. Both cases use the same dialogue paging,
character lighting, night desk, title animation, pause/settings behavior, perk
modal and completion celebration. Explicit cast lists prevent remote chat members
from appearing in John's room. `advisor_phone.gd` extends the existing chapter
phone, sharing its skin, chat timing and lifecycle; it only adds these activities:

- Compare the earlier and new email side by side by sender, format, wording or
  signature. The matching format is a distractor, not a fourth mismatch.
- Retype the lookalike domain in a local Report to IT form. The sender stays
  visible, the draft persists, and accepted transcription exposes L versus 1.
- Match From, Reply-To and Subject using drag/drop or tap-label/tap-field.

All addresses are fictional `.example` values and the report never sends mail.
Comparison preserves both messages; the domain and raw-header results form the
remaining exhibit context. Knowledge of the club format and Dan's jokes are not
treated as proof. The approved opening and closing are anonymous black captions.
Dan appears only in chat and Sir Rham only through emails; no substitute portraits
are used. Their supplied photos are references for future physical appearances,
not new assets uploaded or copied into the repository in this milestone.

PlayerManager now has chapter-keyed definition, checkpoint, unlock, begin and save
methods. Chapter 1 compatibility wrappers and its old replay field remain intact.
Chapter 2 replays use `chapter_replays[chapter_id]`. Perk attempts include chapter
ID; both validators reject another chapter's perk run. The assessment deny-list
boundary is unchanged: only explicit story contexts and that case's phases work.

Run `verify_advisor_chapter.gd` (optionally `-- --render`) for the full story/chat,
comparison, transcription, header drag/tap, pause, save/reload, perks, sealing,
closing, reward, replay and 1280x720 / 844x390 checks. Existing Chapter 1,
module-select and perk suites cover shared regressions. Screenshots go to ignored
`.godot/chapter2_*.png`. Physical Android keyboard/drag feel and live cross-device
cloud acceptance still require a device pass; no hosted data was changed.


### Chapter 2 presentation polish (23 October 2026)

Visual consistency: refine spacing and hierarchy without introducing a new skin.
Phone investigations retain the shared cream paper, muted-pink header/accent,
ink text, raised beige controls and pixel bezel. The comparison view consumes
the palette in `opening_phone.gd`; it must not become a separate navy/blue UI.

The first incoming advisor email now starts with a tappable notification and the
existing `ui_notification` cue (respects audio settings). Private chat opens through
a pause-aware Contacts scroll and Jobert selection with tap feedback. The shared
chat composer/timing remains unchanged; the private footer no longer claims group
read receipts. Per-sentence pose metadata changes laughter to a smile, then concern.
Chapter-specific night background metadata prevents duplicate standing sprites.

Artwork was generated with the built-in image tool using the existing John sprite
and night desk art as identity/style references. Cloudinary is the runtime source;
no generated image binaries are tracked by Git. Local originals are saved under
`frontend/.godot/chapter2_art/` (ignored cache; Cloudinary is the durable copy).

Final prompts and local filenames:

#### Chapter-select illustration

Local: `frontend/.godot/chapter2_art/chapter2_advisor_cover_v1.png`

Use case: illustration-story. Asset type: 16:9 landscape visual novel chapter-select illustration for Chapter 2 The Advisor Email. Input image: reference for John's exact established face, curly black hair, slim build, white short-sleeve school shirt with green-and-black pocket stripe, and painterly anime/pixel-textured environment style. New scene: John alone in a sunlit school corridor, waist-up three-quarter view, holding his phone near chest level, eyebrows slightly raised and focused as an unexpected email arrives. A subtle envelope notification icon glows on the phone, no legible message text. Preserve his distinctive face and clothing. Face and phone in upper/middle portion, bottom quarter quieter for game title overlay. Cinematic warm daylight against teal shadows; polished narrative illustration. No UI frame, no title, no text, no watermark, no extra people.

#### Night investigation background

Local: `frontend/.godot/chapter2_art/john_bed_night_v1.png`

Use case: illustration-story. Asset type: 16:9 visual novel investigation background. Reference image supplies John's exact face, curly black hair, slim build, illustrated anime style and bedroom continuity (teal curtains, books, plants, dark blue bedding). Create a NEW viewpoint: John lying flat on his back on his bed at night, head resting naturally on pillow, BOTH hands holding his phone raised ABOVE his face, arms bent upward, eyes looking up at the phone messages. Phone SCREEN FACES JOHN, cool screen light clearly illuminates his cheeks, nose, eyes and hands. Three-quarter side view from beside the bed, medium-wide room composition. Keep his recognizable facial features; white school shirt with green-and-black pocket stripe. Midnight blue ambience, faint city lights through window, subtle warm bedside accent, suspenseful but quiet. Frame his face/raised phone around left-middle, keep right and bottom less busy for investigation UI. Anatomically natural hands, exactly two arms. No floating text, no UI, no other people, no watermark.

#### Laughing pose

Local: `frontend/.godot/chapter2_art/john_laugh_v1.png`

Use case: identity-preserve. Asset: one transparent-background visual novel character sprite, no scene, no grid. Reference image is John's existing six-pose character sheet: preserve his exact face, curly black hair, warm skin, slender build, white short-sleeve school shirt with green and black pocket stripes, black belt/slacks, same polished anime illustration. Create ONE new waist-up pose of John genuinely laughing softly at a friend's joke: eyes happily narrowed/closed, eyebrows relaxed, mouth open in a natural laugh with teeth visible, shoulders relaxed, one hand loosely near his mouth, other arm resting naturally. No waving, no worried eyebrows. Frame from hair top to below belt, entire head elbows and hands inside frame, consistent proportions with reference. Transparent background, no shadow backdrop, no text or extra people.

### Chapter 3 — The Payout (23 October 2026)

- `payout_chapter.gd` owns the approved story, fictional URLs, clue explanations, evidence validation and chapter-specific save cleaning. `payout_phone.gd` extends the existing phone presentation; the shared chapter screen continues to own persistence, pause, captions, rewards and transitions.
- Chapter 2 completion unlocks Chapter 3 through the chapter selector and completion CTA. Chapter 4 remains unavailable. Original clears and replay attempts remain separate; completion rewards cannot be collected twice.
- Story includes the payout notification, Eric's private borrowing request, Mika's off-screen doorway exchange, scripted username interrupted by Jobert's call, screenshot sharing and separate closing private conversations. Mika remains off-screen until her visual design is approved. Existing hallway, desk and bed artwork is reused; no additional binary assets are tracked.
- All URLs use reserved `.example` domains and remain inert text. The wallet page is a frozen UI facsimile with hotspots, never a credential form. No web request, external navigation or real credential submission occurs.
- Hold-to-reveal uses a phone-owned one-shot Timer, cancelled on release, pointer/focus exit, pause, view change and scene exit. Expansion supports drag/drop and select-then-tap. Three distinct hotspots unlock the mandatory findings review; five can be inspected. HTTP and the absent secure indicator are explicitly related, while logo/spelling issues are supporting context.
- Correct discoveries use the existing Success green against the cream phone surface. The pixel bezel, pink Mail header, ink text and existing button styling are retained. Compact views hide the redundant phone heading and scroll the content.
- Recap and Perspective support the chapter's story/investigation contexts. Reference still requires two captures; it is not available for this one-message case. Assessments remain excluded and assist usage stays in the attempt ledger.
- Verification: `verify_payout_chapter.gd` checks the authored story, incoming-call pause, private-chat isolation, Timer cancellation, expansion payload validation, unique clues, findings-review gate, save/resume, replay, reward idempotency and assessment exclusion. Existing survey/advisor/module-select/perk suites remain regression gates. Use `-- --render` to capture ignored desktop/mobile previews under `.godot/chapter3_*.png`.

### Chapter 4 — The Prize (24 October 2026)

- `prize_chapter.gd` owns the story, timestamp records, matching evidence pairs, case-note validation and save cleaning. `prize_phone.gd` extends the existing cream/pink phone; the shared chapter screen still owns pause, persistence, rewards and transitions. Chapter 3 completion now unlocks Chapter 4. Chapter 5 unlocks after the completed prize exhibit.
- Continuity is anchored to the original opening: John wakes in the same bedroom that morning, receives the Prize Desk million-peso offer, sees the ten-minute deadline and password demand, and asks offline Jobert for help. Existing wake/reach/claim artwork is reused from Cloudinary; no new image binaries are added. The coffee quote and repeated `recieve` come directly from Chapter 1.
- Investigation pauses that memory before the tap. The HUD says INVESTIGATION rather than NIGHT; it does not introduce a contradictory later evening. Four records are ordered at 08:12:00 (survey confirmation reply), 08:13:45 (Eric last seen), 08:13:50 (Jobert last seen), and 08:14:00 (prize email). The two-minute and ten-second intervals are distinct. Recorded presence status is never presented as proof of authorship.
- Timeline slots and the pattern board support both drag/drop and select-then-tap. Three connections link the shared coffee comment, repeated typo, and ten-second interval. A distinct wrong board pair records one investigation mistake, affecting the existing clean-work bonus but never deducting wallet coins directly. Duplicate wrong pairs, unknown pins and self-links do not stack penalties. Correct findings use Success green.
- The typed case note keeps its timestamp reference visible and accepts normalized factual variants. Partial arrangements, discovered links and report drafts survive save/resume. Invalid saves cannot skip the evidence, seal or scripted-claim gates.
- After sealing, the story returns to the same morning. Claim Prize is explicitly a scripted story action, not an assessment answer or a player mistake. The bounded glitch/fade pauses with gameplay, supports reduced motion and is removed on exit. Late artwork updates preserve the active claim image. The black-caption ending leads into Chapter 5 preparation; rewards are awarded once.
- Recap and Perspective remain story-only assists, recorded in the attempt ledger. Research tests/checkpoints are excluded. Reference still requires two captures and is unavailable in this one-message case.
- `verify_prize_chapter.gd` exercises chronology, private offline messages, timeline swaps, drag payloads, board penalties, pause, draft persistence, report validation, seal/claim gating, reward idempotency, replay and assessment exclusion. `-- --render` writes ignored desktop/mobile previews under `.godot/chapter4_*.png`.

### Chapter 5 — Confrontation (24 October 2026)

- Mobile-only landscape hearing. The Chapter 4 completion button and Chapter 5 selector route to preparation. `confrontation_chapter.gd` owns authored evidence, rounds and save validation; `confrontation_screen.gd` owns the attempt and lifecycle; `confrontation_widgets.gd` supplies the title impact, video-call cast, evidence drawer, comic and reward presentation. Widgets emit intent signals and never award progress themselves.
- Preparation adds two explicitly new story exhibits: the 20-member roster and the fictional IT input-event record paired with John's call log. Earlier chapters' evidence is preserved. The advisor headers do not establish a shared provider with the survey emails. The hearing refutes unsupported accusations; status and spelling are not identity proof. Jobert's explicit admission resolves identity before consequences.
- A correct suspect choice starts credibility at 35; three distinct wrong choices join at 20. Each wrong theory displays a hint and is recorded as assisted. Four rebuttals award 15 each; wrong evidence costs 10. After two errors in a round, the matching record is highlighted and assist usage is recorded. Zero restores that round's starting credibility (minimum 20), retaining earlier rebuttals and error history. The final spelling match adds 20, capped at 100. Completing all required stages is the victory condition, not attaining an exact score after penalties.
- Touch interaction: load a record, then tap the orange weak point. Hold and the evidence drawer pause the statement loop without an assist penalty. No hover, mouse aiming or keyboard shortcuts are required. The equipped-perk menu keeps portrait space available; loadouts are editable during preparation and frozen once the theory stage begins. Perks are denied outside `story_chapter`, including short checks, checkpoints and research tests.
- Closing argument uses six illustrated panels across two pages and eight shuffled candidate frames. Select a frame and tap a slot; moving an existing frame swaps slots. Incorrect sequences remain editable. The completed sequence plays as sentence-paced, on-screen John narration with grayscale flashbacks and dialogue blips. Existing Cloudinary-backed artwork is reused; there are no new tracked image binaries or recorded voice files. Dan, Mika and Sir Rham appear as named camera-off participants rather than invented likenesses.
- The black/red/cream ALL RISE entrance, rebuttal impact, typed final chat, four-light fade and coin count are owner-driven animations. Menus, backgrounding and hidden screens stop progression; reduced motion removes strong motion. Final reward music uses the existing chapter-completion track and respects music settings. Saved state preserves rounds, hints, comic placements and narrative checkpoints. Reopening resumes the current narrative step rather than mid-letter animation. Original rewards are awarded once; replays are separate.
- `verify_confrontation_chapter.gd` covers unlocks, invalid completion, distinct guesses, both starting scores, hints, zero retries, score caps, duplicate rebuttals, comic persistence, replay rewards, assist tracking, background/owner guards and assessment exclusion. `-- --render` writes ignored mobile previews at 720×360, 844×390 and 932×430 under `.godot/chapter5_*.png`. Actual-device touch, cutout and audio QA remains a release check; these are Godot viewport tests, not physical-device results.

### Hearing preparation polish — 25 October 2026

Preparation uses 64px touch actions with Finish pinned below the scroll area. The theory screen uses four dossier cards and a separate confirmation, so selection alone never spends a guess. All four choices fit at 720×360. The original 24-second 80 BPM minor decision score uses bass pulses, low drums, suspended pads and a plucked ostinato, baked offline with `bake_game_audio.gd -- --hearing-only`; the existing BGM decks handle looping, crossfades, music settings and pause ownership. Artwork: `frontend/assets/ui/hearing_mystery_v1.png`. Score: `frontend/assets/audio/bgm/hearing_decision.wav`.

Artwork generated with the built-in imagegen tool. Exact prompt:

> Use case: stylized-concept. Asset type: mobile mystery game hearing preparation illustration. Create a polished grayscale anime visual novel illustration: a single anonymous person shown chest-up in a dark silhouette, face entirely obscured, a large luminous white question mark floating over the face. Smoky gray background with subtle dossier-paper textures, faint geometric evidence connections and dramatic overhead light, charcoal vignette. Center composition, square canvas, strong readable silhouette at small mobile size. Mysterious psychological investigation mood, no horror gore. Detailed ink shading, tasteful halftone grain, restrained cinematic lighting. Only text is the question mark '?'. No UI, no logos, no watermark, no identifiable character, no color accents.

### Cinematic debate flow — 25 October 2026

The existing DebateStage now owns a full-stage virtual hearing backdrop, large active speaker, dim listener tiles, angled close-up, cream name strip, inline orange weak phrase and Truth Bullet ribbon. A 2.4-second round entrance precedes evidence loading. Selecting a bullet releases the discussion; an unanswered claim pauses on John's reflection until Replay Discussion is tapped. Tapping the highlighted sentence provides a generous mobile hit area. The controller alone validates evidence and awards credibility. A correct answer saves once, then runs a 2.2-second evidence flight, word break and John COUNTER cut-in before revealing the explanation. Wrong-answer feedback, assist tracking and chapter reward rules remain shared.

Animations are advanced by the chapter owner's process loop, freezing with pause, backgrounding and Hold. Reduced motion removes speaker slides, projectile travel and scattered words. Scoring rejects input during the entrance, Hold, reflection and counter. Menu and disposal release audio ownership. The original 112 BPM debate score and three short impacts are generated offline by `bake_game_audio.gd -- --debate-only` and use existing audio buses/decks; no runtime synthesis is added. Mobile checks cover 720×360, 844×390 and 932×430, every weak phrase, actual evidence/target signals, duplicate taps, reflection replay, counter pause, mute and save/reward behavior.

Backdrop saved at `frontend/assets/ui/hearing_debate_v1.png`, generated with the built-in imagegen tool. Exact prompt:

> Use case: stylized-concept. Asset type: widescreen background for a mobile anime cybersecurity visual novel debate. A dramatic virtual hearing broadcast set, empty of people: deep navy and near-black layered space, tall angular translucent teal glass panels, luminous cyan frame edges, subtle fine circuit lines, atmospheric depth and overhead shafts of light. A dark central area for a large character sprite, darker lower half for readable floating dialogue. Rightmost quarter contains a tall angled dark portrait window with no face in it. Grayscale halftone and ink shading details, polished anime game background, restrained premium cinematic mood. Palette strictly near-black #050B18, navy #0A1730 #102040, deep teal #0E2A28, subtle cyan #4FE0D4. Landscape 16:9. No text, letters, people, logos, courtroom benches, UI buttons or orange/red accents. This is a virtual remote-hearing environment, not a physical shared room.

### Joining the hearing and hosted artwork — 25 October 2026

- Chapter 5 now waits on a mobile invitation with an `OPEN ZOOM LINK` touch target. This is an in-game meeting transition; it does not open an external meeting or request camera/microphone permissions.
- The existing intro phase owns the complete sequence: connection rings, six staggered remote participants, a brief blackout, then the original `CONFRONTATION / ALL RISE!` reveal and the debate entrance. `JoiningImpact` is a presentation child in the existing widgets script; the screen owns timing and sound. No new scene manager, save phase, or gameplay scoring changes.
- Menu/app suspension pauses the clock. Repeated join taps cannot restart it, and stray taps cannot skip the title. Resizing retains the current beat. Reduced motion keeps the same readable beats without rotating rings, tile slides, or title zoom. Participants without portraits retain camera-off silhouettes.
- `hearing_debate_v1`, `hearing_mystery_v1`, and `john_counter_lettered_v1` now resolve through AssetManager using the supplied versioned Cloudinary URLs. Successful downloads persist in `user://assets/` for later offline use. Missing assets retain functional UI/text fallbacks.
- Removed the three bundled PNGs and their import sidecars, plus the unused `john_counter_v1` source and sidecar (9.07 MiB). The generation prompts below remain as design provenance; the old local image paths are historical.
- Verification extends the existing chapter checks with invitation gating, duplicate taps, menu/background pause, title gating, cached Cloudinary reloads, and rendered normal/reduced-motion mobile captures. Physical-device playback remains a separate manual check.

### John counter artwork — 25 October 2026

The counter cut-in now uses `frontend/assets/ui/john_counter_v1.png`: an original ultra-wide illustration matched to John's existing pose-sheet identity and uniform. Live outlined typography remains separate from the artwork. Aspect-preserving cropping and a brief push-in retain the face and pointing gesture on mobile; reduced motion displays the still image. Generated with the built-in imagegen tool, using `chapter1_john.png` as the character reference.

Exact prompt:

> Use case: illustration-story. Asset type: finished cinematic COUNTER cut-in background for a mobile anime cybersecurity visual novel. Use the attached sprite sheet ONLY as the identity and clothing reference for John; create ONE new wide illustration, not a sprite sheet. Preserve his warm medium-tan skin, thick tousled curly black hair, dark eyes, youthful facial features and white short-sleeved school shirt with green-and-black pocket trim. John occupies the RIGHT HALF: dramatic close-up three-quarter pose lunging forward, fiercely determined eyebrows, mouth visibly open mid-rebuttal, one arm thrust forward with a clear anatomically correct pointing hand aimed diagonally toward the left. Make it energetic and confident, not smiling or threatening physical violence. Sharp ink outlines, polished cel shading, strong foreshortening, cyan rim light, expressive face. Background: sweeping diagonal cyan/teal speed lines, shattered abstract ink streaks, deep navy #050B18 #0A1730 and teal #153B37, cream #F3ECD6 highlights. LEFT 48 percent mostly dark clean negative space for live COUNTER typography added by the game. Ultra-wide landscape composition about 3:1; keep John's entire face and pointing hand in the middle vertical 70 percent for safe mobile cropping. No text, no letters, no logo, no UI, no extra people, no duplicate faces or limbs. Crisp dramatic visual-novel key art, not photorealistic.

Counter lettering revision: `frontend/assets/ui/john_counter_lettered_v1.png` replaces the live COUNTER heading with lettering baked into the illustration. The renderer fits the complete image instead of cropping it, preserving every letter at mobile aspect ratios. The unlettered original remains the source asset. Built-in imagegen edit prompt:

> Edit this exact cinematic game illustration. Add the single word 'COUNTER!' directly into the dark LEFT HALF as huge dramatic custom anime-game impact lettering: uppercase, forward slanted, cream-white #F3ECD6 face, bold deep-navy outline and crisp cyan offset shadow, slight rough ink edges and a sharp underline slash. Make the word immediately legible and powerful, fitting fully in the image with generous safe margins (start at 14% of full image width, end around 53%, place between 43% and 76% of image height). Spell exactly C O U N T E R !, one occurrence, no other text. Preserve John's exact identity, expressive shouting face, pointing pose, fingers, white school uniform, cyan/navy speed-line background, image proportions and composition. Keep his face unobstructed. Typography should feel integrated with the action, not like a plain UI label. Change only by adding the lettering and its immediate shadow/underline.
