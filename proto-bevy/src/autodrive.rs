//! `--autodrive`: expand `shared/replay/slice_trace.json` into one input per
//! tick so a screenshot run exercises the real tick path with known inputs.
use proto_bevy::sim::Input;

/// One [`Input`] per tick, empty when the fixture cannot be read.
#[must_use]
pub fn load() -> Vec<Input> {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../shared/replay/slice_trace.json");
    let Ok(text) = std::fs::read_to_string(path) else { return Vec::new() };
    let Ok(trace) = serde_json::from_str::<serde_json::Value>(&text) else { return Vec::new() };
    let mut out = Vec::new();
    for seg in trace["inputs"].as_array().into_iter().flatten() {
        let n: Vec<i64> =
            seg.as_array().into_iter().flatten().filter_map(serde_json::Value::as_i64).collect();
        if let [ticks, l, r, j] = n[..] {
            let input = Input { left: l != 0, right: r != 0, jump: j != 0 };
            out.extend((0..ticks).map(|_| input));
        }
    }
    out
}
