#ifndef OVERLAY_H
#define OVERLAY_H

#include "game.h"

void overlay_update(const Game *g); // slider dragging while the overlay is open
void overlay_draw(const Game *g, int fps);

#endif
