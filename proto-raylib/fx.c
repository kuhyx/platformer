#include "fx.h"
#include <math.h>

#define TICK (1.0f / SIM_TICK_HZ)
#define TWO_PI 6.28318530717958647692f

static void burst(Fx *fx, Sim *sim) {
    RoomRect me = sim_rect(sim);
    float speed = PARAM(P_PARTICLE_SPEED);
    float life = PARAM(P_PARTICLE_LIFETIME);
    int n = (int)PARAM(P_DEATH_PARTICLES);
    for (int i = 0; i < n && fx->count < FX_MAX_PARTICLES; i++) {
        float angle = rng_range(&sim->rng, 0.0f, TWO_PI);
        float mag = rng_range(&sim->rng, 0.0f, speed);
        fx->particles[fx->count++] = (Particle){me.x + me.w / 2.0f, me.y + me.h / 2.0f,
                                                cosf(angle) * mag, sinf(angle) * mag, life};
    }
}

void fx_on_events(Fx *fx, Sim *sim) {
    for (int i = 0; i < sim->event_count; i++) {
        if (sim->events[i].kind == EV_DEATH) {
            burst(fx, sim);
            fx->shake_left = (double)PARAM(P_SHAKE_DURATION);
        } else if (sim->events[i].kind == EV_GOAL) {
            fx->flash_left = (double)PARAM(P_GOAL_FLASH_DURATION);
        }
    }
}

static void tick_particles(Fx *fx) {
    float gravity = PARAM(P_GRAVITY);
    int kept = 0;
    for (int i = 0; i < fx->count; i++) {
        Particle p = fx->particles[i];
        p.life -= TICK;
        if (p.life <= 0.0f) {
            continue;
        }
        p.vy += gravity * TICK;
        p.x += p.vx * TICK;
        p.y += p.vy * TICK;
        fx->particles[kept++] = p;
    }
    fx->count = kept;
}

void fx_tick(Fx *fx, Sim *sim) {
    tick_particles(fx);
    fx->shake_left = fmax(fx->shake_left - (double)TICK, 0.0);
    if (fx->shake_left > 0.0) {
        float amp = PARAM(P_SHAKE_AMPLITUDE);
        fx->shake_x = rng_range(&sim->rng, -amp, amp);
        fx->shake_y = rng_range(&sim->rng, -amp, amp);
    } else {
        fx->shake_x = fx->shake_y = 0.0f;
    }
    fx->flash_left = fmax(fx->flash_left - (double)TICK, 0.0);
}

float fx_flash_alpha(const Fx *fx) {
    double total = (double)PARAM(P_GOAL_FLASH_DURATION);
    return total > 0.0 ? (float)(fx->flash_left / total) : 0.0f;
}
