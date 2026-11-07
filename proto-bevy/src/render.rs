//! Immediate-mode drawing on retained sprites: each frame the world is
//! flattened to a list of coloured rects (like `main.gd::_draw`) and written
//! into a pool of sprite entities. Game space is 854x480, y down; Bevy's is
//! centred, y up, so `to_world` converts. No text in game (D04).
use crate::game::Game;
use crate::{HEIGHT, WIDTH};
use bevy::camera::ScalingMode;
use bevy::prelude::*;
use bevy::sprite::Anchor;
use proto_bevy::geom::Rect as GRect;
use proto_bevy::params::Params;
use proto_bevy::sim::State;

// Palette fixed by the slice spec: no sprites, one colour per element.
const COLOR_PLAYER: Color = Color::WHITE;
const COLOR_HAZARD: Color = Color::srgb(1.0, 0.0, 0.0);
const COLOR_CHECKPOINT: Color = Color::srgb(0.0, 1.0, 0.0);
const COLOR_GOAL: Color = Color::srgb(1.0, 1.0, 0.0);
const COLOR_FLOOR: Color = Color::srgb(0.5, 0.5, 0.5);

/// Layering (higher is nearer the camera).
pub const Z_WORLD: f32 = 0.0;
const Z_FLASH: f32 = 40.0;
const Z_DIM: f32 = 50.0;
const Z_GATE_ICON: f32 = 51.0;
/// Overlay layers live above the dim, below the letterbox bars.
pub const Z_OVERLAY: f32 = 100.0;
const Z_BARS: f32 = 200.0;
/// Letterbox bar thickness: larger than any window overshoot.
const BAR: f32 = 8000.0;

/// One flattened rectangle in game space.
#[derive(Clone, Copy)]
pub struct Quad {
    /// Rect, top-left origin, y down.
    pub rect: GRect,
    /// Fill colour (alpha honoured).
    pub color: Color,
    /// Layer.
    pub z: f32,
}

/// Sprite entities reused frame to frame.
#[derive(Resource, Default)]
pub struct Pool(pub Vec<Entity>);

/// Marks the gate's pulsing circle.
#[derive(Component)]
pub struct GateIcon;

/// Game space (top-left, y down) to Bevy world translation.
#[must_use]
pub fn to_world(x: f32, y: f32, z: f32) -> Vec3 {
    Vec3::new(x - WIDTH / 2.0, HEIGHT / 2.0 - y, z)
}

/// Camera that shows exactly 854x480 (more only as letterbox), the gate
/// circle, and four bars that hide anything outside the room (D13).
pub fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    commands.insert_resource(Pool::default());
    commands.spawn((
        Camera2d,
        Projection::Orthographic(OrthographicProjection {
            scaling_mode: ScalingMode::AutoMin { min_width: WIDTH, min_height: HEIGHT },
            ..OrthographicProjection::default_2d()
        }),
    ));
    commands.spawn((
        GateIcon,
        Mesh2d(meshes.add(Circle::new(1.0))),
        MeshMaterial2d(materials.add(ColorMaterial::from(COLOR_PLAYER))),
        Transform::from_xyz(0.0, 0.0, Z_GATE_ICON),
        Visibility::Hidden,
    ));
    let (w, h) = (WIDTH, HEIGHT);
    let bars = [(-BAR, -BAR, w + 2.0 * BAR, BAR), (-BAR, h, w + 2.0 * BAR, BAR)]
        .into_iter()
        .chain([(-BAR, 0.0, BAR, h), (w, 0.0, BAR, h)]);
    for (x, y, bw, bh) in bars {
        commands.spawn((
            Sprite::from_color(Color::BLACK, Vec2::new(bw, bh)),
            Anchor::TOP_LEFT,
            Transform::from_translation(to_world(x, y, Z_BARS)),
        ));
    }
}

fn quad(rect: GRect, color: Color, z: f32) -> Quad {
    Quad { rect, color, z }
}

fn shifted(r: &GRect, off: (f32, f32)) -> GRect {
    GRect::new(r.x + off.0, r.y + off.1, r.w, r.h)
}

