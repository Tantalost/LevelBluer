# Intro and loading presentation

## Disclaimer and title

The intro fades from black into the academic disclaimer, then waits for Continue.
There is no animated logo reveal, game-mode banner or automatic disclaimer timeout.
The existing title screen and Start → loading → login/dashboard navigation are preserved.

## Paired loading eyecatches

The splash uses two separate original pixel-art illustrations:

- `frontend/assets/ui/loading_before_v1.webp`: Alex on the left pulling a switch; Mia on the right at the keyboard.
- `frontend/assets/ui/loading_after_v1.webp`: a new low-angle composition, Mia in the left foreground and Alex on the right celebrating, with a shield/check behind them.

Both are 1672×941 lossless WebP files (3,300,436 bytes combined).
They are bundled locally so the loading artwork itself does not depend on the downloads it describes.
The first artwork is unchanged; the final second image replaces the rejected same-composition draft.
No Cloudinary upload was performed.

The existing SplashScreen owns both TextureRects, the footer and its lightweight activity sweep.
AssetManager exposes a read-only synchronization snapshot and retains its existing progress signal.
The splash subscribes only during its asset phase and disconnects on completion, retry or exit.
No additional loading manager is introduced.

Progress is based on completed boot work: settings, save/profile, content, catalog checks,
required-asset readiness and account restoration. Catalog checks occupy 10–85 percent;
required-asset validation advances to 90 percent; session completion permits 100 percent.
The visual fill eases toward—but never beyond—measured work.
A subtle activity sweep indicates a pending request without inventing percentage progress.
The footer reports checked entries and download bytes when available, without treating failed checks as successful downloads.

The separate ready image crossfades in only after required assets and session checks finish.
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

## Artwork provenance and exact prompts

Created using the **imagegen skill**, built-in image-generation tool (not the fallback CLI).
Alex/Mia dialogue atlases supplied character identity and outfit references.
For the second illustration the accepted first image was a style reference only.
Selected outputs were converted losslessly to WebP; no source PNGs were added to the repository.

### Before — final prompt

Use case: illustration-story. Asset type: first of two matching landscape 16:9 loading-screen eyecatch illustrations for LEVELBLUE, a teenage cybersecurity pixel-art game. Input 1 is Alex identity/outfit reference only; input 2 is Mia identity/outfit reference only, not layout targets. Create a single original full-bleed wide illustration, not a sprite sheet. Alex (tousled brown hair, warm tan skin, blue overshirt, cream T shirt) and Mia (dark chin-length bob, warm tan skin, teal cardigan, cream collared shirt) scramble playfully to power up a chunky cyber-defense console, faces determined with a little comic nervous energy. Alex reaches for a large switch; Mia works on a keyboard. Same scene must be usable for a later 'defenses online' companion. Distinctive anime-eyecatch energy through bold diagonal composition and dynamic perspective, but entirely original, no existing anime characters/insignias. Crisp deliberate pixel clusters, dark outlines, limited navy #050B18 #0A1730 #102040 and teal #153B37, cyan #4FE0D4 accent light and cream highlights; subtle amber standby indicators. Restrained lighting, no blinding bloom. Large readable character silhouettes grouped in central upper 70%; console machinery and shield-shaped power core behind them. Bottom 25% stays dark and low-detail for native UI. Faces kept away from side edges for mobile landscape cropping. No text, lettering, numbers, logos, watermark, HUD, progress bar or borders. Opaque background. Wide 16:9.

### Defenses online — final prompt

Use case: illustration-story. Asset type: separate DEFENSES ONLINE loading-complete eyecatch illustration for LEVELBLUE. References: image 1 is ONLY palette, character identity and pixel-art style reference; do not reuse its camera or composition. Images 2 and 3 are Alex and Mia identity/outfit references. Make a distinctly NEW full-bleed wide 16:9 illustration: swap the staging completely. Mia stands in the LEFT foreground, short dark bob, teal cardigan and cream collared shirt, beaming confidently with one fist raised beside her shoulder. Alex stands RIGHT slightly behind her, tousled brown hair, blue overshirt cream T-shirt, laughing in relief with one hand on his hip and other raised in a small victorious fist. Both are teenage cybersecurity defenders, not armed soldiers. Different viewpoint: wide dramatic low camera looking across the powered-up defense control room, with the console now behind them, no pulling levers or typing keyboard. A large geometric cyan shield/check hologram hangs in the background on the far right behind Alex; staggered navy server racks and diagonal circuit trails converge toward upper left. Characters central and faces safely within middle 75 percent; stylish confident victory grouping with strong silhouetted poses, dynamic diagonal anime-eyecatch framing but original characters/artwork only. Crisp intentional pixel clusters, limited navy #050B18 #0A1730 #102040, teal #153B37, cyan #4FE0D4, cream highlights. Soft success lighting, no blinding bloom or huge flares. Keep bottom 25 percent dark and visually quiet for native loading-complete UI. No text, letters, numbers, logos, watermark, progress bar, UI elements, split panels or border. Opaque. This MUST look like a new illustration and pose arrangement, not a recolor of the first reference.
