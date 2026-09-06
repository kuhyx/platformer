# Spec critique → resolution

Each contradiction found in the original brief, and the decision that
closed it. Unresolved items are Open Questions in `spec/DOCS-decisions.md`.

| Contradiction | Resolution |
|---|---|
| "No menus" vs browser audio-autoplay (needs a gesture) and first wasm download | D02: one icon-only start gate on web |
| "No menus" vs Godot threaded web needing COOP/COEP on itch.io | D10: single-threaded builds |
| "No menus" vs Steam overlay, fullscreen, rebinding, accessibility, quitting | D05: zero settings; pause = resume only; quit = close window (Open Q3) |
| "No text" vs store pages, EULA, OS crash dialogs | D04: runtime-only scope; diegetic error signals still undesigned (Open Q4) |
| "No loading" vs mandatory first download | D02 + D10: target is cached load < 2 s; first load sits behind the gate |
| One-hit death vs "never lose progress" | D03: progress = checkpoints, one per room; respawn delay is a parameter |
| Invisible autosave vs power loss / tab close / storage limits | tech-reqs: atomic writes native, IndexedDB web, payload < 1 KB; missing-save behaviour still open (Open Q4) |
| "No HUD" vs communicating abilities/collectibles | D06 removed rewards, so nothing needs a HUD; any future state must be diegetic |
| "All mainstream engagement techniques" vs respecting the player | D06: juice + mastery only; dark patterns forbidden |
| 100% coverage on a solo prototype | D07: suspended for the bake-off; re-decided at engine pick |
| 250-line cap on prose fragments docs | D08: kept everywhere; docs split into linked files |
| "Everything adjustable live" scope explosion | D14: single parameter registry; only registered keys are tunable |
| Video/gaze cost on i3 and privacy even in debug | D09: dev build only, opt-in, recording indicator; owner accepts friend-recording risk |
| Browser vs native parity (timestep, latency, saves) | D12: fixed 60 Hz sim; save backend abstracted |

## Still unresolved (must be answered before the slice)
1. Room model: one fixed screen with hard cuts, or scrolling with a
   boundary. Drives checkpoints, camera, level data.
2. Player placeholder size (12×16 proposed).
3. Quit / start over with zero settings.
4. Icon + audio signals for save missing/corrupt, WebGL missing, gamepad
   disconnect.
5. Respawn presentation: hard cut vs camera pan.
