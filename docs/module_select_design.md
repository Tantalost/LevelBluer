# Deployment module selector

The existing `stage_select` route now uses the shared study-screen shell: a charcoal/slate background, permanently enabled subtle CRT overlay, muted teal accents, and larger DigitalDisco text.

- Dashboard-style profile, rank, threat and credit band; profile and settings remain accessible.
- Compact Upgrades button preserves the skill-tree route.
- Five vertically scrollable operation cards, with explicit lock icons and text.
- A separate briefing panel shows themed, code-drawn signal artwork, lesson preparation, stage availability and prerequisites.
- Open Module stays visible while the briefing scrolls. Selecting an unlocked card retains the original one-tap navigation.
- Module 1 reports explicit clears out of its ten stages. Other modules say stages are coming soon, independently of lesson-based access.

Unlock rules and destinations are unchanged: Module 1 uses the completed-module lesson record and opens its introduction; later modules use previous-module lesson counts and open their stage lists. This screen never writes progression, rewards or account data.

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
leads to the title card. Replay is read-only. Continue retains the existing
`module_stages` destination until the separate Chapter 1 milestone is implemented.

Typing and title transitions pause on application focus loss/suspension and are
cancelled on exit. Reduced motion, instant text, audio mute and cached/offline art
fallback remain supported. Only Continue invokes the existing intro-seen save;
reading, replaying and skipping to the card do not award progress, evidence or coins.

The module-select verifier now also checks sequential caption fading, the prologue, title, replay, skip,
focus pause, resume, progress invariance and both desktop/landscape-phone layouts.
Cloudinary-environment verification covers late and missing cached intro art.
Use `-- --download-art` with the module-select verifier to fetch the two new
art assets into the normal Godot cache; combine with `--render` for screenshots.
