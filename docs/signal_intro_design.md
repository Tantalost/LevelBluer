# Separate signal-defense intro

The new `signal_intro.tscn` is an animation-only scene shown before the original title card. It contains a framed pixel vignette, a short caption, and Skip. It has no logo, Start Game button, asset requests, or navigation.

A hostile envelope approaches a server outpost, a shield intercepts it, and the city lights up. After 1.8 seconds (or immediately on Skip), it emits `finished` and the parent reveals the original title screen. Elapsed wall-clock timing prevents slow frames or app suspension from stretching the animation. There is no scrolling story or full-screen flash.

## Preserved title

`intro_screen.tscn` is restored to its original scene definition. Its Cloudinary preview background, original logo texture and bob animation, tagline, Start Game styling, hint, and layout remain intact. Only the old lengthy pan/flash sequence is replaced. The existing Start → loading splash → session/login flow is unchanged.

Cached title textures display immediately. If absent, the existing asset synchronization runs in parallel with the cinematic, and textures bind when ready. This download is separate from the animation timing; a first-install/offline title background can remain unavailable until synchronization succeeds.

## Mobile and assets

The cinematic uses a fixed 320×104 code-drawn canvas, integer scaling, safe-area padding, and a Skip touch target of at least 48 physical pixels. No new image files or Cloudinary uploads are required. The existing title design is not resized or redesigned.

## Verification

Run Godot with `--path frontend --script res://src/tools/verify_signal_intro.gd`; add `-- --render` for screenshots in the ignored `.godot` folder.

Checks cover automatic handoff within two seconds, Skip, original title textures/layout/button styling, re-entry, slow frames, exit cancellation, resume, and unchanged credits/completion. Layout is checked at 1280×720, 960×600 and 844×390, including simulated phone safe-area insets. The harness never presses Start or downloads assets. If title textures are absent it explicitly reports in-memory fixtures; these are test-only and never saved.
