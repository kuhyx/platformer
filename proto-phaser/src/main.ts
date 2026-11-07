// Entry point: resolve the saved room (IndexedDB), then hand a Boot record to
// the thin Phaser scene. WebGL missing -> the static crossed-out-monitor icon
// from index.html and nothing else (D19).
import Phaser from "phaser";
import roomsJson from "../rooms.json" with { type: "json" };
import { BACKGROUND, HEIGHT, Slice, WIDTH, type Boot } from "./game.ts";
import { parseRooms } from "./rooms.ts";
import { readRoom, readSnapshot } from "./save.ts";
import type { Snapshot } from "./simState.ts";

const MS_PER_S = 1000;

function webglAvailable(): boolean {
  return document.createElement("canvas").getContext("webgl2") !== null;
}

async function boot(): Promise<void> {
  if (!webglAvailable()) {
    document.getElementById("fail")?.style.setProperty("display", "block");
    return;
  }
  const query = new URLSearchParams(location.search);
  const debug = import.meta.env.DEV || query.has("debug");
  const rooms = parseRooms(roomsJson);
  const startRoom = await readRoom(rooms.rooms.length);
  const snap = debug && query.has("restore") ? ((await readSnapshot()) as Snapshot | null) : null;
  const seed = Number(query.get("seed") ?? Math.trunc(Date.now() / MS_PER_S));
  const config: Boot = { rooms, startRoom, seed, debug, snap };
  new Phaser.Game({
    type: Phaser.WEBGL,
    width: WIDTH,
    height: HEIGHT,
    parent: "game",
    backgroundColor: BACKGROUND,
    scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
    scene: new Slice(config),
  });
}

void boot();
