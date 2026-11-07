//! Shared helpers for the sim tests: fresh sims and scripted runs.
#![allow(dead_code)] // each test binary uses a different subset
use proto_bevy::params::Params;
use proto_bevy::rooms::Rooms;
use proto_bevy::sim::{Input, Sim};

pub const SEED: u64 = 7;
pub const SECONDS: u32 = 60; // ticks per second, D12

pub const IDLE: Input = Input { left: false, right: false, jump: false };
pub const RIGHT: Input = Input { left: false, right: true, jump: false };
pub const RIGHT_JUMP: Input = Input { left: false, right: true, jump: true };
pub const JUMP: Input = Input { left: false, right: false, jump: true };

pub fn setup() -> (Params, Rooms) {
    let params = Params::load();
    let rooms = Rooms::load(&params);
    (params, rooms)
}

pub fn fresh(rooms: &Rooms, p: &Params, room: usize) -> Sim {
    let mut sim = Sim::new(rooms.clone(), SEED);
    sim.enter_room(room, false);
    let _ = p;
    sim
}

/// Run `ticks` ticks with one input; return event names seen.
pub fn run(sim: &mut Sim, p: &Params, ticks: u32, input: Input) -> Vec<&'static str> {
    let mut seen = Vec::new();
    for _ in 0..ticks {
        sim.tick(input, p);
        seen.extend(sim.events.iter().map(|e| e.kind.name()));
    }
    seen
}
