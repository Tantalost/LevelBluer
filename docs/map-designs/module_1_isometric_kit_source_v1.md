# Module 1 isometric kit — visual source v1

> The source-art limitations below describe the original generated sheet. A usable Godot kit has now been derived from it with normalized floors, packed sprite regions, TileSets and explicit scenery footprints. See [the TileMap kit guide](module_1_isometric_tilemap_guide.md) for the current deliverables and validation.

## Deliverable and status

`module_1_isometric_kit_source_v1.png` is a 1086 × 1448 RGBA source-art sheet generated with the built-in ImageGen tool from the user's industrial courtyard reference. Corner and sampled gutter alpha are zero. This is a visual source kit, **not a validated, import-ready Godot TileSet**. No current gameplay map, layout, collision, entrance, exit, or obstacle was changed.

The generated artwork includes ten separated category bands without labels: floors; edges/corners; walls; doors; stairs/platforms; ventilation; machinery; cover/obstacles; pipes/cables; small decoration. It captures concrete, grates, fan housings, industrial walls, railings, piping, tires and debris from the reference.

## Production requirements still outstanding

- The floor row contains ten tiles, not the sixteen requested in the prompt. The complete transition and oriented corner set is not present.
- Generated diamond outlines and object projections are not mathematically validated at 2:1. Do not use their current image bounds as gameplay cell dimensions.
- Sprites are arranged visually, not in uniform atlas cells. No slicing rectangles or origin offsets have been authored.
- Multi-cell footprint sizes below are intended authoring constraints, not verified metadata for the generated sprites.
- Seamless neighboring texels, all connector orientations, and alpha edge quality require production cleanup and adjacency testing.
- No `.tres` TileSet, collision polygons, terrain connections, occlusion polygons or scenery scenes were created.

## Authoring contract

Use a 128 × 64 ground diamond: top (64,0), right (128,32), bottom (64,64), left (0,32). Grid steps are (64,32) and (-64,32). Height extends vertically upward independently of ground projection.

Floors define gameplay. Keep ground tiles flat, congruent, and edge-compatible. Materials and wear vary internally. Place larger scenery using explicit occupied-cell coordinates and an origin on the ground plane; texture dimensions do not define collision.

Intended footprint families:

| Family | Footprints |
| --- | --- |
| Ground material, transition, edge and corner | 1 × 1 |
| Short, medium and long walls | 1 × 1, 2 × 1, 3 × 1; axis counterparts |
| Wall junctions | Explicit L/T occupied-cell lists |
| Doors and windows | 1 × 1 or 2 × 1 |
| Platforms | 2 × 2, with separate edge/corner modules |
| Stairs and ramps | 2 × 1; both axes |
| Ventilation and machinery | 1 × 1, 2 × 1, 2 × 2 |
| Cover, fences, railings, containers | 1 × 1, 2 × 1, 3 × 1 |
| Pipes and cable runs | 1 × 1, 2 × 1, 3 × 1; compatible connector ends |
| Loose decoration | Within one cell; occupancy chosen separately |

When reconstructing the reference, preserve its gameplay cell identities and connectivity. An isometric projection changes screen positions, not room/corridor topology, obstacle occupancy, entrances or exits. The screenshot alone is not sufficient to validate hidden or ambiguous gameplay semantics; use the existing logical map as well.

## Prompt record

Generated using the built-in ImageGen tool. The first output established the kit; a targeted correction requested 2:1 reprojection and missing floor variations; a final extraction requested real alpha. Only the selected source sheet is copied into the repository.

### Initial generation prompt

Use case: stylized-concept.
Asset type: ONE professional reusable game environment ASSET SHEET / SPRITE TILESET, intended for a Godot 4.7 2D TileMapLayer workflow.
Input image 1 is the user's strict source reference for the environment's components, gameplay proportions, obstacles, landmarks, materials and visual language. It is NOT the output composition: do not reproduce or redesign a finished map. Extract its kit of parts so its original rooms, corridors, routes, entrances, exits, playable area and obstacle arrangements can later be rebuilt without rearrangement.

