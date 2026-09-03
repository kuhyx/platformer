// Parameter registry accessor (spec/parameters.md). Generated params.json
// is the only source; nothing in src/ holds a tunable literal.
import registry from "../params.json";

interface Entry {
  value: number;
  min: number;
  max: number;
  step: number;
}

const entries = registry as unknown as Record<string, Entry | string>;

export function param(key: string): number {
  const entry = entries[key];
  if (typeof entry !== "object") {
    throw new Error(`unknown param: ${key}`);
  }
  return entry.value;
}

export function paramKeys(): string[] {
  return Object.keys(entries).filter((k) => !k.startsWith("_"));
}
