// Browser e2e for the love.js build: start gate, held D to room 2, save
// resume across reload (IDBFS), corrupt save -> room 0.
// Usage: node e2e_web.mjs <url> [outdir]   (headless, muted, software GL)
// window.__game is fed by main.lua's stdout markers (see web/index.html).
// Waits are on that state (air, room, IDB contents), never on fixed sleeps:
// the sim is wall-clock driven but clamped, so it slows down under load.
import { chromium } from "../tools/node_modules/playwright/index.mjs";
import { mkdirSync } from "node:fs";

const [url, outdir = "/tmp/proto-love-web"] = process.argv.slice(2);
mkdirSync(outdir, { recursive: true });
const IDB_NAME = "/home/web_user/love"; // love.js IDBFS mount point
const SAVE_KEY = `${IDB_NAME}/proto-love/save.txt`; // conf.lua t.identity
const STATE_MS = 8000; // per game-state wait; sim runs slow-mo under CPU load
// Grounded run-up between hops. The sim is deterministic, so a fixed gap would
// repeat one phase and could land in the pit every time: vary it (golden
// ratio steps) so hops sweep through every take-off phase.
const gapMs = (i) => 50 + 400 * ((i * 0.618034) % 1);
const ROOM2_MS = 30000; // whole run to room 2
let failures = 0;

const check = (ok, what) => {
  console.log(`${ok ? "ok  " : "FAIL"} ${what}`);
  failures += ok ? 0 : 1;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const game = (page) => page.evaluate(() => ({ ...window.__game }));

async function ready(page) {
  await page.waitForFunction(() => typeof window.__gameReady === "number", null, { timeout: 30000 });
}

async function dismissGate(page) {
  await page.mouse.click(427, 240);
  await until(page, () => window.__game.gate === 0);
}

const until = (page, fn, arg, timeout = STATE_MS) => page.waitForFunction(fn, arg, { timeout });

// Space held from takeoff to landing = a full-height hop (no jump cut), so it
// clears the 40 px ledge however slowly the sim advances.
async function hopToRoom2(page) {
  await page.keyboard.down("KeyD");
  const deadline = Date.now() + ROOM2_MS;
  for (let i = 0; Date.now() < deadline && (await game(page)).room !== 1; i++) {
    await page.keyboard.down("Space");
    await until(page, () => window.__game.air === 1 || window.__game.room === 1).catch(() => {});
    await until(page, () => window.__game.air === 0 || window.__game.room === 1).catch(() => {});
    await page.keyboard.up("Space");
    await sleep(gapMs(i));
  }
  await page.keyboard.up("KeyD");
}

// Reads (or overwrites) the save file straight from love.js's IndexedDB.
function idb(page, contents) {
  return page.evaluate(
    ([name, key, text]) =>
      new Promise((resolve, reject) => {
        const req = indexedDB.open(name);
        req.onerror = () => reject(req.error);
        req.onsuccess = () => {
          const tx = req.result.transaction("FILE_DATA", "readwrite");
          const store = tx.objectStore("FILE_DATA");
          let out = null;
          if (text === null) {
            const get = store.get(key);
            get.onsuccess = () => {
              out = get.result ? new TextDecoder().decode(get.result.contents) : null;
            };
          } else {
            store.put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(text) }, key);
          }
          tx.oncomplete = () => resolve(out);
        };
      }),
    [IDB_NAME, SAVE_KEY, contents],
  );
}

const browser = await chromium.launch({
  args: ["--mute-audio", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width: 854, height: 480 } });
page.on("pageerror", (e) => console.log("pageerror", e.message));
await page.goto(url);
await ready(page);
check(typeof (await page.evaluate(() => window.__gameReady)) === "number", "window.__gameReady is a number");
await page.screenshot({ path: `${outdir}/gate.png` });
check((await game(page)).gate === 1, "start gate is up before any input");
await dismissGate(page);
await hopToRoom2(page);
check((await game(page)).room === 1, "held D (+ hops) reaches room 2 (room id 1)");
await page.screenshot({ path: `${outdir}/room2.png` });

// love.js flushes its IDBFS mount only from a beforeunload handler, and an
// IndexedDB write started while the page unloads can be lost. Fire that
// handler by hand and wait for the save to land before reloading.
await page.evaluate(() => window.dispatchEvent(new Event("beforeunload")));
for (let i = 0; i < 80 && !(await idb(page, null))?.startsWith("room_id=1"); i++) await sleep(100);
await page.reload();
await ready(page);
console.log(`saved file after reload: ${JSON.stringify(await idb(page, null))}`);
await dismissGate(page);
check((await game(page)).room === 1, "reload resumes in room id 1 (IDBFS)");
await page.screenshot({ path: `${outdir}/resumed.png` });

// Corrupt it from a game-free page on the same origin, so love.js's
// beforeunload sync cannot write the in-memory save back over it.
await page.goto(new URL("e2e-blank", url).href);
await idb(page, "\x01garbage{{{");
await page.goto(url);
await ready(page);
await dismissGate(page);
check((await game(page)).room === 0, "corrupt IDBFS save starts silently in room id 0");
await browser.close();
console.log(`e2e_web: ${failures} failure(s), screenshots in ${outdir}`);
process.exit(failures > 0 ? 1 : 0);
