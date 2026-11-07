// Thin Phaser scene for the slice (spec/DOCS-slice.md): polls input, steps the
// pure sim at 60 Hz (D12), draws the world, owns the gate and the debug keys.
// Every rule lives in sim.ts; this file only renders and forwards.
import Phaser from "phaser";
import { HALF } from "./mathConsts.ts";
import { Fx } from "./fx.ts";
import { Gate } from "./gate.ts";
import { Controls } from "./input.ts";
import { Overlay } from "./overlay.ts";
import { param, reloadFromServer } from "./params.ts";
import type { Rect, Rooms } from "./rooms.ts";
import { writeRoom, writeSnapshot } from "./save.ts";
import { Sim } from "./sim.ts";
import { State, TICK } from "./simTypes.ts";
import { restore, snapshot, type Snapshot } from "./simState.ts";

declare global {
  interface Window {
    __gameReady?: number;
    __sim?: Sim; // debug builds only: lets the M9 run read sim state
  }
}

export const WIDTH = 854; // D13
export const HEIGHT = 480; // D13
export const BACKGROUND = "#1a1a1f";
const MS_PER_S = 1000;
const MAX_FRAME = 0.1; // seconds; longer stalls drop time instead of spiralling

// Palette fixed by the slice spec: no sprites, one colour per element.
const COLOR_PLAYER = 0xffffff;
const COLOR_HAZARD = 0xff0000;
const COLOR_CHECKPOINT = 0x00ff00;
const COLOR_GOAL = 0xffff00;
const COLOR_FLOOR = 0x808080;
const COLOR_FLASH = 0xffffff;
const COLOR_DIM = 0x000000;
const OPAQUE = 1;

export interface Boot {
  rooms: Rooms;
  startRoom: number;
  seed: number;
  debug: boolean;
  snap: Snapshot | null;
}

export class Slice extends Phaser.Scene {
  private readonly boot: Boot;
  private readonly sim: Sim;
  private readonly fx = new Fx();
  private readonly gate = new Gate();
  private readonly controls = new Controls();
  private overlay: Overlay | null = null;
  private world!: Phaser.GameObjects.Graphics;
  private top!: Phaser.GameObjects.Graphics;
  private paused = false;
  private acc = 0;

  constructor(boot: Boot) {
    super("slice");
    this.boot = boot;
    this.sim = new Sim(boot.rooms, boot.seed);
  }

  create(): void {
    this.world = this.add.graphics();
    this.top = this.add.graphics();
    this.sim.enterRoom(this.boot.startRoom);
    if (this.boot.debug) {
      this.overlay = new Overlay(document.body);
      window.__sim = this.sim;
      this.controls.swallow("F1", "F5", "F6");
      if (this.boot.snap) {
        restore(this.sim, this.boot.snap);
      }
    }
    this.afterTick();
    this.controls.onPress = (): void => {
      this.gate.dismiss();
    };
    this.controls.onPause = (): void => {
      if (!this.gate.active) {
        this.paused = !this.paused;
      }
    };
    this.controls.onKey = (code): void => {
      this.debugKey(code);
    };
    this.controls.attach(window);
    this.game.events.once(Phaser.Core.Events.POST_RENDER, () => {
      window.__gameReady = performance.now();
      this.gate.ready = true;
    });
  }

  override update(_time: number, delta: number): void {
    const dt = Math.min(delta / MS_PER_S, MAX_FRAME);
    this.gate.tick(dt);
    const input = this.controls.poll();
    if (this.paused || this.gate.active) {
      this.acc = 0;
    } else {
      this.acc += dt;
      for (; this.acc >= TICK; this.acc -= TICK) {
        this.sim.tick(input);
        this.afterTick();
        if (!this.sim.frozen()) {
          this.fx.tick(this.sim.rng);
        }
      }
    }
    if (this.overlay?.visible) {
      this.overlay.setStatus(this.sim.roomId, this.game.loop.actualFps);
    }
    this.draw();
  }

  /** Reacts to whatever the sim emitted: effects and autosave. */
  private afterTick(): void {
    const r = this.sim.rect();
    this.fx.onEvents(this.sim.events, this.sim.rng, r.x + r.w / HALF, r.y + r.h / HALF);
    for (const ev of this.sim.events) {
      if (ev.e === "checkpoint" && ev.room !== undefined) {
        void writeRoom(ev.room);
      }
    }
  }

  private debugKey(code: string): void {
    if (!this.overlay || this.gate.active) {
      return;
    }
    if (code === "F1") {
      this.overlay.toggle();
    } else if (code === "F5") {
      void reloadFromServer().then(() => {
        this.overlay?.refresh();
      });
    } else if (code === "F6") {
      const text = JSON.stringify(snapshot(this.sim), null, HALF);
      console.info("snapshot:", text);
      void writeSnapshot(text);
    }
  }

  private fill(g: Phaser.GameObjects.Graphics, color: number, r: Rect, alpha = OPAQUE): void {
    g.fillStyle(color, alpha).fillRect(r.x, r.y, r.w, r.h);
  }

  private draw(): void {
    const room = this.sim.room();
    const g = this.world.clear().setPosition(this.fx.shakeX, this.fx.shakeY);
    room.solids.forEach((s) => {
      this.fill(g, COLOR_FLOOR, s);
    });
    room.hazards.forEach((h) => {
      this.fill(g, COLOR_HAZARD, h);
    });
    this.fill(g, COLOR_CHECKPOINT, room.checkpoint);
    if (room.goal) {
      this.fill(g, COLOR_GOAL, room.goal);
    }
    const blade = this.sim.bladeRect();
    if (blade) {
      this.fill(g, COLOR_HAZARD, blade);
    }
    if (this.sim.state !== State.DEAD) {
      this.fill(g, COLOR_PLAYER, this.sim.rect());
    }
    const side = param("particle_size");
    this.fx.particles.forEach((p) => {
      g.fillStyle(COLOR_PLAYER, OPAQUE).fillRect(p.x, p.y, side, side);
    });
    this.drawTop();
  }

  private drawTop(): void {
    const t = this.top.clear();
    const screen = { x: 0, y: 0, w: this.sim.rooms.width, h: this.sim.rooms.height };
    if (this.fx.flashAlpha() > 0) {
      this.fill(t, COLOR_FLASH, screen, this.fx.flashAlpha());
    }
    if (this.paused) {
      this.fill(t, COLOR_DIM, screen, param("pause_dim"));
    }
    if (this.gate.visible()) {
      this.fill(t, COLOR_DIM, screen, param("pause_dim"));
      t.fillStyle(COLOR_PLAYER, OPAQUE).fillCircle(screen.w / HALF, screen.h / HALF, this.gate.radius());
    }
  }
}
