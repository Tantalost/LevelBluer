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
