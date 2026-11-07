//! Cross-engine replay fixture (`shared/replay/slice_trace.json`): the inputs
//! are fed to the sim at 60 Hz from `enter_room(0)` with seed 7, and the
//! emitted events must match the fixture's names, rooms and order, each tick
//! within +-1 (float width differs per engine).
mod common;
use common::{fresh, setup, SEED};
use proto_bevy::sim::Input;
use serde_json::Value;

const TRACE: &str = include_str!("../../shared/replay/slice_trace.json");
const TICK_TOLERANCE: i64 = 1;

fn log(sim: &proto_bevy::sim::Sim, out: &mut Vec<(i64, String, usize)>) {
    for e in &sim.events {
        out.push((i64::from(sim.tick_count), e.kind.name().to_owned(), sim.room_id));
    }
}

fn replay() -> Vec<(i64, String, usize)> {
    let trace: Value = serde_json::from_str(TRACE).expect("fixture parses");
    let (p, rooms) = setup();
    let mut sim = fresh(&rooms, &p, 0);
    assert_eq!(SEED, 7, "fixture seed");
    let mut got = Vec::new();
    log(&sim, &mut got);
    for seg in trace["inputs"].as_array().expect("inputs array") {
        let n: Vec<i64> =
            seg.as_array().expect("segment").iter().map(|v| v.as_i64().expect("int")).collect();
        let input = Input { left: n[1] != 0, right: n[2] != 0, jump: n[3] != 0 };
        for _ in 0..n[0] {
            sim.tick(input, &p);
            log(&sim, &mut got);
        }
    }
    got
}

#[test]
fn replay_matches_fixture_events() {
    let trace: Value = serde_json::from_str(TRACE).expect("fixture parses");
    let want = trace["events"].as_array().expect("events array");
    let got = replay();
    assert_eq!(got.len(), want.len(), "event count: {got:?}");
    for ((tick, name, room), w) in got.iter().zip(want) {
        assert_eq!(name, w[1].as_str().expect("name"), "name at tick {tick}");
        assert_eq!(i64::try_from(*room).ok(), w[2].as_i64(), "room at tick {tick}");
        let want_tick = w[0].as_i64().expect("tick");
        assert!((tick - want_tick).abs() <= TICK_TOLERANCE, "{name}: tick {tick} vs {want_tick}");
    }
}

#[test]
fn replay_is_deterministic() {
    assert_eq!(replay(), replay());
}
