// Juice (D06): death particles, screen shake, goal flash. Ticked in lockstep
// with the sim and fed its RNG, so a replay reproduces every particle.
import { TAU } from "./mathConsts.ts";
import { param } from "./params.ts";
import type { Rng } from "./rng.ts";
import { TICK, type SimEvent } from "./simTypes.ts";

export interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
}

export class Fx {
  particles: Particle[] = [];
  shakeLeft = 0;
  shakeX = 0;
  shakeY = 0;
  flashLeft = 0;

  /** `cx`, `cy` is the avatar centre at the moment the events fired. */
  onEvents(events: SimEvent[], rng: Rng, cx: number, cy: number): void {
    for (const ev of events) {
      if (ev.e === "death") {
        this.burst(rng, cx, cy);
        this.shakeLeft = param("shake_duration");
      } else if (ev.e === "goal") {
        this.flashLeft = param("goal_flash_duration");
      }
    }
  }

  private burst(rng: Rng, cx: number, cy: number): void {
    const speed = param("particle_speed");
    const life = param("particle_lifetime");
    const count = Math.trunc(param("death_particles"));
    for (let i = 0; i < count; i++) {
      const angle = rng.range(0, TAU);
      const mag = rng.range(0, speed);
      this.particles.push({ x: cx, y: cy, vx: Math.cos(angle) * mag, vy: Math.sin(angle) * mag, life });
    }
  }

  tick(rng: Rng): void {
    const gravity = param("gravity");
    this.particles = this.particles.filter((p) => {
      p.life -= TICK;
      if (p.life <= 0) {
        return false;
      }
      p.vy += gravity * TICK;
      p.x += p.vx * TICK;
      p.y += p.vy * TICK;
      return true;
    });
    this.shakeLeft = Math.max(this.shakeLeft - TICK, 0);
    if (this.shakeLeft > 0) {
      const amp = param("shake_amplitude");
      this.shakeX = rng.range(-amp, amp);
      this.shakeY = rng.range(-amp, amp);
    } else {
      this.shakeX = 0;
      this.shakeY = 0;
    }
    this.flashLeft = Math.max(this.flashLeft - TICK, 0);
  }

  flashAlpha(): number {
    const total = param("goal_flash_duration");
    return total > 0 ? this.flashLeft / total : 0;
  }
}
