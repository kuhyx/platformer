# proto-bevy

Bevy 0.20.1, Rust 1.98.1. Status: full slice (sim, rooms, fx, save, pause,
gate, F1/F5/F6 overlay) native and web; audio and analytics (D09) skipped.

## Requirements
- Rust stable via rustup (Bevy 0.20.1 needs >= 1.97.1; `rustup update stable`).
- Linux: `libasound2-dev libudev-dev` (Bevy audio/input).
- Web: `rustup target add wasm32-unknown-unknown`, `cargo install trunk`
  or `wasm-bindgen-cli`, plus `wasm-opt` (binaryen).

## Build / run / lint
```
cargo run
cargo fmt --check && cargo clippy --all-targets -- -D warnings
cargo test
```
Native flags: `--seed=N`, `--autodrive` (feeds `../shared/replay/slice_trace.json`
through the real tick), `--stop-at=N` (freeze the sim at tick N, keep
rendering), `--overlay` (F1 open, debug builds), `--no-gate`.
`PROTO_BEVY_DATA_DIR` redirects the save. Under Xvfb the NVIDIA Vulkan
adapter works (present-layout validation noise in the log, harmless); no
software GPU was needed.

## Web build
```
cargo build --release --target wasm32-unknown-unknown
wasm-bindgen --out-dir dist --target web target/wasm32-unknown-unknown/release/proto-bevy.wasm
wasm-opt -Oz --enable-bulk-memory --enable-bulk-memory-opt --enable-sign-ext --enable-nontrapping-float-to-int --enable-mutable-globals --enable-multivalue --enable-reference-types -o dist/proto-bevy_bg.wasm dist/proto-bevy_bg.wasm
cp web/index.html dist/index.html
python3 ../tools/size_budget.py dist 12000000
```
`wasm-opt` needs the feature flags (rustc emits bulk-memory) and must not get
`--all-features` (its compact-imports output is rejected by Chromium).
`web/index.html` is the loader: no text, progress bar, crossed-out-monitor
icon on failure (D19), IndexedDB save behind a synchronous cache
(`protoSaveRead` / `protoSaveWrite`), `protoReady` sets `window.__gameReady`.
Cold release build is ~5 calls of 55 s; the last link step took 43 s.

## `__gameReady`
`src/main.rs::signal_ready` (`Last` schedule, after two presented frames),
before the start gate is dismissed.

## Live tweak / hot reload
- Registry: `Params` is a mutable `Resource`; F1 sliders mutate it live and
  F5 reloads `params.json` from disk (native debug builds only, as Godot).
- Code: no hot reload; see the measured incremental rebuild in the report.

## Agent play (M9)
Native: `xvfb-run -a ./target/debug/proto-bevy --autodrive --no-gate
--stop-at=900`, then `import -window root` shows room 2 with the blade.
Web: Playwright `keyboard.down` on the served `dist/`.

## Notes
- Bevy breaks APIs roughly every 3 months. `Cargo.toml` exact-pins every
  crate and `Cargo.lock` is committed; the dependency-freshness gate
  reports when a newer stable exists.
- `src/lib.rs` owns the pure sim, registry, rooms, fx and save so
  `cargo test` replays the shared fixture without a window.
- Web saves go through the IndexedDB shim; native saves are an atomic
  temp-file + rename in `$XDG_DATA_HOME/proto-bevy/save.json`.
- `clippy::pedantic` is on; keep it. Fix, do not `allow`.
