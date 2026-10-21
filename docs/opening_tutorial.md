# Opening and phone tutorial — implementation handoff

## Current milestone: visual-novel item showcase and choice bars (2026-10-20)

Replaces the centered presentation for `choice`, `inspect_intro` and `next_issue` only:

- Left: rounded navy choice bars with neutral cyan circular envelope/delete/inspect icons. All choices use the same emphasis. Hover/focus outlines, pressed shading and staggered fades improve feedback without hinting at the correct answer.
- Right: a rounded item card reuses the existing cream phone at a fixed presentation scale, with a readable caption beneath it. Its preview is non-interactive and fully revealed before input is locked; no miniature Close controls are shown. Entering investigation creates the normal interactive phone.
- Bottom: full-width translucent dialogue stays visible, above the blur/dim layer. The background alone is blurred; narration, choices and the item remain sharp.
- Header and presentation buttons share rounded styling. Back, Skip and Menu remain available. Existing menu/background pause, reduced-motion, evidence, retry and save rules are unchanged.

No new scripts, raster assets, gameplay rules or dependencies. The existing opening screen owns the layout and signals; the tutorial phone owns its static-preview state.

Rendered practice verification and the full headless tutorial regression suite both pass with zero failures. Checks include pointer-driven choices and non-overlapping item/dialogue bounds at 1280×720 and 844×390 landscape. Actual Android GPU blur performance remains a device check.

## Previous milestone: decision staging and completion celebration (2026-10-20)

This revision supersedes the previous tutorial presentation below; it does not change the intro, chapter economy, mastery or campaign rules.

- Reading Mail enables the existing circular dialogue advance **outside** the phone. It opens a centered **“What should I do?”** overlay over the blurred/dimmed scene. Claim Prize, Delete and Investigate appear after a short beat; the background phone cannot accept input.
- Claim Prize opens a staged password page. Tapping its button-like password field animates eight masked characters and highlighted keyboard keys. It is not a LineEdit and cannot collect credentials. Only **Submit** remains within the app after typing; it leads to the failure explanation and Retry returns to the centered decision. Global Back/Skip/Menu remain escape controls.
- Investigate begins with centered **“Read between the lines”**. Mail contains the message, not the old instructional heading or phrase-tapping paragraph. Each tapped clue emits a thought signal to a cream bubble outside the device. The thought types slowly; its button becomes available when the line finishes.
- Three distinct flags unlock **“Alright, what next could be the issue?”**. The marked message fades, then the player continues to a separate sender step. No sender or domain-entry controls are exposed during highlighting.
- Opening sender details reveals the full address. **Open Notepad** returns to phone home, where the Notepad banner and notebook icon are interactive. Notepad has its own content/title and domain field. Close returns home; Mail can be reopened to check the address. Only a validated canonical domain is persisted, never an arbitrary draft or password.
- Existing camera and local evidence submission follow. The freeze caption remains unchanged.
- Successful completion now uses a centered navy/gold panel with a sealed-evidence emblem, success SFX, a 3-second cyan/gold/cream confetti burst, **Continue** and **Replay Tutorial**. Skip is still a separate paused/skipped screen and never celebrates completion.

The existing opening screen owns the presentation layer and bounded Tween; the existing tutorial phone emits thought/evidence/action signals. No additional scripts, image/audio assets, manager, or backend endpoint. Menu/app backgrounding pause presentation and typing; navigation kills old callbacks. Reduced Motion uses dimming/static artwork without confetti or animated key highlights. Audio follows existing mute/volume controls.

Save schema version 6 adds sequential presentation steps while preserving valid version-5 evidence. Physical Android keyboard behavior, GPU blur performance, and touch acceptance remain device checks.

Verification for this revision:

- Rendered `verify_tutorial.gd -- --practice-only --render`: zero failures and no script errors. Covers real pointer input on the decision overlay, password animation gating, failure/retry, staged evidence, notebook icon, Mail/Notepad round trip, camera capture, submission, completion, menu pause, reduced motion, skip, and invalid saved-progress recovery.
- Full headless `verify_tutorial.gd`: zero failures, including opening navigation, existing tutorial safeguards, replay isolation and progress checks.
- Layout captures checked at 1280×720 and 844×390 landscape. Completion actions remain on-screen; screenshot outputs stay in ignored `.godot/`.

## Previous milestone: hands-on rewind tutorial (2026-10-20)

Scope: replace only the onboarding practice. The cinematic intro remains intact. The broader Day/Night chapter loop, coins, perks and chapter progression are **not** implemented by this milestone.

The existing opening screen owns navigation and onboarding persistence. One new strictly typed `tutorial_phone.gd` extends the existing cream `opening_phone.gd`, owns its interactive controls, and emits evidence snapshots, a local image preview, and guarded navigation intents. No extra manager/autoload or backend route.

### Current playable script

1. **That morning, again** — room art, eye-opening and bottom translucent narration. Advance opens the alarm/PIN/home/Mail phone.
2. **One unread message** — read the prize email; opening it does not compromise the account.
3. **Before I act** — three alternative branches, not three sequential quiz questions:
   - **Claim** opens a simulated password-request page. Submit a fixed fictional placeholder (no password input) for the explanatory bad ending. Retry returns to the same decision; Stop goes back.
   - **Delete** is a safe ending, not a mistake. Investigate a practice copy or leave for now; leaving does not falsely mark the investigation complete.
   - **Check the message** opens the investigation.
4. **Event 1 / Look closer** — tap the unexpected reward, deadline and password request; a greeting is not evidence. Open sender details, type only `prize-claim.example`, and save the note. Case/outer spaces normalize; lookalike spelling and a full address do not pass. A hint is optional and recorded. All three flags plus a correctly read domain gate the next event.
5. **Event 2 / Keep the context** — drag a camera frame and its blue resize corner over sender, subject and request. TOOLS switches to directional/resize buttons, framing assistance and Capture; FRAME returns to the sheet. Partial crops cannot advance. Moving the crop invalidates its previous capture/seal.
6. **Build the exhibit** — review the captured image and attachments. Send animates a paper into an envelope, then seals the practice exhibit. This is explicitly a local simulation, not the existing student-feedback or teacher-intervention service.
7. **Practice exhibit sealed** — success SFX and reflection, then advance.
8. **Freeze frame** — existing John/phone artwork freezes under a gentle dark fade; exact centered caption: **“If only John thought of this before....”**. Hold two seconds, then the circular advance becomes available.
9. **TUTORIAL COMPLETE** — Hub and Replay Tutorial. Skip remains a distinct paused/skipped result. No coins, BKT evidence, assessment attempts, upgrades, or chapter unlocks.

### Lifecycle, privacy and compatibility

- Save version 5 stores flags, canonical domain, hint use, crop and captured/sealed metadata. Older click-to-save tutorial progress resumes at the new start; existing account completion flags are not reset. Intro cursor migrations remain intact.
- Camera previews render only an immutable simulated message in a temporary SubViewport; never the entire screen. Textures stay in memory, and a resumed exhibit shows its saved source summary. No screenshot files or arbitrary typed strings are saved/uploaded.
- Back/Skip/Menu/Exit stay available. Menu and app backgrounding pause sending; replacing the phone stops its tweens. Deferred actions verify their source instance and active step. Replay does not write account progress.
- Reduced Motion retains a static sealed envelope instead of movement and gentle closing fades. Existing mute/volume settings apply. No new flashes or vibration.
- Uses existing remote/cached artwork; no new PNG/audio asset downloads or dependencies.

