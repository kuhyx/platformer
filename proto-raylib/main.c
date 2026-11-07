// Scene glue for the slice (spec/DOCS-slice.md): polls input, ticks the sim at
// 60 Hz, owns the web start gate, autosave and the debug hooks. Rules live in
// sim.c; this file only forwards. Mirrors proto-godot/main.gd.
#define _POSIX_C_SOURCE 200809L
#include "debug.h"
#include "input.h"
#include "overlay.h"
#include "raylib.h"
#include "render.h"
#include "save.h"
#include "trace.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
EM_JS(void, signal_web_ready, (void), { window.__gameReady = performance.now(); })
// Read-only state for the browser e2e driver (e2e_web.mjs).
EM_JS(void, publish_state, (int room, double x, double y, int tick, int gate),
      { window.__game = {room : room, x : x, y : y, tick : tick, gate : gate}; })
#endif

#define MAX_FRAME_S 0.25 // clamp after a stall so the sim does not spiral
#define MAX_TICKS_PER_FRAME 5
#define TARGET_FPS 60
#define TITLE "proto-raylib"

static Game game;
static bool booted;
static double accumulator;
static int frames_drawn;
#if !defined(PLATFORM_WEB)
static bool quit_requested; // --quit-at, native only
#endif
static CliOptions cli;
static Trace replay;

static void after_tick(void) {
    fx_on_events(&game.fx, &game.sim);
    for (int i = 0; i < game.sim.event_count; i++) {
        if (cli.log_events) {
            printf("event tick=%d %s room=%d\n", game.sim.tick_count,
                   EVENT_NAMES[game.sim.events[i].kind], game.sim.events[i].room);
            fflush(stdout);
        }
        if (game.sim.events[i].kind == EV_CHECKPOINT) {
            save_write(game.sim.events[i].room);
        }
    }
}

static bool boot(void) {
    char err[128];
    if (!sim_check_winnable(err, sizeof err)) {
        fprintf(stderr, "layout not winnable: %s\n", err);
        return false;
    }
    sim_init(&game.sim, cli.has_seed ? cli.seed : (uint64_t)time(NULL));
    sim_enter_room(&game.sim, save_read_room(ROOM_COUNT), false);
    after_tick();
#if defined(PLATFORM_WEB)
    game.gate_active = true;
#endif
    booted = true;
    return true;
}

static SimInput tick_input(void) {
    if (cli.replay_path == NULL) {
        return input_poll();
    }
    SimInput in;
    trace_input_at(&replay, game.sim.tick_count, &in.left, &in.right, &in.jump);
    return in;
}

static void run_ticks(double dt) {
    accumulator += dt;
    SimInput in = tick_input();
    for (int n = 0; accumulator >= 1.0 / SIM_TICK_HZ && n < MAX_TICKS_PER_FRAME; n++) {
        accumulator -= 1.0 / SIM_TICK_HZ;
        sim_tick(&game.sim, in);
        after_tick();
        if (!sim_frozen(&game.sim)) {
            fx_tick(&game.fx, &game.sim);
        }
    }
}

static void handle_keys(void) {
    if (game.gate_active) {
        if (game.ready_signalled && input_any_press()) {
            game.gate_active = false;
        }
        return;
    }
    if (input_pause_pressed()) {
        game.paused = !game.paused;
    }
    if (IsKeyPressed(KEY_F1)) {
        game.overlay_open = !game.overlay_open;
    }
    if (IsKeyPressed(KEY_F5)) {
        debug_reload_registry();
    }
    if (IsKeyPressed(KEY_F6)) {
        debug_dump_snapshot(&game.sim);
    }
}

static void frame(void) {
    if (!booted) {
        if (!save_ready()) {
            return;
        }
        if (!boot()) {
            exit(1);
        }
    }
    double dt = GetFrameTime();
    dt = dt < MAX_FRAME_S ? dt : MAX_FRAME_S;
    game.gate_phase += dt;
    handle_keys();
    overlay_update(&game);
    if (!game.paused && !game.gate_active) {
        run_ticks(dt);
    }
    render_present(&game);
#if defined(PLATFORM_WEB)
    publish_state(game.sim.room_id, (double)game.sim.x, (double)game.sim.y, game.sim.tick_count,
                  game.gate_active);
#endif
    if (frames_drawn++ == 0) {
        game.ready_signalled = true;
#if defined(PLATFORM_WEB)
        signal_web_ready();
#endif
    }
    debug_take_shots(&cli, game.sim.tick_count);
#if !defined(PLATFORM_WEB)
    quit_requested = cli.quit_at > 0 && game.sim.tick_count >= cli.quit_at;
#endif
}

int main(int argc, char **argv) {
    debug_parse_args(argc, argv, &cli);
    if (cli.replay_path != NULL && !trace_load(cli.replay_path, &replay)) {
        fprintf(stderr, "cannot read replay %s\n", cli.replay_path);
        return 1;
    }
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow((int)ROOMS_WIDTH, (int)ROOMS_HEIGHT, TITLE);
    SetExitKey(KEY_NULL);
    render_init();
    save_init();
#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(frame, 0, 1);
#else
    SetTargetFPS(TARGET_FPS);
    while (!WindowShouldClose() && !quit_requested) {
        frame();
    }
    render_shutdown();
#endif
    CloseWindow();
    return 0;
}