/// Flatten the world, effects, flash and pause dim into quads.
#[must_use]
pub fn world_quads(game: &Game, p: &Params) -> Vec<Quad> {
    let (sim, fx) = (&game.sim, &game.fx);
    let room = &sim.rooms.rooms[sim.room_id];
    let off = (fx.shake_offset.x, fx.shake_offset.y);
    let mut q = Vec::new();
    q.extend(room.solids.iter().map(|s| quad(shifted(s, off), COLOR_FLOOR, Z_WORLD)));
    q.extend(room.hazards.iter().map(|h| quad(shifted(h, off), COLOR_HAZARD, Z_WORLD + 1.0)));
    q.push(quad(shifted(&room.checkpoint, off), COLOR_CHECKPOINT, Z_WORLD + 2.0));
    if let Some(g) = room.goal {
        q.push(quad(shifted(&g, off), COLOR_GOAL, Z_WORLD + 2.0));
    }
    if room.blade.is_some() {
        q.push(quad(shifted(&sim.blade_rect(), off), COLOR_HAZARD, Z_WORLD + 3.0));
    }
    if sim.state != State::Dead {
        q.push(quad(shifted(&sim.rect(p), off), COLOR_PLAYER, Z_WORLD + 4.0));
    }
    let side = p.get("particle_size");
    for part in &fx.particles {
        let r = GRect::new(part.pos.x + off.0, part.pos.y + off.1, side, side);
        q.push(quad(r, COLOR_PLAYER, Z_WORLD + 5.0));
    }
    let screen = GRect::new(0.0, 0.0, sim.rooms.width, sim.rooms.height);
    if fx.flash_alpha(p) > 0.0 {
        q.push(quad(screen, COLOR_PLAYER.with_alpha(fx.flash_alpha(p)), Z_FLASH));
    }
    if game.paused || (game.gate_active && game.ready()) {
        q.push(quad(screen, Color::BLACK.with_alpha(p.get("pause_dim")), Z_DIM));
    }
    q
}

/// Write `quads` into the pool, growing it as needed; surplus is hidden.
pub fn apply(
    commands: &mut Commands,
    pool: &mut Pool,
    quads: &[Quad],
    sprites: &mut Query<(&mut Sprite, &mut Transform, &mut Visibility), Without<GateIcon>>,
) {
    while pool.0.len() < quads.len() {
        let e = commands
            .spawn((
                Sprite::from_color(Color::WHITE, Vec2::ONE),
                Anchor::TOP_LEFT,
                Transform::default(),
                Visibility::Hidden,
            ))
            .id();
        pool.0.push(e);
    }
    for (i, e) in pool.0.iter().enumerate() {
        let Ok((mut sprite, mut tf, mut vis)) = sprites.get_mut(*e) else { continue };
        match quads.get(i) {
            Some(q) => {
                sprite.color = q.color;
                sprite.custom_size = Some(Vec2::new(q.rect.w, q.rect.h));
                tf.translation = to_world(q.rect.x, q.rect.y, q.z);
                *vis = Visibility::Visible;
            }
            None => *vis = Visibility::Hidden,
        }
    }
}

/// Pulsing gate icon (D02/D04): a circle breathing between
/// `radius * (1 - depth)` and `radius`.
fn gate_radius(game: &Game, p: &Params) -> f32 {
    let wave = f32::midpoint(
        1.0,
        (game.gate_phase / p.get("gate_pulse_period") * std::f32::consts::TAU).sin(),
    );
    p.get("gate_icon_radius") * (1.0 - p.get("gate_pulse_depth") * (1.0 - wave))
}

/// Per-frame render system.
pub fn draw(
    mut commands: Commands,
    game: Res<Game>,
    params: Res<Params>,
    mut pool: ResMut<Pool>,
    mut sprites: Query<(&mut Sprite, &mut Transform, &mut Visibility), Without<GateIcon>>,
    mut icon: Query<(&mut Transform, &mut Visibility), With<GateIcon>>,
    overlay_quads: Res<crate::overlay::OverlayQuads>,
) {
    let mut quads = world_quads(&game, &params);
    quads.extend(overlay_quads.0.iter().copied());
    apply(&mut commands, &mut pool, &quads, &mut sprites);
    if let Ok((mut tf, mut vis)) = icon.single_mut() {
        let show = game.gate_active && game.ready();
        tf.scale = Vec3::splat(gate_radius(&game, &params));
        *vis = if show { Visibility::Visible } else { Visibility::Hidden };
    }
}