### Verification

Godot 4.7.2 checks use `verify_tutorial.gd -- --practice-only`, `--opening-only`, and optional `--render`. Coverage includes all branches, duplicate flags/sends, exact domain matching, partial crops, touch movement and tap controls, local rendered capture, JSON resume, stale callback cancellation, pause/backgrounding, and replay isolation. Landscape render fixtures cover 1280×720 and 844×390.

Final results: full headless tutorial/navigation regression **0 failures**; rendered opening/tutorial regression **0 failures**; focused rendered practice **0 failures**. Inspected choice, inspection, capture/tools, submission, closing and completion screenshots. `git diff --check` passes (repository line-ending normalization notice only).

Physical Android soft-keyboard placement, touch feel and device background/resume still require a device acceptance pass. The sections below record earlier milestones and do not describe the replaced click-to-save tutorial.

## Artwork correction: Amani's extra hand (2026-10-19)

Removed the hand beneath Amani's mouth in the second victim panel, preserving her phone-holding hand and worried expression. The full 1672×941 montage retains its existing panel boundaries. Both montage and closing now reference `opening_five_victims_v3` at https://res.cloudinary.com/nfd5bhkz/image/upload/v1792420653/five_victims_v3.png. Previous remote versions remain available; no PNG is tracked/bundled.

### Personalized John artwork revision

The montage and closing now use `opening_five_victims_john_v4`, hosted at
https://res.cloudinary.com/nfd5bhkz/image/upload/v1792509486/opening_five_victims_john_personal_v4.png.
John's first panel was regenerated using the supplied facial reference and white
school uniform with green-and-black pocket stripes. The other four characters
and existing panel layout were retained. Only the generated illustration was
uploaded; the source portrait and uniform reference are not bundled or uploaded.
Prior remote artwork remains available. This revision does not replace John's
earlier bedroom/reaching/claim-prize artwork.

Built-in imagegen precise-object edit, guided by the imagegen skill. Workspace preview: `C:/Users/John Lloyd/OneDrive/Documents/level-blue/frontend/.godot/five_victims_v3.png` (ignored). Generated original: `C:/Users/John Lloyd/.codex/generated_images/01a07a9a-7037-7471-bd7f-2e5ae97dbb79/exec-7f7838b6-ba78-44ee-99c2-b33d59c020d6.png`.

Final prompt: “Use case: precise-object-edit. Image 1 is the edit target: LEVELBLUE five-panel victim montage. Make ONE localized correction in the SECOND panel from the left (long-haired woman in pale sweater): remove the extra hand and wrist directly beneath/near her mouth. Reconstruct the obscured neck, sweater neckline and chest naturally with matching pixel-art texture, lighting and fabric folds. Keep her existing lower hand holding the dark blue phone EXACTLY as is. Her other arm is lowered out of view, not near her face. Preserve her face, worried expression, hair, phone, background and pose. Preserve the other FOUR panels unchanged. Preserve original full landscape dimensions/aspect ratio, exact straight panel boundaries and all framing, colors, lighting and style. Do not crop, rearrange, redraw characters, add hands, add text, or add objects. Output the full five-panel image, not an isolated portrait.”

## Previous milestone: Scenes 6–9 (2026-10-19)

Opening only: no module ending, assessment, BKT, account, or progression changes. The optional unclosable popup is omitted.

| Scene | Implemented timing |
| --- | --- |
| 6 — Got You, 6 seconds | Hard music/UI-tail cut; 0.6-second silence; 1.2-second rising buzz, small growing shake and radial red spread from phone. At 1.8 seconds: red-phone art, low impact, two rendered frames of RGB separation. Layered robotic laugh with a lower voice and six decaying echoes. Red recedes and one slow glow breath settles before Advance. |
| 7 — Meeting, 7 seconds | Four masked figures/four lamps; empty central chair in shadow. 8% push-in. Five staggered HAHAHAHA captions with a small overshoot; largest rises from center toward the right edge, partially off-screen. Rising drone and one heartbeat; **no extra laugh**. One lamp dim/recover cycle, then black. |
| 8 — Victims, 9 seconds | John first; five independent reveals 0.7 seconds apart, 5% face push-ins, detuned chimes. Tap completes only the current panel; later audio cues stay synchronized. Accelerating heartbeat; thin red connecting line draws and glows once with a low note. |
| 9 — Closing, 6 seconds + rewind | Image darkens; red line contracts. Whole-word caption reveal ends at 2.8 seconds, cutting heartbeat completely. Two-second caption hold followed by fade to black. Player's Advance triggers a one-second reverse clock/whoosh, then practice and fading-in morning music. |

The existing screen owns one cinematic Tween and an inner presentation-only `CinematicEffects` Control. No new manager or scene file. Existing source-owned AudioManager SFX playback handles five offline-baked mixes (approximately 1.22 MiB source WAVs), generated with `bake_game_audio.gd -- --cinematic-only`. Scene mixes respect SFX mute/volume; morning track respects Music controls. No external voice samples.

Menu pauses timeline and score. Backgrounding freezes the timeline, stops audio, and resumes at its saved offset; returning with Menu open stays paused. Back/Skip/replay/exit cancel callbacks and audio, including rewind. Reduced Motion keeps narrative timing with fades and static artwork: no shake, RGB split, camera zoom, caption overshoot or spinning clock. Android vibration respects its preference and is suppressed by Reduced Motion. No flashing loops.

Two revised Cloudinary assets replace the meeting/montage entries; original v1 uploads remain untouched. Other four opening images retain the user's original URLs:

- `opening_collector_meeting_v2`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1792338328/collector_meeting_v2.png
- `opening_five_victims_v2`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1792338338/five_victims_v2.png

The victim atlas uses measured source edges `[0.0, 0.2177, 0.407, 0.597, 0.785, 1.0]`, mapped into equal-width screen panels without stretching faces. All five remain visible in extra-wide landscape. Downloads were verified through AssetManager. First download requires internet; later playback uses the cache. No generated PNG is bundled or tracked in Git.

### New artwork provenance and prompt set

Mode: built-in imagegen, reference-image edits. The imagegen skill guided continuity-preserving edits and independent panel framing. Ignored previews: `frontend/.godot/collector_meeting_v2.png` and `frontend/.godot/five_victims_v2.png`. Generated originals:

- `C:/Users/John Lloyd/.codex/generated_images/01a07a9a-7037-7471-bd7f-2e5ae97dbb79/exec-f2f007d4-aa3f-420e-ba92-cf224d7c0a24.png`
- `C:/Users/John Lloyd/.codex/generated_images/01a07a9a-7037-7471-bd7f-2e5ae97dbb79/exec-c1774e3d-0474-4e17-bae7-0de0ab8848a7.png`

Meeting prompt: “Use case: precise-object-edit. Asset: LEVELBLUE visual-novel cinematic background, 16:9 landscape. Edit the supplied meeting illustration, preserving its crisp pixel-art/anime rendering, dark navy room and muted red/cyan light. Redesign composition to have EXACTLY FOUR masked figures, two on each side of a table, laughing in distinct poses. Exactly FOUR small pendant lamps, each directly above one figure. Arrange lights near normalized coordinates (0.18,0.20), (0.37,0.17), (0.63,0.17), (0.82,0.20) so game can animate their illumination. Leave a strong empty pool of darkness at table center near (0.50,0.58), suggesting a hidden fifth chair but showing NO fifth person, face, silhouette or mask. Figures and lamps stay inside central 80% for slow push-in. Center table leads viewer into darkness. No central overhead lamp. No text, captions, logos, UI, watermark, extra figures. Final polished background only.”

