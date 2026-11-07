//! Input polling per spec/DOCS-input-map.md (D05): keyboard and gamepad are
//! both always active; no rebinding.
use bevy::input::gamepad::{Gamepad, GamepadAxis, GamepadButton};
use bevy::prelude::*;
use proto_bevy::sim::Input;

/// Stick dead zone, fixed by D05 (not a tunable).
const STICK_DEAD_ZONE: f32 = 0.25;

const LEFT: [KeyCode; 2] = [KeyCode::KeyA, KeyCode::ArrowLeft];
const RIGHT: [KeyCode; 2] = [KeyCode::KeyD, KeyCode::ArrowRight];
const JUMP: [KeyCode; 5] =
    [KeyCode::Space, KeyCode::KeyW, KeyCode::ArrowUp, KeyCode::KeyZ, KeyCode::KeyK];
const PAUSE: [KeyCode; 2] = [KeyCode::Escape, KeyCode::KeyP];

/// Held movement and jump from keyboard plus every connected gamepad.
#[must_use]
pub fn poll(keys: &ButtonInput<KeyCode>, pads: &Query<&Gamepad>) -> Input {
    let mut input = Input {
        left: keys.any_pressed(LEFT),
        right: keys.any_pressed(RIGHT),
        jump: keys.any_pressed(JUMP),
    };
    for pad in pads {
        let x = pad.get(GamepadAxis::LeftStickX).unwrap_or(0.0);
        input.left |= x < -STICK_DEAD_ZONE || pad.pressed(GamepadButton::DPadLeft);
        input.right |= x > STICK_DEAD_ZONE || pad.pressed(GamepadButton::DPadRight);
        input.jump |= pad.pressed(GamepadButton::South);
    }
    input
}

/// Pause toggled this frame (Esc, P, gamepad Start).
#[must_use]
pub fn pause_pressed(keys: &ButtonInput<KeyCode>, pads: &Query<&Gamepad>) -> bool {
    keys.any_just_pressed(PAUSE) || pads.iter().any(|p| p.just_pressed(GamepadButton::Start))
}

/// Any key, mouse button or gamepad button went down (dismisses the gate).
#[must_use]
pub fn any_press(
    keys: &ButtonInput<KeyCode>,
    mouse: &ButtonInput<MouseButton>,
    pads: &Query<&Gamepad>,
) -> bool {
    keys.get_just_pressed().next().is_some()
        || mouse.get_just_pressed().next().is_some()
        || pads.iter().any(|p| p.get_just_pressed().next().is_some())
}
