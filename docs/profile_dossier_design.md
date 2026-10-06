# Operator dossier

The existing Profile route now shares the readable dark/teal study-screen shell and permanent subtle CRT treatment, with an operator-ID presentation distinct from the Progress screen.

## Reasons to visit

- Identity card: existing avatar, reusable rank insignia, rank points and the next rank target.
- Next assignment: a suggestion from actual stage access and lesson progress, opening the existing Deploy, Lessons, Codex or Progress route. It never launches a locked stage or bypasses a pre-test.
- Field Record and Tower Armory shortcuts: exact authored-stage/lesson totals and current credits.
- Personal intelligence: highest and lowest assessed BKT estimates, including awaiting-sync labels. Absent mastery is not presented as zero.
- Four service milestones derived from recorded lesson and stage completion. They award no new rewards.
- Expandable personal record: name, section, email, reported status, sessions, threat points, reported system levels and available test information.

The full graph and journey remain in Progress. Profile is a concise personal briefing, not a second overall-score screen.

Cached data appears immediately. The existing authenticated profile refresh is retained in the background; UI updates are guarded against exit/account changes. Empty account fields and unconfirmed tests are labeled explicitly. No database, reward, scoring or unlock changes, and no new bitmap assets.

## Verification

Godot: `--headless --path frontend --script res://src/tools/verify_profile_screen.gd`.

For visual QA, run with a graphical renderer and append `-- --render`. Screenshots are saved only under ignored `frontend/.godot/`.

Fixtures cover fresh/partial/completed players, Commander, recommendations, absent and pending mastery, earned milestones, long identity fields, account switches, read-only inspection and 1280×720, 960×600 and 844×390 layouts with simulated safe-area insets. No real account requests, purchases or saves are performed by the test.

## Uniform avatar collection (2026-10-05)

The profile portrait now opens a landscape-only modal with a large preview, 5-by-2 circular avatar grid, and Cancel / Confirm controls. Two avatars (Byte Bot and Cyber Cat) are free. The eight paid avatars share canonical IDs/prices with the store: p1 Commander Avatar (800), p2 Operative Icon (450), p3 Neon Fox (600), p4 Circuit Owl (500), p5 Glitch Ghost (700), p6 Pixel Bunny (400), p7 Cyber Axolotl (650), p8 Masked Raccoon (550). All prices are PvP Tokens. Existing p1/p2 ownership is preserved. Free avatars are not listed for sale.

`avatar_portrait.gd` owns the immutable catalog and common circular texture presentation. `avatar_picker.gd` owns only the modal and emits confirmed/store_requested/dismissed. Profile handles confirmation and navigation. PlayerManager validates ownership, persists `selected_avatar_id`, and emits `avatar_changed`; selecting does not debit either wallet. Purchases unlock without auto-equipping. Missing, unknown, or unowned saved selections fall back to Byte Bot. Reset/account rehydration refreshes selection. All existing `AssetManager.bind_texture(..., "ui_pfp")` consumers now bind to the selected portrait (dashboard, profile, stage screens, victory); freed portrait nodes automatically release their signal connections. Preview and Cancel never save. Locked entries navigate to the exact item in the existing Store route; the store still rejects Solo funds.

Artwork: ten built-in image-generation outputs use the supplied versioned Cloudinary URLs through AssetManager's `ui_avatar_*` entries. Downloads are cached in `user://assets/` and capped at 256 pixels before storage/texture creation. The ten source PNGs and import sidecars have been removed from the repository; Cloudinary copies remain available. An uncached avatar uses a native silhouette placeholder, so first-time artwork downloads require network access. Headers, picker cells, and store previews refresh after complete or partial asset syncs, without changing selection or ownership. Receiver-owned signal connections are released when portraits are freed. The UI retains identical circular masks and selection rings; no upload or API keys are needed.

Final generation prompt set: each image used the following shared prompt plus its subject and a final period (built-in tool, one generation per portrait):

> Use case: stylized-concept. Asset type: finished square player avatar portrait for Level Blue, a teen-friendly cybersecurity game. Style: charming polished 16-bit pixel art with visibly square pixel clusters, crisp stepped outlines, limited 24-color palette, no smooth painting, no 3D. Composition: one character only, front-facing centered head and shoulders, head fills about 65% of square, eyes at 45% height, whole ears/head visible with 12% safe margin, consistent collectible avatar framing. Background: flat dark navy #102040 filling the whole square, no border, no circle, no scene. Shared palette: cream #F3ECD6, navy #102040, cyan #4FE0D4 with the character's accent colors. Mood: fun, expressive, approachable. No text, letters, labels, logos, watermark, interface or extra characters. Subject:

- `byte_bot_v1.png`: a friendly small cream-and-teal robot with square cyan eyes, a tiny antenna and a cheerful digital smile.
- `cyber_cat_v1.png`: a playful charcoal-gray cat with cream muzzle, bright green eyes and teal cyber headphones.
- `commander_v1.png`: a confident young woman with dark brown skin, short curly hair, gold-trimmed navy officer jacket and small gold headset.
- `operative_v1.png`: a cheerful young man with warm tan skin, tousled dark hair, cyan visor pushed above his eyes and a navy tech jacket.
- `neon_fox_v1.png`: a mischievous orange fox with cream muzzle, cyan cyber goggles perched on its forehead.
- `circuit_owl_v1.png`: a studious round brown owl with large amber eyes and tiny cyan circuit-pattern spectacles.
- `glitch_ghost_v1.png`: a friendly little cream ghost with violet pixel edges, expressive black eyes and a playful crooked smile.
- `pixel_bunny_v1.png`: a lively cream rabbit with upright ears, rose inner ears and a blue tech hoodie.
- `cyber_axolotl_v1.png`: an adorable pink axolotl with coral external gills, a wide tiny smile and teal headphones.
- `masked_raccoon_v1.png`: a cheeky gray raccoon with natural black eye mask, cream cheeks and a purple tech scarf.

Validation extends `verify_profile_screen.gd` and `verify_store.gd`: exactly 2 free / 8 paid; all textures; ownership guards; legacy purchases; purchase without auto-equip; selection round trip; no Solo-funded avatar; native avatar/cancel/confirm/store-intent controls; invalid save fallback; account-switch dismissal; live header updates and freed receivers; exact store deep link; 1280x720, 960x540 and 844x390 landscape layouts. Purchase/selection mutations use an off-tree persistence probe; normal fixture browsing never writes player saves. Existing dashboard tests remain passing.
