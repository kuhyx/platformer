// Boot stub: opens the canvas, draws the avatar placeholder, signals web
// readiness. The slice (spec/DOCS-slice.md) is not implemented yet.
import Phaser from "phaser";
import { param } from "./params";

declare global {
  interface Window {
    __gameReady?: number;
  }
}

const WIDTH = 854; // D13
const HEIGHT = 480; // D13
const BACKGROUND = "#1a1a1f";
const PLAYER_COLOR = 0xffffff;
const PLACEHOLDER_SPAWN_X = 100; // slice will read spawn from room data
const PLACEHOLDER_SPAWN_Y = 400;

class Boot extends Phaser.Scene {
  create(): void {
    this.add
      .rectangle(PLACEHOLDER_SPAWN_X, PLACEHOLDER_SPAWN_Y, param("player_w"), param("player_h"), PLAYER_COLOR)
      .setOrigin(0);
    this.game.events.once(Phaser.Core.Events.POST_RENDER, () => {
      window.__gameReady = performance.now();
    });
  }
}

new Phaser.Game({
  type: Phaser.WEBGL,
  width: WIDTH,
  height: HEIGHT,
  parent: "game",
  backgroundColor: BACKGROUND,
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: [Boot],
});
