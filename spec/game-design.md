# Game design principles (binding)

Source: owner's brief, 2026-09-02, amended by `decisions.md`.

## 1. Constant gameplay, player always in control
- No cutscenes, no loading screens, no menus, no settings (D05).
- Playable the instant the window exists. Only exceptions: voluntary
  pause; the single web start gate (D02).
- The game saves itself. Saves are invisible and never need a player
  action (D03).

## 2. Minimalism
- Add as few elements as possible; each new element gets the smallest
  value that works.
- Player has one hit point. Enemies have one hit point.
- No HUD. All state is readable from the world and the avatar.
- One difficulty.

## 3. No text in the runtime (D04)
Graphics, icons, audio and the world communicate everything.

## 4. No cheap mechanics
No QTEs. No jumpscares.

## 5. Gameplay stands alone
The slice must be fun with no audio, rectangle art and no story. Audio
and art are multipliers, never load-bearing.

## 6. Satisfying and addictive through craft (D06)
- Juice: hitstop, screen shake, particles, squash/stretch, snappy audio,
  tight input (coyote time, jump buffer).
- Mastery: readable challenges, instant retry, short loops.
- Forbidden: reward currencies, unlocks-as-bait, streaks, absence
  penalties, variable-ratio schedules.

## 7. Progress is never lost (D03)
Checkpoint per room, autosave on entry. Death costs at most the current
room.

## Adding anything
A new element needs a line in this file, an entry in `decisions.md`, and
every tunable it introduces registered in `shared/params/params.json`.
