#ifndef GAME_H
#define GAME_H

#include "fx.h"
#include "sim.h"

typedef struct {
    Sim sim;
    Fx fx;
    bool paused;
    bool gate_active;     // web start gate (D02); absent on desktop
    bool ready_signalled; // first frame drawn: the gate may be dismissed
    bool overlay_open;    // F1 debug overlay
    double gate_phase;    // seconds, drives the pulse
} Game;

#endif
