//! Juice (D06): death particles, screen shake, goal flash. Ticked in
//! lockstep with the sim and fed its RNG, so a replay reproduces every
//! particle. Mirrors `proto-godot/fx.gd`.
use crate::geom::V2;
use crate::params::Params;
use crate::rng::Rng;
use crate::sim::{Event, EventKind, TICK};

/// One death-burst particle.
#[derive(Clone, Copy, Debug)]
pub struct Particle {
    /// Top-left position.
    pub pos: V2,
    /// Velocity, px/s.
    pub vel: V2,
    /// Seconds left.
    pub life: f32,
}

/// Effect state.
#[derive(Clone, Debug, Default)]
pub struct Fx {
    /// Live particles.
    pub particles: Vec<Particle>,
    /// Shake seconds left.
    pub shake_left: f32,
    /// Current shake offset.
    pub shake_offset: V2,
    /// Goal-flash seconds left.
    pub flash_left: f32,
}

impl Fx {
    /// React to sim events (death burst + shake, goal flash).
    pub fn on_events(&mut self, events: &[Event], rng: &mut Rng, avatar_center: V2, p: &Params) {
        for e in events {
            match e.kind {
                EventKind::Death => {
                    self.burst(rng, avatar_center, p);
                    self.shake_left = p.get("shake_duration");
                }
                EventKind::Goal => self.flash_left = p.get("goal_flash_duration"),
                _ => {}
            }
        }
    }

    fn burst(&mut self, rng: &mut Rng, center: V2, p: &Params) {
        let (speed, life) = (p.get("particle_speed"), p.get("particle_lifetime"));
        let mut left = p.get("death_particles");
        while left >= 1.0 {
            left -= 1.0;
            let angle = rng.range(0.0, std::f32::consts::TAU);
            let mag = rng.range(0.0, speed);
            let vel = V2::new(angle.cos() * mag, angle.sin() * mag);
            self.particles.push(Particle { pos: center, vel, life });
        }
    }

    /// Advance one sim tick.
    pub fn tick(&mut self, rng: &mut Rng, p: &Params) {
        let gravity = p.get("gravity");
        self.particles.retain_mut(|q| {
            q.life -= TICK;
            if q.life <= 0.0 {
                return false;
            }
            q.vel.y += gravity * TICK;
            q.pos.x += q.vel.x * TICK;
            q.pos.y += q.vel.y * TICK;
            true
        });
        self.shake_left = (self.shake_left - TICK).max(0.0);
        self.shake_offset = if self.shake_left > 0.0 {
            let amp = p.get("shake_amplitude");
            V2::new(rng.range(-amp, amp), rng.range(-amp, amp))
        } else {
            V2::default()
        };
        self.flash_left = (self.flash_left - TICK).max(0.0);
    }

    /// Flash overlay alpha, `0..=1`.
    #[must_use]
    pub fn flash_alpha(&self, p: &Params) -> f32 {
        let total = p.get("goal_flash_duration");
        if total > 0.0 {
            self.flash_left / total
        } else {
            0.0
        }
    }
}
