# Industrial isometric TileMap kit

Ready to paint in Godot 4.7.2. This is an authoring kit, not a replacement for a live stage.

## Start here

1. Open `frontend/project.godot` in Godot.
2. Open `res://src/gameplay/maps/isometric/industrial_kit_workbench.tscn`. The material patches and scenery pads are a kit preview, not a stage.
3. Select **Ground**, **FloorDetails**, or **Scenery** in the scene tree, then paint using Godot's bottom **TileMap** panel.
4. Press **F6** to run the preview. Mouse wheel zooms; middle mouse pans.
5. For a new map, open `res://src/gameplay/maps/isometric/isometric_map_template.tscn`, then **Save As** your own scene. It deliberately starts empty. Paint the Ground layer first.

The kit uses native atlas tiles for floors and native scene-collection tiles for larger objects. See Godot's [TileSet documentation](https://docs.godotengine.org/en/stable/classes/class_tileset.html) and [scene-collection documentation](https://docs.godotengine.org/en/stable/classes/class_tilesetscenescollectionsource.html).

## Layers and resources

| Layer | Resource | Use |
| --- | --- | --- |
| Ground | `res://assets/gameplay/isometric/industrial_floors.tres` | Paint the playable footprint. Source 0 is buildable ground; source 1 is route ground. Both offer the same material art. |
| FloorDetails | Same floor TileSet | Choose source 2 for edge/corner overlays; paint over existing Ground cells. |
| Scenery | `res://assets/gameplay/isometric/industrial_scenery.tres` | Select a category, then paint multi-cell modules by their anchor cell. |

All art is packed in **one 2048 × 2048 PNG** (about 3.3 MiB), downloaded from
Cloudinary as asset ID `map_industrial_atlas` and cached at
`user://assets/map_industrial_atlas.png`.
The floor resources and scenery modules share
`res://assets/gameplay/isometric/industrial_atlas_texture.tres`, which loads the
cached PNG without requiring the image in the repository. Run the game's asset
sync once before using the editor workbench. Reopen the scene after downloading
if the editor loaded its transparent pre-sync placeholder.
The module scenes reference regions of this texture. Mirrored variants reuse their original regions; they do not duplicate texture pixels.

Inventory:

- 16 base material variants, derived from the approved ten floor drawings.
- 8 concrete/metal and concrete/grate transition variants.
- 15 edge combinations and 4 inner-corner overlays.
- 85 extracted scenery drawings; 112 paintable modules including mirrored variants.
- Nine scenery categories: edges, walls, doors, platforms, ventilation, machinery, cover, pipes, decoration.

The geometric floor foundation is exact **128 × 64**, isometric diamond-down. Ground-axis steps are (64,32) and (-64,32). Floor texture sampling excludes the original bevel, with a shared perimeter to prevent transparent seams. The original artistic tile outlines no longer define the grid.

## Footprints, collision and placement

Each scene in `res://src/gameplay/maps/isometric/modules/` exports:

- `module_id`
- `occupied_cells`: offsets from the painted anchor
- `blocks_movement`
- `show_footprint`: optional editor outline

Footprints are explicit arrays, including L-shaped corner modules. Mirrored modules transpose their footprint coordinates as well as mirroring the artwork. Artwork is grounded using a front contact point, and may rise above its occupied cells. Y sorting is enabled for scenery and its visual nodes.

Blocking modules contain one diamond collision polygon per occupied cell on physics layer 1. Nonblocking platforms, pipes and dressing have no collision by default. These are conservative, editable occupancy choices; ramps and platforms are visual pieces, not a simulated elevation/navigation system.

**Godot's native scene painting stores only the anchor; it does not automatically reserve neighboring cells.** The template's root script validates the full footprints and reports off-ground or overlapping placements as configuration warnings. Toggle **Validate Placement** in the root Inspector to print the detailed results. Manually erase or reposition invalid scene tiles.

For code-driven placement, use the root's checked API:

```gdscript
# IDs are in res://assets/gameplay/isometric/module_registry.json.
var placed: bool = map.place_module(source_id, scene_id, anchor_cell)
var reserved: Dictionary = map.occupied_cells()
var solid_cells: Dictionary = map.occupied_cells(true)
var tower_cell_available: bool = map.is_buildable(cell)
```

`place_module` rejects overlapping or off-ground footprints. It does not build an enemy route or replace the existing stage path system. Route/buildable flags are available on Ground tile custom data.

Module 1 Stage 1 now uses this kit through `stage_one_isometric.gd`, including projected placement previews, actor scale, ground-distance combat and path speed. Other stages retain their existing square-grid presentation. See [Stage 1 integration notes](module_1_stage_1_isometric.md).

## Painting borders and transitions

Floor overlay masks name their selected sides by bits: 1 = +X, 2 = +Y, 4 = -X, 8 = -Y. For example, mask 1 is a single straight edge, mask 3 joins two edges, mask 5 is a two-sided strip, and mask 15 encloses all sides. Inner-corner overlays are separate choices.

Material transitions and borders are manually paintable tiles. They are not configured as automatic terrain brushes. Use restrained mixtures of the material variants to reduce repetition.

The props retain the approved source illustrations. Their anchors and occupancy are normalized, but their painted perspective and shading are not reconstructed from 3D geometry. Mirroring also mirrors baked highlights. Thin walls/railings use conservative cells even where the visible object occupies only a boundary.

## Regenerate and verify

The source PNG is retained at `docs/map-designs/module_1_isometric_kit_source_v1.png`.
Crop rectangles, footprints and flags are in
`frontend/src/tools/isometric_kit_manifest.json`.
The converter uses Godot's Image and resource APIs; it makes no image-generation calls.

From the repository root, replace `godot` with your executable:

```powershell
godot --headless --path frontend --script res://src/tools/build_isometric_kit.gd -- --atlas
godot --headless --path frontend --editor --import
godot --headless --path frontend --script res://src/tools/build_isometric_kit.gd -- --resources
godot --headless --path frontend --script res://src/tools/verify_isometric_kit.gd
```

Regeneration overwrites generated kit resources and the two provided kit scenes. Save your authored map under a different filename. Change shared module definitions in the manifest/converter if they must survive regeneration.

Verified in Godot 4.7.2:

- Both TileSets and all 112 module scenes load.
- Cell projection and coordinate round trips match the 128 × 64 grid.
- All 65,536 pixels of a 4 × 4 floor patch are covered exactly once.
- Full multi-cell occupancy survives saving/loading; off-ground and overlap placement is rejected by the helper.
- Every blocking module has collision for every occupied cell.
- Scene tiles instantiate and render with the shared atlas.
- OpenGL rendered overview and close-up inspected; screenshots remain in ignored `.godot/` only.

For Cloudinary, the only new runtime image to upload is `industrial_atlas.png`.
Keep the TileSets, module scenes and registry in the project; they define the atlas regions and gameplay metadata. Remote loading has not been configured for this kit yet.
