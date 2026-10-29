# Codex field guide

## Module 1 story archive — Milestone 3, first gate

Characters and Evidence now cover all five Module 1 chapters through the existing Codex containers. A touch-sized chapter selector opens unlocked chapters and chapters with saved original progress. The archive contains 35 observations in total. John, Eric, Jobert, Sir Rham, Dan and Mika appear as their introductions become available; the latter three use name cards where no approved Codex portrait is configured.

Records unlock from each chapter's validated story beats and investigation fields. Undiscovered records hide their title, source and associated characters. Known observations remain distinct from unverified claims: a typo or status timestamp alone does not identify the culprit. Chapter 5's admission and outcome require their own saved milestones, rather than revealing the resolution when the typo is matched.

The selector reads existing original chapter checkpoints, so replaying does not erase discoveries. Existing account and progress signals refresh the archive; an account change resets chapter and character selection. Browsing is read-only and introduces no new save schema, assets, network requests or BKT observations. The existing Combat Intel section remains available for its current gameplay and remediation routes.

Deploy now reports completion across all five Module 1 chapters instead of advertising Chapters 3–5 as coming soon. Chapter 3's link-inspection hint describes touch-and-hold input. Modules 2–5 remain separate gates requiring agreed story content.

Local verification covers all five chapter gameplay scripts, every archive discovery gate, malformed progress, locked chapters, replay preservation, account reset, touch selection and read-only browsing. Rendered landscape-phone checks supplement these assertions; physical-device touch and safe-area acceptance remains pending.

## Combat Intel

The existing dashboard/gameplay Codex route uses a visual collection layout: a cream roster page with illustrated Defender/Threat cards and name/type search, and a navy specimen page with the same beveled journal borders as Worlds and Missions. Currency is hidden because browsing is read-only. The detail page has a gameplay-model preview, rotation control, compact base stats, and selectable illustrated matchup tiles. Selecting a matchup reveals its combat effect. Tactics and real-world notes are collapsed separately to avoid a wall of text.

Below 1,000 physical pixels wide, selecting an entry opens a separate full-width details page. Back returns to the collection without applying exit/remediation behavior; a subsequent Back exits normally. Search, remediation deep links and previous/next entry navigation remain available. Scrollbars are hidden without disabling scrolling. Entry changes use a short fade, skipped with Reduced Motion and cancelled on exit/free.

## Data and assets

- `codex_field_data.gd` reads stats from ContentDB and calls EnemyBase's actual matchup methods with an off-tree probe. No damage or slow tables are duplicated and no combat rules were changed.
- Damage cards show multipliers before whole-number rounding. Slow cards show movement-speed reduction, not remaining speed or damage resistance. Enemy cards describe effects received from towers.
- Seven current entries are browsable regardless of deployment unlocks. Additional ContentDB entries appear automatically with fallback notes.
- `codex_specimen.gd` now calls the exact `gameplay/preview/unit_glyphs.gd` tower/enemy renderers used by the geometric campaign. This replaces the stale Basic Node texture, old character sheets and unrelated schematic glyphs. All three defenders and four enemy variants use their gameplay silhouettes; enemy colors come from ContentDB. Preview size and sandbox ring radius are normalized for display, not real attack-range measurements. No combat actors, bitmap files, downloads or Cloudinary changes were added.
- Existing Codex remediation navigation and stage-lock clearing on exit are preserved. Browsing does not complete lessons, spend credits or unlock towers.

## Real-world notes

Notes are optional and explicitly separated from fictional combat mechanics. They work offline; only the user-clicked source buttons need internet. Authored links are restricted to NIST and CISA. Reference sources checked for this implementation:

- [NIST: Firewall](https://csrc.nist.gov/glossary/term/firewall)
- [NIST: Vulnerability scanning](https://csrc.nist.gov/glossary/term/vulnerability_scanning)
- [NIST: Sandbox](https://csrc.nist.gov/glossary/term/Sandbox)
- [CISA: Staying safe online](https://www.cisa.gov/sites/default/files/2024-09/Secure-Our-World-4-Easy-Ways-Stay-Safe-Online-Tip-Sheet.pdf)
- [CISA: StopRansomware guide](https://www.cisa.gov/resources-tools/resources/stopransomware-guide)

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_codex_field_guide.gd`. The in-memory test covers all seven combat entries, all 12 defender/enemy pairings, shared gameplay-renderer identity, native roster/matchup taps, rotation, reduced motion, remediation selection, search and empty states, tactics/real-world expansion, navigation, and mobile viewport layouts. It verifies browsing changes no progress, credits or stage locks and creates no combat actors. It does not invoke exit/remediation mutations or save progress. With rendering enabled and `-- --render`, screenshots are written under ignored `frontend/.godot/` for visual QA. Developer verification files and generated artifacts stay out of commits.
