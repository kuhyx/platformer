//! The slice's pure fixed-step simulation (D12): movement, collision, rooms,
//! hazards, death and goal. Mirrors `proto-godot/sim.gd` rule for rule. No
//! engine types, so a test or replay drives it without a window (M10). Every
//! number comes from the registry or `rooms.json`; rendering reads its state.
use crate::geom::{Rect, V2};
use crate::params::Params;
use crate::rng::Rng;
use crate::rooms::Rooms;

/// Sim tick rate, a decision not a tunable (D12).
pub const TICK_HZ: f32 = 60.0;
/// Seconds per tick.
pub const TICK: f32 = 1.0 / TICK_HZ;

pub use crate::events::{Event, EventKind, Input, State};

/// The simulation state.
#[derive(Clone, Debug)]
pub struct Sim {
    /// Loaded layout.
    pub rooms: Rooms,
    /// Seeded RNG, shared with effects.
    pub rng: Rng,
    /// Seed it started from.
    pub seed: u64,
    /// Ticks since start.
    pub tick_count: u32,
    /// Current room.
    pub room_id: usize,
    /// Avatar top-left.
    pub pos: V2,
    /// Avatar velocity, px/s.
    pub vel: V2,
    /// Standing on a solid.
    pub on_ground: bool,
    /// Seconds of coyote grace left.
    pub coyote_left: f32,
    /// Seconds of buffered jump press left.
    pub buffer_left: f32,
    /// Takeoff until release or apex (variable height).
    pub jump_cut_pending: bool,
    prev_jump: bool,
    /// Life cycle.
    pub state: State,
    /// Seconds spent in Dead or Goal.
    pub state_t: f32,
    /// Blade top-left.
    pub blade_pos: V2,
    /// Blade direction, +1 or -1.
    pub blade_dir: f32,
    /// Events emitted by the last tick.
    pub events: Vec<Event>,
}

impl Sim {
    /// New sim; call [`Sim::enter_room`] to place the avatar.
    #[must_use]
    pub fn new(rooms: Rooms, seed: u64) -> Self {
        Self {
            rooms,
            rng: Rng::new(seed),
            seed,
            tick_count: 0,
            room_id: 0,
            pos: V2::default(),
            vel: V2::default(),
            on_ground: false,
            coyote_left: 0.0,
            buffer_left: 0.0,
            jump_cut_pending: false,
            prev_jump: false,
            state: State::Alive,
            state_t: 0.0,
            blade_pos: V2::default(),
            blade_dir: 1.0,
            events: Vec::new(),
        }
    }

    /// Avatar size from the registry.
    #[must_use]
    pub fn size(p: &Params) -> V2 {
        V2::new(p.get("player_w"), p.get("player_h"))
    }

    /// Avatar rect.
    #[must_use]
    pub fn rect(&self, p: &Params) -> Rect {
        let s = Self::size(p);
        Rect::new(self.pos.x, self.pos.y, s.x, s.y)
    }

    /// Blade rect in the current room (zero rect when none).
    #[must_use]
    pub fn blade_rect(&self) -> Rect {
        self.rooms.rooms[self.room_id].blade.map_or_else(Rect::default, |b| {
            Rect::new(self.blade_pos.x, self.blade_pos.y, b.rect.w, b.rect.h)
        })
    }

    /// True during hitstop: the whole world, effects included, holds still.
    #[must_use]
    pub fn frozen(&self, p: &Params) -> bool {
        self.state == State::Dead && self.state_t < p.get("hitstop")
    }

    /// Fresh entry into a room: spawn point, blade reset, checkpoint saved.
    pub fn enter_room(&mut self, id: usize, keep_motion: bool) {
        self.room_id = id;
        if let Some(b) = self.rooms.rooms[id].blade {
            self.blade_pos = V2::new(b.rect.x, b.rect.y);
            self.blade_dir = 1.0;
        }
        if !keep_motion {
            self.spawn();
        }
        self.state = State::Alive;
        self.state_t = 0.0;
        self.emit(EventKind::RoomEnter);
        self.emit(EventKind::Checkpoint);
    }

    fn spawn(&mut self) {
        self.pos = self.rooms.rooms[self.room_id].spawn;
        self.vel = V2::default();
        self.on_ground = false;
        self.coyote_left = 0.0;
        self.buffer_left = 0.0;
        self.jump_cut_pending = false;
    }

    /// Advance one 60 Hz tick.
    pub fn tick(&mut self, input: Input, p: &Params) {
        self.events.clear();
        self.tick_count += 1;
        match self.state {
            State::Alive => self.tick_alive(input, p),
            State::Dead => {
                self.state_t += TICK;
                if self.state_t >= p.get("hitstop") + p.get("respawn_delay") {
                    self.spawn();
                    self.state = State::Alive;
                    self.emit(EventKind::Respawn);
                }
            }
            State::Goal => {
                self.state_t += TICK;
                if self.state_t >= p.get("goal_flash_duration") {
                    self.enter_room(0, false);
                }
            }
        }
        self.prev_jump = input.jump;
    }

    fn tick_alive(&mut self, input: Input, p: &Params) {
        self.vel.x = (f32::from(u8::from(input.right)) - f32::from(u8::from(input.left)))
            * p.get("move_speed");
        let jump_pressed = input.jump && !self.prev_jump;
        self.buffer_left =
            if jump_pressed { p.get("jump_buffer") } else { (self.buffer_left - TICK).max(0.0) };
        self.coyote_left =
            if self.on_ground { p.get("coyote_time") } else { (self.coyote_left - TICK).max(0.0) };
        // The press counts on its own tick: jump_buffer 0 means no buffering, not no jumping.
        if (jump_pressed || self.buffer_left > 0.0) && (self.on_ground || self.coyote_left > 0.0) {
            self.vel.y = -p.get("jump_velocity");
            self.buffer_left = 0.0;
            self.coyote_left = 0.0;
            self.on_ground = false;
            self.jump_cut_pending = true;
            self.emit(EventKind::Jump);
        }
        if self.jump_cut_pending && !input.jump {
            if self.vel.y < 0.0 {
                self.vel.y *= p.get("jump_cut_multiplier");
            }
            self.jump_cut_pending = false;
        }
        if self.vel.y >= 0.0 {
            self.jump_cut_pending = false;
        }
        self.vel.y = (self.vel.y + p.get("gravity") * TICK).min(p.get("max_fall_speed"));
        self.step(p);
        self.edges(p);
        self.move_blade(p);
        self.touch(p);
    }

    pub(crate) fn emit(&mut self, kind: EventKind) {
        self.events.push(Event { kind, room: self.room_id });
    }
}
