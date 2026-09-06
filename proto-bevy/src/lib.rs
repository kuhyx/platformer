//! Library half of proto-bevy: everything the binary, the future debug
//! overlay and the tests share. Keeping the registry here rather than in a
//! private `mod` of `main.rs` is what makes `Entry`'s slider bounds and
//! `Params::keys` reachable API instead of dead code the binary happens not
//! to call yet.
pub mod params;
