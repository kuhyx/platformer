//! Boot stub: opens the window, draws the avatar placeholder, signals web
//! readiness. The slice (spec/slice.md) is not implemented yet.
//! API names follow Bevy 0.16-era conventions; check the 0.19 migration
//! guide on the first build and fix what moved.
mod params;

use bevy::prelude::*;
use params::Params;

const WIDTH: f32 = 854.0; // D13
const HEIGHT: f32 = 480.0; // D13
// Bevy's 2D origin is the screen centre; spawn expressed in that space.
const PLACEHOLDER_SPAWN: Vec3 = Vec3::new(-327.0, -160.0, 0.0);

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "proto-bevy".into(),
                resolution: (WIDTH, HEIGHT).into(),
                ..default()
            }),
            ..default()
        }))
        .insert_resource(Params::load())
        .add_systems(Startup, setup)
        .add_systems(Update, signal_web_ready_once)
        .run();
}

fn setup(mut commands: Commands, params: Res<Params>) {
    commands.spawn(Camera2d);
    let size = Vec2::new(params.get("player_w"), params.get("player_h"));
    commands.spawn((
        Sprite::from_color(Color::WHITE, size),
        Transform::from_translation(PLACEHOLDER_SPAWN),
    ));
}

fn signal_web_ready_once(mut done: Local<bool>) {
    if *done {
        return;
    }
    *done = true;
    signal_web_ready();
}

#[cfg(target_arch = "wasm32")]
fn signal_web_ready() {
    let _ = js_sys::eval("window.__gameReady = performance.now()");
}

#[cfg(not(target_arch = "wasm32"))]
fn signal_web_ready() {}
