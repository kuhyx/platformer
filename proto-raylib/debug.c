// Debug hooks: command line flags, F5 registry reload, F6 snapshot dump.
#include "debug.h"
#include "raylib.h"
#include "save.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FLAG_SEED "--seed="
#define FLAG_REPLAY "--replay="
#define FLAG_SHOT "--shot="
#define FLAG_LOG "--log-events"
#define FLAG_QUIT "--quit-at="
#define SHARED_REGISTRY "shared/params/params.json"
#define REGISTRY_BUF 512

void debug_parse_args(int argc, char **argv, CliOptions *cli) {
    memset(cli, 0, sizeof *cli);
    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], FLAG_SEED, strlen(FLAG_SEED)) == 0) {
            cli->has_seed = true;
            cli->seed = strtoull(argv[i] + strlen(FLAG_SEED), NULL, 10);
        } else if (strncmp(argv[i], FLAG_REPLAY, strlen(FLAG_REPLAY)) == 0) {
            cli->replay_path = argv[i] + strlen(FLAG_REPLAY);
        } else if (strcmp(argv[i], FLAG_LOG) == 0) {
            cli->log_events = true;
        } else if (strncmp(argv[i], FLAG_QUIT, strlen(FLAG_QUIT)) == 0) {
            cli->quit_at = atoi(argv[i] + strlen(FLAG_QUIT));
        } else if (strncmp(argv[i], FLAG_SHOT, strlen(FLAG_SHOT)) == 0 &&
                   cli->shot_count < CLI_MAX_SHOTS) {
            cli->shots[cli->shot_count++] = atoi(argv[i] + strlen(FLAG_SHOT));
        }
    }
}

void debug_take_shots(CliOptions *cli, int tick) {
    if (cli->shots_taken < cli->shot_count && tick >= cli->shots[cli->shots_taken]) {
        TakeScreenshot(TextFormat("shot_%04d.png", cli->shots[cli->shots_taken]));
        cli->shots_taken++;
    }
}

// Native only. Run from proto-raylib/ or its parent directories; the web
// build compiles the registry in, so there F5 stays the browser's reload.
void debug_reload_registry(void) {
#if !defined(PLATFORM_WEB)
    char path[REGISTRY_BUF];
    const char *prefixes[] = {"../", "", "../../"};
    for (size_t i = 0; i < sizeof prefixes / sizeof prefixes[0]; i++) {
        snprintf(path, sizeof path, "%s%s", prefixes[i], SHARED_REGISTRY);
        int updated = prm_reload(path);
        if (updated >= 0) {
            printf("registry: reloaded %d values from %s\n", updated, path);
            return;
        }
    }
    printf("registry: %s not found\n", SHARED_REGISTRY);
#endif
}

void debug_dump_snapshot(const Sim *sim) {
    const char *path = save_path("snapshot.json");
    FILE *f = path != NULL ? fopen(path, "w") : NULL;
    if (f == NULL) {
        return;
    }
    fprintf(f,
            "{\"room_id\": %d, \"checkpoint_id\": %d, \"player_state\": {\"x\": %g, \"y\": %g, "
            "\"vx\": %g, \"vy\": %g, \"on_ground\": %d, \"coyote_left\": %g, "
            "\"buffer_left\": %g, \"state\": %d, \"state_t\": %g, \"blade_x\": %g, "
            "\"blade_dir\": %g}, \"rng_seed\": %llu, \"rng_state\": %llu, "
            "\"params_hash\": \"%08x\", \"tick\": %d}\n",
            sim->room_id, sim->room_id, (double)sim->x, (double)sim->y, (double)sim->vx,
            (double)sim->vy, sim->on_ground, sim->coyote_left, sim->buffer_left, (int)sim->phase,
            sim->state_t, (double)sim->blade_x, (double)sim->blade_dir,
            (unsigned long long)sim->seed, (unsigned long long)sim->rng.state, prm_hash(),
            sim->tick_count);
    fclose(f);
    printf("snapshot: %s\n", path);
}
