# Scenic dashboard / command outpost

The six central menu buttons keep their authored shapes, textures, actions, and relative arrangement. Only the surrounding screen is redesigned: slate header, quiet teal accents, scenic pixel-art background, compact field progress, and a right-side holographic Handler.

## Assets

- New background: `frontend/assets/ui/dashboard/command_outpost_v1.png` (one image, generated with the built-in image-generation tool).
- Companion: existing `npc_smile` and `npc_talk` Cloudinary assets from the tutorial, tinted at runtime with a shader. No new character images.
- Avatar/settings: existing `ui_pfp` and `ui_setting` assets.
- The original `ui_dashboard` remains available for the unchanged central button textures. It is no longer bound to the screen background or a duplicate HeroArt rectangle.

The new background is bundled until its Cloudinary URL is supplied. Its separate AssetManager ID is `ui_dashboard_scenic`; add that ID to the remote catalog when uploaded. Do not replace `ui_dashboard`, since other consumers still use it.

## Companion behavior

Click the portrait (or focus it and press Enter/Space) to open a small typewriter dialogue. Click again to reveal the current line, then to advance; X or Escape closes it. No full-screen mouse catcher or gameplay navigation is added. The companion is disabled during the required pretest/tutorial and closes when leaving the dashboard. Missing portrait downloads leave a clickable text fallback; completed asset sync rebinds the portrait.

Implementation: `frontend/src/ui/screens/dashboard/dashboard_companion.gd`. The expression IDs and dialogue can be replaced without changing the menu. `verify_dashboard.gd` tests menu shapes, companion spacing, dialogue state, compact layout, lock behavior, and screen exit, without navigating or saving progress.

## Final image prompt (built-in tool mode)

Use case: stylized-concept
Asset type: production 16:9 landscape background illustration for Level Blue, a 16-bit pixel-art cyber-defense tactical game dashboard. One background only, not a UI mockup.
Primary request: a scenic futuristic industrial command outpost overlooking a sprawling city at blue hour, viewed from a sheltered observation terrace. Beautiful layered city depth, distant hills and mist, server facilities, industrial rooftops, ventilation and restrained window lights. Foreground framing only at extreme edges and bottom, large open view across the middle. Atmospheric lived-in world, not a flat circuit map.
Style/medium: polished detailed 16-bit pixel art, crisp pixel clusters, deliberate dithering, painterly depth expressed in pixels. Palette charcoal slate, desaturated blue-gray, muted teal and warm stone with restrained amber lighting. Neutral and inviting yet tactical. No purple/pink wash, no saturated neon glow.
Composition: wide 16:9 frame. Left and middle 65% subdued and low contrast for existing large cream geometric menu buttons to overlay. Right 30% airy distant city skyline and gentle mist, enough contrast for a separate mascot sprite to overlay. Top 12% quiet dark sky for a compact header. Bottom includes a subtle terrace ledge, not a UI panel. Scenic landmarks visible around edges and above menu.
Lighting: soft dusk ambient light, subtle warm windows, cinematic but readable, no heavy bloom.
Constraints: no characters, no mascot, no lettering, no logos, no watermark, no HUD, no buttons, no grid, no graph-paper lines, no circuit-board pattern, no duplicated inset images. Complete edge-to-edge scenic background.

## Solo / PvP OS selection milestone

- The existing mode control is moved from the hidden bottom bar to below the left menu. Its diamond contains a code-native pixel swap glyph; the six existing menu shapes remain unchanged.
- `dashboard_mode_modal.gd` renders a full-bleed vertical split, Solo on the left and PvP on the right. Both illustrations fill the entire screen height without card borders or gutters. Cover cropping favors the hacker's eyes; native top/bottom gradients keep the floating headings and footer readable. Previewing a side changes its tint, brightness and subtle zoom without changing the active mode. Cancel restores focus; keyboard navigation stays inside the selector.
- `dashboard_screen.gd` owns the transition. Confirming a different mode closes black shutters toward the center, changes workspace only when fully covered, briefly displays the destination OS boot label, then opens the shutters. Same-mode confirmation does not reboot. Repeated confirmations are ignored while input is blocked. Reduced motion uses a short fade. Exiting the screen cancels the tween and releases the overlay.
- `dashboard_pvp_hub.gd` is a presentation-only red/black workspace with a return switch. It displays the real player name. Matchmaking is explicitly unavailable: no networking, fake opponents, rank changes, currency changes or progression writes are implemented. Mode choice is session-local to this dashboard, not a saved gameplay setting.
- Test: `verify_dashboard.gd` covers native pointer activation, keyboard focus cycling, cancellation, both OS directions, same-mode confirmation, repeated taps, reduced motion, interrupted transitions, unchanged lesson progress, and 1280x720 / 960x600 / 844x390 layouts. Run with `--render` for screenshots in `frontend/.godot/`.

### PvP art handoff

