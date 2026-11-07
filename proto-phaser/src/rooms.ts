// Rooms loader (D24): parses the generated rooms.json and proves the slice is
// winnable at the current registry values: every gap must be clearable by a
// full jump and every step-up lower than the jump apex. A layout that fails is
// a bug, not a tuning job.
import { HALF } from "./mathConsts.ts";
import { param } from "./params.ts";

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Blade {
  rect: Rect;
  trackMin: number;
  trackMax: number;
}

export interface Room {
  spawn: { x: number; y: number };
  checkpoint: Rect;
  solids: Rect[];
  hazards: Rect[];
  gaps: [number, number][];
  blade: Blade | null;
  goal: Rect | null;
}

export interface Rooms {
  width: number;
  height: number;
  rooms: Room[];
}

type RawRect = [number, number, number, number];
interface RawRoom {
  spawn: [number, number];
  checkpoint: RawRect;
  solids: RawRect[];
  hazards: RawRect[];
  gaps: [number, number][];
  blade: { rect: RawRect; track: [number, number] } | null;
  goal: RawRect | null;
}
interface RawRooms {
  width: number;
  height: number;
  rooms: RawRoom[];
}

const rect = ([x, y, w, h]: RawRect): Rect => ({ x, y, w, h });

/** Godot Rect2.intersects semantics: touching edges do not overlap. */
export function intersects(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function parseRoom(raw: RawRoom): Room {
  return {
    spawn: { x: raw.spawn[0], y: raw.spawn[1] },
    checkpoint: rect(raw.checkpoint),
    solids: raw.solids.map(rect),
    hazards: raw.hazards.map(rect),
    gaps: raw.gaps,
    blade: raw.blade
      ? { rect: rect(raw.blade.rect), trackMin: raw.blade.track[0], trackMax: raw.blade.track[1] }
      : null,
    goal: raw.goal ? rect(raw.goal) : null,
  };
}

/** Horizontal reach of one full jump from flat ground, at the current values. */
export function jumpReach(): number {
  return param("move_speed") * ((HALF * param("jump_velocity")) / param("gravity"));
}

export function jumpApex(): number {
  const v = param("jump_velocity");
  return (v * v) / (HALF * param("gravity"));
}

/**
 * Throws when a gap is wider than a jump or a step taller than the apex.
 * Steps are measured from the room's floor (its lowest solid top). Godot's
 * rooms.gd measures from the highest solid, so its step check never fires;
 * this port checks what the comment there says.
 */
export function assertWinnable(layout: Rooms): void {
  const reach = jumpReach();
  const apex = jumpApex();
  const pw = param("player_w");
  layout.rooms.forEach((room, id) => {
    for (const [from, to] of room.gaps) {
      const span = to - from + pw;
      if (span >= reach) {
        throw new Error(`room ${String(id)}: gap needs ${String(span)} px, reach is ${String(reach)}`);
      }
    }
    const floorY = Math.max(...room.solids.map((s) => s.y));
    for (const s of room.solids) {
      if (floorY - s.y >= apex) {
        throw new Error(`room ${String(id)}: step of ${String(floorY - s.y)} px exceeds apex ${String(apex)}`);
      }
    }
  });
}

export function parseRooms(json: unknown): Rooms {
  const raw = json as RawRooms;
  const layout: Rooms = { width: raw.width, height: raw.height, rooms: raw.rooms.map(parseRoom) };
  assertWinnable(layout);
  return layout;
}
