//! Platform seam: native files vs the web shim in `dist/index.html`
//! (`IndexedDB` save, ready signal). The web side talks to JS through
//! `js_sys::Reflect` on globals the shim defines, so no extra crate is needed.
use proto_bevy::save;

/// True in the browser build.
pub const IS_WEB: bool = cfg!(target_arch = "wasm32");

/// Seed for a normal run: wall clock, as Godot does. `--seed=` overrides.
#[must_use]
pub fn clock_seed() -> u64 {
    #[cfg(target_arch = "wasm32")]
    {
        js_sys::Date::now() as u64
    }
    #[cfg(not(target_arch = "wasm32"))]
    {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_secs())
    }
}

/// Saved room id (0 when missing or corrupt, D19).
#[must_use]
pub fn load_room(room_count: usize) -> usize {
    #[cfg(target_arch = "wasm32")]
    {
        call_js("protoSaveRead", None).map_or(0, |t| save::decode(&t, room_count))
    }
    #[cfg(not(target_arch = "wasm32"))]
    {
        save::read_room(&save::data_dir(), room_count)
    }
}

/// Persist the room id (atomic file natively, `IndexedDB` on web).
pub fn store_room(room_id: usize, params_hash: &str) {
    let text = save::encode(room_id, params_hash);
    #[cfg(target_arch = "wasm32")]
    {
        let _ = call_js("protoSaveWrite", Some(&text));
    }
    #[cfg(not(target_arch = "wasm32"))]
    {
        // A lost save is not fatal (D19): ignore the error.
        let _ = save::write_atomic(&save::data_dir(), &text);
    }
}

/// F6 target: `snapshot.json` in the data dir natively, console on web.
pub fn dump_snapshot(text: &str) {
    #[cfg(target_arch = "wasm32")]
    {
        bevy::log::info!("snapshot: {text}");
    }
    #[cfg(not(target_arch = "wasm32"))]
    {
        let dir = save::data_dir();
        let path = dir.join("snapshot.json");
        if std::fs::create_dir_all(&dir).and_then(|()| std::fs::write(&path, text)).is_ok() {
            println!("snapshot: {}", path.display());
        }
    }
}

/// Web contract: `window.__gameReady = performance.now()` once a frame has
/// been rendered (the shim sets it). No-op natively.
pub fn signal_ready() {
    #[cfg(target_arch = "wasm32")]
    {
        let _ = call_js("protoReady", None);
    }
}

#[cfg(target_arch = "wasm32")]
fn call_js(name: &str, arg: Option<&str>) -> Option<String> {
    let global = js_sys::global();
    let func = js_sys::Function::from(js_sys::Reflect::get(&global, &name.into()).ok()?);
    let out = match arg {
        Some(a) => func.call1(&global, &a.into()),
        None => func.call0(&global),
    };
    out.ok()?.as_string()
}
