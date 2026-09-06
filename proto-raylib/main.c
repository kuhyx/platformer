// Boot stub: opens the window, draws the avatar placeholder from the generated
// registry, signals web readiness. The slice (spec/DOCS-slice.md) is not implemented.
#include "params.h"
#include "raylib.h"

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

static const int WIDTH = 854;  // D13
static const int HEIGHT = 480; // D13
static const int TARGET_FPS = 60;
static const Color BACKGROUND = {26, 26, 31, 255};
static const int PLACEHOLDER_SPAWN_X = 100; // slice will read spawn from room data
static const int PLACEHOLDER_SPAWN_Y = 400;

static int frames_drawn = 0;

static void signal_web_ready(void) {
#if defined(PLATFORM_WEB)
    EM_ASM({ window.__gameReady = performance.now(); });
#endif
}

static void frame(void) {
    BeginDrawing();
    ClearBackground(BACKGROUND);
    DrawRectangle(PLACEHOLDER_SPAWN_X, PLACEHOLDER_SPAWN_Y, (int)PARAM(P_PLAYER_W),
                  (int)PARAM(P_PLAYER_H), WHITE);
    EndDrawing();
    if (frames_drawn++ == 0) {
        signal_web_ready();
    }
}

int main(void) {
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(WIDTH, HEIGHT, "proto-raylib");
#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(frame, 0, 1);
#else
    SetTargetFPS(TARGET_FPS);
    while (!WindowShouldClose()) {
        frame();
    }
#endif
    CloseWindow();
    return 0;
}
