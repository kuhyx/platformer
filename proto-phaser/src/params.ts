// Parameter registry accessor (spec/DOCS-parameters.md). The generated
// params.json is the only source; nothing in src/ holds a tunable literal.
// The bundled copy boots the game; F5 re-fetches the served copy (D14).
import bundled from "../params.json" with { type: "json" };

export interface Entry {
  value: number;
  min: number;
  max: number;
  step: number;
  unit: string;
  desc: string;
}

const FNV_OFFSET = 0x811c9dc5;
const FNV_PRIME = 0x01000193;
const HASH_RADIX = 16;
const HASH_WIDTH = 8;

const entries = new Map<string, Entry>();
let hash = "";

/** FNV-1a over the registry text: tags saves and snapshots (not a security hash). */
function fnv1a(text: string): string {
  let h = FNV_OFFSET;
  for (let i = 0; i < text.length; i++) {
    h = Math.imul(h ^ text.charCodeAt(i), FNV_PRIME) >>> 0;
  }
  return h.toString(HASH_RADIX).padStart(HASH_WIDTH, "0");
}

/** Replace the registry. Keys starting with `_` are metadata, skipped (contract). */
export function loadRegistry(raw: object, text: string = JSON.stringify(raw)): void {
  entries.clear();
  for (const [key, value] of Object.entries(raw)) {
    if (!key.startsWith("_")) {
      entries.set(key, { ...(value as Entry) });
    }
  }
  hash = fnv1a(text);
}

/** F5: pull the registry the server currently serves, not the bundled one. */
export async function reloadFromServer(url = "params.json"): Promise<void> {
  const text = await (await fetch(url, { cache: "no-store" })).text();
  loadRegistry(JSON.parse(text) as object, text);
}

export function entry(key: string): Entry {
  const found = entries.get(key);
  if (!found) {
    throw new Error(`unknown param: ${key}`);
  }
  return found;
}

export function param(key: string): number {
  return entry(key).value;
}

/** Live tweak from the debug overlay (M7). Clamped to the entry's bounds. */
export function setParam(key: string, value: number): void {
  const e = entry(key);
  e.value = Math.min(Math.max(value, e.min), e.max);
}

export function paramKeys(): string[] {
  return [...entries.keys()];
}

export function registryHash(): string {
  return hash;
}

loadRegistry(bundled);
