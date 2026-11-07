// Input map (spec/DOCS-input-map.md, D05): keyboard and gamepad both live.
#include "input.h"
#include "raylib.h"
#include <math.h>

#define GAMEPAD_ID 0
#define STICK_DEAD_ZONE 0.25f // D05: fixed, not a tunable

static const int LEFT_KEYS[] = {KEY_A, KEY_LEFT};
static const int RIGHT_KEYS[] = {KEY_D, KEY_RIGHT};
static const int JUMP_KEYS[] = {KEY_SPACE, KEY_W, KEY_UP, KEY_Z, KEY_K};

#define COUNT(a) ((int)(sizeof(a) / sizeof((a)[0])))

static bool any_key_down(const int *keys, int count) {
    for (int i = 0; i < count; i++) {
        if (IsKeyDown(keys[i])) {
            return true;
        }
    }
    return false;
}

static bool pad_down(int button) {
    return IsGamepadAvailable(GAMEPAD_ID) && IsGamepadButtonDown(GAMEPAD_ID, button);
}

static float stick_x(void) {
    if (!IsGamepadAvailable(GAMEPAD_ID)) {
        return 0.0f;
    }
    float x = GetGamepadAxisMovement(GAMEPAD_ID, GAMEPAD_AXIS_LEFT_X);
    return fabsf(x) >= STICK_DEAD_ZONE ? x : 0.0f;
}

SimInput input_poll(void) {
    SimInput in;
    in.left = any_key_down(LEFT_KEYS, COUNT(LEFT_KEYS)) ||
              pad_down(GAMEPAD_BUTTON_LEFT_FACE_LEFT) || stick_x() < 0.0f;
    in.right = any_key_down(RIGHT_KEYS, COUNT(RIGHT_KEYS)) ||
               pad_down(GAMEPAD_BUTTON_LEFT_FACE_RIGHT) || stick_x() > 0.0f;
    in.jump = any_key_down(JUMP_KEYS, COUNT(JUMP_KEYS)) || pad_down(GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
    return in;
}

bool input_pause_pressed(void) {
    return IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_P) ||
           (IsGamepadAvailable(GAMEPAD_ID) &&
            IsGamepadButtonPressed(GAMEPAD_ID, GAMEPAD_BUTTON_MIDDLE_RIGHT));
}

bool input_any_press(void) {
    bool key = GetKeyPressed() != 0;
    bool mouse =
        IsMouseButtonPressed(MOUSE_BUTTON_LEFT) || IsMouseButtonPressed(MOUSE_BUTTON_RIGHT);
    bool pad =
        IsGamepadAvailable(GAMEPAD_ID) && GetGamepadButtonPressed() != GAMEPAD_BUTTON_UNKNOWN;
    return key || mouse || pad;
}
