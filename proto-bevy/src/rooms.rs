//! Loads `rooms.json` (generated, D24) and proves the slice is winnable at
//! the current registry values: every gap must be clearable by a full jump
//! and every step-up lower than the jump apex. Mirrors `proto-godot/rooms.gd`.
use crate::geom::{Rect, V2};
use crate::params::Params;
use serde::Deserialize;

/// The generated layout, compiled in.
const EMBEDDED: &str = include_str!("../rooms.json");

/// A patrolling hazard: its start rect and the x range it sweeps.
#[derive(Clone, Copy, Debug)]
pub struct Blade {
    /// Start rect (top-left plus size).
    pub rect: Rect,
    /// Left and right limits of the rect's x position.
    pub track: (f32, f32),
}

/// One screen.
#[derive(Clone, Debug)]
pub struct Room {
    /// Avatar top-left on (re)spawn.
    pub spawn: V2,
    /// Checkpoint marker.
    pub checkpoint: Rect,
    /// Floor and ledges.
    pub solids: Vec<Rect>,
    /// Static hazards (spikes, pits).
    pub hazards: Vec<Rect>,
    /// `[start_x, end_x]` of each gap the player must jump.
    pub gaps: Vec<(f32, f32)>,
    /// Moving hazard, if any.
    pub blade: Option<Blade>,
    /// Goal pillar, if any.
    pub goal: Option<Rect>,
}

/// All rooms plus the shared screen size.
#[derive(Clone, Debug)]
pub struct Rooms {
    /// Room width in px (854, D13).
    pub width: f32,
    /// Room height in px (480, D13).
    pub height: f32,
    /// Rooms, left to right.
    pub rooms: Vec<Room>,
}

#[derive(Deserialize)]
struct RawBlade {
    rect: [f32; 4],
    track: [f32; 2],
}

#[derive(Deserialize)]
struct RawRoom {
    spawn: [f32; 2],
    checkpoint: [f32; 4],
    solids: Vec<[f32; 4]>,
    hazards: Vec<[f32; 4]>,
    gaps: Vec<[f32; 2]>,
    blade: Option<RawBlade>,
    goal: Option<[f32; 4]>,
}

#[derive(Deserialize)]
struct RawRooms {
    width: f32,
    height: f32,
    rooms: Vec<RawRoom>,
}

fn rect(a: [f32; 4]) -> Rect {
    Rect::new(a[0], a[1], a[2], a[3])
}

impl From<RawRoom> for Room {
    fn from(r: RawRoom) -> Self {
        Self {
            spawn: V2::new(r.spawn[0], r.spawn[1]),
            checkpoint: rect(r.checkpoint),
            solids: r.solids.into_iter().map(rect).collect(),
            hazards: r.hazards.into_iter().map(rect).collect(),
            gaps: r.gaps.into_iter().map(|g| (g[0], g[1])).collect(),
            blade: r.blade.map(|b| Blade { rect: rect(b.rect), track: (b.track[0], b.track[1]) }),
            goal: r.goal.map(rect),
        }
    }
}

impl Rooms {
    /// The embedded layout, checked against `params`.
    ///
    /// # Panics
    /// If the layout is malformed or unwinnable: a bug, not a tuning job.
    #[must_use]
    pub fn load(params: &Params) -> Self {
        Self::parse(EMBEDDED, params).expect("embedded rooms.json is valid and winnable")
    }

    /// Parse layout text and run the winnability check.
    ///
    /// # Errors
    /// On malformed JSON or a layout the avatar cannot clear.
    pub fn parse(text: &str, params: &Params) -> Result<Self, String> {
        let raw: RawRooms = serde_json::from_str(text).map_err(|e| format!("rooms: {e}"))?;
        let rooms = Self {
            width: raw.width,
            height: raw.height,
            rooms: raw.rooms.into_iter().map(Room::from).collect(),
        };
        rooms.assert_winnable(params)?;
        Ok(rooms)
    }

    /// Number of rooms.
    #[must_use]
    pub fn count(&self) -> usize {
        self.rooms.len()
    }

    /// Horizontal reach of one full jump from flat ground.
    #[must_use]
    pub fn jump_reach(p: &Params) -> f32 {
        let air_time = 2.0 * p.get("jump_velocity") / p.get("gravity");
        p.get("move_speed") * air_time
    }

    /// Height of one full jump.
    #[must_use]
    pub fn jump_apex(p: &Params) -> f32 {
        let v = p.get("jump_velocity");
        v * v / (2.0 * p.get("gravity"))
    }

    /// Every gap clearable, every step below the apex.
    ///
    /// # Errors
    /// Names the first room and gap or step that fails.
    pub fn assert_winnable(&self, p: &Params) -> Result<(), String> {
        let (reach, apex, pw) = (Self::jump_reach(p), Self::jump_apex(p), p.get("player_w"));
        for (id, room) in self.rooms.iter().enumerate() {
            for gap in &room.gaps {
                let span = gap.1 - gap.0 + pw;
                if span >= reach {
                    return Err(format!("room {id}: gap needs {span:.0} px, reach is {reach:.0}"));
                }
            }
            let tallest = room.solids.iter().map(|s| self.height - s.y).fold(0.0, f32::max);
            for s in &room.solids {
                let step = self.height - s.y - tallest;
                if step >= apex {
                    return Err(format!("room {id}: step {step:.0} px exceeds apex {apex:.0}"));
                }
            }
        }
        Ok(())
    }
}
