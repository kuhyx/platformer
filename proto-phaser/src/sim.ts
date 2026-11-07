// The slice's pure fixed-step simulation (D12): movement, collision, rooms,
// hazards, death and goal. No Phaser, no DOM, so a test or replay drives it
// headless (M10). Every number comes from the registry or rooms.json.
// Mirrors proto-godot/sim.gd line for line.
import { param } from "./params.ts";
import { Rng } from "./rng.ts";
import { intersects, type Rect, type Room, type Rooms } from "./rooms.ts";
import { State, TICK, type Input, type SimEvent, type StateId } from "./simTypes.ts";

/**
 * Godot stores position, velocity and blade position in Vector2, whose
 * components are 32-bit floats. Rounding the same stores keeps this port on
 * the same side of every touching-edge contact (the replay fixture's goal
 * contact is exactly such an edge: x reaches 808.0 against a goal at 820).
 */
const f32 = Math.fround;

export class Sim {
  readonly rng: Rng;
  tickCount = 0;
  roomId = 0;
  x = 0; // avatar top-left
  y = 0;
  vx = 0;
  vy = 0;
  onGround = false;
  coyoteLeft = 0;
  bufferLeft = 0;
  jumpCutPending = false; // takeoff until release or apex (variable height)
  prevJump = false;
  state: StateId = State.ALIVE;
  stateT = 0; // seconds spent in DEAD / GOAL
  bladeX = 0;
  bladeY = 0;
  bladeDir = 1;
  events: SimEvent[] = []; // emitted during the last tick

  readonly rooms: Rooms;
  readonly seedValue: number;

  constructor(rooms: Rooms, seedValue: number) {
    this.rooms = rooms;
    this.seedValue = seedValue;
    this.rng = new Rng(seedValue);
  }

  size(): { w: number; h: number } {
    return { w: param("player_w"), h: param("player_h") };
  }

  rect(): Rect {
    return { x: this.x, y: this.y, ...this.size() };
  }

  room(): Room {
    const found = this.rooms.rooms[this.roomId];
    if (!found) {
      throw new Error(`no room ${String(this.roomId)}`);
    }
    return found;
  }

  bladeRect(): Rect | null {
    const blade = this.room().blade;
    return blade ? { x: this.bladeX, y: this.bladeY, w: blade.rect.w, h: blade.rect.h } : null;
  }

  /** True during hitstop: the whole world, effects included, holds still. */
  frozen(): boolean {
    return this.state === State.DEAD && this.stateT < param("hitstop");
  }

  /** Fresh entry into a room: spawn point, blade reset, checkpoint saved. */
  enterRoom(id: number, keepMotion = false): void {
    this.roomId = id;
    const blade = this.room().blade;
    if (blade) {
      this.bladeX = f32(blade.rect.x);
      this.bladeY = f32(blade.rect.y);
      this.bladeDir = 1;
    }
    if (!keepMotion) {
      this.spawn();
    }
    this.state = State.ALIVE;
    this.stateT = 0;
    this.emit({ e: "room_enter", room: id });
    this.emit({ e: "checkpoint", room: id });
  }

  private spawn(): void {
    const { x, y } = this.room().spawn;
    this.x = f32(x);
    this.y = f32(y);
    this.vx = 0;
    this.vy = 0;
    this.onGround = false;
    this.coyoteLeft = 0;
    this.bufferLeft = 0;
    this.jumpCutPending = false;
  }

  tick(input: Input): void {
    this.events = [];
    this.tickCount += 1;
    if (this.state === State.ALIVE) {
      this.tickAlive(input);
    } else if (this.state === State.DEAD) {
      this.stateT += TICK;
      if (this.stateT >= param("hitstop") + param("respawn_delay")) {
        this.spawn();
        this.state = State.ALIVE;
        this.emit({ e: "respawn", room: this.roomId });
      }
    } else {
      this.stateT += TICK;
      if (this.stateT >= param("goal_flash_duration")) {
        this.enterRoom(0);
      }
    }
    this.prevJump = input.jump;
  }

