// Invisible autosave (D03): room id + registry hash as one JSON string in
// IndexedDB (never localStorage, tech-reqs). A transaction commits whole or
// not at all, which is the atomic write the native builds get from temp +
// rename. Missing, corrupt or unavailable store -> room 0, silently (D19).
import { registryHash } from "./params.ts";

const DB_NAME = "proto-phaser";
const STORE = "kv";
const SAVE_KEY = "save";
const SNAPSHOT_KEY = "snapshot";
const DB_VERSION = 1;

/** The saved room id when it is a valid index, else 0. */
export function parseSave(raw: unknown, roomCount: number): number {
  if (typeof raw !== "string") {
    return 0;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return 0;
  }
  const id = (parsed as { room_id?: unknown } | null)?.room_id;
  return typeof id === "number" && Number.isInteger(id) && id >= 0 && id < roomCount ? id : 0;
}

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (): void => {
      req.result.createObjectStore(STORE);
    };
    req.onsuccess = (): void => {
      resolve(req.result);
    };
    req.onerror = (): void => {
      reject(req.error ?? new Error("indexedDB open failed"));
    };
  });
}

async function put(key: string, value: string): Promise<void> {
  const db = await open();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).put(value, key);
    tx.oncomplete = (): void => {
      resolve();
    };
    tx.onerror = (): void => {
      reject(tx.error ?? new Error("indexedDB write failed"));
    };
  });
  db.close();
}

async function get(key: string): Promise<unknown> {
  const db = await open();
  const value = await new Promise<unknown>((resolve, reject) => {
    const req = db.transaction(STORE, "readonly").objectStore(STORE).get(key);
    req.onsuccess = (): void => {
      resolve(req.result);
    };
    req.onerror = (): void => {
      reject(req.error ?? new Error("indexedDB read failed"));
    };
  });
  db.close();
  return value;
}

export async function writeRoom(roomId: number): Promise<void> {
  try {
    await put(SAVE_KEY, JSON.stringify({ room_id: roomId, params_hash: registryHash() }));
  } catch (err) {
    console.warn("save: write failed", err);
  }
}

export async function readRoom(roomCount: number): Promise<number> {
  try {
    return parseSave(await get(SAVE_KEY), roomCount);
  } catch {
    return 0;
  }
}

/** F6 dump target; `?restore` loads it back at boot. */
export async function writeSnapshot(text: string): Promise<void> {
  try {
    await put(SNAPSHOT_KEY, text);
  } catch (err) {
    console.warn("snapshot: write failed", err);
  }
}

export async function readSnapshot(): Promise<unknown> {
  try {
    const raw = await get(SNAPSHOT_KEY);
    return typeof raw === "string" ? (JSON.parse(raw) as unknown) : null;
  } catch {
    return null;
  }
}
