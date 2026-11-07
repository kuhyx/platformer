// M9 agent play: headless Playwright through the real keyboard path.
//   node e2e/m9.mjs http://127.0.0.1:8771/ /tmp/phaser-shots
// Needs a built dist served at the URL (see README). Muted, off-screen
// (headless), software GL. Prints one JSON verdict line per check.
import { mkdirSync } from "node:fs";
import { chromium } from "../../tools/node_modules/playwright/index.mjs";

const [base = "http://127.0.0.1:8771/", out = "/tmp/phaser-shots"] = process.argv.slice(2);
const URL = `${base}?debug&seed=7`;
const POLL_MS = 6;
const AFTER_HITSTOP_MS = 110; // particles hold still during hitstop; let them spread
const FAILS = [];
mkdirSync(out, { recursive: true });

const browser = await chromium.launch({
  args: ["--mute-audio", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
});
const page = await (await browser.newContext({ viewport: { width: 854, height: 480 } })).newPage();
page.on("pageerror", (e) => console.log("pageerror", e.message));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const shot = (name) => page.screenshot({ path: `${out}/${name}.png` });
const verdict = (name, ok, detail = "") => {
  if (!ok) FAILS.push(name);
  console.log(JSON.stringify({ check: name, ok, detail }));
};
const state = () =>
  page.evaluate(() => {
    const s = window.__sim;
    const r = s.room();
    const b = s.bladeRect();
    return {
      room: s.roomId, x: s.x, y: s.y, st: s.state, ground: s.onGround, tick: s.tickCount,
      w: s.size().w, gap: r.gaps[0][0], ledge: r.solids[2]?.x ?? 0,
      blade: b && { x: b.x, end: b.x + b.w, dir: s.bladeDir },
    };
  });
const untilState = (st) => page.waitForFunction((v) => window.__sim.state === v, st, { polling: "raf" });

async function boot() {
  await page.goto(URL, { waitUntil: "commit" });
  await page.waitForFunction(() => typeof window.__gameReady === "number", null, { timeout: 30000 });
  await page.waitForTimeout(100);
}
async function dismissGate() {
  await page.mouse.click(427, 240);
  await page.waitForTimeout(100);
}
const savedRoom = () =>
  page.evaluate(() => new Promise((res) => {
    const req = indexedDB.open("proto-phaser");
    req.onsuccess = () => {
      const get = req.result.transaction("kv").objectStore("kv").get("save");
      get.onsuccess = () => res(get.result ?? null);
    };
  }));
const writeSave = (text) =>
  page.evaluate((t) => new Promise((res) => {
    const req = indexedDB.open("proto-phaser");
    req.onsuccess = () => {
      const tx = req.result.transaction("kv", "readwrite");
      tx.objectStore("kv").put(t, "save");
      tx.oncomplete = () => res();
    };
  }), text);
const slider = (key) => page.locator(`xpath=//span[starts-with(text(), "${key} ")]/following-sibling::input`);
const setSlider = (key, v) => slider(key).evaluate((el, val) => {
  el.value = val;
  el.dispatchEvent(new Event("input", { bubbles: true }));
}, String(v));

// 1. boot, gate, room 1
await boot();
verdict("gameReady is a number", typeof (await page.evaluate(() => window.__gameReady)) === "number");
await shot("0-gate");
await dismissGate();
await shot("1-room1-start");
verdict("gate dismissed by click, sim ticking", (await state()).tick > 0);

// 2. hold D into the spike pit: death burst
await page.keyboard.down("KeyD");
await untilState("dead");
await page.waitForTimeout(AFTER_HITSTOP_MS);
await shot("2-death-burst");
const dead = await state();
await page.keyboard.up("KeyD");
await untilState("alive");
verdict("pit kills then respawns in room 0", dead.room === 0 && (await state()).room === 0);

// 3. autopilot: hold D, hold Space across each pit/ledge approach
async function autopilot(until) {
  let jumping = false;
  let pressedAt = 0;
  await page.keyboard.down("KeyD");
  for (;;) {
    const s = await state();
    if (until(s)) break;
    const near = (x) => s.x + 2 * s.w >= x && s.x < x;
    const want = s.st === "alive" && (near(s.gap) || near(s.ledge));
    if (want && !jumping) { await page.keyboard.down("Space"); jumping = true; pressedAt = s.tick; }
    if (jumping && !want && s.ground && s.tick - pressedAt > 10) { await page.keyboard.up("Space"); jumping = false; }
    await sleep(POLL_MS);
  }
  if (jumping) await page.keyboard.up("Space");
  await page.keyboard.up("KeyD");
}
await autopilot((s) => s.room === 1);
verdict("room 1 cleared by keyboard, now in room 2", (await state()).room === 1);
verdict("autosave holds room id 1", JSON.parse((await savedRoom()) ?? "{}").room_id === 1);

// 4. relaunch resumes in room 2
await page.reload({ waitUntil: "commit" });
await page.waitForFunction(() => typeof window.__gameReady === "number");
await dismissGate();
verdict("reload resumes in room id 1", (await state()).room === 1);
await shot("3-room2-blade");

// 4b. blade death mid-air: stand at x ~215 (inside the blade track), jump as the blade closes
async function bladeDeath() {
  await page.keyboard.down("KeyD");
  await page.waitForFunction(() => window.__sim.x > 215);
  await page.keyboard.up("KeyD");
  for (;;) {
    const s = await state();
    if (s.st === "dead") return s;
    if (s.blade?.dir < 0 && s.blade.x - (s.x + s.w) < 44 && s.ground) {
      await page.keyboard.down("Space");
      await untilState("dead");
      await page.keyboard.up("Space");
      return state();
    }
    await sleep(POLL_MS);
  }
}
const hit = await bladeDeath();
await page.waitForTimeout(AFTER_HITSTOP_MS);
await shot("2b-blade-death-burst");
verdict("blade kills mid-air", hit.st === "dead" && hit.y < 424, `y=${hit.y}`);
await untilState("alive");
verdict("respawn stays in room 2", (await state()).room === 1);

// 5. pause, overlay, F5
await page.keyboard.press("KeyP");
const t0 = (await state()).tick;
await page.waitForTimeout(300);
verdict("pause freezes the sim", (await state()).tick === t0);
await page.keyboard.press("KeyP");
await page.waitForTimeout(100);
verdict("resume restarts the sim", (await state()).tick > t0);
await page.keyboard.press("F1");
await setSlider("jump_buffer", 0.3);
await shot("5-overlay");
await page.keyboard.press("F5");
await page.waitForTimeout(300);
verdict("F5 reloads the registry from the server", (await slider("jump_buffer").inputValue()) === "0.1");
await setSlider("goal_flash_duration", 1);
await page.keyboard.press("F1");

// 6. room 2: time the blade, reach the goal, catch the flash
async function room2() {
  await page.keyboard.down("KeyD");
  for (;;) {
    const s = await state();
    if (s.st === "goal") return;
    const b = s.blade;
    const near = s.x + 2 * s.w >= s.gap && s.x < s.gap;
    const safe = b && ((b.dir < 0 && b.end < s.x - 10) || b.x > s.x + 140);
    if (s.room === 1 && near && s.st === "alive") {
      if (safe) {
        await page.keyboard.down("KeyD");
        await page.keyboard.down("Space");
        await sleep(250);
        await page.keyboard.up("Space");
      } else await page.keyboard.up("KeyD");
    }
    await sleep(POLL_MS);
  }
}
await room2();
await shot("4-goal-flash");
await page.keyboard.up("KeyD");
await page.waitForFunction(() => window.__sim.roomId === 0 && window.__sim.state === "alive", null, { timeout: 5000 });
verdict("goal flash then loop back to room 1", true);

// 7. corrupt save starts silently in room 0
await writeSave("{not json");
await page.reload({ waitUntil: "commit" });
await page.waitForFunction(() => typeof window.__gameReady === "number");
await dismissGate();
verdict("corrupt save starts in room id 0", (await state()).room === 0);

await browser.close();
console.log(FAILS.length ? `FAILED: ${FAILS.join(", ")}` : "m9: all checks ok");
process.exit(FAILS.length ? 1 : 0);
