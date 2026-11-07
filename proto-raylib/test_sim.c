// Headless slice check (M10): drives Sim with scripted input, no window.
// Mirrors proto-godot/tests/test_sim.gd; exit code 0 = every check passed.
#include "test.h"
#include <stdio.h>
#include <string.h>

static const SimInput IDLE = {false, false, false};
static const SimInput RIGHT = {false, true, false};
static const SimInput RIGHT_JUMP = {false, true, true};
static const SimInput JUMP = {false, false, true};

int failures = 0;

void expect(bool cond, const char *what) {
    if (!cond) {
        failures++;
    }
    printf("%s %s\n", cond ? "ok  " : "FAIL", what);
}

static void fresh(Sim *s, int room) {
    sim_init(s, TEST_SEED);
    sim_enter_room(s, room, false);
}

// Runs `ticks` steps; returns true when `kind` was emitted at least once.
static bool run(Sim *s, int ticks, SimInput in, EventKind kind) {
    bool seen = false;
    for (int i = 0; i < ticks; i++) {
        sim_tick(s, in);
        for (int e = 0; e < s->event_count; e++) {
            seen = seen || s->events[e].kind == kind;
        }
    }
    return seen;
}

static void check_landing(void) {
    Sim s;
    fresh(&s, 0);
    run(&s, SECONDS, IDLE, EV_JUMP);
    expect(s.on_ground && s.y == ROOMS[0].solids[0].y - PARAM(P_PLAYER_H),
           "idle avatar rests on the floor");
}

static void check_pit_kills(void) {
    Sim s;
    fresh(&s, 0);
    bool died = run(&s, 5 * SECONDS, RIGHT, EV_DEATH);
    expect(died, "walking into room 1's spike pit kills");
    fresh(&s, 0);
    bool respawned = run(&s, 5 * SECONDS, RIGHT, EV_RESPAWN);
    expect(respawned && s.room_id == 0, "respawn returns to room 1's checkpoint");
}

// Hold right, jump when the pit or the ledge is next. Ends in room 2.
static bool run_room_1(Sim *s) {
    float pit_x = ROOMS[0].gaps[0][0];
    float ledge_x = ROOMS[0].solids[2].x;
    float w = PARAM(P_PLAYER_W);
    bool died = false;
    for (int i = 0; i < 8 * SECONDS && s->room_id == 0; i++) {
        bool near_pit = s->x + w >= pit_x - w && s->x < pit_x;
        bool near_ledge = s->x + w >= ledge_x - w && s->x < ledge_x;
        sim_tick(s, near_pit || near_ledge ? RIGHT_JUMP : RIGHT);
        for (int e = 0; e < s->event_count; e++) {
            died = died || s->events[e].kind == EV_DEATH;
        }
    }
    return !died;
}

static void check_run_reaches_room_2(void) {
    Sim s;
    fresh(&s, 0);
    bool clean = run_room_1(&s);
    expect(clean && s.room_id == 1, "jumping the pit and the ledge reaches room 2");
    expect(s.event_count >= 2 && s.events[1].kind == EV_CHECKPOINT && s.events[1].room == 1,
           "entering room 2 raises a checkpoint (autosave)");
}

static void check_room_2_hazards(void) {
    Sim s;
    fresh(&s, 1);
    bool died = run(&s, 5 * SECONDS, RIGHT, EV_DEATH);
    expect(died && s.room_id == 1, "room 2's gap or blade kills; respawn stays in room 2");
    fresh(&s, 1);
    float start_x = s.blade_x;
    run(&s, SECONDS, IDLE, EV_JUMP);
    bool moved = s.blade_x != start_x;
    bool within = s.blade_x >= ROOMS[1].blade_track[0] && s.blade_x <= ROOMS[1].blade_track[1];
    expect(moved && within, "blade patrols inside its track");
}

static void check_goal_loops(void) {
    Sim s;
    fresh(&s, 1);
    s.x = ROOMS[1].goal.x - PARAM(P_PLAYER_W) - 1.0f;
    s.y = ROOMS[1].goal.y;
    bool goal = run(&s, 2 * SECONDS, RIGHT, EV_GOAL);
    expect(goal, "touching the goal pillar fires goal");
    expect(s.room_id == 0 && s.phase == PHASE_ALIVE, "after the flash the loop restarts in room 1");
}

