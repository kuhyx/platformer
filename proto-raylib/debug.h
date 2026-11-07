#ifndef DEBUG_H
#define DEBUG_H

#include "game.h"

#define CLI_MAX_SHOTS 8

typedef struct {
    bool has_seed;
    uint64_t seed;
    const char *replay_path;  // --replay=FILE: feed a trace instead of the keyboard
    int shots[CLI_MAX_SHOTS]; // --shot=TICK: save a PNG at that sim tick
    int shot_count;
    int shots_taken;
    bool log_events; // --log-events: print every sim event to stdout
    int quit_at;     // --quit-at=TICK: exit cleanly at that sim tick (0 = never)
} CliOptions;

void debug_parse_args(int argc, char **argv, CliOptions *cli);
void debug_take_shots(CliOptions *cli, int tick);
void debug_reload_registry(void);         // F5
void debug_dump_snapshot(const Sim *sim); // F6

#endif
