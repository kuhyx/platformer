#ifndef RENDER_H
#define RENDER_H

#include "game.h"

void render_init(void);
void render_present(const Game *g); // world, gate, overlay, then letterboxed blit
void render_shutdown(void);

#endif
