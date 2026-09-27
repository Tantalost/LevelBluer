# School story assets

## Sources and use

Backgrounds supplied by the user. The images are hosted on Cloudinary, not bundled in the repository. `AssetManager._school_story_catalog()` registers all 15 images in the existing startup synchronization. Gameplay reads `user://assets/story_bg_<location>.png` and `user://assets/story_portrait_<character>.png`; no HTTP request occurs during story playback. First-time artwork requires an online startup, then remains available offline. If a download is unavailable, the themed background and procedural portraits keep dialogue playable. A finished synchronization refreshes an open story without advancing dialogue.

The current Stage 1 uses school_gate_morning for its opening, hallway_day for incidents 1–2, and classroom_day for incident 3 and its ending. Other supplied locations remain in the requested location catalog; other chapters are not rewritten by this milestone. The source filenames below are archival labels, not local resource paths. All downloaded pixels were verified against the original images before the 15 PNGs and their import descriptors were removed. An external ZIP backup of the originals was also verified by SHA-256.

Cache verification: run `res://src/tools/verify_cloudinary_environment.gd` with `--story --download` once, then `--story` to check disk-only loading, all expression frames, missing-cache fallbacks, and scene refresh/cleanup. This does not modify player progress.

- `backgrounds/gymnasium.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432520/gymnasium.png
- `backgrounds/courtyard.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432520/courtyard.png
- `backgrounds/school_gate_morning.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432520/school_gate_morning.png
- `backgrounds/classroom_sunset.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432520/classroom_sunset.png
- `backgrounds/clubroom.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432520/clubroom.png
- `backgrounds/classroom_day.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432520/classroom_day.png
- `backgrounds/rooftop_day.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432521/rooftop_day.png
- `backgrounds/music_room.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432521/music_room.png
- `backgrounds/hallway_day.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432521/hallway_day.png
- `backgrounds/library_room.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432521/library_room.png
- `backgrounds/infirmary.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432521/infirmary.png
- `backgrounds/science_lab.png`: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790432521/science_lab.png

## Character sheets

- Alex: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790436023/alex_expressions.png
- Mia: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790436023/mia_expressions.png
- Ms. Reyes: https://res.cloudinary.com/nfd5bhkz/image/upload/v1790436023/ms_reyes_expressions.png

Generated with the built-in image tool using the user's 64×64 pixel portrait reference (codex-clipboard-1a69b158-d50d-4c49-900f-a8c01bb11271.png). No background generation or image manipulation scripts were used. Final sheets are 2172×724 transparent PNGs, three 724×724 cells: neutral, worried, relieved/reassuring. The original tool outputs are preserved in the Codex generated-images folder. Cached AtlasTextures and nearest-neighbor rendering retain hard pixel edges. Unknown speakers retain the existing fallback. Art is enabled only for the school story cast, not old corporate chapters.

### portraits/alex_expressions.png — final prompt

Use case: illustration-story. Input image 1 is a STYLE and FRAMING reference only. Create a production pixel-art dialogue portrait expression sheet for Alex, a high-school boy about 16, warm medium complexion, short tousled dark-brown hair, brown eyes, blue school overshirt over a cream T-shirt, no badge or headset. EXACT reference look: small classic 64x64 JRPG/anime face portrait enlarged with hard nearest-neighbor pixel blocks, expressive large anime eyes with small highlights, angular fine dark pixel outlines, simple 3-tone cel shading, subtle cheek warmth, bright clear face, very limited palette. NO realistic rendering, no smooth painted anime, no fine texture, no gradients or antialiasing. Head and upper shoulders only, head occupies most of each frame, like the supplied square reference. Exactly 3 equally sized portrait cells horizontally across a wide 3:1 sheet, no labels or separators. LEFT neutral attentive; CENTER visibly worried with raised inner eyebrows and slightly open mouth; RIGHT relieved confident small smile. Identical head size, face identity, pose, eyeline, hair and clothing in all 3. Full hair and shoulders inside each equal-width third, with a small transparent gap; no crossing cells. Genuinely transparent alpha outside the portraits, no glow or backdrop, no checkerboard, no text or watermark. Output flat sprite atlas only.

### portraits/mia_expressions.png — final prompt

Use case: illustration-story. Input image 1 is the exact PIXEL ART STYLE and portrait framing reference, not the character identity to copy. Create Mia, a high-school girl about 16, warm medium skin, dark shoulder-length hair parted to the side, brown eyes, teal cardigan over a cream school blouse, no office badge. Production dialogue expression atlas, THREE equal square cells side by side on a 3:1 transparent sheet. Match the reference's tiny 64x64 JRPG anime portrait aesthetic: face dominates frame, upper shoulders only, expressive large eyes, delicate angular dark pixel contours, clear small eye highlights, rosy cheeks, hand-placed square pixel clusters, 3 flat shade levels per material. NO smooth painted rendering, no realistic detail, no gradient, no blur, no antialiasing. Left expression neutral interested, center worried with raised inner eyebrows and small open mouth, right relieved cheerful smile. All three exactly the same character, head size, eye-line, hair, outfit and pose; only facial expression changes. Each full head and shoulders inside its equal-width third with small clear alpha margins; no overlap across cells. Genuine transparent alpha background, no scene, glow, checkerboard, text, dividers or watermark. Flat game-ready sprite sheet.

### portraits/ms_reyes_expressions.png — final prompt

Use case: illustration-story. Input image 1 is the exact pixel portrait ART STYLE reference only. Create Ms. Reyes, a warm high-school teacher in her late thirties, medium brown skin, dark hair tied in a neat low bun with side-parted bangs, brown eyes, small rectangular glasses, muted warm terracotta cardigan over cream blouse. Production dialogue expression atlas with exactly THREE equal square cells side by side, wide 3:1 canvas, transparent alpha background. Reference style: small 64x64 classic JRPG/anime face portraits enlarged with hard crisp pixel blocks, expressive eyes, delicate angular pixel outlines, flat 3-tone shading, limited palette, clear tiny eye highlights and warm cheeks. Adult teacher proportions, not a child or chibi body. Head and upper shoulders only; full head with bun fits in every cell. Left expression calm attentive; center concerned eyebrows with slightly open speaking mouth; right reassuring gentle smile. IDENTICAL face identity, glasses, hairstyle, eye-line, head size, outfit, pose across all three; facial expression is the only change. Each portrait fully inside its equal-width third with a transparent gap, no crop across cell boundaries. NO smooth painted anime, no photorealism, no fine realistic texture, no gradients, no blur or antialiasing. No background, glow, opaque shadow, checkerboard, dividers, labels, text or watermark. Flat ready-to-use sprite atlas.