Generated with the **built-in image-generation tool**, not the fallback CLI.
Cloudinary: https://res.cloudinary.com/nfd5bhkz/image/upload/v1791049225/pvp_command_v1.png
AssetManager ID: `ui_dashboard_pvp`; runtime cache: `user://assets/ui_dashboard_pvp.png`.
The mode selector uses this cached texture and refreshes on `sync_finished`, including partially successful syncs. The workspace uses separate subdued artwork (below). Solo reuses `ui_dashboard_scenic`. Missing/uncached art falls back to the native dark-red background without blocking controls; a first download needs network access. The bundled bright PNG and import sidecar have been removed after verifying the remote URL (HTTP 200, PNG, 1,715,274 bytes). The original generated copy remains outside the repository in Codex's generated-images folder.

Final generation prompt:

Use case: stylized-concept. Asset type: production background illustration for Level Blue, a pixel-art cybersecurity game, 16:9 landscape. Primary request: red-and-black hacker-side operating system atmosphere. Scene: shadowy underground computer command room, angular server racks along the edges, subdued red monitor reflections, cables and distant red-lit industrial structures. On the RIGHT HALF, an enormous enigmatic pair of angular glowing crimson eyes emerges from a dark hood-like silhouette in the background, intimidating competitive energy but appropriate for high-school players, not horror. Eyes centered near x=74%, y=43%, clearly recognizable even when image is cropped into a wide horizontal selection banner. LEFT HALF mostly dark charcoal negative space for native UI text and controls. Style: polished 16-bit pixel illustration with clearly visible crisp pixel clusters, deliberate dithering, layered depth, restrained red glow, no smooth photorealism. Palette: near black #09070D, charcoal navy #101623, deep crimson #3B101C, red #FF5C5C and rare cream highlights. Composition: panoramic cinematic game wallpaper, no built-in split, no interface, no text, no letters, no logos, no watermark, no existing characters, no weapons. Finished game background, not a mockup.

### PvP-only store / cosmetic exchange

The existing Store route and scene UID are preserved. Its content is now a pixel-art gallery with category tabs, a selected-item preview, ownership states, and a purchase confirmation. The seven existing item IDs and prices are retained. Featured collectibles and borders are drawn locally; the Profiles category now uses the ten-avatar catalog's eight purchasable portraits (see profile_dossier_design.md). Narrow screens separate browsing from item details, with Back returning to the gallery. Scrollbars are hidden while scrolling remains enabled; confirmation keeps keyboard focus within its controls.

`PlayerManager.pvp_tokens` is independent of `credits`. Only PvP Tokens appear in the store. Older saves load zero tokens without converting Solo currency or removing existing purchases. Reset clears both wallets; save snapshots include the separate wallet. The current progress-sync schema preserves extra keys, including this wallet. Item prices come from `PlayerManager.store_items()`, combining existing collectibles with the shared avatar catalog; unknown IDs, invalid quotes, duplicate ownership, and insufficient tokens are rejected. A successful purchase debits tokens and records ownership before one persistence call. Solo rewards and technology upgrades still use `credits` unchanged.

PvP matches and authoritative reward settlement are not connected. There is intentionally no local token-grant function, OS-switch reward, or participation shortcut. Production PvP must validate match rewards and purchases on the server; the existing client-save system is not an anti-cheat boundary. The UI explicitly reports unavailable match rewards. Purchased profile avatars can be equipped from Profile; other collectibles and borders remain collection-only. No item grants combat effects.

Validation: `res://src/tools/verify_store.gd` checks wallet isolation, legacy/malformed saves, round trips, reset, canonical prices, duplicate/insufficient purchases, native card/tab interaction, confirmation/cancellation, stale quotes, owned states, and desktop and landscape-phone layouts. Its off-tree wallet probe overrides persistence so tests never write purchases or balances to the player's save. Use `--render` to capture previews under `.godot/store_*.png`.

### Subdued PvP workspace background

The dashboard uses `ui_dashboard_pvp_workspace`, downloaded from `https://res.cloudinary.com/nfd5bhkz/image/upload/v1791168774/pvp_workspace_muted_v1.png` through AssetManager's persistent cache. The bundled PNG and import sidecar have been removed; an empty cache uses the native dark background until the first successful download. The selector keeps the existing dramatic eye artwork. The workspace is a static texture, with no blinking, pulsing, bloom, or animated lighting. Controls and OS transition behavior are unchanged. The independent asset ID prevents a selector download from replacing the quieter dashboard image. Tests cover the exact URL, missing-art fallback, and independent refresh.

Generated with the built-in image-generation tool. Final prompt:

Use case: stylized-concept. Asset type: static pixel-art game dashboard background, landscape 16:9. Create a subdued red-and-black hacker command room for a cybersecurity mobile game. Composition: the left 55 percent is quiet dark charcoal wall and shadow, reserved for cream UI text and controls; on the right, a modest computer desk and recessed server racks give depth, with dim burgundy monitor screens and restrained dusty-red edge lighting. Style: crisp intentional pixel clusters, limited palette, old-school detailed 2D game environment, not photorealistic. Palette: near-black #090B12 and charcoal #151219 dominate, with low-saturation oxblood #351920 and muted red #71343E accents. Lighting: calm, low-key, matte, low contrast; the room should remain visible without bright highlights. No people, no faces or eyes, no bright neon, no bloom, no glowing white lights, no saturated red flood, no flashing or motion effects, no text, no logos, no UI controls, no frame. This is a comfortable backdrop for long reading sessions, not an alarm screen. Fill the whole canvas.
