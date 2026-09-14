# Codex field guide

The existing dashboard/gameplay Codex route now uses the shared lesson CRT shell, readable fonts and two-panel layout. The left panel provides Defender/Threat tabs and name/type search. The right panel includes a specimen preview, base stats, matchup cards, optional real-world notes and previous/next navigation.

## Data and assets

- `codex_field_data.gd` reads stats from ContentDB and calls EnemyBase's actual matchup methods with an off-tree probe. No damage or slow tables are duplicated and no combat rules were changed.
- Damage cards show multipliers before whole-number rounding. Slow cards show movement-speed reduction, not remaining speed or damage resistance. Enemy cards describe effects received from towers.
- Seven current entries are browsable regardless of deployment unlocks. Additional ContentDB entries appear automatically with fallback notes.
- `codex_specimen.gd` reuses AssetManager's cached Basic Node base/head and animated enemy walk frames. Scanner/Sandbox use existing code-native glyphs; unavailable art has a schematic fallback. No bitmap files, asset downloads or Cloudinary changes were added.
- Existing Codex remediation navigation and stage-lock clearing on exit are preserved. Browsing does not complete lessons, spend credits or unlock towers.

## Real-world notes

Notes are optional and explicitly separated from fictional combat mechanics. They work offline; only the user-clicked source buttons need internet. Authored links are restricted to NIST and CISA. Reference sources checked for this implementation:

- [NIST: Firewall](https://csrc.nist.gov/glossary/term/firewall)
- [NIST: Vulnerability scanning](https://csrc.nist.gov/glossary/term/vulnerability_scanning)
- [NIST: Sandbox](https://csrc.nist.gov/glossary/term/Sandbox)
- [CISA: Staying safe online](https://www.cisa.gov/sites/default/files/2024-09/Secure-Our-World-4-Easy-Ways-Stay-Safe-Online-Tip-Sheet.pdf)
- [CISA: StopRansomware guide](https://www.cisa.gov/resources-tools/resources/stopransomware-guide)

## Verification

Run Godot with `--headless --path frontend --script res://src/tools/verify_codex_field_guide.gd`. The in-memory test covers all seven entries, all 12 defender/enemy pairings, remediation selection, search and empty states, real-world expansion, navigation, and compact layout. It does not invoke exit/remediation mutations or save progress. With rendering enabled and `-- --render`, screenshots are written under ignored `frontend/.godot/` for visual QA.
