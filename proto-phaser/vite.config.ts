import { defineConfig } from "vite";

// base "./" so the bundle works from any itch.io path.
export default defineConfig({
  base: "./",
  build: { target: "es2022", sourcemap: false, reportCompressedSize: true },
});
