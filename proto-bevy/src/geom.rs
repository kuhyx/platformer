//! Minimal 2D geometry for the sim: no Bevy types, y grows downward as in
//! `rooms.json` (the render layer flips it).

/// Small index to float without a lossy `as` cast (saturates at `u16::MAX`).
#[must_use]
pub fn idx_f32(n: usize) -> f32 {
    f32::from(u16::try_from(n).unwrap_or(u16::MAX))
}

/// A 2D point or vector.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct V2 {
    /// Horizontal component.
    pub x: f32,
    /// Vertical component (down).
    pub y: f32,
}

impl V2 {
    /// Construct from components.
    #[must_use]
    pub const fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

/// Axis-aligned rectangle: top-left corner plus size.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Rect {
    /// Left edge.
    pub x: f32,
    /// Top edge.
    pub y: f32,
    /// Width.
    pub w: f32,
    /// Height.
    pub h: f32,
}

impl Rect {
    /// Construct from `[x, y, w, h]`.
    #[must_use]
    pub const fn new(x: f32, y: f32, w: f32, h: f32) -> Self {
        Self { x, y, w, h }
    }

    /// Right edge.
    #[must_use]
    pub fn right(&self) -> f32 {
        self.x + self.w
    }

    /// Bottom edge.
    #[must_use]
    pub fn bottom(&self) -> f32 {
        self.y + self.h
    }

    /// Centre point.
    #[must_use]
    pub fn center(&self) -> V2 {
        V2::new(self.x + self.w * 0.5, self.y + self.h * 0.5)
    }

    /// Strict overlap: touching edges do not intersect (Godot `Rect2.intersects`).
    #[must_use]
    pub fn intersects(&self, o: &Rect) -> bool {
        self.x < o.right() && self.right() > o.x && self.y < o.bottom() && self.bottom() > o.y
    }
}
