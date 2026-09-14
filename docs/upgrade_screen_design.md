# Tower research UI

The existing Upgrades route now opens a readable three-card armory using the shared dark study-screen shell, always-on subtle CRT effect and muted teal/blue/lilac accents.

Selecting an unlocked tower opens a reference-inspired layout:

- Left: tower portraits with quick switching and padlocks.
- Center: connected circular research nodes, colored halos, rank badges and a gold selection ring. The network scrolls vertically rather than shrinking touch targets.
- Right: selected upgrade effect, prerequisite or installed state, exact credit cost and a persistent **Level Up** action.

Existing Basic Node artwork is reused from the asset cache. Scanner/Sandbox schematics, portraits, glyphs and glow effects are drawn in code. No new image uploads are needed.

Basic Node's nine ranks and all costs/effects still come from ContentDB. Purchases still use PlayerManager.purchase_tech_rank. The tutorial's granted capacity rank and acknowledgement path are retained. Scanner and Sandbox have no configured research tracks, so their screens show an explicit coming-soon state.

Successful purchases refresh credits, node ownership and tower availability, and play a short ring pulse. Inspecting a node does not spend credits.

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_research_ui.gd`. For ignored QA screenshots, use a graphical renderer and append `-- --render`.

The in-memory test covers tower locks, nine rank selections, prerequisites, insufficient credits, installed/max ranks, account changes, back navigation, tutorial restrictions and touch/layout checks at 1280×720, 960×600 and 844×390 with simulated phone insets. It does not purchase upgrades or save player data.
