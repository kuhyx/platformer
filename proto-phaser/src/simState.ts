// Snapshot = { room_id, checkpoint_id, player_state, rng_seed, params_hash }
// (spec/DOCS-dev-principles.md section 3). Feeds the F6 dump; restore() puts a
// Sim back exactly where a snapshot left it. Same shape as sim_state.gd.
import { registryHash } from "./params.ts";
import type { Sim } from "./sim.ts";
import type { StateId } from "./simTypes.ts";

export interface PlayerState {
  x: number;
  y: number;
  vx: number;
  vy: number;
  on_ground: boolean;
  coyote_left: number;
  buffer_left: number;
  jump_cut_pending: boolean;
  state: StateId;
  state_t: number;
  blade_x: number;
  blade_y: number;
  blade_dir: number;
}

export interface Snapshot {
  room_id: number;
  checkpoint_id: number;
  player_state: PlayerState;
  rng_seed: number;
  rng_state: number;
  params_hash: string;
  tick: number;
}

export function snapshot(sim: Sim): Snapshot {
  return {
    room_id: sim.roomId,
    checkpoint_id: sim.roomId,
    player_state: {
      x: sim.x,
      y: sim.y,
      vx: sim.vx,
      vy: sim.vy,
      on_ground: sim.onGround,
      coyote_left: sim.coyoteLeft,
      buffer_left: sim.bufferLeft,
      jump_cut_pending: sim.jumpCutPending,
      state: sim.state,
      state_t: sim.stateT,
      blade_x: sim.bladeX,
      blade_y: sim.bladeY,
      blade_dir: sim.bladeDir,
    },
    rng_seed: sim.seedValue,
    rng_state: sim.rng.state,
    params_hash: registryHash(),
    tick: sim.tickCount,
  };
}

export function restore(sim: Sim, snap: Snapshot): void {
  const p = snap.player_state;
  sim.roomId = snap.room_id;
  sim.x = p.x;
  sim.y = p.y;
  sim.vx = p.vx;
  sim.vy = p.vy;
  sim.onGround = p.on_ground;
  sim.coyoteLeft = p.coyote_left;
  sim.bufferLeft = p.buffer_left;
  sim.jumpCutPending = p.jump_cut_pending;
  sim.state = p.state;
  sim.stateT = p.state_t;
  sim.bladeX = p.blade_x;
  sim.bladeY = p.blade_y;
  sim.bladeDir = p.blade_dir;
  sim.rng.state = snap.rng_state;
  sim.tickCount = snap.tick;
}
