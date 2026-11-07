// Debug overlay (F1): one slider per registry entry, generated from PARAMS
// (D14, never hand-built), plus room id and fps. Mirrors proto-godot/overlay.gd.
#include "overlay.h"
#include "raylib.h"
#include <math.h>

#define PANEL_WIDTH_RATIO 0.5f // share of the screen the panel takes
#define MARGIN 6
#define ROW_H 18
#define FONT 10
#define TRACK_X 190
#define TRACK_W 160
#define TRACK_H 6
#define VALUE_X 358
#define NO_DRAG (-1)

static const Color PANEL = {20, 20, 26, 220};
static const Color TRACK = {90, 90, 100, 255};
static const Color KNOB = {255, 255, 255, 255};

static int dragging = NO_DRAG;

static int row_y(int i) {
    return MARGIN + (i + 1) * ROW_H; // row 0 is the status line
}

static Rectangle track_rect(int i) {
    return (Rectangle){TRACK_X, (float)row_y(i) + 2.0f, TRACK_W, ROW_H - 4.0f};
}

static float snapped(const Param *p, float t) {
    float v = p->min + t * (p->max - p->min);
    v = p->min + roundf((v - p->min) / p->step) * p->step;
    return fminf(fmaxf(v, p->min), p->max);
}

void overlay_update(const Game *g) {
    if (!g->overlay_open) {
        dragging = NO_DRAG;
        return;
    }
    Vector2 m = GetMousePosition();
    if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        for (int i = 0; i < P_COUNT; i++) {
            if (CheckCollisionPointRec(m, track_rect(i))) {
                dragging = i;
            }
        }
    }
    if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
        dragging = NO_DRAG;
    }
    if (dragging != NO_DRAG) {
        Rectangle r = track_rect(dragging);
        float t = fminf(fmaxf((m.x - r.x) / r.width, 0.0f), 1.0f);
        prm_table()[dragging].value = snapped(&prm_table()[dragging], t);
    }
}

static void draw_row(int i) {
    const Param *p = &prm_table()[i];
    Rectangle r = track_rect(i);
    int y = row_y(i);
    float t = (p->value - p->min) / (p->max - p->min);
    DrawText(p->key, MARGIN, y + 4, FONT, WHITE);
    DrawRectangle((int)r.x, y + (ROW_H - TRACK_H) / 2, (int)r.width, TRACK_H, TRACK);
    DrawRectangle((int)(r.x + t * r.width) - 2, y + 2, 4, ROW_H - 4, KNOB);
    DrawText(TextFormat("%.6g", (double)p->value), VALUE_X, y + 4, FONT, WHITE);
}

void overlay_draw(const Game *g, int fps) {
    DrawRectangle(0, 0, (int)(ROOMS_WIDTH * PANEL_WIDTH_RATIO), (int)ROOMS_HEIGHT, PANEL);
    DrawText(TextFormat("room %d   fps %d", g->sim.room_id, fps), MARGIN, MARGIN, FONT, WHITE);
    for (int i = 0; i < P_COUNT; i++) {
        draw_row(i);
    }
}
