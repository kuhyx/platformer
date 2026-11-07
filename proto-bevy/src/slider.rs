//! Slider maths for the debug overlay, kept pure so it is unit-tested
//! (the overlay itself is Bevy glue).
use crate::params::Entry;

/// Fraction `0..=1` of `value` along the entry's `[min, max]` range.
#[must_use]
pub fn fraction(e: &Entry, value: f32) -> f32 {
    if e.max > e.min {
        ((value - e.min) / (e.max - e.min)).clamp(0.0, 1.0)
    } else {
        0.0
    }
}

/// Value for a pointer at fraction `t` along the track, snapped to `step`.
#[must_use]
pub fn value_at(e: &Entry, t: f32) -> f32 {
    let raw = e.min + t.clamp(0.0, 1.0) * (e.max - e.min);
    let snapped =
        if e.step > 0.0 { e.min + ((raw - e.min) / e.step).round() * e.step } else { raw };
    snapped.clamp(e.min, e.max)
}

/// Value text without float noise (`0.1`, not `0.100000001`).
#[must_use]
pub fn label(value: f32) -> String {
    let text = format!("{value:.3}");
    text.trim_end_matches('0').trim_end_matches('.').to_owned()
}
