//! Library half of proto-bevy: the pure fixed-step sim (no ECS types), its
//! data (registry, rooms), effects and save format. The binary renders and
//! forwards; every rule lives here so `cargo test` can replay it headless.
pub mod events;
pub mod fx;
pub mod geom;
pub mod params;
pub mod rng;
pub mod rooms;
pub mod save;
pub mod sim;
mod sim_world;
pub mod slider;
pub mod snapshot;
