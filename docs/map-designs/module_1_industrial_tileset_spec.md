# Module 1 industrial tileset specification

This document freezes the reusable visual rules established by the Module 1,
Stage 1 2.5D map. The current map is still procedurally drawn; these categories
are the intended source list when the design is converted into a texture atlas.

## Projection and dimensions

- Logical gameplay cell: 32×32 px.
- Recommended atlas cell: 48×48 px, leaving room below/right for an 8 px face
  and a 12 px cast shadow without changing the logical footprint.
- Camera: near top-down orthographic. Tile tops remain rectangular so existing
  ASCII coordinates, enemy paths, and tower hit testing do not need projection.
- Light direction: upper-left to lower-right.
- Standard elevation: 8 px; machinery elevation: 10 px.
- Standard shadow offset: +8 px X, +12 px Y.

## Tile families

| Family | Required variants | Gameplay meaning |
| --- | --- | --- |
| Deck | clean A/B, bolted, grate, lit | Buildable base floor |
| Recessed route | horizontal, vertical, four corners, cap | Enemy-only lane |
| Raised platform | 2×2, 3×2, 3×3, 4×2 edges/corners | Buildable high-ground presentation |
| Perimeter | top rail, front fascia, side wall, hazard edge | Non-playable boundary |
| Machinery | vent cabinet, server rack, dual fan, conduit | Boundary or decorative module |
| Gate | cyan entry and red data-core exit | ASCII `S` and `E` markers |

## Material language

- Deck tops use cool charcoal steel with low-contrast variation.
- Raised tops use off-white or medium steel with bright upper/left bevels.
- Front and right faces are 45–65% darker than their top surface.
- Route wells are darker than the deck and receive an internal contact shadow
  from adjacent floor lips.
- Cyan is reserved for entry/navigation; red is reserved for the protected core;
  amber is limited to hazard strips and small practical lights.
- Bolts, seams, grates, fans, and wall panels should be separate variants, not
  baked randomly, so maps can stay readable and avoid obvious repetition.

## Authoring constraints

- Never move the visible top footprint away from its 32×32 logical cell.
- Side faces and shadows may overlap lower/right neighbors but must not imply a
  different collision area.
- Enemy lanes must remain visually continuous across straight and corner tiles.
- Decorative machinery must stay off the path and may not obscure tower centers.
- Each tile should remain readable under the gameplay vignette and placement
  overlays at the 1280×720 reference resolution.
