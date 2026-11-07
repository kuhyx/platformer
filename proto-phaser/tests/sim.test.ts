// Headless slice check (M10): drives Sim with scripted input, no browser.
//   npm test        (node --test, Node type stripping; no extra dependency)
// Mirrors proto-godot/tests/test_sim.gd; replay.test.ts mirrors replay.gd.
import assert from "node:assert/strict";
import { check } from "./helpers.ts";
import roomsJson from "../rooms.json" with { type: "json" };
import { param, setParam } from "../src/params.ts";
import { parseRooms, type Rect, type Room, type Rooms } from "../src/rooms.ts";
import { Sim } from "../src/sim.ts";
import { snapshot } from "../src/simState.ts";
import { State, type Input } from "../src/simTypes.ts";

const IDLE: Input = { left: false, right: false, jump: false };
const RIGHT: Input = { left: false, right: true, jump: false };
const RIGHT_JUMP: Input = { left: false, right: true, jump: true };
const JUMP: Input = { left: false, right: false, jump: true };
const SEED = 7;
const SECONDS = 60; // ticks per second, D12
const LONG_RUN = 300; // five seconds of ticks
const ROOM_1_RUN = 480; // eight seconds of ticks
const SETTLE = 2;
const DROP_TICKS = 9; // most of the way down from two avatar heights
const COYOTE_DEFAULT = 0.08;
const BUFFER_DEFAULT = 0.1;
const LEDGE_INDEX = 2;
const TWICE = 2;

const rooms: Rooms = parseRooms(roomsJson);

function roomAt(id: number): Room {
  const found = rooms.rooms[id];
  assert.ok(found);
  return found;
}

function solidAt(id: number, index: number): Rect {
  const found = roomAt(id).solids[index];
  assert.ok(found);
  return found;
}

function fresh(room = 0): Sim {
  const sim = new Sim(rooms, SEED);
  sim.enterRoom(room);
  return sim;
}

function run(sim: Sim, ticks: number, input: Input): string[] {
  const seen: string[] = [];
  for (let i = 0; i < ticks; i++) {
    sim.tick(input);
    seen.push(...sim.events.map((ev) => ev.e));
  }
  return seen;
}

/** Hold right, jump when the pit or the ledge is next. Ends in room 2. */
function runRoom1(sim: Sim): string[] {
  const seen: string[] = [];
  const pitX = roomAt(0).gaps[0]?.[0] ?? 0;
  const ledgeX = solidAt(0, LEDGE_INDEX).x;
  const w = sim.size().w;
  for (let i = 0; i < ROOM_1_RUN && sim.roomId === 0; i++) {
    const nearPit = sim.x + w >= pitX - w && sim.x < pitX;
    const nearLedge = sim.x + w >= ledgeX - w && sim.x < ledgeX;
    sim.tick(nearPit || nearLedge ? RIGHT_JUMP : RIGHT);
    seen.push(...sim.events.map((ev) => ev.e));
  }
  return seen;
}

check("idle avatar rests on the floor", () => {
  const sim = fresh();
  run(sim, SECONDS, IDLE);
  const floorTop = solidAt(0, 0).y;
  assert.ok(sim.onGround);
  assert.equal(sim.y, floorTop - sim.size().h);
});

check("walking into room 1's spike pit kills, respawn returns to room 1", () => {
  const sim = fresh();
  const seen = run(sim, LONG_RUN, RIGHT);
  assert.ok(seen.includes("death"));
  assert.ok(seen.includes("respawn") && sim.roomId === 0);
});

check("jumping the pit and the ledge reaches room 2 and raises a checkpoint", () => {
  const sim = fresh();
  const seen = runRoom1(sim);
  assert.ok(!seen.includes("death") && sim.roomId === 1);
  assert.ok(seen.includes("checkpoint"));
});

check("room 2: gap or blade kills, respawn stays in room 2; blade patrols its track", () => {
  let sim = fresh(1);
  const seen = run(sim, LONG_RUN, RIGHT);
  assert.ok(seen.includes("death") && sim.roomId === 1);
  sim = fresh(1);
  const blade = roomAt(1).blade;
  assert.ok(blade);
  const startX = sim.bladeX;
  run(sim, SECONDS, IDLE);
  assert.notEqual(sim.bladeX, startX);
  assert.ok(sim.bladeX >= blade.trackMin && sim.bladeX <= blade.trackMax);
});

check("touching the goal fires goal, then the loop restarts in room 1", () => {
  const sim = fresh(1);
  const goal = roomAt(1).goal;
  assert.ok(goal);
  sim.x = goal.x - sim.size().w - 1;
  sim.y = goal.y;
  const seen = run(sim, TWICE * SECONDS, RIGHT);
  assert.ok(seen.includes("goal"));
  assert.ok(sim.roomId === 0 && sim.state === State.ALIVE);
});

/** Walk off the ledge, then press jump a few ticks later. */
function lateJumpAfterLedge(coyote: number): boolean {
  setParam("coyote_time", coyote);
  const sim = fresh();
  const ledge = solidAt(0, LEDGE_INDEX);
  const { w, h } = sim.size();
  sim.x = ledge.x + ledge.w - w - 1;
  sim.y = ledge.y - h;
  run(sim, SETTLE, IDLE); // settle onto the ledge
  sim.x = rooms.width - w; // stand on the ledge's last pixel
  run(sim, 1, IDLE);
  sim.x = ledge.x + ledge.w; // airborne past the edge
  run(sim, SETTLE, IDLE);
  const seen = run(sim, 1, JUMP);
  setParam("coyote_time", COYOTE_DEFAULT);
  return seen.includes("jump");
}

check("coyote_time 0 loses the late jump, default keeps it", () => {
  assert.equal(lateJumpAfterLedge(0), false);
  assert.equal(lateJumpAfterLedge(COYOTE_DEFAULT), true);
});

/** Tap jump while falling, a few ticks before landing. */
function earlyJumpBeforeLanding(buffer: number): boolean {
  setParam("jump_buffer", buffer);
  const sim = fresh();
  sim.y -= TWICE * sim.size().h;
  run(sim, DROP_TICKS, IDLE);
  run(sim, 1, JUMP);
  const seen = run(sim, SECONDS, IDLE);
  setParam("jump_buffer", BUFFER_DEFAULT);
  return seen.includes("jump");
}

check("jump_buffer 0 loses the early tap, default fires it on landing", () => {
  assert.equal(earlyJumpBeforeLanding(0), false);
  assert.equal(earlyJumpBeforeLanding(BUFFER_DEFAULT), true);
});

check("coyote_time and jump_buffer 0 still jump from the ground", () => {
  setParam("coyote_time", 0);
  setParam("jump_buffer", 0);
  const sim = fresh();
  run(sim, SETTLE, IDLE);
  const seen = run(sim, 1, JUMP);
  setParam("coyote_time", COYOTE_DEFAULT);
  setParam("jump_buffer", BUFFER_DEFAULT);
  assert.ok(seen.includes("jump"));
});

check("same seed + inputs give an identical snapshot (D12)", () => {
  const a = fresh();
  const b = fresh();
  runRoom1(a);
  runRoom1(b);
  run(a, SECONDS, RIGHT);
  run(b, SECONDS, RIGHT);
  assert.deepEqual(snapshot(a), snapshot(b));
  assert.equal(param("coyote_time"), COYOTE_DEFAULT);
});

check("winnability assert rejects a layout the registry cannot clear", () => {
  const speed = param("move_speed");
  setParam("move_speed", 1);
  try {
    assert.throws(() => parseRooms(roomsJson), /needs/);
  } finally {
    setParam("move_speed", speed);
  }
});
