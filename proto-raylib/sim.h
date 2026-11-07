// The slice's pure fixed-step simulation (D12), a C port of proto-godot/sim.gd.
// No raylib include: a plain C test binary drives it (M10). Every number
// comes from the registry or the generated rooms table.
#ifndef SIM_H
#define SIM_H

#include "prm.h"
#include "rooms.h"
#include <stdbool.h>
#include <stdint.h>

#define SIM_TICK_HZ 60 // D12, non-tunable
#define SIM_MAX_EVENTS 8

typedef enum { PHASE_ALIVE, PHASE_DEAD, PHASE_GOAL } SimPhase;

typedef enum {
    EV_ROOM_ENTER,
    EV_CHECKPOINT,
    EV_JUMP,
    EV_DEATH,
    EV_RESPAWN,
    EV_GOAL,
    EV_KIND_COUNT
} EventKind;

typedef struct {
    EventKind kind;
    int room;
    float x, y; // death position
} SimEvent;

typedef struct {
    bool left, right, jump;
} SimInput;

typedef struct {
    uint64_t state, inc;
} Rng; // PCG32, the generator family Godot's RandomNumberGenerator uses

typedef struct {
    Rng rng;
    uint64_t seed;
    int tick_count;
    int room_id;
    float x, y;   // avatar top-left
    float vx, vy; // px/s
    bool on_ground;
    double coyote_left, buffer_left;
    bool jump_cut_pending;
    bool prev_jump;
    SimPhase phase;
    double state_t; // seconds spent in DEAD / GOAL
    float blade_x, blade_y;
    float blade_dir;
    SimEvent events[SIM_MAX_EVENTS]; // emitted during the last tick
    int event_count;
} Sim;

extern const char *const EVENT_NAMES[EV_KIND_COUNT];

void rng_seed(Rng *r, uint64_t seed);
uint32_t rng_u32(Rng *r);
float rng_range(Rng *r, float lo, float hi);

void sim_init(Sim *s, uint64_t seed);
void sim_enter_room(Sim *s, int id, bool keep_motion);
void sim_tick(Sim *s, SimInput in);
bool sim_frozen(const Sim *s); // hitstop: the whole world holds still
RoomRect sim_rect(const Sim *s);
RoomRect sim_blade_rect(const Sim *s);

// Winnability proof at the current registry values (a layout that fails is a
// bug, not a tuning job). Returns true when ok; otherwise fills `err`.
bool sim_check_winnable(char *err, int err_size);

static inline const Room *sim_room(const Sim *s) {
    return &ROOMS[s->room_id];
}

#endif
