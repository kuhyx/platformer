//! Invisible autosave (D03): room id + registry hash, atomically written
//! (temp + rename) on native; web persists the same text in `IndexedDB` via
//! the shim in `dist/index.html`. Missing or corrupt means start fresh,
//! silently (D19). The format is shared so one decoder serves both.
use std::path::PathBuf;

/// Save payload text (< 1 KB, DOCS-tech-reqs web contract).
#[must_use]
pub fn encode(room_id: usize, params_hash: &str) -> String {
    serde_json::json!({ "room_id": room_id, "params_hash": params_hash }).to_string()
}

/// The saved room id when it is a valid index, else 0 (never an error).
#[must_use]
pub fn decode(text: &str, room_count: usize) -> usize {
    let parsed: serde_json::Value = serde_json::from_str(text).unwrap_or_default();
    parsed
        .get("room_id")
        .and_then(serde_json::Value::as_u64)
        .and_then(|id| usize::try_from(id).ok())
        .filter(|&id| id < room_count)
        .unwrap_or(0)
}

/// Platform user-data directory for this game (`PROTO_BEVY_DATA_DIR` wins,
/// so tests and verification runs never touch the real save).
#[must_use]
pub fn data_dir() -> PathBuf {
    if let Some(dir) = std::env::var_os("PROTO_BEVY_DATA_DIR") {
        return PathBuf::from(dir);
    }
    let base = std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("APPDATA").map(PathBuf::from))
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/share")))
        .unwrap_or_else(std::env::temp_dir);
    base.join("proto-bevy")
}

/// Atomic write: temp file in the same directory, then rename over the save.
///
/// # Errors
/// On any filesystem failure; callers ignore it (a lost save is not fatal).
pub fn write_atomic(dir: &std::path::Path, text: &str) -> std::io::Result<()> {
    std::fs::create_dir_all(dir)?;
    let tmp = dir.join("save.json.tmp");
    std::fs::write(&tmp, text)?;
    std::fs::rename(&tmp, dir.join("save.json"))
}

/// Read the saved room from `dir`; missing file means room 0.
#[must_use]
pub fn read_room(dir: &std::path::Path, room_count: usize) -> usize {
    std::fs::read_to_string(dir.join("save.json")).map_or(0, |t| decode(&t, room_count))
}
