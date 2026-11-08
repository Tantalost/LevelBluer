# Module 4 — The Perfect Credential

Approved first slice: Sir Rham's intro and Chapter 1, 3 November 2026. Built-in image generation was used for all four assets; no CLI fallback. Final local PNGs remain here for review, while production uses the versioned Cloudinary URLs through AssetManager. The transparent portrait sheet was checked for alpha and rendered in Godot. Each environment/title is 1672×941; the portrait sheet is 1536×1024 in a 3×2 grid.

| Workspace file | Hosted URL | Integration |
| --- | --- | --- |
| `sir_rham_poses_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793694622/levelblue_mod4_sir_rham_poses_v1_20261103.png | `story_rham_poses`; neutral, amused, concerned, skeptical, phone-checking, resolved |
| `faculty_workroom_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793694625/levelblue_mod4_faculty_workroom_v1_20261103.png | `story_bg_mod4_faculty_workroom_v1`; intro earlier-morning beat, Chapter 1 story/investigation and preview |
| `consultation_room_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793694634/levelblue_mod4_consultation_room_v1_20261103.png | `story_bg_mod4_consultation_room_v1`; intro late-afternoon flash-forward and Chapter 3 story/investigation/preview; same room and lighting |
| `mystery_title_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793694637/levelblue_mod4_mystery_title_v1_20261103.png | `module4_mystery_title_v1`; intro title, future-chapter development preview |
| `admin_reception_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793734229/levelblue_mod4_admin_reception_v1_20261104.png | `story_bg_mod4_admin_reception_v1`; Chapter 2 late-morning story, investigation and preview |
| `briefing_room_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793765299/levelblue_mod4_briefing_room_v1_20261104.png | `story_bg_mod4_briefing_room_v1`; Chapter 5 hearing, reconstruction and preview |
| `rham_counter_documents_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793765303/levelblue_mod4_rham_counter_documents_v1_20261104.png | `module4_rham_counter_documents_v1`; lettered counter with document motif |
| `records_office_v1.png` | https://res.cloudinary.com/nfd5bhkz/image/upload/v1793735846/levelblue_mod4_records_office_v1_20261104.png | `story_bg_mod4_records_office_v1`; Chapter 4 late-afternoon story, investigation and preview |

The portrait uses the user's second reference image, `codex-clipboard-76ee1481-4c3c-43d6-959e-1ea8f1db4b00.png`, for Sir Rham's likeness. Preserve cap, glasses, dark hair, tan shirt and watch in later imagery. The unidentified coordinator is represented only as an anonymous title-art silhouette, never as an established culprit portrait.

## Exact generation prompts

### Sir Rham portrait sheet

Create one transparent-background anime visual novel character sprite sheet for LEVELBLUE, a mobile school cybersecurity game. Use the attached photo ONLY as the likeness reference for the fictional character Sir Rham: Filipino adult male teacher, warm complexion, round thin dark glasses, dark navy baseball cap, dark hair visible near ears and nape, broad warm smile, tan textured short-sleeve shirt, black wristwatch, dark trousers. Preserve these visible features consistently. Clean anime linework and painterly cel shading with restrained crisp pixel texture, matching a polished school visual novel. SIX separate waist-up poses in an exactly evenly spaced THREE COLUMNS by TWO ROWS grid. Each cell contains the same character at identical scale and bottom baseline, isolated with generous transparent padding, no overlap. Left-to-right top row: 1 neutral attentive with arms relaxed, 2 amused broad smiling with teeth and slightly squinting eyes, 3 concerned with raised brows. Left-to-right bottom row: 4 skeptical thoughtful hand near chin, 5 focused checking his dark smartphone, 6 confident resolved gesture with open hand. Whole cap and both arms within each cell. Transparent background throughout, no cell borders, no text, no logos, no extra people or furniture. Do not reproduce the café or photo background. Use 3:2 overall landscape composition.

### Environment prefix (prepended verbatim to each environment suffix below)

Create ONE edge-to-edge wide 16:9 environment illustration for LEVELBLUE, a Filipino school cybersecurity mobile visual novel. Polished anime background painting, crisp subtle pixel texture, grounded school architecture, cream plaster, dark teal frames, navy shadows, muted cyan light and restrained warm amber accents. No people, silhouettes, readable text, lettering, logos, watermark, UI, collage, split screen or border. Generous clear central foreground for separately overlaid characters and lower quarter visually quiet for dialogue.

### Faculty workroom suffix

Faculty workroom in the morning. View from inside toward tall louvered windows on the LEFT with sunlit tropical trees outside. Long wooden teacher workbench and shelves of folders on the RIGHT, a modest cold coffee cup and stacked club folders at the far right end, spare wooden chairs, wall clock high on the wall. A partly open door to the school corridor in the BACK CENTER. Warm fresh morning light, welcoming but busy, distinct professional staff workspace. No computer monitor and no visible phone.

### Consultation room suffix

Small private faculty consultation room in late afternoon, a distinct intimate room unlike a classroom or library. Frosted glass door and dark teal frame at the LEFT, round wooden consultation table at the RIGHT with two empty cushioned chairs, closed cream folders, empty in-tray. Narrow high windows along the BACK RIGHT cast long golden slats of sunlight, a wall-mounted fan, subdued cyan reflected window light. Slightly tense stillness, plausible administrative meeting space, lots of empty center floor. No computer monitor and no visible phone.

### Mystery title

Create ONE wide 16:9 cinematic mystery title background for LEVELBLUE's school cybersecurity mobile visual novel. Polished anime illustration with crisp restrained pixel texture. A faceless shadowy adult figure beyond frosted office glass in the RIGHT THIRD, unreadable blank credential shape hanging at chest, no recognizable face. Angular frosted glass partitions and overlapping translucent paper silhouettes, a closed folder on a desk foreground right. Deep navy #050B18, cyan #4FE0D4 edge light, subtle warm cream beam from behind the glass. Intriguing institutional impersonation, psychological mystery rather than horror. LEFT 60 percent dark quiet negative space for title text added by the game. No words, numbers, letters, logos, seals, badges with writing, interface, borders, gore or weapons. Edge to edge landscape composition.

## Acceptance and remaining artwork

The hosted download/cache decode checks passed for all four images. Mobile Godot captures at 720×360, 844×390 and 932×430 were inspected: notification, story portrait, comparison feedback, independent route, intro/title and selector. Existing reveal timing aligns cyan source-line accents beneath the title; normal-motion pause/resume and reduced-motion behavior passed. The image itself contains no UI text.

**Environment inventory: 5 of 5 required new backgrounds integrated as of 4 November.** The early-evening school briefing room supports Chapter 5. Its new Sir Rham counter, mystery preparation art, source-layer title, document alignment and pixel command trails use the existing hearing controls. Local rendering/behavior acceptance is tracked in the milestone review; physical-phone and user visual acceptance remain separate requirements.

The four PNGs were committed externally while implementation was in progress. They have now been removed from the current Git index, retained locally and covered by the root ignore rule. Earlier commits still contain their historical copies; history was not rewritten. Developer scripts/screenshots remain local and must not be staged.

Chapter 3 review (4 November): the consultation room now appears in the story, investigation and chapter preview, matching the intro's late-afternoon location and lighting. Its new restricted-roster presentation is drawn using existing navy/cyan phone panels; evidence text remains live UI, not baked into an image. The scene and touch comparisons were inspected in Godot at 720×360, 844×390 and 932×430. No duplicate environment was generated or counted for this return visit; inventory stays at 3/5.

### Records office — 4 November 2026

Mode: built-in imagegen, new opaque environment, no reference image or CLI fallback. Final project file: `output/module4-art/records_office_v1.png`, 1672×941. Production uses the Cloudinary catalog URL above. Hosted download/cache decode and mobile-size Godot render checks passed. Source PNG remains ignored. This fourth environment is distinct from the public reception and private consultation room.

Exact prompt:

Use case: illustration-story. Create ONE edge-to-edge wide 16:9 environment background for LEVELBLUE, a Filipino school cybersecurity mobile visual novel. Polished anime background painting with crisp restrained pixel texture, cream plaster, dark teal window frames, navy shadows, warm wood, subdued cyan accents. Scene: a school RECORDS-OFFICE CONSULTATION COUNTER in late afternoon, distinct from an open reception lobby and from a private meeting room. View from the visitor side of a low L-shaped wooden records counter on the right, with glass partition above its rear section and a small document pass-through. Beyond the glass: orderly metal filing cabinets, shelves of closed folders with blank spines, a plain wall clock. To the left, tall louvered windows and partly drawn cream blinds cast long warm golden stripes across a quiet tiled floor. A potted plant and single empty visitor chair anchor the back left. A closed cream case folder and small empty document tray sit on the counter. The mood is calm verification after tension, grounded, orderly, visually rich but not cluttered. Keep the central foreground open for separately overlaid character sprites; lower quarter quiet for dialogue. NO people, faces, silhouettes, readable text, logos, seals, readable documents, computers, phone screens, UI, border, split screen, collage, or watermark. One coherent room, landscape composition.

### Administration reception — 4 November 2026

Mode: built-in imagegen, new opaque environment; no reference image or CLI fallback. Final local path: `output/module4-art/admin_reception_v1.png`, 1672×941. Hosted acquisition/cache decoding and Godot mobile-size renders passed. The PNG remains ignored; production uses the catalog URL above.

Exact prompt:

Create ONE edge-to-edge wide 16:9 environment illustration for LEVELBLUE, a Filipino school cybersecurity mobile visual novel. Polished anime background painting, crisp subtle pixel texture, grounded school architecture, cream plaster, dark teal frames, navy shadows, muted cyan light and restrained warm amber accents. NO people, silhouettes, readable text, lettering, logos, watermark, UI, collage, split screen or border. Generous clear central foreground for separately overlaid character sprites, lower quarter visually quiet for dialogue. School administration reception alcove in LATE MORNING: camera from the waiting area facing an open service window at the BACK LEFT, a long low wooden reception counter with stacked closed folders and a brass bell; three empty wooden waiting chairs and large potted tropical plant at the RIGHT; glass-block windows high along the back wall and a wide open-air corridor at the FAR RIGHT admit bright diffuse daylight. Notice board with blank colored paper shapes and an unmarked wall clock. Visually different from faculty workroom and private meeting room: airy public waiting area, institutional yet welcoming, clear empty center tiled floor, interesting layered architecture. No computer screens, no phones, no actual personal records. Preserve navy/cyan/cream school palette with natural warm wood. Full single coherent scene, not a montage.


### School briefing room — 4 November 2026

Built-in imagegen, new opaque 1672×941 environment. Exact prompt:

Use case: illustration-story. ONE wide 16:9 edge-to-edge environment background for LEVELBLUE, a Filipino school cybersecurity mobile visual novel. Polished anime painted school architecture with crisp restrained pixel texture. A SCHOOL BRIEFING ROOM in early evening, clearly distinct from a records counter, a small private consultation room, a faculty workroom and a reception lobby. View diagonally across an open central aisle, with a horseshoe arrangement of low dark wooden meeting tables at the edges and empty teal chairs, closed cream case folders, a blank cream whiteboard on the back wall. Large left-side windows show dusk blue tropical campus silhouettes, while warm ceiling lights illuminate the cream plaster and dark teal trim. Right wall has tall storage cupboards, a rolled blank projection screen and potted tropical plant. Calm but tense case-review atmosphere, navy shadows, muted cyan highlights, cream and warm wood. Leave generous central foreground and a quiet lower quarter for separately overlaid character portraits and dialogue; keep table edges mostly at left/right. No people, faces, silhouettes, computers, monitors, phones, readable text, writing, badges, logos, UI, borders, split screen, collage or watermark. This is a school room, not a grand courtroom.

### Sir Rham document counter — 4 November 2026

Built-in imagegen, new opaque 1672×941 illustration, referenced the existing `sir_rham_poses_v1.png` after visual inspection. Exact prompt:

Use case: illustration-story. Create one NEW wide 16:9 cinematic counter-argument illustration for LEVELBLUE's mobile cybersecurity hearing. Use the supplied sprite sheet ONLY as the identity/style reference for ONE Sir Rham: Filipino adult male teacher, dark navy cap, round thin glasses, dark hair at nape, warm complexion, tan textured short sleeve shirt, black wristwatch. Keep his recognizable face and clothing. NOT a sprite sheet, just one character. Place a dynamic confident three-quarter bust on the RIGHT HALF: determined expressive eyes, mouth open as he delivers a rebuttal, one hand gestures toward the evidence, other holds a plain closed cream folder; anatomy natural. On the LEFT HALF integrate huge legible exact lettering 'COUNTER!' in cream with cyan edges, pixelated dark navy block shadow; keep every letter well inside frame. Cybersecurity case-record motif: layered blank cream document outlines pull apart into separate source panels, cyan registration corner brackets snap into alignment, small square pixel fragments. Deep navy #050B18 background, #4FE0D4 cyan, #F3ECD6 cream; warm tan skin/clothing accents. Strong diagonals and anime linework with restrained pixel texture, dramatic but clean readable mobile composition, not a courtroom, no guns or bullets, no identifiable villain, no actual student details or official logos. Keep bottom 12 percent quiet dark navy for an in-game caption; no other text beyond COUNTER! Opaque full-frame artwork, no collage, no split screen.
