//! Game-level state shared by the Bevy systems: the sim, effects, and the
//! flags `main.gd` keeps (pause, web start gate, ready signal).
use crate::platform;
use bevy::prelude::Resource;
use proto_bevy::fx::Fx;
use proto_bevy::params::Params;
use proto_bevy::rooms::Rooms;
use proto_bevy::sim::{EventKind, Input, Sim};

/// Frames rendered before the web ready signal: the first playable frame has
/// been presented, not merely scheduled.
pub const READY_FRAMES: u32 = 2;

/// Command-line options (native only; the browser passes none).
#[derive(Resource, Default)]
pub struct Opts {
    /// `--seed=N`: fix the RNG seed.
    pub seed: Option<u64>,
    /// `--autodrive`: feed `shared/replay/slice_trace.json` through the tick.
    pub autodrive: bool,
    /// `--stop-at=N`: stop ticking at sim tick N (screenshots), keep rendering.
    pub stop_at: Option<u32>,
    /// `--overlay`: start with the F1 overlay open (debug builds).
    pub overlay: bool,
    /// `--no-gate`: skip the web start gate (screenshot runs).
    pub no_gate: bool,
}

impl Opts {
    /// Parse `std::env::args`.
    #[must_use]
    pub fn from_args() -> Self {
        let mut o = Self::default();
        for arg in std::env::args().skip(1) {
            if let Some(v) = arg.strip_prefix("--seed=") {
                o.seed = v.parse().ok();
            } else if let Some(v) = arg.strip_prefix("--stop-at=") {
                o.stop_at = v.parse().ok();
            } else {
                match arg.as_str() {
                    "--autodrive" => o.autodrive = true,
                    "--overlay" => o.overlay = true,
                    "--no-gate" => o.no_gate = true,
                    _ => {}
                }
            }
        }
        o
    }
}

/// Everything the systems share.
#[derive(Resource)]
pub struct Game {
    /// The pure sim.
    pub sim: Sim,
    /// Juice.
    pub fx: Fx,
    /// Pause (resume only, D-pause).
    pub paused: bool,
    /// Web start gate (D02); absent on desktop.
    pub gate_active: bool,
    /// Seconds since boot, drives the gate pulse.
    pub gate_phase: f32,
    /// Frames rendered; `__gameReady` is signalled once two have been
    /// presented, so the first playable frame is on screen.
    pub frames: u32,
    /// F1 overlay visible (debug builds).
    pub overlay: bool,
    /// Autodrive tick feed.
    pub trace: Vec<Input>,
}

impl Game {
    /// Boot like `main.gd::_ready`: load the saved room and enter it.
    #[must_use]
    pub fn new(params: &Params, opts: &Opts) -> Self {
        let rooms = Rooms::load(params);
        let seed = opts.seed.unwrap_or_else(platform::clock_seed);
        let saved = if opts.autodrive { 0 } else { platform::load_room(rooms.count()) };
        let mut sim = Sim::new(rooms, seed);
        sim.enter_room(saved, false);
        let mut game = Self {
            sim,
            fx: Fx::default(),
            paused: false,
            gate_active: platform::IS_WEB && !opts.no_gate,
            gate_phase: 0.0,
            frames: 0,
            overlay: cfg!(debug_assertions) && opts.overlay,
            trace: if opts.autodrive { crate::autodrive::load() } else { Vec::new() },
        };
        game.after_tick(params);
        game
    }

    /// A frame has been presented and `__gameReady` was signalled.
    #[must_use]
    pub fn ready(&self) -> bool {
        self.frames >= READY_FRAMES
    }

    /// Reacts to whatever the sim emitted: effects and autosave.
    pub fn after_tick(&mut self, params: &Params) {
        let center = self.sim.rect(params).center();
        self.fx.on_events(&self.sim.events, &mut self.sim.rng, center, params);
        for e in &self.sim.events {
            if e.kind == EventKind::Checkpoint {
                platform::store_room(e.room, params.registry_hash());
            }
        }
    }

    /// One 60 Hz step (skipped while paused or gated).
    pub fn step(&mut self, input: Input, params: &Params) {
        self.sim.tick(input, params);
        self.after_tick(params);
        if !self.sim.frozen(params) {
            self.fx.tick(&mut self.sim.rng, params);
        }
    }
}
