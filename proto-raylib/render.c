// Draws the slice into an 854x480 target scaled to the window, aspect kept (D13).
#include "render.h"
#include "overlay.h"
#include "raylib.h"
#include <math.h>

#define TWO_PI 6.2831853f

static const Color PLAYER = {255, 255, 255, 255};
static const Color HAZARD = {255, 0, 0, 255};
static const Color CHECKPOINT = {0, 255, 0, 255};
static const Color GOAL = {255, 255, 0, 255};
static const Color FLOOR_GREY = {190, 190, 190, 255};
static const Color BARS = {26, 26, 31, 255}; // letterbox, matches the web shell

static RenderTexture2D target;

void render_init(void) {
    target = LoadRenderTexture((int)ROOMS_WIDTH, (int)ROOMS_HEIGHT);
    SetTextureFilter(target.texture, TEXTURE_FILTER_BILINEAR);
}

void render_shutdown(void) {
    UnloadRenderTexture(target);
}

static Rectangle to_rect(RoomRect r) {
    return (Rectangle){r.x, r.y, r.w, r.h};
}

static void draw_world(const Game *g) {
    const Sim *s = &g->sim;
    const Room *room = sim_room(s);
    for (int i = 0; i < room->solid_count; i++) {
        DrawRectangleRec(to_rect(room->solids[i]), FLOOR_GREY);
    }
    for (int i = 0; i < room->hazard_count; i++) {
        DrawRectangleRec(to_rect(room->hazards[i]), HAZARD);
    }
    DrawRectangleRec(to_rect(room->checkpoint), CHECKPOINT);
    if (room->has_goal) {
        DrawRectangleRec(to_rect(room->goal), GOAL);
    }
    if (room->has_blade) {
        DrawRectangleRec(to_rect(sim_blade_rect(s)), HAZARD);
    }
    if (s->phase != PHASE_DEAD) {
        DrawRectangleRec(to_rect(sim_rect(s)), PLAYER);
    }
    float side = PARAM(P_PARTICLE_SIZE);
    for (int i = 0; i < g->fx.count; i++) {
        DrawRectangleV((Vector2){g->fx.particles[i].x, g->fx.particles[i].y}, (Vector2){side, side},
                       PLAYER);
    }
}

// Pulsing icon, no text (D02/D04): a circle breathing between
// radius * (1 - depth) and radius.
static void draw_gate(const Game *g) {
    float wave = (1.0f + sinf((float)g->gate_phase / PARAM(P_GATE_PULSE_PERIOD) * TWO_PI)) / 2.0f;
    float radius = PARAM(P_GATE_ICON_RADIUS) * (1.0f - PARAM(P_GATE_PULSE_DEPTH) * (1.0f - wave));
    DrawRectangle(0, 0, (int)ROOMS_WIDTH, (int)ROOMS_HEIGHT, Fade(BLACK, PARAM(P_PAUSE_DIM)));
    DrawCircleV((Vector2){ROOMS_WIDTH / 2.0f, ROOMS_HEIGHT / 2.0f}, radius, PLAYER);
}

static void draw_scene(const Game *g) {
    ClearBackground(BLACK);
    Camera2D shake = {{g->fx.shake_x, g->fx.shake_y}, {0.0f, 0.0f}, 0.0f, 1.0f};
    BeginMode2D(shake);
    draw_world(g);
    EndMode2D();
    float flash = fx_flash_alpha(&g->fx);
    if (flash > 0.0f) {
        DrawRectangle(0, 0, (int)ROOMS_WIDTH, (int)ROOMS_HEIGHT, Fade(PLAYER, flash));
    }
    if (g->paused) {
        DrawRectangle(0, 0, (int)ROOMS_WIDTH, (int)ROOMS_HEIGHT, Fade(BLACK, PARAM(P_PAUSE_DIM)));
    }
    if (g->gate_active && g->ready_signalled) {
        draw_gate(g);
    }
    if (g->overlay_open) {
        overlay_draw(g, GetFPS());
    }
}

void render_present(const Game *g) {
    BeginTextureMode(target);
    draw_scene(g);
    EndTextureMode();

    float win_w = (float)GetScreenWidth();
    float win_h = (float)GetScreenHeight();
    float scale = fminf(win_w / ROOMS_WIDTH, win_h / ROOMS_HEIGHT);
    float w = ROOMS_WIDTH * scale;
    float h = ROOMS_HEIGHT * scale;
    float x = (win_w - w) / 2.0f;
    float y = (win_h - h) / 2.0f;
    SetMouseOffset((int)-x, (int)-y);
    SetMouseScale(1.0f / scale, 1.0f / scale);

    BeginDrawing();
    ClearBackground(BARS);
    Rectangle src = {0.0f, 0.0f, ROOMS_WIDTH, -ROOMS_HEIGHT};
    DrawTexturePro(target.texture, src, (Rectangle){x, y, w, h}, (Vector2){0.0f, 0.0f}, 0.0f,
                   WHITE);
    EndDrawing();
}
