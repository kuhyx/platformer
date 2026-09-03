// Time-to-first-playable-frame for a web build (spec/tech-reqs.md, D10).
// Usage: node tools/measure_load.mjs <url> [runs=5]
// Requires: npm i -D playwright && npx playwright install chromium
// Run 1 is uncached; runs 2..n share the HTTP cache. Pass = cached median < 2000 ms.
import { chromium } from "playwright";

const READY_TIMEOUT_MS = 60_000;
const PASS_MS = 2000;
const DEFAULT_RUNS = 5;

const [url, runsArg] = process.argv.slice(2);
if (!url) {
  console.error("usage: node tools/measure_load.mjs <url> [runs]");
  process.exit(2);
}
const runs = Number(runsArg ?? DEFAULT_RUNS);

const median = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : Math.round((s[mid - 1] + s[mid]) / 2);
};

const browser = await chromium.launch();
const context = await browser.newContext();
const results = [];
for (let i = 0; i < runs; i++) {
  const page = await context.newPage();
  await page.goto(url, { waitUntil: "commit" });
  await page.waitForFunction(() => typeof window.__gameReady === "number", null, {
    timeout: READY_TIMEOUT_MS,
  });
  results.push(Math.round(await page.evaluate(() => window.__gameReady)));
  await page.close();
}
await browser.close();

const [uncached_ms, ...cached] = results;
const cached_median_ms = cached.length ? median(cached) : null;
console.log(JSON.stringify({
  url, runs, uncached_ms, cached_ms: cached, cached_median_ms,
  pass: cached_median_ms !== null && cached_median_ms < PASS_MS,
}));
