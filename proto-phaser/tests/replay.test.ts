// Cross-engine replay fixture (shared/replay/slice_trace.json): the inputs are
// fed to Sim at 60 Hz from enterRoom(0), seed 7, and the emitted events must
// match the fixture's names, rooms and order, each tick within +-1.
import assert from "node:assert/strict";
import { check } from "./helpers.ts";
import roomsJson from "../rooms.json" with { type: "json" };
import { parseRooms } from "../src/rooms.ts";
import { Sim } from "../src/sim.ts";
import trace from "../../shared/replay/slice_trace.json" with { type: "json" };

const TOLERANCE = 1; // float width differs per engine
type Segment = [number, number, number, number];
type Expected = [number, string, number];

function replay(segments: Segment[]): Expected[] {
  const sim = new Sim(parseRooms(roomsJson), trace.seed);
  const got: Expected[] = [];
  const log = (): void => {
    for (const ev of sim.events) {
      got.push([sim.tickCount, ev.e, sim.roomId]);
    }
  };
  sim.enterRoom(0);
  log();
  for (const [ticks, left, right, jump] of segments) {
    for (let i = 0; i < ticks; i++) {
      sim.tick({ left: left === 1, right: right === 1, jump: jump === 1 });
      log();
    }
  }
  return got;
}

check("slice_trace.json replays to the same events within one tick", () => {
  const want = trace.events as unknown as Expected[];
  const got = replay(trace.inputs as unknown as Segment[]);
  assert.equal(got.length, want.length);
  want.forEach(([tick, name, room], i) => {
    const [gotTick, gotName, gotRoom] = got[i] ?? [-1, "", -1];
    assert.equal(gotName, name, `event ${String(i)} name`);
    assert.equal(gotRoom, room, `event ${String(i)} room`);
    assert.ok(Math.abs(gotTick - tick) <= TOLERANCE, `event ${String(i)} tick ${String(gotTick)} vs ${String(tick)}`);
  });
});
