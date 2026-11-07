// Browser e2e: gate, held keys to room 2, save resume across reload, corrupt save.
// Usage: node e2e_web.mjs <url> [outdir]   (headless, muted, software GL)
import { chromium } from "../tools/node_modules/playwright/index.mjs";
import { mkdirSync } from "node:fs";

const [url, outdir = "/tmp/proto-raylib-web"] = process.argv.slice(2);
mkdirSync(outdir, { recursive: true });
const PLAYER_W = 12;
const JUMP_HOLD_MS = 150;
const CLEAR_X = [390, 560]; // pit and ledge edges in room 1 (rooms.h)
let failures = 0;

const check = (ok, what) => {
  console.log(`${ok ? "ok  " : "FAIL"} ${what}`);
  failures += ok ? 0 : 1;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const state = (page) => page.evaluate(() => window.__game);

async function open(browser) {
  const page = await browser.newPage({ viewport: { width: 854, height: 480 } });
  page.on("pageerror", (e) => console.log("pageerror", e.message));
  await page.goto(url);
  await page.waitForFunction(() => typeof window.__gameReady === "number", null, { timeout: 30000 });
  return page;
}

async function dismissGate(page) {
  await sleep(300);
  await page.mouse.move(400, 240);
  await page.mouse.down();
  await sleep(150);
  await page.mouse.up();
  await page.waitForFunction(() => window.__game && window.__game.gate === 0, null, { timeout: 5000 });
}

async function holdToRoom2(page) {
  await page.keyboard.down("KeyD");
  const jumped = new Set();
  for (let i = 0; i < 1200; i++) {
    const s = await state(page);
    if (s.room === 1) break;
    for (const edge of CLEAR_X) {
      if (!jumped.has(edge) && s.x + 2 * PLAYER_W >= edge && s.x < edge) {
        jumped.add(edge);
        await page.keyboard.down("Space");
        await sleep(JUMP_HOLD_MS);
        await page.keyboard.up("Space");
      }
    }
    await sleep(10);
  }
  await page.keyboard.up("KeyD");
}

const browser = await chromium.launch({
  args: ["--mute-audio", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
let page = await open(browser);
check(typeof (await page.evaluate(() => window.__gameReady)) === "number", "window.__gameReady is a number");
await sleep(500);
await page.screenshot({ path: `${outdir}/gate.png` });
check((await state(page)).gate === 1, "start gate is up before any input");
await dismissGate(page);
await holdToRoom2(page);
const inRoom2 = (await state(page)).room === 1;
check(inRoom2, "held D (+ timed jumps) reaches room 2 (room id 1)");
await sleep(600);
await page.screenshot({ path: `${outdir}/room2.png` });

await page.reload();
await page.waitForFunction(() => typeof window.__gameReady === "number", null, { timeout: 30000 });
await dismissGate(page);
check((await state(page)).room === 1, "reload resumes in room id 1 (IndexedDB)");
await page.screenshot({ path: `${outdir}/resumed.png` });

await page.evaluate(
  () =>
    new Promise((resolve, reject) => {
      const open = indexedDB.open("/save");
      open.onerror = () => reject(open.error);
      open.onsuccess = () => {
        const tx = open.result.transaction("FILE_DATA", "readwrite");
        const entry = { timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode("\x01garbage{{{") };
        tx.objectStore("FILE_DATA").put(entry, "/save/save.json");
        tx.oncomplete = resolve;
      };
    }),
);
await page.reload();
await page.waitForFunction(() => typeof window.__gameReady === "number", null, { timeout: 30000 });
await dismissGate(page);
check((await state(page)).room === 0, "corrupt IndexedDB save starts silently in room id 0");
await browser.close();
console.log(`e2e_web: ${failures} failure(s), screenshots in ${outdir}`);
process.exit(failures > 0 ? 1 : 0);
