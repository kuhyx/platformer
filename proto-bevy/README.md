# proto-bevy

Bevy 0.19.1, Rust. Status: boot stub only; compiles clean under clippy.

## Requirements
- Rust stable via rustup (Bevy 0.19.1 needs >= 1.95; `rustup update stable`).
- Linux: `libasound2-dev libudev-dev` (Bevy audio/input).
- Web: `rustup target add wasm32-unknown-unknown`, `cargo install trunk`
  or `wasm-bindgen-cli`, plus `wasm-opt` (binaryen).

## Build / run / lint
```
cargo run
cargo fmt --check && cargo clippy --all-targets -- -D warnings
```

## Web build
```
cargo build --release --target wasm32-unknown-unknown
wasm-bindgen --out-dir dist --target web target/wasm32-unknown-unknown/release/proto-bevy.wasm
wasm-opt -Oz -o dist/proto-bevy_bg.wasm dist/proto-bevy_bg.wasm
python3 ../tools/size_budget.py dist 12000000
```
Expect 15–30 MB before compression; this is the prototype most likely to
fail M3/M4. Write a `dist/index.html` loader during the slice.

## `__gameReady`
`src/main.rs::signal_web_ready_once`, first `Update` tick. Move it to a
post-render hook once the slice renders real content.

## Live tweak / hot reload
- Registry: `Params` is a mutable `Resource`; mutate via the debug overlay
  or the Bevy Remote Protocol.
- Code: no hot reload; incremental rebuilds 2–10 s. Score M8 honestly.

## Agent play (M9)
`natepiano/bevy_brp_mcp` + `bevy_brp_extras` (screenshots, entity
inspection/mutation over BRP). Input injection: send input events over
BRP or expose a debug system that reads a command queue.

## Notes
- Bevy breaks APIs roughly every 3 months. `Cargo.toml` exact-pins every
  crate and `Cargo.lock` is committed; the dependency-freshness gate
  reports when a newer stable exists.
- `src/lib.rs` owns the registry so its slider bounds and `keys()` are
  public API rather than dead code in a binary that does not call them yet.
- `clippy::pedantic` is on; keep it. Fix, do not `allow`.
