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
