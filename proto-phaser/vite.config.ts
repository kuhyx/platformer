import { readFileSync } from "node:fs";
import { defineConfig, type Plugin } from "vite";

// The bundle embeds params.json for boot; F5 (debug) re-fetches a served copy,
// so the build emits it next to index.html. Dev serves it from the project root.
function serveParams(): Plugin {
  return {
    name: "serve-params",
    generateBundle() {
      this.emitFile({ type: "asset", fileName: "params.json", source: readFileSync("params.json", "utf8") });
    },
  };
}

// Phaser alone is ~1.3 MB minified; the real gate is tools/size_budget.py (gzip),
// so the 500 kB per-chunk hint is raised to the 1.5 MB budget instead of nagging.
const CHUNK_WARNING_KB = 1500;

// base "./" so the bundle works from any itch.io path.
export default defineConfig({
  base: "./",
  plugins: [serveParams()],
  build: { target: "es2022", sourcemap: false, reportCompressedSize: true, chunkSizeWarningLimit: CHUNK_WARNING_KB },
});
