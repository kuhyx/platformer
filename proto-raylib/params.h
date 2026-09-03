// GENERATED FILE - edit shared/params/params.json and run `make gen-params`
#ifndef PARAMS_H
#define PARAMS_H

typedef struct { const char *key; float value, min, max, step; } Param;

enum {
    P_MOVE_SPEED,
    P_GRAVITY,
    P_MAX_FALL_SPEED,
    P_JUMP_VELOCITY,
    P_JUMP_CUT_MULTIPLIER,
    P_COYOTE_TIME,
    P_JUMP_BUFFER,
    P_PLAYER_W,
    P_PLAYER_H,
    P_BLADE_SPEED,
    P_RESPAWN_DELAY,
    P_HITSTOP,
    P_SHAKE_AMPLITUDE,
    P_SHAKE_DURATION,
    P_DEATH_PARTICLES,
    P_STATE_LOG_EVERY,
    P_COUNT
};

static Param PARAMS[] = {
    {"move_speed", 160.0f, 40.0f, 400.0f, 5.0f},
    {"gravity", 1400.0f, 400.0f, 4000.0f, 50.0f},
    {"max_fall_speed", 900.0f, 200.0f, 2000.0f, 25.0f},
    {"jump_velocity", 420.0f, 100.0f, 1000.0f, 10.0f},
    {"jump_cut_multiplier", 0.4f, 0.0f, 1.0f, 0.05f},
    {"coyote_time", 0.08f, 0.0f, 0.3f, 0.01f},
    {"jump_buffer", 0.1f, 0.0f, 0.3f, 0.01f},
    {"player_w", 12.0f, 4.0f, 64.0f, 1.0f},
    {"player_h", 16.0f, 4.0f, 64.0f, 1.0f},
    {"blade_speed", 120.0f, 0.0f, 600.0f, 10.0f},
    {"respawn_delay", 0.25f, 0.0f, 2.0f, 0.05f},
    {"hitstop", 0.06f, 0.0f, 0.5f, 0.01f},
    {"shake_amplitude", 3.0f, 0.0f, 20.0f, 1.0f},
    {"shake_duration", 0.15f, 0.0f, 1.0f, 0.05f},
    {"death_particles", 24.0f, 0.0f, 200.0f, 4.0f},
    {"state_log_every", 10.0f, 1.0f, 600.0f, 1.0f},
};

#define PARAM(k) (PARAMS[(k)].value)

#endif