Victims prompt: “Use case: identity-preserve / illustration-story. Edit this LEVELBLUE five-victim montage into a game animation atlas. Keep EXACTLY the same five characters, facial identities, hairstyles, clothes, emotions and cyber-scam contexts, in SAME left-to-right order: John shocked navy tee holding red phone with prize email background; Amani confused long black hair pale sweater with lost-signal/impersonation messages; Liza crying bun dark tee holding phone to ear with diverted payment/voice call graphics; adult female school staff angry glasses high bun beige shirt lanyard holding unauthorized student-list document; male classmate sad wavy black hair light hoodie holding phone with free gift and locked-account background. Change ONLY the panel geometry and framing: five EXACTLY EQUAL WIDTH vertical rectangular panels filling a 16:9 landscape image, perfectly straight vertical boundaries at 20%,40%,60%,80%. No angled/slanted separators. No outer margin or gutter, no text/captions/watermarks. Each person's face centered horizontally in their own panel near 47% image height; all five heads fully within their panels with breathing room for 5% face push-in. Crisp pixel-art/anime rendering and dramatic navy/warm lighting as reference. Each panel must be a complete self-contained illustration suitable for independent rectangular cropping. Preserve all five cause-in-background storytelling elements.”

### Verification

Passed on Godot 4.7.2: full tutorial regression, opening-only rendered regression, and game-audio suite; all report zero failures. Final rendered runs have no stderr warnings/errors. Inspected 1280×720 and 844×390 landscape captures. Checks include menu/focus interruption, rewind cancellation, reduced motion, source-owned audio, exact 0.6-second initial silence and no heartbeat tail after 2.8 seconds. Replay/account state remains unchanged. `git diff --check` passes (only the repository's LF/CRLF normalization notice).

Physical Android haptics/touch, background-resume on device, and subjective loudness/mix still need a device acceptance pass. The four-lamp payoff in Module 1 is not implemented in this opening-only milestone.

## Previous milestone: hosted opening art and meeting captions

The remaining sections are historical implementation/provenance notes. Where timing, art versions or reduced-motion behavior differ, the current milestone above supersedes them.

All six opening PNGs now come from the supplied Cloudinary `v1792317115` URLs in `AssetManager._ui_catalog()`. The data file retains the `room_art`, `art_path`, and `reveal_art` field names, but their values are AssetManager IDs (`opening_<filename_without_extension>`), not resource paths. The existing startup catalog sync downloads and version-caches them under `user://assets/`; opening rendering only reads that cache. A receiver-owned `sync_finished` connection updates the current scene without replaying animations or applying an old scene's art.

Removed six project PNG files and their six `.import` sidecars (11,824,340 bytes total). Cloudinary copies remain the recovery source; generated originals were not deleted. This reduces repository/export size, not the eventual device cache size. Internet is needed for a first uncached download; later offline visits use cached art. Missing art clears stale textures and shows a scene description, with Back/Skip/Menu still available. No downloader, relaxed-TLS behavior, or backend code was added by this change.

The masked meeting now has five cream “HAHAHAHA” captions distributed around the composition, revealed sequentially with a small scale-in. There is no flashing loop. Menu pauses the existing cinematic timeline; navigation cancels it. Reduced Motion shows all captions immediately without scaling. Captions are hidden on the next scene.

## Follow-up milestone: morning audio and phone polish

- Original 0.72-second alarm plays with the eyelids closed. At 0.82 seconds, a soft thump starts the eye-opening reveal and narration. Advance waits for the reveal; Back/Skip/Menu stay available. Reduced Motion retains the short audio sequence without eyelids or blur.
- A quiet, original 24-second / 80 BPM morning loop accompanies the room, phone and practice scenes. It fades out for the dark ending. The reaching-phone illustration triggers a short cloth/shuffle cue.
- Existing AudioManager decks handle music; its source-owned SFX player handles cues. Opening menu pauses music/timelines and stops one-shot cues. Resume does not replay old sounds. Navigation cancels owned audio/tweens; mute, volume and application focus are respected. Speech-blip and instant-text preferences do not mute these environmental cues.
- The opening-only phone keeps its cream portrait bezel and enlarged/cropped Mail view. Home shows a clickable unread banner and numbered Mail badge; both clear after reading. Email has a larger subject, compact sender/time card and separately spaced body. Scrolling remains inside the device; Close returns home without advancing the story. No campaign phone redesign or extra apps were introduced.
- Assets are generated offline with the existing `bake_game_audio.gd -- --opening-only` entry point. Four 22.05 kHz mono WAVs total approximately 1.1 MiB; no synthesis runs during gameplay for these cues/music, and no external samples or dependencies were added.

Regression coverage includes alarm/thump ordering, pausing both before and during eye-opening, reduced motion, cue/music mute and routing, unread state, internal scrolling, replay isolation and both landscape layouts. Physical Android swipe, interruption behavior and subjective speaker-volume audition remain device acceptance checks.

Earlier local-art paths and generation prompts below are historical provenance, not current runtime dependencies.

Milestone scope: post-login presentation and onboarding only. This does not rewrite any module story, assessment, scoring, authentication, BKT calculation, or stage gate. Previous uncommitted navigation work was preserved.

## Implementation

- Existing Router selects `opening` when login/password-change/loading routes request the dashboard for an account that still needs onboarding. Existing completed/skipped accounts retain the dashboard route.
- `StudentOpening` extends BaseScreen. Full-screen aspect-preserving artwork is a root layer behind the safe-area interface, not a row in the workspace. Back/Skip/Menu float above it. A translucent navy bottom dialogue overlay has a cyan speaker strip and an embedded circular advance prompt. The existing action footer remains only for interactive practice actions. A local modal menu sits above everything. Workspace-only shake never moves Container-managed children or navigation controls. Longer dialogue remains scrollable; interaction controls stay in the workspace, not mixed into narration.
- Narrative dialogue reveals at 45 characters/second. Tapping the dialogue reveals the whole line without advancing; the circular prompt appears only after completion and gently pulses. Practice instructions are immediate and never gate evidence/response controls. Reduce Motion makes narrative text immediate and the prompt static. Menu pauses typing and stops the prompt animation; Back/Skip/replay/exit cancel old text and prompt tweens. A 250ms guard absorbs duplicate advance taps.
- John’s intro progresses through the illustrated room wake-up, reaching-phone shot, existing gameplay phone with an animated dummy PIN, unread email notification, internally scrollable email, Claim Prize action, illustrated tapping shot, red takeover / Got You phone, masked meeting, five-victim montage, and closing caption / fade to black. Email and claim beats cannot be bypassed by Continue. No credentials are entered or collected and no external link is opened. Back/Skip/Menu remain available during the unlock animation.
- `opening_phone.gd` is a visual subclass of the existing `story_phone.gd`, isolated from campaign/investigation phones. It uses a 0.52-width/height portrait cream pixel bezel, blue/lavender wallpaper, colorful code-drawn app icons and dock. Morning Alarm is dismissed explicitly before the dummy PIN animation. Mail enlarges to a cropped upper-device view with coral header, internally scrollable cream content, and a neutral Close button below; Close animates back to the portrait home screen. Only Mail is interactive; other icons are decorative. No new raster downloads, account state, or app subsystem were added.
- During phone beats a root-level clipped phone host occupies the right side; the existing translucent dialogue stays bottom-left. The phone is outside the workspace VBox so its height is not reduced by dialogue. Menu pauses PIN/zoom tweens and blocks actions; replacement/exit kills them and frees the host. Deferred action signals verify their source instance before advancing. The separate evidence tutorial remains unchanged.
- Opening data version 4 migrates version-1/2/3 resume and Back cursors after inserting the search/claim shots and merging the victim previews. Completion, skip, clues and learning records are unchanged.

### Claim artwork provenance

Generated using the built-in image-generation tool with `john_reaching_phone_v1.png` as the continuity reference. Saved asset: `frontend/assets/story/john_claim_prize_v1.png`. The imagegen skill guided reuse of existing art and a consistent first-person composition; no new runtime image service was introduced.

Prompt: “Use case: illustration-story. Asset: a single landscape 16:9 pixel-art cutscene background for LEVELBLUE. Input image 1 is a continuity reference, not a UI screenshot. Create the NEXT shot of the same student John in the same bedroom: first-person camera now looking down at the black smartphone HELD upright in his left hand over the navy bed blanket, while his right index finger visibly touches a cyan rectangular button on the screen. Both hands medium-brown skin like the reference, natural anatomy. Close-up hands and phone are the main focal point in the upper-middle of the frame; keep them above the bottom 30 percent where the game overlays dialogue. Phone screen has an abstract email layout with a few short neutral lines and a cyan button, no readable text or currency or logos. Preserve the same crisp detailed pixel-art style, warm morning sunlight, teal curtains, wooden desk, closed laptop, backpack, wooden bedside table and plant in the softly simplified background. A different closer camera composition from the reference, unmistakable act of tapping a phone rather than reaching toward it. Navy and muted teal shadows, warm cream light. Do not show John's face, another character, extra hands, interface overlays, speech bubbles, watermark or borders. Full-bleed finished game artwork.”

### Unchanged onboarding behavior

- Tutorial: wake → notification → message → Inspect → clue detail → Save clue → Binder → response. Four distinct clues are available; three are required for the practice completion path. Ignore/report/delete avoid the link. Following the link always leads to explanatory retry, even after inspection. No credential collection, external link opening, real reporting, or rewards occur.
- Intro Skip enters the tutorial. Tutorial Skip and menu Skip Opening show one controls-summary screen before the hub. Back revisits navigation history, including across the intro/tutorial boundary; Back at the beginning opens the menu. Menu also has Resume, Replay Intro, Exit Game, and Reduce Motion.
- Settings adds Replay Intro; Replay Tutorial now opens phone practice. The previous defense tutorial remains available in code through `Router.start_defense_training()`; combat assets and logic were not removed.
- Exit uses the existing application-level confirmation and local flush followed by `SceneTree.quit()`. It does not log the account out.
- Per-account `onboarding_state` stores part, step, intro cursor, separate statuses, bounded Back history, inspected clue IDs and saved clue IDs. Completion/skip mirrors existing tutorial flags to release the existing dashboard gate, never to clear lessons. Existing SaveService transport/retries are unchanged. The existing backend accepts extra snapshot keys.
- Replay from Settings keeps a session-only copy: no onboarding, reward, learning, or mastery writes. An interrupted normal session resumes from its local/cloud snapshot. If the app closes at the controls summary, that summary is resumed; final completion/skip is committed when Go to Hub is pressed.

## Authoring / placeholders

Phone integration verification: full tutorial regression suite and rendered opening checks at 1280×720 and 844×390. Checks cover alarm dismissal, portrait aspect ratio, animated unlock pause/resume, reduced motion, internal wheel scrolling, 20-physical-pixel email text, phone/dialogue non-overlap, pointer-driven Close and Mail reopening, action gating, duplicate claim presses, cursor migration, and replay/save isolation. The synthetic wheel test releases its wheel event before testing a subsequent pointer click. A physical Android swipe and lifecycle pass remains manual acceptance work.

Edit `frontend/data/student_opening.json`:

- `cast`: John, Amani, Liza, The Collector, and clearly marked staff/classmate name placeholders. All new story text and character names are here.
- `message.channel`: `email` (current default) or `text`. Labels, sender, body and destination are editable in the same file. Update the related clue text when changing message details.
- `panels`: retained character/emotion/scam notes from the earlier individual previews; their SVG placeholders are no longer displayed in the opening. The generated five-panel image replaces those previews.
- `intro`: ordered narrative beats, their title/text/speaker and visual treatment.
- `intro[].art_path` and `room_art`: AssetManager IDs for version-cached Cloudinary shots. They work offline after a successful download; they are not generated at runtime.
- `tutorial`, `responses`, `clues`, `ui`: prompts, response explanations, Binder content, navigation labels.
- `after_intro`: defaults to `tutorial`; another value currently bypasses practice to the summary/hub. A direct Module 1 route is not enabled: the approved learning entry/gates remain unchanged.

Remaining authoring decisions: the staff member’s name, classmate’s name, and whether the prize should arrive by email or text. The opening has generated phone/meeting/montage art, an original synthesized robotic laugh, and the original morning audio above; no recorded voice acting was added. The procedural silhouette remains only in the separate practice failure screen.

Motion: full-screen artwork-only eyelid open/close/open with brief four-sample focus blur, a small positive workspace lift, short workspace shake, and one muted red field (no strobe). The eyelid layer is below the UI, so navigation remains available. Reduce Motion suppresses these strong effects and haptics. Audio respects AudioManager mute/volume controls. Vibration checks the existing vibration setting and Android platform. No sound is required to understand the story. Existing touch scaling supplies readable text and approximately 48px physical button targets, including the circular advance prompt; scroll areas handle longer copy without moving Skip/Menu/footer off screen.

## Files changed in this milestone

- `frontend/src/autoload/player_manager.gd`: presentation snapshot, reset/load/save support, onboarding eligibility.
- `frontend/src/autoload/screen_router.gd`: opening route, post-login destination selection, replay actions; retained legacy drill entry.
- `frontend/src/ui/screens/settings/settings_screen.gd`: Replay Intro action.
- `frontend/src/tools/verify_tutorial.gd`: opening acceptance/regression fixtures and rendered captures; retained defense-drill tests.

## Files added

- `frontend/data/student_opening.json`
- `frontend/src/ui/screens/intro/student_opening.gd` and Godot `.gd.uid`
- `frontend/src/ui/screens/intro/student_opening.tscn`
- `frontend/assets/story/comic_panel_amani_placeholder.svg`
- `frontend/assets/story/comic_panel_liza_placeholder.svg`
- `frontend/assets/story/comic_panel_staff_placeholder.svg`
- `frontend/assets/story/comic_panel_classmate_placeholder.svg`
- The four SVG `.import` descriptors generated by Godot.
- `frontend/assets/story/john_room_wake_v1.png` and `john_reaching_phone_v1.png`, with their Godot `.import` descriptors.
- This handoff document.

## Acceptance and verification checklist

Results: the full tutorial/onboarding, dashboard, Intel navigation, and learning-record suites passed with zero assertion failures. The isolated rendered onboarding suite also passed at 1280×720 and 844×390. Shader/tween runtime issues found during development were corrected; final checked runs had no shutdown audio-resource warnings. `git diff --check` passed (Git still reports existing line-ending normalization notices).

| # | Check | Verification / limitation |
|---|---|---|
| 1 | Fresh login → ordered intro → tutorial | Router login-to-home fixture and ordered scene traversal; no live credentials used. |
| 2 | Back and Skip remain available | Intro/tutorial history, cross-boundary Back, first-step menu, summary Back, and persistent header checked. |
| 3 | Resume/Skip Opening/Replay Intro/Exit | Menu actions checked. Exit still uses the existing quit/flush implementation; actual Android process closure requires device testing. |
| 4 | Returning users bypass onboarding | Completed/skipped legacy flags, new presentation status, and account reset/round-trip checked. |
| 5 | Both replay entry points | Router/Settings entries checked; replay snapshots compared for zero account changes. |
| 6 | Both decision outcomes | Unsafe link before/after inspection, retry, insufficient clues, three unique saved clues, and all safe responses checked. |
| 7 | Reduced motion | No shake tween or eyelid/focus overlay in reduced mode; sound-independent copy remains visible. |
| 8 | Offline persistence and later sync | Snapshot serialization/account isolation checked; existing local-first save queue reused. Real offline disconnect/reconnect and hosted round-trip remain manual acceptance checks. |
| 9 | Data-driven channel/cast | Email/text label switch tested; cast and all four artwork paths resolve from JSON. No new character names in scripts. |
| 10 | No learning-system changes | Opening account fixtures compare every save field except onboarding flags/state; no assessment, BKT/scoring, backend, or stage-structure implementation changed. |

Regression commands (from project root with Godot available):

```powershell
godot --headless --path frontend --script res://src/tools/verify_tutorial.gd
godot --headless --path frontend --script res://src/tools/verify_tutorial.gd -- --opening-only
godot --headless --path frontend --script res://src/tools/verify_dashboard.gd
godot --headless --path frontend --script res://src/tools/verify_intel_navigation.gd
godot --headless --path frontend --script res://src/tools/verify_learning_records.gd
```

For screenshots use the opening-only command without `--headless` and add `--render` after `--`. Captures are written under `frontend/.godot/opening_*.png` (ignored by Git), including 1280×720 and 844×390 landscape views. Automated tests intentionally do not persist a real account or submit learning events.

Before shipping: test a newly provisioned student after mandatory password change, exit/relaunch while offline, reconnect and verify the snapshot on a second device, both Android Back gestures, mute/vibration on a physical device, and accessibility scaling/notches. Reading duration is user-controlled; the requested 60–90s intro and 2–3min tutorial need student usability timing. No release APK or hosted deployment was produced.

## Generated bedroom artwork (visual revision)

Created with the built-in image-generation tool, using the imagegen skill. The second image used the first generated image as its continuity reference. Originals remain in the generator output folder; the game consumes these workspace copies:

- `frontend/assets/story/john_room_wake_v1.png`
- `frontend/assets/story/john_reaching_phone_v1.png`

Visual revision verification: full tutorial regression and isolated opening/render suites pass with zero failures. Room and reach shots were inspected at 1280×720 and 844×390; the translucent dialogue overlays the full-screen artwork and the circular advance remains inside the dialogue. New tests cover routed dialogue clicks, natural typing completion, rapid duplicate advances, pause/resume, static reduced-motion prompts, full-screen art bounds, and legacy cursor migration. Replay isolation, clue collection and safe/unsafe response paths remain covered. No physical Android export has been tested for this revision.

Final prompt — room:

> Use case: illustration-story. Asset type: landscape 16:9 background art for LEVELBLUE, a pixel-art cybersecurity learning game, not a UI mockup. Create a single full-bleed establishing shot: first-person view through John's eyes as he wakes in his modest student bedroom in the Philippines at early morning. View from his pillow looking across a rumpled deep navy blanket in the foreground into the room. A simple study desk with closed laptop, notebooks and school backpack across the room; a window with teal curtains and soft warm morning light; a small wooden bedside table immediately beside the bed on the right with a dark smartphone lying face up, its screen only a faint cyan glow with no readable notification. The phone is secondary, the ROOM is the subject. Cozy believable lived-in student space, not a sci-fi command center. Detailed crisp pixel-art adventure-game environment, deliberate visible pixel clusters, tasteful dithering, polished cinematic light, navy #050B18 and #102040 shadows, muted teal #153B37, cyan #4FE0D4 accents, cream morning highlights. Wide landscape composition, cohesive perspective; lower quarter quieter for an in-game dialogue overlay. No visible face, no third-person character, no other people, no text, no logos, no watermark, no borders, no interface or speech bubbles. This is the first of two continuous camera shots; remember the room layout for the next image.

Final prompt — reaching for the phone:

> Use case: illustration-story. Asset type: second standalone landscape 16:9 game cutscene background. Input image 1 is the continuity reference: preserve exactly its pixel-art rendering, bedroom furniture/layout, navy blanket, wooden bedside table, teal curtains, morning sunlight and colors. Generate the NEXT camera shot, not a duplicate: first-person John turns and leans to the RIGHT looking for his buzzing phone. Camera is closer and tilted slightly downward toward the same bedside table. His ONE natural medium-brown right forearm and hand reaches from the lower left across the navy blanket toward the smartphone on the bedside table, fingertips about to reach it, natural five-finger anatomy. The same black phone glows soft cyan with a single blank notification rectangle but absolutely NO letters, icons with text, currency, prize or words. Phone and reaching hand form the main readable focal action in the middle of the frame, above the bottom quarter reserved for dialogue. Same notebook stack, plant and curtain recognizable in background; background desk remains spatially consistent as seen from this closer rightward viewpoint. Polished detailed pixel-art adventure scene, deliberate pixel clusters, no photorealism. Full-bleed image, no borders, no collage, no UI, no speech bubble, no text, no watermark, no logos. No visible face, no third-person view, no other people. This should unmistakably tell the visual story of searching for and reaching for a phone from bed.

## Remaining old-name inventory

This is an audit of matching source/content/documentation text, not a rename. It includes dialogue, lesson/pretest content, voice and art identifiers, legacy tutorials, tests, and docs. Keep identities, asset keys, and tests coordinated in the later rename milestone. Case-insensitive search included `Alex`, `Leah`, `Mia`, `Ms. Reyes`, `ms_reyes`, and `Security Assistant`. Generated `.import`/`.uid`/binary translation files and ignored caches are excluded; regenerate generated resources after a future rename. Line numbers below refer to the inspected working tree.

### `backend/tests/test_decision_scenarios.py`

Matches: Leah, mia.

Lines: 571, 572, 860, 1082, 1084, 1090, 1337, 1338.

### `docs/gameplay-stage-one-rollout.md`

Matches: Mia, Security Assistant.

Lines: 256.

### `docs/signal_intro_design.md`

Matches: Alex, Mia.

Lines: 13, 14, 54, 60, 64.

### `frontend/assets/story/ARTWORK.md`

Matches: Alex, Leah, Mia, ms_reyes, Ms. Reyes.

Lines: 5, 11, 13, 44, 45, 46, 49, 55, 56, 57, 61, 63, 65, 67, 69, 71.

### `frontend/assets/ui/level_blue_theme.tres`

Matches: mIa.

Lines: 35.

### `frontend/content/ui_strings.csv`

Matches: Alex.

Lines: 89, 90, 91, 92, 126.

### `frontend/data/decision_scenarios.json`

Matches: Alex, Leah, Mia, Ms. Reyes, Security Assistant.

Lines: 11, 16, 24, 29, 30, 31, 32, 33, 36, 37, 38, 41, 44, 45, 64, 66, 67, 70, 71, 72, 73, 74, 75, 76, 78, 94, 100, 103, 105, 110, 125, 127, 128, 131, 132, 133, 134, 135, 136, 137, 138, 140, 145, 151, 154, 156, 161, 178, 179, 182, 183, 184, 185, 186, 187, 188, 190, 192, 201, 206, 211, 233, 238, 243, 244, 248, 255, 260, 265, 270, 277, 284, 289, 301, 304, 309, 315, 319, 324, 329, 334, 344, 349, 352, 354, 370, 375, 434, 439, 440, 443, 445, 449, 454, 459, 464, 466, 468, 474, 479, 484, 500, 505, 515, 536, 547, 548, 564, 565, 569, 573, 579, 584, 589, 594, 599, 601, 603, 612, 614, 619, 635, 640, 650, 671, 683, 692, 694, 705, 707, 718, 723, 741, 746, 751, 756, 761, 762, 768, 773, 778, 783, 788, 795, 802, 807, 808, 819, 822, 826, 832, 837, 842, 847, 852, 857, 862, 864, 865, 872, 875, 877, 882, 898, 899, 903, 913, 934, 944, 945, 946, 959, 962, 963, 967, 972, 973, 978, 982, 983, 987, 992, 997, 998, 1002, 1007, 1009, 1017, 1022, 1027, 1043, 1044, 1048, 1079, 1091, 1107, 1112, 1113, 1117, 1122, 1127, 1132, 1137, 1142, 1147, 1152, 1167, 1170, 1172, 1188, 1193, 1207, 1236, 1245, 1247, 1291, 1292, 1293, 1296, 1313, 1331, 1332, 1336, 1341, 1346, 1351, 1358, 1363, 1368, 1373, 1378, 1385, 1392, 1397, 1413, 1418, 1424, 1428, 1429, 1433, 1438, 1443, 1448, 1453, 1463, 1466, 1468, 1473, 1515, 1523, 1528, 1553, 1563, 1568, 1573, 1578, 1583, 1588, 1593, 1603, 1606, 1608, 1613, 1655, 1663, 1668, 1693, 1698, 1708, 1713, 1718, 1723, 1728, 1733, 1738, 1744, 1749, 1754, 1796, 1811, 1816, 1833, 1835, 1879, 1880, 1885, 1892, 1897, 1919, 1921, 1964, 1969, 1974, 1979, 1984, 1991, 1996, 2001, 2006, 2013, 2020, 2025, 2035, 2058, 2062, 2067, 2073, 2077, 2082, 2087, 2092, 2097, 2099, 2100, 2101, 2107, 2112, 2117, 2143, 2149, 2153, 2157, 2164, 2170, 2178, 2183, 2204, 2208, 2213, 2223, 2228, 2233, 2238, 2243, 2245, 2247, 2253, 2258, 2263, 2289, 2306, 2310, 2317, 2325, 2330, 2355, 2360, 2370, 2375, 2380, 2385, 2390, 2393, 2394, 2400, 2405, 2410, 2457, 2464, 2468, 2475, 2482, 2487, 2516, 2561, 2566, 2571, 2576, 2581, 2588, 2593, 2598, 2603, 2608, 2615, 2622, 2627, 2635, 2648, 2668, 2673, 2674, 2677, 2683, 2688, 2693, 2698, 2703, 2707, 2713, 2716, 2718, 2723, 2732, 2780, 2787, 2799, 2804, 2805, 2829, 2834, 2844, 2849, 2854, 2859, 2864, 2868, 2874, 2877, 2879, 2884, 2937, 2945, 2950, 2951, 2975, 2980, 2990, 2995, 3000, 3005, 3010, 3012, 3013, 3020, 3023, 3025, 3030, 3060, 3077, 3091, 3096, 3097, 3125, 3170, 3175, 3176, 3180, 3185, 3190, 3197, 3198, 3202, 3207, 3212, 3219, 3226, 3231, 3241, 3244, 3246, 3253, 3258, 3273, 3278, 3288, 3293, 3298, 3303, 3308, 3312, 3318, 3321, 3323, 3328, 3377, 3385, 3390, 3415, 3420, 3430, 3435, 3440, 3445, 3450, 3460, 3465, 3468, 3470, 3542, 3547, 3572, 3577, 3578, 3581, 3582, 3587, 3592, 3597, 3602, 3607, 3610, 3617, 3622, 3625, 3627, 3636, 3640, 3669, 3670, 3685, 3690, 3719, 3721, 3764, 3769, 3774, 3779, 3784, 3791, 3796, 3801, 3806, 3811, 3818, 3825, 3830, 3840, 3862, 3877, 3882, 3892, 3897, 3902, 3907, 3912, 3915, 3916, 3922, 3927, 3932, 3975, 3993, 4000, 4005, 4030, 4035, 4041, 4045, 4050, 4055, 4060, 4065, 4068, 4069, 4075, 4080, 4085, 4132, 4139, 4147, 4152, 4177, 4182, 4192, 4197, 4202, 4207, 4212, 4215, 4216, 4222, 4227, 4232, 4265, 4280, 4286, 4294, 4299, 4328, 4330, 4373, 4378, 4383, 4388, 4393, 4400, 4405, 4410, 4417, 4424, 4429, 4438, 4457, 4471, 4476, 4481, 4486, 4491, 4509, 4514, 4519, 4524, 4542, 4547, 4553, 4557, 4562, 4567, 4572, 4577, 4579, 4580, 4581, 4587, 4592, 4618, 4623, 4634, 4638, 4645, 4651, 4659, 4664, 4689, 4694, 4700, 4704, 4709, 4714, 4719, 4724, 4734, 4744, 4765, 4785, 4805, 4810, 4835, 4840, 4846, 4850, 4855, 4860, 4865, 4870, 4874, 4880, 4885, 4911, 4944, 4952, 4957, 4983, 4996, 5071, 5076, 5081, 5086, 5087, 5091, 5092, 5096, 5103, 5108, 5113, 5118, 5123, 5130, 5137, 5145, 5188, 5193, 5200, 5205, 5210, 5234, 5238, 5243, 5248, 5254, 5258, 5308, 5313, 5331, 5335, 5340, 5345, 5401, 5406, 5424, 5428, 5433, 5438, 5443, 5503, 5508, 5531, 5544, 5647, 5648, 5652, 5657, 5662, 5667, 5672, 5679, 5684, 5689, 5694, 5699, 5706, 5713, 5721, 5760, 5765, 5772, 5777, 5778, 5782, 5806, 5810, 5815, 5820, 5825, 5902, 5907, 5930, 5934, 5939, 5944, 5949, 6026, 6031, 6036, 6054, 6058, 6063, 6068, 6073, 6135, 6150, 6155, 6160, 6183, 6196, 6207, 6208, 6209, 6212, 6214, 6217, 6219, 6319, 6320, 6324, 6329, 6334, 6339, 6344, 6351, 6356, 6361, 6366, 6371, 6378, 6385, 6393, 6432, 6437, 6444, 6449, 6454, 6482, 6487, 6492, 6497, 6501, 6526, 6535, 6537, 6538, 6539, 6546, 6560, 6564, 6572, 6574, 6579, 6582, 6584, 6587, 6606, 6611, 6616, 6621, 6625, 6659, 6661, 6663, 6667, 6684, 6698, 6730, 6735, 6740, 6745, 6750, 6756, 6760, 6762, 6779, 6790, 6791, 6792, 6796, 6813, 6817, 6827, 6860, 6873, 6878, 6887, 6894, 6998, 7003, 7008, 7013, 7018, 7025, 7030, 7035, 7040, 7047, 7054, 7111, 7116, 7117, 7123, 7128, 7133, 7138, 7166, 7171, 7176, 7181, 7211, 7232, 7259, 7291, 7296, 7301, 7306, 7353, 7370, 7384, 7394, 7416, 7421, 7426, 7431, 7443, 7456, 7478, 7509, 7542, 7555, 7560, 7574, 7581, 7596, 7708, 7713, 7718, 7723, 7728, 7735, 7740, 7741, 7745, 7750, 7757, 7764, 7822, 7827, 7834, 7839, 7844, 7849, 7877, 7882, 7887, 7892, 7939, 7970, 7975, 8002, 8007, 8012, 8017, 8022, 8036, 8081, 8090, 8100, 8113, 8115, 8132, 8137, 8142, 8147, 8152, 8157, 8169, 8182, 8204, 8208, 8221, 8235, 8268, 8274, 8281, 8286, 8296, 8313, 8438, 8443, 8448, 8453, 8458, 8465, 8470, 8475, 8480, 8487, 8494, 8553, 8558, 8565, 8570, 8575, 8580, 8608, 8613, 8618, 8623, 8653, 8670, 8691, 8701, 8733, 8738, 8743, 8748, 8826, 8836, 8858, 8863, 8868, 8873, 8920, 8951, 8979, 8984, 8989, 8997, 9002, 9011, 9166, 9171, 9176, 9181, 9186, 9193, 9198, 9203, 9208, 9213, 9220, 9227, 9291, 9296, 9303, 9308, 9313, 9318, 9324, 9346, 9351, 9356, 9361, 9375, 9420, 9424, 9439, 9447, 9471, 9476, 9481, 9486, 9491, 9497, 9501, 9503, 9516, 9555, 9572, 9601, 9606, 9611, 9616, 9681, 9745, 9758, 9763, 9945, 9950, 9955, 9960, 9965, 9972, 9977, 9982, 9987, 9992, 9999, 10006, 10071, 10076, 10083, 10088, 10093, 10098, 10126, 10131, 10136, 10141, 10251, 10256, 10261, 10266, 10394, 10399, 10404, 10409, 10414, 10483, 10543, 10556, 10561, 10746, 10751, 10756, 10761, 10766, 10773, 10778, 10783, 10788, 10793, 10800, 10807, 10873, 10878, 10885, 10890, 10895, 10900, 10928, 10933, 10938, 10943, 10990, 11053, 11058, 11063, 11068, 11196, 11201, 11206, 11211, 11339, 11559, 11591, 11596, 11601, 11606, 11611, 11618, 11623, 11628, 11633, 11638, 11649, 11654, 11659, 11735, 11834, 11839, 11844, 11850, 11854, 11870, 11887, 11891, 11937, 11939, 11946, 11994, 12024, 12039, 12044, 12049, 12142, 12271, 12272, 12273, 12275, 12277, 12279, 12286, 12287, 12289, 12291, 12293, 12295, 12297, 12298, 12301, 12303, 12305, 12310, 12311, 12312, 12314, 12323, 12326, 12371, 12373, 12375, 12376, 12378, 12429, 12431, 12436, 12438, 12443, 12445, 12467, 12499, 12501, 12506, 12507, 12509, 12511, 12513, 12514, 12515, 12517, 12526, 12527, 12535, 12544, 12555, 12575, 12578, 12580, 12582, 12587, 12589, 12598, 12629, 12631, 12633, 12647, 12652, 12655, 12657, 12660, 12664, 12667, 12668, 12700, 12717, 12719, 12722, 12724, 12725, 12730, 12732, 12756, 12761, 12764, 12766, 12767, 12768, 12770, 12793, 12796, 12798, 12804, 12805, 12816, 12820, 12821, 12841, 12845, 12855, 12857, 12859, 12864, 12873, 12896, 12901, 12903, 12911, 12912, 12913, 12914, 12916, 12917, 12919, 12920, 12921, 12923, 12929, 12933, 12934, 12939, 12940, 12941, 12990, 13035, 13052, 13055, 13070, 13071, 13080, 13082, 13088, 13090, 13114, 13127, 13131, 13133, 13140, 13164, 13177, 13180, 13188, 13196, 13197, 13200, 13201, 13209, 13227, 13282, 13298, 13303, 13312, 13316, 13321, 13323, 13326, 13327, 13328, 13330, 13335, 13338, 13339, 13356, 13365, 13368, 13398, 13400, 13402, 13409, 13429, 13432, 13434, 13445, 13446, 13448, 13453, 13454, 13467, 13469, 13470, 13474, 13475, 13494, 13497, 13506, 13508, 13512, 13514, 13515, 13516, 13518, 13520, 13521, 13530, 13531, 13543, 13558, 13561, 13564, 13569, 13571, 13574.

### `frontend/data/pvp_social_engineering_100.json`

Matches: Mia.

Lines: 153.

### `frontend/src/autoload/asset_manager.gd`

Matches: Alex, Leah, Mia, ms_reyes.

Lines: 304, 311, 314.

### `frontend/src/autoload/audio_manager.gd`

Matches: Alex, Leah, Mia, Ms. Reyes.

Lines: 15, 16, 17, 18.

### `frontend/src/data/pretest_bank.gd`

Matches: Alex, Ms. Reyes.

Lines: 136, 138, 139.

### `frontend/src/gameplay/assessment_live.gd`

Matches: Mia, Ms. Reyes.

Lines: 66, 373.

### `frontend/src/gameplay/decision/decision_overlay.gd`

Matches: Security Assistant.

Lines: 381.

### `frontend/src/gameplay/decision/decision_workspace.gd`

Matches: Alex, Mia, Ms. Reyes, Security Assistant.

Lines: 80, 106, 109, 463, 467, 814, 1090.

### `frontend/src/gameplay/decision/dialogue_portrait.gd`

Matches: Alex, Leah, Mia, ms_reyes, Ms. Reyes.

Lines: 7, 38, 39, 40, 95, 150, 236, 239, 242, 245, 246, 247, 272, 274, 277, 279, 282.

### `frontend/src/gameplay/decision/stage_one_live.gd`

Matches: Alex, Security Assistant.

Lines: 148, 245.

### `frontend/src/gameplay/decision/story_laptop.gd`

Matches: ALEX.

Lines: 28.

### `frontend/src/gameplay/decision/story_phone.gd`

Matches: Alex.

Lines: 247.

### `frontend/src/gameplay/tutorial/tutorial_match.gd`

Matches: Ms. Reyes.

Lines: 38, 47, 57, 58, 123.

### `frontend/src/main.gd`

Matches: alEx.

Lines: 57.

### `frontend/src/tools/verify_cloudinary_environment.gd`

Matches: Alex, Mia, Ms. Reyes.

Lines: 99, 101, 104, 109, 111, 117.

### `frontend/src/tools/verify_decision_stage.gd`

Matches: ALEX, Leah, MIA, Security Assistant.

Lines: 321, 324, 326, 454, 513, 514, 555, 574, 584, 639, 648, 890, 1458, 1477, 1533, 2484, 2485, 2511, 2521, 2522, 2622, 2641, 2655, 2659, 2660, 2739, 2758, 2875, 2894, 2895, 3006, 3015, 3028, 3030, 3034, 3035, 3049, 3059, 3060, 3157, 3176, 3177, 3178, 3180, 3264, 3278, 3291, 3313, 3341, 3423, 3454, 3483, 3651, 4383, 4895, 4932, 5006, 5072, 5073.

### `frontend/src/tools/verify_dialogue_emotion.gd`

Matches: Alex, Leah, Mia, Ms. Reyes.

Lines: 72, 74, 76, 216, 223, 244, 245, 246, 257, 259, 260, 261, 267, 274, 280, 281.

### `frontend/src/tools/verify_game_audio.gd`

Matches: Alex, Leah, Mia, Ms. Reyes.

Lines: 219, 235, 244, 260, 266, 292, 297, 303, 308, 312, 387, 393, 422, 423, 424, 425, 434, 436, 451, 454, 455, 473, 477, 484, 493.

### `frontend/src/tools/verify_investigation.gd`

Matches: Mia, Security Assistant.

Lines: 97, 185.

### `frontend/src/tools/verify_lessons_workspace.gd`

Matches: alEx.

Lines: 168.

### `frontend/src/tools/verify_stage_one_live.gd`

Matches: Alex, Leah, mia, Ms. Reyes.

Lines: 260, 353, 447, 459, 1306, 1330, 1342, 1343, 1347, 1348, 1551, 2516, 2517, 2518, 2519, 2520, 2524, 2525, 2531, 2533, 2534, 2546, 2547, 2564, 2646, 2647, 2651, 2652, 2654, 2655, 2657, 2658, 2662, 2676.

### `frontend/src/tools/verify_story_consequence.gd`

Matches: Mia.

Lines: 85.

### `frontend/src/ui/screens/deploy/module_intro_screen.gd`

Matches: Alex.

Lines: 2.

### `frontend/src/ui/screens/deploy/stage_briefings.gd`

Matches: Alex, LEAH, Mia, Ms. Reyes.

Lines: 38, 44, 49, 54, 59, 69, 79, 84, 89, 94, 104, 119.

### `frontend/src/ui/screens/intel/lesson_catalog.gd`

Matches: Mia.

Lines: 562, 563.

### `frontend/src/ui/screens/intel/lesson_player_screen.gd`

Matches: alEx.

Lines: 398.

### `frontend/src/ui/screens/intel/lesson_study_content.gd`

Matches: mia.

Lines: 10, 152.

### `frontend/src/ui/screens/pretest/pretest_screen.gd`

Matches: Alex.

Lines: 360.

# Cinematic ending — version 4 (2026-10-18)

Replaces the opening-only silhouette exposition and four individual placeholder previews with three generated illustrations. Existing practice failure explanations and account/BKT behavior are unchanged.

- Claim illustration → one sustained red wash and short background shake → red phone with “Got You” and a source-owned, synthesized 1.65-second robotic laugh.
- Dark masked meeting → five-victim montage (John / Amani / Liza / unnamed staff member / unnamed classmate).
- Closing caption “And this is how it began…” overlays the montage, then image and caption fade to black. The circular advance control hands off to practice; Back, Skip and Menu remain accessible.
- Cinematic tweens pause in Menu; laughter stops rather than restarting. Back/Skip/replay/exit cancel effects and audio. Reduced Motion uses immediate stills and a readable static closing caption on black. The five-panel art is aspect-fitted on extra-wide screens to retain every face.
- Snapshot version 4 maps old victim cursors 7–10 to montage 7 and old closing 11 to closing 8, including Back history; earlier v1/v2 migrations run first.
- These images dramatize scam consequences. They are not evidence that opening an email or merely tapping a link automatically grants account access; the following practice still explains that distinction. Staff/classmate remain unnamed; generated faces are fictional, not portraits of real students.

## Ending art provenance and exact prompts

Verification: the full `verify_tutorial.gd` and `verify_game_audio.gd` suites pass. Ending coverage includes real pointer activation of the cinematic advance button, menu pause, audio ownership/mute, Skip cancellation, reduced-motion stills, version 1–3 cursor migration, closing-caption/fade state, and unchanged replay/account data. Rendered inspection covers 1280×720 and 844×390 landscape. Audio-duration checks allow one sample of rounding at 22050 Hz. Physical Android touch, background/resume behavior and perceived speaker loudness still require a device acceptance pass.

Built-in image generation, using `john_claim_prize_v1.png` as the continuity/style reference; no external voice samples. Final assets:

- `frontend/assets/story/john_got_you_v1.png`
- `frontend/assets/story/collector_meeting_v1.png`
- `frontend/assets/story/five_victims_v1.png`

### got_you

Use case: illustration-story. Asset type: LEVELBLUE landscape 16:9 full-screen game cutscene. Reference image is the preceding shot; preserve the first-person medium-brown hands, black portrait smartphone, navy bed blanket, teal curtains and bedroom continuity, and the detailed pixel-art illustrated rendering. Create the NEXT shot, slightly closer to the upright phone held in the left hand, right finger now drawn back in startled hesitation. Entire phone display is ominous deep luminous RED with very large centered pale cream text exactly "Got You". Render those two words legibly, once, and no other text. Red light spills onto the hands; bedroom darkens into navy shadow, still recognizable. Phone and exact text occupy center safe region so landscape aspect-cover cropping retains them. No UI framing, dialogue box, logo, watermark, real website, gore or violence. This is a fictional cinematic scam reveal, not a real device screenshot.

### masked_meeting

Use case: illustration-story. Asset type: LEVELBLUE landscape 16:9 full-screen game cutscene. Reference image is STYLE ONLY: match its detailed cinematic pixel-art texture, crisp illustrated pixel edges, deep navy shadows. New scene: a group of five anonymous adult scammers in plain dark clothes and original simple pale masks sitting around a meeting table in a dark clandestine room, visibly laughing together through body language: heads tilted back, shoulders raised, one hand gesturing at a phone. Mysterious identities hidden, NOT existing franchise masks. Dim red monitor glow, muted teal rim light; faint generic message windows behind them, no legible writing or real logos. Readable silhouettes and masks despite dark background, dramatic low-key composition, all main heads within central safe margins. A restrained sinister tone suitable for teen educational game; no weapons, gore, money glamour, superhero outfits, dialogue box, words, watermark.

### five_victims

Use case: illustration-story. Asset type: LEVELBLUE ending montage, full-screen landscape 16:9. Reference image STYLE AND JOHN ROOM continuity only: detailed cinematic pixel-art rendering. Create exactly FIVE distinct tall comic panels side-by-side spanning canvas, separated by bold dark slightly slanted diagonal borders; varied expressive close-to-medium portraits. Original Filipino characters, no existing anime/franchise characters. Each face has enough space and readable emotion, all 5 faces inside central 80% height. Left to right: (1) John, young male student with short dark hair and medium-brown skin, casual navy shirt in teal-curtain bedroom, shocked wide eyes and parted lips, red prize-email phone behind him with envelope and gift lure icons. (2) Amani, young woman with dark shoulder-length hair, confused brows and hand near face, phone with no-signal icon and multiple impersonating chat bubbles behind her. (3) Liza, young woman with tied-back dark hair, crying with a visible tear, phone held at ear and an outgoing payment receipt with warning mark behind her to imply familiar-voice fraud. (4) adult female school staff member with dark bun and glasses, angry tense brow, unauthorized confidential student-list document and forged approval stamp behind her. (5) male classmate with dark wavy hair, dejected downcast expression, free-gift offer and locked-account phone icon behind him. Respectful empathetic portrayal, no victim mockery. Symbolic scam causes visible as background visual motifs, no tiny explanatory text. Consistent character proportions and cohesive navy, teal, amber, muted warning red palette, expressive comic framing. NO caption, names, dialogue bubbles with text, watermark, logos. Closing caption will be added in game.

