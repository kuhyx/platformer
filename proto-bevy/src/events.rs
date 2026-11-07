//! Value types the sim exchanges with its callers: polled input, life-cycle
//! state and the events a tick reports. Re-exported from [`crate::sim`].

/// One tick of polled input.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Input {
    /// Move left held.
    pub left: bool,
    /// Move right held.
    pub right: bool,
    /// Jump held.
    pub jump: bool,
}

/// Avatar life cycle.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum State {
    /// Playing.
    Alive,
    /// Hitstop then respawn delay.
    Dead,
    /// Goal flash, then the loop restarts.
    Goal,
}

/// What a tick reported.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EventKind {
    /// A room was entered (also at boot).
    RoomEnter,
    /// Checkpoint raised: the autosave trigger.
    Checkpoint,
    /// Avatar jumped.
    Jump,
    /// Avatar died.
    Death,
    /// Avatar reappeared at the checkpoint.
    Respawn,
    /// Goal touched.
    Goal,
}

impl EventKind {
    /// Wire name used by the replay fixture.
    #[must_use]
    pub fn name(self) -> &'static str {
        match self {
            Self::RoomEnter => "room_enter",
            Self::Checkpoint => "checkpoint",
            Self::Jump => "jump",
            Self::Death => "death",
            Self::Respawn => "respawn",
            Self::Goal => "goal",
        }
    }
}

/// An event plus the room it concerned.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Event {
    /// Kind.
    pub kind: EventKind,
    /// Room id at emission.
    pub room: usize,
}
