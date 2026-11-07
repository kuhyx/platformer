//! Debug overlay (F1): one slider per registry entry, generated from the
//! registry (D14, never hand-built), plus room id and fps. Debug builds only
//! (`cfg!(debug_assertions)`), which is how its labels coexist with D04.
//! F5 reloads the registry from disk, F6 dumps a snapshot. Mirrors
//! `overlay.gd`; sliders are rects dragged with the mouse.
use crate::game::Game;
use crate::render::{to_world, Quad, Z_OVERLAY};
use crate::{HEIGHT, WIDTH};
use bevy::diagnostic::{DiagnosticsStore, FrameTimeDiagnosticsPlugin};
use bevy::prelude::*;
use bevy::sprite::Anchor;
use proto_bevy::geom::{idx_f32, Rect as GRect};
use proto_bevy::params::Params;
use proto_bevy::{slider, snapshot};

const PANEL_WIDTH_RATIO: f32 = 0.5; // share of the screen the panel takes
const NAME_X: f32 = 6.0;
const TRACK: (f32, f32) = (215.0, 345.0);
const VALUE_X: f32 = 352.0;
const HANDLE_W: f32 = 5.0;
const TRACK_H: f32 = 3.0;

/// What a text entity shows.
#[derive(Component, Clone, Copy)]
pub enum OverlayText {
    /// "room N   fps F".
    Status,
    /// Row label, `key (unit)`.
    Name,
    /// Row's current value.
    Value(usize),
}

/// Overlay rects handed to the renderer each frame.
#[derive(Resource, Default)]
pub struct OverlayQuads(pub Vec<Quad>);

fn row_h(rows: usize) -> f32 {
    HEIGHT / idx_f32(rows + 1)
}

fn text_bundle(text: String, size: f32, x: f32, y: f32, kind: OverlayText) -> impl Bundle {
    (
        kind,
        Text2d::new(text),
        TextFont { font_size: size.into(), ..default() },
        Anchor::CENTER_LEFT,
        Transform::from_translation(to_world(x, y, Z_OVERLAY + 2.0)),
        Visibility::Hidden,
    )
}

/// Spawn one name and one value label per registry key, plus the status line.
pub fn setup(mut commands: Commands, params: Res<Params>) {
    commands.insert_resource(OverlayQuads::default());
    if !cfg!(debug_assertions) {
        return;
    }
    let keys: Vec<&str> = params.keys().collect();
    let (h, size) = (row_h(keys.len()), row_h(keys.len()) * 0.55);
    commands.spawn(text_bundle(String::new(), size, NAME_X, h * 0.5, OverlayText::Status));
    for (i, key) in keys.iter().enumerate() {
        let y = h * (idx_f32(i) + 1.5);
        let name = format!("{key} ({})", params.entry(key).unit);
        commands.spawn(text_bundle(name, size, NAME_X, y, OverlayText::Name));
        commands.spawn(text_bundle(String::new(), size, VALUE_X, y, OverlayText::Value(i)));
    }
}

/// Cursor position in game space (top-left origin), if over the window.
fn cursor_game(win: &Window, cam: &Camera, tf: &GlobalTransform) -> Option<Vec2> {
    let world = cam.viewport_to_world_2d(tf, win.cursor_position()?).ok()?;
    Some(Vec2::new(world.x + WIDTH / 2.0, HEIGHT / 2.0 - world.y))
}