// Walk off the ledge, then press jump a few ticks later.
static bool late_jump_after_ledge(float coyote) {
    float saved = PARAM(P_COYOTE_TIME);
    PARAM(P_COYOTE_TIME) = coyote;
    Sim s;
    fresh(&s, 0);
    RoomRect ledge = ROOMS[0].solids[2];
    float w = PARAM(P_PLAYER_W);
    s.x = ledge.x + ledge.w - w - 1.0f;
    s.y = ledge.y - PARAM(P_PLAYER_H);
    run(&s, 2, IDLE, EV_JUMP);
    s.x = ROOMS_WIDTH - w;
    run(&s, 1, IDLE, EV_JUMP);
    s.x = ledge.x + ledge.w;
    run(&s, 2, IDLE, EV_JUMP);
    bool jumped = run(&s, 1, JUMP, EV_JUMP);
    PARAM(P_COYOTE_TIME) = saved;
    return jumped;
}

static void check_coyote(void) {
    expect(!late_jump_after_ledge(0.0f), "coyote_time 0: no jump after leaving the ledge");
    expect(late_jump_after_ledge(PARAMS[P_COYOTE_TIME].value),
           "coyote_time default: jump still fires shortly after");
}

// Tap jump while falling, a few ticks before landing.
static bool early_jump_before_landing(float buffer) {
    float saved = PARAM(P_JUMP_BUFFER);
    PARAM(P_JUMP_BUFFER) = buffer;
    Sim s;
    fresh(&s, 0);
    s.y -= 2.0f * PARAM(P_PLAYER_H);
    run(&s, 9, IDLE, EV_JUMP);
    run(&s, 1, JUMP, EV_JUMP);
    bool jumped = run(&s, SECONDS, IDLE, EV_JUMP);
    PARAM(P_JUMP_BUFFER) = saved;
    return jumped;
}

static void check_buffer(void) {
    expect(!early_jump_before_landing(0.0f), "jump_buffer 0: early tap is lost");
    expect(early_jump_before_landing(PARAMS[P_JUMP_BUFFER].value),
           "jump_buffer default: early tap fires on landing");
    float coyote = PARAM(P_COYOTE_TIME), buffer = PARAM(P_JUMP_BUFFER);
    PARAM(P_COYOTE_TIME) = PARAM(P_JUMP_BUFFER) = 0.0f;
    Sim s;
    fresh(&s, 0);
    run(&s, 2, IDLE, EV_JUMP);
    expect(run(&s, 1, JUMP, EV_JUMP), "coyote_time and jump_buffer 0: ground press still jumps");
    PARAM(P_COYOTE_TIME) = coyote;
    PARAM(P_JUMP_BUFFER) = buffer;
}

static void check_determinism(void) {
    Sim a, b;
    fresh(&a, 0);
    fresh(&b, 0);
    run_room_1(&a);
    run_room_1(&b);
    run(&a, SECONDS, RIGHT, EV_JUMP);
    run(&b, SECONDS, RIGHT, EV_JUMP);
    expect(memcmp(&a, &b, sizeof a) == 0, "same seed + inputs: identical state (D12)");
}

static void check_winnable(void) {
    char err[128];
    expect(sim_check_winnable(err, sizeof err), "shipped layout is winnable at shipped values");
    float saved = PARAM(P_MOVE_SPEED);
    PARAM(P_MOVE_SPEED) = PARAMS[P_MOVE_SPEED].min;
    expect(!sim_check_winnable(err, sizeof err), "slowest move_speed makes the pit unclearable");
    PARAM(P_MOVE_SPEED) = saved;
}

static void check_reload(void) {
    PARAM(P_GRAVITY) = 1.0f;
    PARAM(P_COYOTE_TIME) = 0.3f;
    int n = prm_reload("../shared/params/params.json");
    expect(n == P_COUNT, "F5 reload reads every registry entry from disk");
    expect(PARAM(P_GRAVITY) == 1400.0f && PARAM(P_COYOTE_TIME) == 0.08f,
           "F5 reload restores edited values");
    expect(prm_reload("/nonexistent/params.json") == -1, "F5 reload of a missing file is a no-op");
}

int main(int argc, char **argv) {
    const char *trace = argc > 1 ? argv[1] : "../shared/replay/slice_trace.json";
    check_landing();
    check_pit_kills();
    check_run_reaches_room_2();
    check_room_2_hazards();
    check_goal_loops();
    check_coyote();
    check_buffer();
    check_determinism();
    check_winnable();
    check_reload();
    run_replay_checks(trace);
    run_save_checks();
    printf("test_sim: %d failure(s)\n", failures);
    return failures > 0 ? 1 : 0;
}
