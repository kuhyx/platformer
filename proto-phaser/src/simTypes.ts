// Shared sim vocabulary: tick constants, states, input and event shapes.
export const TICK_HZ = 60; // D12 non-tunable
export const TICK = 1 / TICK_HZ;

export const State = { ALIVE: "alive", DEAD: "dead", GOAL: "goal" } as const;
export type StateId = (typeof State)[keyof typeof State];

export interface Input {
  left: boolean;
  right: boolean;
  jump: boolean;
}

export interface SimEvent {
  e: string;
  room?: number;
  x?: number;
  y?: number;
}
