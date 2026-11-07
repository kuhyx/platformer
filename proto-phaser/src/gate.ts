// Web start gate (D02): pulsing icon, no text (D04).
import { HALF, TAU } from "./mathConsts.ts";
import { param } from "./params.ts";

export class Gate {
  active = true;
  ready = false;
  phase = 0;

  tick(dt: number): void {
    this.phase += dt;
  }

  visible(): boolean {
    return this.active && this.ready;
  }

  /** Only after the first frame was signalled; true when this press consumed it. */
  dismiss(): boolean {
    if (!this.visible()) {
      return false;
    }
    this.active = false;
    return true;
  }

  radius(): number {
    const wave = (1 + Math.sin((this.phase / param("gate_pulse_period")) * TAU)) / HALF;
    return param("gate_icon_radius") * (1 - param("gate_pulse_depth") * (1 - wave));
  }
}
