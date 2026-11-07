//! Headless slice checks (M10), mirroring `proto-godot/tests/test_sim.gd`.
mod common;
use common::{fresh, run, setup, IDLE, JUMP, RIGHT, RIGHT_JUMP, SECONDS};
use proto_bevy::geom::V2;
use proto_bevy::params::Params;
use proto_bevy::rooms::Rooms;
use proto_bevy::sim::{Sim, State};

#[test]
fn idle_avatar_rests_on_the_floor() {
    let (p, rooms) = setup();
    let mut sim = fresh(&rooms, &p, 0);
    run(&mut sim, &p, SECONDS, IDLE);
    let floor_top = rooms.rooms[0].solids[0].y;
    assert!(sim.on_ground);
    assert!((sim.pos.y - (floor_top - Sim::size(&p).y)).abs() < 1e-3);
}

#[test]
fn spike_pit_kills_then_respawns_in_room_one() {
    let (p, rooms) = setup();
    let mut sim = fresh(&rooms, &p, 0);
    let seen = run(&mut sim, &p, 5 * SECONDS, RIGHT);
    assert!(seen.contains(&"death"));
    assert!(seen.contains(&"respawn") && sim.room_id == 0);
}

/// Hold right, jump when the pit or the ledge is next. Ends in room 2.
fn run_room_one(sim: &mut Sim, p: &Params) -> Vec<&'static str> {
    let mut seen = Vec::new();
    let w = Sim::size(p).x;
    let pit_x = sim.rooms.rooms[0].gaps[0].0;
    let ledge_x = sim.rooms.rooms[0].solids[2].x;
    for _ in 0..8 * SECONDS {
        let near = |x: f32| sim.pos.x + w >= x - w && sim.pos.x < x;
        let input = if near(pit_x) || near(ledge_x) { RIGHT_JUMP } else { RIGHT };
        sim.tick(input, p);
        seen.extend(sim.events.iter().map(|e| e.kind.name()));
        if sim.room_id == 1 {
            break;
        }
    }
    seen
}

#[test]
fn jumping_pit_and_ledge_reaches_room_two() {
    let (p, rooms) = setup();
    let mut sim = fresh(&rooms, &p, 0);
    let seen = run_room_one(&mut sim, &p);
    assert!(!seen.contains(&"death") && sim.room_id == 1);
    assert!(seen.contains(&"checkpoint"), "entering room 2 autosaves");
}

#[test]
fn room_two_kills_and_blade_patrols_inside_its_track() {
    let (p, rooms) = setup();
    let mut sim = fresh(&rooms, &p, 1);
    let seen = run(&mut sim, &p, 5 * SECONDS, RIGHT);
    assert!(seen.contains(&"death") && sim.room_id == 1);
    let mut sim = fresh(&rooms, &p, 1);
    let start = sim.blade_pos.x;
    run(&mut sim, &p, SECONDS, IDLE);
    let track = rooms.rooms[1].blade.expect("room 2 has a blade").track;
    assert!((sim.blade_pos.x - start).abs() > f32::EPSILON);
    assert!(sim.blade_pos.x >= track.0 && sim.blade_pos.x <= track.1);
}

#[test]
fn goal_flashes_and_loops_to_room_one() {
    let (p, rooms) = setup();
    let mut sim = fresh(&rooms, &p, 1);
    let goal = rooms.rooms[1].goal.expect("room 2 has a goal");
    sim.pos = V2::new(goal.x - Sim::size(&p).x - 1.0, goal.y);
    let seen = run(&mut sim, &p, 2 * SECONDS, RIGHT);
    assert!(seen.contains(&"goal"));
    assert!(sim.room_id == 0 && sim.state == State::Alive);
}

/// Walk off the ledge, then press jump a few ticks later.
fn late_jump_after_ledge(coyote: f32) -> bool {
    let (mut p, rooms) = setup();
    p.set("coyote_time", coyote);
    let mut sim = fresh(&rooms, &p, 0);
    let ledge = rooms.rooms[0].solids[2];
    let size = Sim::size(&p);
    sim.pos = V2::new(ledge.right() - size.x - 1.0, ledge.y - size.y);
    run(&mut sim, &p, 2, IDLE); // settle onto the ledge
    sim.pos.x = rooms.width - size.x; // stand on the ledge's last pixel
    run(&mut sim, &p, 1, IDLE);
    sim.pos.x = ledge.right(); // airborne past the edge, still in room 1
    run(&mut sim, &p, 2, IDLE);
    run(&mut sim, &p, 1, JUMP).contains(&"jump")
}

#[test]
fn coyote_time_zero_vs_default() {
    assert!(!late_jump_after_ledge(0.0), "coyote_time 0: no jump after leaving the ledge");
    assert!(late_jump_after_ledge(0.08), "coyote_time 0.08: jump still fires");
}

/// Tap jump while falling, a few ticks before landing.
fn early_jump_before_landing(buffer: f32) -> bool {
    let (mut p, rooms) = setup();
    p.set("jump_buffer", buffer);
    let mut sim = fresh(&rooms, &p, 0);
    sim.pos.y -= 2.0 * Sim::size(&p).y; // drop from above the floor
    run(&mut sim, &p, 9, IDLE);
    run(&mut sim, &p, 1, JUMP);
    run(&mut sim, &p, SECONDS, IDLE).contains(&"jump")
}

#[test]
fn jump_buffer_zero_vs_default() {
    assert!(!early_jump_before_landing(0.0), "jump_buffer 0: early tap is lost");
    assert!(early_jump_before_landing(0.1), "jump_buffer 0.1: fires on landing");
}

#[test]
fn zero_coyote_and_buffer_still_jump_from_the_ground() {
    let (mut p, rooms) = setup();
    p.set("coyote_time", 0.0);
    p.set("jump_buffer", 0.0);
    let mut sim = fresh(&rooms, &p, 0);
    run(&mut sim, &p, 2, IDLE);
    assert!(run(&mut sim, &p, 1, JUMP).contains(&"jump"), "ground press must jump");
}

#[test]
fn same_seed_and_inputs_give_identical_state() {
    let (p, rooms) = setup();
    let play = || {
        let mut sim = fresh(&rooms, &p, 0);
        run_room_one(&mut sim, &p);
        run(&mut sim, &p, SECONDS, RIGHT);
        proto_bevy::snapshot::snapshot(&sim, p.registry_hash())
    };
    assert_eq!(play(), play());
}

#[test]
fn shipped_layout_is_winnable_and_a_wide_gap_is_not() {
    let (p, rooms) = setup();
    assert!(rooms.assert_winnable(&p).is_ok());
    let mut wide = rooms.clone();
    wide.rooms[0].gaps[0] = (0.0, Rooms::jump_reach(&p));
    assert!(wide.assert_winnable(&p).is_err());
}
