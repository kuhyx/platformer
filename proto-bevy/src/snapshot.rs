//! Snapshot = `{ room_id, checkpoint_id, player_state, rng_seed, params_hash }`
//! (spec/DOCS-dev-principles.md section 3). Feeds the F6 dump; `restore`
//! puts a [`Sim`] back exactly where a snapshot left it.
use crate::geom::V2;
use crate::sim::{Sim, State};
use serde_json::{json, Value};

/// Serialise the sim for the F6 dump.
#[must_use]
pub fn snapshot(sim: &Sim, params_hash: &str) -> Value {
    json!({
        "room_id": sim.room_id,
        "checkpoint_id": sim.room_id,
        "player_state": {
            "x": sim.pos.x, "y": sim.pos.y, "vx": sim.vel.x, "vy": sim.vel.y,
            "on_ground": sim.on_ground,
            "coyote_left": sim.coyote_left, "buffer_left": sim.buffer_left,
            "jump_cut_pending": sim.jump_cut_pending,
            "state": state_id(sim.state), "state_t": sim.state_t,
            "blade_x": sim.blade_pos.x, "blade_y": sim.blade_pos.y, "blade_dir": sim.blade_dir,
        },
        "rng_seed": sim.seed,
        "rng_state": sim.rng.state.to_string(),
        "params_hash": params_hash,
        "tick": sim.tick_count,
    })
}

const fn state_id(s: State) -> u8 {
    match s {
        State::Alive => 0,
        State::Dead => 1,
        State::Goal => 2,
    }
}

fn f(v: &Value, key: &str) -> f32 {
    serde_json::from_value(v[key].clone()).unwrap_or_default()
}

/// Load a snapshot into `sim`; `false` when the document is not one.
pub fn restore(sim: &mut Sim, snap: &Value) -> bool {
    let room = snap["room_id"].as_u64().and_then(|r| usize::try_from(r).ok());
    let (Some(p), Some(room)) = (snap.get("player_state"), room) else { return false };
    if room >= sim.rooms.count() {
        return false;
    }
    sim.room_id = room;
    sim.pos = V2::new(f(p, "x"), f(p, "y"));
    sim.vel = V2::new(f(p, "vx"), f(p, "vy"));
    sim.on_ground = p["on_ground"].as_bool().unwrap_or(false);
    sim.coyote_left = f(p, "coyote_left");
    sim.buffer_left = f(p, "buffer_left");
    sim.jump_cut_pending = p["jump_cut_pending"].as_bool().unwrap_or(false);
    sim.state = match p["state"].as_u64() {
        Some(1) => State::Dead,
        Some(2) => State::Goal,
        _ => State::Alive,
    };
    sim.state_t = f(p, "state_t");
    sim.blade_pos = V2::new(f(p, "blade_x"), f(p, "blade_y"));
    sim.blade_dir = f(p, "blade_dir");
    sim.rng.state =
        snap["rng_state"].as_str().and_then(|s| s.parse().ok()).unwrap_or(sim.rng.state);
    sim.tick_count = snap["tick"].as_u64().and_then(|t| u32::try_from(t).ok()).unwrap_or_default();
    true
}
