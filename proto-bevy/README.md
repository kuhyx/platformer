# proto-bevy

Bevy 0.19, Rust. Status: boot stub only; API names unverified against 0.19.

## Requirements
- Rust stable via rustup; `cargo search bevy` to confirm the 0.19.x patch.
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
- Bevy breaks APIs roughly every 3 months. Pin the exact patch in
  Cargo.lock and commit it.
- `clippy::pedantic` is on; keep it. Fix, do not `allow`.
