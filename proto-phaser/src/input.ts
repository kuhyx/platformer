// Input per spec/DOCS-input-map.md (D05): keyboard and gamepad always both
// active, no rebinding. Keyboard state is held in a Set so holding D across
// ticks works; the gamepad is polled each frame (standard mapping).
import type { Input } from "./simTypes.ts";

const LEFT = ["KeyA", "ArrowLeft"];
const RIGHT = ["KeyD", "ArrowRight"];
const JUMP = ["Space", "KeyW", "ArrowUp", "KeyZ", "KeyK"];
const PAUSE = ["Escape", "KeyP"];
const SWALLOW = [...LEFT, ...RIGHT, ...JUMP, "Escape"]; // keys the page must not scroll on
const DEAD_ZONE = 0.25; // fixed by D05, not a tunable
const PAD_SOUTH = 0;
const PAD_START = 9;
const PAD_DPAD_LEFT = 14;
const PAD_DPAD_RIGHT = 15;

export interface PadState {
  left: boolean;
  right: boolean;
  jump: boolean;
  start: boolean;
  any: boolean;
}

/** Map one standard-layout gamepad to actions. Pure, so it is unit-testable. */
export function readPad(buttons: readonly boolean[], axisX: number): PadState {
  return {
    left: axisX < -DEAD_ZONE || buttons[PAD_DPAD_LEFT] === true,
    right: axisX > DEAD_ZONE || buttons[PAD_DPAD_RIGHT] === true,
    jump: buttons[PAD_SOUTH] === true,
    start: buttons[PAD_START] === true,
    any: buttons.some(Boolean),
  };
}

export class Controls {
  private readonly down = new Set<string>();
  private padStart = false;
  private padAny = false;
  private readonly extraSwallow: string[] = [];
  /** Fired on every non-repeat key press, click and new pad button press. */
  onPress: () => void = () => undefined;
  /** Fired on Esc / P / pad Start. */
  onPause: () => void = () => undefined;
  /** Fired with the key code on every non-repeat key press (debug keys). */
  onKey: (code: string) => void = () => undefined;

  attach(target: Window): void {
    target.addEventListener("keydown", (ev) => {
      if (SWALLOW.includes(ev.code) || this.extraSwallow.includes(ev.code)) {
        ev.preventDefault();
      }
      if (ev.repeat) {
        return;
      }
      this.down.add(ev.code);
      this.onKey(ev.code);
      if (PAUSE.includes(ev.code)) {
        this.onPause();
      }
      this.onPress();
    });
    target.addEventListener("keyup", (ev) => {
      this.down.delete(ev.code);
    });
    target.addEventListener("blur", () => {
      this.down.clear();
    });
    target.addEventListener("pointerdown", () => {
      this.onPress();
    });
  }

  swallow(...codes: string[]): void {
    this.extraSwallow.push(...codes);
  }

  private held(codes: string[]): boolean {
    return codes.some((c) => this.down.has(c));
  }

  /** Sample once per frame: edge-detect pad buttons, return the current actions. */
  poll(): Input {
    const pad = navigator.getGamepads().find((p) => p?.connected);
    const state = pad
      ? readPad(
          pad.buttons.map((b) => b.pressed),
          pad.axes[0] ?? 0,
        )
      : readPad([], 0);
    if (state.start && !this.padStart) {
      this.onPause();
    }
    if (state.any && !this.padAny) {
      this.onPress();
    }
    this.padStart = state.start;
    this.padAny = state.any;
    return {
      left: this.held(LEFT) || state.left,
      right: this.held(RIGHT) || state.right,
      jump: this.held(JUMP) || state.jump,
    };
  }
}
