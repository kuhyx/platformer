// Debug overlay (F1): one slider per registry entry, generated from the
// registry (D14, never hand-built), plus room id and fps. Only created in a
// debug build (dev server or `?debug`), which is how its labels coexist with D04.
import { entry, paramKeys, setParam } from "./params.ts";

const PANEL_STYLE =
  "position:fixed;left:0;top:0;bottom:0;width:50%;overflow:auto;box-sizing:border-box;" +
  "background:rgba(0,0,0,0.75);color:#fff;font:12px monospace;padding:4px;display:none;z-index:10";
const ROW_STYLE = "display:flex;align-items:center;gap:6px";
const NAME_STYLE = "flex:1";
const SLIDER_STYLE = "flex:1";
const VALUE_STYLE = "width:48px;text-align:right";

export class Overlay {
  visible = false;
  private readonly panel = document.createElement("div");
  private readonly status = document.createElement("div");
  private readonly sliders = new Map<string, HTMLInputElement>();
  private readonly values = new Map<string, HTMLSpanElement>();

  constructor(parent: HTMLElement) {
    this.panel.setAttribute("style", PANEL_STYLE);
    this.panel.append(this.status);
    for (const key of paramKeys()) {
      this.panel.append(this.row(key));
    }
    parent.append(this.panel);
  }

  toggle(): void {
    this.visible = !this.visible;
    this.panel.style.display = this.visible ? "block" : "none";
  }

  /** After F5 reloads the registry the sliders follow the file, not the other way. */
  refresh(): void {
    for (const [key, slider] of this.sliders) {
      slider.value = String(entry(key).value);
      this.showValue(key);
    }
  }

  /** Room id, then fps, as bare numbers (word labels need a textgate ledger key). */
  setStatus(roomId: number, fps: number): void {
    this.status.textContent = `${String(roomId)} | ${String(Math.trunc(fps))}`;
  }

  private row(key: string): HTMLDivElement {
    const e = entry(key);
    const row = document.createElement("div");
    row.setAttribute("style", ROW_STYLE);
    const name = document.createElement("span");
    name.setAttribute("style", NAME_STYLE);
    name.textContent = `${key} (${e.unit})`;
    name.title = e.desc;
    const slider = document.createElement("input");
    slider.type = "range";
    slider.setAttribute("style", SLIDER_STYLE);
    slider.min = String(e.min);
    slider.max = String(e.max);
    slider.step = String(e.step);
    slider.value = String(e.value);
    slider.addEventListener("input", () => {
      setParam(key, Number(slider.value));
      this.showValue(key);
    });
    slider.addEventListener("change", () => {
      slider.blur();
    });
    const value = document.createElement("span");
    value.setAttribute("style", VALUE_STYLE);
    this.sliders.set(key, slider);
    this.values.set(key, value);
    this.showValue(key);
    row.append(name, slider, value);
    return row;
  }

  private showValue(key: string): void {
    const label = this.values.get(key);
    if (label) {
      label.textContent = String(entry(key).value);
    }
  }
}
