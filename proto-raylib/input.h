#ifndef INPUT_H
#define INPUT_H

#include "sim.h"

SimInput input_poll(void);
bool input_pause_pressed(void);
bool input_any_press(void); // dismisses the web start gate

#endif
