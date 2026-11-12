# Intro and loading presentation

## Disclaimer and title

The intro fades from black into the academic disclaimer, then waits for Continue.
There is no animated logo reveal, game-mode banner or automatic disclaimer timeout.
The existing title screen and Start → loading → login/dashboard navigation are preserved.

## Loading illustrations

The splash cycles through ten Cloudinary illustrations of the school-story cast. It requests one 1280-pixel WebP per visit and reuses cached illustrations offline. The last displayed index persists across launches. Artwork loads independently of boot progress.

AssetManager exposes a read-only synchronization snapshot and retains its existing progress signal.
The splash subscribes only during its asset phase and disconnects on completion, retry or exit.
No additional loading manager is introduced.

Progress is based on completed boot work: settings, save/profile, content, catalog checks,
required-asset readiness and account restoration. Catalog checks occupy 10–85 percent;
required-asset validation advances to 90 percent; session completion permits 100 percent.
The visual fill eases toward—but never beyond—measured work.
A subtle activity sweep indicates a pending request without inventing percentage progress.
The footer reports checked entries and download bytes when available, without treating failed checks as successful downloads.

The current illustration stays visible as the footer confirms that required assets and session checks have finished.
It holds for 1.1 seconds, then fades to the existing destination.
Missing required assets retain the first artwork and expose Retry.
Reduced motion disables the activity sweep; there are no flashes, shakes or rapid cuts.
Cancellation tokens prevent stale asynchronous work from navigating after the splash exits.

## Verification

- `verify_loading_screen.gd`: deterministic I/O stand-in exercising production progress, retry, ready transition and routing.
- Checks include known/unknown download sizes, truthful stationary progress during pending I/O,
  late progress snapshots, duplicate notifications, required-asset failure, repeated Retry,
  signed-in/signed-out routing, exit cancellation, reduced motion and unchanged player data.
- Landscape checks: 1280×720 and 844×390, including readable footer and reachable Retry.
- `verify_signal_intro.gd`: disclaimer regression checks.
- Run either with Godot `--headless --path frontend --script res://src/tools/<script>.gd`.
  For loading visual captures, omit headless and append `-- --render`; screenshots stay in ignored `.godot`.
- These deterministic tests do not certify live network/server behavior.
