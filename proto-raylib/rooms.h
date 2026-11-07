// GENERATED FILE - edit shared/rooms/rooms.json and run `make gen-rooms`
#ifndef ROOMS_H
#define ROOMS_H

#define ROOMS_WIDTH 854.0f
#define ROOMS_HEIGHT 480.0f
#define ROOM_COUNT 2
#define ROOM_MAX_SOLIDS 3
#define ROOM_MAX_HAZARDS 1
#define ROOM_MAX_GAPS 1

typedef struct { float x, y, w, h; } RoomRect;

typedef struct {
    float spawn_x, spawn_y;
    RoomRect checkpoint;
    int solid_count, hazard_count, gap_count;
    RoomRect solids[ROOM_MAX_SOLIDS];
    RoomRect hazards[ROOM_MAX_HAZARDS];
    float gaps[ROOM_MAX_GAPS][2];
    int has_blade;
    RoomRect blade;
    float blade_track[2];
    int has_goal;
    RoomRect goal;
} Room;

static const Room ROOMS[ROOM_COUNT] = {
    {
        24.0f, 424.0f,
        {8.0f, 416.0f, 12.0f, 24.0f},
        3, 1, 1,
        {{0.0f, 440.0f, 390.0f, 40.0f}, {454.0f, 440.0f, 400.0f, 40.0f}, {560.0f, 400.0f, 294.0f, 40.0f}},
        {{390.0f, 464.0f, 64.0f, 216.0f}},
        {{390.0f, 454.0f}},
        0,
        {0.0f, 0.0f, 0.0f, 0.0f},
        {0.0f, 0.0f},
        0,
        {0.0f, 0.0f, 0.0f, 0.0f},
    },
    {
        24.0f, 424.0f,
        {8.0f, 416.0f, 12.0f, 24.0f},
        2, 1, 1,
        {{0.0f, 440.0f, 300.0f, 40.0f}, {356.0f, 440.0f, 498.0f, 40.0f}, {0.0f, 0.0f, 0.0f, 0.0f}},
        {{300.0f, 464.0f, 56.0f, 216.0f}},
        {{300.0f, 356.0f}},
        1,
        {200.0f, 396.0f, 24.0f, 16.0f},
        {200.0f, 472.0f},
        1,
        {820.0f, 380.0f, 20.0f, 60.0f},
    },
};

#endif
