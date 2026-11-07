// Juice (D06): death particles, screen shake, goal flash. Ticked in lockstep
// with the sim and fed its RNG, so a replay reproduces every particle.
#ifndef FX_H
#define FX_H

#include "sim.h"

#define FX_MAX_PARTICLES 256 // above the death_particles registry max (200)

typedef struct {
    float x, y, vx, vy;
    float life;
} Particle;

typedef struct {
    Particle particles[FX_MAX_PARTICLES];
    int count;
    double shake_left;
    float shake_x, shake_y;
    double flash_left;
} Fx;

void fx_on_events(Fx *fx, Sim *sim);
void fx_tick(Fx *fx, Sim *sim);
float fx_flash_alpha(const Fx *fx);

#endif
