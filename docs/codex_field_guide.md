# Codex field guide

## Complete presentation redesign — implemented, 20 November 2026

Approved through the user's instruction to continue. The implementation replaces the current text-heavy presentation across the index, collections and readers. It does not change discovery rules, chapter access, learning content, saves or BKT evidence.

- **Library index:** keep the rectangular Back control and existing navy/cyan/cream palette. Use one concise Library heading and three large illustrated entry points: Characters as a portrait dossier with a projecting file tab, Evidence as a layered document folder with an angled tab, and Field Guide as a shield-shaped entry with a drawn shield emblem. Existing gameplay specimens remain inside its collection and detail pages. Each shows only its name and one availability/discovery count. School Content becomes a labeled bookmark-shaped shortcut. Use generous, predictable touch areas despite the decorative silhouettes. Remove repeated collection numbers, promotional paragraphs and the fixed Module 01 footer. Existing approved portraits and drawn glyphs supply the visuals; no new generated media is required.
- **Collections and readers:** use folder-shaped section tabs and rounded module/chapter filters. Characters become a portrait gallery with name and brief role; profiles show a short overview with separately expandable Background, Observations and Relationships. Evidence becomes compact document tiles with title, status and at most one preview sentence; the selected record opens a readable cream page separating the finding from its source. Field Guide retains the existing Combat Intel entries and their fictional gameplay/real-world distinction, but uses visual entry tiles, compact stat badges and expandable explanations. Search and full existing text remain accessible; summaries do not invent conclusions or expose locked records.
- **Existing structure and signals:** retain CodexScreen's shell, archive scroll container, collection/detail panes, current selection/search state and Back routing. Extend its existing button presentation locally for the folder/bookmark/shield silhouettes; keep the rectangular Back control unchanged. Existing pressed callbacks still open sections, characters, records and School Content; account/progress signals refresh the same read-only snapshot. Use the current transition tween for short selection/page feedback and cancel it on exit; Reduced Motion changes views immediately. No new manager, save schema or parallel navigation system.

Acceptance after implementation: inspect the index and every reader at small landscape phone sizes (including 667x375 and 844x390); verify text legibility, touch targets and safe-area scrolling, search and empty states, correct module/chapter labels, spoiler protection, source visibility, account refresh, offline portrait fallback, remediation links, Back behavior and Reduced Motion. Reconcile affected local Codex fixtures with the new presentation while retaining discovery/read-only checks. Keep verification scripts and screenshots out of commits.

## Library navigation and reading

Codex opens on a library index with three collection cards: Characters, Evidence, and Combat Intel. Cards show a preview and available-entry/discovery counts. School Content remains accessible from the header. All styling reuses the existing navy, cyan and cream palette and beveled panels; no new assets or save fields are required.

Characters and Evidence have a chapter selector and collection search. Character search matches names and roles; evidence search matches only discovered titles, text and sources in the selected chapter. Empty searches explain that undiscovered records are excluded. Selecting evidence opens a dedicated cream reading page with its full observation and source. Character files present background and relationships on a cream reference panel, with related discoveries available below.

Back returns from a reader to its source profile or collection, then to the library, then exits Codex. Search is retained while opening and closing a reading page. Account changes clear the selection and return to the library. Combat Intel keeps its existing roster, detail pages and remediation entry points.

Collection cards stack on narrow phone viewports. They size to their wrapped text, keeping the whole card tappable; long pages scroll within the existing safe-area shell. Local validation covers native card taps, clipped visible touch regions, search, spoiler protection, reading sources, Back navigation, account reset and 844×390, 720×360 and 390×844 viewport layouts. Physical-phone acceptance is still pending.

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

Implementation review: the library now has illustrated dossier/folder/shield covers; character profiles use expandable background, observations and relationships; evidence uses two columns in landscape and a single column on narrow screens. Paper-toned readers retain the full authored observation and source. Controls use tabs, pills and rounded tiles; Back retains its existing style. Character/evidence opening uses the existing transition tween, skipped with Reduced Motion.

Corrected the archive's old module filter, which only exposed Modules 1 and 2 and grouped later chapters under the second group. All five modules now have their own five-chapter selection, with the same access/discovery guards. No learning, reward, save or mastery rules changed.

Validation: the Codex field-guide suite passes with zero failures, including native taps, discovery/search guards, profile/evidence navigation, all five module filters, original-versus-replay preservation, account reset, seven reference entries and twelve matchup combinations. Updated the local Chapter 5 fixture to include its approved ending sequence instead of pretending the new cutaway was complete. Godot screenshots were reviewed at 667x375, 720x360, 844x390 and 390x844. Physical-phone acceptance remains open. Developer fixtures and screenshots are not included in the production patch.
