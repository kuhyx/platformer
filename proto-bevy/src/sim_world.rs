//! The world half of a sim tick: collision sweep, room edges, the patrolling
//! blade and hazard/goal contact. Split from `sim.rs` for the file cap.
use crate::events::{EventKind, State};
use crate::params::Params;
use crate::sim::{Sim, TICK};

impl Sim {
    /// Axis-separated AABB sweep against the room's solids.
    pub(crate) fn step(&mut self, p: &Params) {
        let size = Self::size(p);
        let solids = self.rooms.rooms[self.room_id].solids.clone();
        self.pos.x += self.vel.x * TICK;
        for s in &solids {
            if self.rect(p).intersects(s) {
                self.pos.x = if self.vel.x > 0.0 { s.x - size.x } else { s.right() };
            }
        }
        self.pos.y += self.vel.y * TICK;
        self.on_ground = false;
        for s in &solids {
            if self.rect(p).intersects(s) {
                if self.vel.y > 0.0 {
                    self.pos.y = s.y - size.y;
                    self.on_ground = true;
                } else {
                    self.pos.y = s.bottom();
                }
                self.vel.y = 0.0;
            }
        }
    }

    /// Room edges: hard cut to the neighbour (D16), clamp at the slice ends.
    pub(crate) fn edges(&mut self, p: &Params) {
        let w = Self::size(p).x;
        let width = self.rooms.width;
        if self.pos.x < 0.0 {
            if self.room_id > 0 {
                self.enter_room(self.room_id - 1, true);
                self.pos.x = width - w;
            } else {
                self.pos.x = 0.0;
            }
        } else if self.pos.x + w > width {
            if self.room_id + 1 < self.rooms.count() {
                self.enter_room(self.room_id + 1, true);
                self.pos.x = 0.0;
            } else {
                self.pos.x = width - w;
            }
        }
    }

    pub(crate) fn move_blade(&mut self, p: &Params) {
        let Some(blade) = self.rooms.rooms[self.room_id].blade else { return };
        self.blade_pos.x += self.blade_dir * p.get("blade_speed") * TICK;
        if self.blade_pos.x >= blade.track.1 {
            self.blade_pos.x = blade.track.1;
            self.blade_dir = -1.0;
        } else if self.blade_pos.x <= blade.track.0 {
            self.blade_pos.x = blade.track.0;
            self.blade_dir = 1.0;
        }
    }

    pub(crate) fn touch(&mut self, p: &Params) {
        let me = self.rect(p);
        let room = &self.rooms.rooms[self.room_id];
        let hit_static = room.hazards.iter().any(|h| me.intersects(h));
        let hit_blade = room.blade.is_some() && me.intersects(&self.blade_rect());
        if hit_static || hit_blade {
            self.state = State::Dead;
            self.state_t = 0.0;
            self.emit(EventKind::Death);
        } else if room.goal.is_some_and(|g| me.intersects(&g)) {
            self.state = State::Goal;
            self.state_t = 0.0;
            self.emit(EventKind::Goal);
        }
    }
}
