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
