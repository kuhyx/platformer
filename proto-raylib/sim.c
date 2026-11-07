// Pure sim: movement, collision, rooms, hazards, death, goal. Mirrors sim.gd.
#include "sim.h"
#include <math.h>
#include <string.h>

#define TICK (1.0 / SIM_TICK_HZ)

const char *const EVENT_NAMES[EV_KIND_COUNT] = {"room_enter", "checkpoint", "jump",
                                                "death",      "respawn",    "goal"};

static void emit(Sim *s, EventKind kind) {
    if (s->event_count < SIM_MAX_EVENTS) {
        s->events[s->event_count++] = (SimEvent){kind, s->room_id, s->x, s->y};
    }
}

// Strict overlap: touching edges do not intersect (Godot Rect2.intersects).
static bool overlaps(RoomRect a, RoomRect b) {
    return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

RoomRect sim_rect(const Sim *s) {
    return (RoomRect){s->x, s->y, PARAM(P_PLAYER_W), PARAM(P_PLAYER_H)};
}

RoomRect sim_blade_rect(const Sim *s) {
    RoomRect r = sim_room(s)->blade;
    r.x = s->blade_x;
    r.y = s->blade_y;
    return r;
}

bool sim_frozen(const Sim *s) {
    return s->phase == PHASE_DEAD && s->state_t < (double)PARAM(P_HITSTOP);
}

static void spawn(Sim *s) {
    const Room *room = sim_room(s);
    s->x = room->spawn_x;
    s->y = room->spawn_y;
    s->vx = s->vy = 0.0f;
    s->on_ground = false;
    s->coyote_left = s->buffer_left = 0.0;
    s->jump_cut_pending = false;
}

void sim_init(Sim *s, uint64_t seed) {
    memset(s, 0, sizeof *s);
    s->seed = seed;
    rng_seed(&s->rng, seed);
}

void sim_enter_room(Sim *s, int id, bool keep_motion) {
    s->room_id = id;
    const Room *room = sim_room(s);
    if (room->has_blade) {
        s->blade_x = room->blade.x;
        s->blade_y = room->blade.y;
        s->blade_dir = 1.0f;
    }
    if (!keep_motion) {
        spawn(s);
    }
    s->phase = PHASE_ALIVE;
    s->state_t = 0.0;
    emit(s, EV_ROOM_ENTER);
    emit(s, EV_CHECKPOINT);
}

// Axis-separated AABB sweep against the room's solids.
static void move(Sim *s) {
    const Room *room = sim_room(s);
    s->x += (float)((double)s->vx * TICK);
    for (int i = 0; i < room->solid_count; i++) {
        RoomRect w = room->solids[i];
        if (overlaps(sim_rect(s), w)) {
            s->x = s->vx > 0.0f ? w.x - PARAM(P_PLAYER_W) : w.x + w.w;
        }
    }
    s->y += (float)((double)s->vy * TICK);
    s->on_ground = false;
    for (int i = 0; i < room->solid_count; i++) {
        RoomRect w = room->solids[i];
        if (overlaps(sim_rect(s), w)) {
            if (s->vy > 0.0f) {
                s->y = w.y - PARAM(P_PLAYER_H);
                s->on_ground = true;
            } else {
                s->y = w.y + w.h;
            }
            s->vy = 0.0f;
        }
    }
}

// Hard cut to the neighbour (D16); clamp at the ends of the slice.
static void edges(Sim *s) {
    float w = PARAM(P_PLAYER_W);
    if (s->x < 0.0f) {
        if (s->room_id > 0) {
            sim_enter_room(s, s->room_id - 1, true);
            s->x = ROOMS_WIDTH - w;
        } else {
            s->x = 0.0f;
        }
    } else if (s->x + w > ROOMS_WIDTH) {
        if (s->room_id < ROOM_COUNT - 1) {
            sim_enter_room(s, s->room_id + 1, true);
            s->x = 0.0f;
        } else {
            s->x = ROOMS_WIDTH - w;
        }
    }
}

static void move_blade(Sim *s) {
    const Room *room = sim_room(s);
    if (!room->has_blade) {
        return;
    }
    s->blade_x += (float)((double)(s->blade_dir * PARAM(P_BLADE_SPEED)) * TICK);
    if (s->blade_x >= room->blade_track[1]) {
        s->blade_x = room->blade_track[1];
        s->blade_dir = -1.0f;
    } else if (s->blade_x <= room->blade_track[0]) {
        s->blade_x = room->blade_track[0];
        s->blade_dir = 1.0f;
    }
}

static void die(Sim *s) {
    s->phase = PHASE_DEAD;
    s->state_t = 0.0;
    emit(s, EV_DEATH);
}

static void touch(Sim *s) {
    const Room *room = sim_room(s);
    RoomRect me = sim_rect(s);
    for (int i = 0; i < room->hazard_count; i++) {
        if (overlaps(me, room->hazards[i])) {
            die(s);
            return;
        }
    }
    if (room->has_blade && overlaps(me, sim_blade_rect(s))) {
        die(s);
        return;
    }
    if (room->has_goal && overlaps(me, room->goal)) {
        s->phase = PHASE_GOAL;
        s->state_t = 0.0;
        emit(s, EV_GOAL);
    }
}

static void tick_alive(Sim *s, SimInput in) {
    s->vx = ((float)in.right - (float)in.left) * PARAM(P_MOVE_SPEED);
    bool pressed = in.jump && !s->prev_jump;
    s->buffer_left = pressed ? (double)PARAM(P_JUMP_BUFFER) : fmax(s->buffer_left - TICK, 0.0);
    s->coyote_left = s->on_ground ? (double)PARAM(P_COYOTE_TIME) : fmax(s->coyote_left - TICK, 0.0);
    // The press counts on its own tick: jump_buffer 0 means no buffering, not no jumping.
    if ((pressed || s->buffer_left > 0.0) && (s->on_ground || s->coyote_left > 0.0)) {
        s->vy = -PARAM(P_JUMP_VELOCITY);
        s->buffer_left = s->coyote_left = 0.0;
        s->on_ground = false;
        s->jump_cut_pending = true;
        emit(s, EV_JUMP);
    }
    if (s->jump_cut_pending && !in.jump) {
        if (s->vy < 0.0f) {
            s->vy *= PARAM(P_JUMP_CUT_MULTIPLIER);
        }
        s->jump_cut_pending = false;
    }
    if (s->vy >= 0.0f) {
        s->jump_cut_pending = false;
    }
    s->vy =
        fminf((float)((double)s->vy + (double)PARAM(P_GRAVITY) * TICK), PARAM(P_MAX_FALL_SPEED));
    move(s);
    edges(s);
    move_blade(s);
    touch(s);
}

void sim_tick(Sim *s, SimInput in) {
    s->event_count = 0;
    s->tick_count++;
    if (s->phase == PHASE_ALIVE) {
        tick_alive(s, in);
    } else if (s->phase == PHASE_DEAD) {
        s->state_t += TICK;
        if (s->state_t >= (double)PARAM(P_HITSTOP) + (double)PARAM(P_RESPAWN_DELAY)) {
            spawn(s);
            s->phase = PHASE_ALIVE;
            emit(s, EV_RESPAWN);
        }
    } else {
        s->state_t += TICK;
        if (s->state_t >= (double)PARAM(P_GOAL_FLASH_DURATION)) {
            sim_enter_room(s, 0, false);
        }
    }
    s->prev_jump = in.jump;
}
