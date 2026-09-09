# Module 1 — Stage 1 industrial intake deck

The live `frontend/src/gameplay/maps/map_basic.tscn` scene now uses the modular kit through `isometric/stage_one_isometric.gd`. No baked map image or newly generated art is required. Floors and scenery share the kit atlas.

## Presentation

- Exact 128 × 64 isometric cells, framed to fill the play area with a plain dark surround.
- The legacy forest, oversized road, trees and castle are hidden for this authored environment.
- Raised deck faces, metal service apron, perimeter walls/railings and restrained route chevrons.
- Interior cooling, power and cargo bays with fans, HVAC, generators, pipes, tanks, cabinets, containers and crates. Grates and hazard paint identify the utility areas.
- Existing broken-PC spawn and health-reactive server base sprites, scaled for the new projection.

## Gameplay

All 416 logical ASCII cells and the 35-cell route distance remain intact. The added interior machinery reserves 33 previously buildable cells. There are 110 valid 3 × 3 deployment centers after accounting for machinery, route and edges. No scenery footprint intersects the enemy route.

Tower placement uses custom buildability plus scenery occupancy, not atlas coordinates. The drag preview follows the nine diamond cells of the footprint. Actor size and deployment animation scale are adapted to this map. Enemy movement keeps the original time per logical cell. Tower range uses a projected ellipse; projectile speed and splash distance use the original ground-space metric.

Level initialization now waits for the map builder before reading its endpoints and presentation flags. This binds the actual PlayerBase collider and health-dependent endpoint art correctly and suppresses the fallback backdrop on first entry.

## Verification

Run from the repository root with your Godot executable:

```powershell
godot --headless --path frontend --script res://src/tools/verify_stage_one_isometric.gd
```

The test loads the live level and checks all cell flags, scenery-aware deployment, endpoint/collider alignment, health-hook binding, route length, enemy travel time, actual tower placement, range acquisition and projectile damage. It also checks that Stage 2 retains its square grid and route restrictions.

Adding `-- --render` with a rendering-capable Godot run saves full-level clean and combat previews under ignored `frontend/.godot/`. These are verification captures, not game assets.

Validated with Godot 4.7.2: 416 cells, 110 expected/actual deployment centers, zero test failures. Full HUD/map renders were inspected after background removal and reframing.
