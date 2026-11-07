//! Seeded PCG32, so the sim and effects replay identically (D12). Same
//! family as Godot's RNG, not bit-identical: only event timing is compared
//! across engines, and no sim rule consumes randomness.

const MULT: u64 = 6_364_136_223_846_793_005;
const INC: u64 = 1_442_695_040_888_963_407;

/// Deterministic generator; `state` is saved in snapshots.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Rng {
    /// Internal 64-bit state.
    pub state: u64,
}

impl Rng {
    /// Seeded generator (PCG32 seeding sequence).
    #[must_use]
    pub fn new(seed: u64) -> Self {
        let mut rng = Self { state: 0 };
        rng.next_u32();
        rng.state = rng.state.wrapping_add(seed);
        rng.next_u32();
        rng
    }

    /// Next 32 random bits.
    pub fn next_u32(&mut self) -> u32 {
        let old = self.state;
        self.state = old.wrapping_mul(MULT).wrapping_add(INC);
        let xorshifted = u32::try_from((((old >> 18) ^ old) >> 27) & 0xFFFF_FFFF).unwrap_or(0);
        xorshifted.rotate_right(u32::try_from(old >> 59).unwrap_or(0))
    }

    /// Uniform float in `[a, b)`.
    pub fn range(&mut self, a: f32, b: f32) -> f32 {
        // 23 random mantissa bits under exponent 0 give [1, 2); minus 1 is [0, 1).
        let unit = f32::from_bits(0x3F80_0000 | (self.next_u32() >> 9)) - 1.0;
        a + (b - a) * unit
    }
}
