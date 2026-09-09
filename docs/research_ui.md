# Research UI

The live `frontend/src/ui/screens/deploy/upgrade_screen.tscn` retains the two-step
tower selection / research flow. This is a presentation change: tower costs,
credit costs, rank effects, save behavior, and evolution prerequisites still come
from ContentDB and PlayerManager.

## Reusable components

- `tower_research_card.gd`: framed tower dossier, hardware preview, stats, unlock
  requirement, and research progress. Basic Node uses AssetManager's existing
  base/head textures; unavailable art falls back to a code-drawn schematic.
  Scanner and Sandbox explicitly display schematics, not new final tower art.
- `tech_orbit_node.gd`: focusable circular Button with branch insignia, rank,
  owned/next/locked appearance, selection ring, and prerequisite lock badge.
- `upgrade_glyphs.gd`: shared procedural insignias; no extra raster assets.
- `research_background.gd`: subdued research-only blueprint background.

Each research track is an independent chain from the core. The UI renders the
existing nine Basic Node ranks across Skill, Stats, Capacity, and Evolution; it
does not introduce extra research nodes or cross-track prerequisites.

Select a node to inspect its full effect and cost, then use Research to purchase.
Owned ranks, unmet prerequisites, and unaffordable ranks disable that action.
The tutorial retains direct acknowledgment of Capacity rank 1. Scanner and
Sandbox show an explicit empty state until their tracks exist in the content.

## Verification

Run Godot with `--headless --path frontend --script
res://src/tools/verify_research_ui.gd`. The smoke test uses in-memory progression
only and never purchases upgrades or writes player saves. It checks locks,
rank states, affordability, navigation, tutorial target availability, and bounds
at standard and compact landscape sizes.

With a rendering driver, add `-- --render` to write review screenshots under the
ignored `frontend/.godot/` directory. No new production bitmap assets are needed.
