// Seeded RNG (D12): mulberry32. One instance per Sim, state saved in snapshots.
// Not bit-identical to Godot's PCG; the replay fixture checks events, not particles.
const UINT32 = 0x1_0000_0000;
const GOLDEN = 0x6d2b79f5;
const SHIFT_A = 15;
const SHIFT_B = 7;
const SHIFT_C = 14;
const MIX_B = 61;

export class Rng {
  state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** Uniform float in [0, 1). */
  next(): number {
    this.state = (this.state + GOLDEN) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> SHIFT_A), t | 1);
    t ^= t + Math.imul(t ^ (t >>> SHIFT_B), t | MIX_B);
    return ((t ^ (t >>> SHIFT_C)) >>> 0) / UINT32;
  }

  range(lo: number, hi: number): number {
    return lo + this.next() * (hi - lo);
  }
}
