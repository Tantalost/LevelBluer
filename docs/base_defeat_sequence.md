# Base defeat sequence

Defense losses now retain the live battlefield behind the results. The reference
video's destruction segment (roughly 16.5 seconds onward) informed the red-magenta
grading, large destruction title, ongoing pixel fire, sequential reward reveal,
and centered Upgrade / Restart controls. The text is `BASE DESTROYED`.

## Runtime flow

1. A final breach commits GAME_OVER and invalidates wave spawning immediately.
2. The existing 10-credit loss payout runs once. Duplicate leak, kill, and terminal
   callbacks cannot issue another payout or continue changing the match.
3. The environment stops processing, the gameplay HUD is hidden, and time scale
   returns to 1. The shared endpoint effect continues processing independently.
4. The critical server-base texture splits into 36 pieces, leaving a charred
   remnant with animated pixel fire, smoke, and embers.
5. A live screen shader grades the map. The title appears at 0.25 seconds; credit,
   wave, and kill results reveal from 1.65 seconds; actions activate at 3.6 seconds.
   Skip completes only the UI reveal; it never awards anything.
6. Upgrade opens the existing research screen; Restart restarts the active stage.
   Lessons and Back retain the remediation and return routes. Router tears down
   the map, overlay, and destruction effect together when leaving.

Summative exam failures with health remaining retain their advisory results;
they do not pretend that the base was destroyed. Tutorial handling and victory
presentation are unchanged.

## Components and assets

- `gameplay/base_destruction.gd`: reusable sprite-fragment collapse and pixel FX.
- `gameplay/maps/map_endpoint_visuals.gd`: one-time shared home destruction hook.
- `ui/screens/victory/base_defeat_overlay.gd`: timed presentation and action signals.
- `ui/screens/victory/defeat_tint.gdshader`: live battlefield grading and vignette.
- `ui/screens/victory/defeat_action_button.gd`: reusable pixel-metal result frame.

No new production images or video assets. Destruction reuses the existing
`home_base_critical_v1.png`; the input video and frame-review files are not shipped.

## Checks

`--headless --path frontend --script res://src/tools/verify_base_defeat.gd`
exercises the actual final breach, duplicate events, frozen combat, progressing
animation, timing, skip, button signals, compact bounds, and cleanup. The test
manager overrides only payout and navigation endpoints, so it never saves player
progress or leaves the test scene. Add `-- --render` with a rendering driver to
capture review frames inside the ignored `.godot` directory.
