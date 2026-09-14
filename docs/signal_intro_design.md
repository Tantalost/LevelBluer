# Signal defense intro

The opening uses an original code-drawn pixel vignette: a hostile envelope approaches a server outpost, a shield intercepts it, and the surrounding city lights up. A framed illustration on black and a short caption borrow the storybook presentation of the reference without reusing its characters or artwork.

## Timing and interaction

- 0–0.60 seconds: establish the outpost and incoming signal.
- 0.60–1.24 seconds: shield activates with one localized pixel impact.
- 0.88–1.56 seconds: title and Start Game appear as the city wakes.
- 1.80 seconds: Start Game is enabled and animation processing stops.
- Skip immediately reveals the ready title. It does not start loading or navigate.

Timing uses elapsed wall-clock time, so a slow frame or app suspension does not prolong the reveal. There is no full-screen flash, strobe, scrolling story, or new audio. The normal post-Start splash, asset loading, session validation, and routing are unchanged; their duration is separate from this short intro.

## Assets and mobile

No new image assets, Cloudinary requests, or generated textures are needed. The illustration is drawn on a fixed 320×104 canvas with integer scaling. Existing bundled fonts and shared button styles are reused. Safe-area margins and scaled touch targets support compact landscape screens; hidden Skip retains its layout space so the title does not jump when the reveal finishes.

## Verification

Run Godot with `--path frontend --script res://src/tools/verify_signal_intro.gd`. Add `-- --render` with a graphical renderer to capture frames in the ignored `.godot` directory.

Checks cover the two-second cap, immediate Skip, replay reset, slow-frame completion, exit cleanup, 48-pixel Start targets, safe-area layout at 960×600 and 844×390, and unchanged player credits/completion records. Rendered frames also cover 1280×720. This intro-only harness does not press Start, contact the backend, or alter player progress.
