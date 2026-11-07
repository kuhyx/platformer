// Proof that the shipped layout can be won at the current registry values.
#include "sim.h"
#include <math.h>
#include <stdio.h>

// Highest solid top minus this solid's top: the step-up the avatar must clear.
static float step_height(const Room *room, RoomRect solid) {
    float floor_top = 0.0f;
    for (int i = 0; i < room->solid_count; i++) {
        floor_top = fmaxf(floor_top, room->solids[i].y);
    }
    return floor_top - solid.y;
}

bool sim_check_winnable(char *err, int err_size) {
    float v = PARAM(P_JUMP_VELOCITY);
    float reach = PARAM(P_MOVE_SPEED) * 2.0f * v / PARAM(P_GRAVITY);
    float apex = v * v / (2.0f * PARAM(P_GRAVITY));
    for (int id = 0; id < ROOM_COUNT; id++) {
        for (int g = 0; g < ROOMS[id].gap_count; g++) {
            float span = ROOMS[id].gaps[g][1] - ROOMS[id].gaps[g][0] + PARAM(P_PLAYER_W);
            if (span >= reach) {
                snprintf(err, (size_t)err_size, "room %d: gap needs %.0f px, reach is %.0f", id,
                         (double)span, (double)reach);
                return false;
            }
        }
        for (int i = 0; i < ROOMS[id].solid_count; i++) {
            float step = step_height(&ROOMS[id], ROOMS[id].solids[i]);
            if (step >= apex) {
                snprintf(err, (size_t)err_size, "room %d: step %.0f px exceeds apex %.0f", id,
                         (double)step, (double)apex);
                return false;
            }
        }
    }
    return true;
}
