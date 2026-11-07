//! Bevy glue for the slice (spec/DOCS-slice.md): polls input, ticks the pure
//! sim at 60 Hz in `FixedUpdate`, draws rectangles, owns the web start gate
//! and the debug hooks. Every rule lives in the library's `sim`.
mod autodrive;
mod game;
mod input;
mod overlay;
mod platform;
mod render;

use bevy::prelude::*;
use bevy::window::WindowResolution;
use game::{Game, Opts};
use proto_bevy::params::Params;
use proto_bevy::sim::TICK_HZ;

const WIDTH_PX: u32 = 854; // D13
const HEIGHT_PX: u32 = 480; // D13
const WIDTH: f32 = 854.0; // D13
const HEIGHT: f32 = 480.0; // D13

fn main() {
    let opts = Opts::from_args();
    let params = Params::load();
    let game = Game::new(&params, &opts);
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "proto-bevy".into(),
                resolution: WindowResolution::new(WIDTH_PX, HEIGHT_PX),
                canvas: Some("#bevy".into()),
                fit_canvas_to_parent: true,
                prevent_default_event_handling: true,
                ..default()
            }),
            ..default()
        }))
        .add_plugins(bevy::diagnostic::FrameTimeDiagnosticsPlugin::default())
        .insert_resource(ClearColor(Color::BLACK))
        .insert_resource(Time::<Fixed>::from_hz(f64::from(TICK_HZ)))
        .insert_resource(params)
        .insert_resource(game)
        .insert_resource(opts)
        .add_systems(Startup, (render::setup, overlay::setup))
        .add_systems(FixedUpdate, tick)
        .add_systems(Update, (controls, overlay::update, render::draw).chain())
        .add_systems(Last, signal_ready)
        .run();
}

/// `_physics_process`: poll input (or the autodrive feed) and step the sim.
fn tick(
    mut game: ResMut<Game>,
    params: Res<Params>,
    opts: Res<Opts>,
    keys: Res<ButtonInput<KeyCode>>,
    pads: Query<&Gamepad>,
) {
    if game.paused || game.gate_active {
        return;
    }
    let at = game.sim.tick_count as usize;
    if opts.stop_at.is_some_and(|stop| game.sim.tick_count >= stop) {
        return;
    }
    let input = if opts.autodrive {
        game.trace.get(at).copied().unwrap_or_default()
    } else {
        input::poll(&keys, &pads)
    };
    game.step(input, &params);
}

/// `_unhandled_input` and `_process`: gate dismissal, pause, gate pulse.
fn controls(
    time: Res<Time>,
    mut game: ResMut<Game>,
    keys: Res<ButtonInput<KeyCode>>,
    mouse: Res<ButtonInput<MouseButton>>,
    pads: Query<&Gamepad>,
) {
    game.gate_phase += time.delta_secs();
    if game.gate_active {
        if game.ready() && input::any_press(&keys, &mouse, &pads) {
            game.gate_active = false;
        }
    } else if input::pause_pressed(&keys, &pads) {
        game.paused = !game.paused;
    }
}

/// Web contract: signal readiness after a frame has been presented, never
/// from the first `Update` (that is before anything is drawn).
fn signal_ready(mut game: ResMut<Game>) {
    game.frames += 1;
    if game.frames == game::READY_FRAMES {
        platform::signal_ready();
    }
}