  private tickAlive(input: Input): void {
    this.vx = f32((Number(input.right) - Number(input.left)) * param("move_speed"));
    const jumpPressed = input.jump && !this.prevJump;
    this.bufferLeft = jumpPressed ? param("jump_buffer") : Math.max(this.bufferLeft - TICK, 0);
    this.coyoteLeft = this.onGround ? param("coyote_time") : Math.max(this.coyoteLeft - TICK, 0);
    // The press counts on its own tick: jump_buffer 0 means no buffering, not no jumping.
    if ((jumpPressed || this.bufferLeft > 0) && (this.onGround || this.coyoteLeft > 0)) {
      this.vy = f32(-param("jump_velocity"));
      this.bufferLeft = 0;
      this.coyoteLeft = 0;
      this.onGround = false;
      this.jumpCutPending = true;
      this.emit({ e: "jump" });
    }
    if (this.jumpCutPending && !input.jump) {
      if (this.vy < 0) {
        this.vy = f32(this.vy * param("jump_cut_multiplier"));
      }
      this.jumpCutPending = false;
    }
    if (this.vy >= 0) {
      this.jumpCutPending = false;
    }
    this.vy = f32(Math.min(this.vy + param("gravity") * TICK, param("max_fall_speed")));
    this.move();
    this.edges();
    this.moveBlade();
    this.touch();
  }

  /** Axis-separated AABB sweep against the room's solids. */
  private move(): void {
    const { w, h } = this.size();
    this.x = f32(this.x + this.vx * TICK);
    for (const s of this.room().solids) {
      if (intersects(this.rect(), s)) {
        this.x = this.vx > 0 ? s.x - w : s.x + s.w;
      }
    }
    this.y = f32(this.y + this.vy * TICK);
    this.onGround = false;
    for (const s of this.room().solids) {
      if (intersects(this.rect(), s)) {
        if (this.vy > 0) {
          this.y = s.y - h;
          this.onGround = true;
        } else {
          this.y = s.y + s.h;
        }
        this.vy = 0;
      }
    }
  }

  /** Room edges: hard cut to the neighbour (D16), clamp at the ends of the slice. */
  private edges(): void {
    const w = this.size().w;
    const width = this.rooms.width;
    if (this.x < 0) {
      if (this.roomId > 0) {
        this.enterRoom(this.roomId - 1, true);
        this.x = width - w;
      } else {
        this.x = 0;
      }
    } else if (this.x + w > width) {
      if (this.roomId < this.rooms.rooms.length - 1) {
        this.enterRoom(this.roomId + 1, true);
        this.x = 0;
      } else {
        this.x = width - w;
      }
    }
  }

  private moveBlade(): void {
    const blade = this.room().blade;
    if (!blade) {
      return;
    }
    this.bladeX = f32(this.bladeX + this.bladeDir * param("blade_speed") * TICK);
    if (this.bladeX >= blade.trackMax) {
      this.bladeX = blade.trackMax;
      this.bladeDir = -1;
    } else if (this.bladeX <= blade.trackMin) {
      this.bladeX = blade.trackMin;
      this.bladeDir = 1;
    }
  }

  private touch(): void {
    const me = this.rect();
    const bladeRect = this.bladeRect();
    if (this.room().hazards.some((h) => intersects(me, h)) || (bladeRect && intersects(me, bladeRect))) {
      this.state = State.DEAD;
      this.stateT = 0;
      this.emit({ e: "death", room: this.roomId, x: this.x, y: this.y });
      return;
    }
    const goal = this.room().goal;
    if (goal && intersects(me, goal)) {
      this.state = State.GOAL;
      this.stateT = 0;
      this.emit({ e: "goal", room: this.roomId });
    }
  }

  private emit(ev: SimEvent): void {
    this.events.push(ev);
  }
}