/// Keys, slider dragging, labels and the rect list.
#[allow(clippy::too_many_arguments)] // Bevy system parameters
pub fn update(
    keys: Res<ButtonInput<KeyCode>>,
    mouse: Res<ButtonInput<MouseButton>>,
    windows: Query<&Window>,
    cams: Query<(&Camera, &GlobalTransform)>,
    diagnostics: Res<DiagnosticsStore>,
    mut game: ResMut<Game>,
    mut params: ResMut<Params>,
    mut quads: ResMut<OverlayQuads>,
    mut drag: Local<Option<String>>,
    mut texts: Query<(&OverlayText, &mut Text2d, &mut Visibility)>,
) {
    quads.0.clear();
    if !cfg!(debug_assertions) || game.gate_active {
        return;
    }
    if keys.just_pressed(KeyCode::F1) {
        game.overlay = !game.overlay;
    }
    if keys.just_pressed(KeyCode::F5) {
        if let Err(e) = params.reload_from_disk() {
            warn!("F5 reload failed, keeping registry: {e}");
        }
    }
    if keys.just_pressed(KeyCode::F6) {
        let snap = snapshot::snapshot(&game.sim, params.registry_hash());
        crate::platform::dump_snapshot(&serde_json::to_string_pretty(&snap).unwrap_or_default());
    }
    let shown = game.overlay;
    let fps = diagnostics
        .get(&FrameTimeDiagnosticsPlugin::FPS)
        .and_then(bevy::diagnostic::Diagnostic::smoothed)
        .unwrap_or(0.0);
    let cursor = match (windows.single(), cams.single()) {
        (Ok(w), Ok((c, t))) => cursor_game(w, c, t),
        _ => None,
    };
    let keys_list: Vec<String> = params.keys().map(str::to_owned).collect();
    let h = row_h(keys_list.len());
    if shown {
        drag_sliders(&mouse, cursor, &keys_list, h, &mut drag, &mut params);
        quads.0 = panel_quads(&keys_list, h, &params);
    }
    for (kind, mut text, mut vis) in &mut texts {
        *vis = if shown { Visibility::Visible } else { Visibility::Hidden };
        let want = match kind {
            OverlayText::Status => format!("room {}   fps {fps:.0}", game.sim.room_id),
            OverlayText::Name => continue,
            OverlayText::Value(i) => slider::label(params.get(&keys_list[*i])),
        };
        if text.0 != want {
            text.0 = want;
        }
    }
}

fn drag_sliders(
    mouse: &ButtonInput<MouseButton>,
    cursor: Option<Vec2>,
    keys: &[String],
    h: f32,
    drag: &mut Option<String>,
    params: &mut Params,
) {
    if !mouse.pressed(MouseButton::Left) {
        *drag = None;
        return;
    }
    let Some(c) = cursor else { return };
    if mouse.just_pressed(MouseButton::Left)
        && c.x >= TRACK.0 - HANDLE_W
        && c.x <= TRACK.1 + HANDLE_W
    {
        let row = (0..keys.len())
            .find(|&i| c.y >= h * (idx_f32(i) + 1.0) && c.y < h * (idx_f32(i) + 2.0));
        *drag = row.and_then(|i| keys.get(i)).cloned();
    }
    if let Some(key) = drag.as_deref() {
        let t = (c.x - TRACK.0) / (TRACK.1 - TRACK.0);
        let v = slider::value_at(params.entry(key), t);
        params.set(key, v);
    }
}

fn panel_quads(keys: &[String], h: f32, params: &Params) -> Vec<Quad> {
    let panel = GRect::new(0.0, 0.0, WIDTH * PANEL_WIDTH_RATIO, HEIGHT);
    let mut out = vec![Quad { rect: panel, color: Color::BLACK.with_alpha(0.8), z: Z_OVERLAY }];
    for (i, key) in keys.iter().enumerate() {
        let y = h * (idx_f32(i) + 1.5);
        let t = slider::fraction(params.entry(key), params.get(key));
        let track = GRect::new(TRACK.0, y - TRACK_H / 2.0, TRACK.1 - TRACK.0, TRACK_H);
        out.push(Quad { rect: track, color: Color::srgb(0.4, 0.4, 0.4), z: Z_OVERLAY + 1.0 });
        let hx = TRACK.0 + t * (TRACK.1 - TRACK.0) - HANDLE_W / 2.0;
        let handle = GRect::new(hx, y - h * 0.3, HANDLE_W, h * 0.6);
        out.push(Quad { rect: handle, color: Color::WHITE, z: Z_OVERLAY + 1.5 });
    }
    out
}
