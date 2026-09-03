# The slice

The same 60-second experience built in every prototype. Anything not
listed here is out of scope for the bake-off.

## World
- Two rooms, each exactly one screen (854×480), left to right. Walking
  off the right edge of room 1 enters room 2. (Open Q1 may change this.)
- Room 1: flat floor, a spike pit mid-room (static hazard), a raised
  ledge after it.
- Room 2: a horizontally patrolling blade (moving hazard) over a gap; a
  goal pillar at the far right. Touching the goal flashes the screen and
  restarts at room 1 — that is the loop.
- Checkpoint marker at each room's left edge. Entering a room saves.

## Avatar
- Rectangle `player_w`×`player_h`. Runs at `move_speed`.
- Jump: `jump_velocity` up; releasing early multiplies vertical speed by
  `jump_cut_multiplier` (variable height).
- `coyote_time` after leaving a ledge still allows a jump. A jump pressed
  within `jump_buffer` before landing fires on landing.
- Gravity `gravity`, fall speed capped at `max_fall_speed`.

## Death
- Any hazard touch = death. `hitstop` freeze, screen shake
  (`shake_amplitude`, `shake_duration`), `death_particles` burst.
- After `respawn_delay` the avatar reappears at the room's checkpoint.
  No fade, no text.

## Web
- First playable frame sets `window.__gameReady`. Start gate: a pulsing
  icon; any key or click dismisses it and unlocks audio.

## Art and audio
- Player white, hazards red, checkpoint green, goal yellow, floor grey.
  No sprites.
- Audio optional. If present: jump, death, checkpoint.

## Debug build
- F1 toggles the overlay: one slider per registry entry, room id, fps.
- F5 reloads the registry from disk. F6 dumps a snapshot.

## Done means
- [ ] Runs native (Linux or Windows) and in a browser.
- [ ] Both hazards kill; both checkpoints save; relaunching resumes at
      the last room.
- [ ] Coyote time and jump buffer verifiably work (set them to 0 and feel
      the difference).
- [ ] `tools/measure_load.mjs` reports the cached load.
- [ ] Scorecard row filled in `comparison-protocol.md`.
