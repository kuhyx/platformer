// node:test registers asynchronously; this wrapper keeps call sites clean.
import { test } from "node:test";

export function check(name: string, body: () => Promise<void> | void): void {
  void test(name, body);
}