Create one large high-resolution transparent PNG asset atlas, preferably 3072 by 4096, with individually isolated components, generous regular gutters, no overlaps or crops, no text or labels. Use ten clearly separated horizontal category bands, organized in orderly rows, with larger objects receiving larger slots. No background surface connecting the assets. True alpha background, never a painted checkerboard.

CRITICAL GEOMETRY: fixed orthographic 2:1 isometric game projection for EVERY piece. Floor top diamonds exactly twice as wide as high, identical scale; axes project with rise/run 1/2, verticals perfectly vertical, no vanishing points, no perspective diminution. Base design unit 128x64 pixels at the working sprite scale: diamond vertices (64,0), (128,32), (64,64), (0,32). Use same unit for all objects and all floor top faces. Simple perfectly congruent tile boundaries and matched neutral border texels; internal wear must stop before or match at borders, enabling seamless adjacent floor tiles. Basic floor tiles nearly flat, no chunky floating plinths. Raised platform objects separate from flat floor tiles. Floors alone define gameplay grid. No arbitrary rotation or individually rescaled objects. Multi-cell modules occupy integer grid footprints, with clearly readable bases and tile divisions where appropriate; artwork may extend vertically, without being squeezed into a single cell. Both grid-axis orientations must be represented for connecting pieces. Matching heights, connector cross sections and endpoints across modules.

ORDER from top to bottom, category names are instructions ONLY, do not draw them:
1 FLOOR TILES: 16 same-size independent 1x1 floor diamonds: basic concrete, 3 subtly different concrete textures, damaged/chipped concrete, fine cracked concrete, heavily cracked concrete, oil-stained concrete, damp stained concrete, weathered metal plate, alternate riveted metal, grated floor, alternative grate, restrained yellow hazard edge, circular access cover, muted teal technical floor with very small restrained magenta corner lamps. Readable understated textures, seamless flat perimeters.
2 FLOOR EDGES & CORNERS: comprehensive 1-cell modular curb and floor border set: four oriented straight edges, four outer corners, four inner concave corners, short end caps in both axes, concrete-to-metal and concrete-to-grate transitions, floor-to-wall skirting transitions. Consistent 2:1 top surfaces, low shallow vertical edge faces only where intended, exact continuous joins.
3 WALL MODULES: 1x1 short, 2x1 straight, 3x1 long wall sections and their other-axis variants; same wall height, inner and outer corners, T-junction, capped ends, weathered window wall, damaged wall variation. Dark industrial concrete with panel seams, recessed vents, matching top coping. Open modular sections only, no complete buildings or rooms.
4 DOOR MODULES: matching industrial door frames, closed and open sliding doors, service door and shutter door, plus recessed industrial window section, both grid-axis orientations. Wall-height matched to category 3, frames join its ends. 1x1 and 2x1 footprints.
5 STAIRS & PLATFORMS: low 2x2 modular platform, 2x1 platform edge, platform corner, 2x1 stairs in both directions and 2x1 ramps in both directions; consistent platform rise, exposed realistic vertical faces and rail attachment points.
6 VENTILATION / INDUSTRIAL MODULES: the source's prominent circular raised fan housings, both clean and worn 1x1 versions; large 2x2 fan housing; large 2x1 duct vent; 2x1 double-fan air conditioner; 1x1 utility ventilation box; 2x1 rooftop HVAC equipment. Open grille detail, bolts, ducts, shadows recessed into the machinery.
7 MACHINERY: 2x1 generator, 1x1 electrical cabinet in two variants, 2x2 industrial machine, 2x1 horizontal tank, 1x1 vertical tank, rooftop utility equipment and utility boxes. Mechanical construction with muted teal indicator lamps and small restrained red warning indicators, no writing.
8 COVER & OBSTACLES: short and long waist-high concrete barrier, damaged barrier, 2x1 metal barricade, 1x1 crates in two variants, 3x1 industrial container, 2x1 railing in both axes, railing corner, 2x1 chainlink fence in both axes, fence end post. Keep cover appreciably lower than walls.
9 PIPES & CABLES: compatible straight pipe modules, elbow bends, T connections, vertical risers, matching clusters of parallel pipes, valve junction, overhead cable span, short floor cable bundles and cable corner. Both grid-axis directions, consistently aligned connection ports, footprints 1x1, 2x1 and 3x1 as appropriate.
10 SMALL DECORATION: source-derived individual tire and loose tire stack, small broken grate, trash bag cluster, compact rubble, scattered concrete chips, small scrap metal, bin, industrial lamp, small unlettered emissive fixture. Footprints contained within one grid cell. Isolated reusable dressing, not piles filling a whole scene.

