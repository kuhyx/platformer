//! Autosave contract (D03/D19): the room id round-trips through the atomic
//! file write, and a missing, corrupt or out-of-range save means room 0.
use proto_bevy::save::{decode, encode, read_room, write_atomic};

const ROOMS: usize = 2;

fn scratch(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("proto-bevy-test-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    dir
}

#[test]
fn room_id_round_trips_through_the_atomic_file() {
    let dir = scratch("roundtrip");
    write_atomic(&dir, &encode(1, "hash")).expect("write");
    assert_eq!(read_room(&dir, ROOMS), 1);
    assert!(!dir.join("save.json.tmp").exists(), "temp file renamed away");
    std::fs::remove_dir_all(&dir).expect("cleanup");
}

#[test]
fn missing_corrupt_and_out_of_range_saves_start_in_room_zero() {
    let dir = scratch("bad");
    assert_eq!(read_room(&dir, ROOMS), 0, "missing file");
    for bad in
        ["{garbage", "", "null", r#"{"room_id":-1}"#, r#"{"room_id":9}"#, r#"{"room_id":"1"}"#]
    {
        assert_eq!(decode(bad, ROOMS), 0, "{bad}");
    }
}
