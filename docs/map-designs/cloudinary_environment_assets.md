# Cloudinary environment assets

Seven runtime assets are registered in `AssetManager._map_environment_catalog()`:

| Asset ID | Uploaded filename |
| --- | --- |
| `home_base_clean` | `home_base_clean_v1.png` |
| `home_base_cracked` | `home_base_cracked_v1.png` |
| `home_base_critical` | `home_base_critical_v1.png` |
| `enemy_spawn_broken_pc` | `enemy_spawn_broken_pc_v1.png` |
| `map_module_1_stage_2` | `module_1_stage_2_25d_baked.png` |
| `map_module_1_stage_3` | `module_1_stage_3_25d_baked.png` |
| `map_industrial_atlas` | `industrial_atlas.png` |

The versioned URLs live in the catalog. Asset sync downloads them into
`user://assets/<asset_id>.png` and records versions/hashes in the asset database.
Subsequent play uses the local cache. A new installation needs an initial download;
offline play requires those cached files to remain available.

The bases, destruction animation, Stage 2/3 backgrounds, and native isometric
TileSets no longer have hard PNG dependencies in their scenes. The local PNGs
were already removed during integration; they were not restored or duplicated.
Dynamic bundled fallbacks remain for endpoint/background assets if a build
deliberately includes them, but they are not required to parse these scenes.

The original `module_1_isometric_kit_source_v1.png` upload is a design/source
sheet, not the runtime atlas. It is intentionally excluded from the game catalog.
The corrected `industrial_atlas.png` upload matched the previous runtime PNG's
SHA-256 exactly. Never resize or rearrange it without rebuilding tile regions.

Verification: `--headless --path frontend --script
res://src/tools/verify_cloudinary_environment.gd`. Add `-- --download` to force
validation/download of these seven assets only. Standard mode checks offline
cache bindings, health states, destruction art, both baked stages, and the shared
atlas. Isometric-kit, Stage 1 gameplay, and defeat regression tests also pass with
the repository PNGs absent.
