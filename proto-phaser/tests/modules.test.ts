// Unit checks for the non-sim modules: fx, gate, save parsing, pad mapping, registry.
import assert from "node:assert/strict";
import { Fx } from "../src/fx.ts";
import { Gate } from "../src/gate.ts";
import { readPad } from "../src/input.ts";
import { entry, loadRegistry, param, paramKeys, registryHash, setParam } from "../src/params.ts";
import { Rng } from "../src/rng.ts";
import { parseSave, readRoom } from "../src/save.ts";
import { TICK } from "../src/simTypes.ts";
import { check } from "./helpers.ts";

const SEED = 7;
const ROOM_COUNT = 2;
const PAD_RIGHT_STICK = 0.9;
const PAD_DRIFT = 0.2;
const PAD_DPAD_RIGHT = 15;
const PAD_SOUTH = 0;
const PAD_START = 9;
const PAD_BUTTONS = 16;
const PULSE_STEPS = 200;
const EPSILON = 1e-9;
const CENTER = 100;
const SINGLE_MAX = 2;

function burstAt(rng: Rng): Fx {
  const fx = new Fx();
  fx.onEvents([{ e: "death", room: 0 }], rng, CENTER, CENTER);
  return fx;
}

check("death spawns death_particles from the seeded rng, same seed same burst", () => {
  const a = burstAt(new Rng(SEED));
  const b = burstAt(new Rng(SEED));
  assert.equal(a.particles.length, param("death_particles"));
  assert.deepEqual(a.particles, b.particles);
  assert.equal(a.shakeLeft, param("shake_duration"));
  assert.notDeepEqual(a.particles, burstAt(new Rng(SEED + 1)).particles);
});

check("particles expire after particle_lifetime and shake settles to zero", () => {
  const rng = new Rng(SEED);
  const fx = burstAt(rng);
  const ticks = Math.ceil(Math.max(param("particle_lifetime"), param("shake_duration")) / TICK) + 1;
  for (let i = 0; i < ticks; i++) {
    fx.tick(rng);
  }
  assert.equal(fx.particles.length, 0);
  assert.equal(fx.shakeX, 0);
  assert.equal(fx.shakeY, 0);
});

check("goal flash starts at alpha 1 and fades to 0", () => {
  const rng = new Rng(SEED);
  const fx = new Fx();
  fx.onEvents([{ e: "goal", room: 1 }], rng, 0, 0);
  assert.equal(fx.flashAlpha(), 1);
  const ticks = Math.ceil(param("goal_flash_duration") / TICK) + 1;
  for (let i = 0; i < ticks; i++) {
    fx.tick(rng);
  }
  assert.equal(fx.flashAlpha(), 0);
});

check("gate dismisses only after ready, and its pulse stays inside radius * (1 - depth)..radius", () => {
  const gate = new Gate();
  assert.equal(gate.dismiss(), false);
  assert.ok(gate.active);
  const top = param("gate_icon_radius");
  const bottom = top * (1 - param("gate_pulse_depth"));
  for (let i = 0; i < PULSE_STEPS; i++) {
    gate.tick(TICK);
    assert.ok(gate.radius() <= top + EPSILON && gate.radius() >= bottom - EPSILON);
  }
  gate.ready = true;
  assert.ok(gate.visible());
  assert.equal(gate.dismiss(), true);
  assert.equal(gate.visible(), false);
});

check("a missing, corrupt or out-of-range save starts in room 0 (D19)", () => {
  assert.equal(parseSave('{"room_id":1}', ROOM_COUNT), 1);
  for (const bad of [undefined, null, "", "{", "[]", "null", '{"room_id":"1"}', '{"room_id":-1}', '{"room_id":2}', '{"room_id":0.5}']) {
    assert.equal(parseSave(bad, ROOM_COUNT), 0);
  }
});

check("without IndexedDB the save read falls back to room 0 silently", async () => {
  assert.equal(await readRoom(ROOM_COUNT), 0);
});

check("pad: stick beyond the dead zone, d-pad, south and start map to actions", () => {
  const none = Array.from({ length: PAD_BUTTONS }, () => false);
  assert.equal(readPad(none, PAD_RIGHT_STICK).right, true);
  assert.equal(readPad(none, -PAD_RIGHT_STICK).left, true);
  assert.equal(readPad(none, PAD_DRIFT).right, false);
  assert.equal(readPad(none, 0).any, false);
  const press = (i: number): boolean[] => none.map((_, k) => k === i);
  assert.equal(readPad(press(PAD_DPAD_RIGHT), 0).right, true);
  assert.equal(readPad(press(PAD_SOUTH), 0).jump, true);
  assert.equal(readPad(press(PAD_START), 0).start, true);
});

check("registry: metadata keys skipped, values clamped, hash follows the text", () => {
  const before = paramKeys();
  assert.ok(!before.some((k) => k.startsWith("_")));
  const hashBefore = registryHash();
  const speed = entry("move_speed");
  setParam("move_speed", speed.max + 1);
  assert.equal(param("move_speed"), speed.max);
  loadRegistry({ _note: "x", only: { value: 1, min: 0, max: SINGLE_MAX, step: 1, unit: "u", desc: "d" } });
  assert.deepEqual(paramKeys(), ["only"]);
  assert.notEqual(registryHash(), hashBefore);
  assert.throws(() => param("move_speed"), /unknown param/);
});