STYLE: match the supplied reference's gritty futuristic industrial cyberpunk surfaces and high-detail miniature tactical battlefield appearance. Charcoal gray, dark concrete, desaturated blue-gray, muted teal, subtle green and extremely restrained magenta/red neon accents. Realistic scale relationships and convincing vertical mass. Weathered metal, grime, rust, scratches, cracks, stains, chipped paint, panel seams and cables. Premium tactical RPG miniature-diorama rendering, finely detailed crisp game sprites, clean silhouettes. Floors remain brighter and simpler than tall scenery so navigation stays readable. All sprites lit consistently from upper left, modest cool fill, strong localized contact shadows and ambient occlusion baked within the object's footprint, subtle confined light scattering by emissive fixtures only. No large cast shadows, bloom clouds or atmospheric overlay across gutters.
ABSOLUTELY NO finished map, connected scene, characters, enemies, UI, HUD, text, labels, numbers, logos, watermark, perspective distortion, random composition, decorative surrounding environment, checkerboard pixels or thick borders around sheet. Prioritize structural consistency and reusable matching modular connections over concept art composition.

### Geometry correction prompt

Edit the supplied asset sheet into a corrected modular game kit. Preserve its industrial designs, category order, palette, and detail. Two mandatory production corrections:
1. REPROJECT ALL ASSETS onto exact 2:1 isometric geometry. Current floor diamonds are too tall (roughly 1.5:1). Correct each flat floor TOP FACE to exactly twice as wide as tall: horizontal span 128, vertical span 64. Ground axis vectors (64,32) and (-64,32). Parallel edges have slopes +0.5 and -0.5. Vertical structure lines stay vertical and maintain realistic wall/object heights; do not squash the entire sheet. Reproject floor planes and object bases consistently, preserving vertical height. Flat floor base tiles have no thick extruded sides.
2. REMOVE the baked white/gray checkerboard completely, output genuine transparent PNG ALPHA outside every sprite, including holes in railings and frames. Do not draw a checkerboard or any background color.
Complete the floor section at top into TWO orderly rows with sixteen equally sized 2:1 tiles including basic concrete, three concrete variations, damaged, cracked, stained, metal, grated, hazard, circular access cover and restrained emissive floor. Include transition tiles and all four orientations of straight edges, inner corners, outer corners and end pieces in the following band. Keep remaining categories orderly and separate. Do not reduce the existing inventory of wall, door, platform, stair, ramp, ventilation, machinery, cover, pipes, cable and small prop pieces.
Fixed shared orthographic camera for the entire kit, matching integer-grid footprints. 1x1, 2x1, 3x1, 2x2 bases share the same diamond grid. Consistent upper-left lighting, no perspective distortion. Generous transparent gutters. High resolution full sheet, crisp fine details. Absolutely no text, labels, UI, characters, map, background scene or watermark. This is a reusable sprite atlas, not a finished level.

### Transparency extraction prompt

Use case: background-extraction. Edit target: the supplied industrial modular sprite asset sheet. Remove all of the gray and white checkerboard background, including the checkerboard inside door frames, railings, fences and between small cables. Export a genuinely transparent PNG with alpha=0 in all empty background and gutter areas. Preserve every existing sprite's position, scale, color, details and silhouette exactly. Keep all ten rows. Do not redraw or restyle objects. No checkerboard pixels, no white background, no labels, no added shapes. Actual transparent background, isolated sprite cutouts only.
